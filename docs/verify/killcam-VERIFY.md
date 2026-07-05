# THE KILLCAM — VERIFICATION

Engine: Godot 4.6.2 (Windows). All commands run from the worktree root.
Screenshots live in `docs/verify/shots/killcam_*.png` (committed); raw capture
output in `verify_out/killcam/` (gitignored). Frozen invariants respected:
**ball putt physics / damping / round_manager turn logic untouched** — the
killcam is pure presentation, driven off a transform ring buffer and a paused
tree. Read + critiqued the shots inline.

Import pass after adding files — zero script/parse errors in the new code:
```
godot --headless --editor --import --quit --path .
```
(Pre-existing missing-asset warnings for `assets/ui/*.png` / meshy `*.jpg` are
unrelated to this change; `update_scripts_classes | Killcam` registers clean.)

---

## What was built

| File | Change |
|------|--------|
| `scripts/ball.gd` | Ring buffer of `global_transform` sampled every LIVE physics tick (`REPLAY_CAP=160`, ~2.6 s @ 60 Hz). `get_replay_samples(seconds)` returns a fresh copy; buffer cleared on `reset_for_round`. Dead/sunk/resting frames are skipped so the tail is always real motion. Never read by game logic. |
| `scripts/killcam.gd` (new, `class_name Killcam`) | `PROCESS_MODE_ALWAYS` node holding its own `Camera3D`, a throwaway clone sphere, and a `CanvasLayer` overlay (radial vignette shader + author-colored edge frame + Luckiest-Guy credit banner + "INSTANT REPLAY" tag + skip hint). Plays the recorded transforms on the clone from a low angle near the kill point, with a gentle push-in. Skips on click / `ui_accept`; bot-only matches auto-skip at `BOT_SKIP_TIME=0.4`. |
| `scripts/main.gd` | `_resolve_death_cinematics()` dispatches: full killcam (normal round, first death of the stroke) / credit-banner-only (chaos, or an already-claimed stroke) / timeline-neutral no-op (headless / autoplay / `--nokillcam`). Windowed real play freezes the table with `get_tree().paused` for exactly `KILLCAM_DURATION=1.6`; the turn resumes on unpause. One killcam per stroke resolution (`_killcam_claimed`, reset on each stroke). Death particles set `PROCESS_MODE_ALWAYS` so the splat reads during the freeze. |

CLI flags added (all in `scripts/main.gd`, none touch the read-only harness):
`--nokillcam` (disable), `--parquit` (verify: quit at MATCH_OVER, skip flyover),
`--killcamtest=signed|self|chaos|skip` (verify: stage one deterministic death).

---

## 1. Turn/timing integrity — determinism holds (the killcam is presentation only)

### Why it can't drift
Windowed play freezes the table with `get_tree().paused = true`. A pause inserts
**zero physics ticks**, so every moving trap (crusher/spinner/windmill/…) resumes
at the exact phase it froze at, and the pausable bot/round_manager drivers freeze
too — the turn advances on the physics tick it always would have, just later in
wall-clock. In headless / `--autoplay` / `--autobuild` (where the read-only
`verify_capture` harness counts frames while paused and could drift a cooldown)
the killcam is made a **pure no-op on the timeline** — identical to `--nokillcam`.

### Headless proof — same seed, killcam×2 vs `--nokillcam`
```
ARGS="--skipmenu --parbots --parquit --seed=13 --players=4 --rounds=2 --course=fairway --forcetrap=crusher"
godot --headless --path . -- $ARGS                # run A (killcam on)
godot --headless --path . -- $ARGS                # run B (killcam on)
godot --headless --path . -- $ARGS --nokillcam    # run C (nokillcam)
```
Diff of the gameplay receipts (`BALL_SUNK / DEATH: / KILL_EVENTS / MATCH_OVER /
FINAL_RESULT`):

- **A vs B (killcam on, twice): IDENTICAL — 11/11 receipt lines.**
- **A vs C (killcam on vs --nokillcam): IDENTICAL — 11/11 receipt lines.**

```
DEATH: MINT by GOLD'S THE CRUSHER (round 1)
BALL_SUNK p=0 round=1
BALL_SUNK p=2 round=1
DEATH: BLUE by GOLD'S THE CRUSHER (round 1)
DEATH: GOLD by GOLD'S THE CRUSHER (round 2)      # self-kill (killer -1)
BALL_SUNK p=0 round=2
DEATH: BLUE by MINT'S THE CRUSHER (round 2)
BALL_SUNK p=3 round=2
MATCH_OVER champ=RED
KILL_EVENTS n=4 [{killer:2,victim:3},{killer:2,victim:1},{killer:-1,victim:2},{killer:3,victim:1}]
FINAL_RESULT placements=[0, 3, 2, 1] points={ 0: 15, 1: 0, 2: 7, 3: 8 }
```
The ONLY lines that differ between the killcam-on and `--nokillcam` logs are the
presentation-only skip-reason prints, exactly as intended:
```
killcam-on : KILLCAM neutral skip=headless victim=3 author=2
--nokillcam: KILLCAM neutral skip=nokillcam victim=3 author=2
```

