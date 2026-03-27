import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/api/api_service.dart';
import '../../core/models/feed_comment_model.dart';

String feedCommentTimeLabel(String raw) {
  if (raw.isEmpty) return '';
  final DateTime? d = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
  if (d == null) return raw;
  final int sec = DateTime.now().difference(d).inSeconds;
  if (sec < 60) return 'Vừa xong';
  if (sec < 3600) return '${sec ~/ 60} phút';
  if (sec < 86400) return '${sec ~/ 3600} giờ';
  if (sec < 604800) return '${sec ~/ 86400} ngày';
  return '${d.day}/${d.month}/${d.year}';
}

/// Shared comment list + composer (nested replies, likes, edit/delete for owner).
/// Used by the bottom sheet and the full post detail screen (danbox parity).
class FeedCommentsPanel extends StatefulWidget {
  const FeedCommentsPanel({
    super.key,
    required this.postId,
    required this.isLocked,
    required this.onTotalChanged,
    this.currentUserId,
    this.showSheetChrome = false,
  });

  final int postId;
  final bool isLocked;
  final int? currentUserId;
  final void Function(int total) onTotalChanged;
  /// Top drag handle + "Bình luận" row (bottom sheet).
  final bool showSheetChrome;

  @override
  State<FeedCommentsPanel> createState() => _FeedCommentsPanelState();
}

class _FeedCommentsPanelState extends State<FeedCommentsPanel> {
  static const Color _primary = Color(0xFFF84D43);
  static const Color _text = Color(0xFF111827);
  static const Color _muted = Color(0xFF6B7280);

  final ApiService _api = ApiService();
  final TextEditingController _composer = TextEditingController();
  TextEditingController? _editDraftController;

