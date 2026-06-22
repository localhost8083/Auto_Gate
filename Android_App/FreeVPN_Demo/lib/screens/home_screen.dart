import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/home_controller.dart';
import '../controllers/nav_controller.dart';
import '../controllers/servers_controller.dart';
import '../main.dart';
import '../theme/nebula_theme.dart';
import '../widgets/count_down_timer.dart';
import '../widgets/nebula_server_card.dart';
import '../widgets/nebula_widgets.dart';

class HomeTab extends StatelessWidget {
  HomeTab({super.key});

  final _controller = Get.put(HomeController());
  final _servers = Get.put(ServersController());
  final _nav = Get.find<NavController>();

  @override
  Widget build(BuildContext context) {
    mq = MediaQuery.sizeOf(context);

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(),
            SizedBox(height: mq.height * .03),
            Center(child: Obx(() => _ring(context))),
            SizedBox(height: mq.height * .035),
            Obx(() => NebulaServerCard(
                  vpn: _controller.vpn.value,
                  onTap: () => _nav.go(1),
                )),
            const SizedBox(height: 18),
            _featureRow(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        const NebulaMark(size: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
              const SizedBox(height: 2),
              const Text('Unblock. Secure. Freedom.',
                  style: NebulaText.tagline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

  Widget _ring(BuildContext context) {
    final size = mq.width * .62;
    return NebulaConnectRing(
      size: size,
      connected: _controller.isConnected,
      connecting: _controller.isConnecting,
      statusLabel: _controller.statusLabel,
      onTap: () => _controller.toggle(_servers.servers.toList()),
      timer: CountDownTimer(
        startTimer: _controller.isConnected,
        style: NebulaText.timer,
      ),
    );
  }

  Widget _featureRow() {
    final items = [
      _Feature(Icons.verified_user, 'Secure', 'AES-256', NebulaColors.teal),
      _Feature(Icons.lock_outline, 'No Logs', 'Privacy First', NebulaColors.purple),
      _Feature(Icons.public, 'Global', '50+ Locations', NebulaColors.blue),
      _Feature(Icons.bolt, 'Fast', 'Optimized', NebulaColors.orange),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      decoration: BoxDecoration(
        color: NebulaColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NebulaColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: items.map((f) => _featureItem(f)).toList(),
      ),
    );
  }

  Widget _featureItem(_Feature f) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(f.icon, color: f.color, size: 26),
        const SizedBox(height: 8),
        Text(f.title,
            style: const TextStyle(
                color: NebulaColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(f.sub,
            style: const TextStyle(
                color: NebulaColors.textFaint, fontSize: 11)),
      ],
    );
  }
}

class _Feature {
  final IconData icon;
  final String title;
  final String sub;
  final Color color;
  _Feature(this.icon, this.title, this.sub, this.color);
}
