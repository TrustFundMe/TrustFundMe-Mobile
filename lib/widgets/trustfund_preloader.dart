import 'dart:async';
import 'package:flutter/material.dart';

/// Preloader inspired by danbox `Preloader.tsx`: spinner + staggered TRUSTFUNDME letters + fade out.
class TrustFundPreloader extends StatefulWidget {
  const TrustFundPreloader({
    super.key,
    required this.onFinished,
    this.minDisplayMs = 900,
    this.fadeMs = 600,
  });

  final VoidCallback onFinished;
  final int minDisplayMs;
  final int fadeMs;

  @override
  State<TrustFundPreloader> createState() => _TrustFundPreloaderState();
}

class _TrustFundPreloaderState extends State<TrustFundPreloader> {
  static const Color _bg = Color(0xFFF9FAFB);
  static const Color _accent = Color(0xFFF84D43);
  static const Color _text = Color(0xFF1F2937);

  bool _fadeOut = false;

  @override
  void initState() {
    super.initState();
    unawaited(_runSequence());
  }

  Future<void> _runSequence() async {
    await Future<void>.delayed(Duration(milliseconds: widget.minDisplayMs));
    if (!mounted) return;
    setState(() => _fadeOut = true);
    await Future<void>.delayed(Duration(milliseconds: widget.fadeMs));
    if (!mounted) return;
    widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    const letters = <String>[
      'T', 'R', 'U', 'S', 'T', 'F', 'U', 'N', 'D', 'M', 'E',
    ];

    return AnimatedOpacity(
      opacity: _fadeOut ? 0 : 1,
      duration: Duration(milliseconds: widget.fadeMs),
      curve: Curves.easeInOut,
      child: ColoredBox(
        color: _bg,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: _accent,
                  backgroundColor: _accent.withOpacity(0.12),
                ),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List<Widget>.generate(letters.length, (int i) {
                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: Duration(milliseconds: 400 + i * 80),
                    curve: Curves.easeOutCubic,
                    builder: (context, double t, Widget? child) {
                      return Opacity(
                        opacity: t,
                        child: Transform.translate(
                          offset: Offset(0, 8 * (1 - t)),
                          child: child,
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1.5),
                      child: Text(
                        letters[i],
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: _text,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              Text(
                'Đang tải',
                style: TextStyle(
                  fontSize: 13,
                  color: _text.withOpacity(0.55),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
