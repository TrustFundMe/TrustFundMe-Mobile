import 'dart:async';

import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Fires [onDwell] once after the child stays sufficiently visible for [dwell].
class FeedDwellTracker extends StatefulWidget {
  const FeedDwellTracker({
    super.key,
    required this.visibilityKey,
    required this.child,
    required this.onDwell,
    this.dwell = const Duration(seconds: 3),
    this.visibleFractionThreshold = 0.45,
  });

  final Key visibilityKey;
  final Widget child;
  final VoidCallback onDwell;
  final Duration dwell;
  final double visibleFractionThreshold;

  @override
  State<FeedDwellTracker> createState() => _FeedDwellTrackerState();
}

class _FeedDwellTrackerState extends State<FeedDwellTracker> {
  Timer? _timer;
  bool _completed = false;

  void _handleVisibility(VisibilityInfo info) {
    if (!mounted || _completed) return;
    if (info.visibleFraction >= widget.visibleFractionThreshold) {
      _timer ??= Timer(widget.dwell, () {
        if (!mounted || _completed) return;
        _completed = true;
        widget.onDwell();
      });
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: widget.visibilityKey,
      onVisibilityChanged: _handleVisibility,
      child: widget.child,
    );
  }
}
