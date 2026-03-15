class ApiConfig {
  // Đối với Android Emulator, dùng 10.0.2.2 thay cho localhost
  // Đối với iOS Simulator hoặc thiết bị thật, dùng IP của máy tính
  static const String baseUrl = "http://10.0.2.2"; 

  // Các cổng Service tương ứng với Backend hiện tại của bạn
  static const String identityServicePort = "8081";
  static const String campaignServicePort = "8082";
  static const String fundraisingServicePort = "8083";
  static const String chatServicePort = "8086";

  // Endpoints chi tiết
  static String get identityUrl => "$baseUrl:$identityServicePort/api";
  static String get campaignUrl => "$baseUrl:$campaignServicePort/api";
  
  // Auth endpoints
  static String get loginEndpoint => "/auth/login";
  static String get registerEndpoint => "/auth/register";
  static String get profileEndpoint => "/users/profile";
}
