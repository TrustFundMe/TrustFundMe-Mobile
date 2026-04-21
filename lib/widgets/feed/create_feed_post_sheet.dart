import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/api_service.dart';
import '../../core/models/feed_post_media_model.dart';
import '../../core/models/feed_post_model.dart';
import '../../core/providers/auth_provider.dart';

enum _TargetKind { none, campaign, expenditure }

class _CampaignPickResult {
  const _CampaignPickResult({required this.ids, required this.titles});

  final List<int> ids;
  final List<String> titles;
}

class _ExistingMediaSlot {
  _ExistingMediaSlot(this.item);

  final FeedPostMediaItem item;
  bool markedForDelete = false;
}

/// Create or edit feed post (parity with web options; mobile-first layout).
Future<void> showCreateFeedPostSheet(
  BuildContext context, {
  int? linkedCampaignId,
  String? linkedCampaignTitle,
  FeedPostModel? existingPost,
  VoidCallback? onCreated,
  VoidCallback? onUpdated,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (BuildContext ctx) {
      return FractionallySizedBox(
        heightFactor: 0.92,
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Color(0xFF424242),
            statusBarBrightness: Brightness.dark,
            statusBarIconBrightness: Brightness.light,
            systemNavigationBarColor: Colors.white,
            systemNavigationBarIconBrightness: Brightness.dark,
          ),
          child: _CreateFeedPostBody(
            linkedCampaignId: linkedCampaignId,
            linkedCampaignTitle: linkedCampaignTitle,
            existingPost: existingPost,
            onCreated: onCreated,
            onUpdated: onUpdated,
          ),
        ),
      );
    },
  );
}

class _CreateFeedPostBody extends StatefulWidget {
  const _CreateFeedPostBody({
    this.linkedCampaignId,
    this.linkedCampaignTitle,
    this.existingPost,
    this.onCreated,
    this.onUpdated,
  });

  final int? linkedCampaignId;
  final String? linkedCampaignTitle;
  final FeedPostModel? existingPost;
  final VoidCallback? onCreated;
  final VoidCallback? onUpdated;

  @override
  State<_CreateFeedPostBody> createState() => _CreateFeedPostBodyState();
}

class _CreateFeedPostBodyState extends State<_CreateFeedPostBody> {
  static const Color _primary = Color(0xFFF84D43);
  static const String _draftKey = 'create_feed_post_sheet_draft_v1';

  final ApiService _api = ApiService();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _content = TextEditingController();
  final List<XFile> _pickedImages = <XFile>[];
  final List<PlatformFile> _pickedFiles = <PlatformFile>[];
  List<_ExistingMediaSlot> _existingMedia = <_ExistingMediaSlot>[];
  bool _submitting = false;
  String _visibility = 'PUBLIC';

  _TargetKind _targetKind = _TargetKind.none;
  int? _campaignTargetId;
  String _campaignLabel = '';
  int? _expenditureTargetId;
  String _expenditureLabel = '';
  String? _targetValidationError;
  bool _loadingCampaignOptions = false;
  bool _loadingExpenditureOptions = false;
  /// Tránh gọi API lặp vô hạn khi danh sách rỗng (post-frame trong build).
  bool _campaignOptionsLoaded = false;
  String? _campaignListError;
  List<MapEntry<int, String>> _campaignOptions = <MapEntry<int, String>>[];
  List<MapEntry<int, String>> _expenditureOptions = <MapEntry<int, String>>[];
  bool _restoringDraft = false;

  bool get _isEdit => widget.existingPost != null;
  bool get _shouldUseDraft => !_isEdit && widget.linkedCampaignId == null;
  bool get _isLockedLinkedCampaign => widget.linkedCampaignId != null && !_isEdit;
  bool get _isTargetLocked =>
      _isEdit &&
      widget.existingPost?.targetId != null &&
      (widget.existingPost?.targetType ?? '').isNotEmpty;

