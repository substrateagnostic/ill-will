# ECHO CHAMBER — verification

Top-down arena brawl where every previous round replays as translucent,
owner-tinted ghosts. Your echoes earn YOU points when they land hits in the
present ("PAST BLUE STRIKES AGAIN"). 5 rounds, 2–4 players, seeded self-play.

Root scene: `minigames/echo_chamber/echo_chamber.tscn` (root extends
`Minigame`). Files: `echo_chamber.gd` (controller), `fighter.gd` (live
player/bot), `ghost.gd` (replay actor).

---

## v1.1 — combat triangle + ghost declutter (playtest feedback)

Three changes on top of v1, all inside the same 2-button PlayerInput budget:

**1. Real attacks + combat triangle.** Tap/hold discriminates on each button:
- **A tap → LIGHT** (`1H_Melee_Attack_Chop`): 1 dmg, fast (hitbox <50ms after
  release), 120° arc, 1.9m, 0.5s cd.
- **A hold ≥0.35s, release → HEAVY** (`2H_Melee_Attack_Slice`): 2 dmg, 150°
  arc, +0.4m reach (2.3m), big knockback (14 vs 7.5), 0.9s cd. The charge is
  **readable**: 1.06× scale + red material-overlay tint while holding, and the
  fighter is rooted (committed). Getting hit mid-charge cancels it.
- **B tap → DASH** (unchanged; i-frames the whole 0.25s burst).
- **B hold >0.15s → PARRY** (`Blocking` while held): incoming hit (live OR
  ghost swing) → 0 dmg; a **live** attacker staggers 0.6s (`Hit_A`); the
  parrier gets a **riposte** window — next LIGHT within 0.8s does +1 dmg and
  +1 point. Ghost swings are parryable (negated) but ghosts never stagger.
  Anti-turtle: 1.2s max hold, 1.0s cooldown after release.

Result: heavy beats a passive opponent; parry beats heavy (riposte punish);
fast light beats parry-spam (parry's cooldown leaves a gap). Bots exercise
every verb, so the ghosts of past rounds replay heavies/parries/ripostes.

**2. Ghost declutter (Alex's note).** A ghost no longer lingers in a death
pose or freezes at the end. The instant its recording reaches its **recorded
death** (first `ST_DEAD` sample) or its **end**, it fires a one-shot 20-shard
particle burst in its owner tint (0.5s) and despawns. The `GHOSTS: N` HUD
count visibly ticks down across a round as echoes resolve.

**3. Recorder carries the new verbs.** The per-frame `fire` byte is now
0/1/2 (none/light/heavy) and `state` carries CHARGE(8)/HEAVY(6)/PARRY(7), so
ghosts replay heavies (wide 2-dmg swing), parry stances (Blocking), and the
charge windup with the right anims — and the determinism assertion still
prints `max_err 0.000000` (ghosts report endpoint drift as they fragment).

## v1.2 — GHOST MEDDLING (doc 24 §6 / B6)

The dead get one verb. When a **human** seat is KO'd it rises as a drifting,
owner-tinted **wisp** (name + cooldown ring + "MEDDLE READY" tag) for its 2s
respawn window and may, once, press **A** to **STIR A COLD DRAFT** — a brief
0.22s spectral stagger of the LIVING within 3.2m. The estate files it:
`RED'S GHOST STIRRED A COLD DRAFT.` (`core/ghost_meddle.gd`, wired in
`_build_world` / `_tick_play` / `_on_death` / `_process_respawns` /
`_mirror_tick`).

**Mischief, not murder — safety by construction.** The draft is a *stagger*,
which adds **no velocity**, so it can never ring anyone out; and it **skips any
fighter already over the ring** (`r > RING_R`), so it never decides a death in
progress. It never touches HP or points. SIM meddle: the stagger rides the
existing fighter snapshot to mirrors — no new network messages.

**Receipt-safe by construction.** A wisp is raised **only for a non-bot seat**
(`not fighters[victim].is_bot`), so `--echobots` / standalone all-bot runs never
build one and never call `_on_ghost_meddle`. Verified byte-identical:

```
# baseline (HEAD, pre-meddle) vs wired — identical, every run:
godot --headless --path . res://minigames/echo_chamber/echo_chamber.tscn -- \
  --echobots --echofast=3 --seed=1 --echocap --outdir=verify_out
# -> ECHO_DETERMINISM round=1..5 ... max_err=0.000000 OK   (all five, identical)
# -> ECHO_MATCH_OVER champ=BLUE placements=[1, 3, 0, 2]     (identical)
```

The determinism assertions + final placements are byte-identical before/after
(the bounty-kill *line ordering* jitters ±1 run-to-run from the pre-existing
real-time hit-pause timer — see Known issues — independent of this change; the
ghost-replay `max_err` stays exactly 0).

**Live-wisp screenshot** (dev flag `--echomeddleshot`, windowed — bypasses the
human gate to photograph the actor; never a receipt path):
```
godot --path . res://minigames/echo_chamber/echo_chamber.tscn -- \
  --echobots --echofast=6 --seed=1 --echomeddleshot --outdir=verify_out
# -> verify_out/echo_meddle_wisp.png  (RED wisp: emissive orb, floating name,
#    cooldown ring, "MEDDLE READY"; the killed seat reads RED 0 on the board)
```

---

## v1.3 — TUNING PASS: visible dash cooldown + ring-out drain timer (playtest)

Friend playtest note verbatim: *"Cooldown timer on dash with a bar the player
can see. Same with the ring to show how long the player has outside the
area."* Two presentation-only additions, both reusing the house
`core/cooldown_ring.gd` component (same class `lw_ghost.gd` uses for the gust
recharge ring) — neither touches sim state, combat resolution, or bot logic.

**1. Dash cooldown ring** (`fighter.gd` `tick()`, `_dash_ring`). A ring at each
fighter's feet, owner-colored, radii 0.68/0.60 (a hair outside the identity
puck). Fires **full-size the instant you dash** and shrinks to nothing as
`DASH_CD` (1.2s) recharges, then disappears. This is the OPPOSITE fill
direction from `lw_ghost.gd`'s gust ring (which fills UP to ready): that
house idiom assumes a hollow, semi-transparent identity ring so a
still-small charging ring stays visible underneath it. Echo Chamber's
identity marker is an OPAQUE solid puck (`_ring`, a `CylinderMesh` disc, not a
torus), so a fill-up ring spends most of a short 1.2s cooldown at a radius
smaller than the puck and renders invisibly underneath it — exactly the part
of the wait that needed to read as "a bar the player can see." Draining from
full-size instead means the ring is large and clearly visible the instant you
dash (the moment it matters most) and disappears cleanly the instant the dash
is actually ready — driven directly off `_dash_cd` rather than
`CooldownRing`'s own ready-flash-then-hide FSM (which assumes the opposite
fill direction and would otherwise show/hide at the wrong ends).

