import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../services/audio_service.dart';
import '../../screens/audio/audio_player_screen.dart';

/// Mini audio player widget that floats at bottom of screen
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioService>(
      builder: (context, audioService, _) {
        if (!audioService.hasPlaylist || audioService.currentContent == null) {
          return const SizedBox.shrink();
        }

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AudioPlayerScreen()),
            );
          },
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                // Audio icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00ACC1), Color(0xFF00838F)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.audiotrack,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),

                // Title and progress
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        audioService.currentContent!.title,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      // Progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: audioService.duration.inMilliseconds > 0
                              ? audioService.position.inMilliseconds /
                                    audioService.duration.inMilliseconds
                              : 0,
                          backgroundColor: AppColors.border,
                          valueColor: const AlwaysStoppedAnimation(
                            Color(0xFF00ACC1),
                          ),
                          minHeight: 3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Previous button
                IconButton(
                  icon: const Icon(Icons.skip_previous),
                  iconSize: 28,
                  color: audioService.hasPrevious
                      ? AppColors.textPrimary
                      : AppColors.textHint,
                  onPressed: audioService.hasPrevious
                      ? audioService.playPrevious
                      : null,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),

                // Play/Pause button
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(
                      audioService.isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                    ),
                    iconSize: 24,
                    onPressed: audioService.togglePlayPause,
                    padding: EdgeInsets.zero,
                  ),
                ),

                // Next button
                IconButton(
                  icon: const Icon(Icons.skip_next),
                  iconSize: 28,
                  color: audioService.hasNext
                      ? AppColors.textPrimary
                      : AppColors.textHint,
                  onPressed: audioService.hasNext
                      ? audioService.playNext
                      : null,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),

                // Close button
                IconButton(
                  icon: const Icon(Icons.close),
                  iconSize: 20,
                  color: AppColors.textSecondary,
                  onPressed: audioService.stop,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
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
