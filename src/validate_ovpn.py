"""
Tier 3: the real OpenVPN egress test.

For each top candidate we actually bring up the tunnel and prove that
traffic egresses through it:

  1. Write the decoded .ovpn plus extra directives (auth, no route hijack).
  2. Launch `openvpn` (via sudo) and wait for
     "Initialization Sequence Completed".
  3. Detect the tun interface name from the OpenVPN log.
  4. curl an IP-echo endpoint *bound to the tun interface* — if it returns
     an IP that differs from the runner's own public IP, egress through the
     tunnel is confirmed. We also record the through-tunnel latency.
  5. Optionally pull ~1 MB through the tunnel to estimate throughput.
  6. Tear the tunnel down and clean up temp files.

We use `--route-nopull` so the runner's default route is never hijacked;
binding curl to the tun device (SO_BINDTODEVICE) forces the probe traffic
through the tunnel without disturbing the host. This keeps the CI runner
healthy and lets the tests run one after another safely.
"""
from __future__ import annotations

import logging
import os
import re
import shutil
import signal
import subprocess
import tempfile
import time
from dataclasses import dataclass

import requests

from . import config
from .parse import Server
from .validate_tcp import TcpResult

log = logging.getLogger(__name__)

_INIT_DONE = "Initialization Sequence Completed"
_RE_TUN = re.compile(r"\b(tun\d+)\b")
_EXTRA_DIRECTIVES = [
    "route-nopull",
    'pull-filter ignore "redirect-gateway"',
    "connect-retry 1",
    "connect-retry-max 1",
    "resolv-retry 0",
    "nobind",
    "verb 3",
]


@dataclass
class OvpnResult:
    server: Server
    egress_verified: bool = False
    egress_ip: str | None = None
    tunnel_latency_ms: int | None = None
    throughput_kbps: int | None = None
    error: str | None = None


def openvpn_available() -> bool:
    return shutil.which("openvpn") is not None


def get_baseline_ip() -> str | None:
    """The runner's own public IP, used to confirm the tunnel changes egress."""
    try:
        resp = requests.get(config.EGRESS_IP_URL, timeout=10)
        resp.raise_for_status()
        return resp.text.strip()
    except Exception as exc:  # noqa: BLE001
        log.warning("Could not determine baseline public IP: %s", exc)
        return None


def _write_config(server: Server, workdir: str) -> tuple[str, str]:
    """Write the .ovpn and credentials files; return (config_path, creds_path)."""
    import base64

    ovpn_text = base64.b64decode(server.ovpn_base64).decode("utf-8", errors="replace")

    creds_path = os.path.join(workdir, "creds.txt")
    with open(creds_path, "w", encoding="utf-8") as fh:
        fh.write(f"{config.VPN_USERNAME}\n{config.VPN_PASSWORD}\n")

    config_path = os.path.join(workdir, "server.ovpn")
    with open(config_path, "w", encoding="utf-8") as fh:
        fh.write(ovpn_text.rstrip() + "\n")
        fh.write(f"auth-user-pass {creds_path}\n")
        for directive in _EXTRA_DIRECTIVES:
            fh.write(directive + "\n")
    return config_path, creds_path


def _curl_through_tun(iface: str, url: str, timeout: int) -> tuple[str | None, float | None]:
    """
    Run curl bound to the tun interface.
    Returns (stdout_body, time_total_seconds) or (None, None) on failure.
    """
    cmd = [
        "curl", "--silent", "--show-error", "--interface", iface,
        "--max-time", str(timeout),
        "--write-out", "\n%{time_total}",
        url,
    ]
    try:
        proc = subprocess.run(
            cmd, capture_output=True, text=True, timeout=timeout + 5
        )
        if proc.returncode != 0:
            return None, None
        out = proc.stdout.rsplit("\n", 1)
        if len(out) != 2:
            return proc.stdout.strip(), None
        body, t_total = out
        try:
            return body.strip(), float(t_total)
        except ValueError:
            return body.strip(), None
    except Exception:  # noqa: BLE001
        return None, None


def _throughput_once(iface: str) -> int | None:
    """Single throughput sample through the tunnel; return kbps or None."""
    url = config.THROUGHPUT_URL.format(bytes=config.THROUGHPUT_BYTES)
    cmd = [
        "curl", "--silent", "--show-error", "--interface", iface,
        "--max-time", str(config.OVPN_CURL_TIMEOUT),
        "--output", os.devnull,
        "--write-out", "%{size_download} %{time_total}",
        url,
    ]
    try:
        proc = subprocess.run(
            cmd, capture_output=True, text=True,
            timeout=config.OVPN_CURL_TIMEOUT + 5,
        )
        if proc.returncode != 0:
            return None
        size_str, time_str = proc.stdout.split()
        size = float(size_str)
        secs = float(time_str)
        if secs <= 0 or size <= 0:
            return None
        return int((size * 8 / 1000) / secs)  # kilobits per second
    except Exception:  # noqa: BLE001
        return None


def _throughput_through_tun(iface: str) -> int | None:
    """
    Measure throughput through the tunnel, retrying once on failure.

    The first sample sometimes fails on a freshly-established tunnel (the
    server is still settling, or a transient curl error), so a single retry
    recovers most of those without materially slowing the run.
    """
    result = _throughput_once(iface)
    if result is None:
        result = _throughput_once(iface)
    return result


