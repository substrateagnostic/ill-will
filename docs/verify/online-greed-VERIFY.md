# ONLINE PHASE 2 — GREED INC. game mirror + THE CLOSING BELL (verification)

*Built to `docs/design/10-online-first-architecture.md` §4.3 on the house
pattern set by `docs/verify/online-seance-VERIFY.md` (PATTERN NOTES copied
verbatim), plus the AAA-queue Q5 polish item (`docs/design/09-aaa-gap-analysis.md`
§6.1-3, owner-signed): THE CLOSING BELL. Files touched: `minigames/greed/greed.gd`
(bell + realkeys bar + mirror), `minigames/greed/greed_player.gd` (`net_pose`
render helper), `minigames/greed/greed_pot.gd` (`bell_pulse`/`restless`
visuals). `estate/estate.gd` and `core/net_session.gd`: UNTOUCHED — the
phase-2 shell pumps any module exposing `_net_state()`; greed just grew the
two methods.*

## What was built

### 1. THE CLOSING BELL (doc 09 §6.1-3 — Q5)

All presentation, all inside `greed.gd`/`greed_pot.gd`; no rng, no sim writes:

- **§6.3 T-20 straight line:** if `banks_this_round == 0` when the round
  crosses T-20 — `NOBODY HAS BANKED — THE POT GROWS RESTLESS` banner, a low
  grudge tone, and the pot model TREMBLES for 1.6 s (`GreedPot.restless`).
  The GREED PUNISHED punchline finally has its setup.
- **§6.1 T-15 the bell:** `LAST BANKS!` banner + `grudge` sting + the pot's
  giant Label3D value PULSES ×3 (`GreedPot.bell_pulse`) — the room's eyes go
  to the hoard.
- **Final-stretch ticks (Q1 kit cadence, local):** T-10..T-1, one exact-pitch
  tick per second on a rising ladder (1.0 → 1.55; the Sfx pool randomizes
  pitch, so the bell keeps its own tiny pitched pool, séance-style). Timer
  red at ≤10 was already there.
- **§6.2 the approach:** carrier within **3.0 m** of its OWN chute with pot
  **≥ 15** → that chute pad STROBES at 3 Hz and a tick rises every 0.4 s,
  pitch +0.06 per tick, until banked, dropped, or walked away. Logged as
  `bell_approach on p<i> pot=<n>`.

Every bell fact rides `_net_state()` (`"bell": [last, warn, approach,
approach_ticks]`) so a guest's room hears the same bell (below).

### 2. Real keys on the main hint bar (realkeys-VERIFY template)

`_human_seats` / `_btn_hint` / `_controls_bar` copied from the five-game
retrofit; the bar prints live `PlayerInput.describe_binding` text once at
`begin()`:
`MOVE   ·   <key> = GRAB (hold) / TACKLE   ·   <key> = DASH   |   CARRY THE
POT TO YOUR CHUTE TO BANK IT`. All-bot demos keep the generic scene text
(receipts untouched). Remote guests are excluded on the host (their device is
`-99` there) — and the MIRROR builds the same bar locally, so a guest reads
THEIR OWN keys, not the host's.

### 3. The render mirror (house pattern, copied verbatim)

- **The guard:** `_physics_process` opens `if _mirror: game_t += delta;
  _mirror_tick(delta); return` — sim, bots, input sampling never run.
  `_mirror` comes from `config.get("net_mirror", false)` in `begin()`.
- **The begin() split:** fenced only what a mirror must not do — bot
  construction, `_start_round()`, the probes. Pawns, chute tints, scoreboard
  and the vault build exactly as the host does.
- **`_net_state()` (host, 20 Hz):** per-pawn pose facts (x/z/yaw/moving/
  stunned + dash-cd + grab-hold), pot value/state/carrier/loose-pos, floor
  coin list, scores, tackle-swing counters, event counters
  (grab/drop/bank/geyser/punished/leak) with last-drop/last-bank attribution,
  HUD texts (banner + color, round label, timer, hint visibility), the bell
  facts, and the champ. Nothing hidden exists in greed — no private channel.
- **`_net_apply()` (client):** stores, diffs, fires ALL juice from deltas:
  grabs (confirm + GRABBED! flash), drops (victim squash-pop + spark along
  the real knockback + coin burst + splat/death + hitstop), banks (full
  ceremony: coin rain, confetti, cheer, chute-light surge), geysers,
  GREED-PUNISHED scatter, dash coin-leaks, dash one-shots (Dodge_Forward from
  the cooldown jump), tackle swings (whiffs included), the bell, and the
  champion cheer/confetti. Banner text/color/visibility mirrors with the pop
  tween; timer text mirrors with the red-hot color and drives the local
  final-stretch tick ladder.
- **`_mirror_tick()` (client, 60 Hz):** `GreedPlayer.net_pose` glides every
  pawn to the authoritative spot and runs the SAME locomotion-anim logic as
  the host; **the grab-hold ring fills locally at the host's real rate**
  (+delta per tick, resynced each snapshot within ±0.08 s) — the 0.6 s
  tension IS the hold, so the fill is smooth, not 20 Hz steppy. Pot transform
  reuses `_update_pot_transform()` (a CARRIED pot rides the interpolated
  carrier — smooth for free); the edge arrows reuse `_update_hud()` against
  mirrored positions.
