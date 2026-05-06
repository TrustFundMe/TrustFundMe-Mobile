import 'package:flutter/material.dart';

/// Sanitizes an avatar URL:
/// - If URL contains `ui-avatars.com`, appends `&format=png&size=128` to force
///   a PNG response (Flutter Android cannot decode SVG via [ImageDecoder]).
/// - Returns the original URL otherwise.
String sanitizeAvatarUrl(String url) {
  if (url.contains('ui-avatars.com')) {
    final uri = Uri.parse(url);
    final params = Map<String, String>.from(uri.queryParameters);
    params['format'] = 'png';
    params.putIfAbsent('size', () => '128');
    return uri.replace(queryParameters: params).toString();
  }
  return url;
}

/// A drop-in replacement for [CircleAvatar] that safely loads a network avatar.
///
/// Features:
/// - Automatically sanitizes `ui-avatars.com` URLs to force PNG format.
/// - Catches image-decode errors and falls back to an initials-based avatar,
///   preventing the red error screen on Android.
/// - Shows a coloured circle with the first letter of [name] when [imageUrl]
///   is null, empty, or fails to load.
class SafeNetworkAvatar extends StatefulWidget {
  const SafeNetworkAvatar({
    super.key,
    this.imageUrl,
    required this.name,
    this.radius = 20,
    this.backgroundColor,
    this.fallbackIcon,
    this.textStyle,
  });

  /// The network URL for the avatar image.  May be null or empty.
  final String? imageUrl;

  /// Display name used to derive the fallback initial letter.
  final String name;

  /// Radius of the [CircleAvatar].
  final double radius;

  /// Background colour of the fallback avatar.
  final Color? backgroundColor;

  /// Optional icon to show instead of the text initial when there is no URL.
  final Widget? fallbackIcon;

  /// Text style for the initial letter.
  final TextStyle? textStyle;

  @override
  State<SafeNetworkAvatar> createState() => _SafeNetworkAvatarState();
}

class _SafeNetworkAvatarState extends State<SafeNetworkAvatar> {
  bool _hasError = false;

  String get _initial {
    if (widget.name.isEmpty) return '?';
    return widget.name[0].toUpperCase();
  }

  String? get _safeUrl {
    final url = widget.imageUrl;
    if (url == null || url.isEmpty) return null;
    return sanitizeAvatarUrl(url);
  }

  @override
  void didUpdateWidget(covariant SafeNetworkAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _hasError = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = _safeUrl;
    final bool showFallback = url == null || _hasError;

    final bgColor =
        widget.backgroundColor ?? const Color(0xFFF3F4F6);

    if (showFallback) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundColor: bgColor,
        child: widget.fallbackIcon ??
            Text(
              _initial,
              style: widget.textStyle ??
                  TextStyle(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF6B7280),
                    fontSize: widget.radius * 0.9,
                  ),
            ),
      );
    }

    // Use foregroundImage + onForegroundImageError so that
    // decode failures are caught without throwing.
    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: bgColor,
      backgroundImage: NetworkImage(url!),
      onBackgroundImageError: (_, __) {
        if (mounted && !_hasError) {
          setState(() => _hasError = true);
        }
      },
      child: null,
    );
  }
}
