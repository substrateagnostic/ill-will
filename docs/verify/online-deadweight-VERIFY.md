# ONLINE PHASE 2 — DEAD WEIGHT game mirror (verification)

*Built to `docs/design/10-online-first-architecture.md` §4.3 on the house
pattern set by `docs/verify/online-seance-VERIFY.md` (PATTERN NOTES copied
verbatim). Dead weight is the first JOLT-HEAVY mirror: the host runs the
whole physics sim; the client freezes every rigid body and puppets it from
snapshots. Files touched: `minigames/dead_weight/dead_weight.gd` (the
mirror), `minigames/dead_weight/fighter.gd` (three additive net counters),
`minigames/dead_weight/prop.gd` (render-only `net_round_reset`).
`estate/estate.gd` and `core/net_session.gd`: UNTOUCHED.*

## What was built

### 1. The house pattern on a physics game

- **The guard:** `_physics_process` opens (after the existing game_time +
  shake lines, exactly like the séance) with `if _mirror: _mirror_tick(delta);
  return` — sim, bots, round flow, Jolt driving: host only.
- **The begin() fence:** the mirror builds the attic, fighters and all 12
  props exactly as the host does, then **freezes every body** — fighters get
  `freeze = true` + `set_physics_process(false)` + `set_process(false)`
  (anim/rings become controller-driven), props get `freeze = true` but KEEP
  their script process: the possession wobble/glow in `prop.gd` is pure
  visual and runs full-fat on the mirror while the frozen body takes its
  transform from the wire. No `_start_round()`, no bots, no economy.
- **`_net_state()` (host, 20 Hz):** per-fighter rows (alive, pos xyz, pivot
  yaw, anim tag, shove/hop cooldowns, hit counter + last knock dir, shove
  counter), per-seat ghost rows (up, pos xyz, possessed-prop index),
  **all 12 furniture transforms** (pos + rotation quaternion — the armchair
  lunge and the tumble stream as transforms), HUD texts (banner + color,
  round label, timer), THE HOUSE AWAKENS fact, scores/ghost-kills/deaths,
  the possessed-prop hit counter, and the champ. No hidden info in dead
  weight — no private channel.
