import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trustfundme_mobile/core/providers/auth_provider.dart';
import 'package:trustfundme_mobile/screens/login_screen.dart';
import 'package:trustfundme_mobile/screens/main_screen.dart';
import 'package:trustfundme_mobile/widgets/trustfund_preloader.dart';

/// Shows danbox-style preloader, then:
/// - nếu có saved token hợp lệ → auto-login → [MainScreen]
/// - nếu không → [LoginScreen]
class AppBootstrapScreen extends StatefulWidget {
  const AppBootstrapScreen({super.key});

  @override
  State<AppBootstrapScreen> createState() => _AppBootstrapScreenState();
}

class _AppBootstrapScreenState extends State<AppBootstrapScreen> {
  bool _preloaderDone = false;
  bool _autoLoginChecked = false;
  bool _autoLoginSuccess = false;

  @override
  void initState() {
    super.initState();
    _checkAutoLogin();
  }

  Future<void> _checkAutoLogin() async {
    final auth = context.read<AuthProvider>();
    final bool success = await auth.tryAutoLogin();
    if (mounted) {
      setState(() {
        _autoLoginChecked = true;
        _autoLoginSuccess = success;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Cả preloader và auto-login check đã xong → navigate
    if (_preloaderDone && _autoLoginChecked) {
      if (_autoLoginSuccess) {
        return const MainScreen();
      }
      return const LoginScreen();
    }

    // Vẫn đang hiển thị preloader
    return TrustFundPreloader(
      minDisplayMs: 1000,
      fadeMs: 550,
      onFinished: () {
        if (mounted) {
          setState(() => _preloaderDone = true);
        }
      },
    );
  }
}
