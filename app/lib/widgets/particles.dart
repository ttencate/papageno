import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Controller for the [Particles] widget.
/// Must be disposed after use.
class ParticlesController {

  final List<Particle> _particles;
  _TickNotifier _tickNotifier;
  _ParticlesPainter _painter;
  Ticker _ticker;
  Duration _previousTick;

  ParticlesController({
    @required List<Particle> particles,
    @required ui.Image image,
  }) :
      _particles = particles
  {
    _tickNotifier = _TickNotifier();

    _painter = _ParticlesPainter(
      repaint: _tickNotifier,
      controller: this,
      image: image,
    );

    _ticker = Ticker(_onTick);
  }

  /// Starts the particle animation. The returned future completes when the animation completes,
  /// or this controller is disposed, whichever comes first.
  Future<void> start() {
    return _ticker.start().orCancel;
  }

  void dispose() {
    if (_ticker.isActive) {
      _ticker.stop(canceled: true);
    }
    _ticker.dispose();
    _ticker = null;

    _tickNotifier.dispose();
    _tickNotifier = null;
  }

  void _onTick(Duration now) {
    if (_isDisposed) {
      return;
    }

    _previousTick ??= now;
    final delta = now - _previousTick;

    for (final particle in _particles) {
      particle.tick(delta);
    }
    _particles.removeWhere((particle) => !particle.isAlive);
    if (_particles.isEmpty) {
      _ticker.stop();
    }
    _tickNotifier.notifyListeners();

    _previousTick = now;
  }

  bool get _isDisposed => _tickNotifier == null;
}

final _imageCache = <dynamic, ui.Image>{};

/// Helper that simulates and renders particles in an [Overlay].
/// It cleans itself up after all particles have disappeared, so it's fire-and-forget.
/// Images loaded from the [ImageProvider] are cached forever, so don't go crazy with variety!
Future<void> spawnParticlesInOverlay({@required BuildContext context, @required ImageProvider image, @required List<Particle> particles}) async {
  final renderBox = context.findRenderObject() as RenderBox;
  final globalOffset = renderBox.localToGlobal(Offset.zero);
  final overlay = Overlay.of(context);
  final imageConfiguration = createLocalImageConfiguration(context);

  final cacheKey = image.obtainKey(imageConfiguration);
  if (!_imageCache.containsKey(cacheKey)) {
    final completer = Completer<ui.Image>();
    image.resolve(createLocalImageConfiguration(context))
        .addListener(ImageStreamListener((imageInfo, synchronousCall) {
          completer.complete(imageInfo.image);
        }));
    _imageCache[cacheKey] = await completer.future;
  }
  final img = _imageCache[cacheKey];

  final particlesController = ParticlesController(particles: particles, image: img);

  final overlayEntry = OverlayEntry(
    builder: (context) => Positioned(
      left: globalOffset.dx,
      top: globalOffset.dy,
      child: Particles(
        controller: particlesController,
      ),
    )
  );
  overlay.insert(overlayEntry);

  await particlesController.start();

  overlayEntry.remove();
  // We need to delay the removal of the controller because removal of the OverlayEntry itself is also delayed,
  // and we must avoid disposing the controller when it's still in use by the widget inside the overlay.
  SchedulerBinding.instance.addPostFrameCallback((Duration duration) {
    particlesController.dispose();
  });
}

/// A widget that draws particle effects on top of some child widget.
class Particles extends StatelessWidget {
  final ParticlesController controller;
  final Widget child;

  const Particles({Key key, @required this.controller, this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: controller._painter,
      // willChange: _ticker.isActive,
      child: child,
    );
  }
}

/// Trivial helper because [ChangeNotifier.notifyListeners] is not public.
class _TickNotifier extends ChangeNotifier {
  @override
  void notifyListeners() { // ignore: unnecessary_overrides
    super.notifyListeners();
  }
}

/// Representation of a particle, just enough to render it.
/// Subclass it to implement behaviour.
abstract class Particle {
  Offset position = Offset.zero;
  double rotation = 0.0;
  Size size = Size.zero;
  double opacity = 1.0;

  bool get isAlive;

  void tick(Duration delta);
}

class _ParticlesPainter extends CustomPainter {
  final ParticlesController _controller;
  final ui.Image _image;

  _ParticlesPainter({@required Listenable repaint, @required ParticlesController controller, @required ui.Image image}) :
      _controller = controller,
      _image = image,
      super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in _controller._particles) {
      final paint = Paint()..color = Colors.white.withOpacity(particle.opacity);
      canvas
          ..save()
          ..translate(particle.position.dx, particle.position.dy)
          ..rotate(particle.rotation)
          ..scale(particle.size.width / _image.width, particle.size.height / _image.height)
          ..translate(-_image.width / 2, -_image.height / 2)
          ..drawImage(_image, Offset.zero, paint)
          ..restore();
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) =>
      oldDelegate is _ParticlesPainter && oldDelegate._controller != _controller;

  // Particles are purely cosmetic, they don't have any semantics.
  @override
  bool shouldRebuildSemantics(CustomPainter oldDelegate) => false;
}