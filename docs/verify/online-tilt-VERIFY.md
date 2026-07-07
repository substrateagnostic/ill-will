# ONLINE PHASE 2 — TILT game mirror (verification)

*Built to `docs/design/10-online-first-architecture.md` §4.3 and the house
pattern set by `minigames/seance/seance.gd` (PATTERN NOTES in
`docs/verify/online-seance-VERIFY.md`, copied verbatim where they are the
pattern). Files touched: `minigames/tilt/tilt.gd` (+~330: counters, visual
factoring, `_net_state()`/`_net_apply()`/`_mirror_tick()`),
`minigames/tilt/platter.gd` (+9: `mirror_set_tilt`),
`minigames/tilt/tilt_pawn.gd` (+55: render-only mirror poses),
`minigames/tilt/seagull.gd` (+11: `mirror_tick`). `core/net_session.gd` and
`estate/estate.gd`: NOT touched — the phase-2 shell pump is generic; tilt just
exposes the two contract methods.*

## What was built

- **Host sim untouched.** The host runs the whole match exactly as couch; the
  estate pumps `_net_state()` at 20 Hz (unreliable_ordered ch 4, latest-seq
  wins) because the module exposes the method — no estate edits.
- **`_net_state()`** (host): the platter tilt vector (radians, snapped 1e-4) —
  *the one transform that moves everything*; per-pawn `[state, pos, facing,
  coins, flags(moving/braced/cheering), shove-counter, knock-counter]`
  (platter-local XZ while standing, world XYZ while falling); gull XZ + a
  bombs-dropped counter per gull; loose-coin list; splat list (pos + owner +
  remaining life); clash counter + midpoint; scores; round/overtime/sudden-
  death facts; the banner fact `[text, color, visible]`; round-winner and
  match-winner facts. Everything in this dict is on every couch player's
  screen already — tilt has no hidden info, so there is no private channel.
- **`_net_apply()`** (client): drives a RENDER MIRROR — the same `tilt.tscn`
  booted by the client estate with `config.net_mirror = true`. The mirror
  branch of `begin()` builds the world, pawns and quadrant markers exactly as
  the host does and fences ONLY bot construction and the round kick.
  `_physics_process` opens with the house guard
  (`if _mirror: _mirror_tick(delta); return`). **All juice fires from state
  DELTAS:** shove-counter deltas play the windup tell (scale pulse + early
  punch anim + quiet card flick), knock-counter deltas play the hit reaction +
  shake, brace-flag edges click, coin-count deltas rebuild the back-stack and
  ring the bell, state edges fire the fall (death sting + shake) and the
  splash, clash deltas fire sparks + shock ring + "CLASH!" floaty, the
  sudden-death/overtime facts raise the pin and harden the platter (the v1.2
  "THE ESTATE SPLITS NOTHING" banner rides the mirrored banner fact, as do
  the AIR RAID gull-assist royalty banners), and the round/match-winner facts
  fire cheer + confetti.
- **`_mirror_tick()`** (client, 60 fps): exponential chase of the
  authoritative platter tilt (`platter.mirror_set_tilt` — disc rotation, rim
  glow and warning lamp reuse the couch renderer), pawn lpos/facing glide,
  falling pawns chase their world position and tumble locally, gulls glide
  with local flap/bob/yaw, bombs integrate locally as cosmetics (the SPLAT
  truth arrives via the splat list), and the low-side klaxon plays off the
  mirrored tilt. The couch `_process` (timer text, camera roll with the
  platter, splat fade, coin twirl, shake) runs UNMODIFIED on the mirror —
  `_net_apply` feeds it `game_t`/`round_t`/`overtime`/`sudden_death` and the
  platter tilt, which is all it ever read.
- **Hint bar divergence (deliberate):** the mirror builds its controls bar
  from ITS OWN machine's bindings (`_controls_bar()` already resolves per-seat
  devices; on a client only MY seat has a device). The couch shows the host's
  keys; the mirror shows yours — better, not different information. The
  seagull hint appears on the mirror only when MY seat is the gull.
- **Input: ZERO tilt code.** The sitting loop polls PlayerInput per seat; the
  phase-1 `_remote` seam feeds remote seats on the host untouched.

## The wire, honestly priced

Snapshot = 1 platter vector + 4 pawn rows + gulls/coins/splats/facts.
Measured via the estate's NETHASH_MOD `bytes=` lines (var_to_bytes of the
full dict, every 40th snapshot): see Evidence below. Tilt needs no grid and
no private sends; the whole game rides the generic 20 Hz pump.

## Evidence

_(two-instance probe on one machine, spec §7; all screenshots WINDOWED and
read by eye)_

### Commands

