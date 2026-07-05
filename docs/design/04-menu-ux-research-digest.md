# Menu/Settings/Join UX Research Digest (2026-07-05)

Basis for the estate-as-main-menu redesign. Full report in session; durable
essentials here.

## Governing principle

The 3D space carries fun, identity, and "what do we play"; a flat ESC
overlay carries settings, quit, remap, dialogs — NO shipped hub game makes
those diegetic (Lethal Company, DRG, Astro, Content Warning all fall back
to flat). Beware the "minimal HUD paradox": design the flat overlay
first-class from day one. DRG's dual pattern is the accepted answer to
walk-vs-press: diegetic object AND a hotkey opening the same panel.

## What lives in the Estate (diegetic)

Minigame selection entry (board/pedestals + hotkey), Ready Room join seats
("press A/Space to join" chairs), mirror/wardrobe customization, presence +
trophies (we have this: monuments/graffiti/trail), practice doors per game,
optional Invite Kiosk later (PEAK pattern).

## What stays flat overlay (ESC anywhere)

All settings, quit, confirmations, disconnect/rejoin dialogs, the actual
10-game selector GRID (diegetic object opens it), online lobby management.

## Join flow recommendation (our 4 seats)

Press-confirm-to-join claims next seat by event.device (KB+mouse = one
first-class seat); per-seat card: device glyph, name, color, HUMAN/BOT/
EMPTY tri-state, ready check; disconnected controller → bot takeover +
lingering rejoin prompt; local profiles persist name/color per device;
Steamworks on-screen keyboard for names (Deck-safe). We already have the
PartySetup foundation — this evolves it into the Ready Room.

## Selector recommendation (10 games)

One-screen 5x2 grid, no paging (UFO 50 gold standard): art, name, player
count, length tag, favorite star, jiggle+audio on highlight; confirm=play,
secondary=How-to-Play details card with controls diagram + best scores;
PRACTICE launches from the details card (solo, no scoring, controls
overlay). Couch flow: host picks default, optional vote mode, "Surprise
Me" with one reroll. Target <10s hub→gameplay.

## Settings checklist (ranked)

MUST: remap (KB+M and pad separately); colorblind 3 modes AND
never-color-alone (CRITICAL for us — player identity IS color; add
shapes/icons/names backup); subtitles + size + bg; audio buses
(Master/Music/SFX/UI); screen-shake toggle, motion-blur off,
reduce-flashing (XAG 117); text/UI scale (min font 9px @1280x800, aim
12px — Steam Deck Verified); display mode (exclusive fullscreen +
borderless + windowed), resolution, VSync, FPS cap; glyphs match active
device + full controller nav + Steam on-screen keyboard; settings persist;
language.
SHOULD: FOV, render scale, presets, per-player sensitivity, hold-vs-
toggle, rumble toggle, brightness/gamma, mono audio, dyslexia font,
high-contrast UI, menu TTS start.
LATER: full TTS/STT, directional subtitles, VRR/Reflex, per-game assists,
custom colorblind picker.

## Online (future phase, design-ahead)

Friends-only + copy-paste invite CODE (crossplay-cheap, Epic-compliant);
skip public browser at launch. Rejoin is the differentiator: bot takeover
on drop + "rejoin?" at hub/minigame boundary (Mario Party Superstars);
avoid R.E.P.O./PEAK/StS2 anti-patterns. Key hook: the hub IS the lobby in
both couch and online — remote players inhabit the same Estate as avatars,
one UI two transports.

## Redesign implications for us (pre-design notes)

- Estate scene absorbs menu duties: boot straight into it (title card over
  the grounds), Ready Room seats replace the player-count buttons,
  minigame board opens the flat 10-grid selector, practice doors optional
  v2. Old menu.tscn retires or becomes the title card layer.
- PartySetup evolves into the per-seat card UI (already has tri-state
  bones: human/bot + device).
- Never-color-alone: add per-player ICONS (suit symbols? ♠♥♦♣ or
  animal sigils) across all games' HUDs — cross-cutting accessibility
  task, schedule as its own pass.
- Settings overlay: build the MUST list as a proper flat ESC menu
  (currently PartySetup only) — video/audio/access/remap tabs.
