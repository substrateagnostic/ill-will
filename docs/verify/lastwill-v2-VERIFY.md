# LAST WILL v2 — the funeral procession race (rebuild verification)

Date: 2026-07-06. Owner call after two playtests: the sumo-circle body was
too close to Dead Weight — KEEP the death-drafting soul, change the body to
a Fall Guys-style obstacle gauntlet. Rebuilt IN PLACE: same module id
`lastwill`, same scene `res://minigames/last_will/last_will.tscn`, same
`begin(config)` / `finished(results)` contract.

## What the game is now

A linear 3-segment funeral procession race over the dusk void: start
chapel -> winding graveyard path -> THE CRYPT (x 0..198, checkpoints at 66
and 138). 3 lives each. DIE (hazard, void, shove, gust) and the whole world
FREEZES for the six-second WILL DRAFT — the anthology's best screen,
preserved: memorial portrait with black ribbon, deceased-color frame, three
parchment cards, draining timer. The deceased picks ONE CURSE card; each
card = a curse kind + a NAMED STRETCH of the route (nine stretches, from
THE LYCHGATE ROAD to THE CRYPT STEPS):

- **SUMMON THE SCYTHE** — an endless pendulum blade over the stretch
- **GREASE THE FLAGSTONES** — accel crushed to 22%, momentum keeps
- **A GUST CORRIDOR** — a crosswind bursts void-ward every 3.4s
- **RAISE THE DEAD** — a rank of gravestones blocks all but one gap

