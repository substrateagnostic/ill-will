# THE ILL WILL HIT KIT + THE COOLDOWN RING — DEAD WEIGHT & LAST WILL (verification)

Implements `docs/design/08-gamefeel-research.md` §B1 (**THE ILL WILL HIT KIT**) and
§B2 (**THE COOLDOWN RING**) in the two games the research names as the owner's #1
playtest pain — the two bare shoves that were "too slow, no weight, can't tell
direction or strength, no cooldown feedback": **`minigames/dead_weight/`** and
**`minigames/last_will/`**.

Presentation only — same damage, knockback impulses, cooldown durations, timings,
and bot behavior; proven with each game's existing deterministic harness (below).
Built ON the dead-state controls + Last Will's shove windup/arc cue already on
master (the arc cue IS the KIT's swing-arc element — extended, not duplicated).
Reuses the shared `core/cooldown_ring.gd` (`class_name CooldownRing`) exactly like
`minigames/greed/greed_player.gd` does — the house reference.

---

## What shipped

### Shared reuse: `core/cooldown_ring.gd` (already on master)
A flat, player-colored `TorusMesh` on the ground, concentric with the identity
feet-ring. Its fill is Greed's `show_grab_progress` form: scale the torus by
`clamp(1 - cd_remaining/cd_total)` — **geometry = colorblind-safe** (arc length,
never red-vs-green). Dim (~0.4× emission) while charging; on completion a
**ready-flash** (×1.6 emission for 0.15s + 1.12 scale-pop + a soft `confirm` tick);
then it **hides itself** ~0.4s after ready so a permanently-ready ability adds no
clutter. Reduced-motion keeps the ring + emission spike, drops only the scale-pop.

### DEAD WEIGHT (`minigames/dead_weight/`) — research rollout #1
| Change | Where | Note |
|---|---|---|
| **Windup coil** (`1.08/0.90` crouch → base; a landed shove adds a `0.92/1.0/1.12` forward stretch for mass) | `fighter.gd:windup_coil()` from `_do_shove()` | HIT KIT Phase 1; hitbox resolves the same frame → time-to-hit unchanged (<0.18s) |
| **Windup whoosh + readability arc** (WHEN + WHERE, front-hemisphere to `SHOVE_RANGE`, shover-colored) | `_do_shove()` → `dead_weight.gd:on_shove_fired()` | directly answers "can't tell direction"; whoosh SFX = `bounce` |
| **Victim squash-pop** (`1.22/0.85` → base 0.16s) + **spark burst** (≤14, cone along knockback, white→attacker color) | `fighter.gd:hit()` → `flash_pop()` + `dead_weight.gd:spark_at()` | one path serves BOTH shoves AND poltergeist-fling hits (both route through `hit()`) |
| **Layered thud + throttled micro-hitstop** (0.15 time_scale, 45ms, one-at-a-time 0.14s throttle) + capped shake | `dead_weight.gd:on_shove_landed()` | thud SFX = `bumper`; shake stays 0.28 (research table); reduced-motion drops hitstop+shake, keeps pop/spark |
| **SHOVE + HOP cooldown rings** (outer r0.64 / thin inner r0.53, just outside the 0.46 identity ring) | `fighter.gd` (`_shove_ring`/`_hop_ring`, driven in `_process`) | ≤2 rings/player; ability = by *position* (outer/inner), not hue |

### LAST WILL (`minigames/last_will/`) — research rollout #2
| Change | Where | Note |
|---|---|---|
| **Windup coil** (+ landed forward-stretch), reusing the existing shove arc cue | `lw_pawn.gd:windup_coil()` from `_do_shove()` | the on-master `on_shove_fired` arc IS the KIT swing-arc — kept, not duplicated; whoosh SFX = `bounce` |
| **Victim squash-pop + spark burst** | `lw_pawn.gd:hit()` → `flash_pop()` + `last_will.gd:spark_at()` | shove hits; kept under reduced-motion |
| **Layered thud + throttled micro-hitstop** (0.15/45ms, 0.14s throttle) | `last_will.gd:on_shove_landed()` | shake stays 0.26; gusts/stumbles stay soft — **NO hitstop** (per research table) |
| **SHOVE + HOP cooldown rings** (outer r0.64 / thin inner r0.53) | `lw_pawn.gd` (`_shove_ring`/`_hop_ring`, in `_process`) | ≤2 rings on the living pawn |
| **GHOST GUST cooldown ring** — the 10s recharge, "the ring that matters most" | `lw_ghost.gd` (`_cd_ring`, r0.80/0.68 at the pew feet, in `_process`) | geometric fill makes the long gust wait legible; ready-flash on completion |
| **Soft gust-contact spark** (readability only, NO hitstop/pop) | `lw_pawn.gd:gust_push()` | "ghost gust where sensible" — a gust is soft spite, so just a small spark |

### Research invariants honored
- **Total time-to-hit < 0.18s** — windups are visual scale tweens; the hitbox
  still resolves on the same tick it always did. No action was lengthened.
- **One hitstop at a time + 0.14s throttle** — each controller's `_last_hitstop`
  timestamp. Only committed, landed shoves freeze time (never whiffs, gusts,
  stumbles, or the soft boulder squish).
- **Reduced-motion (`PartySetup.pref("screen_shake")`)** — off ⇒ drop hitstop +
  shake, **keep** pop / spark / ring (information, not motion). Every ring reads
  `PartySetup.pref` and drops only its scale-pop.
- **Rings are player-colored + geometric fill**, never red/green; visible only
  while charging or freshly-ready; ready-flash per spec; ≤2 rings/player.
- **Spark cap 14**, `round(8*strength)`, `strength = clamp(power/(BASE+5·SCALE),
  0.5, 1.5)`; shake capped 0.5.

Every new visual is gated behind the controller's **`fx_on()`** (avatars call
`_visuals_on()` → `owner_game.fx_on()`), so the reproducible balance / tally sims
run **none** of it — see the determinism receipts below.

