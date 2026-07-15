# 16 — Two Game-Feel Problems: The Universal Jump & Occluded-Player Visibility

Date: 2026-07-15. Engine: Godot 4.6.2. Author: research agent.
Trigger: (1) playtesters keep reaching for a jump button in modes that don't
have one ("people expect that"); (2) in ORBITAL DODGEBALL, humans lose track
of players on the far side of a planet while bots aim at them unaffected.

Both problems are answered from **what this repo already does**, not from
genre platitudes. The anthology already has four shipped jump/hop
implementations and one shipped x-ray-style always-visible marker — this doc
audits them, brings outside research to bear on the gaps, and gives per-game
and per-solution recommendations concrete enough to build from.

---

# PROBLEM 1 — THE UNIVERSAL JUMP

## 0. The constraint that decides this before any research does

`docs/specs/anthology-module-contract.md:49-51`:

> Design for 2–4 players. Input policy (2026-07-04): ... **Verb budget per
> player stays move + A + B** (tap/hold variants welcome). Design within it.

Every one of the 12 shipped minigames obeys this. There is no third button —
gamepad `A`/`B`, keyboard-half `Space`/`E` or `Enter`/`Shift`, KBM
click/right-click (`core/player_input.gd:24-25`, `is_down()`). So "add a
universal jump" cannot mean "add a jump button" — the button doesn't exist,
and adding one would break the one architectural rule every module was built
against. **The real question is: where does the existing A/B budget already
deliver what playtesters are calling "jump," and where should the answer be
juice, not a verb.**

### Current A/B allocation, audited game by game

| Game | A | B | Jump/hop today? |
|---|---|---|---|
| PAR FOR THE CURSE — putting | aim/putt | — | none (putting has no locomotion) |
| PAR FOR THE CURSE — grief-brawl (chaos) | shove | **hop** (`HOP_VY`) | **yes — expressive/traversal** |
| ECHO CHAMBER (arena brawl, ring-out) | swing/heavy | dash (tap) / parry (hold) | none — dash substitutes |
| TILT (tilting platter) | shove | brace | none |
| ORBITAL DODGEBALL (planet dodgeball) | throw/catch | **jump** (planet-hop) | **yes — full, functional** |
| MOWER MAYHEM (top-down mower race) | ram | boost | none |
| GREED INC. (carrier keep-away) | tackle | dash | none |
| SWAP MEET (kart race) | throw swap orb | drift-boost | none |
| DEAD WEIGHT (sumo push arena) | shove | **hop** (over low props) | **yes — traversal only, see §B** |
| THE THRONE (king of the hill) | shove | dash | none |
| LAST WILL (survival gauntlet) | shove | **hop** (over boulder) | **yes — traversal only** |
| THE SÉANCE (seated theater) | chant | anonymous surge | none — no embodied movement at all |
| THE UNDERSTUDY (seated theater) | — | — | none — no embodied movement at all |
| MASKED BALL (hide-among-NPCs ballroom) | curtsy | unmask | none — see §D |