  @override
  void initState() {
    super.initState();
    _title.addListener(_saveDraftIfNeeded);
    _content.addListener(_saveDraftIfNeeded);
    if (widget.linkedCampaignId != null) {
      _campaignTargetId = widget.linkedCampaignId;
      _campaignLabel =
          widget.linkedCampaignTitle ?? 'Chiến dịch #${widget.linkedCampaignId}';
      _targetKind = _TargetKind.campaign;
    }
    if (widget.existingPost != null) {
      final FeedPostModel p = widget.existingPost!;
      _title.text = (p.title ?? '').trim();
      _content.text = p.content;
      final String tt = (p.targetType ?? '').toUpperCase();
      if (tt == 'CAMPAIGN' && p.targetId != null) {
        _targetKind = _TargetKind.campaign;
        _campaignTargetId = p.targetId;
        _campaignLabel = (p.targetName ?? '').trim().isNotEmpty
            ? p.targetName!.trim()
            : 'Chiến dịch #${p.targetId}';
        _campaignOptions = <MapEntry<int, String>>[
          MapEntry<int, String>(p.targetId!, _campaignLabel),
        ];
      } else if (tt == 'EXPENDITURE' && p.targetId != null) {
        _targetKind = _TargetKind.expenditure;
        _expenditureTargetId = p.targetId;
        _expenditureLabel = (p.targetName ?? '').trim().isNotEmpty
            ? p.targetName!.trim()
            : 'Đợt chi #${p.targetId}';
      } else {
        _targetKind = _TargetKind.none;
      }
      _visibility = p.visibility.toUpperCase() == 'FOLLOWERS'
          ? 'FOLLOWERS'
          : 'PUBLIC';
      _loadExistingMedia();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _preloadEditTargetOptions();
      });
    } else if (_targetKind == _TargetKind.expenditure &&
        _effectiveCampaignId != null) {
      _loadExpenditureOptions(_effectiveCampaignId!);
    }
    if (_shouldUseDraft) {
      _restoreDraftIfAny();
    }
  }

  /// Edit sheet: tải danh sách chiến dịch (và đợt chi) ngay khi mở — trước đây chỉ tải khi đổi chip.
  Future<void> _preloadEditTargetOptions() async {
    if (!mounted || widget.existingPost == null) return;
    final AuthProvider auth = context.read<AuthProvider>();
    if (_targetKind == _TargetKind.campaign ||
        _targetKind == _TargetKind.expenditure) {
      await _ensureCampaignOptions(auth, force: true);
    }
    if (!mounted) return;
    if (_targetKind == _TargetKind.expenditure &&
        _effectiveCampaignId != null) {
      await _loadExpenditureOptions(_effectiveCampaignId!);
    }
  }

  Future<void> _loadExistingMedia() async {
    final FeedPostModel? p = widget.existingPost;
    if (p == null) return;
    try {
      final Response<dynamic> res = await _api.getMediaByPostId(p.id);
      final List<FeedPostMediaItem> list = parseFeedPostMediaResponse(res.data);
      if (!mounted) return;
      setState(() {
        _existingMedia =
            list.map((FeedPostMediaItem e) => _ExistingMediaSlot(e)).toList();
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _title.removeListener(_saveDraftIfNeeded);
    _content.removeListener(_saveDraftIfNeeded);
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  static int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  /// API có thể trả trùng id; DropdownButton yêu cầu mỗi [value] xuất hiện đúng một lần.
  static List<MapEntry<int, String>> _dedupeEntriesById(
    List<MapEntry<int, String>> items,
  ) {
    final Set<int> seen = <int>{};
    final List<MapEntry<int, String>> out = <MapEntry<int, String>>[];
    for (final MapEntry<int, String> e in items) {
      if (seen.add(e.key)) out.add(e);
    }
    return out;
  }

  int? get _campaignDropdownValue {
    final int? id = _campaignTargetId;
    if (id == null) return null;
    if (_campaignOptions.any((MapEntry<int, String> e) => e.key == id)) {
      return id;
    }
    return null;
  }

  int? get _expenditureDropdownValue {
    final int? id = _expenditureTargetId;
    if (id == null) return null;
    if (_expenditureOptions.any((MapEntry<int, String> e) => e.key == id)) {
      return id;
    }
    return null;
  }

  Future<void> _restoreDraftIfAny() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_draftKey);
    if (!mounted || raw == null || raw.isEmpty) return;
    try {
      _restoringDraft = true;
      final Map<String, dynamic> data = jsonDecode(raw) as Map<String, dynamic>;
      setState(() {
        _title.text = (data['title'] as String?) ?? '';
        _content.text = (data['content'] as String?) ?? '';
        final String tk = (data['targetKind'] as String?) ?? 'none';
        _targetKind = tk == 'campaign'
            ? _TargetKind.campaign
            : tk == 'expenditure'
                ? _TargetKind.expenditure
                : _TargetKind.none;
        _campaignTargetId = _parseInt(data['campaignTargetId']);
        _expenditureTargetId = _parseInt(data['expenditureTargetId']);
        _visibility =
            ((data['visibility'] as String?) ?? 'PUBLIC').toUpperCase() == 'FOLLOWERS'
                ? 'FOLLOWERS'
                : 'PUBLIC';
      });
      await _ensureCampaignOptions(context.read<AuthProvider>());
      if (_targetKind == _TargetKind.expenditure && _effectiveCampaignId != null) {
        await _loadExpenditureOptions(_effectiveCampaignId!);
      }
      if (_campaignTargetId != null) {
        _campaignLabel = _labelForId(_campaignOptions, _campaignTargetId);
      }
      if (_expenditureTargetId != null) {
        _expenditureLabel = _labelForId(_expenditureOptions, _expenditureTargetId);
      }
    } catch (_) {
      await prefs.remove(_draftKey);
    } finally {
      _restoringDraft = false;
    }
  }

  Future<void> _saveDraftIfNeeded() async {
    if (!_shouldUseDraft || _restoringDraft) return;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> data = <String, dynamic>{
      'title': _title.text,
      'content': _content.text,
      'targetKind': _targetKind.name,
      'campaignTargetId': _campaignTargetId,
      'expenditureTargetId': _expenditureTargetId,
      'visibility': _visibility,
    };
    await prefs.setString(_draftKey, jsonEncode(data));
  }

  Future<void> _clearDraftIfNeeded() async {
    if (!_shouldUseDraft) return;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
  }

  String _mediaTypeForPath(String path, {String? mime}) {
    final String m = (mime ?? '').toLowerCase();
    if (m.startsWith('image/')) return 'PHOTO';
    final String lower = path.toLowerCase();
    if (lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif')) {
      return 'PHOTO';
    }
    return 'FILE';
  }

  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> files = await picker.pickMultiImage(imageQuality: 85);
    if (files.isEmpty) return;
    setState(() => _pickedImages.addAll(files));
  }

  Future<void> _pickDocuments() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: <String>[
        'pdf',
        'doc',
        'docx',
        'zip',
        'txt',
        'xls',
        'xlsx',
      ],
    );
    if (result == null || result.files.isEmpty) return;
    setState(() => _pickedFiles.addAll(result.files));
  }

  static void _mergeCampaignRowsIntoMap(
    List<dynamic> rows,
    Map<int, String> byId,
  ) {
    for (final dynamic row in rows) {
      if (row is! Map<String, dynamic>) continue;
      final int? id = _parseInt(row['id']);
      final String title = (row['title'] as String?)?.trim() ?? '';
      if (id == null) continue;
      byId.putIfAbsent(
        id,
        () => title.isEmpty ? 'Chiến dịch #$id' : title,
      );
    }
  }

  /// Chỉ chiến dịch do user làm chủ quỹ (parity web modal `/post`).
  Future<_CampaignPickResult> _loadCampaignTitles(int userId) async {
    final Map<int, String> byId = <int, String>{};
    const int size = 50;
    int page = 0;
    bool fetchedOk = false;

    while (true) {
      try {
        final Response<dynamic> r =
            await _api.getUserCampaigns(userId, page: page, size: size);
        fetchedOk = true;
        final dynamic data = r.data;
        if (data is! Map<String, dynamic>) break;
        final List<dynamic> content = data['content'] as List<dynamic>? ??
            data['items'] as List<dynamic>? ??
            <dynamic>[];
        if (content.isEmpty) break;
        _mergeCampaignRowsIntoMap(content, byId);
        if (content.length < size) break;
        page++;
      } catch (_) {
        if (!fetchedOk) {
          throw Exception('campaigns_fetch_failed');
        }
        break;
      }
    }

    final List<MapEntry<int, String>> entries = byId.entries.toList()
      ..sort(
        (MapEntry<int, String> a, MapEntry<int, String> b) =>
            a.value.toLowerCase().compareTo(b.value.toLowerCase()),
      );
    return _CampaignPickResult(
      ids: entries.map((MapEntry<int, String> e) => e.key).toList(),
      titles: entries.map((MapEntry<int, String> e) => e.value).toList(),
    );
  }

  int? get _effectiveCampaignId => widget.linkedCampaignId ?? _campaignTargetId;

  bool get _isTargetSelectionValid {
    switch (_targetKind) {
      case _TargetKind.none:
        return true;
      case _TargetKind.campaign:
        if (widget.linkedCampaignId != null) return true;
        return _campaignTargetId != null &&
            _campaignOptions.any((MapEntry<int, String> e) => e.key == _campaignTargetId);
      case _TargetKind.expenditure:
        final int? cid = widget.linkedCampaignId ?? _campaignTargetId;
        if (cid == null) return false;
        if (widget.linkedCampaignId == null &&
            (_campaignTargetId == null ||
                !_campaignOptions.any((MapEntry<int, String> e) => e.key == _campaignTargetId))) {
          return false;
        }
        return _expenditureTargetId != null &&
            _expenditureOptions.any((MapEntry<int, String> e) => e.key == _expenditureTargetId);
    }
  }

  void _showSnackBar(String message, {bool isError = false, bool isSuccess = false}) {
    if (!mounted) return;
    final Color bg = isError
        ? Colors.red.shade800
        : isSuccess
            ? Colors.green.shade800
            : Colors.grey.shade900;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        backgroundColor: bg,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  bool get _canSubmit {
    return !_submitting &&
        (_content.text.trim().isNotEmpty || _title.text.trim().isNotEmpty) &&
        _isTargetSelectionValid;
  }

  String _labelForId(List<MapEntry<int, String>> options, int? id) {
    if (id == null) return '';
    for (final MapEntry<int, String> e in options) {
      if (e.key == id) return e.value;
    }
    return '';
  }

  Future<void> _ensureCampaignOptions(AuthProvider auth, {bool force = false}) async {
    if (_loadingCampaignOptions) return;
    if (!force && _campaignOptionsLoaded) return;
    if (auth.user == null) {
      if (!mounted) return;
      setState(() {
        _campaignOptionsLoaded = true;
        _campaignListError = 'Vui lòng đăng nhập để chọn chiến dịch.';
      });
      return;
    }

    setState(() {
      _loadingCampaignOptions = true;
      if (force) _campaignListError = null;
    });
    try {
      final _CampaignPickResult res = await _loadCampaignTitles(auth.user!.id);
      if (!mounted) return;
      setState(() {
        List<MapEntry<int, String>> options = _dedupeEntriesById(
          List<MapEntry<int, String>>.generate(
            res.ids.length,
            (int i) => MapEntry<int, String>(res.ids[i], res.titles[i]),
          ),
        );
        if (_isEdit &&
            _targetKind == _TargetKind.campaign &&
            _campaignTargetId != null &&
            !options.any((MapEntry<int, String> e) => e.key == _campaignTargetId)) {
          final String orphanLabel = _campaignLabel.trim().isNotEmpty
              ? _campaignLabel
              : 'Chiến dịch #${_campaignTargetId!}';
          options = <MapEntry<int, String>>[
            MapEntry<int, String>(_campaignTargetId!, orphanLabel),
            ...options,
          ];
        }
        _campaignOptions = options;
        _campaignListError = options.isEmpty
            ? 'Bạn chưa có chiến dịch nào. Tạo chiến dịch trước khi gắn bài viết.'
            : null;
        if (!_isEdit &&
            !_isLockedLinkedCampaign &&
            _campaignTargetId != null &&
            !options.any((MapEntry<int, String> e) => e.key == _campaignTargetId)) {
          _campaignTargetId = null;
          _campaignLabel = '';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _campaignListError =
            'Không tải được danh sách chiến dịch. Kiểm tra mạng và thử lại.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingCampaignOptions = false;
          _campaignOptionsLoaded = true;
        });
      }
    }
  }

  Future<void> _loadExpenditureOptions(int campaignId) async {
    if (_loadingExpenditureOptions) return;
    setState(() => _loadingExpenditureOptions = true);
    try {
      final Response<dynamic> res = await _api.getExpendituresByCampaign(campaignId);
      final dynamic data = res.data;
      if (data is! List<dynamic> || data.isEmpty) {
        if (!mounted) return;
        setState(() {
          _expenditureOptions = <MapEntry<int, String>>[];
          _loadingExpenditureOptions = false;
        });
        return;
      }
      final List<MapEntry<int, String>> options = <MapEntry<int, String>>[];
      for (final Map<String, dynamic> row in data.whereType<Map<String, dynamic>>()) {
        final int? eid = _parseInt(row['id']);
        if (eid == null) continue;
        final String plan = (row['plan'] as String?)?.trim() ?? '';
        options.add(MapEntry<int, String>(eid, plan.isNotEmpty ? plan : 'Đợt chi #$eid'));
      }
      final List<MapEntry<int, String>> deduped = _dedupeEntriesById(options);
      if (!mounted) return;
      setState(() {
        _expenditureOptions = deduped;
        if (_expenditureTargetId != null &&
            !deduped.any((MapEntry<int, String> e) => e.key == _expenditureTargetId)) {
          _expenditureTargetId = null;
          _expenditureLabel = '';
        }
        _loadingExpenditureOptions = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loadingExpenditureOptions = false);
      }
    }
  }

  Future<void> _setTargetKind(_TargetKind k, AuthProvider auth) async {
    setState(() {
      _targetKind = k;
      _targetValidationError = null;
      if (k == _TargetKind.none) {
        _expenditureTargetId = null;
        _expenditureLabel = '';
        if (widget.linkedCampaignId != null) {
          _campaignTargetId = widget.linkedCampaignId;
          _campaignLabel = widget.linkedCampaignTitle ??
              'Chiến dịch #${widget.linkedCampaignId}';
        } else {
          _campaignTargetId = null;
          _campaignLabel = '';
        }
        _expenditureOptions = <MapEntry<int, String>>[];
      } else {
        _expenditureTargetId = null;
        _expenditureLabel = '';
        _expenditureOptions = <MapEntry<int, String>>[];
      }
    });
    await _ensureCampaignOptions(auth, force: false);
    if (k == _TargetKind.expenditure) {
      final int? cid = _effectiveCampaignId;
      if (cid != null) {
        await _loadExpenditureOptions(cid);
      }
    }
    await _saveDraftIfNeeded();
  }

  Map<String, dynamic> _targetBody() {
    switch (_targetKind) {
      case _TargetKind.none:
        return <String, dynamic>{'targetId': null, 'targetType': null};
      case _TargetKind.campaign:
        final int? id = widget.linkedCampaignId ?? _campaignTargetId;
        if (id == null) {
          return <String, dynamic>{'targetId': null, 'targetType': null};
        }
        return <String, dynamic>{'targetId': id, 'targetType': 'CAMPAIGN'};
      case _TargetKind.expenditure:
        if (_expenditureTargetId == null) {
          return <String, dynamic>{'targetId': null, 'targetType': null};
        }
        return <String, dynamic>{
          'targetId': _expenditureTargetId,
          'targetType': 'EXPENDITURE',
        };
    }
  }

  Future<void> _uploadOneFile({
    required File file,
    required String mediaType,
    required int postId,
  }) async {
    final Response<dynamic> up = await _api.uploadMedia(
      file,
      postId: postId,
      mediaType: mediaType,
    );
    final dynamic u = up.data;
    if (u is Map<String, dynamic>) {
      final int? mid = _parseInt(u['id']);
      if (mid != null) {
        await _api.updateMedia(mid, <String, dynamic>{'postId': postId});
      }
    }
  }

  String _friendlySubmitError(Object error, {required bool isEdit}) {
    if (error is DioException) {
      final int? status = error.response?.statusCode;
      final dynamic data = error.response?.data;
      final String? apiMessage = data is Map<String, dynamic>
          ? (data['message'] as String?)?.trim()
          : null;
      final String apiMessageLower = apiMessage?.toLowerCase() ?? '';
      if (status == 401) return 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
      if (status == 403) return 'Bạn không có quyền thực hiện thao tác này.';
      if (status == 422 || status == 400) {
        if (apiMessageLower.contains('invalid input data') ||
            apiMessageLower.contains('invalid input')) {
          return 'Dữ liệu chưa hợp lệ. Vui lòng nhập nội dung bài viết.';
        }
        return apiMessage?.isNotEmpty == true
            ? apiMessage!
            : 'Dữ liệu bài viết chưa hợp lệ. Vui lòng kiểm tra lại.';
      }
      if (status != null && status >= 500) {
        return 'Máy chủ đang bận. Vui lòng thử lại sau.';
      }
      if (apiMessage?.isNotEmpty == true) return apiMessage!;
    }
    return isEdit ? 'Cập nhật bài viết thất bại.' : 'Đăng bài thất bại.';
  }

  Future<void> _submit(AuthProvider auth, {required String nextStatus}) async {
    if (_submitting) return;
    if (!auth.isLoggedIn || auth.user == null) {
      _showSnackBar('Vui lòng đăng nhập.', isError: true);
      return;
    }
    final String raw = _content.text.trim();
    final String titleTrim = _title.text.trim();
    if (raw.isEmpty) {
      _showSnackBar('Vui lòng nhập nội dung bài viết.', isError: true);
      return;
    }
    if (raw.isEmpty && titleTrim.isEmpty) {
      _showSnackBar('Vui lòng nhập tiêu đề hoặc nội dung.', isError: true);
      return;
    }
    final String titleText = titleTrim.isEmpty ? raw : titleTrim;
    final String titlePayload =
        titleText.length > 50 ? titleText.substring(0, 50) : titleText;
    final String contentPayload =
        raw.length > 2000 ? raw.substring(0, 2000) : raw;

    final int? effectiveCampaignId = widget.linkedCampaignId ?? _campaignTargetId;
    if (_visibility == 'FOLLOWERS' && effectiveCampaignId == null) {
      _showSnackBar(
        'Bài viết follower-only cần gắn với một campaign.',
        isError: true,
      );
      return;
    }
    if (_targetKind == _TargetKind.campaign &&
        (effectiveCampaignId == null ||
            (widget.linkedCampaignId == null &&
                !_campaignOptions.any((MapEntry<int, String> e) => e.key == _campaignTargetId)))) {
      setState(() {
        _targetValidationError = 'Bạn đang chọn mục tiêu Chiến dịch. Vui lòng chọn chiến dịch.';
      });
      _showSnackBar('Vui lòng chọn chiến dịch trước khi đăng bài.', isError: true);
      return;
    }
    if (_targetKind == _TargetKind.expenditure) {
      if (effectiveCampaignId == null) {
        setState(() {
          _targetValidationError = 'Vui lòng chọn chiến dịch trước khi chọn đợt chi.';
        });
        _showSnackBar('Bạn cần chọn chiến dịch trước.', isError: true);
        return;
      }
      if (_expenditureTargetId == null) {
        setState(() {
          _targetValidationError = 'Bạn đang chọn mục tiêu Đợt chi. Vui lòng chọn đợt chi cụ thể.';
        });
        _showSnackBar('Vui lòng chọn đợt chi trước khi đăng bài.', isError: true);
        return;
      }
    }

    setState(() => _submitting = true);
    try {
      if (_isEdit) {
        final FeedPostModel p = widget.existingPost!;

        // Step 1: update() FIRST — triggers snapshotRevision() which captures
        // the BEFORE state (old text + old media still linked). Must happen
        // before any media changes so the revision snapshot is accurate.
        final Map<String, dynamic> target = _targetBody();
        await _api.updateFeedPost(
          p.id,
          <String, dynamic>{
            'title': titlePayload,
            'content': contentPayload,
            'status': nextStatus,
            'visibility': _visibility,
            ...target,
          },
        );

        // Step 2: Delete removed images AFTER snapshot captured old state
        for (final _ExistingMediaSlot slot in _existingMedia) {
          if (slot.markedForDelete && slot.item.id > 0) {
            try {
              await _api.deleteMedia(slot.item.id);
            } catch (_) {}
          }
        }

        // Step 3: Upload new images/files
        int failUploads = 0;
        for (final XFile x in _pickedImages) {
          try {
            final File f = File(x.path);
            await _uploadOneFile(
              file: f,
              mediaType: _mediaTypeForPath(x.path),
              postId: p.id,
            );
          } catch (_) {
            failUploads++;
          }
        }
        for (final PlatformFile pf in _pickedFiles) {
          if (pf.path == null) continue;
          try {
            await _uploadOneFile(
              file: File(pf.path!),
              mediaType: _mediaTypeForPath(pf.path!),
              postId: p.id,
            );
          } catch (_) {
            failUploads++;
          }
        }
        if (!mounted) return;
        widget.onUpdated?.call();
        _showSnackBar(
          failUploads > 0
              ? 'Đã cập nhật bài. $failUploads tệp tải lên lỗi.'
              : 'Đã cập nhật bài.',
          isSuccess: failUploads == 0,
          isError: failUploads > 0,
        );
        Navigator.of(context).pop();
      } else {
        final Map<String, dynamic> target = _targetBody();
        final Response<dynamic> response = await _api.createFeedPost(
          <String, dynamic>{
            'type': 'DISCUSSION',
            'visibility': _visibility,
            'title': titlePayload,
            'content': contentPayload,
            'status': nextStatus,
            ...target,
          },
        );

        if (response.statusCode != 200 && response.statusCode != 201) {
          throw Exception('Tạo bài thất bại');
        }

        final dynamic data = response.data;
        int? postId;
        if (data is Map<String, dynamic>) {
          postId = _parseInt(data['id']);
        }

        int failUploads = 0;
        if (postId != null) {
          for (final XFile x in _pickedImages) {
            try {
              await _uploadOneFile(
                file: File(x.path),
                mediaType: _mediaTypeForPath(x.path),
                postId: postId,
              );
            } catch (_) {
              failUploads++;
            }
          }
          for (final PlatformFile pf in _pickedFiles) {
            if (pf.path == null) continue;
            try {
              await _uploadOneFile(
                file: File(pf.path!),
                mediaType: _mediaTypeForPath(pf.path!),
                postId: postId,
              );
            } catch (_) {
              failUploads++;
            }
          }
        }

        if (!mounted) return;
        widget.onCreated?.call();
        await _clearDraftIfNeeded();
        _showSnackBar(
          failUploads > 0
              ? 'Đã đăng bài. $failUploads tệp tải lên lỗi.'
              : 'Đã đăng bài.',
          isSuccess: failUploads == 0,
          isError: failUploads > 0,
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(_friendlySubmitError(e, isEdit: _isEdit), isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  InputDecoration _fieldDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: Color(0xFF6B7280),
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _primary, width: 1.5),
      ),
      floatingLabelStyle: const TextStyle(
        color: _primary,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
    );
  }

  Widget _choiceTargetChip({
    required String label,
    required bool selected,
    required ValueChanged<bool>? onSelected,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor: const Color(0xFFEFF6FF),
      backgroundColor: Colors.white,
      side: BorderSide(
        color: selected ? const Color(0xFFBFDBFE) : const Color(0xFFE5E7EB),
      ),
      labelStyle: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 13,
        color: selected ? const Color(0xFF1E40AF) : const Color(0xFF4B5563),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onSelected: onSelected,
    );
  }

  Widget _campaignLoadStatus(AuthProvider auth) {
    if (_campaignListError == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.warning_amber_rounded, size: 20, color: Colors.red.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _campaignListError!,
                  style: TextStyle(
                    color: Colors.red.shade900,
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: _loadingCampaignOptions || _submitting
                    ? null
                    : () => _ensureCampaignOptions(auth, force: true),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();
    final MediaQueryData mq = MediaQuery.of(context);
    final double bottomSafe = mq.viewPadding.bottom;

    return Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: true,
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(8 + kToolbarHeight),
          child: Container(
            padding: const EdgeInsets.only(top: 8),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Color(0xFFF3F4F6), width: 1),
              ),
            ),
            child: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              foregroundColor: const Color(0xFF111827),
              centerTitle: true,
              automaticallyImplyLeading: false,
              title: Text(
                _isEdit ? 'Chỉnh sửa bài viết' : 'Đăng bài lên feed',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ),
        body: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: bottomSafe + 20,
          ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
            Text(
              'Gắn mục tiêu',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                letterSpacing: -0.2,
                color: Colors.grey.shade900,
              ),
            ),
            const SizedBox(height: 10),
            if (_isTargetLocked)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _targetKind == _TargetKind.campaign
                      ? 'Đã gắn chiến dịch${_campaignLabel.isNotEmpty ? ': $_campaignLabel' : ''} (không thể đổi)'
                      : 'Đã gắn đợt chi${_expenditureLabel.isNotEmpty ? ': $_expenditureLabel' : ''} (không thể đổi)',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF92400E),
                  ),
                ),
              )
            else if (_isLockedLinkedCampaign)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  widget.linkedCampaignTitle != null
                      ? 'Luôn gắn: ${widget.linkedCampaignTitle}'
                      : 'Luôn gắn chiến dịch hiện tại.',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF166534),
                  ),
                ),
              )
            else
              DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFF3F4F6)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      _choiceTargetChip(
                        label: 'Không',
                        selected: _targetKind == _TargetKind.none,
                        onSelected: (_submitting || _isTargetLocked)
                            ? null
                            : (_) => _setTargetKind(_TargetKind.none, auth),
                      ),
                      _choiceTargetChip(
                        label: 'Chiến dịch',
                        selected: _targetKind == _TargetKind.campaign,
                        onSelected: (_submitting || _isTargetLocked)
                            ? null
                            : (_) => _setTargetKind(_TargetKind.campaign, auth),
                      ),
                      _choiceTargetChip(
                        label: 'Đợt chi',
                        selected: _targetKind == _TargetKind.expenditure,
                        onSelected: (_submitting || _isTargetLocked)
                            ? null
                            : (_) => _setTargetKind(_TargetKind.expenditure, auth),
                      ),
                    ],
                  ),
                ),
              ),
            if (_targetKind == _TargetKind.campaign && !_isLockedLinkedCampaign && !_isTargetLocked) ...<Widget>[
              const SizedBox(height: 16),
              DropdownButtonFormField<int?>(
                value: _campaignDropdownValue,
                isExpanded: true,
                decoration: _fieldDecoration('Chọn chiến dịch'),
                items: <DropdownMenuItem<int?>>[
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Chọn chiến dịch...'),
                  ),
                  ..._campaignOptions.map(
                    (MapEntry<int, String> e) => DropdownMenuItem<int?>(
                      value: e.key,
                      child: Text(e.value, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: _submitting || _loadingCampaignOptions
                    ? null
                    : (int? v) {
                        setState(() {
                          _campaignTargetId = v;
                          _campaignLabel = _labelForId(_campaignOptions, v);
                          _targetValidationError = null;
                        });
                        _saveDraftIfNeeded();
                      },
              ),
              if (_loadingCampaignOptions)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: LinearProgressIndicator(minHeight: 3),
                ),
              _campaignLoadStatus(auth),
              if (_campaignLabel.isNotEmpty && !_isLockedLinkedCampaign)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Đã chọn: $_campaignLabel',
                    style: const TextStyle(
                      color: Color(0xFF166534),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
            if (_targetKind == _TargetKind.expenditure && !_isTargetLocked) ...<Widget>[
              const SizedBox(height: 16),
              if (widget.linkedCampaignId == null) ...<Widget>[
                DropdownButtonFormField<int?>(
                  value: _campaignDropdownValue,
                  isExpanded: true,
                  decoration: _fieldDecoration('Chọn chiến dịch'),
                  items: <DropdownMenuItem<int?>>[
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Chọn chiến dịch...'),
                    ),
                    ..._campaignOptions.map(
                      (MapEntry<int, String> e) => DropdownMenuItem<int?>(
                        value: e.key,
                        child: Text(e.value, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: _submitting || _loadingCampaignOptions
                      ? null
                      : (int? v) async {
                          setState(() {
                            _campaignTargetId = v;
                            _expenditureTargetId = null;
                            _expenditureLabel = '';
                            _targetValidationError = null;
                          });
                          if (v != null) {
                            await _loadExpenditureOptions(v);
                          } else {
                            setState(() {
                              _expenditureOptions = <MapEntry<int, String>>[];
                            });
                          }
                          _saveDraftIfNeeded();
                        },
                ),
                if (_loadingCampaignOptions)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(minHeight: 3),
                  ),
                _campaignLoadStatus(auth),
              ] else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.campaign_outlined, color: Color(0xFF4B5563), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.linkedCampaignTitle ?? 'Chiến dịch #${widget.linkedCampaignId}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                value: _expenditureDropdownValue,
                isExpanded: true,
                decoration: _fieldDecoration('Chọn đợt chi'),
                items: <DropdownMenuItem<int?>>[
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Chọn đợt chi...'),
                  ),
                  ..._expenditureOptions.map(
                    (MapEntry<int, String> e) => DropdownMenuItem<int?>(
                      value: e.key,
                      child: Text(e.value, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: _submitting || _loadingExpenditureOptions || _effectiveCampaignId == null
                    ? null
                    : (int? v) {
                        setState(() {
                          _expenditureTargetId = v;
                          _expenditureLabel = _labelForId(_expenditureOptions, v);
                          _targetValidationError = null;
                        });
                        _saveDraftIfNeeded();
                      },
              ),
              if (_loadingExpenditureOptions)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              if (!_loadingExpenditureOptions &&
                  _effectiveCampaignId != null &&
                  _expenditureOptions.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'Chiến dịch chưa có đợt chi để chọn.',
                    style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                  ),
                ),
              if (_expenditureLabel.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Đã chọn: $_expenditureLabel',
                    style: const TextStyle(
                      color: Color(0xFF166534),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
            if (_targetValidationError != null) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                _targetValidationError!,
                style: const TextStyle(
                  color: Color(0xFFDC2626),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              textInputAction: TextInputAction.next,
              decoration: _fieldDecoration('Tiêu đề (tuỳ chọn)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _content,
              minLines: 4,
              maxLines: 10,
              onChanged: (_) => setState(() {}),
              decoration: _fieldDecoration('Nội dung *').copyWith(
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: <Widget>[
                  const Text(
                    'Người xem:',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Công khai'),
                    selected: _visibility == 'PUBLIC',
                    onSelected: _submitting
                        ? null
                        : (_) {
                            setState(() => _visibility = 'PUBLIC');
                            _saveDraftIfNeeded();
                          },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Follower'),
                    selected: _visibility == 'FOLLOWERS',
                    onSelected: _submitting
                        ? null
                        : (_) {
                            setState(() => _visibility = 'FOLLOWERS');
                            _saveDraftIfNeeded();
                          },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_isEdit && _existingMedia.isNotEmpty) ...<Widget>[
              const Text(
                'Ảnh / tệp hiện có',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _existingMedia.map((_ExistingMediaSlot s) {
                  if (s.markedForDelete) {
                    return Chip(
                      label: Text('Đã xóa #${s.item.id}'),
                      onDeleted: () => setState(() => s.markedForDelete = false),
                    );
                  }
                  return InputChip(
                    label: Text(
                      s.item.fileName ??
                          (s.item.isPhoto ? 'Ảnh #${s.item.id}' : 'Tệp #${s.item.id}'),
                    ),
                    onDeleted: () => setState(() => s.markedForDelete = true),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _submitting ? null : _pickImages,
                    icon: const Icon(Icons.add_photo_alternate_outlined, size: 20),
                    label: Text('Ảnh (${_pickedImages.length})'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF374151),
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _submitting ? null : _pickDocuments,
                    icon: const Icon(Icons.attach_file, size: 20),
                    label: Text('Tệp (${_pickedFiles.length})'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF374151),
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_pickedImages.isNotEmpty)
              SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _pickedImages.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, int i) {
                    return Stack(
                      clipBehavior: Clip.none,
                      children: <Widget>[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            File(_pickedImages[i].path),
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: -6,
                          right: -6,
                          child: IconButton(
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black87,
                              padding: const EdgeInsets.all(2),
                              minimumSize: const Size(24, 24),
                            ),
                            icon: const Icon(Icons.close, color: Colors.white, size: 14),
                            onPressed: _submitting
                                ? null
                                : () => setState(() => _pickedImages.removeAt(i)),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            if (_pickedFiles.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              for (int fi = 0; fi < _pickedFiles.length; fi++)
                ListTile(
                  dense: true,
                  title: Text(_pickedFiles[fi].name),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _submitting
                        ? null
                        : () => setState(() => _pickedFiles.removeAt(fi)),
                  ),
                ),
            ],
            const SizedBox(height: 20),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _canSubmit && !_submitting
                        ? () => _submit(auth, nextStatus: 'DRAFT')
                        : null,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFFF59E0B)),
                      foregroundColor: const Color(0xFFB45309),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Lưu bản nháp',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _canSubmit ? () => _submit(auth, nextStatus: 'PUBLISHED') : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _isEdit ? 'Lưu thay đổi' : 'Đăng bài ngay',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              letterSpacing: -0.2,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
}
