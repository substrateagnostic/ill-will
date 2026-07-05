# ALEX MEMORY — running log of things worth your review
*Claude maintains this. Newest entries at top of the log. The NEEDS YOU
section is always current. Skim top-down; nothing below the fold is urgent.*

---

## NEEDS YOU (current)

- **🏆 THE ROSTER IS COMPLETE: TEN GAMES.** Last Will just merged — the
  will-drafting freeze is the best screen in the anthology ("THE LAST WILL
  OF GOLD / six seconds of posthumous power / now... curse whom?" with a
  live memorial portrait). 3.00 wills/round across all seeds; the dead own
  the pause while ghosts sway on pews. Your "aim for 10+" is fulfilled:
  par, echo, tilt, orbital, mower, greed, swap, dead weight, throne,
  last will — all in the auction pool, all reviewed.
- **🎯 BOT-MIX IS MERGED — GO PLAY.** All eight minigames now honor
  per-seat HUMAN/BOT from the ESC menu (roster-driven, determinism
  receipts unchanged). Par included: bots draft/place/putt on their turns
  and the game waits for yours. Verified on master: full Par match with
  3 bots ran to MATCH_OVER. Your saved setup (RED=human, rest bots) is
  exactly the solo-test loop you asked for. Mouse-AIM retrofit (swing/
  throw/tackle/furniture-fling toward cursor for the KB+MOUSE device) is
  now in flight for echo/orbital/greed/dead_weight.
- **IMPORTANT: fully CLOSE and RELAUNCH the game.** The auction fix is
  proven working on master via an end-to-end test that drives the real
  button signals (bid → CHOOSING → click card → launch: PASS). A running
  Godot instance keeps pre-fix scripts — your "still broken" was almost
  certainly the stale build.
- **Fixed this pass**: estate leakage (Trail stones/sun/environment were
  visible behind Tilt etc. — now fully hidden during minigames); bid
  buttons relabeled "NAME: RAISE TO n♠" and disabled for bots.
- **NEW DEVICE in ESC menu: "KB (WASD) + MOUSE"** (LMB=A, RMB=B). Mouse
  AIM (swing/throw/tackle toward cursor) comes per-game right after the
  bot-mix retrofit merges — the two would collide in the same files.

- **YOUR TWO PLAYTEST ISSUES: FIXED (pull/relaunch).** (1) Auction bug
  root-caused: the resolve step re-fired every frame (no phase change),
  re-draining grudge and rebuilding the chooser buttons before clicks
  registered — now single-fire with a proper CHOOSING phase. (2) **ESC now
  opens the PLAYERS & CONTROLS menu anywhere**: set each player
  HUMAN/BOT + device (mouse / WASD / arrows / gamepads 1-4); persists
  between sessions; estate honors it live (bot rows dim, bots auto-act,
  reckoning waits for humans). Minigames honor the bot flags after the
  retrofit agent lands (in flight — Par gets a full bot too, so you can
  solo-test everything vs 3 bots).
- **In flight now**: per-player-bot retrofit (all 8 games), THE THRONE
  (Opus), LAST WILL (Fable), and a **Meshy asset agent** generating 10
  custom props from builder wishlists (wardrobe, lamp, mower, kart,
  seagull, gilded pot, throne, lanterns, gate, podium) — I review before
  any integration.

- **THE FLEET IS HOME: EIGHT GAMES LIVE.** Par for the Curse (3 courses +
  chaos round), Echo Chamber (parry triangle + ghost shatter), Tilt (shove
  clash), Orbital Dodgeball, Mower Mayhem, Greed Inc., Swap Meet, and Dead
  Weight — all reviewed, merged, and in the Estate auction pool. Start an
  ESTATE NIGHT and the podium picks from all eight. Throne + Last Will
  specs are staged for the next wave (→ roster of 10).
- **MORNING REVIEW MENU**: (1) The PILGRIMAGE TRAIL is built and live —
  start an Estate Night and watch the Reckoning parade march the pawns up
  the hill; claim a tollgate by passing it. Screenshot:
  `verify_out/trail/shot_5800.png`. (2) Your read wanted on THE SABOTEUR
  sketch (social-deduction spice layer) in the trail design doc. (3) Echo
  v1.1 + Tilt v1.1 merged — feel-check the parry and the clash when you
  play. (4) Three more minigames building overnight: Greed Inc, Swap Meet,
  Mower Mayhem; Throne + Last Will specs ready for the next wave.

