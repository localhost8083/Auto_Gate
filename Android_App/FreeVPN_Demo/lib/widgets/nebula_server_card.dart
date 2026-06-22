import 'package:flutter/material.dart';

import '../models/vpn.dart';
import '../theme/nebula_theme.dart';

/// Small signal-strength bars; more bars + greener for lower latency.
class SignalBars extends StatelessWidget {
  final int latencyMs;
  const SignalBars({super.key, required this.latencyMs});

  int get _strength {
    if (latencyMs <= 0) return 2;
    if (latencyMs < 600) return 4;
    if (latencyMs < 1200) return 3;
    if (latencyMs < 2500) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final strength = _strength;
    final color = strength >= 3 ? NebulaColors.green : NebulaColors.orange;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (i) {
        final on = i < strength;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          width: 4,
          height: 6.0 + i * 4,
          decoration: BoxDecoration(
            color: on ? color : NebulaColors.border,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}

Widget _flag(String cc, {double size = 44}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: Image.asset(
      'assets/flags/${cc.toLowerCase()}.png',
      width: size,
      height: size * 0.72,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        width: size,
        height: size * 0.72,
        color: NebulaColors.surfaceAlt,
        child: const Icon(Icons.public, color: NebulaColors.textSecondary),
      ),
    ),
  );
}

/// The selected-server summary card shown on the Home tab.
class NebulaServerCard extends StatelessWidget {
  final Vpn vpn;
  final VoidCallback onTap;
  const NebulaServerCard({super.key, required this.vpn, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasServer = vpn.countryLong.isNotEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: NebulaColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: NebulaColors.border),
        ),
        child: Row(
          children: [
            _flag(hasServer ? vpn.countryShort : 'us'),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(hasServer ? vpn.countryLong : 'Select a server',
                      style: NebulaText.cardTitle,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(
                    hasServer
                        ? (vpn.serial > 0 ? 'Server ${vpn.serial}' : 'Server')
                        : 'Tap to choose',
                    style: NebulaText.cardSub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SignalBars(latencyMs: vpn.latencyMs),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: NebulaColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

/// Row tile used in the Locations list.
class NebulaServerTile extends StatelessWidget {
  final Vpn vpn;
  final bool selected;
  final VoidCallback onTap;
  const NebulaServerTile({
    super.key,
    required this.vpn,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: NebulaColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: selected ? NebulaColors.teal : NebulaColors.border,
              width: selected ? 1.4 : 1),
        ),
        child: Row(
          children: [
            _flag(vpn.countryShort, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(vpn.countryLong,
                      style: NebulaText.cardTitle.copyWith(fontSize: 16),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(vpn.hostname,
                      style: NebulaText.cardSub,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(vpn.latencyMs > 0 ? '${vpn.latencyMs} ms' : '—',
                    style: const TextStyle(
                        color: NebulaColors.green,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                SignalBars(latencyMs: vpn.latencyMs),
              ],
            ),
          ],
        ),
      ),
    );
  }
}



/// Country row tile for the grouped Locations list.
class NebulaCountryTile extends StatelessWidget {
  final String countryCode;
  final String countryName;
  final int serverCount;
  final int bestLatencyMs;
  final bool selected;
  final VoidCallback onTap;

  const NebulaCountryTile({
    super.key,
    required this.countryCode,
    required this.countryName,
    required this.serverCount,
    required this.bestLatencyMs,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: NebulaColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: selected ? NebulaColors.teal : NebulaColors.border,
              width: selected ? 1.4 : 1),
        ),
        child: Row(
          children: [
            _flag(countryCode, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(countryName,
                      style: NebulaText.cardTitle.copyWith(fontSize: 16),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                      '$serverCount server${serverCount == 1 ? '' : 's'} available',
                      style: NebulaText.cardSub),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SignalBars(latencyMs: bestLatencyMs),
              ],
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, color: NebulaColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
