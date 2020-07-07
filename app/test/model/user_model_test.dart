import 'package:flutter_test/flutter_test.dart';
import 'package:papageno/model/user_model.dart';

void main() {
  group('encoding and decoding', () {
    group('encodeSpeciesIdList and decodeSpeciesIdList', () {
      for (final speciesIds in <List<int>>[
        [],
        [0],
        [1],
        [0xff],
        [0x100],
        [0x7fff],
        [0x8000],
        [0xffff],
        [47764, 18734, 837, 72, 1817],
      ]) {
        test(speciesIds.toString(), () {
          expect(decodeSpeciesIdList(encodeSpeciesIdList(speciesIds)), speciesIds);
        });
      }
    });
  });
}