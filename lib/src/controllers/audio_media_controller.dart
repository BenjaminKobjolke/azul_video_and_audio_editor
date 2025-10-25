import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_soloud/flutter_soloud.dart';
import '../models/media_controller.dart';

/// Audio implementation of MediaController using flutter_soloud
class AudioMediaController implements MediaController {
  AudioSource? _source;
  SoundHandle? _handle;
  final SoLoud _soloud = SoLoud.instance;

  bool _isInitialized = false;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Float32List? _fullAudioSamples;

  final List<Function()> _listeners = [];

  @override
  Future<void> initialize(File file) async {
    try {
      // Initialize SoLoud if not already initialized
      if (!_soloud.isInitialized) {
        await _soloud.init();
      }

      // Load the audio file
      _source = await _soloud.loadFile(file.path);

      // Get duration
      final length = _soloud.getLength(_source!);
      _duration = length;

      // Load full audio samples for visualization (1024 samples for smooth display)
      final bytes = await file.readAsBytes();
      _fullAudioSamples = await _soloud.readSamplesFromMem(
        bytes,
        1024,
        average: true,
      );

      _isInitialized = true;
      _notifyListeners();
    } catch (e) {
      throw Exception('Failed to initialize audio: $e');
    }
  }

  @override
  Future<void> play() async {
    if (_source == null) return;

    try {
      if (_handle == null) {
        // Start playing
        _handle = await _soloud.play(_source!);
      } else {
        // Resume from pause
        _soloud.setPause(_handle!, false);
      }
      _isPlaying = true;
      _notifyListeners();
    } catch (e) {
      throw Exception('Failed to play audio: $e');
    }
  }

  @override
  Future<void> pause() async {
    if (_handle == null) return;

    try {
      _soloud.setPause(_handle!, true);
      _isPlaying = false;
      _notifyListeners();
    } catch (e) {
      throw Exception('Failed to pause audio: $e');
    }
  }

  @override
  Future<void> seekTo(int milliseconds) async {
    if (_source == null) return;

    try {
      // If no handle exists, create one by starting playback then pausing
      // This allows seeking before first playback
      if (_handle == null) {
        _handle = await _soloud.play(_source!);
        await Future.delayed(const Duration(milliseconds: 10)); // Brief delay for handle initialization
        _soloud.setPause(_handle!, true);
        _isPlaying = false;
      }

      // Now we have a handle, so we can seek
      _soloud.seek(_handle!, Duration(milliseconds: milliseconds));
      _notifyListeners();
    } catch (e) {
      throw Exception('Failed to seek audio: $e');
    }
  }

  @override
  int get currentPositionMs {
    if (_handle == null) return 0;

    try {
      final position = _soloud.getPosition(_handle!);
      return position.inMilliseconds;
    } catch (e) {
      return 0;
    }
  }

  @override
  int get durationMs {
    return _duration.inMilliseconds;
  }

  @override
  bool get isPlaying {
    return _isPlaying && _handle != null;
  }

  @override
  bool get isInitialized {
    return _isInitialized;
  }

  @override
  void addListener(Function() listener) {
    _listeners.add(listener);
  }

  @override
  void removeListener(Function() listener) {
    _listeners.remove(listener);
  }

  void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }

  @override
  Future<void> dispose() async {
    try {
      if (_handle != null) {
        await _soloud.stop(_handle!);
        _handle = null;
      }

      if (_source != null) {
        await _soloud.disposeSource(_source!);
        _source = null;
      }

      _isInitialized = false;
      _isPlaying = false;
      _listeners.clear();
    } catch (e) {
      // Ignore disposal errors
    }
  }

  @override
  MediaType get mediaType => MediaType.audio;

  /// Get the underlying audio source for audio-specific features
  AudioSource? get audioSource => _source;

  /// Get the full audio samples for large waveform visualization
  Float32List? get fullAudioSamples => _fullAudioSamples;
}
