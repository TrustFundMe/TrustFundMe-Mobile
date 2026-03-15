import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/providers/auth_provider.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  // Màu sắc chính xác theo thiết kế Web (Tailwind Colors)
  static const Color webPrimary = Color(0xFFF84D43); // Coral-Red (--primary)
  static const Color webButtonBlack = Color(0xFF000000); // Pure black
  static const Color webBgGray = Color(0xFFF9FAFB); // bg-gray-50
  static const Color webBorderGray = Color(0xFFD1D5DB); // border-gray-300
  static const Color webTextGray = Color(0xFF4B5563); // text-gray-600

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: webBgGray,
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Container chứa toàn bộ Card Login (Phần Content trắng ở bản Web)
                Container(
                  constraints: const BoxConstraints(maxWidth: 450),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Logo
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Image.asset(
                          'assets/images/black-logo.png',
                          height: 64, // Tăng kích thước để dễ thấy hơn
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.image_not_supported, size: 48, color: Colors.grey);
                          },
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Subheading
                      const Text(
                        "Sign in to TrustFundMe or sign up to continue",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: webTextGray,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Google Login Button (Giả lập giống Web)
                      _buildSocialButton(
                        icon: Icons.g_mobiledata,
                        text: "Continue with Google",
                        onPressed: () {},
                      ),

                      const SizedBox(height: 24),

                      // Divider "or"
                      Row(
                        children: [
                          const Expanded(child: Divider(color: webBorderGray)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              "or",
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                            ),
                          ),
                          const Expanded(child: Divider(color: webBorderGray)),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Username Input
                      _buildTextField(
                        controller: _usernameController,
                        hint: "Email",
                        obscure: false,
                      ),
                      const SizedBox(height: 16),

                      // Password Input (Nếu logic của bạn đã tách step thì sẽ ẩn, ở đây tôi gộp vào)
                      _buildTextField(
                        controller: _passwordController,
                        hint: "Password",
                        obscure: _obscurePassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                            size: 20,
                            color: webTextGray,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Link Quên mật khẩu
                      Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: () {},
                          child: const Text(
                            "Forgot password?",
                            style: TextStyle(
                              color: webPrimary,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      if (authProvider.error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            authProvider.error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red, fontSize: 13),
                          ),
                        ),

                      // Nút Continue chính
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: authProvider.isLoading
                              ? null
                              : () async {
                                  final success = await authProvider.login(
                                    _usernameController.text,
                                    _passwordController.text,
                                  );
                                  if (success && mounted) {
                                    Navigator.of(context).pushReplacement(
                                      MaterialPageRoute(builder: (context) => const HomeScreen()),
                                    );
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: webButtonBlack,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          child: authProvider.isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text(
                                  "Continue",
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Sign up Link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "Don't have an account? ",
                            style: TextStyle(color: webTextGray, fontSize: 14),
                          ),
                          GestureDetector(
                            onTap: () {},
                            child: const Text(
                              "Sign up",
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

                const SizedBox(height: 32),
                // Footer text như Web
                const Text(
                  "This site is protected by reCAPTCHA and the Google Privacy Policy and Terms of Service apply.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required bool obscure,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
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
          borderSide: const BorderSide(color: webPrimary, width: 2),
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String text,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
        side: const BorderSide(color: webBorderGray),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.black, size: 28),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w400),
          ),
        ],
      ),
    );
  }
}
