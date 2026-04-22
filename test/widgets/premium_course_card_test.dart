import 'package:educational_app/widgets/premium_course_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(430, 900),
          textScaler: TextScaler.linear(0.8),
        ),
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: 260,
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  group('PremiumCourseCard pricing plan badge', () {
    testWidgets('shows plans available badge when plans exist',
        (WidgetTester tester) async {
      final course = <String, dynamic>{
        'title': 'Advanced Biology',
        'instructor': {'name': 'Dr. Mina'},
        'category': {'name_en': 'Science'},
        'price_egp': 1200,
        'course_subscription_plans': [
          {'id': 'plan_1', 'name': 'Monthly', 'price_egp': 250}
        ],
      };

      await tester.pumpWidget(
        wrap(
          PremiumCourseCard(
            course: course,
            onTap: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Plans available'), findsOneWidget);
    });

    testWidgets('does not show plans available badge when plans do not exist',
        (WidgetTester tester) async {
      final course = <String, dynamic>{
        'title': 'Advanced Biology',
        'instructor': {'name': 'Dr. Mina'},
        'category': {'name_en': 'Science'},
        'price_egp': 1200,
      };

      await tester.pumpWidget(
        wrap(
          PremiumCourseCard(
            course: course,
            onTap: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Plans available'), findsNothing);
    });

    testWidgets('shows plans available badge when backend bool is true',
        (WidgetTester tester) async {
      final course = <String, dynamic>{
        'title': 'Advanced Biology',
        'instructor': {'name': 'Dr. Mina'},
        'category': {'name_en': 'Science'},
        'price_egp': 1200,
        'has_subscription_plans': true,
      };

      await tester.pumpWidget(
        wrap(
          PremiumCourseCard(
            course: course,
            onTap: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Plans available'), findsOneWidget);
    });
  });
}
