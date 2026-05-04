import 'package:flutter/material.dart';
import '../../core/api/auth_service.dart';
import '../../core/utils/password_rules.dart';

/// Màn hình "Đổi mật khẩu" — validate theo password_rules.dart.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  final _currentPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _isSubmitting = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  static const Color _primary = Color(0xFFF84D43);
  static const Color _emerald = Color(0xFF1A685B);
  static const Color _textDark = Color(0xFF1F2937);
  static const Color _textGray = Color(0xFF4B5563);
  static const Color _bgGray = Color(0xFFF9FAFB);
  static const Color _border = Color(0xFFE5E7EB);

  @override
  void dispose() {
    _currentPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final errorMsg =
        passwordStrengthErrorMessage(_newPasswordCtrl.text.trim());
    if (errorMsg != null) {
      _snack(errorMsg, isError: true);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final response = await _authService.changePassword(
        currentPassword: _currentPasswordCtrl.text,
        newPassword: _newPasswordCtrl.text.trim(),
      );
      if (response.statusCode == 200) {
        if (!mounted) return;
        _snack('Đổi mật khẩu thành công!');
        _currentPasswordCtrl.clear();
        _newPasswordCtrl.clear();
        _confirmPasswordCtrl.clear();
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) Navigator.pop(context);
      } else {
        _snack('Đổi mật khẩu thất bại.', isError: true);
      }
    } catch (e) {
      String msg = 'Đổi mật khẩu thất bại.';
      // Extract server error message if available
      final dynamic err = e;
      if (err is dynamic &&
          err.response != null &&
          err.response?.data is Map) {
        msg = err.response?.data['message'] ?? msg;
      }
      _snack(msg, isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : _emerald,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgGray,
      appBar: AppBar(
        title: const Text('Đổi mật khẩu',
            style: TextStyle(fontWeight: FontWeight.bold, color: _textDark)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 20, color: _textDark),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _emerald.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 20, color: _emerald),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Mật khẩu cần ít nhất 12 ký tự, bao gồm chữ hoa, chữ thường, số và ký tự đặc biệt.',
                        style: TextStyle(fontSize: 12, color: _textGray),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Current password
              _buildPasswordField(
                controller: _currentPasswordCtrl,
                label: 'Mật khẩu hiện tại',
                obscure: _obscureCurrent,
                onToggle: () =>
                    setState(() => _obscureCurrent = !_obscureCurrent),
                validator: (v) => (v == null || v.isEmpty)
                    ? 'Vui lòng nhập mật khẩu hiện tại'
                    : null,
              ),
              const SizedBox(height: 16),

              // New password
              _buildPasswordField(
                controller: _newPasswordCtrl,
                label: 'Mật khẩu mới',
                obscure: _obscureNew,
                onToggle: () =>
                    setState(() => _obscureNew = !_obscureNew),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Vui lòng nhập mật khẩu mới';
                  final err = passwordStrengthErrorMessage(v);
                  return err;
                },
                onChanged: (_) => setState(() {}), // rebuild strength indicator
              ),
              const SizedBox(height: 8),

              // Strength indicator
              _buildStrengthIndicator(_newPasswordCtrl.text),

              const SizedBox(height: 16),

              // Confirm password
              _buildPasswordField(
                controller: _confirmPasswordCtrl,
                label: 'Xác nhận mật khẩu mới',
                obscure: _obscureConfirm,
                onToggle: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Vui lòng xác nhận mật khẩu';
                  if (v != _newPasswordCtrl.text) return 'Mật khẩu không khớp';
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // Submit
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 2,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Đổi mật khẩu',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _border),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: _textGray,
            size: 20,
          ),
          onPressed: onToggle,
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildStrengthIndicator(String password) {
    if (password.isEmpty) return const SizedBox.shrink();

    final v = validatePasswordStrength(password);
    final rules = <MapEntry<String, bool>>[
      MapEntry('≥ 12 ký tự', v.minLength),
      MapEntry('Chữ hoa', v.hasUppercase),
      MapEntry('Chữ thường', v.hasLowercase),
      MapEntry('Số', v.hasNumber),
      MapEntry('Ký tự đặc biệt', v.hasSymbol),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: rules.map((entry) {
        final ok = entry.value;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: ok
                ? _emerald.withOpacity(0.1)
                : Colors.red.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                ok ? Icons.check_circle : Icons.cancel,
                size: 14,
                color: ok ? _emerald : Colors.red,
              ),
              const SizedBox(width: 4),
              Text(entry.key,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: ok ? _emerald : Colors.red,
                  )),
            ],
          ),
        );
      }).toList(),
    );
  }
}
