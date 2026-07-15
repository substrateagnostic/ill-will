# PARITY NIGHT 4 — verification-only lane (couch-trust online-safety audit)

*Verification-only pass. No code changed. Mission: independently re-verify
prior recon's claims about seance/understudy/masked_ball private delivery
with FRESH paired-instance evidence against the CURRENT code state, then
sweep the rest of the anthology + estate flow for couch-only assumptions
recon may have missed. Evidence lives under `verify_out/parity_night4/`
(screenshots + full logs); this doc is the only write to `docs/verify/`.*

Engine: Godot 4.6.2 (Windows), run via a privately-copied binary
(`g_v4n.exe`, scratch-dir only) on private ports (8930-8934, one per probe
pair) so this lane could not collide with any other agent's probe on the
same machine.
`user://` (`ILL WILL` app_userdata: cosmetics/estate_save/party_setup/prefs/
slot_1) was hashed and backed up to `verify_out/parity_night4/userbak/`
before any run; `party_setup.json` was seeded with the standard BOTMIX
config (`seat0 HUMAN, seats1-3 BOT`, matching `VERIFY-BOTMIX.md`) so the
joining probe lands on seat 1 as prior nights assumed — the live machine's
real `party_setup.json` had drifted (two human seats persisted from a real
play session), which is itself the first finding below.

---

## 1. Verdict table — the three recon claims

| # | Claim (from recon) | Verdict | Evidence |
|---|---|---|---|
| 1 | **THE SÉANCE**: private role/word card delivered ONLY to the owning remote seat via `send_module_private`; host + every other screen show a REDACTED card; no leak in `_net_state()` | **VERIFIED** (fresh, current code) | `verify_out/parity_night4/seance/host/snap_cast_5695.png` (host: "▲ BLUE · summoned across the wire · THE CARD IS DELIVERED TO THEIR SCREEN ALONE") vs `verify_out/parity_night4/seance/join/snap_mirror_cast_5739.png` (client: "THE WORD IS \"GHOST\" · YOU WERE PAID — 2 GRUDGE"). Log: `SEANCE_PRIV cast card received (seat 1) — content lives on this screen alone` (join log) paired with `SEANCE_FORCECHAR idx=1` (host log). Full run reached REVEAL/RESULTS/podium/reckoning; `NETHASH_MOD` module-snapshot digests **73/73 identical** between host and client (zero mismatches). Logs: `verify_out/parity_night4/logs/seance-host2.log` / `seance-join2.log`. |
| 2 | **THE UNDERSTUDY**: same private-delivery pattern for the cast card / "you never got the script" card | **VERIFIED** (fresh, current code) | `verify_out/parity_night4/understudy/host/snap_host_redacted_6525.png` (host: "SUMMONED ACROSS THE WIRE · THE SCRIPT IS DELIVERED TO THEIR SCREEN ALONE") vs `verify_out/parity_night4/understudy/join/snap_mirror_card_2758.png` (client: "TONIGHT'S PLAY · THE HAUNTING"). Log: `US_PRIV call card received (seat 1, cast) — content lives on this screen alone`. Full run reached RESOLVE/podium/reckoning cleanly. Logs: `verify_out/parity_night4/logs/understudy-host.log` / `understudy-join.log`. |
| 3 | **MASKED BALL**: feather-glint self-ID is leak-proof by construction (untagged glint counters, zero `send_module_private` use, body-indexed not seat-indexed state) | **VERIFIED** (fresh, current code) | `verify_out/parity_night4/masked_ball/host/snap_mb_net_waltz_11520.png` vs `join/snap_mb_client_waltz_11387.png`: 20 identical hooded dancers, no badge/ring/tag on either screen, one snapshot beat apart (timer 70/71) — only deliberate divergence is the hint-bar legend (host shows real KBM keys, mirror shows generic). Log: 6/6 `MB_GLINT seat=1 body=13` events (host, t=13.1…20.1) paired with `MB_MIRROR_GLINT body=13` at the same timestamps on the client — interleaved with dozens of untagged decoy glints on other bodies (11, 5, 9, 17, 3, 14, 19, 6, 0, 18, 12, 16…), reproducing the "correlation is the only signal" design exactly. Confirmed `send_module_private` is never called anywhere in `masked_ball.gd` (grep). Full run reached the last dance / champion (`BLUE, Belle of the Ball`, 16 pts) / podium / reckoning; `NETHASH_MOD` digests **48/48 identical**, zero mismatches. Logs: `verify_out/parity_night4/logs/maskedball-host.log` / `maskedball-join.log`. |

