# 08 — Game-Feel Research: Melee Weight & Cooldown Feedback

Date: 2026-07-05. Engine: Godot 4.6.2. Author: research agent.
Trigger: owner playtest note — *"shoves are too slow, lack weight, don't read as
attacks (no direction, no strength, no impact), and cooldown-gated actions give
no cooldown feedback. Colored circles might be best."*

This doc is **docs-only**. It touches no code. It delivers:
- **(A)** a ranked, cited technique stack for readable top-down melee;
- **(B)** the house standard — **THE ILL WILL HIT KIT** and **THE COOLDOWN RING**,
  specced tight enough for any build agent to implement;
- **(C)** a per-game prescription table (6 contact games, file:line);
- **(D)** explicit anti-goals.

---

## 0. Our camera, our characters, our existing infra (constraints that set the numbers)

Everything below is tuned to **what our games actually are**, not generic advice.

**Camera.** Dead Weight sets `cam.global_position = (0, 13.5, 11.5)` looking at
`(0, 0.3, -0.4)`, `fov = 52` (`dead_weight.gd:114-116`). That is a **perspective
camera ~45-48° above the ground plane** — the whole anthology sits in this
"warm chunky diorama" band (`docs/design/07-visual-polish-audit.md`). Consequences:
- The **ground under each character is on-camera and readable** → world-anchored
  rings work (they already carry player identity — every contact game draws a
  color-emissive feet ring). This is why the owner's instinct ("colored circles")
  is correct.
- **Vertical** motion (a knockback pop, a squash) reads well; a body launched up
  and back is legible from 45°.
- **Translational** screenshake (`cam.h_offset/v_offset`) is what every game
  already uses and is safe here; **rotational** roll would swim at this distance —
  avoid it (contra the 2D advice in the shake literature).

**Characters.** Chunky low-poly KayKit bodies at ~0.9-0.95 scale, tinted with a
thin identity rim. They have a **fixed KayKit animation set** (`Idle`, `Running_A`,
`Interact`, `Unarmed_Melee_Attack_Punch_A`, `1H_Melee_Attack_Chop`,
`2H_Melee_Attack_Slice`, `Hit_A`, `Jump_Start`, `Dodge_Forward`, `Blocking`,
`Cheer`, `Death_A`). We cannot author new skeletal anims cheaply — **so "weight"
must come from code-driven squash/scale, particles, hitstop, and knockback layered
ON TOP of these clips**, not from new animation.

**Player count.** Always 4, often stacked in a shove-scrum. Every feedback
element has a **4× clutter budget**: whatever we add fires up to four times at
once. This is the single biggest constraint on the whole design.

**Infra we already have (reuse it, don't reinvent):**
| System | Where | Reuse for |
|---|---|---|
| Per-game screenshake `_shake` + `cam.h/v_offset`, `exp` decay | `dead_weight.gd:686`, `echo_chamber.gd:820`, `greed.gd:409`, `mower.gd:583`, `orbital.gd:792` | HIT KIT shake stage |
| Hitstop via `Engine.time_scale` (throttled) | `echo_chamber.gd:1080` (0.2 for 0.05s, 0.16s throttle), `greed.gd:813` (0.05 for 0.05s) | HIT KIT hitstop stage |
| Squash-pop on hit `_flash_pop()` (1.22x/0.85y → base over 0.16s tween) | `echo_chamber.gd:559` | HIT KIT impact-pop |
| Charge windup visual (scale 1.06 + red additive overlay) | `echo_chamber.gd:546` (`_set_charge_visual`), tilt avatar 1.06 pulse `tilt_pawn.gd:199` | HIT KIT windup / charge display |
| World-anchored ring that **fills with a fraction** (torus, scale + emission) | `greed_player.gd:297` (`show_grab_progress`) — **this is a working cooldown-ring precedent** | THE COOLDOWN RING |
| Identity feet ring (color-emissive) | every fighter/pawn `setup()` | Ring the cooldown ring is concentric with |
| One-shot `CPUParticles3D` bursts | `lw_pawn.gd:335` (shield burst), `greed_player.gd` stun stars, coin leak | HIT KIT spark burst |
| Never-color-alone badge: shape+color per player `● ▲ ■ ◆` | `core/player_badge.gd` (`glyph()`, `Shape`) | COOLDOWN RING colorblind pairing |
| Accessibility `screen_shake` / reduced-motion flag | `scripts/dev/test_access.gd:55` | Gate/attenuate shake + hitstop |

**Reference implementations already in-tree:** **Echo Chamber** is our internal
gold standard (windup overlay + squash-pop + throttled hitstop + directional
knockback + arc-cone hit resolution). **Greed** has the working fill-ring and a
hit-pause. **Tilt** already has a readable 0.12s shove windup. The three that need
the most work are **Dead Weight, Last Will, and Throne** — their shoves are
instant, telegraph-free, hitstop-free, spark-free, and cooldown-blind.

---

## A. Ranked technique stack (highest yield first, with evidence)

Ranked by **impact-per-implementation-cost for a 45°, 4-player, fixed-anim
party brawler.** The headline: **the owner's shoves feel "slow" and "weak" mostly
because the IMPACT isn't sold, not because the action is literally slow.** The fix
is to make the *hit* heavy, while keeping the *action* fast. Lengthening windups
is near the bottom of this list on purpose.

**1. Hitstop / micro-freeze on contact (40-60 ms).** *Highest yield, lowest cost.*
At the frame of impact, freeze time for a few dozen ms then resume. "The pause
sells the collision as something that cost energy… gives the eyes a few frames to
register the hit and makes the impact seem more powerful" (SmashWiki *Hitlag*;
CritPoints). Smash calls them freeze frames. We already have the exact mechanism
(`Engine.time_scale`) in Echo/Greed. Standardize it (§B) and **add it to Dead
Weight / Last Will / Throne, which have none.**

