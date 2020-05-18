import 'dart:async';

import 'package:audioplayers/audio_cache.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:papageno/model/model.dart';

/// Audio player widget with seek bar and play/pause button.
// TODO: Sometimes hot reload causes double playback.
class Player extends StatefulWidget {
  final Recording recording;

  Player({Key key, @required this.recording}) :
        assert(recording != null),
        super(key: key);

  @override
  _PlayerState createState() => _PlayerState();
}

class _PlayerState extends State<Player> with WidgetsBindingObserver {
  AudioPlayer _audioPlayer;
  AudioCache _audioCache;
  bool _loaded = false;
  AudioPlayerState _state = AudioPlayerState.STOPPED;
  bool _pausedDueToLifecycleState = false;
  Duration _duration = Duration();
  Duration _position = Duration();
  StreamSubscription<AudioPlayerState> _playerStateSubscription;
  StreamSubscription<Duration> _durationSubscription;
  StreamSubscription<Duration> _audioPositionSubscription;

  Recording get _recording => widget.recording;

  @override
  void initState() {
    super.initState();
    // AudioPlayer.logEnabled = true;
    _audioPlayer = AudioPlayer();
    _audioPlayer.setReleaseMode(ReleaseMode.LOOP);
    _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen((AudioPlayerState state) {
      setState(() { _state = state; });
    });
    _durationSubscription = _audioPlayer.onDurationChanged.listen((Duration duration) {
      setState(() { _duration = duration; });
    });
    _audioPositionSubscription = _audioPlayer.onAudioPositionChanged.listen((Duration position) {
      setState(() { _position = position; });
    });

    _audioCache = AudioCache(fixedPlayer: _audioPlayer, prefix: 'sounds/');
    _audioCache.play(_recording.fileName).then((_) {
      _pausedDueToLifecycleState = false;
      setState(() {
        _loaded = true;
      });
    });

    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _audioCache.clearCache();

    _playerStateSubscription.cancel();
    _durationSubscription.cancel();
    _audioPositionSubscription.cancel();
    _audioPlayer.release();

    super.dispose();
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
              onChanged: _loaded ? _seek : null,
            ),
          ),
          IconButton(
            icon: Icon(_state == AudioPlayerState.PLAYING ? Icons.pause : Icons.play_arrow),
            iconSize: 48.0,
            onPressed: _loaded ? _togglePlaying : null,
          ),
        ]
    );
  }

  void _togglePlaying() {
    if (_state != AudioPlayerState.PLAYING) {
      _audioPlayer.resume();
    } else {
      _audioPlayer.pause();
    }
    _pausedDueToLifecycleState = false;
  }

  void _seek(double position) {
    _audioPlayer.seek(Duration(milliseconds: position.toInt()));
  }
}