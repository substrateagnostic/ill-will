# Research Digest (2026-07-03)

Condensed from three research agents. Full detail lived in session context;
this is the durable record.

## Genre findings that shape the design

- **Super Battle Golf** (2026, 1M+ sales, built in 4.5 months by a tiny team):
  twist = simultaneous weaponized golf. Documented complaints: (1) undercooked
  putt *feel* (max-power shots go nowhere, steering inverts), (2) zero comeback
  mechanics — last place gets camped with no recourse, (3) thin content, no
  workshop. These are our design opportunities.
- **The ROUNDS lesson**: the only beloved catch-up mechanic in the genre is
  *loser drafts the powerup* — transparent, earned, announced. Mario Party's
  opaque luck-redistribution is widely hated (Jamboree added an off switch).
- **The UCH lesson** (Ultimate Chicken Horse): self-incrimination — you may
  only screw others with hazards you must also survive — is the cleanest
  "how cruel can I afford to be?" tension in the genre.
- **Effort-to-fun ranking** for small teams: (1) one tight verb + combinatorial
  draft variety, (2) physics sandbox, (3) familiar verb + one twist +
  simultaneity, (4) player-authored content as force multiplier,
  (WORST) board + minigame collection — never build minigame piles solo.
- Other atomic patterns to bake in: targeted screwage (choosing WHO), instant
  unambiguous kills, always-in-play (dead players never just wait), built-in
  spectacle/killcam layer, physics ambiguity as blame-generator.

## Tooling decision

**Godot 4.6.2** (installed, MIT, MCP wired). Verify loop PROVEN on this
machine: author .tscn/.gd as text → run windowed → viewport capture PNG →
read image. `--write-movie` + ffmpeg frame extraction for motion checks.
- UID discipline (Godot ≥4.4): after adding new resources, run
  `godot --headless --editor --import --quit --path .` before running.
- .tscn comments are stripped on editor resave — don't document in scenes.
- Keyboard sharing: 2 players max reliably (ghosting). Design is
  mouse-hotseat-native + optional gamepads, so this doesn't bind.
- Web export later is possible (itch.io supports SharedArrayBuffer headers).
- Web stack (Three.js+Playwright) was the runner-up; rejected because the
  screenshot loop is already solved in Godot and the game wants real 3D
  lighting/physics/UI/audio without hand-assembly.

## Asset shopping list (all free; licenses noted)

| Need | Pick | License |
|---|---|---|
| Golf course pieces | **Kenney Minigolf Kit** (126 models, GLB) | CC0 |
| Characters | **KayKit Adventurers** (4-5 chunky rigged chars, 75 anims) + KayKit Skeletons (90+ anims — gravestone/ghost theme!) | CC0 (verified in LICENSE.txt) |
| Extra chars/animals | Quaternius Ultimate Animated packs (52 chars / 12 animals) | CC0 |
| Props | Kenney Platformer Kit (153), Food Kit (200), Nature Kit | CC0 |
| UI | Kenney UI Pack (~430 pcs + fonts + SFX), Input Prompts (1500 icons), Board Game Icons | CC0 |
| Particles | Kenney Particle Pack (80 sprites) | CC0 |
| SFX | Kenney Impact/UI/Jingles/Interface packs; Freesound CC0 filter for sad trombones (9), crowd cheers (586), boings (68) | CC0 |
| Music | Pixabay Music (no attribution) ; Kevin MacLeod as CC-BY fallback | Pixabay/CC-BY |
| Fonts | Fredoka + Baloo 2 (UI), Luckiest Guy (logo), Bangers (callouts) | OFL |
| HDRI (if needed) | Poly Haven 2K studio HDRI via public API | CC0 |

Automation: Kenney = direct zips; itch.io KayKit/Quaternius = $0 checkout no
account; Freesound needs a free account (fallback: Kenney covers most SFX).
Aesthetic note from research: the Fall Guys/Mario Party look is flat color +
toon shading + 3-point lighting, NOT PBR textures. Budget effort into palette
and shading, not texture libraries.

**Total budget: $0.** (Optional later: itch.io hosting free; Steam page $100
only if we ever want it.)
