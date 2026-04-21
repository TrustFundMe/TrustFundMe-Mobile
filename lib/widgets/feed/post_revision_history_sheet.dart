import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../core/api/api_service.dart';
import '../../core/models/feed_post_revision_model.dart';

/// Shows the post revision history as a modal bottom sheet.
Future<void> showPostRevisionHistorySheet(
  BuildContext context, {
  required int postId,
  String? currentTitle,
  String? currentContent,
  List<RevisionMediaItem>? currentMedia,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext ctx) => _RevisionHistorySheet(
      postId: postId,
      currentTitle: currentTitle,
      currentContent: currentContent,
      currentMedia: currentMedia,
    ),
  );
}

// ─── Word-level diff engine ──────────────────────────────────────────────────

enum _DiffType { same, added, removed }

class _DiffSeg {
  const _DiffSeg(this.type, this.text);
  final _DiffType type;
  final String text;
}

List<_DiffSeg> _wordDiff(String before, String after) {
  final List<String> bW = before.split(RegExp(r'(\s+)'));
  final List<String> aW = after.split(RegExp(r'(\s+)'));
  const int cap = 400;
  final int bm = math.min(bW.length, cap);
  final int an = math.min(aW.length, cap);

  final List<List<int>> lcs = List<List<int>>.generate(
    bm + 1, (_) => List<int>.filled(an + 1, 0),
  );
  for (int i = 1; i <= bm; i++) {
    for (int j = 1; j <= an; j++) {
      lcs[i][j] = bW[i - 1] == aW[j - 1]
          ? lcs[i - 1][j - 1] + 1
          : math.max(lcs[i - 1][j], lcs[i][j - 1]);
    }
  }

  final List<_DiffSeg> segs = <_DiffSeg>[];
  int i = bm, j = an;
  while (i > 0 || j > 0) {
    if (i > 0 && j > 0 && bW[i - 1] == aW[j - 1]) {
      segs.insert(0, _DiffSeg(_DiffType.same, bW[i - 1]));
      i--;
      j--;
    } else if (j > 0 && (i == 0 || lcs[i][j - 1] >= lcs[i - 1][j])) {
      segs.insert(0, _DiffSeg(_DiffType.added, aW[j - 1]));
      j--;
    } else {
      segs.insert(0, _DiffSeg(_DiffType.removed, bW[i - 1]));
      i--;
    }
  }
  return segs;
}

// ─── Change summary ──────────────────────────────────────────────────────────

class _ChangeTag {
  const _ChangeTag(this.label, this.kind);
  final String label;
  final String kind; // 'title' | 'content' | 'media-add' | 'media-remove' | 'link'
}

class _VersionState {
  const _VersionState({this.title, required this.content, required this.mediaCount, this.media});
  final String? title;
  final String content;
  final int mediaCount;
  final List<RevisionMediaItem>? media;
}

_VersionState _revToState(FeedPostRevisionModel r) =>
    _VersionState(
      title: r.title,
      content: r.content,
      mediaCount: r.mediaSnapshot.length,
      media: r.mediaSnapshot,
    );

List<_ChangeTag> _computeTags(_VersionState before, _VersionState after, {String? editNote}) {
  final List<_ChangeTag> tags = <_ChangeTag>[];
  if ((before.title ?? '') != (after.title ?? '')) {
    tags.add(const _ChangeTag('Sửa tiêu đề', 'title'));
  }
  if (before.content != after.content) {
    tags.add(const _ChangeTag('Sửa nội dung', 'content'));
  }
  // URL-level media comparison for accuracy
  final Set<String> beforeUrls = (before.media ?? <RevisionMediaItem>[]).map((RevisionMediaItem m) => m.url).toSet();
  final Set<String> afterUrls = (after.media ?? <RevisionMediaItem>[]).map((RevisionMediaItem m) => m.url).toSet();
  final int added = afterUrls.difference(beforeUrls).length;
  final int removed = beforeUrls.difference(afterUrls).length;
  if (added > 0) tags.add(_ChangeTag('+$added ảnh', 'media-add'));
  if (removed > 0) tags.add(_ChangeTag('$removed ảnh xóa', 'media-remove'));
  // Fallback when no snapshots available (count-only)
  if (added == 0 && removed == 0 && before.mediaCount != after.mediaCount) {
    final int diff = after.mediaCount - before.mediaCount;
    if (diff > 0) tags.add(_ChangeTag('+$diff ảnh', 'media-add'));
    if (diff < 0) tags.add(_ChangeTag('${diff.abs()} ảnh xóa', 'media-remove'));
  }
  if (editNote != null && editNote.isNotEmpty && tags.isEmpty) {
    tags.add(_ChangeTag(editNote, 'link'));
  }
  return tags;
}

