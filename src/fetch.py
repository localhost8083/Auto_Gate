"""
Tier 0a: fetch the raw VPN Gate server list.

The VPN Gate "/api/iphone/" endpoint returns a CSV document (not JSON).
It can be slow or temporarily unavailable, so we retry with backoff and
fall back through a list of mirror URLs.
"""
from __future__ import annotations

import logging
import time

import requests

from . import config

log = logging.getLogger(__name__)

# A valid response contains this marker line near the top.
_MARKER = "*vpn_servers"
_HEADERS = {
    "User-Agent": "Mozilla/5.0 (compatible; AutoGate-VPNGate-Validator/1.0)",
    "Accept": "text/csv,text/plain,*/*",
}


def _looks_valid(text: str) -> bool:
    return bool(text) and _MARKER in text and "OpenVPN_ConfigData_Base64" in text


def fetch_csv() -> str:
    """Return the raw CSV body, or raise RuntimeError if every attempt fails."""
    last_err: Exception | None = None

    for url in config.API_URLS:
        for attempt in range(1, config.FETCH_RETRIES + 1):
            try:
                log.info("Fetching VPN Gate list: %s (attempt %d)", url, attempt)
                resp = requests.get(
                    url, timeout=config.FETCH_TIMEOUT, headers=_HEADERS
                )
                resp.raise_for_status()
                text = resp.text
                if _looks_valid(text):
                    log.info("Fetched %d bytes from %s", len(text), url)
                    return text
                log.warning("Response from %s did not look like a VPN Gate list", url)
                last_err = RuntimeError(f"Unexpected response body from {url}")
            except Exception as exc:  # noqa: BLE001 - we want to retry on anything
                last_err = exc
                log.warning("Fetch failed (%s attempt %d): %s", url, attempt, exc)

            # Exponential-ish backoff between attempts.
            time.sleep(min(2 ** attempt, 15))

    raise RuntimeError(f"All fetch attempts failed; last error: {last_err}")


if __name__ == "__main__":  # pragma: no cover - manual smoke test
    logging.basicConfig(level=logging.INFO)
    body = fetch_csv()
    print(f"Fetched {len(body)} bytes; first line: {body.splitlines()[0]!r}")
