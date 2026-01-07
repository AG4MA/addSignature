import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:sign_stamp/features/editor/data/models/project_model.dart';
import 'package:sign_stamp/features/signature/data/models/signature_model.dart';

void main() {
  group('ProjectModel', () {
    final testProject = ProjectModel(
      id: 'project-id',
      name: 'Test Project',
      documentPath: '/path/to/document.png',
      documentType: DocumentType.image,
      signatureId: 'sig-id',
      signatureTransform: const SignatureTransform(
        translateX: 100,
        translateY: 200,
        rotation: 0.5,
        scale: 1.5,
      ),
      signatureColorMode: SignatureColorMode.original,
      signatureOpacity: 0.8,
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 2),
      isDraft: true,
    );

    group('constructor', () {
      test('creates instance with all parameters', () {
        expect(testProject.id, equals('project-id'));
        expect(testProject.name, equals('Test Project'));
        expect(testProject.documentPath, equals('/path/to/document.png'));
        expect(testProject.documentType, equals(DocumentType.image));
        expect(testProject.signatureId, equals('sig-id'));
        expect(testProject.signatureOpacity, equals(0.8));
        expect(testProject.isDraft, isTrue);
      });

      test('creates instance with minimal parameters', () {
        final minimal = ProjectModel(
          id: 'min-id',
          name: 'Minimal',
          documentPath: '/doc.png',
          documentType: DocumentType.image,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(minimal.signatureId, isNull);
        expect(minimal.signatureTransform, isNull);
        expect(minimal.signatureOpacity, equals(1.0));
        expect(minimal.isDraft, isTrue);
      });
    });

    group('copyWith', () {
      test('creates copy with changed values', () {
        final copy = testProject.copyWith(
          name: 'Updated Project',
          isDraft: false,
        );

        expect(copy.id, equals(testProject.id));
        expect(copy.name, equals('Updated Project'));
        expect(copy.isDraft, isFalse);
        expect(copy.documentPath, equals(testProject.documentPath));
      });

      test('creates copy with new signature transform', () {
        final newTransform = const SignatureTransform(
          translateX: 50,
          translateY: 50,
          rotation: 0,
          scale: 1,
        );

        final copy = testProject.copyWith(signatureTransform: newTransform);

        expect(copy.signatureTransform?.translateX, equals(50));
        expect(copy.signatureTransform?.translateY, equals(50));
      });
    });

    group('JSON serialization', () {
      test('toJson creates correct map', () {
        final json = testProject.toJson();

        expect(json['id'], equals('project-id'));
        expect(json['name'], equals('Test Project'));
        expect(json['documentPath'], equals('/path/to/document.png'));
        expect(json['documentType'], equals('image'));
        expect(json['signatureId'], equals('sig-id'));
        expect(json['signatureOpacity'], equals(0.8));
        expect(json['signatureColorMode'], equals('original'));
        expect(json['isDraft'], isTrue);
        expect(json['signatureTransform'], isNotNull);
      });

      test('fromJson creates correct instance', () {
        final json = {
          'id': 'json-project',
          'name': 'JSON Project',
          'documentPath': '/json/doc.pdf',
          'documentType': 'pdf',
          'pdfPageIndex': 2,
          'signatureId': 'json-sig',
          'signatureTransform': {
            'translateX': 150.0,
            'translateY': 250.0,
            'rotation': 1.0,
            'scale': 2.0,
          },
          'signatureColorMode': 'blackAndWhite',
          'signatureOpacity': 0.5,
          'createdAt': '2024-03-01T00:00:00.000',
          'updatedAt': '2024-03-02T00:00:00.000',
          'isDraft': false,
        };

        final project = ProjectModel.fromJson(json);

        expect(project.id, equals('json-project'));
        expect(project.documentType, equals(DocumentType.pdf));
        expect(project.pdfPageIndex, equals(2));
        expect(project.signatureColorMode, equals(SignatureColorMode.blackAndWhite));
        expect(project.signatureOpacity, equals(0.5));
        expect(project.isDraft, isFalse);
        expect(project.signatureTransform?.translateX, equals(150.0));
      });

      test('round-trip serialization preserves data', () {
        final json = testProject.toJson();
        final restored = ProjectModel.fromJson(json);

        expect(restored.id, equals(testProject.id));
        expect(restored.name, equals(testProject.name));
        expect(restored.documentType, equals(testProject.documentType));
        expect(restored.signatureOpacity, equals(testProject.signatureOpacity));
      });
    });
  });

  group('SignatureTransform', () {
    group('constructor', () {
      test('creates with default values', () {
        const transform = SignatureTransform();

        expect(transform.translateX, equals(0));
        expect(transform.translateY, equals(0));
        expect(transform.rotation, equals(0));
        expect(transform.scale, equals(1.0));
      });

      test('creates with custom values', () {
        const transform = SignatureTransform(
          translateX: 100,
          translateY: 200,
          rotation: 1.5,
          scale: 2.0,
        );

        expect(transform.translateX, equals(100));
        expect(transform.translateY, equals(200));
        expect(transform.rotation, equals(1.5));
        expect(transform.scale, equals(2.0));
      });

      test('translation getter returns correct offset', () {
        const transform = SignatureTransform(
          translateX: 50,
          translateY: 75,
        );

        expect(transform.translation, equals(const Offset(50, 75)));
      });
    });

    group('identity', () {
      test('identity has default values', () {
        expect(SignatureTransform.identity.translateX, equals(0));
        expect(SignatureTransform.identity.translateY, equals(0));
        expect(SignatureTransform.identity.rotation, equals(0));
        expect(SignatureTransform.identity.scale, equals(1.0));
      });
    });

    group('copyWith', () {
      test('creates copy with changed values', () {
        const original = SignatureTransform(
          translateX: 10,
          translateY: 20,
          rotation: 0.5,
          scale: 1.5,
        );

        final copy = original.copyWith(
          translateX: 30,
          scale: 2.0,
        );

        expect(copy.translateX, equals(30));
        expect(copy.translateY, equals(20));
        expect(copy.rotation, equals(0.5));
        expect(copy.scale, equals(2.0));
      });
    });

    group('JSON serialization', () {
      test('toJson creates correct map', () {
        const transform = SignatureTransform(
          translateX: 100,
          translateY: 200,
          rotation: 0.785,
          scale: 1.25,
        );

        final json = transform.toJson();

        expect(json['translateX'], equals(100));
        expect(json['translateY'], equals(200));
        expect(json['rotation'], equals(0.785));
        expect(json['scale'], equals(1.25));
      });

      test('fromJson creates correct instance', () {
        final json = {
          'translateX': 50.5,
          'translateY': 75.5,
          'rotation': 1.0,
          'scale': 0.5,
        };

        final transform = SignatureTransform.fromJson(json);

        expect(transform.translateX, equals(50.5));
        expect(transform.translateY, equals(75.5));
        expect(transform.rotation, equals(1.0));
        expect(transform.scale, equals(0.5));
      });

      test('round-trip serialization preserves data', () {
        const original = SignatureTransform(
          translateX: 123.456,
          translateY: 789.012,
          rotation: 3.14159,
          scale: 2.71828,
        );

        final json = original.toJson();
        final restored = SignatureTransform.fromJson(json);

        expect(restored.translateX, equals(original.translateX));
        expect(restored.translateY, equals(original.translateY));
        expect(restored.rotation, equals(original.rotation));
        expect(restored.scale, equals(original.scale));
      });
    });
  });

  group('DocumentType', () {
    test('has correct values', () {
      expect(DocumentType.values.length, equals(2));
      expect(DocumentType.image.name, equals('image'));
      expect(DocumentType.pdf.name, equals('pdf'));
    });
  });
}
