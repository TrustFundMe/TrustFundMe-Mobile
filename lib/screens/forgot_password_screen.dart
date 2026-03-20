import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../core/api/api_service.dart';
import '../core/utils/error_handler.dart';
import 'otp_verification_screen.dart';

/// Bước 1 quên mật khẩu: nhập email → gửi OTP (giống luồng danbox / BE `/api/auth/send-otp`).
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  final ApiService _api = ApiService();
  bool _loading = false;
  String? _error;

  static const Color webPrimary = Color(0xFFF84D43);
  static const Color webBgGray = Color(0xFFF9FAFB);
  static const Color webBorderGray = Color(0xFFD1D5DB);
  static const Color webTextGray = Color(0xFF4B5563);
  static const Color webButtonBlack = Color(0xFF000000);

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final String email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _error = 'Vui lòng nhập email hợp lệ.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final Response<dynamic> res = await _api.sendPasswordResetOtp(email);
      if (!mounted) return;
      if (res.statusCode == 200) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => OtpVerificationScreen(email: email),
          ),
        );
        return;
      }
      setState(() {
        _loading = false;
        _error = 'Không gửi được mã OTP.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ErrorHandler.handle(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: webBgGray,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: webBgGray,
        foregroundColor: Colors.black87,
        title: const Text(
          'Quên mật khẩu',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text(
                'Khôi phục mật khẩu',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Nhập email đã đăng ký. Chúng tôi sẽ gửi mã OTP 6 số tới email của bạn (giống trên web).',
                style: TextStyle(fontSize: 14, color: webTextGray, height: 1.35),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: webBorderGray),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(fontSize: 15),
                      decoration: InputDecoration(
                        hintText: 'Email',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: webBorderGray),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: webBorderGray),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFF111827),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    if (_error != null) ...<Widget>[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: webButtonBlack,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Gửi mã OTP',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text(
                        'Quay lại đăng nhập',
                        style: TextStyle(
                          color: webPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
