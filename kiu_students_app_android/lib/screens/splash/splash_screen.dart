import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../config/app_routes.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';

/// Branded splash shown on launch: logo, app name, version and the
/// "Powered by SSA Technologies" credit. While it's visible we restore any
/// saved session, then route to Home (logged in) or Login.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  String _version = '';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _boot();
  }

  Future<void> _boot() async {
    final auth = context.read<AuthProvider>();

    // Kick off version load + restore session while the splash is on screen,
    // and hold the splash for a minimum, pleasant duration.
    final infoFuture = PackageInfo.fromPlatform();
    final minDisplay = Future.delayed(const Duration(milliseconds: 1600));

    await auth.initialize();
    final info = await infoFuture;
    if (mounted) setState(() => _version = 'v${info.version}');

    await minDisplay;
    if (!mounted) return;

    Navigator.pushReplacementNamed(
      context,
      auth.isLoggedIn ? AppRoutes.home : AppRoutes.login,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: FadeTransition(
                  opacity: _fade,
                  child: ScaleTransition(
                    scale: _scale,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo tile
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: colors.border),
                            boxShadow: [
                              BoxShadow(
                                color: isDark
                                    ? Colors.black.withValues(alpha: 0.45)
                                    : colors.primary.withValues(alpha: 0.18),
                                blurRadius: 22,
                                offset: const Offset(4, 8),
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/images/kiu_logo.png',
                            height: 96,
                            width: 96,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'KIU Students',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Your study companion',
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Loader
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                valueColor: AlwaysStoppedAnimation(colors.primary),
              ),
            ),
            const SizedBox(height: 24),

            // Version
            Text(
              _version.isEmpty ? ' ' : _version,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),

            // Branding
            Text(
              'Powered by SSA Technologies',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
                color: colors.textHint,
              ),
            ),
            const SizedBox(height: 22),
          ],
        ),
      ),
    );
  }
}
