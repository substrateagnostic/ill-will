# ONLINE PHASE 2 — THE SÉANCE game mirror (verification)

*Built to `docs/design/10-online-first-architecture.md` §4.3 (the spec is law):
the séance is the FIRST game mirror and this port defines the house pattern
every later mirror copies. Files touched: `minigames/seance/seance.gd` (+ the
mirror), `minigames/seance/seance_planchette.gd` (`tick_fx` split, 6 lines),
`core/net_session.gd` (ADDITIVE: module-state channel + per-peer private
sends + tape A-edge accessor), `estate/estate.gd` (the game-handoff seam,
fenced; lobby/flow code untouched). Evidence below; PATTERN NOTES for the
fan-out agents at the end.*

## What was built

### 1. The house pattern (spec §4.3), implemented in the séance

- **Host runs the ENTIRE sim exactly as couch.** No séance logic moved. The
  estate pumps `_module._net_state()` to every guest at **20 Hz**
  (`unreliable_ordered`, channel 4, latest-seq wins) whenever the running
  contract module exposes it.
- **`_net_state() -> Dictionary`** (host): compact PUBLIC facts only — phase,
  sitting clock, focus, planchette XZ, dwell letter + progress, the 26-letter
  state string, per-seat tap totals, per-seat pull vectors (the spectral
  arrows are public by design), anonymous surge COUNT, all HUD texts
  (banner/sub/executor/phase/hint/timer/blanks/clue), the REDACTED cast
  overlay, vote cursors + locks (public pointing), the unmask facts (only
  after the unmask hit), and the settlement rows as they are read out.
  **What never enters this dict: the word, the charlatan before the unmask,
  per-seat surge attribution.** It fans out to every guest; secrets don't.
- **`_net_apply(state)`** (client): drives a RENDER MIRROR — the same
  `seance.tscn` booted by the client estate with `config.net_mirror = true`.
  In mirror mode `begin()` builds the stage/figures/UI and stops: no word
  pick, no charlatan draw, no bots, no fee. `_physics_process` opens with the
  house guard (`if _mirror: _mirror_tick(delta); return`) — sim, bots and
  input sampling never run. **All juice fires locally from state DELTAS:**
  letter 0→1/0→2 transitions pop + ring the same sfx, tap-count deltas flare
  that sitter's candle at that seat's pitch, surge-count deltas ripple the
  planchette, lock deltas stamp chips, ledger-row deltas read out the
  settlement, the unmask fact swings the spotlight/reactions/confetti, and a
  local drumroll runs between the roll banner and the unmask fact.
- **`_mirror_tick(delta)`** (client, 60 Hz): planchette glide toward the
  latest authoritative XZ, smooth candle-pulse clock (resynced to the
  snapshot's elapsed when off by >0.25 s), arrows, drumroll — everything that
  must be smoother than 20 Hz.

### 2. Private per-peer delivery (the spec's "hidden info gets BETTER online")

- `NetSession.send_module_private(seat, data)` → `rpc_id` (reliable) to the
  peer that owns that seat and **nobody else**. The charlatan/faithful cast
  card physically exists on one machine.
- At the START of a remote seat's cast window the host sends the full private
  card; the client runs the same theater locally (3 summons ticks → name card
  at 1.2 s → CONTENT + 4th tick at 2.2 s → public facts resume at 6.1 s).
- The host screen (and the public fact every OTHER guest mirrors) shows a
  REDACTED card for that window: `THE CARD IS DELIVERED TO THEIR SCREEN
  ALONE`. Local seats keep the couch's eyes-closed honor system, unchanged —
  and their content is also redacted on the wire (`(the card is theirs
  alone)`).
- **Eyes-closed voice summons, the design win:** on the couch the summons is
  an honor system (everyone HEARS every seat's ticks; only the named seat may
  look). Online each remote peer receives ONLY its own summons (roll-call
  `{"kind":"summons"}` and the cast window's ticks both ride the private
  channel) — a blind-table mechanic that required trust in one room becomes
  structurally private across the wire. This is not extra work; it is the
  transport doing the design's job for free. Document-worthy and documented.
- **Chant beat-stamps (spec §4.3, ~30 lines):** the sitting is rhythm-judged,
  so a remote sitter would be systematically late by RTT. The mirror stamps
  each local A press with the beat phase visible ON ITS OWN SCREEN
  (`{"kind":"seance_chant", "bt": …}` on the reliable panel-intent pipe); the
  host trusts the stamp within ±150 ms and otherwise keeps its own clock. No
  stamp (couch, tally, bots) = byte-identical old behavior. The NETPROBE tape
  exercises the same path end-to-end via `NetSession.tape_pressed_a()`.

### 3. Estate handoff (fenced seam; the estate lane is otherwise untouched)

- Host: `_do_launch_game` records `_net_mirror_id` when the booted contract
  module has `_net_state()`; the 5 Hz lobby state carries
  `state["mirror"] = id` while the module runs; `_on_module_finished` clears
  it. The 20 Hz pump lives at the end of `_net_host_broadcast`.
- Client: on lobby facts with `phase == "GAME"` + `mirror`, the estate leaves
  the spectate placeholder and boots the mirror (same environment shuffle as
  the host's launch); when the mirror fact drops (module finished — host
  authority) or the session dies, `_client_teardown_mirror()` folds it and
  hands the estate back. A `_client_mirror_up` latch guarantees teardown can
  never touch a HOST's real module.
- The host's podium ceremony is not mirrored (the client sees the spectate
  card for those ~4 s, then the mirrored reckoning ladder). Known gap, listed
  for phase 3.

