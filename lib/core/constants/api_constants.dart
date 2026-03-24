import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  static String get baseUrl =>
      dotenv.get('API_BASE_URL', fallback: 'http://10.0.2.2');

  static String get identityServicePort =>
      dotenv.get('IDENTITY_PORT', fallback: '8081');
  static String get campaignServicePort =>
      dotenv.get('CAMPAIGN_PORT', fallback: '8082');
  static String get mediaServicePort =>
      dotenv.get('MEDIA_PORT', fallback: '8083');
  static String get chatbotServicePort =>
      dotenv.get('CHATBOT_PORT', fallback: '8086');
  static String get aiServicePort =>
      dotenv.get('AI_PORT', fallback: '8089');
  static String get paymentServicePort =>
      dotenv.get('PAYMENT_PORT', fallback: '8087');

  static String get identityUrl => '$baseUrl:$identityServicePort/api';
  static String get campaignUrl => '$baseUrl:$campaignServicePort/api';
  static String get mediaUrl => '$baseUrl:$mediaServicePort/api';
  static String get aiUrl => '$baseUrl:$aiServicePort/api';
  static String get paymentUrl => '$baseUrl:$paymentServicePort/api/payments';
  static String get chatUrl => '$baseUrl:$chatbotServicePort/api';
  static String get chatWsUrl {
    final String wsBase = baseUrl.replaceFirst('http', 'ws');
    return '$wsBase:$chatbotServicePort/ws/websocket';
  }

  // Supabase
  static String get supabaseUrl => dotenv.get('SUPABASE_URL');
  static String get supabaseKey =>
      dotenv.get('SUPABASE_SERVICE_ROLE_KEY');
  static String get supabaseBucket =>
      dotenv.get('SUPABASE_BUCKET', fallback: 'Avatars');

  static String get loginEndpoint => '/auth/login';
  static String get registerEndpoint => '/auth/register';
  static String get sendOtpEndpoint => '/auth/send-otp';
  static String get verifyOtpEndpoint => '/auth/verify-otp';
  static String get resetPasswordEndpoint => '/auth/reset-password';
  static String get verifyEmailEndpoint => '/auth/verify-email';
  static String get userEndpoint => '/users';
  static String get bankAccountEndpoint => '/bank-accounts';
  static String get googleLoginEndpoint => '/auth/google-login';
}
