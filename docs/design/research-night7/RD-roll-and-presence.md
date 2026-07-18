# R-D: The Slider Roll — Skill-Flavored Randomizer + Board-Adjacent Presence

*Night-7 research lane R-D. Read-only design lane, no code changes. Brief: the
board's movement roll is being reworked from `estate/procession/pawn_putt.gd`'s
golf-putt power meter into a Madden-kick-meter-style fast oscillating slider —
release position biases the die, center biases toward the middle, sequential
rolls with an over-shoulder camera per pawn. This doc surveys the reference
mechanics, fully specifies three candidates, stress-tests exploitability at
144Hz, and specs the determinism/bot policy and a "walkabout characters
heckle the roller" presence layer.*

---

## 0. Reading the current mechanic first (what's actually being replaced)

`estate/procession/pawn_putt.gd` today is **not** a Mario-Party dice roll — it's
Par's frozen golf-putt physics (`LINEAR_DAMP`, `MIN_SPEED`/`MAX_SPEED`)
reprojected onto the board rail. All four seats charge **simultaneously**, one
`PuttMeter` per screen corner, in the same `_physics_process` loop
(`_tick_human`/`_tick_bot`, lines 230–252). Release ratio maps through a
**deterministic, continuous** function (`speed_for_ratio` → `spaces_for_power`)
— there is no probability table anywhere in the current roll; distance is a
physics fact, not a die. The only randomness in today's roll is presentational:
**W8, night 6** (`band_order`, lines 150–163) reshuffles which face-VALUE prints
on each of the six fixed-position windows, specifically so a release-past-half
can't become memorized muscle memory ("release-past-half was always 4" — the
docstring's own words, lines 14–22). That precedent — *re-deal the numbers
every roll, never the geometry* — is the single most important piece of
in-repo prior art for this lane and gets reused directly in §2 and §3.

