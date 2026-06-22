// VPN server model.
//
// Historically this mapped VPN Gate's CSV columns. It now also understands the
// Auto_Gate validated-server JSON (the `servers[]` records published to GitHub),
// while keeping a symmetric fromJson/toJson so it can still be persisted to Hive
// by the Pref helper.

class Vpn {
  late final String hostname;
  late final String ip;
  late final String ping; // tunnel latency in ms (as string, for display)
  late final int speed; // bytes/sec (derived from throughput for the speed UI)
  late final String countryLong;
  late final String countryShort;
  late final int numVpnSessions;
  late final String openVPNConfigDataBase64;

  // --- Nebula / Auto_Gate enrichment ---
  late final int latencyMs; // tunnel latency in ms (0 if unknown)
  late final int throughputKbps; // measured throughput (0 if unknown)
  late final double reliability; // 0..1
  late final double score; // 0..1 composite ranking score

  // Display serial (1-based rank in the best-first list). Mutable; assigned
  // after the feed loads. Persisted so a restored selection keeps its label.
  int serial = 0;

  Vpn({
    required this.hostname,
    required this.ip,
    required this.ping,
    required this.speed,
    required this.countryLong,
    required this.countryShort,
    required this.numVpnSessions,
    required this.openVPNConfigDataBase64,
    this.latencyMs = 0,
    this.throughputKbps = 0,
    this.reliability = 0,
    this.score = 0,
  });

  /// Hive / internal round-trip (keep keys symmetric with [toJson]).
  Vpn.fromJson(Map<String, dynamic> json) {
    hostname = json['HostName'] ?? '';
    ip = json['IP'] ?? '';
    ping = json['Ping'].toString();
    speed = json['Speed'] ?? 0;
    countryLong = json['CountryLong'] ?? '';
    countryShort = json['CountryShort'] ?? '';
    numVpnSessions = json['NumVpnSessions'] ?? 0;
    openVPNConfigDataBase64 = json['OpenVPN_ConfigData_Base64'] ?? '';
    latencyMs = json['LatencyMs'] ?? 0;
    throughputKbps = json['ThroughputKbps'] ?? 0;
    reliability = (json['Reliability'] ?? 0).toDouble();
    score = (json['Score'] ?? 0).toDouble();
    serial = json['Serial'] ?? 0;
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['HostName'] = hostname;
    data['IP'] = ip;
    data['Ping'] = ping;
    data['Speed'] = speed;
    data['CountryLong'] = countryLong;
    data['CountryShort'] = countryShort;
    data['NumVpnSessions'] = numVpnSessions;
    data['OpenVPN_ConfigData_Base64'] = openVPNConfigDataBase64;
    data['LatencyMs'] = latencyMs;
    data['ThroughputKbps'] = throughputKbps;
    data['Reliability'] = reliability;
    data['Score'] = score;
    data['Serial'] = serial;
    return data;
  }

  /// Build from an Auto_Gate validated-server record (servers.json).
  factory Vpn.fromNebula(Map<String, dynamic> json) {
    final int latency = (json['tunnel_latency_ms'] ??
            json['tcp_latency_ms'] ??
            0) as int;
    final int kbps = (json['throughput_kbps'] ?? 0) as int;
    final double reliability = (json['reliability'] ?? 0).toDouble();
    final double score = (json['score'] ?? 0).toDouble();

    return Vpn(
      hostname: json['host'] ?? json['ip'] ?? '',
      ip: json['ip'] ?? '',
      ping: latency.toString(),
      // kbps (kilobits/s) -> bytes/s for the byte-formatting speed widgets.
      speed: (kbps * 125),
      countryLong: json['country'] ?? 'Unknown',
      countryShort: (json['country_code'] ?? 'XX').toString(),
      numVpnSessions: (reliability * 100).round(),
      openVPNConfigDataBase64: json['ovpn_base64'] ?? '',
      latencyMs: latency,
      throughputKbps: kbps,
      reliability: reliability,
      score: score,
    );
  }
}
