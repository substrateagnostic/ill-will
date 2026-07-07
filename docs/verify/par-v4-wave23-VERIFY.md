# PAR v4 WAVES 2+3 — LIVE CHAOS GRIEFING + THE WIDOW'S WALK — VERIFICATION

Engine: Godot 4.6.2 (Windows). Commands from the worktree root. Spec:
`docs/superpowers/specs/2026-07-06-par-v4-embodied-golf-design.md` (waves 2-3),
with the owner's binding adaptation: **ball physics stay frozen — avatars
NEVER touch balls (wave-1 collision exceptions are permanent); griefing is
AVATAR-VS-AVATAR** (walk / shove with the HIT KIT / hop), and a shove that
connects with the acting golfer flinches their SHOT INPUT, never the sim.
Screenshots live in `verify_out/parv4w23/` (gitignored), windowed, read +
critiqued inline. Import pass after all edits: **zero script/parse errors**.

User-file hygiene: the realkeys receipts staged `user://party_setup.json`
(both device configs) — the ILL WILL file AND the `Par for the Curse`
migration source were backed up first and byte-restored (`cmp` clean) after.

---

## 0. What shipped

### Wave 2 — live chaos griefing (commit `b7582ab`)

- `scripts/grief_controller.gd` (new) — in the CHAOS round the non-stroking
  avatars go live. Direct control for kb halves / KB+MOUSE / pads via
  `PlayerInput.get_move` + a/b; `-3` mouse seats auto-grief via a seeded
  seek-bot (spec OQ1 default) while their own shots keep mouse aim. Bots run
  the same seek-bot: chase the shooter, shove in reach, hop walls/when stuck,
  trigger nearby powered traps — every draw from a dedicated seeded rng.
- **Verbs (2-button budget):** A = SHOVE — full HIT KIT per
  `docs/design/08-gamefeel-research.md` (0.08s windup coil, throttled 45 ms
  hitstop at 0.15 scale — skipped headless, victim 1.22/0.85 pop, attacker
  lunge-stretch, ≤10 sparks white→attacker color, layered thud, shake 0.28,
  knockback 5.2 m/s + up-pop on the VICTIM AVATAR). B = HOP (7 m/s vertical,
  clears the 0.51 m course walls onto the aprons) or, standing at a powered
  trap, TRIGGER it early.
- **Flinch (the mid-swing grief):** `avatar_shot.flinch()` — shove connecting
  with the acting golfer: ADDRESS → 0.45 s stagger (Hit_A, no stroke lost,
  bot think clock resets); CHARGE → the shot fires NOW at current meter power
  with a 13° deflection toward the push; SWING pre-contact → contact fires
  with the deflected angle. **Only the (power, angle) INPUT to the one frozen
  `debug_putt` changes.** 1.2 s flinch immunity so shoves can't chain-stun.
- **Trap grief-trigger** (`Trap.grief_trigger()`, timing/state only — the
  kill rule `kill_ball` on ball contact is untouched): crusher snaps to the
  slam, fan fires one capped gust (dv 1.0 m/s on balls already in the zone),
  bumper kicks its sensor now, windmill lurches a quarter-turn. 2.0 s
  cooldown per trap; proximity = footprint radius + 1.0 m.
- **Anti-frustration (spec, non-negotiable):** cup-exclusion disc (radius =
  `cup_no_build_radius`) with soft radial pushback that outpaces the run
  speed; shove cd 0.8 s / hop cd 0.9 s; flinch immunity; pit-respawn at a
  grounded spot from ≥20 ticks back.
- **Grudge, not points:** a shove/trigger that directly precedes a death or
  DNF (≤300 ticks) logs `{type:"grudge", player:griefer, reason:"griefed X"}`
  + a "GRIEFER GRIEFED VICTIM" highlight + +1 grudge, zero score. Royalties/
  kill_events flow unchanged to the trap author. Chasm shoves get their own
  highlight ("X SHOVED Y INTO THE CHASM", 3 s throttle).
- **Dead still walk (chaos flavor):** after the ball-death drama the avatar
  stands back up (1.6 s) and keeps griefing; its ball stays dead.
- **Wave-2 exit criterion — tick-locked bots:** the bot driver moved from
  `_process` wall-clock to `_physics_process` (fixed 1/60); the between-round
  gap is a physics-time timer (exactly 180 ticks); the gutter sweep tween
  runs on the physics clock. Grief rng is separate and seeded
  (`GameState.rng.seed ^ 0x51EF6E55`) so the layers never correlate.
