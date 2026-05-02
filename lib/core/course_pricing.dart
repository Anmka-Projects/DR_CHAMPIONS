// Shared parsing and "is this course actually free?" logic.
// The API may send is_free=true for paid courses; UI should rely on prices.

import 'package:intl/intl.dart';

num? tryParseCourseNum(dynamic value) {
  if (value == null) return null;
  if (value is num) return value;
  if (value is String) {
    final s = value.trim();
    if (s.isEmpty) return null;
    final normalized = s.replaceAll(',', '');
    final match = RegExp(r'[-+]?\d*\.?\d+').firstMatch(normalized);
    if (match == null) return null;
    return num.tryParse(match.group(0)!);
  }
  return null;
}

/// EGP line: `discount_price_egp` only when it is a positive sale; else `price_egp`.
/// Prevents a discount in USD alone from blanking EGP and forcing the wrong branch.
num? effectiveCoursePriceEgp(Map<String, dynamic> m) {
  final d = tryParseCourseNum(m['discount_price_egp']);
  if (d != null && d > 0) return d;
  return tryParseCourseNum(m['price_egp']);
}

/// USD line: `discount_price_usd` when positive; else `price_usd`.
num? effectiveCoursePriceUsd(Map<String, dynamic> m) {
  final d = tryParseCourseNum(m['discount_price_usd']);
  if (d != null && d > 0) return d;
  return tryParseCourseNum(m['price_usd']);
}

bool _dynamicToBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final v = value.trim().toLowerCase();
    return v == 'true' || v == '1' || v == 'yes';
  }
  return false;
}

/// Preferred source for "does this course have plans?".
///
/// Backend can provide one of:
/// - `has_subscription_plans` (recommended)
/// - `has_plans`
/// - `has_course_plans`
///
/// When absent, fallback uses plans list existence.
bool courseHasSubscriptionPlans(Map<String, dynamic> course) {
  for (final key in [
    'has_subscription_plans',
    'has_plans',
    'has_course_plans',
  ]) {
    if (course.containsKey(key)) {
      return _dynamicToBool(course[key]);
    }
  }

  final subscriptionPlans =
      course['course_subscription_plans'] ?? course['subscription_plans'];
  return subscriptionPlans is List && subscriptionPlans.isNotEmpty;
}

/// True if any positive price exists (single/dual currency or subscription plan).
bool courseHasPaidAmount(Map<String, dynamic> course) {
  final priceValue = tryParseCourseNum(course['price']) ?? 0.0;

  final currency = course['currency']?.toString().toUpperCase();
  final singlePrice = tryParseCourseNum(course['price']);
  final singleDiscount = tryParseCourseNum(course['discount_price']);
  final hasSingleCurrency = currency == 'EGP' || currency == 'USD';
  final singleFinalAmount = (singleDiscount != null && singleDiscount > 0)
      ? singleDiscount
      : singlePrice;

  final finalEgp = effectiveCoursePriceEgp(course);
  final finalUsd = effectiveCoursePriceUsd(course);

  final subscriptionPlans =
      course['course_subscription_plans'] ?? course['subscription_plans'];
  final hasPaidPlan = subscriptionPlans is List &&
      subscriptionPlans.any((p) {
        if (p is! Map) return false;
        final price = tryParseCourseNum(p['price']);
        final planEgp = tryParseCourseNum(p['price_egp']);
        final planUsd = tryParseCourseNum(p['price_usd']);
        return (price != null && price > 0) ||
            (planEgp != null && planEgp > 0) ||
            (planUsd != null && planUsd > 0);
      });

  return (hasSingleCurrency && (singleFinalAmount ?? 0) > 0) ||
      (finalEgp != null && finalEgp > 0) ||
      (finalUsd != null && finalUsd > 0) ||
      courseHasSubscriptionPlans(course) ||
      hasPaidPlan ||
      priceValue > 0;
}

/// Free only when no positive price can be determined.
bool courseIsEffectivelyFree(Map<String, dynamic> course) =>
    !courseHasPaidAmount(course);

/// Single amount for list/card badges (prefers EGP when both exist).
num? courseCardDisplayAmount(Map<String, dynamic> course) {
  if (!courseHasPaidAmount(course)) return null;
  // Same priority as checkout: dual `price_egp` / `price_usd` before legacy `price`
  // when `currency`+`price` disagree with admin dashboard amounts.
  final egp = effectiveCoursePriceEgp(course);
  if (egp != null && egp > 0) return egp;
  final usd = effectiveCoursePriceUsd(course);
  if (usd != null && usd > 0) return usd;

  final currency = course['currency']?.toString().toUpperCase();
  final singleDiscount = tryParseCourseNum(course['discount_price']);
  final singlePrice = tryParseCourseNum(course['price']);
  if (currency == 'EGP' || currency == 'USD') {
    final amt = (singleDiscount != null && singleDiscount > 0)
        ? singleDiscount
        : singlePrice;
    if (amt != null && amt > 0) return amt;
  }
  if (singlePrice != null && singlePrice > 0) return singlePrice;

  final subscriptionPlans =
      course['course_subscription_plans'] ?? course['subscription_plans'];
  if (subscriptionPlans is List) {
    for (final p in subscriptionPlans) {
      if (p is! Map) continue;
      final v = tryParseCourseNum(p['price_egp']) ??
          tryParseCourseNum(p['price']) ??
          tryParseCourseNum(p['price_usd']);
      if (v != null && v > 0) return v;
    }
  }
  return null;
}

