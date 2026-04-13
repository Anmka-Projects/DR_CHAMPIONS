import 'package:flutter/foundation.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';

/// Service for QR code operations
class QrCodeService {
  QrCodeService._();

  static final QrCodeService instance = QrCodeService._();

  /// Get user's QR code (tries attendance path per TEACHER_DASHBOARD_API, then fallback)
  Future<String> getMyQrCode() async {
    try {
      // TEACHER_DASHBOARD_API: GET /api/attendance/my-qr-code
      final urls = [
        ApiEndpoints.attendanceMyQrCode,
        ApiEndpoints.myQrCode,
      ];
      for (final url in urls) {
        try {
          if (kDebugMode) {
            print('📱 Fetching QR code from: $url');
          }
          final response = await ApiClient.instance.get(
            url,
            requireAuth: true,
          );
          return _parseQrResponse(response, url);
        } catch (_) {
          continue;
        }
      }
      throw Exception('Failed to fetch QR code from available endpoints');
    } catch (e) {
      if (kDebugMode) {
        print('❌ QrCodeService.getMyQrCode error: $e');
      }
      rethrow;
    }
  }

  String _parseQrResponse(Map<String, dynamic> response, String url) {
    if (kDebugMode) {
      print('📱 QR code response from $url:');
      print('  success: ${response['success']}');
      print('  data: ${response['data']}');
    }

    if (response['success'] == true && response['data'] != null) {
      final data = response['data'] as Map<String, dynamic>?;

      final qrCode = data?['qr_code']?.toString();
      if (qrCode != null && qrCode.isNotEmpty) {
        if (kDebugMode) {
          print('✅ QR code extracted');
        }
        return qrCode;
      }

      final user = data?['user'] as Map<String, dynamic>?;
      final userId = user?['id']?.toString();
      if (userId != null && userId.isNotEmpty) {
        if (kDebugMode) {
          print('✅ User ID (fallback) extracted');
        }
        return userId;
      }

      throw Exception('QR code or User ID not found in response');
    } else {
      final errorMsg = response['message'] ?? 'Failed to fetch QR code';
      throw Exception(errorMsg);
    }
  }
}

