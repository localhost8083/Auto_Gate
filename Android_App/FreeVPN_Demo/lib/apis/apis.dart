import 'dart:convert';
import 'dart:developer';

import 'package:get/get.dart';
import 'package:http/http.dart';

import '../helpers/my_dialogs.dart';
import '../helpers/pref.dart';
import '../models/ip_details.dart';
import '../models/vpn.dart';

class APIs {
  /// Auto_Gate validated-server feed (best-first, egress-verified servers).
  /// Published hourly-ish by the validator pipeline in this same repo.
  static const _serversUrl =
      'https://raw.githubusercontent.com/localhost8083/Auto_Gate/refs/heads/main/data/servers.json';

  static Future<List<Vpn>> getVPNServers() async {
    final List<Vpn> vpnList = [];

    try {
      final res = await get(Uri.parse(_serversUrl));

      final Map<String, dynamic> data = jsonDecode(res.body);
      final List servers = data['servers'] ?? [];

      for (final s in servers) {
        final vpn = Vpn.fromNebula(s as Map<String, dynamic>);
        // Only keep entries that actually carry a usable OpenVPN config.
        if (vpn.openVPNConfigDataBase64.isNotEmpty) vpnList.add(vpn);
      }

      // Already ranked best-first by the pipeline; keep that order.
      for (var i = 0; i < vpnList.length; i++) {
        vpnList[i].serial = i + 1;
      }
    } catch (e) {
      MyDialogs.error(msg: 'Failed to load servers: $e');
      log('\ngetVPNServersE: $e');
    }

    if (vpnList.isNotEmpty) Pref.vpnList = vpnList;

    return vpnList;
  }

  static Future<void> getIPDetails({required Rx<IPDetails> ipData}) async {
    try {
      final res = await get(Uri.parse('http://ip-api.com/json/'));
      final data = jsonDecode(res.body);
      log(data.toString());
      ipData.value = IPDetails.fromJson(data);
    } catch (e) {
      MyDialogs.error(msg: e.toString());
      log('\ngetIPDetailsE: $e');
    }
  }
}
