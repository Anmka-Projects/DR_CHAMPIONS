import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';

/// Service for wishlist
class WishlistService {
  WishlistService._();
  
  static final WishlistService instance = WishlistService._();

  /// Get wishlist
  Future<Map<String, dynamic>> getWishlist() async {
    try {
      final response = await ApiClient.instance.get(
        ApiEndpoints.wishlist,
        requireAuth: true,
      );
      
      if (response['success'] == true) {
        return response;
      } else {
        throw Exception(response['message'] ?? 'Failed to fetch wishlist');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Add to wishlist
  Future<void> addToWishlist(String courseId) async {
    try {
      final response = await ApiClient.instance.post(
        ApiEndpoints.wishlist,
        body: {'course_id': courseId},
        requireAuth: true,
      );
      
      if (response['success'] != true) {
        throw Exception(response['message'] ?? 'Failed to add to wishlist');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Remove from wishlist
  Future<void> removeFromWishlist(String courseId) async {
    try {
      final response = await ApiClient.instance.delete(
        ApiEndpoints.wishlistItem(courseId),
        requireAuth: true,
      );
      
      if (response['success'] != true) {
        throw Exception(response['message'] ?? 'Failed to remove from wishlist');
      }
    } catch (e) {
      rethrow;
    }
  }
}

