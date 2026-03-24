
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import '../api/api_service.dart';
import '../constants/api_constants.dart';
import '../models/chat_models.dart';
import 'auth_provider.dart';

class ChatProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final AuthProvider _authProvider;
  
  StompClient? _stompClient;
  List<ChatMessage> _messages = [];
  Conversation? _currentConversation;
  bool _isLoading = false;
  bool _isConnected = false;
  String? _staffName;

  List<ChatMessage> get messages => _messages;
  Conversation? get currentConversation => _currentConversation;
  bool get isLoading => _isLoading;
  bool get isConnected => _isConnected;
  String? get staffName => _staffName;

  ChatProvider(this._authProvider);

  // 1. Fetch old messages
  Future<void> fetchMessages(int conversationId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _apiService.getMessagesByConversationId(conversationId);
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        final currentUserId = _authProvider.user?.id ?? 0;
        _messages = data.map((m) => ChatMessage.fromJson(m, currentUserId)).toList();
        // Sort by date ascending for display
        _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      }
    } catch (e) {
      debugPrint("Error fetching messages: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 2. Load or Create Conversation
  Future<void> initConversation(int campaignId, int? passedStaffId) async {
    _isLoading = true;
    _currentConversation = null;
    _messages = [];
    _staffName = null;
    notifyListeners();

    try {
      final currentUserId = _authProvider.user?.id;
      debugPrint("ChatProvider: initConversation for campaign $campaignId, user: $currentUserId");
      if (currentUserId == null) {
        debugPrint("ChatProvider: User ID is null, cannot init conversation");
        return;
      }

      int? finalStaffId = passedStaffId;

      // 1. Fetch assigned staff from Campaign Task if not passed
      try {
        final taskRes = await _apiService.getTaskByCampaignId(campaignId);
        if (taskRes.statusCode == 200 && taskRes.data['staffId'] != null) {
          finalStaffId = taskRes.data['staffId'];
        }
      } catch (e) {
        debugPrint("ChatProvider: Error fetching task for campaign: $e");
      }

      // 2. Fetch staff name
      if (finalStaffId != null) {
        try {
          final staffRes = await _apiService.getUserById(finalStaffId);
          if (staffRes.statusCode == 200 && staffRes.data['fullName'] != null) {
            _staffName = staffRes.data['fullName'];
            notifyListeners(); // Update UI with staff name ASAP
          }
        } catch (e) {
          debugPrint("ChatProvider: Error fetching staff info: $e");
        }
      }

      // Try fetching existing
      try {
        final response = await _apiService.getConversationByCampaignId(campaignId);
        if (response.statusCode == 200) {
          _currentConversation = Conversation.fromJson(response.data);
        }
      } catch (e) {
        // If 404, we create
        debugPrint("Conversation not found, creating new one...");
        final createRes = await _apiService.createConversation(
          fundOwnerId: currentUserId,
          campaignId: campaignId,
          staffId: finalStaffId,
        );
        if (createRes.statusCode == 201 || createRes.statusCode == 200) {
          _currentConversation = Conversation.fromJson(createRes.data);
        }
      }

      if (_currentConversation != null) {
        await fetchMessages(_currentConversation!.id);
        _connectWebSocket();
      }
    } catch (e) {
      debugPrint("Error initializing conversation: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 3. WebSocket Connection
  Future<void> _connectWebSocket() async {
    if (_stompClient != null && _stompClient!.isActive) return;
    if (_currentConversation == null) return;

    final String? token = await _authProvider.token;

    _stompClient = StompClient(
      config: StompConfig(
        url: ApiConfig.chatWsUrl,
        onConnect: (frame) => _onConnect(frame),
        onWebSocketError: (error) => debugPrint("WS Error: $error"),
        stompConnectHeaders: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
        webSocketConnectHeaders: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
        onDisconnect: (frame) {
           _isConnected = false;
           notifyListeners();
        },
      ),
    );
    _stompClient!.activate();
  }

  void _onConnect(StompFrame frame) {
    _isConnected = true;
    notifyListeners();

    _stompClient!.subscribe(
      destination: '/topic/conversation/${_currentConversation!.id}',
      callback: (frame) {
        if (frame.body != null) {
          final Map<String, dynamic> msgData = jsonDecode(frame.body!);
          final currentUserId = _authProvider.user?.id ?? 0;
          final ChatMessage newMessage = ChatMessage.fromJson(msgData, currentUserId);
          
          // Add if not exists
          if (!_messages.any((m) => m.id == newMessage.id)) {
            _messages.add(newMessage);
            _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
            notifyListeners();
          }
        }
      },
    );
  }

  // 4. Send Message
  void sendMessage(String content) {
    if (_stompClient == null || !_stompClient!.isActive || _currentConversation == null) return;
    if (content.trim().isEmpty) return;

    final currentUserId = _authProvider.user?.id ?? 0;
    final Map<String, dynamic> body = {
      'conversationId': _currentConversation!.id,
      'content': content.trim(),
      'senderId': currentUserId,
      'senderRole': _authProvider.user?.role ?? 'ROLE_FUND_OWNER',
    };

    _stompClient!.send(
      destination: '/app/chat/${_currentConversation!.id}',
      body: jsonEncode(body),
    );
  }

  @override
  void dispose() {
    _stompClient?.deactivate();
    super.dispose();
  }
}
