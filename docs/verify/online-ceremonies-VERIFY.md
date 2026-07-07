# ONLINE PHASE 3 — PODIUMS + NIGHT CEREMONIES mirror (verification)

*Closes the biggest remaining online gap: remote guests used to stare at the
spectate card while the couch got the drama. Now the whole dramatic arc —
match podium, THE RECKONING ticker, night podium, THE READING OF THE WILL,
THE PARADE, the free-roam boundary, and the RUN-OVER heir ceremony — plays on
the guest's own screen, restaged from host facts. Files touched:
`estate/estate.gd` (+~330: host ceremony-stage facts + client restager),
`core/podium.gd` (+12, additive: `stage_entries()` split out of `present()`,
explicit-cosmetics entries). `core/net_session.gd`: NOT touched — everything
rides the existing 5 Hz lobby-facts channel with new fact keys, exactly as the
lane spec preferred.*

## Design (host renders truth; clients render a faithful ceremony)

- **Ceremony stage facts.** The host narrates each ceremony as a small dict
  (`_net_set_ceremony`) merged into the existing lobby-facts broadcast
  (reliable, 5 Hz — stage flips also push immediately). Stages:
  `match_podium` → (cleared at RECKONING) → `night_podium` → `will` →
  `parade` → (cleared at GROUNDS boundary), plus `run_podium` → `heir` when
  the trail summits. Clients restage; they never simulate an outcome.
- **The podium is the same Podium.** `podium.gd` gained `stage_entries()` —
  `present()` = stage + timer + `done`, byte-identical host behavior; the
  client calls `stage_entries()` directly because the HOST decides when a
  mirrored ceremony ends (next stage fact folds it). Entries accept
  `cosmetics: [ids]` — the host's wardrobe truth — because a guest's local
  cosmetics.json is a different estate's closet. Placements, names, colors,
  rank blocks, cheer/sit/lie animations, confetti and the fanfare all come
  from the same scene code the couch runs.
- **The will reading travels as composed lines** (head text + per-award
  `[player, line]` + vendetta notice), colored per player and faded in with
  the couch's exact 0.45 s stagger. Word-for-word by construction.
- **Banners mirror through the stage.** `_flash` on the host writes
  `[text, color, dur]` into the current stage facts (WINS THE NIGHT, tollgate
  claims, REACHES THE MANOR, TAKES THE MANOR); the client flashes each
  distinct banner once, and hides it on a stage flip whose facts carry none —
  exactly when the host clears its own.
- **The parade animates stone-by-stone.** Lobby facts now always carry
  `trail` (host trail_pos). Outside the parade the client seats pawns at host
  truth; during the `parade` stage each host advance pushes facts and the
  client plays `advance_pawn` over the same stones, hop-tweens, card ticks.
  The night-podium stage also ships the new gate statue (`add_statue`).
- **Wardrobe facts** (`hats`) ride every lobby state: guests' mirrored
  walkers and podiums wear what the host's estate says, not their local file.
- **RECKONING ticker mirrored** (`ticker` fact): the full "+pts / ♠ / carved"
  ladder, verbatim, above the standings on the guest panel.
- **AUCTION visibility (spec item 3):** phase 1 sent nothing auction-shaped.
  Now `auction` facts carry the block (game names), high bid + leader, clock,
  pot, the Executor's quip and the vendetta book — rendered read-only on the
  guest card with "the couch holds the paddles tonight". CHOOSING shows
  "X CHOOSES THE GAME". **No new client inputs** — bidding stays couch-side;
  guests keep exactly ready/continue relays, per the lane scope.
- **No-flicker handoff:** `_present_match_podium` sets the stage fact in the
  same frame `_on_module_finished` drops the mirror fact, so one client
  rebuild folds the game mirror and raises the podium — no spectate-card
  flash between them.

## Evidence

_(two-instance probe on one machine; private port 9473 and a private-named
binary copy `g_est73.exe` — other agents probe tonight; all screenshots
WINDOWED and read by eye at the FINAL code state)_

### Commands

```
# host (real selector, tilt pool, ONE-GAME night so the reckoning settles it):
g_est73 --path . --position 60,60  -- --net=host --port=9473 --netprobe=host --pool=tilt \
        --night=1 --seed=7 --rounds=2 --roundtime=25 --quitafter=200000 \
        --outdir=docs/verify/cer_netshots_host
# join (deterministic tape drives seat 1):
g_est73 --path . --position 700,240 -- --net=join=127.0.0.1:9473 --nettape --netprobe=join \
        --quitafter=200000 --outdir=docs/verify/cer_netshots_join
```

The netprobe rig itself grew the ceremonies leg: the host probe presses its
own CONTINUE after the reckoning and walks night podium → will → parade →
boundary; the join probe gates on the ceremony-stage facts and snaps each one
(legacy phase-1/2 probes skip the leg automatically — their hosts quit at the
reckoning and the session drop bypasses it).

### The run (110 s, scripted end-to-end, twice — pre- and post-banner-fix)

Client granted seat 1 (BLUE, REMOTE, tape) → mirrored lobby/ready → **mirrored
auction** → gate → TILT mirror (2 rounds, sudden death, the works) → module
`finished` → `NET ceremony stage: match_podium` + `NET mirror fold` in the
same rebuild → mirrored reckoning ticker → host CONTINUE →
`night_podium` → `will` (`WILL_READ_MIRROR awards=2` paired with host
`WILL_READ night=… awards=2`) → `parade` → boundary
(`NETPROBE ceremonies leg done (boundary=true)`), then
`NETPROBE_RESULTS RED:pts=1,grudge=5 BLUE:pts=2,grudge=5 GOLD:pts=3,grudge=4
MINT:pts=5,grudge=1`, saves restored, both quit clean.

