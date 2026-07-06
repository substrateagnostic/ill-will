# SWAP MEET — Photo Finish + Overtake Sting (verification evidence)

Queue item **Q4** from `docs/design/09-aaa-gap-analysis.md` (§7.1 photo
finish, §7.2 overtake sting). Lane: `minigames/swap_meet/` only — no
shared-file touches. **Presentation only**: race outcome, physics, swap
logic and bot behaviour are unchanged; same-seed placements are proven
byte-identical below.

All commands run from the repo root. Screenshots land in `verify_out/`
(gitignored) and the two referenced frames were copied to
`docs/verify/shots/` and read by eye during the session.

## What was built (per the doc's prescription)

- **Photo finish (§7.1).** When the race winner (first finisher) crosses
  the line with the chaser within **1.2 progress-units** (`PHOTO_MARGIN_UNITS`),
  `_finish_kart` routes through `_try_photo_finish` → `_photo_finish`:
  - a **10-tick line freeze** using the existing tick-counted hit-stop
    (`_freeze_ticks`, `PHOTO_FREEZE_TICKS`) — **never** `Engine.time_scale`,
    exactly as §7.1 and the file's determinism note require;
  - a **camera punch** to the line (`_fov_punch`: 45°→38°→45° on the fixed
    overhead cam, animated on the render tick so it plays through the freeze);
  - a **flashbulb frame** (`_flashbulb`: a white full-viewport pop that
    fades in 0.35s — paparazzi feel);
  - a **staged winner reveal** — beat 1 "PHOTO FINISH!" at the crossing,
    beat 2 (0.55s later, on a process-always timer that runs during the
    freeze) "PHOTO FINISH / <WINNER> BY %.1fs!" from the projected time
    delta + a second flash + **double confetti**.
- **Overtake sting (§7.2).** On a genuine lead change (crown holder flips
  from one valid leader to another, detected in `_update_crown`),
  `_overtake_sting` plays the bank's `sink` asset **pitched to 1.3** via a
  dedicated `AudioStreamPlayer` (the shared `Sfx.play` API only wobbles
  around pitch 1.0, so a dedicated one-shot on the same asset is the only
  way to hit 1.3 without editing `scripts/sfx.gd`), plus a **crown flash
  ×1.5 for 0.4s**. Gated by `OVERTAKE_STING_CD = 1.5s` on the sim clock so
  a drafting duel of rapid swaps can't machine-gun it.

The freeze adds **zero sim-time** (`sdt = 0` for the frozen ticks, so
`race_t` and all progress are untouched), which is why placements stay
identical. The sim uses only seeded RNG (`self.rng` + per-bot `rng`);
`Sfx.play`, tweens and confetti touch only the global RNG / render layer,
never the simulation.

## Commands run

```sh
# import pass (assets were not yet cached in this worktree)
godot --headless --editor --import --path .

# 1. Photo-finish demo (WINDOWED — real render). Two bot karts staged a
#    hair apart on the final approach; the real _finish_kart path fires.
godot --path . res://minigames/swap_meet/swap_meet.tscn -- --photofin --players=2 --autoquit

# 2. Determinism: same-seed placements byte-identical before/after the change
godot --headless --path . res://minigames/swap_meet/swap_meet.tscn -- --swapbots --seed=N --fast=8 --autoquit
#    (N = 1, 2, 3, 7, 11; FINISH / SWAPMEET_RESULTS / SWAPMEET_SIM / _LAPS
#     lines diffed against a baseline captured from the unmodified file)

# 3. Overtake-sting telemetry + throttle check
godot --headless --path . res://minigames/swap_meet/swap_meet.tscn -- --swapbots --seed=11 --fast=8 --autoquit
```

`--photofin` is a verify-only demo path (like the existing `--swaptest`
modes): it is off by default and cannot affect normal play or determinism.

## Evidence

### Photo-finish frame + close-margin log line

```
PHOTOFIN demo armed laps=1 line=95.1 seats=2
PHOTO_FINISH t=0.8 winner=0 chaser=1 margin=0.98u delta=0.24s
FINISH t=0.8 p=0 place=1 laps=[0.8]
PHOTOFINISH_SHOT res://verify_out/photofinish_01.png
FINISH t=1.0 p=1 place=2 laps=[1.03]
PHOTOFINISH_SHOT res://verify_out/photofinish_02.png
```

The close-margin log line is `PHOTO_FINISH … margin=0.98u delta=0.24s`
— the chaser was 0.98 progress-units (< the 1.2 threshold) from the line
when the winner crossed; the projected delta of 0.24s is what the banner
renders as "BY 0.2s!".

- **`shots/swap_photofinish_01.png`** — beat 1: "PHOTO FINISH!" banner, the
  flashbulb wash over the viewport, and BLUE (the chaser) **frozen** right
  at the checkered line while RED has just crossed (scoreboard `P1 RED · 5 FIN`).
- **`shots/swap_photofinish_02.png`** — beat 2: the staged reveal
  "PHOTO FINISH / RED BY 0.2s!", flash cleared, both karts across
  (`P1 RED · 5 FIN`, `P2 BLUE · 3 FIN`).

### Determinism — placements byte-identical

Baseline captured from the **unmodified** `swap_meet.gd`, then re-run after
the change. FINISH / SWAPMEET_RESULTS / SWAPMEET_SIM / SWAPMEET_LAPS lines:

| seed | verdict |
|---|---|
| 1  | IDENTICAL |
| 2  | IDENTICAL |
| 3  | IDENTICAL |
| 7  | IDENTICAL |
| 11 | IDENTICAL |

No `PHOTO_FINISH` line appears in any normal bot race — real finishes are
seconds (many progress-units) apart, so the arm condition never trips in
ordinary play; it is reserved for the genuinely close finish it was
designed for.

### Overtake sting — fires and is throttled

Seed 11 (a 20-swap race) produced 10 stings, every consecutive pair
≥ 1.5s apart (the cooldown), so the far more frequent raw crown-flips are
correctly suppressed:

```
OVERTAKE t=9.0 leader=3
OVERTAKE t=11.9 leader=1     (+2.9s)
OVERTAKE t=15.1 leader=1     (+3.2s)
OVERTAKE t=17.8 leader=3     (+2.7s)
OVERTAKE t=19.9 leader=1     (+2.1s)
OVERTAKE t=23.2 leader=3     (+3.3s)
OVERTAKE t=25.2 leader=2     (+2.0s)
OVERTAKE t=30.0 leader=1     (+4.8s)
OVERTAKE t=43.3 leader=0
OVERTAKE t=45.6 leader=1
```

The sting rides the same lead-change detection as the visible
"<X> LEADS - AIM AT THE CROWN" event (see frame 1), so its crown-flash and
pitched `sink` are guaranteed to line up with the on-screen lead change.

## Files touched

- `minigames/swap_meet/swap_meet.gd` — all changes (new constants, sting
  player, `_overtake_sting`, `_try_photo_finish` / `_photo_finish` /
  `_fov_punch` / `_flashbulb`, the `--photofin` demo + capture helpers, and
  the `_finish_kart` / `_update_crown` hooks).

No other files in `minigames/swap_meet/` and no shared scripts were
modified.
