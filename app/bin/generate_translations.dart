/// Ingests a manually created CSV file (e.g. from a spreadsheet program) to
/// generate Dart code containing translated strings.
///
/// The columns are:
///
///     key,description,aa,bb,...
///
/// where `key` must be a valid Dart identifier, `description` is a hint for the
/// translators about the context in which the string is used, and `aa`, `bb`,
/// and so on are language codes (for example: `en`, `en_GB`, `nl`).
///
/// Note that these CSV conventions must be used:
///
/// - Use Unix line endings
/// - Separate columns by a comma (`,`)
/// - Surround any field containing a comma or newline with double quotes (`"`)
/// - Escape double quotes inside a field by doubling them (`""`)
///
/// Each translated string may contain placeholders using one of the following
/// formats:
///
/// - `${...}` for inserting a string
/// - `#{...}` for inserting an integer
///
/// The placeholder name must be a valid Dart identifier. Translations using at
/// least one placeholder are generated as Dart functions that take the
/// placeholder values as arguments of the correct type. A warning is emitted if
/// a placeholder name is not used in all translations.
///
/// Translations for a specific country code (e.g. `en_GB`) will inherit from a
/// more generic one (e.g. `en`) if available, meaning that translations that
/// don't differ among language variants may be left blank. If no generic
/// language is available, languages will inherit from the _first_ language in
/// the list, which thus becomes the default (and must not have any blanks).
///
/// Usage:
///
/// - Update translations.csv
/// - Run 'flutter pub run generate_translations'
/// - Build and run the app as usual
///
/// We use this, rather than the Dart "intl" package, because the latter is
/// overly complex. Moreover, it relies on the .arb file format which is not
/// widely supported, especially since the shutdown of Google Translator
/// Toolkit. The solution is being discussed
/// (https://github.com/dart-lang/intl_translation/issues/74) but we need
/// something today, and it doesn't hurt if it's easier to use.
///
/// If we ever want to extract this into a standalone Dart package, this is what
/// would need to be done:
///
/// - Make input and output file names configurable
/// - Improve error reporting (replace all asserts by exceptions, and report
///   row/column where appropriate)
/// - Add support for plurals and genders
/// - Add a way to escape placeholders
/// - Make the Flutter dependency optional
/// - Add better documentation, especially about the generated code
/// - Add unit tests

import 'dart:io';

import 'package:csv/csv.dart';
import 'package:meta/meta.dart';

