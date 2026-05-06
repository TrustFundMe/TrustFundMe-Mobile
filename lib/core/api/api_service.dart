import 'dart:io';
import 'package:dio/dio.dart';
import 'base_service.dart';
import 'auth_service.dart';
import 'user_service.dart';
import 'campaign_service.dart';
import 'donation_service.dart';
import 'expenditure_service.dart';
import 'feed_service.dart';
import 'media_service.dart';
import 'chat_service.dart';
import 'flag_service.dart';

/// Monolithic API service â€” giu backward compatibility.
///
/// **DEPRECATED**: Cac screen/widget moi nen dung truc tiep domain services
/// ([AuthService], [UserService], [CampaignService], v.v.) thay vi ApiService.
///
/// File nay delegate tat ca methods sang domain services tuong ung,
/// dam bao code hien tai van hoat dong khong can sua.
class ApiService extends BaseService {
  // Domain service instances (lazy)
  final AuthService _auth = AuthService();
  final UserService _user = UserService();
  final CampaignService _campaign = CampaignService();
  final DonationService _donation = DonationService();
  final ExpenditureService _expenditure = ExpenditureService();
  final FeedService _feed = FeedService();
  final MediaService _media = MediaService();
  final ChatService _chat = ChatService();
  final FlagService _flag = FlagService();

  // AUTH (delegate -> AuthService)

  @Deprecated('Use AuthService.login() instead')
  Future<Response<dynamic>> login(String username, String password) =>
      _auth.login(username, password);

  @Deprecated('Use AuthService.register() instead')
  Future<Response<dynamic>> register({
    required String email,
    required String password,
    required String fullName,
    String? phoneNumber,
  }) =>
      _auth.register(
        email: email,
        password: password,
        fullName: fullName,
        phoneNumber: phoneNumber,
      );

  @Deprecated('Use AuthService.loginWithGoogle() instead')
  Future<Response<dynamic>> loginWithGoogle(String idToken) =>
      _auth.loginWithGoogle(idToken);

  @Deprecated('Use AuthService.sendPasswordResetOtp() instead')
  Future<Response<dynamic>> sendPasswordResetOtp(String email) =>
      _auth.sendPasswordResetOtp(email);

  @Deprecated('Use AuthService.verifyPasswordResetOtp() instead')
  Future<Response<dynamic>> verifyPasswordResetOtp({
    required String email,
    required String otp,
  }) =>
      _auth.verifyPasswordResetOtp(email: email, otp: otp);

  @Deprecated('Use AuthService.resetPassword() instead')
  Future<Response<dynamic>> resetPassword({
    required String token,
    required String newPassword,
  }) =>
      _auth.resetPassword(token: token, newPassword: newPassword);

  @Deprecated('Use AuthService.verifyEmailWithToken() instead')
  Future<Response<dynamic>> verifyEmailWithToken(String token) =>
      _auth.verifyEmailWithToken(token);

  // USER / PROFILE (delegate -> UserService)

  @Deprecated('Use UserService.updateProfile() instead')
  Future<Response<dynamic>> updateProfile(
    int userId,
    Map<String, dynamic> data,
  ) =>
      _user.updateProfile(userId, data);

  @Deprecated('Use UserService.uploadToSupabase() instead')
  Future<String> uploadToSupabase(String filePath, int userId) =>
      _user.uploadToSupabase(filePath, userId);

  @Deprecated('Use UserService.getUserById() instead')
  Future<Response<dynamic>> getUserById(int userId) =>
      _user.getUserById(userId);

  @Deprecated('Use UserService.getMyBankAccounts() instead')
  Future<Response<dynamic>> getMyBankAccounts() =>
      _user.getMyBankAccounts();

  @Deprecated('Use UserService.createBankAccount() instead')
  Future<Response<dynamic>> createBankAccount(Map<String, dynamic> data) =>
      _user.createBankAccount(data);

