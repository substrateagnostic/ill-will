# PAR — OUTSIDE TESTER ROUND 2 — THREE BUGS, THREE ROOT CAUSES, RECEIPTS

Engine: Godot 4.6.2 (Windows). Commands run from the worktree root. Import pass
after all edits: zero script/parse errors (`godot --headless --editor --import
--quit --path .`; only the pre-existing cosmetics `*_0.jpg` import warnings
remain — outside this lane). Screenshots live in `verify_out/parr2_*`
(gitignored) and were read + critiqued inline, windowed. Par ball/putt physics
FROZEN — zero edits to ball.gd / putt_controller.gd / any sim constant.

User-file hygiene: receipts that needed bot-free seats temporarily removed
`user://party_setup.json` — AND its migration source in
`app_userdata/Par for the Curse/` (see Finding 0) — both backed up first and
byte-restored after the runs.

---

## Finding 0 (met while reproducing): bot seats resurrect themselves

`core/migrate.gd` (autoload, loads FIRST) re-copies `party_setup.json` from the
old `app_userdata/Par for the Curse/` dir whenever the `ILL WILL` copy is
missing. Deleting the ILL WILL file does NOT give a bot-free boot — the stale
config (seats 1-3 = bots, the owner's real couch setup) reappears every run.
Not a bug (it is the rename migration working as designed), but it is why every
"clean" reproduction still had bots, and it is exactly the seat layout the
tester played: one human + three bots. No code change; documented for the next
agent who needs bot-free receipts.

## Bug 1 — "Lighting on tee off is too bright — hurting my eyes"

**Root cause.** The PAR v4 SHOT camera (SMITE frame, ~53 deg down from 11.5 m)
fills ~70% of the frame with the sunlit striped green plus the near-white wall
caps. Same materials/sun/tonemap as v3 — but the v3 diorama frames the course
small, far, and surrounded by dark table; the new SHOT pose is wall-to-wall
high-luminance saturated green. Composition, not a lighting regression — so the
fix must be scoped to the SHOT frame.

**Fix.** `scripts/camera_rig.gd`: `SHOT_EXPOSURE := 0.58` — `set_mode()` tweens
`cam.attributes.exposure_multiplier` to 0.58 entering SHOT and back to 1.0
entering DIORAMA, over the existing camera blend times (no pop). Presentation
only; DIORAMA untouched; UI (CanvasLayer) unaffected by 3D exposure.

**Receipts** (windowed, fairway seed 12, `--parbots --swingsnap --shots=240`):

| frame | before | after | read |
|---|---|---|---|
| SHOT address (green patch mean, sRGB) | (144, 219, 119) | (119, 181, 92) | overcast-bright; stripes, aim ring, traps, cup all still read |
| SHOT address (same mid-lane pixel) | (151, 224, 125) | (124, 186, 96) | peak green off the "snow-blind" band |
| DIORAMA build view (`shot_0240.png`, green patch) | (156, 213, 132) | (156, 213, 132) | **byte-identical** — build view untouched |
| post-contact diorama (`snap_diorama`) | — | stock v3 brightness | exposure tweens back to 1.0 on handoff |

Eyeballed both address frames side by side: after reads like cloudy-bright, not
muddy — colors keep identity, the cyan trap pad and pink rings still pop.
Files: `verify_out/parr2_before/` vs `verify_out/parr2_after2/`.

## Bug 2 — "Click fast enough and you can steal the bot's traps"

**Root cause.** `placement_controller._unhandled_input` gated only on
`active and ghost != null` — never on WHO owns the build turn. During a bot's
BUILD turn (ghost live while the bot "thinks" for 1.0 s) the shared mouse could
move, rotate, and CONFIRM the bot's ghost. The draft cards had the same hole:
buttons stayed clickable during a bot's DRAFT turn.

**Fix.**
- `scripts/placement_controller.gd`: new `human_input` flag, set per placement
  by `begin(..., allow_mouse)`; `_unhandled_input` returns when false. Bots
  place exclusively through `debug_place_scan` (unchanged code path).
- `scripts/main.gd`: `_on_card_picked` passes `not _is_bot(p)`;
  `_begin_draft_turn` sets `btn.disabled = _is_bot(p)` (bots pick via
  `debug_pick_card`, which bypasses the buttons).
- Hotseat semantics preserved: on any HUMAN's turn the mouse is the current
  builder's — human-vs-human couch play is byte-identical to before.

**Receipts** — new inert `--stealtest` flag (`scripts/verify_capture.gd`):
waits for the first BUILD turn (a bot's, under `--parbots`), injects a
synthetic mouse motion + left click at a screen point unprojected over a legal
build spot, and logs the ghost/board state. Windowed, fairway seed 5, 4 seats:

PRE-FIX (theft, reproduced):
```
STEALTEST build turn open | ghost_at=(0.00,0.00,-8.25) placed_traps=0
STEALTEST after synthetic MOUSE MOTION | ghost_at=(0.00,0.00,-6.25) ghost_alive=true
STEALTEST after synthetic CLICK | placed_traps=1 ghost_alive=false
STEALTEST placed trap spikes author=3 at (0.00,0.00,-6.25)
```
The "human" mouse dragged the BOT's ghost 2 m and planted it ~55 frames before
the bot's own think fired.

POST-FIX (same seed, same screen point, same camera):
```
STEALTEST after synthetic MOUSE MOTION | ghost_at=(0.00,0.00,-8.25) ghost_alive=true
STEALTEST after synthetic CLICK | placed_traps=0 ghost_alive=true
STEALTEST bot-liveness | placed_traps=2
STEALTEST placed trap spikes author=3 at (-2.42,0.00,-12.07)
STEALTEST placed trap boost_pad author=2 at (-2.04,0.00,-14.77)
```
Synthetic input changes NOTHING; 240 frames later the bots have completed their
own placements through their own path.

## Bug 3 — Crusher "pad/hammer don't follow the ghost" + crusher on the tee

**Investigated with the `--placetest` harness first** (crusher card forced,
bot-free seats, headless + windowed):

```
PLACETEST drag t=0.25 | root=(0.38,0.00,-3.75) Pad=(0.38,0.02,-3.75) Hammer=(0.38,1.50,-3.75) Model=(0.38,1.50,-3.75)
PLACETEST drag t=0.50 | root=(0.75,0.00,-5.50) Pad=(0.75,0.02,-5.50) Hammer=(0.75,0.31,-5.50) Model=(0.75,0.31,-5.50)
PLACETEST drag t=0.75 | root=(1.13,0.00,-7.25) Pad=(1.13,0.02,-7.25) Hammer=(1.13,1.00,-7.25) Model=(1.13,1.00,-7.25)
PLACETEST drag t=1.00 | root=(1.50,0.00,-9.00) Pad=(1.50,0.02,-9.00) Hammer=(1.50,1.50,-9.00) Model=(1.50,1.50,-9.00)
PLACETEST confirmed
PLACETEST 1s after confirm | root=(1.50,0.00,-9.00) Pad=(1.50,0.02,-9.00) Hammer=(1.49,0.48,-8.96) Model=(1.49,0.48,-8.96)
```

Pad, Hammer (mid-slam y values are the animation), and the Meshy head track the
root at every sample; the placetest now also snaps windowed frames at each
report (`verify_out/parr2_place/snap_placetest_090/135.png`, read: ghost pad +
hammer + validity disc travel together up the lane mid-drag). **The ghost
structure is sound — the "stuck pad/hammer" is not a transform bug.**

**Actual root causes, both fixed:**

1. **The bot-confirm race (= Bug 2).** On a bot's build turn the owner's mouse
   was really driving the bot's ghost; when the bot's 1.0 s think fired, its
   `debug_place_scan` CONFIRMED the trap at a scan point (reproduced live: the
   placetest drag was repeatedly hijack-confirmed at a random spot by the bot
   seat before the fix). To the player: the crusher freezes at a spot they
   never chose "near the draft/spawn area", while the validity disc under
   their cursor keeps moving — it belongs to the NEXT bot's freshly spawned
   ghost. Bug 2's seat gate removes the interleave entirely.
2. **Tee exclusion had a hole.** `course.no_build_zones()` protected the tees
   with ONE disc at the tee CENTROID (r 1.5). With tees spread ±1.2 m, a trap
   could legally park ~0.73 m from an outer tee ball — a crusher there visually
   sits ON the tee pad strip and menaces the spawn. Fix in `scripts/course.gd`:
   one no-build disc PER TEE (same radius) in addition to the centroid disc
   (whose coverage is not a strict subset of the union). Applies to humans and
   bots alike — both funnel through `_check_valid`.

**Tee receipt** — the placetest now probes tee 0 before the drag:
```
PLACETEST tee-probe at (-1.20,0.15,1.60) valid=false
```
A crusher ghost parked ON a tee reads INVALID (pre-fix this exact probe point
was legal for the scan on wide courses).

Note: the 1s-after-confirm sample shows the solidified hammer a few cm off the
root mid-slam — that is the stock `AnimatableBody3D sync_to_physics` tick
interpolation every powered trap has had since v2 (windmill/moving wall too),
visible only while the hammer is in flight. Pre-existing, cosmetic, physics —
not touched.

## Regression guard (frozen physics, harness, full match)

- Zero edits to ball/putt code or constants; camera exposure + input gating +
  no-build zones are presentation/validity only.
- `--autobuild --autoplay --tracepos` (fairway seed 7, rounds 2, headless):
  drafts/builds/putts all fire, `VERIFY_DONE`, **0 script errors**.
- Full 4-bot match (fairway seed 5, `--parbots --parquit`, headless):
  `MATCH_OVER champ=MINT`, `FINAL_RESULT placements=[3, 2, 0, 1] points={ 0: 2,
  1: 0, 2: 5, 3: 7 }`, kill events attributed, `CHAOS_CONCURRENT_PEAK movers=3`
  — chaos overlap alive. **0 script errors.**
- Estate boot smoke (`--estate --quitafter=400`): **0 script errors** (the
  verify_capture additions are inert without their flags).
- Known, disclosed: per-tee no-build zones change which SCAN points are legal,
  so bot trap LAYOUTS for a given seed differ from pre-fix runs (draw-count
  shift). Determinism per seed is intact; no putt-physics receipt is affected.

## New harness surface (all inert without flags)

- `--stealtest` — synthetic-input theft receipt (above).
- `--placetest` upgrades: tee-0 validity probe before the drag; windowed runs
  snap a frame at each drag report.
