import 'package:flutter/material.dart';
import 'logger.dart';

/// Custom exception types for better error categorization
abstract class NotekerException implements Exception {
  const NotekerException(this.message, {this.code, this.originalError});

  final String message;
  final String? code;
  final Object? originalError;

  @override
  String toString() => 'NotekerException: $message${code != null ? ' (Code: $code)' : ''}';
}

class SyncException extends NotekerException {
  const SyncException(super.message, {super.code, super.originalError});
}

class StorageException extends NotekerException {
  const StorageException(super.message, {super.code, super.originalError});
}

class NetworkException extends NotekerException {
  const NetworkException(super.message, {super.code, super.originalError});
}

class ValidationException extends NotekerException {
  const ValidationException(super.message, {super.code, super.originalError});
}

/// Error handling utility class
class ErrorHandler with LoggerMixin {
  factory ErrorHandler() => _instance;
  ErrorHandler._internal();
  static final ErrorHandler _instance = ErrorHandler._internal();
  
  /// Handle and log errors with appropriate user feedback
  void handleError(
    Object error, {
    StackTrace? stackTrace,
    String? context,
    bool showToUser = true,
    BuildContext? buildContext,
  }) {
    final errorMessage = _getErrorMessage(error);
    final userMessage = _getUserFriendlyMessage(error);
    
    // Log the error
    if (error is NotekerException) {
      logError(
        '${context ?? 'Error'}: $errorMessage',
        error: error.originalError ?? error,
        stackTrace: stackTrace,
      );
    } else {
      logError(
        '${context ?? 'Unexpected error'}: $errorMessage',
        error: error,
        stackTrace: stackTrace,
      );
    }
    
    // Show user feedback if requested and context is available
    if (showToUser && buildContext != null) {
      _showErrorToUser(buildContext, userMessage);
    }
  }
  
  /// Wrap async operations with error handling
  Future<T?> safeAsync<T>(
    Future<T> Function() operation, {
    String? context,
    BuildContext? buildContext,
    bool showErrorToUser = true,
    T? fallbackValue,
  }) async {
    try {
      return await operation();
    } on Object catch (error, stackTrace) {
      handleError(
        error,
        stackTrace: stackTrace,
        context: context,
        showToUser: showErrorToUser,
        buildContext: buildContext,
      );
      return fallbackValue;
    }
  }
  
  /// Wrap synchronous operations with error handling
  T? safeSync<T>(
    T Function() operation, {
    String? context,
    BuildContext? buildContext,
    bool showErrorToUser = true,
    T? fallbackValue,
  }) {
    try {
      return operation();
    } on Object catch (error, stackTrace) {
      handleError(
        error,
        stackTrace: stackTrace,
        context: context,
        showToUser: showErrorToUser,
        buildContext: buildContext,
      );
      return fallbackValue;
    }
  }
  
  String _getErrorMessage(Object error) {
    if (error is NotekerException) {
      return error.message;
    } else if (error is Exception) {
      return error.toString();
    } else {
      return 'Unknown error: $error';
    }
  }
  
  String _getUserFriendlyMessage(Object error) {
    if (error is SyncException) {
      return 'Failed to sync with Google Drive. Please check your connection and try again.';
    } else if (error is StorageException) {
      return 'Failed to save your notes. Please try again.';
    } else if (error is NetworkException) {
      return 'Network error. Please check your internet connection.';
    } else if (error is ValidationException) {
      return error.message; // Validation messages are usually user-friendly
    } else {
      return 'Something went wrong. Please try again.';
    }
  }
  
  void _showErrorToUser(BuildContext context, String message) {
    if (!context.mounted) {
      return;
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Theme.of(context).colorScheme.onError,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }
}

/// Widget to catch and handle errors in the widget tree
class ErrorBoundary extends StatelessWidget with LoggerMixin {
  const ErrorBoundary({
    required this.child,
    this.errorBuilder,
    this.onError,
    super.key,
  });

  final Widget child;
  final Widget Function(Object error, StackTrace? stackTrace)? errorBuilder;
  final void Function(Object error, StackTrace? stackTrace)? onError;

  @override
  Widget build(BuildContext context) => child;
}
