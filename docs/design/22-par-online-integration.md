# PAR ONLINE — Phase 3 integration (Par for the Curse)

Engine: Godot 4.6.2 (Windows). Par is the 13th and last of the games to cross
the wire. It is the crown jewel with **FROZEN physics** (ball putt / damping /
cup magnet / drag-mapping untouched), and its control surface — mouse drag-putt,
hold-charge swing, ghost trap placement, all on the shared hotseat device `-3` —
**bypasses the `PlayerInput` relay** every other game rides. So par does not
cross as relayed input; it crosses as **seat-attributed intents**, applied into
the one frozen entry point the sim already exposes, with a house-pattern render
mirror on top.

Writable surface for this lane: `scripts/*` (par module) + docs. `core/*`,
`estate/*`, `minigames/*` were left untouched. **No `NetSession` change was
needed** — the existing module-state pump + panel-intent channel are sufficient
(see §6 for the one estate-side seam the core lane still owns).

---

## 1. The intent layer (the refactor)

Every putt now enters the sim through **one funnel**, attributed to a seat:

```
submit_putt_intent(seat, power, angle)      # main.gd
    client + seat==my_seat  ->  NetSession.send_panel_intent({kind:"par_putt", ...})
    host / offline          ->  _apply_putt_intent(seat, power, angle)

_apply_putt_intent(seat, power, angle)
    putt_controller.ball = balls[seat]
    (remote seat on host + addressed)  ->  avatar_shot.auto_swing(power, angle)
    else                               ->  putt_controller.debug_putt(power, angle)   # FROZEN
```

`(power, angle)` is exactly the shape `debug_putt(power, angle)` already took.
The producers were rewired to go through the funnel — **no logic duplicated**:

| producer | file | path |
|---|---|---|
| embodied charge-swing (human + bot) | `avatar_shot.gd` `_fire_contact` | swing contact → `_main.submit_putt_intent(actor, power, angle)` |
| bot v3-direct fallback | `main.gd` `_bot_putt` | → `submit_putt_intent(actor, ...)` |
| remote guest | `main.gd` `_on_par_panel_intent` | `par_putt` → `submit_putt_intent(seat, ...)` |
| verify harness (`--physputt/--autoplay/--autoputt`) | `verify_capture.gd` | still calls `debug_putt` directly — it *is* the frozen primitive the funnel applies |

Offline / on the host the funnel is a **straight pass-through** to the same
`debug_putt(power, angle)` on the same numbers, on the same tick — hence
byte-identical (§5).

### Intent schema (client → host, reliable panel-intent channel)

```
putt          { kind:"par_putt",          seat, power:float, angle:float }
aim (preview) { kind:"par_aim",           seat, ax:float, az:float, power:float }   # ~7 Hz
draft pick    { kind:"par_build_pick",    seat, card:int }
build move    { kind:"par_build_move",    seat, x:float, z:float, rot:float }        # ghost drag stream
build confirm { kind:"par_build_confirm", seat, x:float, z:float, rot:float }
```

Builds reuse the mouse validity gate exactly: `placement_controller.remote_move`
(stream the ghost) and `remote_place` (commit when legal). A remote confirm that
lands on an illegal spot falls back to `debug_place_scan` so a guest can never
softlock the build. Par traps are **public**, so there is no private channel —
the draft hand and ghost ride the normal `_net_state()` fan-out.

---

## 2. The render mirror (house pattern)

Host pumps `main._net_state()` at **20 Hz** (`send_module_state`, unreliable
ordered ch.4); a joined guest boots the **same** `scenes/main.tscn` as a mirror
(`_online_client`), freezes its sim bodies, and drives everything from
`_net_apply()`. Juice fires from deltas; endings are pre-announced.

Snapshot is packed to stay under the ENet MTU (1392 B) even at a full board:

