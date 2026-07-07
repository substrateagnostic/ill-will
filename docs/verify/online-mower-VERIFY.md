# ONLINE PHASE 2 — MOWER MAYHEM game mirror (verification)

*Built to `docs/design/10-online-first-architecture.md` §4.3 and the séance
house pattern (`docs/verify/online-seance-VERIFY.md` PATTERN NOTES). Files
touched: `minigames/mower/mower.gd` (+~230), `minigames/mower/mower_lawn.gd`
(+~45: `grid_packet`/`mirror_apply_grid`/`grid_hash`),
`minigames/mower/mower_unit.gd` (+~25: render-only mirror poses).
`core/net_session.gd` / `estate/estate.gd`: NOT touched.*

## The grid decision (the hard part, priced honestly)

The lawn is a 64x48 = 3072-cell byte grid driving ONE shader texture — the
whole game state in one array. Three replication schemes were considered:

| Scheme | Bandwidth | Failure mode |
|---|---|---|
| (a) full raw grid at 2–4 Hz | 3072 B x 2–4 Hz = **6–12 kB/s** | none (latest wins), but the stripe head lags 250–500 ms behind the mower — visible chunking at 4.2 m/s |
| (b) dirty-row diffs per snapshot | ~0.3–1 kB/s | rides the 20 Hz module pump, which is **unreliable_ordered** — one dropped datagram permanently loses rows; needs an ack/repair layer or a periodic full grid anyway |
| (c) paint events (per-mower cell trails) applied to a client grid | ~0.75 kB/s (≈240 cells/s x 3 B) | same drop problem, PLUS drift: the client would stamp from *interpolated* positions, and steal-bursts/overtime widths must be evented separately; needs full-grid healing anyway |

**Chosen: (a′) — the full grid, deflate-compressed, on every 2nd snapshot
(10 Hz), and on EVERY snapshot during RESULTS.** The insight that changes
the math is that the grid is huge runs of identical owner codes — deflate
crushes 3072 B to a few hundred (measured below). What (a′) buys over the
diff schemes:

- **Self-healing by construction.** Latest-wins full state; a dropped packet
  costs 100 ms of lawn freshness, never a cell, forever. No ack layer, no
  repair pass, no divergence class of bugs. (This is pattern note #4 —
  "counters, not events" — applied to a texture.)
- **Internal consistency.** Every grid arrives beside the mower transforms of
  the same tick: the stripe head is glued to the mower that cut it. At
  10 Hz the head lags at most one pump (~0.2 cells at base speed, cell =
  0.25 m) — sub-cell.
