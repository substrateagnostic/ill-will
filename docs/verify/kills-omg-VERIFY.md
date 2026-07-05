# Kill Attribution — Orbital / Mower / Greed (`kill_events`)

Evidence that the three minigames now emit the optional module-contract results
field:

```
kill_events: Array of {killer: int, victim: int, cause: String}
```

`killer` = player index, or `-1` for environment/never-thrown; a self-kill is
reported with `killer == victim` (the honest attribution — the player is their
own thrower). The array is appended **at the exact existing code path that
already credits a royalty/grudge for the kill/KO**, included in the finished
`results` dict, and echoed with a `print("KILL_EVENTS n=", ...)` next to each
game's end-of-match prints.

**Reporting only — determinism preserved.** No append touches bot decisions,
scoring, or physics. In orbital the same seed produced byte-identical kill
timings headless-`--fast=12` vs windowed (see below); mower/greed appends sit
after the royalty `_currency.append` with no control-flow change.

Godot 4.6.2.stable. All commands run from repo root. Import pass after edits:
`godot --headless --editor --import --quit --path .` → exit 0.

Pre-existing environment noise seen in every run (NOT from this change):
missing `btn_green.png` / `error_004.ogg` / the KayKit GLB failing to
`instantiate` in this box — players render as colored orbs but the sim,
kills/KOs, and HUD are intact.

---

## Orbital Dodgeball — cause `"orbit_hit"`

Code path: `_do_kill(pw, bb)` (the pawn dies + respawns; already the
royalty/grudge site). One event per death: `{killer: bb.owner_idx, victim:
pw.index, cause: "orbit_hit"}`.

### Windowed, run to completion (screenshot + KILL_EVENTS in one session)
```
godot --path . res://minigames/orbital/orbital.tscn -- \
  --orbbots --seed=11 --matchsec=40 --shots=900 --quitafter=100000 \
  --outdir=verify_out --autoquit
```
- `KILL t=` lines printed during play: **2** (t=24.4 killer=2→victim=1;
  t=24.9 killer=2→victim=3).
- `KILL_EVENTS n=2` with those same two entries.
- `ORBITAL_SIM ... deaths={0:0,1:1,2:0,3:1}` → deaths sum **2** = n. Consistent.
- Screenshot `verify_out/shot_0900.png` — 3 planets, orbiting trails, scoreboard,
  timer, hint. Nothing visual changed.

### Headless `--fast=12`, full 180s match (cross-check + determinism)
```
godot --headless --path . res://minigames/orbital/orbital.tscn -- \
  --orbbots --seed=11 --fast=12 --autoquit
```
- 27 `KILL t=` lines → `KILL_EVENTS n=27`; `deaths` sum = 6+6+7+8 = **27**.
- Credited `kills={0:6,1:4,2:9,3:3}` (22 non-self) + 5 self-kills
  (killer==victim: p1,p0,p3,p0,p1) = **27**. Every event accounted for.
- First two kills identical to the windowed run above → sim is byte-identical
  across headless/`--fast`/windowed. Determinism holds.

---

## Mower Mayhem — cause `"mowed"`

No lives/eliminations exist, but a **ram** calls `victim.spin_out()` =
`SPINOUT_TIME` (1.2s) loss of control — a genuine down — and is the exact site
that credits the attacker a royalty. Mapped honestly: one event per ram,
`{killer: attacker, victim: victim, cause: "mowed"}`. (Coverage/turf-steal
without a spin-out is NOT an event.)

### Windowed, run to completion
```
godot --path . res://minigames/mower/mower.tscn -- \
  --mowbots --seed=7 --roundtime=30 --shots=900 --quitafter=100000 \
  --outdir=verify_out
```
- Perf line: `total_rams=22`.
- `KILL_EVENTS n=22`.
- Per-player ram counts from the results dump: RED=5, BLUE=4, GOLD=6, MINT=7
  (sum **22**). Per-killer tally in the kill_events JSON: killer0=5, killer1=4,
  killer2=6, killer3=7. **Exact match** — every ram is one attributed KO.
- Screenshot `verify_out/mower_shot.png` — colored coverage stripes, identity
  rings, birdbath/flowerbeds, meter + scoreboard, timer. Nothing visual changed.

---

## Greed Inc. — cause `"mugged"`

Greed has muggings, not kills. A tackle that lands calls `_drop_carrier()` →
`carrier.get_stunned()` (1s stun = a down) and credits the tackler a royalty.
Only that path emits `{killer: tackler, victim: victim, cause: "mugged"}`.
Coin pickups and pot-grabs (mere theft, no down) emit **nothing** — honesty rule.

### Windowed, run to completion — a mugging occurs (seed 3)
```
godot --path . res://minigames/greed/greed.tscn -- \
  --greedbots --seed=3 --rounds=1 --roundtime=45 --shots=900 \
  --quitafter=9999999 --outdir=verify_out
```
(greed has no self-quit; a bash `timeout` is the backstop — it fires *after*
KILL_EVENTS prints, so the run shows EXIT 124 by design.)
- Drop log during play: `drop victim=3 tackler=1 scatter=2 pot=7` (t=15.55).
- `KILL_EVENTS n=1  [{"cause":"mugged","killer":1,"victim":3}]` — killer=1 =
  tackler, victim=3 = MINT. Matches the drop line **and** the currency events
  ("mugged MINT off the pot" royalty p1 / "got mugged" grudge p3).
- Screenshot `verify_out/greed_shot.png` — vault, pot (value 8), glowing chute
  pads, crates, scoreboard, timer. Nothing visual changed.

### Honesty check — no muggings ⇒ no events
- seed 7 (`--roundtime=30`): bots banked (BLUE 18, GOLD 12) but nobody was
  caught → `KILL_EVENTS n=0 []`. No events invented for theft/banking.
- Concurrent headless sweep (`--roundtime=45`): seed 2 → n=0 (0 drops); seed 3
  → n=1 (killer1→victim3); seed 5 → n=1 (killer1→victim0). Count == drop-line
  count in every case.

---

## Summary

| Game    | Cause slug   | KO/kill path            | Verified count (windowed) | Cross-check                          |
|---------|--------------|-------------------------|---------------------------|--------------------------------------|
| Orbital | `orbit_hit`  | `_do_kill` (death)      | n=2 (40s) / n=27 (180s)   | == KILL lines == deaths sum          |
| Mower   | `mowed`      | `_do_ram` (spin-out KO) | n=22                      | == total_rams == Σ per-player rams   |
| Greed   | `mugged`     | `_drop_carrier` (stun)  | n=1 (seed 3)              | == drop lines == royalty/grudge pair |
