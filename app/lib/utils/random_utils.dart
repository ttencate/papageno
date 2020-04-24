import 'dart:math';

extension RandomElement<T> on List<T> {
  T randomElement(Random random) {
    assert(isNotEmpty);
    return this[random.nextInt(length)];
  }
}