# R9 — Audio Infrastructure & SFX Coverage Audit
ILL WILL, Godot 4.6.2 — read-only research pass, night 5 state (commit 6228003)

Scope per brief: bus layout, playback plumbing, per-minigame SFX coverage,
ducking, UI sound consistency, volume settings, positional audio, and the
bell_toll layering pattern as the quality bar. Music COMPOSITION is out of
scope (per hard constraint) — only infrastructure/plumbing is assessed.

---

## 1. Bus layout

No `default_bus_layout.tres` exists anywhere in the project (checked repo
root, `assets/`, `.godot/`). Buses are created **at runtime, redundantly, by
three different autoloads**, each with its own copy-pasted `_ensure_bus()`
helper:

- `scripts/sfx.gd` (`Sfx` autoload) → creates `"Music"` and `"SFX"`, routed
  straight to Master.
- `core/ambience.gd` (`Ambience` autoload) → creates `"Ambience"`, routed
  straight to Master.
- `core/music.gd` (`Music` autoload) has **no** `_ensure_bus` of its own — it
  relies on `Sfx` having already created the `"Music"` bus. This works only
  because of autoload *order* in `project.godot` (`Sfx` before `Music`), which
  is not documented or asserted anywhere. Fragile but currently correct.

Four buses total: **Master → {Music, SFX, Ambience}**. No sends, no effects
(no reverb, no EQ, no limiter/compressor on Master) on any bus — this is a
flat, dry mix by design ("plumbing only," consistent with doc 21's scope
note). No bus is dedicated to voice/announcer (see §4 — there is no announcer
audio to route).

## 2. Playback plumbing

- **`Sfx` autoload** (`scripts/sfx.gd`) is the one-shot workhorse: a 40-key
  `BANK` dict of round-robin sample lists, a 10-voice `AudioStreamPlayer`
  pool (2D, non-positional, all on the `SFX` bus), `play()` (pitch-wobbled)
  and `play_pitched()` (exact pitch, for ladders). Voice-stealing prefers an
  idle player before hard-cutting a busy one. Samples prefer a declicked
  `.wav` over a legacy `.ogg` (`_load_sample`). Per-key volume trims live in
  a small `VOL` dict. This is clean, well-commented, and easy to extend.
- **`Music` autoload** (`core/music.gd`) is a 2-player A/B crossfader over 6
  named slots (`lobby`, `grounds`, `auction`, `ceremony`, `game_light`,
  `game_tense`), 1.4s fade. All 6 `.ogg` files exist in `assets/music/` and
  are wired from `estate/estate.gd`, `estate/procession/procession.gd`,
  `estate/howto_cards.gd`, `estate/net_lobby.gd`, and `core/final_stretch.gd`.
  Music is **not silent** — contrary to the older doc 09 gap note ("no
  minigame calls Music"), the `FinalStretch` kit (added since doc 09) now
  drives `game_light`/`game_tense` for every game that adopts it.
- **`Ambience` autoload** (`core/ambience.gd`) is a 2-player crossfade bed
  system (3 beds: wind, parlor room tone, crickets), well built, but **still
  completely unadopted** — grep for `Ambience.play_bed` outside
  `core/ambience.gd` itself finds only `tools/sfx_audition.gd` (the audition
  tool). No estate scene, no minigame, and no procession scene ever plays an
  ambience bed. Confirmed unchanged from the doc 21 "nothing calls it
  tonight" note — this has now shipped two more nights (24, board broadcast;
  PALLBEARERS) without adoption.
- **`Voice` (core/voice.gd)** is **text only** — a line-picker over
  `PackedStringArray` pools, no audio. There is no recorded/synthesized VO,
  no "announcer" or "narrator" audio anywhere in the codebase (confirmed by
  grep — zero hits for `announcer`/`narrator` in any `.gd` file). The
  Executor "speaks" exclusively via on-screen text banners.

## 3. Volume settings plumbing

