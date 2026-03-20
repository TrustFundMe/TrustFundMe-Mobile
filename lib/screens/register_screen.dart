import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/providers/auth_provider.dart';
import '../core/utils/password_rules.dart';
import 'email_verification_screen.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  static const Color webPrimary = Color(0xFFF84D43);
  static const Color webButtonBlack = Color(0xFF000000);
  static const Color webBgGray = Color(0xFFF9FAFB);
  static const Color webBorderGray = Color(0xFFD1D5DB);
  static const Color webTextGray = Color(0xFF4B5563);

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? _validate() {
    final String name = _fullNameController.text.trim();
    final String email = _emailController.text.trim();
    final String pass = _passwordController.text;
    final String confirm = _confirmController.text;
    if (name.isEmpty) return 'Vui lòng nhập họ và tên.';
    if (email.isEmpty) return 'Vui lòng nhập email.';
    if (!email.contains('@')) return 'Email không hợp lệ.';
    final String? pwdRule = passwordStrengthErrorMessage(pass);
    if (pwdRule != null) return pwdRule;
    if (pass != confirm) return 'Mật khẩu xác nhận không khớp.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: webBgGray,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: webBgGray,
        foregroundColor: Colors.black87,
        title: const Text(
          'Đăng ký',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text(
                'Tạo tài khoản TrustFundMe',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Điền thông tin bên dưới. Sau đăng ký bạn xác minh email bằng OTP (giống web).',
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
                    _field(
                      controller: _fullNameController,
                      hint: 'Họ và tên',
                      obscure: false,
                    ),
                    const SizedBox(height: 12),
                    _field(
                      controller: _emailController,
                      hint: 'Email',
                      obscure: false,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    _field(
                      controller: _phoneController,
                      hint: 'Số điện thoại (tuỳ chọn)',
                      obscure: false,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    _field(
                      controller: _passwordController,
                      hint: 'Mật khẩu',
                      obscure: _obscurePassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          size: 20,
                          color: webTextGray,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _field(
                      controller: _confirmController,
                      hint: 'Xác nhận mật khẩu',
                      obscure: _obscureConfirm,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                          size: 20,
                          color: webTextGray,
                        ),
                        onPressed: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (auth.error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SizedBox(
                          width: double.infinity,
                          child: Text(
                            auth.error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red, fontSize: 13),
                          ),
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: auth.isLoading
                            ? null
                            : () async {
                                final String? err = _validate();
                                if (err != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(err)),
                                  );
                                  return;
                                }
                                final bool ok = await auth.register(
                                  email: _emailController.text.trim(),
                                  password: _passwordController.text,
                                  fullName: _fullNameController.text.trim(),
                                  phoneNumber: _phoneController.text.trim().isEmpty
                                      ? null
                                      : _phoneController.text.trim(),
                                );
                                if (!context.mounted) return;
                                if (ok) {
                                  // Giống danbox: đăng ký BE xong (đã có JWT) → màn xác minh email (OTP + verify-email).
                                  Navigator.of(context).pushAndRemoveUntil(
                                    MaterialPageRoute<void>(
                                      builder: (_) => EmailVerificationScreen(
                                        email: _emailController.text.trim(),
                                      ),
                                    ),
                                    (Route<dynamic> r) => false,
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: webButtonBlack,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: auth.isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Đăng ký',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        const Text(
                          'Đã có tài khoản? ',
                          style: TextStyle(color: webTextGray, fontSize: 14),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute<void>(
                                builder: (_) => const LoginScreen(),
                              ),
                            );
                          },
                          child: const Text(
                            'Đăng nhập',
                            style: TextStyle(
                              color: webPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
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

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required bool obscure,
    Widget? suffixIcon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 15, color: Colors.black),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 15),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        suffixIcon: suffixIcon,
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
          borderSide: const BorderSide(color: Color(0xFF111827), width: 1.5),
        ),
      ),
    );
  }
}
