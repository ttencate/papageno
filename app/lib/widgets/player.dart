import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pedantic/pedantic.dart';

final _log = Logger('Player');

@immutable
class PlayerState {
  final bool loaded;
  final Duration duration;

  final bool playing;
  final Duration position;

  PlayerState(this.loaded, this.duration, this.playing, this.position);

  static final initial = PlayerState(false, Duration(), false, Duration());
}

/// Controls playback of a single audio file.
/// Must be `dispose()`d after use.
class PlayerController with WidgetsBindingObserver {
  final String audioFile;
  bool _playWhenLoaded;
  final bool pauseWhenLosingFocus;

  StreamController<PlayerState> _stateUpdatesController = StreamController<PlayerState>.broadcast();

  AudioPlayer _audioPlayer = AudioPlayer();
  AudioPlayerState _state;
  Duration _duration = Duration();
  Duration _position = Duration();

  bool _looping;

  bool _loaded = false;
  File _tempFile;

  PlayerController({@required this.audioFile, bool playing = false, this.pauseWhenLosingFocus = true, bool looping = false}) :
      _playWhenLoaded = playing,
      _looping = looping
  {
    _initAudioPlayer();
    _loadSound(audioFile);

    WidgetsBinding.instance.addObserver(this);
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    unawaited(_disposeAudioPlayer(_audioPlayer));
    _audioPlayer = null;

    try {
      _tempFile?.deleteSync();
    } catch (ex) {
      _log.warning('Failed to delete temporary file ${_tempFile}');
    }
    _tempFile = null;

    _stateUpdatesController.close();
    _stateUpdatesController = null;
  }

  Stream<PlayerState> get stateUpdates => _stateUpdatesController?.stream;

  void _initAudioPlayer() {
    _log.fine('${this} initializing AudioPlayer');

    // AudioPlayer.logEnabled = true;

    _audioPlayer.setReleaseMode(_looping ? ReleaseMode.LOOP : ReleaseMode.STOP);

    _audioPlayer.onPlayerStateChanged.listen((AudioPlayerState state) {
      // _log.fine('${this} received AudioPlayer state ${state}');
      _state = state;
      if (_state == AudioPlayerState.COMPLETED) {
        _position = _duration;
      }
      _notify();
    });
    _audioPlayer.onDurationChanged.listen((Duration duration) {
      _duration = duration;
      _notify();
    });
    _audioPlayer.onAudioPositionChanged.listen((Duration position) {
      _position = position;
      _notify();
    });
  }

  Future<void> _loadSound(String audioFile) async {
    try {
      _log.fine('$this loading sound');
      // `AudioPlayer` cannot play files from inside the asset bundle, so we have to copy it to a temporary location.
      // The `AudioCache` can also do this for us, but it has a clunky API. Also it can't be cleared properly:
      // https://github.com/luanpotter/audioplayers/issues/539
      final data = await rootBundle.load(audioFile);
      final tempDir = await getTemporaryDirectory();
      _tempFile = File(path.join(tempDir.path, path.basename(audioFile)));
      await _tempFile.writeAsBytes(data.buffer.asUint8List());

      if (_audioPlayer == null) {
        _log.warning('$this disposed before audio data was loaded');
        return;
      }
      _log.fine('${this} loaded and setting AudioPlayer source');
      await _audioPlayer.setUrl(_tempFile.path);
    } catch (e, s) {
      _log.severe('Could not load ${audioFile}', e, s);
      return;
    }

    _loaded = true;
    _notify();

    if (_playWhenLoaded) {
      play();
    }
  }

  Future<void> _disposeAudioPlayer(AudioPlayer audioPlayer) async {
    _log.fine('${this} disposing AudioPlayer');

    // Explicit release() needed until https://github.com/luanpotter/audioplayers/pull/507 lands.
    await audioPlayer.release();
    await audioPlayer.dispose();
  }

  bool get playing => _state == AudioPlayerState.PLAYING;

  set playing(bool playing) {
    if (_audioPlayer == null) {
      _log.warning('set playing called when _audioPlayer already disposed');
      return;
    }
    if (!_loaded) {
      _playWhenLoaded = playing;
    }
    final wasPlaying = this.playing;
    if (playing && !wasPlaying) {
      unawaited(_audioPlayer.play(_tempFile.path));
    } else if (!playing && wasPlaying) {
      unawaited(_audioPlayer.pause());
    }
  }

  bool get looping => _looping;

  set looping(bool looping) {
    if (_audioPlayer == null) {
      _log.warning('set looping called when _audioPlayer already disposed');
      return;
    }
    if (looping != _looping) {
      _looping = looping;
      unawaited(_audioPlayer.setReleaseMode(_looping ? ReleaseMode.LOOP : ReleaseMode.STOP));
    }
  }

  void play() {
    playing = true;
  }

  void pause() {
    playing = false;
  }

  void togglePlaying() {
    playing = !playing;
  }

  void seek(Duration to) {
    if (_audioPlayer == null) {
      _log.warning('seek called when _audioPlayer already disposed');
      return;
    }
    _audioPlayer.seek(to);
  }

  /// Implementation of [WidgetsBindingObserver].
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        if (pauseWhenLosingFocus) {
          pause();
        }
        break;
      case AppLifecycleState.resumed:
        break;
    }
  }

  void _notify() {
    if (_stateUpdatesController == null) {
      // Don't log any spam; this legitimately happens because player disposal is asynchronous and it emits events
      // while being disposed.
      return;
    }
    _stateUpdatesController.add(PlayerState(_loaded, _duration, playing, _position));
  }

  @override
  String toString() => 'PlayerController($audioFile)';
}

/// Floating play/pause button for audio playback.
class FloatingPlayPauseButton extends StatelessWidget {
  final PlayerController controller;

  const FloatingPlayPauseButton({Key key, this.controller}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<PlayerState>(
      stream: controller.stateUpdates,
      initialData: PlayerState.initial,
      builder: (context, snapshot) {
        final state = snapshot.data;
        return FloatingActionButton(
          backgroundColor: theme.accentColor,
          onPressed: state.loaded ? controller.togglePlaying : null,
          child: Icon(
            state.playing ? Icons.pause : Icons.play_arrow,
            size: 32.0,
          ),
        );
      }
    );
  }
}

/// Non-interactive playback progress bar for audio.
class PlaybackProgress extends StatelessWidget {
  final PlayerController controller;

  const PlaybackProgress({Key key, this.controller}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<PlayerState>(
      stream: controller.stateUpdates,
      initialData: PlayerState.initial,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final position = state.position.inMicroseconds.toDouble();
        final duration = state.duration.inMicroseconds.toDouble();
        return LinearProgressIndicator(
          value: duration > 0.0 ? position / duration : 0.0,
          backgroundColor: Color.lerp(theme.accentColor, Colors.white, 0.7),
        );
      }
    );
  }
}