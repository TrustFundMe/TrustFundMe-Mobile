/// Khớp danbox `sign-in/page.tsx` — `validatePassword` + `isPasswordValid`.
/// BE chỉ bắt tối thiểu 6 ký tự; FE web chặt hơn, mobile dùng cùng rule với web.
class PasswordValidation {
  const PasswordValidation({
    required this.minLength,
    required this.hasUppercase,
    required this.hasLowercase,
    required this.hasNumber,
    required this.hasSymbol,
  });

  final bool minLength;
  final bool hasUppercase;
  final bool hasLowercase;
  final bool hasNumber;
  final bool hasSymbol;

  bool get isAllValid =>
      minLength &&
      hasUppercase &&
      hasLowercase &&
      hasNumber &&
      hasSymbol;
}

PasswordValidation validatePasswordStrength(String password) {
  return PasswordValidation(
    minLength: password.length >= 12,
    hasUppercase: RegExp(r'[A-Z]').hasMatch(password),
    hasLowercase: RegExp(r'[a-z]').hasMatch(password),
    hasNumber: RegExp(r'[0-9]').hasMatch(password),
    hasSymbol: RegExp(r'[!@#$%^&*()_+\-=\[\]{}|;:,.<>?]').hasMatch(password),
  );
}

/// Thông báo ngắn gọn khi chưa đạt (dùng cho SnackBar / lỗi form).
String? passwordStrengthErrorMessage(String password) {
  final PasswordValidation v = validatePasswordStrength(password);
  if (v.isAllValid) return null;
  final List<String> missing = <String>[];
  if (!v.minLength) missing.add('ít nhất 12 ký tự');
  if (!v.hasUppercase) missing.add('chữ hoa');
  if (!v.hasLowercase) missing.add('chữ thường');
  if (!v.hasNumber) missing.add('số');
  if (!v.hasSymbol) missing.add('ký tự đặc biệt');
  return 'Mật khẩu cần: ${missing.join(', ')}.';
}
