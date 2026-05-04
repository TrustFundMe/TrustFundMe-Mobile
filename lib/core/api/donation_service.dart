import 'package:dio/dio.dart';
import 'base_service.dart';

/// Service xử lý donations / payments.
///
/// Tách từ payment-related methods trong ApiService gốc.
class DonationService extends BaseService {
  /// Tạo payment (donation) mới.
  Future<Response<dynamic>> createPayment(
    Map<String, dynamic> body,
  ) async {
    return dio.post('$paymentUrl/create', data: body);
  }

  /// Xác minh trạng thái thanh toán của donation.
  Future<Response<dynamic>> verifyDonationPayment(int donationId) async {
    return dio.get('$paymentUrl/donation/$donationId/verify');
  }

  /// Đồng bộ số lượng donation.
  Future<Response<dynamic>> syncDonationQuantity(int donationId) async {
    return dio.post('$paymentUrl/donation/$donationId/sync-quantity');
  }

  /// Đồng bộ số dư donation.
  Future<Response<dynamic>> syncDonationBalance(int donationId) async {
    return dio.post('$paymentUrl/donation/$donationId/sync-balance');
  }

  /// Lấy tóm tắt donation theo danh sách expenditure item IDs.
  Future<Response<dynamic>> getDonationSummary(
    List<int> expenditureItemIds,
  ) async {
    return dio.get(
      '$paymentUrl/donations/summary',
      queryParameters: <String, dynamic>{
        'expenditureItemIds': expenditureItemIds.join(','),
      },
    );
  }

  /// Lấy danh sách donors của một expenditure item.
  Future<Response<dynamic>> getDonorsByItem(int itemId) async {
    return dio.get('$paymentUrl/expenditure-item/$itemId/donors');
  }

  /// Lấy tiến độ gây quỹ của campaign.
  Future<Response<dynamic>> getCampaignProgress(int campaignId) async {
    return dio.get('$paymentUrl/campaign/$campaignId/progress');
  }

  /// Lấy donors gần đây của campaign.
  Future<Response<dynamic>> getRecentDonors(
    int campaignId, {
    int limit = 3,
  }) async {
    return dio.get(
      '$paymentUrl/campaign/$campaignId/recent-donations',
      queryParameters: <String, dynamic>{'limit': limit},
    );
  }

  /// Lấy lịch sử donation của user hiện tại.
  Future<Response<dynamic>> getMyDonations({int limit = 50}) async {
    return dio.get(
      '$paymentUrl/my-donations',
      queryParameters: <String, dynamic>{'limit': limit},
    );
  }

  /// Kiểm tra giới hạn mua hàng mục chi tiêu.
  Future<Response<dynamic>> checkExpenditureItemLimit(
    int expenditureItemId,
    int quantity,
  ) async {
    return dio.get(
      '$paymentUrl/expenditure-item/$expenditureItemId/check',
      queryParameters: <String, dynamic>{'quantity': quantity},
    );
  }

  /// Lấy thông tin donation theo ID.
  Future<Response<dynamic>> getDonation(int donationId) async {
    return dio.get('$paymentUrl/donation/$donationId');
  }

  /// Hủy donation.
  Future<Response<dynamic>> cancelDonation(int donationId) async {
    return dio.post('$paymentUrl/donation/$donationId/cancel');
  }
}
