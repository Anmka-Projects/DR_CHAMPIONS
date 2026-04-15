import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../../core/design/app_colors.dart';
import '../../core/design/app_text_styles.dart';
import '../../core/design/app_radius.dart';
import '../../core/localization/localization_helper.dart';
import '../../services/notifications_service.dart';
import '../../services/push_inbox_service.dart';

/// Notifications screen: LMS API list merged with FCM messages stored on device.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _notifications = [];
  int _unreadCount = 0;
  StreamSubscription<void>? _inboxSub;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _inboxSub = PushInboxService.onInboxChanged.listen((_) {
      if (mounted) _loadNotifications();
    });
  }

  @override
  void dispose() {
    _inboxSub?.cancel();
    super.dispose();
  }

  List<Map<String, dynamic>> _mergeWithPushInbox(
    List<Map<String, dynamic>> apiList,
    List<Map<String, dynamic>> localList,
  ) {
    final merged = <Map<String, dynamic>>[...localList, ...apiList];
    merged.sort((a, b) {
      final da = DateTime.tryParse(a['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final db = DateTime.tryParse(b['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return db.compareTo(da);
    });
    final seen = <String>{};
    final out = <Map<String, dynamic>>[];
    for (final n in merged) {
      final id = n['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      if (!seen.add(id)) continue;
      out.add(n);
    }
    return out;
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      final response = await NotificationsService.instance.getNotifications(
        page: 1,
        perPage: 50,
        unreadOnly: false,
      );

      // Handle response - safely check if data is a List or Map
      List<Map<String, dynamic>> notificationsList = [];

      final data = response['data'];

      if (data != null) {
        if (data is List) {
          // Data is directly a List
          try {
            notificationsList = data.map((item) {
              if (item is Map<String, dynamic>) {
                return item;
              } else if (item is Map) {
                return Map<String, dynamic>.from(item);
              } else {
                return <String, dynamic>{};
              }
            }).toList();
          } catch (e) {
            debugPrint('❌ Error parsing List data: $e');
          }
        } else if (data is Map<String, dynamic>) {
          // Data is a Map, check for common keys
          final dataMap = data;

          // Try different possible keys
          final possibleKeys = ['notifications', 'items', 'list', 'data'];
          for (final key in possibleKeys) {
            if (dataMap[key] != null && dataMap[key] is List) {
              try {
                notificationsList = (dataMap[key] as List).map((item) {
                  if (item is Map<String, dynamic>) {
                    return item;
                  } else if (item is Map) {
                    return Map<String, dynamic>.from(item);
                  } else {
                    return <String, dynamic>{};
                  }
                }).toList();
                break; // Found the list, exit loop
              } catch (e) {
                debugPrint('❌ Error parsing $key: $e');
              }
            }
          }
        }
      }

      final localPush = await PushInboxService.instance.getAll();
      notificationsList = _mergeWithPushInbox(notificationsList, localPush);

      final unreadCount = notificationsList
          .where((n) => (n['is_read'] ?? false) == false)
          .length;

      setState(() {
        _notifications = notificationsList;
        _unreadCount = unreadCount;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      setState(() => _isLoading = false);
      if (mounted) {
        // Print error for debugging
        debugPrint('❌ Error loading notifications: $e');
        debugPrint('Stack trace: $stackTrace');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.errorLoadingNotifications(e.toString())),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    final idx =
        _notifications.indexWhere((n) => n['id']?.toString() == notificationId);
    final isLocalFcm = idx >= 0 &&
        _notifications[idx]['source']?.toString() == 'fcm_local';
    if (isLocalFcm) {
      try {
        await PushInboxService.instance.markAsRead(notificationId);
        if (mounted) await _loadNotifications();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(context.l10n.errorUpdatingNotification(e.toString())),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
      return;
    }

    try {
      await NotificationsService.instance.markAsRead(notificationId);
      // Update local state immediately for better UX
      setState(() {
        final index = _notifications.indexWhere(
          (n) => n['id']?.toString() == notificationId,
        );
        if (index != -1) {
          _notifications[index]['is_read'] = true;
          _unreadCount = _unreadCount > 0 ? _unreadCount - 1 : 0;
        }
      });
      // Reload notifications to sync with server
      await _loadNotifications();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.errorUpdatingNotification(e.toString())),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await PushInboxService.instance.markAllRead();
      await NotificationsService.instance.markAllAsRead();
      // Update local state immediately
      setState(() {
        for (var notification in _notifications) {
          notification['is_read'] = true;
        }
        _unreadCount = 0;
      });
      // Reload notifications to sync with server
      await _loadNotifications();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.errorUpdatingNotifications(e.toString())),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _newNotifications => _notifications
      .where((n) => (n['is_read'] ?? n['isNew']) == false)
      .toList();

  List<Map<String, dynamic>> get _readNotifications => _notifications
      .where((n) => (n['is_read'] ?? n['isNew']) == true)
      .toList();

  String _formatTime(BuildContext context, String? createdAt) {
    if (createdAt == null) return context.l10n.recently;
    try {
      final date = DateTime.parse(createdAt);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 1) {
        return context.l10n.now;
      } else if (difference.inMinutes < 60) {
        return context.l10n.minutesAgoShort(difference.inMinutes);
      } else if (difference.inHours < 24) {
        return context.l10n.hoursAgoShort(difference.inHours);
      } else if (difference.inDays < 7) {
        return context.l10n.daysAgoShort(difference.inDays);
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return context.l10n.recently;
    }
  }

  IconData _getIconFromString(String? iconName) {
    if (iconName == null) return Icons.notifications;

    final iconMap = {
      'book': Icons.menu_book,
      'menu_book': Icons.menu_book,
      'emoji_events': Icons.emoji_events,
      'trophy': Icons.emoji_events,
      'message': Icons.message,
      'campaign': Icons.campaign,
      'announcement': Icons.campaign,
      'notifications_active': Icons.notifications_active,
      'course': Icons.school,
      'school': Icons.school,
      'update': Icons.update,
      'course_update': Icons.update,
      'achievement': Icons.emoji_events,
    };

    return iconMap[iconName.toLowerCase()] ?? Icons.notifications;
  }

  Color _parseColor(dynamic colorValue) {
    if (colorValue == null) return AppColors.purple;
    if (colorValue is Color) return colorValue;
    if (colorValue is String) {
      String hex = colorValue.replaceAll('#', '');
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      }
    }
    return AppColors.purple;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.beige,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Header - Purple gradient like Home
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0C52B3), Color(0xFF093F8A)],
                ),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back button and title - matches React: gap-4 mb-4
                  Row(
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
                        context.l10n.notificationsTitle,
                        style: AppTextStyles.h3(color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16), // mb-4
                  // Notification count - matches React: gap-2
                  Row(
                    children: [
                      Icon(
                        Icons.notifications,
                        size: 20, // w-5 h-5
                        color: Colors.white.withOpacity(0.7), // white/70
                      ),
                      const SizedBox(width: 8), // gap-2
                      Text(
                        context.l10n.newNotificationsCount(
                          _unreadCount > 0 ? _unreadCount : _newNotifications.length,
                        ),
                        style: AppTextStyles.bodyMedium(
                          color: Colors.white.withOpacity(0.7), // white/70
                        ),
                      ),
                      const Spacer(),
                      // Mark all as read button
                      if (_newNotifications.isNotEmpty)
                        GestureDetector(
                          onTap: _markAllAsRead,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              context.l10n.markAllAsRead,
                              style: GoogleFonts.cairo(
                                fontSize: 12,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Content - matches React: px-4 -mt-4 space-y-6
            Expanded(
              child: Transform.translate(
                offset: const Offset(0, -16), // -mt-4
                child: _isLoading
                    ? _buildNotificationsSkeleton()
                    : RefreshIndicator(
                        onRefresh: _loadNotifications,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16), // px-4
                          child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 24), // space-y-6

                            // New Notifications section
                            if (_newNotifications.isNotEmpty) ...[
                              Text(
                                context.l10n.newSection,
                                style: AppTextStyles.bodySmall(
                                  color: AppColors.foreground,
                                ).copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 12), // mb-3
                              ..._newNotifications.asMap().entries.map((entry) {
                                final index = entry.key;
                                final notification = entry.value;
                                return TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0.0, end: 1.0),
                                  duration: Duration(
                                      milliseconds: 400 + (index * 100)),
                                  curve: Curves.easeOut,
                                  builder: (context, value, child) {
                                    return Transform.translate(
                                      offset: Offset(0, 20 * (1 - value)),
                                      child: Opacity(
                                        opacity: value,
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: GestureDetector(
                                    onTap: () {
                                      final notificationId =
                                          notification['id']?.toString();
                                      if (notificationId != null) {
                                        _markAsRead(notificationId);
                                      }
                                      // Handle navigation if action_type exists
                                      final actionValue =
                                          notification['action_value'];
                                      if (actionValue != null && mounted) {
                                        // Navigate based on action_value
                                        // You can implement navigation logic here
                                      }
                                    },
                                    child: _buildNotificationCard(context, notification,
                                        isNew: true),
                                  ),
                                );
                              }),
                            ],

                            const SizedBox(height: 24), // space-y-6

                            // Read Notifications section
                            if (_readNotifications.isNotEmpty) ...[
                              Text(
                                context.l10n.past,
                                style: AppTextStyles.bodySmall(
                                  color: AppColors.foreground,
                                ).copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 12), // mb-3
                              ..._readNotifications
                                  .asMap()
                                  .entries
                                  .map((entry) {
                                final index = entry.key;
                                final notification = entry.value;
                                return TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0.0, end: 1.0),
                                  duration: Duration(
                                    milliseconds: 400 +
                                        ((_newNotifications.length + index) *
                                            100),
                                  ),
                                  curve: Curves.easeOut,
                                  builder: (context, value, child) {
                                    return Transform.translate(
                                      offset: Offset(0, 20 * (1 - value)),
                                      child: Opacity(
                                        opacity: value,
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: _buildNotificationCard(context, notification,
                                      isNew: false),
                                );
                              }),
                            ],

                            // Empty state - matches React
                            if (_notifications.isEmpty)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 80),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 96, // w-24
                                      height: 96, // h-24
                                      decoration: const BoxDecoration(
                                        color: AppColors.lavenderLight,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.notifications,
                                        size: 48, // w-12 h-12
                                        color: AppColors.purple,
                                      ),
                                    ),
                                    const SizedBox(height: 16), // mb-4
                                    Text(
                                      context.l10n.noNotifications,
                                      style: AppTextStyles.h4(
                                        color: AppColors.foreground,
                                      ),
                                    ),
                                    const SizedBox(height: 8), // mb-2
                                    Text(
                                      context.l10n.newNotificationsWillAppear,
                                      style: AppTextStyles.bodyMedium(
                                        color: AppColors.mutedForeground,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),

                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard(BuildContext context, Map<String, dynamic> notification,
      {required bool isNew}) {
    final color = _parseColor(notification['color']?.toString());
    final icon = notification['icon'] is IconData
        ? notification['icon'] as IconData
        : _getIconFromString(notification['icon']?.toString());
    final title = notification['title'] ?? '';
    final message = notification['body'] ?? notification['message'] ?? '';
    final time = notification['created_at'] != null
        ? _formatTime(context, notification['created_at']?.toString())
        : (notification['time'] ?? context.l10n.recently);

    return Container(
      margin: const EdgeInsets.only(bottom: 12), // space-y-3
      decoration: BoxDecoration(
        color: isNew
            ? Colors.white
            : Colors.white.withOpacity(0.7), // bg-white or bg-white/70
        borderRadius: BorderRadius.circular(16), // rounded-2xl
        boxShadow: isNew
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Stack(
        children: [
          // Purple indicator for new notifications - matches React
          if (isNew)
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              child: Container(
                width: 8, // w-2
                decoration: const BoxDecoration(
                  color: AppColors.purple,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
              ),
            ),

          // Content - matches React: flex items-start gap-3 pr-3
          Padding(
            padding: EdgeInsets.only(
              top: 16, // p-4
              bottom: 16,
              left: 16,
              right: isNew ? 24 : 16, // pr-3 for new notifications
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon container - matches React: w-12 h-12 rounded-xl
                Container(
                  width: 48, // w-12
                  height: 48, // h-12
                  decoration: BoxDecoration(
                    color: color.withOpacity(
                        isNew ? 0.15 : 0.1), // color15 or opacity-60
                    borderRadius: BorderRadius.circular(12), // rounded-xl
                  ),
                  child: Icon(
                    icon,
                    size: 24, // w-6 h-6
                    color: isNew ? color : color.withOpacity(0.6),
                  ),
                ),
                const SizedBox(width: 12), // gap-3
                // Text content - matches React: flex-1
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.toString(),
                        style: AppTextStyles.bodyMedium(
                          color: AppColors.foreground,
                        ).copyWith(
                          fontWeight: isNew ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4), // mb-1
                      Text(
                        message.toString(),
                        style: AppTextStyles.bodySmall(
                          color: AppColors.mutedForeground,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8), // mb-2
                      Text(
                        time.toString(),
                        style: AppTextStyles.labelSmall(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Skeleton Loading Widget
  Widget _buildNotificationsSkeleton() {
    return Skeletonizer(
      enabled: true,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            // Section header skeleton
            Container(
              height: 16,
              width: 60,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 12),
            // Notification cards skeleton
            ...List.generate(5, (index) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon skeleton
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Text skeleton
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 14,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 12,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            height: 12,
                            width: 100,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 10,
                            width: 60,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 24),
            // Another section header skeleton
            Container(
              height: 16,
              width: 60,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 12),
            // More notification cards skeleton
            ...List.generate(3, (index) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 14,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 12,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 10,
                            width: 60,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
