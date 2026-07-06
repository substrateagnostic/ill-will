# Eyes-closed secret delivery — the VOICE SUMMONS (verification)

*Playtest fix from the first outside tester (Andrew, round 1). Presentation /
timing only. Files touched: `minigames/seance/`, `minigames/understudy/`, and
`docs/verify/`. Word selection, roles, scoring, votes and bot logic are
UNCHANGED — only how the eyes-closed casting is paced and announced.*

## What the tester found

> "Eyes closed section needs longer in betweens. Also how da hell if everyone
> eyes are closed are people supposed to know who should look first."

He is right. Both theater games (THE SÉANCE, THE UNDERSTUDY) deliver secret
roles one seat at a time with everyone else's eyes shut — and the only cue for
"it's your turn" was a **visual** card. A player with their eyes closed cannot
see "GOLD — LOOK NOW". The handoffs were also too quick to keep up with.

## The fix (both games, one house language)

Both games already voice seats at **seat-distinct pitches** (THE SÉANCE's chant
tick: RED 0.90 / BLUE 1.00 / GOLD 1.12 / MINT 1.26). That same mapping is now
the **turn summons**, so the sound a player learns in one game means the same
thing in the other.

1. **AUDIO SUMMONS.** When it becomes a seat's turn, the room plays **that seat's
   pitch three times** (tick·tick·tick, 0.35 s apart, at −4 dB — louder than the
   −12 dB chant tick so it carries with eyes shut) **before** any private content
   appears, then a **fourth confirmation tick** as the reveal turns up. Nobody
   has to see anything to know it's their turn.

2. **VOICE ROLL-CALL (teaches it once, eyes OPEN).** During the casting intro,
   before any eyes close, the Executor runs an **~9 s roll-call**: "Your colour
   has a voice… RED, this one is yours" → RED's triple-tick → BLUE's → GOLD's →
   MINT's. Every player hears their own pitch **with their eyes open** before
   they ever have to recognise it blind.

3. **LONGER IN-BETWEENS.** Per the tester: **≥ 2.0 s of silence** between one
   seat's eyes-down handoff and the next seat's summons, and reveal hold times
   **+50 %** (séance 2.6 s → 3.9 s; understudy bot commit 1.1 s → 1.65 s).
   Nothing rushes.

4. **Reveal cards restated.** The card names the summoned seat **HUGE** (for the
   one player peeking) and carries the standing instruction **"everyone else —
   eyes down · listen for your voice"** the whole time a private card is up.

## How it stays presentation-only (determinism preserved)

- **THE SÉANCE** — the summons is voiced by the existing local pitched-tick pool
  (`_play_pitched` over the `place` bank stream). New `_play_summons_tick(seat)`
  and a rewritten `_begin_cast()` roll-call + per-seat summons are all inside the
  CAST phase, which draws **no RNG** (word + charlatan are drawn in `begin()`
  before CAST). Every audio call is `if _tally: return`. Phase DURATION grew;
  the sim did not.
- **THE UNDERSTUDY** — gained the same tiny pitched-tick pool (`_build_pitched_pool`
  / `_bank_stream` / `_play_pitched` / `_play_summons_tick`, over the `card` bank
  stream). The roll-call (`Cast.ROLLCALL`) and the inter-seat gap (`Cast.GAP`) run
  **only when not `_tally`** — the headless evidence run takes the original
  straight-to-`_present_call` path, so the sim sequence is byte-for-byte the same.
  The summons-tick scheduler in the `CALL` step is guarded `if not _tally`, and
  the tick calls early-return in tally regardless.

### Tally receipts — byte-identical

```
godot --headless --path . res://minigames/seance/seance.tscn      -- --seancetally --seed=5
godot --headless --path . res://minigames/understudy/understudy.tscn -- --ustally  --seed=1 (and 2, 3)
```

| run | sim lines diffed | result |
|-----|------------------|--------|
| séance seed 5 (`word=WINTER charlatan=BLUE success=true caught=true`) | 20 (`SEANCE_COMMIT / TAPS / TASK / VERDICT / RESULTS / TALLY / points: / suspicion:`) | **BYTE-IDENTICAL** |
| understudy seed 1 (`champ=RED 9`) | 67 (`US_ROUND / CUE / VOTE / ACCUSE / MAJORITY / DISTRIBUTED / RESULTS / MATCH_OVER / TALLY`) | **BYTE-IDENTICAL** |
| understudy seed 2 (`champ=BLUE 9`) | 67 | **BYTE-IDENTICAL** |
| understudy seed 3 (`champ=BLUE 9`) | 67 | **BYTE-IDENTICAL** |

Baseline captured before the change, re-run after, `diff` empty in all four.

## Triple-tick evidence (windowed bot runs)

**THE SÉANCE** (`--seancebots --seed=5`) — every seat holds its own pitch; the
roll-call fires exactly three per colour, then each turn summons fires three more
plus a confirmation:

```
SEANCE_SUMMONS p=0 RED  pitch=0.90   (×3 roll-call, ×3 summons, ×1 confirm)
SEANCE_SUMMONS p=1 BLUE pitch=1.00
SEANCE_SUMMONS p=2 GOLD pitch=1.12
SEANCE_SUMMONS p=3 MINT pitch=1.26
```

**THE UNDERSTUDY** (`--usbots --seed=1`) — same mapping, over the `card` tone:

```
US_SUMMONS seat=0 RED  pitch=0.90   (roll-call ×3 in order RED→BLUE→GOLD→MINT,
US_SUMMONS seat=1 BLUE pitch=1.00    then per-seat CALL ×3 + confirm ×1)
US_SUMMONS seat=2 GOLD pitch=1.12
US_SUMMONS seat=3 MINT pitch=1.26
```

## Screenshots (windowed, `docs/verify/shots/`)

- `seance_eyes_rollcall.png` — the teaching moment: "● RED / this is your voice —
  listen", Executor "RED — this one is yours", **eyes open**.
- `seance_eyes_summons.png` — a turn summons: "● RED" huge, "eyes open — this is
  for you alone", standing footer "everyone else — eyes down · listen for your
  voice".
- `us_eyes_rollcall.png` — "▲ BLUE / THIS IS YOUR VOICE — REMEMBER IT", BLUE's
  actor lit alone, "BLUE — three ticks in your tone", Executor teaching line.
- `us_eyes_summons.png` — "● RED — YOUR PART" huge, standing instruction
  "EVERYONE ELSE — EYES DOWN · LISTEN FOR YOUR VOICE", the private script card.

## Files touched

- `minigames/seance/seance.gd` — `SUMMONS_TICK_DB` / `SUMMONS_GAP` consts;
  `_play_summons_tick`; `_begin_cast()` rewritten (voice roll-call, per-seat
  triple-tick + confirmation, ≥2 s gaps, +50 % reveal hold, standing footer).
- `minigames/seance/seance_ui.gd` — `cast_show(...)` gains a standing `foot`
  line; `_cast_foot` label.
- `minigames/understudy/understudy.gd` — pitched-tick pool + `_play_summons_tick`;
  `Cast.ROLLCALL` / `Cast.GAP`; `_enter_casting` / `_tick_casting` / `_present_call`
  / `_present_teach` / `_tick_rollcall` (roll-call, summons, ≥2 s gap). Tally path
  unchanged.
- `minigames/understudy/us_reveal.gd` — standing instruction restated on the call;
  `show_rollcall_intro` / `show_teach` / `show_gap`.
- `docs/verify/eyesclosed-VERIFY.md` + `docs/verify/shots/{seance,us}_eyes_*.png`.
