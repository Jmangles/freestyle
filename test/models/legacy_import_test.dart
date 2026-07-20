import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:freestyle_highline/models/legacy_import.dart';
import 'package:freestyle_highline/models/user_trick.dart';

void main() {
  group('legacy stickFrequency -> Consistency', () {
    test('maps every legacy level, folding Rarely into Sometimes', () {
      expect(consistencyFromStickFrequency(0), Consistency.neverTried);
      expect(consistencyFromStickFrequency(1), Consistency.attempting);
      expect(consistencyFromStickFrequency(2), Consistency.once);
      expect(consistencyFromStickFrequency(3), Consistency.sometimes); // Rarely
      expect(consistencyFromStickFrequency(4), Consistency.sometimes);
      expect(consistencyFromStickFrequency(5), Consistency.often);
      expect(consistencyFromStickFrequency(6), Consistency.generally);
      expect(consistencyFromStickFrequency(7), Consistency.always);
    });

    test('clamps values outside the legacy enum', () {
      expect(consistencyFromStickFrequency(-1), Consistency.neverTried);
      expect(consistencyFromStickFrequency(8), Consistency.neverTried);
      expect(consistencyFromStickFrequency(999), Consistency.neverTried);
    });

    test('never produces a consistency the DB constraint rejects', () {
      for (final index in legacyConsistencyByStickFrequency) {
        expect(index, inInclusiveRange(0, 6));
      }
    });
  });

  group('bundled trick id map', () {
    test('matches the generated CSV', () {
      final json = jsonDecode(
              File('assets/legacy/trick_id_map.json').readAsStringSync())
          as Map<String, dynamic>;
      final csv = File('docs/legacy-migration/trick_id_map.csv')
          .readAsLinesSync()
          .skip(1)
          .where((line) => line.trim().isNotEmpty);

      final fromCsv = {
        for (final line in csv)
          line.split(',')[0]: int.parse(line.split(',')[1]),
      };
      expect(json.map((k, v) => MapEntry(k, v as int)), fromCsv);
    });

    test('has no legacy id below the predefined range and no duplicates', () {
      final json = jsonDecode(
              File('assets/legacy/trick_id_map.json').readAsStringSync())
          as Map<String, dynamic>;
      expect(json.keys.every((k) => int.parse(k) >= 10000), isTrue);
      expect(json.values.toSet().length, json.length);
    });
  });
}
