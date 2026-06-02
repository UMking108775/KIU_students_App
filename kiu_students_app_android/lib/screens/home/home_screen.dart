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
import '../../services/guest_service.dart';
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
      _checkWeeklyPortalVisit(); // Moved from original
    });
  }

  @override
  void dispose() {
    _zoomDrawerController.dispose();
    super.dispose();
  }

  Future<void> _checkWeeklyPortalVisit() async {
    // Skip for guest mode
    if (context.read<AuthProvider>().isGuestMode) return;

    final needsLogin = await _portalService.needsWeeklyLogin();
    if (needsLogin && mounted) {
      // Force user to login to portal
      _showForcedLoginDialog();
    }
  }

  void _showForcedLoginDialog() {
    showDialog(
      context: context,
      barrierDismissible: true, // Allow clicking outside to close
      builder: (context) => AlertDialog(
        title: const Text('Weekly Login Suggestion'), // Changed title
        content: const Text(
          'To keep your access active, it is recommended to login to the KIU Web Portal once a week.\n\nWould you like to login now?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const WebPortalScreen(isForced: true),
                ),
              ).then((_) async {
                // Re-check after returning, but don't force dialog again immediately
                await _portalService.needsWeeklyLogin();
              });
            },
            child: const Text('Login to Portal'),
          ),
        ],
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
    // Urdu message: "Assalam-o-Alaikum, Main KIU ka student hun aur mujhe study material tak rasai chahiye. Meri KIU ID hai: "
    final message =
        'السلام علیکم، میں KIU کا طالب علم ہوں اورمجھے جامعہ کی ایپ تک رسائی چاہیے۔ میری KIU ID ہے: $kiuId';
    final encodedMessage = Uri.encodeComponent(message);
    final whatsappUrl =
        'https://wa.me/${AppConfig.adminWhatsApp}?text=$encodedMessage';

    final uri = Uri.parse(whatsappUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch WhatsApp';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('WhatsApp نہیں کھل سکا: ${e.toString()}'),
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
        mainScreen: Builder(
          builder: (context) {
            final colors = AppColors.of(context);
            return Scaffold(
              key: _scaffoldKey,
              backgroundColor: colors.background,
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
                      child: Image.asset(
                        'assets/images/kiu_logo.png',
                        height: 28,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text('KIU Students'),
                  ],
                ),
                actions: [
                  Consumer<NotificationProvider>(
                    builder: (context, provider, _) {
                      final hasUnread = provider.unreadCount > 0;
                      return IconButton(
                        icon: Badge(
                          label: Text('${provider.unreadCount}'),
                          isLabelVisible: hasUnread,
                          backgroundColor: colors.error,
                          child: Icon(
                            hasUnread
                                ? Icons
                                      .notifications // Filled when unread
                                : Icons
                                      .notifications_outlined, // Outline when all read
                            color: hasUnread ? Colors.amber : null,
                          ),
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
                      color: colors.primary,
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
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(color: colors.textSecondary),
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
                                      color: colors.warning.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: colors.warning.withValues(
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
                                                  color: colors.warning,
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
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                24,
                                20,
                                12,
                              ),
                              child: Text(
                                'Categories',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                          ),

                          // Guest Mode Banner
                          Consumer<AuthProvider>(
                            builder: (context, authProvider, _) {
                              if (!authProvider.isGuestMode) {
                                return const SliverToBoxAdapter(
                                  child: SizedBox.shrink(),
                                );
                              }
                              return SliverToBoxAdapter(
                                child: Container(
                                  margin: const EdgeInsets.fromLTRB(
                                    20,
                                    0,
                                    20,
                                    16,
                                  ),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        colors.primary.withValues(alpha: 0.1),
                                        colors.primary.withValues(alpha: 0.05),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: colors.primary.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.visibility_outlined,
                                            color: AppColors.primary,
                                            size: 24,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Guest Preview Mode',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleSmall
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: colors.primary,
                                                      ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'You can preview 1 audio & 1 PDF. Register for full access!',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: colors
                                                            .textSecondary,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: () {
                                            authProvider.exitGuestMode();
                                            Navigator.pushReplacementNamed(
                                              context,
                                              AppRoutes.login,
                                            );
                                          },
                                          child: const Text('Login / Register'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),

                          // Categories Grid
                          Consumer2<CategoryProvider, AuthProvider>(
                            builder: (context, categoryProvider, authProvider, _) {
                              if (categoryProvider.isLoading &&
                                  !categoryProvider.hasCategories) {
                                return const SliverFillRemaining(
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }

                              if (categoryProvider.errorMessage != null &&
                                  !categoryProvider.hasCategories) {
                                return SliverFillRemaining(
                                  child: Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(32),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.error_outline,
                                            size: 64,
                                            color: colors.textSecondary,
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
                                            onPressed: () => categoryProvider
                                                .loadCategories(),
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
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(20),
                                            decoration: BoxDecoration(
                                              color: colors.error.withValues(
                                                alpha: 0.1,
                                              ),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.lock_outline,
                                              size: 48,
                                              color: colors.error,
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
                                                  color: colors.textSecondary,
                                                ),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 24),
                                          ElevatedButton.icon(
                                            onPressed: _openWhatsApp,
                                            icon: const Icon(
                                              Icons.chat_outlined,
                                            ),
                                            label: const Text(
                                              'Contact on WhatsApp',
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(
                                                0xFF25D366,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
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
                                                  color: colors.textHint,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }

                              // Filter categories for guest mode
                              var categories = categoryProvider.categories;
                              if (authProvider.isGuestMode) {
                                categories = GuestService()
                                    .filterCategoriesForGuest(categories);
                              }

                              return SliverPadding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                sliver: SliverGrid(
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        mainAxisSpacing: 16,
                                        crossAxisSpacing: 16,
                                        childAspectRatio: 0.85,
                                      ),
                                  delegate: SliverChildBuilderDelegate((
                                    context,
                                    index,
                                  ) {
                                    final category = categories[index];
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
                                  }, childCount: categories.length),
                                ),
                              );
                            },
                          ),

                          // Bottom padding for mini player
                          const SliverToBoxAdapter(
                            child: SizedBox(height: 100),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Mini Player
                  const MiniPlayer(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
