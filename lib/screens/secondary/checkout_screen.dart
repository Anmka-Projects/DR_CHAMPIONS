import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/course_pricing.dart';
import '../../core/design/app_colors.dart';
import '../../core/design/app_text_styles.dart';
import '../../core/design/app_radius.dart';
import '../../services/payments_service.dart';
import '../../l10n/app_localizations.dart';

/// Checkout Screen - Pixel-perfect match to React version
/// Matches: components/screens/checkout-screen.tsx
class CheckoutScreen extends StatefulWidget {
  final Map<String, dynamic>? course;

  const CheckoutScreen({super.key, this.course});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String? _selectedPayment;
  String _couponCode = '';
  bool _couponApplied = false;
  bool _isProcessing = false;
  bool _isValidatingCoupon = false;
  String? _checkoutSessionId;

  // Pricing from API (amount + currency from selected plan or course)
  double _originalPrice = 0.0;
  double _discountAmount = 0.0;
  double _finalPrice = 0.0;
  String _checkoutCurrencyCode = 'EGP';

  // Payment methods - will be localized in build method
  List<Map<String, dynamic>> _getPaymentMethods(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return [
      {
        'id': 'fawry',
        'name': l10n.fawry,
        'icon': Icons.account_balance,
        'description': l10n.payAtFawryBranch,
      },
      {
        'id': 'wallet',
        'name': l10n.eWallet,
        'icon': Icons.account_balance_wallet,
        'description': l10n.walletDescription,
      },
      {
        'id': 'visa',
        'name': l10n.visaMastercard,
        'icon': Icons.credit_card,
        'description': l10n.creditDebitCard,
      },
    ];
  }

  @override
  void initState() {
    super.initState();
    _loadInitialPrice();
  }

  void _loadInitialPrice() {
    final course = widget.course;
    if (course == null) {
      _originalPrice = 0;
      _finalPrice = 0;
      _checkoutCurrencyCode = 'EGP';
      return;
    }
    final parsed = parseCheckoutPricing(course);
    _checkoutCurrencyCode = parsed.currency;
    _originalPrice = parsed.amount;
    _finalPrice = parsed.amount;
  }

  String _formatCheckoutMoney(AppLocalizations l10n, double amount) {
    final amt = amount.toStringAsFixed(2);
    if (_checkoutCurrencyCode == 'USD') {
      return l10n.usdAmount(amt);
    }
    return l10n.egyptianPoundAmount(amt);
  }