- **Reduced motion:** every mirrored shake/hitstop routes through the
  CLIENT's own `_reduced_motion()` pref.
- **Aim provider:** the mirror installs `NetSession.set_aim_provider` —
  a KBM guest's tackle-lunge aim is computed against their own mirrored
  render and relayed as a unit vector (doc 10 §1.3).

## Evidence

_(two-instance probe on one machine, spec §7; screenshots WINDOWED and read
by eye)_

### Commands

```
# host (real selector, greed-only pool; prefs staged to mg_rounds=2 for a 2-round night):
godot --path . --position 60,60  -- --net=host --netprobe=host --pool=greed --seed=7 \
      --quitafter=200000 --outdir=docs/verify/greed_netshots_host

# join (deterministic input tape):
godot --path . --position 700,120 -- --net=join=127.0.0.1:8910 --nettape --netprobe=join \
      --quitafter=200000 --outdir=docs/verify/greed_netshots_join
```

Scripted end-to-end: client connects → claims seat 1 (BLUE, REMOTE, tape) →
strolls + READY → host starts the night → REAL auction (greed-only pool) →
GET READY gate (remote A over the wire answers it) → **GREED INC.**, a full
2-round match with the mirror live on the client (`NET mirror boot: greed` /
`GREED_MIRROR boot players=4 my_seat=1`), the bell ringing in BOTH rounds
(`bell_lastbanks t=75.0` twice on the host — T-15 of each 90 s round), six
muggings, MINT winning 122–76 (`match_end … placements [3,2,0,1]`), module
`finished()` folding the mirror (`NET mirror fold`) → spectate card for the
podium beat → mirrored RECKONING → both quit clean:
`NETPROBE_RESULTS RED:pts=2,grudge=5 BLUE:pts=1,grudge=5 GOLD:pts=3,grudge=6
MINT:pts=5,grudge=3` and `NETPROBE saves restored`. Full logs:
`online-greed-host.log`, `online-greed-client.log` (engine `--log-file`; the
one-machine two-instance rig detaches from redirected shells on Windows —
gotcha noted at the end).

### Screenshots (read by eye; `greed_netshots_host/` + `greed_netshots_join/`)

Each event snap fires independently on each side (host: at the sim event;
mirror: at the counter delta — one snapshot apart), so pairs are the same
story, not the same frame:

- **The carry pair** — `host/snap_greed_host_carry_4052.png` vs
  `join/snap_greed_mirror_carry_3632.png`: timer 86 on BOTH, `GRABBED!`
  flash on BOTH (the mirror fired it from the grab-counter delta), GOLD
  carrying at the pedestal with the golden aura and the pot label `8`,
  everyone else on their marks. The host's hint bar reads its own keys
  (`Space = GRAB (hold) / TACKLE · E = DASH`); the mirror's bar is built
  LOCALLY from the client machine's bindings — real keys on both screens.
- **The drop pair** — `host/snap_greed_host_drop_10141.png` vs
  `join/snap_greed_mirror_drop_9755.png`: timer 44 on both, `MINT MUGGED
  GOLD!` banner on both, the `-2` dash-leak flash on both (mirror: from the
  leak counter), MINT and GOLD tangled at GOLD's chute, scattered floor
  coins mirrored, scoreboards identical (MINT 35 / GOLD 6). The pot label
  reads 13 on the mirror vs 10 on the host — the value label catches up one
  physics tick after the apply (honest limitation below).
- **THE BELL pair** — `host/snap_greed_host_bell_14191.png` vs
  `join/snap_greed_mirror_bell_13813.png`: near pixel-identical. Timer 15,
  `LAST BANKS!` on both, and the pot's giant value label caught MID-PULSE at
  the same swollen size on BOTH screens — the closing bell rings in the
  guest's room.
- **The bank pair** — `host/snap_greed_host_bank_4172.png` vs
  `join/snap_greed_mirror_bank_3776.png`: timer 85, `GOLD BANKS 6!` on both,
  GOLD cheering on its pad with the coin rain falling on both screens,
  scoreboard re-sorted GOLD-first on both.
- **Flow shots:** `join/snap_online_client_lobby/ready/gate` (phase-1 lobby
  mirror), `join/snap_online_client_game_3060.png` (the mirror already up
  in INTRO — no spectate card), and both reckonings
  (`host/…reckoning_31667.png`, `join/…reckoning_31303.png`).

### NETHASH_MOD — mirror integrity + bandwidth

Host prints a digest + byte size of every 40th module snapshot at send;
client prints the digest of the same snapshot at apply, keyed by seq:

- **89/89 digest pairs identical** (every seq the host printed, the client
  printed with the same hash; zero mismatches, zero missing).
- **Bandwidth (measured, `var_to_bytes` of the full snapshot):** min 892 /
  median 916 / max 1052 / mean 927 bytes → at the 20 Hz pump ≈ **18.5 kB/s
  per guest** — the same order as the séance mirror, three orders under
  video. Input relay upstream stays the phase-1 ≈1.2 kB/s.
