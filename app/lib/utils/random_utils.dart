import 'dart:math';

import 'package:built_collection/built_collection.dart';

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
class RandomBag<T> {

  final BuiltList<T> elements;
  final _remaining = <T>[];

  RandomBag(Iterable<T> elements) :
      elements = elements.toBuiltList()
  {
    assert(this.elements.isNotEmpty);
  }

  T next(Random random) {
    if (_remaining.isEmpty) {
      _remaining.addAll(elements);
      _remaining.shuffle(random);
    }
    return _remaining.removeLast();
  }

}