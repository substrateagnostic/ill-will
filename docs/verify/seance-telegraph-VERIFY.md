# THE SÉANCE — pull-arrow telegraph gate (verification)

*Producer ruling: "if you can see the arrows, you can see who the unfaithful
is — needs to be somewhere in the middle, some telegraph without giving the
game away." Presentation only. Files touched: `minigames/seance/` +
`docs/verify/` only. Coexists with the audio drama pass
(`seance-audio-VERIFY.md`) — nothing there was reverted.*

## The complaint, and why the arrows earned it

`seance-arrows-VERIFY.md` (the prior pass) gave every sitter a spectral
pull-pointer, visible continuously and in full precision, over the game's
original Ouija-deniability design. Its own closing note flagged the risk and
proposed two knobs: gate to surges only, or **"arrow jitter/lag: add a small
seeded angular wobble or smoothing latency so the exact heading is fuzzy and a
single glance can't precisely convict."**

The producer confirmed the risk played out: `seance_bots.gd` retargets each
honest bot's pull every 1–2.6s, but the saboteur (`_pick_target`) excludes
every word letter after the 6s alibi window closes — so a saboteur's arrow
diverges from the honest three on the overwhelming majority of retargets.
Watching one wisp continuously for even ten seconds converged on certainty
long before the 90s sitting ended. The full-time, full-precision arrow made
the tell too legible.

## The fix: gate HEADING to the candle's own heartbeat, not PRESENCE

Two things an arrow shows are not equally sensitive:

- **PRESENCE** (a hand is on the board, and how hard) — harmless. Every
  sitter's hand is on the planchette most of the sitting; hiding it would
  read as a bug, not a tell.
