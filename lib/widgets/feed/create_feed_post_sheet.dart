import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_service.dart';
import '../../core/providers/auth_provider.dart';

class _CampaignPickResult {
  const _CampaignPickResult({required this.ids, required this.titles});

  final List<int> ids;
  final List<String> titles;

  static _CampaignPickResult empty() =>
      const _CampaignPickResult(ids: <int>[], titles: <String>[]);
}

Future<void> showCreateFeedPostSheet(
  BuildContext context, {
  int? linkedCampaignId,
  String? linkedCampaignTitle,
  VoidCallback? onCreated,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (BuildContext ctx) {
      return _CreateFeedPostBody(
        linkedCampaignId: linkedCampaignId,
        linkedCampaignTitle: linkedCampaignTitle,
        onCreated: onCreated,
      );
    },
  );
}

class _CreateFeedPostBody extends StatefulWidget {
  const _CreateFeedPostBody({
    this.linkedCampaignId,
    this.linkedCampaignTitle,
    this.onCreated,
  });

  final int? linkedCampaignId;
  final String? linkedCampaignTitle;
  final VoidCallback? onCreated;

  @override
  State<_CreateFeedPostBody> createState() => _CreateFeedPostBodyState();
}

class _CreateFeedPostBodyState extends State<_CreateFeedPostBody> {
  static const Color _primary = Color(0xFFF84D43);
  static const Color _green = Color(0xFF1A685B);

  final ApiService _api = ApiService();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _content = TextEditingController();
  final List<XFile> _picked = <XFile>[];
  bool _submitting = false;

  int? _optionalCampaignId;
  String _optionalCampaignLabel = '';

