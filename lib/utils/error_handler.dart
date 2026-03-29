import 'package:flutter/foundation.dart';
import 'package:sentry/sentry.dart';

/// App error severity levels
enum ErrorSeverity {
  low,
  medium,
  high,
  critical,
}

/// App error handler for consistent error management
class ErrorHandler {
  ErrorHandler._();

  /// Log an error with severity level and send to Sentry
  static Future<void> logError(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    ErrorSeverity severity = ErrorSeverity.medium,
    Map<String, dynamic>? extra,
  }) async {
    final severityTag = _getSeverityTag(severity);
    final logMessage = '[$severityTag] $message';

    if (error != null) {
      debugPrint('$logMessage: $error');
      if (stackTrace != null) {
        debugPrint(stackTrace.toString());
      }
    } else {
      debugPrint(logMessage);
    }

    // Send to Sentry in release mode for medium+ severity
    if (kReleaseMode) {
      await _sendToSentry(
        message: logMessage,
        error: error,
        stackTrace: stackTrace,
        severity: severity,
      );
    }
    // Always send critical errors to Sentry in debug too
    else if (severity == ErrorSeverity.critical && error != null) {
      await _sendToSentry(
        message: logMessage,
        error: error,
        stackTrace: stackTrace,
        severity: severity,
      );
    }
  }

  /// Send error to Sentry
  static Future<void> _sendToSentry({
    required String message,
    Object? error,
    StackTrace? stackTrace,
    ErrorSeverity severity = ErrorSeverity.medium,
  }) async {
    try {
      final sentryLevel = _getSentryLevel(severity);

      if (error != null) {
        // Capture as exception
        await Sentry.captureException(error, stackTrace: stackTrace);
      } else {
        // Capture as message
        await Sentry.captureMessage(message, level: sentryLevel);
      }
    } catch (e) {
      debugPrint('Failed to send to Sentry: $e');
    }
  }

  /// Capture a specific exception to Sentry
  static Future<void> captureException(
    Object error, {
    StackTrace? stackTrace,
    String? reason,
  }) async {
    try {
      await Sentry.captureException(error, stackTrace: stackTrace);
    } catch (e) {
      debugPrint('Failed to capture exception to Sentry: $e');
    }
  }

  /// Capture a message to Sentry
  static Future<void> captureMessage(
    String message, {
    SentryLevel level = SentryLevel.info,
  }) async {
    try {
      await Sentry.captureMessage(message, level: level);
    } catch (e) {
      debugPrint('Failed to capture message to Sentry: $e');
    }
  }

  /// Add a breadcrumb for user actions
  static void addBreadcrumb(String message, {String? category}) {
    Sentry.addBreadcrumb(
      Breadcrumb(
        message: message,
        category: category,
        timestamp: DateTime.now(),
      ),
    );
  }

  static SentryLevel _getSentryLevel(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.low:
        return SentryLevel.debug;
      case ErrorSeverity.medium:
        return SentryLevel.warning;
      case ErrorSeverity.high:
        return SentryLevel.error;
      case ErrorSeverity.critical:
        return SentryLevel.fatal;
    }
  }

  /// Get user-friendly message for common errors
  static String getUserMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('network') ||
        errorString.contains('socket') ||
        errorString.contains('connection')) {
      return 'Network error. Please check your connection.';
    }

    if (errorString.contains('timeout')) {
      return 'Request timed out. Please try again.';
    }

    if (errorString.contains('401') || errorString.contains('unauthorized')) {
      return 'Authentication failed. Please log in again.';
    }

    if (errorString.contains('404') || errorString.contains('not found')) {
      return 'Resource not found.';
    }

    if (errorString.contains('500') || errorString.contains('server')) {
      return 'Server error. Please try again later.';
    }

    if (errorString.contains('xml') || errorString.contains('parse')) {
      return 'Failed to parse content. This feed may be invalid.';
    }

    // Default message
    return 'An error occurred. Please try again.';
  }

  /// Check if error should be shown to user
  static bool shouldShowToUser(dynamic error) {
    final errorString = error.toString().toLowerCase();

    // Don't show trivial errors
    if (errorString.contains('canceled') ||
        errorString.contains('disposed') ||
        errorString.contains('duplicate')) {
      return false;
    }

    return true;
  }

  /// Check if error is recoverable (user can retry)
  static bool isRecoverable(dynamic error) {
    final errorString = error.toString().toLowerCase();

    return errorString.contains('network') ||
        errorString.contains('timeout') ||
        errorString.contains('connection') ||
        errorString.contains('server');
  }

  static String _getSeverityTag(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.low:
        return 'INFO';
      case ErrorSeverity.medium:
        return 'WARN';
      case ErrorSeverity.high:
        return 'ERROR';
      case ErrorSeverity.critical:
        return 'CRITICAL';
    }
  }
}

/// Result type for operations that can fail
class Result<T> {
  final T? data;
  final String? error;
  final bool isSuccess;

  Result.success(this.data)
      : error = null,
        isSuccess = true;

  Result.failure(this.error)
      : data = null,
        isSuccess = false;

  bool get isFailure => !isSuccess;

  /// Get data if successful, throw if not
  T get dataOrThrow {
    if (isSuccess) {
      return data!;
    }
    throw Exception(error);
  }

  /// Map the data if successful
  Result<R> map<R>(R Function(T) mapper) {
    if (isFailure) {
      return Result.failure(error);
    }
    if (data == null) {
      return Result.failure('No data available');
    }
    try {
      return Result.success(mapper(data as T));
    } catch (e) {
      return Result.failure(e.toString());
    }
  }
}