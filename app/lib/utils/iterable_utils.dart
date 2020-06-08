extension Sorted<T> on Iterable<T> {
  List<T> sorted([int Function(T, T) compare]) {
    return <T>[...this]..sort(compare);
  }
}