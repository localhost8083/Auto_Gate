import 'package:get/get.dart';

import '../apis/apis.dart';
import '../helpers/pref.dart';
import '../models/vpn.dart';
import 'home_controller.dart';

/// Loads the Auto_Gate validated-server feed and keeps the shared list.
/// Also seeds a sensible default server (the best-ranked one) so the home
/// screen has something to connect to on first launch.
class ServersController extends GetxController {
  final RxList<Vpn> servers = <Vpn>[].obs;
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    // Show any cached list immediately, then refresh from network.
    servers.assignAll(Pref.vpnList);
    loadServers();
  }

  Future<void> loadServers() async {
    isLoading.value = true;
    final list = await APIs.getVPNServers();
    if (list.isNotEmpty) servers.assignAll(list);
    isLoading.value = false;
    _ensureDefaultSelected();
  }

  void _ensureDefaultSelected() {
    if (servers.isEmpty) return;
    final home = Get.isRegistered<HomeController>()
        ? Get.find<HomeController>()
        : Get.put(HomeController());
    // If nothing chosen yet, pick the best-ranked (first) server.
    if (home.vpn.value.openVPNConfigDataBase64.isEmpty) {
      select(servers.first);
    }
  }

  void select(Vpn vpn) {
    final home = Get.isRegistered<HomeController>()
        ? Get.find<HomeController>()
        : Get.put(HomeController());
    home.vpn.value = vpn;
    Pref.vpn = vpn;
  }
}