  Future<void> _handleApplyCoupon() async {
    if (_couponCode.isEmpty) return;

    final course = widget.course;
    if (course == null || course['id'] == null) return;

    final courseId = course['id']?.toString();
    if (courseId == null || courseId.isEmpty) return;

    setState(() => _isValidatingCoupon = true);

    try {
      final result = await PaymentsService.instance.validateCoupon(
        code: _couponCode,
        courseId: courseId,
      );

      if (kDebugMode) {
        print('✅ Coupon validated: $result');
      }

      if (result['is_valid'] == true) {
        setState(() {
          _couponApplied = true;
          _discountAmount =
              (result['discount_amount'] as num?)?.toDouble() ?? 0.0;
          _finalPrice =
              (result['final_price'] as num?)?.toDouble() ?? _originalPrice;
          _isValidatingCoupon = false;
        });

        if (mounted) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result['message']?.toString() ?? l10n.discountApplied,
                style: GoogleFonts.cairo(),
              ),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      } else {
        setState(() => _isValidatingCoupon = false);
        if (mounted) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                l10n.invalidCouponCode,
                style: GoogleFonts.cairo(),
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error validating coupon: $e');
      }

      setState(() => _isValidatingCoupon = false);

      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().contains('401') ||
                      e.toString().contains('Unauthorized')
                  ? l10n.loginRequired
                  : e.toString().contains('Invalid') ||
                          e.toString().contains('غير صحيح')
                      ? l10n.invalidCouponCode
                      : l10n.errorCheckingDiscount,
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Future<void> _handleCheckout() async {
    if (_selectedPayment == null) return;

    final course = widget.course;
    if (course == null || course['id'] == null) return;

    final courseId = course['id']?.toString();
    if (courseId == null || courseId.isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      // Map payment method IDs to API format
      String paymentMethod = 'card'; // default
      if (_selectedPayment == 'fawry') {
        paymentMethod = 'fawry';
      } else if (_selectedPayment == 'wallet') {
        paymentMethod = 'wallet';
      } else if (_selectedPayment == 'visa') {
        paymentMethod = 'card';
      }

      // Initiate checkout
      final checkoutData = await PaymentsService.instance.initiateCheckout(
        courseId: courseId,
        paymentMethod: paymentMethod,
        couponCode: _couponApplied ? _couponCode : null,
        planId:
            widget.course?['checkout_selected_plan']?['id']?.toString(),
      );

      if (kDebugMode) {
        print('✅ Checkout initiated: $checkoutData');
      }

      setState(() {
        _checkoutSessionId = checkoutData['checkout_session_id']?.toString();
      });

      // Update pricing from API response
      if (checkoutData['pricing'] != null) {
        final pricing = checkoutData['pricing'] as Map<String, dynamic>;
        setState(() {
          _originalPrice =
              (pricing['original_price'] as num?)?.toDouble() ?? _originalPrice;
          _discountAmount =
              (pricing['discount_amount'] as num?)?.toDouble() ?? 0.0;
          if (pricing['coupon_discount'] != null) {
            _discountAmount +=
                (pricing['coupon_discount'] as num?)?.toDouble() ?? 0.0;
          }
          _finalPrice =
              (pricing['final_price'] as num?)?.toDouble() ?? _originalPrice;
        });
      }

      // Complete checkout (in real app, this would be done after payment gateway)
      if (_checkoutSessionId != null) {
        try {
          final completeData = await PaymentsService.instance.completeCheckout(
            checkoutSessionId: _checkoutSessionId!,
            paymentMethod: paymentMethod,
            paymentToken:
                'tok_${DateTime.now().millisecondsSinceEpoch}', // Mock token
          );

          if (kDebugMode) {
            print('✅ Checkout completed: $completeData');
          }

          setState(() => _isProcessing = false);

          if (mounted) {
            final l10n = AppLocalizations.of(context)!;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  completeData['message']?.toString() ??
                      l10n.purchaseSuccessful,
                  style: GoogleFonts.cairo(),
                ),
                backgroundColor: const Color(0xFF10B981),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );

            // Navigate back and refresh course details
            context.pop(true); // Return true to indicate success
          }
        } catch (e) {
          if (kDebugMode) {
            print('❌ Error completing checkout: $e');
          }

          setState(() => _isProcessing = false);

          if (mounted) {
            final l10n = AppLocalizations.of(context)!;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  l10n.errorCompletingPayment,
                  style: GoogleFonts.cairo(),
                ),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initiating checkout: $e');
      }

      setState(() => _isProcessing = false);

      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().contains('401') ||
                      e.toString().contains('Unauthorized')
                  ? l10n.loginRequired
                  : l10n.errorProcessingPayment,
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final course = widget.course;
    if (course == null) {
      return Scaffold(
        backgroundColor: AppColors.beige,
        body: Center(child: Text(l10n.noCourse)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.beige,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Header - matches React: bg-[var(--purple)] rounded-b-[3rem] pt-4 pb-8 px-4
            Container(
              decoration: const BoxDecoration(
                color: AppColors.purple,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(AppRadius.largeCard),
                  bottomRight: Radius.circular(AppRadius.largeCard),
                ),
              ),
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 16, // pt-4
                bottom: 32, // pb-8
                left: 16, // px-4
                right: 16,
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 40, // w-10
                      height: 40, // h-10
                      decoration: const BoxDecoration(
                        color: AppColors.whiteOverlay20, // bg-white/20
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 20, // w-5 h-5
                      ),
                    ),
                  ),
                  const SizedBox(width: 16), // gap-4
                  Text(
                    l10n.completePurchase,
                    style: AppTextStyles.h3(color: Colors.white),
                  ),
                ],
              ),
            ),

