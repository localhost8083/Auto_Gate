"""
Tier 0b: parse the VPN Gate CSV and decode each server's OpenVPN config.

The CSV layout (between the "*vpn_servers" and trailing "*" markers):

    #HostName,IP,Score,Ping,Speed,CountryLong,CountryShort,NumVpnSessions,
     Uptime,TotalUsers,TotalTraffic,LogType,Operator,Message,
     OpenVPN_ConfigData_Base64

The final column is a base64-encoded .ovpn file. We decode it and pull out
the structured fields an Android client needs (remote/port/proto/cipher/...)
while keeping the raw base64 around too.
"""
from __future__ import annotations

import base64
import binascii
import csv
import io
import logging
import re
from dataclasses import dataclass, field, asdict
from typing import Optional

log = logging.getLogger(__name__)

_HEADER_PREFIX = "#"
_LIST_END = "*"


@dataclass
class Server:
    host: str
    ip: str
    country: str
    country_code: str
    port: int
    proto: str                      # "udp" | "tcp"
    ovpn_base64: str
    # Source-reported (advertised) metrics — not yet validated.
    src_score: int = 0
    src_ping: int = 0
    src_speed: int = 0              # bytes/sec advertised by VPN Gate
    num_sessions: int = 0
    uptime_ms: int = 0
    # Parsed from the .ovpn body.
    cipher: Optional[str] = None
    auth: Optional[str] = None
    ca_present: bool = False
    cert_present: bool = False
    tls_auth_present: bool = False
    # Stable identifier used as the history/state key.
    id: str = field(default="")

    def make_id(self) -> str:
        ip_part = self.ip.replace(".", "-").replace(":", "-")
        return f"{self.country_code.lower()}-{ip_part}-{self.port}-{self.proto}"


def _safe_int(value: str) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return 0


def _decode_ovpn(b64: str) -> Optional[str]:
    try:
        return base64.b64decode(b64).decode("utf-8", errors="replace")
    except (binascii.Error, ValueError):
        return None


# Regexes over the decoded .ovpn text.
_RE_REMOTE = re.compile(r"^\s*remote\s+(\S+)\s+(\d+)", re.MULTILINE)
_RE_PROTO = re.compile(r"^\s*proto\s+(tcp|udp)", re.MULTILINE | re.IGNORECASE)
_RE_CIPHER = re.compile(r"^\s*cipher\s+(\S+)", re.MULTILINE | re.IGNORECASE)
_RE_AUTH = re.compile(r"^\s*auth\s+(\S+)", re.MULTILINE | re.IGNORECASE)


def _extract_config_fields(ovpn_text: str) -> dict:
    """Pull remote/port/proto/cipher/etc. out of a decoded .ovpn body."""
    fields: dict = {}

    m = _RE_REMOTE.search(ovpn_text)
    if m:
        fields["remote"] = m.group(1)
        fields["port"] = _safe_int(m.group(2))

    m = _RE_PROTO.search(ovpn_text)
    if m:
        # OpenVPN may write "tcp-client"; normalise to tcp/udp.
        fields["proto"] = "tcp" if m.group(1).lower().startswith("tcp") else "udp"

    m = _RE_CIPHER.search(ovpn_text)
    if m:
        fields["cipher"] = m.group(1)

    m = _RE_AUTH.search(ovpn_text)
    if m:
        fields["auth"] = m.group(1)

    fields["ca_present"] = "<ca>" in ovpn_text
    fields["cert_present"] = "<cert>" in ovpn_text
    fields["tls_auth_present"] = "<tls-auth>" in ovpn_text or "tls-auth" in ovpn_text
    return fields


def parse_csv(csv_text: str) -> list[Server]:
    """Parse the raw CSV into a deduplicated list of Server objects."""
    # Keep only the data region; strip the "*vpn_servers" header line and the
    # trailing "*" terminator. The header row begins with '#'.
    lines = csv_text.splitlines()
    data_lines: list[str] = []
    header: list[str] | None = None

    for line in lines:
        if not line.strip():
            continue
        if line.startswith("*"):           # "*vpn_servers" or trailing "*"
            continue
        if line.startswith(_HEADER_PREFIX):
            header = line[1:].split(",")
            continue
        data_lines.append(line)

    if header is None:
        log.warning("No header row found; using positional parsing")

    reader = csv.reader(io.StringIO("\n".join(data_lines)))
    servers: list[Server] = []
    seen: set[str] = set()

    for row in reader:
        # Expected: 15 columns. Skip malformed rows.
        if len(row) < 15:
            continue
        (
            hostname, ip, score, ping, speed, country_long, country_short,
            num_sessions, uptime, _total_users, _total_traffic, _log_type,
            _operator, _message, ovpn_b64,
        ) = row[:15]

        if not ip or not ovpn_b64:
            continue

        ovpn_text = _decode_ovpn(ovpn_b64)
        if ovpn_text is None:
            continue

        cfg = _extract_config_fields(ovpn_text)
        port = cfg.get("port", 0)
        proto = cfg.get("proto", "udp")
        if not port:
            continue

        srv = Server(
            host=hostname or ip,
            ip=ip,
            country=country_long or "Unknown",
            country_code=(country_short or "XX").upper(),
            port=port,
            proto=proto,
            ovpn_base64=ovpn_b64,
            src_score=_safe_int(score),
            src_ping=_safe_int(ping),
            src_speed=_safe_int(speed),
            num_sessions=_safe_int(num_sessions),
            uptime_ms=_safe_int(uptime),
            cipher=cfg.get("cipher"),
            auth=cfg.get("auth"),
            ca_present=cfg.get("ca_present", False),
            cert_present=cfg.get("cert_present", False),
            tls_auth_present=cfg.get("tls_auth_present", False),
        )
        srv.id = srv.make_id()

        # Dedupe: same IP+port+proto can appear multiple times.
        if srv.id in seen:
            continue
        seen.add(srv.id)
        servers.append(srv)

    log.info("Parsed %d unique servers from CSV", len(servers))
    return servers


def server_to_dict(srv: Server) -> dict:
    return asdict(srv)


if __name__ == "__main__":  # pragma: no cover - manual smoke test
    import sys

    logging.basicConfig(level=logging.INFO)
    raw = sys.stdin.read()
    parsed = parse_csv(raw)
    print(f"{len(parsed)} servers")
    for s in parsed[:5]:
        print(s.id, s.country_code, s.proto, s.port, s.cipher)
