import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/chat_provider.dart';
import 'screens/app_bootstrap_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, ChatProvider>(
          create: (context) => ChatProvider(context.read<AuthProvider>()),
          update: (context, auth, previousChat) =>
              previousChat ?? ChatProvider(auth),
        ),
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
      home: const AppBootstrapScreen(),
    );
  }
}
