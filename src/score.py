"""
Historical reliability scoring with persisted state.

Each pipeline run records, per server id, how many times it was Tier-3
tested ("checks") and how many of those passed egress verification
("passes"). Reliability uses Laplace smoothing so brand-new servers aren't
unfairly rated 0% or 100% off a single sample:

    reliability = (passes + 1) / (checks + 2)

Stale entries (servers not seen for HISTORY_TTL_HOURS) are pruned so the
state file stays small and meaningful.
"""
from __future__ import annotations

import json
import logging
from datetime import datetime, timedelta, timezone

from . import config
from .validate_ovpn import OvpnResult

log = logging.getLogger(__name__)


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _iso(dt: datetime) -> str:
    return dt.replace(microsecond=0).isoformat().replace("+00:00", "Z")


def load_history() -> dict:
    try:
        with open(config.STATE_FILE, "r", encoding="utf-8") as fh:
            data = json.load(fh)
        if not isinstance(data, dict) or "servers" not in data:
            raise ValueError("malformed state")
        return data
    except (OSError, ValueError, json.JSONDecodeError):
        log.warning("No usable history found; starting fresh")
        return {"schema_version": config.SCHEMA_VERSION, "servers": {}}


def save_history(history: dict) -> None:
    config.STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(config.STATE_FILE, "w", encoding="utf-8") as fh:
        json.dump(history, fh, indent=2, sort_keys=True)
        fh.write("\n")


def update_history(history: dict, ovpn_results: dict[str, OvpnResult]) -> dict:
    """Fold this run's Tier-3 results into the persisted history."""
    now = _now()
    now_iso = _iso(now)
    servers = history.setdefault("servers", {})

    for sid, res in ovpn_results.items():
        entry = servers.setdefault(
            sid, {"checks": 0, "passes": 0, "last_seen": None, "last_pass": None}
        )
        entry["checks"] += 1
        entry["last_seen"] = now_iso
        if res.egress_verified:
            entry["passes"] += 1
            entry["last_pass"] = now_iso

    history["schema_version"] = config.SCHEMA_VERSION
    return history


def prune_history(history: dict) -> dict:
    """Drop entries not seen within the TTL window."""
    cutoff = _now() - timedelta(hours=config.HISTORY_TTL_HOURS)
    servers = history.get("servers", {})
    keep: dict = {}
    for sid, entry in servers.items():
        last_seen = entry.get("last_seen")
        if not last_seen:
            continue
        try:
            seen_dt = datetime.fromisoformat(last_seen.replace("Z", "+00:00"))
        except ValueError:
            continue
        if seen_dt >= cutoff:
            keep[sid] = entry
    removed = len(servers) - len(keep)
    if removed:
        log.info("Pruned %d stale history entries", removed)
    history["servers"] = keep
    return history


def reliability_for(history: dict, sid: str) -> float:
    entry = history.get("servers", {}).get(sid)
    if not entry:
        return 0.0
    checks = entry.get("checks", 0)
    passes = entry.get("passes", 0)
    if checks <= 0:
        return 0.0
    return round((passes + 1) / (checks + 2), 4)


def _clamp01(x: float) -> float:
    return max(0.0, min(1.0, x))


def compute_score(result: OvpnResult, reliability: float) -> float:
    """
    Composite 0..1 ranking score. Only meaningful for egress-verified servers.
    Weights: reliability 35%, latency 30%, throughput 20%, load (free capacity) 15%.
    """
    if not result.egress_verified:
        return 0.0

    # `tunnel_latency_ms` is a full through-tunnel HTTPS request time
    # (DNS + TCP + TLS + GET), not a raw RTT — for volunteer VPNs it commonly
    # lands in the hundreds of ms to a couple of seconds, so we calibrate
    # against a ~3 s ceiling rather than 1 s.
    latency_ms = result.tunnel_latency_ms
    latency_score = _clamp01(1 - (latency_ms / 3000)) if latency_ms else 0.0

    # Reward measured throughput up to ~10 Mbps. A failed/absent throughput
    # sample gets a small penalty value (NOT a neutral midpoint) so that a
    # server we could actually measure as fast outranks one we couldn't —
    # the whole point of the feed is "fastest, *proven* working".
    tput = result.throughput_kbps
    tput_score = _clamp01(tput / 10000) if tput else 0.1

    # Load / free capacity: VPN Gate servers cap concurrent sessions and refuse
    # new connections when full. Fewer current sessions => more likely to accept
    # a fresh connection, so deprioritise crowded servers. ~64 sessions -> 0.
    sessions = getattr(result.server, "num_sessions", 0) or 0
    load_score = _clamp01(1 - (sessions / 64))

    score = (
        0.35 * reliability
        + 0.30 * latency_score
        + 0.20 * tput_score
        + 0.15 * load_score
    )
    return round(score, 4)