**One premise correction, stated up front because it changes the pacing math
in §3 and directly motivates §5:** the brief asks for *sequential* rolls with
a per-pawn over-shoulder camera. The current roll is *simultaneous* — all four
meters resolve in parallel, total roll-phase wall clock bounded by
`ROLL_TICKS` (8×60 = 480 ticks ≈ 8s worst case, usually much faster since
everyone releases early). Going sequential is a real pacing cost: four solo
performances end-to-end will typically run longer than four parallel ones,
and it converts the three non-active seats from "also charging" to "idle" for
each other's turn — precisely the idle-watcher gap doc `research-night6/
R7-spectator.md` catalogued for the reveal cascade and VENDETTA duel. **This
is not a reason to reject sequential rolling** (the over-shoulder camera ask
is clearly a deliberate spectacle trade — Mario Party's own single-die-block
turn order is sequential-with-spotlight for exactly this reason, and it's the
format that makes a per-pawn camera legible at all) — but it is the reason
§5's presence layer isn't a nice-to-have bolted onto this lane, it's the
answer to a gap this exact redesign creates. Recommend budgeting roll-phase
pacing against **~1.6–2.2s per roller** including the camera cut-in (see §3),
so four sequential rolls land at roughly 6.5–9s total — comparable to or only
modestly slower than today's worst case, provided release happens well before
the auto-release safety valve most rolls.

---

## 1. Survey — skill-flavored randomizer mechanics, and what makes each read fair

**Madden kick meter.** Two build variants exist: a single combined meter, and
a split power/accuracy "multi-meter." The mechanically interesting finding is
the **overkick penalty**: filling power to true 100% pushes the needle into a
red zone that *weakens* the kick — the reliable-best input is deliberately
short of the extreme, not at it. Recent Maddens added a **post-commit wiggle**:
once you've set power+accuracy, the arrow keeps jittering before it locks.
Community reaction is explicitly negative ("the arrow wiggles all over the
place no matter how good your placement," per Steam/Operation Sports
discussion) — **the lesson is a hard rule, not a maybe: never randomize AFTER
the player's skill input has committed.** Randomizing the target/geometry
*before* input (Madden's own overkick zone, our W8 band-reshuffle) reads as a
puzzle to solve; randomizing the *outcome* after a clean input reads as the
game cheating you, every time, no exceptions. This directly forbids one
tempting design (a hidden extra rng roll layered on top of a already-locked
release) and is cited again in §2's design constraints.
[1v1me kicking guide](https://www.1v1me.com/blog/madden-26-kicking-guide-power-accuracy),
[Steam wiggle thread](https://steamcommunity.com/app/2582560/discussions/0/6194224803806673094/),
[MaddenUniversity multi-meter](https://www.maddenuniversity.com/strategies/special-teams/kicking/two-ways-to-kick-in-madden-nfl-25-legacy-and-multi-meter-options.html)

**Mario Golf / Everybody's Golf three-click shot meter.** First press starts
the fill, second press **freely chooses power** (no timing skill involved —
power is a pure player decision about how far up the bar to let it go before
committing), third press is a **tight timing gate for accuracy/impact** —
missing it "dramatically" hooks or shortens the shot. The skill channel and
the choice channel are cleanly separated: power is *decided*, accuracy is
*executed*. The target window is always visually telegraphed on the bar
before you commit to it (never a hidden gate you find out about after
missing) — **transparency of the target, not its difficulty, is what reads as
fair.** Precision requirement is described as "a couple of frames" — tiny in
absolute terms but always visible, which is why players describe a high
skill ceiling rather than a rigged one.
[DualShockers review](https://www.dualshockers.com/everybodys-golf-hot-shots-review/),
[NookGaming review](https://www.nookgaming.com/everybodys-golf-hot-shots-review/)

**Mario Party's dice roll — the essential cautionary tale.** The spinning
face-cycle animation strongly implies timing skill. It is a lie. Testing
across the series (data-mined and reload-tested) shows that in the current
mainline entries (confirmed for *Mario Party Superstars*) **button-press
timing has zero effect on the outcome** — the value is rolled independently
of input, the animation is pure theater. This became a minor community
scandal precisely *because* players believed otherwise for years ("Looks Like
You Have No Control Over Mario Party Dice Rolls After All," Nintendo Life;
"Scandalous Dice," Jengerer). **This is the single most important negative
precedent for this lane**: our brief explicitly promises real skill influence
("releasing full-left biases toward rolling 1..."); if the shipped mapping
ever drifts to being cosmetic-only (a fixed table regardless of `p`, or a
crit window that never actually changes weights), a sufficiently curious
player *will* datamine it via `--autoplay` receipts, and the discovery reads
as betrayal, not neutrality — worse than if we'd never promised skill at all.
Every candidate in §2 is built so the weight table is a **real, checkable
function of `p`** for exactly this reason.
[Nintendo Life](https://www.nintendolife.com/news/2020/12/random_looks_like_you_have_no_control_over_mario_party_dice_rolls_after_all),
[GameFAQs Q&A](https://gamefaqs.gamespot.com/switch/323655-mario-party-superstars/answers/603658-can-you-actually-time-a-dice-roll-to-get-the-desired-number)

**Mario Party character dice blocks — real, honest weighting.** Separately
from the (fake) timing skill, the series' *character* dice ARE genuinely
non-uniform probability tables baked into the die itself: standard die totals
21 across faces 1–6; Bowser's die totals 28 and is "very volatile" (includes
high faces and coin-cost faces); Donkey Kong's and Diddy Kong's dice mix
movement with coin swings. This is a clean, low-risk precedent for **honest,
inspectable weighting that never depends on hidden timing** — worth keeping
in mind as a *fourth*, unbuilt option (a per-character or per-persona die
skin layered on top of whichever candidate ships), even though it's out of
this lane's three-candidate scope.
[gregstoll.com dice analysis](https://gregstoll.com/~gregstoll/mariopartydice/)

**WarioWare microgames.** Standard microgame length is 8 beats (~4 seconds at
default tempo); prompts are radically over-telegraphed (one verb, one
target, huge readable iconography) because the time budget is so short that
any ambiguity reads as unfair rather than hard. Relevant transfer: **brevity
budget forces single-purpose clarity** — our slider's "what should I be
watching" surface (bar position, face labels, crit tell if any) needs to be
legible inside a sub-second glance, not parsed.
[Super Mario Wiki: Microgame](https://www.mariowiki.com/Microgame)

**Crypt of the NecroDancer / rhythm-hit games generally.** Precise numeric
hit-window citations for NecroDancer specifically didn't surface in search,
but the design family's shared property is directly useful: **the beat is
always audible/visible before the hit is required** — you're never asked to
react to a surprise, only to synchronize with something you've already been
tracking for at least one full cycle. This is the same principle underlying
§3's exploitability floor: periodic, previewed motion is a *timing* task
(anticipatory), not a *reaction* task, and the two have very different human
precision limits (see §3).

**Dokapon Kingdom's spinner — the "does it even matter" case study.** In the
original *Dokapon Kingdom*, the spin-stop button press is **cosmetic** —
results are fully seeded before the spin starts, confirmed by players who
reload-tested it; stopping "early" or "late" changes nothing. Later entries
(*Dokapon Journey*) made timing genuinely load-bearing. This is the
purest-possible illustration of the Mario Party lesson from a different
franchise: **a fake-skill spinner is cheap to build and structurally safe
(zero exploit surface, zero balance risk) but is a discoverable lie**, and
the community's own words for finding this out ("pre-determined spinners,"
GameFAQs thread title) are not flattering. Filed as a rejected approach, not
a candidate.
[Dokapon spinner wiki](https://dokapon.fandom.com/wiki/Spinner),
[GameFAQs "pre determined spinners"](https://gamefaqs.gamespot.com/boards/945683-dokapon-kingdom/59201791)

**Synthesis — five transferable rules**, applied throughout §2–§3:
1. Never randomize *after* the skill input commits (Madden wiggle).
2. Telegraph the target *before* asking the player to hit it (Everybody's Golf).
3. If you promise skill influence, the weight function must be real and
   checkable — never a timing-flavored coin flip (Mario Party dice, Dokapon).
4. Keep the moment-to-moment read single-purpose and glanceable (WarioWare).
5. Randomize the geometry/target per-roll, not the physics (W8 doctrine,
   already shipped in this repo).

---

## 2. Three candidates

### 2.0 Shared plumbing

All three candidates share one weighting primitive: a **geometric-decay
kernel** centered on the continuous face position implied by release ratio
`p`. It reproduces the brief's own illustrative table almost exactly (see
Candidate A, `p=0.0`), so it's presented once and reused.

```gdscript
# Continuous "aim point" in face-space: p=0 -> face 1, p=1 -> face N.
static func aim_center(n_faces: int, p: float) -> float:
    return 1.0 + clampf(p, 0.0, 1.0) * float(n_faces - 1)

