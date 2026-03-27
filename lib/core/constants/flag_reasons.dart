/// Aligned with web `CampaignActions.tsx` (REPORT_REASONS) and
/// `FlagPostModal.tsx` (FLAG_REASONS).

const List<String> kCampaignFlagReasons = <String>[
  'Nội dung gian lận / lừa đảo',
  'Chiến dịch không hoạt động hoặc bị bỏ rơi',
  'Thông tin sai lệch về mục tiêu',
  'Vi phạm điều khoản sử dụng',
  'Nội dung phản cảm hoặc không phù hợp',
  'Khác',
];

const String kCampaignFlagOtherLabel = 'Khác';

const List<String> kFeedPostFlagReasons = <String>[
  'Nội dung sai sự thật hoặc lừa đảo',
  'Nội dung xúc phạm, thù ghét hoặc bạo lực',
  'Spam hoặc nội dung quảng cáo không phù hợp',
  'Vi phạm quyền riêng tư',
  'Lạm dụng hoặc quấy rối',
  'Nội dung khiêu dâm hoặc không phù hợp',
  'Lý do khác',
];

const String kFeedPostFlagOtherLabel = 'Lý do khác';

const int kFlagCustomReasonMaxLength = 500;
