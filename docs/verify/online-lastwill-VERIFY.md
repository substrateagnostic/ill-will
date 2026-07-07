# ONLINE PHASE 2 — LAST WILL game mirror (verification)

*Built to `docs/design/10-online-first-architecture.md` §4.3 and the house
pattern (`docs/verify/online-seance-VERIFY.md` PATTERN NOTES). LAST WILL is
the procession race whose course REMEMBERS: curses persist with authorship,
and the whole world freezes for six seconds while the dead redraw the road.
Both of those are the interesting mirror problems, and both crossed the wire:
the ACTIVE CURSE SET streams complete every snapshot (late-booting mirrors
rebuild the whole accreted road, plaques included), and the WILL DRAFT
freeze stops both screens while the same public theater plays on each.
Files touched: `minigames/last_will/last_will.gd` (+~600: wire-fact capture,
`_net_state()`/`_net_apply()`/`_mirror_tick()`, will/curse/boulder/ghost
sync, aim provider), `lw_pawn.gd` (+3 counters), `lw_boulder.gd` (+1 id),
`lw_curse.gd` (+1 stored seed). `core/net_session.gd` and `estate/estate.gd`:
NOT touched.*

## What was built

- **Host sim untouched.** The estate pumps `_net_state()` at 20 Hz because
  the module exposes the method — no estate edits.
