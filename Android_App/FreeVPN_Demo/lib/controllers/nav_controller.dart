import 'package:get/get.dart';

/// Holds the selected bottom-navigation tab index so any screen can switch tabs
/// (e.g. the home server card jumping to Locations).
class NavController extends GetxController {
  final RxInt index = 0.obs;
  void go(int i) => index.value = i;
}
