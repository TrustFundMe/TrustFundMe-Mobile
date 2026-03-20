
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/providers/auth_provider.dart';
import '../core/api/api_service.dart';
import 'create_campaign_screen.dart';
import 'edit_campaign_screen.dart';
import 'package:intl/intl.dart';

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

  Future<void> _fetchMyCampaigns() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final response = await _apiService.getUserCampaigns(user.id, page: _currentPage, size: 10);
      if (response.statusCode == 200) {
        final List<dynamic> newItems = response.data['content'] ?? [];
        setState(() {
          if (_currentPage == 0) {
            _campaigns = newItems;
          } else {
            _campaigns.addAll(newItems);
          }
          _currentPage++;
          _hasMore = newItems.length == 10;
        });
      }
    } catch (e) {
      debugPrint("Error fetching campaigns: $e");
    } finally {
      setState(() => _isLoading = false);
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
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Color(0xFF1F2937)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _currentPage = 0;
            _hasMore = true;
          });
          await _fetchMyCampaigns();
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateCampaignScreen()),
          ).then((_) => _fetchMyCampaigns()); // Refresh after creation
        },
        backgroundColor: const Color(0xFFF84D43),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Tạo chiến dịch", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                             Navigator.push(
                               context,
                               MaterialPageRoute(
                                 builder: (context) => EditCampaignScreen(
                                   campaignId: campaign['id'],
                                 ),
                               ),
                             ).then((_) {
                               setState(() {
                                 _currentPage = 0;
                                 _campaigns = [];
                               });
                               _fetchMyCampaigns();
                             });
                          },
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text("Chỉnh sửa"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.withAlpha(200),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
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
}