# Geometric-decay weights: face i's raw weight is k^-|i - center|, normalized.
# Larger k = sharper (more certain); k=1.0 would be a flat/uniform roll.
static func weight_kernel(n_faces: int, p: float, k: float) -> Array[float]:
    var c := aim_center(n_faces, p)
    var raw: Array[float] = []
    var total := 0.0
    for i in range(1, n_faces + 1):
        var w: float = pow(k, -absf(float(i) - c))
        raw.append(w)
        total += w
    for i in raw.size():
        raw[i] /= total
    return raw

# One rng draw, seat-order, host-only. Never resampled by mirrors.
static func sample_face(weights: Array[float], rng: RandomNumberGenerator) -> int:
    var roll := rng.randf()
    var acc := 0.0
    for i in weights.size():
        acc += weights[i]
        if roll < acc or i == weights.size() - 1:
            return i + 1
    return weights.size()
```

**Die size recommendation: ship N=6 in v1.** `SPACE_DISTANCE`, the board's
tile count, Codicil pricing, and every one of the 15 minigames' pacing
assumptions are tuned against a 1–6 move range (see `pawn_putt.gd`'s own
"FROZEN PAR PHYSICS — do not tune here" banner, lines 7–12, and
`TARGET_SPACES := 6`). Widening to 8 or 10 faces is a real board-economy
re-tune (average spaces/turn shifts, deed/grudge pacing shifts, the reveal
cascade gets longer), not a slider-only change — worth doing later as its
own lane, not smuggled into this one. Every formula below is written in terms
of `n_faces` so the escalation is a config change, not a rewrite, when that
lane happens.

### 2.1 Candidate A — PURE BIAS ("read the bar, then land it")

Release position is the *only* input to the distribution. No timing gate, no
crit. Closest in spirit to the brief's own example and the simplest to teach
in one sentence: "left leans low, right leans high, center is the safe
average."

- **Die size:** 6 faces (N=6, see above).
- **Slider period:** 700ms full sweep (0→1→0), ±60ms seeded jitter reseeded
  every roll (range 640–760ms) — see §3 for why the jitter exists.
- **Weight formula:** `weight_kernel(6, p, 1.6)` — `BIAS_DECAY := 1.6`.
- **Exact tables** (computed, not eyeballed):

| p | face 1 | face 2 | face 3 | face 4 | face 5 | face 6 | EV |
|---|---|---|---|---|---|---|---|
| 0.00 | 40% | 25% | 15% | 10% | 6% | 4% | 2.29 |
| 0.25 | 18% | 29% | 23% | 15% | 9% | 6% | 2.84 |
| 0.50 | 10% | 15% | 25% | 25% | 15% | 10% | 3.50 |
| 0.75 | 6% | 9% | 15% | 23% | 29% | 18% | 4.16 |
| 1.00 | 4% | 6% | 10% | 15% | 25% | 40% | 4.71 |

`p=0.0` lands on **[40,25,15,10,6,4]** — the exact numbers the brief used as
its own illustrative example, which is a useful sanity check that `k=1.6` is
the "obvious" decay rate for this shape, not an arbitrary pick.

- **EV curve across p** (full resolution, step 0.1): 2.286, 2.513, 2.699,
  2.971, 3.224, 3.500, 3.776, 4.029, 4.301, 4.487, 4.714 — monotonic,
  symmetric about `p=0.5`, no dead zones. Landing exactly on one of the five
  "sweet spot" ratios (`p = i/5` for `i=0..5`, i.e. 0, .2, .4, .6, .8, 1.0)
  puts the aim center exactly on an integer face and gives that face its
  single sharpest peak (e.g. `p=0.2` centers exactly on face 2); landing
  between two sweet spots (e.g. `p=0.1`, exactly between faces 1 and 2)
  **splits** the peak across two adjacent faces instead of sharpening one —
  a natural, unscripted texture, not a bug to smooth out.

- **Pseudocode:**

```gdscript
# One active roller at a time (sequential — see §4 for the queue shape).
const SWEEP_PERIOD_MS := 700.0
const SWEEP_JITTER_MS := 60.0
const BIAS_DECAY := 1.6
const N_FACES := 6

