# Kill Attribution + Par HUD polish — verification

Three deliverables, all reporting/presentation-only (gameplay byte-identical):

1. **PART 1 — `kill_events` in all three games** (Par, The Throne, Last Will).
2. **PART 2 — Par scoreboard PlayerBadges** (shape+color identity chip left of
   every name, matching the other nine games).
3. **PART 3 — Par CHAOS turn banner** (persistent "CHAOS — EVERYONE AT ONCE"
   replaces the misleading per-player "X'S TURN" during the simultaneous round).

Godot 4.6.2.stable. Import pass after edits: clean (only the pre-existing
`assets/models/meshy/cosmetics/*.jpg` texture-import errors, which are unrelated
and in an off-limits tree).

---

## PART 1 — `kill_events` (module contract, optional results field)

Per `docs/specs/anthology-module-contract.md`, results may now carry:

```
kill_events: Array of { killer: int, victim: int, cause: String }
```

`killer == -1` means environment or self-inflicted (no OTHER player to credit).
`cause` is a short slug. Appended right where each game already detects the
death/kill for royalties/grudges, carried in the finished/results payload the
same way `currency_events` is, and echoed with `print("KILL_EVENTS n=", ...)` at
match end. **Reporting only — no gameplay branch reads it; behavior is unchanged
and byte-identical per seed.**

Mapping per game:

| Game | Where appended | killer | cause slug(s) |
|------|----------------|--------|---------------|
| Par (`scripts/main.gd` `_on_ball_died`) | beside the royalty credit | trap `author_index`, or `-1` for authorless/self kills | the trap's `trap_id` (`spikes`, `crusher`, `water`, …), `course` if no trap |
| Throne (`minigames/throne/throne.gd` `_dethrone`) | beside the royalty append | the kingslayer | `dethroned` |
| Last Will (`minigames/last_will/last_will.gd` `_on_pawn_died`) | beside the grudge append (mirrors the banner attribution) | the shover/guster, or `-1` | `void` (shoved off), `gust`, `squish` (boulder), `pendulum` |

### Throne — `--thronebots --matchtime=20 --seed=1`

```
THRONE_DETHRONE t=9.8  MINT dethroned BLUE
THRONE_DETHRONE t=11.8 GOLD dethroned RED
THRONE_DETHRONE t=14.5 RED  dethroned MINT
THRONE_DETHRONE t=16.6 RED  dethroned BLUE
THRONE_DETHRONE t=18.7 MINT dethroned RED
KILL_EVENTS n=5 [{killer:3,victim:1,cause:dethroned}, {killer:2,victim:0,...},
                 {killer:0,victim:3,...}, {killer:0,victim:1,...}, {killer:3,victim:0,...}]
THRONE_MATCH_OVER champ=BLUE placements=[1,0,3,2]
```
n=5 kill_events == 5 dethronings; each killer/victim matches the DETHRONE log
(RED=0 BLUE=1 GOLD=2 MINT=3). No "Minigame results problem" warnings.

### Last Will — `--willtally --seed=3`

```
LW_DEATH r1 GOLD SHOVES MINT INTO THE DUSK   cause=void
LW_DEATH r1 THE BOULDER FLATTENS RED         cause=squish
LW_DEATH r1 RED SHOVES GOLD INTO THE DUSK    cause=void
LW_DEATH r2 GOLD SHOVES MINT INTO THE DUSK   cause=void
LW_DEATH r2 THE BOULDER FLATTENS BLUE        cause=squish
LW_DEATH r2 RED SHOVES GOLD INTO THE DUSK    cause=void
LW_DEATH r3 MINT SHOVES GOLD INTO THE DUSK   cause=void
LW_DEATH r3 THE PENDULUM SWATS BLUE AWAY     cause=void
LW_DEATH r3 THE BOULDER FLATTENS RED         cause=squish
KILL_EVENTS n=9 [{killer:2,victim:3,cause:void}, {killer:-1,victim:0,cause:squish},
                 {killer:0,victim:2,cause:void}, {killer:2,victim:3,cause:void},
                 {killer:-1,victim:1,cause:squish}, {killer:0,victim:2,cause:void},
                 {killer:3,victim:2,cause:void}, {killer:-1,victim:1,cause:pendulum},
                 {killer:-1,victim:0,cause:squish}]
LW_MATCH_OVER champ=RED   WILL_TALLY wills_per_round=3.00
```
All 9 map 1:1 to the LW_DEATH log: shoves credit the shover, boulders +
pendulum are environment (`-1`). No validation warnings.