- Gates: griefing runs only when embodied + chaos + not under the trace
  harness (autoplay/autobuild/physputt), mirroring the killcam determinism
  guard; `--nogrief` forces it off. `--griefprobe=verb,tick[,...]` injects
  deterministic shove/cup/trigger/hop actions for receipts.
- **Realkeys retrofit** (per `docs/verify/realkeys-VERIFY.md` template):
  per-seat PUTT bar with the seat's LIVE verbs (mouse seats show mouse verbs)
  + merged chaos GRIEF bar (`_human_seats`/`_btn_hint` helpers; hidden in
  all-bot demos so receipts stay byte-identical).

### Wave 3 — bigger courses + THE WIDOW'S WALK (commit `e84199c`)

| Course | change | camera |
|---|---|---|
| fairway | ×1.4 → 8×29 lane, hop-over 1.5 m walk APRONS outside both walls, banks/cup/tees rescaled, per-tee no-build intact | y 20, fov 58 |
| dogleg | ×1.4 (legs 9.5/16.2), elbow cut-corner walk deck (own muted material) | y 21, fov 62 |
| green | → 16×16 plaza, humps/tees rescaled | y 26, fov 62 |
| the_gauntlet | footprint kept + gutters kept; raised catwalk skirting the north wall (griefer highway) | y 19 |
| **widows_walk** (NEW) | 9×30 three-tier spine: tee meadow + mausoleum monument; 3 m CHASM (2.5 m buildable land bridge; gutter channels deliver near-not-at the green at (0,-11.8); avatars pit-fall & respawn); switchback around monument B; ELEVATED green +0.3 ringed by a knee-high wall, funnel-banked 3 m ramp mouth; continuous catwalks down both flanks | (0,24,11), fov 62 |

- Geometry interface: `green_rects` (rest-legal, never buildable — the raised
  green keeps the y=0 trap-placement contract intact), `walk_rects`
  (declarative walk furniture); `placement_controller` validity now checks
  `is_point_buildable` (play_rects only — flat courses byte-identical).
- `Course.cup_height()` + an elevation-aware bot power heuristic in
  `_bot_putt` (`+ sqrt(2g·climb)·1.25`, same rng draw count) so bots can buy
  the ramp climb. Pure bot heuristic; sim untouched.
- `"widows_walk"` in `GameState.COURSE_IDS` — same random per-match draw and
  `--course=` gate as the original four.
- Grief seek-bot anti-lemming: after a pit fall the bot wanders near its
  respawn anchor for 6 s instead of marching back over the lip (widow's walk
  seed 13 full match: **1 pit** — a shove, the intended highlight — where the
  pre-fix build looped dozens).

## 1. FROZEN BALL PHYSICS — byte-identical receipts (make-or-break)

Method as wave 1: `--traceall` PTRACE (every ball, every physics tick, 0.1 mm)
dedupe per ball, byte-diff. All runs `--fixed-fps 60` (locks the loop 1:1 with
physics; also what makes full-match logs byte-reproducible — see §2).

| # | Setup | sides | verdict |
|---|---|---|---|
| W2-R1 | old fairway, seed 11, `--players=2 --rounds=1 --autoplay="6:-10,6:10"` (wave-2 code live) | `--v3putt` vs `--swingplay` | **both balls byte-identical** (268/211 samples) |
| W3-R1 | **scaled** fairway, same command | `--v3putt` vs `--swingplay` | **both balls byte-identical** (267/268 samples) |
| W3-AA | widows_walk seed 4 `--autoplay="9:-2,9:2" --swingplay`, run twice | A/A | **identical** (301/157 samples; chasm gutter in path) |
| W3-R2 | widows_walk, swing run logged `SWING_FIRE phys=71/217`; v3 run fired `--physputt=9,-2,71,9,2,217` at those exact ticks | tick-aligned v3 vs swing | **both balls byte-identical** — ball 0 crosses the chasm gutter both times |

(The non-tick-aligned widows cross-path run diverges at sample 126 — the two
CHAOS strokes fire at different absolute ticks, so the two live balls interact
differently. Same course-state effect wave 1 documented as R3/R3b; when the
stroke enters the sim on the same tick with the same numbers, the roll is
identical to 0.1 mm. **The griefing layer does not leak into the sim** — and
under the trace harness griefing is gated off entirely, on both sides.)

## 2. WAVE-2 EXIT — same-seed chaos/matches reproducible run-to-run

Event lines compared: `MATCH_OVER|FINAL_RESULT|KILL_EVENTS|DEATH|BALL_SUNK|
GRIEF_*|SWING_FIRE|GUTTER` — i.e. every stroke (with power/angle/tick), every
grief action, every death and outcome.

