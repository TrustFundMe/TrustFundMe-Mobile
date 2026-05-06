import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../api/api_service.dart';
import '../api/auth_service.dart';
import '../models/user_model.dart';
import '../models/bank_account_model.dart';
import '../utils/error_handler.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String? _error;
  bool _isLoggedIn = false;
  UserModel? _user;
  BankAccountModel? _bankAccount;

  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _isLoggedIn;
  UserModel? get user => _user;
  BankAccountModel? get bankAccount => _bankAccount;

  Future<String?> get token => const FlutterSecureStorage().read(key: 'jwt_token');

  Future<bool> register({
    required String email,
    required String password,
    required String fullName,
    String? phoneNumber,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final Response<dynamic> response = await _apiService.register(
        email: email,
        password: password,
        fullName: fullName,
        phoneNumber: phoneNumber,
      );
      if (response.statusCode == 201) {
        final dynamic userRaw = response.data['user'];
        if (userRaw is Map<String, dynamic>) {
          _user = UserModel.fromJson(userRaw);
          // Persist user data để auto-login lần sau
          await _authService.saveUserData(userRaw);
        }
        _isLoggedIn = true;
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _error = ErrorHandler.handle(e);
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.login(username, password);
      if (response.statusCode == 200) {
        final Map<String, dynamic> userJson =
            response.data['user'] as Map<String, dynamic>;
        _user = UserModel.fromJson(userJson);
        _isLoggedIn = true;
        _isLoading = false;
        // Persist user data vào secure storage để auto-login lần sau
        await _authService.saveUserData(userJson);
        notifyListeners();
        return true;
      }
    } catch (e) {
      _error = ErrorHandler.handle(e);
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> loginWithGoogle(String idToken) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.loginWithGoogle(idToken);
      if (response.statusCode == 200) {
        final Map<String, dynamic> userJson =
            response.data['user'] as Map<String, dynamic>;
        _user = UserModel.fromJson(userJson);
        _isLoggedIn = true;
        _isLoading = false;
        // Persist user data
        await _authService.saveUserData(userJson);
        notifyListeners();
        return true;
      }
    } catch (e) {
      _error = ErrorHandler.handle(e);
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> updateProfile(String fullName, String? phoneNumber) async {
    if (_user == null) return false;
    final String safeFullName = fullName.trim();
    final String? safePhone = (phoneNumber == null || phoneNumber.trim().isEmpty)
        ? null
        : phoneNumber.trim();
    
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.updateProfile(_user!.id, {
        'fullName': safeFullName,
        'phoneNumber': safePhone,
      });

      if (response.statusCode == 200) {
        _user = UserModel.fromJson(response.data);
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _error = ErrorHandler.handle(e);
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> updateAvatar(String filePath) async {
    if (_user == null) return false;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 1. Upload ảnh trực tiếp lên Supabase Storage (Giống FE)
      final avatarUrl = await _apiService.uploadToSupabase(filePath, _user!.id);

      // 2. Cập nhật avatarUrl vào Profile thông qua Identity Service
      final updateResponse = await _apiService.updateProfile(_user!.id, {
        'avatarUrl': avatarUrl,
      });

      if (updateResponse.statusCode == 200) {
        _user = UserModel.fromJson(updateResponse.data);
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _error = ErrorHandler.handle(e);
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> fetchBankAccount() async {
    try {
      final response = await _apiService.getMyBankAccounts();
      if (response.statusCode == 200 && response.data is List && response.data.isNotEmpty) {
        _bankAccount = BankAccountModel.fromJson(response.data[0]);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error fetching bank account: $e");
    }
  }

  Future<bool> saveBankAccount(String bankCode, String accountNumber, String accountHolderName) async {
    final String safeBankCode = bankCode.trim();
    final String safeAccountNumber = accountNumber.trim();
    final String safeAccountHolderName = accountHolderName.trim();

    if (safeBankCode.isEmpty || safeAccountNumber.isEmpty || safeAccountHolderName.isEmpty) {
      _error = "Vui lòng nhập đầy đủ thông tin ngân hàng.";
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      Response response;
      Map<String, dynamic> data = {
        'bankCode': safeBankCode,
        'accountNumber': safeAccountNumber,
        'accountHolderName': safeAccountHolderName,
      };

      if (_bankAccount != null) {
        response = await _apiService.updateBankAccount(_bankAccount!.id, data);
      } else {
        response = await _apiService.createBankAccount(data);
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        _bankAccount = BankAccountModel.fromJson(response.data);
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _error = ErrorHandler.handle(e);
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// Đăng xuất: clear state + xóa token & user data khỏi secure storage.
  Future<void> logout() async {
    _isLoggedIn = false;
    _user = null;
    _bankAccount = null;
    await _authService.logout(); // xóa jwt_token + user_data
    notifyListeners();
  }

  // ─── Auto-login khi mở app ───────────────────────────────────────────────

  /// Kiểm tra token trong secure storage, nếu có → verify với server
  /// và tự động khôi phục session.
  ///
  /// Trả về `true` nếu auto-login thành công, `false` nếu cần login lại.
  Future<bool> tryAutoLogin() async {
    final String? savedToken = await _authService.getToken();
    if (savedToken == null || savedToken.isEmpty) {
      return false;
    }

    // Đọc cached user data để lấy userId
    final Map<String, dynamic>? cachedUser = await _authService.readUserData();
    if (cachedUser == null || cachedUser['id'] == null) {
      // Có token nhưng không có user data → xóa token, yêu cầu login lại
      await _authService.logout();
      return false;
    }

    final dynamic rawId = cachedUser['id'];
    final int userId = rawId is int
        ? rawId
        : (rawId is num ? rawId.toInt() : int.tryParse('$rawId') ?? 0);

    if (userId == 0) {
      await _authService.logout();
      return false;
    }

    // Verify token bằng cách gọi API lấy user mới nhất
    final Map<String, dynamic>? freshUser =
        await _authService.verifyTokenAndGetUser(userId);

    if (freshUser != null) {
      // Token hợp lệ → khôi phục session
      _user = UserModel.fromJson(freshUser);
      _isLoggedIn = true;
      // Cập nhật cached user data với data mới nhất
      await _authService.saveUserData(freshUser);
      notifyListeners();
      return true;
    }

    // Token hết hạn hoặc không hợp lệ → clear và yêu cầu login lại
    await _authService.logout();
    return false;
  }

  /// Sau [verify-email] trên BE (luồng xác minh OTP đăng ký).
  void applyEmailVerified() {
    if (_user == null) return;
    _user = _user!.copyWith(verified: true);
    notifyListeners();
  }

  /// Sau khi KYC submit/approve → cập nhật local state.
  void applyKycStatus(String status) {
    if (_user == null) return;
    _user = _user!.copyWith(
      kycStatus: status,
      kycVerified: status == 'APPROVED',
    );
    notifyListeners();
  }
}
