"""
Tier 1 + 2: asynchronous TCP reachability and latency measurement.

This is the cheap, massively-parallel pre-filter. For every server we open
a TCP connection to host:port a few times and record the median connect
latency. Servers that never connect, or that connect too slowly, are
dropped before the expensive Tier 3 OpenVPN test.

Note: a UDP OpenVPN server still listens for the handshake, but UDP has no
connection to "open", so for UDP entries we attempt a TCP connect to the
same port as a coarse reachability hint. Many VPN Gate hosts expose the
port on TCP too; those that don't simply fall through to Tier 3 ranked by
their advertised metrics. To keep the signal meaningful we treat a failed
TCP probe on a UDP server as "unknown" rather than "dead".
"""
from __future__ import annotations

import asyncio
import logging
import statistics
import time
from dataclasses import dataclass

from . import config
from .parse import Server

log = logging.getLogger(__name__)


@dataclass
class TcpResult:
    server: Server
    reachable: bool
    latency_ms: int | None  # median of successful samples
    unknown: bool = False   # UDP server we couldn't TCP-probe; not proven dead


async def _connect_once(host: str, port: int, timeout: float) -> float | None:
    """Return connect latency in seconds, or None on failure."""
    start = time.perf_counter()
    try:
        fut = asyncio.open_connection(host, port)
        reader, writer = await asyncio.wait_for(fut, timeout=timeout)
        elapsed = time.perf_counter() - start
        writer.close()
        try:
            await writer.wait_closed()
        except Exception:  # noqa: BLE001 - closing best-effort
            pass
        return elapsed
    except Exception:  # noqa: BLE001 - any failure means "not reachable"
        return None


async def _probe(server: Server, sem: asyncio.Semaphore) -> TcpResult:
    async with sem:
        samples: list[float] = []
        for _ in range(max(1, config.TCP_SAMPLES)):
            latency = await _connect_once(
                server.ip, server.port, config.TCP_TIMEOUT
            )
            if latency is not None:
                samples.append(latency)

        if samples:
            median_ms = int(statistics.median(samples) * 1000)
            reachable = median_ms <= config.TCP_MAX_LATENCY_MS
            return TcpResult(server, reachable, median_ms)

        # No successful TCP connect. For UDP servers this is inconclusive.
        if server.proto == "udp":
            return TcpResult(server, reachable=False, latency_ms=None, unknown=True)
        return TcpResult(server, reachable=False, latency_ms=None)


async def _run(servers: list[Server]) -> list[TcpResult]:
    sem = asyncio.Semaphore(config.TCP_CONCURRENCY)
    tasks = [asyncio.create_task(_probe(s, sem)) for s in servers]
    return await asyncio.gather(*tasks)


def validate_tcp(servers: list[Server]) -> list[TcpResult]:
    """Probe every server; returns a TcpResult per server."""
    if not servers:
        return []
    log.info("Tier 1/2: TCP-probing %d servers (concurrency=%d)",
             len(servers), config.TCP_CONCURRENCY)
    results = asyncio.run(_run(servers))

    reachable = sum(1 for r in results if r.reachable)
    unknown = sum(1 for r in results if r.unknown)
    log.info("Tier 1/2 done: %d reachable, %d unknown(UDP), %d dropped",
             reachable, unknown, len(results) - reachable - unknown)
    return results


def select_candidates(results: list[TcpResult], limit: int) -> list[TcpResult]:
    """
    Pick the best candidates for the expensive Tier 3 test.

    Ranking: confirmed-reachable servers first (lowest TCP latency wins),
    then 'unknown' UDP servers ranked by the source-advertised score as a
    fallback so good UDP-only hosts still get a real test.
    """
    reachable = [r for r in results if r.reachable and r.latency_ms is not None]
    reachable.sort(key=lambda r: r.latency_ms)  # type: ignore[arg-type]

    unknown = [r for r in results if r.unknown]
    unknown.sort(key=lambda r: r.server.src_score, reverse=True)

    ordered = reachable + unknown
    return ordered[:limit]


if __name__ == "__main__":  # pragma: no cover - manual smoke test
    logging.basicConfig(level=logging.INFO)
    demo = [
        Server(host="example.com", ip="93.184.216.34", country="US",
               country_code="US", port=443, proto="tcp", ovpn_base64=""),
    ]
    for r in validate_tcp(demo):
        print(r.server.id, r.reachable, r.latency_ms)