  @override
  void initState() {
    super.initState();
    if (widget.linkedCampaignId != null) {
      _optionalCampaignId = widget.linkedCampaignId;
      _optionalCampaignLabel =
          widget.linkedCampaignTitle ?? 'Chiến dịch #${widget.linkedCampaignId}';
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  static int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> files = await picker.pickMultiImage(imageQuality: 85);
    if (files.isEmpty) return;
    setState(() => _picked.addAll(files));
  }

  Future<_CampaignPickResult> _loadCampaignTitles(int userId) async {
    try {
      final dynamic data =
          (await _api.getUserCampaigns(userId, page: 0, size: 50)).data;
      if (data is! Map<String, dynamic>) return _CampaignPickResult.empty();
      final List<dynamic> content = data['content'] as List<dynamic>? ??
          data['items'] as List<dynamic>? ??
          <dynamic>[];
      final List<int> ids = <int>[];
      final List<String> titles = <String>[];
      for (final dynamic row in content) {
        if (row is Map<String, dynamic>) {
          final int? id = _parseInt(row['id']);
          final String title = (row['title'] as String?)?.trim() ?? '';
          if (id != null) {
            ids.add(id);
            titles.add(title.isEmpty ? 'Chiến dịch #$id' : title);
          }
        }
      }
      return _CampaignPickResult(ids: ids, titles: titles);
    } catch (_) {
      return _CampaignPickResult.empty();
    }
  }

  Future<void> _pickCampaignIfNeeded(AuthProvider auth) async {
    if (widget.linkedCampaignId != null || auth.user == null) return;
    final int userId = auth.user!.id;
    final _CampaignPickResult res = await _loadCampaignTitles(userId);
    if (!mounted || res.ids.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không có chiến dịch để gắn.')),
        );
      }
      return;
    }
    final int? selected = await showDialog<int>(
      context: context,
      builder: (BuildContext c) {
        return SimpleDialog(
          title: const Text('Gắn chiến dịch (tuỳ chọn)'),
          children: <Widget>[
            SimpleDialogOption(
              onPressed: () => Navigator.pop(c, -1),
              child: const Text('Bỏ gắn'),
            ),
            ...res.ids.asMap().entries.map((MapEntry<int, int> e) {
              return SimpleDialogOption(
                onPressed: () => Navigator.pop(c, e.value),
                child: Text(res.titles[e.key]),
              );
            }),
          ],
        );
      },
    );
    if (!mounted || selected == null) return;
    if (selected < 0) {
      setState(() {
        _optionalCampaignId = null;
        _optionalCampaignLabel = '';
      });
      return;
    }
    final int idx = res.ids.indexOf(selected);
    setState(() {
      _optionalCampaignId = selected;
      _optionalCampaignLabel =
          idx >= 0 ? res.titles[idx] : 'Chiến dịch #$selected';
    });
  }

  Future<void> _submit(AuthProvider auth) async {
    if (!auth.isLoggedIn || auth.user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để đăng bài.')),
      );
      return;
    }
    final String raw = _content.text.trim();
    if (raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nội dung không được để trống.')),
      );
      return;
    }
    final String titleText =
        _title.text.trim().isEmpty ? raw : _title.text.trim();

    setState(() => _submitting = true);
    try {
      final int? campaignTarget = widget.linkedCampaignId ?? _optionalCampaignId;
      final Response<dynamic> response = await _api.createFeedPost(
        <String, dynamic>{
          'type': 'DISCUSSION',
          'visibility': 'PUBLIC',
          'title':
              titleText.length > 50 ? titleText.substring(0, 50) : titleText,
          'content': raw.length > 2000 ? raw.substring(0, 2000) : raw,
          'status': 'PUBLISHED',
          if (campaignTarget != null) 'targetId': campaignTarget,
          if (campaignTarget != null) 'targetType': 'CAMPAIGN',
        },
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Tạo bài thất bại');
      }

      final dynamic data = response.data;
      int? postId;
      if (data is Map<String, dynamic>) {
        postId = _parseInt(data['id']);
      }

      if (postId != null && _picked.isNotEmpty) {
        for (final XFile x in _picked) {
          try {
            final File f = File(x.path);
            final Response<dynamic> up = await _api.uploadMedia(
              f,
              postId: postId,
              mediaType: 'PHOTO',
            );
            final dynamic u = up.data;
            if (u is Map<String, dynamic>) {
              final int? mid = _parseInt(u['id']);
              if (mid != null) {
                await _api
                    .updateMedia(mid, <String, dynamic>{'postId': postId});
              }
            }
          } catch (_) {
            // continue other images
          }
        }
      }

      if (!mounted) return;
      widget.onCreated?.call();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã đăng bài.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();
    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: bottomInset + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: Container(
                width: 46,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Đăng bài lên feed',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.linkedCampaignId != null
                  ? 'Bài viết sẽ được gắn với chiến dịch này.'
                  : 'Bài tự do hoặc gắn chiến dịch của bạn (tuỳ chọn).',
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 16),
            if (_optionalCampaignLabel.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.campaign_outlined, color: _green, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _optionalCampaignLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF166534),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (widget.linkedCampaignId == null) ...<Widget>[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _submitting ? null : () => _pickCampaignIfNeeded(auth),
                icon: const Icon(Icons.link, size: 18),
                label: Text(
                  _optionalCampaignId == null
                      ? 'Gắn chiến dịch (tuỳ chọn)'
                      : 'Đổi chiến dịch gắn kèm',
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Tiêu đề (tuỳ chọn)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _content,
              minLines: 4,
              maxLines: 10,
              decoration: InputDecoration(
                alignLabelWithHint: true,
                labelText: 'Nội dung *',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: _submitting ? null : _pickImages,
                  icon: const Icon(Icons.add_photo_alternate_outlined, size: 20),
                  label: Text('Ảnh (${_picked.length})'),
                ),
              ],
            ),
            if (_picked.isNotEmpty)
              SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _picked.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, int i) {
                    return Stack(
                      clipBehavior: Clip.none,
                      children: <Widget>[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            File(_picked[i].path),
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: -6,
                          right: -6,
                          child: IconButton(
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black87,
                              padding: const EdgeInsets.all(2),
                              minimumSize: const Size(24, 24),
                            ),
                            icon: const Icon(Icons.close, color: Colors.white, size: 14),
                            onPressed: _submitting
                                ? null
                                : () => setState(() => _picked.removeAt(i)),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _submitting ? null : () => _submit(auth),
              style: FilledButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _submitting
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Đăng bài',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