**2. Ring-out drain-timer ring** (`echo_chamber.gd` `_enforce_ring()` ->
`fighter.gd` `set_ring_warning()`, `_ringout_ring`). A second, larger ring
(radii 0.82/0.74, hot orange, distinct from any owner color) that appears the
instant a live fighter crosses the yellow boundary (`RING_R`) and shrinks
from full-size to nothing over the existing `RING_WARN_T` (1.5s) grace window,
hitting empty exactly as the ring-out KO fires — a literal, geometric answer
to "how long do I have left outside." Runs alongside the pre-existing
flashing "THE RING DEMANDS" label (unchanged); the ring adds a continuous,
colorblind-safe (shape/size, not just color) countdown on top of the discrete
blink. Visibility is force-held true while the warning is active so
`CooldownRing`'s own idle-hide behavior (built for abilities that go quiet
once ready, not an active death timer) never blanks it mid-countdown.

**Verified presentation-only — zero sim impact.** Full 5-round headless soak,
same seed as the existing v1.2 receipt, is byte-identical to the value already
recorded above:
```
godot --headless --path . res://minigames/echo_chamber/echo_chamber.tscn -- \
  --echobots --echofast=3 --seed=1 --echocap --outdir=verify_out
# ECHO_DETERMINISM round=1..5 max_err=0.000000 OK   (all five, unchanged)
# ECHO_MATCH_OVER champ=BLUE placements=[1, 3, 0, 2]  (byte-identical to v1.2 receipt above)
```
No receipt values moved — this tuning pass needed no deliberate-change entry
beyond this note, since the match/determinism receipts are unchanged.

**Dash-ring logic proof** (headless trace, no display —
`CooldownRing.tick()`/`.visible` run identically headless or windowed, only
the PNG grab is display-gated): confirms full-size-on-fire -> smooth shrink
-> clean hide at ready, matching the design exactly:
```
DASH_RING_TRACE cd=0.000 vis=false scale=1.000   <- idle-ready: hidden
DASH_RING_TRACE cd=1.183 vis=true  scale=0.986   <- just dashed: ~full size
DASH_RING_TRACE cd=0.600 vis=true  scale=0.500   <- half recharged: half size
DASH_RING_TRACE cd=0.300 vis=true  scale=0.250   <- nearly ready: nearly gone
```

**Screenshots** (`verify_out/echo_tune_m3/`, seed=1):
- `echo_ringwarn.png` (`--ringtest`) — RED parked at r=7.0 (outside `RING_R`):
  "THE RING DEMANDS" flashing above a clearly visible bright-orange drain ring
  at RED's feet, mid-countdown, well outside RED's own identity puck.
