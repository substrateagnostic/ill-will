# ECHO CHAMBER — verification

Top-down arena brawl where every previous round replays as translucent,
owner-tinted ghosts. Your echoes earn YOU points when they land hits in the
present ("PAST BLUE STRIKES AGAIN"). 5 rounds, 2–4 players, seeded self-play.

Root scene: `minigames/echo_chamber/echo_chamber.tscn` (root extends
`Minigame`). Files: `echo_chamber.gd` (controller), `fighter.gd` (live
player/bot), `ghost.gd` (replay actor).

---

## Commands actually run

Import pass (required after adding files):
```
godot --headless --editor --import --quit --path .
```

Seeded self-play, 5 full rounds, state-based screenshots (the reliable way to
hit the round-5 density shot — see "Screenshots" note):
```
godot --path . res://minigames/echo_chamber/echo_chamber.tscn -- \
  --echobots --echofast=5 --seed=1 --echocap --outdir=verify_out
```
Writes `verify_out/echo_{r1_play,r2_ghosts,r3,r4_full12,r5_dense_preshrink,r5_postshrink}.png`
and quits after the last beat.

House-standard frame-indexed capture (module contract `--shots`, VerifyCapture
autoload) also works:
```
godot --path . res://minigames/echo_chamber/echo_chamber.tscn -- \
  --echobots --echofast=5 --seed=1 --shots=300,820 --quitafter=2600 --outdir=verify_out
```

Standalone self-start (NO `begin()` call, NO bots — proves the 0.5s auto-start
with a default 4-player roster from GameState + KayKit chars):
```
godot --headless --path . res://minigames/echo_chamber/echo_chamber.tscn -- \
  --echofast=3 --echocap --seed=7 --outdir=verify_out
```
Logged: `ECHO_BEGIN players=4 seed=7 bots=false` → rounds 1..5 → `ECHO_MATCH_OVER`.

### CLI args this game understands (after `--`)
- `--echobots` — seeded self-play bots (wander + swing + dash). Deterministic.
- `--echofast=SECS` — round length (default 45). Shortens rounds for verify.
- `--echocap` — state-based screenshots at fixed game beats; quits when done.
- `--outdir=DIR` — output dir for `--echocap` (default `verify_out`).
- `--seed=N`, `--players=N` — used by the standalone default config.
- `--shots=…`, `--quitafter=…` — handled by the house VerifyCapture autoload.

---

## Screenshots (verify_out/, from seed=1 --echobots --echofast=5)

- **echo_r1_play.png** — Round 1, GHOSTS: 0. Four KayKit fighters with
  saturated identity rings on a lit circular arena, 3 cover pillars, yellow
  safe-zone ring, HUD (round / countdown / scoreboard with ♥ HP pips / ghost
  count). Baseline: no ghosts yet.
- **echo_r2_ghosts.png** — Round 2, GHOSTS: 4. Cleanest read of the core idea:
  LIVE players are opaque + textured + ringed; GHOSTS are 55%-translucent,
  flat owner-color, no ring — visibly "past selves." "PAST MINT STRIKES AGAIN"
  bounty banner is live.
- **echo_r3.png / echo_r4_full12.png** — Ghost ramp 8 → 12. In r4 a BLUE ghost
  is caught mid-swing (sword extended) — ghost combat is visible; bounty banner
  firing.
- **echo_r5_dense_preshrink.png** — THE make-or-break shot. Round 5, GHOSTS: 12
  (capped). 12 translucent owner-tinted echoes + 4 live players. Live vs ghost
  still separable by opacity/texture. Bounty banner active.
- **echo_r5_postshrink.png** — Arena collapse: the outer ring has fallen away,
  the yellow boundary now hugs the shrunk inner disc, brawl continues on the
  smaller platform, "THE FLOOR FALLS AWAY!" banner.

Note on screenshots: framerate is uncapped and load-dependent, so frame-indexed
`--shots` cannot reliably land on "round 5" (frame→round mapping drifts with
load). `--echocap` fires captures off GAME STATE (round + round-clock), so the
round-5 density shot is guaranteed. Both capture paths use the same viewport
image grab, so run `--echocap` **windowed** — under `--headless` there is no
`frame_post_draw`, so PNG saving is skipped (logged `ECHO_CAP_SKIP_HEADLESS`)
and the run still exits cleanly; only the logic is exercised, not the image.

---

## Determinism test (spec Risk: "replay drift")

Each round end asserts every live ghost's node position equals its recorded
final 30Hz sample within 0.01, and prints the measured max error. Because
ghosts are driven by DIRECT transform application (never re-simulated physics),
the error is exactly 0:
```
ECHO_DETERMINISM round=1 ghosts=0  max_err=0.000000 OK
ECHO_DETERMINISM round=2 ghosts=4  max_err=0.000000 OK
ECHO_DETERMINISM round=3 ghosts=8  max_err=0.000000 OK
ECHO_DETERMINISM round=4 ghosts=12 max_err=0.000000 OK
ECHO_DETERMINISM round=5 ghosts=12 max_err=0.000000 OK
```
This is a real integration test of record → take-store → `Ghost.replay()`
boundary clamp → transform write (an off-by-one or interpolation overshoot at
the last sample would make it nonzero). `assert()` halts on drift.

