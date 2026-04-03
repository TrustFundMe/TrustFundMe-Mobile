import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../core/api/api_service.dart';
import '../core/models/feed_post_model.dart';
import 'feed_post_detail_screen.dart';

class MyFeedScreen extends StatefulWidget {
  const MyFeedScreen({super.key});

  @override
  State<MyFeedScreen> createState() => _MyFeedScreenState();
}

class _MyFeedScreenState extends State<MyFeedScreen> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late final TabController _tabController;

  bool _loading = true;
  String? _error;
  List<FeedPostModel> _allPosts = <FeedPostModel>[];
  List<FeedPostModel> _draftPosts = <FeedPostModel>[];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final Response<dynamic> allRes = await _api.getMyFeedPosts(status: 'ALL', size: 50);
      final Response<dynamic> draftRes = await _api.getMyFeedPosts(status: 'DRAFT', size: 50);

      final List<FeedPostModel> all = _parsePage(allRes.data);
      final List<FeedPostModel> drafts = _parsePage(draftRes.data);
      if (!mounted) return;
      setState(() {
        _allPosts = all;
        _draftPosts = drafts;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _allPosts = <FeedPostModel>[];
        _draftPosts = <FeedPostModel>[];
        _error = 'Khong tai duoc du lieu feed. Vui long thu lai.';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  List<FeedPostModel> _parsePage(dynamic data) {
    if (data is! Map<String, dynamic>) return <FeedPostModel>[];
    final List<dynamic> content = data['content'] as List<dynamic>? ?? <dynamic>[];
    return content.whereType<Map<String, dynamic>>().map(FeedPostModel.fromJson).toList();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bai feed cua toi'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const <Tab>[
            Tab(text: 'Tat ca'),
            Tab(text: 'Draft'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: _load,
                          child: const Text('Thu lai'),
                        ),
                      ],
                    ),
                  ),
                )
          : TabBarView(
              controller: _tabController,
              children: <Widget>[
                _PostList(posts: _allPosts),
                _PostList(posts: _draftPosts),
              ],
            ),
    );
  }
}

class _PostList extends StatelessWidget {
  const _PostList({required this.posts});

  final List<FeedPostModel> posts;

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return const Center(
        child: Text('Khong co bai viet'),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: posts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (BuildContext context, int index) {
        final FeedPostModel post = posts[index];
        return ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          title: Text(post.title?.trim().isNotEmpty == true ? post.title! : '(Khong tieu de)'),
          subtitle: Text(post.status),
          onTap: () {
            Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => FeedPostDetailScreen(postId: post.id),
              ),
            );
          },
        );
      },
    );
  }
}
