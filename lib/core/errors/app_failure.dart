import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthException, PostgrestException, StorageException;

/// The single error type every repository/service and every ported
/// notifier maps into at the data-layer boundary (ADR-011). Callers --
/// and the UI -- are only ever meant to see an [AppFailure], never a raw
/// `PostgrestException`/`StorageException`/`AuthException` directly.
///
/// This mirrors the recoverable/non-recoverable status-code split that
/// already existed in one place before this type did
/// (`NoteitSyncManager._processTask`): Postgrest codes `42501` (RLS
/// denial), `23xxx` (constraint violation), `400`, and `403` are
/// non-recoverable; everything else is treated as a transient network
/// condition. [mapExceptionToFailure] generalizes that same split so any
/// caller can reuse it instead of reimplementing the classification.
sealed class AppFailure {
  const AppFailure(this.message, {this.cause});

  /// A short, user-presentable description. Callers may still choose to
  /// show a feature-specific message instead -- this is a sane default,
  /// not a mandate (see ADR-011: "derived at the presentation layer").
  final String message;

  /// The original exception/error this failure was mapped from, if any.
  /// Kept for logging -- never shown to the user.
  final Object? cause;

  @override
  String toString() => cause == null ? '$runtimeType($message)' : '$runtimeType($message, cause: $cause)';
}

/// Connectivity or 5xx-class failures. Retryable.
class NetworkFailure extends AppFailure {
  const NetworkFailure({String message = 'A network error occurred. Please check your connection.', Object? cause})
      : super(message, cause: cause);
}

/// Supabase Auth session is missing, expired, or invalid.
class AuthFailure extends AppFailure {
  const AuthFailure({String message = 'Your session has expired. Please sign in again.', Object? cause})
      : super(message, cause: cause);
}

/// A Row Level Security or permission denial (Postgrest `42501`/`403`-class).
/// Not retryable.
class AuthorizationFailure extends AppFailure {
  const AuthorizationFailure({String message = "You don't have permission to do that.", Object? cause})
      : super(message, cause: cause);
}

/// Bad input rejected by a database constraint or check (Postgrest
/// `23xxx`/`400`-class). Not retryable.
class ValidationFailure extends AppFailure {
  const ValidationFailure({String message = 'That input was not valid.', Object? cause})
      : super(message, cause: cause);
}

/// The requested row or resource does not exist.
class NotFoundFailure extends AppFailure {
  const NotFoundFailure({String message = "That couldn't be found.", Object? cause})
      : super(message, cause: cause);
}

/// A Supabase Storage (bucket) failure -- distinct from a local disk I/O
/// error, which falls under [UnknownFailure].
class StorageFailure extends AppFailure {
  const StorageFailure({String message = 'A file storage error occurred.', Object? cause})
      : super(message, cause: cause);
}

/// Anything that doesn't fit the categories above -- the catch-all.
class UnknownFailure extends AppFailure {
  const UnknownFailure({String message = 'Something went wrong. Please try again.', Object? cause})
      : super(message, cause: cause);
}

/// Maps a raw exception caught at a repository/service boundary to the
/// [AppFailure] taxonomy above, generalizing the status-code split that
/// previously existed only inside `NoteitSyncManager`.
AppFailure mapExceptionToFailure(Object error) {
  if (error is PostgrestException) {
    final code = error.code;
    if (code == '42501' || code == '403') {
      return AuthorizationFailure(cause: error);
    }
    if (code == '400' || (code?.startsWith('23') ?? false)) {
      return ValidationFailure(cause: error);
    }
    if (code == 'PGRST116') {
      return NotFoundFailure(cause: error);
    }
    return NetworkFailure(cause: error);
  }
  if (error is StorageException) {
    final code = error.statusCode;
    if (code == '400' || code == '403' || code == '42501') {
      return AuthorizationFailure(cause: error);
    }
    return StorageFailure(cause: error);
  }
  if (error is AuthException) {
    return AuthFailure(cause: error);
  }
  return UnknownFailure(cause: error);
}
