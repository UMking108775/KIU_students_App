import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_config.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../config/app_routes.dart';
import '../../providers/category_provider.dart';
import '../../providers/notification_provider.dart';
import '../../screens/category/category_screen.dart';
import '../../services/portal_visit_service.dart';
import '../../widgets/common/connectivity_banner.dart';
import '../../widgets/home/app_drawer.dart';
import '../../widgets/audio/mini_player.dart';
import '../../widgets/home/category_card.dart';
import '../../widgets/common/zoom_drawer.dart';
import '../../screens/web/web_portal_screen.dart';

/// Home screen with user greeting and main categories
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ZoomDrawerController _zoomDrawerController = ZoomDrawerController();
  final PortalVisitService _portalService = PortalVisitService();

  @override
  void initState() {
    super.initState();
    // Load categories when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CategoryProvider>().loadCategories();
      context.read<NotificationProvider>().fetchUnreadCount();
      _checkWeeklyPortalVisit();
    });
  }

  Future<void> _checkWeeklyPortalVisit() async {
    final needsVisit = await _portalService.needsWeeklyVisit();
    if (needsVisit && mounted) {
      // Force user to visit portal
      _showForcedVisitDialog();
    }
  }

  void _showForcedVisitDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          title: const Text('Weekly Check-in Required'),
          content: const Text(
            'To ensure you stay updated, you must visit the KIU Web Portal at least once a week.\n\nPlease take a moment to visit the portal now.',
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const WebPortalScreen(isForced: true),
                    ),
                  ).then((_) {
                    // Re-check when coming back, maybe they didn't load it fully or just closed it immediately?
                    // But WebPortalScreen marks visit in initState, so simply opening it clears the flag.
                    // Ideally we might want to check if page loaded successfully, but for now this suffices.
                  });
                },
                child: const Text('Visit Portal Now'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 17) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  Future<void> _handleRefresh() async {
    await context.read<CategoryProvider>().refreshCategories();
  }

  Future<void> _openWhatsApp() async {
    final authProvider = context.read<AuthProvider>();
    final kiuId = authProvider.user?.kiuId ?? '';
    final message = '${AppConfig.noAccessMessage}$kiuId';
    final encodedMessage = Uri.encodeComponent(message);
    final whatsappUrl =
        'https://wa.me/${AppConfig.adminWhatsApp}?text=$encodedMessage';

    final uri = Uri.parse(whatsappUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open WhatsApp'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final userName = authProvider.user?.name ?? 'Student';

    return ChangeNotifierProvider.value(
      value: _zoomDrawerController,
      child: ZoomDrawer(
        controller: _zoomDrawerController,
        menuScreen: const AppDrawer(),
        mainScreen: Scaffold(
          key: _scaffoldKey,
          backgroundColor: AppColors.background,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => _zoomDrawerController.toggle(),
            ),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo with white circular background
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Image.asset('assets/images/kiu_logo.png', height: 28),
                ),
                const SizedBox(width: 10),
                const Text('KIU Students'),
              ],
            ),
            actions: [
              Consumer<NotificationProvider>(
                builder: (context, provider, _) {
                  return IconButton(
                    icon: Badge(
                      label: Text('${provider.unreadCount}'),
                      isLabelVisible: provider.unreadCount > 0,
                      backgroundColor: AppColors.error,
                      child: const Icon(Icons.notifications_outlined),
                    ),
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.notifications,
                      ).then((_) => provider.fetchUnreadCount());
                    },
                  );
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Column(
            children: [
              // Connectivity Banner
              const ConnectivityBanner(),

              // Main Content
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _handleRefresh,
                  color: AppColors.primary,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      // Greeting Header
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getGreeting(),
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                userName,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Offline Mode Banner
                      Consumer<CategoryProvider>(
                        builder: (context, categoryProvider, _) {
                          if (categoryProvider.isOfflineMode) {
                            return SliverToBoxAdapter(
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.warning.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.warning.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.cloud_off_outlined,
                                      color: AppColors.warning,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'You are offline. Showing cached data.',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: AppColors.warning,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                          return const SliverToBoxAdapter(
                            child: SizedBox.shrink(),
                          );
                        },
                      ),

                      // Section Title
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                          child: Text(
                            'Categories',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                      ),

                      // Categories Grid
                      Consumer<CategoryProvider>(
                        builder: (context, categoryProvider, _) {
                          if (categoryProvider.isLoading &&
                              !categoryProvider.hasCategories) {
                            return const SliverFillRemaining(
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

                          if (categoryProvider.errorMessage != null &&
                              !categoryProvider.hasCategories) {
                            return SliverFillRemaining(
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.error_outline,
                                        size: 64,
                                        color: AppColors.textSecondary,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        categoryProvider.errorMessage!,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium,
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 16),
                                      ElevatedButton(
                                        onPressed: () =>
                                            categoryProvider.loadCategories(),
                                        child: const Text('Retry'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }

                          // No categories - show access denied message
                          if (!categoryProvider.hasCategories) {
                            return SliverFillRemaining(
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          color: AppColors.error.withValues(
                                            alpha: 0.1,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.lock_outline,
                                          size: 48,
                                          color: AppColors.error,
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      Text(
                                        'No Access to Materials',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'You don\'t have access to study materials. Please contact the administrator to get access.',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: AppColors.textSecondary,
                                            ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 24),
                                      ElevatedButton.icon(
                                        onPressed: _openWhatsApp,
                                        icon: const Icon(Icons.chat_outlined),
                                        label: const Text(
                                          'Contact on WhatsApp',
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF25D366,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 24,
                                            vertical: 14,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        AppConfig.adminWhatsAppDisplay,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: AppColors.textHint,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }

                          return SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            sliver: SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    mainAxisSpacing: 16,
                                    crossAxisSpacing: 16,
                                    childAspectRatio: 0.85,
                                  ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final category =
                                      categoryProvider.categories[index];
                                  return CategoryCard(
                                    category: category,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => CategoryScreen(
                                            category: category,
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                                childCount: categoryProvider.categories.length,
                              ),
                            ),
                          );
                        },
                      ),

                      // Bottom padding for mini player
                      const SliverToBoxAdapter(child: SizedBox(height: 100)),
                    ],
                  ),
                ),
              ),

              // Mini Player
              const MiniPlayer(),
            ],
          ),
        ),
      ),
    );
  }
}
