import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../models/content_model.dart';

/// Loop mode enum
enum AudioLoopMode { off, all, one }

/// Global audio service for background playback
class AudioService extends ChangeNotifier {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  AudioPlayer? _player;
  List<ContentModel> _playlist = [];
  List<String?> _localPaths = [];
  int _currentIndex = 0;
  bool _isPlaying = false;
  bool _shuffleEnabled = false;
  AudioLoopMode _loopMode = AudioLoopMode.off;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Duration _buffered = Duration.zero;

  // Shuffle order
  List<int> _shuffledIndices = [];
  int _shufflePosition = 0;

  // Random for shuffle
  final Random _random = Random();

  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _bufferedSubscription;
  StreamSubscription? _playerStateSubscription;

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
      _playlist.isNotEmpty && _currentIndex < _playlist.length
      ? _playlist[_currentIndex]
      : null;
  String? get currentLocalPath =>
      _localPaths.isNotEmpty && _currentIndex < _localPaths.length
      ? _localPaths[_currentIndex]
      : null;

  bool get hasNext {
    if (_shuffleEnabled) {
      return _shufflePosition < _shuffledIndices.length - 1;
    }
    return _currentIndex < _playlist.length - 1;
  }

  bool get hasPrevious {
    if (_shuffleEnabled) {
      return _shufflePosition > 0;
    }
    return _currentIndex > 0;
  }

  /// Initialize player with a playlist
  Future<void> initPlaylist(
    List<ContentModel> playlist,
    int startIndex, {
    List<String?>? localPaths,
  }) async {
    _playlist = playlist;
    _localPaths = localPaths ?? List.filled(playlist.length, null);
    _currentIndex = startIndex;

    // Generate shuffle order
    _generateShuffleOrder();

    await _initPlayer();
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

  /// Generate shuffle order
  void _generateShuffleOrder() {
    _shuffledIndices = List.generate(_playlist.length, (i) => i);
    _shuffledIndices.shuffle(_random);

    // Find current position in shuffle order
    _shufflePosition = _shuffledIndices.indexOf(_currentIndex);
    if (_shufflePosition == -1) _shufflePosition = 0;
  }

  Future<void> _initPlayer() async {
    // Dispose old subscriptions
    await _positionSubscription?.cancel();
    await _durationSubscription?.cancel();
    await _bufferedSubscription?.cancel();
    await _playerStateSubscription?.cancel();

    // Create new player if needed
    _player ??= AudioPlayer();

    try {
      // Set audio source
      final localPath = currentLocalPath;
      if (localPath != null) {
        await _player!.setFilePath(localPath);
      } else if (currentContent != null) {
        await _player!.setUrl(currentContent!.backblazeUrl);
      }

      // Set up listeners
      _positionSubscription = _player!.positionStream.listen((pos) {
        _position = pos;
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

      _playerStateSubscription = _player!.playerStateStream.listen((state) {
        _isPlaying = state.playing;

        // Auto-play next on completion
        if (state.processingState == ProcessingState.completed) {
          _onTrackComplete();
        }

        notifyListeners();
      });
    } catch (e) {
      debugPrint('Error initializing player: $e');
    }
  }

  void _onTrackComplete() {
    if (_loopMode == AudioLoopMode.one) {
      // Repeat current track
      seek(Duration.zero);
      play();
    } else if (hasNext) {
      // Play next track
      playNext();
    } else if (_loopMode == AudioLoopMode.all) {
      // Loop back to beginning
      if (_shuffleEnabled) {
        _shufflePosition = 0;
        _currentIndex = _shuffledIndices[0];
      } else {
        _currentIndex = 0;
      }
      _initPlayer().then((_) => play());
    }
    // If no next and no loop, just stop
  }

  /// Play
  Future<void> play() async {
    await _player?.play();
  }

  /// Pause
  Future<void> pause() async {
    await _player?.pause();
  }

  /// Toggle play/pause
  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  /// Seek to position
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

  /// Play next track
  Future<void> playNext() async {
    if (_shuffleEnabled) {
      if (_shufflePosition < _shuffledIndices.length - 1) {
        _shufflePosition++;
        _currentIndex = _shuffledIndices[_shufflePosition];
        await _initPlayer();
        await play();
      }
    } else {
      if (_currentIndex < _playlist.length - 1) {
        _currentIndex++;
        await _initPlayer();
        await play();
      }
    }
    notifyListeners();
  }

  /// Play previous track
  Future<void> playPrevious() async {
    if (_shuffleEnabled) {
      if (_shufflePosition > 0) {
        _shufflePosition--;
        _currentIndex = _shuffledIndices[_shufflePosition];
        await _initPlayer();
        await play();
      } else {
        await seek(Duration.zero);
      }
    } else {
      if (_currentIndex > 0) {
        _currentIndex--;
        await _initPlayer();
        await play();
      } else {
        await seek(Duration.zero);
      }
    }
    notifyListeners();
  }

  /// Play specific index
  Future<void> playAt(int index) async {
    if (index >= 0 && index < _playlist.length) {
      _currentIndex = index;

      // Update shuffle position
      if (_shuffleEnabled) {
        _shufflePosition = _shuffledIndices.indexOf(index);
        if (_shufflePosition == -1) {
          _shufflePosition = 0;
          _shuffledIndices[0] = index;
        }
      }

      await _initPlayer();
      await play();
    }
  }

  /// Toggle shuffle
  Future<void> toggleShuffle() async {
    _shuffleEnabled = !_shuffleEnabled;

    if (_shuffleEnabled) {
      // Generate new shuffle order, keeping current track at current position
      _generateShuffleOrder();
    }

    notifyListeners();
  }

  /// Toggle loop mode (off -> all -> one -> off)
  Future<void> toggleLoopMode() async {
    switch (_loopMode) {
      case AudioLoopMode.off:
        _loopMode = AudioLoopMode.all;
        break;
      case AudioLoopMode.all:
        _loopMode = AudioLoopMode.one;
        break;
      case AudioLoopMode.one:
        _loopMode = AudioLoopMode.off;
        break;
    }
    notifyListeners();
  }

  /// Set playback speed
  Future<void> setSpeed(double speed) async {
    await _player?.setSpeed(speed);
    notifyListeners();
  }

  /// Stop and clear playlist
  Future<void> stop() async {
    await _player?.stop();
    _playlist = [];
    _localPaths = [];
    _currentIndex = 0;
    _isPlaying = false;
    _position = Duration.zero;
    _duration = Duration.zero;
    notifyListeners();
  }

  /// Dispose
  @override
  Future<void> dispose() async {
    await _positionSubscription?.cancel();
    await _durationSubscription?.cancel();
    await _bufferedSubscription?.cancel();
    await _playerStateSubscription?.cancel();
    await _player?.dispose();
    _player = null;
    super.dispose();
  }
}
