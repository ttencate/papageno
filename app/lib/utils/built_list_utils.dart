import 'package:built_collection/built_collection.dart';

extension Trim<T> on ListBuilder<T> {
  void trimTo(int maxLength) {
    if (length > maxLength) {
      removeRange(maxLength, length);
    }
  }
}