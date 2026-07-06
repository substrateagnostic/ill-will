# THE ILL WILL HIT KIT + THE COOLDOWN RING — GREED & THRONE (verification)

Implements `docs/design/08-gamefeel-research.md` §B1 (**THE ILL WILL HIT KIT**) and
§B2 (**THE COOLDOWN RING**) in the two games the research names as owner-pain
targets that this pass owns: **`minigames/greed/`** and **`minigames/throne/`**.
Presentation only — same damage, knockback impulses, cooldown durations, and bot
behaviour; proven with each game's existing deterministic harness (below).

Dead Weight and Last Will (also on the research's rollout list) are **untouched** —
owned by another agent.

---

## What shipped

### Shared: `core/cooldown_ring.gd` (`class_name CooldownRing`)
The house cooldown ring, factored once and reused by both games. A flat,
player-colored `TorusMesh` on the ground, concentric with the identity feet-ring.
It **copies Greed's `show_grab_progress` fill form** (the research's named house
reference, `greed_player.gd:297`): the torus scales by the fill fraction
`clamp(1 - cd_remaining/cd_total)` — **geometry = colorblind-safe** (arc length,
never red-vs-green). Dim (~0.4× emission) while charging; on completion a
**ready-flash** (×1.6 emission for 0.15s + 1.12 scale-pop + a soft `confirm` tick);
then it **hides itself** ~0.4s after ready so a permanently-ready ability adds no
clutter. Reduced-motion keeps the ring + emission spike, drops only the scale-pop.

### GREED (`minigames/greed/`) — research fix #2
| Change | Where | Note |
|---|---|---|
| **Hitstop softened `0.05 → 0.15` time_scale** (45ms), reduced-motion gated | `greed.gd:_hit_pause()` | the 0.05 freeze on every tackle read as a lurch, not impact |
| **Tackle windup coil** (`1.08/0.90` crouch → spring back) | `greed_player.gd:do_tackle_swing()` → `windup_coil()` | HIT KIT Phase 1; time-to-hit unchanged |
| **Victim squash-pop** (`1.22/0.85` → base over 0.16s) | `greed_player.gd:flash_pop()`, fired from `greed.gd:_drop_carrier()` | copy of echo `_flash_pop` |
| **Spark burst** (≤14, cone along knockback, white→attacker color) | `greed.gd:_spark_burst()` from `_drop_carrier()` | kept under reduced-motion |
| **Dash cooldown ring** off `dash_cd`/`DASH_CD` | `greed_player.gd` (`_dash_ring`, driven in `tick_visual`) | outer r 0.70 / inner 0.60, just outside the 0.58 identity ring |
| Tackle-drop **shake** now reduced-motion gated | `greed.gd:_drop_carrier()` | drops with hitstop under reduced-motion |

### THRONE (`minigames/throne/`) — research fix #3
| Change | Where | Note |
|---|---|---|
| **King-shove / grip-drain reads as a real hit**: king squash-pop + spark + throttled micro-hitstop (0.15/45ms) + scaled shake | `throne.gd:on_king_shoved()` (+ `royal.gd:flash_pop()`) | hitstop only on a **non-final** drain (the final one keeps the big dethrone slow-mo beat); one hitstop at a time, 0.14s throttle; hitstop+shake reduced-motion gated |
| **Standard shove windup coil** | `royal.gd:_do_shove()` → `windup_coil()` | fires on the shove action; hitbox still resolves same-frame |
| **Victim squash-pop + spark** on landed challenger shoves; pop on decree-blast victims | `royal.gd:take_shove()` / `apply_blast()` | decree keeps its own shockwave for the "spark" read (avoids 3× spark clutter) |
| **DECREE + GUARD cooldown rings** at the king's feet | `throne.gd` (`_decree_ring` outer, `_guard_ring` thin inner, driven in `_update_cd_rings`) | both had cooldowns with **zero display**; ≤2 rings/player; ability = by *position*, not hue |

Every new Throne visual is gated behind the controller's `_fx` flag (`royal.gd`
checks `owner_game.fx_on()`), so the reproducible `--thronebalancefast` sim runs
**none** of it — see the byte-identical receipt below.

### Research invariants honored
- **Total time-to-hit < 0.18s** — windups (coil tweens) are visual; the hitbox
  still resolves on the same tick it always did. No action was lengthened.
