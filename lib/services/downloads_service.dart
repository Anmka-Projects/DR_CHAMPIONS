import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';

/// Service for downloads
class DownloadsService {
  DownloadsService._();
  
  static final DownloadsService instance = DownloadsService._();

  /// Get downloads
  Future<Map<String, dynamic>> getDownloads() async {
    try {
      final response = await ApiClient.instance.get(
        ApiEndpoints.curriculum,
        requireAuth: true,
      );
      
      if (response['success'] == true && response['data'] != null) {
        return response['data'] as Map<String, dynamic>;
      } else {
        throw Exception(response['message'] ?? 'Failed to fetch downloads');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Download file
  Future<Map<String, dynamic>> downloadFile(String resourceId) async {
    try {
      final response = await ApiClient.instance.post(
        ApiEndpoints.curriculum,
        body: {'resource_id': resourceId},
        requireAuth: true,
      );
      
      if (response['success'] == true && response['data'] != null) {
        return response['data'] as Map<String, dynamic>;
      } else {
        throw Exception(response['message'] ?? 'Failed to download file');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Delete download
  Future<Map<String, dynamic>> deleteDownload(String downloadId) async {
    try {
      final response = await ApiClient.instance.delete(
        ApiEndpoints.curriculumItem(downloadId),
        requireAuth: true,
      );
      
      if (response['success'] == true && response['data'] != null) {
        return response['data'] as Map<String, dynamic>;
      } else {
        throw Exception(response['message'] ?? 'Failed to delete download');
      }
    } catch (e) {
      rethrow;
    }
  }
}

