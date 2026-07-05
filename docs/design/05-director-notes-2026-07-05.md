# Director Notes — 2026-07-05 (post-compaction session)

Decisions from Alex's review, with sequencing. These are commitments, not
ideas — each has an owner and a place in the queue.

## Priority override (Alex): menus are first-class from day one

The digest (04-menu-ux-research-digest.md) MUST list is now the active
build, ahead of the cosmetics store. Increment plan:

1. **Settings overlay v2** (director, NOW): tabbed flat ESC panel —
   SEATS / CONTROLS / AUDIO / VIDEO / ACCESS. Custom keybinds live here.
2. **Never-color-alone badges** (agent, NOW): procedural shape+color
   PlayerBadge across the 9 contract games' HUDs. Par integrated after
   v3 lands; estate integrated by director.
3. **Ready Room + How-to-Play cards** (director, next): press-A-to-join
   seats, per-game rule cards that render LIVE bindings, practice doors.
4. **Cosmetics store at the stall** (director, after menus).

## Keybinds decision (Alex asked; direction agreed)

- Remaps are **device-keyed, not player-keyed** (-1 / -2 / -4 keyboard
  maps): a keyboard half means the same keys regardless of who sits there.
- Verb surface is tiny (up/down/left/right/a/b) so full rebinding is
  cheap — no reason to ship less than total remap for keyboards.
- KB+MOUSE (-4): movement remappable, **a/b stay LMB/RMB** (that IS the
  device). Gamepads get an A/B swap toggle per pad.
- **Onboarding reflects reality by construction**: How-to-Play cards call
  `PlayerInput.describe_binding(p, action)` — they render whatever is
  currently bound, never hardcoded key names. This was Alex's instinct
  and it is correct; it also future-proofs the cards for controller
  glyphs later.

## THE EXECUTOR (host character — Alex's call, estate-lore-perfect)

A will needs an executor. The host is the estate's butler/solicitor who:
reads the Will at night's end, calls the auctions, greets returning
parties by their ledger history ("welcome back, THE SNAKE"). V1 is a
Meshy-generated butler model + text lines at ceremonies (we have plenty
of Meshy credits per Alex). Voice/TTS is a later experiment. The
Executor is the delivery mechanism for "the estate tells the story back."

## The Theater (social/party games venue — Alex's call)

A stage/theater structure on the grounds hosting SHORT social games
(bluff/vote/deduction — Jackbox energy, couch-controller-native, not
phone-based). Occasional, between auction rounds or as night openers.
Needs its own brainstorm+spec with Alex before building: which 2-3
social formats fit 4 seats + two buttons. Meshy builds the venue.

## Par v4: EMBODIED GOLF (Alex's sketch — approved direction, sequenced)

Par is the only game where the character models don't do the playing.
V4 makes them play: Super-Battle-Golf-scale courses, top-down hazard
placement (unchanged), **third-person shots** (your character walks to
the ball and swings), and **live griefing during the chaos round**
(non-shooting players walk the course and interfere in real time).
Ball physics stay frozen — the interface changes, not the sim.
Sequencing: land Par v3 → Alex playtests v3 → full v4 spec → subagent
wave. Too big to collide with v3 mid-flight.

## Online co-op (Alex, 2026-07-05: on the list, further down)

For TRUE testing purposes ahead of couch parties. Design-ahead notes
already in digest 04: invite codes, bot-takeover-on-drop rejoin, the
hub IS the lobby (remote players inhabit the estate as avatars — one
UI, two transports). Godot high-level multiplayer, likely WebRTC for
browser. Sequenced after the Theater wave and Par v4.

## Music (Alex owns, tomorrow)

Alex reviews/selects the soundtrack himself (Berklee viola performance;
this is his instrument, literally). Director's prep: Music audio bus
exists as of settings v2 so tracks drop straight in. ~6 slots: lobby/
grounds, auction, ceremony, 3 game moods.
