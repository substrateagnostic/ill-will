# ALEX MEMORY — running log of things worth your review
*Claude maintains this. Newest entries at top of the log. The NEEDS YOU
section is always current. Skim top-down; nothing below the fold is urgent.*

---

## NEEDS YOU (current)

- **Nothing blocking.** Five builder agents are constructing minigames in
  isolated worktrees; I review their screenshots/reports before anything
  reaches you. Next thing I'll surface: playtest builds of whichever
  minigames pass my review first.
- Whenever you feel like it: **ESTATE NIGHT (beta)** is on the main menu —
  the full night loop works with real Par matches inside. Your monuments
  will persist between sessions (that's the point).

## HOW TO RUN THINGS

```
godot --path C:\Users\agall\projects\un_party_game          # main menu
# Par quick test:   TEE OFF
# Estate night:     ESTATE NIGHT (beta)
# Fast mock night:  godot --path . -- --estate --estatebots --mockonly --night=3
# Fresh estate:     add --fresh-estate (wipes monuments/graffiti save)
```

## STANDING DECISIONS (agreed, in force)

- **Anthology direction**: Par for the Curse = minigame #1 of a Mario-Party-
  style anthology. Meta layer = **THE ESTATE**: board/hub/menu/trophy-room
  are one persistent place players build & scar; simultaneous between-game
  phases; grudge auctions pick the next game; classic-clarity scoreboard;
  estate persists ACROSS game nights (save file). Spec:
  `docs/superpowers/specs/2026-07-04-the-estate-design.md`
- **Par v2** (from your playtest): putting frozen as-is (approved); 3 rounds
  + CHAOS round; double trap density; 3 course shapes (fairway/dogleg/green)
  random per match. Spec: `docs/specs/par-v2-minigame-cut.md`
- **Delegation model**: Claude directs + builds taste-critical parts (Estate);
  builder agents construct minigames from specs with mandatory screenshot
  self-review; only playtesting/final review surfaces to you.
- Research receipts live in `docs/design/02-research-notes.md` (genre) and
  `docs/design/03-board-research-digest.md` (board meta-layers; headline:
  our accreting-board idea is confirmed unshipped white space — closest
  ancestors: Ultimate Chicken Horse, Death Race 1976 gravestones, Legacy
  board games).

## LOG

### 2026-07-04 — Podium ceremony (core, reusable)
Night-end now presents a podium: champion Cheers on block 1, 2nd stands
politely, 3rd sulks cross-legged, 4th lies flat on the floor beside the
podium. Confetti rain, name tags, pastel blocks. `core/podium.gd` — built
reusable so minigames can adopt it at merge. Screenshot:
`verify_out/podium2/shot_2900.png`

### 2026-07-04 — AAA polish pass, part 1 (your standing directive)
- **3D animated main menu**: slow-orbiting course diorama behind the UI with
  a spinning windmill and gravestones as set dressing. Screenshot:
  `verify_out/menu2/shot_0120.png`
- **Kenney UI theme project-wide**: chunky green pill buttons with depth +
  proper panels — every button/panel in menu, Par, and Estate upgraded in
  one stroke (`assets/ui/theme.tres`).
- **Tilt-shift depth of field** on menu + estate cameras (toy diorama look).
- **Scene-fade transitions** between menu/game/estate.
- Part 2 (Par-side: DOF, trajectory dots, win podium) waits until the Par v2
  builder branch merges, to avoid conflicts.

### 2026-07-04 — Estate E2a: the grounds are ALIVE
Walkable KayKit characters on the estate (gamepad sticks move them directly;
shared mouse: click a character to select, click ground to send them).
Physics toy balls to shove, glowing lanterns, castle folly on the hill.
Screenshot: `verify_out/e2/shot_0600.png` — Mage at the stall, Rogue on the
path, auction running. Still to come in E2b: stall purchases, seeded walkway
traps, station-proximity interactions.

### 2026-07-04 — The Estate E1 built & verified (by Claude directly)
Night loop works end-to-end: Grounds betting → grudge auction → game module
→ Reckoning ticker → champion monument. **Cross-session persistence
verified**: Night 2 loaded Night 1's monuments onto the lawn. Placeholder-box
visuals; E2 (walkable grounds, stall, toys, art pass) is next.
Screenshots: `verify_out/shot_2400.png` (Reckoning), `verify_out/night2/shot_0600.png` (persistence).

### 2026-07-04 — Builder fleet launched (5 agents, isolated worktrees)
- TILT — Fable. ORBITAL DODGEBALL — Fable. ECHO CHAMBER — Opus.
  DEAD WEIGHT — Opus. PAR v2 upgrade — Opus.
- Each: spec + house-style contract, mandatory windowed screenshot
  self-verification (headless-render trap pre-empted per your warning),
  seeded bots, VERIFY.md deliverable. I review before you see anything.

### 2026-07-04 — Crusher bug fixed (your playtest find)
Root cause: Godot AnimatableBody3D with sync_to_physics ignores ancestor
moves once physics registers it — the hammer froze at the ghost's spawn
point while the pad followed your mouse. Fix: ghosts disable sync_to_physics,
placement re-enables. Also: gravestones can't spawn in the tee zone anymore.

### 2026-07-04 — Anthology framework shipped
`core/minigame.gd` (module contract: config in, results out incl.
currency_events — royalty/grudge economy is the anthology signature),
`core/player_input.gd` (per-player devices: gamepads > keyboard halves >
shared mouse). Par retrofitted to emit contract results.

### 2026-07-04 — Par for the Curse v1 complete (11 commits)
Playable 2–4P hotseat sabotage golf: draft/build/putt, killers, gravestones,
royalties, CURSED deck, KayKit caddies (author cheers when their trap
kills), flyover ending. Budget: $0, all CC0.
