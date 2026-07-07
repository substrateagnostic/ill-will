# ONLINE PHASE 2 — ECHO CHAMBER game mirror (verification)

*Built to `docs/design/10-online-first-architecture.md` §4.3 and the house
pattern (`docs/verify/online-seance-VERIFY.md` PATTERN NOTES; arena reference
`minigames/throne/throne.gd`). ECHO CHAMBER is the ghost game — the one
mirror where most of the bodies on screen are DETERMINISTIC REPLAYS. The
port's central decision: ghost transforms are STREAMED in the same
body-indexed block as the live fighters, never re-simulated on the client —
drift risk zero by construction, for a measured ~32 bytes per ghost per
snapshot. Files touched: `minigames/echo_chamber/echo_chamber.gd` (+~330:
mirror vars, begin() fence, `_net_state()`/`_net_apply()`/`_mirror_tick()`,
juice counters, champ pre-announce), `fighter.gd` (+45: `net_pose()` +
mirror anim/sfx applier), `ghost.gd` (+18: wire id, `cur_state`,
`net_pose()`). `core/net_session.gd` and `estate/estate.gd`: NOT touched —
the phase-2 shell pump is generic.*

## What was built

- **Host sim untouched.** The host runs the whole brawl exactly as couch; the
  estate pumps `_net_state()` at 20 Hz (unreliable_ordered ch 4, latest-seq
  wins) because the module exposes the method.
- **`_net_state()`** (host): one flat dict of PUBLIC facts. The heart is
  `bd`, a PackedInt32Array of stride-8 entries — first the N fighters
  (x/y/z cm, yaw mrad, anim-state byte, hp, alive|ring-warn flags), then one
  entry per LIVE GHOST (pose + anim-state byte + owner + wire id + opacity).
  **Ghosts on the wire are poses, not takes**: the recorded-round data that
  drives them never leaves the host, so the mirror cannot drift — it renders
  exactly what the host's replayer computed this tick. Beside the block:
  round index + rmax + authoritative round clock (`rem`), the shrunk flag,
  points, both banner texts+colors, and five juice counters (parries,
  ghost bounties, self-haunts, deciding-moment beats) plus the pre-announced
  champ.
