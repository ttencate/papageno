import 'package:flutter/material.dart';

// TODO: Currently unused.
Color percentageColor(int percent) {
  // Conveniently, maps in Dart preserve their order.
  const stops = <int, Color>{
    0: Color.fromRGBO(0, 0, 0, 0.15),
    20: Colors.red,
    40: Colors.deepOrange,
    50: Colors.orange,
    60: Colors.yellow,
    75: Colors.lightGreen,
    100: Colors.green,
  };
  var prevLocation = stops.keys.first;
  var prevColor = stops.values.first;
  for (final stop in stops.entries.skip(1)) {
    if (percent <= stop.key) {
      return Color.lerp(prevColor, stop.value, (percent - prevLocation) / (stop.key - prevLocation));
    }
    prevLocation = stop.key;
    prevColor = stop.value;
  }
  return stops.values.last;
}