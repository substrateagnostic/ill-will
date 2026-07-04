# Anthology Module Contract (v1)

*For any model/agent building a minigame for the UN Party Game anthology.
Read this + your minigame spec + `core/minigame.gd` + `core/player_input.gd`
before writing code. The reference implementation of the house style is
`scripts/main.gd` (Par for the Curse).*

## The deal

You build **one self-contained scene** under `minigames/<your_game>/`.
Root node extends `Minigame` (core/minigame.gd) or duck-types it exactly
(`signal finished(results: Dictionary)` + `func begin(config: Dictionary)`).
The party shell instantiates your scene, calls `begin(config)`, and waits.
You NEVER: change scenes, touch GameState, write global scores, load other
minigames, or use `randomize()`/`Date.now()` (seed from `config.rng_seed`).

Config and results shapes are documented exhaustively in `core/minigame.gd`.
Always include every roster player in `placements`. Report `currency_events`
— the cross-game spite economy ("royalty" = you profited from someone's
suffering; "grudge" = you suffered) is the anthology's signature; your game
must feed it.

## Input

Use the `PlayerInput` autoload for ALL player controls (see
core/player_input.gd): `get_move(p)`, `is_down(p,"a"|"b")`,
`just_pressed(p,"a"|"b")`. Device assignment is the shell's job — never read
gamepads/keys directly. Design for 2–4 players. Input policy (2026-07-04):
assume ONE full control surface per player (gamepad or M+KB) — keyboard
halves are a fallback, not the design target. Verb budget per player stays
move + A + B (tap/hold variants welcome). Design within it. Online/web
co-op is a future phase: keep player state authoritative in one place per
player and avoid frame-coupled input assumptions where cheap to do so.

## House style (non-negotiable)

- **Player identity**: use `roster[i].color` on everything owned by a player
  (Par: balls, trap accents, gravestones, banners). Use `roster[i].char_scene`
  (KayKit GLB, 76+ anims incl. Idle/Cheer/Death_A) for avatars where the
  game wants bodies — see `scripts/caddy.gd` for the wrapper pattern.
- **Nobody watches dead air**: eliminated players get SOMETHING (spectate
  power, ghost nudge, points drip). Rounds ≤ 90s.
- **Catch-up is earned and announced**, never hidden luck.
- **Juice floor**: Sfx autoload for putt-class/impact/fanfare sounds
  (`Sfx.play("bounce")` etc. — see scripts/sfx.gd BANK), screenshake on big
  moments, banner text in Luckiest Guy (see main.tscn UI), confetti/particles
  on wins, slow-mo beat (Engine.time_scale dip) on kills.
- **Fonts/UI**: Fredoka default (project-wide), Luckiest Guy banners,
  Baloo 2 small headers. Colors: saturated, chunky, outlined text.
- **Assets**: CC0 only. Available in-repo: KayKit characters
  (assets/models/kaykit), Kenney minigolf models (assets/models/minigolf),
  Kenney audio (assets/audio, add more from assets_raw/), Kenney particles/UI
  (assets_raw/kenney_particles, kenney_ui). Ask before adding new sources.

## Verification (required before you call it done)

The repo has a screenshot-verification autoload (`scripts/verify_capture.gd`).
Support these CLI user args in your game (after `--` on the command line):
- `--shots=N,N,...` works automatically (captures PNGs to verify_out/).
- Implement a deterministic self-play hook analogous to Par's `--autoplay`
  so the game can demo itself headed-but-unattended: expose
  `is_turn_ready()`-style state + a `debug_*` action method, or listen for
  your own custom arg. Every mechanic must be demonstrable via CLI + PNGs.
- After adding files: `godot --headless --editor --import --quit --path .`
- Exit criteria per spec. Include a `VERIFY.md` in your folder listing the
  exact commands you ran and what the screenshots show.

## GDScript gotchas (learned the hard way here)

- Never `:=` infer from untyped Array/Dictionary elements — annotate.
- AnimatableBody3D + sync_to_physics ignores ancestor transform changes:
  disable sync during any ghost/preview dragging, re-enable when live.
- .tscn comments get stripped by the editor; document in .gd files.
- RigidBody3D state changes inside physics callbacks need call_deferred.
- Test continuous interactions with GRADUAL simulated motion, not teleports.