- **`_net_apply()`** (client): drives a RENDER MIRROR — the same
  `echo_chamber.tscn` booted with `config.net_mirror = true`. The mirror
  branch of `begin()` builds arena/UI/fighters and stops: no recorders, no
  bots, no rng, no intro kick. `_physics_process` opens with the house guard.
  **All juice fires from deltas**: hp drops fire the hit burst at that
  fighter, alive-edges fire death fx/respawn chime, ghost-id vanishes during
  PLAY fire the fragment burst in owner tint (round swaps clear silently,
  as the couch does), the parry counter fires the clash flash at the
  parrier, the bounty counter fires the royalty sting ("PAST X STRIKES
  AGAIN" text rides the credit-banner fact), the self-haunt counter fires
  the grudge sting + deep shake under the mirrored "KILLED BY THEIR OWN
  ECHO" banner, the deciding-moment counter fires the FOV punch, the shrunk
  edge runs the shared `_shrink_fx()` (floor-fall tween + crush + shake),
  and the champ fact fires confetti + win sting.
- **`_mirror_tick()`** (client, per physics tick): exponential glide of every
  fighter AND ghost toward its authoritative pose (`k = 1-exp(-14·dt)`);
  teleports (respawns, recorded respawn snaps, arena falls) never glide —
  distance > 4 snaps, the same rule the couch replayer uses. Anim one-shots
  + swing sfx fire on state-byte ENTRY inside `net_pose()` (fighter and
  ghost both). The ring-out warning blinks at the couch's 4 Hz from a LOCAL
  clock — only the steady "outside the ring" flag rides the wire, so the
  alarm never aliases against the 20 Hz pump.
- **THE FINAL STRETCH on the mirror** (this wave's lesson 2): the kit
  attaches in mirror begin() and fires purely from facts already in the
  snapshot — `rn`/`rmax` (escalate when the final round begins — `rmax`
  comes off the WIRE because the client estate boots mirrors with a stock
  rounds count), `rem` (the last-10s tick ladder + timer pulse), round flips
  (re-arm), DONE (match_ended). Zero extra bytes.
- **Champion pre-announce** (this wave's lesson 1, from masked_ball):
  `report_finished()` stops the estate's pump the same tick it runs, and
  echo's `_finish_match()` used to report in the very tick it minted the
  winner tableau. Now it mints `_net_champ` + all prints on the original
  tick and defers only the `report_finished()` emit by 0.5 s (real-time
  timer, immune to the deciding-moment slow-mo). ~10 snapshot beats carry
  the champ fact; the couch gains half a second of winner tableau it never
  had under the estate (the podium used to cut the banner off at frame one);
  standalone/bot logs are unchanged (prints stay on the original tick).
- **Input: ZERO echo code.** Fighters poll `PlayerInput` per seat; remote
  seats arrive through the phase-1 `_remote` seam untouched. The probe's
  remote seat 1 strolled and threw light swings across the wire with no echo
  input changes.
- **No hidden info** in the arena — nothing rides the private channel.

## Evidence

_(two-instance probe on one machine, spec §7; port 9617 and a privately
named binary copy (`g_es93`) because other agents ran probes on this machine
tonight; all screenshots WINDOWED and read by eye. Night 2 below is
canonical; night 1 — identical story (62/62 digests, the same self-haunt on
the remote seat), before a mirror evidence-latch timing fix (one snap fired
on the final round's FIRST snapshot, while the twelve echoes still stood
stacked on their spawn rings — cosmetically useless, mechanically fine) —
is kept as `online-echo-*-night1.log`. Full night-2 logs:
`online-echo-host.log` / `online-echo-client.log`.)_

### Commands

```
# host (real selector, echo-only pool; --echofast=30 keeps a 4-round night
# inside the probe's podium window):
g_es93 --path . --position 60,60  -- --net=host --port=9617 --netprobe=host \
       --pool=echo --echofast=30 --seed=7 --quitafter=200000 \
       --outdir=docs/verify/echo_netshots_host

# join (deterministic input tape: strolls + A presses = light swings over
# the wire):
g_es93 --path . --position 700,120 -- --net=join=127.0.0.1:9617 --nettape \
       --netprobe=join --quitafter=200000 --outdir=docs/verify/echo_netshots_join
```

### The night, end to end

Client connects on 9617 → granted seat 1 (BLUE, REMOTE) → tape strolls +
READY → host starts the night → REAL auction (bots bid; echo-only pool) →
GET READY gate (remote A answers it) → **ECHO CHAMBER**: `ECHO_BEGIN
players=4 seed=3300865038 bots=false round_len=30.0` (seat 0 the host's
idle keyboard human, seat 1 the remote tape, seats 2/3 bots), the mirror
boots on the client (`NET mirror boot: echo` / `ECHO_MIRROR boot players=4
my_seat=1`) during the INTRO — no spectate card — and tracked every round
flip (`ECHO_MIRROR round=1/4 … 4/4`). Then the full anthology of echo beats
crossed the wire (night-2 log lines, paired by eye):

- **Ghosts.** Rounds 2/3/4 spawned 4/8/12 ghosts host-side, and the host's
  in-sim ghost-drift assert stayed at zero THROUGH the online night:
  `ECHO_DETERMINISM round=1..4 max_err=0.000000 OK` all four rounds while
  every one of those poses also rode the wire. The mirror's GHOSTS counter
  tracked the block, ticking down as echoes fragmented (PLAY-time
  id-vanishes fire the shard burst in owner tint on both screens).
- **Parry clashes.** Many `ECHO_PARRY` beats — live and ghost-swing parries
  both, including `parrier=GOLD attacker=GOLD ghost=true round=1 t=1.54`,
  a bot parrying ITS OWN past self; the mirror fired the clash flash +
  credit banner off the counter.
- **THE IRONY PACK, five times.** `ECHO_SELF_HAUNT` fired for BLUE (r2),
  GOLD (r3), MINT ×2 (r3), MINT (r4) — the round-2 one is **the REMOTE
  player killed by their own recorded echo**, and the "KILLED BY THEIR OWN
  ECHO" banner landed on both screens (the pair below, read at the same
  timer tick in night 1; night 2's pair at 28.5/28.4).
- **THE RING DEMANDS**: warnings ride as a steady outside-the-ring flag and
  blink at the couch's 4 Hz from the mirror's local clock, so the alarm
  can't alias against the 20 Hz pump.
- **Round-4 final stretch**: tense bed + last-10s ladder on both machines
  from `rn/rmax/rem` — zero dedicated bytes.
- **The collapse**: `ECHO_SHRINK round=4 t=13.51` (`0.45 × 30 s`, the spec's
  fraction on the shortened round) → shrunk flag edge → the floor fell away
  on the mirror (`_shrink_fx`), banner riding the ban fact (pair below).
- **The champ**: host `ECHO_MATCH_OVER champ=MINT placements=[3, 2, 1, 0]`
  — and the mirror printed `ECHO_MIRROR champ=3` and fired confetti BEFORE
  the fold (`NET mirror fold`), the pre-announce doing exactly what lesson 1
  demands. Spectate card for the podium beat → mirrored match podium +
  RECKONING ladder (`NETPROBE_RESULTS RED:pts=1,grudge=5 BLUE:pts=2,
  grudge=6 GOLD:pts=3,grudge=5 MINT:pts=5,grudge=4`) → `NETPROBE saves
  restored` → both instances quit clean. **Zero script errors in all four
  logs (both nights).**

### Screenshots (read by eye; `echo_netshots_host/` + `echo_netshots_join/`)

- **The irony pair — the banner the lane brief asked for:**
  `host/snap_net_irony_8753.png` vs `join/snap_mirror_irony_8158.png`
  (night 1's pair, read first, matched at the SAME timer tick 28.5: both
  screens show "KILLED BY THEIR OWN ECHO" + "PAST BLUE STRIKES AGAIN",
  GHOSTS: 4, the identical scoreboard GOLD 13 ♥♥♥ / MINT 10 ♥♥· / BLUE 4 ··
  / RED 0 ♥♥♥, and the same translucent green/yellow/red echoes around the
  same pillars).
- **The parry pair:** `host/snap_net_parry_3767.png` vs
  `join/snap_mirror_parry_3169.png` — "GOLD PARRIES!" credit + clash flash
  on both.
- **The final-round pair — the arena of echoes:** `host/snap_net_r5_15446
  .png` vs `join/snap_mirror_r5_18685.png` — **read side by side at timer
  25.0, ROUND 4/4, GHOSTS: 9 on both**: two mint echoes, two yellow echoes,
  the red echo at the right pillar, the mage-hat ghost over the blue ghost,
  and the four live fighters, body for body on the same floor, scoreboard
  identical (MINT 44 / GOLD 31 / BLUE 5 / RED 0).
- **The haunted-arena pair:** `host/snap_net_ghosts_9297.png` vs
  `join/snap_mirror_ghosts_8690.png` (round 2, opaque fighters vs
  owner-tinted translucent echoes).
- **The collapse pair:** `host/snap_net_shrink_15979.png` (timer 16.5) vs
  `join/snap_mirror_shrink_19986.png` (timer 16.4, one snapshot beat) —
  same "THE FLOOR FALLS AWAY!" banner over the same shrunk disc, the outer
  apron caught mid-fall on the mirror.
- **The champ pair:** `host/snap_net_champ_17079.png` vs
  `join/snap_mirror_champ_22600.png` — near pixel-identical: "MINT WINS THE
  ECHO!", FINAL, GHOSTS: 0, final board MINT 56 / GOLD 38 / BLUE 5 / RED 0.
  The mirror's tableau exists ONLY because the champ fact was pre-announced.
- **Flow shots:** client lobby/ready/gate (`snap_online_client_*`), the
  mirror already live during INTRO (`snap_online_client_game_2978.png`),
  and matching match-podium + reckoning pairs on both sides.

### NETHASH_MOD — mirror integrity + bandwidth (seq-keyed, never wall clock)

- Night 2: **61/61 received digest pairs identical**; one of the 62 sampled
  snapshots (seq 1200) never reached the client — dropped in flight on the
  unreliable_ordered channel, which is the design (latest-seq wins; the
  next snapshot 50 ms later carried the world on). Night 1: **62/62.**
  Zero MISMATCHES across both nights. The phase-1 walker channel stayed
  clean too (152/152 night 1, 153/153 night 2).
- **Bandwidth (measured, `var_to_bytes` of the full snapshot, every 40th):**
  night 2 min 588 / median 684 / max 1012 / mean 708 bytes (night 1:
  588/680/1012/706); at 20 Hz **≈14 kB/s per guest** (≈42 kB/s at a full
  table of three guests). The ghost block is the marginal cost the lane
  brief asked to measure: **32 B per live ghost per snapshot** (8 int32s) —
  the round-4 cap of 12 ghosts adds ≈384 B/snapshot ≈ 7.7 kB/s, and the
  whole game rides at about half the séance's own footprint. Streaming
  poses beats re-simulation on every axis that matters here: zero drift
  risk, no take shipping (one full 4-player round of takes is ~4 × 3200
  frames × ~17 B ≈ 220 kB that would have to cross up front, growing every
  round), and the mirror stays dumb.

### Couch receipts — the transport did not perturb the sim

**The pre-existing noise floor, measured first (control):** echo is the
anthology's one game whose brawlers are real `CharacterBody3D`s under
`move_and_slide()`, and its bot matches are NOT byte-reproducible run to run
— **on pristine HEAD (ae60154) itself**, two sequential
`--echobots --echofast=5 --seed=1` runs diverge from round ~3 on (bot
physics is chaotic; a solver-level difference amplifies). This is unlike
swap (hand-integrated, tick-deterministic) and predates this lane; echo's
own v1.1 receipts always verified WITHIN-run determinism (ghost replay
drift), not cross-run logs. Receipts therefore:

- **Control diffs:** pristine↔pristine and work↔work self-diffs show the
  same divergence character (rounds 1–2 typically identical, then chaos);
  pristine↔work shows no NEW divergence class.
- **Structure equal, both trees, seeds 1/7/42:** round ramp `ghosts=0/4/8/12`
  identical; **`ECHO_DETERMINISM … max_err=0.000000 OK` for every round in
  every run on both trees** (the ghost-drift receipt — the assert stays
  armed and never fired); `ECHO_SHRINK round=5 t=2.26` — the round-5
  collapse lands on the tick-exact same sim time in BOTH trees;
  `ECHO_MATCH_OVER` reached with full `KILL_EVENTS`.
- **The mirror code cannot touch the couch by construction:** every addition
  is either a counter/fact write (`_net_*` bookkeeping, ghost `gid`,
  `cur_state` mirroring the anim already applied), fenced behind `_mirror`,
  gated on `NetSession.is_online()` (`_net_snap`), or after the final
  prints (the 0.5 s report deferral — prints stay on the original tick, so
  logs are structurally unchanged; couch estate nights get half a second of
  winner tableau that used to be cut off).

```
g_es93 --headless --path . res://minigames/echo_chamber/echo_chamber.tscn -- \
       --echobots --echofast=5 --seed=1|7|42 --quitafter=14000
```

### Regressions (offline behavior untouched)

```
g_es93 --headless --editor --import --quit --path .                      # clean
g_es93 --headless --path . res://.../echo_chamber.tscn -- --echobots ...  # above
g_es93 --headless --path . -- --estate --auctiontest --quitafter=9000    # AUCTIONTEST PASS
g_es93 --headless --path . -- --estate --estatebots --quitafter=3200     # zero script errors
g_es93 --headless --path . -- --strolltest --quitafter=1200              # zero script errors
```

## Save discipline

`user://` (party_setup.json, prefs.json, estate_save.json, cosmetics.json,
saves/slot_1.json) backed up with an md5 manifest before ANY run and
restored byte-identical after the last one (hashes re-verified: party_setup
D3E6350C…, prefs 99914B93…, estate_save 0D8ACBF4…, cosmetics 2BE51EFA…,
slot_1 0D8ACBF4…). The probe itself also does its own `.npbak` dance. Other
agents ran probes on this machine tonight; this lane used a private port
(9617) and a privately named binary (`g_es93`) so only its own processes
were ever started or killed.

## Honest limitations

- **Echo's couch baseline is not cross-run reproducible** (pre-existing;
  see the control section). The byte-diff receipt the fleet uses elsewhere
  is replaced here by control-diffs + structural invariants + the in-sim
  determinism assert, honestly labeled.
- **Anim one-shots are state-sampled at 20 Hz**, so a light swing's 0.34 s
  animation window (≈7 snapshots) always lands, but a state that flickers
  inside one snapshot interval (< 50 ms) can drop its anim (never its
  outcome — hits ride hp deltas).
- **Hit-strength on the mirror is inferred from the hp delta** (≥2 = heavy
  feedback); a 2-damage heavy that only removes a fighter's last 1 hp plays
  the light-strength burst. Cosmetic.
- **The mirror does not reproduce the host's slow-mo beats**
  (`Engine.time_scale` dips for self-haunt/deciding KOs) — a time-scaled
  mirror would fight the snapshot clock; it fires shake/FOV/sting instead
  (throne precedent).
- **Ghost fragment bursts on the mirror fire at the last STREAMED pose** —
  up to one snapshot (50 ms) behind the couch's exact endpoint. The
  determinism assert lives host-side, where the sim is.
- **The mirror's hint bar** personalizes from the client's local default
  bindings for all four seats (the estate hands the mirror `device: -99`
  rosters, but the client's own PlayerInput answers `describe_binding`) —
  same cosmetic gap as masked ball, phase-3 polish.
- Both instances share one `user://` on a dev machine — probe-bounded,
  everything restored by hash after the runs.