void main() {
  const inputFileName = 'translations.csv';
  const outputFileName = 'lib/strings.g.dart';
  const baseName = 'Strings';

  stderr.writeln('Loading ${inputFileName}...');
  final csvContents = File(inputFileName).readAsStringSync();
  final rows = CsvToListConverter(shouldParseNumbers: false, allowInvalid: false, eol: '\n').convert(csvContents);

  stderr.writeln('Generating code...');
  final header = rows.first;
  final languageCodes = header.skip(2).map((dynamic cell) => cell as String).toList();
  assert(languageCodes.isNotEmpty);
  assert(languageCodes.length == languageCodes.toSet().length);
  final defaultLanguageCode = languageCodes.first;

  final baseLanguageCodes = <String, String>{
    for (final languageCode in languageCodes) languageCode: languageCodes.firstWhere(
      (other) => languageCode.startsWith(other) && languageCode.length > other.length,
      orElse: () => languageCodes[0],
    ),
  };

  final abstractBaseClass = Class(name: baseName, isAbstract: true);
  abstractBaseClass.methods.add(Method(
    documentation: 'Returns a concrete Strings implementation based on the current locale derived from the context.',
    signature: MethodSignature(
    isStatic: true,
    returnType: baseName,
    name: 'of',
    parameters: [Parameter('BuildContext', 'context')]),
        body: ExpressionBody('Localizations.of<${baseName}>(context, ${baseName})'),
  ));
  final languageClasses = languageCodes
      .map((languageCode) => Class(
        name: '${baseName}_${languageCode}',
        baseClassName: languageCode == defaultLanguageCode ? baseName : '${baseName}_${baseLanguageCodes[languageCode]}'))
      .toList();
  final keys = <String>[];

  for (final row in rows.sublist(1)) {
    assert(row.length == header.length);
    final key = row[0] as String;
    final description = row[1] as String;
    final translations = row.sublist(2)
        .map((dynamic cell) => Translation.fromString(cell as String))
        .toList();
    assert(_isValidDartIdentifier(key));
    keys.add(key);

    final variables = <VariablePart>[];
    for (final translation in translations) {
      variables.addAll(translation.variables);
    }
    final variableTypes = <String, VariableType>{};
    for (final variable in variables) {
      final existingType = variableTypes[variable.name];
      if (existingType != null) {
        assert(variable.type == existingType);
      } else {
        variableTypes[variable.name] = variable.type;
      }
    }
    final parameters = variableTypes.entries.map((entry) => Parameter(_typeToDart(entry.value), entry.key)).toList();

    final methodSignature = MethodSignature(
        returnType: 'String',
        isGetter: parameters.isEmpty,
        name: key,
        parameters: parameters);
    abstractBaseClass.methods.add(Method(
        documentation: description,
        signature: methodSignature,
        isOverride: false));

    for (var i = 0; i < languageCodes.length; i++) {
      final languageCode = languageCodes[i];
      final translation = translations[i];
      if (translation.isFallback) {
        assert(languageCode != defaultLanguageCode);
        continue;
      }

      final unusedParameters = methodSignature.parameters.map((parameter) => parameter.name).toSet();
      unusedParameters.removeAll(translation.parts.whereType<VariablePart>().map((variable) => variable.name));
      if (unusedParameters.isNotEmpty) {
        stderr.writeln('Warning: ${languageCode} translation for ${key} does not use variables ${unusedParameters.join(', ')}');
      }
      
      languageClasses[i].methods.add(Method(
          signature: methodSignature,
          body: translation.toMethodBody(),
          isOverride: true));
    }
  }

  abstractBaseClass.methods.add(Method(
    documentation:
      'Returns the translation for the given key.\n'
      'For translations without arguments, returns a `String`.\n'
      'For translations with arguments, returns a `String Function(...)`.'
      'Returns `null` if the key was not found.',
    signature: MethodSignature(
      returnType: 'dynamic',
      name: 'operator []',
      parameters: <Parameter>[Parameter('String', 'key')],
    ),
    body: BlockBody(<String>[
      'switch (key) {',
      for (final key in keys) "  case '${key}': return ${key};",
      '}',
      'return null;',
    ]),
  ));

  stderr.writeln('Writing output to ${outputFileName}...');
  final output = File(outputFileName).openWrite();
  output.write('''
/// Translations from ${inputFileName}. AUTOGENERATED, DO NOT EDIT!
/// To make changes to this file, edit ${inputFileName}
/// and run `flutter pub run bin/generate_translations`.

import 'package:flutter/widgets.dart';

'''.trimLeft());
  output.writeln(abstractBaseClass.toDartCode());
  for (final languageClass in languageClasses) {
    output.writeln('');
    output.writeln(languageClass.toDartCode());
  }
  output.close();
}

class Class {
  final String documentation;
  final bool isAbstract;
  final String name;
  final String baseClassName;
  
  final methods = <Method>[];
  
  Class({this.documentation, @required this.name, this.baseClassName, this.isAbstract = false}) :
    assert(name != null);
  
  String toDartCode() {
    return <String>[
      if (documentation != null) for (final line in documentation.split('\n')) '/// ${line}\n',
      if (isAbstract) 'abstract ',
      'class ',
      name,
      if (baseClassName != null) ' extends ${baseClassName}',
      ' {\n',
      ...methods.map((method) => method.toDartCode() + '\n'),
      '}',
    ].join();
  }
}

class MethodSignature {
  final bool isStatic;
  final bool isGetter;
  final String returnType;
  final String name;
  final List<Parameter> parameters;

  MethodSignature({this.isStatic = false, @required this.returnType, this.isGetter = false, @required this.name, this.parameters = const <Parameter>[]}) :
    assert(returnType != null),
    assert(!isGetter || parameters.isEmpty);

  String toDartCode() {
    return <String>[
      if (isStatic) 'static ',
      returnType,
      ' ',
      if (isGetter) 'get ',
      name,
      if (!isGetter) '(${parameters.map((variable) => variable.toDartParameter()).join(', ')})',
    ].join();
  }
}

class Parameter {
  final String name;
  final String type;

  Parameter(this.type, this.name) :
    assert(_isValidDartIdentifier(name)),
    assert(type != null);