String _formatCourseNumber(num value) =>
    NumberFormat.decimalPattern('en_US').format(value);

String formatDualCurrencyFromValues({
  num? egp,
  num? usd,
}) {
  final parts = <String>[];
  if (egp != null && egp != 0) parts.add('${_formatCourseNumber(egp)} EGP');
  if (usd != null && usd != 0) {
    parts.add('\$${_formatCourseNumber(usd)} USD');
  }
  return parts.join(' / ');
}

String formatSingleCurrencyPrice({
  required String currency,
  required num amount,
}) {
  final c = currency.toUpperCase();
  if (c == 'USD') return '\$${_formatCourseNumber(amount)} USD';
  return '${_formatCourseNumber(amount)} EGP';
}

/// Same rules as course details price line — use on list cards for consistency.
String? formatCoursePriceCompact(Map<String, dynamic> course) {
  final dualText = formatDualCurrencyFromValues(
    egp: effectiveCoursePriceEgp(course),
    usd: effectiveCoursePriceUsd(course),
  );
  if (dualText.isNotEmpty) return dualText;

  final currency = course['currency']?.toString().toUpperCase();
  final price = tryParseCourseNum(course['price']);
  final discount = tryParseCourseNum(course['discount_price']);

  if (currency == 'EGP' || currency == 'USD') {
    final finalAmount =
        (discount != null && discount > 0) ? discount : (price ?? 0);
    if (finalAmount > 0) {
      return formatSingleCurrencyPrice(
        currency: currency!,
        amount: finalAmount,
      );
    }
  }

  if (price != null && price != 0) {
    return formatSingleCurrencyPrice(currency: 'EGP', amount: price);
  }
  return null;
}

void _pickAmountFromPricingMap(
  Map<String, dynamic> m,
  void Function(String currency, num amount) onPick,
) {
  final egp = effectiveCoursePriceEgp(m);
  final usd = effectiveCoursePriceUsd(m);
  if (egp != null && egp > 0) {
    onPick('EGP', egp);
    return;
  }
  if (usd != null && usd > 0) {
    onPick('USD', usd);
    return;
  }

  final currency = m['currency']?.toString().toUpperCase();
  final price = tryParseCourseNum(m['price']);
  final discount = tryParseCourseNum(m['discount_price']);
  if (currency == 'EGP' || currency == 'USD') {
    final finalAmount =
        (discount != null && discount > 0) ? discount : price;
    if (finalAmount != null && finalAmount > 0) {
      onPick(currency!, finalAmount);
      return;
    }
  }
  // Admin often sets legacy `price` only (no currency / dual fields).
  if (price != null && price > 0) {
    onPick('EGP', price);
  }
}

/// Amount + ISO currency for checkout (user-picked plan first, then course root).
///
/// Only [checkout_selected_plan] is used for plan pricing — not API `selected_plan`,
/// which can be stale and disagree with [price_egp] / card display.
({String currency, double amount}) parseCheckoutPricing(
    Map<String, dynamic> course) {
  var currency = 'EGP';
  var amount = 0.0;

  void onPick(String c, num v) {
    currency = c;
    amount = v.toDouble();
  }

  final plan = course['checkout_selected_plan'];
  if (plan is Map<String, dynamic>) {
    _pickAmountFromPricingMap(plan, onPick);
  }
  if (amount > 0) return (currency: currency, amount: amount);

  _pickAmountFromPricingMap(course, onPick);
  return (currency: currency, amount: amount);
}

/// Amount + ISO currency for full course price only (ignores selected plan).
({String currency, double amount}) parseCourseTotalPricing(
    Map<String, dynamic> course) {
  var currency = 'EGP';
  var amount = 0.0;

  void onPick(String c, num v) {
    currency = c;
    amount = v.toDouble();
  }

  _pickAmountFromPricingMap(course, onPick);
  return (currency: currency, amount: amount);
}

/// True when the course has subscription plans but no standalone full-course
/// amount to display.
bool courseHasPlansWithZeroBasePrice(Map<String, dynamic> course) {
  if (!courseHasSubscriptionPlans(course)) return false;
  final total = parseCourseTotalPricing(course).amount;
  return total <= 0;
}