  @Deprecated('Use UserService.updateBankAccount() instead')
  Future<Response<dynamic>> updateBankAccount(
    int id,
    Map<String, dynamic> data,
  ) =>
      _user.updateBankAccount(id, data);

  // CAMPAIGNS (delegate -> CampaignService)

  @Deprecated('Use CampaignService.getCampaigns() instead')
  Future<Response<dynamic>> getCampaigns() =>
      _campaign.getCampaigns();

  @Deprecated('Use CampaignService.getCampaign() instead')
  Future<Response<dynamic>> getCampaign(int id) =>
      _campaign.getCampaign(id);

  @Deprecated('Use CampaignService.createCampaign() instead')
  Future<Response<dynamic>> createCampaign(Map<String, dynamic> data) =>
      _campaign.createCampaign(data);

  @Deprecated('Use CampaignService.updateCampaign() instead')
  Future<Response<dynamic>> updateCampaign(
    int id,
    Map<String, dynamic> data,
  ) =>
      _campaign.updateCampaign(id, data);

  @Deprecated('Use CampaignService.deleteCampaign() instead')
  Future<Response<dynamic>> deleteCampaign(int id) =>
      _campaign.deleteCampaign(id);

  @Deprecated('Use CampaignService.getUserCampaigns() instead')
  Future<Response<dynamic>> getUserCampaigns(
    int userId, {
    int page = 0,
    int size = 10,
  }) =>
      _campaign.getUserCampaigns(userId, page: page, size: size);

  @Deprecated('Use CampaignService.getCategories() instead')
  Future<Response<dynamic>> getCategories() =>
      _campaign.getCategories();

  @Deprecated('Use CampaignService.followCampaign() instead')
  Future<Response<dynamic>> followCampaign(int campaignId) =>
      _campaign.followCampaign(campaignId);

  @Deprecated('Use CampaignService.unfollowCampaign() instead')
  Future<Response<dynamic>> unfollowCampaign(int campaignId) =>
      _campaign.unfollowCampaign(campaignId);

  @Deprecated('Use CampaignService.isFollowingCampaign() instead')
  Future<Response<dynamic>> isFollowingCampaign(int campaignId) =>
      _campaign.isFollowingCampaign(campaignId);

  @Deprecated('Use CampaignService.getFollowerCount() instead')
  Future<Response<dynamic>> getCampaignFollowerCount(int campaignId) =>
      _campaign.getFollowerCount(campaignId);

  @Deprecated('Use CampaignService.getFollowers() instead')
  Future<Response<dynamic>> getCampaignFollowers(int campaignId) =>
      _campaign.getFollowers(campaignId);

  @Deprecated('Use CampaignService.getActiveGoalByCampaign() instead')
  Future<Response<dynamic>> getActiveGoalByCampaign(int campaignId) =>
      _campaign.getActiveGoalByCampaign(campaignId);

  @Deprecated('Use CampaignService.createGoal() instead')
  Future<Response<dynamic>> createGoal(Map<String, dynamic> data) =>
      _campaign.createGoal(data);

  @Deprecated('Use CampaignService.getGoalsByCampaign() instead')
  Future<Response<dynamic>> getGoalsByCampaign(int campaignId) =>
      _campaign.getGoalsByCampaign(campaignId);

  @Deprecated('Use CampaignService.getTaskByCampaignId() instead')
  Future<Response<dynamic>> getTaskByCampaignId(int campaignId) =>
      _campaign.getTaskByCampaignId(campaignId);

  @Deprecated('Use CampaignService.generateDescription() instead')
  Future<Response<dynamic>> generateDescription(
    String prompt, {
    String? rules,
  }) =>
      _campaign.generateDescription(prompt, rules: rules);

  @Deprecated('Use MediaService.getCampaignFirstImage() instead')
  Future<Response<dynamic>> getCampaignFirstImage(int campaignId) =>
      _media.getCampaignFirstImage(campaignId);

  // DONATIONS / PAYMENTS (delegate -> DonationService)

  @Deprecated('Use DonationService.createPayment() instead')
  Future<Response<dynamic>> createPayment(Map<String, dynamic> body) =>
      _donation.createPayment(body);

