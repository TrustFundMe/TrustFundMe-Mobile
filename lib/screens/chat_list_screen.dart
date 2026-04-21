
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/api/api_service.dart';
import '../core/models/chat_models.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final ApiService _api = ApiService();
  List<Conversation> _conversations = [];
  final Map<int, String> _campaignTitleOverrides = <int, String>{};
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final res = await _api.getConversations().timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final List<dynamic> data = res.data;
        final List<Conversation> conversations =
            data.map((c) => Conversation.fromJson(c)).toList();
        if (mounted) {
          setState(() {
            _conversations = conversations;
          });
        }
        await _resolveCampaignTitles(conversations);
      } else {
        if (mounted) {
          setState(() => _errorMessage = "Lỗi hệ thống (${res.statusCode})");
        }
      }
    } catch (e) {
      debugPrint("Error loading conversations: $e");
      if (mounted) {
        setState(() => _errorMessage = "Không thể kết nối đến máy chủ");
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool _looksLikeFallbackIdTitle(String? title, int campaignId) {
    final String t = (title ?? '').trim().toLowerCase();
    return t.isEmpty || t.contains('#$campaignId');
  }

  Future<void> _resolveCampaignTitles(List<Conversation> conversations) async {
    final Set<int> missingCampaignIds = conversations
        .where((Conversation c) => _looksLikeFallbackIdTitle(c.campaignTitle, c.campaignId))
        .map((Conversation c) => c.campaignId)
        .toSet();
    if (missingCampaignIds.isEmpty) return;

    final Map<int, String> resolved = <int, String>{};
    for (final int campaignId in missingCampaignIds) {
      try {
        final response = await _api.getCampaign(campaignId);
        final dynamic payload = response.data;
        if (payload is! Map<String, dynamic>) continue;
        final String title = (payload['title'] as String?)?.trim() ?? '';
        if (title.isNotEmpty) {
          resolved[campaignId] = title;
        }
      } catch (_) {}
    }
    if (!mounted || resolved.isEmpty) return;
    setState(() => _campaignTitleOverrides.addAll(resolved));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text(
          "Tin nhắn",
          style: TextStyle(color: Color(0xFF1F2937), fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF1F2937), size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadConversations,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? _buildErrorState()
                : _conversations.isEmpty
                    ? _buildEmptyState()
                    : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _conversations.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final conv = _conversations[index];
                      return _ConversationCard(
                        conversation: conv,
                        campaignTitleOverride: _campaignTitleOverrides[conv.campaignId],
                      );
                    },
                  ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 80, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? "Có lỗi xảy ra",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _loadConversations,
            child: const Text("Thử lại"),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.message_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            "Chưa có cuộc hội thoại nào",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            "Mở chi tiết một chiến dịch để bắt đầu chat",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _ConversationCard extends StatelessWidget {
  final Conversation conversation;
  final String? campaignTitleOverride;

  const _ConversationCard({
    required this.conversation,
    this.campaignTitleOverride,
  });

  @override
  Widget build(BuildContext context) {
    final String campaignTitle =
        (campaignTitleOverride ?? conversation.campaignTitle ?? '').trim().isNotEmpty
            ? (campaignTitleOverride ?? conversation.campaignTitle!).trim()
            : "Chiến dịch #${conversation.campaignId}";

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              campaignId: conversation.campaignId,
              campaignTitle: campaignTitle,
              staffId: conversation.staffId,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: const Color(0xFFF84D43).withOpacity(0.1),
              child: const Icon(Icons.forum_outlined, color: Color(0xFFF84D43)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          campaignTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                      if (conversation.lastMessageAt != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Text(
                            DateFormat('dd/MM').format(conversation.lastMessageAt ?? DateTime.now()),
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    conversation.lastMessageContent ?? "Nhấn để tiếp tục trò chuyện",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }
}