- **Bandwidth, measured on the probe night** (16 `MOWGRID … zbytes=` host
  samples spanning the whole round): the fresh lawn deflates 3072 → **53 B**;
  the packet grows with mix to a **peak of 435 B** at maximum five-symbol
  chop (median 377 B). The non-grid module snapshot rides 512–540 B, so the
  grid adds only ≈3.9 kB/s at its 10 Hz cadence — **≈14.5 kB/s per guest
  total** (vs tilt's ≈21 kB/s), with the ENTIRE 3072-cell lawn on the wire.
  The raw worst case (well-mixed 5-symbol lawn ≈ entropy bound ~1 kB
  deflated) at 10 Hz would still be ~10 kB/s — under scheme (a)'s raw cost
  at HALF the rate.

The mirror re-derives `owner_cells`/`uncut_cells` from each applied grid, so
`coverage_pct()` — and therefore the meter, the scoreboard, and the tally
ceremony — run the exact couch code on mirrored data. Both ends print
`MOWGRID` digests of the raw cells keyed by snapshot seq: the lawn has its
own NETHASH.

## What was built

- **Host sim untouched**; estate pumps `_net_state()` at 20 Hz as with the
  séance and tilt.
- **`_net_state()`** (host): per-mower `[pos, facing, flags(boost/spin/ram/
  spin-dir), fuel]`; round clock + overtime; ram counter + last impact +
  attacker (the mirror's burst/shake); the banner fact; the compressed grid
  (cadence above); and during RESULTS the placements array.
- **`_net_apply()`** (client): mirror `begin()` builds the lawn, obstacles,
  mowers, meter and tally UI exactly as the host (all deterministic,
  seed-free — except gravestone yaw, cosmetic, noted below) and fences only
  bots + the round kick. Juice from deltas: spin-flag rising edge = the hit
  anim; ram-counter delta = clang + confetti-burst at the impact in the
  attacker's color + shake (the banner rides the banner fact; the host's
  slow-mo arrives as a slowed snapshot stream — the mirror never touches
  `Engine.time_scale`); overtime edge = shader pulse + stingers.
- **THE TALLY CEREMONY IS LOCAL.** On the RESULTS edge the mirror receives
  the host's `placements`, stops mirroring the banner, and runs the couch
  `_run_tally()` verbatim on the mirrored final grid: camera pull,
  worst-to-best turf spotlight, 72 pt count-up (`coverage_pct` of the SAME
  cells = the SAME numbers), winner stamp, cheer, confetti. Zero ceremony
  state crosses the wire beyond the placements — the reveal is
  reconstructed, not streamed.
- **`_mirror_tick()`**: 60 fps pos/facing glide (`lerp`/`lerp_angle`, rate
  14); clippings emit while moving; spin lean and ram bounce ride the
  mirrored flags through `MowerUnit.mirror_pose` (couch visual paths).
  The couch `_process` — timer, meter, 5 Hz scoreboard, engine put-put,
  `lawn.commit()` — runs UNMODIFIED on the mirror.
- **Input: ZERO mower code** (PlayerInput per seat; phase-1 relay).
- Hint bar: built from THIS machine's bindings, my seat only.

## Evidence

_(two-instance probe on one machine, spec §7; all screenshots WINDOWED and
read by eye)_

### Commands

```
# host (real selector, mower-only pool, 30 s round so overtime + tally land inside the probe):
g_aa41 --path . --position 60,60  --log-file docs/verify/online-mower-host.log \
      -- --net=host --port=9412 --netprobe=host --pool=mower \
      --seed=7 --roundtime=30 --quitafter=200000 --outdir=docs/verify/mower_netshots_host

# join (launched ~5 s after the host — the seat-0 grant race, see the tilt VERIFY):
g_aa41 --path . --position 700,120 --log-file docs/verify/online-mower-client.log \
      -- --net=join=127.0.0.1:9412 --nettape --netprobe=join \
      --quitafter=200000 --outdir=docs/verify/mower_netshots_join
```

*(`g_aa41` + `--port=9412` + join-after-host stagger: see the tilt VERIFY —
shared-machine defenses against foreign probe clients on 8910 and blanket
Godot taskkills, and the seat-0 grant race.)*

Scripted end-to-end: client connects on 9412 → granted seat 1 (BLUE,
REMOTE) → deterministic tape strolls + READY → host starts the night → GET
READY gate answered over the wire → **MOWER MAYHEM**, a full 30 s round +
overtime + the tally ceremony with a remote seat 1. Host sim:
`begin players=4 seed=3300865038 roundtime=30 bots=[false, false, true,
true]` (seat 0 the host's keyboard human, seat 1 the remote tape, two
bots). The mirror booted on the client (`NET mirror boot: mower` /
`MOWER_MIRROR boot players=4 my_seat=1`) and walked the phases with the
host (`INTRO → PLAY → RESULTS`). The round was rich on the wire: **16
rams** (all `cause=mowed` kill events, `GOLD RAMMED RED!`-class banners
mirrored via the ban fact), the overtime edge at t=18, and the coverage
climb visible in both scoreboards every 5 s. At `rt=30.0` the host entered
RESULTS and the mirror ran the ceremony LOCALLY: `MOWER_MIRROR tally
begins placements=[3, 2, 0, 1]` — camera pull, worst-to-best turf reveal
and count-up staged from the mirrored final grid, closing on the same
winner stamp (host results: MINT 43% of the lawn, `groundskeeper`
monument, points {RED 3, BLUE 2, GOLD 5, MINT 9}). Host
`MOWER_COVERAGE_ASSERT sum=100.0000% -> PASS` mid-run. Module `finished()`
folded the mirror (`NET mirror fold`) → spectate card → mirrored
reckoning → both quit clean: `NETPROBE_RESULTS RED:pts=2,grudge=3
BLUE:pts=1,grudge=4 GOLD:pts=3,grudge=2 MINT:pts=5,grudge=1`, `NETPROBE
saves restored`, `NETPROBE_DONE` / `NETPROBE_CLIENT_DONE`. Full logs:
`online-mower-host.log`, `online-mower-client.log`.

### MOWGRID + NETHASH_MOD — the lawn's own NETHASH (seq-keyed)

- **MOWGRID: 15/15 applied grids digest-identical to the host's** (seq 41
  … 601, `hash(cells)` printed at send and at apply). The host's seq=1
  grid has no client twin — it was pumped during the estate's handoff
  beat, before the client's mirror booted (boot order, not loss); the
  seq=41 grid was the mirror's first and every one after matched.