| key | type | contents |
|---|---|---|
| `b` | `PackedFloat32Array` | per ball: x, y, z, flags (sunk/dead/petrified/transit/visible) |
| `av` | `PackedFloat32Array` | per avatar: x, y, z, yaw, anim-code |
| `sc` | `PackedInt32Array` | per player: score, grudge, royalties |
| `tp` / `tid` | `PackedFloat32Array` + `PackedStringArray` | per trap: [netid, x, z, roty, author] + trap_id slug (color from author seat) |
| `ph`,`rn`,`rt`,`chaos`,`cur` | int/bool | phase, round, chaos flag, current putter seat |
| `rl`,`tl`,`tlc`,`sl`,`ban` | str/array | round / turn (+color) / stroke / banner labels |
| `draft`,`ghost` | dict | draft hand + placement ghost (only while active) |
| `kc` | dict | killcam **trigger fact** {seq, victim, credit color, death pos, border, text} |
| `champ` | int | pre-announced winner (facts minted the tick of `report_finished` never reach a mirror) |

The mirror restages the killcam **locally** from `kc` (its own low-angle replay
from the mirrored ball's recent motion) and the winner ceremony from `champ`.
Remote build ghost + aim line are streamed so the couch watches the guest line
up. Couch hotseat with **no** remote seats is exactly as before (every branch is
gated on the online role).

---

## 3. Standalone vs. estate

Par runs two ways and the same code covers both:

- **Standalone** (`--skipmenu` boots `scenes/main.tscn`, the estate frees
  itself): par is `current_scene`, so `_self_net = true` and par owns the whole
  online lifecycle itself — a `WAITING FOR A GUEST` lobby, seat grants on
  `seat_requested`, and the 20 Hz pump. This is the path the verification below
  drives.
- **Estate** (gamestate module, the shell stays alive): `_self_net = false`, so
  par does **not** self-pump or self-grant — the estate owns seat policy and the
  pump. Par still exposes `_net_state()` / `_net_apply()` and reads remote seats
  from `NetSession.is_seat_remote()`. `_online_init` falls back to the live
  `NetSession` role when no `--net` flag is present, so no launch-flag change is
  needed.

---

## 4. Files touched

- `scripts/main.gd` — intent funnel, `_net_state`/`_net_apply`, host seat-grant +
  intent routing + pump, client mirror + input, killcam/ending trigger facts,
  `--net`/`--netauto` args. (Offline branches all gated on the online role.)
- `scripts/avatar_shot.gd` — swing contact routes through `submit_putt_intent`.
- `scripts/placement_controller.gd` — `remote_move` / `remote_place`.

---

## 5. Byte-identical receipt gate (couch untouched)

Documented `--parbots` receipts (the wave2/3 harness, `--fixed-fps 60`), run on
**unmodified** code and again on the **full** phase-3 tree, diffed line-for-line:

```
godot --headless --fixed-fps 60 --path . -- --skipmenu --course=<c> --seed=<s> \
      --players=4 --rounds=4 --parbots --parquit --quitafter=200000 \
  | grep -E "MATCH_OVER|FINAL_RESULT|KILL_EVENTS n=|DEATH:|BALL_SUNK|GRIEF_|SWING_FIRE|GUTTER"
```

| course | seed | baseline | after phase 3 | verdict |
|---|---|---|---|---|
| fairway | 5 | 168 lines | 168 lines | **byte-identical** |
| widows_walk | 13 | 231 lines | 231 lines | **byte-identical** |

These lines carry every stroke (`SWING_FIRE power/angle/tick`, through the new
funnel), every death, `KILL_EVENTS`, and `FINAL_RESULT` — a complete behavioral
receipt. Both match exactly, matching the numbers in `VERIFY-PARV3.md` /
`docs/verify/par-v4-wave23-VERIFY.md`.

> Note on `--traceall` per-tick traces: they are sensitive to the pre-existing
> engine deferred-flush nondeterminism the wave-3 doc documents. On this machine
> under concurrent load, seed-7 `--parbots` produces **either** 2439 or 3886
> PTRACE lines run-to-run **on the unmodified/committed code itself** — so a
> per-tick diff is not a clean gate here. The event-line receipts above (which do
> not exhibit this flakiness) are the authoritative check and are identical.

---

## 6. Paired-instance verification (a remote seat plays a round)

Two **windowed** instances on one machine (windowed = real-time 60 fps, so the
ENet handshake has wall-clock time; a headless `--fixed-fps` client burns its
frame budget in ~2 s and quits before connecting):

```
# host (couch): seats 1-3 bots, seat 0 handed to the guest
godot --path . --position 0,40   -- --skipmenu --net=host \
      --course=fairway --seed=3 --players=4 --rounds=2 --parbots \
      --outdir=verify_out/par_online/host  --shots=700,1300,1900,2500,3100 --quitafter=3500
# guest: render mirror, auto-drives its seat through the intent channel
godot --path . --position 700,40 -- --skipmenu --net=join=127.0.0.1:8910 --netauto \
      --course=fairway --seed=3 --players=4 --rounds=2 \
      --outdir=verify_out/par_online/client --shots=700,1300,1900,2500,3100 --quitafter=3500
```

Observed (host log): `match start (guests=1)` → `recv par_build_confirm seat=0`
(the guest **placed a trap**) → `recv par_putt seat=0` ×7 across strokes (the
guest **putted via intents**) → `KILLCAM play victim=1`. Client log:
`PAR_MIRROR auto-putt seat=0` ×7, `PAR_MIRROR killcam seq=1 victim=1` (the guest
**saw the killcam**), 0 script errors. `--netauto` drives the seat with a machine
that ships the *same* intents a human would — it exercises the wire, not a
shortcut around it.

Paired screenshots (host + client, same beat), in `verify_out/par_online/`:

- `host/snap_paronline_host_putt_0725.png` + `client/snap_paronline_client_putt_0691.png`
  — both read **RED'S TURN · STROKE 3/6**, identical scoreboard, identical trap
  layout; the host shows the `AIM: REMOTE · HOLD REMOTE TO CHARGE` bar.
- `host/snap_paronline_host_killcam_1142.png` + `client/snap_paronline_client_killcam_1137.png`
  — the guest's mirror plays the full low-angle **GOLD'S THE CRUSHER — SIGNED
  WORK** instant replay; the host (a `--parbots` bot-only killcam) fast-skips and
  the snap catches the resumed diorama with the death banner.
- `host/shot_0700..3100.png`, `client/shot_0700..3100.png` — round coverage.

Whole-project smoke: `godot --headless --editor --import --quit --path .` clean
(534 assets, exit 0); estate boots and par runs on all five courses (fairway,
dogleg, green, the_gauntlet, widows_walk) with **0 script errors**.

---

## 7. The one estate-side seam still owned by the core/estate lane

Par is a **gamestate** module (`estate.gd` `info.mode == "gamestate"`), so unlike
the input-relay minigames it is added via `get_tree().root.add_child(_module)`
and reads `GameState` directly — it is **not** booted through `begin(config)`,
and the estate's phase-2 mirror seam (which lives only in the minigame `else`
branch) does not fire for it. To drive the par mirror **through the estate**
(rather than standalone), the estate needs two small additions. No `NetSession`
change is required — the pipe already exists.

