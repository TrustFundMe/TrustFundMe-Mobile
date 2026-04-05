import 'package:flutter/material.dart';

/// Pill filter giống màn Feed cộng đồng.
class FeedFilterPill extends StatelessWidget {
  const FeedFilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.selectedBg,
    required this.selectedFg,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color selectedBg;
  final Color selectedFg;
  final VoidCallback onTap;

  static const Color _border = Color(0xFFE5E7EB);
  static const Color _muted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? selectedBg : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? Colors.transparent : _border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: selected ? selectedFg : _muted,
            ),
          ),
        ),
      ),
    );
  }
}
