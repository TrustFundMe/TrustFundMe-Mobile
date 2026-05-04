import 'dart:io';
import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import 'base_service.dart';

/// Service xử lý user profile, bank accounts, avatar upload.
class UserService extends BaseService {
  /// Cập nhật profile người dùng.
  Future<Response<dynamic>> updateProfile(
    int userId,
    Map<String, dynamic> data,
  ) async {
    return dio.put(
      '$identityUrl${ApiConfig.userEndpoint}/$userId',
      data: data,
    );
  }

  /// Lấy thông tin user theo ID.
  Future<Response<dynamic>> getUserById(int userId) async {
    return dio.get('$identityUrl/users/$userId');
  }

  /// Upload avatar lên Supabase Storage và trả về public URL.
  Future<String> uploadToSupabase(String filePath, int userId) async {
    final File file = File(filePath);
    final List<int> bytes = await file.readAsBytes();
    final String ext = filePath.split('.').last;
    final String fileName =
        '${DateTime.now().millisecondsSinceEpoch}.$ext';

    final String path = 'avatars/$userId/$fileName';
    final String uploadUrl =
        '${ApiConfig.supabaseUrl}/storage/v1/object/${ApiConfig.supabaseBucket}/$path';

    String contentType = 'image/jpeg';
    if (ext.toLowerCase() == 'png') contentType = 'image/png';
    if (ext.toLowerCase() == 'gif') contentType = 'image/gif';
    if (ext.toLowerCase() == 'webp') contentType = 'image/webp';

    await dio.put(
      uploadUrl,
      data: bytes,
      options: Options(
        headers: <String, String>{
          'Authorization': 'Bearer ${ApiConfig.supabaseKey}',
          'Content-Type': contentType,
          'x-upsert': 'true',
        },
      ),
    );

    return '${ApiConfig.supabaseUrl}/storage/v1/object/public/${ApiConfig.supabaseBucket}/$path';
  }

  // ─── Bank Account ─────────────────────────────────────────────────────────

  /// Lấy danh sách tài khoản ngân hàng của user hiện tại.
  Future<Response<dynamic>> getMyBankAccounts() async {
    return dio.get(
      '$identityUrl${ApiConfig.bankAccountEndpoint}',
    );
  }

  /// Tạo tài khoản ngân hàng mới.
  Future<Response<dynamic>> createBankAccount(
    Map<String, dynamic> data,
  ) async {
    return dio.post(
      '$identityUrl${ApiConfig.bankAccountEndpoint}',
      data: data,
    );
  }

  /// Cập nhật tài khoản ngân hàng.
  Future<Response<dynamic>> updateBankAccount(
    int id,
    Map<String, dynamic> data,
  ) async {
    return dio.put(
      '$identityUrl${ApiConfig.bankAccountEndpoint}/$id',
      data: data,
    );
  }
}