```
# host (real selector, tilt-only pool, short match for the probe night):
g_aa41 --path . --position 60,60  -- --net=host --port=9412 --netprobe=host --pool=tilt \
      --seed=7 --rounds=2 --roundtime=25 --quitafter=200000 --outdir=docs/verify/tilt_netshots_host

# join (deterministic input tape; A-pulses shove while standing and BOMB as a gull):
g_aa41 --path . --position 700,120 -- --net=join=127.0.0.1:9412 --nettape --netprobe=join \
      --quitafter=200000 --outdir=docs/verify/tilt_netshots_join
```

*(`g_aa41` = the stock Godot 4.6.2 binary under a private name, and
`--port=9412`: several agents ran two-instance probes on this machine
tonight — the default port 8910 was being claimed by foreign probe clients
mid-run, and blanket `taskkill godot` cleanups from neighbouring lanes killed
two earlier attempts. Same binary, same code, private port. The join must
launch a few seconds AFTER the host: the netprobe host claims seat 0 for its
keyboard human ~1 s after boot, and a faster join gets granted seat 0.)*

Scripted end-to-end: client connects on 9412 → granted seat 1 (BLUE, REMOTE)
→ deterministic tape strolls + READY → host starts the night → GET READY
gate answered over the wire → **TILT**, two full rounds with a remote
seat 1. The mirror booted on the client (`NET mirror boot: tilt` /
`TILT_MIRROR boot players=4 my_seat=1`; host sim `begin players=4
seed=3300865038 rounds=2 bots=[false, false, true, true]` — seat 0 the
host's keyboard human, seat 1 the remote tape, two bots) and tracked every
phase edge the host logged — `TILT_MIRROR phase -> INTRO/PLAY/ROUND_END`
twice over, then `MATCH_END`, pairing 1:1 with the host's `round_start`/
`round_end`/`match_end`. The night put everything on the wire at once:
9 gull bombs from the fallen BLUE (`guano p1` ×9 — the tape's A presses
riding the phase-1 relay to a seagull), coins carried to GOLD's ×4 stack,
two clashes, sudden death in BOTH rounds, a full round-2 OVERTIME
(`overtime start standing=2 gain=2.40x`), two last-stand wins, and
`TILT_MIRROR match winner=3` = exactly the host's placements `[3,2,1,0]`
(MINT 13, GOLD 11, BLUE 2, RED 0). The round-2 → MATCH_END transition kept
the final tableau on the mirror (the rn bump into match end deliberately
does not scrub the board — the matchend pair below shows the same two gulls
still airborne on both screens). Module `finished()` folded the client
mirror (`NET mirror fold`) → spectate card → mirrored reckoning → both
instances quit clean: `NETPROBE_RESULTS RED:pts=1,grudge=5 BLUE:pts=2,
grudge=5 GOLD:pts=3,grudge=4 MINT:pts=5,grudge=1`, `NETPROBE saves
restored`, `NETPROBE_DONE` / `NETPROBE_CLIENT_DONE`.

### NETHASH_MOD — mirror integrity + bandwidth (seq-keyed, never wall clock)

- Module channel: the host printed 30 `NETHASH_MOD` digests (every 40th
  snapshot, seq 40…1200); the client matched **29/29 of the snapshots that
  arrived — zero mismatches**. seq=960 never reached the client: one
  dropped datagram on the unreliable_ordered channel, exactly the loss
  class the counters-not-events pattern absorbs — the next snapshot healed
  everything and no mirror hiccup is visible anywhere in the client log.
- Walker channel (phase 1, still running underneath): **84/84 paired**
  (one drop, seq=675, same class).
- **Bandwidth, measured at the pump** (`bytes=` = `var_to_bytes` of the
  full module snapshot): min 924 / median 1052 / mean 1028 / max 1072 bytes
  across 30 samples spanning idle, 4-pawn brawls, gulls + splats + coins
  and the match-end banner. At the 20 Hz pump that is **≈21 kB/s per
  guest** — séance-class, "state, not pixels."

### Screenshots (read by eye)

**The tilting pair — one platter, two machines:**

- `tilt_netshots_host/snap_net_tilting_1869.png` vs
  `tilt_netshots_join/snap_mirror_tilting_3383.png` — each side fired its
  snap from the same condition (its own RENDERED tilt crossing 8°). Near
  pixel-identical: ROUND 1/2, timer 23, all four pawns on the same spots of
  the same-attitude disc (witch-hat GOLD north with the coin at its feet,
  knight RED center, the same platter shadow), same quadrant markers, same
  all-zero scoreboard. The mirror's platter is a 60 fps exponential chase
  of a 20 Hz vector, and it lands on the host's frame.
- The client's PLAY-entry snap (`join/snap_online_client_game_3033.png`)
  caught the "TILT!" kick floaty mid-pop — mirror juice firing locally, one
  beat after the host's own PLAY snap (`host/snap_online_host_game_1721.png`,
  same board at timer 25).

