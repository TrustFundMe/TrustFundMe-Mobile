import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/feed_post_media_model.dart';

/// Compact preview for feed cards (horizontal gallery + file rows).
class FeedPostAttachmentsPreview extends StatelessWidget {
  const FeedPostAttachmentsPreview({
    super.key,
    required this.media,
    this.imageHeight = 160,
    this.borderRadius = 16,
  });

  final List<FeedPostMediaItem> media;
  final double imageHeight;
  final double borderRadius;

  static const Color _muted = Color(0xFF6B7280);

  List<FeedPostMediaItem> get _images =>
      media.where((FeedPostMediaItem m) => m.isPhoto || m.isVideo).toList();

  List<FeedPostMediaItem> get _files =>
      media.where((FeedPostMediaItem m) => m.isFile && !m.isPhoto && !m.isVideo).toList();

  Future<void> _openUrl(BuildContext context, String url) async {
    final Uri? uri = Uri.tryParse(url);
    if (uri == null) return;
    final bool ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không mở được liên kết.')),
      );
    }
  }

  void _openImageViewer(
    BuildContext context, {
    required List<FeedPostMediaItem> images,
    required int initialIndex,
  }) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (BuildContext dialogContext) {
        final PageController pageController = PageController(initialPage: initialIndex);
        int currentIndex = initialIndex;
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(
                backgroundColor: Colors.black,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                title: Text(
                  '${currentIndex + 1}/${images.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                centerTitle: true,
              ),
              body: PageView.builder(
                controller: pageController,
                itemCount: images.length,
                onPageChanged: (int index) {
                  setModalState(() => currentIndex = index);
                },
                itemBuilder: (_, int index) {
                  return InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: Center(
                      child: Image.network(
                        images[index].url,
                        fit: BoxFit.contain,
                        loadingBuilder: (_, Widget child, ImageChunkEvent? progress) {
                          if (progress == null) return child;
                          return const Center(
                            child: CircularProgressIndicator(color: Colors.white),
                          );
                        },
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white70,
                            size: 42,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (media.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (_images.isNotEmpty)
          SizedBox(
            height: imageHeight,
            child: PageView.builder(
              itemCount: _images.length,
              controller: PageController(
                viewportFraction: _images.length > 1 ? 0.92 : 1.0,
              ),
              itemBuilder: (BuildContext c, int i) {
                final FeedPostMediaItem m = _images[i];
                return Padding(
                  padding: EdgeInsets.only(right: i < _images.length - 1 ? 8 : 0),
                  child: GestureDetector(
                    onTap: () {
                      if (m.isVideo) {
                        _openUrl(context, m.url);
                        return;
                      }
                      _openImageViewer(
                        context,
                        images: _images.where((FeedPostMediaItem item) => !item.isVideo).toList(),
                        initialIndex: _images
                            .where((FeedPostMediaItem item) => !item.isVideo)
                            .toList()
                            .indexWhere((FeedPostMediaItem item) => item.url == m.url),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(borderRadius),
                      child: Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          Image.network(
                            m.url,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: const Color(0xFFE5E7EB),
                              alignment: Alignment.center,
                              child: const Icon(Icons.broken_image_outlined, color: _muted),
                            ),
                          ),
                          if (m.isVideo)
                            const Center(
                              child: Icon(Icons.play_circle_fill, size: 48, color: Colors.white70),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        if (_files.isNotEmpty) ...<Widget>[
          if (_images.isNotEmpty) const SizedBox(height: 10),
          ..._files.map((FeedPostMediaItem m) {
            final String label = (m.fileName?.trim().isNotEmpty == true)
                ? m.fileName!.trim()
                : 'Tệp đính kèm';
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Material(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _openUrl(context, m.url),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: <Widget>[
                        const Icon(Icons.insert_drive_file_outlined, color: _muted, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                label,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              if ((m.mimeType ?? '').isNotEmpty)
                                Text(
                                  m.mimeType!,
                                  style: const TextStyle(fontSize: 11, color: _muted),
                                ),
                            ],
                          ),
                        ),
                        const Icon(Icons.open_in_new, size: 18, color: _muted),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ],
    );
  }
}