### NETHASH — seq-keyed, zero mismatches

- Final run: walker channel **98/98 paired, 0 unpaired**; module channel
  **28/28 paired, 0 unpaired**. First run: 102/102 and 30/30. Not a single
  divergent digest across both runs.

### Screenshots (paired, read by eye)

- **THE MONEY SHOT — `cer_netshots_join/snap_will_reading_mirror_13917.png`**
  vs `cer_netshots_host/snap_will_reading_14211.png`: the guest's READING OF
  THE WILL is word-for-word the couch's — same head ("…finds it, on the
  whole, actionable. MINT wins the night." in mint), same superlatives
  ("RED, THE DOORMAT — finished dead last 1 time. forgive them." in red,
  "GOLD, THE HOARDER — amassed 2♠ of pure spite" in gold), same stagger; the
  host shows TO THE PARADE where the guest reads "the host turns the page —
  the parade follows".
- **Match podium pair** (`…client_matchpodium_12249` / `…host_matchpodium_12572`):
  near pixel-identical tableaus — MINT cheering on 1, GOLD on 2 **in the
  chef's toque**, BLUE seated on 3, RED collapsed stage-right **in the viking
  helm**. The hats are the host's wardrobe riding the facts channel; they
  bought them, they keep them online.
- **Night podium pair** (`…client_nightpodium_13082` / `…host_nightpodium_13373`):
  same standings order, same hats, same "MINT WINS THE NIGHT / the estate
  will remember" banner words+color mirrored through the stage facts.
- **Reckoning** (`…client_reckoning_12756`): the full ticker (placements
  +pts, three "fell off the platter" spades, "...and 6 more (carved into the
  graffiti wall)") + THE LADDER, matching `…host_reckoning_13108`.
- **Auction pair** (`…client_auction_1089` / `…host_auction_1441`): same
  Executor quip, same "on the block: TILT / TILT / TILT", same
  "no bids — cheapest seat chooses (Ns)" + pot; host shows live bid/bet
  buttons, guest shows the read-only card.
- **Parade pair** (`…client_parade_14479` / `…host_parade_14697`): pawns
  advancing the same stones (snap timing differs by one advance — the client
  animates each fact push as it lands).
- **Boundary pair** (`…client_boundary_14906` / `…host_boundary_15187`):
  ceremony facts cleared → guest back on the online-night panel with trail
  pawns resting at the post-parade stones, walkers strolling again.

### Receipts unbroken (final code state)

```
godot --headless --editor --import --quit --path .                      # exit 0, no parse/script errors
godot --headless --path . -- --estate --estatebots --mockonly --night=1 # NIGHT_OVER -> WILL_READ ->
                                                                        # PARADE -> DAWN, night 2 rolls on
godot --headless --path . -- --estate --auctiontest                     # AUCTIONTEST PASS: game launched
godot --headless --path . -- --strolltest                               # clean
godot --path . -- --readytest --outdir=docs/verify/cer_receipts         # GET READY card verified by eye
godot --headless --path . -- --netprobe=couch                           # tape -> NETPROBE_DONE, saves restored
```

*Note on `--auctiontest`: it cannot press the free-roam CONTINUE, so it
requires a save that is not resting at a between-nights boundary (tonight's
estate is). The receipt above ran on a temporarily-fresh slot with the real
saves moved aside and restored after — pre-existing harness shape, not a
regression.*

## The wire, honestly priced

The new facts ride the EXISTING reliable 5 Hz lobby channel. Arithmetic on
the actual dict contents (not measured at the pump — the channel has no
`bytes=` probe): base state (seats+standings+trail+hats+header) ≈ 0.6 kB;
+auction ≈ 0.2 kB; +reckoning ticker ≈ 0.4 kB; +will ceremony ≈ 0.35 kB →
worst case ≈ 1.5 kB × 5 Hz ≈ **7.5 kB/s per guest for seconds at a time**,
usually ~3 kB/s. Stage flips and parade steps add a handful of immediate
pushes per night. The moving channels are unchanged (walkers 15 Hz; module
20 Hz, tilt median 1052 B ≈ 21 kB/s measured in the tilt lane).

## Honest gaps

- **Top bar is host-only.** Guests get standings in panels (reckoning ladder,
  spectate card) but no persistent mirrored top bar during ceremonies.
- **The lawn décor is local.** Monuments, graffiti wall and gate statues
  (except the night's new statue, which is mirrored) render from the guest's
  own EstateState — on a remote machine that is their own estate's lawn
  behind the host's ceremony. Panels and podiums carry the host truth.
- **Banner font-size can differ**: the host banner sometimes carries a
  smaller stroll-prompt override; the guest renders scene default. Words,
  color and timing match.
- **Parade tollgate SFX/claims** reach guests as banner facts + the trail
  animation's own hop ticks; the toll math itself is host-side (as designed).
- **RUN-OVER (`run_podium`/`heir`) is code-complete but not probe-driven** —
  reaching the manor needs a multi-night run; the stages are the same
  facts/restager path the (verified) night podium and will reading use, and
  the heir text ships composed. A future `--night=1` soak on a near-summit
  save would close this.
- Guests still cannot bid (deliberate scope: no new inputs) — remote paddles
  are a named later chore.
- The reckoning ticker on the guest is static (no fade stagger): the panel
  rebuilds on every fact change (ping ticks), and re-fading would strobe.

## Save discipline

`user://` ("ILL WILL": estate_save.json, saves/, cosmetics.json,
party_setup.json, prefs.json) backed up with an md5 manifest before ANY run
and restored byte-identical after the last one; the netprobe additionally did
its own `.npbak` dance per run, and `--readytest`/`--auctiontest` used their
own aside-and-restore.
