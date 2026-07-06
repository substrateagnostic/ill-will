# THE SÉANCE — audio drama pass (verification)

*Build-queue item Q6 / §11 of `docs/design/09-aaa-gap-analysis.md`. Presentation
only. Files touched: `minigames/seance/` + `docs/verify/` only. Coexists with the
per-sitter spectral pull-arrows (`seance_arrow.gd`) — nothing there was reverted.*

## What the doc asked for (§11)

The séance's core deduction tell is **the saboteur's broken chant rhythm**, but
chant taps were **silent** (a candle flare only) — so the tell was invisible to
anyone not staring at one suspect's candle. Three §11 items, all "PRESENTATION /
S", are implemented here:

- **#1 — per-seat pitched chant tick.** Every A-chant now plays an audible tick
  at a **seat-distinct pitch** (`0.9 / 1.0 / 1.12 / 1.26`, −12 dB). Pitch encodes
  *who* is tapping; timing encodes *on- vs off-beat* — so a saboteur's arrhythmic
  taps land audibly out of pocket at their own tone. The tell is now **hearable**.
- **#3 — unmask drumroll.** The silent 1.6 s between "THE CHARLATAN WAS…" (t=1.6)
  and the unmask (t=3.2) is filled by a **planchette-rattle crescendo**: `bounce`
  every 0.12 s, pitch ramping **0.9 → 1.4** (and volume swelling −15 → −5 dB) into
  the existing `grudge` unmask hit.
- **#4 — staggered ledger.** The settlement rows used to appear **all at once**;
  they now **read out one row every 0.5 s** with a `card` tick each and a
  final-total warm pulse. REVEAL total extends 9.6 s → 11.1 s (still tight).

*(§11 #2 — the TALK ready-up early-end — is out of scope for this pass and was
left untouched.)*

## How it stays presentation-only

`Sfx.play` only offers a symmetric pitch **wobble** around 1.0, so it cannot voice
a seat at a *fixed* 0.9 or 1.26. Rather than touch the shared autoload (which would
break the "seance lane is clean" guarantee and collide with the Q1 music kit), the
game owns a **tiny local `AudioStreamPlayer` pool** that plays the **existing Sfx
bank streams** at an exact `pitch_scale`:

- `_build_pitched_pool()` makes 8 players on the **"SFX"** bus (the same bus the
  AUDIO settings sliders drive). Built once in `_ready`, **skipped entirely in
  tally**.
- `_bank_stream(key)` loads the stream straight from `Sfx.BANK[key]` — **no new
  audio files** ("place" → the chant tick, "bounce" → the drumroll rattle).
- `_play_pitched` / `_play_seat_tick` / `_drumroll_hit` are **inert in tally**
  (`if _tally: return`) and read only already-computed state — no forces, no focus,
  no scoring, no RNG, no bot logic.
- The ledger stagger reuses the same rows in the **same content and order**; only
  *when* each row appears changed. In tally the rows are still added **all at once**
  (`add_settle_row(...)` with the default non-animated path).

The one gameplay-file line inside `_do_tap` — `var on_beat := not spam and dist <=
TAP_WINDOW` — is a rename of the exact boolean the scoring branch already used; the
focus math and tap counters are byte-identical.

## Determinism (byte-identical sim)

Baseline captured **before** the change, re-run **after**, diffed:

```
godot --headless --path . res://minigames/seance/seance.tscn -- --seancetally --seed=5
godot --headless --path . res://minigames/seance/seance.tscn -- --seancetally --seed=1
```

- **seed 5** (`word=WINTER charlatan=BLUE success=true caught=true correct_votes=2`,
  `points RED=2 BLUE=0* GOLD=3 MINT=3`): every sim-state line
  (`SEANCE_COMMIT / TAPS / VOTE / VERDICT / TASK / TALLY / RESULTS / KILL_EVENTS /
  points: / suspicion:`) **byte-identical**.
- **seed 1** (`word=GHOST charlatan=RED success=false caught=true`): **byte-identical**.

