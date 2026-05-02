import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import 'package:flutter/foundation.dart';

/// Service for certificates
class CertificatesService {
  CertificatesService._();
  
  static final CertificatesService instance = CertificatesService._();

  /// Get user certificates
  Future<Map<String, dynamic>> getCertificates() async {
    if (kDebugMode) {
      print('📤 Certificates request URL: ${ApiEndpoints.certificates}');
    }
    final response = await ApiClient.instance.get(
      ApiEndpoints.certificates,
      requireAuth: true,
      logTag: 'CERTIFICATES_API',
    );
    final normalized = _normalizeCertificatesResponse(response);
    if (normalized['success'] == true) {
      return normalized;
    }
    throw Exception(normalized['message'] ?? 'Failed to fetch certificates');
  }

  Map<String, dynamic> _normalizeCertificatesResponse(
      Map<String, dynamic> response) {
    final data = response['data'];
    if (data is List) {
      return {
        ...response,
        'success': true,
        'data': data.whereType<Map<String, dynamic>>().toList(),
      };
    }
    if (data is Map<String, dynamic>) {
      final nested = data['certificates'] ?? data['items'] ?? data['data'];
      if (nested is List) {
        return {
          ...response,
          'success': true,
          'data': nested.whereType<Map<String, dynamic>>().toList(),
        };
      }
    }
    final root = response['certificates'] ?? response['items'];
    if (root is List) {
      return {
        ...response,
        'success': true,
        'data': root.whereType<Map<String, dynamic>>().toList(),
      };
    }
    return response;
  }

  /// Get certificate for a specific course (filters locally from full list)
  Future<Map<String, dynamic>?> getCertificateForCourse(
      String courseId) async {
    try {
      final response = await getCertificates();
      final data = response['data'];
      if (data is! List) return null;
      for (final item in data) {
        if (item is Map<String, dynamic>) {
          final cId = item['course']?['id']?.toString() ??
              item['course_id']?.toString();
          if (cId == courseId) return item;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Verify certificate
  Future<Map<String, dynamic>> verifyCertificate(String certificateId) async {
    try {
      final response = await ApiClient.instance.get(
        ApiEndpoints.certificate(certificateId),
        requireAuth: false,
      );
      
      if (response['success'] == true && response['data'] != null) {
        return response['data'] as Map<String, dynamic>;
      } else {
        throw Exception(response['message'] ?? 'Failed to verify certificate');
      }
    } catch (e) {
      rethrow;
    }
  }
}

