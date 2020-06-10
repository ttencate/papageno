import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';

class CircleClipper extends CustomClipper<Rect> {
  const CircleClipper({Listenable reclip, this.fraction = 1.0}) :
        super(reclip: reclip);

  final double fraction;

  @override
  Rect getApproximateClipRect(Size size) {
    return getClip(size);
  }

  @override
  Rect getClip(Size size) {
    final diameter = fraction * sqrt(size.width * size.width + size.height * size.height);
    return Rect.fromCenter(center: size.center(Offset.zero), width: diameter, height: diameter);
  }

  @override
  bool shouldReclip(CustomClipper<Rect> oldClipper) {
    return oldClipper.runtimeType == CircleClipper ? (oldClipper as CircleClipper).fraction != fraction : true;
  }
}

class RevealingImage extends StatefulWidget {
  RevealingImage({@required this.image, this.revealed = true}) :
        assert(image != null);

  final Widget image;
  final bool revealed;

  @override
  State<StatefulWidget> createState() => _RevealingImageState();
}

class _RevealingImageState extends State<RevealingImage> with SingleTickerProviderStateMixin {
  AnimationController controller;
  Animation<double> animation;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(duration: const Duration(milliseconds: 1000), vsync: this);
    animation = Tween<double>(begin: 0.0, end: 1.0).animate(controller)
        // TODO figure out why we need this -- CustomClipper.reclip is tied to this animation so it should be updating outside the build cycle, right?
        ..addListener(() { setState(() {}); });
    if (widget.revealed) {
      controller.forward(from: 1.0); // Skip to end.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.revealed) {
      controller.forward();
    } else {
      controller.reverse();
    }
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: Container(
            color: Colors.grey.shade200,
            child: FittedBox(
              fit: BoxFit.contain,
              alignment: Alignment.center,
              child: Padding(
                padding: EdgeInsets.all(64.0),
                child: Image(
                  image: AssetImage('assets/question.png'),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: ClipOval(
            clipper: CircleClipper(
              fraction: animation.value,
              reclip: animation,
            ),
            // Supposed to be faster than antiAlias, and during animation the
            // difference is invisible anyway.
            clipBehavior: Clip.hardEdge,
            child: widget.image,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}