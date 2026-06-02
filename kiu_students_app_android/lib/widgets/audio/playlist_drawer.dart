import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../models/content_model.dart';
import '../../services/audio_service.dart';

/// Playlist drawer sidebar for audio player
class PlaylistDrawer extends StatelessWidget {
  final VoidCallback onClose;

  const PlaylistDrawer({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Consumer<AudioService>(
      builder: (context, audioService, _) {
        return Container(
          width: MediaQuery.of(context).size.width * 0.85,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              bottomLeft: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(-5, 0),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.queue_music, color: colors.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Playlist',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colors.textPrimary,
                                ),
                          ),
                        ),
                        Text(
                          '${audioService.playlist.length} tracks',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.textSecondary),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(Icons.close, color: colors.textSecondary),
                          onPressed: onClose,
                          iconSize: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Shuffle and Repeat controls
                    Row(
                      children: [
                        Expanded(
                          child: _ControlButton(
                            icon: Icons.shuffle,
                            label: 'Shuffle',
                            isActive: audioService.shuffleEnabled,
                            onTap: audioService.toggleShuffle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ControlButton(
                            icon: _getLoopIcon(audioService.loopMode),
                            label: _getLoopLabel(audioService.loopMode),
                            isActive:
                                audioService.loopMode != AudioLoopMode.off,
                            onTap: audioService.toggleLoopMode,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Playlist items
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: audioService.playlist.length,
                  itemBuilder: (context, index) {
                    final content = audioService.playlist[index];
                    final isPlaying = index == audioService.currentIndex;

                    return _PlaylistItem(
                      content: content,
                      index: index,
                      isPlaying: isPlaying,
                      onTap: () {
                        audioService.playAt(index);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _getLoopIcon(AudioLoopMode mode) {
    switch (mode) {
      case AudioLoopMode.off:
        return Icons.repeat;
      case AudioLoopMode.all:
        return Icons.repeat;
      case AudioLoopMode.one:
        return Icons.repeat_one;
    }
  }

  String _getLoopLabel(AudioLoopMode mode) {
    switch (mode) {
      case AudioLoopMode.off:
        return 'Repeat Off';
      case AudioLoopMode.all:
        return 'Repeat All';
      case AudioLoopMode.one:
        return 'Repeat One';
    }
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isActive
              ? colors.primary.withValues(alpha: 0.15)
              : colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isActive ? colors.primary : colors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isActive ? colors.primary : colors.textSecondary,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isActive ? colors.primary : colors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaylistItem extends StatelessWidget {
  final ContentModel content;
  final int index;
  final bool isPlaying;
  final VoidCallback onTap;

  const _PlaylistItem({
    required this.content,
    required this.index,
    required this.isPlaying,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isPlaying ? colors.primary.withValues(alpha: 0.1) : null,
          border: Border(
            left: BorderSide(
              color: isPlaying ? colors.primary : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            // Track number or playing indicator
            SizedBox(
              width: 32,
              child: isPlaying
                  ? Icon(Icons.graphic_eq, color: colors.primary, size: 20)
                  : Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
            ),
            const SizedBox(width: 12),

            // Audio icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isPlaying
                    ? colors.primary.withValues(alpha: 0.2)
                    : colors.textSecondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.audiotrack,
                color: isPlaying ? colors.primary : colors.textSecondary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),

            // Title
            Expanded(
              child: Text(
                content.title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: isPlaying ? FontWeight.w600 : FontWeight.w500,
                  color: isPlaying ? colors.primary : colors.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Play icon on hover/tap
            if (isPlaying)
              Icon(Icons.volume_up, color: colors.primary, size: 20),
          ],
        ),
      ),
    );
  }
}
