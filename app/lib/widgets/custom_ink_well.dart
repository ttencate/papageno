
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// A widget similar to [InkWell] but which allows triggering ink splashes at any moment
/// and position through its controller, rather than only on user input.
///
/// Not currently used; here only for reference.
class CustomInkWell extends SingleChildRenderObjectWidget {
  final CustomInkWellController controller;

  CustomInkWell({Key key, Widget child, @required this.controller}) : super(key: key, child: child);

  @override
  RenderObject createRenderObject(BuildContext context) {
    final renderObject = _CustomInkWellRenderObject();
    final material = Material.of(context);
    controller._splashes.stream.listen((splash) => renderObject.addSplash(material, splash));
    return renderObject;
  }
}

/// Definition of a custom ink splash.
@immutable
class CustomInkSplash {
  /// Color of the splash.
  final Color color;
  /// Position of the splash's center. If `null`, uses the center of the widget.
  final Offset position;
  /// How long the splash should take to fill the widget. If `null`, fills it instantly.
  final Duration duration;
  /// Delay until the animation should start. If `null`, starts immediately.
  final Duration delay;

  CustomInkSplash({@required this.color, this.position, this.duration, this.delay});
}

/// Controller for [CustomInkWell]. Can be used to add splashes on demand.
/// Must be disposed after use.
class CustomInkWellController {
  final _splashes = StreamController<CustomInkSplash>();

  void addSplash(CustomInkSplash splash) {
    _splashes.add(splash);
  }

  void dispose() {
    _splashes.close();
  }
}

class _CustomInkWellRenderObject extends RenderProxyBox {
  final _features = <InkFeature>[];

  void addSplash(MaterialInkController material, CustomInkSplash splash) {
    final feature = _AnswerInkFeature(
      controller: material,
      referenceBox: this,
      splash: splash,
    );
    _features.add(feature);
  }

  @override
  void detach() {
    for (final feature in _features) {
      feature.dispose();
    }
    super.detach();
  }
}

/// A red or green ink ripple that indicates whether or not the answer was correct.
/// Unlike [InkRipple] and [InkSplash], it does not fade out, so it persists until explicitly disposed.
class _AnswerInkFeature extends InkFeature {
  final Offset _position;
  final Paint _paint;
  AnimationController _radiusController;
  Animation<double> _radius;

  _AnswerInkFeature({@required MaterialInkController controller, @required RenderBox referenceBox, @required CustomInkSplash splash}) :
        _position = splash.position ?? referenceBox.size.center(Offset.zero),
        _paint = Paint()..color = splash.color,
        super(controller: controller, referenceBox: referenceBox)
  {
    final size = referenceBox.size;
    final finalRadius =
    [
      size.topLeft(Offset.zero), size.topRight(Offset.zero),
      size.bottomLeft(Offset.zero), size.bottomRight(Offset.zero)
    ]
        .map((corner) => (corner - _position).distance)
        .reduce(max);
    final duration = splash.duration ?? Duration.zero;
    final delay = splash.delay ?? Duration.zero;
    final totalDuration = duration + delay;

    _radiusController = AnimationController(duration: totalDuration, vsync: controller.vsync)
      ..addListener(controller.markNeedsPaint);
    if (totalDuration > Duration.zero) {
      _radius = _radiusController.drive(
          Tween<double>(begin: 0.0, end: finalRadius)
              .chain(CurveTween(curve: Interval(delay.inMicroseconds / totalDuration.inMicroseconds, 1.0, curve: Curves.ease)))
      );
    } else {
      _radius = AlwaysStoppedAnimation<double>(finalRadius);
    }
    _radiusController.forward();

    controller.addInkFeature(this);
  }

  @override
  void paintFeature(Canvas canvas, Matrix4 transform) {
    final clipRect = Rect.fromPoints(Offset.zero, referenceBox.size.bottomRight(Offset.zero));
    canvas
      ..save()
      ..transform(transform.storage)
      ..clipRect(clipRect)
      ..drawCircle(_position, _radius.value, _paint)
      ..restore();
  }
}