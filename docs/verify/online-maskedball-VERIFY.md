# ONLINE PHASE 2 — MASKED BALL game mirror (verification)

*Built to `docs/design/10-online-first-architecture.md` §4.3 and the house
pattern (`docs/verify/online-seance-VERIFY.md` PATTERN NOTES, copied verbatim
where they are the pattern). MASKED BALL is the identity-hiding game — the
most interesting privacy case of the phase, and the cheapest: its secret model
is "ZERO on-screen secret delivery", and that property crosses the wire for
free if you mirror faithfully and never tag ownership. Files touched:
`minigames/masked_ball/masked_ball.gd` (+~580: event ledgers,
`_net_state()`/`_net_apply()`/`_mirror_tick()`, the `--mbnetdemo` probe rig),
`minigames/masked_ball/mb_dancer.gd` (+24: untagged glint counter,
`walking()`/`dimmed()` accessors, `mirror_act()` pose setter).
`core/net_session.gd` and `estate/estate.gd`: NOT touched — the phase-2 shell
pump is generic; masked ball just exposes the two contract methods.*

## What was built

- **Host sim untouched.** The host runs the whole ball exactly as couch; the
  estate pumps `_net_state()` at 20 Hz (unreliable_ordered ch 4, latest-seq
  wins) because the module exposes the method — no estate edits.
- **`_net_state()`** (host): one dict of PUBLIC facts — the full field-by-field
  audit is below. The heart is a `PackedInt32Array` of 20 × 7 quantized ints,
  **indexed by BODY id**: the four player bodies and sixteen NPC bodies stream
  the *same seven fields in the same shape*, and nothing in the array says
  which is which.
- **`_net_apply()`** (client): drives a RENDER MIRROR — the same
  `masked_ball.tscn` booted by the client estate with
  `config.net_mirror = true`. The mirror branch of `begin()` builds the
  ballroom and twenty pawns on a plain ring (no rng consumed, **no deal** —
  `_body_of` stays empty on the client machine) and fences the deal, the bots
  and the intro kick. `_physics_process` opens with the house guard
  (`if _mirror: _mirror_tick(delta); return`). **All juice fires from deltas
  and cumulative rows** (latest-wins snapshots may drop; counters and
  append-only rows lose nothing but in-between frames): per-body glint-counter
  deltas fire `glint()`, `gone` flag edges fire the corpse fade, `dim` edges
  darken the hired bodies at the last dance, unmask/waste/survivor rows fire
  the badge reveals + seat-pitch ticks + shake + floor-mask monument +
  spotlight, the unnamed curtsy count pulses the throne ring + coin clink,
  ghost rows spawn the pew wisps and gust counters fire their ripple + crowd
  wobble, ledger rows read out the settlement, the champ fact fires
  confetti + the win sting, and banner/sub/executor/HUD strings ride as text.
- **`_mirror_tick()`** (client, per physics tick): exponential glide of all
  twenty dancers toward authoritative x/z + facing, local decay of `act_t`
  (smooth bow/twirl tilt between 20 Hz snaps) and `flash_t`, ghost-wisp glide,
  the waltz metronome, camera-shake decay.
- **Input: ZERO masked-ball code.** The waltz loop polls `PlayerInput` per
  seat; remote seats arrive through the phase-1 `_remote` seam untouched. The
  feather band (stick magnitude 0.15–0.5) rides the relay's `move: Vector2`
  verbatim — an analog magnitude survives the wire, so the private pulse
  needs no adjustment at all.
- **`send_module_private`: NOT USED — and that is the finding.** The couch
  has no private beat: every glint is publicly visible to the whole room; only
  the *correlation* with your own hidden stick gives one of them meaning. A
  correlation between a public event stream and your own hands is a secret no
  packet can carry and therefore no packet can leak. Masked ball is the
  spec's "zero secret delivery" pitch, and the transport honors it by
  carrying nothing.
