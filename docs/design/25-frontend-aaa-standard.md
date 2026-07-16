# 25 — Front-End AAA Standard: Title, Attract Mode, Settings, Pause

Date: 2026-07-16. Engine: Godot 4.6.2. Author: research agent (Wave R, doc 23's
R2 lane), feeding B4 (FRONT-END AAA) in the same director's plan. Docs-only —
no code touched. Question answered: **what separates our front-end from a
shipped AAA party game?**

This doc does not repeat doc 14 (AAA UX Standard: controller assignment,
menus, scoreboards, HUD, juice) or doc 04 (menu-UX research digest, the
original MUST/SHOULD/LATER settings checklist) — both already did deep,
cited research on settings categories, pause conventions, hold-to-confirm
timing, and colorblind-palette floors. This doc **re-audits the codebase as
it stands today** (a full day after doc 14, several builds later — READY
ROOM v2 press-to-join, controller-disconnect overlay, and host-pause netcode
all landed since), closes the remaining named gaps with fresh sourcing
(attract mode, pause ownership in couch co-op, Hades/Celeste as praised
accessibility references), and turns the result into a build spec concrete
enough for B4 to implement directly.

**Housekeeping correction to the night's brief:** the brief that spawned this
doc describes colorblind palettes and text scale as "queued but unbuilt."
That is stale. Both shipped between doc 14 (2026-07-15) and tonight — see
§1 rows 6–9. What's actually still open is narrower and sharper than the
brief assumed: attract mode (never built), gamepad-reachable pause (literally
does not exist), and a handful of settings-panel polish/plumbing gaps. This
doc audits what's real, not what was assumed.

---

## 0. Where the pieces already live (read in full for this doc)

- **Title screen**: not a separate `.tscn` — `estate/estate.gd`'s
  `Phase.TITLE` (enum at line 5), built procedurally in `_enter_title_swap()`
  (lines 503–610) as a `Control` layer (`_title_layer`) parented under the
  estate's own `$UI`, sitting over whatever the estate's `$Camera3D` /
  `$WorldEnvironment` currently show. `project.godot`'s `run/main_scene` is
  `res://estate/estate.tscn` — the estate IS the shell; there is no
  boot-to-title separate scene to find.
- **Pause / ESC**: single source of truth, `core/party_setup.gd` (814
  lines), an autoload `CanvasLayer` at `layer = 90`,
  `process_mode = PROCESS_MODE_ALWAYS`. `_input()` (line 174) is the ONLY
  place `KEY_ESCAPE` is handled anywhere in the project (confirmed —
  no minigame or estate script intercepts it). `toggle()` (line 193) flips
  `get_tree().paused` and calls `_net_reflect_host_pause()` so a **host's**
  pause freezes every guest behind a "THE HOST HAS PAUSED" curtain
  (`_build_hostpause_overlay()`, line 367), while a **guest's** own ESC only
  pauses their local tree (comment at line 358 makes the asymmetry explicit
  and deliberate).
- **Prefs storage**: `user://prefs.json` (`PREFS_PATH`, party_setup.gd:12) —
  audio/video/access toggles, loaded/saved via `pref()`/`set_pref()`
  (lines 431–436). Device/keybind assignment is a **separate** file,
  `user://party_setup.json`, owned by `PlayerInput` (not read in full for
  this doc; referenced via `PlayerInput.save_setup()`/`load_setup()`).
- **Audio buses**: created at runtime, not from a `.tres` bus layout —
  `scripts/sfx.gd:_ensure_bus()` (line 115) makes `Music` and `SFX`;
  `core/ambience.gd:_ensure_bus()` (line 28) makes a **fourth**, `Ambience`.
  All three non-Master buses send straight to `Master`
  (`AudioServer.set_bus_send(idx, "Master")`).
- **SFX bank**: `scripts/sfx.gd`, 40+ keys (`BANK` dict, line 14), 10-voice
  round-robin pool, declicked-WAV preference over legacy `.ogg`.
- **Colorblind palettes**: `scripts/game_state.gd:PALETTES` (line 12) — 4
  presets (classic/deutan/protan/tritan), Machado-2009-simulated +
  CIEDE2000-checked per the file's own header comment, anchored on
  Okabe-Ito hues. `apply_palette()` (line 96) mutates `PLAYER_COLORS` in
  place so live readers (HUD, estate panels) pick up a change without a
  reload.
- **Never-color-alone identity**: `core/player_badge.gd` — every seat is
  color **+** a procedurally-drawn shape (circle/triangle/square/diamond,
  `Shape` enum line 19) **+** a name (RED/BLUE/GOLD/MINT). This is the
  concrete implementation of the "identity must survive color removal"
  principle doc 14 cites as a hard access requirement.
- **Input glyphs**: `core/input_glyphs.gd` — brand detection
  (`brand_for_device()`, line 62) sniffs `Input.get_joy_name()` for
  Xbox/PlayStation/Switch keywords, falls back to a generic pad glyph set,
  with a full keyboard glyph table too.
