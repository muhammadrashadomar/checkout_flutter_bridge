import 'package:flutter/foundation.dart';

/// ANSI color codes for console output
class ConsoleColor {
  static const String reset = '\x1B[0m';
  static const String red = '\x1B[31m';
  static const String green = '\x1B[32m';
  static const String yellow = '\x1B[33m';
  static const String blue = '\x1B[34m';
  static const String magenta = '\x1B[35m';
  static const String cyan = '\x1B[36m';
  static const String white = '\x1B[37m';

  // Bright colors
  static const String brightRed = '\x1B[91m';
  static const String brightGreen = '\x1B[92m';
  static const String brightYellow = '\x1B[93m';
  static const String brightBlue = '\x1B[94m';
  static const String brightCyan = '\x1B[96m';
}

/// Colored console logger for better visibility
class ConsoleLogger {
  /// Log success message (green)
  static void success(String message) {
    if (kDebugMode) {
      debugPrint('${ConsoleColor.brightGreen}✅ $message${ConsoleColor.reset}');
    }
  }

  /// Log error message (red)
  static void error(String message) {
    if (kDebugMode) {
      debugPrint('${ConsoleColor.brightRed}❌ $message${ConsoleColor.reset}');
    }
  }

  /// Log warning message (yellow)
  static void warning(String message) {
    if (kDebugMode) {
      debugPrint(
        '${ConsoleColor.brightYellow}⚠️  $message${ConsoleColor.reset}',
      );
    }
  }

  /// Log info message (cyan)
  static void info(String message) {
    if (kDebugMode) {
      debugPrint('${ConsoleColor.brightCyan}ℹ️  $message${ConsoleColor.reset}');
    }
  }

  /// Log debug message (blue)
  static void debug(String message) {
    if (kDebugMode) {
      debugPrint('${ConsoleColor.brightBlue}🔍 $message${ConsoleColor.reset}');
    }
  }

  /// Log payment-related message (magenta)
  static void payment(String message) {
    if (kDebugMode) {
      debugPrint('${ConsoleColor.magenta}💳 $message${ConsoleColor.reset}');
    }
  }
}
