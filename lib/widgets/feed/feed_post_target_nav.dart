import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/api/api_service.dart';
import '../../core/models/campaign_model.dart';
import '../../core/models/feed_post_model.dart';
import '../../screens/campaign_detail_screen.dart';
import '../../screens/expenditure_detail_screen.dart';

int? _extractEvidenceExpenditureId(FeedPostModel post) {
  final RegExp re = RegExp(r'evidence\D*(\d+)', caseSensitive: false);
  final String a = (post.title ?? '').trim();
  final String b = (post.targetName ?? '').trim();
  final Match? m = re.firstMatch(a.isNotEmpty ? a : b);
  if (m == null) return null;
  return int.tryParse(m.group(1)!);
}

bool isEvidencePost(FeedPostModel post) {
  final String type = post.postType.trim().toUpperCase();
  if (type.contains('EVIDENCE')) return true;
  final String t = (post.title ?? '').trim().toLowerCase();
  final String n = (post.targetName ?? '').trim().toLowerCase();
  return t.startsWith('evidence') || n.startsWith('evidence');
}

Future<void> _openExpenditureTarget(
  BuildContext context,
  ApiService api,
  int expenditureId,
) async {
  int? parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  try {
    final Response<dynamic> res = await api.getExpenditureById(expenditureId);
    final dynamic data = res.data;
    if (data is! Map) {
      throw Exception('invalid expenditure payload');
    }
    final Map<String, dynamic> exp = Map<String, dynamic>.from(data);
    final int? campaignId = parseInt(exp['campaignId']) ??
        parseInt((exp['campaign'] as Map?)?['id']);
    if (campaignId != null) {
      exp['campaignId'] = campaignId;
    }
    String campaignType = 'ITEMIZED';
    if (campaignId != null) {
      try {
        final Response<dynamic> cRes = await api.getCampaign(campaignId);
        final dynamic c = cRes.data;
        if (c is Map<String, dynamic>) {
          final dynamic t = c['type'];
          if (t != null && t.toString().trim().isNotEmpty) {
            campaignType = t.toString().trim();
          }
        }
      } catch (_) {}
    }
    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ExpenditureDetailScreen(
          expenditure: exp,
          campaignType: campaignType,
          forcePublicView: true,
        ),
      ),
    );
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không mở được minh chứng chi tiêu.')),
      );
    }
  }
}

/// Mở chiến dịch hoặc đợt chi từ [targetId] / [targetType] của bài feed.
Future<void> openFeedPostTarget(
  BuildContext context,
  ApiService api,
  FeedPostModel post,
) async {
  final int? tid = post.targetId;
  final String tt = (post.targetType ?? '').trim().toUpperCase();
  final int? evidenceExpenditureId = _extractEvidenceExpenditureId(post);
  if (!context.mounted) return;

  // Ưu tiên mở đợt chi khi đây là bài minh chứng (dù targetType không chuẩn).
  if (evidenceExpenditureId != null) {
    await _openExpenditureTarget(context, api, evidenceExpenditureId);
    return;
  }

  if (tid == null) return;

  if (tt == 'CAMPAIGN') {
    final String title = (post.targetName ?? '').trim().isEmpty
        ? 'Chiến dịch #$tid'
        : post.targetName!.trim();
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CampaignDetailScreen(
          campaign: CampaignModel(id: tid, title: title),
        ),
      ),
    );
    return;
  }

  if (tt == 'EXPENDITURE') {
    await _openExpenditureTarget(context, api, tid);
  }
}

/// Chip bấm được: chiến dịch / đợt chi (dùng trên feed và màn chi tiết).
class FeedPostTargetPill extends StatelessWidget {
  const FeedPostTargetPill({
    super.key,
    required this.api,
    required this.post,
  });

  final ApiService api;
  final FeedPostModel post;

  String _cleanTargetName(String value) {
    String cleaned = value.trim();
    // Backend đôi khi trả tiền tố kỹ thuật kiểu `evidence...` trước tên đợt chi.
    // Dùng [a-zA-Z0-9_]* thay vì \S* để không ăn mất ký tự Unicode (Đợt, ...).
    cleaned = cleaned.replaceFirst(
      RegExp(r'^evidence[a-zA-Z0-9_]*\s*[-:|]?\s*', caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned;
  }

  bool _isEvidenceTarget(String value) {
    return value.trim().toLowerCase().startsWith('evidence');
  }

  String _formatExpenditureLabel(String rawName, int id) {
    if (rawName.isEmpty) return 'Chi tiêu đợt #$id';
    final String lower = rawName.toLowerCase();
    if (lower.startsWith('chi tiêu đợt')) return rawName;
    if (lower.startsWith('tiêu đợt')) return 'Chi $rawName';
    if (lower.startsWith('đợt')) return 'Chi tiêu $rawName';
    return 'Chi tiêu đợt $rawName';
  }

  @override
  Widget build(BuildContext context) {
    final int? tid = post.targetId;
    if (tid == null) return const SizedBox.shrink();
    final String tt = (post.targetType ?? '').trim().toUpperCase();
    if (tt != 'CAMPAIGN' && tt != 'EXPENDITURE') {
      return const SizedBox.shrink();
    }
    final bool isCampaign = tt == 'CAMPAIGN';
    final String originalTargetName = post.targetName ?? '';
    final String rawName = _cleanTargetName(originalTargetName);
    final bool evidence = isEvidencePost(post) ||
        (!isCampaign && _isEvidenceTarget(originalTargetName));
    final String expenditureLabel = _formatExpenditureLabel(rawName, tid);
    final String label = evidence
        ? 'Minh chứng'
        : (isCampaign
            ? (rawName.isEmpty ? 'Chiến dịch #$tid' : rawName)
            : expenditureLabel);
    final Color fg = evidence ? const Color(0xFF6D28D9) : const Color(0xFF166534);
    final Color bg = evidence ? const Color(0xFFF5F3FF) : const Color(0xFFECFDF5);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: () => openFeedPostTarget(context, api, post),
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: <Widget>[
                Icon(
                  evidence
                      ? Icons.verified_outlined
                      : (isCampaign
                          ? Icons.campaign_outlined
                          : Icons.receipt_long_outlined),
                  size: 18,
                  color: fg,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: fg,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: fg,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
