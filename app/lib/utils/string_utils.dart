extension Capitalize on String {
  String capitalize() {
    if (isEmpty) return '';
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  String ellipsize(int maxLength) {
    if (length <= maxLength) {
      return this;
    } else {
      return '${substring(0, maxLength - 3)}...';
    }
  }
}