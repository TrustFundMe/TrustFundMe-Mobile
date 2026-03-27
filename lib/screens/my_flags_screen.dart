import 'package:flutter/material.dart';

import '../core/api/api_service.dart';
import '../core/models/campaign_model.dart';
import '../core/models/feed_post_model.dart';
import '../core/models/flag_model.dart';
import 'campaign_detail_screen.dart';
import 'feed_post_detail_screen.dart';

/// Resolved target label for a flag row (post title/snippet or campaign title).
class _TargetPreview {
  const _TargetPreview({
    required this.headline,
    this.subline,
    this.extra,
  });

  final String headline;
  final String? subline;
  final String? extra;
}

/// Full-screen route: [MyFlagsScreen]. Sheet: [showMyFlagsBottomSheet].
class MyFlagsScreen extends StatelessWidget {
  const MyFlagsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const MyFlagsView(sheetMode: false);
  }
}

Future<void> showMyFlagsBottomSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext ctx) {
      return Padding(
        padding: EdgeInsets.only(top: MediaQuery.of(ctx).padding.top + 8),
        child: const Align(
          alignment: Alignment.bottomCenter,
          child: MyFlagsView(sheetMode: true),
        ),
      );
    },
  );
}

class MyFlagsView extends StatefulWidget {
  const MyFlagsView({super.key, required this.sheetMode});

  final bool sheetMode;

  @override
  State<MyFlagsView> createState() => _MyFlagsViewState();
}

