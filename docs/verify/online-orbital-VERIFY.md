# ONLINE PHASE 2 — ORBITAL DODGEBALL game mirror (verification)

*Built to `docs/design/10-online-first-architecture.md` §4.3 and the house
pattern (`docs/verify/online-seance-VERIFY.md` PATTERN NOTES, copied verbatim
where they are the pattern). ORBITAL's soul is the BALLS: throws never
despawn, and the whole threat ladder (heat glow, trail burn, threat tones,
danger vignette) is derived from ball VELOCITY — so the wire carries ball
state + velocity and the client's own presentation renders the same menace
the couch sees, including a 30-second-old ghost orbit pulsing on both
screens. Files touched: `minigames/orbital/orbital.gd` only (+~330: wire-fact
counters, `_net_state()`/`_net_apply()`/`_mirror_tick()`, aim provider,
probe latches). `core/net_session.gd` and `estate/estate.gd`: NOT touched —
the phase-2 shell pump is generic.*

## What was built

- **Host sim untouched.** The host runs the whole match exactly as couch; the
  estate pumps `_net_state()` at 20 Hz (unreliable_ordered ch 4, latest-seq
  wins) because the module exposes the method — no estate edits.
- **`_net_state()`** (host): one flat dict of PUBLIC facts — per-pawn
  [alive, visible, pos, basis quat, anim, charge, invuln] (12 fields), per-ball
  [state, pos, VELOCITY, owner, holder, age] (10 fields), score/catch/death
  arrays, banner/event strings with colors, `time_left`, the FINAL ORBIT flag,
  a bounce counter + impact, the last-kill row [gen, victim, killer, ball
  speed], and the champion fact. Nothing else enters; orbital has no hidden
  info, so `send_module_private` is not used.
- **`_net_apply()`** (client): drives a RENDER MIRROR — the same
  `orbital.tscn` booted by the client estate with `config.net_mirror = true`.
  The mirror branch of `begin()` builds planets, pedestals, the four start
  balls and the pawns from the same deterministic consts as the host (no rng
  drawn — the estate boots mirrors with `rng_seed: 0` and nothing reads it),
  fences bots and the sim, and installs the aim provider. All juice fires
  from DELTAS: catch-counter deltas fire the bumper + white burst + shake,
  the kill row fires splat/death + the speed-scaled FOV punch + the victim
  burst, ball state transitions fire throw whoosh / pickup tick, the bounce
  counter fires the impact-scaled bounce voice, alive rising edges fire the
  respawn chirp + burst, the FINAL ORBIT flip escalates the kit + tints the
  starfield, and the pre-announced champ fact fires confetti + the win sting.
  Banner and event-line text ride the wire with their colors (an event GEN
  counter replays repeated texts).
- **`_mirror_tick()`** (client, per physics tick): pawn glide + basis slerp
  (the tangent frame `srf_n`/`heading` is re-derived from the mirrored basis,
  so the dotted AIM PREVIEW works off `throw_vector()` unchanged), held balls
  glue to their holder's hands exactly as the couch computes it, FLYING balls
  **dead-reckon** (snapshot position advanced by its own velocity, glided at
  a tight rate) and feed their trails locally, charge HOLD-FILL advances at
  the host's real rate between snapshots (greed's grab pattern) and resyncs
  on apply, `time_left` drains smoothly for the timer + the kit's last-10s
  ladder.
- **THE THREAT LADDER crosses the wire for free.** `heat_factor()`, the
  emission ramp, trail heat, threat-tone cadence/pitch and the danger
  vignette all read `bb.vel` — which is authoritative from the snapshot. No
  threat state is separately mirrored because velocity IS the threat state.
- **FINAL STRETCH kit (doc 09 §Q1)** attaches on the mirror and fires
  client-side from mirrored facts: `play_started` on first snapshot,
  `escalate` + starfield tint on the FINAL ORBIT flip, the last-10s tick
  ladder off the mirrored `time_left`, `match_ended` on the champ fact.
- **Input: ZERO orbital code.** The sim polls `PlayerInput` per seat; remote
  seats arrive through the phase-1 `_remote` seam untouched. Orbital aims in
  SCREEN space (the sphere game), so the mirror's aim provider returns
  `aim_screen` computed against its own render — the host's
  `get_aim_screen()` returns it verbatim for a remote seat, the exact seam
  KBM aiming already used.