The only differing line is `SEANCE_VOTE_OPEN t=…` (78.6 → 78.1 on seed 5), which
prints wall-clock `game_time`, not the pinned-dt sim — it jitters **every** run and
predates this change (documented in `seance-arrows-VERIFY.md`). **DETERMINISM PASS.**

Tally never voices audio: `_build_pitched_pool` is skipped, `_play_*`/`_drumroll_hit`
early-return, and the ledger is added all-at-once — so the evidence harness is
untouched. The windowed run's `SEANCE_RESULTS` also matched the tally exactly.

## Audible-beat wiring (windowed, `--seancebots --seed=5`)

```
godot --path . res://minigames/seance/seance.tscn -- --seancebots --seed=5 \
      --shots=1800,3000 --quitafter=7800 --outdir=verify_out/seance_audio
```

**Chant ticks — seat-distinct pitch (124+ logged during the sitting):**

```
SEANCE_TICK p=0 RED  pitch=0.90 on_beat=false beat=0
SEANCE_TICK p=1 BLUE pitch=1.00 on_beat=true  beat=1
SEANCE_TICK p=2 GOLD pitch=1.12 on_beat=true  beat=2
SEANCE_TICK p=3 MINT pitch=1.26 on_beat=true  beat=0
```

Every seat holds its own pitch across the whole sitting; the `on_beat` flag rides
with the tap, so the off-beat taps are the ones audibly between the pulses:

| seat | RED | BLUE | GOLD | MINT |
|------|-----|------|------|------|
| pitch | 0.90 | 1.00 | 1.12 | 1.26 |

**Unmask drumroll — 13 rattles, pitch 0.9 → 1.4 into the hit:**

```
SEANCE_DRUMROLL pitch=0.90 db=-15.0
SEANCE_DRUMROLL pitch=0.94 db=-14.2
 …  (11 more, monotonically rising) …
SEANCE_DRUMROLL pitch=1.36 db=-5.8
SEANCE_DRUMROLL pitch=1.40 db=-5.0
```

**Ledger stagger — rows read out one at a time (card tick each):**

```
SEANCE_LEDGER row=0 "the seance HELD — the faithful collect royalties"
SEANCE_LEDGER row=1 "BLUE eats 2 grudge, dragged into the light"
SEANCE_LEDGER row=2 "GOLD fingered the charlatan — +1 royalty"
SEANCE_LEDGER row=3 "MINT fingered the charlatan — +1 royalty"
```

These four rows are exactly the baseline settle rows (BLUE caught; GOLD + MINT
fingered), now revealed 0.5 s apart, then a warm total-pulse.

## Screenshots (windowed, `docs/verify/shots/`)

- `seance_audio_sitting.png` — the sitting mid-word ("W\_\_\_\_\_"): all four
  sitters chanting, board + candles + the prior agent's pull-arrows all intact.
  Visuals **unchanged** by the audio pass.
- `seance_audio_reveal.png` — the unmask (where the drumroll lands): WINTER
  revealed, BLUE spotlit as the charlatan, locked vote chips on the portraits.
- `seance_audio_settle.png` — the fully read-out ledger: "THE CIRCLE HOLDS THE
  TRAITOR" over the four staggered rows, captured clean (the snap fires before the
  total-pulse). Same content as the old single-frame dump, now a sequence.

## Files touched

- `minigames/seance/seance.gd` — audio-drama consts + local pitched-tick pool
  (`_build_pitched_pool` / `_bank_stream` / `_play_pitched`); `_play_seat_tick` in
  `_do_tap`; unmask drumroll `_seq_add` loop + `_drumroll_hit` in `_begin_reveal`;
  `_settle_moment` collects rows then `_reveal_next_ledger_row` staggers them;
  REVEAL finish 9.6 s → 11.1 s. All audio guarded so tally/headless is untouched.
- `minigames/seance/seance_ui.gd` — `add_settle_row(..., animate)` fade-in for the
  staggered path (default unchanged); `pulse_settle()` final-total flash.
- `docs/verify/seance-audio-VERIFY.md` + `docs/verify/shots/seance_audio_*.png`.
