import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// A localization delegate that assumes that the localization for each
/// particular language is implemented in a class, all implementing a common
/// base interface [T]. Its constructor takes as an argument the mapping between
/// locales and concrete instances of [T].
class InheritanceDelegate<T> extends LocalizationsDelegate<T> {
  InheritanceDelegate(this.locales, {Locale defaultLocale}) :
      defaultLocale = defaultLocale ?? Locale('en')
  {
    assert(locales.containsKey(this.defaultLocale));
  }

  final Map<Locale, T> locales;
  final Locale defaultLocale;

  List<Locale> get supportedLocales => locales.keys.toList();

  @override
  bool isSupported(Locale locale) => locales.containsKey(locale);

  @override
  Future<T> load(Locale locale) {
    if (locales.containsKey(locale)) {
      return SynchronousFuture<T>(locales[locale]);
    } else {
      return SynchronousFuture<T>(locales[defaultLocale]);
    }
  }

  @override
  bool shouldReload(InheritanceDelegate<T> old) => false;
}