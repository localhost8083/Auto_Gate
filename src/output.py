"""
Write the final, app-friendly JSON artifacts.

Outputs (all under data/):
  - servers.json          full validated list with metrics + config
  - best.json             top BEST_COUNT servers (small, fast first-load)
  - by-country/<CC>.json  per-country slices for filtered loading
  - meta.json             counts, schema version, generation timestamp

Only egress-verified servers are written — the whole point is that the app
gets servers that are *proven* to work, ranked fastest/most reliable first.
"""
from __future__ import annotations

import json
import logging
import shutil
from datetime import datetime, timezone

from . import config
from .score import compute_score, reliability_for
from .validate_ovpn import OvpnResult
from .validate_tcp import TcpResult

log = logging.getLogger(__name__)


def _now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace(
        "+00:00", "Z"
    )


def _server_record(
    res: OvpnResult, tcp: TcpResult | None, reliability: float, score: float
) -> dict:
    srv = res.server
    return {
        "id": srv.id,
        "host": srv.host,
        "ip": srv.ip,
        "port": srv.port,
        "proto": srv.proto,
        "country": srv.country,
        "country_code": srv.country_code,
        "tcp_latency_ms": tcp.latency_ms if tcp else None,
        "tunnel_latency_ms": res.tunnel_latency_ms,
        "throughput_kbps": res.throughput_kbps,
        "sessions": srv.num_sessions,
        "egress_ip": res.egress_ip,
        "egress_verified": res.egress_verified,
        "reliability": reliability,
        "score": score,
        "last_validated": _now_iso(),
        "config": {
            "cipher": srv.cipher,
            "auth": srv.auth,
            "ca_present": srv.ca_present,
            "cert_present": srv.cert_present,
            "tls_auth_present": srv.tls_auth_present,
        },
        "ovpn_base64": srv.ovpn_base64,
    }


def _write_json(path, payload) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(payload, fh, indent=2, ensure_ascii=False)
        fh.write("\n")


def build_and_write(
    ovpn_results: dict[str, OvpnResult],
    tcp_by_id: dict[str, TcpResult],
    history: dict,
) -> dict:
    """Build records for verified servers and write all artifacts."""
    records: list[dict] = []
    for sid, res in ovpn_results.items():
        if not res.egress_verified:
            continue
        reliability = reliability_for(history, sid)
        score = compute_score(res, reliability)
        records.append(
            _server_record(res, tcp_by_id.get(sid), reliability, score)
        )

    # Best first: highest score, then lowest tunnel latency.
    records.sort(
        key=lambda r: (-r["score"], r["tunnel_latency_ms"] or 1_000_000)
    )

    generated_at = _now_iso()

    # servers.json
    _write_json(
        config.DATA_DIR / "servers.json",
        {
            "schema_version": config.SCHEMA_VERSION,
            "generated_at": generated_at,
            "count": len(records),
            "servers": records,
        },
    )

    # best.json
    _write_json(
        config.DATA_DIR / "best.json",
        {
            "schema_version": config.SCHEMA_VERSION,
            "generated_at": generated_at,
            "count": min(config.BEST_COUNT, len(records)),
            "servers": records[: config.BEST_COUNT],
        },
    )

    # by-country/<CC>.json — rebuild the directory fresh each run.
    if config.BY_COUNTRY_DIR.exists():
        shutil.rmtree(config.BY_COUNTRY_DIR, ignore_errors=True)
    by_country: dict[str, list[dict]] = {}
    for rec in records:
        by_country.setdefault(rec["country_code"], []).append(rec)
    for cc, recs in by_country.items():
        _write_json(
            config.BY_COUNTRY_DIR / f"{cc}.json",
            {
                "schema_version": config.SCHEMA_VERSION,
                "generated_at": generated_at,
                "country_code": cc,
                "count": len(recs),
                "servers": recs,
            },
        )

    # meta.json
    meta = {
        "schema_version": config.SCHEMA_VERSION,
        "generated_at": generated_at,
        "total_verified": len(records),
        "countries": sorted(by_country.keys()),
        "country_count": len(by_country),
        "best_count": min(config.BEST_COUNT, len(records)),
    }
    _write_json(config.DATA_DIR / "meta.json", meta)

    log.info("Wrote %d verified servers across %d countries",
             len(records), len(by_country))
    return meta


if __name__ == "__main__":  # pragma: no cover
    logging.basicConfig(level=logging.INFO)
    print("output module OK")
