import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client_new/socket_io_client_new.dart' as io;
import '../core/api/api_endpoints.dart';
import 'token_storage_service.dart';

/// Socket.IO service for real-time chat messages.
/// Connects at /api/socket.io with auth token.
class ChatWebSocketService {
  ChatWebSocketService._();
  static final ChatWebSocketService instance = ChatWebSocketService._();

  io.Socket? _socket;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onMessage => _messageController.stream;
  String? _currentConversationId;
  bool _isConnecting = false;

  bool get isConnected => _socket?.connected ?? false;
  String? get currentConversationId => _currentConversationId;

  /// Connect and subscribe to a conversation.
  Future<void> connect(String conversationId) async {
    if (_currentConversationId == conversationId && isConnected) return;
    if (_isConnecting) return;
    _isConnecting = true;
    await disconnect();

    try {
      final token = await TokenStorageService.instance.getAccessToken();
      if (token == null || token.isEmpty) {
        if (kDebugMode) print('❌ ChatSocket: No auth token');
        _isConnecting = false;
        return;
      }

      final baseUrl = ApiEndpoints.chatSocketBaseUrl;
      if (kDebugMode)
        print('🔌 ChatSocket: Connecting to $baseUrl path /api/socket.io');

      _socket = io.io(
        baseUrl,
        io.OptionBuilder()
            .setPath('/api/socket.io')
            .setAuth({'token': token})
            .setTransports(['websocket', 'polling'])
            .enableForceNew()
            .build(),
      );

      _currentConversationId = conversationId;

      _socket!
        ..onConnect((_) {
          if (kDebugMode) print('✅ ChatSocket: connected');
          _socket?.emit('subscribe', {'conversationId': conversationId});
        })
        ..onConnectError((e) {
          if (kDebugMode) print('❌ ChatSocket connectError: ${e ?? "unknown"}');
        })
        ..onError((e) {
          if (kDebugMode) print('❌ ChatSocket error: ${e ?? "unknown"}');
        })
        ..onDisconnect((_) {
          if (kDebugMode) print('🔌 ChatSocket: disconnected');
        })
        ..on('message', _onMessage)
        ..on('new_message', _onMessage)
        ..on('chat:message', _onMessage);

      _socket!.connect();
    } catch (e, st) {
      if (kDebugMode) {
        print('❌ ChatSocket connect error: $e');
        print(st);
      }
    } finally {
      _isConnecting = false;
    }
  }

  void _onMessage(dynamic data) {
    try {
      Map<String, dynamic>? msg;
      if (data is Map) {
        msg = Map<String, dynamic>.from(data);
      } else if (data is List && data.isNotEmpty && data[0] is Map) {
        msg = Map<String, dynamic>.from(data[0] as Map);
      }
      if (msg != null) {
        final extracted = msg['message'] ?? msg['data'] ?? msg;
        final m = extracted is Map ? Map<String, dynamic>.from(extracted) : msg;
        if (_messageController.hasListener) {
          _messageController.add(m);
        }
      }
    } catch (e) {
      if (kDebugMode) print('❌ ChatSocket parse error: $e');
    }
  }

  /// Disconnect and cleanup.
  Future<void> disconnect() async {
    _currentConversationId = null;
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  void dispose() {
    disconnect();
    _messageController.close();
  }
}
