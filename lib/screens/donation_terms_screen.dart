import 'package:flutter/material.dart';

class DonationTermsScreen extends StatelessWidget {
  const DonationTermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color textDark = Color(0xFF1F2937);
    const Color textGray = Color(0xFF6B7280);
    const Color borderGray = Color(0xFFE5E7EB);
    const Color primary = Color(0xFFF84D43);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text(
          'Điều khoản quyên góp',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: textDark,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderGray),
            ),
            child: const Text(
              '1) Khoản quyên góp là tự nguyện.\n\n'
              '2) Nền tảng chỉ thu hộ và chuyển tiền theo thông tin chiến dịch đã công bố.\n\n'
              '3) Trường hợp thanh toán thành công nhưng trạng thái chưa cập nhật, hệ thống sẽ đồng bộ lại sau khi xác minh cổng thanh toán.\n\n'
              '4) Với quyên góp theo hạng mục, số lượng sẽ được kiểm tra giới hạn trước khi tạo giao dịch.\n\n'
              '5) Người dùng chịu trách nhiệm kiểm tra kỹ số tiền/tip trước khi xác nhận thanh toán.',
              style: TextStyle(
                color: textDark,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Nếu bạn đồng ý, quay lại màn hình trước và tích chọn xác nhận điều khoản.',
            style: TextStyle(
              color: textGray,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Đã hiểu, quay lại quyên góp',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
