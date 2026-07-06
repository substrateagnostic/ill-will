# THE SÉANCE — spectral pull-arrows (verification)

*Owner's design change (2026-07), overriding the original Ouija-deniability
choice: each sitter now shows a little ghostly directional arrow for which way
they are currently dragging the planchette, so the table can watch the arrows
against the letter the circle needs — the saboteur becomes detectable by pull,
not just by chant rhythm. Presentation only. Files touched: `minigames/seance/`
+ `docs/verify/` only.*

## What was built

A per-sitter **spectral pull-pointer** (`SeanceArrow`, new file
`minigames/seance/seance_arrow.gd`), one per seat, **bots included** (a bot
saboteur's pull is the whole point):

- **Anchored at each sitter's edge of the board** — the rim point toward that
  seat's azimuth (`_seat_rim_anchor()`, derived from the planchette's clamp
  ellipse), so the four pointers are spatially separated and each obviously
  belongs to one chair.
- **Rotates to the pull heading** — points the way that sitter is currently
  dragging the planchette (`atan2` on the summed per-seat force).
- **Length + opacity scale with pull strength** — a faint short wisp for a
  nudge, a long bright shaft + arrowhead for a hard yank (`MIN_LEN`→`MAX_LEN`,
  alpha `0.14`→`~0.74`, emission ramps with strength).
- **Fades out ~0.4s after the hand goes idle** — while the pull is under the
  idle epsilon (matching the physics gate ~0.05), the wisp shrinks linearly to
  nothing over `FADE_TIME = 0.4`, keeping its last heading so it dissipates
  pointing where they let go.
- **Candlelit-aesthetic, no hard HUD lines** — unshaded warm-glow translucent
  meshes (the same material family as the surge ripple and dwell ring), bloomed
  by the room's `glow`; a billboard **badge glyph** (● ▲ ■ ◆) floats over each
  tail so identity is **shape + color, never color alone**.
- The pointers **snuff** the instant the sitting ends (`_end_seance` →
  `arrow.snuff()`); they never appear in TALK / VOTE / REVEAL.

## Presentation-only guarantee

The arrows **read** the sitter's current pull where the planchette code already
sums it and **never write anything the sim reads back**:

- In `_tick_seance`, the same per-seat `force := Vector3(mv.x, 0, mv.y)` that is
  fed to `planchette.apply_force(...)` is copied to a **visual-only** array,
  `_pull[i]` (one added line, right after the existing `_contrib[i]` update).
- After `planchette.tick(delta)`, `_update_arrows(delta)` points each arrow with
  `_pull[i]`. It touches **no forces, no physics, no focus meter, no bot logic,
  no scoring, and no RNG** (`rng` / `_fx_rng` are never sampled by arrow code).
- Arrows are **not created at all in headless tally mode** (`if not _tally` at
  spawn), so the evidence harness is untouched.

## Determinism (byte-identical sim)

Per the game's harness (`docs/verify/seance-VERIFY.md`), the deterministic
check is a tally run rerun on one seed and diffed.

```
godot --headless --path . res://minigames/seance/seance.tscn -- --seancetally --seed=5   # run A
godot --headless --path . res://minigames/seance/seance.tscn -- --seancetally --seed=5   # run B
```

**Result:** every sim-state line is byte-identical across runs —
`SEANCE_COMMIT`, `SEANCE_VOTE`, `SEANCE_VERDICT`, `SEANCE_TASK`, `SEANCE_TALLY`,
`points:`, `suspicion:`, `SEANCE_RESULTS`, `KILL_EVENTS` all match
(seed 5: `word=WINTER charlatan=BLUE success=true caught=true correct_votes=2`,
`points RED=2 BLUE=0* GOLD=3 MINT=3`). **DETERMINISM PASS.**