func _roll_sweep_ratio(t_ms: float, period_ms: float) -> float:
    var phase := fmod(t_ms / period_ms, 1.0) * 2.0
    return phase if phase <= 1.0 else 2.0 - phase   # triangle wave, 0..1..0

func _tick_active_roller(delta_ms: float) -> void:
    _elapsed_ms += delta_ms
    var p := _roll_sweep_ratio(_elapsed_ms, _period_this_roll_ms)
    meter.set_needle(p)
    if PlayerInput.just_pressed(_active_seat, "a"):
        _release(_active_seat, p)

func _release(seat: int, p: float) -> void:
    var weights := weight_kernel(N_FACES, p, BIAS_DECAY)
    var face := sample_face(weights, rng)   # ONE host rng draw, seat order
    _resolve(seat, face)   # -> advance queue, or auto-release safety valve
```

### 2.2 Candidate B — BIAS + TIMING CRIT ("read it, then thread it")

Same base kernel as A, plus a **hidden-until-approached, re-dealt-every-roll**
crit window that sharpens (not shifts) the distribution around wherever the
player was already aiming. This is the candidate that most literally matches
"Madden kick meter" — power/direction is the coarse skill channel (as in
Everybody's Golf's second click), the crit is the fine channel (its third
click) — while obeying rule #1 from §1 (the crit is evaluated exactly at
release, never after).

- **Die size:** 6 faces.
- **Slider period:** identical to A (700ms ± 60ms jitter).
- **Crit window:** `CRIT_HALF_WIDTH := 0.032` of the bar (≈45ms of sweep
  time at baseline period — ≈13 frames of the 144Hz frame budget, see §3),
  centered on `crit_center`, **redealt from the host rng every roll** —
  exactly the W8 doctrine (§0) applied to a new surface: the crit's *position*
  moves so a fixed pixel/frame count can never be memorized, but the crit's
  *existence and width* are constant and legible once the player learns to
  look for the tell.
- **Weight formula:** `weight_kernel(6, p, k)` where `k = 1.6` normally,
  **`k = 3.2` if `|p - crit_center| <= CRIT_HALF_WIDTH` at the moment of
  release.** The crit doesn't move your aim, it makes you *more sure of the
  aim you already had* — a release at `p=0.5` that also lands in the crit
  band gets a sharper bell around faces 3/4, not a free 6.

- **Exact tables** — normal vs. crit, same `p`:

| p | NORMAL (k=1.6) | CRIT (k=3.2) |
|---|---|---|
| 0.00 | 40/25/15/10/6/4 | **69**/21/7/2/1/0 |
| 0.50 | 10/15/25/25/15/10 | 4/11/**35/35**/11/4 |
| 1.00 | 4/6/10/15/25/40 | 0/1/2/7/21/**69** |

- **Top-face probability, normal vs. crit, across the full p range** (this is
  the number that matters for "does the crit feel worth chasing"):

| p | 0.0 | 0.1 | 0.2 | 0.3 | 0.4 | 0.5 | 0.6 | 0.7 | 0.8 | 0.9 | 1.0 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| normal top% | 39.9 | 29.3 | 32.9 | 25.7 | 30.5 | 24.8 | 30.5 | 25.7 | 32.9 | 29.3 | 39.9 |
| crit top% | 68.8 | 40.8 | 56.7 | 36.3 | 54.0 | 35.5 | 54.0 | 36.3 | 56.7 | 40.8 | 68.8 |

A crit roughly **doubles your top-face certainty** everywhere on the bar —
consistent, easy to explain in one line to a new player ("hit the flash and
you're way more likely to get exactly what you aimed at"), and never changes
*which* face you were leaning toward, so it can't be misread as the game
overriding your read of the bar.

- **Pseudocode** (delta from Candidate A only):

```gdscript
const CRIT_HALF_WIDTH := 0.032
const CRIT_DECAY := 3.2
var crit_center := 0.5   # redealt in begin_roll(), NOT at scene load

func begin_roll(rng: RandomNumberGenerator) -> void:
    crit_center = rng.randf_range(0.12, 0.88)   # never flush to either edge
    # ... existing queue/period setup ...

func _release(seat: int, p: float) -> void:
    var in_crit := absf(p - crit_center) <= CRIT_HALF_WIDTH
    var k := CRIT_DECAY if in_crit else BIAS_DECAY
    var weights := weight_kernel(N_FACES, p, k)
    var face := sample_face(weights, rng)
    if in_crit:
        Sfx.play("roll_crit", -6.0)   # the tell fires on the SAME frame as release, never after
    _resolve(seat, face)
