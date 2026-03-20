import 'package:flutter/material.dart';
import 'package:trustfundme_mobile/screens/login_screen.dart';
import 'package:trustfundme_mobile/widgets/trustfund_preloader.dart';

/// Shows danbox-style preloader once, then fades to [LoginScreen].
class AppBootstrapScreen extends StatefulWidget {
  const AppBootstrapScreen({super.key});

  @override
  State<AppBootstrapScreen> createState() => _AppBootstrapScreenState();
}

class _AppBootstrapScreenState extends State<AppBootstrapScreen> {
  bool _showLogin = false;

  @override
  Widget build(BuildContext context) {
    if (_showLogin) {
      return const LoginScreen();
    }
    return TrustFundPreloader(
      minDisplayMs: 1000,
      fadeMs: 550,
      onFinished: () {
        if (mounted) setState(() => _showLogin = true);
      },
    );
  }
}
