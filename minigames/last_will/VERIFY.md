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

## Key receipts (full log in docs/verify/lastwill-v2-VERIFY.md)

```
WILL_TALLY seed=1 races=3 wills=22 curse_kills=6 gust_kills=0 deaths=22
WILL_TALLY seed=2 races=3 wills=13 curse_kills=2 gust_kills=0 deaths=13
WILL_TALLY seed=3 races=3 wills=10 curse_kills=1 gust_kills=0 deaths=10
all nine races reached the crypt (41-55s race clock); byte-identical reruns
WILLTEST squish RESULT: PASS (t=3.90)
LW_VALIDATE problems=0 []
```

## Screenshots (committed in shots/, Godot-ignored; read by eye)

screen_course_overview / screen_will_draft / screen_will_displace /
screen_curse_scythe / screen_curse_grease_crypt / screen_crypt_finish /
screen_ghost_race — regeneration commands in the v2 verify doc.