### Windowed proof — the REAL pause is still outcome-neutral
Same seed, windowed (so the killcam actually pauses + replays), killcam-on vs
`--nokillcam`:
```
godot --path . -- $ARGS                # 2 real killcams played (play->done)
godot --path . -- $ARGS --nokillcam
```
- Run A executed **2 real killcam pauses** (`KILLCAM play … / KILLCAM done`) yet
  the receipts are **IDENTICAL — 11/11 lines** vs `--nokillcam`
  (`FINAL_RESULT placements=[0, 2, 1, 3] points={0:15,1:6,2:7,3:0}` both).
- Both runs took ~63 s wall-clock — the 0.4 s bot auto-skips add no meaningful
  time to a soak.

*(Windowed and headless reach different — but each internally deterministic —
matches, because vsync-capped vs uncapped stepping changes bot shot timing. The
determinism claim is per-environment, and holds in both.)*

---

## 2. Timing measurements (`held_ms` = real pause duration, pause→unpause)

| Context | Command | Measured hold |
|---------|---------|---------------|
| Non-bot, run to cap | `--killcamtest=signed` | **1708 ms** / **1667 ms** (≈ `KILLCAM_DURATION` 1.6 s hard cap) |
| Bot-only auto-skip | `--killcamtest=signed --parbots` | **387 ms** (≈ `BOT_SKIP_TIME` 0.4 s) |
| Player skip (SPACE mid-replay) | `--killcamtest=skip` | **256 ms** (ended early on the injected press) |

The turn cannot advance during the hold (tree paused), so the next player's
action is delayed by exactly this hold and nothing else.

---

## 3. Skip behavior

- **Any player input** — `Killcam._unhandled_input` ends the replay on a mouse
  click or `ui_accept`/`ui_select`, and consumes the event so it doesn't leak
  into a putt. Proven: injected SPACE at 0.25 s → `held_ms=256` (vs 1.6 s cap).
- **Bots auto-skip** — bot-only matches (`--parbots`, or every seat a bot) pass
  `bot_only=true`; the killcam bails at 0.4 s. Proven: `held_ms=387`, and the
  soak stayed at ~63 s. `botonly` is logged on every `KILLCAM play` line.
- **One per stroke resolution** — `_killcam_claimed` is set on the first death
  and reset on the next stroke; extra deaths on the same putt log
  `KILLCAM already-claimed … -> banner-only` and only flash the credit.

---

## 4. Presentation cases (screenshots, read inline)

All captured windowed (headless can't render) via `--killcamtest`, seed 3,
fairway, 2 players.

### `docs/verify/shots/killcam_signed.png` — authored kill
`--killcamtest=signed` → BLUE's crusher kills RED. Low camera near the crusher;
red clone ball rolling in from the left; **thin blue (author-colored) frame**;
"◉ INSTANT REPLAY" tag; banner **"BLUE'S THE CRUSHER — SIGNED WORK"** in the
author's blue (Luckiest Guy, matching `_flash_banner`); "CLICK / SPACE TO SKIP".
The heightened sabotage-authorship fantasy, delivered.

### `docs/verify/shots/killcam_self.png` — self-inflicted
`--killcamtest=self` → RED's own crusher kills RED. **No border** (no author to
credit); banner **"SELF-INFLICTED. THE ESTATE APPLAUDS."** in the Executor's dry
bone-white register.

### `docs/verify/shots/killcam_chaos.png` — chaos, banner only
`--killcamtest=chaos` → death during the CHAOS round. **No killcam, no pause** —
play stays live on the normal diorama camera under golden-hour light, the
persistent "CHAOS — EVERYONE AT ONCE" banner still up, and the authorship gets a
credit banner only (**"BLUE'S THE CRUSHER — SIGNED WORK"**). Log confirms
`KILLCAM chaos-banner victim=0` (no `KILLCAM play`).

---

## 5. Scope / notes

- No physics re-simulation: the replay is transform playback on a clone; real
  balls/traps/round state are never touched.
- Course/unsigned kills (no author) get a neutral bone-colored frame and an
  "— UNSIGNED" credit; self-kills get no frame per spec.
- The killing trap itself is shown frozen in its kill pose (the paused real
  trap) rather than re-animated — recording per-trap moving parts was left out
  as the "if trivial" it is not (generic across 20 trap types); the frozen slam
  reads correctly. Documented as a deliberate v1 boundary.
- Untouched per the file allowlist: `estate/`, `core/`, `minigames/`,
  `project.godot`, `scripts/verify_capture.gd`, `scripts/sfx.gd`.