- **HEADING** (exactly which letter they're steering toward) — the actual
  secret-adjacent information, since it's checked against the letter the
  circle needs.

`SeanceArrow.drive()` (`minigames/seance/seance_arrow.gd`) now takes a third
argument, `pulse: float` — the *exact* 0..1 candle-flare envelope that already
brightens the spirit flame each beat (`seance.gd`: `maxf(0.0, 1.0 -
beat_time()*5.0)`, reused verbatim, not reimplemented). PRESENCE (`_shown`,
driving length/opacity) still updates every frame, unconditionally. HEADING
(`rotation.y`) only turns toward the sitter's true pull while `pulse >=
CATCH_THRESH (0.32)` — roughly the first 0.14s after each 0.85s beat fires.
Outside that window the arrow **holds its last-caught heading, frozen**.

Why this option over the doc's other two ("surges only" / plain jitter):

- **Surges-only** would have hidden the steady-steering tell entirely (the
  dominant signal — a saboteur's *retarget pattern* — lives in ordinary stick
  input, not the rare B-press), trading "too revealing" for "not revealing
  enough."
- **Plain angular jitter/smoothing-lag** (a continuous fuzzy/laggy heading)
  still converges to the truth under a *sustained* watch across the full 90s
  — it slows the read, it doesn't change what a patient viewer eventually
  learns.
- **The beat-gate** does what a glance-based UI needs: it makes reading the
  table a **sampling problem with a real cost**. The catch window is the same
  ~0.14s slice of each beat where the whole room visibly brightens (a free,
  diegetic "look now" cue — no new UI element), and it's the *same beat* a
  sitter is meant to be chanting on. Watching for the true heading means
  looking away from your own planchette aim and choosing not to chant that
  beat — the same trade the game's other tells already impose. A single
  glance mid-beat shows a **stale snapshot**; only sustained, costly attention
  across many beats accumulates enough true-heading samples to build a
  pattern. Suspicion stays legible; certainty from one glance does not.
- **Proximity-based reveal** (the third example in the brief) doesn't fit
  this game's camera model — the séance is one fixed shared-screen shot, not
  a per-player perspective, so there is no "distance" for a mirror client or
  couch player to be near or far from.

No sim/wire change: `pulse` is derived identically, locally, by both the host
(`_tick_seance`) and the mirror (`_mirror_tick`) from already-public beat
timing (`beat_time()` / `_mir_el`). Nothing new rides `_net_state()`.

## Presentation-only guarantee (unchanged from the prior pass)

- `SeanceArrow.drive` still reads only `_pull[i]` (visual-only, copied from
  the same per-seat force already fed to `planchette.apply_force`) and now
  also `pulse` (visual-only, copied from the same value already driving the
  spirit-flame material). It writes nothing the sim reads back — no forces,
  no focus, no bot logic, no scoring, no RNG (`rng` / `_fx_rng` untouched).
- Arrows are still not created at all in headless tally (`if not _tally` at
  spawn) — the evidence harness is untouched.

## Determinism (byte-identical sim)

```
godot --headless --path . res://minigames/seance/seance.tscn -- --seancetally --seed=5
godot --headless --path . res://minigames/seance/seance.tscn -- --seancetally --seed=1
```

- **seed 5**: `SEANCE_TALLY seed=5 word=WINTER charlatan=BLUE success=true
  caught=true correct_votes=2` / `points: RED=2 BLUE=0* GOLD=3 MINT=3` —
  **byte-identical** to the baseline recorded in `seance-arrows-VERIFY.md`
  and `seance-audio-VERIFY.md`.
- **seed 1**: `SEANCE_TALLY seed=1 word=GHOST charlatan=RED success=false
  caught=true correct_votes=2` / `points: RED=0* BLUE=0 GOLD=1 MINT=1` —
  **byte-identical** to the same baseline.

**Result: NO MOVEMENT.** The catch-window gate is confined entirely to
`SeanceArrow`'s own rotation-update branch and a `pulse` value neither read
by nor derived from anything the sim touches — every `SEANCE_COMMIT / TAPS /
VOTE / VERDICT / TASK / TALLY / RESULTS / KILL_EVENTS` line matches the
frozen receipt exactly. (Per the task brief: had this moved, the move would
be sanctioned and documented old-vs-new here — it did not move, so there is
nothing to reconcile.)

Board receipts (unrelated code, checked per the runtime rules):

```
godot --headless --path . -- --procession --boardgraphtest
  → BOARDGRAPH checksum=b269c570  BOARDGRAPH_OK   (unchanged)
godot --headless --path . -- --procession --seed=7 --turncap=12 --nights=3 --autoplay=bots
  → PROCESSION_HEIR GOLD (seed 7, 3 nights), wreaths=[36,41,56,43]   (unchanged)
```

## Screenshot

`docs/verify/shots/seance_telegraph_midround.png` — the automatic `"board"`
event snap (fires at `seance_elapsed >= 30.0`, mid-sitting), captured with the
new gate live (`--seancebots --seed=5`). All four spectral arrows are present
around the board — the telegraph still exists and is still legible on a
sustained watch — each anchored at its sitter's rim with its shape+color
badge (● RED / ■ GOLD / ▲ BLUE / ◆ MINT). The frame is one instant; the
design claim (stale-outside-the-catch-window) is a *timing* property that a
single still cannot itself prove — it is proven instead by the deterministic
formula shared verbatim with the spirit-flame flare (see source) and by the
identical `pulse` value being fed to both, so the arrows visibly sharpen in
lockstep with the same beat that already brightens the candle.

## Files touched

- `minigames/seance/seance_arrow.gd` — `drive()` gains the `pulse` param;
  `CATCH_THRESH` / `CATCH_LERP` consts; heading updates gated to the catch
  window, presence ungated; header doc expanded with the TELEGRAPH GATE note.
- `minigames/seance/seance.gd` — `_update_arrows(delta, pulse)`; both call
  sites (`_tick_seance`, `_mirror_tick`) pass the already-computed local
  `pulse` var through, no new state.
- `docs/verify/seance-telegraph-VERIFY.md` +
  `docs/verify/shots/seance_telegraph_midround.png`.