- **PLAYTESTABLE: ECHO CHAMBER, TILT, and ORBITAL DODGEBALL are merged and
  live in the Estate's auction pool.** Orbital's signature moment works:
  a 45-second-old orbit killed someone and credited the original thrower. Start an Estate Night from the menu and you can win the
  auction into either. (Echo needs real-time input — gamepads shine;
  keyboard halves work for 2. Tilt same. Par stays mouse-hotseat.)
- Reviewed and approved by me before merge: Echo's determinism proof
  (ghosts replay exactly, error 0.000000), Tilt's stability self-tests
  (idle + edge-slide both PASS). Screenshots reviewed as art director.
- Still building: Orbital Dodgeball (Fable), Dead Weight (Opus), Par v2
  (Opus — your 3+chaos/2x-hazards/3-courses changes).

## HOW TO RUN THINGS

```
godot --path C:\Users\agall\projects\un_party_game          # main menu
# Par quick test:   TEE OFF
# Estate night:     ESTATE NIGHT (beta)
# Fast mock night:  godot --path . -- --estate --estatebots --mockonly --night=3
# Fresh estate:     add --fresh-estate (wipes monuments/graffiti save)
```

## STANDING DECISIONS (agreed, in force)

- **Input policy (Alex, 2026-07-04)**: assume one full control surface per
  player (M+KB or gamepad) — no shared-surface contortions needed for
  simultaneous games; Par keeps mouse-hotseat because it's turn-based.
  Two-button verb budget stays fine. **Web co-op wiring is on the roadmap**
  (later phase — Godot high-level multiplayer, likely WebRTC for browser).
- **Animation readability > new mechanics**: Tilt's knockback and Echo's
  attacks existed but didn't READ in tests — v1.1 builders are adding real
  KayKit attack/parry/clash animations + windups precisely for this.

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

### 2026-07-05 — MESHY PROPS LIVE IN-GAME (wave closed)
The tufted golden throne sits on the dais, the gilded cauldron anchors the
vault, mowers/karts carry their riders with tinted identity rings, and the
seagull has a player-color collar. All visual-only; every legacy check
re-run and passing (throne re-verified across 5 seeds). New reusable
helper `scripts/meshy_prop.gd` normalizes any future Meshy GLB. Proofs in
`docs/verify/shots/prop_*.png`. Estate set (gate/lanterns/podium/pot) was
already in. ALL AGENTS HOME — the field is quiet until your notes.

### 2026-07-05 — MOUSE AIM MERGED (KB+MOUSE cursor combat live)
Echo swings, Orbital throws (preview follows), Greed tackle-pounces, and
Dead Weight shoves + poltergeist furniture-flings all go toward YOUR
CURSOR on the KB+MOUSE device. Movement stays WASD; bots untouched (all
four legacy determinism/balance harnesses re-verified byte-identical).
Echo ghosts now record your true aim, so your past selves swing where
you really swung. Dual-ray screenshot proofs in the aim worktree;
VERIFY-AIM.md committed.

### 2026-07-05 — THE THRONE MERGED (game #9)
Musical-chairs tyranny works: golden score-stream from the seated king,
grip pips + TYRANNY fatigue bar, dethrone fling with physics crown
("MINT DETHRONES BLUE"). Balance: worst bot share 31% vs 55% cap, all
seeds; two real bugs caught by screenshot review (seat jam, kings flung
over the walls into the void). Watch in human play: reign length (its
Meshy throne model is queued for the props integration pass too).

### 2026-07-05 — MESHY CUSTOM PROPS MERGED (10/10 keepers)
Your Meshy API paid for itself in one run: wardrobe, table lamp, riding
mower, go-kart, seagull, gilded coin-pot, tufted throne, stone lantern,
manor gate, auction podium — all chunky-lowpoly on-style, zero retries.
Probe lineup: `docs/verify/shots/meshy_probe_overview.png`; per-asset
prompts/AABBs in `docs/verify/meshy-assets-VERIFY.md`. Reusable probe tool
at `tools/asset_probe.tscn` (drop any GLB in assets/models/meshy/ and
re-run). Not yet wired into scenes — that's my integration pass, queued
behind your playtest. Key never touched the repo (verified).

### 2026-07-05 (night shift, later) — Swap Meet MERGED (game #7)
The swap-racer works: whole tabletop circuit readable in one frame,
windmill landmarks + shortcut ramp, leader wears a crown (bullseye), and
the golden orb is BOTH leader-locked and trailing-spawned so the comeback
verb lands where needed. Kart feel deliberately bumper-car pace (builder
documented the tuning knobs at the top of swap_kart.gd if we want zip:
TOP_SPEED 5.0->5.6 first). "SWAPPED! RED <-> MINT" banner in identity
colors. Dead Weight builder resumed with a final-report order.

