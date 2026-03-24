import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../api/api_service.dart';
import '../models/user_model.dart';
import '../models/bank_account_model.dart';
import '../utils/error_handler.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
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
        _user = UserModel.fromJson(response.data['user']);
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

  Future<bool> loginWithGoogle(String idToken) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.loginWithGoogle(idToken);
      if (response.statusCode == 200) {
        _user = UserModel.fromJson(response.data['user']);
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

  void logout() {
    _isLoggedIn = false;
    _user = null;
    _bankAccount = null;
    notifyListeners();
  }

  /// Sau [verify-email] trên BE (luồng xác minh OTP đăng ký).
  void applyEmailVerified() {
    if (_user == null) return;
    _user = UserModel(
      id: _user!.id,
      email: _user!.email,
      fullName: _user!.fullName,
      phoneNumber: _user!.phoneNumber,
      avatarUrl: _user!.avatarUrl,
      role: _user!.role,
      verified: true,
      isActive: _user!.isActive,
    );
    notifyListeners();
  }
}