### 4. Input: ZERO work (verified, not rebuilt)

The séance polls `PlayerInput` per seat everywhere (`seance.gd` sitting loop,
vote nav/lock). Remote seats arrive through the phase-1 `_remote` seam
untouched — the probe's remote seat 1 chanted (candle flares + focus moves on
the host from taped A presses over the wire), and locked its vote, with no
séance input code changed. The only addition is the beat-stamp ADJUSTMENT
described above; the press itself still rides the phase-1 relay.

## Evidence

_(two-instance probe on one machine, spec §7; all screenshots WINDOWED and
read by eye)_

### Commands

```
# host (real selector, séance-only pool, charlatan pinned to the remote seat for the private-flash receipt):
godot --path . --position 60,60  -- --net=host --netprobe=host --pool=seance --seancechar=1 --seed=7 \
      --quitafter=200000 --outdir=docs/verify/seance_netshots_host

# join (deterministic input tape; the tape's A-edges also drive beat-stamps):
godot --path . --position 700,120 -- --net=join=127.0.0.1:8910 --nettape --netprobe=join \
      --quitafter=200000 --outdir=docs/verify/seance_netshots_join
```

Scripted end-to-end, twice (runs identical): client connects → claims seat 1
(BLUE, REMOTE) → deterministic tape strolls + READY → host starts the night →
REAL auction (bots bid; séance-only pool) → GET READY gate (remote A over the
wire answers it) → **THE SÉANCE**, full round with a remote seat 1 —
`SEANCE_FORCECHAR idx=1` pins the charlatan onto the remote player, and the
spirits, unprompted, drew the word **MIRROR** for the first game mirror's
verification night. The mirror booted on the client (`NET mirror boot:
seance` / `SEANCE_MIRROR boot players=4 my_seat=1`) and tracked every phase
(`INTRO → CAST → SEANCE → TALK → VOTE → REVEAL`), received its private card
(`SEANCE_PRIV cast card received (seat 1) — content lives on this screen
alone`), and mirrored the unmask (`SEANCE_MIRROR unmask charlatan=1
caught=true` — exactly the host's `SEANCE_VERDICT caught=true
correct_votes=2 charlatan=1 success=true`). The remote sitter's tape CHANTED
across the wire and every press carried a beat-stamp the host accepted:
14 × `SEANCE_STAMP p=1 … used=true` (14/14, none rejected), stamp-vs-host
skew 16–50 ms (loopback: mirror-clock quantization; the mechanism that will
matter at 80 ms RTT).
Module `finished()` on the host folded the client mirror (`NET mirror fold`)
→ spectate card for the podium beat → mirrored RECKONING ladder → both
instances quit clean; `NETPROBE_RESULTS RED:pts=2,grudge=3 BLUE:pts=1,
grudge=7 GOLD:pts=5,grudge=2 MINT:pts=3,grudge=1` and `NETPROBE saves
restored`. Full logs: `online-seance-host.log`, `online-seance-client.log`.

### Screenshots (read by eye; `seance_netshots_host/` + `seance_netshots_join/`)

**The private-flash pair — the spec's hidden-info claim as two PNGs:**
- `host/snap_cast_2896.png` — the HOST screen during the remote seat's cast
  window: `▲ BLUE · summoned across the wire · THE CARD IS DELIVERED TO
  THEIR SCREEN ALONE`. No word. No role. The machine running the whole sim
  shows a redacted card.
- `join/snap_mirror_cast_2680.png` — the CLIENT, same window: `▲ BLUE · the
  spirits took the liberty of paying you · YOU WERE PAID — 2 GRUDGE, UP
  FRONT · THE WORD IS "MIRROR" · Bury it. Do not get caught.` The charlatan
  flash exists on exactly one screen, and it is the right one.

**The chant pair — a live mirror mid-sitting:**
- `host/snap_net_sitting_4808.png` vs `join/snap_mirror_sitting_4592.png` —
  timers read 82 / 83 (the two snaps trigger independently at elapsed 8 s,
  one snapshot beat apart); everything else matches: blanks `M _ _ _ o _`,
  the same red-burned F miscommit and gold M/O on the board, the same focus
  bar, the planchette on the same spot, and the same live pull-arrows (GOLD
  dragging west, MINT south-east) — per-seat pull is mirrored in flight.
- Both boards show the public clue (`Six letters. It shows you everything
  except yourself.`); neither shows the word.

**The verdict pair — one story on both screens:**
- `host/snap_reveal_8563.png` vs `join/snap_mirror_verdict_8358.png` —
  near pixel-identical: `MIRROR` spelled in gold, the `▲ BLUE` unmask banner
  over the board, BLUE's portrait spotlit while the others dim, GOLD's and
  MINT's chips stamped LOCKED under BLUE, RED's `?` chip unlocked. The
  mirror fired its spotlight/reactions locally from the `rev` fact and
  landed on the identical frame.

**Flow shots:** `join/snap_online_client_lobby/ready/gate` (phase-1 lobby
mirror alive and well), `join/snap_online_client_game_1286.png` (the mirror
already up during the séance INTRO — no spectate card), `host/
snap_accuse/settle`, and both reckonings (`host/snap_online_host_reckoning
_9384.png`, `join/snap_online_client_reckoning_9172.png` — same ladder).

### Couch tally receipt — the transport did not perturb the sim

The `--seancetally` harness (couch baseline) run from a PRISTINE `git
worktree` of HEAD (87ea91a) vs this working tree, seeds 7 / 11 / 42:

```
godot --headless --path . res://minigames/seance/seance.tscn -- --seancetally --seed=N
```

- **`======== SEANCE TALLY ========` blocks: byte-identical, all three seeds**
  (seed 7: `word=VELVET charlatan=BLUE success=true caught=true
  correct_votes=3`; seed 11: `word=GHOST charlatan=RED success=false
  caught=true correct_votes=3`; seed 42: `word=GHOST charlatan=RED
  success=false caught=false correct_votes=1`) — points, suspicion, focus,
  commits, cause: all equal to the pristine baseline.
- Every `SEANCE_*` logic line matched too, with ONE honest exception: the
  wall-stamps on `SEANCE_SITTING_START t=…` / `SEANCE_VOTE_OPEN t=…` wander
  ±≈1 s **run to run on identical code** (the 0.5 s boot timer under
  `time_scale 8` is wall-clock coupled — pre-existing). Proof it is noise,
  not drift: the post-change build run twice against itself moved the same
  stamps by 0.4 s, and the *sitting duration* (`VOTE_OPEN − SITTING_START`)
  is tick-exact in every pairing (48.8 s / 48.8 s seed 7, 78.0 s / 78.0 s
  seed 42).

### NETHASH_MOD — mirror integrity + bandwidth

Host prints a digest + byte size of every 40th module snapshot at send;
client prints the digest of the same snapshot at apply, keyed by seq (never
wall clock):

- Run 1: **61/61 digest pairs identical.** Run 2: **56/56 identical.** Zero
  mismatches across both nights.
- **Bandwidth (measured, `var_to_bytes` of the full snapshot):** min 776 /
  median ~1100 / max 1468 / mean 1066 bytes. At the 20 Hz pump that is
  **≈21 kB/s per guest** (~64 kB/s at a full table of 3 guests) — three
  orders of magnitude under a video stream, exactly the spec's "state, not
  pixels" posture. Input relay upstream stays the phase-1 ≈1.2 kB/s.
- The 15 Hz walker NETHASH from phase 1 still runs and still matches
  (lobby mirror unperturbed by the module channel).

### Regressions (offline behavior untouched)

```
godot --headless --editor --import --quit --path .                          # clean
godot --headless --path . res://minigames/seance/seance.tscn -- --seancetally --seed=7|11|42
                                            # TALLY blocks byte-identical to pristine HEAD
godot --headless --path . -- --estate --auctiontest                         # AUCTIONTEST PASS: game launched
godot --headless --path . -- --estate --estatebots --quitafter=3200         # clean, zero script errors
godot --headless --path . -- --strolltest                                   # clean, zero script errors
```

The final code state re-ran `--seancetally --seed=7` once more after the
last edit (the paired sitting snap): still byte-identical.

## Save discipline

`user://` (party_setup.json, prefs.json, estate_save.json, cosmetics.json,
saves/slot_1.json) backed up with md5 hashes before ANY run and restored
byte-identical after the last one (hashes re-verified). The probe itself also
does its own `.npbak` dance for party_setup/prefs, as in phase 1.