Update order that guarantees it (all inside one physics step, in `_tick_play`):
1. tick live fighters (input + `move_and_slide`), in index order
2. sample the 30Hz recorder from post-move state, keyed to the round clock
3. replay ghosts by direct transform vs those fresh positions
Fighters are driven manually (no per-fighter `_physics_process`) so this order
is fixed.

Sample of the bounty economy working (same run):
```
ECHO_BOUNTY_KILL ROUND-2 GOLD KILLED PRESENT GOLD   <- your own echo kills you
ECHO_BOUNTY_KILL ROUND-1 RED KILLED PRESENT RED
ECHO_MATCH_OVER champ=GOLD placements=[2, 0, 3, 1]
```

---

## Perf (spec Risk: "12 ghosts + 4 players")

Watchdog samples `Performance.TIME_PROCESS`; if the 45-frame average exceeds
8 ms it degrades once (drops ghost shadows — already off by default for
readability — and thins ghost opacity), logging `ECHO_PERF degraded=true`.
Additionally: ghosts never cast shadows, and the OLDEST kept ghost-round is
rendered at 0.4 opacity for readability; total ghosts are hard-capped at 12
(oldest ROUND dropped first: r5 replays rounds 2–4, not 1).

Caveat: under `--headless` the software rasterizer renders 12 skinned meshes at
~160 ms/frame and the watchdog trips immediately — this is a headless artifact,
not real perf. Windowed on a GPU renders all 12 ghosts fine (see the r4/r5
PNGs, produced windowed).

---

## MUST checklist (v1 scope)

- [x] Recording/replay — 30Hz capture (pos/yaw/anim-state/swing-fire), replay by
      direct transform. Determinism asserted (±0.01, prints 0.000000).
- [x] Melee — A swing, 120° arc, range 1.9m, hitbox live 0.04s after press
      (<50ms), knockback + 1 dmg, 0.5s cooldown.
- [x] Dash — B, 0.25s burst at 11 m/s, 1.2s cooldown, i-frames whole dash.
- [x] HP / respawn — 3 HP, death → 2s respawn at arena edge, nobody eliminated.
- [x] Bounty credits — your ghost hitting a live player: +1 to YOU now, banner
      "PAST <COLOR> STRIKES AGAIN", royalty currency event.
- [x] 5 rounds × 45s (knob via `--echofast`).
- [x] Banners — Luckiest Guy, pop-scaled, owner-colored (round/credit/collapse).
- [x] Results contract — placements (all roster, ties→lower index), points,
      currency_events (royalty per ghost-hit, grudge per 2+ death round),
      highlights (ghost-kill one-liners), monuments (top-bounty "revenant").
- [x] Self-play hook — `--echobots`, seeded wander/swing/dash.

## SHOULD checklist

- [x] Round-5 shrink — outer ring falls (30%), fall = death + center respawn at
      half HP (2), telegraphed mid-round.
- [x] Hit-pause — 0.05s freeze at time_scale 0.2 on impact, throttled 0.16s so a
      swarm of ghosts can't lock the game in slow-mo.
- [x] KayKit avatars — roster `char_scene` (Barbarian/Knight/Mage/Rogue),
      Running_A / Idle / 1H_Melee_Attack_Slice_Horizontal / Dodge_Forward /
      Hit_A / Death_A.

## Scoring

+2 per live hit · +1 per credited ghost hit · +3 survival bonus (0 deaths that
round). currency: royalty +1 per ghost-hit; grudge +1 per round a player died
2+ times.

---

## Known issues / notes

- Bots cluster toward center (targets sampled within 0.8·platform_r), so the
  round-5 crowd is a tight blob in verify shots. Human play spreads out more;
  gameplay/readability is unaffected. Not a code issue.
- Headless perf is software-rasterizer bound (see Perf caveat) — verify GPU
  frame cost windowed, not headless.
- After `finished` is emitted the scene idles (shell owns teardown). Standalone
  runs can press R to reload.
- Cross-run determinism holds within a render mode; hit-pause uses a real-time
  (time_scale-independent) timer, so headless vs windowed can diverge slightly.
  The replay-determinism property that the spec asks for is mode-independent and
  asserted every round.

## Asset wishes (committed assets only; worktree has no assets_raw)

- A dedicated "swing whoosh" and "dash swoosh" SFX (currently reuse
  `Sfx.play("putt")` / `"bounce"` impacts as stand-ins) and a spectral/echo
  ghost-hit sting (currently `"grudge"` bong, which fits surprisingly well).
- A ground decal / shockwave particle for swing arcs would sell the melee more
  than the current scale-pop + spark burst.
- A low ambient "chamber" music bed for the arena.