  @Deprecated('Use DonationService.verifyDonationPayment() instead')
  Future<Response<dynamic>> verifyDonationPayment(int donationId) =>
      _donation.verifyDonationPayment(donationId);

  @Deprecated('Use DonationService.syncDonationQuantity() instead')
  Future<Response<dynamic>> syncDonationQuantity(int donationId) =>
      _donation.syncDonationQuantity(donationId);

  @Deprecated('Use DonationService.syncDonationBalance() instead')
  Future<Response<dynamic>> syncDonationBalance(int donationId) =>
      _donation.syncDonationBalance(donationId);

  @Deprecated('Use DonationService.getDonationSummary() instead')
  Future<Response<dynamic>> getDonationSummary(
    List<int> expenditureItemIds,
  ) =>
      _donation.getDonationSummary(expenditureItemIds);

  @Deprecated('Use DonationService.getDonorsByItem() instead')
  Future<Response<dynamic>> getDonorsByItem(int itemId) =>
      _donation.getDonorsByItem(itemId);

  @Deprecated('Use DonationService.getCampaignProgress() instead')
  Future<Response<dynamic>> getCampaignProgress(int campaignId) =>
      _donation.getCampaignProgress(campaignId);

  @Deprecated('Use DonationService.getRecentDonors() instead')
  Future<Response<dynamic>> getRecentDonors(
    int campaignId, {
    int limit = 3,
  }) =>
      _donation.getRecentDonors(campaignId, limit: limit);

  @Deprecated('Use DonationService.getMyDonations() instead')
  Future<Response<dynamic>> getMyDonations({int limit = 50}) =>
      _donation.getMyDonations(limit: limit);

  @Deprecated('Use DonationService.checkExpenditureItemLimit() instead')
  Future<Response<dynamic>> checkExpenditureItemLimit(
    int expenditureItemId,
    int quantity,
  ) =>
      _donation.checkExpenditureItemLimit(expenditureItemId, quantity);

  // EXPENDITURES (delegate -> ExpenditureService)

  @Deprecated('Use ExpenditureService.createExpenditure() instead')
  Future<Response<dynamic>> createExpenditure(Map<String, dynamic> data) =>
      _expenditure.createExpenditure(data);

  @Deprecated('Use ExpenditureService.getExpendituresByCampaign() instead')
  Future<Response<dynamic>> getExpendituresByCampaign(int campaignId) =>
      _expenditure.getExpendituresByCampaign(campaignId);

  @Deprecated('Use ExpenditureService.getExpenditureById() instead')
  Future<Response<dynamic>> getExpenditureById(int expenditureId) =>
      _expenditure.getExpenditureById(expenditureId);

  @Deprecated('Use ExpenditureService.getExpenditureItemsByCampaign() instead')
  Future<Response<dynamic>> getExpenditureItemsByCampaign(int campaignId) =>
      _expenditure.getExpenditureItemsByCampaign(campaignId);

  @Deprecated('Use ExpenditureService.getExpenditureItems() instead')
  Future<Response<dynamic>> getExpenditureItems(int expenditureId) =>
      _expenditure.getExpenditureItems(expenditureId);

  @Deprecated('Use ExpenditureService.getApprovedExpenditureItemsByCampaign() instead')
  Future<Response<dynamic>> getApprovedExpenditureItemsByCampaign(
    int campaignId,
  ) =>
      _expenditure.getApprovedExpenditureItemsByCampaign(campaignId);

  @Deprecated('Use ExpenditureService.requestWithdrawal() instead')
  Future<Response<dynamic>> requestWithdrawal(int expenditureId) =>
      _expenditure.requestWithdrawal(expenditureId);

  @Deprecated('Use ExpenditureService.updateEvidenceStatus() instead')
  Future<Response<dynamic>> updateEvidenceStatus(
    int expenditureId,
    String status,
  ) =>
      _expenditure.updateEvidenceStatus(expenditureId, status);

