# ONLINE PHASE 2 — THE THRONE game mirror (verification)

*The first ARENA mirror, built to `docs/design/10-online-first-architecture.md`
§4.3 and to the house pattern the séance defined (`docs/verify/online-seance-VERIFY.md`
PATTERN NOTES). Where the séance/understudy are UI/turn games, THE THRONE is a
continuous Jolt-physics brawl — so this port proves the pattern carries a
realtime arena: physics stays HOST-SIDE, the client renders interpolated
transforms and fires every court-power juice from state deltas. Files touched,
this lane only: `minigames/throne/throne.gd` (the mirror), `minigames/throne/
royal.gd` (`net_mirror` guard + `net_render`/`model_yaw`/`anim_tag`), and this
doc + `docs/verify/throne_netshots_{host,join}/`. The estate shell +
`core/net_session.gd` are UNTOUCHED — the generic 20 Hz pump just works.*

## What was built (the house pattern, applied to a realtime arena)

- **Host runs the ENTIRE physics sim exactly as couch.** No throne logic moved.
  Jolt, coronation, grip, decree/guard, dethrone launches, overtime — all stay
  host-authoritative. The estate pumps `_module._net_state()` to every guest at
  **20 Hz** (`unreliable_ordered`, channel 4, latest-seq wins).
- **`_net_state() -> Dictionary`** (host): compact PUBLIC facts only — phase +
  game clock, the king + who's mid-coronation, grip + decree-fatigue, each
  royal's transform (`x,y,z`, model yaw) + anim tag, the reign gold-stream flag,
  the decree/guard cooldown fractions, the active guard wall's transform, the
  timer + crisis/overtime line + banner, the per-seat scoreboard, and three
  monotonic **juice counters** (decree blasts, dethronings, grip-drain hits).
  There is no hidden info in an arena, so nothing rides a private channel.
- **`_net_apply(state)`** (client): drives a RENDER MIRROR — the same
  `throne.tscn` booted by the client estate with `config.net_mirror = true`. In
  mirror mode `begin()` builds the arena + royals, freezes every Royal
  (`net_mirror = true`, `freeze = true`) and stops: no bots, no match start, no
  coronation. `_physics_process` opens with the house guard (`if _mirror:
  _mirror_tick(delta); return`) — the sim, bots and input sampling never run.
- **`_mirror_tick(delta)`** (client, render rate): interpolates every royal
  toward its latest authoritative transform (`lerp` position + `lerp_angle`
  model yaw), advances the local game clock + cooldowns for smooth rings, and
  keeps the throne HUD glued to the mirrored king. `royal.net_render()` places
  the frozen body, faces the model, and re-plays the anim on tag change.
- **All juice fires locally from state DELTAS:** a bump in the decree counter
  throws the shockwave + shake + boom at the dais; a bump in the grip-drain
  counter pops the king + shakes; a bump in the dethrone counter fires the
  slow-beat's echo (shake + splat) while the king→−1 transition tumbles a
  physics crown off the seat; the gold-stream flag toggles the reign fountain;
  the guard fact spawns/clears the wall; grip pips + fatigue bar redraw from the
  king/grip/decree-fatigue fields; **THE COURT WILL NOT ADJOURN** overtime rides
  the crisis line + banner + hot-red timer, mirrored exactly.

## Evidence

_(two-instance probe on one machine, spec §7; all screenshots WINDOWED and read
by eye)_

### Commands

```
# host (real selector, throne-only pool):
godot --path . --position 60,60  -- --net=host --netprobe=host --pool=throne \
      --seed=7 --quitafter=200000 --outdir=docs/verify/throne_netshots_host

# join (deterministic input tape drives the claimed remote seat 1):
godot --path . --position 760,120 -- --net=join=127.0.0.1:8910 --nettape \
      --netprobe=join --quitafter=200000 --outdir=docs/verify/throne_netshots_join
```

Scripted end-to-end: client connects → claims seat 1 (BLUE, REMOTE) → tape
strolls + READY → host starts the night → REAL auction (throne-only pool) → GET
READY gate → **THE THRONE**, a full ~2-minute arena match with a remote seat 1.
The mirror booted on the client (`NET mirror boot: throne` / `THRONE_MIRROR boot
players=4 my_seat=1`) and tracked the whole brawl: coronations, dethronings,
grip drains, decrees, and the succession crisis — every phase mirrored from the
20 Hz snapshot stream, physics never leaving the host.

### Screenshots (read by eye)

- `throne_netshots_join/snap_mirror_reign_1687.png` — a live reign mirrored:
  GOLD crowned and seated on the dais with the reign gold-stream fountain, the
  `♔` crown glyph beside GOLD in the score panel, RED + BLUE challengers ringed
  around the steps, the `GOLD TAKES THE THRONE` banner, timer `1:32`.
- `throne_netshots_join/snap_mirror_crisis_5686.png` — the **SUCCESSION CRISIS —
  THRONE PAYS DOUBLE** banner + line + hot-red `0:30` timer mirrored on the
  client, GOLD reigning with MINT contesting the dais and the scoreboard tracking
  throne-seconds (`GOLD 28 · MINT 28`). The match then ran into overtime and the
  same channel carried **THE COURT WILL NOT ADJOURN** (host log
  `THRONE_OVERTIME`).