### Par — `--skipmenu --parbots --rounds=2 --seed=7`

```
DEATH: BLUE by GOLD'S SPIKE STRIP (round 2)
MATCH_OVER champ=RED
KILL_EVENTS n=1 [{killer:2,victim:1,cause:spikes}]
```
`{killer:2 (GOLD), victim:1 (BLUE), cause:spikes}` matches the death line, and
the killer index is exactly who earned the royalty.

Self-kill / mixed case, `--skipmenu --parbots --rounds=3 --seed=3`:
```
DEATH: RED  by RED'S SPIKE STRIP  (round 1)   # self-kill (author == victim)
DEATH: GOLD by RED'S SPIKE STRIP  (round 1)   # RED's trap kills GOLD
DEATH: RED  by RED'S SPIKE STRIP  (round 2)   # self-kill again
KILL_EVENTS n=3 [{killer:-1,victim:0,cause:spikes}, {killer:0,victim:2,cause:spikes},
                 {killer:-1,victim:0,cause:spikes}]
```
A self-kill (author == victim) records `killer:-1` — and no royalty is credited
in that case either, so the ledger stays consistent with the spite economy. A
kill of another player credits the trap author (RED=0 kills GOLD=2).

Reproduce:
```
GODOT=godot
$GODOT --headless --path . minigames/throne/throne.tscn -- --thronebots --matchtime=20 --seed=1 --quitafter=2400
$GODOT --headless --path . minigames/last_will/last_will.tscn -- --willtally --seed=3
$GODOT --headless --path . -- --skipmenu --parbots --rounds=2 --seed=7 --quitafter=40000
```

---

## PART 2 — Par scoreboard badges

`scripts/main.gd` `_rebuild_scoreboard()` now wraps each row in an
`HBoxContainer` with `PlayerBadge.make(i, 24)` (colored to `player.color`) left
of the name Label — the exact one-liner the other nine games use. The score
panel in `scenes/main.tscn` was widened (`offset_left -220 → -256`) to seat the
24px chip without clipping the name/score/royalty tags.

Shape+color is index-driven, so identity holds regardless of standings order:
`0 RED = circle, 1 BLUE = triangle, 2 GOLD = square, 3 MINT = diamond`.

**Proof: `shots/badge_par.png`** — normal round, HUD top-right shows
● RED / ▲ BLUE / ■ GOLD / ◆ MINT, each chip in the player's color left of the
name. Captured windowed via
`--skipmenu --parbots --rounds=2 --seed=4 --shots=3200 --outdir=verify_out/badge`.

---

## PART 3 — Par CHAOS turn banner

During the final CHAOS round play is simultaneous, but the turn banner still
cycled "X'S TURN" as the shot clock rotated seats — a lie. Now:

- On chaos entry (`_enter_chaos_round`) the turn Label is set once to a
  persistent **"CHAOS — EVERYONE AT ONCE"** in the same Luckiest Guy style as
  the other banners, with a looping heat-color pulse (gold-orange ↔ ember red).
- `_on_turn_started` skips the per-player text during chaos (still assigns the
  ball/camera and refreshes the **STROKE n/6** counter, which stays meaningful).
- The pulse tween is killed at match over. Chaos is always the final round, so
  no normal round follows it; a normal round still shows "X'S TURN".

**No gameplay/timing change** — only the two Labels' text/color. The chaos
shot-clock, 1.5s gap, and 75s round timer are untouched (`round_manager.gd` not
modified).

**Proof: `shots/chaos_banner.png`** — CHAOS round, banner reads "CHAOS —
EVERYONE AT ONCE" (heat gold) with "STROKE 2 / 6" beneath and two balls live on
the green at once. Captured windowed via
`--skipmenu --parbots --rounds=1 --seed=5 --shots=430 --outdir=verify_out/chaos`.
(`badge_par.png` in the same shot family confirms the normal-round "GOLD'S TURN"
banner still appears — the replacement is chaos-scoped.)

---

## Files touched (within the allowed set)

- `scripts/main.gd` — Par kill_events + scoreboard badges + chaos banner.
- `scenes/main.tscn` — ScorePanel width for the badge.
- `minigames/throne/throne.gd` — throne kill_events.
- `minigames/last_will/last_will.gd` — last_will kill_events.
- `docs/verify/kills-ptl-VERIFY.md` + `docs/verify/shots/{badge_par,chaos_banner}.png`.

Not touched: `estate/`, `core/`, `project.godot`, other minigames,
`scripts/verify_capture.gd`, `scripts/sfx.gd`,
`docs/specs/anthology-module-contract.md`.
