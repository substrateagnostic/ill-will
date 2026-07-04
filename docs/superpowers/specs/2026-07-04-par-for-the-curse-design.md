# PAR FOR THE CURSE — Design Spec

*2026-07-04. Chosen from 20 concepts (docs/design/00-ideation.md) refined
against genre research (docs/design/02-research-notes.md). Direction approved
by discretion grant; Alex can redirect at any commit boundary.*

## One line

Sabotage mini-golf on a course that remembers: players draft and place the
traps themselves, putt through the gauntlet they co-authored, and the same
hole accretes traps and gravestones all match until it's a haunted Rube
Goldberg museum of the evening's grudges.

## Design pillars

1. **The course is the scoreboard of your sins.** Every trap keeps its
   author's name forever; every death leaves a gravestone. Accretion is the
   twist nobody has shipped.
2. **Cruelty is a loan you cosign.** You must putt through your own traps
   (UCH self-incrimination), and your traps pay you royalties when they kill.
3. **Catch-up is earned and announced.** Last place drafts from the visibly
   nastier CURSED deck (the ROUNDS lesson). No hidden luck taxes.
4. **The putt must feel excellent.** SBG's documented failure. Drag-release,
   predictable physics, first-bounce preview. Tuning this is priority zero.
5. **Nobody is ever out; everybody watches everything.** Hotseat sequential
   strokes = communal spectacle. Death pays grudge. Killcam credits the
   architect.

## Players & input

- 2–4 players, couch hotseat, **one mouse** is the only required hardware.
- Turn-based phases pass the mouse; stroke-rotation putting means nobody
  waits more than ~20s. Gamepads + simultaneous "chaos putting" = post-v1.

## Match structure

One course diorama. **9 rounds** on the same hole. Match = ~30-40 min.

Round flow:
1. **DRAFT** — reverse-standings order; each player picks 1 of 3 face-up trap
   cards. Last place's row includes CURSED variants (bigger, meaner, higher
   royalty). Public draft = table talk.
2. **BUILD** — reverse-standings order; place your trap with ghost preview
   (mouse move, wheel/R to rotate; invalid zones shaded red: no-build radius
   around tee, cup, and existing cup path chokepoints must remain solvable —
   v1 rule: a 0.8m-wide corridor check from tee to cup must exist).
   20s shot clock.
3. **PUTT** — stroke rotation (everyone takes stroke 1, then stroke 2, ...)
   in standings order, leader first (leader faces the unknown course first =
   subtle transparent catch-up). Round ends when every ball is sunk or dead,
   or after 6 strokes (ball petrifies where it rests = DNF).
4. **SCORE** — banner + scoreboard.

## Scoring

- Finish order in the round: 5 / 3 / 2 / 1 points (2P: 3/1).
- Fewer strokes breaks ties within the round.
- **Royalties:** +2 to a trap's author each time it kills a ball (forever —
  round-2 windmills still pay in round 9). Author cannot earn royalties from
  own death.
- Death or DNF: 0 points, +1 **grudge**.
- **Grudge spend:** next draft, +1 extra card option drawn from the CURSED
  deck. (Poltergeist-nudge spend = post-v1.)
- Win: most points after 9 rounds. Tiebreak: total royalties ("the crueler
  architect wins").

## Death & accretion

- Kill traps (spikes, crusher, water, void) shatter the ball: particles,
  slow-mo beat, sad trombone, banner "DEATH BY: {AUTHOR}'S {TRAP}".
- A **gravestone** spawns at the death spot: small collidable obstacle in the
  dead player's color, engraved with round number. Gravestones persist all
  match and affect play (bank shots off your friend's corpse are encouraged).
- All placed traps persist all 9 rounds. Nothing is ever cleaned up. That's
  the point.

## Trap library (v1: 10)

Standard: Windmill (rotating blades, blocks), Bumper (pinball kicker),
Fan (steady push zone), Sand pit (heavy damping), Wall (L-piece), Ramp.
Killers: Spike strip, Crusher (timed smasher), Water strip, Magnet Mine
(pulls then detonates).
CURSED variants (drafted only via catch-up/grudge): Double Windmill, Mega
Bumper, Black Hole (stronger magnet, bigger radius), Crusher Row.
Each trap = one .tscn + shared TrapBase script (author id, royalty hook,
placement footprint, validity rules). Library growth is the content axis.

## Look & feel

Toy diorama: miniature golf course standing in a warm den — the game reads
as a board game come alive. Flat colors + toon-ish shading, Kenney Minigolf
Kit geometry, KayKit characters as caddies/avatars at the tee, chunky Kenney
UI, Fredoka/Baloo text, Luckiest Guy logo. Juice: screenshake on kills,
confetti on sinks, slow-mo death beats, ball squash-stretch, crowd "oooh"
SFX. Camera: 3/4 diorama orbit; drag-putt happens from this view (whole-
course readability beats behind-ball cam for trap-dodging).

## Tech architecture (Godot 4.6.2)

- `GameState` (autoload): players, standings, round, phase state machine,
  trap registry (author map), grudge, RNG seed.
- `Course.tscn`: base green + TrapContainer + GravestoneContainer + Tee/Cup.
- `Ball.tscn`: RigidBody3D sphere, tuned damping, sink/kill detection.
- `traps/*.tscn`: TrapBase.gd inheritance; each exports footprint + validity.
- `ui/`: DraftUI, BuildUI (ghost placement), PuttUI (drag indicator),
  Scoreboard, Banners. Godot Control nodes + Kenney UI theme.
- Verification loop: windowed run → viewport PNG capture → read; motion via
  `--write-movie` + ffmpeg stills. Debug autoload `VerifyCapture` triggered
  by CLI arg so shipping build is clean.
- Solvability check: corridor raycast sweep tee→cup on placement validity.

## Build phases (each = build-check, visual verify, commit)

1. **Putt feel** — green, walls, ball physics, drag-release aim + preview,
   sink detection, diorama camera. Exit: a putt that feels good in a clip.
2. **Round loop** — hotseat 2-4 players, stroke rotation, finish/DNF, scores,
   phase banners, scoreboard.
3. **Traps** — TrapBase, 6 standard traps, draft UI, ghost placement +
   validity + solvability.
4. **Blood & memory** — killers, death FX, gravestones, royalties, CURSED
   deck, grudge draft bonus.
5. **Art & juice** — Kenney/KayKit assets, toon look, particles, SFX/music,
   menus, logo, killcam banner polish.
6. **Tuning & wow** — playtest balance pass, course-history flyover at match
   end (the closer: watch the hole grow round by round), chaos-mode putting
   if time allows.

## Non-goals (v1)

Online multiplayer, level editor UI, workshop, more than one base course,
poltergeist live-nudges, controller support (designed-for but not wired).

## Risks

- Putt feel is make-or-break → Phase 1 is only that, verified by motion clips.
- Solvability griefing (walling the cup) → corridor check + no-build radii.
- Trap balance (killers dominating) → royalty economy tuning in Phase 6;
  kill traps have narrow footprints, hinder traps wide ones.
- Hotseat pacing → shot clocks on build (20s) and stroke (25s).
