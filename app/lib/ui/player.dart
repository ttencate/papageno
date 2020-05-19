import 'dart:async';

import 'package:audioplayers/audio_cache.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:papageno/model/app_model.dart';

/// Audio player widget with seek bar and play/pause button.
class Player extends StatefulWidget {
  final Recording recording; // TODO take raw filename instead

  Player({Key key, @required this.recording}) :
        assert(recording != null),
        super(key: key);

  @override
  _PlayerState createState() => _PlayerState();
}

class _PlayerState extends State<Player> with WidgetsBindingObserver {
  static final AudioCache _audioCache = AudioCache(prefix: 'sounds/');

  AudioPlayer _audioPlayer;
  bool _disposed = false;
  Duration _duration = Duration();
  Duration _position = Duration();

  AudioPlayerState _state = AudioPlayerState.STOPPED;
  bool _pausedDueToLifecycleState = false;

  Recording get _recording => widget.recording;

  @override
  void initState() {
    super.initState();

    // AudioPlayer.logEnabled = true;
    _startPlaying();

    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> _startPlaying() async {
    final audioPlayer = await _audioCache.loop(_recording.fileName);
    if (_disposed) {
      print('${this} disposed before playback started');
      await _disposeAudioPlayer(audioPlayer);
      return;
    }

    setState(() {
      _audioPlayer = audioPlayer;
    });

    _audioPlayer.onPlayerStateChanged.listen((AudioPlayerState state) {
      if (_disposed) {
        return;
      }
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _disposed = true;

    if (_audioPlayer != null) {
      // Indicate to all other async code that it should not be accessing the player anymore.
      final audioPlayer = _audioPlayer;
      _audioPlayer = null;
      _disposeAudioPlayer(audioPlayer);
    }

    // Note that this doesn't clear the cache until
    // https://github.com/luanpotter/audioplayers/issues/539 is resolved.
    _audioCache.clearCache();

    super.dispose();
  }

  Future<void> _disposeAudioPlayer(AudioPlayer audioPlayer) async {
    // Explicit release() needed until https://github.com/luanpotter/audioplayers/pull/507 lands.
    await audioPlayer.release();
    await audioPlayer.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        if (_audioPlayer != null && _audioPlayer.state == AudioPlayerState.PLAYING) {
          _audioPlayer.pause();
          _pausedDueToLifecycleState = true;
        }
        break;
      case AppLifecycleState.resumed:
        if (_audioPlayer != null && _audioPlayer.state == AudioPlayerState.PAUSED && _pausedDueToLifecycleState) {
          _audioPlayer.resume();
          _pausedDueToLifecycleState = false;
        }
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
              onChanged: _audioPlayer != null ? _seek : null,
            ),
          ),
          IconButton(
            icon: Icon(_state == AudioPlayerState.PLAYING ? Icons.pause : Icons.play_arrow),
            iconSize: 48.0,
            onPressed: _audioPlayer != null ? _togglePlaying : null,
          ),
        ]
    );
  }

  void _togglePlaying() {
    if (_audioPlayer == null) {
      print('${this} tried to toggle playback without AudioPlayer');
      return;
    }
    if (_state != AudioPlayerState.PLAYING) {
      _audioPlayer.resume();
    } else {
      _audioPlayer.pause();
    }
    _pausedDueToLifecycleState = false;
  }

  void _seek(double position) {
    if (_audioPlayer == null) {
      print('${this} tried to seek without AudioPlayer');
      return;
    }
    _audioPlayer.seek(Duration(milliseconds: position.toInt()));
  }

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      super.toString(minLevel: minLevel) + '(${_recording.fileName})';
}