  // FEED POSTS (delegate -> FeedService)

  @Deprecated('Use FeedService.getFeedPosts() instead')
  Future<Response<dynamic>> getFeedPosts({
    int page = 0,
    int size = 10,
    String sort = 'createdAt,desc',
    int? categoryId,
    int? campaignId,
  }) =>
      _feed.getFeedPosts(
        page: page,
        size: size,
        sort: sort,
        categoryId: categoryId,
        campaignId: campaignId,
      );

  @Deprecated('Use FeedService.getFeedPostsByTarget() instead')
  Future<Response<dynamic>> getFeedPostsByTarget({
    required int targetId,
    required String targetType,
    int page = 0,
    int size = 20,
    String sort = 'createdAt,desc',
  }) =>
      _feed.getFeedPostsByTarget(
        targetId: targetId,
        targetType: targetType,
        page: page,
        size: size,
        sort: sort,
      );

  @Deprecated('Use FeedService.getMyFeedPosts() instead')
  Future<Response<dynamic>> getMyFeedPosts({
    String status = 'ALL',
    int page = 0,
    int size = 20,
    String sort = 'updatedAt,desc',
  }) =>
      _feed.getMyFeedPosts(
        status: status,
        page: page,
        size: size,
        sort: sort,
      );

  @Deprecated('Use FeedService.getFeedPostById() instead')
  Future<Response<dynamic>> getFeedPostById(int id) =>
      _feed.getFeedPostById(id);

  @Deprecated('Use FeedService.createFeedPost() instead')
  Future<Response<dynamic>> createFeedPost(Map<String, dynamic> body) =>
      _feed.createFeedPost(body);

  @Deprecated('Use FeedService.updateFeedPost() instead')
  Future<Response<dynamic>> updateFeedPost(
    int id,
    Map<String, dynamic> body,
  ) =>
      _feed.updateFeedPost(id, body);

  @Deprecated('Use FeedService.deleteFeedPost() instead')
  Future<Response<dynamic>> deleteFeedPost(int id) =>
      _feed.deleteFeedPost(id);

  @Deprecated('Use FeedService.patchFeedPostVisibility() instead')
  Future<Response<dynamic>> patchFeedPostVisibility(
    int id,
    String visibility,
  ) =>
      _feed.patchFeedPostVisibility(id, visibility);

  @Deprecated('Use FeedService.toggleFeedPostLike() instead')
  Future<Response<dynamic>> toggleFeedPostLike(int postId) =>
      _feed.toggleFeedPostLike(postId);

  @Deprecated('Use FeedService.toggleFeedPostCommentLike() instead')
  Future<Response<dynamic>> toggleFeedPostCommentLike(int commentId) =>
      _feed.toggleFeedPostCommentLike(commentId);

  @Deprecated('Use FeedService.getFeedPostComments() instead')
  Future<Response<dynamic>> getFeedPostComments(
    int postId, {
    int page = 0,
    int size = 20,
    String sort = 'createdAt,desc',
  }) =>
      _feed.getFeedPostComments(postId, page: page, size: size, sort: sort);

  @Deprecated('Use FeedService.createFeedPostComment() instead')
  Future<Response<dynamic>> createFeedPostComment(
    int postId,
    String content, {
    int? parentCommentId,
  }) =>
      _feed.createFeedPostComment(postId, content,
          parentCommentId: parentCommentId);

  @Deprecated('Use FeedService.updateFeedPostComment() instead')
  Future<Response<dynamic>> updateFeedPostComment(
    int commentId,
    String content,
  ) =>
      _feed.updateFeedPostComment(commentId, content);

  @Deprecated('Use FeedService.deleteFeedPostComment() instead')
  Future<Response<dynamic>> deleteFeedPostComment(int commentId) =>
      _feed.deleteFeedPostComment(commentId);

  @Deprecated('Use FeedService.markUserPostSeen() instead')
  Future<Response<dynamic>> markUserPostSeen(int postId) =>
      _feed.markUserPostSeen(postId);