class _MyFlagsViewState extends State<MyFlagsView>
    with SingleTickerProviderStateMixin {
  static const Color _bg = Color(0xFFF9FAFB);
  static const Color _text = Color(0xFF111827);
  static const Color _muted = Color(0xFF6B7280);

  final ApiService _api = ApiService();
  late final TabController _tab;

  bool _loading = true;
  List<FlagModel> _flags = <FlagModel>[];
  Map<int, _TargetPreview> _postPreviewById = <int, _TargetPreview>{};
  Map<int, _TargetPreview> _campaignPreviewById = <int, _TargetPreview>{};
  bool _enrichingTargets = false;

  static String _snippet(String raw, int maxChars) {
    final String t = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (t.isEmpty) return '';
    if (t.length <= maxChars) return t;
    return '${t.substring(0, maxChars)}…';
  }

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  static String _fmtDate(String raw) {
    if (raw.isEmpty) return '';
    final DateTime? d = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
    if (d == null) return raw;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _postPreviewById = <int, _TargetPreview>{};
      _campaignPreviewById = <int, _TargetPreview>{};
    });
    try {
      final res = await _api.getMyFlags(page: 0, size: 100);
      final dynamic data = res.data;
      List<dynamic> content = <dynamic>[];
      if (data is Map<String, dynamic>) {
        final dynamic c = data['content'];
        if (c is List<dynamic>) content = c;
      } else if (data is List<dynamic>) {
        content = data;
      }
      final List<FlagModel> list = content
          .whereType<Map<String, dynamic>>()
          .map(FlagModel.fromJson)
          .toList();
      if (!mounted) return;
      setState(() {
        _flags = list;
        _loading = false;
      });
      await _enrichTargets(list);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _flags = <FlagModel>[];
        _loading = false;
      });
    }
  }

  Future<void> _enrichTargets(List<FlagModel> flags) async {
    final Set<int> postIds = <int>{};
    final Set<int> campaignIds = <int>{};
    for (final FlagModel f in flags) {
      if (f.postId != null) postIds.add(f.postId!);
      if (f.campaignId != null) campaignIds.add(f.campaignId!);
    }
    if (postIds.isEmpty && campaignIds.isEmpty) return;

    if (mounted) {
      setState(() => _enrichingTargets = true);
    }
    final Map<int, _TargetPreview> nextPosts = <int, _TargetPreview>{};
    final Map<int, _TargetPreview> nextCamps = <int, _TargetPreview>{};

    await Future.wait(<Future<void>>[
      ...postIds.map((int id) async {
        try {
          final res = await _api.getFeedPostById(id);
          final dynamic data = res.data;
          if (data is Map<String, dynamic>) {
            final FeedPostModel post = FeedPostModel.fromJson(data);
            String headline = (post.title != null && post.title!.trim().isNotEmpty)
                ? post.title!.trim()
                : _snippet(post.content, 120);
            if (headline.isEmpty) headline = 'Bài viết #$id';
            nextPosts[id] = _TargetPreview(
              headline: headline,
              subline: 'Tác giả: ${post.authorName}',
              extra: (post.targetName != null && post.targetName!.trim().isNotEmpty)
                  ? 'Liên quan: ${post.targetName}'
                  : null,
            );
          } else {
            nextPosts[id] = _TargetPreview(
              headline: 'Bài viết #$id',
              subline: 'Không tải được chi tiết bài viết.',
            );
          }
        } catch (_) {
          nextPosts[id] = _TargetPreview(
            headline: 'Bài viết #$id',
            subline: 'Không tải được chi tiết bài viết.',
          );
        }
      }),
      ...campaignIds.map((int id) async {
        try {
          final res = await _api.getCampaign(id);
          final dynamic data = res.data;
          if (data is Map<String, dynamic>) {
            final CampaignModel c = CampaignModel.fromJson(data);
            nextCamps[id] = _TargetPreview(
              headline: c.title.trim().isNotEmpty ? c.title.trim() : 'Chiến dịch #$id',
            );
          } else {
            nextCamps[id] = _TargetPreview(
              headline: 'Chiến dịch #$id',
              subline: 'Không tải được chi tiết chiến dịch.',
            );
          }
        } catch (_) {
          nextCamps[id] = _TargetPreview(
            headline: 'Chiến dịch #$id',
            subline: 'Không tải được chi tiết chiến dịch.',
          );
        }
      }),
    ]);

    if (!mounted) return;
    setState(() {
      _postPreviewById = nextPosts;
      _campaignPreviewById = nextCamps;
      _enrichingTargets = false;
    });
  }

  Future<void> _openCampaign(int campaignId, {required NavigatorState nav}) async {
    try {
      final res = await _api.getCampaign(campaignId);
      final dynamic data = res.data;
      if (data is! Map<String, dynamic>) return;
      final CampaignModel campaign = CampaignModel.fromJson(data);
      await nav.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => CampaignDetailScreen(campaign: campaign),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không mở được chiến dịch.')),
      );
    }
  }

  Widget _buildEmpty(String label) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: <Widget>[
        const SizedBox(height: 120),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildList(List<FlagModel> list, {required bool isCampaign}) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (list.isEmpty) {
      return _buildEmpty(
        isCampaign ? 'Chưa có tố cáo chiến dịch nào.' : 'Chưa có tố cáo bài viết nào.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (BuildContext c, int i) {
          final FlagModel f = list[i];
          final int? id = isCampaign ? f.campaignId : f.postId;
          final String date = _fmtDate(f.createdAt);
          final _TargetPreview? preview = id == null
              ? null
              : (isCampaign ? _campaignPreviewById[id] : _postPreviewById[id]);
          final String targetHeadline = preview?.headline ??
              (isCampaign ? 'Chiến dịch #${id ?? 0}' : 'Bài viết #${id ?? 0}');
          final String? targetSub = preview?.subline ??
              (_enrichingTargets ? 'Đang tải thông tin…' : null);
          final String? targetExtra = preview?.extra;

          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Center(
                        child: Text(
                          '✓',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF166534),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              'Tố cáo đã được gửi',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF166534),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            '·',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFFD1D5DB),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            date,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: _muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  isCampaign ? 'Chiến dịch' : 'Bài viết',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: _muted.withValues(alpha: 0.95),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  targetHeadline,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.35,
                    color: _text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (id != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    'ID #$id',
                    style: TextStyle(
                      fontSize: 12,
                      color: _muted.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (targetSub != null && targetSub.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    targetSub,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: _muted.withValues(alpha: 0.98),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (targetExtra != null && targetExtra.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    targetExtra,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: _muted.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  'Lý do tố cáo',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                    color: _muted.withValues(alpha: 0.95),
                  ),
                ),
                const SizedBox(height: 4),
                Tooltip(
                  message: f.reason.isEmpty ? 'Không có lý do' : f.reason,
                  child: Text(
                    f.reason.isEmpty ? 'Không có lý do' : f.reason,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: _text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: id == null
                        ? null
                        : () async {
                            final int targetId = id;
                            final NavigatorState rootNav =
                                Navigator.of(context, rootNavigator: true);

                            if (widget.sheetMode) {
                              Navigator.of(context).pop();
                            }

                            if (isCampaign) {
                              await _openCampaign(targetId, nav: rootNav);
                            } else {
                              await rootNav.push<void>(
                                MaterialPageRoute<void>(
                                  builder: (_) => FeedPostDetailScreen(postId: targetId),
                                ),
                              );
                            }
                          },
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: <Color>[
                            Color(0xFFEF4444),
                            Color(0xFFF97316),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            isCampaign ? 'Xem chiến dịch' : 'Xem bài viết',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              color: Colors.white,
                              height: 1,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<FlagModel> campaignFlags =
        _flags.where((FlagModel f) => f.campaignId != null).toList();
    final List<FlagModel> postFlags =
        _flags.where((FlagModel f) => f.postId != null).toList();

    final TabBar tabBar = TabBar(
      controller: _tab,
      labelColor: _text,
      unselectedLabelColor: _muted,
      indicatorColor: _text,
      labelStyle: const TextStyle(fontWeight: FontWeight.w800),
      tabs: <Widget>[
        Tab(text: 'Chiến dịch (${campaignFlags.length})'),
        Tab(text: 'Bài viết (${postFlags.length})'),
      ],
    );

    final Widget tabView = TabBarView(
      controller: _tab,
      children: <Widget>[
        _buildList(campaignFlags, isCampaign: true),
        _buildList(postFlags, isCampaign: false),
      ],
    );

    if (widget.sheetMode) {
      final double h = MediaQuery.sizeOf(context).height * 0.92;
      return Material(
        color: Colors.transparent,
        child: Container(
          height: h,
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: _text.withValues(alpha: 0.06),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Row(
                  children: <Widget>[
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            'Tố cáo của tôi',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: _text,
                            ),
                          ),
                          Text(
                            'Danh sách báo cáo bạn đã gửi',
                            style: TextStyle(
                              fontSize: 12,
                              color: _muted.withValues(alpha: 0.95),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: _text),
                    ),
                  ],
                ),
              ),
              tabBar,
              Expanded(child: tabView),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text(
          'Tố cáo của tôi',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: _text,
        bottom: tabBar,
      ),
      body: tabView,
    );
  }
}