```

### 2.3 Candidate C — TWO-STAGE ZONE CALL (wildcard: golf-club-select + overkick tax)

Distinct shape from A/B, built directly from two survey findings: Everybody's
Golf's *separate* power-then-accuracy passes (§1), and Madden's overkick
penalty for pushing all the way to the edge (§1). Two sequential sweeps per
roll instead of one: a slower **zone pick** (which third of the die you're
in), then a faster **fine pick** (which of the two faces inside that zone).
Pushing the zone pick right up to a boundary is tempting (it's adjacent to a
better zone) and carries real risk of slipping the wrong way — the "overkick"
tax, made explicit and inspectable instead of Madden's opaque red zone.

- **Die size:** 6 faces, split into three fixed zones: LOW={1,2}, MID={3,4},
  HIGH={5,6}.
- **Stage 1 (zone) period:** 900ms full sweep — slower than A/B because it's
  a coarse, low-stakes-feeling read (three thirds, not six positions).
  Boundaries at `p1 = 1/3` and `p1 = 2/3`, drawn as visible tick marks (rule
  #2 from §1 — telegraph before you ask).
- **Stage 2 (fine) period:** 380ms full sweep, starts immediately on Stage 1
  release — noticeably faster, reads as "now it gets real."
- **Bust rule (the overkick tax):** if Stage 1 releases within
  `BUST_EDGE := 0.04` of either boundary, there's an **18% chance
  (`BUST_CHANCE`)** the locked zone slips to the neighbor across that
  boundary instead of the one you were in. This is a real, disclosed cost —
  UI shows the boundary tick already slightly "hot" (a thin glow) inside that
  0.04 margin, so a bust is never a surprise rule, only a surprise *result*
  (rule #2 again).
- **Stage 2 weight formula:** `weight_kernel(2, p2, 2.0)` over the zone's two
  faces (`FINE_DECAY := 2.0`).

- **Exact tables:**

Stage-2 fine split within any zone (k=2.0, 2 faces):

| p2 | low face of zone | high face of zone |
|---|---|---|
| 0.0 | 67% | 33% |
| 0.5 | 50% | 50% |
| 1.0 | 33% | 67% |

Resulting per-zone EV range (compose zone + fine pick):

| Zone | faces | EV range (p2: 0→1) |
|---|---|---|
| LOW | 1, 2 | 1.33 → 1.67 |
| MID | 3, 4 | 3.33 → 3.67 |
| HIGH | 5, 6 | 5.33 → 5.67 |

- **EV across the controllable range:** treat Stage 1's three zones as the
  primary EV lever (≈1.5 / ≈3.5 / ≈5.5 average by zone) with Stage 2 adding
  a further ±0.17 fine adjustment inside whichever zone landed. The
  boundary-hugging tax is the one nonmonotonic wrinkle: aiming Stage 1 at
  `p1 = 0.66` (deep in MID, one step from the HIGH boundary) carries an 18%
  chance of landing in HIGH instead — a real ~2-face EV swing, exactly
  mirroring Madden's overkick finding that the theoretical-best input isn't
  the reliable-best input.

- **Pseudocode:**

```gdscript
const ZONES := [[1, 2], [3, 4], [5, 6]]
const ZONE_PERIOD_MS := 900.0
const FINE_PERIOD_MS := 380.0
const BUST_EDGE := 0.04
const BUST_CHANCE := 0.18
const FINE_DECAY := 2.0

func _release_stage1(p1: float) -> int:
    var zone_i := clampi(int(p1 * 3.0), 0, 2)
    var near_low := zone_i > 0 and (p1 - float(zone_i) / 3.0) < BUST_EDGE
    var near_high := zone_i < 2 and (float(zone_i + 1) / 3.0 - p1) < BUST_EDGE
    if (near_low or near_high) and rng.randf() < BUST_CHANCE:
        zone_i += -1 if near_low else 1   # slip across the boundary
    return zone_i

func _release_stage2(zone_i: int, p2: float) -> int:
    var faces := ZONES[zone_i]
    var weights := weight_kernel(2, p2, FINE_DECAY)
    var local := sample_face(weights, rng)   # 1 or 2
    return faces[local - 1]
