import 'package:flutter_test/flutter_test.dart';
import 'package:sign_stamp/core/utils/result.dart';

void main() {
  group('Result', () {
    group('Success', () {
      test('isSuccess returns true', () {
        const result = Success<int>(42);
        expect(result.isSuccess, isTrue);
        expect(result.isFailure, isFalse);
      });

      test('valueOrNull returns value', () {
        const result = Success<String>('hello');
        expect(result.valueOrNull, equals('hello'));
      });

      test('errorOrNull returns null', () {
        const result = Success<int>(42);
        expect(result.errorOrNull, isNull);
      });

      test('when executes success callback', () {
        const result = Success<int>(42);
        final value = result.when(
          success: (v) => v * 2,
          failure: (msg, err) => 0,
        );
        expect(value, equals(84));
      });

      test('map transforms value', () {
        const result = Success<int>(10);
        final mapped = result.map((v) => v.toString());
        expect(mapped.valueOrNull, equals('10'));
      });

      test('mapAsync transforms value asynchronously', () async {
        const result = Success<int>(5);
        final mapped = await result.mapAsync((v) async => v * 3);
        expect(mapped.valueOrNull, equals(15));
      });
    });

    group('Failure', () {
      test('isFailure returns true', () {
        const result = Failure<int>('error');
        expect(result.isFailure, isTrue);
        expect(result.isSuccess, isFalse);
      });

      test('valueOrNull returns null', () {
        const result = Failure<String>('error');
        expect(result.valueOrNull, isNull);
      });

      test('errorOrNull returns error message', () {
        const result = Failure<int>('Something went wrong');
        expect(result.errorOrNull, equals('Something went wrong'));
      });

      test('stores error object', () {
        final exception = Exception('Test exception');
        final result = Failure<int>('error', exception);
        expect(result.error, equals(exception));
      });

      test('when executes failure callback', () {
        const result = Failure<int>('error message');
        final value = result.when(
          success: (v) => 'success',
          failure: (msg, err) => 'failed: $msg',
        );
        expect(value, equals('failed: error message'));
      });

      test('map propagates failure', () {
        const result = Failure<int>('original error');
        final mapped = result.map((v) => v.toString());
        expect(mapped.isFailure, isTrue);
        expect(mapped.errorOrNull, equals('original error'));
      });

      test('mapAsync propagates failure', () async {
        const result = Failure<int>('async error');
        final mapped = await result.mapAsync((v) async => v.toString());
        expect(mapped.isFailure, isTrue);
        expect(mapped.errorOrNull, equals('async error'));
      });
    });

    group('Pattern matching', () {
      test('switch expression works with Success', () {
        const Result<int> result = Success(42);
        final value = switch (result) {
          Success(:final value) => 'Value: $value',
          Failure(:final message) => 'Error: $message',
        };
        expect(value, equals('Value: 42'));
      });

      test('switch expression works with Failure', () {
        const Result<int> result = Failure('not found');
        final value = switch (result) {
          Success(:final value) => 'Value: $value',
          Failure(:final message) => 'Error: $message',
        };
        expect(value, equals('Error: not found'));
      });
    });
  });
}
