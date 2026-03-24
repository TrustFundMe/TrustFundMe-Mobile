
class Conversation {
  final int id;
  final int? staffId;
  final int fundOwnerId;
  final int campaignId;
  final DateTime? lastMessageAt;
  final DateTime createdAt;
  final String? lastMessageContent;

  Conversation({
    required this.id,
    this.staffId,
    required this.fundOwnerId,
    required this.campaignId,
    this.lastMessageAt,
    required this.createdAt,
    this.lastMessageContent,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'],
      staffId: json['staffId'],
      fundOwnerId: json['fundOwnerId'],
      campaignId: json['campaignId'],
      lastMessageAt: json['lastMessageAt'] != null ? DateTime.parse(json['lastMessageAt']) : null,
      createdAt: DateTime.parse(json['createdAt']),
      lastMessageContent: json['lastMessageContent'],
    );
  }
}

class ChatMessage {
  final String id;
  final String content;
  final int senderId;
  final String senderRole;
  final int conversationId;
  final DateTime createdAt;
  final bool isMe;
  final String senderName;

  ChatMessage({
    required this.id,
    required this.content,
    required this.senderId,
    required this.senderRole,
    required this.conversationId,
    required this.createdAt,
    required this.isMe,
    required this.senderName,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json, int currentUserId) {
    final senderId = json['senderId'] ?? 0;
    return ChatMessage(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      content: json['content'] ?? "",
      senderId: senderId,
      senderRole: json['senderRole'] ?? "",
      conversationId: json['conversationId'],
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
      isMe: senderId == currentUserId,
      senderName: senderId == 0 ? "Bot" : (senderId == currentUserId ? "Tôi" : "Staff"),
    );
  }
}
