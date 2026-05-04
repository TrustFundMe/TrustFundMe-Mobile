import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/chat_provider.dart';
import 'screens/app_bootstrap_screen.dart';
import 'screens/campaign/new_campaign_screen.dart';
import 'screens/kyc/kyc_screen.dart';
import 'screens/notifications/notification_screen.dart';
import 'screens/account/account_screen.dart';
import 'screens/account/donation_history_screen.dart';
import 'screens/account/bank_accounts_screen.dart';
import 'screens/account/change_password_screen.dart';
import 'screens/my_campaigns_screen.dart';
import 'screens/feed/community_feed_screen.dart';

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
      routes: {
        '/kyc': (context) => const KycScreen(),
        '/notifications': (context) => const NotificationScreen(),
        '/new-campaign': (context) => const NewCampaignScreen(),
        '/account': (context) => const AccountScreen(),
        '/my-campaigns': (context) => const MyCampaignsScreen(),
        '/donation-history': (context) => const DonationHistoryScreen(),
        '/bank-accounts': (context) => const BankAccountsScreen(),
        '/change-password': (context) => const ChangePasswordScreen(),
        '/community-feed': (context) => const CommunityFeedScreen(),
      },
    );
  }
}
