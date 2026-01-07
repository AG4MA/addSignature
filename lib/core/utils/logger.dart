import 'dart:developer' as developer;

enum LogLevel { debug, info, warning, error }

class AppLogger {
  static bool enabled = true;
  static LogLevel minLevel = LogLevel.debug;

  static void debug(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.debug, message, error, stackTrace);
  }

  static void info(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.info, message, error, stackTrace);
  }

  static void warning(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.warning, message, error, stackTrace);
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.error, message, error, stackTrace);
  }

  static void _log(
    LogLevel level,
    String message,
    Object? error,
    StackTrace? stackTrace,
  ) {
    if (!enabled || level.index < minLevel.index) return;

    final prefix = switch (level) {
      LogLevel.debug => '🐛 DEBUG',
      LogLevel.info => 'ℹ️ INFO',
      LogLevel.warning => '⚠️ WARNING',
      LogLevel.error => '❌ ERROR',
    };

    final timestamp = DateTime.now().toIso8601String();
    final fullMessage = '[$timestamp] $prefix: $message';

    developer.log(
      fullMessage,
      error: error,
      stackTrace: stackTrace,
      name: 'SignStamp',
    );
  }
}
