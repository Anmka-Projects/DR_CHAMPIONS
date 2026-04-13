import 'package:flutter/foundation.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';

/// Service for notifications
class NotificationsService {
  NotificationsService._();
  
  static final NotificationsService instance = NotificationsService._();

  /// Get notifications
  Future<Map<String, dynamic>> getNotifications({
    int page = 1,
    int perPage = 20,
    bool unreadOnly = false,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'per_page': perPage.toString(),
        'unread_only': unreadOnly.toString(),
      };

      final queryString = Uri(queryParameters: queryParams).query;
      final url = '${ApiEndpoints.notifications}?$queryString';

      if (kDebugMode) {
        print('📬 Fetching notifications from: $url');
      }

      final response = await ApiClient.instance.get(
        url,
        requireAuth: true,
      );
      
      if (kDebugMode) {
        print('📬 Notifications response:');
        print('  success: ${response['success']}');
        print('  data type: ${response['data']?.runtimeType}');
        if (response['data'] is List) {
          print('  data count: ${(response['data'] as List).length}');
        } else if (response['data'] is Map) {
          print('  data keys: ${(response['data'] as Map).keys.toList()}');
        }
        print('  unread_count: ${response['meta']?['unread_count'] ?? 0}');
      }
      
      if (response['success'] == true) {
        return response;
      } else {
        final errorMsg = response['message'] ?? 'Failed to fetch notifications';
        if (kDebugMode) {
          print('❌ Notifications API error: $errorMsg');
        }
        throw Exception(errorMsg);
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ NotificationsService.getNotifications error: $e');
      }
      rethrow;
    }
  }

  /// Mark notification as read
  Future<Map<String, dynamic>> markAsRead(String notificationId) async {
    try {
      if (kDebugMode) {
        print('✅ Marking notification as read: $notificationId');
      }

      final response = await ApiClient.instance.post(
        ApiEndpoints.markNotificationRead(notificationId),
        requireAuth: true,
      );
      
      if (response['success'] == true) {
        if (kDebugMode) {
          print('✅ Notification marked as read successfully');
        }
        return response['data'] as Map<String, dynamic>;
      } else {
        final errorMsg = response['message'] ?? 'Failed to mark notification as read';
        if (kDebugMode) {
          print('❌ Mark as read error: $errorMsg');
        }
        throw Exception(errorMsg);
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ NotificationsService.markAsRead error: $e');
      }
      rethrow;
    }
  }

  /// Mark all notifications as read
  Future<Map<String, dynamic>> markAllAsRead() async {
    try {
      if (kDebugMode) {
        print('✅ Marking all notifications as read');
      }

      final response = await ApiClient.instance.post(
        ApiEndpoints.markAllNotificationsRead,
        requireAuth: true,
      );
      
      if (response['success'] == true) {
        if (kDebugMode) {
          print('✅ All notifications marked as read successfully');
          print('  marked_count: ${response['data']?['marked_count'] ?? 0}');
          print('  unread_count: ${response['data']?['unread_count'] ?? 0}');
        }
        return response['data'] as Map<String, dynamic>;
      } else {
        final errorMsg = response['message'] ?? 'Failed to mark all notifications as read';
        if (kDebugMode) {
          print('❌ Mark all as read error: $errorMsg');
        }
        throw Exception(errorMsg);
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ NotificationsService.markAllAsRead error: $e');
      }
      rethrow;
    }
  }
}

