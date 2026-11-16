import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

// Core
import '../audio/audio_player_service.dart';
import '../audio/audio_recorder_service.dart';
import '../constants/api_constants.dart';
import '../network/signalr_service.dart';

// Session Feature
import '../../features/session/data/datasources/session_remote_datasource.dart';
import '../../features/session/data/repositories/session_repository_impl.dart';
import '../../features/session/domain/repositories/session_repository.dart';
import '../../features/session/domain/usecases/complete_session_usecase.dart';
import '../../features/session/domain/usecases/get_active_sessions_usecase.dart';
import '../../features/session/domain/usecases/get_session_detail_usecase.dart';
import '../../features/session/domain/usecases/start_session_usecase.dart';
import '../../features/session/presentation/bloc/session_bloc.dart';

// Voice Tutor Feature
import '../../features/voice_tutor/data/datasources/voice_hub_datasource.dart';
import '../../features/voice_tutor/data/repositories/voice_tutor_repository_impl.dart';
import '../../features/voice_tutor/domain/repositories/voice_tutor_repository.dart';
import '../../features/voice_tutor/domain/usecases/connect_voice_hub_usecase.dart';
import '../../features/voice_tutor/domain/usecases/send_messages_usecases.dart';
import '../../features/voice_tutor/presentation/bloc/voice_tutor_bloc.dart';

final sl = GetIt.instance;

Future<void> initDependencies() async {
  // ----------------------------------------------------
  // External / Core
  // ----------------------------------------------------
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ),
  );
  dio.interceptors.add(
    PrettyDioLogger(
      requestHeader: true,
      requestBody: true,
      responseBody: true,
      responseHeader: false,
      error: true,
      compact: true,
      maxWidth: 90,
    ),
  );
  sl.registerLazySingleton<Dio>(() => dio);

  sl.registerLazySingleton<ISignalRService>(() => SignalRService());
  sl.registerLazySingleton<IAudioRecorderService>(() => AudioRecorderService());
  sl.registerLazySingleton<IAudioPlayerService>(() => AudioPlayerService());

  // ----------------------------------------------------
  // Session Feature
  // ----------------------------------------------------
  // Data sources
  sl.registerLazySingleton<ISessionRemoteDataSource>(
    () => SessionRemoteDataSource(sl<Dio>()),
  );

  // Repositories
  sl.registerLazySingleton<ISessionRepository>(
    () => SessionRepositoryImpl(sl<ISessionRemoteDataSource>()),
  );

  // Use cases
  sl.registerLazySingleton(() => StartSessionUseCase(sl<ISessionRepository>()));
  sl.registerLazySingleton(() => GetSessionDetailUseCase(sl<ISessionRepository>()));
  sl.registerLazySingleton(() => CompleteSessionUseCase(sl<ISessionRepository>()));
  sl.registerLazySingleton(() => GetActiveSessionsUseCase(sl<ISessionRepository>()));

  // Bloc
  sl.registerFactory(
    () => SessionBloc(
      startSessionUseCase: sl<StartSessionUseCase>(),
      getSessionDetailUseCase: sl<GetSessionDetailUseCase>(),
      completeSessionUseCase: sl<CompleteSessionUseCase>(),
    ),
  );

  // ----------------------------------------------------
  // Voice Tutor Feature
  // ----------------------------------------------------
  // Data sources
  sl.registerLazySingleton<IVoiceHubDataSource>(
    () => VoiceHubDataSource(sl<ISignalRService>()),
  );

  // Repositories
  sl.registerLazySingleton<IVoiceTutorRepository>(
    () => VoiceTutorRepositoryImpl(sl<IVoiceHubDataSource>()),
  );

  // Use cases
  sl.registerLazySingleton(() => ConnectVoiceHubUseCase(sl<IVoiceTutorRepository>()));
  sl.registerLazySingleton(() => SendAudioMessageUseCase(sl<IVoiceTutorRepository>()));
  sl.registerLazySingleton(() => SendTextMessageUseCase(sl<IVoiceTutorRepository>()));

  // Bloc
  sl.registerFactory(
    () => VoiceTutorBloc(
      repository: sl<IVoiceTutorRepository>(),
      recorderService: sl<IAudioRecorderService>(),
      playerService: sl<IAudioPlayerService>(),
      getSessionDetailUseCase: sl<GetSessionDetailUseCase>(),
    ),
  );
}
