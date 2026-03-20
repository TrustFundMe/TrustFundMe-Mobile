import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/api/api_service.dart';
import '../core/providers/auth_provider.dart';
import '../core/utils/error_handler.dart';
import 'main_screen.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({
    super.key,
    required this.email,
    this.replaceAppOnSuccess = true,
  });

  final String email;

  /// `true` (mặc định): sau xác minh → [MainScreen], xóa stack (luồng đăng ký).
  /// `false`: chỉ [Navigator.pop] (mở từ Hồ sơ — giữ tab & stack).
  final bool replaceAppOnSuccess;

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final TextEditingController _otpController = TextEditingController();
  final ApiService _api = ApiService();
  bool _loading = false;
  bool _resending = false;
  bool _initialSendTried = false;
  String? _error;
  String? _info;

  static const Color webPrimary = Color(0xFFF84D43);
  static const Color webBgGray = Color(0xFFF9FAFB);
  static const Color webBorderGray = Color(0xFFD1D5DB);
  static const Color webTextGray = Color(0xFF6B7280);
  static const Color webButtonBlack = Color(0xFF000000);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_initialSendTried) return;
      _initialSendTried = true;
      _sendOtp(showSnackOnOk: false);
    });
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp({bool showSnackOnOk = true}) async {
    setState(() {
      _resending = true;
      _error = null;
    });
    try {
      final Response<dynamic> res =
          await _api.sendPasswordResetOtp(widget.email);
      if (!mounted) return;
      if (res.statusCode == 200) {
        setState(() {
          _info = 'Mã OTP đã được gửi đến email của bạn.';
          _resending = false;
        });
        if (showSnackOnOk) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã gửi lại mã OTP.')),
          );
        }
        Future<void>.delayed(const Duration(seconds: 5), () {
          if (mounted) setState(() => _info = null);
        });
        return;
      }
      setState(() {
        _resending = false;
        _error = 'Gửi OTP thất bại.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _resending = false;
        _error = ErrorHandler.handle(e);
      });
    }
  }

  Future<void> _verify() async {
    final String otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() => _error = 'Mã OTP phải gồm 6 chữ số.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final Response<dynamic> verifyRes = await _api.verifyPasswordResetOtp(
        email: widget.email,
        otp: otp,
      );
      if (!mounted) return;
      if (verifyRes.statusCode != 200) {
        setState(() {
          _loading = false;
          _error = 'Xác thực OTP thất bại.';
        });
        return;
      }
      final dynamic data = verifyRes.data;
      String? token;
      if (data is Map<String, dynamic>) {
        token = data['token'] as String?;
      }
      if (token == null || token.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'Không nhận được token xác minh từ máy chủ.';
        });
        return;
      }

      final Response<dynamic> emailRes =
          await _api.verifyEmailWithToken(token);
      if (!mounted) return;
      if (emailRes.statusCode != 200) {
        setState(() {
          _loading = false;
          _error = 'Xác minh email thất bại.';
        });
        return;
      }

      final AuthProvider auth = Provider.of<AuthProvider>(context, listen: false);
      auth.applyEmailVerified();

      if (!mounted) return;
      if (widget.replaceAppOnSuccess) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const MainScreen()),
          (Route<dynamic> r) => false,
        );
      } else {
        Navigator.of(context).pop(true);
      }
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
          'Xác minh email',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Text(
                      'Kiểm tra hộp thư',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text.rich(
                      TextSpan(
                        style: const TextStyle(
                          fontSize: 15,
                          color: webTextGray,
                          height: 1.45,
                        ),
                        children: <InlineSpan>[
                          const TextSpan(text: 'Chúng tôi đã gửi mã 6 số tới\n'),
                          TextSpan(
                            text: widget.email,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const TextSpan(text: '.'),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
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
                          if (_info != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                _info!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFF059669),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          TextField(
                            controller: _otpController,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 8,
                            ),
                            inputFormatters: <TextInputFormatter>[
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: InputDecoration(
                              counterText: '',
                              hintText: '••••••',
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
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.red, fontSize: 13),
                            ),
                          ],
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _verify,
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
                                      'Xác minh',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                          TextButton(
                            onPressed: _resending
                                ? null
                                : () => _sendOtp(showSnackOnOk: true),
                            child: _resending
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text(
                                    'Gửi lại mã OTP',
                                    style: TextStyle(
                                      color: webPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                          TextButton(
                            onPressed: _loading
                                ? null
                                : () {
                                    if (widget.replaceAppOnSuccess) {
                                      Navigator.of(context).pushAndRemoveUntil(
                                        MaterialPageRoute<void>(
                                          builder: (_) => const MainScreen(),
                                        ),
                                        (Route<dynamic> r) => false,
                                      );
                                    } else {
                                      Navigator.of(context).pop(false);
                                    }
                                  },
                            child: Text(
                              widget.replaceAppOnSuccess
                                  ? 'Để sau, vào app'
                                  : 'Để sau',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
