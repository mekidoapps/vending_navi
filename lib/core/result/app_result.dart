import '../errors/app_failure.dart';

sealed class AppResult<T> {
  const AppResult();

  const factory AppResult.success(T value) = AppSuccess<T>;
  const factory AppResult.failure(AppFailure failure) = AppFailureResult<T>;

  bool get isSuccess => this is AppSuccess<T>;
  bool get isFailure => this is AppFailureResult<T>;

  T? get valueOrNull => switch (this) {
    AppSuccess<T>(:final value) => value,
    AppFailureResult<T>() => null,
  };

  AppFailure? get failureOrNull => switch (this) {
    AppSuccess<T>() => null,
    AppFailureResult<T>(:final failure) => failure,
  };

  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(AppFailure failure) onFailure,
  }) {
    return switch (this) {
      AppSuccess<T>(:final value) => onSuccess(value),
      AppFailureResult<T>(:final failure) => onFailure(failure),
    };
  }

  AppResult<R> map<R>(R Function(T value) transform) {
    return switch (this) {
      AppSuccess<T>(:final value) => AppResult<R>.success(transform(value)),
      AppFailureResult<T>(:final failure) => AppResult<R>.failure(failure),
    };
  }

  AppResult<R> flatMap<R>(AppResult<R> Function(T value) transform) {
    return switch (this) {
      AppSuccess<T>(:final value) => transform(value),
      AppFailureResult<T>(:final failure) => AppResult<R>.failure(failure),
    };
  }
}

final class AppSuccess<T> extends AppResult<T> {
  const AppSuccess(this.value);

  final T value;
}

final class AppFailureResult<T> extends AppResult<T> {
  const AppFailureResult(this.failure);

  final AppFailure failure;
}
