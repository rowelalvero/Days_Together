import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:days_together/core/errors/app_failure.dart';

void main() {
  group('mapExceptionToFailure', () {
    test('Postgrest 42501 (RLS denial) maps to AuthorizationFailure', () {
      final failure = mapExceptionToFailure(const PostgrestException(message: 'denied', code: '42501'));
      expect(failure, isA<AuthorizationFailure>());
    });

    test('Postgrest 403 maps to AuthorizationFailure', () {
      final failure = mapExceptionToFailure(const PostgrestException(message: 'denied', code: '403'));
      expect(failure, isA<AuthorizationFailure>());
    });

    test('Postgrest 23xxx constraint violation maps to ValidationFailure', () {
      final failure = mapExceptionToFailure(const PostgrestException(message: 'bad', code: '23505'));
      expect(failure, isA<ValidationFailure>());
    });

    test('Postgrest 400 maps to ValidationFailure', () {
      final failure = mapExceptionToFailure(const PostgrestException(message: 'bad', code: '400'));
      expect(failure, isA<ValidationFailure>());
    });

    test('Postgrest PGRST116 (no rows) maps to NotFoundFailure', () {
      final failure = mapExceptionToFailure(const PostgrestException(message: 'not found', code: 'PGRST116'));
      expect(failure, isA<NotFoundFailure>());
    });

    test('Postgrest with an unrecognized/null code maps to NetworkFailure', () {
      final failure = mapExceptionToFailure(const PostgrestException(message: 'timeout'));
      expect(failure, isA<NetworkFailure>());
    });

    test('Storage exception with a permission status code maps to AuthorizationFailure', () {
      final failure = mapExceptionToFailure(const StorageException('denied', statusCode: '403'));
      expect(failure, isA<AuthorizationFailure>());
    });

    test('Storage exception with any other status code maps to StorageFailure', () {
      final failure = mapExceptionToFailure(const StorageException('upload failed', statusCode: '500'));
      expect(failure, isA<StorageFailure>());
    });

    test('AuthException maps to AuthFailure', () {
      final failure = mapExceptionToFailure(const AuthException('session expired'));
      expect(failure, isA<AuthFailure>());
    });

    test('an unrelated exception maps to UnknownFailure', () {
      final failure = mapExceptionToFailure(Exception('something else'));
      expect(failure, isA<UnknownFailure>());
    });

    test('the original exception is preserved as cause', () {
      final original = Exception('boom');
      final failure = mapExceptionToFailure(original);
      expect(failure.cause, same(original));
    });
  });
}
