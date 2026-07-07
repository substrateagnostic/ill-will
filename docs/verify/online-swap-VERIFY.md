# ONLINE PHASE 2 — SWAP MEET game mirror (verification)

*Built to `docs/design/10-online-first-architecture.md` §4.3 and the house
pattern (`docs/verify/online-seance-VERIFY.md` PATTERN NOTES; arena
reference `minigames/throne/throne.gd`). SWAP MEET is the racing mirror —
the one where interpolation quality IS the game feel — and the home of the
PHOTO FINISH, whose freeze-tick ceremony had to cross the wire faithfully.
Files touched: `minigames/swap_meet/swap_meet.gd` (+~400: mirror vars,
begin() fence, `_net_state()`/`_net_apply()`/`_mirror_tick()`, fact taps on
the flashers/rituals, the `--swapnetdemo` probe rig), `swap_kart.gd` (+8:
one-shot anim counter facts), `swap_orb.gd` (+1: wire id).
`core/net_session.gd` and `estate/estate.gd`: NOT touched — the phase-2
shell pump is generic.*

## What was built

- **Host sim untouched.** The host runs the whole race exactly as couch; the
  estate pumps `_net_state()` at 20 Hz (unreliable_ordered ch 4, latest-seq
  wins).
- **`_net_state()`** (host): one flat dict of PUBLIC facts. Karts ride `kd`,
  a PackedInt32Array of stride-12 entries (x/y/z cm, heading-yaw mrad,
  speed, steer, PROGRESS cm, a flag word — drifting / boost tier / finished
  / golden / swap-immune / locked / airborne / on-shortcut / orb-ready —,
  drift charge, finish place, and a one-shot anim id+counter). Orbs ride as
  id-keyed rows (pos + golden + owner). Around them: phase, authoritative
  race clock, laps, the FINAL-LAP flip, positions-independent `pts`, the
  crown owner, boom sweep angles, the golden-pickup spot, and the ritual
  counters — swaps (with both teleport positions), photo finishes (winner/
  chaser/delta), knocks, wall thuds, gate pulses, golden claims, overtake
  stings — plus `[gen, text]` replay facts for the banner and the event
  line, and the pre-announced champ.
- **`_net_apply()`** (client): the same `swap_meet.tscn` booted with
  `config.net_mirror = true`; begin()'s mirror branch builds track, karts,
  crown and HUD, skips bots/countdown/sim, and waits for the first
  snapshot. **Everything the couch feels fires from deltas**: SWAPPED!
  rituals replay both teleport beams + shake + sink at the exact wire
  positions; the PHOTO FINISH counter fires flashbulb + FOV punch + double
  confetti NOW and the reveal pop (+second flashbulb + win sting) on the
  same 0.55 s real-time timer the host uses, so both screens beat together;
  knock/thud/gate/claim/sting counters fire their couch juice; kart flag
  EDGES fire ramp-launch putt, landing burst, boost tiers, finish cheers;
  orb-id vanishes burst at the last known spot; banner + event line replay
  the couch's own `_flash_banner`/`_flash_event` off the gen facts.
  **Because progress/finished/place ride the block, the ladder HUD,
  `_positions_list()`, the lap label and THE FINAL STRETCH distance ladder
  all run on the client through the very same functions the host runs.**
- **`_mirror_tick()`** (client, per physics tick): exponential glide
  (`k = 1-exp(-18·dt)` — racing NEEDS smooth) of every kart toward its
  authoritative pose, heading slerped through the kart's own `_orient`
  (so lean/wheel/drift-spark presentation in `SwapKart._process` keeps
  working untouched); orbs interpolate faster (`-30·dt`); SWAP teleports
  snap (distance > 4), never glide; crown glued to the mirrored leader with
  local bob/spin; golden pickup bobs locally; windmill booms sweep at their
  true constant speed locally and get resynced by every snapshot.
- **THE FINAL STRETCH on the mirror** (lesson 2): `play_started` on first
  snapshot, `escalate` off the `fl` (FINAL LAP) flip, `match_ended` off the
  first finished-flag edge, and the last-10% distance ladder from mirrored
  progress via the host's own `_stretch_tick()`. Zero extra bytes beyond
  the flip — the ladder reads facts the HUD already needed.
