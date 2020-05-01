import 'package:flutter/material.dart';

import 'create_course.dart';
import 'strings.dart';

class SplashScreen extends StatefulWidget {
  static const route = '/splashScreen';

  final Future<void> loadingFuture;

  const SplashScreen({Key key, this.loadingFuture}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();
    widget.loadingFuture.then((_) {
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
            Image(
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
    );
  }
}