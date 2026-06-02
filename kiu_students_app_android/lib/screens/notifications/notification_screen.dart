import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../config/app_theme.dart';
import '../../models/notification_model.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/common/zoom_drawer.dart';
import '../../widgets/home/app_drawer.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final ZoomDrawerController _zoomDrawerController = ZoomDrawerController();

  @override
  void initState() {
    super.initState();
    // Fetch notifications on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().fetchNotifications(refresh: true);
    });
  }

  Future<void> _handleRefresh() async {
    await context.read<NotificationProvider>().fetchNotifications(
      refresh: true,
    );
  }

  void _handleNotificationTap(NotificationModel notification) {
    if (!notification.isRead) {
      context.read<NotificationProvider>().markAsRead(notification.id);
    }

    // Handle navigation based on type or action_url
    if (notification.categoryId != null) {
      // Navigate to category
      // Navigator.pushNamed(context, '/category', arguments: notification.categoryId);
      // For now just show snackbar as we need proper routing setup
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ChangeNotifierProvider(
      create: (_) => _zoomDrawerController,
      child: ZoomDrawer(
        controller: _zoomDrawerController,
        menuScreen: const AppDrawer(),
        mainScreen: Scaffold(
          backgroundColor: colors.background,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: AppBar(
              toolbarHeight: 48,
              automaticallyImplyLeading: false,
              leading: IconButton(
                icon: const Icon(Icons.menu, size: 22),
                onPressed: () => _zoomDrawerController.toggle(),
                padding: EdgeInsets.zero,
              ),
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Image.asset(
                      'assets/images/kiu_logo.png',
                      height: 22,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('KIU Students', style: TextStyle(fontSize: 15)),
                ],
              ),
              centerTitle: false,
            ),
          ),
          body: Column(
            children: [
              // Header with inline back button
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  children: [
                    // Back button
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.arrow_back_ios_new,
                          size: 16,
                          color: colors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Icon and title
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: colors.info.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.notifications_outlined,
                        color: colors.info,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Consumer<NotificationProvider>(
                        builder: (context, provider, _) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Notifications',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: colors.textPrimary,
                              ),
                            ),
                            Text(
                              '${provider.notifications.length} notifications',
                              style: TextStyle(
                                fontSize: 11,
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Read All button
                    TextButton.icon(
                      onPressed: () {
                        context.read<NotificationProvider>().markAllAsRead();
                      },
                      icon: const Icon(Icons.done_all, size: 14),
                      label: const Text(
                        'Read All',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: colors.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Consumer<NotificationProvider>(
                  builder: (context, provider, child) {
                    if (provider.isLoading && provider.notifications.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (provider.notifications.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: colors.info.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                Icons.notifications_off_outlined,
                                size: 28,
                                color: colors.info,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'No Notifications',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'You\'re all caught up!',
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: _handleRefresh,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: provider.notifications.length,
                        itemBuilder: (context, index) {
                          final notification = provider.notifications[index];
                          return _NotificationCard(
                            notification: notification,
                            onTap: () => _handleNotificationTap(notification),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;

  const _NotificationCard({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    Color typeColor = colors.info;
    IconData typeIcon = Icons.info_outline;

    switch (notification.type) {
      case 'success':
        typeColor = colors.success;
        typeIcon = Icons.check_circle_outline;
        break;
      case 'warning':
        typeColor = colors.warning;
        typeIcon = Icons.warning_amber_rounded;
        break;
      case 'error':
        typeColor = colors.error;
        typeIcon = Icons.error_outline;
        break;
      case 'announcement':
        typeColor = colors.primary;
        typeIcon = Icons.campaign_outlined;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: notification.isRead
            ? colors.surface
            : colors.primary.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: notification.isRead
              ? colors.border
              : colors.primary.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(typeIcon, color: typeColor, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: notification.isRead
                                  ? FontWeight.w500
                                  : FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        if (!notification.isRead) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: colors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      notification.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(notification.createdAt),
                      style: TextStyle(fontSize: 10, color: colors.textHint),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d, y').format(date);
    }
  }
}