            // Content - matches React: px-4 -mt-4 space-y-4
            Expanded(
              child: Transform.translate(
                offset: const Offset(0, -16), // -mt-4
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16), // px-4
                  child: Column(
                    children: [
                      // Course Summary Card - matches React: bg-white rounded-3xl p-4 shadow-lg
                      Container(
                        margin: const EdgeInsets.only(bottom: 16), // space-y-4
                        padding: const EdgeInsets.all(16), // p-4
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(24), // rounded-3xl
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Course image - matches React: w-20 h-20 rounded-2xl
                            Container(
                              width: 80, // w-20
                              height: 80, // h-20
                              decoration: BoxDecoration(
                                borderRadius:
                                    BorderRadius.circular(16), // rounded-2xl
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: _buildCourseImage(course),
                              ),
                            ),
                            const SizedBox(width: 16), // gap-4
                            // Course info - matches React: flex-1
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    course['title']?.toString() ??
                                        l10n.courseTitle,
                                    style: AppTextStyles.bodyMedium(
                                      color: AppColors.foreground,
                                    ).copyWith(fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4), // mb-1
                                  Text(
                                    () {
                                      final instructors =
                                          course['instructors'] as List?;
                                      if (instructors != null &&
                                          instructors.isNotEmpty) {
                                        final first = instructors.first;
                                        if (first is Map) {
                                          final name = first['name']?.toString();
                                          if (name != null && name.isNotEmpty) {
                                            return name;
                                          }
                                        }
                                      }

                                      if (course['instructor'] is Map) {
                                        return (course['instructor'] as Map)[
                                                    'name']
                                                ?.toString() ??
                                            l10n.instructor;
                                      }
                                      return course['instructor']?.toString() ??
                                          l10n.instructor;
                                    }(),
                                    style: AppTextStyles.bodySmall(
                                      color: AppColors.purple,
                                    ),
                                  ),
                                  if (course['checkout_selected_plan'] != null &&
                                      course['checkout_selected_plan'] is Map &&
                                      (course['checkout_selected_plan']['name'] ??
                                              '')
                                          .toString()
                                          .isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      course['checkout_selected_plan']['name']
                                          .toString(),
                                      style: AppTextStyles.bodySmall(
                                        color: AppColors.mutedForeground,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                  const SizedBox(height: 8), // mb-2
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.star,
                                        size: 12, // w-3 h-3
                                        color: AppColors.orange,
                                      ),
                                      const SizedBox(width: 4), // gap-1
                                      Text(
                                        '${course['rating'] ?? 4.8}',
                                        style: AppTextStyles.labelSmall(
                                          color: AppColors.mutedForeground,
                                        ),
                                      ),
                                      const SizedBox(width: 12), // gap-3
                                      const Icon(
                                        Icons.access_time,
                                        size: 12, // w-3 h-3
                                        color: AppColors.mutedForeground,
                                      ),
                                      const SizedBox(width: 4), // gap-1
                                      Text(
                                        '${course['duration_hours'] ?? course['hours'] ?? 48}${l10n.hourShort}',
                                        style: AppTextStyles.labelSmall(
                                          color: AppColors.mutedForeground,
                                        ),
                                      ),
                                      const SizedBox(width: 12), // gap-3
                                      const Icon(
                                        Icons.menu_book,
                                        size: 12, // w-3 h-3
                                        color: AppColors.mutedForeground,
                                      ),
                                      const SizedBox(width: 4), // gap-1
                                      Text(
                                        l10n.lessonsCount(() {
                                          final n = course['lessons_count'];
                                          if (n is num) return n.toInt();
                                          final list = course['lessons'];
                                          if (list is List) return list.length;
                                          return 22;
                                        }()),
                                        style: AppTextStyles.labelSmall(
                                          color: AppColors.mutedForeground,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Coupon Section - matches React: bg-white rounded-2xl p-4 shadow-sm
                      Container(
                        margin: const EdgeInsets.only(bottom: 16), // space-y-4
                        padding: const EdgeInsets.all(16), // p-4
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(16), // rounded-2xl
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.local_offer,
                                  size: 20, // w-5 h-5
                                  color: AppColors.purple,
                                ),
                                const SizedBox(width: 8), // gap-2
                                Text(
                                  l10n.discount,
                                  style: AppTextStyles.bodyMedium(
                                    color: AppColors.foreground,
                                  ).copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12), // mb-3
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16, // px-4
                                      vertical: 12, // py-3
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.lavenderLight,
                                      borderRadius: BorderRadius.circular(
                                          12), // rounded-xl
                                    ),
                                    child: TextField(
                                      enabled: !_couponApplied,
                                      decoration: InputDecoration(
                                        hintText: l10n.enterCouponCode,
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                        hintStyle: const TextStyle(
                                          color: AppColors.mutedForeground,
                                        ),
                                      ),
                                      style: AppTextStyles.bodyMedium(
                                        color: AppColors.foreground,
                                      ),
                                      onChanged: (value) {
                                        _couponCode = value;
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8), // gap-2
                                GestureDetector(
                                  onTap: (_couponApplied ||
                                          _couponCode.isEmpty ||
                                          _isValidatingCoupon)
                                      ? null
                                      : _handleApplyCoupon,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24, // px-6
                                      vertical: 12, // py-3
                                    ),
                                    decoration: BoxDecoration(
                                      color: _couponApplied
                                          ? Colors.green[100]
                                          : (_isValidatingCoupon
                                              ? Colors.grey[300]
                                              : AppColors.purple),
                                      borderRadius: BorderRadius.circular(
                                          12), // rounded-xl
                                    ),
                                    child: _isValidatingCoupon
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                      Colors.grey),
                                            ),
                                          )
                                        : _couponApplied
                                            ? Icon(
                                                Icons.check,
                                                size: 20, // w-5 h-5
                                                color: Colors.green[600],
                                              )
                                            : Text(
                                                l10n.apply,
                                                style: AppTextStyles.bodyMedium(
                                                  color: Colors.white,
                                                ).copyWith(
                                                    fontWeight:
                                                        FontWeight.w500),
                                              ),
                                  ),
                                ),
                              ],
                            ),
                            if (_couponApplied) ...[
                              const SizedBox(height: 8), // mt-2
                              Text(
                                l10n.discount20,
                                style: AppTextStyles.bodySmall(
                                  color: Colors.green[600],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Payment Methods - matches React: bg-white rounded-2xl p-4 shadow-sm
                      Container(
                        margin: const EdgeInsets.only(bottom: 16), // space-y-4
                        padding: const EdgeInsets.all(16), // p-4
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(16), // rounded-2xl
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.only(bottom: 16), // mb-4
                              child: Text(
                                l10n.paymentMethod,
                                style: AppTextStyles.bodyMedium(
                                  color: AppColors.foreground,
                                ).copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                            ..._getPaymentMethods(context).map((method) {
                              final isSelected =
                                  _selectedPayment == method['id'];
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedPayment = method['id'] as String;
                                  });
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(
                                      bottom: 12), // space-y-3
                                  padding: const EdgeInsets.all(16), // p-4
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.lavenderLight
                                        : Colors.transparent,
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.purple
                                          : Colors.grey[200]!,
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                        16), // rounded-2xl
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 48, // w-12
                                        height: 48, // h-12
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? AppColors.purple
                                              : Colors.grey[100],
                                          borderRadius: BorderRadius.circular(
                                              12), // rounded-xl
                                        ),
                                        child: Icon(
                                          method['icon'] as IconData,
                                          size: 24, // w-6 h-6
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.grey[500],
                                        ),
                                      ),
                                      const SizedBox(width: 16), // gap-4
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              method['name'] as String,
                                              style: AppTextStyles.bodyMedium(
                                                color: AppColors.foreground,
                                              ).copyWith(
                                                  fontWeight: FontWeight.w500),
                                            ),
                                            Text(
                                              method['description'] as String,
                                              style: AppTextStyles.labelSmall(
                                                color:
                                                    AppColors.mutedForeground,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        width: 24, // w-6
                                        height: 24, // h-6
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isSelected
                                              ? AppColors.purple
                                              : Colors.transparent,
                                          border: Border.all(
                                            color: isSelected
                                                ? AppColors.purple
                                                : Colors.grey[300]!,
                                            width: 2,
                                          ),
                                        ),
                                        child: isSelected
                                            ? const Icon(
                                                Icons.check,
                                                size: 16, // w-4 h-4
                                                color: Colors.white,
                                              )
                                            : null,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),

                      // Price Summary - matches React: bg-white rounded-2xl p-4 shadow-sm
                      Container(
                        margin: const EdgeInsets.only(bottom: 16), // space-y-4
                        padding: const EdgeInsets.all(16), // p-4
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(16), // rounded-2xl
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.only(bottom: 16), // mb-4
                              child: Text(
                                l10n.orderSummary,
                                style: AppTextStyles.bodyMedium(
                                  color: AppColors.foreground,
                                ).copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                            // Price rows - matches React: space-y-3
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  l10n.coursePrice,
                                  style: AppTextStyles.bodyMedium(
                                    color: AppColors.mutedForeground,
                                  ),
                                ),
                                Text(
                                  _formatCheckoutMoney(l10n, _originalPrice),
                                  style: AppTextStyles.bodyMedium(
                                    color: AppColors.foreground,
                                  ).copyWith(fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                            if (_couponApplied && _discountAmount > 0) ...[
                              const SizedBox(height: 12), // space-y-3
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    l10n.discount,
                                    style: AppTextStyles.bodyMedium(
                                      color: Colors.green[600],
                                    ),
                                  ),
                                  Text(
                                    '-${_formatCheckoutMoney(l10n, _discountAmount)}',
                                    style: AppTextStyles.bodyMedium(
                                      color: Colors.green[600],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 12),
                            Container(
                              height: 1,
                              color: Colors.grey[100],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  l10n.total,
                                  style: AppTextStyles.bodyMedium(
                                    color: AppColors.foreground,
                                  ).copyWith(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  _formatCheckoutMoney(l10n, _finalPrice),
                                  style: AppTextStyles.h2(
                                    color: AppColors.purple,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Checkout Button - matches React
                      GestureDetector(
                        onTap: _selectedPayment == null || _isProcessing
                            ? null
                            : _handleCheckout,
                        child: Container(
                          width: double.infinity,
                          padding:
                              const EdgeInsets.symmetric(vertical: 16), // py-4
                          decoration: BoxDecoration(
                            color: _selectedPayment != null && !_isProcessing
                                ? AppColors.purple
                                : Colors.grey[200],
                            borderRadius:
                                BorderRadius.circular(16), // rounded-2xl
                          ),
                          child: Center(
                            child: Text(
                              _isProcessing
                                  ? l10n.processing
                                  : l10n.confirmPayment,
                              style: AppTextStyles.buttonLarge(
                                color:
                                    _selectedPayment != null && !_isProcessing
                                        ? Colors.white
                                        : Colors.grey[400],
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseImage(Map<String, dynamic> course) {
    // Try thumbnail first, then image, then banner
    String? imageUrl;
    if (course['thumbnail'] != null) {
      imageUrl = course['thumbnail']?.toString();
    } else if (course['image'] != null) {
      imageUrl = course['image']?.toString();
    } else if (course['banner'] != null) {
      imageUrl = course['banner']?.toString();
    }

    if (imageUrl != null &&
        imageUrl.isNotEmpty &&
        imageUrl.startsWith('http')) {
      // Network image
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: AppColors.purple.withOpacity(0.1),
          child: const Icon(
            Icons.image,
            color: AppColors.purple,
          ),
        ),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: AppColors.purple.withOpacity(0.1),
            child: const Center(
              child: CircularProgressIndicator(
                color: AppColors.purple,
                strokeWidth: 2,
              ),
            ),
          );
        },
      );
    } else if (imageUrl != null && imageUrl.isNotEmpty) {
      // Asset image
      return Image.asset(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: AppColors.purple.withOpacity(0.1),
          child: const Icon(
            Icons.image,
            color: AppColors.purple,
          ),
        ),
      );
    } else {
      // Placeholder
      return Container(
        color: AppColors.purple.withOpacity(0.1),
        child: const Icon(
          Icons.menu_book_rounded,
          color: AppColors.purple,
          size: 40,
        ),
      );
    }
  }
}
