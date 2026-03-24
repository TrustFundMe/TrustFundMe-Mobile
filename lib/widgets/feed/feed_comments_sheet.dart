import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/providers/auth_provider.dart';
import 'feed_comments_panel.dart';

Future<void> showFeedCommentsSheet(
  BuildContext context, {
  required int postId,
  required bool isLocked,
  required void Function(int newTotal) onCommentCountChanged,
}) {
  final int? uid = context.read<AuthProvider>().user?.id;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (BuildContext ctx) {
      final double sheetH = MediaQuery.of(ctx).size.height * 0.78;
      return SizedBox(
        height: sheetH,
        child: Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 4),
          child: FeedCommentsPanel(
            postId: postId,
            isLocked: isLocked,
            currentUserId: uid,
            showSheetChrome: true,
            onTotalChanged: onCommentCountChanged,
          ),
        ),
      );
    },
  );
}
