# 39 — noray relay: the producer's five-minute deploy (ONLINE ERA, task #91)

*Written 2026-07-22 (overnight online lane). The `transport = "noray"` branch in
`core/net_session.gd` is code-complete and certified against the in-repo mock
(`tools/noray_mock.gd` + `tools/run_noraytest.ps1`). What it still needs from
the world is ONE always-on box running the real relay. This is that recipe.*

## What you get

Guests join with a code (`noray:ABC123`) and NOBODY forwards ports at home:
the relay introduces both sides (NAT punchthrough), and when a hostile router
wins anyway, play rides the relay itself (one extra hop). Direct ENet and the
Steam transport are untouched fallbacks — if the relay box is down, hosting
falls back to plain ENet with one log line, exactly like the Steam seam.

## The software

[`foxssake/noray`](https://github.com/foxssake/noray) — MIT, TypeScript on
Bun, from the netfox family (RB-online §2c has the full evaluation). Small,
active, **no tagged releases** → PIN A COMMIT: check out a SHA you tested,
write it down here, and never `git pull` on game night.

    Pinned commit: ____________________  (fill on deploy night)

## Deploy (Docker route, recommended)

On the always-on Linux box:

```bash
git clone https://github.com/foxssake/noray.git && cd noray
git checkout <PINNED_SHA>
docker compose up -d          # the repo ships docker-compose.yaml
docker compose logs -f        # watch it come up
```

(No Docker? `bun install && bun start` — needs Bun >= 1.x on the box.)

## Ports to open on the RELAY box / its router (once, ever)

| Port | Proto | What |
|---|---|---|
| 8890 | TCP | command channel (register-host / connect) — REQUIRED |
| 8809 | UDP | address registrar (clients send their PID here) — REQUIRED |
| 49152-51200 | UDP | relay data range (used only when punchthrough fails) |
| 8891 | TCP | metrics endpoint — optional, keep LAN-only |

Nobody ELSE forwards anything — that is the whole point. Players' routers
stay untouched.

## Point the game at it

```
godot --path . -- --net=host --transport=noray --relay=relay.example.org:8890
godot --path . -- --net=join=noray:<OID>      --relay=relay.example.org:8890
```

The host's shareable code is printed at host-up (`NET noray host up: guests
join with noray:<OID>`) and rides the lobby card via `invite_code()`. The
relay address will get an estate settings knob in the estate UI pass; until
then it is CLI/config (`NetSession.set_relay()`).

Dev/probe extras: `--net=join=norayrelay:<OID>` skips punchthrough and rides
the relay directly (used by the relay-path certification).

## Smoke test (5 minutes, one machine + the relay)

```powershell
# against the in-repo mock (no relay needed) — should already PASS:
powershell -File tools\run_noraytest.ps1
# against the REAL relay: host + join on one machine, relay in the middle:
godot --headless --path . -- --net=host --transport=noray --relay=<BOX>:8890
#   expect: NET noray host up: guests join with noray:<OID>
godot --headless --path . -- --net=join=noray:<OID> --relay=<BOX>:8890
#   expect: NET noray: punchthrough OK ... NET connected to host as peer <id>
```

Then the real test: a second machine on a different network (phone hotspot
counts) joining `noray:<OID>`.

## Status ledger (keep honest)

- [x] Protocol implemented in `core/net_session.gd` (register/registrar/
      punch/relay-fallback state machine, netfox-compatible `$`-packets)
- [x] Certified against the mock: NAT path + relay path, full estate probe
      (`NORAYTEST VERDICT: PASS` — see VERIFY-BOARD online section)
- [ ] Live relay deployed (this doc) — pending the producer's box
- [ ] Live cross-network session (second machine) — pending deploy
- [ ] Estate UI knob for the relay address — estate settings pass

## Tonight's zero-code alternative (unchanged)

Tailscale (RB-online §2b): everyone installs it once, host shares their
`100.x.x.x` IP, `--net=join=100.x.y.z:8910` — no relay, no port forwarding,
works tonight. The noray path exists so GUESTS someday need nothing but the
game and a code.
