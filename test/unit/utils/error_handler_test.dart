import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:curatedfeeds/utils/error_handler.dart';

void main() {
  group('ErrorHandler', () {
    group('getUserMessage', () {
      test('returns network message for connection errors', () {
        expect(
          ErrorHandler.getUserMessage(Exception('network error')),
          'Network error. Please check your connection.',
        );
        expect(
          ErrorHandler.getUserMessage(Exception('socket exception')),
          'Network error. Please check your connection.',
        );
        expect(
          ErrorHandler.getUserMessage(Exception('No connection')),
          'Network error. Please check your connection.',
        );
      });

      test('returns timeout message for timeout errors', () {
        expect(
          ErrorHandler.getUserMessage(Exception('timeout')),
          'Request timed out. Please try again.',
        );
      });

      test('returns auth message for 401 errors', () {
        expect(
          ErrorHandler.getUserMessage(Exception('HTTP 401 unauthorized')),
          'Access denied. Please try again.',
        );
      });

      test('returns rate limit message for 429 errors', () {
        expect(
          ErrorHandler.getUserMessage(Exception('HTTP 429 rate limit exceeded')),
          'Too many requests. Please try again in a moment.',
        );
      });

      test('returns not found message for 404 errors', () {
        expect(
          ErrorHandler.getUserMessage(Exception('not found 404')),
          'Resource not found.',
        );
      });

      test('returns server error message for 500 errors', () {
        expect(
          ErrorHandler.getUserMessage(Exception('server error 500')),
          'Server error. Please try again later.',
        );
      });

      test('returns XML parse message for XML errors', () {
        expect(
          ErrorHandler.getUserMessage(Exception('xml parse error')),
          'Failed to parse content. This feed may be invalid.',
        );
      });

      test('returns default message for unknown errors', () {
        expect(
          ErrorHandler.getUserMessage(Exception('something unexpected')),
          'An error occurred. Please try again.',
        );
      });

      test('is case-insensitive', () {
        expect(
          ErrorHandler.getUserMessage(Exception('Network ERROR')),
          'Network error. Please check your connection.',
        );
        expect(
          ErrorHandler.getUserMessage(Exception('TIMEOUT')),
          'Request timed out. Please try again.',
        );
      });
    });

    group('shouldShowToUser', () {
      test('returns false for canceled errors', () {
        expect(ErrorHandler.shouldShowToUser('canceled operation'), false);
      });

      test('returns false for disposed errors', () {
        expect(ErrorHandler.shouldShowToUser('widget disposed'), false);
      });

      test('returns false for duplicate errors', () {
        expect(ErrorHandler.shouldShowToUser('duplicate entry'), false);
      });

      test('returns true for normal errors', () {
        expect(ErrorHandler.shouldShowToUser('network error'), true);
        expect(ErrorHandler.shouldShowToUser('timeout'), true);
        expect(ErrorHandler.shouldShowToUser(Exception('something')), true);
      });
    });

    group('isRecoverable', () {
      test('returns true for network-related errors', () {
        expect(ErrorHandler.isRecoverable('network error'), true);
        expect(ErrorHandler.isRecoverable('timeout'), true);
        expect(ErrorHandler.isRecoverable('connection lost'), true);
        expect(ErrorHandler.isRecoverable('server error'), true);
      });

      test('returns false for data-related errors', () {
        expect(ErrorHandler.isRecoverable('xml parse error'), false);
        expect(ErrorHandler.isRecoverable('invalid data'), false);
        expect(ErrorHandler.isRecoverable('not found'), false);
      });
    });

    group('Result type', () {
      test('Result.success creates success result', () {
        final result = Result.success(42);
        expect(result.isSuccess, true);
        expect(result.isFailure, false);
        expect(result.data, 42);
        expect(result.error, null);
      });

      test('Result.failure creates failure result', () {
        final result = Result.failure('something went wrong');
        expect(result.isSuccess, false);
        expect(result.isFailure, true);
        expect(result.data, null);
        expect(result.error, 'something went wrong');
      });

      test('dataOrThrow returns data on success', () {
        final result = Result.success('hello');
        expect(result.dataOrThrow, 'hello');
      });

      test('dataOrThrow throws on failure', () {
        final result = Result.failure('bad');
        expect(() => result.dataOrThrow, throwsException);
      });

      test('map transforms success data', () {
        final result = Result.success(10);
        final mapped = result.map((n) => n * 2);
        expect(mapped.dataOrThrow, 20);
      });

      test('map passes through failure', () {
        final result = Result.failure('bad');
        final mapped = result.map((_) => 'unreachable');
        expect(mapped.isFailure, true);
        expect(mapped.error, 'bad');
      });

      test('map returns failure when data is null', () {
        final result = Result.success(null);
        final mapped = result.map((d) => d.toString());
        expect(mapped.isFailure, true);
        expect(mapped.error, 'No data available');
      });

      test('map catches mapper exceptions', () {
        final result = Result.success(10);
        final mapped = result.map((_) => throw Exception('mapper failed'));
        expect(mapped.isFailure, true);
        expect(mapped.error, contains('mapper failed'));
      });
    });

    group('severity to SentryLevel mapping', () {
      test('all severity levels are valid', () {
        expect(ErrorSeverity.low.index, 0);
        expect(ErrorSeverity.medium.index, 1);
        expect(ErrorSeverity.high.index, 2);
        expect(ErrorSeverity.critical.index, 3);
      });

      test('SentryLevel values are correct', () {
        expect(SentryLevel.debug.name, 'debug');
        expect(SentryLevel.warning.name, 'warning');
        expect(SentryLevel.error.name, 'error');
        expect(SentryLevel.fatal.name, 'fatal');
        expect(SentryLevel.info.name, 'info');
      });
    });

    group('ErrorHandler public API smoke tests', () {
      test('logWarning completes without error', () async {
        await ErrorHandler.logWarning('test warning');
      });

      test('logWarning with error completes', () async {
        await ErrorHandler.logWarning(
          'test warning with error',
          error: Exception('test'),
        );
      });

      test('logError default severity completes', () async {
        await ErrorHandler.logError('test error');
      });

      test('logError with all severity levels completes', () async {
        await ErrorHandler.logError(
          'low severity',
          severity: ErrorSeverity.low,
        );
        await ErrorHandler.logError(
          'medium severity',
          severity: ErrorSeverity.medium,
        );
        await ErrorHandler.logError(
          'high severity',
          severity: ErrorSeverity.high,
        );
        await ErrorHandler.logError(
          'critical severity',
          severity: ErrorSeverity.critical,
        );
      });

      test('logError with exception and stack completes', () async {
        await ErrorHandler.logError(
          'error with details',
          error: Exception('real error'),
          stackTrace: StackTrace.current,
          severity: ErrorSeverity.high,
        );
      });

      test('addBreadcrumb completes without error', () {
        ErrorHandler.addBreadcrumb('test breadcrumb');
        ErrorHandler.addBreadcrumb(
          'categorized breadcrumb',
          category: 'navigation',
        );
      });

      test('logError does not throw on null error', () async {
        await ErrorHandler.logError('error with null error');
      });

      test('logError handles very long messages', () async {
        final longMessage = 'A' * 10000;
        await ErrorHandler.logError(longMessage);
      });
    });
  });
}