- NETHASH_MOD (full snapshot digests, every 40th): **15/15 identical.**
  Walker channel: **58/58.** Zero mismatches anywhere in the night.
- **Bandwidth:** non-grid snapshots 512–540 B (`bytes=` at the pump);
  grid-bearing pumps add the deflated lawn (53 → 435 B, median 377); the
  RESULTS pump (grid every snapshot + placements) peaked at 948 B. Total
  **≈14.5 kB/s per guest** at the 20 Hz pump with the 10 Hz grid cadence.

### Screenshots (read by eye)

**The lawn pair — the grid decision, proven on screen:**

- `mower_netshots_host/snap_net_lawn_6644.png` vs
  `mower_netshots_join/snap_mirror_lawn_6056.png` — both fired from the
  same authoritative round clock (`round_t >= 20`, ten seconds left).
  **The lawns match cell for cell**: every stripe, every patch boundary,
  the dark uncut wedge through the center, the light borders around both
  flower beds — identical on both screens. So does everything the grid
  feeds: the scoreboard reads MINT 41% / RED 21% / GOLD 11% / BLUE 9% on
  BOTH sides (the mirror's percentages are re-derived from its own applied
  grid — couch `coverage_pct` on mirrored cells), the same `GOLD RAMMED
  RED!` banner, timer 10, RED's `SPUN!` tag, the same mower positions
  including the GOLD-into-RED collision cluster mid-right. The only
  legible difference across 1280×720: GOLD's fuel reads 81% vs 82% — one
  snapshot beat of staleness on a 0.02-snapped float.

**The tally pair — reconstructed, not streamed:**

- `host/snap_tally_mid_8428.png` vs `join/snap_tally_mid_7828.png` — both
  ceremonies mid-reveal on RED's turf: the same camera pull, the same
  spotlit cells, and the count-up frozen at the same **RED 14%** on both
  screens. Zero ceremony state crossed the wire beyond `placements` —
  identical numbers because `coverage_pct` of identical cells.
- `host/snap_winner_stamp_8594.png` vs `join/snap_winner_stamp_7995.png` —
  the closing frame, functionally pixel-identical: `MINT TAKES THE LAWN!`,
  MINT 43%, MINT's turf spotlit, everyone else's dimmed.

**Flow shots:** `join/snap_online_client_lobby/ready/gate` (phase-1 lobby
mirror), `host/snap_online_host_claim/ready/gate`, the PLAY pair
(`host/snap_online_host_game_3601.png` at the first frame — untouched
lawn, all 0% — vs `join/snap_online_client_game_3054.png` one beat in,
first stripes already cut and every mower on the same corner), and the
paired reckonings (`host/snap_online_host_reckoning_9505.png`,
`join/snap_online_client_reckoning_8910.png`).

