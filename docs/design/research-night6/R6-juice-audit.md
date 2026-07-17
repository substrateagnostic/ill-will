# R6 — Juice / Game-Feel Audit, ILL WILL (15 games)

Read-only research pass. Quality bar used throughout: **estate/procession/board_fx.gd**
(flying attributed numbers `fly_number`, wax-seal `fly_deed`), **core/final_stretch.gd**
(`FinalStretch.fov_punch` — the shared "deciding moment" camera punch-in synced to a
game's own freeze, real-time/ignore_time_scale, gated on `MomentScribe.capture` +
reduced-motion pref), **core/moment_scribe.gd** (throttled still-frame capture for the
newsreel/album — NOT a replay, a photo), and **core/podium.gd** (redressed estate
ceremony: moonlit EnvKit, stone plinths, funeral wreath, ash/ember confetti). The golf
game's own kit — **scripts/main.gd** (`_resolve_death_cinematics` / `_start_killcam` —
a REAL kill-cam with determinism-timeline guards, `_slow_mo()`, confetti-on-sink,
narrated death banners) and **scripts/camera_rig.gd** (`shake()`, `focus_on()`,
`start_flyover()`) — is more cinematically mature than any of the 14 minigames.

## Canonical game-feel checklist (quick research pass)

Sources: Jan Willem Nijman / Vlambeer, ["The Art of Screenshake"](https://www.youtube.com/watch?v=AJdEqssNZ-U)
(INDIGO Classes 2013; summary via [GameDesign.gg](https://www.gamedesign.gg/knowledge-base/game-design/game-feel-feedback/the-art-of-screenshake-jan-willem-nijman-vlambeer/));
Martin Jonasson & Petri Purho, "Juice It or Lose It" (2012), summarized at
[GameJuice](https://gamejuice.co.uk/resources/juice-it-or-lose-it) and
[valdemird.com](https://valdemird.com/blog/game-feel-on-the-web/).

- **Screenshake has magnitudes** — small (routine), medium, large (a real event) — and
  medium/large shake should add a FRACTION OF A DEGREE of camera **rotation**, not just
  translation. Nijman's specific point: pure positional jitter reads as a glitch;
  a tenth of a degree of rotational jitter reads as physical force. **ILL WILL's shared
  `_shake` pattern (below) is translation-only (`h_offset`/`v_offset`) in every game —
  this is a one-line-per-site, zero-risk, house-wide upgrade.**
- **Freeze frames / hitstop** — a few frames (or tens of ms) of near-zero time on
  impact sells weight before the knockback plays. ILL WILL already has this ("HIT KIT
  §B1 Phase 2 hitstop", softened 0.05→0.15 time_scale after playtesting felt too harsh).
- **Squash & stretch** — anticipation (coil) + impact (squash) + recovery (over-shoot
  pop) on ANY moving/scoring object, not just characters.
- **Particles / juice-per-event** — Purho/Jonasson's signature: bury every scoring
  event in colored debris; the object that made the world change should visibly shed
  something.
- **Screen/world feedback beyond the object** — vignette pulses, color flashes,
  environment reacting (the "juice it or lose it" talk's escalating layering).
- **Exaggeration + anticipation + follow-through** (classic animation principles,
  reapplied to game feel) — a windup that reads before the hit, a followthrough after.
- **Audio-visual sync** — a thud/sting exactly on the frame of impact, not after.
- **Camera language for stakes** — punch-ins, focus-pulls, and slow-mo reserved for
  moments the player should remember (match point, a kill, a lead change), so the
  camera itself communicates "this mattered."
- **Haptic feedback (controller rumble)** — the physical channel completely orthogonal
  to screen shake; a couch multiplayer game is exactly where it pays off most (each
  pad rumbles independently, no shared-screen tradeoff). **Zero occurrences anywhere
  in this codebase** (`grep -i "vibrat|joy_vibration"` across all `.gd` files: no
  matches). This is the single cleanest total gap in the whole anthology.
- **Kill-cam / instant replay** — a short slow-mo replay from a dramatic angle of the
  decisive hit, distinct from a single freeze-frame photo. ILL WILL has this ONLY in
  the golf game (`scripts/main.gd:_start_killcam`), gated behind careful
  "timeline-neutral" / chaos-round / headless guards so receipts stay byte-identical.
  None of the 14 minigames have an equivalent — they get `MomentScribe.capture`, which
  is a single still PNG for the newsreel, not a played-back moment.

## The shared house kit (context for every game below)

Every combat-adjacent minigame implements the same **HIT KIT** primitives, largely
copy-pasted per-game (fighter.gd / royal.gd / lw_pawn.gd / wg_pawn.gd / greed_player.gd
/ pb_carrier.gd):
- `_squash_tw`: coil-scale on windup, `Vector3(1.08,0.90,1.08)`→`ONE` pop on landing/hit,
  a harder `Vector3(1.22,0.85,1.22)`→`ONE` pop on a heavier hit.
- `_shake` float, decayed `lerpf(_shake, 0.0, 1-exp(-6*delta))`, read every `_process`
  into `cam.h_offset` / `cam.v_offset` jitter (`randf_range(-1,1) * _shake * 0.3`-ish).
  Gated everywhere on `PartySetup.pref("screen_shake", true)`.
- Hitstop via `Engine.time_scale` dropped to ~0.15-0.4 for tens/hundreds of ms, restored
  on a `create_timer(dur, true, false, true)` (real-time timer, so it survives its own
  freeze) — EXCEPT **orbital** and **swap_meet**, which deliberately built a
  **tick-counted slow-mo budget that never touches `Engine.time_scale`** specifically
  so their receipts stay byte-identical (documented explicitly in both VERIFY.md files,
  proven via full event-log diff at seed 11). This is the correct, already-solved
  pattern for adding slow-mo to any game with receipts, and should be the template
  copied rather than re-solving the determinism problem per game.
- A pop-scaled "banner" (`Label`/`Control` `scale` BACK-eased to `ONE`) for every named
  event — this IS the anthology's announcer/toast system, and it's genuinely good:
  attributed, colored, sometimes narrated ("PAST RED STRIKES AGAIN", "RED'S GHOST
  ORBIT STRIKES! 44-SECOND-OLD THROW TAKES OUT BLUE", "THE CRATE (GOLD) CLAIMS BLUE /
  RED").
- `FinalStretch.attach()` for tension music + optional vignette/ticks in the last 10s,
  and `FinalStretch.fov_punch()` for a real-time fov punch-in synced to a game's own
  deciding-moment freeze (this is what a "match point" camera language looks like here).

---

## Per-game audit

### 1. dead_weight
HAS: fighter.gd HIT KIT (squash-pop, spark cone along knockback), shake (0.5 cap, 0.28
micro), hitstop via slow-mo beat (`time_scale 0.32 for 0.4s` per VERIFY.md), `Engine.time_scale
= 6.0` bot-sim fast-forward (separate concern, not juice), `FinalStretch.fov_punch`
called TWICE (round win + HOUSE AWAKENS-adjacent beat), CLAIMS banner, poltergeist/prop
particle effects.
DESERVES: already one of the 5 "complete" games (fov_punch parity group: dead_weight,
echo_chamber, throne, tilt, widows_gaze). Missing only rumble + rotational shake (house-wide).

### 2. echo_chamber
HAS: the HEAVIEST shake tuning in the anthology (max 0.9), the most precisely documented
hitstop ("0.05s freeze at time_scale 0.2 on impact, throttled 0.16s" — VERIFY.md calls
this out explicitly as tuned-by-feel), HOP_SQUASH squash-stretch, `fov_punch` called
twice, bounty/credit banners, ring-out warning banner.
DESERVES: this is the one game whose THEME begs for a real kill-cam — the whole
mechanic is "your past selves fight in the present." A ghost's kill replaying as a
literal echo (a translucent instant-replay of the recorded input stream that made the
kill) would be nearly free thematically and mechanically (the ghost's input log
already exists as the game's core data structure) but currently gets only banner +
shake + hitstop, same as every other game — no visual distinction for the fact that
the killer *is* a replay.

### 3. greed
HAS: full HIT KIT (softened hitstop to 0.15 time_scale per an explicit playtest note),
shake (0.7 cap on the big grab), spark, banner, `pot_flash` scale-pop on the pot itself.
`FinalStretch.attach(..., {"ticks": false})` — attached but with no `fov_punch` call
anywhere in the file.
DESERVES: LAST BANKS (the closing-bell climax, per FinalStretch's own doc comment
listing it as greed's bespoke endgame beat) gets tense music + the red vignette but
NOT the camera punch-in the other 5 fov_punch games get on their own climax.

### 4. last_will
HAS: full HIT KIT via lw_pawn.gd, TWO separate shake-tick blocks in the file (likely
race-cam + a second camera context), curse-stone scale animation, arc/ring particle
tweens, banner. `FinalStretch.attach()` called but **no `fov_punch` call** anywhere.
DESERVES: first-to-crypt (the race finish — this game's whole identity, "3 lives, die
→ curse a stretch of road, first-to-crypt") has no deciding-moment camera language at
all. Of everything audited, this is the single biggest mismatch between a game's
stated identity and its ending's camera treatment.

### 5. masked_ball
HAS: `_tick_shake` (shared pattern), mask-shrink-to-near-zero reveal tween (mb_dancer.gd,
the unmasking beat), ring pulse (mb_ghost.gd), pop-scaled banners.
**No `FinalStretch` reference anywhere in the file** — no tension music bed, no
vignette, no ticks, no fov_punch, for the entire game.
DESERVES: the reveal (guessing who's who among 20 identical dancers via a feather-glint
tell) is the ENTIRE game, and it currently resolves as a scale-tween + banner with zero
camera reaction and zero escalating tension bed in the run-up — the one place in the
anthology where a slow zoom-in + a held beat before the reveal (classic "who is it"
game-show grammar) would cost almost nothing and pay off enormously.

### 6. mower
HAS: full HIT KIT, `Engine.time_scale = 0.4` hitstop beat, shake, banner,
`FinalStretch.attach()`. **No `fov_punch` call.**
DESERVES: the Splatoon-style territory tally at time's up is a visual reveal moment
(a top-down "who painted more turf" flip) that gets a banner but no camera punch/pull-back
— a natural, cheap addition given the tally is already a discrete, scriptable beat.

### 7. orbital
HAS: shake scaled continuously off a threat/tension value (up to 0.82), kill banners
with genuinely great flavor text ("44-SECOND-OLD THROW TAKES OUT BLUE"),
`FinalStretch.attach(..., {"vignette": false})`, and — importantly — **the anthology's
best-engineered slow-mo**: explicitly documented as tick-counted and never touching
`Engine.time_scale`, specifically so the sim stays byte-identical (this should be the
reference pattern, not a gap).
**No `fov_punch` call.**
DESERVES: the T-30 sudden-death escalation (its own named threshold) doesn't get the
camera punch the tick-safe slow-mo infrastructure would make trivial to add.

### 8. pallbearers (game #15, newest, 2v2 team)
HAS: pb_carrier.gd squash on hop/nudge/heave/drop, shake, banner, `FinalStretch.attach()`,
an explicit `_no_juice` flag to keep the balance-tally headless path byte-stable (good
discipline). **No `fov_punch` call.**
DESERVES: the coffin DROP + one of the ~6 written complaint barks
("COMPLAINTS[rng...]") is the game's signature comedy beat and currently gets only
squash+shake+a text bark — no camera reaction at all to a team physically failing at
their one job. Being the newest game, it has the least accumulated polish of the
combat-adjacent titles; it's the one place a coffin literally hitting the ground gets
LESS camera attention than a routine hit in dead_weight.

### 9. seance
HAS: `_tick_shake` (0.4 cap), scale-pop score labels (1.45x bump), banner, a generic
`Engine.time_scale` hitstop hook. **No `FinalStretch` reference anywhere** (same gap as
masked_ball/understudy).
DESERVES: as a mystery/deduction game, the accusation reveal deserves the same
escalating-tension bed (music, vignette) the physical games get before their climax —
currently there is zero ramp into the moment that decides the round.

### 10. swap_meet
HAS: shake (item-weighted: 0.55 for golden vs 0.4 normal), `crown_flash` scale-pop,
beam/ring particle scale tweens, banner, `FinalStretch.attach()`, and — like orbital —
**tick-counted slow-mo proven never to touch `Engine.time_scale`** (VERIFY.md: "full
event-log diff, seed 11"). **No `fov_punch` call.**
DESERVES: the "photo finish" (its own named climax per project memory) is precisely
the moment `fov_punch` exists for, and the tick-safe slow-mo plumbing needed to gate it
safely already exists in this file — this is the lowest-friction fov_punch add of the
six missing games.

### 11. throne
HAS: the most complete treatment in the anthology — shake up to 0.95 (a dethroning),
softened hitstop, `fov_punch` called TWICE, crown scale-pop (1.35–1.4x), a decree-ring
particle expand, pop-scaled banners, full `FinalStretch`. Use this as the internal
benchmark alongside golf's kit.
DESERVES: essentially at the bar already; the one add that would matter is rumble on
the dethrone hit, and the rotational-shake upgrade like everywhere else.

### 12. tilt
HAS: full HIT KIT, shake, hitstop, `fov_punch` called twice, the OVERTIME
`gain_scale`/`overtime_scale` mechanic (platter.gd) driving torque response, a pin-rise
scale tween for sudden death.
DESERVES: also near the bar; missing only rumble + rotational shake.

### 13. understudy
HAS: card-flip squash (a real squash-stretch: horizontal scale to 0.04 then BACK-eased
recovery, "sell the turn-over" per its own comment), board-chip scale pops, verdict
scale pop. **No shake, no hitstop, no `FinalStretch` anywhere** — consistent with
seance/masked_ball (the non-physical "theater trio" all skip the escalation kit, likely
by design since there's no combat to hitstop).
DESERVES: the VERDICT (correct/incorrect cast guess) is this game's entire payoff and
currently is a scale-pop with no camera or tension-bed reaction at all — of the three
theater games this is the starkest "nothing but a UI tween" ending.

### 14. widows_gaze
HAS: the most shake call-sites of any game (five separate `_shake = maxf(_shake, 0.5)`
freeze-tag-catch moments), `fov_punch` called twice, a DISTINCT freeze/thaw squash tween
in wg_pawn.gd (separate from the combat HIT KIT — a nice touch, freezing reads
differently from being hit), hitstop, an explicit "lightning + squash-pop + hitstop +
shake" comment describing its own catch beat, banner.
DESERVES: also at the bar (fov_punch group); a rumble pulse on the "gotcha" freeze-catch
(the whole game's core verb) would be the highest-value single addition for this title.

### 15. PAR / golf (board-embedded — scripts/main.gd, camera_rig.gd, grief_controller.gd,
estate/procession/pawn_putt.gd)
HAS: everything the other 14 have PLUS a real **kill-cam** (`_resolve_death_cinematics`
→ `_start_killcam`, with explicit "timeline-neutral" / chaos-round / headless-skip
guards so a determinism-sensitive context degrades gracefully to a banner instead of
touching the clock), `_slow_mo()` (0.3 time_scale, 0.4s, used both on kills and on
already-claimed/chaos paths), confetti on EVERY sink (not just the podium), a
dedicated `camera_rig.focus_on()` cinematic focus-pull independent of shake, narrated
death banners with authorship ("SIGNED WORK" / "UNSIGNED" / "SELF-INFLICTED. THE ESTATE
APPLAUDS."), and `camera_rig.shake()`.
DESERVES: this is the anthology's actual ceiling — frozen-putt-physics notwithstanding,
the presentation layer here is untouchable by comparison. The one gap shared with
everything else: no controller rumble on a sink or a death.

---

## Cross-cutting gaps (apply to some or all 15)

1. **Controller rumble: zero anywhere.** Confirmed via `grep -i "vibrat|joy_vibration"`
   across every `.gd` file in the repo — no results. Every game already computes a
   `_shake` magnitude per hit that is a ready-made proxy for vibration strength.
2. **Screenshake is translation-only house-wide.** Every `_shake`→`h_offset`/`v_offset`
   site (13+ occurrences across dead_weight, echo_chamber, greed, last_will (x2),
   masked_ball, mower, orbital, pallbearers, seance, swap_meet, throne, tilt,
   widows_gaze) skips the rotational component Nijman's talk identifies as the actual
   "force" signal.
3. **`fov_punch` (the shared deciding-moment camera language) is missing from 6 of the
   9 games that already `FinalStretch.attach()`**: greed, last_will, mower, orbital,
   pallbearers, swap_meet. The other 5 (dead_weight, echo_chamber, throne, tilt,
   widows_gaze) already call it. This is a parity gap, not a missing system — the
   system exists, is proven safe, and is simply uncalled in 6 files.
4. **No `FinalStretch` at all in the 3 "theater" games** (masked_ball, seance,
   understudy) — no tension music bed, no vignette, no ticks, for any of them. May be
   intentional (no combat, no clock-pressure framing) but their climaxes (reveal /
   accusation / verdict) get no escalation treatment of any kind, unlike every other
   game's ending.
5. **No true kill-cam/replay anywhere except the golf game.** `MomentScribe.capture`
   (used by all 15 games' `fov_punch` calls and the podium) is a single still PNG, not
   a played-back replay. The golf game solved the hard part (determinism-safe replay
   gating) already; porting the *pattern* (not the code) to one signature moment
   per combat game is the highest-ceiling, highest-effort item here.

---

## Determinism-risk framing (per the task constraint)

- Rotational shake, `fov_punch` calls, squash-stretch, particle bursts, and rumble are
  all **presentation-only**: they touch `Camera3D.h_offset/v_offset/rotation`, `Label`/
  `Node3D.scale`, `CPUParticles3D`, and (proposed) `Input.start_joy_vibration` — none of
  which are read by any game's sim state, rng stream, or receipt/tally output. Every
  game in this anthology already has the discipline to gate this class of effect behind
  `PartySetup.pref("screen_shake", true)` / `_headless` / `_no_juice`-style flags, so
  adding more of the same is a proven-safe pattern, not a new risk.
- Anything that touches `Engine.time_scale` for a NEW visual slow-mo in a game that
  ships receipts (nearly all of them — VERIFY.md files repeatedly assert
  "byte-identical run to run") **is** a determinism risk unless it follows orbital's /
  swap_meet's already-solved tick-counted-budget pattern instead of touching
  `Engine.time_scale` directly. A real kill-cam is the biggest instance of this: the
  golf game's own comments show it needed explicit "timeline-neutral" / chaos-round /
  headless-skip guards to be safe, and any port of that idea to a minigame with
  receipts needs the same guard, not a shortcut.
