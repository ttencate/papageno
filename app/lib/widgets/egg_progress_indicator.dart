/// Clone of Flutter's official [CircularProgressIndicator] except with a more
/// appropriate shape for this application. Sadly the original is not modular
/// enough that we can just plug a new renderer in; we have to copy the whole
/// thing. Our version is not adaptive between Cupertino and Material styles.

import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;

const double _kEggLeftExtent = 1.0;
const double _kEggRightExtent = 1.0;
const double _kEggTopExtent = 1.0 + (2.0 - math.sqrt2);
const double _kEggBottomExtent = 1.0;
const double _kEggWidth = _kEggLeftExtent + _kEggRightExtent;
const double _kEggHeight = _kEggTopExtent + _kEggBottomExtent;

const double _kEggProgressIndicatorWidth = 36.0;
const double _kEggProgressIndicatorHeight = _kEggProgressIndicatorWidth * _kEggHeight / _kEggWidth;
const int _kIndeterminateCircularDuration = 1333 * 2222;

/// A material design circular progress indicator, which spins to indicate that
/// the application is busy.
///
/// {@youtube 560 315 https://www.youtube.com/watch?v=O-rhXZLtpv0}
///
/// A widget that shows progress along a circle. There are two kinds of circular
/// progress indicators:
///
///  * _Determinate_. Determinate progress indicators have a specific value at
///    each point in time, and the value should increase monotonically from 0.0
///    to 1.0, at which time the indicator is complete. To create a determinate
///    progress indicator, use a non-null [value] between 0.0 and 1.0.
///  * _Indeterminate_. Indeterminate progress indicators do not have a specific
///    value at each point in time and instead indicate that progress is being
///    made without indicating how much progress remains. To create an
///    indeterminate progress indicator, use a null [value].
///
/// The indicator arc is displayed with [valueColor], an animated value. To
/// specify a constant color use: `AlwaysStoppedAnimation<Color>(color)`.
///
/// See also:
///
///  * [LinearProgressIndicator], which displays progress along a line.
///  * [RefreshIndicator], which automatically displays a [EggProgressIndicator]
///    when the underlying vertical scrollable is overscrolled.
///  * <https://material.io/design/components/progress-indicators.html#circular-progress-indicators>
class EggProgressIndicator extends ProgressIndicator {
  /// Creates a circular progress indicator.
  ///
  /// {@macro flutter.material.ProgressIndicator.ProgressIndicator}
  const EggProgressIndicator({
    Key key,
    double value,
    Color backgroundColor,
    Animation<Color> valueColor,
    this.strokeWidth = 4.0,
    String semanticsLabel,
    String semanticsValue,
  }) : super(
        key: key,
        value: value,
        backgroundColor: backgroundColor,
        valueColor: valueColor,
        semanticsLabel: semanticsLabel,
        semanticsValue: semanticsValue,
      );

  /// The width of the line used to draw the circle.
  ///
  /// This property is ignored if used in an adaptive constructor inside an iOS
  /// environment.
  final double strokeWidth;

  @override
  _EggProgressIndicatorState createState() => _EggProgressIndicatorState();

  Widget _buildSemanticsWrapper({
    @required BuildContext context,
    @required Widget child,
  }) {
    var expandedSemanticsValue = semanticsValue;
    if (value != null) {
      expandedSemanticsValue ??= '${(value * 100).round()}%';
    }
    return Semantics(
      label: semanticsLabel,
      value: expandedSemanticsValue,
      child: child,
    );
  }

  Color _getValueColor(BuildContext context) => valueColor?.value ?? Theme.of(context).accentColor;
}

class _EggProgressIndicatorState extends State<EggProgressIndicator> with SingleTickerProviderStateMixin {
  static const int _pathCount = _kIndeterminateCircularDuration ~/ 1333;
  static const int _rotationCount = _kIndeterminateCircularDuration ~/ 2222;

  static final Animatable<double> _strokeHeadTween = CurveTween(
    curve: const Interval(0.0, 0.5, curve: Curves.fastOutSlowIn),
  ).chain(CurveTween(
    curve: const SawTooth(_pathCount),
  ));
  static final Animatable<double> _strokeTailTween = CurveTween(
    curve: const Interval(0.5, 1.0, curve: Curves.fastOutSlowIn),
  ).chain(CurveTween(
    curve: const SawTooth(_pathCount),
  ));
  static final Animatable<double> _offsetTween = CurveTween(curve: const SawTooth(_pathCount));
  static final Animatable<double> _rotationTween = CurveTween(curve: const SawTooth(_rotationCount));

  AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: _kIndeterminateCircularDuration),
      vsync: this,
    );
    if (widget.value == null) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(EggProgressIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value == null && !_controller.isAnimating) {
      _controller.repeat();
    } else if (widget.value != null && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildMaterialIndicator(BuildContext context, double headValue, double tailValue, double offsetValue, double rotationValue) {
    return widget._buildSemanticsWrapper(
      context: context,
      child: SizedBox(
        width: _kEggProgressIndicatorWidth,
        height: _kEggProgressIndicatorHeight,
        child: CustomPaint(
          painter: _EggProgressIndicatorPainter(
            backgroundColor: widget.backgroundColor,
            valueColor: widget._getValueColor(context),
            value: widget.value, // may be null
            headValue: headValue, // remaining arguments are ignored if widget.value is not null
            tailValue: tailValue,
            offsetValue: offsetValue,
            rotationValue: rotationValue,
            strokeWidth: widget.strokeWidth,
          ),
        ),
      ),
    );
  }

  Widget _buildAnimation() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget child) {
        return _buildMaterialIndicator(
          context,
          _strokeHeadTween.evaluate(_controller),
          _strokeTailTween.evaluate(_controller),
          _offsetTween.evaluate(_controller),
          _rotationTween.evaluate(_controller),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.value != null) {
      return _buildMaterialIndicator(context, 0.0, 0.0, 0, 0.0);
    }
    return _buildAnimation();
  }
}

