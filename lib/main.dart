import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/providers/auth_provider.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: const TrustFundMeApp(),
    ),
  );
}

class TrustFundMeApp extends StatelessWidget {
  const TrustFundMeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TrustFundMe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue.shade900),
        useMaterial3: true,
        fontFamily: 'Roboto', // Đảm bảo bạn có font hoặc dùng mặc định
      ),
      home: const LoginScreen(),
    );
  }
}