Present and working. `core/party_setup.gd`'s AUDIO tab (`_build_audio_tab`,
`_volume_row`) drives 4 sliders — MASTER / MUSIC / SFX / AMBIENCE — each
persisted to prefs and applied via `_apply_volume()` → `AudioServer
.set_bus_volume_db` + `set_bus_mute` at `v <= 0.001`. The SFX slider plays a
live preview tick (`Sfx.play("card", -6.0)`) on drag, a nice touch; the other
three sliders have no live preview (Music/Ambience arguably don't need one,
but Master arguably should preview *something*, currently previews nothing).

## 4. Ducking

**None exists.** There is no bus-ducking code anywhere (`AudioServer
.set_bus_volume_db` calls exist only in the settings-slider path above; no
tween/lerp of a bus's volume tied to a game event). This is moot for
"announcer speaking" specifically, because there is no announcer *audio* to
duck under (§2) — but it also means nothing ducks Music under the loud
one-shot moments that DO exist (e.g. `match_win` + the deferred `bell_toll`
layered under it in `core/podium.gd:213-217`, or any future stinger). If VO
is ever added per doc 26's "voice bible," there is currently zero ducking
scaffolding to hang it on.

## 5. The bell_toll pattern (quality bar) — `core/podium.gd:212-217`

```gdscript
Sfx.play("match_win")
# A single distant toll layered UNDER the sting — the estate tolling for an
# heir. Additive (never replaces match_win); deferred a beat so it reads as a
# far bell after the flourish. Both host and mirror reach here, so both ring.
get_tree().create_timer(0.5).timeout.connect(func() -> void: Sfx.play("bell_toll", -9.0))
```

This is genuinely good sound design: a foreground sting (`match_win`,
immediate) plus a background layer (`bell_toll`, deferred 0.5s, -9dB, thematic)
that never replaces the first — layering, not swapping. It is *not* generally
replicated elsewhere. Only 2 non-tool files reference `bell_toll` at all. Most
other "big moment" resolutions in the anthology (see §7, deciding-moment fov
punches) fire a single flat cue with no second layer.

## 6. Per-minigame SFX coverage (raw call counts, `Sfx.play`/`play_pitched`)

| Game | Sfx.play call sites | Notes |
|---|---|---|
| dead_weight | 19 | — |
| echo_chamber | 28 | — |
| greed | 29 | + bespoke CLOSING BELL tick system (see §8) |
| last_will | 35 | heaviest coverage |
| masked_ball | 16 | — |
| mower | 10 | lightest coverage alongside understudy |
| orbital | 19 | visual danger-tier system NOT paired with audio (see §7) |
| pallbearers | 12 | newest game (night 5); uses `thud_coffin` |
| seance | 25 | — |
| swap_meet | 39 | heaviest coverage |
| throne | 20 | — |
| tilt | 30 | — |
| understudy | 10 | lightest coverage alongside mower |
| widows_gaze | 17 | — |

**No game is silent.** Every one of the 14 shipped minigames has non-trivial
SFX call coverage — the "which games have impact/score/win sounds vs
silence" question in the brief resolves to "none are silent," which is a
healthy baseline. (The brief's "15 games" — the repo currently ships 14
minigame directories; PALLBEARERS was game 15 by title/commit numbering but
`masked_ball` appears to be an un-numbered 15th slot, or numbering is
non-contiguous — not resolved further, out of scope for an audio audit.)

Illegal-move / rejection feedback (`"invalid"` key) is inconsistently wired:
only 4 of 14 games (`greed`, `masked_ball`, `tilt`, `understudy`) ever call
it. The other 10 either have no illegal-move state, or reject silently —
not fully distinguished without a deeper per-game trace, flagged here as a
lower-confidence secondary gap.

## 7. UI sound consistency

Good news: the anthology is **not** inconsistent in the way the brief
worried about. Every menu/HUD surface checked (`core/party_setup.gd`,
`core/attract_mode.gd`, `core/cooldown_ring.gd`, `core/ui_kit/intro_card.gd`,
`estate/estate.gd`) converges on the same two legacy keys — `"card"` (30
call sites) for navigate/click and `"confirm"` (22 call sites) for
accept/commit — so the *actual* shipped click sound is consistent anthology-
wide.

The bad news: Night 4's purpose-built UI family — `ui_move`, `ui_confirm`,
`ui_back`, `ui_error`, `ui_tab` (13 declicked variants, peak-normalized,
volume-trimmed in `VOL`) — is **completely unused**. Grep finds these five
keys referenced only inside `scripts/sfx.gd` itself (the bank definition)
and `tools/sfx_audition.gd`/`tools/sfx_smoke.gd` (the audition/smoke test
tools). Zero real call sites. An entire, already-finished asset family sits
on the shelf while every screen keeps using the older, less differentiated
`card`/`confirm`/`invalid` trio.

Same shelf-ware pattern for several gothic/impact keys: `bell_small`,
`thunder_far`, `organ_stab`, `projector`, `impact_heavy`, `impact_metal` all
show **zero** non-tool call sites; `impact_light`/`impact_wood`/
`whoosh_small`/`whoosh_big` show exactly **1** call site each (some single
game picked up one piece of the family). `gust` is the best-adopted new key
at 4 files. Net: roughly half of the ~26 new Night-4 key families are wired
into zero or one game, five nights after being built.

## 8. Countdown ticks — the sharpest concrete miss

`Sfx.BANK` ships a **purpose-built** `tick_countdown` family: 3 declicked
variants, explicitly designed to be pitch-ramped
(`Sfx.play_pitched("tick_countdown", pitch)`), called out in doc 21 as
unlocking "the missing countdown audio."

It is never used. Instead:

- `core/final_stretch.gd` (`FinalStretch` kit, adopted by **11 of 14**
  minigames plus `estate/procession/procession.gd`) implements its own
  `_play_tick()` that loads `res://assets/audio/click_001.wav` (the generic
  UI click) and pitch-ramps *that* — explicitly modeled on…
- `minigames/greed/greed.gd`'s pre-existing `_bell_tick()` (the CLOSING BELL
  system), which does the same thing: pulls `Sfx.BANK["card"][0]` and loads
  its raw `.ogg` directly, bypassing the `Sfx` autoload entirely.

