import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';

/// Service for search
class SearchService {
  SearchService._();
  
  static final SearchService instance = SearchService._();

  /// Search
  Future<Map<String, dynamic>> search({
    required String query,
    String type = 'all', // all, courses, instructors, categories
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final queryParams = <String, String>{
        'q': query,
        'type': type,
        'page': page.toString(),
        'per_page': perPage.toString(),
      };

      final queryString = Uri(queryParameters: queryParams).query;
      final url = '${ApiEndpoints.search}?$queryString';

      final response = await ApiClient.instance.get(
        url,
        requireAuth: false,
      );
      
      if (response['success'] == true && response['data'] != null) {
        return response['data'] as Map<String, dynamic>;
      } else {
        throw Exception(response['message'] ?? 'Failed to search');
      }
    } catch (e) {
      rethrow;
    }
  }
}

