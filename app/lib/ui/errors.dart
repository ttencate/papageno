import 'package:flutter/material.dart';

// TODO only for development; get rid of this
class ErrorScreen extends StatelessWidget {

  final String message;
  final dynamic exception;

  const ErrorScreen(this.message, this.exception) : super();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
          child: Text('${message}\n${exception}')
      ),
    );
  }
}