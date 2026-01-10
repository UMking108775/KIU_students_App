import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../models/content_model.dart';
import '../../services/audio_service.dart';
import '../../widgets/audio/playlist_drawer.dart';
import '../../widgets/common/connectivity_banner.dart';

/// Pro-level audio player screen with visualizer and playlist support
class AudioPlayerScreen extends StatefulWidget {
  final ContentModel? content;
  final String? localPath;
  final List<ContentModel>? playlist;
  final List<String?>? playlistLocalPaths;
  final int initialIndex;

  const AudioPlayerScreen({
    super.key,
    this.content,
    this.localPath,
    this.playlist,
    this.playlistLocalPaths,
    this.initialIndex = 0,
  });

  @override
  State<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;
  bool _showPlaylist = false;

  // Playback speed options
  final List<double> _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
  int _currentSpeedIndex = 2; // 1.0x

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Initialize audio service if new content is provided
    if (widget.content != null || widget.playlist != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initAudio();
      });
    }

    // Start wave animation if already playing
    final audioService = context.read<AudioService>();
    if (audioService.isPlaying) {
      _waveController.repeat();
    }
  }

  void _initAudio() {
    final audioService = context.read<AudioService>();

    if (widget.playlist != null && widget.playlist!.isNotEmpty) {
      audioService.initPlaylist(
        widget.playlist!,
        widget.initialIndex,
        localPaths: widget.playlistLocalPaths,
      );
    } else if (widget.content != null) {
      audioService.initSingle(widget.content!, localPath: widget.localPath);
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  void _changeSpeed() {
    final audioService = context.read<AudioService>();
    setState(() {
      _currentSpeedIndex = (_currentSpeedIndex + 1) % _speeds.length;
    });
    audioService.setSpeed(_speeds[_currentSpeedIndex]);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioService>(
      builder: (context, audioService, _) {
        // Control wave animation based on playing state
        if (audioService.isPlaying) {
          if (!_waveController.isAnimating) {
            _waveController.repeat();
          }
        } else {
          _waveController.stop();
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.keyboard_arrow_down),
              iconSize: 32,
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text('Now Playing'),
            centerTitle: true,
            actions: [
              // Playlist button
              if (audioService.playlist.length > 1)
                IconButton(
                  icon: const Icon(Icons.queue_music),
                  onPressed: () {
                    setState(() {
                      _showPlaylist = true;
                    });
                  },
                  tooltip: 'Playlist',
                ),
            ],
          ),
          body: Stack(
            children: [
              // Main content
              Column(
                children: [
                  const ConnectivityBanner(),

                  // Track indicator
                  if (audioService.playlist.length > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      color: AppColors.surface,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.playlist_play,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Track ${audioService.currentIndex + 1} of ${audioService.playlist.length}',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),

                  Expanded(
                    child: audioService.currentContent == null
                        ? const Center(child: Text('No audio loaded'))
                        : _buildPlayer(audioService),
                  ),
                ],
              ),

              // Playlist drawer overlay
              if (_showPlaylist) ...[
                // Backdrop
                GestureDetector(
                  onTap: () => setState(() => _showPlaylist = false),
                  child: Container(color: Colors.black54),
                ),
                // Drawer
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: PlaylistDrawer(
                    onClose: () => setState(() => _showPlaylist = false),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlayer(AudioService audioService) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Spacer(),

          // Audio Icon with Waves
          _buildAudioVisualizer(audioService),

          const SizedBox(height: 40),

          // Title
          Text(
            audioService.currentContent?.title ?? 'Unknown',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 8),

          // Type badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF00ACC1).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Audio',
              style: TextStyle(
                color: Color(0xFF00ACC1),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          const Spacer(),

          // Progress Bar
          ProgressBar(
            progress: audioService.position,
            buffered: audioService.buffered,
            total: audioService.duration,
            progressBarColor: AppColors.primary,
            baseBarColor: AppColors.border,
            bufferedBarColor: AppColors.primary.withValues(alpha: 0.3),
            thumbColor: AppColors.primary,
            thumbRadius: 8,
            timeLabelTextStyle: Theme.of(context).textTheme.bodySmall,
            onSeek: audioService.seek,
          ),

          const SizedBox(height: 24),

          // Shuffle, Speed, Repeat controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Shuffle
              IconButton(
                onPressed: audioService.toggleShuffle,
                icon: Icon(
                  Icons.shuffle,
                  color: audioService.shuffleEnabled
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
              ),

              // Speed
              TextButton(
                onPressed: _changeSpeed,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    '${_speeds[_currentSpeedIndex]}x',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              // Repeat
              IconButton(
                onPressed: audioService.toggleLoopMode,
                icon: Icon(
                  audioService.loopMode == AudioLoopMode.one
                      ? Icons.repeat_one
                      : Icons.repeat,
                  color: audioService.loopMode != AudioLoopMode.off
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Playback Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Rewind 10s
              IconButton(
                onPressed: () =>
                    audioService.seekRelative(const Duration(seconds: -10)),
                icon: const Icon(Icons.replay_10),
                iconSize: 36,
                color: AppColors.textSecondary,
              ),

              // Previous
              IconButton(
                onPressed: () {
                  if (audioService.hasPrevious) {
                    audioService.playPrevious();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('This is the first track'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.skip_previous),
                iconSize: 40,
                color: audioService.hasPrevious
                    ? AppColors.textPrimary
                    : AppColors.textHint,
              ),

              // Play/Pause
              GestureDetector(
                onTap: audioService.togglePlayPause,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(
                    audioService.isPlaying ? Icons.pause : Icons.play_arrow,
                    size: 36,
                    color: Colors.white,
                  ),
                ),
              ),

              // Next
              IconButton(
                onPressed: () {
                  if (audioService.hasNext) {
                    audioService.playNext();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('This is the last track'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.skip_next),
                iconSize: 40,
                color: audioService.hasNext
                    ? AppColors.textPrimary
                    : AppColors.textHint,
              ),

              // Forward 10s
              IconButton(
                onPressed: () =>
                    audioService.seekRelative(const Duration(seconds: 10)),
                icon: const Icon(Icons.forward_10),
                iconSize: 36,
                color: AppColors.textSecondary,
              ),
            ],
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildAudioVisualizer(AudioService audioService) {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        return Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF00ACC1).withValues(alpha: 0.1),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer waves
              ...List.generate(3, (index) {
                final delay = index * 0.3;
                final wave = ((_waveController.value + delay) % 1.0);
                return Container(
                  width: 160 + (wave * 40),
                  height: 160 + (wave * 40),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(
                        0xFF00ACC1,
                      ).withValues(alpha: (1 - wave) * 0.3),
                      width: 2,
                    ),
                  ),
                );
              }),

              // Center icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF00ACC1),
                      const Color(0xFF00ACC1).withValues(alpha: 0.7),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00ACC1).withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.audiotrack,
                  size: 48,
                  color: Colors.white,
                ),
              ),

              // Frequency bars
              if (audioService.isPlaying)
                CustomPaint(
                  size: const Size(200, 200),
                  painter: _AudioWavePainter(animation: _waveController),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _AudioWavePainter extends CustomPainter {
  final Animation<double> animation;

  _AudioWavePainter({required this.animation}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = const Color(0xFF00ACC1).withValues(alpha: 0.6)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    const barCount = 24;
    const innerRadius = 65.0;
    const maxBarHeight = 25.0;

    for (int i = 0; i < barCount; i++) {
      final angle = (i / barCount) * 2 * pi;
      final barHeight =
          maxBarHeight *
          (0.3 + 0.7 * ((sin(animation.value * 2 * pi + i * 0.5) + 1) / 2));

      final startX = center.dx + innerRadius * cos(angle);
      final startY = center.dy + innerRadius * sin(angle);
      final endX = center.dx + (innerRadius + barHeight) * cos(angle);
      final endY = center.dy + (innerRadius + barHeight) * sin(angle);

      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