- The 15 Hz walker NETHASH from phase 1 still runs and still matches.

### THE CLOSING BELL — staged receipts (windowed, `--greedbellcap`)

`godot --path . res://minigames/greed/greed.tscn -- --greedbellcap --seed=5
--outdir=docs/verify/greedbell-shots` stages each beat on a LIVE round clock
(only `round_t` is moved and a 22-coin carrier parked 2.4 m from its chute —
the bell code itself runs untouched) and films it:

- `greedbell-shots/greed_bell_approach.png` — timer 26: RED parked inside the
  3 m ring with a 22 pot; RED's chute pad strobing HOT (visibly brighter than
  the other three pads), edge arrows hunting, `bell_approach on p0 pot=22`
  in the log with the rising 0.4 s ticks.
- `greed_bell_warn.png` — timer 20: `NOBODY HAS BANKED — THE POT GROWS
  RESTLESS` banner over a trembling pot.
- `greed_bell_lastbanks.png` — timer 15: `LAST BANKS!` banner, the pot's
  giant 22 caught mid-PULSE (clearly larger than in the approach shot).
- `greed_bell_ticks.png` — timer 9 in RED, tick ladder audible in the run
  (one `_bell_tick` per second, pitch rising).

### Couch receipts — the transport and the bell did not perturb the sim

Pristine `git worktree` of HEAD (d0a1f18) vs this working tree:

```
godot --headless --path . res://minigames/greed/greed.tscn -- --greedtest=intercept --seed=N
```

Seeds 1 / 7 / 42 — `GREED_INTERCEPT` lines **byte-identical** to the pristine
baseline (64/0.80, 57/0.71, 58/0.72, all PASS ≥ 0.60).

### Regressions (offline behavior untouched)

```
godot --headless --editor --import --quit --path .                    # clean (2nd pass)
godot --headless --path . res://minigames/greed/greed.tscn -- --greedbots --rounds=1 --roundtime=26
                                                                       # full bell arc, zero script errors
godot --headless --path . -- --estate --auctiontest                    # AUCTIONTEST PASS: game launched
godot --headless --path . -- --estate --estatebots --quitafter=3200    # zero script errors
godot --headless --path . -- --strolltest                              # zero script errors
```

## Save discipline

`user://` (party_setup.json, prefs.json, estate_save.json, cosmetics.json,
saves/slot_1.json) backed up with md5 hashes before ANY run; `prefs.json` was
deliberately staged to `{"mg_rounds":2}` for the probe nights (shorter
evidence runs) and everything restored byte-identical afterwards (hashes
re-verified). The netprobe additionally does its own `.npbak` dance.

## Honest limitations

- **Pose facts are quantized** to 0.01 m / 0.01 rad and 20 Hz; the 60 Hz
  glide hides it. Dash trails read correctly from the Dodge one-shot + the
  position stream.
- **The grab-hold fill extrapolates between snapshots** (host adds delta per
  tick, so does the mirror); a tackle that interrupts a hold mid-window can
  show ≤50 ms of extra fill before the zero fact lands. Invisible in play.
- **`_flash_pot` transients are event-local**, not mirrored text — a guest
  joining mid-transient misses one 0.9 s flash. By design (counters, not
  events, per the pattern).
- **The MATCH_END camera shake and champ confetti fire at the phase fact**,
  one snapshot after the host's. Same news, local juice.
- **Floor-coin sync rebuilds by list diff** — a simultaneous pickup+scatter
  in one 50 ms window repositions nodes rather than animating each coin.
  Party-invisible.
- **The mirror's value label lags its event juice by one physics tick** —
  `pot.update_value` runs in `_mirror_tick` (physics), while an apply landing
  between physics and render can snap a shot with the previous value (the
  13-vs-10 drop pair above). ≤1 frame; invisible at speed.
- **Mirror scoreboard can be a beat FRESHER than the host's** — it rebuilds
  on the carrier fact, so `CARRYING` appears on the guest one rebuild before
  the host's next rebuild. Same facts, cosmetic ordering.
- Killcam-skip gating (spec §1.2.2) still an open phase-2 chore; greed has
  no killcam, so it does not bite this lane.
- Both instances share one `user://` on a dev machine — probe-bounded, all
  restored by hash after the runs.

## GOTCHA for the fan-out agents (new, Windows probe rig)

The winget `godot` shim DETACHES windowed instances from a redirected shell:
the visible process exits code 1 immediately while the real
`Godot_v4.6.2-stable_win64` child keeps running — and with `> file 2>&1`
BOTH write the same file at independent offsets, shredding the log. Two
fixes, both verified tonight: launch via `Start-Process` (or any detached
spawn) with the ENGINE's own `--log-file <path>` per instance (used for the
receipts here), or pipe (`… 2>&1 | cat > file`) so a single writer
serializes the stream. Kill wedged probes by image name
`Godot_v4.6.2-stable_win64.exe` — `tasklist` never shows `godot.exe`.
