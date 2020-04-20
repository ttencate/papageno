import 'dart:async';

import 'package:audioplayers/audio_cache.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../model/model.dart';

class Player extends StatefulWidget {
  final Recording recording;

  Player({Key key, @required this.recording}) :
        assert(recording != null),
        super(key: key);

  @override
  _PlayerState createState() => _PlayerState();
}

class _PlayerState extends State<Player> {
  AudioPlayer _audioPlayer;
  AudioCache _audioCache;
  bool _loaded = false;
  AudioPlayerState _state = AudioPlayerState.STOPPED;
  Duration _duration = Duration();
  Duration _position = Duration();
  StreamSubscription<AudioPlayerState> _playerStateSubscription;
  StreamSubscription<Duration> _durationSubscription;
  StreamSubscription<Duration> _audioPositionSubscription;

  Recording get _recording => widget.recording;

  @override
  void initState() {
    super.initState();
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

    _audioCache = AudioCache(fixedPlayer: _audioPlayer);
    _audioCache.play(_recording.fileName).then((_) {
      setState(() {
        _loaded = true;
      });
    });
  }

  @override
  void dispose() {
    _audioCache.clearCache();

    _playerStateSubscription.cancel();
    _durationSubscription.cancel();
    _audioPositionSubscription.cancel();
    _audioPlayer.release();

    super.dispose();
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
            color: Colors.blue, // TODO take from theme
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
  }

  void _seek(double position) {
    _audioPlayer.seek(Duration(milliseconds: position.toInt()));
  }
}