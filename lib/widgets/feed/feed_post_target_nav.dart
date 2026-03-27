import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/api/api_service.dart';
import '../../core/models/campaign_model.dart';
import '../../core/models/feed_post_model.dart';
import '../../screens/campaign_detail_screen.dart';
import '../../screens/expenditure_detail_screen.dart';

/// Mở chiến dịch hoặc đợt chi từ [targetId] / [targetType] của bài feed.
Future<void> openFeedPostTarget(
  BuildContext context,
  ApiService api,
  FeedPostModel post,
) async {
  final int? tid = post.targetId;
  if (tid == null) return;
  final String tt = (post.targetType ?? '').trim().toUpperCase();
  if (!context.mounted) return;

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
    try {
      final Response<dynamic> res = await api.getExpenditureById(tid);
      final dynamic data = res.data;
      if (data is! Map) {
        throw Exception('invalid expenditure payload');
      }
      final Map<String, dynamic> exp = Map<String, dynamic>.from(data);
      final dynamic rawCid = exp['campaignId'];
      final int? campaignId = rawCid is int
          ? rawCid
          : int.tryParse(rawCid?.toString() ?? '');
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
          ),
        ),
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không mở được đợt chi.')),
        );
      }
    }
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

  @override
  Widget build(BuildContext context) {
    final int? tid = post.targetId;
    if (tid == null) return const SizedBox.shrink();
    final String tt = (post.targetType ?? '').trim().toUpperCase();
    if (tt != 'CAMPAIGN' && tt != 'EXPENDITURE') {
      return const SizedBox.shrink();
    }
    final bool isCampaign = tt == 'CAMPAIGN';
    final String suffix = (post.targetName ?? '').trim().isEmpty
        ? (isCampaign ? 'Chiến dịch #$tid' : 'Đợt chi #$tid')
        : post.targetName!.trim();
    final String label =
        isCampaign ? 'Chiến dịch: $suffix' : 'Đợt chi: $suffix';

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: () => openFeedPostTarget(context, api, post),
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: <Widget>[
                Icon(
                  isCampaign
                      ? Icons.campaign_outlined
                      : Icons.receipt_long_outlined,
                  size: 18,
                  color: const Color(0xFF166534),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF166534),
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: Color(0xFF166534),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
