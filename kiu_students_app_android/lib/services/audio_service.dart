import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/content_model.dart';

/// Loop mode enum
enum AudioLoopMode { off, all, one }

/// Global audio service for background playback
/// Now with position persistence and background audio support!
class AudioService extends ChangeNotifier {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  // Position persistence key prefix
  static const String _positionKeyPrefix = 'audio_position_';

  AudioPlayer? _player;
  List<ContentModel> _playlist = [];
  List<String?> _localPaths = []; // Track local paths corresponding to playlist

  // State getters aligned with UI
  int _currentIndex = 0;
  bool _isPlaying = false;
  bool _shuffleEnabled = false;
  AudioLoopMode _loopMode = AudioLoopMode.off;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Duration _buffered = Duration.zero;

  // Persistence
  Timer? _positionSaveTimer;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _bufferedSubscription;
  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _indexSubscription;
  StreamSubscription? _shuffleModeSubscription;
  StreamSubscription? _loopModeSubscription;

  // Getters
  AudioPlayer? get player => _player;
  List<ContentModel> get playlist => _playlist;
  int get currentIndex => _currentIndex;
  bool get isPlaying => _isPlaying;
  bool get shuffleEnabled => _shuffleEnabled;
  AudioLoopMode get loopMode => _loopMode;
  Duration get position => _position;
  Duration get duration => _duration;
  Duration get buffered => _buffered;
  bool get hasPlaylist => _playlist.isNotEmpty;

  ContentModel? get currentContent =>
      _playlist.isNotEmpty &&
          _currentIndex >= 0 &&
          _currentIndex < _playlist.length
      ? _playlist[_currentIndex]
      : null;

  // Helper for UI buttons (now delegated to player logic, but useful for badges)
  bool get hasNext => _player?.hasNext ?? false;
  bool get hasPrevious => _player?.hasPrevious ?? false;

  /// Initialize player with a playlist
  Future<void> initPlaylist(
    List<ContentModel> playlist,
    int startIndex, {
    List<String?>? localPaths,
  }) async {
    _playlist = playlist;
    _localPaths = localPaths ?? List.filled(playlist.length, null);
    _currentIndex = startIndex;

    await _initPlayer(startIndex);
    notifyListeners();
  }

  /// Initialize with single content
  Future<void> initSingle(ContentModel content, {String? localPath}) async {
    await initPlaylist(
      [content],
      0,
      localPaths: localPath != null ? [localPath] : null,
    );
  }

  Future<void> _initPlayer(int initialIndex) async {
    // Ensure player exists
    if (_player == null) {
      _player = AudioPlayer();
      _setupListeners();
    } else {
      // Must stop before resetting source to avoid glitches
      await _player!.stop();
    }

    try {
      // Construct AudioSources with Metadata
      final children = <AudioSource>[];
      for (int i = 0; i < _playlist.length; i++) {
        final content = _playlist[i];
        final localPath = _localPaths[i]; // Use local path if available

        final uri = localPath != null
            ? Uri.file(localPath)
            : Uri.parse(content.backblazeUrl);

        children.add(
          AudioSource.uri(
            uri,
            tag: MediaItem(
              id: content.id.toString(),
              album: "KIU Urdu", // App Name as Album
              title: content.title,
              artist: "Audio Lesson",
              artUri: Uri.parse('asset:///assets/images/app_icon.png'),
              extras: <String, dynamic>{'content_type': content.contentType},
            ),
          ),
        );
      }

      final playlistSource = ConcatenatingAudioSource(children: children);

      // Restore position if possible
      final savedPosition = await _getSavedPosition(_playlist[initialIndex].id);

      await _player!.setAudioSource(
        playlistSource,
        initialIndex: initialIndex,
        initialPosition: savedPosition,
      );

      // Auto-play
      await _player!.play();
    } catch (e) {
      debugPrint('Error initializing player: $e');
    }
  }

