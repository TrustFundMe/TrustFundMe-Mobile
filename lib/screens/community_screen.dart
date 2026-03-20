import 'package:flutter/material.dart';
import '../core/api/api_service.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  static const Color _primary = Color(0xFFF84D43);
  static const Color _bg = Color(0xFFF9FAFB);
  static const Color _text = Color(0xFF111827);
  static const Color _muted = Color(0xFF6B7280);

  final ApiService _apiService = ApiService();

  final List<_FeedPost> _posts = const <_FeedPost>[
    _FeedPost(
      id: 1,
      author: "Nguyễn Văn A",
      role: "Người gây quỹ",
      type: "UPDATE",
      timeAgo: "2 giờ trước",
      title: "Cập nhật về dự án xây trường học",
      caption:
          "Chúng tôi rất vui mừng thông báo rằng dự án xây trường học tại vùng cao đã hoàn thành 70%. Cảm ơn tất cả các nhà tài trợ đã đóng góp.",
      imageUrl:
          "https://placehold.co/1200x900?text=Cap+nhat+du+an+xay+truong&bg=FEE2E2&color=111827",
      likes: 124,
      comments: 12,
      campaignTitle: "Xây dựng trường học cho trẻ em vùng cao",
      campaignProgress: 0.70,
    ),
    _FeedPost(
      id: 2,
      author: "Trần Thị B",
      role: "Người gây quỹ",
      type: "ANNOUNCEMENT",
      timeAgo: "5 giờ trước",
      title: null,
      caption:
          "Hôm nay chúng tôi đã trao 500 phần quà cho các em nhỏ vùng cao. Nụ cười của các em là động lực lớn nhất của chúng tôi.",
      imageUrl:
          "https://placehold.co/1200x900?text=Trao+500+phan+qua&bg=E0F2FE&color=111827",
      likes: 256,
      comments: 19,
      campaignTitle: "Hỗ trợ quà Tết cho gia đình khó khăn",
      campaignProgress: 0.60,
    ),
    _FeedPost(
      id: 3,
      author: "Lê Văn C",
      role: "Nhà hảo tâm",
      type: "NEWS",
      timeAgo: "1 ngày trước",
      title: "Thông báo về chương trình từ thiện mới",
      caption:
          "Chúng tôi sẽ tổ chức chương trình từ thiện mới vào cuối tháng này. Mọi người hãy đóng góp để giúp đỡ những hoàn cảnh khó khăn.",
      imageUrl:
          "https://placehold.co/1200x900?text=Thong+bao+chuong+trinh+moi&bg=F3F4F6&color=111827",
      likes: 89,
      comments: 8,
    ),
    _FeedPost(
      id: 4,
      author: "Phạm Thị D",
      role: "Tình nguyện viên",
      type: "ANNOUNCEMENT",
      timeAgo: "3 ngày trước",
      title: "Kết quả chiến dịch gây quỹ",
      caption:
          "Chúng tôi đã gây quỹ được 500 triệu đồng trong tháng vừa qua. Cảm ơn tất cả các nhà hảo tâm đã đồng hành.",
      imageUrl:
          "https://placehold.co/1200x900?text=Ket+qua+gay+quy+thang&bg=E2E8F0&color=111827",
      likes: 445,
      comments: 26,
      campaignTitle: "Chương trình từ thiện cuối năm",
      campaignProgress: 0.62,
    ),
  ];

  int _selectedFilter = 0;
  late final List<bool> _likedStates = _posts.map((_) => false).toList();
  late final List<int> _commentCounts = _posts.map((post) => post.comments).toList();
  final Map<int, List<_CommentVm>> _commentsByPostId = <int, List<_CommentVm>>{};
  static const List<String> _filters = <String>[
    'Tất cả',
    'Update',
    'Thông báo',
    'Tin tức',
  ];

  List<int> get _visibleIndexes {
    if (_selectedFilter == 0) {
      return List<int>.generate(_posts.length, (int index) => index);
    }

    final String expectedType = switch (_selectedFilter) {
      1 => 'UPDATE',
      2 => 'ANNOUNCEMENT',
      3 => 'NEWS',
      _ => '',
    };

    return _posts
        .asMap()
        .entries
        .where((MapEntry<int, _FeedPost> entry) => entry.value.type == expectedType)
        .map((MapEntry<int, _FeedPost> entry) => entry.key)
        .toList();
  }

  Future<List<_CommentVm>> _fetchComments(int postId) async {
    final response = await _apiService.getFeedPostComments(postId, size: 30);
    final dynamic data = response.data;
    final List<dynamic> list = (data is Map<String, dynamic>)
        ? (data['content'] as List<dynamic>? ?? <dynamic>[])
        : (data is List<dynamic> ? data : <dynamic>[]);

    return list.map((dynamic item) {
      final Map<String, dynamic> json = item as Map<String, dynamic>;
      final String authorName = (json['authorName'] as String?)?.trim().isNotEmpty == true
          ? json['authorName'] as String
          : 'Thành viên';
      final String content = (json['content'] as String?) ?? '';
      return _CommentVm(text: '$authorName: $content');
    }).toList();
  }

  void _openCommentSheet(int postIndex) {
    final TextEditingController controller = TextEditingController();
    final int postId = _posts[postIndex].id;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            final List<_CommentVm> comments = _commentsByPostId[postId] ?? <_CommentVm>[];
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 14,
                bottom: MediaQuery.of(context).viewInsets.bottom + 14,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 46,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1D5DB),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Bình luận bài viết',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: _text,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<List<_CommentVm>>(
                    future: _commentsByPostId.containsKey(postId)
                        ? null
                        : _fetchComments(postId),
                    builder: (BuildContext context, AsyncSnapshot<List<_CommentVm>> snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          !_commentsByPostId.containsKey(postId)) {
                        return const SizedBox(
                          height: 220,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      if (snapshot.hasData && !_commentsByPostId.containsKey(postId)) {
                        _commentsByPostId[postId] = snapshot.data!;
                      }

                      final List<_CommentVm> merged = _commentsByPostId[postId] ?? comments;

                      if (merged.isEmpty) {
                        return const SizedBox(
                          height: 120,
                          child: Center(
                            child: Text(
                              'Chưa có bình luận nào',
                              style: TextStyle(color: _muted, fontSize: 13),
                            ),
                          ),
                        );
                      }

                      return SizedBox(
                        height: 220,
                        child: ListView.separated(
                          itemCount: merged.length,
                          itemBuilder: (_, int index) => Text(
                            merged[index].text,
                            style: const TextStyle(
                              color: _text,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: controller,
                          minLines: 1,
                          maxLines: 2,
                          decoration: InputDecoration(
                            hintText: 'Viết bình luận...',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          final String comment = controller.text.trim();
                          if (comment.isEmpty) return;
                          try {
                            await _apiService.createFeedPostComment(postId, comment);
                            final List<_CommentVm> latest = await _fetchComments(postId);
                            if (!mounted) return;
                            setState(() {
                              _commentsByPostId[postId] = latest;
                              _commentCounts[postIndex] = latest.length;
                            });
                            setSheetState(() {});
                            controller.clear();
                          } catch (_) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(content: Text('Gửi bình luận thất bại')),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(66, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Gửi',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(controller.dispose);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text(
          "Feed Cộng đồng",
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: _text,
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.edit_square),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Column(
              children: <Widget>[
                Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    children: <Widget>[
                      SizedBox(width: 12),
                      Icon(Icons.search, color: _muted, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Tìm bài viết, chiến dịch...',
                        style: TextStyle(
                          color: _muted,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (BuildContext context, int index) {
                      final bool isActive = _selectedFilter == index;
                      return InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () {
                          setState(() => _selectedFilter = index);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isActive ? _primary : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _filters[index],
                            style: TextStyle(
                              color: isActive ? Colors.white : _text,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    },
                    separatorBuilder: (BuildContext context, int index) =>
                        const SizedBox(width: 8),
                    itemCount: _filters.length,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              itemCount: _visibleIndexes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (BuildContext context, int listIndex) {
                final int postIndex = _visibleIndexes[listIndex];
                final _FeedPost post = _posts[postIndex];
                final bool isLiked = _likedStates[postIndex];
                final int likeCount = post.likes + (isLiked ? 1 : 0);

                return _PostCard(
                  post: post,
                  isLiked: isLiked,
                  likeCount: likeCount,
                  commentCount: _commentCounts[postIndex],
                  onLikeToggle: () {
                    setState(() => _likedStates[postIndex] = !isLiked);
                  },
                  onCommentTap: () => _openCommentSheet(postIndex),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedPost {
  const _FeedPost({
    required this.id,
    required this.author,
    required this.role,
    required this.type,
    required this.timeAgo,
    required this.title,
    required this.caption,
    required this.imageUrl,
    required this.likes,
    required this.comments,
    this.campaignTitle,
    this.campaignProgress,
  });

  final int id;
  final String author;
  final String role;
  final String type;
  final String timeAgo;
  final String? title;
  final String caption;
  final String imageUrl;
  final int likes;
  final int comments;
  final String? campaignTitle;
  final double? campaignProgress;
}

class _CommentVm {
  const _CommentVm({required this.text});

  final String text;
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.post,
    required this.isLiked,
    required this.likeCount,
    required this.commentCount,
    required this.onLikeToggle,
    required this.onCommentTap,
  });

  final _FeedPost post;
  final bool isLiked;
  final int likeCount;
  final int commentCount;
  final VoidCallback onLikeToggle;
  final VoidCallback onCommentTap;

  static const Color _primary = Color(0xFFF84D43);
  static const Color _text = Color(0xFF111827);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _card = Colors.white;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: <Widget>[
                const CircleAvatar(
                  radius: 19,
                  backgroundColor: Color(0xFFF3F4F6),
                  child: Icon(Icons.person_outline, color: _muted),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        post.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: _text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${post.role} • ${post.timeAgo}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: _muted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                _TypeBadge(type: post.type),
              ],
            ),
          ),
          if (post.title != null) ...<Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: Text(
                post.title!,
                style: const TextStyle(
                  color: _text,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Text(
              post.caption,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _text,
                fontSize: 14,
                height: 1.45,
              ),
            ),
          ),
          RepaintBoundary(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 170,
                  width: double.infinity,
                  child: Image.network(
                    post.imageUrl,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.low,
                    cacheWidth: 1024,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFFE5E7EB),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.image_not_supported_outlined,
                        color: Color(0xFF9CA3AF),
                        size: 30,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (post.campaignTitle != null && post.campaignProgress != null) ...<Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Text(
                post.campaignTitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _text,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 7,
                  value: post.campaignProgress,
                  backgroundColor: const Color(0xFFE5E7EB),
                  color: const Color(0xFF1A685B),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 2),
              child: Text(
                'Đạt ${(post.campaignProgress! * 100).toInt()}% mục tiêu',
                style: const TextStyle(
                  color: _muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
            child: Row(
              children: <Widget>[
                IconButton(
                  onPressed: onLikeToggle,
                  icon: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? _primary : _text,
                  ),
                ),
                IconButton(
                  onPressed: onCommentTap,
                  icon: const Icon(Icons.mode_comment_outlined, color: _text),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.send_outlined, color: _text),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.bookmark_border, color: _text),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: Text(
              '$likeCount lượt thích',
              style: const TextStyle(
                color: _text,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Text(
              'Xem $commentCount bình luận',
              style: const TextStyle(
                color: _muted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    final ({String label, Color bg, Color fg}) config = switch (type) {
      'UPDATE' => (
          label: 'Update',
          bg: const Color(0xFFECFDF5),
          fg: const Color(0xFF047857),
        ),
      'ANNOUNCEMENT' => (
          label: 'Thông báo',
          bg: const Color(0xFFFFF7ED),
          fg: const Color(0xFFC2410C),
        ),
      'NEWS' => (
          label: 'Tin tức',
          bg: const Color(0xFFEFF6FF),
          fg: const Color(0xFF1D4ED8),
        ),
      _ => (
          label: type,
          bg: const Color(0xFFF3F4F6),
          fg: const Color(0xFF4B5563),
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: config.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        config.label,
        style: TextStyle(
          color: config.fg,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
