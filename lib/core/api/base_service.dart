import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/api_constants.dart';

/// Base class cho tất cả domain services.
///
/// Cung cấp [dio] instance chung với:
/// - Token interceptor (tự động gắn JWT header)
/// - Timeout config (60s connect, 60s receive)
/// - Shared [FlutterSecureStorage] để đọc/ghi token
///
/// Các domain service extends class này và dùng [dio] để gọi API.
abstract class BaseService {
  /// Dio instance chia sẻ giữa tất cả services.
  ///
  /// Được khởi tạo lazy singleton: mọi domain service đều dùng cùng
  /// một Dio instance (cùng interceptors, timeout, v.v.).
  static Dio? _sharedDio;

  /// Shared secure storage instance.
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  /// Getter cho Dio instance chung. Nếu chưa tạo sẽ khởi tạo.
  Dio get dio {
    _sharedDio ??= _createDio();
    return _sharedDio!;
  }

  /// Getter cho secure storage.
  FlutterSecureStorage get storage => _storage;

  /// Tạo và cấu hình Dio instance.
  static Dio _createDio() {
    final Dio dio = Dio();
    dio.options.connectTimeout = const Duration(seconds: 60);
    dio.options.receiveTimeout = const Duration(seconds: 60);

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (RequestOptions options, RequestInterceptorHandler handler) async {
          // Chỉ đính kèm JWT cho các service backend, bỏ qua Supabase.
          if (!options.path.contains('supabase.co')) {
            final String? token = await _storage.read(key: 'jwt_token');
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          return handler.next(options);
        },
        onError: (DioException e, ErrorInterceptorHandler handler) {
          return handler.next(e);
        },
      ),
    );

    return dio;
  }

  /// Reset shared Dio instance (dùng cho testing hoặc khi cần re-init).
  static void resetDio() {
    _sharedDio = null;
  }

  // ─── Convenience URL getters ────────────────────────────────────────────────

  String get identityUrl => ApiConfig.identityUrl;
  String get campaignUrl => ApiConfig.campaignUrl;
  String get mediaUrl => ApiConfig.mediaUrl;
  String get aiUrl => ApiConfig.aiUrl;
  String get paymentUrl => ApiConfig.paymentUrl;
  String get chatUrl => ApiConfig.chatUrl;
  String get appointmentUrl => ApiConfig.appointmentUrl;
  String get notificationUrl => ApiConfig.notificationUrl;
}