- **One host-side fix found by the probe:** `report_finished()` stops the
  estate's 20 Hz pump the same tick it runs, so a champion fact set inside
  `_finish_match()` never reached the mirror (night 1: the client missed the
  confetti). `_begin_reveal` now pre-announces `[champ_seat, champ_body]` one
  seq-beat (0.4 s) before `_finish_match` — points are final since survival
  pays at reveal entry. Memory-only on the couch; tally re-diffed
  byte-identical after the change.

## THE SNAPSHOT PRIVACY AUDIT — field by field

*The claim to verify: a packet-sniffing player must learn nothing the couch
doesn't show. Every key of `_net_state()`, audited:*

| key | contents | seat↔body leak analysis |
|---|---|---|
| `seq` | pump counter (estate adds) | none |
| `ph` `wt` `wl` | phase + waltz clock/length | public HUD facts |
| `d` | `PackedInt32Array`, 20 bodies × 7 ints: x (cm), z (cm), yaw (mrad), act, act_t (cs), flags (walk·1 / revealed·2 / gone·4 / dimmed·8), **glint count** | **BODY-indexed, no seat field anywhere.** Player and NPC bodies emit identical fields at identical 1 cm / 1 mrad quantization — no precision channel separates them. The glint counter is bumped by NPC decoys, feather pulses and kill lunges alike, UNTAGGED: the wire says "this mask glinted", never "whose hand did it". `revealed`/`dimmed` bits flip only at reveal beats the couch also shows. |
| `gh` | 4 seats × [eliminated, ghost x, z] | seat-keyed but nonzero **only after that seat's unmask row** — dead is already revealed (ghosts carry name + color on the couch too) |
| `gu` | per-seat gust counters | ghosts only (same as above) |
| `crt` | scored-curtsy COUNT | unnamed, exactly as the Executor announces it. The mirrored crowd shows every concurrent bow, so deniability-by-parallelism survives: the wire tells you *when* somebody bowed for money, and the same twenty dancers to squint at |
| `rev` | cumulative rows [kind, seat, body, killer] | **THE ONLY seat↔body pairs on the wire.** Each row is minted in `_unmask_human` / `_reveal_survivor` at the exact frame the couch stamps the badge/name on screen. Before the reveal, no row exists |
| `wst` | cumulative rows [accuser_seat, accuser_body] | minted with the waste-flash — the self-inflicted position leak, public by design |
| `led` | settle rows [text, color] | reveal phase only |
| `champ` | [seat, body] | set at reveal t_end+0.4 s, when every body is already public |
| `ban` `sub` `exec` `pl` `info` `tmr` | HUD strings | audited line-by-line: intro/waltz lines generic; pip lines unnamed; the only NAMED strings (unmask banner, waste banner, ghost-haunt line, winner line, ledger) fire at reveal moments, identical to the couch. `info` is aggregate (dancer count / humans left / marks unspent) |

**What NEVER enters the dict:** `rng_seed` (the client estate boots every
mirror with `rng_seed: 0` — the seeded deal `_spawn_crowd()` shuffle is not
recomputable remotely), `_body_of` / `body_to_seat` for unrevealed seats,
per-seat pips/marks/points mid-round (aggregates only; per-seat numbers appear
first in the reveal ledger, as on the couch), bot suspicion tables, NPC brain
state (waypoints, pause timers, **decoy glint timers** — all drawn from
`crowd_rng`, which lives only on the host, so a client cannot even *predict*
which glints are decoys).

**The client machine holds no mapping:** in mirror mode `_body_of` is cleared
and never filled; `body_to_seat[b]` is written only when a reveal row arrives.
Until the couch would print a badge, the mapping physically does not exist in
client memory — there is nothing for a memory-reading cheat to find.

**Verdict: the snapshot leaks no fact the couch does not show.** The honest
delta is *recall*, not *content* — see limitations.

## Evidence

