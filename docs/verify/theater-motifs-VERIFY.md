# THE SÉANCE + THE UNDERSTUDY — per-colour audio motif, rumble, shape glyph (verification)

*Producer ruling: "can you do a voiceover for the colours, to show who should
look and not look. Also ADA compliance." No VO pipeline exists and no new
audio assets were added — this pass reuses the existing gothic Sfx bank and
`PlayerInput.rumble`. Presentation only. Files touched: `minigames/seance/`,
`minigames/understudy/` + `docs/verify/` only.*

## What existed already

Both theater games already had an eyes-closed "voice summons" (playtest fix
from an earlier pass): three pitched ticks before a seat's private card, a
fourth as it flips, at a per-seat pitch (`SEAT_TAP_PITCH = [0.9, 1.0, 1.12,
1.26]`, same mapping in both games). That answered "who should look." Nothing
answered "who should stop" — a seat's window just silently reverted to "EYES
CLOSED" — and the tick itself was one shared sample (`"place"` / `"card"`)
merely pitch-shifted, not a distinct *timbre* per colour.

An audit of both games' colour cues (`_cast_card` in `seance.gd`,
`show_call`/`show_teach`/`flip_to_redacted` in `us_reveal.gd`, the sitter
nameplates in `seance_figure.gd`, and `us_actor.gd`) found the **shape glyph
already present at every one of them** — `PlayerBadge.glyph(idx)` (● ▲ ■ ◆)
is prefixed onto every colour title string already (`"%s %s" % [glyph,
name]`), a house rule ("never colour alone") from prior work. No gap found;
no change needed there. See the screenshots below for direct evidence.

## What this pass adds

### 1. Per-colour audio MOTIF (not just a pitched click)

`SEAT_MOTIF_KEY := ["bell_small", "bell_toll", "organ_stab", "raven"]` — one
new const, **identical in both `seance.gd` and `understudy.gd`** — maps each
seat to a distinct existing-bank instrument family (the gothic layer already
shipped for other lanes; see `scripts/sfx.gd` `BANK`). `_play_summons_tick`
in both games now plays `SEAT_MOTIF_KEY[seat]` at the seat's existing
`SEAT_TAP_PITCH` anchor instead of the shared `"place"`/`"card"` sample — so
the sound a seat is taught (roll-call in the séance, casting in the
understudy) is the *exact* sound it hears the rest of the night, in *either*
game. A seat's ear-cue is learned once and works everywhere.

Bug fixed en route: both games' `_bank_stream()` hardcoded a `.ogg` suffix;
the new gothic-layer samples ship only as declicked `.wav`
(`assets/audio/bell_small_v1.wav` etc. — verified on disk). Fixed to prefer
`.wav` and fall back to `.ogg`, mirroring `scripts/sfx.gd`'s own
`_load_sample`, in both files.

### 2. The "don't look" half — `_play_standdown_tick(seat)`

New function, identical shape in both games: the same seat family, **one
note, pitched down** (`SEAT_TAP_PITCH[seat] * 0.72`), quieter
(`STANDDOWN_DB = -7.0` vs. the summons' `-4.0`). Fired once per private
window's close:

- **Séance** (`_begin_cast`): at the seat's `t+6.1` "EYES CLOSED" card swap
  (the existing reveal-hold-then-close beat), alongside the card.
- **Understudy** (`_tick_casting`): the instant `commit` fires, before
  `_cast_seat` advances.
- **Mirror clients** (both games): fired locally, once, when the public cast
  fact moves past *my own* flip — séance via a third `tween_interval(3.9)`
  step in `_mir_private_cast` (`1.2 + 1.0 + 3.9 = 6.1s`, matching the host's
  offset exactly); understudy via a new `_mir_my_flip_open` flag checked in
  `_apply_mir_cast` (set when my own "flip" lands, cleared — firing the
  stand-down — the moment any other cast fact supersedes it).

Direction of pitch, not just timbre, now tells "look" from "look away" even
from sound alone: rising/anchor-pitch triple-tick = look; one low note of the
same family = don't.

### 3. Controller rumble — felt, not just heard or seen

`PlayerInput.rumble(seat, weak, strong, dur)` already existed (dur capped
0.4s, no-ops for bots/remote/keyboard/mouse/headless — see
`core/player_input.gd`). Both games now call it at the same two state
changes, on **that seat's own pad only**:

| state change | call | where |
|---|---|---|
| LOOK begins | `rumble(seat, 0.25, 0.55, 0.16)` | séance `_cast_private_reveal`; understudy `_tick_casting` PEEK; both games' mirror-client reveal paths |
| LOOK ends | `rumble(seat, 0.12, 0.2, 0.12)` | séance `t+6.1` close; understudy commit; both games' mirror-client close paths |

Because `rumble()` already guards bots/remote/keyboard, every call above is
made **unconditionally** — no per-seat `if` needed, matching the existing
house pattern the function was built for.

## Presentation-only guarantee

Every new function (`_play_standdown_tick`, the rumble calls) reads only the
seat index and already-computed roster data; none touch forces, focus,
scoring, RNG, or bot logic. All summons/standdown audio remains `if _tally:
return`-guarded (inert in headless evidence). Rumble is itself inert under
`DisplayServer.get_name() == "headless"` (built into `PlayerInput.rumble`),
so tally is untouched by construction, not by a new guard.

## Determinism (byte-identical sim)

```
godot --headless --path . res://minigames/seance/seance.tscn -- --seancetally --seed=5   # word=WINTER charlatan=BLUE
godot --headless --path . res://minigames/seance/seance.tscn -- --seancetally --seed=1   # word=GHOST  charlatan=RED
godot --headless --path . res://minigames/understudy/understudy.tscn -- --ustally --seed=1
godot --headless --path . res://minigames/understudy/understudy.tscn -- --ustally --seed=2
godot --headless --path . res://minigames/understudy/understudy.tscn -- --ustally --seed=3
```

Results — **all byte-identical to the frozen baselines**:

```
SEANCE_TALLY seed=5 word=WINTER charlatan=BLUE success=true caught=true correct_votes=2
points: RED=2 BLUE=0* GOLD=3 MINT=3
SEANCE_TALLY seed=1 word=GHOST charlatan=RED success=false caught=true correct_votes=2
points: RED=0* BLUE=0 GOLD=1 MINT=1

US_TALLY seed=1 rounds=4 totals: RED=9 BLUE=9 GOLD=6 MINT=7  champ=RED
US_TALLY seed=2 rounds=4 totals: RED=2 BLUE=9 GOLD=6 MINT=7  champ=BLUE
US_TALLY seed=3 rounds=4 totals: RED=7 BLUE=9 GOLD=9 MINT=7  champ=BLUE
```

**NO MOVEMENT** on either game's receipt (matches `understudy-VERIFY.md`
§"Three-seed match results" exactly). Board receipts also unchanged (checked
once for the whole M5 lane — see `seance-telegraph-VERIFY.md`):
`BOARDGRAPH checksum=b269c570`, `PROCESSION_HEIR GOLD (seed 7, 3 nights)`
wreaths `[36,41,56,43]`.

