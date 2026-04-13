import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';

/// Service for payments and checkout
class PaymentsService {
  PaymentsService._();
  
  static final PaymentsService instance = PaymentsService._();

  /// Initiate checkout
  Future<Map<String, dynamic>> initiateCheckout({
    required String courseId,
    required String paymentMethod,
    String? couponCode,
    String? planId,
  }) async {
    try {
      final body = <String, dynamic>{
        'course_id': courseId,
        'payment_method': paymentMethod,
        if (couponCode != null && couponCode.isNotEmpty) 'coupon_code': couponCode,
        if (planId != null && planId.isNotEmpty) 'plan_id': planId,
      };

      final response = await ApiClient.instance.post(
        ApiEndpoints.payments,
        body: body,
        requireAuth: true,
      );
      
      if (response['success'] == true && response['data'] != null) {
        return response['data'] as Map<String, dynamic>;
      } else {
        throw Exception(response['message'] ?? 'Failed to initiate checkout');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Complete checkout
  Future<Map<String, dynamic>> completeCheckout({
    required String checkoutSessionId,
    required String paymentMethod,
    required String paymentToken,
  }) async {
    try {
      final response = await ApiClient.instance.post(
        ApiEndpoints.confirmPayment(checkoutSessionId),
        body: {
          'checkout_session_id': checkoutSessionId,
          'payment_method': paymentMethod,
          'payment_token': paymentToken,
        },
        requireAuth: true,
      );
      
      if (response['success'] == true && response['data'] != null) {
        return response['data'] as Map<String, dynamic>;
      } else {
        throw Exception(response['message'] ?? 'Failed to complete checkout');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Validate coupon
  Future<Map<String, dynamic>> validateCoupon({
    required String code,
    required String courseId,
  }) async {
    try {
      final response = await ApiClient.instance.post(
        ApiEndpoints.validateCoupon,
        body: {
          'code': code,
          'course_id': courseId,
        },
        requireAuth: true,
      );
      
      if (response['success'] == true && response['data'] != null) {
        return response['data'] as Map<String, dynamic>;
      } else {
        throw Exception(response['message'] ?? 'Invalid coupon code');
      }
    } catch (e) {
      rethrow;
    }
  }
}

