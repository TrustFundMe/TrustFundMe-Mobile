import 'package:flutter/material.dart';

import '../core/api/api_service.dart';
import '../core/models/campaign_model.dart';
import '../core/models/payment_models.dart';
import 'donation_screen.dart';

class CampaignsScreen extends StatefulWidget {
  const CampaignsScreen({super.key});

  @override
  State<CampaignsScreen> createState() => _CampaignsScreenState();
}

class _CampaignsScreenState extends State<CampaignsScreen> {
  final ApiService _api = ApiService();
  bool _loading = true;
  List<CampaignModel> _campaigns = <CampaignModel>[];
  final Map<int, CampaignProgressModel> _progressByCampaign =
      <int, CampaignProgressModel>{};

  @override
  void initState() {
    super.initState();
    _fetchCampaigns();
  }

  Future<void> _fetchCampaigns() async {
    try {
      final response = await _api.getCampaigns();
      final List<dynamic> data = response.data as List<dynamic>;
      _campaigns = data
          .map(
            (dynamic e) =>
                CampaignModel.fromJson(e as Map<String, dynamic>),
          )
          .toList();

      for (final CampaignModel c in _campaigns) {
        try {
          final progressRes = await _api.getCampaignProgress(c.id);
          final CampaignProgressModel progress =
              CampaignProgressModel.fromJson(
            progressRes.data as Map<String, dynamic>,
          );
          _progressByCampaign[c.id] = progress;
        } catch (_) {
          // bỏ qua lỗi progress để không chặn danh sách
        }
      }
    } catch (_) {
      _campaigns = <CampaignModel>[];
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Chiến dịch',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchCampaigns,
              child: _campaigns.isEmpty
                  ? const ListView(
                      children: <Widget>[
                        SizedBox(height: 120),
                        Center(
                          child: Text(
                            'Hiện chưa có chiến dịch nào.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _campaigns.length,
                      itemBuilder: (BuildContext context, int index) {
                        final CampaignModel campaign = _campaigns[index];
                        final CampaignProgressModel? progress =
                            _progressByCampaign[campaign.id];
                        final double ratio =
                            (progress?.progressPercentage ?? 0) / 100;
                        return Card(
                          margin:
                              const EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (BuildContext context) =>
                                      DonationScreen(campaign: campaign),
                                ),
                              );
                            },
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: <Widget>[
                                if (campaign.coverImageUrl != null)
                                  ClipRRect(
                                    borderRadius:
                                        const BorderRadius.vertical(
                                      top: Radius.circular(16),
                                    ),
                                    child: Image.network(
                                      campaign.coverImageUrl!,
                                      height: 180,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder: (BuildContext _,
                                              Object __,
                                              StackTrace? ___) =>
                                          Container(
                                        height: 180,
                                        color: Colors.grey[200],
                                        alignment: Alignment.center,
                                        child: const Icon(
                                          Icons.image_not_supported,
                                          size: 40,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  Container(
                                    height: 180,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius:
                                          const BorderRadius.vertical(
                                        top: Radius.circular(16),
                                      ),
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.image,
                                        size: 40,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        campaign.title,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      if (campaign.categoryName !=
                                          null)
                                        Text(
                                          campaign.categoryName!,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      const SizedBox(height: 8),
                                      LinearProgressIndicator(
                                        value: ratio.clamp(0, 1),
                                        backgroundColor:
                                            Colors.grey[200],
                                        color: const Color(0xFFF84D43),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment
                                                .spaceBetween,
                                        children: <Widget>[
                                          Text(
                                            'Đã đạt: ${progress?.progressPercentage ?? 0}%',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color:
                                                  Color(0xFF4B5563),
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              Navigator.of(context)
                                                  .push(
                                                MaterialPageRoute<
                                                    void>(
                                                  builder: (BuildContext
                                                          context) =>
                                                      DonationScreen(
                                                    campaign:
                                                        campaign,
                                                  ),
                                                ),
                                              );
                                            },
                                            child: const Text(
                                              'Quyên góp',
                                              style: TextStyle(
                                                fontWeight:
                                                    FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