- `shot_0800.png` (`--fixed-fps 60 --shots=800`) — round-1 opening scrum
  shortly after the bots' first dashes; dash rings visible at multiple
  fighters' feet (partially occluded on the Mage by that character's own
  wide-brim hat mesh from the top-down camera — a pre-existing camera/model
  interaction that affects the identity puck the same way, not a regression).

---

### v1.1 required evidence (verify_out/, windowed seed=1)

- **echo_heavy_windup.png** — a fighter mid-charge: red-tinted, scaled-up
  body (the readable heavy windup) before the 2H swing.
- **echo_parry_moment.png** — "GOLD PARRIES!" credit banner with the parrier
  in the Blocking pose while an attacker is mid-swing beside it.
- **echo_ghost_fragment.png** — a ghost's despawn burst: colored shard clouds
  in owner tint, `GHOSTS` count already dropped (declutter firing).
- **Bot parry→riposte log line** (deterministic, seed=1), a live parry that
  staggers the attacker, immediately cashed into a riposte:
  ```
  ECHO_PARRY parrier=GOLD attacker=BLUE ghost=false round=0 t=2.03
  ECHO_RIPOSTE by=GOLD victim=BLUE +1 (parry payoff)
  ```
  (ghost-swing parries also log, e.g. `ECHO_PARRY ... ghost=true`.)
- **Ghosts replay the new verbs** — the recorder's `fire` byte carries the
  swing kind (2 = heavy), so past heavies replay with the wide 2-dmg 2H arc,
  not a downgraded light. Logged the first time each round:
  ```
  ECHO_GHOST_HEAVY owner=BLUE src_round=1 (past heavy replays with 2H arc)
  ```
- **Determinism unchanged** — `ECHO_DETERMINISM round=5 ghosts=12
  max_err=0.000000 OK` (full table below), robust across seeds 1/7/42.

The three transient beats (windup/parry/fragment) are captured by state-driven
event grabs (first occurrence after a 1s warmup) that piggyback on `--echocap`,
so they land without frame-index guessing. Run **windowed**.

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
- `--echocap` — state-based screenshots at fixed game beats + v1.1 event grabs
  (first heavy windup / parry / ghost fragment after a 1s warmup); quits when
  the round-beat set is done. Run windowed.
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
- **echo_r3.png / echo_r4_full12.png** — Ghost ramp toward the cap. Ghost
  combat visible; "PAST RED STRIKES AGAIN" bounty banner firing. Note the
  `GHOSTS:` count sits below the 12 cap (e.g. 9) — v1.1 declutter: echoes that
  reached their recorded death have already fragmented and left.
- **echo_r5_dense_preshrink.png** — THE make-or-break shot. Round 5, cap 12 but
  showing ~10 live echoes (declutter thinned the resolved ones). Translucent
  owner-tinted echoes + 4 live players, still separable by opacity/texture.
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

Each ghost, the instant it reaches its recorded endpoint (death or end — see
v1.1 declutter), snaps onto that 30Hz sample and reports the drift between its
transform and the recorded position; the controller accumulates the max and
`assert()`s it under 0.01. By round end every ghost has reported (recording
length == round length). Because ghosts are driven by DIRECT transform
application (never re-simulated physics), the error is exactly 0:
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
- [x] Melee — A tap = LIGHT swing (`Chop`), 120° arc, range 1.9m, hitbox live
      0.04s after release (<50ms), knockback + 1 dmg, 0.5s cooldown.
- [x] Heavy (v1.1) — A hold ≥0.35s release = `2H_Melee_Attack_Slice`, 2 dmg,
      150° arc, +0.4m reach, big knockback, 0.9s cd, readable red-tint+scale
      windup (rooted while charging).
- [x] Parry/riposte (v1.1) — B hold >0.15s = `Blocking`; negates a hit,
      staggers live attacker 0.6s, 0.8s riposte window (+1 dmg/+1 pt on next
      light). Anti-turtle 1.2s max hold / 1.0s cd. Ghost swings parryable.
- [x] Ghost declutter (v1.1) — reaching recorded death/end → 20-shard tint
      burst + immediate despawn (no lingering).
- [x] Dash — B tap, 0.25s burst at 11 m/s, 1.2s cooldown, i-frames whole dash.
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
      Running_A / Idle / 1H_Melee_Attack_Chop / 2H_Melee_Attack_Slice /
      Blocking / Dodge_Forward / Hit_A / Death_A (all present in all 4 rigs).

## Scoring

+2 per live hit (light or heavy) · +1 riposte bonus (v1.1: a light that cashes
a parry) · +1 per credited ghost hit · +3 survival bonus (0 deaths that round).
currency: royalty +1 per ghost-hit; grudge +1 per round a player died 2+ times.

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