- **`_net_apply()` (client):** diffs and fires everything locally:
  - **possession is the soul** — a prop's possessed-by change calls the same
    `possess()`/`release()` the couch uses (color glow, wisps, grudge/card
    sfx), and the wobble runs in prop.gd as on the couch;
  - fighter hit counters → squash-pop + spark along the REAL mirrored
    knockback dir + thud + (pref-gated) shake;
  - shove counters → whoosh + windup coil + the §A6 readability ring/arc at
    the mirrored facing;
  - deaths → death burst + splat/death + (pref-gated) shake + hitstop; the
    kill line itself rides the mirrored banner;
  - **HOUSE AWAKENS** → `_dim_to_candlelight()` runs locally off the fact
    (ambient/sun ease down, four candles gutter in `_process` exactly as the
    host's); round rollover runs `_house_asleep()` + ghost fold + the
    furniture dent tint (`net_round_reset` — no freeze/teleport);
  - champion → match_win + confetti at the champ's corner.
- **`_mirror_tick()` (client, 60 Hz):** fighters glide (pos lerp + pivot
  yaw lerp + mirrored anim tag + cooldown RINGS filling smoothly — local
  decay between snapshots, resync on apply), wisps glide + pulse, and the
  furniture interpolates pos + SLERPed rotation.
- **Reduced motion:** every mirrored shake/hitstop routes through the
  CLIENT's own `_reduced_motion()` pref — a guest with screen-shake off gets
  the pops and sparks but no shake, no time hit, regardless of host prefs.
- **Hint bar:** `_controls_bar()` on the client naturally personalizes to
  the ONE local seat (everyone else has no device there); when MY seat dies
  the bar swaps to MY `_ghost_hint_line` — mirror-side `_refresh_hint`
  ignores other seats' deaths (their hints live on their own screens).
- **Aim provider:** installed at mirror boot; the fling cursor anchors on my
  possessed prop, the shove cursor on my fighter — both computed against MY
  mirrored render and relayed as unit vectors (doc 10 §1.3).

### 2. Host-side additions (all pure counters — receipts unperturbed)

`fighter.gd`: `net_shoves` / `net_hits` / `net_hit_dir` (assigned where the
sim already acts, never read by it). `dead_weight.gd`: `_net_ghost_hits` in
`note_ghost_hit` (the balance `_dbg.ghost_hits` untouched), `_net_champ`,
`_banner_col`, and the `--dwevict=N` evidence pin (probe-only, loud,
`_balance_rounds == 0` fenced). `prop.gd`: `net_round_reset` (mirror-only).
The `--dwbalance` receipt below proves byte-identity.

## Evidence

_(two-instance probe on one machine, spec §7; screenshots WINDOWED and read
by eye)_

### Commands

```
# host (real selector, deadweight-only pool; prefs staged to mg_rounds=2):
godot --path . --position 60,60  -- --net=host --netprobe=host --pool=deadweight --seed=7 \
      --quitafter=200000 --outdir=docs/verify/dw_netshots_host

# join (deterministic input tape):
godot --path . --position 700,120 -- --net=join=127.0.0.1:8910 --nettape --netprobe=join \
      --quitafter=200000 --outdir=docs/verify/dw_netshots_join
```

Two nights were run. **Night 1** (no pin): full clean arc — mirror boot
(`DW_MIRROR boot players=4 my_seat=1`), 2 rounds, HOUSE AWAKENS mirrored in
round 1 (`snap_dw_mirror_awakens` vs `snap_dw_host_awakens`: identical
candlelit attics — timer 30, purple banner, ambient dimmed, every prop and
pawn in the same spot on both screens), reckoning, saves restored. But the
night STALEMATED — zero deaths in 150 s: the two input-idle probe seats got
shoved onto the very lip and parked there, and the bots' edge-avoidance
(steer-back beyond |3.6|) never closes to shove range on a lip-camper.
Pre-existing couch behavior (bots + idle humans), observed here and worth a
future balance look; not this lane's fix. **Night 2** adds the evidence pin
`--dwevict=2` (séance `--seancechar` precedent — real `_fall()` path, logged
`DW_FORCEEVICT seat=2`, never real play) so the poltergeist arc is
guaranteed on film:

- GOLD fell at t=1.0 (`THE VOID CLAIMS GOLD` — the kill line rode the
  mirrored banner), rose as a wisp, POSSESSED furniture and slammed the
  living — `DW_DEATH round=1 t=9.3s THE VOID CLAIMS BLUE` seconds later.
- Ends clean: `NETPROBE_RESULTS RED:pts=5,grudge=3 BLUE:pts=3,grudge=4
  GOLD:pts=1,grudge=3 MINT:pts=2,grudge=1`, `NETPROBE saves restored`,
  `NETPROBE_DONE`. Full logs: `online-deadweight-host.log` /
  `-client.log` (night 2), `online-deadweight-host-night1.log` /
  `-client-night1.log` (night 1). Engine `--log-file` per instance — see
  the Windows shell-detach gotcha in `online-greed-VERIFY.md`.

### Screenshots (read by eye; `dw_netshots_host/` + `dw_netshots_join/`)

- **The possession** — `join/snap_dw_mirror_possess_3018.png`: timer 74,
  `THE VOID CLAIMS GOLD` banner, GOLD already ☠ on the mirror scoreboard,
  and GOLD's golden wisp latched onto a prop beside MINT — the possession
  glow lit by the same `possess()` call the couch uses, fired from the
  mirrored possessed-by fact.
- **THE MONEY SHOT pair** — `host/snap_dw_host_ghosthit_4040.png` vs
  `join/snap_dw_mirror_ghosthit_3115.png`: near pixel-identical. The
  gold-glowing possessed prop mid-slam into MINT, impact SPARKS burst along
  the mirrored knockback dir on BOTH screens (client sparks fired locally
  from the hit counter), the white shove-arc read under the brawl, RED
  parked by the wardrobe top-left, GOLD ☠ on both scoreboards. The
  furniture assault plays in the guest's room.
- **THE HOUSE AWAKENS pair** — `host/snap_dw_host_awakens_*.png` vs
  `join/snap_dw_mirror_awakens_*.png` (both nights): the room drops to
  candlelight on BOTH screens at T-30 — same dimmed ambient, same banner,
  same prop scatter, mirror fired `_dim_to_candlelight()` from the `aw`
  fact.
- **Flow shots:** client lobby/ready/gate, `snap_online_client_game`, and
  both reckonings.
- Hint bars: each machine prints its OWN live keys (realkeys helpers run
  locally on the mirror; on this one-machine rig the client shows the
  shared couch map, on a real guest machine only their seat has a device).

### NETHASH_MOD — mirror integrity + bandwidth (night 2)

- **68/68 digest pairs identical** — every snapshot the client applied
  hashed identically to the host's send, keyed by seq. (The host printed
  one final digest after the client's mirror had already folded at match
  end; nothing the client applied ever mismatched.)
