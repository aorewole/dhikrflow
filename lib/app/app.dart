import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../features/onboarding/onboarding_screen.dart';
import 'app_scope.dart';
import 'theme.dart';

/// Root widget of the Dhikr Counter application.
class DhikrCounterApp extends StatelessWidget {
  final AppDependencies dependencies;

  const DhikrCounterApp({super.key, required this.dependencies});

  @override
  Widget build(BuildContext context) {
    return AppScope(
      dependencies: dependencies,
      child: Builder(
        builder: (context) {
          final deps = AppScope.of(context);

          return ListenableBuilder(
            listenable: deps.settingsController,
            builder: (context, _) {
              return MaterialApp(
                title: AppConstants.appName,
                debugShowCheckedModeBanner: false,
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: deps.settingsController.themeMode,
                home: const OnboardingScreen(),
              );
            },
          );
        },
      ),
    );
  }
}
