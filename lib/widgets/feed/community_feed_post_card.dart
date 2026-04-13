import 'package:flutter/material.dart';

import '../../core/api/api_service.dart';
import '../../core/models/feed_post_media_model.dart';
import '../../core/models/feed_post_model.dart';
import 'feed_post_attachments.dart';
import 'feed_post_target_nav.dart';

/// Card bài viết — cùng layout với feed cộng đồng (có thể thêm badge trạng thái cho màn “bài của tôi”).
class CommunityFeedPostCard extends StatelessWidget {
  const CommunityFeedPostCard({
    super.key,
    required this.api,
    required this.post,
    required this.media,
    required this.timeLabel,
    required this.textPreview,
    this.categoryLabel,
    this.categoryColor,
    this.showHotBadge = false,
    this.statusBadgeText,
    this.currentUserId,
    required this.onOpen,
    this.onLike,
    required this.onComment,
    this.onFlag,
    this.onEdit,
    this.onDelete,
    this.isFollowerLocked = false,
    this.onFollowCampaign,
  });

  final ApiService api;
  final FeedPostModel post;
  final List<FeedPostMediaItem> media;
  final String timeLabel;
  final String textPreview;
  final String? categoryLabel;
  final Color? categoryColor;
  final bool showHotBadge;
  /// Ví dụ: "Bản nháp" khi `post.status == DRAFT` trên màn bài của tôi.
  final String? statusBadgeText;
  final int? currentUserId;
  final VoidCallback onOpen;
  final VoidCallback? onLike;
  final VoidCallback onComment;
  final VoidCallback? onFlag;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool isFollowerLocked;
  final VoidCallback? onFollowCampaign;

  static const Color _primary = Color(0xFFF84D43);
  static const Color _text = Color(0xFF111827);
  static const Color _muted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    final Widget inner = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 8, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                CircleAvatar(
                  radius: 19,
                  backgroundColor: const Color(0xFFF3F4F6),
                  backgroundImage: post.authorAvatar != null &&
                          post.authorAvatar!.isNotEmpty
                      ? NetworkImage(post.authorAvatar!)
                      : null,
                  child: post.authorAvatar == null ||
                          post.authorAvatar!.isEmpty
                      ? Text(
                          post.authorName.isNotEmpty
                              ? post.authorName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: _muted,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              post.authorName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: _text,
                              ),
                            ),
                          ),
                          if (statusBadgeText != null &&
                              statusBadgeText!.trim().isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFFBEB),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: const Color(0xFFFDE68A),
                                ),
                              ),
                              child: Text(
                                statusBadgeText!.trim(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFB45309),
                                ),
                              ),
                            ),
                          if (post.visibility.toUpperCase() == 'FOLLOWERS')
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: const Color(0xFFC7D2FE),
                                ),
                              ),
                              child: const Text(
                                'Chỉ follower',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF4338CA),
                                ),
                              ),
                            ),
                          if (post.isPinned)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF7ED),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                'Ghim',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFC2410C),
                                ),
                              ),
                            ),
                          if (showHotBadge)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF7ED),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Icon(
                                    Icons.local_fire_department,
                                    size: 14,
                                    color: Color(0xFFC2410C),
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Hot',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFFC2410C),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        timeLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          color: _muted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (categoryLabel != null &&
                          categoryLabel!.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: (categoryColor ?? _muted)
                                  .withOpacity(0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              categoryLabel!.trim(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: categoryColor ?? _muted,
                              ),
                            ),
                          ),
                        ),
                      FeedPostTargetPill(api: api, post: post),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz, color: _muted),
                  onSelected: (String value) {
                    if (value == 'flag') {
                      onFlag?.call();
                    } else if (value == 'edit') {
                      onEdit?.call();
                    } else if (value == 'delete') {
                      onDelete?.call();
                    }
                  },
                  itemBuilder: (BuildContext c) {
                    final bool isOwner = currentUserId != null &&
                        currentUserId == post.authorId;
                    return <PopupMenuEntry<String>>[
                      if (isOwner) ...<PopupMenuEntry<String>>[
                        const PopupMenuItem<String>(
                          value: 'edit',
                          child: Text('Chỉnh sửa'),
                        ),
                        const PopupMenuItem<String>(
                          value: 'delete',
                          child: Text('Xóa'),
                        ),
                      ],
                      if (onFlag != null)
                        const PopupMenuItem<String>(
                          value: 'flag',
                          child: Text('Báo cáo bài viết'),
                        ),
                    ];
                  },
                ),
              ],
            ),
          ),
          if ((post.title ?? '').trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
              child: Text(
                post.title!.trim(),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: _text,
                ),
              ),
            ),
          if (textPreview.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Text(
                isFollowerLocked ? '${textPreview.split(' ').take(20).join(' ')} ...' : textPreview,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: _text,
                ),
              ),
            ),
          if (isFollowerLocked)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  children: <Widget>[
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Nội dung dành cho người theo dõi campaign.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF374151),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Theo dõi để mở khóa toàn bộ bài viết.',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: onFollowCampaign,
                      style: FilledButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      child: const Text(
                        'Theo dõi',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (media.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: FeedPostAttachmentsPreview(
                media: media,
                imageHeight: 160,
                borderRadius: 16,
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.remove_red_eye_outlined,
                  size: 16,
                  color: _muted,
                ),
                const SizedBox(width: 4),
                Text(
                  '${post.viewCount}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _muted,
                  ),
                ),
                const SizedBox(width: 14),
                if (post.isLocked)
                  const Icon(Icons.lock_outline, size: 16, color: _muted),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
            child: Row(
              children: <Widget>[
                IconButton(
                  onPressed: isFollowerLocked ? null : onLike,
                  icon: Icon(
                    post.isLiked ? Icons.favorite : Icons.favorite_border,
                    color: post.isLiked ? _primary : _text,
                  ),
                ),
                IconButton(
                  onPressed: isFollowerLocked ? null : onComment,
                  icon: const Icon(Icons.mode_comment_outlined, color: _text),
                ),
                const Spacer(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
            child: Text(
              '${post.likeCount} lượt thích',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: _text,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onComment,
              child: Text(
                'Xem ${post.commentCount} bình luận',
                style: const TextStyle(
                  color: _muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
    return InkWell(
      onTap: isFollowerLocked ? null : onOpen,
      borderRadius: BorderRadius.circular(20),
      child: inner,
    );
  }
}