So the anthology's single most-frequently-heard SFX moment — the last-10-
seconds tick ladder, heard in essentially every match of 11+ games — plays a
repurposed UI click on every single instance, while a tuned, purpose-made,
already-shipped `tick_countdown` sample family sits completely unused one
key away. This is not a missing asset; it's a wiring miss. `FinalStretch
._play_tick()` (lines ~146-166) is the one place to fix it, and the fix is a
straight swap to `Sfx.play_pitched("tick_countdown", pitch)` — the API
already supports it.

## 9. The "deciding moment" — silent camera language

`FinalStretch.fov_punch()` (a slow-mo/zoom-in on the decisive play, per doc
09 §Q2) is adopted by 5 games (`dead_weight`, `echo_chamber`, `throne`,
`tilt`, `widows_gaze`) at 10 call sites. It punches the camera in perfect
sync with each game's own freeze/slow-mo window — but plays **no SFX of its
own**. The `stinger_win`/`stinger_lose`/`stinger_reveal`/`stinger_dread`
family exists in the bank specifically for this ("the deciding-moment /
reveal / tie-ceremony cues doc 09 says every game currently resolves
*silently*" — doc 21 §3) and is, per §7 above, wired nowhere. The visual
language for the anthology's biggest per-round moment shipped; the audio
language for the same moment did not.

## 10. Positional (3D) audio in arenas

**Zero `AudioStreamPlayer3D` usage anywhere in the codebase.** All SFX,
including in fully 3D minigames (34 of 74 minigame scripts extend
`Node3D`/`CharacterBody3D`; the podium, procession, and most arenas are
Node3D scenes with real spatial layout), route through the flat 2D `Sfx`
pool. An impact on the far side of an arena sounds identical in
volume/pan/distance to one at the camera. This is a known, named gap — doc
09 §orbital explicitly specifies the fix (`orb_ball.gd:69,149` — "Per-ball
speed tiers: ≥4 low hum loop -18dB (**AudioStreamPlayer3D**)") and it was
never built: `minigames/orbital/orb_ball.gd` shipped the **visual** half of
this exact spec (a glow-intensity ladder by speed tier, lines 184-205,
confirmed present) but not the audio half. Orbital is the single game where
this matters most mechanically — its whole hook is balls you can't always
see coming from behind a planet or off-camera, and sound is the natural
channel for an off-screen threat warning that never got wired.

## 11. Asset shopping list (concrete, freesound-style — sourcing/synthesis
deferred, nothing downloaded)

These are gaps where infrastructure exists but no suitable sample was ever
sourced (per doc 21's own "Morning Calls," several are open owner decisions,
repeated here as fresh asks since 3+ nights have passed with no resolution
noted):

1. **True pipe-organ chord, single dark stab** — currently `organ_stab` is a
   placeholder dark gong (OGA `gong_02`) reused from `bell_toll`. Want: one
   low, dissonant, cathedral-organ chord, ~1s, tail ring, no attack transient
   softness (should feel ominous/liturgical, not percussive).
2. **True church/funeral bell** (single strike, sustained decaying ring,
   metallic, NOT a gong) — currently `bell_toll` is a gong (OGA `gong_01/02`
   + `bell_03`). Want: a genuine cast-bronze funeral bell strike, long tail,
   to sit under `match_win` per the podium pattern without reading as
   "boxing-ring gong."
3. **Low crowd murmur/gasp bed** — explicitly skipped in doc 21 ("no CC0
   crowd gasp/murmur good enough surfaced"). Want: 3-6s loopable low murmur
   for the podium/ceremony crowd, plus one non-looping "collective gasp"
   one-shot for a reveal beat.
4. **Off-screen threat hum/whistle, 3 tiers** (feeds orbital's missing
   AudioStreamPlayer3D wiring, §10) — low sine/filtered-noise hum for
   mid-speed danger, rising to a thin whistle/hiss layer for max-speed balls.
   Should read as "something dangerous is near, direction/distance audible"
   even off-camera.
5. **True film-projector rattle** — currently `projector` is OGA "machine"
   mechanical clatter (electric-motor flavored). Want: an actual sprocket-
   driven 16mm/35mm projector clatter loop, more wooden/mechanical-ratchet,
   less electric-hum.
6. **Heavy coffin thud, wood-on-stone** — `thud_coffin` exists (Kenney
   wood_heavy + OGA slam) and is in use by pallbearers, but per doc 21's own
   sourcing note it's a generic heavy-wood/slam composite, not specifically
   "coffin set down on a stone crypt floor." Given pallbearers is the newest,
   highest-profile game (game 15) and a coffin-carrying game, a dedicated
   heavy-wood-box-on-stone thud (lower-pitched than the current sample,
   audible stone-slap resonance on the tail) would sell the game's central
   verb better than the current generic composite.
7. **Field-recorded ambience beds** — `amb_wind_grounds` and
   `amb_room_parlor` are synthesized filtered noise (doc 21 Morning Call
   #5); only `amb_night_crickets` is a real recording. Since no game has
   adopted any ambience bed yet regardless (§2), this is lower priority
   until adoption happens — but worth batching if/when someone wires
   `Ambience.play_bed` into the estate grounds or a parlor scene.

---

## Summary of what's healthy vs. what's not

**Healthy:** the `Sfx` autoload architecture (pooling, round-robin, declick
discipline, `play_pitched`), the volume-settings plumbing end to end, no
silent minigames, consistent legacy click sounds anthology-wide, the
`bell_toll` layering pattern as a genuine quality bar, and Music's
slot/crossfade system now actually being driven by `FinalStretch` in 11+
games (contradicting an older doc 09 note that music was fully unwired).

**Not healthy:** a large fraction of Night-4's purpose-built SFX (`tick_
countdown`, the whole `ui_*` family, `stinger_*`, several gothic/impact
tiers) shipped and then was never wired into a single real call site,
including one direct, ironic miss — the shared `FinalStretch` tick system
(11-game reach) reinventing a worse version of the exact asset that was
built to replace it. No ducking infrastructure exists. No positional audio
exists anywhere despite an entirely 3D game with a named, specific,
still-open design ask for it (orbital). Ambience beds remain fully
unadopted three-plus nights after shipping.
