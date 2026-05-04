import 'package:dio/dio.dart';
import 'base_service.dart';

/// Service xử lý expenditures (chi tiêu) của campaigns.
class ExpenditureService extends BaseService {
  /// Tạo expenditure mới.
  Future<Response<dynamic>> createExpenditure(
    Map<String, dynamic> data,
  ) async {
    return dio.post('$campaignUrl/expenditures', data: data);
  }

  /// Lấy expenditures theo campaign.
  Future<Response<dynamic>> getExpendituresByCampaign(
    int campaignId,
  ) async {
    return dio.get('$campaignUrl/expenditures/campaign/$campaignId');
  }

  /// Lấy expenditure theo ID.
  Future<Response<dynamic>> getExpenditureById(int expenditureId) async {
    return dio.get('$campaignUrl/expenditures/$expenditureId');
  }

  /// Lấy expenditure items theo campaign.
  Future<Response<dynamic>> getExpenditureItemsByCampaign(
    int campaignId,
  ) async {
    return dio.get('$campaignUrl/expenditures/campaign/$campaignId/items');
  }

  /// Lấy items của một expenditure.
  Future<Response<dynamic>> getExpenditureItems(int expenditureId) async {
    return dio.get('$campaignUrl/expenditures/$expenditureId/items');
  }

  /// Lấy approved items theo campaign.
  Future<Response<dynamic>> getApprovedExpenditureItemsByCampaign(
    int campaignId,
  ) async {
    return dio.get(
      '$campaignUrl/expenditures/campaign/$campaignId/items/approved',
    );
  }

  /// Yêu cầu rút tiền cho expenditure.
  Future<Response<dynamic>> requestWithdrawal(int expenditureId) async {
    return dio.post(
      '$campaignUrl/expenditures/$expenditureId/request-withdrawal',
    );
  }

  /// Cập nhật trạng thái evidence.
  Future<Response<dynamic>> updateEvidenceStatus(
    int expenditureId,
    String status,
  ) async {
    return dio.patch(
      '$campaignUrl/expenditures/$expenditureId/evidence-status?status=$status',
    );
  }

  /// Upload evidence (qua media service).
  Future<Response<dynamic>> uploadEvidence(
    String filePath, {
    required int expenditureId,
  }) async {
    final formData = FormData.fromMap(<String, dynamic>{
      'file': await MultipartFile.fromFile(filePath),
      'expenditureId': expenditureId,
      'mediaType': 'EVIDENCE',
    });

    return dio.post(
      '$mediaUrl/media/upload',
      data: formData,
      options: Options(
        headers: <String, String>{
          'Content-Type': 'multipart/form-data',
        },
      ),
    );
  }

  /// Tải template Excel cho import.
  Future<Response<dynamic>> downloadTemplate() async {
    return dio.get(
      '$campaignUrl/expenditures/import/template',
      options: Options(responseType: ResponseType.bytes),
    );
  }

  /// Import expenditures từ file Excel.
  Future<Response<dynamic>> importExcel(String filePath) async {
    final formData = FormData.fromMap(<String, dynamic>{
      'file': await MultipartFile.fromFile(filePath),
    });

    return dio.post(
      '$campaignUrl/expenditures/import-bulk',
      data: formData,
      options: Options(
        headers: <String, String>{
          'Content-Type': 'multipart/form-data',
        },
      ),
    );
  }
}
