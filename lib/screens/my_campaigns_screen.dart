
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/providers/auth_provider.dart';
import '../core/api/api_service.dart';
import 'create_campaign_screen.dart';
import 'edit_campaign_screen.dart';
import 'campaign_detail_screen.dart';
import '../core/models/campaign_model.dart';
import 'package:intl/intl.dart';
import 'chat_screen.dart';
import 'campaign_expenditure_screen.dart';

class MyCampaignsScreen extends StatefulWidget {
  const MyCampaignsScreen({super.key});

  @override
  State<MyCampaignsScreen> createState() => _MyCampaignsScreenState();
}

class _MyCampaignsScreenState extends State<MyCampaignsScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<dynamic> _campaigns = [];
  int _currentPage = 0;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchMyCampaigns();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.8) {
      if (!_isLoading && _hasMore) {
        _fetchMyCampaigns();
      }
    }
  }

  /// [reset]: true = load lại từ trang 0 (sau sửa/tạo/kéo refresh). Bắt buộc nếu không
  /// [_currentPage] sẽ tiếp tục từ lần cuộn trước và API trả về trang rỗng → list "mất" hết.
  Future<void> _fetchMyCampaigns({bool reset = false}) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) return;

    setState(() {
      _isLoading = true;
      if (reset) {
        _currentPage = 0;
        _hasMore = true;
        _campaigns = <dynamic>[];
      }
    });

    final int requestedPage = reset ? 0 : _currentPage;

    try {
      final response = await _apiService.getUserCampaigns(
        user.id,
        page: requestedPage,
        size: 10,
      );
      if (response.statusCode == 200) {
        final List<dynamic> newItems = response.data['content'] ?? [];
        if (!mounted) return;
        setState(() {
          if (reset || requestedPage == 0) {
            _campaigns = List<dynamic>.from(newItems);
          } else {
            _campaigns.addAll(newItems);
          }
          _currentPage = requestedPage + 1;
          _hasMore = newItems.length == 10;
        });
      }
    } catch (e) {
      debugPrint("Error fetching campaigns: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toUpperCase()) {
      case 'APPROVED':
        return Colors.green;
      case 'PENDING':
        return Colors.orange;
      case 'REJECTED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text("Chiến dịch của tôi", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Color(0xFF1F2937)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CreateCampaignScreen()),
              ).then((_) {
                if (!mounted) return;
                _fetchMyCampaigns(reset: true);
              });
            },
            icon: const Icon(Icons.add_circle_outline, color: Color(0xFFF84D43), size: 28),
            tooltip: "Tạo chiến dịch",
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _fetchMyCampaigns(reset: true);
        },
        child: _campaigns.isEmpty && !_isLoading
            ? _buildEmptyState()
            : ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _campaigns.length + (_hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _campaigns.length) {
                    return const Center(child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ));
                  }
                  final campaign = _campaigns[index];
                  return _buildCampaignCard(campaign);
                },
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.orange.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.folder_open, size: 64, color: Colors.orange),
            ),
            const SizedBox(height: 16),
            const Text(
              "Bạn chưa có chiến dịch nào",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
            ),
            const SizedBox(height: 8),
            const Text(
              "Hãy bắt đầu tạo chiến dịch đầu tiên của bạn để giúp đỡ cộng đồng.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCampaignCard(Map<String, dynamic> campaign) {
    final NumberFormat currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
    final String status = campaign['status'] ?? 'PENDING';
    final String title = campaign['title'] ?? 'Không tiêu đề';
    final double targetAmount = (campaign['targetAmount'] ?? 0).toDouble();
    final String? coverUrl = campaign['coverImageUrl'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header với ảnh bìa
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Stack(
              children: [
                SizedBox(
                  height: 120,
                  width: double.infinity,
                  child: coverUrl != null
                      ? Image.network(coverUrl, fit: BoxFit.cover)
                      : Container(color: Colors.grey.shade200, child: const Icon(Icons.image, size: 48, color: Colors.grey)),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withAlpha(230),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1F2937)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Mục tiêu huy động", style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                        Text(currencyFormat.format(targetAmount), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF84D43))),
                      ],
                    ),
                    Expanded(
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (status.toUpperCase() == 'APPROVED') ...[
                            // Approved: Spending Campaign + View
                            _buildActionButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => CampaignExpenditureScreen(
                                      campaignId: campaign['id'],
                                      campaignTitle: title,
                                      campaignType: campaign['type'] ?? 'ITEMIZED',
                                    ),
                                  ),
                                );
                              },
                              icon: Icons.receipt_long_outlined,
                              label: "Chi tiêu",
                              color: const Color(0xFF1A685B), // webEmerald
                            ),
                            _buildActionButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => CampaignDetailScreen(
                                      campaign: CampaignModel.fromJson(campaign),
                                    ),
                                  ),
                                );
                              },
                              icon: Icons.visibility_outlined,
                              label: "Xem",
                              color: const Color(0xFF4B5563), // webTextGray
                              isSecondary: true,
                            ),
                            _buildActionButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ChatScreen(
                                      campaignId: campaign['id'],
                                      campaignTitle: title,
                                      staffId: campaign['assignedStaffId'],
                                      staffName: campaign['assignedStaffName'],
                                    ),
                                  ),
                                );
                              },
                              icon: Icons.chat_bubble_outline,
                              label: "Nhắn tin",
                              color: const Color(0xFF4B5563), // webTextGray
                              isSecondary: true,
                            ),
                          ] else ...[
                            // Not Approved: Edit + Message
                            _buildActionButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EditCampaignScreen(
                                      campaignId: campaign['id'],
                                    ),
                                  ),
                                ).then((_) {
                                  if (!mounted) return;
                                  _fetchMyCampaigns(reset: true);
                                });
                              },
                              icon: Icons.edit_outlined,
                              label: "Sửa",
                              color: const Color(0xFFF84D43), // webPrimary
                            ),
                            _buildActionButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ChatScreen(
                                      campaignId: campaign['id'],
                                      campaignTitle: title,
                                      staffId: campaign['assignedStaffId'],
                                      staffName: campaign['assignedStaffName'],
                                    ),
                                  ),
                                );
                              },
                              icon: Icons.chat_bubble_outline,
                              label: "Nhắn tin",
                              color: const Color(0xFF4B5563), // webTextGray
                              isSecondary: true,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (status == 'REJECTED' && campaign['rejectionReason'] != null)
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withAlpha(12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withAlpha(25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Lý do từ chối:", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red)),
                        const SizedBox(height: 2),
                        Text(campaign['rejectionReason'], style: const TextStyle(fontSize: 11, color: Colors.red)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
    bool isSecondary = false,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 14),
      label: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSecondary ? Colors.white : color,
        foregroundColor: isSecondary ? color : Colors.white,
        elevation: isSecondary ? 0 : 2,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: const Size(0, 36),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: isSecondary ? BorderSide(color: color.withOpacity(0.5)) : BorderSide.none,
        ),
      ),
    );
  }
}
