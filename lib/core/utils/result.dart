/// Result wrapper for operation outcomes
sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  T? get valueOrNull => switch (this) {
        Success<T>(:final value) => value,
        Failure<T>() => null,
      };

  String? get errorOrNull => switch (this) {
        Success<T>() => null,
        Failure<T>(:final message) => message,
      };

  R when<R>({
    required R Function(T value) success,
    required R Function(String message, Object? error) failure,
  }) {
    return switch (this) {
      Success<T>(:final value) => success(value),
      Failure<T>(:final message, :final error) => failure(message, error),
    };
  }

  Result<R> map<R>(R Function(T value) transform) {
    return switch (this) {
      Success<T>(:final value) => Success(transform(value)),
      Failure<T>(:final message, :final error) => Failure(message, error),
    };
  }

  Future<Result<R>> mapAsync<R>(Future<R> Function(T value) transform) async {
    return switch (this) {
      Success<T>(:final value) => Success(await transform(value)),
      Failure<T>(:final message, :final error) => Failure(message, error),
    };
  }
}

class Success<T> extends Result<T> {
  final T value;
  const Success(this.value);
}

class Failure<T> extends Result<T> {
  final String message;
  final Object? error;
  const Failure(this.message, [this.error]);
}