### 2026-07-05 (night shift, later) — Greed Inc. MERGED (game #6)
The heist vault works: pot fattens center-stage, carrier glows gold and
leaks coins while edge-chevrons hunt them, corner chutes bank. Anti-turtle
interception verified 68-80% across seeds (builder built a real pursuit
model from movement constants; first pass failed at 5% and forced a design
fix). Money shot: greed worktree `verify_out/greed_grab.png`.

### 2026-07-05 (night shift, later) — Mower Mayhem MERGED (game #5)
Splatoon-on-the-lawn works: four grass-plausible turf tints (builder fixed
a washout by switching to a modulate shader), flowerbed islands, gravestone
bumpers, riders on mowers, overtime drama ("GOLD RAMMED BLUE!" at 0:10).
Coverage math asserts exactly 100.0000%; texture path sub-millisecond.
In the auction pool. Minor polish note: mini coverage meter label overlaps.
Also: Trail summit tie-break made principled (same-parade arrivals resolve
by points), monuments relocated off the hillside.

### 2026-07-05 (night shift) — your bedtime asks, executed
- **5 new minigame specs written** (target roster 10):
  GREED INC. (pot grab-and-run banking), SWAP MEET (kart race where every
  hit swaps positions — 1st place is a bullseye), MOWER MAYHEM (Splatoon-
  style lawn coverage in our mow-stripe language), THE THRONE (musical-
  chairs tyranny), LAST WILL (the dead draft blessings/curses — kingmaking
  as theater). All in docs/specs/. Builders launched for Greed/Swap/Mower;
  Throne + Last Will queued for the next wave (balance-sensitive).
- **Estate progression designed: THE PILGRIMAGE TRAIL** — the leaderboard
  becomes literal terrain: stepping-stones spiral up the hill to the Manor;
  pawns advance by POINTS EARNED (no dice, ever — the Pro-Rules lesson);
  Reckoning becomes a watchable parade (your bio-break moment); TOLLGATE
  stations let leaders tax passers (grudge engine); night champion's statue
  erected at the Manor gates forever. Building it now. Your Among Us
  instinct is sketched as THE SABOTEUR (opt-in, one bluff one vote, no
  elimination) in the same design doc — wants your read before building:
  docs/superpowers/specs/2026-07-05-pilgrimage-trail-design.md
- **Echo v1.1 MERGED**: real attack anims (chop/2H-slice/blocking), charged
  heavy with red-tint windup, parry->riposte triangle, ghosts now shatter
  into tinted shards at their recorded death (your declutter note). Builder
  also caught a real bug: ghost heavies were resolving as lights.
- **Tilt v1.1 MERGED**: shove-clash counter with 0.12s windup — honest
  balance work (measured the whiff regression, compensated with reach +
  aim tracking). Design note to watch in human play: face-to-face duel
  kills now clash by design, so royalties shift toward blindsides.

### 2026-07-04 — PAR v2 MERGED (your playtest changes are live) + more fleet
- **Par v2** (Opus build, reviewed): 3 rounds + CHAOS round (golden hour,
  1.6x traps, double points, no waiting), 2 trap placements per player per
  round, and THREE COURSES — fairway / dogleg (L-shape, bank-shot corner) /
  green (open plaza), seeded-random per match, `--course=` to force one.
  Dogleg verified dense and gorgeous: `verify_out/dogleg/shot_5000.png`.
- **Orbital Dodgeball merged** — the 45-second ghost-orbit kill works;
  comet-sky endgame is beautiful. In the auction pool.
- **AAA part 2 on Par**: tilt-shift DOF + trajectory aim dots (first bounce
  only, fading, power-colored): `verify_out/dots2/shot_1410.png`.
- Fixed post-merge: menu pointed at the moved course scene; scene-fade
  transitions exposed a null-scene frame in the verify harness.

### 2026-07-04 — First two fleet deliveries reviewed & MERGED
- **ECHO CHAMBER** (Opus build): past-rounds-as-ghosts arena brawl. Live
  players textured w/ rings; ghosts flat translucent tints — readable even
  at 12 ghosts. Determinism asserted 0.000000 every round. Best screenshot:
  `minigames worktree echo_r5_dense_preshrink.png` (now in repo history).
- **TILT** (Fable build): spring-damper platter (0.4s lag, provable
  stability), concentric-ring tilt legibility, seagull mode for the fallen,
  "RED SHOVED BLUE OVERBOARD!" banners. Both registered in the Estate
  auction pool alongside Par. Integration polish noted: unify both arenas
  to the warm diorama style later.

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
