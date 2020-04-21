import 'dart:math';

extension Angle on double {
  double degToRad() {
    return this * pi / 180.0;
  }
}