# LAST WILL — verification (v2, the funeral procession race)

A linear 3-segment race over the dusk void — start chapel, winding
graveyard path, THE CRYPT — where DYING IS A POWER: every death freezes
the whole world for six seconds while the deceased drafts ONE CURSE into a
named stretch of the route (author color + name plaque, persists across
races, royalties on kills). Out of lives, the dead drift alongside the
procession on ghost pews and gust the living. First to the crypt inherits.

Full rebuild evidence lives in `docs/verify/lastwill-v2-VERIFY.md`
(determinism receipts, balance history, screenshot log). This file is the
module-local how-to-run.

Root scene: `minigames/last_will/last_will.tscn` (extends `Minigame`,
module id `lastwill`, contract begin/finished unchanged from v1).
Self-starts standalone 0.5s after `_ready` with a default 4-player config
(KayKit chars, colors/names from `GameState`, seed from `--seed=N` or 1).

## Per-player bots (fleet convention)

The bot driver skips roster entries with `"bot": false`; entries without
the key fall back to `PlayerInput.is_bot(index)`. `--willbots` forces
everyone. Racer brain: waypoint follow + blade-gate traffic lights +
one-seeded-roll gap hops (bodies are required) + stones/wall threading +
edge-keeping + shove opportunism near edges and gap lips. Draft brain:
prefer the curse card whose stretch lies just ahead of the race leader
(seeded caprice 25% of the time). Ghost brain: aim at the leader, release
when the push carries void-ward or backward.

## How to run

```
godot --path . minigames/last_will/last_will.tscn                      # humans
godot --path . minigames/last_will/last_will.tscn -- --willbots --seed=3
```

CLI user args (after `--`):
- `--willbots` — every player is a seeded self-play bot
- `--seed=N` (default 1), `--players=N` (2..4), `--willrounds=N` (1..5 races)
- `--willtally` — headless evidence mode: full bot match fast-forwarded
  with dt pinned to 1/60, prints `WILL_TALLY` + `LW_VALIDATE`, quits
- `--willkill=T:P,...` — force-eliminate player P at race-time T (race 1)
- `--willview=overview` — hero survey camera over the whole route
- `--willtest=squish` — self-test: stationary pawn vs an aimed boulder
- `--deadhint` — seat 0 human with ONE life, dies at t=1 (ghost hint demo)
- `--hitkitcap` / `--shovecue` — HIT KIT staging captures (verify-only)
- plus the global `--shots=N,...` / `--outdir=` harness; the module also
  fires event snaps: `snap_draft_*`, `snap_curse_*`, `snap_finish_*`

Import pass after adding res:// files:
```
godot --headless --editor --import --quit --path .
```

## MUST list — all done