The only line that differs is `SEANCE_VOTE_OPEN t=…`, which prints `game_time`
(wall-clock elapsed, not the pinned-dt sim). It varies **every** run
(78.4 / 78.2 / 78.1 / 77.9 across four runs) — inherent real-frame jitter that
predates this change and is independent of both the sim and the arrows (arrows
don't run in tally mode at all).

## Screenshots (windowed bot run, `docs/verify/shots/`)

```
godot --path . res://minigames/seance/seance.tscn -- --seancebots --seed=1 --shots=… --outdir=…
# seed 1: word=GHOST, charlatan=RED (● circle, north/far seat)
```

- `seance_arrows_saboteur.png` — **the saboteur moment.** Mid-sitting ("G____"
  spelled, next-needed = H): **BLUE (▲) drives right toward H, GOLD (■) and MINT
  (◆) lean in — while RED (●), the paid hand, drags LEFT, away from the needed
  letter.** Four arrows, one diverging, and it is the actual Charlatan.
- `seance_arrows_diverge.png` — the boldest single divergence: all four
  pointers up, GOLD's shaft shooting hard off the left rim while BLUE points to
  the needed letter — the "who is dragging it where" read at a glance.
- `seance_arrows_converge.png` — context frame: GOLD and BLUE converging toward
  the letter cluster, colored wisps + badge glyphs legible in the candle-dark.
- **Idle-fade proof (a 3-frame filmstrip of GOLD, ~0.4s):**
  - `seance_arrows_fade_1_full.png` — GOLD pulling: full-length yellow arrow.
  - `seance_arrows_fade_2_shrink.png` — 6 frames later: GOLD has gone idle, the
    wisp has shrunk to a stub.
  - `seance_arrows_fade_3_gone.png` — ~0.4s after idle: GOLD's arrow is gone
    (only the ■ badge remains); the other sitters' arrows are unaffected.

## DESIGN NOTE — detectable vs. deniable (re: `06-social-deduction-research.md` pitch #1)

Pitch #1 built the séance to be **detectable-but-deniable**: "because four hands
tap in parallel, no one can watch all of them — so a Charlatan mistiming taps or
nudging onto a wrong letter is deniable as clumsiness or lag. The tell is
behavioral." The original planchette explicitly refused to visualize individual
hands ("individual hands are NOT visualized — Ouija deniability") — only the
shared motion, the per-suspect candle flare, and the *anonymous* surge ripple
were public.

**What the arrows do to the balance:** they move the dial deliberately toward
**detectable**. Each hand's pull *direction* is now public, so a watcher can see
who is dragging the planchette which way and check it against the letter the
circle needs — exactly the owner's intent (the saboteur is caught by watching
arrows vs. the needed letter). Sabotage is more visible than before.

**Why deniability is not destroyed:**
1. **A single diverging arrow is not proof.** Honest sitters (and the honest
   bots, by design) frequently pull toward *plausible-but-wrong* letters — the
   `seance_arrows_diverge.png` frame's lone outbound arrow is an *honest* player.
   Guilt still lives in the **sustained pattern** (consistently steering off the
   needed letter + off-beat chant + a yank when a correct letter is charging),
   which the arrows now make watchable *over time* rather than convicting in one
   frame.
2. **Four arrows still can't all be watched at once** — the doc's
   parallelism-deniability survives; you can scrutinize one suspect's pull or
   another's, not all four simultaneously.
3. The arrows are **presentation only** — they change nothing about the forces,
   focus, or scoring, so the underlying detectable-but-deniable *mechanics* are
   exactly as tuned; only their *legibility* increased.

**One knob to turn if it proves too revealing:** gate the arrows to **surges
only** — keep ordinary stick-steering hidden (restoring full Ouija deniability
for steady pulls) and only draw a directional, attributed arrow on a **B-surge**
(the saboteur's emergency yank, and honest players' course-corrections). That
narrows the public tell to the loudest, riskiest action. A softer alternative is
**arrow jitter/lag**: add a small seeded angular wobble or smoothing latency so
the exact heading is fuzzy and a single glance can't precisely convict (mirrors
the "looks like a hand, not a servo" wobble the bots already use). Either is a
one-line change confined to the presentation layer (`SeanceArrow.drive` / the
`_update_arrows` gate) with zero sim impact.

## Files touched

- `minigames/seance/seance_arrow.gd` — **new**: the `SeanceArrow` pull-pointer.
- `minigames/seance/seance.gd` — `_pull` + `_arrows` state; spawn arrows in
  `_spawn_figures` (+ `_seat_rim_anchor`); capture `_pull[i]` in `_tick_seance`;
  `_update_arrows`; snuff on `_end_seance`. All guarded so headless/tally is
  untouched.
- `docs/verify/seance-arrows-VERIFY.md` + `docs/verify/shots/seance_arrows_*.png`.