## Honest limitations

- **Chant-tick rhythm on the mirror is quantized to the 20 Hz snapshot** —
  other sitters' candle flares land within ~50 ms of truth. The audible
  who-is-off-beat tell survives but is coarser than the couch. If a
  playtest says it matters, per-tap timestamps can ride the snapshot later.
- **The mirror's own screen shows its own taps at snapshot latency too**
  (the flare comes back from the host). Cosmetic local echo for your own
  candle is a cheap later polish, per spec §4.2's "local echo v1: none".
- **The podium is not mirrored** — the client sees the spectate card for
  the ~4 s ceremony, then the mirrored reckoning. Phase-3 chore.
- **The vote panel opens on the mirror at TALK entry**, ~2.4 s before the
  host's banner-grace beat shows it. Same information, slightly earlier
  furniture. Deliberate simplification.
- **The host's confetti fires ~1.7 s after the unmask (in
  `_verdict_moment`); the mirror celebrates at the unmask fact.** Same
  news, one beat of drift, both local juice.
- **Trust posture:** stamps and packets are friends-lobby trusted (spec:
  not an anti-cheat surface). The ±150 ms stamp window is the only guard.
- **A beat-stamp could theoretically arrive after its tap's input packet**
  (reliable vs unreliable channels race). The stamp then sits ≤350 ms and
  is consumed by the NEXT tap or expires; on loopback it never happened
  (run 2: 14/14 stamps `used=true`; run 1 the same pattern).
