import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../helpers/my_dialogs.dart';
import '../helpers/pref.dart';
import '../models/vpn.dart';
import '../models/vpn_config.dart';
import '../services/vpn_engine.dart';
import '../theme/nebula_theme.dart';

class HomeController extends GetxController {
  final Rx<Vpn> vpn = Pref.vpn.obs;

  final vpnState = VpnEngine.vpnDisconnected.obs;

  // --- Auto-failover progress state ---
  final RxBool isSearching = false.obs;
  final RxInt attempt = 0.obs;
  final RxInt totalAttempts = 0.obs;
  final RxBool lastRunFailed = false.obs;

  /// How long to wait for a single server to reach "connected" before moving
  /// on to the next candidate. VPN Gate handshakes can be slow, so keep this
  /// generous enough to avoid tearing down a connection that's about to succeed.
  static const Duration _perServerTimeout = Duration(seconds: 18);

  /// Cap how many servers we try in one failover run.
  static const int _maxTries = 8;

  bool _cancelRequested = false;
  StreamSubscription<String>? _stageSub;

  @override
  void onInit() {
    super.onInit();
    // Single, app-wide listener that keeps vpnState in sync with the native
    // engine (used both for UI and to detect failover success).
    _stageSub = VpnEngine.vpnStageSnapshot().listen((event) {
      vpnState.value = event;
    });

    // Backstop: whenever the engine reports a real connection, end any search
    // (handles a "connected" event that arrives slightly late).
    ever<String>(vpnState, (s) {
      if (s == VpnEngine.vpnConnected) {
        isSearching.value = false;
        lastRunFailed.value = false;
      }
    });
  }

  @override
  void onClose() {
    _stageSub?.cancel();
    super.onClose();
  }

  bool get isConnected => vpnState.value == VpnEngine.vpnConnected;
  bool get isConnecting =>
      isSearching.value ||
      (vpnState.value != VpnEngine.vpnConnected &&
          vpnState.value != VpnEngine.vpnDisconnected);

  // ---------------------------------------------------------------------------
  // Config handling
  // ---------------------------------------------------------------------------

  /// Decode the base64 .ovpn and strip directives the bundled OpenVPN
  /// (2.5_master) rejects (e.g. `data-ciphers`), which would otherwise make it
  /// exit instantly.
  String _decodeConfig(Vpn v) {
    final data = const Base64Decoder().convert(v.openVPNConfigDataBase64);
    final config = const Utf8Decoder().convert(data);
    return config
        .split('\n')
        .where((line) {
          final t = line.trim().toLowerCase();
          return !t.startsWith('data-ciphers') &&
              !t.startsWith('data-ciphers-fallback');
        })
        .join('\n');
  }

  Future<void> _startVpn(Vpn v) async {
    final vpnConfig = VpnConfig(
      country: v.countryLong,
      username: 'vpn',
      password: 'vpn',
      config: _decodeConfig(v),
    );
    await VpnEngine.startVpn(vpnConfig);
  }

  // ---------------------------------------------------------------------------
  // Connect / disconnect
  // ---------------------------------------------------------------------------

  /// Entry point from the UI. While searching or connected, a tap stops/cancels;
  /// otherwise it kicks off auto-failover over [candidates].
  void toggle(List<Vpn> candidates) {
    if (isSearching.value) {
      cancelSearch();
      return;
    }
    if (vpnState.value != VpnEngine.vpnDisconnected) {
      VpnEngine.stopVpn();
      return;
    }
    autoConnect(candidates);
  }

  void cancelSearch() {
    _cancelRequested = true;
    isSearching.value = false;
    VpnEngine.stopVpn();
  }

  /// Race through [candidates] (already ranked best-first) and stop on the first
  /// that truly reaches the connected state. Robust against VPN Gate volunteer
  /// churn and per-server session limits.
  Future<void> autoConnect(List<Vpn> candidates) async {
    if (candidates.isEmpty) {
      MyDialogs.info(msg: 'No servers available yet. Pull to refresh Locations.');
      return;
    }
    if (isSearching.value) return;

    _cancelRequested = false;
    isSearching.value = true;
    lastRunFailed.value = false;
    final tries = candidates.length < _maxTries ? candidates.length : _maxTries;
    totalAttempts.value = tries;

    // Drop any existing/half-open connection first.
    if (vpnState.value != VpnEngine.vpnDisconnected) {
      await VpnEngine.stopVpn();
      await Future.delayed(const Duration(milliseconds: 1200));
    }

    for (var i = 0; i < tries; i++) {
      if (_cancelRequested) break;
      attempt.value = i + 1;

      final candidate = candidates[i];
      vpn.value = candidate;
      Pref.vpn = candidate;

      final ok = await _tryConnect(candidate);
      // Treat a connection that completed right around the timeout as success.
      if (ok || vpnState.value == VpnEngine.vpnConnected) {
        isSearching.value = false;
        return;
      }

      // Failed/timed out — tear down before trying the next one.
      await VpnEngine.stopVpn();
      await Future.delayed(const Duration(milliseconds: 1200));
    }

    isSearching.value = false;
    if (!_cancelRequested && vpnState.value != VpnEngine.vpnConnected) {
      await VpnEngine.stopVpn();
      lastRunFailed.value = true;
    }
  }

  /// Start [v] and wait until it either reaches connected (true) or the
  /// per-server timeout elapses (false).
  Future<bool> _tryConnect(Vpn v) async {
    final completer = Completer<bool>();

    // React to native stage changes via the already-synced vpnState.
    final worker = ever<String>(vpnState, (s) {
      if (s == VpnEngine.vpnConnected && !completer.isCompleted) {
        completer.complete(true);
      }
    });

    final timer = Timer(_perServerTimeout, () {
      if (!completer.isCompleted) completer.complete(false);
    });

    try {
      await _startVpn(v);
    } catch (_) {
      if (!completer.isCompleted) completer.complete(false);
    }

    final result = await completer.future;
    timer.cancel();
    worker.dispose();
    return result;
  }

  // ---------------------------------------------------------------------------
  // UI helpers
  // ---------------------------------------------------------------------------

  Color get getButtonColor {
    if (isSearching.value) return NebulaColors.orange;
    if (lastRunFailed.value) return NebulaColors.orange;
    switch (vpnState.value) {
      case VpnEngine.vpnDisconnected:
        return NebulaColors.textFaint;
      case VpnEngine.vpnConnected:
        return NebulaColors.teal;
      default:
        return NebulaColors.orange;
    }
  }

  String get statusLabel {
    if (isSearching.value) return 'Connecting';
    if (vpnState.value == VpnEngine.vpnConnected) return 'Connected';
    if (lastRunFailed.value) return 'Retry';
    if (vpnState.value == VpnEngine.vpnDisconnected) return 'Tap to Connect';
    return vpnState.value.replaceAll('_', ' ');
  }

  String get getButtonText => statusLabel;
}
