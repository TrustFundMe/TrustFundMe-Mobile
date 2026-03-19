import 'package:flutter/material.dart';

class IntroductionScreen extends StatelessWidget {
  const IntroductionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Giới thiệu", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(child: Icon(Icons.info, size: 80, color: Color(0xFFF84D43))),
            ),
            const SizedBox(height: 24),
            const Text(
              "Về TrustFundMe",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
            ),
            const SizedBox(height: 16),
            const Text(
              "Chúng tôi là nền tảng gây quỹ minh bạch, kết nối những tấm lòng hảo tâm với những dự án ý nghĩa. Sứ mệnh của chúng tôi là tạo ra sự thay đổi tích cực thông qua sức mạnh cộng đồng.",
              style: TextStyle(fontSize: 16, color: Color(0xFF4B5563), height: 1.6),
            ),
            // Sẽ bổ sung thêm các phần Counter và Value từ FE sau
          ],
        ),
      ),
    );
  }
}