Color _tagBg(String kind) {
  switch (kind) {
    case 'title':        return const Color(0x193B82F6);
    case 'content':      return const Color(0x191A685B);
    case 'media-add':    return const Color(0x1910B981);
    case 'media-remove': return const Color(0x19EF4444);
    case 'link':         return const Color(0x19F59E0B);
    default:             return const Color(0x19000000);
  }
}

Color _tagFg(String kind) {
  switch (kind) {
    case 'title':        return const Color(0xFF2563EB);
    case 'content':      return const Color(0xFF1A685B);
    case 'media-add':    return const Color(0xFF059669);
    case 'media-remove': return const Color(0xFFDC2626);
    case 'link':         return const Color(0xFFD97706);
    default:             return const Color(0xFF374151);
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

String _fmtDate(String raw) {
  if (raw.isEmpty) return '';
  final DateTime? d = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
  if (d == null) return raw;
  return '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year} '
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';
}

int _safeInt(dynamic v, {int fallback = 0}) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? fallback;
}

// ─── Main sheet ──────────────────────────────────────────────────────────────

class _RevisionHistorySheet extends StatefulWidget {
  const _RevisionHistorySheet({
    required this.postId,
    this.currentTitle,
    this.currentContent,
    this.currentMedia,
  });
  final int postId;
  final String? currentTitle;
  final String? currentContent;
  final List<RevisionMediaItem>? currentMedia;

  @override
  State<_RevisionHistorySheet> createState() => _RevisionHistorySheetState();
}

class _RevisionHistorySheetState extends State<_RevisionHistorySheet> {
  static const Color _primary = Color(0xFF1A685B);
  static const Color _text = Color(0xFF111827);
  static const Color _muted = Color(0xFF6B7280);

  final ApiService _api = ApiService();
  List<FeedPostRevisionModel> _revisions = <FeedPostRevisionModel>[];
  List<RevisionMediaItem> _liveMedia = <RevisionMediaItem>[];
  bool _loading = false;
  String? _error;
  int? _selectedIdx; // index in _revisions (sorted asc by revisionNo)

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait(<Future<dynamic>>[
        _api.getFeedPostRevisions(widget.postId, page: 0, size: 50),
        _api.getMediaByPostId(widget.postId).catchError((_) => Response<dynamic>(requestOptions: RequestOptions(), data: <dynamic>[])),
      ]);
      final Response<dynamic> revRes = results[0] as Response<dynamic>;
      final Response<dynamic> mediaRes = results[1] as Response<dynamic>;

      // Parse revisions
      List<dynamic> items = <dynamic>[];
      final dynamic data = revRes.data;
      if (data is Map<String, dynamic>) {
        items = (data['content'] as List<dynamic>?) ?? <dynamic>[];
      } else if (data is List<dynamic>) {
        items = data;
      }
      final List<FeedPostRevisionModel> parsed = items
          .whereType<Map<String, dynamic>>()
          .map(FeedPostRevisionModel.fromJson)
          .toList()
        ..sort((FeedPostRevisionModel a, FeedPostRevisionModel b) => a.revisionNo.compareTo(b.revisionNo));

      // Parse live media
      List<RevisionMediaItem> live = <RevisionMediaItem>[];
      final dynamic md = mediaRes.data;
      if (md is List) {
        for (final dynamic m in md) {
          if (m is Map<String, dynamic>) {
            live.add(RevisionMediaItem(
              mediaId: _safeInt(m['id']),
              url: (m['url'] as String?) ?? '',
              mediaType: m['mediaType'] as String?,
            ));
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _revisions = parsed;
        _liveMedia = live;
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      final int? statusCode = e.response?.statusCode;
      String message;
      if (statusCode == 404) {
        message = 'Bài viết không tồn tại hoặc đã bị xóa.';
      } else if (statusCode == 403) {
        message = 'Bạn không có quyền xem lịch sử chỉnh sửa.';
      } else {
        message = 'Không tải được lịch sử chỉnh sửa. Vui lòng thử lại.';
      }
      setState(() { _error = message; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _error = 'Không tải được lịch sử chỉnh sửa.'; _loading = false; });
    }
  }

  _VersionState _afterState(int i) {
    if (i + 1 < _revisions.length) {
      final FeedPostRevisionModel next = _revisions[i + 1];
      return _VersionState(
        title: next.title,
        content: next.content,
        mediaCount: next.mediaSnapshot.length,
        media: next.mediaSnapshot,
      );
    }
    return _VersionState(
      title: widget.currentTitle,
      content: widget.currentContent ?? '',
      mediaCount: (widget.currentMedia ?? _liveMedia).length,
      media: widget.currentMedia ?? _liveMedia,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      builder: (BuildContext ctx, ScrollController scroll) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: <Widget>[
              const SizedBox(height: 12),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: <Widget>[
                    if (_selectedIdx != null)
                      GestureDetector(
                        onTap: () => setState(() => _selectedIdx = null),
                        child: Container(
                          width: 32, height: 32,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.chevron_left, size: 18),
                        ),
                      ),
                    const Icon(Icons.history, size: 18, color: _primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedIdx != null
                            ? 'Lần chỉnh sửa #${_selectedIdx! + 1}'
                            : 'Lịch sử chỉnh sửa',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: _text),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close, size: 20),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 1),
              Expanded(
                child: _selectedIdx != null
                    ? _buildDetail(_selectedIdx!, scroll)
                    : _buildList(scroll),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── List view ──────────────────────────────────────────────────────────────

  Widget _buildList(ScrollController scroll) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFF84D43), fontSize: 14)),
              const SizedBox(height: 16),
              TextButton(onPressed: () { setState(() { _error = null; }); _load(); }, child: const Text('Thử lại')),
            ],
          ),
        ),
      );
    }
    if (_loading && _revisions.isEmpty) return const Center(child: CircularProgressIndicator());
    if (!_loading && _revisions.isEmpty) {
      return const Center(
        child: Padding(padding: EdgeInsets.all(32), child: Text('Bài viết chưa được chỉnh sửa lần nào.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14))),
      );
    }

    // Display newest first
    final List<int> order = List<int>.generate(_revisions.length, (int i) => i).reversed.toList();

    return ListView.builder(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: order.length + 1, // +1 for "current version" header
      itemBuilder: (BuildContext ctx, int listIdx) {
        if (listIdx == 0) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFD1FAE5)),
            ),
            child: Row(
              children: <Widget>[
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: _primary, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                const Text('Phiên bản hiện tại', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _primary)),
              ],
            ),
          );
        }
        final int revIdx = order[listIdx - 1];
        final FeedPostRevisionModel rev = _revisions[revIdx];
        final List<_ChangeTag> tags = _computeTags(_revToState(rev), _afterState(revIdx), editNote: rev.editNote);
        final int editNo = revIdx + 1;

        return GestureDetector(
          onTap: () => setState(() => _selectedIdx = revIdx),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(15)),
                  child: Center(child: Text('#$editNo', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _primary))),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Flexible(child: Text(_fmtDate(rev.createdAt), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _text))),
                          if (rev.editedByName != null) ...<Widget>[
                            Text(' · ', style: TextStyle(fontSize: 12, color: _muted)),
                            Flexible(child: Text(rev.editedByName!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: _muted))),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (tags.isNotEmpty)
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: tags.map((_ChangeTag t) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(color: _tagBg(t.kind), borderRadius: BorderRadius.circular(20)),
                            child: Text(t.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _tagFg(t.kind))),
                          )).toList(),
                        )
                      else
                        const Text('Không phát hiện thay đổi', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), fontStyle: FontStyle.italic)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, size: 18, color: Color(0xFF9CA3AF)),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Detail view ────────────────────────────────────────────────────────────

  Widget _buildDetail(int idx, ScrollController scroll) {
    final FeedPostRevisionModel rev = _revisions[idx];
    final _VersionState before = _revToState(rev);
    final _VersionState after = _afterState(idx);
    final List<_ChangeTag> tags = _computeTags(before, after, editNote: rev.editNote);
    final int editNo = idx + 1;

    final bool titleChanged = (before.title ?? '') != (after.title ?? '');
    final bool contentChanged = before.content != after.content;

    // Media diff
    final List<RevisionMediaItem> beforeMedia = before.media ?? <RevisionMediaItem>[];
    final List<RevisionMediaItem> afterMedia = after.media ?? <RevisionMediaItem>[];
    final Set<String> afterUrls = afterMedia.map((RevisionMediaItem m) => m.url).toSet();
    final Set<String> beforeUrls = beforeMedia.map((RevisionMediaItem m) => m.url).toSet();
    final List<RevisionMediaItem> removedMedia = beforeMedia.where((RevisionMediaItem m) => !afterUrls.contains(m.url)).toList();
    final List<RevisionMediaItem> addedMedia = afterMedia.where((RevisionMediaItem m) => !beforeUrls.contains(m.url)).toList();

    return ListView(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: <Widget>[
        // Meta
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFD1FAE5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Text('Lần chỉnh sửa #$editNo', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _primary)),
                  const Text('·', style: TextStyle(fontSize: 12, color: _muted)),
                  Text(_fmtDate(rev.createdAt), style: const TextStyle(fontSize: 12, color: _muted)),
                  if (rev.editedByName != null) ...<Widget>[
                    const Text('·', style: TextStyle(fontSize: 12, color: _muted)),
                    Text('bởi ${rev.editedByName}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _text)),
                  ],
                ],
              ),
              if (rev.editNote != null && rev.editNote!.isNotEmpty) ...<Widget>[
                const SizedBox(height: 4),
                Text('"${rev.editNote}"', style: const TextStyle(fontSize: 12, color: _muted, fontStyle: FontStyle.italic)),
              ],
              if (tags.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4, runSpacing: 4,
                  children: tags.map((_ChangeTag t) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: _tagBg(t.kind), borderRadius: BorderRadius.circular(20)),
                    child: Text(t.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _tagFg(t.kind))),
                  )).toList(),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Title diff
        if (titleChanged) ...<Widget>[
          _sectionLabel('TIÊU ĐỀ (THAY ĐỔI)'),
          const SizedBox(height: 6),
          _beforeAfterRow(before.title ?? '(Trống)', after.title ?? '(Trống)'),
          const SizedBox(height: 8),
          _diffText(_wordDiff(before.title ?? '', after.title ?? '')),
          const SizedBox(height: 16),
        ] else if ((before.title ?? '').isNotEmpty) ...<Widget>[
          _sectionLabel('TIÊU ĐỀ'),
          const SizedBox(height: 6),
          Text(before.title!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _text)),
          const SizedBox(height: 16),
        ],

        // Content diff
        if (contentChanged) ...<Widget>[
          _sectionLabel('NỘI DUNG (THAY ĐỔI)'),
          const SizedBox(height: 6),
          _diffText(_wordDiff(before.content, after.content)),
          const SizedBox(height: 16),
        ] else ...<Widget>[
          _sectionLabel('NỘI DUNG (KHÔNG ĐỔI)'),
          const SizedBox(height: 6),
          Text(before.content, style: const TextStyle(fontSize: 14, height: 1.55, color: Color(0xFF374151))),
          const SizedBox(height: 16),
        ],

        // Media diff
        if (addedMedia.isNotEmpty) ...<Widget>[
          _mediaChangeHeader('+${addedMedia.length} ảnh thêm', const Color(0xFF059669), Icons.add_circle_outline),
          const SizedBox(height: 6),
          _mediaGrid(addedMedia, const Color(0xFF10B981)),
          const SizedBox(height: 12),
        ],
        if (removedMedia.isNotEmpty) ...<Widget>[
          _mediaChangeHeader('${removedMedia.length} ảnh xóa', const Color(0xFFDC2626), Icons.remove_circle_outline),
          const SizedBox(height: 6),
          _mediaGrid(removedMedia, const Color(0xFFEF4444)),
          const SizedBox(height: 12),
        ],

        if (tags.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: Text('Không phát hiện sự thay đổi nào.', style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)))),
          ),
      ],
    );
  }

  // ─── Shared widgets ─────────────────────────────────────────────────────────

  Widget _sectionLabel(String label) => Text(
    label,
    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _muted, letterSpacing: 0.8),
  );

  Widget _beforeAfterRow(String before, String after) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0x0FEF4444), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0x26EF4444))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('TRƯỚC', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFFDC2626), letterSpacing: 0.5)),
                const SizedBox(height: 3),
                Text(before, style: const TextStyle(fontSize: 13, color: Color(0xFF991B1B))),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0x0F10B981), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0x2610B981))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('SAU', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF059669), letterSpacing: 0.5)),
                const SizedBox(height: 3),
                Text(after, style: const TextStyle(fontSize: 13, color: Color(0xFF065F46))),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _diffText(List<_DiffSeg> segs) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 13, height: 1.6, color: Color(0xFF374151)),
        children: segs.map((_DiffSeg s) {
          switch (s.type) {
            case _DiffType.added:
              return TextSpan(
                text: s.text,
                style: const TextStyle(backgroundColor: Color(0x3010B981), color: Color(0xFF065F46)),
              );
            case _DiffType.removed:
              return TextSpan(
                text: s.text,
                style: const TextStyle(backgroundColor: Color(0x20EF4444), color: Color(0xFF991B1B), decoration: TextDecoration.lineThrough),
              );
            case _DiffType.same:
              return TextSpan(text: s.text);
          }
        }).toList(),
      ),
    );
  }

  Widget _mediaChangeHeader(String label, Color color, IconData icon) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }

  Widget _mediaGrid(List<RevisionMediaItem> items, Color borderColor) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 6, mainAxisSpacing: 6),
      itemCount: items.length,
      itemBuilder: (BuildContext ctx, int i) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor, width: 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: items[i].url.isNotEmpty
                ? Image.network(
                    items[i].url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFFF3F4F6),
                      child: const Icon(Icons.broken_image_outlined, color: Color(0xFF9CA3AF)),
                    ),
                  )
                : Container(color: const Color(0xFFF3F4F6)),
          ),
        );
      },
    );
  }
}