```

### 2.4 Recommendation

**Candidate B** for v1. It's the closest literal match to "Madden kick meter"
in the brief, keeps a single continuous read (one bar, not two sequential
ones — faster per-roller, which matters given §0's sequential pacing cost),
and its crit doubling top-face certainty is easy to teach in one sentence
without needing a second meter's worth of screen space for an over-shoulder
shot. Candidate C is the strongest *second* pick if playtesting wants more
theater per roll (two distinct beats read well on a per-pawn camera cut) at
the cost of the slower total pacing §0 already flagged as a risk.

---

## 3. Exploitability analysis — 144Hz, human timing limits, recommended speed

**The task is anticipatory timing, not reaction timing — the two have very
different precision floors, and conflating them is the most common mistake
in meter design.** Simple visual reaction time (react to a stimulus you did
not expect) averages **250–300ms** in the literature, with elite/trained
performance around 150–200ms and the fastest lab-recorded humans near
100–120ms. That number is *irrelevant* to a continuously-visible, periodic
slider: the player isn't reacting to a surprise, they're tracking motion
they've already seen at least one full cycle of and choosing a release point
— the correct comparison is **sensorimotor synchronization** research
(tapping to a visible/audible periodic beat), where the standard deviation
of timing error is consistently reported as **"a few tens of milliseconds"**
— tighter than simple reaction time by roughly an order of magnitude, because
prediction replaces reaction.
[ReflexForge reaction time data](https://reflexforge.com/blog/human-reaction-time/),
[PMC: sensorimotor synchronization across modalities](https://pmc.ncbi.nlm.nih.gov/articles/PMC10567517/),
[ScienceDirect: mean/SD of asynchrony](https://www.sciencedirect.com/science/article/abs/pii/S0167945718307978)

**What this means for our numbers.** At 144Hz, one frame is 6.94ms. Our
recommended 700ms full-cycle sweep (350ms one-way) divides the 6-face bar
into roughly 58ms of sweep-time per face-width at the fastest point of
travel — comfortably inside the "a few tens of ms" synchronization-error
band, meaning **landing a specific face on demand sits right at or just
below the human motor-precision floor**, which is exactly the brief's ask
("learnable, not solvable"). Reliable gross aim (lean left vs. lean right)
is a much coarser task — splitting the bar into thirds gives ~117ms-wide
zones, well above the error floor, so "aim for the top half" is a skill a
casual player converges on within a few rolls.

**Where it breaks — the reactive-correction floor.** A player's ability to
*adjust mid-sweep* (see the needle, notice they're early/late, nudge the
release) is bounded by a full see→react→correct loop, which needs at least
one simple-reaction-time's worth of headroom (~200–250ms) to complete even
once. Our one-way sweep (350ms baseline) has just enough margin for a single
correction pass (250ms used, ~100ms of buffer) — this is deliberate, not
generous. **Below roughly a 300–400ms full-cycle** (150–200ms one-way), that
correction loop can no longer complete even once inside a single pass: the
player is forced into pure open-loop/ballistic release (pre-planned by count
or feel, zero mid-sweep adjustment), and at that point *even gross left/
center/right aim starts degrading toward chance* — which fails the "must
feel learnable" requirement, not just the "must not be solvable" one. **Do
not tune the period below ~500ms full cycle** for this reason; 700ms sits
with real margin above that floor while still reading as dramatically faster
than today's 3.2s meter (see §0).

**The muscle-memory exploit is period-*counting*, not frame-perfect input,
and the fix is the same W8 doctrine already shipped in this repo.** A fixed,
never-varying period is beatable without watching the bar at all — a player
who learns "press A exactly 583ms after the tone" doesn't need the visual
once they've internalized the rhythm, at which point it stops being a
skill-flavored *slider* and becomes a memorized *metronome tap*, which is a
worse and more brittle game (breaks the instant frame pacing hitches, favors
whoever practiced blind timing over whoever reads the bar well). The
synchronization-error literature above gives the fix a concrete number:
**seed a period jitter of ±60ms, re-rolled every single roll from the host
rng** (already in the pseudocode above). Sixty milliseconds is comfortably
larger than the ~20–40ms synchronization-error floor a trained player could
otherwise exploit by counting, which forces genuine visual tracking back into
the loop without punishing the player who *is* watching (the jitter changes
the period, never the shape of the sweep or the meaning of `p`). This is the
same move as W8's band-reshuffle: **randomize the geometry per-roll, never
the physics or the post-release outcome** (§1 rule #1 and #5).

**Recommendation:** 700ms full cycle (350ms one-way), ±60ms seeded jitter
per roll, crit window (Candidate B) at 45ms half-width — inside the
synchronization-error band (hard to guarantee, easy to bias toward with
practice), never below the 300–400ms hard floor for the sweep itself.

---

## 4. Determinism / bot policy

Mirrors `pawn_putt.gd`'s existing contract exactly: **the host owns every
release and every rng draw; mirrors only render `_net_state()`.** The
structural change from today is that the roll becomes a **queue of one active
seat at a time** rather than four parallel state machines — everything else
(seeded rng, `_fast` bypass, bot targets sourced from board strategy) carries
over unchanged.

```gdscript
var roll_queue: Array[int] = []      # seat indices, turn order
var active_seat := -1
var active_period_ms := 700.0        # this roll's jittered period
var elapsed_ms := 0.0

