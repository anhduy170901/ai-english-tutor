import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../core/di/injection_container.dart';
import '../core/theme/app_theme.dart';
import '../features/session/presentation/bloc/session_bloc.dart';
import '../features/session/presentation/pages/topic_selection_page.dart';

class AiTutorApp extends StatelessWidget {
  const AiTutorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<SessionBloc>()),
      ],
      child: MaterialApp(
        title: 'AI English Tutor',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const TopicSelectionPage(),
      ),
    );
  }
}
