import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../models/session_model.dart';
import '../models/session_summary_model.dart';

abstract class ISessionRemoteDataSource {
  Future<String> startSession(String topic, int targetLevel);
  Future<SessionModel> getSessionDetail(String sessionId);
  Future<void> completeSession(String sessionId, {String? feedback});
  Future<List<SessionSummaryModel>> getActiveSessions();
}

class SessionRemoteDataSource implements ISessionRemoteDataSource {
  final Dio _dio;

  SessionRemoteDataSource(this._dio);

  @override
  Future<String> startSession(String topic, int targetLevel) async {
    final response = await _dio.post(
      ApiConstants.sessionsEndpoint,
      data: {
        'topic': topic,
        'targetLevel': targetLevel,
      },
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return (data['sessionId'] ?? data['SessionId'] ?? data['id'] ?? '').toString();
      }
      return data.toString();
    }
    throw Exception('Failed to start session: ${response.statusCode} - ${response.data}');
  }

  @override
  Future<SessionModel> getSessionDetail(String sessionId) async {
    final response = await _dio.get(ApiConstants.sessionDetailEndpoint(sessionId));
    if (response.statusCode == 200) {
      return SessionModel.fromJson(response.data as Map<String, dynamic>);
    }
    throw Exception('Failed to fetch session detail: ${response.statusCode}');
  }

  @override
  Future<void> completeSession(String sessionId, {String? feedback}) async {
    final response = await _dio.post(
      ApiConstants.completeSessionEndpoint(sessionId),
      data: {
        'feedback': feedback,
      },
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to complete session: ${response.statusCode}');
    }
  }

  @override
  Future<List<SessionSummaryModel>> getActiveSessions() async {
    final response = await _dio.get(ApiConstants.activeSessionsEndpoint);
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch active sessions: ${response.statusCode}');
    }

    final data = response.data;
    if (data is! List) return [];

    return data
        .whereType<Map<String, dynamic>>()
        .map(SessionSummaryModel.fromJson)
        .toList();
  }
}