- **One hitstop at a time + 0.14s throttle** — Greed's `_slowmo` guard; Throne's
  `_last_hitstop` timestamp. Only committed, landed hits freeze time (never
  whiffs, soft pushes, or clashes).
- **Reduced-motion (`PartySetup.pref("screen_shake")`)** — off ⇒ drop hitstop +
  shake, **keep** pop / spark / ring. Verified live (below).
- **Rings are player-colored + geometric fill**, never red/green; visible only
  while charging or freshly-ready; ready-flash per spec.
- **Spark cap 14**, `round(8*strength)`; shake capped 0.5 on normal hits.

---

## Verification — gameplay numbers UNCHANGED (deterministic receipts)

**Greed** — `--greedtest=intercept` (a closed-form kinematic model of the chase;
does not run players/FX). AFTER these changes it reproduces the committed
`minigames/greed/VERIFY.md` baseline **exactly**:
```
seed=1  trials=80 catches=64 rate=0.80 PASS
seed=4  trials=80 catches=54 rate=0.68 PASS
seed=9  trials=80 catches=58 rate=0.72 PASS
```

**Throne** — `--thronebalancefast` (`_fx=false`, so all HIT KIT / ring code is
skipped). Same seed **before vs after**, byte-identical:
```
                        BEFORE (HEAD)          AFTER (this branch)
--thronescale=8 --matchtime=40 --seed=1  max_share=42.6% PASS    42.6% PASS
                            --seed=2  max_share=44.3% PASS    44.3% PASS
                            --seed=3  max_share=34.8% PASS    34.8% PASS
```
(BEFORE captured via `git stash -u` → run → `git stash pop`.)

**Throne FX-ON** — the only physics-touching addition in a real match is the
king-shove micro-hitstop. The FX-on fairness probe still clears the 55% cap
comfortably (exercises HIT KIT + rings end-to-end, no errors):
```
--thronebalance --matchtime=45 --seed=1  max_share=28.1% PASS
                            --seed=2  max_share=35.9% PASS
                            --seed=3  max_share=33.2% PASS
```

**Full-match smoke** — Greed all-bot match (`--greedbots --seed=3`) plays a real
tackle drop through the HIT KIT path; `kill_events` / results contract intact,
zero script errors. Import pass (`--headless --editor --import --quit`) registers
`CooldownRing` with no parse errors.

## Verification — reduced-motion (`prefs.json {"screen_shake": false}`, backed up + restored)
- Throne capture + Greed all-bot match both run clean; a tackle drop / king-shove
  still fire. `throne_hitkit_impact` under reduced-motion still shows the **king
  squash + spark** (hitstop + shake suppressed) — pop/spark/ring are kept as the
  spec requires.

---

## Screenshots (windowed, committed in `docs/verify/hitkit-shots/`, `.gdignore`d)

Staged deterministically by a verify-only capture mode (`--hitkitcap`, gameplay
frozen so the 0.05s coil / flash frame is guaranteed on film; no effect on a
normal match). Regenerate:
```
godot --path . res://minigames/greed/greed.tscn -- --greedbots --seed=3 --hitkitcap --outdir=verify_out/hitkit
godot --path . minigames/throne/throne.tscn    --            --seed=2 --hitkitcap --outdir=verify_out/hitkit
```

**GREED** (`greed_hitkit_*.png`)
- `coil` — the RED attacker mid tackle-windup (coil crouch + punch pose).
- `impact` — the BLUE victim squash-popped wide/flat + spark cone along the knockback.
- `ring_fill` — RED dash cooldown ring half-filled at the attacker's feet (dim).
- `ring_ready` — same ring full + bright: the ready-flash.

**THRONE** (`throne_hitkit_*.png`)
- `coil` — RED challenger coiled in the shove windup; the crowned BLUE king behind.
- `impact` — the BLUE king squash-popped (grip-drain) + spark, reign-stream hidden for clarity.
- `rings_fill` — BLUE DECREE (outer) + GUARD (inner) rings partway, dim, at the king's feet.
- `ring_ready` — the DECREE ring full + bright: the ready-flash.

Note: at the anthology's wide 45° diorama camera the sparks (≤14 small particles,
by spec) and the ≤0.10s coil read as intended in motion but are small in a frozen
wide shot; the squash-pop, the ring fill state, and the ready-flash are the
clearest reads and are unmistakable in the stills above.