**2. Squash-and-stretch pop on impact (victim + attacker).** Disney's first
principle: flatten on impact, stretch on rebound; "the eye reads the deformation
as weight and energy" (game-feel/juice literature; gamedeveloper.com *12 principles*).
`echo_chamber.gd:_flash_pop()` already does this for the victim (1.22× wide /
0.85× tall, snap back over 0.16s). Extend to **the attacker** (a short forward
*stretch* along the shove axis) so the shove itself has follow-through mass.

**3. Exaggerated, clearly-directional knockback + small vertical pop.** Our shoves
already add `impulse + UP*impulse*0.14` (`fighter.gd:270`). Keep the up-pop — at
45° a victim that lifts-and-slides reads instantly as "hit hard, that way." Scale
the knockback (and every other kit element) with attacker speed, which we already
compute (`SHOVE_BASE + speed*SHOVE_SPEED_SCALE`). "Anticipation should show not
only that an attack is coming, but *where* it will hit" (GDKeys, *Anatomy of an
Attack*) — the knockback vector is the clearest "where."

**4. Impact spark/dust burst at the contact point.** A one-shot `CPUParticles3D`
(≤14 particles, ~0.25s, explosive, cone along the knockback dir) fired at the
strike confirms "a hit landed here." Boomerang Fu leans on exactly this kind of
punchy, high-contrast impact VFX for readability (NookGaming review). We already
spawn one-shot bursts elsewhere (`lw_pawn.gd:335`).

**5. Layered impact SFX (thud + whoosh).** Audio is half of impact. Boomerang Fu's
combat "feels fair and satisfying" largely on its SFX — boomerangs "sounding like
the sharpest swords" (NookGaming). Today a shove plays a single `bumper` sample
(`fighter.gd:224`). Layer a **whoosh on the windup** + a **body thud on the
landed hit** (two `Sfx.play` calls), pitch-varied slightly. Near-zero cost, big
weight gain.

**6. Swing arc / trail on the strike.** A brief sweeping cone/ribbon through the
hit arc, tinted player color, additive, fading. "The weapon follows a smooth arc —
a sloppy path reads as weak… activate the trail at the *start of the swing* (not
anticipation), deactivate when swing velocity drops" (MoCap Online; Rivals
*Anticipation/Action/Recovery*). Gives the shove a visible **direction and reach**
— the missing "this is an attack" read. Echo resolves hits in a cone
(`SWING_HALF_ARC`) already; draw that cone.

**7. Short anticipation windup (< 0.1s).** The "tell": body coils/pulls back before
the strike. Necessary for readability in a scrum, but *"too long and the move feels
unresponsive"* (GDKeys; Rivals). **Tilt already nails this at 0.12s**
(`SHOVE_WINDUP`, avatar scale 1.06). Keep total **time-to-hit under ~0.18s** — the
windup buys weight only if it stays cheap. This is deliberately ranked below the
impact techniques: a windup makes a hit *readable*, hitstop+squash+spark make it
*feel heavy*.

