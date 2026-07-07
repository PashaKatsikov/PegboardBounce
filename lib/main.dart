import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/app_theme.dart';
import 'screens/loading_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Allow both orientations during loading; the game locks to portrait later.
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const PegboardBounceApp());
}

class PegboardBounceApp extends StatelessWidget {
  const PegboardBounceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pegboard Bounce',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.deepPurple,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.panelPurple,
          brightness: Brightness.dark,
        ),
        fontFamily: 'sans-serif',
      ),
      // Some Android devices/OS versions approximate the system "high
      // contrast text" accessibility setting by underlining all text.
      // The game already uses high-contrast colours by design, so we force
      // this off to avoid unwanted underlines everywhere.
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(highContrast: false),
          child: child!,
        );
      },
      home: const LoadingScreen(),
    );
  }
}
