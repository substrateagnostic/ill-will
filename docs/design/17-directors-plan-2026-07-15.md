# 17 — The Fourth Watch: Director's Plan (2026-07-15)

Director: Claude Fable 5, night of the usage reset. Mandate from Alex, verbatim
essentials: *abandon anything locked; production/AAA ready; every player has
their own controller; Meshy for everything without an asset; standardize
menus/scoreboards to AAA; research playability first; create new games; find
improvements I'd never guess; the big add is a Mario Party-like board loop;
aim way higher than you think is possible.*

This is a month-scale plan set as tonight's goal. Waves are ordered so each
one lands value even if the night ends early.

---

## The thesis

ILL WILL has thirteen good minigames and a soul (the estate remembers). What it
does not yet have is the **connective tissue of a AAA party game**: one input
contract, one UI language, one session structure a family recognizes in ten
seconds ("it's like Mario Party, but the house hates you"). Tonight builds the
tissue. The minigames are organs; the board is the skeleton; the UI kit is the
skin; the input system is the nervous system; Meshy gives it a face.

**AAA here means:** every screen navigable by any pad with visible glyphs; no
placeholder primitive where a prop should be; every result staged, never
printed; every wait state killed or made content; the meta-loop legible enough
that a guest understands stakes by night two.

---

## The waves

### WAVE 0 — Research (in flight now, 5 agents)
Codebase systems map · Mario Party loop deconstruction (Opus) · AAA party UX
standard · Meshy API pipeline · jump + occluded-visibility design. All land as
docs/design/13–16.

### WAVE 1 — Foundations (tonight, parallel lanes)
1. **INPUT 2.0 — one pad per player.** Device-claim join screen (press A to
   claim a seat, pick color, ready up), per-seat device routing everywhere,
   pad-disconnect pause + reclaim overlay, per-device real glyphs in every hint
   bar, keyboard remains a legitimate seat, hot-join in the estate. Codex lane
   (thorniest plumbing in the project).
2. **UI KIT — one language.** Shared components: menu framework (title,
   pause, settings with colorblind palettes + text scale + shake/rumble
   toggles), minigame intro card (name, one-line pitch, controls, tip),
   standardized scoreboard/podium with count-ups + row reordering + placement
   stingers, transition wipes. Then an application sweep across all 13 games.
3. **MESHY FORGE — the asset pipeline.** Manifest-driven batch tool
   (tools/meshy_forge): text-to-3D preview → refine → GLB → res://assets/generated/
   → headless import → contact-sheet screenshots for my review. Key read from
   Dead_Attestation/.env at runtime, never committed. Batch 1: graves, medals,
   monuments, trophies, Executor props, board pieces. Style bible keeps
   everything sitting beside KayKit characters.

### WAVE 2 — THE BOARD (the big add)
The estate grounds become a literal 3D board. Design decision after the Opus
brief lands, but the director's prior: **spaces threaded through the existing
free-roam grounds; diegetic movement (your avatar walks); simultaneous rolls
to kill downtime; the Executor hosts; auction absorbed as the item shop; the
will-reading absorbed as the bonus-star ceremony; the trail becomes board
progress; graves and monuments become landable spaces that remember who died
there.** Session target: a full board night in 20–40 minutes, configurable.
This is the skeleton the whole product hangs on — Codex + Opus lane, me on
design.

### WAVE 3 — Game-feel sweep (playtester bugs + jump)
- **Jump/hop in most modes** per the per-game table from research (full jump /
  expressive hop / none — golf and seated games exempt). Movement tuning to
  Alex's frame-data standards: coyote time, input buffer, jump-cut.
- **Orbital far-side visibility**: through-planet silhouette (per-player color,
  depth-test-disabled pass) + rim peek indicators; bots and humans finally see
  the same game.
- **Couch-in-online parity sweep**: every eyes-closed/room-trust mechanic
  (séance sleep-wake, understudy roll-call, masked-ball self-ID) gets an online
  equivalent or an online-specific variant.

### WAVE 4 — New games (director's picks)
At least one new minigame born board-native (short, sharp, 60–90s). Candidates
after research lands; the bar: it must produce a story someone retells the
next day.

### WAVE 5 — AAA graphics pass
Per-game lighting + post (tonemap, glow, AO where it reads), skyboxes,
particle upgrades, Meshy props replacing every primitive placeholder, estate
grounds visual overhaul worthy of being the board.

### WAVE 6 — The surprises (the ones Alex wouldn't guess)
1. **THE NEWSREEL** — end-of-night silent-film highlight reel: the estate
   replays the night's deciding moments (kills, photo finishes, betrayals) as
   grainy title-carded vignettes during the will-reading. Echo Chamber's
   ghost-recording tech generalized into a killcam memory. Memory made
   visible — the thesis of the whole project, playable.
2. **THE GRUDGE LEDGER** — persistent cross-night stats surfacing as Executor
   lines and will clauses ("MINT has died by their own echo THREE TIMES").
   Cheap, deep, thematic.
3. **THE FAMILY ALBUM** — framed photos on the manor walls: every night's
   podium and best monument, captured and hung automatically. The house
   becomes a museum of your parties.

### WAVE 7 — Verification night
Full soaks (estate_save.json backed up first), online paired-window shots,
package rebuild, morning menu #4 in alexmemory.md.

---

## Protocol (unchanged, binding on all agents)
Worktree lanes; I read every screenshot before merging; headless import after
new res:// files; class_name import pass + game-load smoke after merges; putt
physics stays frozen (jump exempts golf anyway); NEVER --fresh-estate on this
machine; back up %APPDATA%\Godot\app_userdata\ILL WILL\estate_save.json before
soaks; PS5.1 single-quoted here-string commits; push after merges.

## Model economy
Opus 4.8 = taste/design/review · Codex 5.6-sol xhigh = input core, board
engine, shaders, netcode · Sonnet 5 = application lanes, pipeline, sweeps,
verification · Director = decisions, merges, screenshots, the record.
