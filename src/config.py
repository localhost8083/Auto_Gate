"""
Central configuration for the VPN Gate validator pipeline.

Every value can be overridden with an environment variable so the GitHub
Actions workflow can tune behaviour without code changes.
"""
from __future__ import annotations

import os
from pathlib import Path


def _env_int(name: str, default: int) -> int:
    try:
        return int(os.environ.get(name, default))
    except (TypeError, ValueError):
        return default


def _env_float(name: str, default: float) -> float:
    try:
        return float(os.environ.get(name, default))
    except (TypeError, ValueError):
        return default


# --- Paths --------------------------------------------------------------
ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = ROOT / "data"
BY_COUNTRY_DIR = DATA_DIR / "by-country"
STATE_FILE = ROOT / "state" / "history.json"

# --- Output schema ------------------------------------------------------
SCHEMA_VERSION = 1

# --- Source API ---------------------------------------------------------
# VPN Gate returns CSV (despite the /api/iphone/ name). Mirrors are tried
# in order until one returns usable data.
API_URLS = [
    u.strip()
    for u in os.environ.get(
        "VPNGATE_API_URLS",
        "https://www.vpngate.net/api/iphone/,"
        "https://api.vpngate.net/api/iphone/",
    ).split(",")
    if u.strip()
]
FETCH_TIMEOUT = _env_int("FETCH_TIMEOUT", 60)
FETCH_RETRIES = _env_int("FETCH_RETRIES", 4)

# VPN Gate's shared credentials (public, documented on their site).
VPN_USERNAME = os.environ.get("VPN_USERNAME", "vpn")
VPN_PASSWORD = os.environ.get("VPN_PASSWORD", "vpn")

# --- Tier 1 / 2: TCP reachability + latency -----------------------------
TCP_TIMEOUT = _env_float("TCP_TIMEOUT", 5.0)
TCP_CONCURRENCY = _env_int("TCP_CONCURRENCY", 120)
TCP_SAMPLES = _env_int("TCP_SAMPLES", 3)  # connect attempts, median taken
TCP_MAX_LATENCY_MS = _env_int("TCP_MAX_LATENCY_MS", 1500)  # drop sluggish hosts

# --- Tier 3: real OpenVPN egress test -----------------------------------
TIER3_COUNT = _env_int("TIER3_COUNT", 60)        # how many candidates to fully test
OVPN_CONNECT_TIMEOUT = _env_int("OVPN_CONNECT_TIMEOUT", 30)  # secs to reach "Initialization Sequence Completed"
OVPN_CURL_TIMEOUT = _env_int("OVPN_CURL_TIMEOUT", 15)
THROUGHPUT_BYTES = _env_int("THROUGHPUT_BYTES", 1_000_000)  # ~1 MB sample download
THROUGHPUT_ENABLED = os.environ.get("THROUGHPUT_ENABLED", "1") != "0"
# Endpoints used to confirm real egress + measure speed through the tunnel.
EGRESS_IP_URL = os.environ.get("EGRESS_IP_URL", "https://api.ipify.org")
THROUGHPUT_URL = os.environ.get(
    "THROUGHPUT_URL",
    "https://speed.cloudflare.com/__down?bytes={bytes}",
)

# --- Scoring ------------------------------------------------------------
# A server must be seen/pass at least this many runs before its reliability
# is treated as meaningful. Smooths out brand-new servers.
RELIABILITY_MIN_CHECKS = _env_int("RELIABILITY_MIN_CHECKS", 3)
# Drop history entries not seen for this many hours (server gone for good).
HISTORY_TTL_HOURS = _env_int("HISTORY_TTL_HOURS", 24 * 7)
# How many servers land in best.json.
BEST_COUNT = _env_int("BEST_COUNT", 20)