**8. Screenshake — trauma², capped, fast-decaying.** Eiserloh's trauma model:
shake = trauma² (or ³) so escalation is perceptible (trauma .3/.6/.9 → 3%/22%/73%
intensity); decay trauma linearly; **in 3D prefer offset/rotation, avoid pushing
the camera through the world** (GDC 2016 *Juicing Your Cameras*; Borderline
*trauma-based screenshake*). Our `_shake` is linear-magnitude; that's fine at our
tiny amplitudes, but **cap it and keep decay fast** so four simultaneous shoves
don't liquefy the screen (§D).

**9. Directional shove indicator (ground wedge/arrow).** A flat, player-colored
wedge on the ground pointing along `_face`, flashing at the strike (radius ≈
`SHOVE_RANGE` 1.9). Explicitly answers the owner's "no direction" complaint and is
colorblind-safe (it's a *shape*, oriented). Cheap, world-anchored, reads at 45°.

**10. Charge-strength display.** Two flavors we already have or can cheaply add:
- *Held charge* (Echo heavy): scale-up + colored overlay that intensifies with
  charge (`_set_charge_visual`) — done.
- *Speed-scaled shove* (Dead Weight / Last Will / Throne): scale the **arc length,
  spark count, knockback, and shake** by the same `power` term, so a running shove
  visibly hits harder than a standing one. Free — the `power` value already exists.

**Sources (A):**
- SmashWiki — Hitlag: https://www.ssbwiki.com/Hitlag
- CritPoints — Hitstop/Hitfreeze/Hitlag: https://critpoints.net/2017/05/17/hitstophitfreezehitlaghitpausehitshit/
- Ahmad Mohammadnejad — A More Realistic HitStop: https://www.ahmadmohammadnejad.com/sandbox/a-more-realistic-hitstop
- Game Developer — The 12 principles of animation in video games: https://www.gamedeveloper.com/production/the-12-principles-of-animation-in-video-games
- GDKeys — Keys to Combat Design: Anatomy of an Attack: https://gdkeys.com/keys-to-combat-design-1-anatomy-of-an-attack/
- Rivals Workshop — Anticipation, Action, Recovery: https://www.rivalslib.com/workshop_guide/art/anticipation_action_recovery.html
- MoCap Online — Sword Melee Animation Guide (Timing, Parries, Impact): https://mocaponline.com/blogs/mocap-news/sword-melee-animation-guide
- Squirrel Eiserloh — Math for Game Programmers: Juicing Your Cameras With Math (GDC 2016): http://www.mathforgameprogrammers.com/gdc2016/GDC2016_Eiserloh_Squirrel_JuicingYourCameras.pdf
- Borderline — All-purpose screenshake, the right way (trauma-based): http://blog.borderline.games/tutorials/gettinghit!/trauma-based-screenshake.html
- NookGaming — Boomerang Fu review (impact VFX/SFX readability): https://www.nookgaming.com/boomerang-fu-review/
- Valdemird — Game feel on the web: squash, shake, and juice: https://valdemird.com/blog/game-feel-on-the-web/

---

## B. The house standard

### B1. THE ILL WILL HIT KIT

A landed contact attack runs three phases. **Total time-to-hit stays < 0.18s** —
we add weight to the *impact*, never latency to the *action*. Everything scales
with a normalized `strength = clamp(power / POWER_REF, 0.5, 1.5)` where `power` is
the game's existing speed/charge term (`POWER_REF ≈ SHOVE_BASE + 5*scale`).

**Phase 1 — WINDUP (anticipation), ~0.08s (cap 0.10s).** Fires on button press,
before the hitbox is live.
- Model coils: `model_pivot.scale → (1.08, 0.90, 1.08)` (chunky crouch) via a
  0.06s tween; snap to base on release. (Tilt already does the 1.06 pulse form.)
- Play the KayKit action clip (`Interact` / `Unarmed_Melee_Attack_Punch_A` /
  `1H_Melee_Attack_Chop`), `_anim_lock` = windup + recovery.
- **Whoosh SFX** (`Sfx.play("bounce"/"putt", -6..-8)`), pitch-varied.
- Optional faint ground wedge in `_face` as a "where" telegraph.

**Phase 2 — STRIKE (action) + IMPACT, on the tick the hitbox lands.** On a
*connected* hit only:
- **Hitstop:** `Engine.time_scale = 0.15` for **45 ms** (heavy hits 55 ms),
  throttled — ignore re-triggers within **0.14s** (mirror `echo_chamber.gd:1084`).
  Restore via a real-time timer (`create_timer(t, true, false, true)`). **One
  hitstop at a time, globally** (§D).
- **Victim pop:** `_flash_pop()` — scale to `(1.22, 0.85, 1.22)*base`, tween back
  over 0.16s (copy `echo_chamber.gd:559`).
- **Attacker follow-through:** stretch to `(0.92, 1.0, 1.12)*base` along facing for
  0.10s, ease back — gives the shove mass.
- **Knockback:** existing `dir*power + UP*power*0.14`. Keep the up-pop. Scale by
  `strength`.
- **Spark burst:** one-shot `CPUParticles3D` at contact midpoint —
  `amount = round(8*strength)` (cap **14**), `lifetime 0.25`, `explosiveness 1.0`,
  `spread 55`, `direction` = knockback dir, unshaded, colored **white→attacker
  color**, `one_shot`, auto-free after 0.6s.
- **Swing arc:** flat cone/ribbon mesh spanning the hit arc at chest height
  (~y 0.9), attacker color, additive, alpha `0.6*strength → 0` over 0.12s.
- **Thud SFX:** second layered `Sfx.play("bumper"/"splat")` at strike, louder than
  the whoosh.
- **Shake:** `_shake = maxf(_shake, 0.22 + 0.14*strength)` (heavy/KO up to 0.5).
  Never exceed 0.5 for a normal hit.

**Phase 3 — RECOVERY, ~0.16-0.20s.** Anim-locked; scales ease to base. Cooldown
timer (which started at press) is already ticking — see the ring below.

**Reduced-motion:** when the access `screen_shake`/reduced-motion flag is off,
**skip hitstop and shake; keep** squash-pop, spark, arc, knockback, SFX (those
carry the read without motion-sickness risk).

*One-line spec:* **Windup ≤0.10s coil+whoosh → on-contact 45ms hitstop + victim
1.22/0.85 pop + attacker forward-stretch + ≤14 sparks along knockback + swing-arc
cone + layered thud + shake 0.22-0.5, all scaled by attacker `power`; total
time-to-hit <0.18s; motion pieces gated by the reduced-motion flag.**

### B2. THE COOLDOWN RING

A **world-anchored, flat, player-colored radial ring on the ground, concentric
with the character's existing identity feet-ring.** This is the owner's "colored
circle," made colorblind-safe and given a ready-flash. It beats HUD corners
because at 45° in a 4-player scrum the player's eyes are **on their character**,
not the screen edge — anchor state to the avatar, not the frame (MOBA/party
convention; gamedesignskills MOBA fundamentals). Greed already proves the form
(`greed_player.gd:show_grab_progress`, a torus that fills by fraction).

- **Anchor:** child of the pawn, `position.y ≈ 0.05`, laid flat (a thin `TorusMesh`
  or a `QuadMesh` with a radial-fill shader). Rides the body; tilts with it (Tilt
  composes from the platter transform — attach in local space so it inherits).
- **Radius:** **~0.58-0.66** outer — a hair *outside* the identity ring
  (identity rings are 0.42-0.62). One concentric band, no overlap with the color
  ring underneath.
- **Fill direction:** **radial wipe, clockwise from 12 o'clock, empties at fire and
  sweeps back to full = READY.** (Matches the MOBA "gold swipe = time until you can
  act" convention; gamedesignskills.) Cleanest via a `shader` that discards texels
  past `angle > 2π*progress`; acceptable fallback = scale/emission like Greed's
  grab ring. A thin brighter **leading edge** on the sweep makes the motion read.
- **Color:** **the player's own identity color** for the fill. Since each ring is
  under its own owner, color already maps to owner — no cross-player ambiguity.
  Charging (0→full) is a **geometric** cue (arc length), which is inherently
  colorblind-safe: do NOT encode ready/not-ready as red-vs-green.
- **Never-color-alone:** the *ability* a ring represents is disambiguated by
  **position + form**, not hue: primary contact move = the main feet ring;
  secondary (hop/dash) = a **thinner inner ring** OR a small badge-glyph pip
  (`PlayerBadge.glyph(index)` `● ▲ ■ ◆`) that lights when ready. Keep **≤2 rings
  per player.**
- **Ready-flash (the key ask):** on completion — emission spike **×1.6 for
  0.15s**, a scale pop `1.12 → 1.0`, and a quiet `Sfx.play("confirm", -14)`. This
  is the "you can shove again now" feedback the owner is missing.
- **During cooldown:** ring dim (emission ~0.4×) and partial; **ready:** full,
  bright, then settles. Hide the ring entirely when the ability has no meaningful
  cooldown left AND has been ready for >0.4s (so a permanently-ready ability
  doesn't add clutter — only show it while charging or freshly-ready).
- **Reduced-motion:** keep the ring (it's information, not shake); drop only the
  scale-pop on the ready-flash, keep the emission spike.

*One-line spec:* **Flat player-colored radial ring on the ground, outer r≈0.62,
concentric with the identity ring; wipes empty→full clockwise as the primary move
recharges (geometry = colorblind-safe); ×1.6 emission + 1.12 scale-pop + soft tick
on ready; secondary abilities get a thin inner ring or a lit ● ▲ ■ ◆ pip; ≤2 rings
per player; only visible while charging or just-ready.**

---

## C. Per-game prescription table (6 contact games)

`✅ have · ⚠️ partial · ❌ missing`. "Where" = the function to touch.

| Game | Primary attack (cd) | Secondary (cd) | Windup | Hitstop | Squash-pop | Spark/arc | Cooldown ring | Where to wire it |
|---|---|---|---|---|---|---|---|---|
| **Dead Weight** | Shove `SHOVE_CD 0.7` | Hop `HOP_CD 1.5` | ❌ | ❌ | ❌ | ❌ | ❌ | `fighter.gd:_do_shove()` (213) add windup+arc+scale; `fighter.gd:hit()` (265) add victim `_flash_pop`+spark; `dead_weight.gd:on_shove_landed()` (890) add throttled hitstop (has shake 0.28); ring in `fighter.gd:_physics_process` off `_shove_cd/_hop_cd` |
| **Last Will** | Shove `SHOVE_CD 0.7` | Hop `HOP_CD 1.1` | ❌ | ❌ | ❌ | ❌ | ❌ | `lw_pawn.gd:_do_shove()` (426); `hit()` (468) pop+spark (reuse effect-FX infra 148-212); hitstop in `last_will.gd:on_shove_landed`; ring off `_shove_cd/_hop_cd`. **Gusts (485)/stumble (498) stay soft — NO hitstop** |
| **Echo Chamber** | Light `SWING_CD 0.5` / Heavy `HEAVY_CD 0.9` | Dash `DASH_CD 1.2` / Parry `PARRY_CD 1.0` | ✅ charge (546) | ✅ (1080) | ✅ (559) | ⚠️ cone resolved, not drawn | ❌ | **Reference impl.** Add: draw the `SWING_HALF_ARC` cone as a visible arc; cooldown ring off `_swing_cd`/`_heavy_cd` (primary) + thin inner ring off `_dash_cd`. Keep everything else — it's the template |
| **Tilt** | Shove `SHOVE_CD 0.8`, windup 0.12 | Brace `BRACE_CD 3.0` | ✅ (191) | ❌ | ❌ | ❌ | ⚠️ brace ring = active-state, not cooldown | `tilt.gd` shove-resolve (reads `consume_shove_release`) add hitstop+pop+spark on landed knock/clash (`apply_knock` 222 / `apply_clash` 234); cooldown ring off `shove_cd`; brace ring already exists — add a cooldown ring for brace's 3s `brace_cd` |
| **Greed** | Tackle `TACKLE_LOCK 0.28` | Dash `DASH_CD 1.4` | ❌ | ✅ (813, too deep) | ❌ | ⚠️ grab ring only | Grab ✅ (297), dash ❌ | `greed_player.gd:do_tackle_swing()` (250) add windup coil + `_flash_pop` on the tackled body + spark; **soften `_hit_pause` from 0.05→0.15 time_scale** (0.05 is a lurch every tackle); dash cooldown ring off `dash_cd`. Grab ring is the ring template |
| **Throne** | Shove `SHOVE_CD 0.7` | Dash `DASH_CD 1.4` | ❌ | ❌ | ❌ | ❌ | ❌ | `royal.gd:_do_shove()` (271) windup+arc; `take_shove()` (310)/`apply_blast()` (318) pop+spark; hitstop in `throne.gd:on_shove_landed` (296, has shake); ring off `_shove_cd`+inner off `_dash_cd`. **A shove on the King drains grip — give the grip-drain its own hitstop+spark so `king_shoved` reads as a real hit** |

**Rollout order (highest owner-pain first):** Dead Weight → Last Will → Throne
(the three bare shoves) get the full HIT KIT + ring; Greed gets the hitstop
softened + tackle windup + dash ring; Tilt gets impact FX + cooldown rings; Echo
gets the drawn arc + rings. Echo's existing code is the copy source for all of it.

---

## D. Anti-goals (what makes it worse — do not do)

- **Do not stack hitstops.** `Engine.time_scale` is **global**; four simultaneous
  shoves must not chain freezes into a stutter. Enforce **one active hitstop, ≤60ms,
  with a ≥0.14s throttle** (Echo's guard). Only *committed, landed* hits stop time —
  **never** soft pushes (Last Will `gust_push`), clashes (Tilt `apply_clash`), or
  whiffs.
- **Do not slow-mo-abuse.** Reserve real slow-mo (deep `time_scale` 0.05, longer
  hold — `main.gd:499`, `greed.gd:813`) for **round-deciding KOs only**. Regular
  landed hits get micro-hitstop (0.15 / 45ms). A 0.05× freeze on every tackle reads
  as lag, not impact.
- **Do not over-shake.** Cap normal-hit `_shake` at **0.5**, keep the fast `exp`
  decay, translational offset only — **no rotational roll** (swims at 45°, risks
  clipping). Four shoves × big trauma = nausea. Honor the reduced-motion flag.
- **Do not lengthen the action to add weight.** Time-to-hit stays **<0.18s**.
  Windup ≤0.10s. Weight comes from *impact* feedback, not from a slower swing — the
  owner already called the shoves "too slow." A long windup makes that worse.
- **Do not clutter the ground at 4p.** **≤2 cooldown rings per player.** No floating
  cooldown numbers, no per-ability HUD bars duplicating the ground rings, no
  full-time rings — show a ring only while it is *charging or freshly ready*. Spark
  bursts capped at **14 particles** (×4 players × frequency = the real perf/read
  cost).
- **Do not encode readiness as color.** Ready/not-ready must be a **geometric** cue
  (empty vs full arc) + a brightness pulse, never red-vs-green fill — we have a
  never-color-alone rule (`player_badge.gd`) and colorblind players.
- **Do not over-tint the models to sell hits.** KayKit texture legibility is house
  law (`lw_pawn.gd` rim is a deliberate *whisper*, 0.13 alpha). Impact color lives
  in **sparks, arcs, and the ground ring** — not a full-body flash that erases the
  character read.

---

## Appendix — copy-paste-ready constants

```
# HIT KIT
WINDUP_T        = 0.08   # cap 0.10; total time-to-hit < 0.18
HITSTOP_SCALE   = 0.15   # heavy 0.15 too; KO may go 0.05
HITSTOP_MS      = 0.045  # heavy 0.055
HITSTOP_THROTTLE= 0.14   # min gap between hitstops (global)
VICTIM_POP      = (1.22, 0.85, 1.22)   # tween back 0.16s
ATTACKER_STRETCH= (0.92, 1.00, 1.12)   # along facing, 0.10s
SPARK_MAX       = 14     # amount = round(8*strength), cap 14
SPARK_LIFE      = 0.25
ARC_ALPHA       = 0.6    # * strength, fade over 0.12s
SHAKE_HIT       = 0.22   # + 0.14*strength ; hard-cap 0.5 (KO up to 0.5)
strength        = clamp(power / (SHOVE_BASE + 5*SHOVE_SPEED_SCALE), 0.5, 1.5)

# COOLDOWN RING
RING_OUTER_R    = 0.62   # concentric, just outside identity ring
RING_INNER_R    = 0.50   # secondary/inner ring
FILL            = clamp(1.0 - cd_remaining/cd_total, 0, 1)   # 0 at fire -> 1 ready
READY_EMISSION  = 1.6    # x, for 0.15s
READY_POP       = 1.12   # scale -> 1.0
MAX_RINGS       = 2      # per player
```
