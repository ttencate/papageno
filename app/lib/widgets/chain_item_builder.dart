import 'package:flutter/widgets.dart';

/// Helper for building [ListView] items on demand from an index, where the index is not into a single array but rather
/// into a concatenation of multiple arrays and/or single elements.
@immutable
class ChainItemBuilder {
  final List<ChainSection> sections;

  ChainItemBuilder({@required this.sections});

  /// Makes this class callable to adhere to the [IndexedWidgetBuilder] interface.
  Widget call(BuildContext context, int index) {
    for (final section in sections) {
      if (index < section.itemCount) {
        return section.itemBuilder(context, index);
      }
      index -= section.itemCount;
    }
    return null;
  }
}

@immutable
class ChainSection {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  ChainSection(this.itemCount, this.itemBuilder);

  ChainSection.single(Widget widget) :
      itemCount = 1,
      itemBuilder = ((BuildContext context, int index) => index == 0 ? widget : null);

  ChainSection.singleBuilder(WidgetBuilder builder) :
      itemCount = 1,
      itemBuilder = ((BuildContext context, int index) => index == 0 ? builder(context) : null);

  static ChainSection listBuilder<T>(List<T> list, Widget Function(BuildContext context, T element) builder) => ChainSection(
      list.length,
      (BuildContext context, int index) => index >= 0 && index < list.length ? builder(context, list[index]) : null);
}