func begin_roll(targets: Array[int], rng: RandomNumberGenerator) -> void:
    roll_queue = range(roster.size())
    crit_center = rng.randf_range(0.12, 0.88)     # W8-style: geometry redealt, not physics
    _advance_queue(targets, rng)

func _advance_queue(targets: Array[int], rng: RandomNumberGenerator) -> void:
    if roll_queue.is_empty():
        all_released.emit(_results)
        return
    active_seat = roll_queue.pop_front()
    elapsed_ms = 0.0
    active_period_ms = SWEEP_PERIOD_MS + rng.randf_range(-SWEEP_JITTER_MS, SWEEP_JITTER_MS)
    board_camera.over_shoulder(walker_pos(active_seat), walker_forward(active_seat))
    if bot_enabled[active_seat]:
        _bot_target_p = _p_for_target_face(int(targets[active_seat]), N_FACES)
        _bot_wants_crit = rng.randf() < bot_crit_appetite[active_seat]   # persona-driven
```

- **Bot target selection** reuses `procession.gd::_bot_targets()` unchanged
  (highest reachable/affordable value, Codicil-aware, seeded jitter) — the
  bot decides *which face it wants* exactly as it does today; only the
  translation from "wanted face" to "slider input" is new:
  `p_target = (target_face - 1) / (n_faces - 1)`, i.e. the exact inverse of
  `aim_center()`.
- **Bot release timing:** a bot watches the same triangle-wave sweep and
  releases on the first crossing of `p_target` (mirroring today's
  `ratio >= bot_target_ratios[i]` check), plus a small seeded jitter
  (`rng.randf_range(-0.03, 0.03)`) so four bots never look robotically
  identical — same texture as today's `bot_start_ticks`/jitter pair.
- **Crit appetite is a persona knob, not a universal constant.** An
  "aggressive" bot persona is more willing to hold out for a release inside
  `crit_center`'s band even when that costs a slightly worse `p_target`
  read; a "cautious" persona always takes the safe crossing. This is new
  surface, not present in `pawn_putt.gd` today, but costs one seeded `bool`
  per bot per roll — cheap, and it's the kind of texture that makes bots
  feel like distinct opponents rather than one script wearing four faces.
- **The face is always sampled by exactly one `rng.randf()` draw at the
  moment of release**, in seat order (queue order = seat order = receipt
  order), whether the releaser is human or bot — this is what keeps
  `--seed=` receipts byte-identical: replaying recorded human release ticks
  against the same seed reproduces the same `p`, the same crit check, and
  the same `sample_face()` draw, deterministically.
- **`_fast`/soak bypass**, matching `procession.gd`'s existing `if not
  _fast: ... else: ...` pattern (e.g. line 936): under `--autoplay=bots` the
  animation never renders; the queue resolves every seat's `p_target` (plus
  jitter, plus crit-appetite roll) and calls `_release()` directly in the
  same single frame, so a full night's worth of sequential rolls costs the
  soak nothing extra despite the format no longer being parallel.
- **Net sync:** `_net_state()` gains `queue`, `active_seat`,
  `active_period_ms`, `crit_center` alongside the existing `ratios`/
  `released`/`spaces` fields; mirrors render the active seat's live needle
  purely from the host's broadcast `p` samples (same 30Hz cadence as
  `PlayerInput`'s existing remote-state stream) and never call
  `sample_face()` themselves — identical trust boundary to today's
  `band_order` sync (mirrors "wear the host's green verbatim," line 346).

---

## 5. Presence interactions — walkabout characters at the board, ranked

The brief's premise (rigged walkabout characters can run alongside the board
without touching the sim) is architecturally the same contract
`core/ambient_life.gd` already ships under: **PRESENTATION ONLY, own
`RandomNumberGenerator` (never the sim's `rng`), near-zero cost, never writes
`EstateState`.** §0 already established that sequential rolling creates a
real idle gap for the three non-active seats — this section is the answer to
that gap, using the free-roam walkabout avatars (not the board pawns) as the
idle players' hands. Any interaction whose *state* needs to be visible to
other players (a bet lock, an emote) needs its own lightweight net-sync
channel separate from `_net_state()`, exactly so a dropped/late presence
packet can never stall or desync the roll itself — same host-owns-sim /
mirror-renders-only split as everywhere else in this file.

Ranked by fun-per-abuse-risk (best first). **Feature or Foul** flags whether
an interaction that *could* distract the active roller is an intended
heckling mechanic (with guardrails) or something that must be prevented
outright.

| # | Interaction | Risk | Feature or Foul |
|---|---|---|---|
| 1 | **Cosmetic stake on the live meter** — since this is shared-screen local co-op, bystanders see the exact same needle the roller does; lock a silent guess (face or high/low half) any time before release, payout is flavor-only (a boast line, no economy touch). Zero sim reads beyond the same `p` already broadcast for rendering. | None | — |
| 2 | **REACT glyph over the roller mid-slider** — reuse the shipped F24 `_poll_reactions`/`_spawn_reaction` idiom (`procession.gd` reveal cascade) on the *active roll* instead of only the reveal beat. | None | — |
| 3 | **Pick up a scenery scrap** — a leaf from Old Rake's pile, a dropped pebble; pure `AmbientLife`-style prop tween, could even feed the groundskeeper's existing scatter/reset choreography (`ambient_life.gd` `Groundskeeper.scatter_leaves()`). | None | — |
| 4 | **Emote gesture wheel** — thumbs up/down, bow, facepalm; a button on the idle walkabout avatar, pure animation. | None | — |
| 5 | **Chronicle gossip bubble crossover** — idle walkabout characters near the graveyard keep gossiping via the already-automatic `CrowGallery`; no new code, just don't let it read as commentary *on this specific roll* (keep the line pool generic chronicle facts, not roll-reactive). | Low (misread as hidden info if lines start referencing the live roll) | — |
| 6 | **Ring the chapel/mausoleum bell** — one-shot ambient SFX+VFX ("the estate has an opinion"). Foul only if it masks Candidate B's crit-window audio tell; mitigate with a cooldown long enough it can't be spammed every roll, or duck it under the active roll's SFX bus. | Low–medium (audio masking) | Feature, with cooldown/ducking |
| 7 | **Taunt aura pose** — a walkabout character strikes a telegraphed, wind-up pose with a short particle flourish near the roller. Must render world-space only, never inside the meter's screen-space HUD rect. | Medium (placement) | Feature, world-space only |
| 8 | **Cosmetic shove/bump between idle avatars** — ragdoll wobble, no gameplay effect on either avatar. Needs a soft camera-space keep-out radius around the active roller so a shove can't walk a body into the over-shoulder framing. | Medium (camera occlusion) | Feature, with keep-out radius |
| 9 | **Confetti / soft-prop toss at the roller** — cosmetic particle only, never triggers screen-shake. Must use a VFX palette visually distinct from the crit tell (Candidate B) so the two are never confusable in a fast glance. | Medium (tell confusion) | Feature, distinct palette required |
| 10 | **Deliberate peripheral-vision distraction** (waving arms, flashing colors, standing in the camera's background) — direct sabotage potential against fine-timing input; the explicit feature-vs-foul boundary case. | High | **Foul unless all three hold:** (a) hard per-night use cap + cooldown, (b) loud, unambiguous tell before it fires (never an ambush), (c) the meter widget itself is always composited on top and cannot be occluded — background occlusion is fair heckling, HUD occlusion is never allowed. |

**The one line that should never move regardless of which of #6–#10 ship:**
occlusion of the meter widget itself is always a foul, full stop — every
mitigation above is written to keep the *background* contestable while the
*instrument* stays unoccludable, the same way a rhythm game can put visual
noise anywhere except on top of the note highway.

---

*Sources: Madden kicking
([1v1me](https://www.1v1me.com/blog/madden-26-kicking-guide-power-accuracy),
[Steam wiggle thread](https://steamcommunity.com/app/2582560/discussions/0/6194224803806673094/),
[MaddenUniversity](https://www.maddenuniversity.com/strategies/special-teams/kicking/two-ways-to-kick-in-madden-nfl-25-legacy-and-multi-meter-options.html));
Everybody's Golf shot meter
([DualShockers](https://www.dualshockers.com/everybodys-golf-hot-shots-review/),
[NookGaming](https://www.nookgaming.com/everybodys-golf-hot-shots-review/));
Mario Party dice timing
([Nintendo Life](https://www.nintendolife.com/news/2020/12/random_looks_like_you_have_no_control_over_mario_party_dice_rolls_after_all),
[GameFAQs](https://gamefaqs.gamespot.com/switch/323655-mario-party-superstars/answers/603658-can-you-actually-time-a-dice-roll-to-get-the-desired-number));
Mario Party character dice weighting
([gregstoll.com](https://gregstoll.com/~gregstoll/mariopartydice/));
WarioWare microgame length
([Super Mario Wiki](https://www.mariowiki.com/Microgame));
Dokapon spinner
([Dokapon Wiki](https://dokapon.fandom.com/wiki/Spinner),
[GameFAQs](https://gamefaqs.gamespot.com/boards/945683-dokapon-kingdom/59201791));
human reaction time
([ReflexForge](https://reflexforge.com/blog/human-reaction-time/));
sensorimotor synchronization precision
([PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC10567517/),
[ScienceDirect](https://www.sciencedirect.com/science/article/abs/pii/S0167945718307978)).
In-repo: `estate/procession/pawn_putt.gd`, `estate/procession/procession.gd`,
`estate/procession/board_camera.gd`, `core/ambient_life.gd`,
`docs/design/24-board-broadcast-standard.md`,
`docs/design/research-night6/R7-spectator.md`.*
