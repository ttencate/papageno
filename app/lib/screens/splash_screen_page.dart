import 'package:flutter/material.dart';
import 'package:papageno/common/strings.g.dart';
import 'package:transparent_image/transparent_image.dart';

class SplashScreenPage extends StatefulWidget {

  final Future<void> loadingFuture;
  final void Function() onDismissed;

  const SplashScreenPage({Key key, @required this.loadingFuture, @required this.onDismissed}) : super(key: key);

  @override
  _SplashScreenPageState createState() => _SplashScreenPageState();
}

class _SplashScreenPageState extends State<SplashScreenPage> {
  static const _minimumSplashScreenDuration = Duration(seconds: 3);

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  void _init() async {
    final waitFuture = Future<void>.delayed(_minimumSplashScreenDuration);
    await widget.loadingFuture;
    setState(() { _loading = false; });
    await waitFuture;
    widget.onDismissed();
  }

  @override
  Widget build(BuildContext context) {
    final strings = Strings.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            FadeInImage(
              placeholder: MemoryImage(kTransparentImage),
              image: AssetImage('assets/logo.png'),
              width: 256.0,
              height: 256.0,
            ),
            SizedBox(height: 32.0),
            Text(
              'Papageno',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 40.0,
                color: Colors.black87,
              ),
            ),
            Text(
              'Birdsong Tutor'.toUpperCase(),
              style: TextStyle(
                fontWeight: FontWeight.w300,
                fontSize: 16.0,
                letterSpacing: 3.6,
              ),
            ),
            SizedBox(height: 32.0),
            AnimatedOpacity(
              opacity: _loading ? 1.0 : 0.0,
              duration: Duration(milliseconds: 300),
              child: Column(
                children: <Widget>[
                  Text(
                    strings.loading,
                    style: TextStyle(
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  SizedBox(height: 8.0),
                  CircularProgressIndicator(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}