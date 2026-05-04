import 'package:flutter/material.dart';
import '../../../core/models/new_campaign_state.dart';

/// Step 4: Điều khoản — hiển thị các điều khoản và yêu cầu đồng ý.
class Step4Terms extends StatefulWidget {
  final NewCampaignState campaignState;
  final ValueChanged<bool> onValidChanged;

  const Step4Terms({
    super.key,
    required this.campaignState,
    required this.onValidChanged,
  });

  @override
  State<Step4Terms> createState() => _Step4TermsState();
}

class _Step4TermsState extends State<Step4Terms>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  bool _hasScrolledToEnd = false;

  Acknowledgements get _ack => widget.campaignState.acknowledgements;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _validateAndNotify());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.offset;
      if (currentScroll >= maxScroll - 50) {
        if (!_hasScrolledToEnd) {
          setState(() => _hasScrolledToEnd = true);
        }
      }
    }
  }

  void _validateAndNotify() {
    final allChecked = _ack.allAccepted;
    widget.onValidChanged(_hasScrolledToEnd && allChecked);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    return Column(
      children: [
        // ── Header ────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Điều khoản & Cam kết',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Vui lòng đọc kỹ và đồng ý với các điều khoản bên dưới.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Nội dung điều khoản (scrollable) ──────────────────────
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey.shade50,
            ),
            child: Stack(
              children: [
                Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  child: ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildTermSection(
                        '1. Điều khoản sử dụng nền tảng TrustFundMe',
                        'Bằng việc tạo chiến dịch gây quỹ trên nền tảng TrustFundMe, bạn đồng ý tuân thủ '
                            'đầy đủ các điều khoản sử dụng. Nền tảng hoạt động như một trung gian kết nối '
                            'giữa người gây quỹ và nhà tài trợ, đảm bảo tính minh bạch và an toàn cho các '
                            'giao dịch.\n\n'
                            'Bạn cam kết:\n'
                            '• Cung cấp thông tin chính xác, trung thực về bản thân và chiến dịch\n'
                            '• Sử dụng số tiền gây quỹ đúng mục đích đã đăng ký\n'
                            '• Tuân thủ các quy định pháp luật hiện hành về gây quỹ cộng đồng\n'
                            '• Không sử dụng nền tảng cho mục đích bất hợp pháp, lừa đảo\n'
                            '• Hợp tác với nền tảng trong quá trình xác minh, kiểm toán',
                      ),
                      const Divider(height: 32),
                      _buildTermSection(
                        '2. Chính sách xử lý dư quỹ (Overfund Policy)',
                        'Trong trường hợp chiến dịch gây quỹ vượt mức mục tiêu đề ra:\n\n'
                            '• Phần dư quỹ sẽ được giữ lại trên nền tảng và chuyển vào quỹ dự phòng\n'
                            '• Bạn có thể sử dụng quỹ dự phòng cho các hoạt động liên quan đến mục đích '
                            'ban đầu của chiến dịch, sau khi được phê duyệt\n'
                            '• Nhà tài trợ sẽ được thông báo về việc dư quỹ và cách xử lý\n'
                            '• Nền tảng có quyền yêu cầu hoàn trả nếu phát hiện vi phạm\n\n'
                            'Các trường hợp đặc biệt sẽ được xem xét riêng bởi ban quản trị nền tảng.',
                      ),
                      const Divider(height: 32),
                      _buildTermSection(
                        '3. Cam kết minh bạch tài chính',
                        'Bạn cam kết đảm bảo minh bạch trong toàn bộ quá trình sử dụng quỹ:\n\n'
                            '• Cung cấp đầy đủ hóa đơn, chứng từ cho mỗi khoản chi\n'
                            '• Đăng tải báo cáo chi tiêu theo từng đợt giải ngân\n'
                            '• Chụp ảnh, quay video minh chứng cho các hoạt động triển khai\n'
                            '• Phản hồi kịp thời các câu hỏi từ nhà tài trợ và nền tảng\n'
                            '• Chấp nhận kiểm toán đột xuất bởi nền tảng hoặc bên thứ ba\n\n'
                            'Vi phạm cam kết minh bạch có thể dẫn đến:\n'
                            '• Tạm dừng giải ngân các đợt tiếp theo\n'
                            '• Yêu cầu hoàn trả số tiền đã giải ngân\n'
                            '• Khóa tài khoản và cấm tạo chiến dịch mới\n'
                            '• Xử lý pháp lý nếu có dấu hiệu gian lận',
                      ),
                      const Divider(height: 32),
                      _buildTermSection(
                        '4. Trách nhiệm pháp lý',
                        'Bạn chịu hoàn toàn trách nhiệm pháp lý đối với:\n\n'
                            '• Tính chính xác của thông tin chiến dịch và hồ sơ KYC\n'
                            '• Việc sử dụng đúng mục đích số tiền được giải ngân\n'
                            '• Các hoạt động triển khai chiến dịch\n'
                            '• Thiệt hại phát sinh do thông tin sai lệch hoặc gian lận\n\n'
                            'TrustFundMe không chịu trách nhiệm đối với:\n'
                            '• Kết quả cuối cùng của chiến dịch (thành công hay thất bại)\n'
                            '• Tranh chấp giữa người gây quỹ và bên thụ hưởng\n'
                            '• Thiệt hại do bất khả kháng\n\n'
                            'Trong trường hợp xảy ra tranh chấp, hai bên sẽ giải quyết thông qua thương '
                            'lượng trước, sau đó có thể đưa ra cơ quan có thẩm quyền nếu cần thiết.',
                      ),
                      const SizedBox(height: 20),

                      if (!_hasScrolledToEnd) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.arrow_downward,
                                  color: Colors.amber.shade700, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Vui lòng cuộn xuống để đọc hết điều khoản',
                                  style: TextStyle(
                                    color: Colors.amber.shade800,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Scroll indicator overlay
                if (!_hasScrolledToEnd)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.grey.shade50.withOpacity(0),
                            Colors.grey.shade50,
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ── Checkboxes ────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              _buildCheckbox(
                value: _ack.termsAccepted,
                label: 'Tôi đã đọc và đồng ý với điều khoản sử dụng',
                enabled: _hasScrolledToEnd,
                onChanged: (v) {
                  setState(() => _ack.termsAccepted = v ?? false);
                  _validateAndNotify();
                },
              ),
              _buildCheckbox(
                value: _ack.overfundPolicyAccepted,
                label: 'Tôi đồng ý với chính sách xử lý dư quỹ',
                enabled: _hasScrolledToEnd,
                onChanged: (v) {
                  setState(() => _ack.overfundPolicyAccepted = v ?? false);
                  _validateAndNotify();
                },
              ),
              _buildCheckbox(
                value: _ack.transparencyAccepted,
                label: 'Tôi cam kết minh bạch tài chính',
                enabled: _hasScrolledToEnd,
                onChanged: (v) {
                  setState(() => _ack.transparencyAccepted = v ?? false);
                  _validateAndNotify();
                },
              ),
              _buildCheckbox(
                value: _ack.legalLiabilityAccepted,
                label: 'Tôi chịu trách nhiệm pháp lý về chiến dịch',
                enabled: _hasScrolledToEnd,
                onChanged: (v) {
                  setState(() => _ack.legalLiabilityAccepted = v ?? false);
                  _validateAndNotify();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildTermSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade800,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildCheckbox({
    required bool value,
    required String label,
    required bool enabled,
    required ValueChanged<bool?> onChanged,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: CheckboxListTile(
        value: value,
        onChanged: enabled ? onChanged : null,
        title: Text(
          label,
          style: const TextStyle(fontSize: 14),
        ),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: EdgeInsets.zero,
        dense: true,
        activeColor: Colors.green.shade600,
      ),
    );
  }
}
