import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConstants {
  // Allow overriding backend host IP (for physical devices)
  static String? customHost;

  static const String _envHost = String.fromEnvironment('BACKEND_HOST');

  static String get baseHost {
    if (customHost != null && customHost!.isNotEmpty) {
      return customHost!;
    }
    if (_envHost.isNotEmpty) {
      return _envHost;
    }
    if (kIsWeb) {
      return 'localhost:5129';
    }
    if (Platform.isAndroid) {
      return '10.0.2.2:5129';
    }
    // For physical iOS device, localhost points to the phone itself.
    // Use Mac's local network IP address:
    return '192.168.88.126:5129';
  }

  static String get baseUrl => 'http://$baseHost';
  static String get hubUrl => 'http://$baseHost/hubs/voice';

  // REST API Endpoints
  static String get sessionsEndpoint => '$baseUrl/api/sessions';
  static String get activeSessionsEndpoint => '$baseUrl/api/sessions/active';
  static String sessionDetailEndpoint(String id) => '$baseUrl/api/sessions/$id';
  static String completeSessionEndpoint(String id) =>
      '$baseUrl/api/sessions/$id/complete';
}