- **Hold-to-confirm**: `core/hold_confirm.gd` — a reusable `Control`
  (`HoldConfirm` class) whose progress is drawn as arc-length + tick marks +
  a moving spoke + a growing inner box, i.e. legible in grayscale (not
  color-coded progress). Used for QUIT TO TITLE (3.0s,
  `party_setup.gd:100`), controller-reclaim-to-bot (2.0s, line 250),
  force-start-night (1.5s, `estate.gd:722`), and slot-wipe (5.0s,
  `estate.gd:476`).
- **Bot/headless play tech (attract-mode raw material)**: `estate.gd`
  already has `bots`/`exhibition`/`_all_bots()` machinery, an `--estatebots`
  CLI flag, an `--exhibtest=<gid>` dev path that seats all 4 as bots and
  calls `_launch_game(gid)` with `exhibition = true` (line 145), and a
  `_launch_game()` (line 1780) that **skips the GET READY gate entirely**
  when `exhibition` or `_all_bots()` is true — i.e. an all-bot match already
  launches straight into gameplay with zero human-facing friction. This is
  exactly the launch path attract mode needs; nothing new has to be
  invented for "make bots play a game headlessly."
- **The house's 1920s film treatment (attract-mode dressing)**:
  `estate/newsreel.gd` + `assets/shaders/newsreel.gdshader` — sepia,
  animated grain, gate flicker, drifting scratches, dust motes, vignette,
  24fps-quantized time, Ken Burns zoom/pan. It is a `canvas_item` shader
  that samples its own bound `TEXTURE` (line 52: `texture(TEXTURE, uv)`) —
  **not** `SCREEN_TEXTURE` — so today it only ever decorates a static
  captured still (`_still: TextureRect`, newsreel.gd:33). See §3.2 for what
  that means for reusing it on **live** gameplay.
- **House cinematic lighting**: `core/env_kit.gd` — three presets
  (MOONLIT/CANDLELIT/STAGELIT), each a `WorldEnvironment` + a one-shadow-light
  rig, AGX tonemap, idempotent re-apply. **Confirmed: `estate.gd` never
  calls `EnvKit` anywhere** (grep returned zero matches) — the estate's
  grounds/title use a single hand-authored `$WorldEnvironment`, not this
  system. The title screen is not lit as a deliberate "hero shot"; it is
  whatever the grounds camera happens to be pointed at, dimmed by a flat
  `ColorRect` shade (`_enter_title_swap()` line 521:
  `Color(0.05, 0.03, 0.08, 0.45)`).

---

## 1. Gap table