- **The masked-ball lesson, applied:** `report_finished()` stops the estate's
  20 Hz pump the same tick it runs, so `_end_match` now minted the champ fact
  and defers ONLY the report by one real beat (0.45 s). All prints stay
  inline and byte-identical; END phase, the winner banner and the champ fact
  reach mirrors before the fold.

## Evidence

_(two-instance probe on one machine, spec §7; private port 9761 and a
privately named binary copy (`g_orblw91`) because other agents run probes on
this machine; all screenshots WINDOWED and read by eye.)_

### Commands

```
# host (real selector, orbital-only pool):
g_orblw91 --path . --position 60,60  -- --net=host --port=9761 --netprobe=host \
          --pool=orbital --seed=7 --quitafter=200000 --outdir=docs/verify/orb_netshots_host

# join (deterministic NETPROBE input tape):
g_orblw91 --path . --position 700,120 -- --net=join=127.0.0.1:9761 --nettape \
          --netprobe=join --quitafter=200000 --outdir=docs/verify/orb_netshots_join
```

(`party_setup.json` was staged so seat 1 reads BOT before the claim — the
live save had seats 0 AND 1 human, which parks a joiner on seat 2 and the
probe rig watches seat 1. Staged file covered by the save-discipline
manifest; the estate seam itself untouched.)

### The night, end to end

Client connects on 9761 → granted seat 1 (BLUE, REMOTE) → tape strolls +
READY → host starts the night → REAL auction (bots bid; orbital-only pool) →
GET READY gate (remote A answers it) → **ORBITAL DODGEBALL**, full 3-minute
match. The mirror booted on the client (`NET mirror boot: orbital` /
`ORB_MIRROR boot players=4 my_seat=1`) already inside the intro banner — no
spectate card. Zero script errors in any log.

**The remote hand played the whole game loop across the wire:**
`CATCH t=96.4 p=1 ball_age=11.2 stolen=true` — the REMOTE seat plucked an
11-second orbit out of the sky (A-tap over the relay meeting a mirrored
catch window), then `KILL t=97.9 killer=1 victim=2` — BLUE threw it back and
smacked GOLD — then stole ANOTHER 15-second orbit at t=106.2. Kill credit,
grudge and points all landed on the remote seat (final: BLUE 4 pts, and the
reckoning gave BLUE +2).

Match end: `ORBITAL_RESULTS` placements [2,3,1,0] (GOLD 12 — including an
11s ghost-orbit royalty — MINT 6, BLUE 4, RED 0), two ghost-orbit monuments.
Module reported one beat later → `NET mirror fold` → spectate card for the
podium breath → mirrored match podium + RECKONING ladder →
`NETPROBE_RESULTS RED:pts=1,grudge=4 BLUE:pts=2,grudge=6 GOLD:pts=5,grudge=5
MINT:pts=3,grudge=5` → `NETPROBE saves restored` → both instances quit clean.

### Screenshots (read by eye; `orb_netshots_host/` + `orb_netshots_join/`)

- **The top-heat pair — the threat ladder on both screens:**
  `host/snap_orb_host_heat_5903.png` vs `join/snap_orb_mirror_heat_5385.png`
  (both latched on the same condition: hf ≥ 0.75 near a living pawn). Near
  pixel-identical at timer 2:42: the same white-hot screamer burning over
  the brown planet's rim with its trail arcing in from upper-right, the same
  GOLD trail loop under the blue planet, MINT's green ball resting at the
  brown planet's west edge, the same pawn formation. The mirror's
  dead-reckoned ball sits within a hair of the host's — velocity-derived
  heat renders the same menace with no extra state.
- **The catch pair:** `host/snap_orb_host_catch_8484.png` vs
  `join/snap_orb_mirror_catch_7984.png` — both read `NICE CATCH — MINT — A
  18-SECOND ORBIT!` at 2:24 with identical ball/trail layouts (the mirror
  snapped one snapshot beat later, mid catch-burst; MINT's model is a blink
  dimmer there — the invuln shimmer, mirrored).
- **The FINAL ORBIT pair — the kit trigger fact:**
  `host/snap_orb_host_finalorbit_25135.png` vs
  `join/snap_orb_mirror_finalorbit_24653.png` — near pixel-identical at
  0:30: FINAL ORBIT banner, `THE ESTATE CALLS TIME. OLD ORBITS STILL KILL.`,
  scores RED 0 / BLUE 4 / GOLD 10 / MINT 3, the same two yellow screamers
  arcing off the purple planet, the same green ball flying bottom-left, the
  starfield leaning warm on both.