- Killcam-skip gating (spec §1.2.2) remains an open phase-2 chore — the
  séance has no killcam, so it does not bite this lane.
- Both instances share one `user://` on a dev machine — probe-bounded, and
  everything restored by hash after the runs (below).

---

## PATTERN NOTES — for the fan-out agents (phase 2 wave)

**Copy these VERBATIM (they are the pattern):**

1. **The guard.** Top of `_physics_process`:
   `if _mirror: _mirror_tick(delta); return` — and `_mirror` comes from
   `config.get("net_mirror", false)` in `begin()`. Nothing else in the sim
   may branch on it.
2. **The begin() split.** Fence ONLY the parts a mirror must not do: secret
   draws, bot construction, economy events, the INTRO kick. Build the world,
   the pawns and the per-seat arrays exactly as the host does — shared
   helpers stay index-safe on both sides.
3. **`_net_state()`** returns one flat Dictionary of snapped floats, short
   strings and small arrays. Ask of every key: "is this on every couch
   player's screen right now?" If not, it does not go in. Hidden info goes
   through `NetSession.send_module_private(seat, {...})` at the moment the
   secret is dealt.
4. **`_net_apply(state)`** stores the dict, diffs against the previous one,
   and fires ALL juice from the deltas (counters, not events — a dropped
   packet then loses nothing but intermediate frames). Continuous motion only
   sets targets; a `_mirror_tick` interpolates at 60 Hz.
5. **The shell is already done for you.** The estate pumps any contract
   module exposing `_net_state()` at 20 Hz and boots/folds the client mirror
   off the `mirror` lobby fact. You implement two methods (+ optionally
   `_net_apply_private`) and NOTHING else outside your game directory.
6. **Verification shape:** couch tally byte-diff (pristine HEAD worktree vs
   yours), the two-instance `--netprobe` night with `--pool=<your game>`,
   paired windowed screenshots read by eye, `NETHASH_MOD` seq-keyed digests,
   and the bandwidth line (bytes × 20 Hz). Back up and restore `user://`.

**What is séance-specific (do NOT copy):**

- Every key inside the state dict (letters string, focus, planchette XZ,
  taps/pull/surge) — yours will be pawn transforms + your HUD facts.
- The beat-stamp chant adjustment (rhythm-judged input is a séance quirk;
  most games need nothing — the input relay is already fair enough at party
  cadence).
- The cast-card theater in `_net_apply_private` (but its SHAPE — host
  composes content, client plays it locally, public fact stays redacted — is
  the template for understudy's word flash).
- The redacted `_cast_pub` twin. If your game has no eyes-closed phase you
  don't need a public/private split of any overlay.

**Gotchas found so far:**

- Call the tally/scene with its FULL scene path (`godot --headless --path .
  res://minigames/<g>/<g>.tscn -- --<g>tally`) — without the scene you boot
  the title menu and wait forever.
- `Sfx`/tween juice helpers used by the mirror must not read sim state that
  only the host has — factor render-only helpers (`_paint_letter`,
  `_render_dwell`, `tick_fx`) and share them.
- Snapshot dicts serialize natively over RPC (Vector2/3 fine); use
  `Color.to_html()` strings for colors; `NetSession.snapshot_hash` both ends
  for the NETHASH receipt (insertion order is preserved through the wire, so
  the hashes match).
- The winget `godot` shim spawns `Godot_v4.6.2-stable_win64` — kill THAT if a
  probe wedges, `tasklist /FI "IMAGENAME eq godot.exe"` sees nothing.
