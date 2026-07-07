# polish-bars-irony — real-keys hint bars (5 games) + ECHO irony pack

Godot 4.6.2. Two presentation deliverables, one lane each:

1. **REAL-KEYS HINT BARS** in `echo_chamber`, `swap_meet`, `last_will`,
   `masked_ball`, `seance` — the persistent main bar now prints each human
   seat's LIVE binding (`Space`/`Enter`/…), not the meaningless `A`/`B`.
   Follows `docs/verify/realkeys-VERIFY.md` (THE TEMPLATE IS LAW).
2. **ECHO IRONY PACK** (doc 09 §2.1) — dying to your OWN recorded ghost now
   gets a distinct celebration + is carried to the Reading of the Will.

Shots: `docs/verify/polish-bars-irony-shots/`. All read by eye, WINDOWED
(RTX 4050 Laptop, Vulkan Forward+ — headless skips `frame_post_draw`).

---

## Deliverable 1 — real-keys hint bars

### The template, copied self-contained into each game (presentation only)

Each game gained three tiny helpers (no shared file → no collision with the
other lanes): `_human_seats()`, `_btn_hint(action,label)`, `_controls_bar()`.
Verbatim from the template's rules:

1. **All human seats share the key** → one legend: `Space = SHOVE` (lone kb),
   `(A) = STRIKE` (all on pads).
2. **Seats differ** (mixed) → per-seat: `SHOVE: Space/RED · Enter/BLUE`.
   NAME = `GameState.PLAYER_NAMES[i]` (RED/BLUE/GOLD/MINT).
3. **No human seats** (all-bot demo) → the game's ORIGINAL generic string, so
   bot-only receipts/demos stay byte-identical.

Bindings are fixed per match, so the bar is built ONCE at match start:

| Game | Build site | Bar source |
|------|-----------|------------|
| swap_meet | end of `begin()` (after bot map) | `_hint_label` |
| last_will | `begin()` + `_refresh_hint()` living branch | `hint_label` (ghost/dead branches untouched) |
| masked_ball | `_begin_waltz()` | `hint_label` |
| seance | `_begin_seance()` (the SITTING chant bar ONLY) | `hint_label` |
| echo_chamber | end of `begin()` | NEW `controls_label` (bottom-center; echo had no bar) |

**Seance scope guard honored:** ONLY the persistent chant/hint bar (line in
`_begin_seance`) was touched. The `_net_state` / `_net_apply` mirror code paths
were NOT touched — the mirror still serializes `hint_label.text` verbatim, so
host/mirror parity is by construction.

### Verification — WINDOWED, mixed seats, read by eye

`user://party_setup.json` was backed up, then staged so `PartySetup` (autoload,
`_ready` → `PlayerInput.load_setup()`) yields a MIXED roster on self-start:

```
{"bots":{"0":false,"1":false,"2":true,"3":true},
 "devices":{"0":-1,"1":-2,"2":-3,"3":-3}}
```

- **P0 = RED** → device -1 (keyboard LEFT: WASD, `Space`=a, `E`=b) — human
- **P1 = BLUE** → device -2 (keyboard RIGHT: arrows, `Enter`=a, `Shift`=b) — human
- **P2/P3 = GOLD/MINT** → bots

Each game launched WINDOWED (no `--headless`) via
`godot --path . res://minigames/<g>/<g>.tscn -- --shots=<frame> --outdir=…`;
VerifyCapture grabs the real rendered viewport. Every log confirmed
`bots=[false, false, true, true]`. The staged file was restored afterward
(md5-identical to the backup; 0 stray godot processes left).

Bars as rendered (mixed kb-vs-kb → the per-seat "differ" form):

| Game | Bar as rendered | Shot |
|------|-----------------|------|
| last_will | `SHOVE: Space/RED · Enter/BLUE · HOP: E/RED · Shift/BLUE   DIE, AND CURSE THE ROAD` | `last_will.png` |
| swap_meet | `STEER move · THROW SWAP ORB: Space/RED · Enter/BLUE · DRIFT hold / BOOST release: E/RED · Shift/BLUE` | `swap_meet.png` |
| masked_ball | `STICK = DRIFT · FEATHER IT = your mask glints · CURTSY: Space/RED · Enter/BLUE · UNMASK (one mark): E/RED · Shift/BLUE` | `masked_ball.png` |
| echo_chamber | `MOVE · STRIKE: Space/RED · Enter/BLUE · DASH / hold PARRY: E/RED · Shift/BLUE  \|  DUEL YOUR OWN ECHO` | `echo_chamber.png` |
| seance | `STICK = GUIDE THE PLANCHETTE   CHANT ON THE PULSE: Space/RED · Enter/BLUE   SURGE: E/RED · Shift/BLUE` | `seance.png` |

Both other branches exercised on `last_will`:

- **All-same** (seat 0 the only human, `devices {0:-1,1:-3,2:-3,3:-3}`,
  `bots=[false,true,true,true]`) → collapses to `Space = SHOVE · E = HOP ·
  DIE, AND CURSE THE ROAD` — no NAME tags (`last_will_solo.png`).
- **All-bot** (`devices` all -3, `bots=[true×4]`) → the ORIGINAL generic bar
  preserved: `A = SHOVE   B = HOP   ·   DIE, AND CURSE THE ROAD`
  (`last_will_allbot.png`).

