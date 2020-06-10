import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

final _log = Logger('Player');

/// Can be passed to a `Player` to control playback externally.
/// Should be `dispose()`d after use.
class PlayerController with ChangeNotifier {
  bool _playing;
  bool _looping;

  PlayerController({bool playing = false, bool looping = false}) :
      _playing = playing,
      _looping = looping;

  bool get playing => _playing;

  set playing(bool playing) {
    if (playing != _playing) {
      _playing = playing;
      notifyListeners();
    }
  }

  bool get looping => _looping;

  set looping(bool looping) {
    if (looping != _looping) {
      _looping = looping;
      notifyListeners();
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
}

/// Audio player widget with seek bar and play/pause button.
class Player extends StatefulWidget {
  final PlayerController controller;
  final String audioFile;

  /// Note that `audioFile` and `controller` should remain the same throughout the widget's lifetime.
  /// The state is not coded to deal with changes in these.
  Player({Key key, @required this.audioFile, PlayerController controller}) :
      controller = controller ?? PlayerController(),
      assert(audioFile != null),
      super(key: key);

  @override
  _PlayerState createState() => _PlayerState();
}

class _PlayerState extends State<Player> with WidgetsBindingObserver {
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _loaded = false;
  bool _disposed = false;
  File _tempFile;
  Duration _duration = Duration();
  Duration _position = Duration();

  AudioPlayerState _state = AudioPlayerState.STOPPED;

  PlayerController get _controller => widget.controller;
  String get _audioFile => widget.audioFile;

  @override
  void initState() {
    super.initState();

    _initAudioPlayer();
    _loadSound(_audioFile);

    WidgetsBinding.instance.addObserver(this);

    _controller.addListener(_updateAudioPlayer);
  }

  void _initAudioPlayer() {
    _log.fine('${this} initializing AudioPlayer');

    // AudioPlayer.logEnabled = true;

    if (_disposed) {
      _log.warning('${this} disposed before audio player was initialized');
      return;
    }

    _audioPlayer.setReleaseMode(ReleaseMode.STOP);

    _audioPlayer.onPlayerStateChanged.listen((AudioPlayerState state) {
      _log.fine('${this} received AudioPlayer state ${state}');
      if (_disposed) {
        return;
      }
      _controller.playing = state == AudioPlayerState.PLAYING;
      setState(() { _state = state; });
    });
    _audioPlayer.onDurationChanged.listen((Duration duration) {
      if (_disposed) {
        return;
      }
      setState(() { _duration = duration; });
    });
    _audioPlayer.onAudioPositionChanged.listen((Duration position) {
      if (_disposed) {
        return;
      }
      setState(() { _position = position; });
    });
  }

  Future<void> _loadSound(String audioFile) async {
    _log.fine('$this loading sound');
    try {
      // `AudioPlayer` cannot play files from inside the asset bundle, so we have to copy it to a temporary location.
      // The `AudioCache` can also do this for us, but it has a clunky API. Also it can't be cleared properly:
      // https://github.com/luanpotter/audioplayers/issues/539
      final data = await rootBundle.load(audioFile);
      final tempDir = await getTemporaryDirectory();
      _tempFile = File(path.join(tempDir.path, path.basename(audioFile)));
      await _tempFile.writeAsBytes(data.buffer.asUint8List());
      if (_disposed) {
        _log.warning('$this disposed before audio data was loaded');
        return;
      }
      _log.fine('${this} setting AudioPlayer source to ${_tempFile.path}');
      await _audioPlayer.setUrl(_tempFile.path);
    } catch (e, s) {
      _log.severe('Could not load ${audioFile}', e, s);
      return;
    }

    _loaded = true;

    await _updateAudioPlayer();
  }

  @override
  void dispose() {
    // Indicate to all other async code that it should not be accessing the player anymore.
    _disposed = true;

    _controller.removeListener(_updateAudioPlayer);

    WidgetsBinding.instance.removeObserver(this);

    _disposeAudioPlayer();

    try {
      _tempFile?.deleteSync();
    } catch (ex) {
      _log.warning('Failed to delete temporary file ${_tempFile}');
    }
    _tempFile = null;

    super.dispose();
  }

  Future<void> _disposeAudioPlayer() async {
    _log.fine('${this} disposing AudioPlayer');

    // Explicit release() needed until https://github.com/luanpotter/audioplayers/pull/507 lands.
    await _audioPlayer.release();
    await _audioPlayer.dispose();
  }

  Future<void> _updateAudioPlayer() async {
    if (_disposed) {
      return;
    }

    _log.fine('${this} updating AudioPlayer: playing = ${_controller.playing}, looping = ${_controller.looping}');
    await _audioPlayer.setReleaseMode(_controller.looping ? ReleaseMode.LOOP : ReleaseMode.STOP);
    if (_controller.playing && _audioPlayer.state != AudioPlayerState.PLAYING) {
      await _audioPlayer.play(_tempFile.path);
    } else if (!_controller.playing && _audioPlayer.state == AudioPlayerState.PLAYING) {
      await _audioPlayer.pause();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _controller.pause();
        break;
      case AppLifecycleState.resumed:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
        children: <Widget>[
          Expanded(
            child: Slider(
              min: 0.0,
              max: _duration.inMilliseconds.toDouble(),
              value: _position.inMilliseconds.toDouble(),
              onChanged: _loaded ? _seek : null,
            ),
          ),
          IconButton(
            icon: Icon(_state == AudioPlayerState.PLAYING ? Icons.pause : Icons.play_arrow),
            iconSize: 48.0,
            onPressed: _loaded ? _controller.togglePlaying : null,
          ),
        ]
    );
  }

  void _seek(double position) {
    if (_audioPlayer == null) {
      _log.warning('${this} tried to seek without AudioPlayer');
      return;
    }
    _audioPlayer.seek(Duration(milliseconds: position.toInt()));
  }

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      '${super.toString(minLevel: minLevel)}(${_audioFile})';
}