- **`_net_state()`** (host), all PUBLIC facts: per-racer [alive, visible,
  pos, pivot yaw, anim, shove/hop cooldowns, hit counter + dir, shove
  counter] (13 fields); per-player lives / best_x / checkpoint / finished /
  total / deaths arrays (the hearts panel and the procession track); per-seat
  ghost rows [seated, HOST's pew slot, aim dir, gust cooldown]; per-seat gust
  counters + last-gust spawn row; hazard poses (pendulum blade angle + pivot
  height, spinner angle, wall phases — exact, not simulated); ACTIVE boulders
  [id, state, traveled + full spawn params]; the ACTIVE CURSE SET
  [install_order, slot id, kind, author, side seed, scythe pose / gale
  phase]; the WILL facts [active, deceased, step, clock, selection, locked
  card] + the three offered cards [kind, slot id, displacement line]; race
  index/total/elapsed/label, the world-freeze flag, banner/sub/Executor
  strings with colors, and the pre-announced champion.
- **`_net_apply()`** (client): the same `last_will.tscn` booted with
  `config.net_mirror = true`. `begin()`'s mirror branch freezes every pawn
  into a puppet (physics +自 process off; anim/rings driven by the tick) and
  fences races, bots and rng. All juice from deltas and rows:
  - **deaths** → burst + shake + splat/death + THE DECIDING MOMENT freeze
    when the mirrored lives table says one racer stands (banner text — shove
    line, curse kill line, royalties — rides the wire with its color);
  - **hit counters** → victim squash-pop + spark cone + layered thud +
    throttled micro-hitstop; **shove counters** → whoosh + windup coil + the
    readability arc along the mirrored facing;
  - **checkpoints** → claim chirp; **finishes** → the crypt doorstep tableau
    (Cheer loop + confetti + win sting), pre-announced by riding `fin` flags
    which the host mints at the finish tick while the pump still runs;
  - **ghost rows** → pew seating ON THE HOST'S PEW (slot rides the wire so
    seating order can never diverge), aim arrow + gust cooldown ring synced;
  - **gust counters** → the wave node spawns at the host's spawn row and
    flies locally (straight, ranged, deterministic — grazing sparks fire on
    the puppets exactly as the couch's soft-spite read);
  - **boulder rows** → replicas spawn from host facts and ROLL LOCALLY (the
    roll is deterministic over static geometry; a traveled-distance nudge
    corrects the one-beat spawn lag; squish checks fenced — deaths are host
    facts);
  - **curse rows** → `LWCurse.setup()` with the author's name/color and the
    HOST's side seed: identical grease sheen / gale corridor / stones rank
    gap / scythe keel AND the NAME PLAQUE, `play_install()` rising from the
    sod mid-race, displacement folding the resident the host displaced;
  - **the WILL** → `_ui.open` on the REVEAL beat (portrait, color frame,
    dim), `show_cards` with the wire's three cards, the deceased's cursor
    strolling via `set_card_sel` deltas, the drain bar interpolated, the
    lock pop, resolution lines + the camera pan to the condemned stretch +
    the skeletal hand, `close` and the camera home — while the freeze flag
    holds every living racer as a statue on BOTH screens and the ghosts
    keep swaying (their sway is local `_process`, never frozen);
  - **the champion**, pre-announced 0.4 s before `_finish_match` via a
    RACE_END sequencer event (the masked-ball lesson: facts minted the same
    tick as `report_finished()` never reach mirrors) → local win banner +
    confetti + sting.
- **The draft privacy question, answered honestly:** on the couch the will
  draft is PUBLIC — one shared screen shows the cards, the cursor and the
  clock to the whole room while everyone waits. So the mirror shows exactly
  the same theater and `send_module_private` is not used. Nothing hidden on
  the couch, nothing hidden on the wire.
- **`_mirror_tick()`**: racer glide + pivot yaw lerp, cooldown rings fed
  locally between snapshots, hazard poses glided to their exact mirrored
  phases (nadir whoosh detected on the mirrored swing), boulders/gusts/ghost
  cooldowns ticked only while the mirrored phase is RACE (so the will freeze
  stops the world), `race_elapsed` drains the timer + the FINAL STRETCH
  hard-cap ladder, and the race camera runs the couch's own framing logic
  over mirrored positions.
- **FINAL STRETCH kit facts carried:** race index + total (the FINAL RACE
  escalates on the flip, earlier races re-arm the light bed), `race_elapsed`
  against the hard cap (tick ladder + timer pulse), champ fact
  (`match_ended`).
- **Input: ZERO last-will code.** Racers poll `PlayerInput`; the ghost's
  gust aim rides the relay's `aim` vector, computed by the mirror's aim
  provider against its own ghost pew — the couch's own twin-stick
  convention, networked.

## Evidence

_(two-instance probe on one machine, spec §7; private port 9762, private
binary `g_orblw91`; all screenshots WINDOWED and read by eye. Probe pins:
`--willrounds=2` keeps the night inside the rig's podium window;
`--willkill=6:1,16:1,26:1` (the `--seancechar` precedent — loud, never real
play) walks the REMOTE seat through three deaths so the will theater, the
plaque and the ghost pew are all guaranteed on film.)_

### Commands

```
# host (real selector, lastwill-only pool):
g_orblw91 --path . --position 60,60  -- --net=host --port=9762 --netprobe=host \
          --pool=lastwill --willrounds=2 --willkill=6:1,16:1,26:1 --seed=7 \
          --quitafter=200000 --outdir=docs/verify/lw_netshots_host

# join (deterministic NETPROBE input tape):
g_orblw91 --path . --position 700,120 -- --net=join=127.0.0.1:9762 --nettape \
          --netprobe=join --quitafter=200000 --outdir=docs/verify/lw_netshots_join
```

### The night, end to end

Client connects on 9762 → granted seat 1 (BLUE, REMOTE) → tape strolls +
READY → REAL auction (lastwill pool) → GET READY gate → **LAST WILL**, two
full races. Mirror boots inside the intro (`NET mirror boot: lastwill` /
`LW_MIRROR boot players=4 my_seat=1`). Zero script errors in all four logs.

- **Nine wills were drafted and NINE CURSES accreted** — by race 2 the slate
  was FULL (all nine named stretches condemned): BLUE greased THE
  PALLBEARERS' GAP and THE OSSUARY RIDGE and summoned a scythe over THE
  MOURNERS' MILE (all three drafts by the DEAD REMOTE PLAYER, nav + lock
  riding the input relay); GOLD greased THE CRYPT STEPS and THE WILLOW TURN,
  raised stones on THE LYCHGATE ROAD and THE SEXTON'S BEND and summoned a
  scythe over THE PROCESSION ROW; MINT put a gale on THE LANTERN WALK. Every
  install appeared on the mirror with author color + plaque as it happened;
  race 2 ran over the full nine-curse road on both screens.
- **The remote player's whole death arc:** three deaths (t=6/16/26) → three
  will drafts (the 6 s freeze stopping both screens each time) → `LW_GHOST
  BLUE takes a pew (race 1)` printed on BOTH machines the same beat → the
  dead hand gusted from beyond **3×** (`LW_GUST from=BLUE`, tape A over the
  wire, aim over the relay) → `BLUE +1 grudge (dead last)` twice in the
  ledger.