  void _setupListeners() {
    _playerStateSubscription = _player!.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      notifyListeners();

      // If completed, clear position
      if (state.processingState == ProcessingState.completed) {
        _clearSavedPosition();
      }
    });

    _positionSubscription = _player!.positionStream.listen((pos) {
      _position = pos;
      _debouncedSavePosition();
      notifyListeners();
    });

    _durationSubscription = _player!.durationStream.listen((dur) {
      _duration = dur ?? Duration.zero;
      notifyListeners();
    });

    _bufferedSubscription = _player!.bufferedPositionStream.listen((buf) {
      _buffered = buf;
      notifyListeners();
    });

    // Listen to current item index changes (auto-advance)
    _indexSubscription = _player!.currentIndexStream.listen((index) {
      if (index != null && index != _currentIndex) {
        _currentIndex = index;
        notifyListeners();
        // We could attempt to restore position here for the new track,
        // but just_audio usually starts fresh or continous.
        // For distinct lessons, user might want to resume.
        // But doing seek here might conflict with auto-advance.
        // We'll trust standard behavior for now (start from 0 on auto-next).
      }
    });

    // Sync Shuffle/Loop state
    _shuffleModeSubscription = _player!.shuffleModeEnabledStream.listen((
      enabled,
    ) {
      _shuffleEnabled = enabled;
      notifyListeners();
    });

    _loopModeSubscription = _player!.loopModeStream.listen((mode) {
      switch (mode) {
        case LoopMode.off:
          _loopMode = AudioLoopMode.off;
          break;
        case LoopMode.all:
          _loopMode = AudioLoopMode.all;
          break;
        case LoopMode.one:
          _loopMode = AudioLoopMode.one;
          break;
      }
      notifyListeners();
    });
  }

  /// Play
  Future<void> play() async {
    await _player?.play();
  }

  /// Pause - also saves position
  Future<void> pause() async {
    await _player?.pause();
    await _saveCurrentPosition(); // Save when pausing
  }

  /// Toggle play/pause
  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      await _player?.pause();
      await _saveCurrentPosition();
    } else {
      await _player?.play();
    }
  }

  /// Seek
  Future<void> seek(Duration position) async {
    await _player?.seek(position);
  }

  /// Seek relative
  Future<void> seekRelative(Duration offset) async {
    final newPosition = _position + offset;
    if (newPosition < Duration.zero) {
      await seek(Duration.zero);
    } else if (newPosition > _duration) {
      await seek(_duration);
    } else {
      await seek(newPosition);
    }
  }

  /// Play Next
  Future<void> playNext() async {
    if (_player?.hasNext ?? false) {
      await _saveCurrentPosition();
      await _player?.seekToNext();
    }
  }

  /// Play Previous
  Future<void> playPrevious() async {
    if (_player?.hasPrevious ?? false) {
      await _saveCurrentPosition();
      await _player?.seekToPrevious();
    } else {
      await seek(Duration.zero);
    }
  }

  /// Play at specific index
  Future<void> playAt(int index) async {
    if (index >= 0 && index < _playlist.length) {
      await _saveCurrentPosition();
      // Restore position for target track if exists
      final savedPos = await _getSavedPosition(_playlist[index].id);
      await _player?.seek(savedPos ?? Duration.zero, index: index);
      await _player?.play();
    }
  }

  /// Toggle shuffle
  Future<void> toggleShuffle() async {
    final enable = !_shuffleEnabled;
    await _player?.setShuffleModeEnabled(enable);
  }

  /// Toggle loop
  Future<void> toggleLoopMode() async {
    LoopMode nextMode;
    switch (_player?.loopMode ?? LoopMode.off) {
      case LoopMode.off:
        nextMode = LoopMode.all;
        break;
      case LoopMode.all:
        nextMode = LoopMode.one;
        break;
      case LoopMode.one:
        nextMode = LoopMode.off;
        break;
    }
    await _player?.setLoopMode(nextMode);
  }

  /// Set speed
  Future<void> setSpeed(double speed) async {
    await _player?.setSpeed(speed);
  }

  /// Stop
  Future<void> stop() async {
    await _saveCurrentPosition();
    await _player?.stop();
    _playlist = [];
    _localPaths = [];
    _isPlaying = false;
    _position = Duration.zero;
    notifyListeners();
  }

  // --- Persistence Logic ---

  Future<Duration?> _getSavedPosition(int contentId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_positionKeyPrefix$contentId';
      final ms = prefs.getInt(key);
      if (ms != null && ms > 0) {
        return Duration(milliseconds: ms);
      }
    } catch (e) {
      debugPrint('Error getting saved pos: $e');
    }
    return null;
  }

  void _debouncedSavePosition() {
    if (_positionSaveTimer?.isActive ?? false) return;
    _positionSaveTimer = Timer(
      const Duration(seconds: 5),
      _saveCurrentPosition,
    );
  }

  Future<void> _saveCurrentPosition() async {
    if (currentContent == null) return;
    if (_position.inSeconds < 5) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_positionKeyPrefix${currentContent!.id}';
      await prefs.setInt(key, _position.inMilliseconds);
    } catch (e) {
      debugPrint('[AudioService] Error saving position: $e');
    }
  }

  Future<void> _clearSavedPosition() async {
    if (currentContent == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_positionKeyPrefix${currentContent!.id}';
      await prefs.remove(key);
    } catch (e) {
      debugPrint('[AudioService] Error clearing position: $e');
    }
  }

  @override
  Future<void> dispose() async {
    _positionSaveTimer?.cancel();
    await _saveCurrentPosition();
    await _playerStateSubscription?.cancel();
    await _positionSubscription?.cancel();
    await _durationSubscription?.cancel();
    await _bufferedSubscription?.cancel();
    await _indexSubscription?.cancel();
    await _shuffleModeSubscription?.cancel();
    await _loopModeSubscription?.cancel();
    await _player?.dispose();
    _player = null;
    super.dispose();
  }
}