```
godot --headless --fixed-fps 60 --path . -- --skipmenu --course=<c> --seed=<s> \
      --players=4 --rounds=4 --parbots --parquit --quitafter=200000   (x2, diff)
```

| course | seed | verdict |
|---|---|---|
| fairway (old geometry, wave-2 receipt) | 5 | **328 event lines byte-identical, absolute ticks included** |
| fairway (scaled, post-wave-3) | 5 | **168 lines byte-identical** |
| widows_walk | 13 | **231 lines byte-identical** |
| fairway chaos-only (`--rounds=1`) | 7 | **FINAL_RESULT identical** (first receipt, realtime headless) |

Verb coverage inside the widows seed-13 match: 179→ shoves (fairway w2 run),
19 hops, 8 grief-triggers, grief credits present (4 in the fairway w2 run).
Every grief verb fires and reproduces.

Caveat (documented, pre-existing engine behavior): wall-clock headless runs
without `--fixed-fps` can burst multiple physics ticks per iteration, which
shifts deferred-call flushes (ball death/reset bookkeeping) by a tick and can
drift outcomes. `--fixed-fps 60` (1 tick : 1 frame, the receipt harness) is
byte-stable end to end; windowed play at a healthy 60 fps has the same 1:1
shape. Bot cadence itself no longer depends on frame rate at all.

## 3. Live-grief receipts (headless logs)

- **Flinches:** `GRIEF_SHOVE by=1 victim=0 flinch=stagger`, `flinch=deflect`,
  `flinch=fired` all present across runs; staggered bots visibly delay
  (is_addressed false → think clock resets) then swing.
- **Cup-camp prevention** (spec row): `--griefprobe=cup,700` steers a griefer
  INTO the cup disc for 10 s —
  `GRIEFPROBE_CUP p=1 min_d=1.24 exclude_r=1.30` on green **and** on the
  widows_walk elevated green (identical numbers). Natural-play pushes also
  logged (`GRIEF_CUP_PUSH p=1 d=1.26 r=1.30`). No cup camping possible.
- **Grudge ledger:** `GRIEF_CREDIT by=3 victim=1` + currency_events
  `{type:"grudge", reason:"griefed ..."}` + "X GRIEFED Y" highlight/banner;
  royalties/kill_events unchanged (KILL_EVENTS attribute the trap author).
- **Chasm:** `GRIEF_PIT p=2 by=3` → "MINT SHOVED GOLD INTO THE CHASM"
  highlight path; walked-in falls get the dry register. 1 pit per flagship
  match post-anti-lemming.

## 4. Screenshots (windowed, read + critiqued by eye — `verify_out/parv4w23/`)

| file | what I saw |
|---|---|
| `green_chaos/snap_brawl_0499.png` (+crop) | chaos on the 16×16 green: a 4-avatar scrum piled at the tee corner (identity rings read), one ball rolling mid-lane with the aim arrow, second ball right of the pile — "brawling while balls roll" |
| `green_chaos/snap_griefshove_0396.png` (+crop) | griefer mid-punch on the addressing golfer (paired log line `flinch=stagger`) — the mid-swing shove connecting |
| `ww_chaos2/snap_brawl_0518.png` | golden-hour chaos on the flagship: scrum at the tee meadow, chasm + bridge reading mid-spine, catwalks flanking |
| `ww_chaos/shot_1500.png` | widow's walk chaos overview: both chasm gaps + land bridge, funnel ramp + ring + flag at top, stroke counter live |
| `ww_normal/snap_address_0517.png` | SMITE skill-shot frame from the tee meadow: lane + placed traps + chasm gap readable in one glance; four avatars at the tees |
| `ww_normal/shot_2400.png` | daylight mid-match: GOLD mid-walk to a mid-course lie, crusher + traps live, chasm behind — the embodied walk at flagship scale |
| `fairway/snap_address_0516.png` | scaled 8×29 fairway from the tee: whole lane + both banks + cup in frame, walk aprons flanking outside the walls; glare fix intact (overcast-bright green) |
| `fairway/snap_walk_2155.png` | RED mid-stride down the big lane, camera tracking — walk reads at the new length |
| `dogleg/shot_0040.png` | scaled L framed whole at y 21; elbow walk deck present (muted after material fix), cup + bank read |
| `the_gauntlet/shot_0040.png` | gauntlet with the raised north catwalk skirting the wall; gutters intact |
| `bars_kb/shot_1100.png` | PUTT bar, kb-left seat: `AIM: W/A/S/D · HOLD Space TO CHARGE — RELEASE TO SWING` in RED's color while RED addresses |
| `bars_mouse/shot_1100.png` | PUTT bar, mouse seat: `AIM: MOUSE · HOLD LMB TO CHARGE — RELEASE TO SWING` — the tester's real-keys ask |
| `bars_grief_kb/shot_0400.png` | chaos GRIEF bar, mixed kb seats: `GRIEF: MOVE · SHOVE: Space/RED · Enter/BLUE · HOP / TRIGGER TRAP: E/RED · Shift/BLUE` |
| `bars_grief_mouse/shot_0400.png` | chaos GRIEF bar, lone mouse human: `MOUSE SEAT GRIEFS ON AUTO — YOUR SHOT IS STILL YOURS` |
| `killcam/snap_killcam_signed_0185.png` | killcam regression: full-cap replay (`KILLCAM done held_ms=1677`), snap taken while the table held |