## 2. Sweep — couch-only assumption checklist (items a–e from the brief)

**(a) "Look away / close your eyes / point at the screen" instruction text.**
Grepped every `minigames/*/*.gd` for eyes-closed / look-away / no-peeking
language. Only two hits, both already covered by claim 1/2 above and by
`docs/verify/eyesclosed-VERIFY.md`: `seance.gd` ("close your eyes. All of
them.") and `understudy.gd` ("the card can be read — the only cue a player
with eyes closed gets."). No other game contains this language — confirmed
by grepping all 12 `_net_state()`-owning modules for `send_module_private`
usage: **only seance.gd and understudy.gd call it.** Masked ball's
zero-delivery design was independently re-derived by reading
`masked_ball.gd` `_net_state()`/`_net_apply()` and confirmed no
`send_module_private` call exists in that file. No missed eyes-closed
mechanic anywhere else in the anthology.

**(b) Controller-rumble / local-effect-only information.**
Grepped `core/player_input.gd` and the full `minigames/` tree for
rumble/vibration/haptic APIs. **None exist in this codebase.** Not
applicable — nothing to leak or lose online.

**(c) Ceremonies (podium / auction / will-reading / parade) — does a remote
guest see everything a couch guest sees?**
Already exhaustively probed by `docs/verify/online-ceremonies-VERIFY.md`
(phase-3 lane): podium, RECKONING ticker, night podium, WILL READING,
PARADE all mirror word-for-word via ceremony-stage facts. One **known,
documented, pre-existing gap** re-confirmed by code read
(`estate.gd:2903-2934`, `_client_build_auction_rows`): **auction bidding is
read-only for remote guests** — `_on_bid` is wired only to host-local UI
buttons; guests get the same quip/pot/leader text but no bid button. This
is a functionality asymmetry (a remote guest cannot spend grudge to steer
which game gets picked), not an information leak — couch guests can act,
remote guests can only watch. Listed as a fix-list item below (severity:
low-medium — cosmetic to the couch-trust question, real to online fairness).

**(d) QUIT/pause overlay — what does the CLIENT see when the HOST pauses?**
**NEW FINDING, not caught by prior recon.** Traced via code, confirmed
live. See §3 below — this is the most severe item found this lane.

**(e) Disconnect mid-minigame — clean bot conversion? Reconnect handling?**
Code-traced in full:
- `NetSession._on_peer_disconnected` → `estate._on_net_peer_left_seat`
  (`estate.gd:2407`): seat flips to BOT immediately, `Sfx.play("grudge")`,
  and a host-visible flash `"THE WIRE TO <NAME> WENT DEAD — <NAME> PLAYS
  ITSELF UNTIL FURTHER NOTICE"` — matches the couch's own gamepad-unplug
  behavior (`_on_net_peer_left_seat`'s own comment: "exactly the couch
  unplug behavior"). **VERIFIED by code**, consistent with the disconnect
  behavior already implicit across every online-*-VERIFY.md lane.
- Reconnect **mid-game** is explicitly declined with a clear reason:
  `_on_net_seat_requested` (`estate.gd:2383`) returns `"the estate is
  mid-game — knock again between games"` when `phase` isn't
  LOBBY/GROUNDS/TITLE; the client's `_on_net_seat_granted` flashes `"THE
  ESTATE DECLINED: <reason>"` and calls `NetSession.leave()`. Clean,
  understandable failure mode.
- The abandoned client's own `_on_net_session_closed` (`estate.gd:3129`)
  fires `"THE NIGHT WENT DARK — <reason>"` and returns to title — gated on
  `phase == LOBBY or phase == GROUNDS`, which reads like a trap for a
  client mid-GAME, but tracing every `phase =` assignment in the file shows
  the **client's local `phase` variable is never reassigned past `LOBBY`
  once a seat is granted** (`_enter_client_lobby` sets it once; every other
  `phase = Phase.X` assignment lives in host-only flow functions the
  client's `_process` never reaches, since `_process` early-returns into
  `_client_process` for `NetSession.is_client()`). So the guard is
  vacuously always-true for a client — disconnect-to-title fires
  regardless of what ceremony/mirror was on screen. **VERIFIED by code**;
  not independently re-timed live this lane (see Honest limitations) —
  ENet's default peer-timeout means "how many seconds until the client
  notices" was not measured, only that it eventually does the right thing.

## 3. THE FINDING — host pause silently kills every remote guest's session

**Severity: CRITICAL. Not caught by any prior online-*-VERIFY.md lane.**

`core/party_setup.gd` (`toggle()`, line 140) sets `get_tree().paused = open`
when a player opens the ESC settings overlay — this is how the game has
always paused for a solo/couch session. `estate/estate.gd`'s root node has
no `process_mode` override (confirmed: `grep process_mode estate.tscn` —
no matches), so it defaults to `PROCESS_MODE_INHERIT`, which — with no
ancestor override — behaves as **pausable**. `estate.gd:_process()`
(line 1288) is where `_net_host_broadcast()` lives (line 2439: the lobby
state / walker / module-state pump to every guest, at 5/15/20 Hz). Only
three nodes in the whole project are explicitly `PROCESS_MODE_ALWAYS`:
`NetSession`, `PartySetup`, and `Music` (`grep -rn process_mode core/`).
**The estate itself is not one of them.**

Consequence, traced end to end: HOST presses ESC → `get_tree().paused =
true` → the Estate node (and any running game module, also a plain child)
stops processing → `_net_host_broadcast()` stops firing → **every remote
guest stops receiving lobby/walker/module snapshots the instant the host
pauses** → the guest's screen freezes on the last snapshot, with **zero
signal that anything happened**. On the couch, pausing is inherently
visible — everyone sitting at the shared screen sees the SETTINGS overlay
appear and knows why the game stopped. Online, the couch's shared-screen
assumption silently breaks: a remote guest sees a frozen, unresponsive
game and has no way to distinguish "the host is in their settings menu"
from "the connection died" or "the game crashed." This is exactly the kind
of couch-only assumption the playtester's brief was worried about, just in
the opposite direction from the seance/understudy hidden-info concern:
instead of *leaking* information, the couch's shared-context cue (everyone
sees the pause) is *lost* online.

**Live-tested, twice, reproduced both times — and the finding is WORSE than
the code read predicted.** Method: `--opensettings=0` auto-opens the host's
settings/pause overlay ~0.8s after boot (existing dev flag, no code
changed); both host and client take frame-indexed screenshots
(`--shots=`) that keep firing even while paused (`VerifyCapture` is
explicitly `PROCESS_MODE_ALWAYS` for exactly this reason).

*Run 1* (port 8931, clean fast localhost handshake — peer connected before
frame 30): `verify_out/parity_night4/pause/`.
- `host/shot_0030.png` vs `join/shot_0030.png` (~0.5s, pre-pause baseline):
  both normal — host mid-lobby, client shows a fully populated "SEAT
  CLAIMED" lobby panel (RED HUMAN, BLUE(you) REMOTE, GOLD BOT, MINT BOT).
- `host/shot_0180.png` (~3s): the HOST is now in the SETTINGS overlay
  ("ESC to close — game is paused"), browsing the SEATS tab.
- `join/shot_0180.png` (~3s): **pixel-identical to `shot_0030.png`** — same
  flash text mid-fade, same walker positions, same everything. The client
  is frozen solid with **zero visual indication** the host paused.
- `join/shot_0500.png` (~8.3s): the client has silently returned to the
  **TITLE SCREEN** ("ILL WILL — a party nobody asked for"). No error text,
  no banner, nothing in the client's own log between `VERIFY_SHOT
  shot_0180.png` and `VERIFY_SHOT shot_0500.png`. The host log shows no
  `NET peer ... left` line either — **neither side logs anything explaining
  the drop.**

*Run 2* (port 8934, denser sampling every ~1.7s, `verify_out/parity_night4/pause2/`)
confirms the same end state on an independent run and narrows the window:
by `join/shot_0120.png` (~2s) the client is still on the "waiting for the
estate to describe itself…" / empty-lobby placeholder (this run's
handshake was slower under machine load — the host's own `NET peer ...
connected` print landed after its frame-220 shot); by `join/shot_0220.png`
(~3.7s) it is **already at the title screen.** So the guest-drop happens
somewhere in the **2-8 second range** after the host pauses, consistently,
across two independently-timed runs.

**Escalated verdict: this is not merely a silent freeze — the online
session does not survive the host pausing at all.** Every connected guest
loses their connection within single-digit seconds and is bounced to the
title screen with no explanation, whether or not the lobby had ever fully
populated for them. The couch-comparison stands even more starkly here:
pausing on the couch is instantaneous, visible, and fully reversible for
everyone at the table; pausing online silently ends the party for every
remote guest. The exact trigger (an ENet-level peer timeout starved by the
host's own paused processing vs. some other multiplayer-poll interaction
with `SceneTree.paused`) was **not** root-caused this lane — that is
verification-only scope — but the OUTCOME is reproduced and photographed
twice. Evidence: `verify_out/parity_night4/pause/`,
`verify_out/parity_night4/pause2/`, and
`verify_out/parity_night4/logs/pause-host.log` / `pause-join.log` /
`pause2-host.log` / `pause2-join.log`.

### Secondary/related observations (lower severity)

- **The client's OWN pause is not obviously safe either.** `PartySetup` is
  `PROCESS_MODE_ALWAYS`, and so is `NetSession` — meaning a CLIENT who
  opens their own ESC menu does **not** stop `NetSession._sample_and_send()`
  (client physics-process input sampling), because `NetSession` keeps
  running through the client's own local pause. Raw device state
  (`Input.is_action_pressed` etc., read by `PlayerInput`) is not gated by
  `SceneTree.paused` either. In principle a client sitting in their own
  settings menu could still be feeding live WASD/stick state to the host
  and moving their pawn on every other player's screen while believing the
  game is paused for them. Not independently confirmed by a dedicated probe
  this lane (time-boxed out) — flagged for the fix list as a code-read
  finding worth a follow-up live check.
- **House rules primer (`_show_house_rules`, `estate.gd:1519`) is
  host-only by explicit design** (`_should_show_house_rules` returns
  `false` when `NetSession.is_client()`). A remote guest who joins while a
  brand-new host is reading the one-time economy primer sees an ordinary,
  unexplained lobby wait of up to `HOUSE_RULES_TIME` (~45s per the commit
  history) with no indication why nothing is progressing. Narrow edge case
  (fires once per fresh estate save) but same family of bug as the pause
  finding: a host-local modal with no online echo.

## 4. Other technical notes gathered along the way

- **MTU warning, reproduced live, séance settle beat:** `WARNING: Sending
  1400 bytes unreliably which is above the MTU (1392), this will result in
  higher packet loss` (`seance-host2.log`, fired from
  `send_module_state` → `_net_host_broadcast:2462` during the ledger-row
  settle beat, where the snapshot briefly carries several ledger strings).
  Loopback hides the consequence (no actual loss observed — `NETHASH_MOD`
  stayed 73/73), but real internet paths fragment/drop packets above MTU;
  the original `online-seance-VERIFY.md` bandwidth section recorded a
  max-observed 1468 B snapshot without flagging this ENet warning. Worth a
  follow-up: either shrink the ledger-row payload or accept ENet's
  fragmentation (it still delivers, just double-sends) at real-world RTTs.
- **Sweep of the remaining 9 mirrored games** (`dead_weight`,
  `echo_chamber`, `greed`, `last_will`, `mower`, `orbital`, `swap_meet`,
  `throne`, `tilt`) via each game's own `online-*-VERIFY.md` "Honest
  limitations" section plus a targeted grep for
  `send_module_private`/`REDACTED`/eyes-closed/rumble/accuse/vote language:
  **no privacy leak or couch-only assumption in any of them** — every gap
  on record is cosmetic/latency (snapshot quantization, mirror-only local
  echo, un-mirrored podium confetti timing) or an explicitly non-mirrored
  ragdoll/anim detail. None of the 9 have a hidden-role or asymmetric-info
  mechanic — confirmed by grep (`accuse|vote|social` across
  `minigames/*.gd` only matches seance/understudy/masked_ball files).

## 5. Fix list (for a follow-up build lane — no code touched this lane)

| # | Severity | File | Issue | Suggested approach |
|---|---|---|---|---|
| 1 | **Critical** | `estate/estate.gd` (root node / scene), `core/party_setup.gd`, `core/net_session.gd` | Host pause (`get_tree().paused`) stops `_net_host_broadcast()`; every remote guest freezes with no explanation and, reproduced twice, the session itself dies within ~2-8s, silently bouncing the guest to the title screen with no error | First root-cause WHY the connection actually drops (ENet peer timeout vs. a multiplayer-poll/pause interaction — instrument `NetSession._process`'s ping accumulator and `_rtt_ms` during a paused window to see if pings truly keep flowing). Then fix at two levels: (a) make the Estate node `PROCESS_MODE_ALWAYS` (or route broadcast through a node that already is) so `_net_host_broadcast` never stops just because the host opened settings, and (b) regardless of (a), have `PartySetup.toggle()` push one last lobby fact (`{"host_paused": true}`) before pausing so a client that DOES lose the stream at least has a last-known "the host stepped away" fact to render instead of silently timing out |
| 2 | **Medium** | `core/party_setup.gd`, `core/net_session.gd` | A CLIENT's own ESC pause does not stop `NetSession`'s input sampling (both `PROCESS_MODE_ALWAYS`), so raw device state may keep streaming to the host while the client believes they're paused | Gate `_sample_and_send()` (or the raw `PlayerInput` reads it depends on) on `not get_tree().paused` for the client role specifically, or freeze/zero the outgoing packet while the local settings overlay is open |
| 3 | **Low-Medium** | `estate/estate.gd` (`_client_build_auction_rows`) | Remote guests cannot bid at auction (read-only card) — a couch guest can spend grudge to steer game choice, a remote guest cannot | Add a `bid` panel-intent (mirrors `ready_toggle`'s existing pattern) so `_on_net_panel_intent` can call `_on_bid(seat)` for a guest's own seat |
| 4 | **Low** | `estate/estate.gd` (`_should_show_house_rules`, `_net_build_lobby_state`) | First-night HOUSE RULES primer is host-only; a guest joining during it sees an unexplained stall | Add a `house_rules: true` fact to the lobby broadcast while `_house_rules_active`, and render a short "the host is reading the house rules" waiting card client-side |
| 5 | **Low (robustness, not correctness)** | `estate/estate.gd` / `minigames/seance/seance.gd` `_net_state()` | Séance settle-beat snapshot (ledger rows) exceeds ENet's safe MTU (1400 > 1392), logged as a runtime warning | Trim the ledger-row payload (send row deltas instead of the full accumulated list) or accept the existing double-send fragmentation cost at real RTTs |

---

*Evidence root: `verify_out/parity_night4/` (screenshots, full stdout logs
for every probe, `userbak/` with the pre-run `user://` md5 manifest).
`party_setup.json` was restored to its pre-lane state after the last probe
(see the manifest in `userbak/`).*
