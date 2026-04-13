import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/design/app_colors.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/navigation/route_names.dart';
import '../../services/chat_service.dart';

/// Chat conversations list – WhatsApp-style, app colors.
/// For both teachers and students.
class ChatConversationsScreen extends StatefulWidget {
  const ChatConversationsScreen({super.key});

  @override
  State<ChatConversationsScreen> createState() =>
      _ChatConversationsScreenState();
}

class _ChatConversationsScreenState extends State<ChatConversationsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _conversations = [];

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ChatService.instance.getConversations();
      final list = res['conversations'] ?? res['data'] ?? res['items'];
      final convs = list is List
          ? list
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : <Map<String, dynamic>>[];
      if (mounted) {
        setState(() {
          _conversations = convs;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return Scaffold(
      backgroundColor: AppColors.beige,
      appBar: AppBar(
        title: Text(
          isAr ? 'المحادثات' : 'Chat',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.purple,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError(isAr)
              : _conversations.isEmpty
                  ? _buildEmpty(isAr)
                  : RefreshIndicator(
                      onRefresh: _loadConversations,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _conversations.length,
                        itemBuilder: (_, i) => _buildConversationTile(
                          _conversations[i],
                          isAr,
                        ),
                      ),
                    ),
    );
  }

  Widget _buildError(bool isAr) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 48, color: AppColors.destructive),
            const SizedBox(height: 16),
            Text(
              _error ?? '',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 14,
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _loadConversations,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(isAr ? 'إعادة المحاولة' : 'Retry',
                  style: GoogleFonts.cairo()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(bool isAr) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline_rounded,
              size: 64, color: AppColors.purple.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            isAr ? 'لا توجد محادثات' : 'No conversations yet',
            style: GoogleFonts.cairo(
              fontSize: 16,
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationTile(Map<String, dynamic> conv, bool isAr) {
    final other =
        conv['otherUser'] ?? conv['participant'] ?? conv['user'] ?? {};
    final otherMap =
        other is Map ? Map<String, dynamic>.from(other) : <String, dynamic>{};
    final name = otherMap['name'] ??
        otherMap['userName'] ??
        conv['otherUserName'] ??
        (isAr ? 'مستخدم' : 'User');
    final avatar = otherMap['avatar'];
    final lastMsg = conv['lastMessage'] ?? conv['last_message'];
    final lastBody = lastMsg is Map
        ? (lastMsg['body'] ?? lastMsg['text'] ?? '')
        : lastMsg?.toString() ?? '';
    final lastTime =
        lastMsg is Map ? (lastMsg['createdAt'] ?? lastMsg['created_at']) : null;
    final unread = conv['unreadCount'] ?? conv['unread_count'] ?? 0;
    final unreadNum = unread is num ? unread.toInt() : 0;
    final conversationId = conv['id']?.toString() ?? '';

    return InkWell(
      onTap: () {
        if (conversationId.isEmpty) return;
        context.push(
          RouteNames.chatMessages.replaceAll(':conversationId', conversationId),
          extra: {
            'conversationId': conversationId,
            'otherUser': otherMap,
            'conversation': conv,
          },
        );
      },
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.purple.withOpacity(0.2),
              backgroundImage: avatar != null && avatar.toString().isNotEmpty
                  ? NetworkImage(ApiEndpoints.getImageUrl(avatar.toString()))
                  : null,
              child: avatar == null || avatar.toString().isEmpty
                  ? Text(
                      (name.toString().isNotEmpty ? name[0] : '?')
                          .toUpperCase(),
                      style: GoogleFonts.cairo(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.purple,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name.toString(),
                          style: GoogleFonts.cairo(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.foreground,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (lastTime != null)
                        Text(
                          _formatTime(lastTime.toString()),
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lastBody.toString(),
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            color: AppColors.mutedForeground,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unreadNum > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.purple,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            unreadNum > 99 ? '99+' : '$unreadNum',
                            style: GoogleFonts.cairo(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
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
    );
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.tryParse(iso);
      if (dt == null) return iso;
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inDays == 0) {
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } else if (diff.inDays == 1) {
        return 'Yesterday';
      } else if (diff.inDays < 7) {
        return '${diff.inDays}d';
      }
      return '${dt.day}/${dt.month}';
    } catch (_) {
      return iso;
    }
  }
}