/// Paints a section of the egg shape.
///
/// Turns out that simply sticking a half ellipse on top of a half circle
/// does not look good. But this one does:
/// https://en.wikipedia.org/wiki/Egg_of_Columbus_(tangram_puzzle)
class _EggProgressIndicatorPainter extends CustomPainter {
  _EggProgressIndicatorPainter({
    this.backgroundColor,
    @required this.valueColor,
    @required this.value,
    @required this.headValue,
    @required this.tailValue,
    @required this.offsetValue,
    @required this.rotationValue,
    @required this.strokeWidth,
  }) :
    arcStart = value != null
      ? _startAngle
      : _startAngle + tailValue * 3 / 2 * math.pi + rotationValue * math.pi * 2.0 + offsetValue * 0.5 * math.pi,
    arcSweep = value != null
      ? value.clamp(0.0, 1.0).toDouble() * _sweep
      : math.max(headValue * 3 / 2 * math.pi - tailValue * 3 / 2 * math.pi, _epsilon);

  final Color backgroundColor;
  final Color valueColor;
  final double value;
  final double headValue;
  final double tailValue;
  final double offsetValue;
  final double rotationValue;
  final double strokeWidth;
  final double arcStart;
  final double arcSweep;

  static const double _twoPi = math.pi * 2.0;
  static const double _epsilon = .001;
  // Canvas.drawArc(r, 0, 2*PI) doesn't draw anything, so just get close.
  static const double _sweep = _twoPi - _epsilon;
  static const double _startAngle = -math.pi / 2.0;

  static const _topRadius = 2.0 - math.sqrt2;
  static const _segments = <_CircleSegment>[
    // Just like in the original and in Path.arcTo, we start on the right side and go clockwise.
    _CircleSegment(Offset(0.0, 0.0), 1.0, 0.0, math.pi), // Bottom
    _CircleSegment(Offset(1.0, 0.0), 2.0, math.pi, 0.25 * math.pi), // Left
    _CircleSegment(Offset(0.0, -1.0), _topRadius, 1.25 * math.pi, 0.5 * math.pi), // Top
    _CircleSegment(Offset(-1.0, 0.0), 2.0, 1.75 * math.pi, 0.25 * math.pi), // Right
  ];
  static final double _totalLength = _segments.map((s) => s.length).fold(0.0, (a, b) => a + b);

  @override
  void paint(Canvas canvas, Size size) {
    if (backgroundColor != null) {
      final backgroundPaint = Paint()
        ..color = backgroundColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke;
      _drawEgg(canvas, size, 0.0, _sweep, backgroundPaint);
    }
    final paint = Paint()
      ..color = valueColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    _drawEgg(canvas, size, arcStart, arcSweep, paint);
  }

  static void _drawEgg(Canvas canvas, Size size, double arcStart, double arcSweep, Paint paint) {
    final startLength = (arcStart * _totalLength / _twoPi) % _totalLength;
    final endLength = startLength + arcSweep * _totalLength / _twoPi;

    final path = Path();
    var forceMoveTo = true;
    var length = 0.0;
    var i = 0;
    while (length < endLength) {
      final segment = _segments[i % _segments.length];
      final startFraction = ((startLength - length) / segment.length).clamp(0.0, 1.0);
      final endFraction = ((endLength - length) / segment.length).clamp(0.0, 1.0);
      if (startFraction < endFraction) {
        final startAngle = segment.startAngle + startFraction * segment.sweepAngle;
        final sweepAngle = segment.startAngle + endFraction * segment.sweepAngle - startAngle;
        path.arcTo(
            (segment.center - Offset(segment.radius, segment.radius)) &
              Size(2.0 * segment.radius, 2.0 * segment.radius),
            startAngle, sweepAngle, forceMoveTo);
        forceMoveTo = false;
      }
      length += _segments[i % _segments.length].length;
      i++;
    }

    final transform = Matrix4.compose(
        Vector3(size.width * _kEggLeftExtent / _kEggWidth, size.height * _kEggTopExtent / _kEggHeight, 1.0),
        Quaternion.identity(),
        Vector3(size.width / _kEggWidth, size.height / _kEggHeight, 1.0));
    
    canvas.drawPath(path.transform(transform.storage), paint);
  }

  @override
  bool shouldRepaint(_EggProgressIndicatorPainter oldPainter) {
    return oldPainter.backgroundColor != backgroundColor
        || oldPainter.valueColor != valueColor
        || oldPainter.value != value
        || oldPainter.headValue != headValue
        || oldPainter.tailValue != tailValue
        || oldPainter.offsetValue != offsetValue
        || oldPainter.rotationValue != rotationValue
        || oldPainter.strokeWidth != strokeWidth;
  }
}

class _CircleSegment {
  final Offset center;
  final double radius;
  final double startAngle;
  final double sweepAngle;
  final double length;

  const _CircleSegment(this.center, this.radius, this.startAngle, this.sweepAngle) :
    length = radius * sweepAngle;
}