import 'package:equatable/equatable.dart';

/// Domain-level error. Data sources translate their own exceptions into one of
/// these so the presentation layer never has to know about Hive or Firestore.
sealed class Failure extends Equatable implements Exception {
  const Failure(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  List<Object?> get props => [message, cause];

  @override
  String toString() => '$runtimeType: $message';
}

class CacheFailure extends Failure {
  const CacheFailure(super.message, {super.cause});
}

class RemoteFailure extends Failure {
  const RemoteFailure(super.message, {super.cause});
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {super.cause});
}

class NotFoundFailure extends Failure {
  const NotFoundFailure(super.message, {super.cause});
}
