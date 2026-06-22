import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/nav_controller.dart';
import '../controllers/servers_controller.dart';
import '../theme/nebula_theme.dart';
import '../widgets/nebula_widgets.dart';
import 'home_screen.dart';
import 'locations_screen.dart';
import 'misc_tabs.dart';

class MainScreen extends StatelessWidget {
  MainScreen({super.key});

  final _nav = Get.put(NavController());

  @override
  Widget build(BuildContext context) {
    // Ensure servers start loading as soon as the app shell is up.
    Get.put(ServersController());

    final tabs = [HomeTab(), LocationsTab(), ProtectionTab(), const ProfileTab()];

    return Scaffold(
      backgroundColor: NebulaColors.bg,
      body: NebulaBackground(
        child: Obx(() => IndexedStack(index: _nav.index.value, children: tabs)),
      ),
      bottomNavigationBar: _bottomNav(),
    );
  }

  Widget _bottomNav() {
    final items = [
      [Icons.home_rounded, 'Home'],
      [Icons.public, 'Locations'],
      [Icons.shield_outlined, 'Protection'],
      [Icons.person_outline, 'Profile'],
    ];
    return Container(
      decoration: const BoxDecoration(
        color: NebulaColors.surface,
        border: Border(top: BorderSide(color: NebulaColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          child: Obx(() {
            final current = _nav.index.value;
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(items.length, (i) {
                final active = i == current;
                final color =
                    active ? NebulaColors.teal : NebulaColors.textFaint;
                return Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _nav.go(i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(items[i][0] as IconData, color: color, size: 24),
                          const SizedBox(height: 4),
                          Text(items[i][1] as String,
                              style: TextStyle(
                                  color: color,
                                  fontSize: 11,
                                  fontWeight: active
                                      ? FontWeight.w600
                                      : FontWeight.w400)),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            );
          }),
        ),
      ),
    );
  }
}
