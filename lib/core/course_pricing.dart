// Shared parsing and "is this course actually free?" logic.
// The API may send is_free=true for paid courses; UI should rely on prices.

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

  final discountEgp = tryParseCourseNum(course['discount_price_egp']);
  final discountUsd = tryParseCourseNum(course['discount_price_usd']);
  final priceEgp = tryParseCourseNum(course['price_egp']);
  final priceUsd = tryParseCourseNum(course['price_usd']);
  final hasAnyDiscount = (discountEgp != null && discountEgp > 0) ||
      (discountUsd != null && discountUsd > 0);
  final finalEgp = hasAnyDiscount ? discountEgp : priceEgp;
  final finalUsd = hasAnyDiscount ? discountUsd : priceUsd;

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
      hasPaidPlan ||
      priceValue > 0;
}

/// Free only when no positive price can be determined.
bool courseIsEffectivelyFree(Map<String, dynamic> course) =>
    !courseHasPaidAmount(course);

/// Single amount for list/card badges (prefers EGP when both exist).
num? courseCardDisplayAmount(Map<String, dynamic> course) {
  if (!courseHasPaidAmount(course)) return null;
  final currency = course['currency']?.toString().toUpperCase();
  final singleDiscount = tryParseCourseNum(course['discount_price']);
  final singlePrice = tryParseCourseNum(course['price']);
  if (currency == 'EGP' || currency == 'USD') {
    final amt = (singleDiscount != null && singleDiscount > 0)
        ? singleDiscount
        : singlePrice;
    if (amt != null && amt > 0) return amt;
  }
  final discountEgp = tryParseCourseNum(course['discount_price_egp']);
  final discountUsd = tryParseCourseNum(course['discount_price_usd']);
  final priceEgp = tryParseCourseNum(course['price_egp']);
  final priceUsd = tryParseCourseNum(course['price_usd']);
  final hasAnyDiscount = (discountEgp != null && discountEgp > 0) ||
      (discountUsd != null && discountUsd > 0);
  if (hasAnyDiscount) {
    if (discountEgp != null && discountEgp > 0) return discountEgp;
    if (discountUsd != null && discountUsd > 0) return discountUsd;
  }
  if (priceEgp != null && priceEgp > 0) return priceEgp;
  if (priceUsd != null && priceUsd > 0) return priceUsd;
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
