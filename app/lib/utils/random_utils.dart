import 'dart:math';

import 'package:built_collection/built_collection.dart';

extension MoreRandom on Random {
  double angleInRadians() {
    return nextDouble() * 2.0 * pi;
  }

  double doubleBetween(double min, double max) {
    return min + (max - min) * nextDouble();
  }

  int intBetween(int min, int max) {
    return min + nextInt(max - min);
  }

  int sign() {
    return nextBool() ? 1 : -1;
  }
}

extension RandomElement<T> on List<T> {
  /// Returns a uniformly random element from this list.
  T randomElement(Random random) {
    assert(isNotEmpty);
    return this[random.nextInt(length)];
  }
}

/// Returns random elements from an array or other iterable using the "Tetris
/// bag" algorithm: each element is returned exactly once, in random order, and
/// then they are all reshuffled for the next round. This guarantees fairness.
///
/// It is legal to create a RandomBag with no elements, but it is not legal to
/// sample from it.
class RandomBag<T> {

  final BuiltList<T> elements;
  final _remaining = <T>[];

  RandomBag(Iterable<T> elements) :
      elements = elements.toBuiltList();

  T next(Random random) {
    if (_remaining.isEmpty) {
      assert(elements.isNotEmpty);
      _remaining
          ..addAll(elements)
          ..shuffle(random);
    }
    return _remaining.removeLast();
  }

}

/// Like `RandomBag` except not random.
class CyclicBag<T> {
  final BuiltList<T> elements;
  var _nextIndex = 0;

  CyclicBag(Iterable<T> elements) :
      elements = elements.toBuiltList();

  T next() {
    assert(elements.isNotEmpty);
    final result = elements[_nextIndex];
    _nextIndex = (_nextIndex + 1) % elements.length;
    return result;
  }
}