### Couch receipts — the transport did not perturb the sim

All baselines from a PRISTINE `git worktree` of HEAD (d0a1f18) vs this tree:

```
godot --headless --path . res://minigames/mower/mower.tscn -- --covtest --seed=5
godot --headless --path . --fixed-fps 60 res://minigames/mower/mower.tscn -- --mowbots --seed=7 --roundtime=30
```

- `--covtest --seed=5`: **PASS on both** (`MOWER_COVERAGE_ASSERT
  sum=100.0000%`), and every `MOWER_EVT`/`KILL_EVENTS`/per-player coverage
  line **byte-identical** (only the `paint_worst/commit_worst` wall-clock
  telemetry inside the status lines differs, as it does between any two runs).
- The seed-7 fixed-fps soak: **every sim line byte-identical** — coverage at
  every 5 s status, all 16 kill_events, the full results JSON (placements,
  points, royalties, grudge, highlights, monuments).
- Both receipts were **re-run in full at the final code state, after the
  probe night** (fresh headless runs, pristine d0a1f18 worktree vs this
  tree): same verdict — covtest 13 sim lines identical, soak 14 sim lines
  identical, `KILL_EVENTS n=16` both sides, the only raw-diff lines being
  the documented wall-clock telemetry.
- **Honest finding, pre-existing:** WITHOUT `--fixed-fps`, the mower soak is
  not run-to-run deterministic — pristine HEAD vs pristine HEAD diverges
  (verified: two baseline runs drift apart by t=15). Cause: the ram slow-mo
  (`Engine.time_scale = 0.4` for a **real-time** 0.22 s timer) makes the
  number of physics ticks inside the slow-mo window wall-clock dependent,
  which advances the bots' RNG stream differently. `--fixed-fps 60` pins
  wall time to frames and restores byte-determinism (same class of noise the
  séance receipt documented for its 0.5 s boot timer). Not introduced by
  this change; not fixed tonight (couch behavior, out of lane).

### Regressions

```
godot --headless --editor --import --quit --path .          # clean (exit 0)
```

## Save discipline

Same as the tilt lane: full `user://` md5 backup before any run, restored
byte-identical after the last (all five hashes re-verified `OK`); the
netprobe's own `.npbak` dance per run. One honest wrinkle from the shared
dev-machine `user://`: the probe pair's two instances both do the `.npbak`
dance on the SAME files, and the later quitter's restore can re-land the
staged 4-seat party (`party_setup.json` came back with seat 1 human). The
outer md5 backup caught it and restored the true pre-run byte state —
which is exactly why the outer backup is house law.

## Honest limitations

- **The lawn on the mirror is at most ~100 ms stale** (10 Hz grid) while the
  mowers ride the 20 Hz pump — the stripe head can trail its mower by up to
  ~2 cells for one pump beat. Invisible at party distance; the MOWGRID
  digests prove the cells themselves are exact.
- **Mirror gravestone yaw differs** (host rolls it from the match seed, the
  mirror boots with seed 0; ±0.3 rad, purely cosmetic — the solid bumper
  circle and the no-mow beds are constants and identical).
- **The tally ceremonies run concurrently, not in lockstep** — each screen
  stages its own reveal from the same facts; they start within a snapshot of
  each other and drift by tween scheduling only. The estate folds the mirror
  when the host's module reports finished, so the mirror's ceremony must fit
  inside the host's ceremony + podium beat (it does — same durations).
- **Ram feel:** the victim sees their own spin-out at snapshot latency
  (spec §4.2 "local echo v1: none").
- The podium after `finished()` is not mirrored (spectate card, phase-3).
- Trust posture: friends-lobby (spec: not an anti-cheat surface).
