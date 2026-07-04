# TILT — minigame spec (v1)

*Read anthology-module-contract.md first. Folder: `minigames/tilt/`.*

## One line

Everyone stands on ONE giant platter balanced on a pin; **every player's
weight tilts the shared world in real physics**. Grab coins that make you
heavier — more influence, worse footing. Last one aboard wins the round.

## Loop

Best-of-5 rounds, ~60s each. 2–4 players simultaneous (move + A + B).

- The platter: 14m disc, RigidBody3D constrained to rotate around its center
  pin only (pitch/roll via Generic6DOFJoint or manual torque model — v1
  recommended: keep platter STATIC-visual but compute tilt from torque sum
  each physics tick and set rotation directly; players are
  CharacterBody3D moving on it, gravity slides everyone downslope).
- Tilt model: torque = Σ(player_mass_i × offset_i) + coin stacks; platter
  responds with angular acceleration + damping; max tilt ~22°. At >14° a
  LOW-side klaxon + edge glow warns.
- Players: KayKit characters, move 4.5 m/s (± slope), **A = shove** (small
  forward knockback cone, 0.8s cd), **B = brace** (2s: you don't slide, you
  can't move, 3s cd).
- Coins spawn center-biased every 3s. Each coin: +8% mass, +1 point, and
  visibly stacks on your back (comedy + information: everyone SEES who's
  heavy).
- Fall off: you're out for the round — but become a **seagull**: fly freely,
  press A to drop one guano bomb per 4s (brief slip zone on platter). Dead
  players stay dangerous.
- Round ends when one remains (or 60s → everyone standing splits the win).
- Sudden death at 45s: pin rises, tilt limit +8°, coins stop.

## Scoring → results

- Round win +4, survival-order 2/1/0, coins banked +1 each.
- currency_events: royalty +1 when your shove directly causes a fall
  (credit within 1.5s of shove contact); grudge +1 per fall.
- highlights: heaviest player, best shove chain.

## Feel targets

- The platter must feel ALIVE: tilt response lag ~0.4s (mass), overshoot
  slightly. Players' downhill slide accelerates with sin(tilt).
- Readability: platter face has concentric rings + compass colors; shadow of
  the tilt on the floor below.
- Camera: fixed 3/4 whole-platter; subtle roll (≤3°) WITH the platter.

## v1 scope

MUST: tilt-from-weight model, move/shove/brace, coins=mass=points, falls,
seagull mode, best-of-5, results contract, seeded self-play bots.
SHOULD: sudden death, guano slip zones, coin back-stacks.
WON'T (v1): platter cracking, powerups, hazards on platter.

## Risks & tests

- Tilt model stability (no oscillation runaway): damp until a 4-bot idle
  test holds |tilt| < 3° for 30s. CharacterBody on rotating floor: move
  players in platter-local space, apply slide velocity manually — do NOT
  trust floor friction alone (test: bot standing at edge at 20° must slide).
