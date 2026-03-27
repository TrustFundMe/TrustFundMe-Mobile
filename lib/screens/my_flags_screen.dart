import 'package:flutter/material.dart';

import '../core/api/api_service.dart';
import '../core/models/campaign_model.dart';
import '../core/models/flag_model.dart';
import 'campaign_detail_screen.dart';
import 'feed_post_detail_screen.dart';

class MyFlagsScreen extends StatefulWidget {
  const MyFlagsScreen({super.key});

  @override
  State<MyFlagsScreen> createState() => _MyFlagsScreenState();
}

class _MyFlagsScreenState extends State<MyFlagsScreen>
    with SingleTickerProviderStateMixin {
  static const Color _bg = Color(0xFFF9FAFB);
  static const Color _text = Color(0xFF111827);
  static const Color _muted = Color(0xFF6B7280);

  final ApiService _api = ApiService();
  late final TabController _tab;

  bool _loading = true;
  List<FlagModel> _flags = <FlagModel>[];

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
    setState(() => _loading = true);
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
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _flags = <FlagModel>[];
        _loading = false;
      });
    }
  }

  Color _statusBg(String s) {
    switch (s.toUpperCase()) {
      case 'RESOLVED':
        return const Color(0xFFDCFCE7);
      case 'DISMISSED':
        return const Color(0xFFFEE2E2);
      default:
        return const Color(0xFFFFF7ED);
    }
  }

  Color _statusFg(String s) {
    switch (s.toUpperCase()) {
      case 'RESOLVED':
        return const Color(0xFF166534);
      case 'DISMISSED':
        return const Color(0xFFB91C1C);
      default:
        return const Color(0xFF9A3412);
    }
  }

  String _statusLabel(String s) {
    switch (s.toUpperCase()) {
      case 'RESOLVED':
        return 'Đã xử lý';
      case 'DISMISSED':
        return 'Đã bỏ qua';
      default:
        return 'Đang chờ';
    }
  }

  Future<void> _openCampaign(int campaignId) async {
    try {
      final res = await _api.getCampaign(campaignId);
      final dynamic data = res.data;
      if (data is! Map<String, dynamic>) return;
      final CampaignModel campaign = CampaignModel.fromJson(data);
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => CampaignDetailScreen(campaign: campaign),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không mở được chiến dịch.')),
        );
      }
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
          final String status = f.status;
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _statusBg(status),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _statusLabel(status),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: _statusFg(status),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      date,
                      style: const TextStyle(
                        fontSize: 12,
                        color: _muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      id == null ? '' : '#$id',
                      style: const TextStyle(
                        fontSize: 12,
                        color: _muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  f.reason.isEmpty ? 'Không có lý do' : f.reason,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: _text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: id == null
                        ? null
                        : () async {
                            if (isCampaign) {
                              await _openCampaign(id);
                            } else {
                              await Navigator.of(context).push<void>(
                                MaterialPageRoute<void>(
                                  builder: (_) => FeedPostDetailScreen(postId: id),
                                ),
                              );
                            }
                          },
                    child: Text(
                      isCampaign ? 'Xem chiến dịch' : 'Xem bài viết',
                      style: const TextStyle(fontWeight: FontWeight.w800),
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

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text(
          'Báo cáo của tôi',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: _text,
        bottom: TabBar(
          controller: _tab,
          labelColor: _text,
          unselectedLabelColor: _muted,
          indicatorColor: _text,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800),
          tabs: <Widget>[
            Tab(text: 'Chiến dịch (${campaignFlags.length})'),
            Tab(text: 'Bài viết (${postFlags.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: <Widget>[
          _buildList(campaignFlags, isCampaign: true),
          _buildList(postFlags, isCampaign: false),
        ],
      ),
    );
  }
}

