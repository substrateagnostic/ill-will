# ORBITAL DODGEBALL — minigame spec (v1)

*Read anthology-module-contract.md first. Folder: `minigames/orbital/`.*

## One line

Dodgeball on a cluster of tiny planets with real gravity wells — **thrown
balls never despawn, they orbit**, and the sky slowly fills with everyone's
old throws coming back around.

## Loop

One continuous 3-minute match (no rounds). 2–4 players simultaneous.

- World: 3 planets (spheres r=3, r=2.2, r=1.8) in a triangle, ~7m apart,
  starfield skybox. Each planet has its own radial gravity (walk all the way
  around, Mario-Galaxy-lite). Camera: fixed wide shot framing all three
  (planets sized/spaced so this reads at 1280×720).
- Players: KayKit chars stuck to planet surfaces (local up = radial).
  move = surface walk 4 m/s; **A = throw/catch**, **B = jump** (hop, can
  reach a neighboring planet at the near points — jump vector blends the
  wells).
- Dodgeballs: start 4 on pedestals. Throw: hold A to aim (simple power
  ramp 0→1 over 0.8s + your facing), release: ball launches and is then
  governed ONLY by the n-body gravity of the 3 planets (cheap: sum of 3
  inverse-square pulls, integrate; cap speed). Balls bounce off planets
  with 0.75 restitution, lose 3% speed/s in "space drag" so orbits decay
  over ~40s into planet-grazing death spirals.
- HIT: a ball moving >4 m/s that touches a player kills them: big pop,
  ragdoll fling of the KayKit model along ball vector (physics ragdoll not
  required: launch the whole character rigid + spin, despawn 2s).
  Respawn 3s later on the least-crowded planet. The killing ball keeps
  flying. **Kill credit: last thrower of that ball, forever** — a 30-second
  old orbit that clips someone credits its original thrower:
  "GOLD'S GHOST ORBIT STRIKES".
- CATCH: press A within 0.2s of an incoming ball >4 m/s: you catch it
  (steal + 0.5s invulnerability + "NICE CATCH" banner). High skill ceiling.
- Every 45s a new ball spawns (sky fills: up to 8 balls in flight late game).

## Scoring → results

- +2 per kill, +1 per catch, −0 for deaths (deaths feed grudge only).
- placements by points. currency_events: royalty +1 for kills by balls
  thrown >10s ago (the signature accretion kill), grudge +1 per death.
- highlights: oldest-orbit kill with age ("a 34-second orbit").

## Feel targets

- Orbits must be VISIBLE: each ball leaves a faint fading trail in its
  current owner's color (2s ribbon). The late-game sky = readable spirograph.
- Throw aim: show predicted path for the FIRST 1.5s only (dotted line,
  cheap integration preview).
- Planet walking must never disorient: camera stays fixed; characters
  orient to surface; controls are screen-relative (move.x = screen right).

## v1 scope

MUST: 3-planet radial gravity walk, throw/orbit physics with trails, kill
credit to last thrower with age tracking, catch, respawn, 3-min match,
results contract, seeded bots (walk, aim at nearest enemy, occasional jump).
SHOULD: aim preview, planet-hop jumps, catch invuln flash.
WON'T (v1): destructible planets, powerups, more planet layouts.

## Risks & tests

- Screen-relative controls on spheres: test bot circumnavigates each planet
  without control flips (log heading continuity).
- Orbit stability: with 8 balls, none may enter a >60s stable orbit (space
  drag guarantees decay — assert max ball age < 75s in a 3-min bot sim).