_(two-instance probe on one machine, spec §7; port 9473 and a privately named
binary copy (`g_mb52`) because several agents ran probes on this machine
tonight; all screenshots WINDOWED and read by eye. Night 2 below is canonical;
night 1 — identical story before the champ pre-announce fix — is archived as
`*-night1.log` / `mb_netshots_*_night1/`.)_

### Commands

```
# host (real selector, maskedball-only pool, --mbnetdemo = 90 s waltz +
# photo-mode bots + ONE scripted reveal beat at ~40 s):
g_mb52 --path . --position 60,60  -- --net=host --port=9473 --netprobe=host \
       --pool=maskedball --mbnetdemo --seed=7 --quitafter=200000 \
       --outdir=docs/verify/mb_netshots_host

# join (NO --nettape — see "a remote hand on the real pipe" below):
g_mb52 --path . --position 700,120 -- --net=join=127.0.0.1:9473 --netprobe=join \
       --mbnetdemo --quitafter=200000 --outdir=docs/verify/mb_netshots_join
```

**A remote hand on the REAL pipe (probe honesty note).** The built-in NETPROBE
tape only produces unit-vector strolls and A pulses — it can never *feather*
(an analog magnitude in 0.15–0.5), so it could never demonstrate the private
pulse. The join therefore runs WITHOUT the tape: once the mirror is up, a
`--mbnetdemo` client script drives ITS OWN seat through
`PlayerInput.set_remote_state()` — the `_dbg_aim` pattern, networked, i.e. the
exact seam NetSession itself injects remote seats through — so NetSession's
30 Hz sampler reads it and streams **genuine input packets** to the host:
stroll, an 8 s FEATHER at 0.30, one B mark, a bluff curtsy, more strolling.
Only the hand is synthetic; sampler, wire, host injection and host sim are the
production path end to end. Without the tape the lobby READY times out after
30 s (probe flow proceeds regardless) and the GET READY gate launches on its
15 s countdown (`waiting on BLUE · begins in 15s` — photographed) — both
estate-standard paths, zero estate edits.

### The night, end to end (both nights, same story)

Client connects on 9473 → granted seat 1 (BLUE, REMOTE) → lobby-ready timeout
→ host starts the night → REAL auction (bots bid; maskedball-only pool) → GET
READY gate lapses its countdown → **MASKED BALL**: `MB_BEGIN players=4
seed=3300865038 bots=[false, false, true, true] waltz=90` (seat 0 the host's
keyboard human, seat 1 the remote, two bots), the deal lands `MB_SELF seat=1
BLUE body=13`, and the mirror boots on the client (`NET mirror boot:
maskedball` / `MB_MIRROR boot players=4 my_seat=1`) already inside the INTRO —
no spectate card. Then, all across the wire:

- **The feather-glint (THE receipt of this lane).** The client script
  feathers 0.30 from wt 13–21. Host: `MB_GLINT seat=1 body=13` at
  **t = 13.0 / 14.4 / 15.8 / 17.2 / 18.6 / 20.0** — the exact 1.4 s GLINT_CD
  cadence, driven by relayed analog input. Client:
  `MB_MIRROR_GLINT body=13` at **wt = 13.1 / 14.4 / 15.8 / 17.2 / 18.6 /
  20.1** — 6/6 pairs, worst skew 0.1 s (one snapshot beat). And in the SAME
  window the mirror rendered **43 glints total** — 37 decoy glints on other
  bodies, indistinguishable in the dict. Only the correlation with the
  client's own (hidden) stick timing picks body 13 out of the noise, which is
  precisely the couch mechanic, preserved.
- **The remote's one mark.** The script presses B at wt 23; the press rides
  the sampler/wire/edge-rescue path and the host resolves it: `MB_MARK
  killer=1 BLUE victim=3 MINT body=4 t=23.0` (night 1: t=23.1) — an
  **unmask-HUMAN by the remote player**, 0.5 s after MINT bowed for a pip.
  Client: `MB_MIRROR unmask victim=3 body=4 killer=1`, badge + ring + death
  reaction + falling mask + floor monument + MINT's ghost pew, photographed
  on both screens.