---

## Verification — gameplay numbers UNCHANGED (deterministic receipts)

### Last Will — `--willtally` byte-identical before vs after (`git stash` baseline)
`fx_on()` returns `not _tally`, so the whole HIT KIT / ring path is skipped in the
headless tally. BEFORE captured on the stashed original, AFTER on this branch:
```
                                   BEFORE (stashed)                     AFTER (this branch)
--willtally --seed=1   WILL_TALLY seed=1 rounds=3 wills=9 wpr=3.00   ==  seed=1 … wills=9 wpr=3.00
--willtally --seed=2   WILL_TALLY seed=2 rounds=3 wills=9 wpr=3.00   ==  seed=2 … wills=9 wpr=3.00
```

### Dead Weight — `--dwbalance` reproducible, headline % on the documented mark
`fx_on()` returns `_balance_rounds == 0`, so all HIT KIT / ring code is skipped in
the balance sim. **One deliberate correction in `on_shove_landed`:** the pre-existing
code ran the wall-clock hit-pause (`_time_hit`) + an rng-consuming `_shake`
*unconditionally* — including headless balance — which made the sim
**non-reproducible run-to-run** (identical seed+code gave 66.7% / 100% / 100% at
n=3). This is exactly the leak `dead_weight/VERIFY.md` "Known issues" warns about
("Balance mode disables FX so its numbers are reproducible"). Gating those FX behind
`fx_on()` — mirroring the death-FX gating already in `_on_fighter_fell` — restores
the documented invariant. Result: the sim is now reproducible AND lands on the
documented headline.
```
--dwbalance=20 --seed=1   run A: LIVING WIN 65.0%  (living-shove=5 ghost-kill=7 void=8, possessions=38 ghost_hits=70)
                          run B: LIVING WIN 65.0%  (byte-identical to run A)         ← now reproducible
--dwbalance=20 --seed=7          LIVING WIN 75.0%                                     ← inside the documented 55-75% band
```
`dead_weight/VERIFY.md` documents seed 1 = "exactly on the spec's ~65%" — this pass
reproduces **65.0%** deterministically. (Bonus: with the wall-clock pause gone from
balance, the 6× fast-forward actually holds, so the sim also runs far faster.)

### Live smoke (FX ON, all-bot, headless) — no script errors
```
--dwbots   → DW_DEATH … MINT BOOTS BLUE INTO THE VOID (player)    (shove → hit() → on_shove_landed hitstop, clean)
--willbots → LW_DEATH … RED SHOVES GOLD INTO THE DUSK             (shove kill + will + ghost-seat gust ring, clean)
```
Import pass (`godot --headless --import`) registers with no parse errors.

---

## Screenshots (windowed, committed in `docs/verify/hitkit-shots/`, `.gdignore`d)

Staged by a verify-only capture mode (`--hitkitcap`, gameplay held so the ≤0.10s
coil / pop frame is guaranteed on film; BLUE attacker + RED victim side-by-side,
victim parked for the ring shots). No effect on a normal match. Regenerate:
```
godot --path . minigames/dead_weight/dead_weight.tscn -- --hitkitcap --outdir=verify_out/hitkit
godot --path . minigames/last_will/last_will.tscn     -- --hitkitcap --outdir=verify_out/hitkit
```

**DEAD WEIGHT** (`dead_weight_hitkit_*.png`) · **LAST WILL** (`last_will_hitkit_*.png`)
- `coil` — BLUE attacker coiled in the shove windup + the player-colored directional
  arc on the ground pointing at the RED victim (the "WHERE").
- `impact` — the RED victim squash-popped wide-and-flat + the spark burst along the
  knockback (the "weight" read).
- `ring_fill` — the BLUE attacker's SHOVE (outer) + HOP (thin inner) cooldown rings
  partway, dim, at the feet.
- `ring_ready` — the SHOVE ring full + bright: the ready-flash ("you can shove again").

Note: at the anthology's wide 45° diorama camera the sparks (≤14 small particles,
by spec) and the ≤0.10s coil read as intended in motion but are small in a frozen
wide shot; the squash-pop, the ring fill/ready state, and the directional arc are
the clearest reads and are unmistakable in the stills.