  String toDartParameter() {
    return '${type} ${name}';
  }
}

class Method {
  final String documentation;
  final bool isOverride;
  final MethodSignature signature;
  final MethodBody body;

  Method({this.documentation, @required this.signature, this.body, this.isOverride = false});

  String toDartCode() {
    return <String>[
      if (documentation != null) for (final line in documentation.split('\n')) '  /// ${line}\n',
      '  ',
      if (isOverride) '@override ',
      signature.toDartCode(),
      if (body != null) body.toDartCode(),
      if (body == null) ';',
    ].join();
  }
}

abstract class MethodBody {
  String toDartCode();
}

class ExpressionBody implements MethodBody {
  final String expression;

  ExpressionBody(this.expression);

  @override
  String toDartCode() => ' => ${expression};';
}

class BlockBody implements MethodBody {
  final List<String> lines;

  BlockBody(this.lines);

  @override
  String toDartCode() => <String>[
    '{',
    for (final line in lines) '    ${line}',
    '  }',
  ].join('\n');
}

class Translation {
  static final _placeholderRegexp = RegExp(r'([#$])\{(.*?)\}');

  final List<TranslationPart> parts;

  Translation._internal(this.parts);

  factory Translation.fromString(String string) {
    final parts = <TranslationPart>[];
    var currentIndex = 0;
    for (final match in _placeholderRegexp.allMatches(string)) {
      if (match.start > currentIndex) {
        parts.add(TextPart(string.substring(currentIndex, match.start)));
      }
      final type = _typeFromChar(match.group(1));
      final name = match.group(2);
      parts.add(VariablePart(name, type));
      currentIndex = match.end;
    }
    if (currentIndex < string.length) {
      parts.add(TextPart(string.substring(currentIndex, string.length)));
    }
    return Translation._internal(parts);
  }

  bool get isFallback => parts.isEmpty;

  Set<VariablePart> get variables => parts.whereType<VariablePart>().toSet();

  MethodBody toMethodBody() {
    assert(!isFallback);
    if (parts.length == 1) {
      return ExpressionBody(parts.single.toDartExpression());
    } else {
      return ExpressionBody('<String>[${parts.map((part) => part.toDartExpression()).join(', ')}].join()');
    }
  }

  static VariableType _typeFromChar(String char) {
    switch (char) {
      case '\$': return VariableType.string;
      case '#': return VariableType.int;
    }
    assert(false);
    return null;
  }
}

abstract class TranslationPart {
  String toDartExpression();
}

class TextPart implements TranslationPart {
  final String text;

  TextPart(this.text);

  @override
  String toDartExpression() => _escapeDartString(text);
}

enum VariableType {
  string,
  int,
}

String _typeToDart(VariableType type) {
  switch (type) {
    case VariableType.int: return 'int';
    case VariableType.string: return 'String';
  }
  assert(false);
  return ''; // Should not happen, but the analyzer doesn't know that.
}

class VariablePart implements TranslationPart {
  final String name;
  final VariableType type;

  VariablePart(this.name, this.type) :
    assert(_isValidDartIdentifier(name));

  @override
  String toDartExpression() {
    switch (type) {
      case VariableType.string: return name;
      case VariableType.int: return '${name}.toString()';
    }
    assert(false);
    return '';
  }
}

final _identifierRegexp = RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$');

bool _isValidDartIdentifier(String string) => _identifierRegexp.hasMatch(string);

const _escapeMap = {
  '\n': r'\n',
  '\r': r'\r',
  '\f': r'\f',
  '\b': r'\b',
  '\t': r'\t',
  '\v': r'\v',
  '\x7F': r'\x7F', // delete
};

final _escapeRegExp = RegExp('[\\x00-\\x07\\x0E-\\x1F${_escapeMap.keys.map(_getHexLiteral).join()}]');

String _escapeDartString(String string) {
  final escapedString = string
      .replaceAll(r'\', r'\\')
      .replaceAllMapped(_escapeRegExp, (match) {
        var mapped = _escapeMap[match[0]];
        if (mapped != null) return mapped;
        return _getHexLiteral(match[0]);
      });
  return "'${escapedString}'";
}

String _getHexLiteral(String input) {
  var rune = input.runes.single;
  return r'\x' + rune.toRadixString(16).toUpperCase().padLeft(2, '0');
}