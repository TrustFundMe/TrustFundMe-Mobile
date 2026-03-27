import '../models/feed_post_model.dart';

/// Returns true if the signed-in user may open the flag flow for [post].
bool userCanFlagFeedPost(FeedPostModel post, int? currentUserId) {
  if (currentUserId == null) return true;
  return post.authorId != currentUserId;
}