## Windowed evidence (motif keys actually firing)

```
godot --path . res://minigames/seance/seance.tscn -- --seancebots --seed=5 --quitafter=22000 --outdir=verify_out/seance_probe
```

```
SEANCE_SUMMONS p=0 RED  pitch=0.90 motif=bell_small
SEANCE_SUMMONS p=1 BLUE pitch=1.00 motif=bell_toll
SEANCE_SUMMONS p=2 GOLD pitch=1.12 motif=organ_stab
SEANCE_SUMMONS p=3 MINT pitch=1.26 motif=raven
```

```
godot --path . res://minigames/understudy/understudy.tscn -- --ussnaps --seed=3
```

```
US_SUMMONS   seat=0 RED  pitch=0.90 motif=bell_small
US_SUMMONS   seat=1 BLUE pitch=1.00 motif=bell_toll
US_SUMMONS   seat=2 GOLD pitch=1.12 motif=organ_stab
US_SUMMONS   seat=3 MINT pitch=1.26 motif=raven
US_STANDDOWN seat=0 RED  pitch=0.65 motif=bell_small
US_STANDDOWN seat=1 BLUE pitch=0.72 motif=bell_toll
US_STANDDOWN seat=2 GOLD pitch=0.81 motif=organ_stab
US_STANDDOWN seat=3 MINT pitch=0.91 motif=raven
```

Same four families, same seat mapping, in both games; the STANDDOWN pitches
are each exactly `SEAT_TAP_PITCH[seat] * 0.72`.

## Screenshots (`docs/verify/shots/`)

- `seance_motif_cast.png` — the automatic `"cast"` event snap (fires on the
  Charlatan's own private reveal): **"▲ BLUE — the spirits took the liberty
  of paying you / YOU WERE PAID — 2 GRUDGE, UP FRONT..."** — the exact
  instant `_cast_private_reveal` plays the `bell_toll` motif (BLUE = seat 1)
  and rumbles seat 1's own pad. Shape (▲) + colour together, never colour
  alone.
- `understudy_reveal.png` — the understudy's own casting card: **"● RED —
  YOUR PART"** over "TONIGHT'S PLAY / THE HAUNTING" — same shape+colour
  pairing, captured at the equivalent `bell_small` (RED = seat 0) reveal.
- `seance_telegraph_midround.png` (shared with `seance-telegraph-VERIFY.md`)
  — the four sitter nameplates in the same frame double as further shape+
  colour evidence (● RED / ■ GOLD / ▲ BLUE / ◆ MINT).

## Files touched

- `minigames/seance/seance.gd` — `SEAT_MOTIF_KEY` / `STANDDOWN_DB` consts;
  `_bank_stream` wav-first fix; `_play_summons_tick` motif swap;
  `_play_standdown_tick` (new); rumble in `_cast_private_reveal` and the
  `t+6.1` close lambda; mirror-side motif/rumble/standdown in
  `_mir_private_cast`.
- `minigames/understudy/understudy.gd` — same const pair; same
  `_bank_stream` fix; `_play_summons_tick` motif swap; `_play_standdown_tick`
  (new); rumble in `_tick_casting`'s PEEK and commit branches;
  `_mir_my_flip_open` flag + standdown/rumble detection in `_apply_mir_cast`;
  LOOK rumble in `_mir_show_my_card`.
- `docs/verify/theater-motifs-VERIFY.md` +
  `docs/verify/shots/seance_motif_cast.png` (new) +
  `docs/verify/shots/understudy_reveal.png` / `understudy_rehearsal.png` /
  `understudy_vote.png` / `understudy_judgment.png` (refreshed via the
  documented `--ussnaps --seed=3` command — same command, current build;
  resolution differs from the prior baseline only because this capture ran
  at this machine's default window size, 1920×1200 vs. the earlier
  1280×720).
