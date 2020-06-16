/// Unit tests for `ebisu.dart`.
///
/// Ported from the Java implementation:
/// https://github.com/fasiha/ebisu-java/blob/master/src/test/java/me/aldebrn/ebisu/EbisuTest.java

import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:papageno/ebisu/ebisu.dart';
import 'package:papageno/ebisu/math.dart';

import 'ulp.dart';

/// Test cases, taken from the Python version of Ebisu.
const _testJson = '[["update", [3.3, 4.4, 1.0], [0, 5, 0.1], {"post": [7.333641958415551, 8.949256654818793, 0.4148304099305316]}], ["update", [3.3, 4.4, 1.0], [1, 5, 0.1], {"post": [7.921333234538209, 7.986078907729781, 0.4148304099305316]}], ["update", [3.3, 4.4, 1.0], [2, 5, 0.1], {"post": [8.54115608235795, 7.039810875112419, 0.4148304099305316]}], ["update", [3.3, 4.4, 1.0], [3, 5, 0.1], {"post": [9.19263541257189, 6.102814088801724, 0.4148304099305316]}], ["update", [3.3, 4.4, 1.0], [4, 5, 0.1], {"post": [3.392668219154276, 5.479702779318754, 1.0]}], ["update", [3.3, 4.4, 1.0], [5, 5, 0.1], {"post": [3.7999999999999674, 4.399999999999965, 1.0]}], ["update", [3.3, 4.4, 1.0], [0, 5, 1.0], {"post": [10.42314781200118, 8.313283751698094, 0.4148304099305316]}], ["update", [3.3, 4.4, 1.0], [1, 5, 1.0], {"post": [4.300000000004559, 8.400000000008617, 1.0]}], ["update", [3.3, 4.4, 1.0], [2, 5, 1.0], {"post": [5.299999999994806, 7.399999999993122, 1.0]}], ["update", [3.3, 4.4, 1.0], [3, 5, 1.0], {"post": [6.300000000003196, 6.400000000002965, 1.0]}], ["update", [3.3, 4.4, 1.0], [4, 5, 1.0], {"post": [7.29999999999964, 5.3999999999998245, 1.0]}], ["update", [3.3, 4.4, 1.0], [5, 5, 1.0], {"post": [8.299999999999644, 4.3999999999998165, 1.0]}], ["update", [3.3, 4.4, 1.0], [0, 5, 9.5], {"post": [3.5601980922377012, 4.953347976808389, 1.0]}], ["update", [3.3, 4.4, 1.0], [1, 5, 9.5], {"post": [4.059118901399234, 6.956645983861514, 3.0652051705190964]}], ["update", [3.3, 4.4, 1.0], [2, 5, 9.5], {"post": [7.352444943202578, 6.778702354841638, 3.0652051705190964]}], ["update", [3.3, 4.4, 1.0], [3, 5, 9.5], {"post": [2.92509341822776, 6.744103533623485, 8.33209151552077]}], ["update", [3.3, 4.4, 1.0], [4, 5, 9.5], {"post": [3.942742342008821, 5.609521448770878, 8.33209151552077]}], ["update", [3.3, 4.4, 1.0], [5, 5, 9.5], {"post": [4.960598139318119, 4.5269207284344954, 8.33209151552077]}], ["update", [34.4, 3.4, 1.0], [0, 5, 0.1], {"post": [8.760308130181903, 8.706432410647471, 3.0652051705190964]}], ["update", [34.4, 3.4, 1.0], [1, 5, 0.1], {"post": [9.10166480676482, 7.599773940410919, 3.0652051705190964]}], ["update", [34.4, 3.4, 1.0], [2, 5, 0.1], {"post": [9.470767961549766, 6.526756194178172, 3.0652051705190964]}], ["update", [34.4, 3.4, 1.0], [3, 5, 0.1], {"post": [2.8193081340183848, 5.8660071644208225, 8.33209151552077]}], ["update", [34.4, 3.4, 1.0], [4, 5, 0.1], {"post": [3.099708783386964, 4.6435435843774, 8.33209151552077]}], ["update", [34.4, 3.4, 1.0], [5, 5, 0.1], {"post": [3.414956576256669, 3.5065282010435452, 8.33209151552077]}], ["update", [34.4, 3.4, 1.0], [0, 5, 1.0], {"post": [9.39628482629719, 8.646019197616297, 3.0652051705190964]}], ["update", [34.4, 3.4, 1.0], [1, 5, 1.0], {"post": [9.911175851781708, 7.562783988233255, 3.0652051705190964]}], ["update", [34.4, 3.4, 1.0], [2, 5, 1.0], {"post": [10.44361446625134, 6.501799830801661, 3.0652051705190964]}], ["update", [34.4, 3.4, 1.0], [3, 5, 1.0], {"post": [3.2044869706691466, 5.7934965103790335, 8.33209151552077]}], ["update", [34.4, 3.4, 1.0], [4, 5, 1.0], {"post": [3.55036687026256, 4.602501903233139, 8.33209151552077]}], ["update", [34.4, 3.4, 1.0], [5, 5, 1.0], {"post": [3.9320618448872042, 3.487419813549091, 8.33209151552077]}], ["update", [34.4, 3.4, 1.0], [0, 5, 5.5], {"post": [11.673894526689034, 8.19258414278996, 3.0652051705190964]}], ["update", [34.4, 3.4, 1.0], [1, 5, 5.5], {"post": [3.769629060906505, 7.893196309207965, 8.33209151552077]}], ["update", [34.4, 3.4, 1.0], [2, 5, 5.5], {"post": [4.431262591926502, 6.693721383041708, 8.33209151552077]}], ["update", [34.4, 3.4, 1.0], [3, 5, 5.5], {"post": [5.117097117261679, 5.5661761667158896, 8.33209151552077]}], ["update", [34.4, 3.4, 1.0], [4, 5, 5.5], {"post": [5.8261655907057435, 4.48706762922024, 8.33209151552077]}], ["update", [34.4, 3.4, 1.0], [5, 5, 5.5], {"post": [1.9697726778066604, 3.6196824722158882, 22.648972959697893]}], ["update", [34.4, 3.4, 1.0], [0, 5, 50.0], {"post": [4.078371066588873, 5.099824929325114, 8.33209151552077]}], ["update", [34.4, 3.4, 1.0], [1, 5, 50.0], {"post": [3.4468346321124614, 6.580022257121179, 22.648972959697893]}], ["update", [34.4, 3.4, 1.0], [2, 5, 50.0], {"post": [5.698262778324584, 6.066639134278961, 22.648972959697893]}], ["update", [34.4, 3.4, 1.0], [3, 5, 50.0], {"post": [7.78211003232517, 5.2894146486836915, 22.648972959697893]}], ["update", [34.4, 3.4, 1.0], [4, 5, 50.0], {"post": [2.927115520019575, 4.610159065548562, 61.566291629607065]}], ["update", [34.4, 3.4, 1.0], [5, 5, 50.0], {"post": [3.711551159097705, 3.496333137758124, 61.566291629607065]}], ["predict", [3.3, 4.4, 1.0], [0.1], {"mean": 0.9112400768028355}], ["predict", [3.3, 4.4, 1.0], [0.99], {"mean": 0.43187379980345186}], ["predict", [3.3, 4.4, 1.0], [1.0], {"mean": 0.4285714285714294}], ["predict", [3.3, 4.4, 1.0], [1.01], {"mean": 0.4253002580752596}], ["predict", [3.3, 4.4, 1.0], [5.5], {"mean": 0.034193559924496846}], ["predict", [34.4, 34.4, 1.0], [0.1], {"mean": 0.9324193906545447}], ["predict", [34.4, 34.4, 1.0], [0.99], {"mean": 0.5034418103093425}], ["predict", [34.4, 34.4, 1.0], [1.0], {"mean": 0.5000000000000027}], ["predict", [34.4, 34.4, 1.0], [1.01], {"mean": 0.4965824260522384}], ["predict", [34.4, 34.4, 1.0], [5.5], {"mean": 0.026134289032202798}]]';

