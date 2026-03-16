import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../api/api_service.dart';
import '../models/user_model.dart';
import '../models/bank_account_model.dart';

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
      } else {
        _error = "Đăng nhập thất bại. Vui lòng kiểm tra lại thông tin.";
      }
    } catch (e) {
      _error = "Có lỗi xảy ra: ${e.toString()}";
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> updateProfile(String fullName, String? phoneNumber) async {
    if (_user == null) return false;
    
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.updateProfile(_user!.id, {
        'fullName': fullName,
        'phoneNumber': phoneNumber,
      });

      if (response.statusCode == 200) {
        _user = UserModel.fromJson(response.data);
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _error = "Cập nhật thất bại: ${e.toString()}";
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
      _error = "Cập nhật ảnh đại diện thất bại: ${e.toString()}";
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
      print("Error fetching bank account: $e");
    }
  }

  Future<bool> saveBankAccount(String bankCode, String accountNumber, String accountHolderName) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      Response response;
      Map<String, dynamic> data = {
        'bankCode': bankCode,
        'accountNumber': accountNumber,
        'accountHolderName': accountHolderName,
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
      _error = "Lỗi lưu tài khoản ngân hàng: ${e.toString()}";
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
}
