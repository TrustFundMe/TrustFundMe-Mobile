import 'package:flutter/material.dart';

import '../../core/constants/flag_reasons.dart';

/// Bottom sheet: preset reasons + optional detail when [otherLabel] is selected.
/// Returns trimmed final reason, or null if dismissed.
Future<String?> showFlagReasonBottomSheet(
  BuildContext context, {
  required String title,
  required String subtitle,
  required List<String> reasons,
  required String otherLabel,
  String customHint = 'Mô tả chi tiết...',
  Color accentColor = const Color(0xFFEF4444),
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext ctx) {
      return _FlagReasonSheetBody(
        title: title,
        subtitle: subtitle,
        reasons: reasons,
        otherLabel: otherLabel,
        customHint: customHint,
        accentColor: accentColor,
      );
    },
  );
}

Future<String?> showCampaignFlagReasonBottomSheet(BuildContext context) {
  return showFlagReasonBottomSheet(
    context,
    title: 'Tố cáo chiến dịch',
    subtitle: 'Báo cáo sẽ được gửi đến đội kiểm duyệt',
    reasons: kCampaignFlagReasons,
    otherLabel: kCampaignFlagOtherLabel,
    customHint: 'Mô tả chi tiết lý do tố cáo...',
    accentColor: const Color(0xFFEF4444),
  );
}

Future<String?> showFeedPostFlagReasonBottomSheet(BuildContext context) {
  return showFlagReasonBottomSheet(
    context,
    title: 'Báo cáo bài viết',
    subtitle: 'Báo cáo sẽ được gửi đến đội ngũ kiểm duyệt',
    reasons: kFeedPostFlagReasons,
    otherLabel: kFeedPostFlagOtherLabel,
    customHint: 'Mô tả chi tiết...',
    accentColor: const Color(0xFFEF4444),
  );
}

class _FlagReasonSheetBody extends StatefulWidget {
  const _FlagReasonSheetBody({
    required this.title,
    required this.subtitle,
    required this.reasons,
    required this.otherLabel,
    required this.customHint,
    required this.accentColor,
  });

  final String title;
  final String subtitle;
  final List<String> reasons;
  final String otherLabel;
  final String customHint;
  final Color accentColor;

  @override
  State<_FlagReasonSheetBody> createState() => _FlagReasonSheetBodyState();
}

class _FlagReasonSheetBodyState extends State<_FlagReasonSheetBody> {
  String _selected = '';
  final TextEditingController _custom = TextEditingController();

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  String get _finalReason {
    if (_selected.isEmpty) return '';
    if (_selected == widget.otherLabel) {
      return _custom.text.trim();
    }
    return _selected;
  }

  bool get _canSubmit => _finalReason.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mq = MediaQuery.of(context);
    final double bottomInset = mq.viewPadding.bottom;
    const Color zinc50 = Color(0xFFFAFAFA);
    const Color zinc200 = Color(0xFFE5E7EB);
    const Color zinc500 = Color(0xFF6B7280);
    const Color zinc700 = Color(0xFF374151);
    const Color zinc900 = Color(0xFF111827);

    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: mq.size.height * 0.92,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: zinc200),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: zinc900.withValues(alpha: 0.08),
                blurRadius: 32,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: zinc200,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: widget.accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.flag_outlined, color: widget.accentColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            widget.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: zinc900,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: zinc500.withValues(alpha: 0.95),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Material(
                      color: zinc50,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        borderRadius: BorderRadius.circular(10),
                        child: const SizedBox(
                          width: 36,
                          height: 36,
                          child: Icon(Icons.close, size: 20, color: zinc700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: zinc200),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const Text(
                        'Chọn lý do:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: zinc700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...widget.reasons.map((String r) {
                        final bool isOn = _selected == r;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Material(
                            color: isOn
                                ? widget.accentColor.withValues(alpha: 0.06)
                                : zinc50,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _selected = r;
                                  if (r != widget.otherLabel) {
                                    _custom.clear();
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    width: 2,
                                    color: isOn
                                        ? widget.accentColor.withValues(alpha: 0.65)
                                        : zinc200,
                                  ),
                                ),
                                child: Row(
                                  children: <Widget>[
                                    Icon(
                                      isOn
                                          ? Icons.radio_button_checked
                                          : Icons.radio_button_off,
                                      size: 22,
                                      color: isOn ? widget.accentColor : zinc500,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        r,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: isOn ? FontWeight.w700 : FontWeight.w500,
                                          color: isOn
                                              ? widget.accentColor.withValues(alpha: 0.95)
                                              : zinc700,
                                          height: 1.35,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                      if (_selected == widget.otherLabel) ...<Widget>[
                        const SizedBox(height: 4),
                        TextField(
                          controller: _custom,
                          maxLines: 3,
                          maxLength: kFlagCustomReasonMaxLength,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: widget.customHint,
                            filled: true,
                            fillColor: zinc50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: zinc200, width: 2),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: zinc200, width: 2),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: widget.accentColor, width: 2),
                            ),
                            counterStyle: const TextStyle(fontSize: 11, color: zinc500),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + bottomInset),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: zinc200, width: 2),
                          foregroundColor: zinc700,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Hủy',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: !_canSubmit
                            ? null
                            : () => Navigator.of(context).pop(_finalReason),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: widget.accentColor,
                          disabledBackgroundColor: zinc200,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Gửi tố cáo',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