The curse installs visibly in the author's color with a **name plaque**
(trimmed headstone + `◆ MINT / GREASED FLAGSTONES` tag — authorship
forever, like Par's traps), persists across races (the course accretes),
and pays the author **+2 royalties** on kills within 3s of a curse touch
(`kill_events` cause = the curse slug, killer = the author). Caps: max 2
scythes + 3 stones active; a full slate offers displacement of the oldest
resident (card says "displaces MINT's ...").

Out of lives -> ghost pew that DRIFTS ALONGSIDE the race on the camera
rail: existing gust kit (right-channel aim, 10s cooldown ring, dead-state
hint bar), gust kills pay +1. First to the crypt ends the race; placements
= finisher, then furthest progress. Points 4/2/1/0 per race; races from
config (cap 3, practice 1). Grudge +1 to dead last each race.

Base hazards (built from house assets): rolling boulders across 4 lanes,
3 endless scythe gates (Meshy pendulum_blade), the graveyard sweeper
(Par's spinner language, Meshy spinner_arms — swats, never kills), two
sliding wall pushers (Par's moving-wall language) on the 1.9-halfwidth
ossuary ridge, two hop-or-fall gaps, stone lanterns + lychgates + a
glowing crypt facade (manor_gate + broken_column).

EXECUTOR lines (Saki register, no exclamation marks): draft — "The
deceased has opinions about the route."; crypt — "The first to the crypt
inherits. The estate finds this poetic."; ghosting — "Out of lives. Not
out of influence."; queued drafts dropped at a finish — "Probate closes at
the crypt door. The grievance is noted."

## Determinism receipt (3 seeds, each run TWICE, byte-diffed)

`godot --headless --path . minigames/last_will/last_will.tscn -- --willtally --seed=N`
(dt pinned to 1/60 via time_scale+physics_ticks scaling; all HIT KIT /
banner / camera FX gated off; camera shake uses a separate unseeded rng
that gameplay never reads).

```
SEED 1: BYTE-IDENTICAL     SEED 2: BYTE-IDENTICAL     SEED 3: BYTE-IDENTICAL

WILL_TALLY seed=1 races=3 wills=22 curse_kills=6 gust_kills=0 deaths=22
  FINISH race 1: BLUE at 41.4s | race 2: RED at 55.2s | race 3: BLUE at 43.3s
WILL_TALLY seed=2 races=3 wills=13 curse_kills=2 gust_kills=0 deaths=13
  FINISH race 1: GOLD at 43.3s | race 2: GOLD at 50.2s | race 3: BLUE at 45.6s
WILL_TALLY seed=3 races=3 wills=10 curse_kills=1 gust_kills=0 deaths=10
  FINISH race 1: GOLD at 48.1s | race 2: GOLD at 42.5s | race 3: MINT at 44.9s
```

Every one of the nine 4-bot races reached the crypt (no timeouts, no
stalls); race-clock winner times 41-55s (the race clock halts during will
freezes — wall time for a live race with drafts is ~75-100s, inside the
60-90s-competent-racer envelope once human error is priced in). Deaths
10-22 per match = wills 10-22, curse kills up to 6. One fixed print leak:
`LW_RACE_START` used to stamp `game_time`, which carries a run-varying
startup offset — removed from the receipt.

2P degenerate case (seed 9, `--players=2`): all 3 races finish, scoring
3/0, `LW_VALIDATE problems=0`. The wills>=races tally heuristic reads
CHECK at 2P (fewer bodies by construction) — expected, same caveat as
v1's ">=2 wills is structurally a 4P target".

## Contract receipt

`LW_RESULTS` (seed 1): placements all 4, points dict, currency_events =
royalty +2 per curse kill / +1 per gust kill / grudge +1 per race last
place, kill_events with causes `shove|gust|pendulum|squish|void|spinner|
scythe|grease|gale|stones`, highlights (max 3, deduped), monuments:
`reaper` at 3+ curse kills, `untouched` for a deathless race win.
`Minigame.validate_results`: **problems=0** (printed as LW_VALIDATE).

## Self-test

```
godot --headless --path . minigames/last_will/last_will.tscn -- --willtest=squish --seed=1
WILLTEST squish RESULT: PASS (t=3.90)
```

## Bot-balance history (what it took)

- v2.0 first run: 36 deaths/match, ALL races timed out — scythe curses in
  segment 1 meat-ground everyone, and one surviving bot parked at a blade
  gate forever. Fixes: blade gates as traffic lights (cross only when the
  blade has passed your lane and is receding, using the blade's velocity
  sign), a 5s no-progress DESPERATION clock (jaywalk rather than statue),
  all-ghosts-ends-the-race rule, scythe cap 2 / stones cap 3, blade KNOCK
  15 -> 10 (a walkway is narrower than the old chapel yard).
- v2.1: races finished in ~30s with 1 death — course stretched 1.5x
  (crypt at x=198), 4th boulder lane, and gap hops became ONE seeded
  timing roll per approach (per-tick rolls never failed). Also fixed:
  the lane-keeping spring out-pulled the stones-gap steer and parked
  three bots against a gravestone rank — thread targets now OVERRIDE
  lane-keeping.

## Screenshots (windowed, read by eye; committed in minigames/last_will/shots/)

Regenerate:
```
godot --path . minigames/last_will/last_will.tscn -- --willview=overview --willbots --seed=3 --shots=260 --outdir=verify_out/lw2a
godot --path . minigames/last_will/last_will.tscn -- --willbots --seed=3 --willkill=4:2 --shots=900 --outdir=verify_out/lw2b
godot --path . minigames/last_will/last_will.tscn -- --willbots --seed=1 --shots=8000 --outdir=verify_out/lw2c   # snap_draft/curse/finish are event-driven
godot --path . minigames/last_will/last_will.tscn -- --deadhint --seed=5 --shots=1400,2200 --outdir=verify_out/lw2d
```

- `screen_course_overview.png` — hero survey from over the chapel: the
  flagstone route with candle-warm curb hairlines, S-curve under the
  scythe gallows, the crypt glowing at the vanishing point.
- `screen_will_draft.png` — THE SHOW: world frozen, GOLD's frame, memorial
  portrait, three curse cards with hand-drawn glyphs (gale strokes,
  grease urn + slick, stones rank), gold zone lines, 6s timer.
- `screen_will_displace.png` — full-slate rule on screen: RAISE THE DEAD
  card reading "displaces MINT's GREASED FLAGSTONES".
- `screen_curse_scythe.png` — resolution pan: "GOLD CONDEMNS THE
  PROCESSION ROW", the summoned scythe descending with GOLD's keel +
  plaque (`■ GOLD / THE SUMMONED SCYTHE`).
- `screen_curse_grease_crypt.png` — MINT greases THE CRYPT STEPS, mint
  sheen on the stones, crypt facade + columns in frame.
- `screen_crypt_finish.png` — "BLUE REACHES THE CRYPT 0:51.7", BLUE
  cheering in the doorway glow, Executor's inheritance line, MINT's
  grease plaque on the steps.
- `screen_ghost_race.png` — RED's ghost pew drifting alongside the pack,
  hint bar "RED IS DEAD — MOUSE aim the gust · LEFT CLICK = GUST (every
  10s)", RED's hearts at 0, lit road with curb read.

## Design decisions & known issues

- Curses persist across races (Par-style accretion); the will is dropped
  with an Executor line if the crypt is reached while drafts are queued.
- The race clock (and finish times) exclude will-freeze time by
  construction — the freeze stops the world, clock included.
- Headed runs are not frame-identical to headless with the same seed (FX
  waits in real time — same caveat as v1); gameplay state advances on the
  physics tick, receipts come from --willtally only.
- Self-kills by your own curse are possible, attributed, and pay no
  royalty ("BLUE'S SCYTHE REAPS BLUE" is working as intended).
- The spinner swats but never kills directly (cause `spinner` only
  appears when the swat carries someone off within 3s — killer -1).
- user:// hygiene: the four save files were backed up before the session;
  afterward estate_save/cosmetics/prefs verified byte-unchanged, and
  party_setup.json (rewritten by PlayerInput.auto_assign during
  standalone runs) was restored from the backup.

## Wishes

- A low organ drone + quill scratch for the draft (shared bank has no
  quill; using grudge bong + card clicks + confirm).
- KayKit skeleton hand / dedicated gravestone props for the plaques.
- A killcam-style slow push-in on curse kills (respect the one-hitstop
  budget).