- **Flow shots:** `join/snap_online_client_lobby/ready/auction/gate`,
  `join/snap_online_client_game_2973.png` (mirror already up during the
  intro), both `matchpodium` and both `reckoning` shots (same ladder).

### NETHASH_MOD — mirror integrity + bandwidth (seq-keyed, never wall clock)

- **82/82 module digest pairs identical** (every 40th snapshot, host print at
  send vs client print at apply). The phase-1 walker channel stayed clean
  too: **200/200** NETHASH pairs identical.
- **Bandwidth (measured, `var_to_bytes` of the full snapshot):** min 1452 /
  median 1636 / max 1864 / mean 1652 bytes. At the 20 Hz pump that is
  **≈33 kB/s per guest** (~99 kB/s at a full table of three guests) — the
  8-ball ceiling plus four pawns, comfortably inside the spec's "state, not
  pixels" posture. Input relay upstream stays the phase-1 ≈1.2 kB/s.

### Couch receipt — the transport did not perturb the sim

`--orbbots` (the game's own long-standing receipt harness) from a PRISTINE
`git worktree` of HEAD (ae60154) vs this working tree, seeds 1 / 2 / 3:

```
g_orblw91 --headless --path . res://minigames/orbital/orbital.tscn -- \
          --orbbots --seed=N --fast=10 --autoquit
```

- **Full logs byte-identical, all three seeds** — every THROW/HOP/CATCH/KILL
  line, `KILL_EVENTS`, `ORBITAL_RESULTS`, `ORBITAL_SIM`,
  `ORBITAL_ASSERT max_flight_age … PASS`. One honest note: the engine's
  exit-time `ObjectDB instances leaked / resources still in use` warnings
  wobble run-to-run **on both trees** (pristine printed them on one run and
  not another; a pristine-vs-pristine rerun moved the count 8→6). With those
  four trailing engine lines stripped, every pairing is byte-identical; the
  sim content lines match exactly in every run.

### Regressions (offline behavior untouched)

```
g_orblw91 --headless --editor --import --quit --path .                    # clean (same pre-existing
                                                                          #  asset warnings as HEAD)
g_orblw91 --headless --path . res://minigames/orbital/orbital.tscn -- \
          --orbbots --seed=1|2|3 --fast=10 --autoquit                     # byte-identical (above)
g_orblw91 --headless --path . -- --estate --auctiontest --quitafter=9000  # AUCTIONTEST PASS
g_orblw91 --headless --path . -- --estate --estatebots --quitafter=3200   # zero script errors
g_orblw91 --headless --path . -- --strolltest --quitafter=1200            # zero script errors
```

## Save discipline

`user://` (party_setup.json, prefs.json, estate_save.json, cosmetics.json,
saves/slot_1.json) backed up with an md5 manifest before ANY run and restored
byte-identical after the last one (hashes re-verified; see the lastwill
VERIFY for the shared-session restore receipt). The probe itself also does
its own `.npbak` dance for party_setup/prefs. This lane used private port
9761/9762 and a privately named binary (`g_orblw91`) so only its own
processes were ever started or killed.

## Honest limitations

- **Ball dead-reckoning overshoots through a bounce** for up to one snapshot
  beat (the prediction carries the pre-bounce velocity until the next apply
  corrects it). At 20 Hz the correction glide is a hand's width at top speed;
  never visible as a teleport in the shots.
- **Bounce sfx is a counter** — several bounces inside one snapshot window
  collapse to one voice (couch plays each). Positional audio is not used, so
  the loss is cadence, not information.
- **The couch's sim slow-mo beat arrives THROUGH the wire** (the host's sim
  step shrinks, so snapshots slow down) — the mirror's kill juice is the FOV
  punch + burst; it does not run a local tick-budget slow-mo. Same news, the
  host's rhythm.
- **A same-anim one-shot repeat can be missed** (two Throws with no
  in-between anim change on the wire); the throw whoosh keys off ball state
  transitions instead, so the audio never skips.
- **The champion beat on the mirror is short** — confetti + sting land ~0.45 s
  before the fold to the (unmirrored) podium card. Podium mirroring remains
  the known phase-3 chore.
- **Trust posture:** friends-lobby trusted, per spec — not an anti-cheat
  surface.
- Both instances share one `user://` on a dev machine — probe-bounded, and
  everything restored by hash after the runs.
