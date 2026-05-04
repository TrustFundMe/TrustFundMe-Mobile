import 'package:dio/dio.dart';
import 'base_service.dart';

/// Service xử lý chat conversations, messages, appointments.
class ChatService extends BaseService {
  // ─── Conversations ────────────────────────────────────────────────────────

  /// Lấy danh sách conversations của user hiện tại.
  Future<Response<dynamic>> getConversations() async {
    return dio.get('$chatUrl/conversations');
  }

  /// Lấy messages theo conversation ID.
  Future<Response<dynamic>> getMessagesByConversationId(
    int conversationId,
  ) async {
    return dio.get('$chatUrl/conversations/$conversationId/messages');
  }

  /// Tạo conversation mới.
  Future<Response<dynamic>> createConversation({
    required int fundOwnerId,
    required int campaignId,
    int? staffId,
  }) async {
    return dio.post(
      '$chatUrl/conversations',
      data: <String, dynamic>{
        'fundOwnerId': fundOwnerId,
        'campaignId': campaignId,
        if (staffId != null) 'staffId': staffId,
      },
    );
  }

  /// Lấy conversation theo campaign ID.
  Future<Response<dynamic>> getConversationByCampaignId(
    int campaignId,
  ) async {
    return dio.get('$chatUrl/conversations/campaign/$campaignId');
  }

  // ─── Appointments ─────────────────────────────────────────────────────────

  /// Lấy appointments theo donor ID.
  Future<Response<dynamic>> getAppointmentsByDonor(int donorId) async {
    return dio.get('$appointmentUrl/donor/$donorId');
  }

  /// Cập nhật trạng thái appointment.
  Future<Response<dynamic>> updateAppointmentStatus(
    int appointmentId,
    String status,
  ) async {
    return dio.patch(
      '$appointmentUrl/$appointmentId/status',
      queryParameters: <String, dynamic>{'status': status},
    );
  }
}