- Race finishes: MINT at 65.0 s (race 1) and 49.5 s (race 2 — the full-slate
  road was FASTER for the untouched one). `LW_MATCH_OVER champ=MINT pts=8`,
  "MINT, the Untouched Procession" monument. The champ fact pre-announced →
  the mirror's win banner + confetti landed before `NET mirror fold` →
  spectate breath → mirrored match podium → RECKONING (`NETPROBE_RESULTS
  RED:pts=2,grudge=3 BLUE:pts=1,grudge=5 GOLD:pts=3,grudge=2
  MINT:pts=5,grudge=1`) → `NETPROBE saves restored` → both quit clean.

### Screenshots (read by eye; `lw_netshots_host/` + `lw_netshots_join/`)

- **The will-draft freeze pair (the 6-second show, both screens):**
  `host/snap_draft_4904.png` vs `join/snap_lw_mirror_draft_1804.png` —
  pixel-for-pixel the same show: THE LAST WILL OF BLUE, the memorial
  portrait with the black ribbon, the SAME three cards (GREASE THE
  FLAGSTONES **upon THE PALLBEARERS' GAP** selected in BLUE's border, A GUST
  CORRIDOR upon THE LYCHGATE ROAD, RAISE THE DEAD upon THE WILLOW TURN),
  timer at 6, the Executor's registry line — and the world behind dimmed to
  a standstill on both machines. The DECEASED here is the REMOTE player; the
  couch shows this draft publicly, so the mirror does too, honestly.
- **The curse-install pair WITH plaque:** `host/snap_curse_5030.png` vs
  `join/snap_lw_mirror_curse_1853.png` — both cameras panned to the same
  stretch mid-race-freeze, `BLUE CONDEMNS / THE PALLBEARERS' GAP` in
  resolution type, the grease sheen risen from the sod, and the author
  plaque **`▲ BLUE · GREASED FLAGSTONES`** legible in the client shot. A
  curse installing mid-race appears on the client with its plaque — the
  lane's core receipt.
- **The crypt-finish pair:** `host/snap_finish_19461.png` vs
  `join/snap_lw_mirror_finish_12315.png` — one story: `MINT REACHES THE
  CRYPT / 1:05.0`, RACE 1/2, identical hearts panel (RED 3, BLUE 0 — dead,
  GOLD 1, MINT 2) and track badges, the Executor's "The first to the crypt
  inherits", GOLD's greased CRYPT STEPS with plaque visible on BOTH. Each
  side frames with its own race camera (the mirror runs the couch's cam
  logic on mirrored positions): the client shot actually shows MINT's pawn
  at the crypt arch AND BLUE's ghost pew drifting alongside. Deliberate,
  honest divergence: the host hint bar reads the remote seat as `REMOTE aim
  the gust`, the client's own bar reads `YOU'RE DEAD — AIM the gust`.
- **The ghost pew (mirror):** `join/snap_lw_mirror_ghost_4424.png` — BLUE's
  translucent ghost on the floating pew with its identity ring and cooldown
  ring, "Out of lives. Not out of influence." — THE EXECUTOR, hearts panel
  showing BLUE at zero.
- **Flow shots:** `join/snap_online_client_lobby/ready/auction/gate/game`,
  both `matchpodium`, both `reckoning` (same ladder; client card `BLUE (you)
  · REMOTE`; MINT's green Untouched-Procession plinth on the host grounds).

### NETHASH_MOD — mirror integrity + bandwidth (seq-keyed, never wall clock)

- **82/82 module digest pairs identical**; the phase-1 walker channel:
  **200/200** identical. Zero mismatches.
- **Bandwidth (measured, `var_to_bytes`, every 40th snapshot):** min 1916 /
  median 2540 / max 3008 / mean 2533 bytes — the fattest snapshots carry the
  FULL nine-curse set + will cards + boulders at once. At 20 Hz that is
  **≈51 kB/s per guest** (~152 kB/s at a full table of three) — the heaviest
  mirror so far and still two orders of magnitude under video; the accreted
  road is what a late joiner needs, so it stays. Input relay upstream stays
  the phase-1 ≈1.2 kB/s.

### Couch tally receipt — the transport did not perturb the sim

`--willtally` from a PRISTINE `git worktree` of HEAD (ae60154) vs this
working tree, seeds 1 / 2 / 3:

```
g_orblw91 --headless --path . res://minigames/last_will/last_will.tscn -- --willtally --seed=N
```

- **Full logs byte-identical, all three seeds** (seed 1: `wills=22
  curse_kills=6 deaths=22`; seed 2: `wills=13 curse_kills=2`; seed 3:
  `wills=10 curse_kills=1`; every `LW_*`, `KILL_EVENTS`, `LW_RESULTS`,
  `WILL_TALLY`, `TALLY_RESULT PASS` line). One honest note: the engine's
  exit-time ObjectDB/resource leak warnings wobble run-to-run **on both
  trees** (seed 2's pristine run printed them, mine didn't; orbital's lane
  saw the same wobble in the other direction). Sim content matches exactly
  in every pairing.

### Regressions (offline behavior untouched)

```
g_orblw91 --headless --editor --import --quit --path .                    # clean (pre-existing asset
                                                                          #  warnings only, same as HEAD)