- **PHOTO FINISH and lesson 1:** the ceremony's facts (`pf` counter +
  winner/chaser/delta) are minted in `_photo_finish`, which fires when the
  FIRST kart crosses — always many seconds (and ≥ the END beat's 1.8 s
  report delay) before `report_finished()` stops the pump, so the freeze
  ceremony can never be eaten by the pump's death. The champ fact is minted
  at race END, 1.8 s before the report (swap already had the delay —
  nothing to fix, verified live: the mirror confettied before the fold both
  nights).
- **Input: ZERO swap code.** The remote seat's tape strolled (steering its
  kart via the relay's move vector) and its A presses THREW SWAP ORBS
  across the wire — `THROW t=1.6 p=1` in night 1 with no swap input
  changes.
- **No hidden info** in a kart race — nothing rides the private channel.

## Evidence

_(two-instance probe on one machine, spec §7; port 9617 + privately named
binary `g_es93`, same discipline as the echo lane; all screenshots WINDOWED
and read by eye. Two nights: night 1 = organic 3-lap race
(`online-swap-host.log`/`online-swap-client.log`), night 2 = the
`--swapnetdemo` photo-finish dash
(`online-swap-*-photofin.log`).)_

### Commands

```
# night 1 — organic race (real selector, swap-only pool):
g_es93 --path . --position 60,60  -- --net=host --port=9617 --netprobe=host \
       --pool=swap --seed=11 --quitafter=200000 \
       --outdir=docs/verify/swap_netshots_host
g_es93 --path . --position 700,120 -- --net=join=127.0.0.1:9617 --nettape \
       --netprobe=join --quitafter=200000 --outdir=docs/verify/swap_netshots_join

# night 2 — the PHOTO FINISH rig (--swapnetdemo: at GO, restage as a 1-lap
# dash whose two BOT karts start 12.0/12.4 units before the line so the real
# _finish_kart path fires a genuine photo finish; one scripted orb drop at
# GO+4.2 s guarantees the SWAPPED! ritual on the wire; probe-only flag):
g_es93 --path . --position 60,60  -- --net=host --port=9617 --netprobe=host \
       --pool=swap --swapnetdemo --seed=5 --quitafter=200000 \
       --outdir=docs/verify/swap_netshots_host_pf
g_es93 --path . --position 700,120 -- --net=join=127.0.0.1:9617 --nettape \
       --netprobe=join --quitafter=200000 --outdir=docs/verify/swap_netshots_join_pf
```

### Night 1 — the organic race, end to end

Client connects → seat 1 (BLUE, REMOTE) → tape strolls + READY → real
auction (swap pool) → GET READY gate answered over the wire → **SWAP
MEET**, mirror up during the countdown (`SWAP_MIRROR boot players=4
my_seat=1`). A full 3-lap race: the remote kart steered by the relay's
analog move and THREW orbs on its tape's A presses (`THROW t=1.6 p=1` among
50 throws — none happened to connect in this sparse two-bot field; the
SWAPPED! ritual receipt is night 2's job); overtake stings at t=2.4/41.2/
47.1 mirrored off the counter (`OVERTAKE t=2.5/41.2/47.1` client-side, one
beat apart); `GOLD_SPAWN t=40.0` → pickup up on both screens →
`GOLD_CLAIM t=44.8 p=2` (claim burst off the counter, [GOLD ORB] on the
mirrored ladder); FINAL LAP called and escalated on both machines
(pair below); MINT wins P1 at 47.1 s, all four karts finish (the idle host
kart and the remote tape kart auto-throttle their way home — DNF-free),
`SWAPMEET_RESULTS` reported, mirror folded, match podium + RECKONING
mirrored, `NETPROBE_RESULTS RED:pts=1,grudge=3 BLUE:pts=2,grudge=3
GOLD:pts=3,grudge=1 MINT:pts=5,grudge=2`, saves restored, both quit clean.

### Night 2 — the PHOTO FINISH, across the wire

