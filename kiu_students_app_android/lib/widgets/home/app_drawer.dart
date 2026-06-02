import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../../config/app_routes.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/portal_visit_service.dart';
import '../../widgets/common/zoom_drawer.dart';
import '../../screens/downloads/my_downloaded_audio_screen.dart';
import '../../screens/downloads/my_downloaded_pdf_screen.dart';
import '../../screens/web/web_portal_screen.dart';
import '../../screens/web/printshop_screen.dart';

/// Modern light-themed app drawer
class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  final PortalVisitService _portalService = PortalVisitService();
  bool _needsLogin = false;
  String? _lastLoginText;
  String _appVersion = ''; // Dynamic version

  @override
  void initState() {
    super.initState();
    _checkPortalStatus();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = 'v${packageInfo.version}';
      });
    }
  }

  Future<void> _checkPortalStatus() async {
    final needs = await _portalService.needsWeeklyLogin();
    final last = await _portalService.getLastLoginFormatted();
    if (mounted) {
      setState(() {
        _needsLogin = needs;
        _lastLoginText = last;
      });
    }
  }

  void _closeDrawer(BuildContext context) {
    try {
      context.read<ZoomDrawerController>().close();
    } catch (e) {
      Navigator.pop(context);
    }
  }

  void _navigateTo(BuildContext context, Widget screen) {
    _closeDrawer(context);
    Future.delayed(const Duration(milliseconds: 150), () {
      if (context.mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;
    final colors = AppColors.of(context);

    return Container(
      color: colors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Profile Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colors.primary.withValues(alpha: 0.08),
                    colors.primary.withValues(alpha: 0.03),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: authProvider.isGuestMode
                            ? [Colors.grey, Colors.grey.shade600]
                            : [
                                colors.primary,
                                colors.primary.withValues(alpha: 0.8),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color:
                              (authProvider.isGuestMode
                                      ? Colors.grey
                                      : colors.primary)
                                  .withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        authProvider.isGuestMode
                            ? Icons.person_outline
                            : Icons.person,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          authProvider.isGuestMode
                              ? 'Guest User'
                              : (user?.name ?? 'Student'),
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: authProvider.isGuestMode
                                ? Colors.orange.withValues(alpha: 0.15)
                                : colors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            authProvider.isGuestMode
                                ? 'Limited Access'
                                : 'ID: ${user?.kiuId ?? 'N/A'}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: authProvider.isGuestMode
                                  ? Colors.orange
                                  : colors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Compact Theme Toggle
                  const _CompactThemeToggle(),
                ],
              ),
            ),

            // Menu Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _MenuItem(
                    icon: Icons.home_rounded,
                    label: 'Home',
                    onTap: () {
                      _closeDrawer(context);
                      Navigator.popUntil(context, (route) => route.isFirst);
                    },
                  ),

                  const _SectionDivider(title: 'Utilities'),
                  _MenuItem(
                    icon: Icons.handyman_rounded,
                    label: 'Student Tools',
                    subtitle: 'PDF tools, GPA calculator & more',
                    onTap: () {
                      _closeDrawer(context);
                      Navigator.pushNamed(context, AppRoutes.tools);
                    },
                  ),

                  const _SectionDivider(title: 'University'),
                  _MenuItem(
                    icon: Icons.language,
                    label: 'KIU Web Portal',
                    subtitle: _needsLogin
                        ? 'Weekly Login Suggestion'
                        : 'Last login: $_lastLoginText',
                    badge: null,
                    badgeColor: Colors.transparent,
                    onTap: () => _navigateTo(context, const WebPortalScreen()),
                  ),
                  _MenuItem(
                    icon: Icons.shopping_cart_rounded,
                    label: 'Order Semester Notes',
                    subtitle: 'SSA Printshop',
                    onTap: () => _navigateTo(context, const PrintshopScreen()),
                  ),

                  // Only show downloads section for logged-in users (not guests)
                  if (!authProvider.isGuestMode) ...[
                    const _SectionDivider(title: 'My Downloads'),
                    _MenuItem(
                      icon: Icons.audiotrack_rounded,
                      label: 'Audio Files',
                      onTap: () =>
                          _navigateTo(context, const MyDownloadedAudioScreen()),
                    ),
                    _MenuItem(
                      icon: Icons.picture_as_pdf_rounded,
                      label: 'PDF Documents',
                      onTap: () =>
                          _navigateTo(context, const MyDownloadedPDFScreen()),
                    ),
                  ],
                  const _SectionDivider(title: 'Account'),
                  _MenuItem(
                    icon: Icons.person_rounded,
                    label: 'Profile',
                    onTap: () {
                      _closeDrawer(context);
                      Navigator.pushNamed(context, '/profile');
                    },
                  ),
                  _MenuItem(
                    icon: Icons.link_rounded,
                    label: 'Important Links',
                    onTap: () {
                      _closeDrawer(context);
                      Navigator.pushNamed(context, '/important-links');
                    },
                  ),
                  _MenuItem(
                    icon: Icons.help_outline_rounded,
                    label: 'Help & Support',
                    onTap: () {
                      _closeDrawer(context);
                      Navigator.pushNamed(context, '/help');
                    },
                  ),
                  // Appearance section removed - moved to header
                ],
              ),
            ),

            // Bottom Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: colors.border)),
              ),
              child: Column(
                children: [
                  // Logout Button
                  InkWell(
                    onTap: () => _handleLogout(context),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: colors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.logout_rounded,
                            size: 18,
                            color: colors.error,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Logout',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: colors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'KIU Students ${_appVersion.isNotEmpty ? _appVersion : "v1.0.0"}',
                    style: TextStyle(fontSize: 11, color: colors.textHint),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleLogout(BuildContext context) async {
    final colors = AppColors.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: colors.error),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<AuthProvider>().logout();
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      }
    }
  }
}

class _SectionDivider extends StatelessWidget {
  final String title;
  const _SectionDivider({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppColors.of(context).textHint,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final String? badge;
  final Color? badgeColor;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.badge,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 17, color: colors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: colors.textPrimary,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 10,
                        color: badge != null ? colors.warning : colors.textHint,
                      ),
                    ),
                ],
              ),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: badgeColor ?? colors.primary,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Compact theme toggle for drawer header
class _CompactThemeToggle extends StatelessWidget {
  const _CompactThemeToggle();

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final colors = AppColors.of(context);
    final mode = themeProvider.themeMode;

    IconData icon;
    Color color;

    // Cycle: Light -> Dark -> System -> Light
    switch (mode) {
      case AppThemeMode.light:
        icon = Icons.light_mode_rounded;
        color = Colors.orange;
        break;
      case AppThemeMode.dark:
        icon = Icons.dark_mode_rounded;
        color = Colors.purpleAccent;
        break;
      case AppThemeMode.system:
        icon = Icons.settings_suggest_rounded;
        color = colors.textSecondary;
        break;
    }

    return Tooltip(
      message: 'Theme: ${mode.name.toUpperCase()}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Cycle logic
            if (mode == AppThemeMode.light) {
              themeProvider.setThemeMode(AppThemeMode.dark);
            } else if (mode == AppThemeMode.dark) {
              themeProvider.setThemeMode(AppThemeMode.system);
            } else {
              themeProvider.setThemeMode(AppThemeMode.light);
            }
          },
          borderRadius: BorderRadius.circular(50),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: colors.border.withValues(alpha: 0.5)),
              color: colors.surface,
            ),
            child: Icon(icon, size: 20, color: color),
          ),
        ),
      ),
    );
  }
}