  List<FeedCommentModel> _roots = <FeedCommentModel>[];
  bool _loading = true;
  String? _error;
  bool _sending = false;
  int? _replyParentId;
  int? _editingCommentId;
  bool _savingEdit = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _editDraftController?.dispose();
    _composer.dispose();
    super.dispose();
  }

  static int _countComments(List<FeedCommentModel> roots) {
    int n = 0;
    for (final FeedCommentModel c in roots) {
      n += 1 + c.replies.length;
    }
    return n;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final Response<dynamic> res =
          await _api.getFeedPostComments(widget.postId, page: 0, size: 40);
      final dynamic data = res.data;
      final List<dynamic> list = data is Map<String, dynamic>
          ? (data['content'] as List<dynamic>? ?? <dynamic>[])
          : (data is List<dynamic> ? data : <dynamic>[]);
      final List<FeedCommentModel> next = list
          .whereType<Map<String, dynamic>>()
          .map(FeedCommentModel.fromJson)
          .toList();
      if (!mounted) return;
      setState(() {
        _roots = next;
        _loading = false;
      });
      widget.onTotalChanged(_countComments(_roots));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Không tải được bình luận';
      });
    }
  }

  Future<void> _send() async {
    final String text = _composer.text.trim();
    if (text.isEmpty || widget.isLocked) return;
    setState(() => _sending = true);
    try {
      await _api.createFeedPostComment(
        widget.postId,
        text,
        parentCommentId: _replyParentId,
      );
      _composer.clear();
      _replyParentId = null;
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gửi bình luận thất bại')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _toggleCommentLike(FeedCommentModel comment) async {
    try {
      final Response<dynamic> res =
          await _api.toggleFeedPostCommentLike(comment.id);
      final dynamic data = res.data;
      int like = comment.likeCount;
      bool liked = comment.isLiked;
      if (data is Map<String, dynamic>) {
        final int? lc = _parseInt(data['likeCount']);
        if (lc != null) like = lc;
        if (data.containsKey('isLiked')) {
          liked = data['isLiked'] == true;
        }
      }
      if (!mounted) return;
      setState(() {
        _roots = _updateCommentInTree(
          _roots,
          comment.id,
          (FeedCommentModel c) => c.copyWithLike(likeCount: like, isLiked: liked),
        );
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không cập nhật được thích')),
        );
      }
    }
  }

  static int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  List<FeedCommentModel> _updateCommentInTree(
    List<FeedCommentModel> roots,
    int commentId,
    FeedCommentModel Function(FeedCommentModel) fn,
  ) {
    return roots.map((FeedCommentModel c) {
      if (c.id == commentId) return fn(c);
      if (c.replies.isEmpty) return c;
      return FeedCommentModel(
        id: c.id,
        postId: c.postId,
        userId: c.userId,
        parentCommentId: c.parentCommentId,
        content: c.content,
        likeCount: c.likeCount,
        isLiked: c.isLiked,
        authorName: c.authorName,
        authorAvatar: c.authorAvatar,
        createdAt: c.createdAt,
        updatedAt: c.updatedAt,
        replies: _updateCommentInTree(c.replies, commentId, fn),
      );
    }).toList();
  }

  List<FeedCommentModel> _removeCommentFromTree(
    List<FeedCommentModel> roots,
    int commentId,
  ) {
    final List<FeedCommentModel> out = <FeedCommentModel>[];
    for (final FeedCommentModel c in roots) {
      if (c.id == commentId) continue;
      final List<FeedCommentModel> sub = _removeCommentFromTree(c.replies, commentId);
      out.add(FeedCommentModel(
        id: c.id,
        postId: c.postId,
        userId: c.userId,
        parentCommentId: c.parentCommentId,
        content: c.content,
        likeCount: c.likeCount,
        isLiked: c.isLiked,
        authorName: c.authorName,
        authorAvatar: c.authorAvatar,
        createdAt: c.createdAt,
        updatedAt: c.updatedAt,
        replies: sub,
      ));
    }
    return out;
  }

  void _cancelInlineEdit() {
    if (!mounted) return;
    setState(() {
      _editingCommentId = null;
      _editDraftController?.dispose();
      _editDraftController = null;
      _savingEdit = false;
    });
  }

  void _beginInlineEdit(FeedCommentModel comment) {
    _editDraftController?.dispose();
    _editDraftController = TextEditingController(text: comment.content);
    setState(() {
      _editingCommentId = comment.id;
      _replyParentId = null;
    });
  }

  Future<void> _saveInlineEdit() async {
    final int? id = _editingCommentId;
    final TextEditingController? ctl = _editDraftController;
    if (id == null || ctl == null || !mounted) return;
    final String next = ctl.text.trim();
    if (next.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nội dung không được để trống')),
      );
      return;
    }
    setState(() => _savingEdit = true);
    try {
      await _api.updateFeedPostComment(id, next);
      if (!mounted) return;
      setState(() {
        _roots = _updateCommentInTree(
          _roots,
          id,
          (FeedCommentModel c) {
            return FeedCommentModel(
              id: c.id,
              postId: c.postId,
              userId: c.userId,
              parentCommentId: c.parentCommentId,
              content: next,
              likeCount: c.likeCount,
              isLiked: c.isLiked,
              authorName: c.authorName,
              authorAvatar: c.authorAvatar,
              createdAt: c.createdAt,
              updatedAt: DateTime.now().toUtc().toIso8601String(),
              replies: c.replies,
            );
          },
        );
        _editingCommentId = null;
        _editDraftController?.dispose();
        _editDraftController = null;
        _savingEdit = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _savingEdit = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lưu bình luận thất bại')),
        );
      }
    }
  }

  Future<void> _deleteComment(FeedCommentModel comment) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext c) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Xóa bình luận?'),
          content: const Text(
            'Bình luận sẽ bị gỡ khỏi bài viết. Bạn có chắc chắn?',
            style: TextStyle(fontSize: 14, height: 1.4, color: _muted),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Huỷ'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              style: FilledButton.styleFrom(backgroundColor: _primary),
              child: const Text('Xóa'),
            ),
          ],
        );
      },
    );
    if (ok != true || !mounted) return;
    try {
      await _api.deleteFeedPostComment(comment.id);
      if (!mounted) return;
      if (_editingCommentId == comment.id) {
        _cancelInlineEdit();
      }
      setState(() {
        _roots = _removeCommentFromTree(_roots, comment.id);
      });
      widget.onTotalChanged(_countComments(_roots));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Xóa bình luận thất bại')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final int total = _countComments(_roots);
    final double padBottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: padBottom + (widget.showSheetChrome ? 16 : 0)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (widget.showSheetChrome) ...<Widget>[
            Center(
              child: Container(
                width: 46,
                height: 4,
                margin: const EdgeInsets.only(top: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                const Text(
                  'Bình luận',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: _text,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh, size: 22),
                  color: _muted,
                ),
              ],
            ),
          ] else ...<Widget>[
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'BÌNH LUẬN ($total)',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  letterSpacing: 0.06,
                  color: _text,
                ),
              ),
            ),
          ],
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!, style: const TextStyle(color: _muted)))
                    : _roots.isEmpty
                        ? const Center(
                            child: Text(
                              'Chưa có bình luận',
                              style: TextStyle(color: _muted),
                            ),
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount:
                                _roots.length + (_roots.isNotEmpty ? 1 : 0),
                            itemBuilder: (BuildContext c, int i) {
                              if (i >= _roots.length) {
                                return Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    8,
                                    20,
                                    8,
                                    12,
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Đã hiển thị tất cả bình luận.\n'
                                      'Không còn bình luận nào phía dưới.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: _muted.withOpacity(0.9),
                                        height: 1.35,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                );
                              }
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  _CommentThread(
                                    comment: _roots[i],
                                    depth: 0,
                                    currentUserId: widget.currentUserId,
                                    editingCommentId: _editingCommentId,
                                    editController: _editDraftController,
                                    savingEdit: _savingEdit,
                                    timeLabel: feedCommentTimeLabel(
                                      _roots[i].updatedAt ??
                                          _roots[i].createdAt,
                                    ),
                                    onReply: (int id) {
                                      setState(() => _replyParentId = id);
                                    },
                                    onToggleLike: _toggleCommentLike,
                                    onBeginEdit: _beginInlineEdit,
                                    onCancelEdit: _cancelInlineEdit,
                                    onSaveEdit: _saveInlineEdit,
                                    onDelete: _deleteComment,
                                  ),
                                  if (i < _roots.length - 1)
                                    const Divider(height: 24),
                                ],
                              );
                            },
                          ),
          ),
          const SizedBox(height: 10),
          if (widget.isLocked)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Bài viết đang khóa bình luận.',
                style: TextStyle(color: _muted, fontSize: 13),
              ),
            ),
          if (!widget.isLocked && _replyParentId != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.reply_rounded,
                        size: 20,
                        color: _muted.withOpacity(0.85),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Đang trả lời bình luận',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _text.withOpacity(0.88),
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () =>
                            setState(() => _replyParentId = null),
                        style: TextButton.styleFrom(
                          foregroundColor: _text,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Hủy trả lời'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _composer,
                  minLines: 1,
                  maxLines: 4,
                  enabled: !widget.isLocked && !_sending,
                  decoration: InputDecoration(
                    hintText: widget.isLocked
                        ? 'Đã khóa bình luận'
                        : (_replyParentId != null
                            ? 'Phản hồi...'
                            : 'Thêm bình luận...'),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: widget.isLocked || _sending ? null : _send,
                style: FilledButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(72, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Đăng'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CommentThread extends StatelessWidget {
  const _CommentThread({
    required this.comment,
    required this.depth,
    required this.currentUserId,
    required this.editingCommentId,
    required this.editController,
    required this.savingEdit,
    required this.timeLabel,
    required this.onReply,
    required this.onToggleLike,
    required this.onBeginEdit,
    required this.onCancelEdit,
    required this.onSaveEdit,
    required this.onDelete,
  });

  final FeedCommentModel comment;
  final int depth;
  final int? currentUserId;
  final int? editingCommentId;
  final TextEditingController? editController;
  final bool savingEdit;
  final String timeLabel;
  final void Function(int parentId) onReply;
  final void Function(FeedCommentModel) onToggleLike;
  final void Function(FeedCommentModel) onBeginEdit;
  final VoidCallback onCancelEdit;
  final VoidCallback onSaveEdit;
  final void Function(FeedCommentModel) onDelete;

  static const Color _muted = Color(0xFF6B7280);
  static const Color _primary = Color(0xFFF84D43);
  static const Color _accentTeal = Color(0xFF1A685B);

  bool get _isOwn =>
      currentUserId != null && comment.userId == currentUserId;

  static const double _indentPerLevel = 22;

  @override
  Widget build(BuildContext context) {
    final bool isReply = depth > 0;
    final double branchLeft = isReply ? 10 + (depth - 1) * _indentPerLevel : 0;
    final bool isEditing = editingCommentId != null &&
        editingCommentId == comment.id &&
        editController != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.only(left: branchLeft),
          child: Container(
            decoration: isReply
                ? const BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: Color(0xFFC7CED6),
                        width: 3,
                      ),
                    ),
                  )
                : null,
            padding: EdgeInsets.only(left: isReply ? 14 : 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
              CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFFF3F4F6),
                backgroundImage: comment.authorAvatar != null &&
                        comment.authorAvatar!.isNotEmpty
                    ? NetworkImage(comment.authorAvatar!)
                    : null,
                child: comment.authorAvatar == null ||
                        comment.authorAvatar!.isEmpty
                    ? Text(
                        comment.authorName.isNotEmpty
                            ? comment.authorName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
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
                            comment.authorName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ),
                        if (isReply)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2F6),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Trả lời',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF64748B),
                                letterSpacing: 0.02,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (isEditing)
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFE5E7EB),
                          ),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            TextField(
                              controller: editController,
                              minLines: 3,
                              maxLines: 10,
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.45,
                                color: Color(0xFF1F2937),
                              ),
                              decoration: const InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: <Widget>[
                                TextButton(
                                  onPressed:
                                      savingEdit ? null : onCancelEdit,
                                  child: Text(
                                    'Huỷ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                FilledButton(
                                  onPressed:
                                      savingEdit ? null : onSaveEdit,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _accentTeal,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: savingEdit
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          'Lưu',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      )
                    else ...<Widget>[
                      Text(
                        comment.content,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.35,
                          color: Color(0xFF374151),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          Text(
                            timeLabel,
                            style: const TextStyle(
                              fontSize: 12,
                              color: _muted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          InkWell(
                            onTap: () => onToggleLike(comment),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(
                                  comment.isLiked
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  size: 18,
                                  color:
                                      comment.isLiked ? _primary : _muted,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${comment.likeCount}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: _muted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (depth == 0)
                            InkWell(
                              onTap: () => onReply(comment.id),
                              child: const Text(
                                'Phản hồi',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _accentTeal,
                                ),
                              ),
                            ),
                          if (_isOwn) ...<Widget>[
                            InkWell(
                              onTap: () => onBeginEdit(comment),
                              child: const Text(
                                'Sửa',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF4B5563),
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () => onDelete(comment),
                              child: const Text(
                                'Xóa',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
            ),
          ),
        ),
        if (comment.replies.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(
              top: 12,
              left: isReply ? 6 + branchLeft : 0,
            ),
            child: Column(
              children: comment.replies
                  .map(
                    (FeedCommentModel r) => Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: _CommentThread(
                        comment: r,
                        depth: depth + 1,
                        currentUserId: currentUserId,
                        editingCommentId: editingCommentId,
                        editController: editController,
                        savingEdit: savingEdit,
                        timeLabel: feedCommentTimeLabel(
                          r.updatedAt ?? r.createdAt,
                        ),
                        onReply: onReply,
                        onToggleLike: onToggleLike,
                        onBeginEdit: onBeginEdit,
                        onCancelEdit: onCancelEdit,
                        onSaveEdit: onSaveEdit,
                        onDelete: onDelete,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }
}
