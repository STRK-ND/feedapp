import 'package:flutter/foundation.dart';

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

  /// Log an error with severity level
  static void logError(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    ErrorSeverity severity = ErrorSeverity.medium,
  }) {
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

    // In production, you would send to a crash reporting service
    if (kReleaseMode && severity == ErrorSeverity.critical) {
      // TODO: Send to crash reporting service (e.g., Sentry, Firebase Crashlytics)
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
      return Result.failure(error!);
    }
    try {
      return Result.success(mapper(data!));
    } catch (e) {
      return Result.failure(e.toString());
    }
  }
}
