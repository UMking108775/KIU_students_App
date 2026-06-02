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
  // Placeholder for state variables if needed
  // _showPlaylist removed as we use Scaffold endDrawer

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
    final colors = AppColors.of(context);
    // Use GlobalKey to control drawer
    final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

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
          key: scaffoldKey,
          endDrawer: PlaylistDrawer(onClose: () => Navigator.pop(context)),
          backgroundColor: colors.background,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(
              color: colors.textPrimary,
            ), // Force visible icons
            leading: IconButton(
              icon: const Icon(Icons.keyboard_arrow_down),
              iconSize: 32,
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Now Playing',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            centerTitle: true,
            actions: [
              if (audioService.playlist.length > 1)
                IconButton(
                  icon: const Icon(Icons.queue_music),
                  onPressed: () => scaffoldKey.currentState?.openEndDrawer(),
                  tooltip: 'Playlist',
                ),
            ],
          ),
          body: Stack(
            children: [
              // Ambient Gradient Background
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      colors.background,
                      colors.background, // Solid top
                      colors.primary.withValues(alpha: 0.15), // Tinted bottom
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),

              // Main content
              SafeArea(
                child: Column(
                  children: [
                    const ConnectivityBanner(),

                    // Playlist Indicator (Subtle)
                    if (audioService.playlist.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Track ${audioService.currentIndex + 1} of ${audioService.playlist.length}',
                          style: TextStyle(
                            color: colors.textSecondary.withValues(alpha: 0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                    Expanded(
                      child: audioService.currentContent == null
                          ? Center(
                              child: Text(
                                'No audio loaded',
                                style: TextStyle(color: colors.textSecondary),
                              ),
                            )
                          : _buildPlayer(audioService),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlayer(AudioService audioService) {
    final colors = AppColors.of(context);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(flex: 2),

        // Visualizer (Hero Element)
        _buildAudioVisualizer(audioService),

        const Spacer(flex: 3),

        // Title Info
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              Text(
                audioService.currentContent?.title ?? 'Unknown',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'Audio Playback', // Could be artist name if available
                style: TextStyle(
                  fontSize: 14,
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        const Spacer(flex: 2),

        // Controls Area
        Container(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Column(
            children: [
              // Progress Bar
              ProgressBar(
                progress: audioService.position,
                buffered: audioService.buffered,
                total: audioService.duration,
                progressBarColor: colors.primary,
                baseBarColor: colors.primary.withValues(alpha: 0.15),
                bufferedBarColor: colors.primary.withValues(alpha: 0.1),
                thumbColor: colors.primary,
                thumbRadius: 6,
                barHeight: 4,
                thumbGlowRadius: 18,
                timeLabelTextStyle: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                onSeek: audioService.seek,
              ),

              const SizedBox(height: 32),

              // Main Controls Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Shuffle
                  IconButton(
                    onPressed: audioService.toggleShuffle,
                    icon: const Icon(Icons.shuffle_rounded),
                    color: audioService.shuffleEnabled
                        ? colors.primary
                        : colors.textSecondary.withValues(alpha: 0.5),
                    tooltip: 'Shuffle',
                  ),

                  // Previous
                  IconButton(
                    onPressed: () {
                      if (audioService.hasPrevious) {
                        audioService.playPrevious();
                      } else {
                        audioService.seek(Duration.zero);
                      }
                    },
                    icon: const Icon(Icons.skip_previous_rounded),
                    iconSize: 36,
                    color: audioService.hasPrevious
                        ? colors.textPrimary
                        : colors.textSecondary.withValues(alpha: 0.3),
                  ),

                  // Play/Pause (FAB style)
                  GestureDetector(
                    onTap: audioService.togglePlayPause,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: colors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: colors.primary.withValues(alpha: 0.4),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(
                        audioService.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: 38,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  // Next
                  IconButton(
                    onPressed: () {
                      if (audioService.hasNext) {
                        audioService.playNext();
                      }
                    },
                    icon: const Icon(Icons.skip_next_rounded),
                    iconSize: 36,
                    color: audioService.hasNext
                        ? colors.textPrimary
                        : colors.textSecondary.withValues(alpha: 0.3),
                  ),

                  // Repeat
                  IconButton(
                    onPressed: audioService.toggleLoopMode,
                    icon: Icon(
                      audioService.loopMode == AudioLoopMode.one
                          ? Icons.repeat_one_rounded
                          : Icons.repeat_rounded,
                    ),
                    color: audioService.loopMode != AudioLoopMode.off
                        ? colors.primary
                        : colors.textSecondary.withValues(alpha: 0.5),
                    tooltip: 'Repeat',
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Secondary Controls (Speed and Skip)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Rewind 10s (Small)
                  IconButton(
                    onPressed: () =>
                        audioService.seekRelative(const Duration(seconds: -10)),
                    icon: const Icon(Icons.replay_10_rounded),
                    iconSize: 22,
                    color: colors.textSecondary,
                    tooltip: '-10s',
                  ),

                  const SizedBox(width: 24),

                  // Speed Chip
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _changeSpeed,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: colors.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          '${_speeds[_currentSpeedIndex]}x Speed',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colors.primary,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 24),

                  // Forward 10s (Small)
                  IconButton(
                    onPressed: () =>
                        audioService.seekRelative(const Duration(seconds: 10)),
                    icon: const Icon(Icons.forward_10_rounded),
                    iconSize: 22,
                    color: colors.textSecondary,
                    tooltip: '+10s',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAudioVisualizer(AudioService audioService) {
    final colors = AppColors.of(context);
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        return Container(
          width: 220,
          height: 220,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.surface,
            boxShadow: [
              BoxShadow(
                color: colors.primary.withValues(alpha: 0.1),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Minimal circular waveform
              if (audioService.isPlaying)
                CustomPaint(
                  size: const Size(220, 220),
                  painter: _AudioWavePainter(
                    animation: _waveController,
                    color: colors.primary,
                  ),
                ),

              // Center icon
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.background,
                  border: Border.all(
                    color: colors.primary.withValues(alpha: 0.2),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors.background,
                      blurRadius: 10,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    Icons.music_note_rounded,
                    size: 64,
                    color: colors.primary,
                  ),
                ),
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
  final Color color;

  _AudioWavePainter({required this.animation, required this.color})
    : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    const barCount = 100;
    const innerRadius = 80.0;
    const maxBarHeight = 35.0;

    for (int i = 0; i < barCount; i++) {
      final angle = (i / barCount) * 2 * pi;

      // Simulate audio data using mixed sine waves for a more natural look
      final t = animation.value * 2 * pi;
      final noise =
          sin(angle * 10 + t) * 0.3 +
          sin(angle * 5 - t * 2) * 0.3 +
          sin(angle * 3 + t * 0.5) * 0.4;

      // Normalize to 0.0 - 1.0 range effectively
      final normalizedHeight = (noise + 1.2) / 2.4;

      final barHeight = maxBarHeight * normalizedHeight;

      final startX = center.dx + innerRadius * cos(angle);
      final startY = center.dy + innerRadius * sin(angle);

      final endX = center.dx + (innerRadius + barHeight) * cos(angle);
      final endY = center.dy + (innerRadius + barHeight) * sin(angle);

      // Opacity based on height for smoother look
      paint.color = color.withValues(alpha: 0.4 + (normalizedHeight * 0.6));

      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