**7a. Host: mark the gamestate module mirrorable.** In `_do_launch_game`, the
`info.mode == "gamestate"` branch, after `get_tree().root.add_child(_module)`:

```gdscript
if NetSession.is_host() and _module.has_method("_net_state"):
    _net_mirror_id = id
    _net_module_seq = 0
    _net_module_accum = 0.0
```

This is the identical two lines the minigame branch already runs; it lets the
existing 20 Hz pump (`_net_host_broadcast`) fan `_module._net_state()` to guests
and stamps `state["mirror"] = id` into the lobby facts.

**7b. Client: boot the par mirror without `begin()`.** `_client_ensure_mirror`
calls `_module.begin({net_mirror:true})`, which par (a gamestate module) does not
implement. Give it a gamestate branch that just instantiates the scene — par
self-detects the client role via `NetSession.is_client()` and enters mirror mode
in its own `_ready`:

```gdscript
if MODULES[id].get("mode", "") == "gamestate":
    get_tree().root.add_child(_module)     # par mirrors itself; no begin()
else:
    add_child(_module)
    _module.begin({... , "net_mirror": true})
```

With 7a + 7b, the estate-hosted flow uses the exact same `_net_state()` /
`_net_apply()` / intent code proven standalone above; par's `_self_net` guard
(`current_scene == self`) keeps it from double-pumping since inside the estate
`current_scene` is the estate, not par.