def _test_one(server: Server, baseline_ip: str | None) -> OvpnResult:
    result = OvpnResult(server=server)
    workdir = tempfile.mkdtemp(prefix="ovpn_")
    log_path = os.path.join(workdir, "ovpn.log")
    proc: subprocess.Popen | None = None
    try:
        config_path, _ = _write_config(server, workdir)
        log_fh = open(log_path, "w", encoding="utf-8")
        proc = subprocess.Popen(
            ["sudo", "openvpn", "--config", config_path],
            stdout=log_fh, stderr=subprocess.STDOUT,
            cwd=workdir, start_new_session=True,
        )

        # Wait for tunnel init (or process death / timeout).
        iface: str | None = None
        deadline = time.monotonic() + config.OVPN_CONNECT_TIMEOUT
        initialized = False
        while time.monotonic() < deadline:
            if proc.poll() is not None:
                result.error = "openvpn exited before init"
                break
            try:
                with open(log_path, "r", encoding="utf-8", errors="replace") as fh:
                    content = fh.read()
            except OSError:
                content = ""
            if iface is None:
                m = _RE_TUN.search(content)
                if m:
                    iface = m.group(1)
            if _INIT_DONE in content:
                initialized = True
                break
            time.sleep(0.5)

        if not initialized:
            result.error = result.error or "init timeout"
            return result
        if iface is None:
            result.error = "tunnel up but no tun interface detected"
            return result

        # Egress verification.
        body, t_total = _curl_through_tun(
            iface, config.EGRESS_IP_URL, config.OVPN_CURL_TIMEOUT
        )
        if body:
            ip = body.strip().splitlines()[-1].strip()
            result.egress_ip = ip
            # Verified if we got an IP and it differs from the runner's own.
            if baseline_ip is None or ip != baseline_ip:
                result.egress_verified = bool(re.match(r"^\d{1,3}(\.\d{1,3}){3}$", ip))
            if t_total is not None:
                result.tunnel_latency_ms = int(t_total * 1000)

        # Throughput (only if egress verified, to avoid wasting time).
        if result.egress_verified and config.THROUGHPUT_ENABLED:
            result.throughput_kbps = _throughput_through_tun(iface)

        return result
    except Exception as exc:  # noqa: BLE001
        result.error = f"{type(exc).__name__}: {exc}"
        return result
    finally:
        if proc is not None and proc.poll() is None:
            try:
                # Kill the whole process group (openvpn may fork).
                os.killpg(os.getpgid(proc.pid), signal.SIGTERM)
            except Exception:  # noqa: BLE001
                pass
            try:
                subprocess.run(["sudo", "pkill", "-TERM", "-f", "openvpn --config"],
                               timeout=10)
            except Exception:  # noqa: BLE001
                pass
            try:
                proc.wait(timeout=10)
            except Exception:  # noqa: BLE001
                pass
        shutil.rmtree(workdir, ignore_errors=True)


def validate_ovpn(candidates: list[TcpResult]) -> dict[str, OvpnResult]:
    """
    Run the real tunnel test sequentially over the candidate list.
    Returns a map of server.id -> OvpnResult.
    """
    results: dict[str, OvpnResult] = {}
    if not candidates:
        return results

    if not openvpn_available():
        log.error("openvpn binary not found; skipping Tier 3 (all egress unverified)")
        for c in candidates:
            results[c.server.id] = OvpnResult(
                server=c.server, error="openvpn not installed"
            )
        return results

    baseline_ip = get_baseline_ip()
    budget = config.TIER3_TIME_BUDGET_SEC
    log.info("Tier 3: testing up to %d candidates (baseline IP=%s, budget=%ss)",
             len(candidates), baseline_ip, budget)

    started = time.monotonic()
    tested = 0
    for idx, cand in enumerate(candidates, 1):
        # Stop cleanly if we've spent the time budget — candidates are already
        # ordered best-first, so we always test the most promising ones.
        elapsed = time.monotonic() - started
        if budget and elapsed >= budget:
            log.warning("Tier 3 time budget reached (%.0fs); tested %d/%d, "
                        "skipping the remaining %d candidates",
                        elapsed, tested, len(candidates), len(candidates) - tested)
            break

        srv = cand.server
        res = _test_one(srv, baseline_ip)
        results[srv.id] = res
        tested += 1
        status = "OK" if res.egress_verified else f"FAIL({res.error})"
        log.info("[%d/%d] %s %s lat=%sms tput=%skbps",
                 idx, len(candidates), srv.id, status,
                 res.tunnel_latency_ms, res.throughput_kbps)

    verified = sum(1 for r in results.values() if r.egress_verified)
    log.info("Tier 3 done: %d/%d egress-verified in %.0fs",
             verified, tested, time.monotonic() - started)
    return results


if __name__ == "__main__":  # pragma: no cover - manual smoke test
    logging.basicConfig(level=logging.INFO)
    print("openvpn available:", openvpn_available())
    print("baseline ip:", get_baseline_ip())
