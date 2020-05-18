extension Sorted<T> on Iterable<T> {
  List<T> sorted([int Function(T, T) compare]) {
    final clone = <T>[...this];
    clone.sort(compare);
    return clone;
  }
}