`SWAP_NETDEMO staged 1-lap photo dash line=95.1` at GO →
`PHOTO_FINISH t=2.8 winner=2 chaser=3 margin=1.04u delta=0.21s` through the
REAL `_finish_kart` path → client `SWAP_MIRROR photo_finish winner=2
chaser=3` — freeze-tick pinning, flashbulb, FOV punch, double confetti and
the two-beat banner reveal on BOTH screens (pairs below). Then
`SWAP_NETDEMO scripted orb drop 0 -> 1` → `SWAP t=4.5 thrower=0 victim=1`
→ client `SWAP_MIRROR swap a=0 b=1` — the full SWAPPED! ritual mirrored
(the REMOTE player's kart traded places with the host's:
`BLUE pickpocketed 1 place from RED` in the results). All four karts
finish the short lap, `SWAP_MIRROR champ=2` lands before the fold, night
runs to the mirrored reckoning, saves restored, both quit clean. **Zero
script errors in all four logs of both nights.**

### Screenshots (read by eye; `swap_netshots_host[_pf]/` + `swap_netshots_join[_pf]/`)

- **The mid-race pair:** `host/snap_net_midrace_4889.png` vs
  `join/snap_mirror_midrace_4339.png` — both at 0:08, LAP 1/3, the same
  four karts at the same track spots (GOLD leading under the crown, RED and
  MINT nose to tail, BLUE trailing), ladder identical to within one
  gate-pulse snapshot beat (P3 MINT ·3 vs ·2), even the boom arms at the
  same sweep angle.
- **The FINAL LAP pair:** `host/snap_net_finallap_8215.png` vs
  `join/snap_mirror_finallap_7703.png` — "FINAL LAP!" banner at the same
  0:31 clock, GOLD crossing under the crown halo, MINT and BLUE at the same
  spots, ladder GOLD 8 / MINT 8 / BLUE 6 / RED 3 on both. The lap labels
  straddle the line-cross itself (host still "LAP 2/3" — its label
  refreshes on a 15-tick cadence — mirror already "LAP 3/3" from the
  streamed progress); the banner is the shared truth.
- **THE MONEY SHOT — the photo-finish pair:**
  `host_pf/snap_net_photofinish_3966.png` vs
  `join_pf/snap_mirror_photofinish_3620.png` — both frozen at 0:02,
  LAP 1/1, "PHOTO FINISH!" center-screen, GOLD and MINT pinned TOGETHER at
  the line under the FINISH arch with confetti bursting, RED and BLUE at
  the same lower-track spots, identical ladder (P1 GOLD·5 FIN / P2 MINT·0 /
  P3 RED·1 / P4 BLUE·1), the same "MINT LEADS — AIM AT THE CROWN" event
  line — and the mirror's frame caught mid-flashbulb (the white pop is the
  client's own, fired from the counter).
