# ONLINE PHASE 2 — THE UNDERSTUDY game mirror (verification)

*The second game mirror, built to `docs/design/10-online-first-architecture.md`
§4.3 and to the house pattern the séance defined (`docs/verify/online-seance-VERIFY.md`
PATTERN NOTES). Files touched, this lane only: `minigames/understudy/understudy.gd`
(the mirror + the private cast channel + the real-keys hint bar), `minigames/
understudy/us_actor.gd` (`net_pack`/`net_apply`, ~30 lines), `minigames/understudy/
us_reveal.gd` (`flip_to_redacted`, ~10 lines), and this doc + `docs/verify/
us_netshots_{host,join}/`. The estate shell + `core/net_session.gd` are UNTOUCHED —
the estate pumps any module exposing `_net_state()` at 20 Hz and boots/folds the
client mirror off the `mirror` lobby fact, so a game that exposes the two methods
just works.*

## What was built (the house pattern, applied to a hidden-info theater)

- **Host runs the ENTIRE sim exactly as couch.** No understudy logic moved. The
  estate pumps `_module._net_state()` to every guest at **20 Hz**
  (`unreliable_ordered`, channel 4, latest-seq wins) whenever the running module
  exposes it.
- **`_net_state() -> Dictionary`** (host): compact PUBLIC facts only — phase, the
  ACT / timer / hint / executor lines, both banners, the per-seat scoreboard
  totals, per-actor visual state (spotlight energy + status label + anim tag),
  the casting overlay MODE (never the card face), the rehearsal grid + active
  deliverer + cursor + the just-locked cue, the vote cursors + locks, and — only
  from RESOLVE — the round understudy, the verdict card, and the staggered
  ledger lines. **What never enters this dict: THE PLAY, and the round's
  understudy before the unmask.** It fans out to every guest; a guest may BE the
  understudy, so those never ride the fan-out.
- **`_net_apply(state)`** (client): drives a RENDER MIRROR — the same
  `understudy.tscn` booted by the client estate with `config.net_mirror = true`.
  In mirror mode `begin()` builds the stage + actors and stops: no plays, no
  understudy rotation, no rounds, no bots. `_physics_process` opens with the
  house guard (`if _mirror: _mirror_tick(delta); return`) — sim, bots and input
  sampling never run. **All juice fires locally from state DELTAS:** total-count
  changes rebuild the scoreboard, the anim-tag delta re-fires cheer/flinch, the
  cue-lock delta paints the grid word, the vote-lock delta stamps the accusation
  chip, the champion fact throws confetti.

### The private cast channel (the spec's "hidden info gets BETTER online")

- At a REMOTE seat's CALL the host sends its card via
  `NetSession.send_module_private(seat, …)` → `rpc_id` (reliable) to that peer
  and **nobody else**. **Cast peers get THE PLAY** (`TONIGHT'S PLAY — THE
  SHIPWRECK …`); the **understudy's peer gets the "you never got the script"
  card** (`UNDERSTUDY — tonight's play is one of: …`). The card physically
  exists on one machine.
- The host screen — and the public fact every OTHER guest mirrors — shows a
  REDACTED flip for that window: `SUMMONED ACROSS THE WIRE · THE SCRIPT IS
  DELIVERED TO THEIR SCREEN ALONE`. Local/bot seats keep the couch's eyes-closed
  honor system, unchanged, and their card face is also redacted on the wire.
