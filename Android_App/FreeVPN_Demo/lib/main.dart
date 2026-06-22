import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:firebase_core/firebase_core.dart';

import 'helpers/pref.dart';
import 'screens/splash_screen.dart';
import 'theme/nebula_theme.dart';

//global object for accessing device screen size
late Size mq;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

  // Local storage (required for persisting the selected server).
  await Pref.initializeHive();

  // Firebase is configured (google-services.json) but non-critical; never let
  // it block or crash app start.
  try {
    await Firebase.initializeApp();
  } catch (e) {
    log('Firebase init skipped: $e');
  }

  await SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'NebulaVPN',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: _nebulaTheme,
      darkTheme: _nebulaTheme,
      home: const SplashScreen(),
    );
  }

  ThemeData get _nebulaTheme => ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: NebulaColors.bg,
        primaryColor: NebulaColors.teal,
        colorScheme: const ColorScheme.dark(
          primary: NebulaColors.teal,
          secondary: NebulaColors.cyan,
          surface: NebulaColors.surface,
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: NebulaColors.surfaceAlt,
          contentTextStyle: TextStyle(color: NebulaColors.textPrimary),
        ),
      );
}