- **The reveal pair:** `host_pf/snap_net_photofinish_reveal_4029.png` vs
  `join_pf/snap_mirror_photofinish_reveal_3680.png` — both latched at
  +0.55 s local time, same 0:03 clock, same track state (GOLD+MINT FIN at
  the line, RED/BLUE at the same corners). The banners straddle one
  banner-gen beat: the host shows the reveal ("PHOTO FINISH — GOLD BY
  0.2s!") while the mirror's frame still shows the "MINT FINISHES P2!"
  flash the host had interleaved a fraction earlier — the same stream,
  ~0.2 s of replay skew; the reveal text lands with the next gen. The
  reveal's LOCAL juice (second flashbulb + win sting + confetti) fired on
  the mirror's own 0.55 s timer, visible as the fresh confetti at the line.
- **The SWAPPED! pair:** `host_pf/snap_net_swap_4207.png` vs
  `join_pf/snap_mirror_swap_3862.png` — "SWAPPED! RED <-> BLUE" with BOTH
  teleport beam columns risen at the two exchange sites, the karts trading
  spots (the two snaps latch independently, so the pair straddles the
  ritual ~0.3 s apart — beams up in both), GOLD + MINT parked FIN beyond
  the line.
- **The end pairs (both nights):** `snap_net_end_*` vs `snap_mirror_end_*`
  — winner banner + confetti from the pre-announced champ, karts still
  cruising behind it.
- **Flow shots:** client lobby/ready/gate/game + matching podium and
  reckoning pairs, as in every lane since phase 1.

### NETHASH_MOD — mirror integrity + bandwidth (seq-keyed, never wall clock)

- Night 1: **78/78 digest pairs identical.** Night 2: **5/5** (a 1-lap dash
  is short). Zero mismatches, zero drops. Walker channel: 191/191 and
  35/35.
- **Bandwidth (measured, `var_to_bytes`, every 40th snapshot):** night 1
  min 896 / median 1024 / max 1084 / mean 999 bytes → at 20 Hz **≈20 kB/s
  per guest** (≈60 kB/s at a full table of three guests). The kart block is
  4 × 12 × 4 = 192 B; the rest is the ritual counters + HUD strings.
  Comfortably inside the spec's "state, not pixels" posture; input relay
  upstream stays the phase-1 ≈1.2 kB/s.

### Couch receipts — the transport did not perturb the sim

Swap is hand-integrated (no physics bodies) and tick-deterministic by
construction, so the strongest receipt applies: **full event logs
byte-identical to a pristine `git worktree` of HEAD (ae60154)**, seeds
1 / 2 / 11:

```
g_es93 --headless --path . res://minigames/swap_meet/swap_meet.tscn -- \
       --swapbots --seed=1|2|11 --fast=8 --autoquit
```

- Seeds 2 and 11: **byte-identical, whole log.** Seed 1: sim log
  byte-identical; the only diff ever seen is Godot's flaky exit-time
  ObjectDB warning, which a pristine rerun of the SAME seed also emits
  (run-to-run engine teardown noise, present on both trees, after the last
  sim line). Seed 11 re-diffed byte-identical again after the final edit
  (the `_drop_orb_on` victim-frame lead).
- Seed 1's tally matches the shipped VERIFY table exactly: `race_t=48.1s
  swaps=20 blocked=2 golden=1` — `SWAPMEET_ASSERT … PASS`.
- **`--swaptest=immunity` re-run: `swaps=2 blocked=1: PASS`** — the one
  shared test hook this lane touched (`_drop_orb_on` now drops in the
  victim's frame so the netdemo's MOVING target is still under the orb;
  parked swaptest karts have speed 0, so the hook's receipts are
  byte-unchanged, and the rerun proves it).

### Regressions (offline behavior untouched)

```
g_es93 --headless --editor --import --quit --path .                      # clean
g_es93 --headless --path . res://.../swap_meet.tscn -- --swapbots ...    # above
g_es93 --headless --path . res://.../swap_meet.tscn -- --swaptest=immunity --autoquit   # PASS
g_es93 --headless --path . -- --estate --auctiontest --quitafter=9000    # AUCTIONTEST PASS
g_es93 --headless --path . -- --estate --estatebots --quitafter=3200     # zero script errors
g_es93 --headless --path . -- --strolltest --quitafter=1200              # zero script errors
```

## Save discipline

Same manifest as the echo lane (the two lanes ran in one session):
`user://` five save files backed up with md5s before ANY run, restored and
re-verified byte-identical after the last one (party_setup D3E6350C…,
prefs 99914B93…, estate_save 0D8ACBF4…, cosmetics 2BE51EFA…, slot_1
0D8ACBF4…; no `.npbak` leftovers). Private port + private binary; only this
lane's own processes were started or killed.

## Honest limitations

- **The organic night produced 0 swap connects** (50 throws): with one
  idle human, one strolling tape and only two bots, traffic is far sparser
  than the 4-bot couch races that average 15+ swaps. The ritual's wire
  path is verified by night 2's scripted beat through the REAL
  `_resolve_hit`/`_do_swap` path; a table of four humans supplies its own
  traffic.
- **The mirror does not reproduce the tick-counted hit-stop** (swap freeze
  / photo freeze): the host's frozen karts simply stop moving in the
  snapshot stream, which reads as the same freeze one interpolation
  constant softer. Deliberate — a mirror must never stall its own clock.
- **Wall thuds collapse to one per snapshot** (`bo` is a counter + latest
  kart; several bounces inside 50 ms play once). Feel-level only.
- **The mirrored lap label derives laps from current progress** (floor of
  progress/lap-length) rather than the host's high-water counter — for the
  LEADER (whose lap the label shows) the two are identical; a kart swapped
  backward across the line could flicker a private lap count it never
  shows.
- **`--swapnetdemo` is a probe rig** (restage at GO + one scripted drop).
  It exists only behind its flag; every receipt above runs without it.
- **The mirror's hint bar** shows the client's local default bindings for
  all seats (same cosmetic gap as masked ball/echo; phase-3 polish).
- Both instances share one `user://` on a dev machine — probe-bounded,
  everything restored by hash after the runs.