- [x] 3-segment course (chapel road / winding yard / ossuary ridge +
      crypt), checkpoints at x=66 and 138, finish plane x=198; built from
      house assets (Meshy pendulum scythe, spinner cross, stone lanterns,
      manor gate, broken columns; Par's spinner/moving-wall language).
- [x] 3 lives, hearts by badge in the HUD + course-progress track with
      gliding PlayerBadge shapes (never color alone).
- [x] Death -> the 6s WILL DRAFT world-freeze (kept from v1: portrait,
      color frame, parchment cards, timer) -> ONE curse onto a named
      stretch -> visible install with author color + name plaque ->
      respawn at last checkpoint.
- [x] Four curse kinds: scythe / grease / gale / stones (caps 2/-/-/3);
      persistence across races; displacement of the oldest resident when
      the slate is full; royalties +2 on curse kills, kill_events cause =
      curse slug, killer = author.
- [x] Out of lives -> ghost pew on the camera rail: v1 gust kit intact
      (right-channel aim, cooldown ring, dead-state hint bar), +1 royalty
      per gust kill.
- [x] First to the crypt ends the race; placements finisher-then-progress;
      points 4/2/1/0 (2P 3/0, 3P 4/2/1); races = min(3, config.rounds),
      practice 1; grudge +1 to dead last.
- [x] Executor lines at draft and crypt (Saki register, no exclamation
      marks).
- [x] Seeded bots run full 4-bot matches to finished() unattended;
      --willtally byte-identical per seed (seeds 1/2/3 proven, twice each).
- [x] HIT KIT + cooldown rings honored unchanged (shove coil/pop/sparks/
      arc/hitstop-throttle, SHOVE+HOP rings, ghost gust ring).

## Key receipts (full log in docs/verify/lastwill-v2-VERIFY.md), PRE v1.1 tune

```
WILL_TALLY seed=1 races=3 wills=22 curse_kills=6 gust_kills=0 deaths=22
WILL_TALLY seed=2 races=3 wills=13 curse_kills=2 gust_kills=0 deaths=13
WILL_TALLY seed=3 races=3 wills=10 curse_kills=1 gust_kills=0 deaths=10
all nine races reached the crypt (41-55s race clock); byte-identical reruns
WILLTEST squish RESULT: PASS (t=3.90)
LW_VALIDATE problems=0 []
```

## v1.1 — TUNING PASS: winner's curse rubber-band (playtest)

Friend playtest note verbatim: *"needs a winners curse — people in last
place move a little faster to catch up."*

**Mechanism (`last_will.gd`):** the per-tick terrain-modifier reset (which
already zeroed every pawn's `terrain_speed`/`terrain_accel` back to 1.0
before curses re-applied theirs on top — see `lw_pawn.gd`'s own header
comment on this exact pattern) now seeds `terrain_speed` from a rubber-band
baseline instead of a flat `1.0`. Each tick: `leader_x = max(best_x)` across
the whole roster (dead or alive — `best_x` is a permanent high-water mark,
so a racer who already finished still anchors the reference); each living
racer's `gap = leader_x - best_x[i]`; `bonus = clamp(gap / 25.0, 0, 1) *
0.18`; `terrain_speed = 1.0 + bonus`. Curses still multiply on top exactly
as before (`*= 1.06` etc.) — this only changes the BASELINE they multiply
against.

**Capped, never faster than a leader sprinting:** `RUBBERBAND_MAX_BONUS =
0.18` (max +18% speed, saturating at 25m behind — about a third of a
66-72m course segment). A trailing racer's ceiling is `1.18x MOVE_SPEED`,
comfortably under a leader's own full, uncursed sprint headroom — the bonus
narrows gaps, it doesn't let someone from the back teleport past a leader
who is actually racing well.

**Announced on the intro card:** new `spec["legend"]` (reusing the static
legend field added to `core/ui_kit/intro_card.gd` for Orbital's scoring key,
same M3 lane) reads *"THE WINNER'S CURSE: fall behind, run a little faster
(capped — never faster than a leader sprinting)."*

**Receipt — deliberate-change doctrine.** This changes movement speed, so
downstream bot-soak numbers move (races resolve faster overall since
laggards catch up, changing hazard/curse exposure windows):
```
godot --headless --path . minigames/last_will/last_will.tscn -- --willbots --willtally --seed=N
```
| seed | OLD (pre-tune) | NEW (v1.1) |
|---|---|---|
| 1 | `wills=22 curse_kills=6 deaths=22` | `wills=13 curse_kills=3 deaths=13` |
| 2 | `wills=13 curse_kills=2 deaths=13` | `wills=4 curse_kills=0 deaths=4` |
| 3 | `wills=10 curse_kills=1 deaths=10` | `wills=14 curse_kills=2 deaths=14` |

All nine races (3 seeds x 3 races) still reach the crypt cleanly — race
clocks now cluster 41.4-50.0s (vs the old 41-55s spread; the top end
compressed since laggards no longer drag races out). `TALLY_RESULT PASS`
for every seed, full valid `LW_RESULTS` (placements/points/currency_events/
highlights/monuments) each time, `LW_VALIDATE problems=0`. Determinism
re-verified: seed=1 run twice, byte-identical `WILL_TALLY`/`LW_RESULTS`
output. `WILLTEST squish RESULT: PASS (t=3.90)` — unchanged (the self-test's
single stationary pawn has zero gap-behind-itself, so the rubber-band
contributes nothing there).

**Screenshot:** `verify_out/lastwill_m3_final/lastwill_winners_curse_intro.png`
— the intro card showing the new legend line under the existing rotating tip.

## Screenshots (committed in shots/, Godot-ignored; read by eye)

screen_course_overview / screen_will_draft / screen_will_displace /
screen_curse_scythe / screen_curse_grease_crypt / screen_crypt_finish /
screen_ghost_race — regeneration commands in the v2 verify doc.
