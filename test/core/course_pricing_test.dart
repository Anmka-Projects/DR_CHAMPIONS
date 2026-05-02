import 'package:educational_app/core/course_pricing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('checkoutPayloadForNavigation', () {
    test('removes stale checkout_selected_plan when course has no plans', () {
      final course = <String, dynamic>{
        'id': 'course_1',
        'price_egp': 1200,
        'checkout_selected_plan': {
          'id': 'old_plan',
          'price_egp': 300,
        },
      };

      final payload = checkoutPayloadForNavigation(course);

      expect(payload.containsKey('checkout_selected_plan'), isFalse);
    });

    test('keeps checkout_selected_plan when plans are available', () {
      final course = <String, dynamic>{
        'id': 'course_1',
        'course_subscription_plans': [
          {'id': 'plan_1', 'price_egp': 400}
        ],
        'checkout_selected_plan': {
          'id': 'plan_1',
          'price_egp': 400,
        },
      };

      final payload = checkoutPayloadForNavigation(course);

      expect(payload['checkout_selected_plan'], isA<Map<String, dynamic>>());
      expect(payload['checkout_selected_plan']['id'], 'plan_1');
    });
  });

  group('checkoutPayloadForFullCoursePrice', () {
    test('always removes checkout_selected_plan', () {
      final course = <String, dynamic>{
        'id': 'course_1',
        'course_subscription_plans': [
          {'id': 'plan_1', 'price_egp': 400}
        ],
        'checkout_selected_plan': {
          'id': 'plan_1',
          'price_egp': 400,
        },
      };

      final payload = checkoutPayloadForFullCoursePrice(course);

      expect(payload.containsKey('checkout_selected_plan'), isFalse);
    });
  });

  group('parseCheckoutPricing', () {
    test('uses selected plan total when plan is present', () {
      final course = <String, dynamic>{
        'price_egp': 1500,
        'checkout_selected_plan': {
          'id': 'plan_1',
          'price_egp': 500,
        },
      };

      final result = parseCheckoutPricing(course);

      expect(result.currency, 'EGP');
      expect(result.amount, 500);
    });

    test('uses course total price when no selected plan exists', () {
      final course = <String, dynamic>{
        'price_egp': 1500,
      };

      final result = parseCheckoutPricing(course);

      expect(result.currency, 'EGP');
      expect(result.amount, 1500);
    });
  });

  group('parseCourseTotalPricing', () {
    test('uses course total and ignores selected plan', () {
      final course = <String, dynamic>{
        'price_egp': 1500,
        'checkout_selected_plan': {
          'id': 'plan_1',
          'price_egp': 500,
        },
      };

      final result = parseCourseTotalPricing(course);

      expect(result.currency, 'EGP');
      expect(result.amount, 1500);
    });
  });

  group('courseHasSubscriptionPlans', () {
    test('returns true when backend bool is true even without plans list', () {
      final course = <String, dynamic>{
        'has_subscription_plans': true,
      };

      expect(courseHasSubscriptionPlans(course), isTrue);
    });

    test('returns false when backend bool is false', () {
      final course = <String, dynamic>{
        'has_subscription_plans': false,
        'course_subscription_plans': [
          {'id': 'plan_1'}
        ],
      };

      expect(courseHasSubscriptionPlans(course), isFalse);
    });

    test('falls back to plans list when bool is missing', () {
      final course = <String, dynamic>{
        'course_subscription_plans': [
          {'id': 'plan_1'}
        ],
      };

      expect(courseHasSubscriptionPlans(course), isTrue);
    });
  });

  group('courseIsEffectivelyFree', () {
    test('returns false when course has plans even if base price is zero', () {
      final course = <String, dynamic>{
        'price': 0,
        'has_subscription_plans': true,
      };

      expect(courseIsEffectivelyFree(course), isFalse);
    });
  });
}