Critique kept honest: chaos stays in the DIORAMA (by design — overlap must
read), so brawl figures are small at course scale; the crops confirm poses.
The first capture pass fired snaps under the round-intro banner — snap gating
now waits 6-8 s so frames read.

## 5. Regression — full matches, five courses

`--parbots --parquit --fixed-fps 60`, headless; err = grep of
`SCRIPT ERROR|Invalid call|null instance|: Nil`:

| course | seed | result |
|---|---|---|
| fairway | 5 | `MATCH_OVER champ=MINT`, err=0 |
| fairway | 9 | `MATCH_OVER champ=BLUE`, err=0 |
| dogleg | 6 | `MATCH_OVER champ=RED`, err=0 |
| dogleg | 11 | `MATCH_OVER champ=MINT`, err=0 |
| widows_walk | 6 | `MATCH_OVER champ=BLUE`, err=0 — 7 sinks, 6 gutter deliveries |
| widows_walk | 13 | `MATCH_OVER champ=BLUE`, err=0 |
| green | 6 | `MATCH_OVER champ=RED`, err=0 |
| the_gauntlet | 6 | `MATCH_OVER champ=BLUE`, err=0 — gutters alive |

Per-tee no-build survives the scaling (round-2 guard): `--placetest
--forcetrap=crusher` on the scaled fairway — `PLACETEST tee-probe at
(-1.50,0.15,1.60) valid=false` (a crusher parked ON relocated tee 0 is
illegal).

`finished(results)` shape unchanged (placements/points/currency_events/
kill_events/highlights/monuments). Estate boot smoke (`--estate
--quitafter=400`): **0 script errors**. Killcam signed test: full-cap replay +
auto-unpause. Import pass: clean.

## 6. Frozen-invariants checklist

- [x] `Ball.putt`, `STOP_SPEED`, `MAX_SPEED`, damping, low-speed brake,
      cup `MAGNET_*`, drag constants — untouched (zero edits to ball.gd /
      putt_controller physics).
- [x] Avatars NEVER touch balls: collision exceptions permanent; brawl mode
      only adds avatar↔avatar (layer 2) contacts.
- [x] Every shot — human swing, flinched swing, bot swing, autoplay,
      physputt — still resolves through the one `debug_putt` entry point.
- [x] Trap kill rule unchanged: `grief_trigger()` mutates timing/state only.
- [x] DRAFT/BUILD, placement seat gate, per-tee no-build, `TRAPS_PER_BUILD=1`
      — untouched; buildable check tightened to play_rects only (flat courses
      byte-identical by construction).
- [x] Killcam, chaos banner, gutters, gravestones, royalties, badges — alive
      in the receipts above.
- [x] Griefing gated out of every trace-harness path + `--nogrief` +
      `--v3putt`; harness flags all inert without CLI args.

## 7. Known limits / notes

- Human grief-device feel (pads/kb halves shoving, hop-onto-catwalk routes)
  needs Alex's hands — same caveat as every wave (no harness injects real
  device state).
- Chaos brawls read at diorama scale; if the owner wants hero-shots of
  shoves, a chaos kill-style punch-in cam would be a v5 polish item.
- Bots DNF more on widows_walk than flat courses by design (chasm +
  ring-wall green); seeds 6/13 still sink 5-7 balls a match. The funnel
  banks + climb heuristic are what made the flagship bot-solvable.
- Club prop (spec OQ3) not shipped — bare 2H swing still sells it.
- `--fixed-fps 60` is the reproducibility harness; realtime headless without
  it can micro-drift via engine physics-step bursting (documented in §2).