- **Eyes-closed voice summons, per-peer:** on the couch the summons is an honor
  system (everyone hears every seat's ticks; only the named seat may look).
  Online each remote peer receives ONLY its own summons — the round-1 roll-call
  teach (`{"kind":"summons"}`) and the cast window's ticks both ride the private
  channel. A blind-table mechanic that required trust in one room becomes
  structurally private across the wire.
- The flip itself is driven off the host's public `flip` fact, so the guest's A
  press (relayed through the phase-1 seam) advances the host state machine and
  the card turns face-up on both the redacted host and the real client in step.

### Real-keys hint bar (docs/verify/realkeys-VERIFY.md template)

The persistent hint bar was retrofitted to print the player's LIVE binding via
`PlayerInput.describe_binding` — self-contained `_human_seats` / `_btn_hint` /
`_controls_bar` copies (no shared file, no collision with the other realkeys
lanes). Bar (human seats present): `STICK = CHOOSE   ·   {a:COMMIT}` →
`STICK = CHOOSE · Space = COMMIT` for a lone keyboard human, the per-seat
`COMMIT: Space/RED · Enter/BLUE` form for a mixed table, and the original
`STICK = CHOOSE     A = COMMIT` for an all-bot demo. Built once at `begin()`.

## Evidence

_(two-instance probe on one machine, spec §7; all screenshots WINDOWED and read
by eye)_

### Commands

```
# host (real selector, understudy-only pool; understudy PINNED to seat 0 so the
# remote seat 1 is a CAST member and its private card is THE PLAY — the money shot):
godot --path . --position 60,60  -- --net=host --netprobe=host --pool=understudy \
      --usforceund=0 --usrounds=1 --seed=7 --quitafter=300000 \
      --outdir=docs/verify/us_netshots_host

# join (deterministic input tape drives the claimed remote seat 1):
godot --path . --position 760,120 -- --net=join=127.0.0.1:8910 --nettape \
      --netprobe=join --quitafter=300000 --outdir=docs/verify/us_netshots_join
```

Scripted end-to-end, twice (runs identical): client connects → claims seat 1
(BLUE, REMOTE) → deterministic tape strolls + READY → host starts the night →
REAL auction (understudy-only pool) → GET READY gate (remote A over the wire
answers it) → **THE UNDERSTUDY**, a full act with a remote seat 1. `US_FORCEUND
seat=0` pins RED as the understudy, so the remote BLUE is a CAST member; tonight's
play drew **THE SHIPWRECK**. The mirror booted on the client (`NET mirror boot:
understudy` / `US_MIRROR boot players=4 my_seat=1`) and tracked every phase
(`INTRO → CASTING → REHEARSAL → VOTE → RESOLVE`), received its private card
(`US_PRIV call card received (seat 1, cast) — content lives on this screen
alone`), and mirrored the verdict (`THEY WALK — RED WAS THE UNDERSTUDY`, matching
the host's `US_DISTRIBUTED pts={RED=7, BLUE=2, GOLD=0, MINT=0}`). Module
`finished()` folded the client mirror (`NET mirror fold`); both instances quit
clean; `NETPROBE_RESULTS RED:pts=5,grudge=3 BLUE:pts=3,grudge=4 GOLD:pts=2,
grudge=2 MINT:pts=1,grudge=1` and `NETPROBE saves restored`.

### Screenshots (read by eye)

**The private-card pair — the spec's hidden-info claim as two PNGs:**
- `us_netshots_host/snap_host_redacted_7056.png` — the HOST screen during the
  remote seat's cast window: `▲ BLUE · SUMMONED ACROSS THE WIRE · THE SCRIPT IS
  DELIVERED TO THEIR SCREEN ALONE`. No play. The machine running the whole sim
  shows a redacted card.
- `us_netshots_join/snap_mirror_card_6824.png` — the CLIENT, same window:
  `▲ BLUE — YOUR PART · TONIGHT'S PLAY · THE SHIPWRECK · You have read the
  script. Move like you belong on this stage.` The play flash exists on exactly
  one screen, and it is the right one (the cast client).

**The mirrored phases — one story on both screens:**
- `join/snap_mirror_rehearsal_7989.png` — the rehearsal cue grid mirrored:
  `THE REHEARSAL · RED — DELIVER YOUR CUE`, the six-word grid (`DROWN` cursored,
  + `ALARM OATH CELLAR LANTERN CAPTAIN`), the actors lit with their delivered
  cues as status labels (`BLUE "CAPTAIN"`, `GOLD "STORM"`).
- `join/snap_mirror_vote_9895.png` — the vote board mirrored live: `NAME THE
  PRETENDER`, four accused columns, the carets forming as votes lock, the
  `BLUE ACCUSES` chip, timer, executor line.
- `join/snap_mirror_verdict_10505.png` — the verdict mirrored: `THEY WALK — RED
  WAS THE UNDERSTUDY`, RED spotlit with the `THE UNDERSTUDY` status label while
  the others dim, scoreboard `RED 7 (u/s) · BLUE 2 · GOLD 0 · MINT 0` — the
  understudy identity revealed on the mirror at RESOLVE exactly as on the host.

**Flow shots:** `join/snap_online_client_{lobby,ready,gate}.png` (phase-1 lobby
mirror alive), `join/snap_online_client_game.png` (the mirror up during casting —
no spectate card), `host/snap_online_host_{claim,ready,gate,game,reckoning}.png`.

### Couch tally receipt — the transport did not perturb the sim

`--ustally` from a PRISTINE `git worktree` of HEAD (d0a1f18) vs this working
tree, seeds 1 / 2 / 3:

```
godot --headless --path . res://minigames/understudy/understudy.tscn -- --ustally --seed=N
```

- **`US_TALLY` blocks byte-identical, all three seeds:**
  - seed 1: `totals: RED=9 BLUE=9 GOLD=6 MINT=7 champ=RED`
  - seed 2: `totals: RED=2 BLUE=9 GOLD=6 MINT=7 champ=BLUE`
  - seed 3: `totals: RED=7 BLUE=9 GOLD=9 MINT=7 champ=BLUE`

  Points, understudy rotation, blend/unmask scoring: all equal to the pristine
  baseline. The mirror code is all gated behind `if _mirror:` or the
  never-in-tally private/net paths.

### NETHASH_MOD — mirror integrity + bandwidth

Host prints a digest + byte size of every 40th module snapshot at send; client
prints the digest of the same snapshot at apply, keyed by seq (never wall clock):

- Run 1: **43/43 digest pairs identical.** Run 2: **46/46 identical.** Zero
  mismatches across both nights.
- **Bandwidth (measured, `var_to_bytes` of the full snapshot):** min 716 /
  mean ~907 / max 1348 bytes. At the 20 Hz pump that is **≈18 kB/s per guest** —
  three orders of magnitude under a video stream. Input relay upstream stays the
  phase-1 ≈1.2 kB/s.

## Save discipline

`user://` (party_setup.json, prefs.json, estate_save.json, cosmetics.json,
saves/slot_1.json) backed up with md5 hashes before ANY run and restored
byte-identical after the last one. The probe itself also does its own `.npbak`
dance for party_setup/prefs.

## Honest limitations

- **The mirror's cast flip follows the host's public `flip` fact**, so the
  card turns face-up ~RTT after the guest's own A press. Same information, one
  beat late; the summons audio fires immediately on the private channel, hiding
  it. On loopback it is imperceptible.
- **The redacted card fades out over 0.35 s when casting closes**, so a snapshot
  taken in that window can show the fading overlay over the rehearsal grid
  behind it (a cosmetic-only artifact; the evidence snaps are timed past it).
- **Actor spotlight energy is mid-tween when the host reads it**, so the mirror
  snaps to intermediate values; the actors settle within one snapshot. Cosmetic.
- **Trust posture:** packets are friends-lobby trusted (spec: not an anti-cheat
  surface). The private card is reliable `rpc_id`; a dropped fan-out snapshot
  loses only intermediate frames (juice from deltas, latest-seq wins).
- Both instances share one `user://` on a dev machine — probe-bounded, and
  everything restored by hash after the runs.
