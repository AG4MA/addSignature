import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:sign_stamp/features/signature/data/models/signature_model.dart';

void main() {
  group('SignatureModel', () {
    final testSignature = SignatureModel(
      id: 'test-id',
      name: 'Test Signature',
      imagePath: '/path/to/signature.png',
      colorValue: 0xFF000000,
      createdAt: DateTime(2024, 1, 1, 12, 0, 0),
      updatedAt: DateTime(2024, 1, 2, 12, 0, 0),
    );

    group('constructor', () {
      test('creates instance with required parameters', () {
        expect(testSignature.id, equals('test-id'));
        expect(testSignature.name, equals('Test Signature'));
        expect(testSignature.imagePath, equals('/path/to/signature.png'));
        expect(testSignature.colorValue, equals(0xFF000000));
      });

      test('color getter returns correct color', () {
        expect(testSignature.color, equals(const Color(0xFF000000)));
      });
    });

    group('copyWith', () {
      test('creates copy with changed name', () {
        final copy = testSignature.copyWith(name: 'New Name');

        expect(copy.id, equals(testSignature.id));
        expect(copy.name, equals('New Name'));
        expect(copy.imagePath, equals(testSignature.imagePath));
      });

      test('creates copy with changed color', () {
        final copy = testSignature.copyWith(colorValue: 0xFFFF0000);

        expect(copy.colorValue, equals(0xFFFF0000));
        expect(copy.color, equals(const Color(0xFFFF0000)));
      });

      test('creates exact copy when no parameters provided', () {
        final copy = testSignature.copyWith();

        expect(copy.id, equals(testSignature.id));
        expect(copy.name, equals(testSignature.name));
        expect(copy.imagePath, equals(testSignature.imagePath));
        expect(copy.colorValue, equals(testSignature.colorValue));
      });
    });

    group('JSON serialization', () {
      test('toJson creates correct map', () {
        final json = testSignature.toJson();

        expect(json['id'], equals('test-id'));
        expect(json['name'], equals('Test Signature'));
        expect(json['imagePath'], equals('/path/to/signature.png'));
        expect(json['colorValue'], equals(0xFF000000));
        expect(json['createdAt'], equals('2024-01-01T12:00:00.000'));
        expect(json['updatedAt'], equals('2024-01-02T12:00:00.000'));
      });

      test('fromJson creates correct instance', () {
        final json = {
          'id': 'json-id',
          'name': 'JSON Signature',
          'imagePath': '/json/path.png',
          'colorValue': 0xFFFF0000,
          'createdAt': '2024-06-01T10:00:00.000',
          'updatedAt': '2024-06-02T10:00:00.000',
        };

        final signature = SignatureModel.fromJson(json);

        expect(signature.id, equals('json-id'));
        expect(signature.name, equals('JSON Signature'));
        expect(signature.imagePath, equals('/json/path.png'));
        expect(signature.colorValue, equals(0xFFFF0000));
        expect(signature.createdAt, equals(DateTime(2024, 6, 1, 10, 0, 0)));
        expect(signature.updatedAt, equals(DateTime(2024, 6, 2, 10, 0, 0)));
      });

      test('round-trip serialization preserves data', () {
        final json = testSignature.toJson();
        final restored = SignatureModel.fromJson(json);

        expect(restored.id, equals(testSignature.id));
        expect(restored.name, equals(testSignature.name));
        expect(restored.imagePath, equals(testSignature.imagePath));
        expect(restored.colorValue, equals(testSignature.colorValue));
      });
    });

    group('equality', () {
      test('signatures with same id are equal', () {
        final sig1 = SignatureModel(
          id: 'same-id',
          name: 'Name 1',
          imagePath: '/path1.png',
          colorValue: 0xFF000000,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final sig2 = SignatureModel(
          id: 'same-id',
          name: 'Name 2',
          imagePath: '/path2.png',
          colorValue: 0xFFFFFFFF,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(sig1 == sig2, isTrue);
        expect(sig1.hashCode, equals(sig2.hashCode));
      });

      test('signatures with different ids are not equal', () {
        final sig1 = SignatureModel(
          id: 'id-1',
          name: 'Same Name',
          imagePath: '/same/path.png',
          colorValue: 0xFF000000,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final sig2 = SignatureModel(
          id: 'id-2',
          name: 'Same Name',
          imagePath: '/same/path.png',
          colorValue: 0xFF000000,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(sig1 == sig2, isFalse);
      });
    });
  });

  group('SignatureColorMode', () {
    test('has correct values', () {
      expect(SignatureColorMode.values.length, equals(2));
      expect(SignatureColorMode.original.index, equals(0));
      expect(SignatureColorMode.blackAndWhite.index, equals(1));
    });
  });
}