- `throne_netshots_join/snap_mirror_guard_1687.png` — fired the frame a summoned
  GUARD wall first entered the mirrored state (`state.has("guard")` → the
  client spawns a visual-only wall at the dais; the wall's transform rides the
  snapshot).
- `throne_netshots_host/snap_online_host_*.png` + `join/snap_online_client_*.png`
  — the estate lobby/gate/game/reckoning shots, both sides.

### Couch balance receipt — the transport did not perturb the sim

THE THRONE's `--thronebalance` runs the real match with FX, and its slow-mo
beats (`_time_hit` changes `Engine.time_scale` on a real-time timer) make it
wall-clock-coupled — it wanders run-to-run on *identical* code (seed 1 pristine
vs pristine drifts throne-seconds and even the overtime path). The deterministic
receipt is the no-FX fixed-step variant **`--thronebalancefast`** (no slow-mo →
pure 1/60 stepping), run from a PRISTINE `git worktree` of HEAD (d0a1f18) vs this
working tree, seeds 1 / 2 / 3:

```
godot --headless --path . res://minigames/throne/throne.tscn -- --thronebalancefast --seed=N
```

- **`shares:` + `THRONE_BALANCE` + `THRONE_OT` + `dethronings:` lines
  byte-identical, all three seeds:**
  - seed 1: `RED=25.7%(20.2s) BLUE=19.2%(15.1s) GOLD=27.0%(21.2s)
    MINT=28.1%(22.0s)` · `max_share=28.1% PASS` · OT `entered=false` ·
    `dethronings: RED=7, BLUE=7, GOLD=10, MINT=8`
  - seed 2: `RED=21.2%(21.3s) BLUE=25.9%(26.0s) GOLD=27.1%(27.2s)
    MINT=25.8%(25.9s)` · `max_share=27.1% PASS` · OT `entered=true len=30.0s
    end=cap` · `dethronings: RED=14, BLUE=11, GOLD=17, MINT=9`
  - seed 3: `RED=21.8%(22.2s) BLUE=28.2%(28.7s) GOLD=23.7%(24.1s)
    MINT=26.3%(26.8s)` · `max_share=28.2% PASS` · OT `entered=true len=30.0s
    end=cap` · `dethronings: RED=14, BLUE=10, GOLD=13, MINT=11`

  (Seed 2 also re-ran twice on the working tree alone — byte-equal both times,
  the run-to-run determinism control.) Every mirror change is behind
  `if _mirror:` or is an additive juice counter that never feeds back into sim
  logic, so the fixed-step sim is provably untouched.

### NETHASH_MOD — mirror integrity + bandwidth

Host prints a digest + byte size of every 40th module snapshot at send; client
prints the digest of the same snapshot at apply, keyed by seq (never wall clock):

- **43/43 client digests identical to the host's, zero disagreements.** (The
  host logged one extra send — seq 1560, its final snapshot — which the client
  folded on module-finish before applying; every snapshot the client DID apply
  matched the host byte-for-byte, keyed by seq.)
- **Bandwidth (measured, `var_to_bytes` of the full snapshot):** min 804 / mean
  855 / max 900 bytes. At the 20 Hz pump that is **≈17 kB/s per guest** — three
  orders of magnitude under a video stream, exactly the spec's "state, not
  pixels". Input relay upstream stays the phase-1 ≈1.2 kB/s.
- The probe match, unprompted, ran into **overtime** (`THRONE_OVERTIME t=100.0
  contested (grip=1/3)`) — so THE COURT WILL NOT ADJOURN, the succession banner,
  and the hot-red OT timer were all exercised on the mirror end to end.

## Save discipline

`user://` (party_setup.json, prefs.json, estate_save.json, cosmetics.json,
saves/slot_1.json) backed up with md5 hashes before ANY run and restored
byte-identical after the last one. The probe itself also does its own `.npbak`
dance for party_setup/prefs.

## Honest limitations

- **The ragdoll TUMBLE is not fully mirrored.** A dethroned king's body-rotation
  (the physics ragdoll spin) rides host-side only; the wire carries position +
  the `Hit_A` anim tag + the tumbling crown, so the mirror shows the fling and
  the fallen slide but keeps the body upright. Cosmetic; the slow-beat + splat +
  crown tumble carry the moment.
- **Motion is interpolated at ~RTT latency** (host-authoritative transforms
  arrive one snapshot late and lerp in). At friend pings this is the accepted
  tier-1 feel; the throne's slow verbs (walk + shove + a 0.4 s coronation) hide
  it well (spec §6: "Good").
- **Cooldown rings / gold pulse tick locally between 20 Hz snapshots** and
  resync on each; sub-frame only.
- **Trust posture:** packets are friends-lobby trusted (spec: not an anti-cheat
  surface); latest-seq wins and juice fires from counter deltas, so a dropped
  snapshot loses only intermediate frames.
- Both instances share one `user://` on a dev machine — probe-bounded, and
  everything restored by hash after the runs.