**4 of 12 already have a hop.** In every one of those four, B was free (or
B's job was already "go airborne"). In every game where B is doing something
incompatible (brace, dash, boost, ram, drift, chant/surge, curtsy/unmask),
there is no room, and the fix is not to steal the verb.

## A. Why "useless" jumps matter anyway (Mario Party evidence)

Mario Party's board/overworld gives every character a jump the board itself
almost never asks for — most of the 300+ minigames across the series don't
use it. It survives because a controller input that never gets a response is
"a button press that goes nowhere," and game feel research treats every
input as **a conversation between player and system** — an unanswered
conversational turn reads as broken, not neutral (see "Game Feel: A
Beginner's Guide," gamedesignskills.com; "Designing Game Feel," Pichlmair &
Johansen, arxiv.org/pdf/2011.09201). The jump costs nothing (no other
verb competes for the input on the overworld), and it buys agency: the player
can express *something* — impatience, personality, a victory hop — the moment
they're not sure what else to do with their hands. That is exactly the
"people expect that" feedback: players default to jump as **idle-fidget
input**, not because they need vertical traversal.

The corollary for us: the fix that satisfies this expectation does **not**
need to be a functional jump. It needs to be *some* button that answers back
when pressed with nothing else going on. Our estate's pre-round GET READY
card, ready-room, and post-round podium beats are the actual overworld-analog
moments — see §E.

## B. Jump as evasion in shove-based brawlers — does it break the game?

**Party Animals** (jump, kick, headbutt, punch, grab, dodge-roll, sprint
haymaker — a full moveset) keeps grounded combat primary because none of
those verbs, including jump, grant true evasion: it's a ragdoll-physics game,
so an airborne character can still be grabbed, thrown, or clipped by another
attack; jump is one tool in a large kit, not an escape hatch. **Gang Beasts**
is even flatter — "spamming the grab button until you knock someone out" is
close to the whole combat verb, and its floppy ragdoll movement makes
jump-as-dodge unreliable by physics alone, not by design fiat. **Boomerang
Fu** treats jump and dash as *interchangeable* evasion options in its options
menu ("dashing is stupid, so you may replace it with jump... this lets you
evade incoming boomerangs, flames, people, and water") — confirming that in
a top-down party arena, a hop and a horizontal dash are read by players as
the same kind of "get out of the way" input.

**The mechanical danger for us specifically:** our shove/hit checks run on
kinematic/rigid bodies, not ragdolls, and several of them are literally
"distance + facing-cone at ground height." If a hop's hit-check DIDN'T
flatten Y, a player at the apex of even a small hop could sidestep an
incoming shove for free — turning every shove-based game into "mash B on
cooldown, ignore positioning." **This is already solved in the codebase, and
it's worth stating as an explicit house rule:** shove/hit resolution
consistently zeroes the vertical component before measuring range and arc —
`minigames/dead_weight/fighter.gd:267-269` (`to.y = 0.0` before the
`SHOVE_RANGE`/`SHOVE_ARC` check), the same pattern in
`echo_chamber/fighter.gd:683,733,751`, `echo_chamber.gd:1066`, and
`masked_ball.gd:758,872,880,902`. Because of this, Dead Weight's hop
(`_do_hop`, `fighter.gd:289-298`) is *provably* not an evasion tool — you can
be shoved mid-air exactly as if grounded — it exists purely to clear low
props per the spec. **Rule to preserve for any future shove/hit-check
minigame: always flatten Y before the range/arc test. That single line is
what lets hop and shove coexist without one invalidating the other.**

This also explains why THE THRONE and TILT — the two purest shove-and-space
games — deliberately gave B to dash and brace instead of hop: a dash still
respects the flattened-Y hit-check (it's a horizontal move, easy to reason
about as "still shovable"), but a design that gave them a *jump* would invite
players to ask "why doesn't jumping dodge the decree blast / the platter
shove" — a fair question a flattened-Y hop answers by staying grounded (or,
if airborne, still hittable) but a design that *looked* like flight would
fight the player's own intuition. Keeping B off "jump" here isn't a
limitation, it's avoiding a promise the physics can't honor without more
plumbing.

## C. Concrete tuning — adapted for 3D party chaos, benchmarked against our own numbers

Canonical platformer forgiveness windows (Kyle Pittman, "Math for Game
Programmers: Building a Better Jump," GDC 2016,
mathforgameprogrammers.com/gdc2016; Celeste's shipped values as widely
documented from its source, e.g. thealmightyguru.com/Wiki, gamerant.com):

- **Coyote time** ≈ 5 frames at 60fps ≈ **~0.08–0.1s** (Celeste's number).
- **Input buffer** ≈ **100–150ms** (~6–9 frames @ 60fps) between seeing a
  landing and pressing the button.
- **Jump-cut / variable height**: release early → gravity (or vertical
  velocity) is cut hard so short taps give short hops, holds give full
  height. Requires **asymmetric gravity** (lower while rising + holding,
  higher while falling) — the classic Mario-style shape (see the Godot
  Mentor "Celeste-Like Platformer" writeup and the "Slowfall Gravity
  Multiplier" pattern common to Celeste-derived controllers).

**None of our four shipped hops implement jump-cut, and that's correct, not
an omission.** These are party hops (clear a prop, hop a gap, plant an
expressive beat), not precision platforming — variable height adds input
complexity (hold-duration reads) for a payoff (finer vertical control) none
of these games need. Keep hops **fixed-impulse, fixed-arc**. What *is* worth
adopting anthology-wide: coyote time and a short input buffer, because they
cost nothing mechanically and remove "I pressed B and nothing happened"
frustration, which is exactly the complaint behind "people expect a jump
button."

Our existing numbers, for calibration (all constants, all Godot 3D, all
already shipping):

| Impl | Gravity | Launch speed | Apex height | Hang time | Notes |
|---|---|---|---|---|---|
| Par grief-brawl `HOP` (`scripts/player_avatar.gd:16,25`) | 24.0 m/s² | `HOP_VY` = 7.0 m/s | v²/2g ≈ **1.02m** | 2v/g ≈ **0.58s** | clears the 0.51m course wall by design comment |
| Orbital planet-hop (`orb_pawn.gd:19`) | n-body, variable | `JUMP_SPEED` = 7.6 m/s | planet-dependent | ~0.5–1s typical | ballistic through blended gravity, not a constant arc |
| Dead Weight hop (`fighter.gd:289-298`) | RigidBody impulse | tuned to clear low props | small | short, 1.5s cd | Y-flattened hit-check — never grants evasion (§B) |
| Last Will hop (`lw_pawn.gd`) | similar family | gap-hop over rolling boulard | small | short | traversal only, not evasion |

**If/when a true free-traversal jump is added anywhere (see §E, the estate
hub), match the house feel:** ~1.0m apex, ~0.5–0.6s hang, `GRAVITY` in the
20–26 m/s² band (matches `player_avatar.gd` and `echo_chamber.gd`'s existing
24.0 constant — reuse it, don't invent a second gravity constant), plus
**coyote ≈ 0.1s** and **buffer ≈ 0.12–0.15s** on the input read (both trivial
timers next to a `just_pressed` check — no jump-cut needed given the fixed
hop precedent above).

## D. Which archetypes should NOT get jump — and why the ones in this repo already got it right

| Archetype (repo game) | Jump: full / hop-expressive / none | Rationale |
|---|---|---|
| Golf putting (PAR — putting phase) | **none** | No locomotion loop to interrupt; the caddy walk-to-ball is automated. Jump has nothing to answer. |
| Golf grief-brawl (PAR — chaos mode) | **hop-expressive** *(shipped)* | Chaos-only side mode with no scoring stakes — pure traversal/flourish, matches the Mario Party "board jump" logic in §A exactly. |
| Tilting platter balance game (TILT) | **none** | The entire mechanic is weight-on-a-surface; a hop changes your effective mass distribution mid-air in a way the torque model doesn't account for, and it would let players briefly escape the "your weight is everyone's problem" premise the game is built on. Brace (commit, can't move) is the correct opposite-pole verb. |
| Planet-surface dodgeball, curved gravity (ORBITAL) | **full** *(shipped)* | Jump IS the traversal verb between planets ("planet-hop jumps" is an explicit SHOULD in the spec) — without it the three-planet layout is unreachable on foot. |
| Top-down mower race (MOWER) | **none** | Vehicles, not characters — "jump" has no vehicle analogue here (boost already fills the risk/reward B slot) and airborne mowers can't mow, breaking the core coverage loop. |
| Sumo push arena (DEAD WEIGHT) | **hop-expressive (traversal-only)** *(shipped)* | Confirmed safe by the Y-flattened hit-check (§B) — hop clears low props without dodging shoves. This is the textbook "how do Gang Beasts / Party Animals keep grounded combat primary" answer, achieved by a one-line hit-check convention rather than by omitting jump. |
| King-of-the-hill (THE THRONE) | **none** | Dash is correct here specifically because the core tension is grip/dethroning via *shove contact* — see §B for why jump would read as promising evasion the physics doesn't grant. |
| Race gauntlet / survival gauntlet (LAST WILL) | **hop-expressive (traversal-only)** *(shipped)* | Gap-hop over a telegraphed hazard is a legible read-and-react beat; full jump/flight would trivialize the hazard-wave tension that the whole round is built around. |
| Hide-among-NPCs ballroom (MASKED BALL) | **none** | The entire disguise mechanic is "you move at exactly crowd speed, and pace can't be the tell — intention is" (the module's own header comment). A jump is an instant tell — no NPC ever leaves the ground, so any hop de-anonymizes the jumper on sight. This is the one archetype where jump would actively break the core premise, not just be irrelevant. |
| Seated séance / theater games (THE SÉANCE, THE UNDERSTUDY) | **none** | No embodied avatar exists in these modules at all — input is a shared planchette pull, a vote-chip swing, a chant tap. There is no body to jump. |

## E. The actual fix for "people expect a jump button"

Given the hard `move + A + B` ceiling, three tiers, not one blanket answer:

1. **Where B already has any airborne flavor (Orbital, Dead Weight, Last
   Will, Par-chaos): ship as-is, sell it harder.** These already answer the
   expectation. Cheap wins: KayKit's rig already ships `Jump_Start` /
   `Jump_Idle` / `Jump_Land` clips (confirmed in use —
   `orb_pawn.gd:64,319`, referenced generally in
   `docs/design/08-gamefeel-research.md:38`) — make sure every hop plays
   the full Start→Idle→Land triptych instead of snapping straight to
   Idle, and add a small landing squash (the codebase's own `flash_pop()`
   pattern, `player_avatar.gd:175-180`) on touchdown. That's the "juice"
   half of Pittman's talk — it reads as a *real* jump even though the
   underlying arc is a fixed, uncomplicated impulse.

2. **Where B is claimed by an incompatible grounded verb (Tilt, Throne,
   Mower, Greed, Swap Meet, Echo Chamber, Masked Ball, Séance,
   Understudy): do not spend the verb budget.** Instead, close the
   expectation gap the way Mario Party's board does — with a **free,
   stakes-free hop that costs nothing because no input triggers it**:
   play a hop/cheer beat automatically during pre-round countdowns,
   READY-room idle loops, and victory podiums (the estate shell already
   has these — `estate.gd`'s `_ready_gate_*` pre-game card and
   `RECKONING`/podium phases). Players see their character *can* hop
   without a control ever needing to grant it mid-round, so it never
   competes with A/B.

3. **The estate GROUNDS hub is the one place in the whole anthology with
   no competing verb and no scoring stakes — this is where a real,
   free-traversal jump belongs, if/when walkable grounds ships.**
   `estate.gd:5` already earmarks `GROUNDS` as "v1 'clipboard' grounds
   (panel UI); walkable grounds is phase E2" — i.e. it doesn't exist yet
   as a 3D space. When it does, it is the direct structural analogue of
   Mario Party's board: players walking between auction/game beats with
   nothing else to do with their hands. Because the anthology's
   `move + A + B` contract is scoped to **minigame modules**
   (`anthology-module-contract.md`), the hub is not bound by it — it can
   safely add a 4th input (gamepad `X`/`Y`, an unused keyboard key) read
   by a *new*, hub-only `PlayerInput` query (e.g. `is_down(p, "jump")`)
   that no minigame ever calls, so the module contract stays intact.
   Tune it to the house numbers in §C (~1.0m apex, ~0.55s hang,
   `GRAVITY = 24.0`, coyote ~0.1s, buffer ~0.12–0.15s, fixed height, no
   jump-cut) so it feels like the *same character* players just played
   Par's grief-brawl hop with.

**Bottom line: don't add a jump button. Confirm the four hops that already
exist are dressed well, let stakes-free moments carry the "my character can
jump" feeling for the other eight games, and reserve an actual new input for
the one context — the walkable hub — that has room for it.**

---

# PROBLEM 2 — OCCLUDED-PLAYER VISIBILITY (Orbital Dodgeball)

## 0. What we're actually working with

- **Camera is fixed, not orbiting**, on purpose: `orbital.gd:60-61` —
  `CAM_POS := Vector3(-0.2, 0.2, 17.6)`, `CAM_FOV := 46.0`, set once in
  `_ready` and never re-aimed (only `fov`/`h_offset`/`v_offset` shake on
  impact, `orbital.gd:940-956`). The spec is explicit about *why*: "Planet
  walking must never disorient: camera stays fixed... controls are
  screen-relative" (`docs/specs/minigame-orbital-dodgeball.md:53-55`), and
  `orb_pawn.gd`'s whole parallel-transported control frame (`frame_r`,
  `_update_frame`) is built assuming a **stable** `world.cam_right()` /
  `cam_axis()` to relax toward. Any camera-motion-based fix (auto-orbit,
  per-player PiP with its own camera) directly fights this control scheme —
  rule it out as primary before comparing costs.
- **The solution seed already exists in-tree.** Every `OrbPawn` already
  carries an always-visible identity marker: `orb_pawn.gd:91-104` — a small
  sphere, `SHADING_MODE_UNSHADED`, `transparency = ALPHA`,
  **`mmat.no_depth_test = true`**, `render_priority = 10`, tinted to the
  player's color, floating above the head. The comment on it says exactly
  what we need: *"always-visible marker orb (no depth test — readable
  behind planets)."* This is the x-ray technique, already shipped, already
  proven at this camera distance — it just isn't on the *body*, only a
  small dot above it.
- **Scale of the occlusion problem is small and bounded**: 3 planets,
  radius 1.8–3m, ~7m apart (`minigame-orbital-dodgeball.md:15`) — at most
  one sphere occludes a given player from the fixed camera at a time. This
  is a cheap case, not a general large-world occlusion problem.

## A. Solution comparison

**(a) Through-wall silhouette rendering (x-ray).** Godot 4 has three ways in:
1. `BaseMaterial3D.no_depth_test = true` set from script (zero shader code)
   — exactly what the existing `_marker` already does. Simplest possible
   extension: give the *body*, not just the dot above it, the same
   treatment.
2. A custom `ShaderMaterial`, `shader_type spatial; render_mode
   depth_test_disabled, unshaded;` — needed once you want fresnel edge-glow,
   scanlines, or a checker "ghost" pattern rather than a flat tint
   (see godotshaders.com "X-Ray Vision Effect," and Tim Klein's
   character-depth-shader writeup, which samples `DEPTH_TEXTURE` /
   `FRAGCOORD.z` to draw *only* where actually occluded, checker-patterned).
3. AAA reference: Overwatch's ally-through-walls treatment (Mercy et al.)
   is a genuine two-pass front/back-face translucent x-ray that only draws
   over already-drawn opaque geometry, using the stencil buffer so it never
   double-tints an already-visible ally. That's the gold-standard version;
   it's more machinery than our low-poly diorama style needs or than 4
   simultaneous characters + up to 8 balls can afford to add per-frame.
   **Recommendation below uses the `no_depth_test` route (1), which is
   cheap, already-proven in this codebase, and visually correct for our
   "chunky diorama" house style** (per `docs/design/07-visual-polish-audit.md`
   — flat, readable, unshaded silhouettes are on-brand, not a compromise).

   Known trap to avoid: a Godot 4.2.x bug (godotengine/godot#95419) makes
   `next_pass`-chained materials fail depth testing unpredictably at some
   camera angles when the *second* pass tries to do its own depth
   comparison. Sidestep it entirely by **not** using `next_pass` — add the
   x-ray silhouette as a **separate sibling `MeshInstance3D`**, the same
   pattern `_marker` already uses (`orb_pawn.gd:92-105` adds `_marker` as a
   plain child of `_visual`, not as anyone's `next_pass`). Same visual
   result, no exposure to the bug, and it's already the house convention.

**(b) Edge-of-planet peek indicators.** The classic "off-screen indicator
arrow" pattern (screen-edge-hugging arrows toward an out-of-viewport target,
per code.tutsplus.com's algebra writeup) doesn't map cleanly here: the
target isn't off-screen, it's *behind an on-screen sphere*. A faithful
adaptation would hug the **planet's own silhouette rim** nearest the hidden
player (a clock-position indicator on the sphere's edge, not the viewport's
edge) — that's a bespoke build (project the hidden player onto the planet's
screen-space limb circle), not a drop-in pattern. Gives *directional* info
("they're on the far side, toward 4 o'clock") that a flat silhouette alone
doesn't.

**(c) Planet transparency / fresnel ghosting.** Make the planet itself go
translucent near the occluded region when a player is behind it. Two risks
specific to this game: (1) the planets are the **spatial reference frame**
for aiming, gravity, and the "walk all the way around, Mario-Galaxy-lite"
mental model — see the spec's readability requirement for the *platter* in
TILT (concentric rings + compass colors) which doesn't literally apply to
Orbital, but the underlying principle does: players orient off the planet's
solid silhouette, and thinning it out at exactly the moments it matters most
(mid-fight) undermines that. (2) fresnel-style transparency is
view-angle-dependent, so its "window" shifts every frame the ball/player
moves relative to camera — less stable than a fixed-alpha silhouette.

**(d) Satellite minimap / second orthographic view.** Cheap to build (small
`SubViewport` + top-down `Camera3D` in a corner). Gives *global* awareness
(all planets, all players, all balls) at a glance — the MOBA precedent (LoL's
fog-of-war "silhouette of a unit observed behind terrain," a legible position
tell without full visibility). But `docs/design/08-gamefeel-research.md`
already flags this anthology's binding constraint as **"a 4× clutter
budget: whatever we add fires up to four times at once"** — a minimap with 4
dots plus up to 8 concurrent orbiting balls (spec: "up to 8 balls in flight
late game") reads as noise at couch distance, and it forces a genuine
attention split (glance away from the 46°-FOV main view) in a game whose
catch window is **0.2s** (`orb_pawn.gd:28`, `CATCH_WINDOW`). Too slow a
sensor for a fast-twitch dodge/catch loop.

**(e) Camera solutions.** Auto-orbit breaks the screen-relative control
frame (§0) — ruled out. Per-player picture-in-picture (à la Renegade Ops'
dynamic split-screen, ph3at.github.io) is designed for lower player-density
games with room to give each viewport real estate; four simultaneous PiP
windows plus HUD plus orbit trails plus throw previews is well past this
anthology's clutter ceiling, and it still doesn't solve the "which bot
reads the far side and I don't" fairness gap for the *primary* shared view
everyone is actually watching (couch multiplayer's main screen).

## B. Comparison table

| Solution | Couch readability | Godot 4.6 impl cost | Visual noise (4p + balls) | Precedent |
|---|---|---|---|---|
| (a) Silhouette / x-ray (sibling mesh, `no_depth_test`) | High — flat colored blob, same read distance as the existing marker orb | Low — extends shipped `_marker` pattern, no shader R&D needed | Low — 4 blobs max, independent of ball count | Overwatch ally x-ray; already shipped in this file as `_marker` |
| (b) Edge-of-planet peek arrows | Medium — adds direction but needs a second glance to parse | Medium-high — bespoke limb-circle projection math, no drop-in library | Medium — another persistent HUD element per hidden player | Off-screen indicator arrows (adapted, not literal) |
| (c) Fresnel planet ghosting | Low-medium — view-angle-dependent, competes with planet-as-reference-frame | Medium — fresnel shader on planet mesh, needs per-planet player-occlusion state | Medium — planet flicker as players/camera move | Sims-style "x-ray bubble" dollhouse transparency |
| (d) Satellite minimap | Medium (global) / Low (per-target, tiny at couch distance) | Low-medium — SubViewport + ortho cam, straightforward | High — adds a whole second dense readout on top of an already-busy HUD | MOBA fog-of-war silhouette-through-terrain |
| (e) Camera auto-orbit / PiP | N/A — breaks control frame or adds heavy clutter | High, and partially wasted (fights existing architecture) | High (PiP) | Renegade Ops dynamic split-screen |

## C. Recommendation: primary + fallback

**Primary: (a), built as a sibling-mesh silhouette off the existing
`_marker` pattern — always-on, not occlusion-gated.** The spec already
states a design value that this technique directly serves: "Orbits must be
VISIBLE... the late-game sky = readable spirograph"
(`minigame-orbital-dodgeball.md:47-50`) — the whole game already commits to
"see through the chaos" as a stated feel goal, not just a bug to patch.
Always-on (rather than occlusion-gated) is simpler to implement (no
per-frame raycast/dot-product occlusion test needed — `depth_test_disabled`
naturally does nothing extra when the character is already visible, since
the normal opaque pass already drew the correct pixel first) and reads
consistently instead of popping in/out as players cross a planet's limb.

**Fallback, ship only if v1 playtesting shows directional confusion, not
preemptively: (b), planet-rim peek arrows.** A flat silhouette answers
*"someone's back there"*; it doesn't say *which way to flank or dodge*. If
playtesting shows humans still lose fights to bots because they can't tell
which side to circle toward, add the rim indicator as a second, thin layer
— but don't build it speculatively; it's the priciest of the viable options
and the silhouette alone may already close the human/bot gap, since bots
"aim at nearest enemy" (`minigame-orbital-dodgeball.md:60`) using raw
position data, not genuine vision — a silhouette gives humans the same
raw-position awareness bots already have, which is the actual parity target.

**Explicitly not recommended:** (c) fresnel planet ghosting (undermines the
planet-as-spatial-reference-frame the whole control scheme depends on); (d)
minimap (blows the anthology's documented 4× clutter budget and splits
attention in a 0.2s-catch-window game); (e) camera changes (architecturally
incompatible with the screen-relative parallel-transport control frame).

## D. Godot 4 implementation sketch

Extends `minigames/orbital/orb_pawn.gd`. Adds a low-poly capsule silhouette
as a sibling of the existing `_marker`, reusing `BODY_R`/`CENTER_H` already
defined on the pawn (`orb_pawn.gd:26-27`) so the proxy matches the real
body's footprint without needing the detailed KayKit rig in a second pass.

```gdscript
# --- add near the top of orb_pawn.gd, alongside the existing consts ---
const XRAY_ALPHA := 0.5

# --- inside setup(), right after the existing _marker block (orb_pawn.gd:91-105) ---
var _xray: MeshInstance3D = null

func _add_xray_silhouette(col: Color) -> void:
	_xray = MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = BODY_R
	cap.height = CENTER_H * 2.0 + BODY_R          # roughly the visible body's bounds
	_xray.mesh = cap
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(col.r, col.g, col.b, XRAY_ALPHA)
	mat.no_depth_test = true          # the same property _marker already uses
	mat.render_priority = 9           # just under the marker's 10, above world geo
	_xray.material_override = mat
	_xray.position = Vector3(0, CENTER_H, 0)
	_visual.add_child(_xray)
```

Call `_add_xray_silhouette(col)` from `setup()` next to the existing
`_marker` construction. No changes needed to `_process()` — `no_depth_test`
draws over occluding geometry automatically every frame; when the character
is already unoccluded, the normal KayKit `inst` mesh (opaque, depth-tested)
draws its correct pixel first in the same draw call ordering the engine
already uses for `_visual`'s children, so the translucent capsule just adds
a faint tint on top of an already-correct pixel — harmless, and arguably a
useful "this is MY color" reinforcement even when fully visible.

**If richer visual treatment is wanted later** (fresnel edge glow, a
scanline "ghost" read instead of a flat tint) — the custom-shader version,
kept for reference, still avoiding `next_pass` per the bug note in §A:

```glsl
// res://minigames/orbital/shaders/xray_silhouette.gdshader
shader_type spatial;
render_mode unshaded, depth_test_disabled, cull_back;

uniform vec4 player_color : source_color = vec4(1.0, 1.0, 1.0, 0.5);
uniform float fresnel_power : hint_range(0.5, 6.0) = 2.5;

void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), fresnel_power);
	ALBEDO = player_color.rgb;
	ALPHA = clamp(player_color.a + fres * 0.35, 0.0, 1.0);
}
```

Assign as a `ShaderMaterial` on the same sibling `MeshInstance3D` (not as a
`next_pass`) to get an edge-brightened "ghost" silhouette that reads even
more clearly at the planet's limb, at the cost of one more uniform to wire
per player color.

## E. Risks & tests (house `VERIFY.md` convention)

- **Clutter ceiling**: silhouette count is capped at 3 (max simultaneous
  hidden players; a 4th is the viewer) regardless of ball count — stays
  inside doc 08's "4× clutter budget" by construction, since it scales with
  players, not with the up-to-8 concurrent balls.
- **Perf**: 4 extra `CapsuleMesh` instances with an unshaded, unlit material
  and no lighting pass — negligible against the existing per-frame
  `no_depth_test` marker orb already proven at this scale.
- **Bot-fairness closure test** (mirrors the existing `minigame-orbital-
  dodgeball.md:64-69` risk-test convention): run a bot-vs-bot sim with one
  bot's aim source swapped to "silhouette-only" position sampling (same
  data a human would now see) vs. the current raw-position aim, and assert
  win-rate parity within a few points — the silhouette closing the gap is
  the actual success criterion, not "looks nice."
- **Colorblind pairing**: reuse the existing shape+color badge system
  (`core/player_badge.gd`, glyphs `● ▲ ■ ◆`, already the anthology's
  colorblind mitigation per doc 08) — if playtesting flags color-only
  confusion between two similarly-hued silhouettes, project the player's
  glyph onto the capsule via a small `Label3D` rather than adding a new
  accessibility system.

---

## Sources

**Jump / game feel:**
- Kyle Pittman, "Math for Game Programmers: Building a Better Jump," GDC 2016 — mathforgameprogrammers.com/gdc2016/GDC2016_Pittman_Kyle_BuildingABetterJump.pdf
- "Game Feel: A Beginner's Guide" — gamedesignskills.com/game-design/game-feel
- Pichlmair & Johansen, "Designing Game Feel" — arxiv.org/pdf/2011.09201
- Coyote time / Celeste values — thealmightyguru.com/Wiki/index.php?title=Coyote_time ; gamerant.com/celeste-coyote-time-mechanic-platforming-impact-hidden-mechanics
- "Coyote Time, Input Buffering, and the Art of Forgiving Controls" — gamejuice.co.uk/articles/coyote-time-input-buffering
- Godot Mentor, "Celeste-Like Platformer in Godot with C#" — godotmentor.com/en/tutorials/celeste-like-godot-csharp-jump-physics
- Party Animals vs. Gang Beasts combat comparison — sportskeeda.com/esports/major-differences-party-animals-gang-beasts ; pcgamer.com/its-no-gang-beasts-killer-but-party-animals-has-made-me-fall-in-love-with-physics-based-mayhem-all-over-again
- Boomerang Fu dash/jump interchangeability — boomerangfu.fandom.com/wiki/Game_options

**Visibility / x-ray:**
- Godot X-Ray Vision Effect shader — godotshaders.com/shader/x-ray-vision-effect
- Fake stencil silhouette/outline (Godot) — godotshaders.com/shader/fake-stencil-silhouette-outline-object-based-but-without-depth-test
- Tim Klein, "Character Depth Shader" — timjklein36.github.io/posts/character_depth_shader
- Godot spatial shader docs (`depth_test_disabled`) — docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html
- `BaseMaterial3D`/`StandardMaterial3D.next_pass` docs — docs.godotengine.org/en/stable/classes/class_basematerial3d.html
- Godot `next_pass` depth-test bug (4.2.1) — github.com/godotengine/godot/issues/95419
- Overwatch ally x-ray technique (Mercy et al.) — lindenreidblog.com/2018/03/17/x-ray-shader-tutorial-in-unity (technique writeup, engine-agnostic)
- Off-screen indicator arrow pattern — code.tutsplus.com/positioning-on-screen-indicators-to-point-to-off-screen-targets--gamedev-6644t
- Super Mario Galaxy fixed-camera small-planet handling — gamedeveloper.com/design/understanding-the-fun-of-super-mario-galaxy
- MOBA fog-of-war / silhouette-through-terrain (League of Legends) — wiki.leagueoflegends.com/en-us/Sight
- Renegade Ops dynamic split-screen — ph3at.github.io/posts/Ray-Coop-Camera

**In-repo (cited by file:line throughout):** `docs/specs/anthology-module-
contract.md`, `core/player_input.gd`, `scripts/player_avatar.gd`,
`minigames/orbital/orb_pawn.gd`, `minigames/orbital/orbital.gd`,
`minigames/dead_weight/fighter.gd`, `minigames/echo_chamber/fighter.gd`,
`minigames/echo_chamber/echo_chamber.gd`, `minigames/masked_ball/
masked_ball.gd`, `docs/specs/minigame-orbital-dodgeball.md`,
`docs/specs/minigame-dead-weight.md`, `docs/specs/minigame-tilt.md`,
`docs/specs/minigame-the-throne.md`, `docs/design/08-gamefeel-research.md`,
`estate/estate.gd`.