- **The scripted beat adapted.** Because an unmask already existed, the
  `--mbnetdemo` host beat had seat 2 (bot) accuse the furniture instead:
  `MB_FLASH seat=2 GOLD body=2 npc=18 t=41.1` (night 1: 40.5) → the waste
  flash + GOLD badge on both screens.
- **Ghost pews live.** MINT's bot ghost gusted ~13 times (`MB_GUST seat=3`),
  each ripple + crowd shiver mirrored via the gust counters.
- **The remote worked the throne.** The injected strolls happened to cross
  the circle during scripted A presses: `MB_CURTSY seat=1 BLUE pip=1/3 t=51.2
  set=[13]`, `pip=2/3 t=69.2 set=[8, 13]`, `pip=3/3 t=87.2 set=[13, 16]` —
  three SCORED curtsies from across the wire, each announced unnamed with its
  deniability set (note MINT's pip at 22.6 had `set=[4, 11]` — two suspects).
- **The last dance.** `MB_REVEAL survivors=[0, 1, 2]`; the mirror dimmed the
  sixteen hired bodies from the flag bits and revealed survivors row by row
  (`MB_MIRROR survivor seat=0/1/2 body=15/13/2`) with spotlight + seat-pitch
  ticks; the ledger read out identically on both screens; the pre-announced
  champ fact landed (`MB_MIRROR champ seat=1 body=13`) → confetti + win sting
  on the mirror before the fold. **BLUE — the remote player — took the ball:
  16 pts, 3 curtsies, unmasked MINT, survived, "BLUE, Belle of the Ball"
  monument.** `MB_RESULTS` identical both nights (points 4/16/7/2, placements
  [1,2,0,3]).
- Module finished → `NET mirror fold` → spectate card for the podium beat →
  mirrored RECKONING ladder (`NETPROBE_RESULTS RED:pts=2,grudge=3
  BLUE:pts=5,grudge=3 GOLD:pts=3,grudge=5 MINT:pts=1,grudge=3`, both nights
  byte-equal) → `NETPROBE saves restored` → both instances quit clean. Zero
  script errors in all four logs.

### Screenshots (read by eye; `mb_netshots_host/` + `mb_netshots_join/`)

- **The waltz pair** — `host/snap_mb_net_waltz_13086.png` vs
  `join/snap_mb_client_waltz_4780.png`: both timers read 70, identical info
  line (`DANCERS 20 · HUMANS AMONG THEM 4 · MARKS UNSPENT 4`), the same
  twenty-dancer formation body for body (the throne-circle cluster, the lone
  drifter on the left, the pair on the carpet). Twenty IDENTICAL hooded
  dancers, no badge, no ring, no tag anywhere — the anthology's one identity
  exception, intact on the wire. Deliberate divergence visible: the host's
  hint bar shows its real KBM keys (`Space = CURTSY · E = UNMASK`), the
  mirror shows the generic legend.
- **The client's own glint moment** — `join/snap_mb_client_glint_4540.png`,
  latched at wt ≥ 15.9 (timer reads 75): a freshly lit mask in the throne
  cluster one beat after host `MB_GLINT seat=1 body=13 t=15.8`. The shot
  shows *a* glint like any decoy; the log pairing (6/6 at 1.4 s cadence)
  is what names it — exactly the epistemics the design promises.
- **The unmask-HUMAN pair** — `host/snap_mb_net_unmask_13507.png` vs
  `join/snap_mb_client_unmask_5038.png`: both screens tell one story — timer
  67, `MINT WAS HUMAN` / `BLUE collects the unmasking`, the Executor's "One
  mask off. MINT, everyone…", the ◆ MINT ghost wisp risen, the fallen-mask
  monument by the throne, marks 4→3. (Client snapped +0.9 s, so the corpse
  has faded to ring + monument while the host still shows the fall.)
- **The furniture penalty pair** — `host/snap_mb_net_waste_16125.png` vs
  `join/snap_mb_client_waste_6099.png`: `GOLD MARKS THE FURNITURE` /
  `-3 · THEIR DANCER FLASHES` on both; GOLD's body strobing gold with its
  badge — the position leak rendered identically, one snapshot beat apart.
- **The last dance** — `join/snap_mb_client_lastdance_9222.png`: hired bodies
  dimmed to silhouettes (the dim bits), RED spotlit and unmasked with badge +
  ring, "RED, all along." — survivor theater fired on the mirror from rows.
- **The verdict pair** — `host/snap_settle_24937.png` vs
  `join/snap_mb_client_verdict_9773.png`: the same four ledger rows in the
  same colors (`BLUE — 3 curtsies · unmasked MINT · survived — 16 pts` …),
  all three survivor badges + rings, MINT's ghost, "GOLD, all along."
- **The reckoning pair** — `host/snap_online_host_reckoning_25823.png` vs
  `join/snap_online_client_reckoning_10110.png`: same ladder (BLUE #1 +5 …),
  the client card marked `BLUE (you) · REMOTE` — and on the host grounds, the
  blue **"BLUE, Belle of the Ball"** plinth.
- **Flow shots**: `join/snap_online_client_lobby/ready/gate` (the gate card
  reads `waiting on BLUE · begins in 15s` — the tapeless countdown path),
  `join/snap_online_client_game_3479.png` (mirror already up during INTRO).

### NETHASH_MOD — mirror integrity + bandwidth (seq-keyed, never wall clock)

- **Night 2: 47/47 digest pairs identical. Night 1: 48/48.** Zero mismatches
  across both nights. The phase-1 walker channel stayed clean too:
  **162/162** NETHASH pairs identical (night 2).
- **Bandwidth (measured, `var_to_bytes` of the full snapshot, every 40th):**
  night 2 min 1280 / median 1372 / max 1796 / mean 1363 bytes (night 1:
  1280/1376/1796/1370). At 20 Hz that is **≈27 kB/s per guest** (~82 kB/s at
  a full table of three guests). The 20-dancer block is the pre-quantized
  `PackedInt32Array` (20×7×4 = 560 B raw) — the "quantized positions"
  option from the lane brief, taken up front; the 1796 B ceiling is the
  settle beat carrying all four ledger strings. Comfortably inside the
  spec's "state, not pixels" posture; input relay upstream stays the
  phase-1 ≈1.2 kB/s.

### Couch tally receipt — the transport did not perturb the sim

`--mbtally` from a PRISTINE `git worktree` of HEAD (d36154f) vs this working
tree, seeds 1 / 2 / 3:

```
g_mb52 --headless --path . res://minigames/masked_ball/masked_ball.tscn -- --mbtally --seed=N
```

- **FULL LOGS byte-identical, all three seeds** — every `MB_*`, `MBBOTS_*`,
  `KILL_EVENTS`, `MB_RESULTS` line and the whole
  `======== MASKED BALL TALLY ========` block (seed 1: `unmasks=1 wastes=0
  survivors=["RED","GOLD","MINT"]`, points `RED=16+ BLUE=4x GOLD=10+
  MINT=8+`). The only diff ever seen was a one-time editor UID-cache warning
  on the very first run after the import pass; the rerun was byte-identical
  including boot lines.
- Re-diffed after the last edit (the champ pre-announce): seeds 1, 2 and 3
  byte-identical again.

### Regressions (offline behavior untouched)

```
g_mb52 --headless --editor --import --quit --path .                      # clean
g_mb52 --headless --path . res://.../masked_ball.tscn -- --mbtally --seed=1|2|3
                                        # FULL logs byte-identical to pristine HEAD
g_mb52 --headless --path . -- --estate --auctiontest --quitafter=9000    # AUCTIONTEST PASS (fresh slot)
g_mb52 --headless --path . -- --estate --estatebots --quitafter=3200     # zero script errors
g_mb52 --headless --path . -- --strolltest --quitafter=1200              # zero script errors
```

(The saved run in `slot_1.json` sat at a night-5 boundary, which parks
`--auctiontest` at the resume card — it was run against a temporarily
set-aside slot and the file restored immediately after. The live probe
night itself also exercises the REAL auction with the maskedball pool.)

## Save discipline

`user://` (party_setup.json, prefs.json, estate_save.json, cosmetics.json,
saves/slot_1.json) backed up with md5 hashes before ANY run and restored
byte-identical after the last one — all five md5s re-verified on restore
(party_setup D3E6350C…, prefs 99914B93… (the md5 of `{}`), estate_save
0D8ACBF4…, cosmetics 2BE51EFA…, slot_1 D58E6E2E… — RESTORED-OK ×5, no
`.npbak` leftovers). The
probe itself also does its own `.npbak` dance for party_setup/prefs, as in
phase 1. Other agents ran probes on this machine the same night; this lane
used a private port (9473) and a privately named binary (`g_mb52`) so only
its own processes were ever started or killed. Only the canonical night-2
shot dirs are committed; night-1 logs are kept as the pre-fix receipt.

## Honest limitations

- **Perfect recall is the one true delta from couch epistemics.** The
  snapshot carries no fact the couch doesn't show — but a packet-logging
  client remembers public facts perfectly. Concretely: NPC decoy glints are
  never spaced closer than 2.0 s while the feather cooldown is 1.4 s, so a
  body glinting repeatedly at sub-2 s intervals is provably human to a tool
  (an attentive couch player can notice the same rhythm; the counter-measure
  is the same — feather sparingly). Likewise stillness, pip-timing
  coincidence and the 1.07–1.12× hunt stride are couch-visible tells that a
  log analyzes better than a memory. Spec posture: friends-lobby trusted,
  not an anti-cheat surface — but unlike a leaked deal, ALL of this is
  play-skill information the design already publishes.
- **Your own glint answers one RTT + one snapshot beat late** (loopback
  ≈ 0.1 s). Against the 1.4 s cooldown cadence the correlation channel is
  untouched; at 80 ms internet RTT it still will be.
- **The champion beat on the mirror is short** — the pre-announced champ fact
  gives the mirror confetti + sting ~0.5 s before the module folds to the
  (unmirrored) podium card. Podium mirroring remains the known phase-3 chore.
- **The mirror's hint bar shows the generic legend**, not the client's own
  keys (`describe_binding` reads "REMOTE" once the demo injector runs; a
  polish pass could personalize it for real clients).
- **Keyboard couch players cannot feather today** — keyboard `get_move` is
  binary, so the 0.15–0.5 band is pad-only ON THE COUCH; the wire changes
  nothing about this (remote pads feather fine, as the probe shows with an
  analog 0.30). Pre-existing design reality, noted for the record.
- **A headless host would stream `walk=0`** (`set_walking` early-outs without
  visuals), idling mirrored gaits. Hosts are windowed by design; noted.
- **--mbnetdemo is a probe rig** (photo-mode bots, one scripted beat, the
  client injector). It exists only behind its flag; couch/tally paths are
  byte-identical with it absent.
- Both instances share one `user://` on a dev machine — probe-bounded, and
  everything restored by hash after the runs.

## The design note worth keeping

The séance proved hidden info gets BETTER online (structural privacy via
`rpc_id`). The masked ball proves the opposite corner of the same theorem:
when a game's secret is a *correlation with your own body* rather than a
*fact*, the honest transport preserves it with zero machinery — the only
requirements are negative ones. Don't tag the glints. Don't ship the deal.
Don't let a seat number ride next to a body id until the couch would print
it. The audit above is a checklist of things NOT sent; the whole privacy
core of this port is absence, verified.
