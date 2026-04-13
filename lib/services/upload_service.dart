import 'dart:io';
import 'package:flutter/foundation.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';

/// Upload files (images, etc.) via POST /api/upload. API_DOCUMENTATION.
class UploadService {
  UploadService._();
  static final UploadService instance = UploadService._();

  /// Upload an image. Returns URL path (e.g. /uploads/images/xxx.jpg) for use as thumbnail.
  Future<String> uploadImage(File file) async {
    try {
      final response = await ApiClient.instance.postMultipart(
        ApiEndpoints.upload,
        fields: {'type': 'image'},
        files: {'image': file},
        requireAuth: true,
      );
      // API may return { success, url } or { success, data: { url } }
      final url = response['url']?.toString() ??
          (response['data'] is Map
              ? (response['data'] as Map)['url']?.toString()
              : null);
      if (url != null && url.isNotEmpty) {
        return url;
      }
      throw Exception(response['message'] ?? 'Upload failed');
    } catch (e) {
      if (kDebugMode) {
        print('❌ UploadService.uploadImage: $e');
      }
      rethrow;
    }
  }

  /// Upload a PDF file. Returns URL path for use as fileUrl.
  Future<String> uploadPdf(File file) async {
    try {
      final response = await ApiClient.instance.postMultipart(
        ApiEndpoints.upload,
        fields: {'type': 'file'},
        files: {'file': file},
        requireAuth: true,
      );
      final url = response['url']?.toString() ??
          (response['data'] is Map
              ? (response['data'] as Map)['url']?.toString()
              : null);
      if (url != null && url.isNotEmpty) {
        return url;
      }
      throw Exception(response['message'] ?? 'Upload failed');
    } catch (e) {
      if (kDebugMode) {
        print('❌ UploadService.uploadPdf: $e');
      }
      rethrow;
    }
  }
}
