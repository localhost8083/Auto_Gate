import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/route_manager.dart';

import '../theme/nebula_theme.dart';
import '../widgets/nebula_widgets.dart';
import 'main_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1600), () {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      Get.off(() => MainScreen());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NebulaColors.bg,
      body: NebulaBackground(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const NebulaMark(size: 96),
              const SizedBox(height: 22),
              RichText(
                text: const TextSpan(children: [
                  TextSpan(text: 'Nebula', style: NebulaText.heading),
                  TextSpan(
                      text: 'VPN',
                      style: TextStyle(
                          color: NebulaColors.cyan,
                          fontSize: 24,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
              const SizedBox(height: 8),
              const Text('Unblock. Secure. Freedom.',
                  style: NebulaText.tagline),
            ],
          ),
        ),
      ),
    );
  }
}
