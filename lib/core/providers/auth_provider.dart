import 'package:flutter/material.dart';
import '../api/api_service.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  String? _error;
  bool _isLoggedIn = false;

  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _isLoggedIn;

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.login(username, password);
      if (response.statusCode == 200) {
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

  void logout() {
    _isLoggedIn = false;
    notifyListeners();
  }
}