g_orblw91 --headless --path . res://minigames/last_will/last_will.tscn -- \
          --willtally --seed=1|2|3                                        # byte-identical (above)
g_orblw91 --headless --path . -- --estate --auctiontest --quitafter=9000  # AUCTIONTEST PASS: game launched
g_orblw91 --headless --path . -- --estate --estatebots --quitafter=3200   # zero script errors
g_orblw91 --headless --path . -- --strolltest --quitafter=1200            # zero script errors
```

## Save discipline

`user://` (party_setup.json, prefs.json, estate_save.json, cosmetics.json,
saves/slot_1.json) backed up with an md5 manifest before ANY run; after the
last run all five restored and re-verified `OK` against the manifest
(`2be51efa / 0d8acbf4 / d3e6350c / 99914b93 / 0d8acbf4`), no `.npbak`
leftovers. One honesty note: the first (aborted) orbital probe launch found
the LIVE save marks seats 0 AND 1 human, which parks a joiner on seat 2
while the probe rig watches seat 1 — so probe nights ran with a STAGED
`party_setup.json` (seat 1 = BOT), covered by the same manifest restore. The
probes also did their own `.npbak` dance. Private ports (9761/9762) and a
privately named binary (`g_orblw91`) — only this lane's own PIDs were ever
started or killed.

## Honest limitations

- **Boulder replicas roll locally** from the spawn fact, so their phase can
  sit up to one snapshot beat behind the host's; the traveled-distance nudge
  corrects drift > 0.6 m. A mirrored squish death can therefore read a hand's
  width off the replica's rock — the death burst uses the pawn's mirrored
  position, which is authoritative.
- **The mirror's race camera is its own** (same logic, mirrored inputs), so
  framing differs by a beat from the host's — visible in the finish pair,
  where it framed the crypt better than the host did. Same information.
- **Hit juice is uniform** on the mirror: pendulum/spinner/shove hits all
  fire the same pop+spark+thud read (the couch differentiates the pendulum's
  bumper pitch slightly). Death attribution lines ride the wire verbatim.
- **A same-window gust pair from one seat would collapse to one wave** —
  impossible in play (10 s cooldown).
- **The champion beat is short** (~0.4 s before the fold) — podium mirroring
  is the known phase-3 chore.
- **The mirror's draft clock quantizes** to 20 Hz + local drain — the bar can
  wobble ±0.05 s against the host's. The lock beat is a fact, never inferred.
- **Trust posture:** friends-lobby trusted, per spec.
- Both instances share one `user://` on a dev machine — probe-bounded,
  restored by hash after the runs.

## The design note worth keeping

The will draft looked like a privacy problem and is not one: the couch
plays it on ONE screen, in the open, while the whole room waits out the
freeze. The honest port is therefore total publicity — mirror the cards,
the cursor, the clock. What the wire had to actually deliver was the
COURSE'S MEMORY: a curse is a persistent, authored world-edit, and the
snapshot carries the complete active set so any mirror at any time can
rebuild the accreted road, plaque for plaque. Persistent world state as
facts, not events — that is the pattern this lane adds to the book.
