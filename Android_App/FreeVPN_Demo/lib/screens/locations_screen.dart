import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/home_controller.dart';
import '../controllers/nav_controller.dart';
import '../controllers/servers_controller.dart';
import '../models/vpn.dart';
import '../theme/nebula_theme.dart';
import '../widgets/nebula_server_card.dart';

/// A country and the validated servers we have for it (best-first).
class _Country {
  final String code;
  final String name;
  final List<Vpn> servers;
  _Country(this.code, this.name, this.servers);

  int get bestLatency =>
      servers.map((s) => s.latencyMs).where((l) => l > 0).fold<int>(
            0,
            (min, l) => min == 0 ? l : (l < min ? l : min),
          );
}

class LocationsTab extends StatelessWidget {
  LocationsTab({super.key});

  final _servers = Get.put(ServersController());
  final _home = Get.put(HomeController());
  final _nav = Get.find<NavController>();

  List<_Country> _grouped() {
    final map = <String, _Country>{};
    for (final v in _servers.servers) {
      final c = map.putIfAbsent(
          v.countryShort, () => _Country(v.countryShort, v.countryLong, []));
      c.servers.add(v);
    }
    final list = map.values.toList();
    // Order countries by their best (lowest) latency server.
    list.sort((a, b) => a.bestLatency.compareTo(b.bestLatency));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
            child: Row(
              children: [
                const Text('Locations', style: NebulaText.heading),
                const SizedBox(width: 8),
                Obx(() => Text('(${_grouped().length} countries)',
                    style: NebulaText.cardSub)),
                const Spacer(),
                IconButton(
                  onPressed: () => _servers.loadServers(),
                  icon: const Icon(Icons.refresh, color: NebulaColors.teal),
                ),
              ],
            ),
          ),
          Expanded(
            child: Obx(() {
              if (_servers.isLoading.value && _servers.servers.isEmpty) {
                return const Center(
                    child: CircularProgressIndicator(
                        color: NebulaColors.teal, strokeWidth: 2.5));
              }
              final countries = _grouped();
              if (countries.isEmpty) {
                return const Center(
                    child: Text('No servers available',
                        style: NebulaText.cardSub));
              }
              return RefreshIndicator(
                color: NebulaColors.teal,
                backgroundColor: NebulaColors.surface,
                onRefresh: () => _servers.loadServers(),
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics()),
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                  itemCount: countries.length,
                  itemBuilder: (ctx, i) =>
                      _countryTile(countries[i]),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _countryTile(_Country c) {
    return Obx(() {
      final isCurrent = _home.vpn.value.countryShort == c.code;
      return NebulaCountryTile(
        countryCode: c.code,
        countryName: c.name,
        serverCount: c.servers.length,
        bestLatencyMs: c.bestLatency,
        selected: isCurrent,
        onTap: () {
          _nav.go(0); // jump to Home so the user sees the search progress
          _home.autoConnect(List<Vpn>.from(c.servers));
        },
      );
    });
  }
}
