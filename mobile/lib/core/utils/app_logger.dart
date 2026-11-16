import 'package:logger/logger.dart';

class AppLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 85,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );

  static void debug(String message) => _logger.d(message);
  static void info(String message) => _logger.i(message);
  static void warning(String message) => _logger.w(message);
  static void error(String message, [dynamic error, StackTrace? stackTrace]) =>
      _logger.e(message, error: error, stackTrace: stackTrace);

  /// Helper to log SignalR Hub invocations
  static void signalrInvoke(String method, List<dynamic> args) {
    _logger.i('📡 [SignalR INVOKE] $method\nPayload: $args');
  }

  /// Helper to log incoming SignalR events
  static void signalrEvent(String eventName, dynamic data) {
    _logger.d('📥 [SignalR EVENT] $eventName: $data');
  }

  /// Helper to log SignalR errors
  static void signalrError(String context, dynamic error) {
    _logger.e('❌ [SignalR ERROR] $context: $error');
  }
}