**The match-end pair — the same story down to the gulls:**

- `host/snap_net_matchend_5329.png` vs `join/snap_mirror_matchend_11661.png`
  — identical banner (`MINT WINS TILT!` in mint), identical scoreboard
  (RED 0 GULL / BLUE 2 GULL / GOLD 11 GULL / MINT 13 ×3 coins), the same
  overtime-hardened platter glowing hot, MINT cheering at the same spot,
  and the two dead players' gulls hovering at the same two points off the
  east rim.
- The one divergence is the DESIGNED one: the host's hint bar shows ITS
  human's state (`SPLASH! YOU'RE A SEAGULL — MOVE to fly · A = drop a
  BOMB`, seat 0 fell), the mirror shows ITS OWN seat's
  (`BLUE IS A SEAGULL — W/A/S/D fly · Space = drop a BOMB`) — per-machine
  controls, better information than mirroring the host's keys.

**Flow shots:** `join/snap_online_client_lobby/ready/gate` (the phase-1
lobby mirror alive and well), `host/snap_online_host_claim/ready/gate`, and
the paired reckonings — `host/snap_online_host_reckoning_5805.png` (THE
RECKONING ladder: MINT #1 +5 / GOLD #2 +3 / BLUE #3 +2 / RED #4 +1) vs
`join/snap_online_client_reckoning_12792.png` (the same four rows on the
client's online-night panel).

### Couch receipts — the transport did not perturb the sim

All baselines from a PRISTINE `git worktree` of HEAD (d0a1f18) vs this
working tree:

```
godot --headless --path . res://minigames/tilt/tilt.tscn -- --tilttest=idle --seed=1   # PASS both
godot --headless --path . res://minigames/tilt/tilt.tscn -- --tilttest=edge --seed=1   # PASS both, off at t=0.83
godot --headless --path . res://minigames/tilt/tilt.tscn -- --tilttest=gull --seed=1   # PASS both:
        # cause=gull_assist killer=1 victim=0 royalty_p1=true t=0.62  (v1.2 credit chain)
godot --headless --path . --fixed-fps 60 res://minigames/tilt/tilt.tscn -- \
        --tiltbots --seed=7 --roundtime=30 --rounds=3 --quitafter=7400
```

- All three `--tilttest` receipts: **byte-identical** (every `TILTTEST` and
  `TILT_EVT` line) between pristine HEAD and this tree.
- The seeded 3-round soak: **236 `TILT_EVT` + `KILL_EVENTS` lines
  byte-identical** between pristine HEAD and this tree — falls, clashes,
  royalties, gull assists, scores, the full results contract.
- All four receipts were **re-run in full at the final code state, after
  the probe night** (fresh headless runs, pristine d0a1f18 worktree vs
  this tree): identical again — idle/edge/gull all PASS with the same
  event lines (gull: `cause=gull_assist killer=1 victim=0 royalty_p1=true
  t=0.62`), soak 236 `TILT_EVT` + `KILL_EVENTS` byte-identical.

### Regressions

```
godot --headless --editor --import --quit --path .          # clean (exit 0)
```

## Save discipline

`user://` (party_setup.json, prefs.json, estate_save.json, cosmetics.json,
saves/slot_1.json) backed up with md5 hashes before ANY run and restored
byte-identical after the last one. The netprobe additionally does its own
`.npbak` dance for party_setup/prefs per run.

## Honest limitations

- **Pawn/gull motion is quantized to 20 Hz + exponential chase** (rate 14 for
  pawns, 12 for the platter tilt). The platter is a slow-consequence
  transform (spring ω=4.2 → ~0.4 s response), so a 50 ms snapshot cadence is
  far inside its own smoothing — the tilt reads as continuous on the mirror.
- **Falling pawns lerp toward snapshot positions** instead of integrating the
  exact host ballistic; the tumble is local. Cosmetic-only (elimination is a
  host fact).
- **Mirror bombs are cosmetic clones** launched from the gull's mirrored
  position; their landing puff can be a few cm from the host's. The slip
  SPLAT (the gameplay object) rides the wire as a list and is exact.
- **The mirror's own screen shows its own actions at snapshot latency**
  (spec §4.2 "local echo v1: none").
- **Host slow-mo beats arrive as slowed snapshots** — the mirror never
  touches `Engine.time_scale`, it just renders the slowed stream (and skips
  the local slow-mo entirely).
- **Mirror gravestone/decor RNG:** none in tilt (world build is seed-free);
  noted here because the mower doc needs the same caveat and agents copy
  these files.
- Killcam-skip gating (spec §1.2.2) — tilt has no killcam; still an open
  phase-2 chore elsewhere.
- The podium after `finished()` is not mirrored (spectate card, phase-3).
