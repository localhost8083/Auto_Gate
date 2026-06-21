# Auto_Gate — VPN Gate server validator

Fetches the public [VPN Gate](https://www.vpngate.net/) server list every 3 hours,
**really** validates each candidate (not just "is the port open"), and publishes
a clean, versioned JSON feed of the **fastest, working** servers — ready to drop
into an Android (or any) client.

VPN Gate's public credentials are `vpn` / `vpn`.

---

## How validation works (tiered)

VPN Gate lists hundreds of servers per pull. Fully tunnel-testing every one
each hour is too slow, so validation is tiered — cheap checks filter the herd,
the expensive real check confirms only the survivors:

| Tier | Check | Cost | Purpose |
|------|-------|------|---------|
| 0 | Parse CSV + decode `.ovpn` + dedupe | trivial | structure the data |
| 1 | Async TCP reachability | cheap, parallel | drop dead/firewalled hosts |
| 2 | TCP latency (median of N samples) | cheap | rank survivors |
| 3 | **Real OpenVPN connect + egress verification + throughput** | expensive | prove it actually works |

**Tier 3** brings up the tunnel with `openvpn`, waits for
`Initialization Sequence Completed`, then `curl`s an IP-echo endpoint *bound to
the tun interface*. If the returned IP differs from the runner's own public IP,
egress through the tunnel is confirmed. It also measures through-tunnel latency
and pulls ~1 MB to estimate throughput. `--route-nopull` keeps the CI runner's
default route intact so tests run back-to-back safely.

Only **egress-verified** servers make it into the output.

### Reliability scoring
Each run records, per server, how many times it was tested and how many passed
(`state/history.json`). Reliability uses Laplace smoothing
`(passes + 1) / (checks + 2)`, so a server proven across many runs outranks a
lucky one-off. The final ranking `score` blends reliability (40%), latency
(35%), and throughput (25%).

---

## Output files (`data/`)

| File | Contents |
|------|----------|
| `servers.json` | Full validated list, best first |
| `best.json` | Top 20 — small, fast first-load for the app |
| `by-country/<CC>.json` | Per-country slices (e.g. `JP.json`) |
| `meta.json` | Counts, country list, schema version, timestamp |

### Server record shape
```json
{
  "id": "jp-1-2-3-4-1194-udp",
  "host": "public-vpn-123.opengw.net",
  "ip": "1.2.3.4",
  "port": 1194,
  "proto": "udp",
  "country": "Japan",
  "country_code": "JP",
  "tcp_latency_ms": 42,
  "tunnel_latency_ms": 88,
  "throughput_kbps": 5400,
  "egress_ip": "1.2.3.4",
  "egress_verified": true,
  "reliability": 0.92,
  "score": 0.81,
  "last_validated": "2026-06-21T15:00:00Z",
  "config": {
    "cipher": "AES-128-CBC",
    "auth": "SHA1",
    "ca_present": true,
    "cert_present": true,
    "tls_auth_present": true
  },
  "ovpn_base64": "...."
}
```
An Android client can decode `ovpn_base64` directly, inject the `vpn`/`vpn`
credentials, and connect — or use the structured `config` fields.

---

## Automation

`.github/workflows/validate.yml` runs every 3 hours (cron `0 */3 * * *`):
installs OpenVPN, runs the pipeline, and commits `data/` + `state/history.json`
back to the repo **only if something changed**. Trigger manually from the
Actions tab via *Run workflow* (optionally overriding the Tier 3 count).

> The workflow needs `contents: write` permission (already set in the YAML).
> Ensure the repo allows Actions to push: **Settings → Actions → General →
> Workflow permissions → Read and write**.

---

## Running locally

```bash
pip install -r requirements.txt

# Full run (needs openvpn + sudo for Tier 3):
python -m src.main -v

# Parse + TCP only, no tunnel tests (works anywhere, e.g. Windows dev):
python -m src.main --skip-ovpn -v
```

### Tunables
All via environment variables (see `src/config.py`): `TIER3_COUNT`,
`TCP_CONCURRENCY`, `TCP_SAMPLES`, `OVPN_CONNECT_TIMEOUT`, `THROUGHPUT_ENABLED`,
`HISTORY_TTL_HOURS`, `BEST_COUNT`, and more.

---

## Project layout
```
src/
  fetch.py         pull CSV from the VPN Gate API (retries + mirrors)
  parse.py         CSV -> structured servers, decode .ovpn, dedupe
  validate_tcp.py  Tier 1/2 async reachability + latency
  validate_ovpn.py Tier 3 real OpenVPN egress test
  score.py         reliability history + composite scoring
  output.py        write servers/best/by-country/meta JSON
  main.py          pipeline orchestrator
data/              generated JSON (committed)
state/history.json reliability state (committed)
```

## Notes & limitations
- Tier 3 is sequential by design (route safety) and bounded by a wall-clock
  budget (`TIER3_TIME_BUDGET_SEC`, default 30 min), testing up to `TIER3_COUNT`
  (default 150) candidates best-first. If the budget runs out it stops cleanly
  with the most promising servers already verified. Parallel tunnels (separate
  tun devices) or sharding across runners can push coverage higher later.
- Some VPN Gate UDP servers don't answer TCP probes; those are ranked by the
  source-advertised score as a fallback rather than being dropped outright.
- VPN Gate is a volunteer network — servers come and go; that's exactly why the
  reliability score and periodic re-validation matter.

## License
MIT — see [LICENSE](LICENSE). Server configs are public data from VPN Gate.
