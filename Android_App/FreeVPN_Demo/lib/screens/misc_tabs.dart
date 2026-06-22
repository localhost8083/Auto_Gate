import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/home_controller.dart';
import '../theme/nebula_theme.dart';

/// Protection tab — shows the active security posture (static for the demo).
class ProtectionTab extends StatelessWidget {
  ProtectionTab({super.key});

  final _home = Get.put(HomeController());

  @override
  Widget build(BuildContext context) {
    final items = [
      _Item(Icons.verified_user, 'Encryption', 'AES-256-CBC', NebulaColors.teal),
      _Item(Icons.lock_outline, 'No-Logs Policy', 'Enabled', NebulaColors.purple),
      _Item(Icons.shield_moon_outlined, 'Kill Switch', 'Active', NebulaColors.cyan),
      _Item(Icons.dns_outlined, 'DNS Leak Protection', 'On', NebulaColors.green),
      _Item(Icons.bolt, 'Protocol', 'OpenVPN', NebulaColors.orange),
    ];
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        children: [
          const Text('Protection', style: NebulaText.heading),
          const SizedBox(height: 16),
          Obx(() => Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: NebulaColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: _home.isConnected
                          ? NebulaColors.teal
                          : NebulaColors.border),
                ),
                child: Row(
                  children: [
                    Icon(
                        _home.isConnected
                            ? Icons.shield
                            : Icons.shield_outlined,
                        color: _home.isConnected
                            ? NebulaColors.teal
                            : NebulaColors.textFaint,
                        size: 40),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        _home.isConnected
                            ? 'You are protected'
                            : 'Not protected — connect to secure your traffic',
                        style: NebulaText.cardTitle.copyWith(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 16),
          ...items.map(_tile),
        ],
      ),
    );
  }

  Widget _tile(_Item it) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: NebulaColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: NebulaColors.border),
        ),
        child: Row(
          children: [
            Icon(it.icon, color: it.color, size: 22),
            const SizedBox(width: 14),
            Expanded(
                child: Text(it.title,
                    style: const TextStyle(
                        color: NebulaColors.textPrimary, fontSize: 15))),
            Text(it.value,
                style: TextStyle(
                    color: it.color,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

/// Profile tab — minimal placeholder for the demo.
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        children: [
          const Text('Profile', style: NebulaText.heading),
          const SizedBox(height: 20),
          Center(
            child: Column(
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: NebulaGradients.glow,
                  ),
                  child: const Icon(Icons.person, color: Colors.white, size: 48),
                ),
                const SizedBox(height: 14),
                const Text('Guest User', style: NebulaText.cardTitle),
                const SizedBox(height: 4),
                const Text('Free plan', style: NebulaText.cardSub),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ..._rows(),
        ],
      ),
    );
  }

  List<Widget> _rows() {
    final items = [
      [Icons.workspace_premium, 'Upgrade to Premium'],
      [Icons.settings_outlined, 'Settings'],
      [Icons.privacy_tip_outlined, 'Privacy Policy'],
      [Icons.info_outline, 'About NebulaVPN'],
    ];
    return items
        .map((it) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              decoration: BoxDecoration(
                color: NebulaColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: NebulaColors.border),
              ),
              child: Row(
                children: [
                  Icon(it[0] as IconData,
                      color: NebulaColors.teal, size: 22),
                  const SizedBox(width: 14),
                  Expanded(
                      child: Text(it[1] as String,
                          style: const TextStyle(
                              color: NebulaColors.textPrimary, fontSize: 15))),
                  const Icon(Icons.chevron_right,
                      color: NebulaColors.textSecondary),
                ],
              ),
            ))
        .toList();
  }
}

class _Item {
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  _Item(this.icon, this.title, this.value, this.color);
}