| # | Feature | AAA floor | Our state | Verdict |
|---|---|---|---|---|
| 1 | Title screen exists with a hero composition | Deliberate camera framing, lit for mood, cast performs an idle beat, not a frozen loading-screen leftover | `Phase.TITLE` is real and functional (PLAY/NEW GAME/SETTINGS/MINIGAMES/WARDROBE/HOST/JOIN, see `verify_out/title3/shot_0300.png`) but renders on the **default grounds camera view**, no `EnvKit` mood lighting, characters stand frozen (spawn pose, no idle anim/breathing/glance), flat dark shade overlay | **Partial** |
| 2 | Title screen is controller-navigable | A gamepad can move focus and confirm without ever touching a mouse | No `grab_focus()` call anywhere in `_enter_title_swap()` — nothing has initial input focus, so a controller-only player at the title screen has no way to move onto PLAY without first clicking with a mouse | **Missing** |
| 3 | Attract/idle demo mode | Idle at the title long enough → the game demonstrates itself; any input interrupts instantly (arcade convention, still alive in 2024–25's UFO 50) | Does not exist. No idle timer, no auto-play trigger, anywhere in the codebase (`grep` for attract/idle-timeout found only this doc's own director's-plan mention) | **Missing** (but every load-bearing building block — bot autoplay, exhibition launch path, film-look shader — already exists; see §3.2) |
| 4 | Pause reachable from any player's own device | Xbox cert (TCR) treats "pause on disconnect/pause request" as a hard requirement; Start/Options is the universal couch-pause button on every console pad | Only `KEY_ESCAPE` opens the settings/pause overlay (`party_setup.gd:189`). **No gamepad button of any kind calls `PartySetup.toggle()` anywhere in the project** (confirmed by grep for `JOY_BUTTON_START`/`PartySetup.toggle`) — a controller-only player literally cannot pause the game | **Missing** — the single sharpest gap in this audit |
| 5 | One consistent pause implementation everywhere | Same pause menu, same button, same behavior in every mode/screen | Fully centralized: `party_setup.gd` is the only file that reads `KEY_ESCAPE`; no minigame installs its own ESC handler. Architecturally this is already correct — the only gap is the missing gamepad input path (row 4) | **Have** (mechanism) / see row 4 for the input-coverage gap |
| 6 | Mid-match controller-disconnect pause + reassignment | Hard platform requirement (XBOXTCR-1): detect, pause, show reconnect prompt | `party_setup.gd:_begin_disconnect_overlay()`/`_poll_disconnect_overlay()` — named/colored "X'S CONTROLLER DISCONNECTED" card, reconnect-to-resume, press-A-on-any-pad-to-reclaim, host-hold-B-to-bot-convert. Built and thorough | **Have** |
| 7 | Host-authoritative pause doesn't strand guests | A couch host's pause shouldn't silently desync or hang a remote guest | `NetSession.host_pause_changed` + `_hostpause_root` "THE HOST HAS PAUSED" curtain, guest-only, gated so a guest's own ESC can never freeze the shared table (party_setup.gd:358) | **Have** |
| 8 | Destructive/shared-consequence action = hold-to-confirm scaled to blast radius | 3s solo, up to 5s when it affects other people (doc 14 §2.4, HOLDCONFIRM-1) | QUIT TO TITLE forfeits 3 other players' game and is a 3.0s hold (`party_setup.gd:100`) — correct **mechanism**, under-scaled **duration** vs the 5s ceiling doc 14 already recommended for this exact case | **Partial** |
| 9 | Press-your-own-device-to-join (diegetic seat claim) | One input event → one seat filled, no menu detour (Overcooked/TowerFall pattern) | **Now built** — `estate.gd:_poll_pad_join()`, `_poll_kb_join()`, `_claim_seat_for_device()` — this closes doc 14's #1-ranked gap, which was flagged against an older read of the codebase | **Have** (doc 14 is stale on this specific point) |
| 10 | Identity-collision guard (two seats never share a device/color) | Hard-blocked, not warned (Smash's "same color glitch" fix) | `estate.gd:_next_free_device()`/`_device_taken_by_other()`/`_dedupe_human_devices()` | **Have** |
| 11 | Audio bus sliders | Master / Music / SFX at minimum | `party_setup.gd:_build_audio_tab()` — all three, live-applied, `AudioServer.set_bus_volume_db` + mute-at-zero | **Have** |
| 12 | Every audio bus that exists is reachable from settings | — | A **4th** bus, `Ambience` (`core/ambience.gd`), exists and routes straight to `Master`, but has no slider and isn't summed into Master's perceived loudness distinctly. Low urgency today — the file's own header says "nothing calls it tonight" — but it must gain a slider (or get re-routed as a `Music`/`SFX` child) **before**, not after, any game lane starts calling `Ambience.play_bed()` | **Partial** (dormant gap, cheap to close now while the cost is zero) |
| 13 | Video: display mode, vsync | Windowed / Borderless / Exclusive triad + vsync | `party_setup.gd:_build_video_tab()` — has both | **Have** |
| 14 | Video: resolution + FPS cap | Standard PC settings-menu contents | Neither exists (no `window_set_size`, no `Engine.max_fps` control found anywhere) | **Missing** |
| 15 | Colorblind modes | 3 CVD presets minimum (COLORBLIND-1) | 4 presets (classic + deutan + protan + tritan), Machado-2009 + CIEDE2000 validated, Okabe-Ito-anchored — exceeds the floor | **Have** (exceeds) |
| 16 | Never-color-alone identity | Shape/icon/text alongside color | `PlayerBadge` shapes + `GameState.PLAYER_NAMES` — both always travel with color | **Have** |
| 17 | Text scale | Scalable toward 200% of a console-legible floor (≥26px@1080p, XAG101) | UI-scale slider exists, 100–130% (`party_setup.gd` ACCESS tab) — **but** base font sizes across the estate's own panels run well under the 26px floor before any multiplier is applied (hint/caption labels commonly 14–16px; see `_build_lobby_panel()`, ACCESS-tab notes) — the slider works, but 130% of an undersized base is still undersized. Doc 14 flagged this exact risk (#7 in its own priority list) and it is still unresolved | **Partial** |
| 18 | Screen-shake / flashing-reduction toggle | Present, ideally labeled by *effect* not *diagnosis* ("Effects Intensity", not "epilepsy mode"), seizure-safety ceiling holds regardless of the toggle | `screen_shake` pref, labeled "SCREEN SHAKE," read by 8+ minigames (`grep` hit: dead_weight, tilt, throne, greed, last_will, orbital, widows_gaze + their sub-scripts) to gate camera shake, hitstop, vignette pulse. Functionally solid; naming is the literal diagnosis-adjacent pattern XAG118 advises against | **Partial** (works; naming/labeling gap only) |
| 19 | Haptics/rumble toggle | Explicit off + intensity, never the sole info carrier (XAG110) | No toggle **and** no underlying API — confirmed directly in this codebase's own verify notes (`docs/verify/parity-night4-VERIFY.md`: "rumble/vibration/haptic APIs. None exist in this codebase.") | **Missing** (there is nothing to toggle yet — this is an engine-plumbing gap, not just a UI gap) |
| 20 | Full remap, KB+M and pad separately, no unbindable state | Genre convention | `party_setup.gd` CONTROLS tab — per-device remap, conflicting binds auto-swap, pad A/B swap toggle | **Have** (exceeds — auto-swap-on-conflict is above table-stakes) |
| 21 | Input glyphs match detected device brand | Xbox/PlayStation/Switch/generic, never a wrong-brand guess | `core/input_glyphs.gd` — string-sniffs `Input.get_joy_name()` | **Have** |
| 22 | Settings screen doesn't collide with a live panel underneath | A settings/pause overlay should read as its own full moment, not a stacked artifact | Observed directly in `verify_out/settings2/shot_0400.png`: opening ESC-settings while the LOBBY seat panel is open renders both panels simultaneously, overlapping, with SETTINGS' text clipped at the frame's right edge and the LOBBY panel bleeding through underneath | **Partial/Missing** — a concrete, reproducible polish defect, not a hypothetical |
| 23 | Attract-mode dressing reuses house identity rather than inventing new visual language | — | The exact ingredients exist and are unused for this purpose: `newsreel.gd`'s intertitle-card builder (Bangers/Fredoka fonts, ornamental double-rule), the `newsreel.gdshader` film-decay look, `EnvKit` mood presets | **Missing (assemblable)** — see §3.2 for the concrete assembly plan |

**Tally: 8 Have, 8 Partial, 5 Missing** (rows 5 and 9 counted once each toward their primary verdict; row 5's sub-note isn't double-counted).

---

## 2. Web research — what AAA/praised-indie floors actually say

**Attract mode, arcade lineage to present.** The convention is old and has
never really left: an idle title screen triggers a self-playing demo after a
timeout, purely to signal "this thing works, come try it," and any input
snaps back to the real menu instantly [ATTRACT-1][ATTRACT-2]. The most
relevant *current* example is **UFO 50** (2024, Metacritic's top-rated
PC-exclusive that year): idling on its hub long enough cycles through demo
footage of each of the 50 games inside it, and several of *those* games have
their own attract-mode-within-the-attract-mode that doubles as a silent
tutorial [UFO50-2]. An indie developer describing their own convention-booth
build put it plainly: leave the title idle and it "cycled into a different
level with different characters being played by AI," with a large
**PRESS START**-style indicator on screen the whole time specifically so
passersby knew they could interrupt it [ATTRACT-3]. That detail — a
persistent, unmissable interrupt affordance, not just "any key exits
eventually" — is the one non-obvious requirement worth holding this build to.

**Hades / Celeste as the accessibility reference class doc 14 didn't need to
cite (different genre than the Xbox-guideline material).** Both are
"praised for shipping a settings menu that respects the player's specific
need without a difficulty-shaming label attached to it." Celeste's Assist
Mode (game-speed 50–100%, infinite stamina, invincibility toggles
independently) is the canonical **non-binary difficulty as accessibility**
pattern — and the team publicly walked back patronizing copy in that menu
once players flagged it, which is itself a lesson: settings-menu *language*
gets scrutinized as much as its contents [HADES-CELESTE-1]. Hades' God Mode
(scaling damage reduction per death, opt-in, silent about it once on) is the
same idea for a different axis (difficulty rather than motor/sensory
access) — relevant to ILL WILL mainly as reinforcement of doc 14's existing
"Effects Intensity, not epilepsy mode" naming guidance (row 18 above): the
pattern these two praised games share is *never* naming a toggle after the
condition it accommodates.

**Pause ownership in couch co-op — no single codified standard, three real
patterns.** Design discussion converges on three approaches rather than one
convention: (a) **host/authority-owns-pause** — one designated player's
pause request is the one that freezes the shared session; (b) **consensus**
— pausing requires acknowledgment from more than one player before time
actually stops; (c) **per-player independent menus** — inventory/status
screens open on that player's *own* half of the screen without stopping
time for anyone else, reserving a true full-stop pause for something rarer
[PAUSE-COOP-1]. ILL WILL has already picked (a) and built it correctly —
`NetSession`'s host-only pause-broadcast (row 7 above) is exactly the
authority model, and it is the right choice for a shared-camera (not
split-screen) couch game where there is no "your own half of the screen" to
open a menu on. The gap is not *which* player owns the pause conceptually —
it's that **only a keyboard can invoke it at all today** (row 4).

---

## 3. Build spec — the front-end lane, concrete enough to implement

### 3.1 Title screen rework

1. **Give TITLE its own lit composition.** In `_enter_title_swap()`
   (`estate/estate.gd`, ~line 503), apply `EnvKit.apply($WorldEnvironment's
   root, EnvKit.MOONLIT, {...})` (or STAGELIT, for a more theatrical framing
   consistent with "the house presents itself") when entering TITLE, and
   restore whatever `_saved_env` already holds (the field exists at line 50
   and is clearly used for exactly this swap-and-restore purpose elsewhere
   in the file — reuse the identical pattern, don't invent a new one).
2. **Controller focus.** After building the PLAY button (~line 551), call
   `play.grab_focus()` once the title layer is visible. This single line
   closes gap row 2 — Godot's own `ui_up`/`ui_down`/`ui_accept` input actions
   already drive `Control` focus navigation once *something* has initial
   focus; nothing has it today.
3. **Idle performance, not a frozen pose.** The four `EstateWalker`s already
   spawn for the title (`_spawn_walkers()`, line 1092) using the same
   character rig the grounds free-roam uses. Trigger an occasional idle beat
   — a slow head-turn tween, or whatever idle/gesture anim the KayKit rig
   already exposes for the grounds' own idle state — on a loose per-walker
   timer (~4–8s stagger) so the cast reads as alive, not paused mid-frame.
   This is cosmetic-only and safe to skip in a soak/all-bots boot path (gate
   it the same way `_bot_wander_timer` already gates the grounds' own
   idle wander at line 1387, i.e. skip when `_netprobe != ""`).
4. **Menu composition — keep, don't rebuild.** PLAY as the pre-focused hero
   action, a secondary row (NEW GAME / SETTINGS / MINIGAMES / WARDROBE), and
   a network row (HOST NIGHT / JOIN NIGHT) is already the correct shape and
   already matches doc 14's "Resume pre-focused" convention adapted to a
   title screen ("PLAY pre-focused"). No structural change needed — just the
   lighting, focus, and idle-performance work above.

### 3.2 Attract mode

**Trigger.** Add an idle-time accumulator in `estate.gd`'s `_process()`,
active only while `phase == Phase.TITLE`: reset on any `Input` event from any
device (reuse the same "any seated human" input surface `newsreel.gd`'s
`_poll_skip()` already samples via `PlayerInput`, plus a raw
`Input.is_anything_pressed()`-style catch-all so a not-yet-seated pad/kb
still resets the clock). Recommend a **45s** threshold — squarely inside the
classic arcade 30–60s attract-mode range [ATTRACT-1] and consistent with
this being a couch game where "sitting and talking before the next game"
idle periods are common and shouldn't trip a demo.

**On trigger — `_enter_attract()` (new function, `estate.gd`, alongside
`_enter_title()`):**

1. Back up the current seat/device config exactly the way `--albumtest`
   and `--readylobbytest` already do (copy `user://party_setup.json` to a
   `.bak` sibling) — this is a proven, already-used idiom in this exact file
   for "temporarily mutate seats, then restore on exit," not a new pattern.
2. Hide the title layer. Show a single intertitle card reading **"THE HOUSE
   REHEARSES"** using the *exact* card-building approach `newsreel.gd`
   already has (`_build_card()`/`_mk_label()`/`_rule()`, lines 134–177):
   Bangers-Regular header, Fredoka body, the ornamental double-rule. Either
   factor those three helpers out of `Newsreel` into a small shared static
   utility both files can call, or duplicate them (they're ~40 lines total)
   — factoring is cleaner but not required for a correct build.
3. Force all 4 seats to bots for the duration
   (`PlayerInput.set_bot(i, true)` for `i in 4`), pick a random **non-theater**
   module from `MODULES` (filter out entries with `"theater": true` — a
   theater game's whole premise assumes present humans reacting to each
   other, which reads as broken when nobody's there), set `exhibition = true`,
   and call `_launch_game(gid)` (line 1780) — this is the *exact* path
   `--exhibtest=` already exercises, so the "does a bot-only match launch and
   run cleanly" question is already answered by existing verify coverage.
4. **The live film-look wash — two options, pick by time budget:**
   - **Full version:** host the launched module inside a `SubViewport` +
     `SubViewportContainer` (instead of the module's normal tree-root
     parenting) and apply the *existing, unmodified*
     `assets/shaders/newsreel.gdshader` as the `SubViewportContainer`'s own
     `material`. This works because `SubViewportContainer` displays its
     child viewport's texture as an ordinary `CanvasItem` texture — the
     shader's `texture(TEXTURE, uv)` sampling (line 52) then reads the
     *live* game frame every tick, with no shader changes required. Set
     `zoom` near 1.0 and disable the per-still Ken Burns tweening (leave
     `pan` at zero) — attract mode wants to *show the whole match*, not crop
     into a slow push-in the way a static still does.
   - **MVP fallback (recommended if the night is tight):** skip the
     SubViewport reparenting entirely and let the bot match render exactly
     as `--exhibtest=` already renders it today (plain, no shader), keeping
     only the intertitle-card bookend and the persistent caption below.
     Upgrade to the full version in a later pass. Either way, ship the
     interrupt behavior and the "THE HOUSE REHEARSES" framing tonight —
     that's what actually sells "this shipped," the shader wash is a nice-to-have
     on top.
5. A persistent, low-opacity caption reading **"ANY BUTTON TO PLAY"**
   overlays the whole attract sequence — the named lesson from
   [ATTRACT-3]: an unmissable, constant interrupt affordance, not a
   blink-and-miss one-time hint.
6. **Interrupt.** Any input from any device: tear the exhibition module down
   the same way `quit_to_title()` already does (`free_stray_root_nodes()`,
   `Engine.time_scale = 1.0` reset — the existing zombie-module sweep is
   exactly what's needed here too), restore the seat/device backup from
   step 1, and re-enter `_enter_title()`.

### 3.3 Settings menu

1. **Ambience bus slider** (closes gap row 12, cheap now, expensive later):
   add a fourth row to `_build_audio_tab()` (`party_setup.gd`, ~line 665)
   mirroring `_volume_row()`'s existing pattern, targeting bus name
   `"Ambience"`. Do this **before** any game lane starts calling
   `Ambience.play_bed()`, not after — retrofitting a slider once players
   have already shipped-experienced an unadjustable bed is a worse look
   than never having exposed it.
2. **Quit-hold duration.** Doc 14 already flagged this precisely
   (HOLDCONFIRM-1: 3s solo / up to 5s shared-consequence). QUIT TO TITLE
   forfeits three other players' game — bump `_quit_hold.configure(3.0)`
   (`party_setup.gd:100`) toward the 5s end of that range.
3. **Screen-shake label.** Rename the ACCESS-tab toggle's visible text from
   "SCREEN SHAKE" to something effect-named ("EFFECTS INTENSITY" /
   "MOTION & FLASH REDUCTION") without changing the `screen_shake` pref key
   itself (every minigame reads that key by name — see the file-pointer map
   in §4 — so the key must not move, only its on-screen label).
4. **Video: resolution + FPS cap.** Add both to `_build_video_tab()`
   (~line 709): an `OptionButton` for a short list of common resolutions
   (or a simple width/height dropdown) driving
   `DisplayServer.window_set_size()`, and a numeric cap (uncapped / 60 / 120
   / 144) driving `Engine.max_fps`. Both are presentation-only, safe by the
   same reasoning as §5's risk notes.
5. **Rumble/haptics — do not add a toggle for a system that doesn't exist.**
   Confirmed twice over (this doc's own grep, and
   `docs/verify/parity-night4-VERIFY.md`'s explicit statement) that no
   rumble/vibration API exists anywhere in this codebase. Adding a toggle
   with nothing behind it would be worse than no toggle — it implies a
   feature. If a future lane wires `Input.start_joy_vibration()` for some
   game-feel purpose, the ACCESS tab gains the toggle **at that time**, not
   before.
6. **Text scale base sizes.** Not a settings-*menu* change but a
   settings-*honesty* one: before claiming the UI-scale slider "works,"
   audit the actual rendered glyph height of the estate's most common panel
   text (hint labels, seat rows) against the 26px@1080p floor doc 14 already
   cites, using that doc's own prescribed measurement method (screenshot →
   measure ascender-to-descender in pixels). This doc did not do that
   measurement (out of scope for a docs-only research pass) — flagging it
   as the next concrete step rather than guessing a number.
7. **Fix the settings/lobby double-panel overlap** (gap row 22): when
   `PartySetup.toggle()` opens while `estate.gd`'s own `phase_panel` (the
   LOBBY/GROUNDS panel) is visible, either (a) have `toggle()` hide
   `phase_panel` for the overlay's duration and restore it on close, or
   (b) reposition/resize `PartySetup.panel` so it never depends on the
   window being wider than its content — the screenshot evidence
   (`verify_out/settings2/shot_0400.png`) shows text clipped past the
   right edge, which is a layout bug independent of the overlap question.

### 3.4 Pause standard

**The one change that matters most in this whole doc:** wire a gamepad
button to `PartySetup.toggle()`. Concretely, in `party_setup.gd`'s
`_process()` or a new `_poll_pause_buttons()`, for every connected joypad,
edge-detect `Input.is_joy_button_pressed(pad, JOY_BUTTON_START)` (mirroring
the exact edge-detect idiom `_poll_pad_join()` already uses in `estate.gd`
for `JOY_BUTTON_A`) and call `toggle()` on the down-edge — from **any**
seated human's device, not host-only, since `toggle()` already routes
through the correct host/guest broadcast semantics
(`_net_reflect_host_pause()`) regardless of which local seat pressed it.
This reuses 100% of the existing pause machinery (disconnect-overlay
interlock, host-pause netcode, `_quit_hold`) — it is purely an additional
input trigger for a function that already does everything correctly. No new
pause *behavior* needs designing; only a new *input path* into the existing
one.

---

## 4. File-pointer map

| Change | File | Where |
|---|---|---|
| Title hero lighting (EnvKit) | `estate/estate.gd` | `_enter_title_swap()`, ~line 503; reuse `_saved_env` field (line 50) |
| Title controller focus | `estate/estate.gd` | after PLAY button creation, ~line 558 |
| Title idle performance | `estate/estate.gd` | `_process()` near the existing `_bot_wander_timer` gate, ~line 1386; walker refs already in `walkers: Array` |
| Attract idle timer + trigger | `estate/estate.gd` | new accumulator in `_process()`, gated on `phase == Phase.TITLE` |
| Attract entry/exit + backup-restore | `estate/estate.gd` | new `_enter_attract()`, mirroring the `--albumtest`/`--readylobbytest` backup idiom (~lines 210–265, 245–265) |
| Attract bot-match launch | `estate/estate.gd` | reuse `_launch_game()` (line 1780) + `MODULES` dict (line 9), filter `theater` key |
| Attract intertitle card | `estate/newsreel.gd` (extract helpers) or duplicate | `_build_card()`/`_mk_label()`/`_rule()`, lines 134–177 |
| Attract live shader wash (full version) | new `SubViewport`/`SubViewportContainer` wrapping the launched module | material = `res://assets/shaders/newsreel.gdshader` (unmodified) |
| Ambience bus slider | `core/party_setup.gd` | `_build_audio_tab()`, ~line 665, mirror `_volume_row()` |
| Quit-hold duration bump | `core/party_setup.gd` | line 100, `_quit_hold.configure(3.0)` → `5.0` |
| Screen-shake label rename | `core/party_setup.gd` | `_build_access_tab()`, ~line 756 (`shake.text`); pref key `"screen_shake"` stays unchanged everywhere it's read (see below) |
| Video: resolution + FPS cap | `core/party_setup.gd` | `_build_video_tab()`, ~line 709, alongside the existing display-mode/vsync controls |
| Settings/lobby panel overlap fix | `core/party_setup.gd` (`toggle()`, line 193) + `estate/estate.gd` (`phase_panel`) | coordinate hide/restore, or resize `panel`'s anchoring |
| Gamepad pause input | `core/party_setup.gd` | new poll alongside `_process()` (line 210), mirroring `estate.gd:_poll_pad_join()`'s edge-detect idiom |
| Text-scale base-size audit | (measurement task, not a file change) | `_build_lobby_panel()` and ACCESS-tab labels are representative samples |
| `screen_shake` pref readers (label rename must not touch these) | `minigames/widows_gaze/wg_pawn.gd:448`, `minigames/widows_gaze/widows_gaze.gd:1225`, `minigames/dead_weight/dead_weight.gd:1249`, `minigames/dead_weight/fighter.gd:357`, `minigames/tilt/tilt.gd:1336`, `minigames/greed/greed.gd:1490`, `minigames/greed/greed_player.gd:591`, `minigames/last_will/last_will.gd:1542`, `minigames/last_will/lw_ghost.gd:236`, `minigames/last_will/lw_pawn.gd:384`, `minigames/throne/throne.gd:1398`, `minigames/orbital/orbital.gd:1098`, `core/final_stretch.gd:131` | all read `PartySetup.pref("screen_shake", true)` by string key — do not rename the key |
| Colorblind palette constants (reference only, no change needed) | `scripts/game_state.gd` | `PALETTES` (line 12), `apply_palette()` (line 96) |
| Identity shape constants (reference only, no change needed) | `core/player_badge.gd` | `Shape` enum (line 19), `DEFAULT_COLORS` (line 23) |

---

## 5. Risk notes — what could break online determinism or receipts

**The existing pattern already has a live version of this exact risk, and
it's worth naming precisely so the front-end lane doesn't add a second
instance.** Several minigames' hitstop implementations write directly to
`Engine.time_scale`, gated by the `screen_shake` pref (e.g.
`minigames/last_will/last_will.gd:1530–1532`: "ONE throttled micro-hitstop
(0.15 time_scale, 45ms)," skipped entirely when the pref is off).
`Engine.time_scale` is a **process-global engine property**, not a
per-viewport or per-client render knob — confirmed by this codebase's own
verify notes (`minigames/orbital/VERIFY.md:75`, `minigames/throne/VERIFY.md:118`:
"`time_scale` SCALES THE PHYSICS DELTA," discovered the hard way when an
earlier probe used it as a naive fast-forward and got a "different game" as
a result). In ILL WILL's host-authoritative online architecture (doc 10:
host runs `_net_state()`, guests only ever `_net_apply()` mirrored facts),
this means **the host's own local `screen_shake` preference measurably
changes the pace of the shared simulation for every guest at the table**,
not just the host's own screen — a guest cannot opt out of it, and the
setting is not actually presentation-only despite being framed as an
accessibility toggle. This is pre-existing, out of scope to fix in this
doc, and at least one game (`echo_chamber`) has already worked around the
adjacent problem for its own hit-pause by using a real-time
(`time_scale`-independent) timer instead (`minigames/echo_chamber/VERIFY.md:254`).
It's flagged here as a **hard constraint on this lane**: none of §3's new
settings may repeat this mistake.

**Concrete constraint for every item in §3.3:** a new preference is safe
exactly when it only ever touches one of —
- `AudioServer` bus volume/mute (bus sliders, Ambience slider) — confirmed
  local-render-only, no gameplay-state coupling.
- `DisplayServer` window mode/size/vsync, `Engine.max_fps` — confirmed
  presentation-only; `max_fps` caps the render loop, not
  `physics_ticks_per_second`, so it does not touch simulation timing the way
  `time_scale` does.
- A `Camera3D`/`CanvasItem` property (FOV, modulate, shader parameters,
  `content_scale_factor`) — confirmed local-render-only.
- A label string (the screen-shake rename) — zero runtime effect.

A new preference is **unsafe** the moment it reaches for `Engine.time_scale`,
`Engine.physics_ticks_per_second`, `Engine.max_physics_steps_per_frame`, or
anything else that is a process-global simulation-rate knob rather than a
per-client render knob. None of the changes in §3 do this; call this out
explicitly if a future pass is tempted to gate a *new* effect (e.g. a
future haptics system, or a "reduce hitstop further" option) through
`time_scale` the way the existing screen-shake pref already does.

**Attract mode specifically:**
- Forcing all 4 seats to bots for the exhibition match, then restoring the
  backed-up `party_setup.json`, is exactly the pattern `--albumtest` and
  `--readylobbytest` already use safely — no new risk there, it's a proven
  idiom in this file.
- The exhibition module must launch with `exhibition = true` (not just
  `_all_bots()`) so it takes the same no-GET-READY-gate path `--exhibtest=`
  already exercises and already has verify coverage for — don't invent a
  parallel launch path.
- If attract mode is ever made **remotely spectatable** (a guest watching a
  host's idle attract sequence over the network) in some later pass, treat
  it as an entirely new mirrored-state surface subject to the same
  `_net_state()`/`_net_apply()` house pattern doc 10 already establishes —
  out of scope for tonight, flagged so nobody assumes it's "just visual."
- The SubViewport/shader-wash option in §3.2 step 4 changes **only** where
  the module's frame gets drawn (an extra render target + a `CanvasItem`
  material), never what the module simulates — it carries zero determinism
  risk regardless of which of the two implementation options is chosen.

---

## Sources

- Doc 14 (`docs/design/14-aaa-ux-standard.md`) — controller assignment,
  pause-menu contents, hold-to-confirm timing, colorblind/text-scale/
  haptics floors, focus/navigation conventions; all citations therein
  (XAG101/110/112/113/118, HOLDCONFIRM-1, COLORBLIND-1, GAG-1/2,
  STEAMDECK-1, XBOXTCR-1, SMASH-* , OC-1/TF-1/PA-1/JBX-1) apply here by
  reference and are not re-derived in this doc.
- Doc 04 (`docs/design/04-menu-ux-research-digest.md`) — original
  MUST/SHOULD/LATER settings checklist (line 47, 56–60); source of the
  "colorblind + text scale" MUST items this doc confirms are now shipped,
  and the "rumble toggle" SHOULD item this doc confirms is still open.
- Doc 10 (`docs/design/10-online-first-architecture.md`) — host-authoritative
  `_net_state()`/`_net_apply()` pattern referenced in §5's risk notes.
- [ATTRACT-1] Attract Mode, general convention and history — TVTropes:
  https://tvtropes.org/pmwiki/pmwiki.php/Main/AttractMode
- [ATTRACT-2] Attract Mode concept overview — Giant Bomb:
  https://giantbomb.com/wiki/Concepts/Attract_Mode
- [UFO50-2] UFO 50's title-idle demo cycling through its 50 games —
  Ani-Gamers mini-review roundup: https://anigamers.com/posts/ufo-50-mini-reviews-every-game/
  ; xeneth.design day-1 writeup: https://www.xeneth.design/2024/09/fifty-days-of-ufo-50-day-1.html
- [ATTRACT-3] Indie-dev convention-booth attract-mode account (AI-played
  demo level, PRESS START interrupt indicator) — ResetEra:
  https://www.resetera.com/threads/indie-devs-are-neglecting-to-do-this-at-conventions-you-wont-beli-ugh-theyre-neglecting-attract-mode-okay.146845/
- [HADES-CELESTE-1] Celeste Assist Mode + Hades God Mode as praised,
  non-diagnostic accessibility patterns; Celeste's menu-copy walk-back —
  Indie Game Culture round-up: https://indiegameculture.com/listicles/indies-with-great-accessibility-features/
  ; GameAccess/SpecialEffect Celeste motor options: https://gameaccess.info/celeste-motor-accessibility-options/
  ; Access-Ability Hades II preview: https://access-ability.uk/2024/05/03/hades-2-accessibility-preview/
- [PAUSE-COOP-1] Couch co-op pause-ownership design discussion (host-owns
  vs consensus vs per-player independent menus) — Steam Community
  discussion threads on *Travellers Rest* local co-op pausing:
  https://steamcommunity.com/app/1139980/discussions/0/595142432657563273/
  ; https://steamcommunity.com/app/1139980/discussions/0/4580716151543858276/
- Colorblind-palette validation cross-check (Wong/Okabe-Ito palette family,
  same lineage our `PALETTES` already uses) — David Nichols' colorblind
  tool: https://davidmathlogic.com/colorblind/ ; colorblind.io guide:
  https://colorblind.io/guides/colorblind-safe-palettes
- `docs/verify/parity-night4-VERIFY.md` — explicit statement that no
  rumble/vibration/haptic API exists in this codebase (cited in §1 row 19
  and §3.3 item 5).
- `minigames/orbital/VERIFY.md`, `minigames/throne/VERIFY.md`,
  `minigames/echo_chamber/VERIFY.md` — `Engine.time_scale`
  physics-delta-scaling discovery, cited in §5's risk notes.
