import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:sign_stamp/core/utils/transform_utils.dart';

void main() {
  group('TransformUtils', () {
    group('createMatrix', () {
      test('creates identity matrix with default values', () {
        final matrix = TransformUtils.createMatrix(
          translation: Offset.zero,
          rotation: 0,
          scale: 1,
        );

        expect(TransformUtils.getTranslation(matrix), equals(Offset.zero));
        expect(TransformUtils.getRotation(matrix), closeTo(0, 0.001));
        expect(TransformUtils.getScale(matrix), closeTo(1, 0.001));
      });

      test('applies translation correctly', () {
        final matrix = TransformUtils.createMatrix(
          translation: const Offset(100, 200),
          rotation: 0,
          scale: 1,
        );

        final translation = TransformUtils.getTranslation(matrix);
        expect(translation.dx, closeTo(100, 0.001));
        expect(translation.dy, closeTo(200, 0.001));
      });

      test('applies scale correctly', () {
        final matrix = TransformUtils.createMatrix(
          translation: Offset.zero,
          rotation: 0,
          scale: 2.5,
        );

        expect(TransformUtils.getScale(matrix), closeTo(2.5, 0.001));
      });

      test('applies rotation correctly', () {
        final matrix = TransformUtils.createMatrix(
          translation: Offset.zero,
          rotation: 1.57, // ~90 degrees
          scale: 1,
        );

        expect(TransformUtils.getRotation(matrix), closeTo(1.57, 0.01));
      });
    });

    group('transformPoint', () {
      test('translates point correctly', () {
        final matrix = TransformUtils.createMatrix(
          translation: const Offset(50, 100),
          rotation: 0,
          scale: 1,
        );

        final result = TransformUtils.transformPoint(matrix, const Offset(10, 20));
        expect(result.dx, closeTo(60, 0.001));
        expect(result.dy, closeTo(120, 0.001));
      });

      test('scales point from origin', () {
        final matrix = TransformUtils.createMatrix(
          translation: Offset.zero,
          rotation: 0,
          scale: 2,
        );

        final result = TransformUtils.transformPoint(matrix, const Offset(10, 20));
        expect(result.dx, closeTo(20, 0.001));
        expect(result.dy, closeTo(40, 0.001));
      });
    });

    group('transformBounds', () {
      test('calculates bounds after translation', () {
        final matrix = TransformUtils.createMatrix(
          translation: const Offset(100, 100),
          rotation: 0,
          scale: 1,
        );

        final bounds = Rect.fromLTWH(0, 0, 50, 50);
        final result = TransformUtils.transformBounds(matrix, bounds);

        expect(result.left, closeTo(100, 0.001));
        expect(result.top, closeTo(100, 0.001));
        expect(result.right, closeTo(150, 0.001));
        expect(result.bottom, closeTo(150, 0.001));
      });

      test('calculates bounds after scale', () {
        final matrix = TransformUtils.createMatrix(
          translation: Offset.zero,
          rotation: 0,
          scale: 2,
        );

        final bounds = Rect.fromLTWH(0, 0, 50, 50);
        final result = TransformUtils.transformBounds(matrix, bounds);

        expect(result.width, closeTo(100, 0.001));
        expect(result.height, closeTo(100, 0.001));
      });
    });

    group('constrainToContainer', () {
      test('returns zero offset when bounds are inside container', () {
        final bounds = const Rect.fromLTWH(50, 50, 100, 100);
        final containerSize = const Size(300, 300);

        final offset = TransformUtils.constrainToContainer(bounds, containerSize);

        expect(offset, equals(Offset.zero));
      });

      test('returns positive offset when bounds are left of container', () {
        final bounds = const Rect.fromLTWH(-20, 50, 100, 100);
        final containerSize = const Size(300, 300);

        final offset = TransformUtils.constrainToContainer(bounds, containerSize);

        expect(offset.dx, closeTo(20, 0.001));
        expect(offset.dy, equals(0));
      });

      test('returns negative offset when bounds are right of container', () {
        final bounds = const Rect.fromLTWH(250, 50, 100, 100);
        final containerSize = const Size(300, 300);

        final offset = TransformUtils.constrainToContainer(bounds, containerSize);

        expect(offset.dx, closeTo(-50, 0.001));
        expect(offset.dy, equals(0));
      });
    });

    group('angle conversions', () {
      test('converts degrees to radians', () {
        expect(TransformUtils.degreesToRadians(0), closeTo(0, 0.001));
        expect(TransformUtils.degreesToRadians(90), closeTo(1.5708, 0.001));
        expect(TransformUtils.degreesToRadians(180), closeTo(3.1416, 0.001));
        expect(TransformUtils.degreesToRadians(360), closeTo(6.2832, 0.001));
      });

      test('converts radians to degrees', () {
        expect(TransformUtils.radiansToDegrees(0), closeTo(0, 0.001));
        expect(TransformUtils.radiansToDegrees(1.5708), closeTo(90, 0.1));
        expect(TransformUtils.radiansToDegrees(3.1416), closeTo(180, 0.1));
      });

      test('normalizes angle correctly', () {
        expect(TransformUtils.normalizeAngle(0), closeTo(0, 0.001));
        expect(TransformUtils.normalizeAngle(4.0), closeTo(4.0 - 6.2832, 0.01));
        expect(TransformUtils.normalizeAngle(-4.0), closeTo(-4.0 + 6.2832, 0.01));
      });

      test('snaps angle to increment', () {
        expect(TransformUtils.snapAngle(0.1, 0.5), closeTo(0, 0.001));
        expect(TransformUtils.snapAngle(0.3, 0.5), closeTo(0.5, 0.001));
        expect(TransformUtils.snapAngle(1.1, 0.5), closeTo(1.0, 0.001));
      });
    });

    group('distance and angle calculations', () {
      test('calculates distance between points', () {
        final d = TransformUtils.distance(const Offset(0, 0), const Offset(3, 4));
        expect(d, closeTo(5, 0.001));
      });

      test('calculates angle between points', () {
        final angle = TransformUtils.angleBetween(
          const Offset(0, 0),
          const Offset(1, 0),
        );
        expect(angle, closeTo(0, 0.001));

        final angle90 = TransformUtils.angleBetween(
          const Offset(0, 0),
          const Offset(0, 1),
        );
        expect(angle90, closeTo(1.5708, 0.001));
      });
    });
  });
}