- **Bandwidth (measured):** min 2004 / median 2028 / max 2096 / mean 2051
  bytes per snapshot → ≈ **41 kB/s per guest** at 20 Hz — the fattest
  mirror so far (12 furniture transforms with quaternions ride along), and
  still orders of magnitude under a video stream. Input relay upstream
  stays ≈1.2 kB/s.

### Couch receipts — the transport did not perturb the Jolt sim

Pristine `git worktree` of HEAD (d0a1f18) vs this working tree:

```
godot --headless --path . res://minigames/dead_weight/dead_weight.tscn -- --dwbalance=20 --seed=N
```

Seeds **1 / 3 / 7**, 20 rounds each: every `DW_*` line, `KILL_EVENTS` dump
and the full `======== DEAD WEIGHT BALANCE ========` block **byte-identical**
to the pristine baseline (seed 1: living 65.0%, possessions=38 ghost_hits=70;
seed 3 and 7 likewise identical). After the `--dwevict` evidence pin landed,
seed 3 was re-run once more: still byte-identical (the pin defaults to -1 and
is additionally fenced out of `--dwbalance`). One harness note, documented honestly: the
Windows runner occasionally KILLS a headless godot mid-run (output stops
mid-round, no error) — re-running the truncated side produced complete,
byte-identical output every time; every line that both runs printed matched
in every pairing. The truncation is a runner flake, not drift.

### Regressions (offline behavior untouched)

```
godot --headless --editor --import --quit --path .                        # clean (2nd pass)
godot --headless --path . res://minigames/dead_weight/dead_weight.tscn -- --dwbots --quitafter=900
                                                                           # zero script errors
godot --headless --path . -- --estate --auctiontest                        # AUCTIONTEST PASS
godot --headless --path . -- --estate --estatebots --quitafter=3200        # zero script errors
godot --headless --path . -- --strolltest                                  # zero script errors
```

## Save discipline

Same as the greed lane (one shared backup/restore bracket around all probe
runs): `user://` backed up with md5 hashes before ANY run, `prefs.json`
staged to `{"mg_rounds":2}` for the probe nights, everything restored
byte-identical afterwards and re-verified by hash.

## Honest limitations

- **The mirror's furniture is frozen-kinematic** — a guest never simulates
  Jolt, so prop-vs-prop clutter on the client is wherever the host says it
  is, interpolated. At 20 Hz a wardrobe freight-training at ~9 m/s moves
  ~0.45 m between snapshots; the 60 Hz slerp/lerp glide reads clean at party
  camera distance.
- **Prop rotation quaternions are snapped to 0.001** — visually lossless.
- **Fighter anim is a mirrored TAG** (Idle/Run/Hit/Jump/Interact) — one
  snapshot (≤50 ms) late relative to the host. The squash-pop and spark fire
  from counters at the same latency.
- **The mirror's initial prop layout is seed-0** for the ~1 lobby frame
  before the first snapshot lands, then every transform snaps authoritative.
  Invisible behind the estate handoff.
- **Ghost possess-cooldown has no on-screen widget on the couch**, so there
  is nothing to mirror for it; the fighters' shove/hop cooldown RINGS are
  mirrored (the only cooldown rings dead weight draws). If a ghost CD ring
  ever ships couch-side, add one number per ghost row.
- **`_time_hit` on the mirror scales the whole client engine clock** for
  0.4 s on deaths — same mechanism as the host, pref-gated client-side.
- Killcam-skip gating (spec §1.2.2) still an open phase-2 chore; dead weight
  has no killcam.
- Both instances share one `user://` on a dev machine — probe-bounded, all
  restored by hash after the runs.
