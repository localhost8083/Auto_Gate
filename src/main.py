"""
Pipeline orchestrator.

    fetch CSV
      -> parse + dedupe
      -> Tier 1/2 TCP reachability + latency
      -> select top candidates
      -> Tier 3 real OpenVPN egress test
      -> update reliability history
      -> write servers/best/by-country/meta JSON

Run from the repo root:  python -m src.main
"""
from __future__ import annotations

import argparse
import logging
import sys

from . import config
from .fetch import fetch_csv
from .parse import parse_csv
from .score import load_history, prune_history, save_history, update_history
from .output import build_and_write
from .validate_ovpn import validate_ovpn
from .validate_tcp import select_candidates, validate_tcp


def _setup_logging(verbose: bool) -> None:
    logging.basicConfig(
        level=logging.DEBUG if verbose else logging.INFO,
        format="%(asctime)s %(levelname)-7s %(name)s: %(message)s",
        datefmt="%H:%M:%S",
    )


def run(tier3_count: int, skip_ovpn: bool = False) -> int:
    log = logging.getLogger("main")

    # Tier 0: fetch + parse
    csv_text = fetch_csv()
    servers = parse_csv(csv_text)
    if not servers:
        log.error("No servers parsed from API response; aborting")
        return 1

    # Tier 1/2: TCP reachability + latency
    tcp_results = validate_tcp(servers)
    tcp_by_id = {r.server.id: r for r in tcp_results}
    candidates = select_candidates(tcp_results, tier3_count)
    log.info("Selected %d candidates for Tier 3", len(candidates))

    # Tier 3: real OpenVPN egress test
    if skip_ovpn:
        log.warning("Tier 3 skipped (--skip-ovpn); no servers will be verified")
        ovpn_results = {}
    else:
        ovpn_results = validate_ovpn(candidates)

    # Scoring / history
    history = load_history()
    history = update_history(history, ovpn_results)
    history = prune_history(history)
    save_history(history)

    # Output
    meta = build_and_write(ovpn_results, tcp_by_id, history)
    log.info("Pipeline complete: %d verified servers", meta["total_verified"])
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="VPN Gate validator pipeline")
    parser.add_argument(
        "--tier3-count", type=int, default=config.TIER3_COUNT,
        help="how many top candidates to fully OpenVPN-test",
    )
    parser.add_argument(
        "--skip-ovpn", action="store_true",
        help="skip the real OpenVPN test (parse/TCP only; for local dev)",
    )
    parser.add_argument("-v", "--verbose", action="store_true")
    args = parser.parse_args(argv)

    _setup_logging(args.verbose)
    try:
        return run(args.tier3_count, skip_ovpn=args.skip_ovpn)
    except Exception as exc:  # noqa: BLE001
        logging.getLogger("main").exception("Pipeline failed: %s", exc)
        return 1


if __name__ == "__main__":
    sys.exit(main())
