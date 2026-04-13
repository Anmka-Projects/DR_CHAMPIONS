import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';

/// Service for certificates
class CertificatesService {
  CertificatesService._();
  
  static final CertificatesService instance = CertificatesService._();

  /// Get user certificates
  Future<Map<String, dynamic>> getCertificates() async {
    try {
      final response = await ApiClient.instance.get(
        ApiEndpoints.certificates,
        requireAuth: true,
      );
      
      if (response['success'] == true) {
        return response;
      } else {
        throw Exception(response['message'] ?? 'Failed to fetch certificates');
      }
    } catch (e) {
      rethrow;
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

