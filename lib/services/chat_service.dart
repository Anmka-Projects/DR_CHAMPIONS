import 'package:flutter/foundation.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';

/// Chat service for teacher-student messaging.
/// Uses /api/chat/conversations and /api/chat/conversations/:id/messages.
class ChatService {
  ChatService._();
  static final ChatService instance = ChatService._();

  /// List conversations (paginated).
  Future<Map<String, dynamic>> getConversations({
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final uri = Uri.parse(ApiEndpoints.chatConversations).replace(
        queryParameters: {
          'page': page.toString(),
          'limit': limit.toString(),
        },
      );
      final response = await ApiClient.instance.get(
        uri.toString(),
        requireAuth: true,
      );
      if (response['success'] == true) {
        final data = response['data'];
        if (data is Map<String, dynamic>) return data;
        if (data is Map) return Map<String, dynamic>.from(data);
        return {'conversations': data ?? [], 'meta': {}};
      }
      throw Exception(response['message'] ?? 'Failed to load conversations');
    } catch (e) {
      if (kDebugMode) print('❌ ChatService.getConversations: $e');
      rethrow;
    }
  }

  /// Create or get conversation with another user.
  Future<Map<String, dynamic>> createOrGetConversation(
      String otherUserId) async {
    try {
      final response = await ApiClient.instance.post(
        ApiEndpoints.chatConversations,
        body: {'otherUserId': otherUserId},
        requireAuth: true,
      );
      if (response['success'] == true && response['data'] != null) {
        final data = response['data'];
        if (data is Map<String, dynamic>) return data;
        if (data is Map) return Map<String, dynamic>.from(data);
        return {'data': data};
      }
      throw Exception(response['message'] ?? 'Failed to create conversation');
    } catch (e) {
      if (kDebugMode) print('❌ ChatService.createOrGetConversation: $e');
      rethrow;
    }
  }

  /// Get messages for a conversation.
  Future<Map<String, dynamic>> getMessages(
    String conversationId, {
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final uri = Uri.parse(
        ApiEndpoints.chatMessages(conversationId),
      ).replace(
        queryParameters: {
          'page': page.toString(),
          'limit': limit.toString(),
        },
      );
      final response = await ApiClient.instance.get(
        uri.toString(),
        requireAuth: true,
      );
      if (response['success'] == true) {
        final data = response['data'];
        if (data is Map<String, dynamic>) return data;
        if (data is Map) return Map<String, dynamic>.from(data);
        return {'messages': data ?? [], 'meta': {}};
      }
      throw Exception(response['message'] ?? 'Failed to load messages');
    } catch (e) {
      if (kDebugMode) print('❌ ChatService.getMessages: $e');
      rethrow;
    }
  }

  /// Send a message.
  Future<Map<String, dynamic>> sendMessage(
    String conversationId, {
    required String body,
  }) async {
    try {
      final response = await ApiClient.instance.post(
        ApiEndpoints.chatMessages(conversationId),
        body: {'body': body},
        requireAuth: true,
      );
      if (response['success'] == true) {
        final data = response['data'];
        if (data is Map<String, dynamic>) return data;
        if (data is Map) return Map<String, dynamic>.from(data);
        return {};
      }
      throw Exception(response['message'] ?? 'Failed to send message');
    } catch (e) {
      if (kDebugMode) print('❌ ChatService.sendMessage: $e');
      rethrow;
    }
  }

  /// Mark message as read.
  Future<void> markMessageRead(String messageId) async {
    try {
      final response = await ApiClient.instance.patch(
        ApiEndpoints.chatMessageRead(messageId),
        body: {},
        requireAuth: true,
      );
      if (response['success'] != true) {
        throw Exception(response['message'] ?? 'Failed to mark as read');
      }
    } catch (e) {
      if (kDebugMode) print('❌ ChatService.markMessageRead: $e');
      rethrow;
    }
  }
}