Labels are chosen from each game's How-to-Play card / existing bar text
(echo's from `estate.gd`'s `"echo"` card: a=STRIKE, b=DASH/PARRY).

---

## Deliverable 2 — ECHO irony pack (doc 09 §2.1)

**Spec:** when a fighter dies to their OWN recorded ghost (`is_ghost and
owner == victim`), the game must SAY SO — banner `KILLED BY THEIR OWN ECHO`
2.2s + `grudge` 0dB + slow-mo 0.3×/0.5s + a tracked `self_haunt` stat for the
Will reading; carried into results `highlights` + a `kill_events` cause slug.

**Implementation (presentation only):**

- `resolve_swing` kill branch tags `self_echo` when the killing swing is a
  ghost whose owner == the victim; passes it as the `_on_death` cause.
- `_on_death` on `cause == "self_echo"`: increments `_self_haunts[victim]`,
  fires the BIG center banner (distinct from the small credit banner ordinary
  ghost kills use), plays `grudge` at 0dB, and calls a new `_slowmo(0.3, 0.5)`
  (same time-scale-independent restore timer as `_hitpause`) instead of the
  0.05s hit-pause. Logs `ECHO_SELF_HAUNT victim=… round=…`.
- `kill_events` cause slug = `"self_echo"` (killer == victim, so the estate's
  NEMESIS matrix — which skips killer==victim — correctly ignores it; a player
  can't be their own nemesis).
- `_best_highlights()` PREPENDS `"<NAME> WAS SLAIN BY THEIR OWN ECHO"` from
  `_self_haunts` (deterministic insertion order) → the estate carves it as
  graffiti and reads it at the will.

Nothing touches the record/replay path or scoring; `_award_ghost_hit`'s points/
royalty/bounty are unchanged.

### Determinism — the ghost-drift receipt HOLDS (the hard invariant)

`--echobots --echofast=5 --seed=1`, headless. The ghost record→replay drift is
byte-identical BEFORE (original) and AFTER (irony pack):

```
ECHO_DETERMINISM round=1 ghosts=0  max_err=0.000000 OK
ECHO_DETERMINISM round=2 ghosts=4  max_err=0.000000 OK
ECHO_DETERMINISM round=3 ghosts=8  max_err=0.000000 OK
ECHO_DETERMINISM round=4 ghosts=12 max_err=0.000000 OK
```

This is transform-based (a ghost replays its OWN recording), so it is
independent of bot behavior, render mode, and the slow-mo change — as the
VERIFY doc for echo already notes.

### Bot baseline — the kill/placement ORDER is inherently wall-clock-coupled

The kill sequence (and thus final placements) is NOT a reproducible receipt in
the ORIGINAL code: echo's hit-pause uses a real-time (`ignore_time_scale`)
timer, and the bots draw seeded RNG per physics tick, so the number of "slow"
ticks — and every downstream bot decision — depends on wall-clock CPU load.

Proof (all headless, `seed=1 --echobots --echofast=5`):

- **Two runs of the ORIGINAL code diverge from each other** after round 1
  (only round-1's first kill is stable): B1 `ROUND-2 BLUE KILLED PRESENT BLUE`
  vs B2 `ROUND-2 BLUE KILLED PRESENT MINT`. Same seed, same binary, different
  kill order.
- Both also diverge from the sequence documented in
  `minigames/echo_chamber/VERIFY.md` (a different machine/run).
- The `max_err=0.000000` table is IDENTICAL across every run.

So the irony pack's slow-mo cannot be blamed for any placement change — the
metric was never deterministic run-to-run. The invariant the game actually
guarantees (ghost-drift = 0) is preserved. No re-baseline needed; no scoring
touched.

### The irony reaches results — full match run (`--echobots --seed=3 --echofast=4`)

```
ECHO_SELF_HAUNT victim=GOLD round=3 (slain by their own recorded ghost)
ECHO_SELF_HAUNT victim=RED round=5 (slain by their own recorded ghost)
ECHO_MATCH_OVER champ=MINT placements=[3, 0, 2, 1]
KILL_EVENTS n=9 [ … {"killer":2,"victim":2,"cause":"self_echo"},
                  … {"killer":0,"victim":0,"cause":"self_echo"}, … ]
```

Both self-echo KOs carry `cause:"self_echo"` with `killer == victim`, and the
`_self_haunts` map (populated → non-empty) feeds the prepended highlight. Match
completes cleanly (no assert/crash).

---

## Commands

Import pass (clean; only first-run cold-cache asset imports, gone on 2nd pass):
```
godot --headless --editor --import --quit --path .
```
Parse note: `--import` does NOT reload every script — a real parse error only
surfaces when the SCENE is loaded. All five scenes were load-checked headless
(no SCRIPT ERROR / Parse Error). The `:=` inference rule bit once
(`self_echo` inferred from an untyped loop var) — fixed with an explicit
`var self_echo: bool = …`.

Hint-bar shots (per game): `--shots=<frame> --outdir=… ` WINDOWED, with the
mixed `party_setup.json` staged. Seance needs a LATE frame — its CAST liturgy
is ~46s of scripted timers before the SITTING chant bar (`SEANCE_SITTING_START
t=49.5`).
