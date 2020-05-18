import 'package:flutter/material.dart';
import 'package:papageno/ui/create_course.dart';
import 'package:papageno/ui/strings.g.dart';
import 'package:transparent_image/transparent_image.dart';

class SplashScreen extends StatefulWidget {
  static const route = '/splashScreen';
  static const _minimumDuration = Duration(seconds: 3);

  final Future<void> waitFuture = Future<void>.delayed(_minimumDuration);
  final Future<void> loadingFuture;

  SplashScreen({Key key, this.loadingFuture}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    widget.loadingFuture.then((_) {
      setState(() { _loading = false; });
    });
    Future.wait(<Future<void>>[widget.loadingFuture, widget.waitFuture]).then((_) {
      Navigator.of(context).pushReplacementNamed(CreateCoursePage.route);
    });
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