  @Deprecated('Use FeedService.getForumCategories() instead')
  Future<Response<dynamic>> getForumCategories() =>
      _feed.getForumCategories();

  @Deprecated('Use FeedService.getFeedPostRevisions() instead')
  Future<Response<dynamic>> getFeedPostRevisions(
    int postId, {
    int page = 0,
    int size = 10,
  }) =>
      _feed.getFeedPostRevisions(postId, page: page, size: size);

  @Deprecated('Use FeedService.getFeedPostRevisionById() instead')
  Future<Response<dynamic>> getFeedPostRevisionById(
    int postId,
    int revisionId,
  ) =>
      _feed.getFeedPostRevisionById(postId, revisionId);

  // MEDIA (delegate -> MediaService)

  @Deprecated('Use MediaService.uploadMedia() instead')
  Future<Response<dynamic>> uploadMedia(
    File file, {
    int? postId,
    int? campaignId,
    int? expenditureId,
    String? mediaType,
    String? description,
  }) =>
      _media.uploadMedia(
        file,
        postId: postId,
        campaignId: campaignId,
        expenditureId: expenditureId,
        mediaType: mediaType,
        description: description,
      );

  @Deprecated('Use MediaService.getMediaByPostId() instead')
  Future<Response<dynamic>> getMediaByPostId(int postId) =>
      _media.getMediaByPostId(postId);

  @Deprecated('Use MediaService.updateMedia() instead')
  Future<Response<dynamic>> updateMedia(
    int mediaId,
    Map<String, dynamic> body,
  ) =>
      _media.updateMedia(mediaId, body);

  @Deprecated('Use MediaService.deleteMedia() instead')
  Future<Response<dynamic>> deleteMedia(int mediaId) =>
      _media.deleteMedia(mediaId);

  @Deprecated('Use MediaService.linkMediaToCampaign() instead')
  Future<Response<dynamic>> linkMediaToCampaign(
    int mediaId,
    int campaignId,
  ) =>
      _media.linkMediaToCampaign(mediaId, campaignId);

  // CHAT (delegate -> ChatService)

  @Deprecated('Use ChatService.getConversations() instead')
  Future<Response<dynamic>> getConversations() =>
      _chat.getConversations();

  @Deprecated('Use ChatService.getMessagesByConversationId() instead')
  Future<Response<dynamic>> getMessagesByConversationId(
    int conversationId,
  ) =>
      _chat.getMessagesByConversationId(conversationId);

  @Deprecated('Use ChatService.createConversation() instead')
  Future<Response<dynamic>> createConversation({
    required int fundOwnerId,
    required int campaignId,
    int? staffId,
  }) =>
      _chat.createConversation(
        fundOwnerId: fundOwnerId,
        campaignId: campaignId,
        staffId: staffId,
      );

  @Deprecated('Use ChatService.getConversationByCampaignId() instead')
  Future<Response<dynamic>> getConversationByCampaignId(int campaignId) =>
      _chat.getConversationByCampaignId(campaignId);

  @Deprecated('Use ChatService.getAppointmentsByDonor() instead')
  Future<Response<dynamic>> getAppointmentsByDonor(int donorId) =>
      _chat.getAppointmentsByDonor(donorId);

  @Deprecated('Use ChatService.updateAppointmentStatus() instead')
  Future<Response<dynamic>> updateAppointmentStatus(
    int appointmentId,
    String status,
  ) =>
      _chat.updateAppointmentStatus(appointmentId, status);

  // FLAGS (delegate -> FlagService)

  @Deprecated('Use FlagService.submitFlag() instead')
  Future<Response<dynamic>> submitFlag({
    int? postId,
    int? campaignId,
    required String reason,
  }) =>
      _flag.submitFlag(postId: postId, campaignId: campaignId, reason: reason);

  @Deprecated('Use FlagService.getMyFlags() instead')
  Future<Response<dynamic>> getMyFlags({int page = 0, int size = 20}) =>
      _flag.getMyFlags(page: page, size: size);
}
