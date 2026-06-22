import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_config.dart';
import '../../config/app_routes.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/auth/auth_button.dart';
import '../../widgets/auth/auth_header.dart';
import '../../widgets/auth/auth_text_field.dart';
import '../../services/portal_visit_service.dart';

/// Login screen for user authentication
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _kiuIdController = TextEditingController();
  final _passwordController = TextEditingController();

  // Session restore + "already logged in" routing is handled by SplashScreen,
  // so the login form can render immediately here.

  @override
  void initState() {
    super.initState();
    // If the user landed here because their session was ended (e.g. signed
    // out by a login on another device), explain why — once.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      final msg = auth.sessionEndedMessage;
      if (msg != null) {
        auth.consumeSessionEndedMessage();
        _showSessionEndedDialog(msg);
      }
    });
  }

  @override
  void dispose() {
    _kiuIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin({bool force = false}) async {
    // Skip form validation on the forced retry — inputs were already valid.
    if (!force && !_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();

    final outcome = await authProvider.login(
      kiuId: _kiuIdController.text.trim(),
      password: _passwordController.text,
      force: force,
    );

    if (!mounted) return;

    switch (outcome) {
      case LoginOutcome.success:
        // Mark portal login as "done" for now so new users aren't prompted immediately
        await PortalVisitService().markLogin();
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, AppRoutes.home);
        break;
      case LoginOutcome.needsDeviceConfirmation:
        await _showDeviceConflictDialog(authProvider.deviceConfirmationMessage);
        break;
      case LoginOutcome.failure:
        final colors = AppColors.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.errorMessage ?? 'Login failed'),
            backgroundColor: colors.error,
          ),
        );
        break;
    }
  }

  /// Shown when the account is already logged in on another device. Confirming
  /// signs out that other device and proceeds with login here.
  Future<void> _showDeviceConflictDialog(String? message) async {
    final colors = AppColors.of(context);
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Already logged in elsewhere'),
        content: Text(
          message ??
              'This account is already logged in on another device. If you '
                  'continue, that device will be signed out.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: colors.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (proceed == true && mounted) {
      await _handleLogin(force: true);
    }
  }

  /// Explains why the previous session ended (forced logout / expiry).
  Future<void> _showSessionEndedDialog(String message) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logged out'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String? _validateKiuId(String? value) {
    if (value == null || value.isEmpty) {
      return 'KIU ID is required';
    }
    if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
      return 'KIU ID must contain only numbers';
    }
    if (value.length < AppConfig.minKiuIdLength) {
      return 'KIU ID must be at least ${AppConfig.minKiuIdLength} digits';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < AppConfig.minPasswordLength) {
      return 'Password must be at least ${AppConfig.minPasswordLength} characters';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),

                // Header with logo
                const AuthHeader(
                  title: 'Welcome Back',
                  subtitle: 'Sign in to access your materials',
                ),

                const SizedBox(height: 28),

                // KIU ID field
                AuthTextField(
                  controller: _kiuIdController,
                  label: 'KIU ID',
                  hint: 'Enter your KIU ID',
                  prefixIcon: Icons.badge_outlined,
                  keyboardType: TextInputType.number,
                  validator: _validateKiuId,
                  textInputAction: TextInputAction.next,
                ),

                const SizedBox(height: 16),

                // Password field
                AuthTextField(
                  controller: _passwordController,
                  label: 'Password',
                  hint: 'Enter your password',
                  prefixIcon: Icons.lock_outline,
                  isPassword: true,
                  validator: _validatePassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _handleLogin(),
                ),

                const SizedBox(height: 22),

                // Login button
                Consumer<AuthProvider>(
                  builder: (context, auth, _) {
                    return AuthButton(
                      text: 'Sign In',
                      isLoading: auth.isLoading,
                      onPressed: () => _handleLogin(),
                    );
                  },
                ),

                const SizedBox(height: 24),

                // Register link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, AppRoutes.register);
                      },
                      child: const Text('Register'),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Divider with OR text
                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: colors.textSecondary.withValues(alpha: 0.3),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'OR',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: colors.textSecondary.withValues(alpha: 0.3),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Guest Access button
                OutlinedButton.icon(
                  onPressed: () {
                    context.read<AuthProvider>().enterGuestMode();
                    Navigator.pushReplacementNamed(context, AppRoutes.home);
                  },
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Guest Preview'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    side: BorderSide(
                      color: colors.primary.withValues(alpha: 0.5),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Guest mode info
                Text(
                  'Preview app with limited content (1 audio, 1 PDF)',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 28),

                // Branding footer
                Text(
                  'Powered by SSA Technologies',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                    color: colors.textHint,
                  ),
                ),

                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