/// Ensures checkout payload does not carry stale selected plan
/// when the course currently has no available subscription plans.
Map<String, dynamic> checkoutPayloadForNavigation(Map<String, dynamic> course) {
  final payload = Map<String, dynamic>.from(course);
  final subscriptionPlans =
      payload['course_subscription_plans'] ?? payload['subscription_plans'];
  final hasPlans = subscriptionPlans is List && subscriptionPlans.isNotEmpty;
  if (!hasPlans) {
    payload.remove('checkout_selected_plan');
  }
  return payload;
}

/// Payload for forcing full course checkout (never keep selected plan).
Map<String, dynamic> checkoutPayloadForFullCoursePrice(
    Map<String, dynamic> course) {
  final payload = Map<String, dynamic>.from(course);
  payload.remove('checkout_selected_plan');
  return payload;
}

/// Prefer English category label when API provides `name_en` or `slug`.
String courseCategoryEnglishLabel(dynamic category) {
  if (category == null) return '';
  if (category is Map) {
    final en = category['name_en']?.toString().trim();
    if (en != null && en.isNotEmpty) return en;
    final slug = category['slug']?.toString().trim();
    if (slug != null && slug.isNotEmpty) {
      return slug
          .replaceAll('_', ' ')
          .split(' ')
          .where((e) => e.isNotEmpty)
          .map((w) {
            if (w.length == 1) return w.toUpperCase();
            return '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}';
          })
          .join(' ');
    }
    return category['name']?.toString() ?? '';
  }
  return category.toString();
}

/// Rating for list/course cards (API field names vary).
num courseCardRatingNum(Map<String, dynamic> course) {
  for (final key in [
    'rating',
    'average_rating',
    'avg_rating',
    'reviews_average',
    'averageRating',
  ]) {
    final n = tryParseCourseNum(course[key]);
    if (n != null) return n;
  }
  return 0;
}

/// Enrolled / learner count for cards.
int courseCardStudentsCount(Map<String, dynamic> course) {
  for (final key in [
    'students_count',
    'students',
    'enrollments_count',
    'enrolled_students',
    'total_students',
    'learners_count',
    'total_enrollments',
  ]) {
    final v = course[key];
    if (v == null) continue;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) {
      final i = int.tryParse(v.trim());
      if (i != null) return i;
    }
  }
  return 0;
}

/// Course length in hours when derivable from numeric API fields.
num? courseCardDurationHoursNum(Map<String, dynamic> course) {
  for (final key in [
    'duration_hours',
    'hours',
    'total_duration_hours',
    'course_hours',
    'estimated_hours',
  ]) {
    final n = tryParseCourseNum(course[key]);
    if (n != null && n > 0) return n;
  }
  for (final key in [
    'duration_minutes',
    'total_duration_minutes',
    'minutes',
    'total_minutes',
  ]) {
    final n = tryParseCourseNum(course[key]);
    if (n != null && n > 0) return n / 60.0;
  }
  return null;
}

/// Compact duration label for horizontal course rows (uses [hoursUnitShort] from l10n).
String courseListCardDurationText(
  Map<String, dynamic> course,
  String Function(num) hoursUnitShort,
) {
  final h = courseCardDurationHoursNum(course);
  if (h != null && h > 0) {
    if (h < 1) return '${(h * 60).round()}m';
    final n = h == h.roundToDouble()
        ? h.round()
        : num.parse(h.toStringAsFixed(1));
    return hoursUnitShort(n);
  }
  final raw = course['duration']?.toString().trim();
  if (raw != null && raw.isNotEmpty) {
    if (!RegExp(r'^-?[\d.]+$').hasMatch(raw)) {
      return raw.length > 12 ? '${raw.substring(0, 12)}…' : raw;
    }
  }
  return hoursUnitShort(0);
}

String courseDisplayTitle(
  Map<String, dynamic> course, {
  String fallback = '',
}) {
  for (final key in ['title', 'name', 'course_title', 'title_en']) {
    final v = course[key]?.toString().trim();
    if (v != null && v.isNotEmpty) return v;
  }
  return fallback;
}

String courseDisplayInstructor(
  Map<String, dynamic> course, {
  String fallback = '',
}) {
  final instructor = course['instructor'];
  if (instructor is Map) {
    for (final key in ['name', 'full_name', 'display_name']) {
      final v = instructor[key]?.toString().trim();
      if (v != null && v.isNotEmpty) return v;
    }
  } else if (instructor != null) {
    final v = instructor.toString().trim();
    if (v.isNotEmpty) return v;
  }

  final instructors = course['instructors'];
  if (instructors is List && instructors.isNotEmpty) {
    final first = instructors.first;
    if (first is Map) {
      for (final key in ['name', 'full_name', 'display_name']) {
        final v = first[key]?.toString().trim();
        if (v != null && v.isNotEmpty) return v;
      }
    } else {
      final v = first.toString().trim();
      if (v.isNotEmpty) return v;
    }
  }
  return fallback;
}