void main() {
  final eps = 2.0 * ulp(1.0);

  test('ulp', () {
    final ulp1 = ulp(1.0);
    expect(ulp1, greaterThan(0.0));
    expect(1.0 + ulp1, greaterThan(1.0));
    expect(1.0 + ulp1 / 2.0, 1.0);
  });

  group('compare against test.json from reference implementation', () {
    final maxTol = 5e-3;
    final json = jsonDecode(_testJson) as List<dynamic>;
    for (final i in json) {
      final testCase = i as List<dynamic>;
      final description = jsonEncode(testCase.sublist(0, 3));
      final ebisu = parseModel(testCase[1]);
      switch (testCase[0] as String) {
        case 'update':
          test(description, () {
            final successes = (testCase[2] as List<dynamic>)[0] as int;
            final total = (testCase[2] as List<dynamic>)[1] as int;
            final tNow = (testCase[2] as List<dynamic>)[2] as double;
            final expected = parseModel((testCase[3] as Map<String, dynamic>)['post']);

            final actual = ebisu.updateRecall(successes, total, tNow);

            expect(actual.alpha, closeTo(expected.alpha, maxTol));
            expect(actual.beta, closeTo(expected.beta, maxTol));
            expect(actual.time, closeTo(expected.time, maxTol));
          });
          break;

        case 'predict':
          test(description, () {
            final tNow = (testCase[2] as List<dynamic>)[0] as double;
            final expected = (testCase[3] as Map<String, dynamic>)['mean'] as double;

            final actual = ebisu.predictRecall(tNow, exact: true);

            expect(actual, closeTo(expected, maxTol));
          });
          break;

        default:
          assert(false);
      }
    }
  });

  test('verify halflife', () {
    final hl = 20.0;
    final m = EbisuModel(time: hl, alpha: 2.0, beta: 2.0);
    expect((m.modelToPercentileDecay(percentile: 0.5, coarse: true) - hl).abs(), greaterThan(1e-2));
    expect(relerr(m.modelToPercentileDecay(percentile: 0.5, tolerance: 1e-6), hl), lessThan(1e-3));
    expect(() => m.modelToPercentileDecay(percentile: 0.5, tolerance: 1e-150), throwsA(isA<AssertionError>()));
  });

  test('Ebisu predict at exactly half-life', () {
    final m = EbisuModel(time: 2.0, alpha: 2.0, beta: 2.0);
    final p = m.predictRecall(2, exact: true);
    expect(p, closeTo(0.5, eps));
  });

  test('Ebisu update at exactly half-life', () {
    final m = EbisuModel(time: 2.0, alpha: 2.0, beta: 2.0);
    final success = m.updateRecall(1, 1, 2.0);
    final failure = m.updateRecall(0, 1, 2.0);

    expect(success.alpha, closeTo(3.0, 500 * eps));
    expect(success.beta, closeTo(2.0, 500 * eps));

    expect(failure.alpha, closeTo(2.0, 500 * eps));
    expect(failure.beta, closeTo(3.0, 500 * eps));
  });

  test('Check logSumExp', () {
    final expected = exp(3.3) + exp(4.4) - exp(5.5);
    final actual = logSumExp([3.3, 4.4, 5.5], [1, 1, -1]);

    final epsilon = ulp(actual);
    expect(actual, closeTo(log(expected.abs()), epsilon));
    // expect(actual[1], signum(expected));
  });
}

EbisuModel parseModel(dynamic params) {
  final doubles = params as List<dynamic>;
  assert(doubles.length == 3);
  return EbisuModel(alpha: params[0] as double, beta: params[1] as double, time: params[2] as double);
}

double relerr(double dirt, double gold) {
  return (dirt == gold) ? 0 : (dirt - gold).abs() / gold.abs();
}