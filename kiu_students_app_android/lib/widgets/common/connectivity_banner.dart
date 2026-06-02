import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/connectivity_service.dart';
import '../../config/app_theme.dart';

/// Global connectivity banner widget that shows when offline
class ConnectivityBanner extends StatelessWidget {
  const ConnectivityBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityService>(
      builder: (context, connectivity, _) {
        if (connectivity.isOnline) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: AppColors.error,
          child: SafeArea(
            bottom: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.wifi_off, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  'No Internet Connection',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Wrapper widget that includes connectivity banner above content
class ConnectivityWrapper extends StatelessWidget {
  final Widget child;
  final bool showBannerAboveAppBar;

  const ConnectivityWrapper({
    super.key,
    required this.child,
    this.showBannerAboveAppBar = false,
  });

  @override
  Widget build(BuildContext context) {
    if (showBannerAboveAppBar) {
      return Column(
        children: [
          const ConnectivityBanner(),
          Expanded(child: child),
        ],
      );
    }

    return Stack(
      children: [
        child,
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: ConnectivityBanner(),
        ),
      ],
    );
  }
}
