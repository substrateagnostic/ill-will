# 24 — THE BOARD BROADCAST STANDARD

*Night-5 research lane R1. The question: what would THE PROCESSION need to feel
like Mario Party if it was made in 2026? The board is mechanically complete and
deterministic (docs 13, 18). What it lacks is PRESENTATION and dead-seat
engagement. Every finding below ends with a concrete PROCESSION change: what to
build, which file(s) it touches, and a T-shirt size (S/M/L). — Fable, 2026-07-16*

Read alongside: `13-board-mode-research.md` (the mechanics research — NOT
re-tread here; this doc is the presentation layer on top of it) and
`18-procession-build-spec.md` (the eight locked calls). This doc feeds build
lanes B1 (PROCESSION CINEMA), B2 (THE EXECUTOR EMBODIED), B3 (AMBIENT LIFE),
B6 (GHOST MEDDLING), B7 (GAME #15).

---

## 0. The governing constraint (read first)

Everything below is **PRESENTATION ONLY**. The headless soak receipt (seed 7 →
heir BLUE, 17 rounds) must stay byte-identical. Three hard rules inherited from
the existing code:

1. **Never draw from `rng` in a visual path.** Every juice effect must be a pure
   function of already-decided state, or use a *separate* non-sim RNG. The board
   already obeys this (grave headstone variety is `posmod(space_idx, N)`, not
   `randi()` — `board_path.gd:305`). A spinning wheel/roulette animates *toward*
   a slot the sim already chose; it never decides the slot.
2. **Gate all of it behind `not _fast` / `not _autoplay`.** The existing
   `_flyover()`, `_slide_in_lowerthird()`, and `_beat()` all collapse to one
   frame under the fast soak (`procession.gd:487`, `:1199`). New cinema follows
   the same pattern so the receipt never renders it.
3. **Every ceremony stays skippable by all-players-press-A** except the win
   reveal (`_all_press_skip`, spec §non-negotiables). New interstitials must
   route through `_beat()` so the skip still works.

### Reuse inventory (tech already shipped — do not rebuild)

| Need | Already exists | Path |
|---|---|---|
| Instant-replay stills / newsreel feed | `MomentScribe.capture(tag, caption, pri, players, game)` | `core/moment_scribe.gd` |
| 1920s film shader (sepia/grain/gate-flicker/vignette) | Newsreel + shader | `estate/newsreel.gd`, `assets/shaders/newsreel.gdshader` |
| Endgame music/light escalation | `FinalStretch` (`play_started`/`escalate`/`round_reset`/`tick`) | `core/final_stretch.gd` |
| Moonlit lighting rig | `EnvKit.MOONLIT` | `core/env_kit.gd` |
| Colour-blind-safe portraits + glyphs | `PlayerBadge.make/glyph` | `core/player_badge.gd` |
| Winner podium staging | `Podium` | `core/podium.gd` |
| A deterministic spinner/arrow | séance minigame arrow | `minigames/seance/seance_arrow.gd` |
| Ghost/poltergeist actors | already animated | `minigames/dead_weight/poltergeist.gd`, `minigames/last_will/lw_ghost.gd` |
| Floating-number popups | used in several games | `minigames/tilt`, `minigames/orbital`, `minigames/dead_weight` |
| Meshy prop loader | `MeshyProp.instance(path, height)` | `scripts/meshy_prop.gd` |

The board contributes NOTHING to any of these today. Wiring the board into tech
it already ships is the cheapest joy in this doc.

---

## 1. THE BROADCAST CAMERA

Current state: a single `Camera3D` (`procession.gd:229`) hand-tweened from three
places — `_flyover()` (opening tour), `executor.push_to()`/`reset_camera()`
(reveal push-in + return), and `executor._process()` (per-frame look-at aim).
Roll and move are a static overhead whole-board shot from `_cam_home (0,23,23)`.
Jamboree's lesson, inverted: reviewers panned its Switch-2 camera because *it
doesn't track* ([VGC](https://www.videogameschronicle.com/review/mario-party-jamboree-switch-2/),
[Pocket Tactics](https://www.pockettactics.com/super-mario-party-jamboree/tv-review)) —
a live camera that loses the subject reads as broken. Our camera is virtual and
always knows where the story is; that is the advantage to press.

**F1 — Extract a camera director.** Camera logic is scattered across three files
and there is no notion of a named shot. Build a `CameraDirector` that owns a
small vocabulary of shots — `ESTABLISH`, `WHOLE_BOARD`, `MOVE_TRAVEL`,
`LANDING_PUSH`, `TWO_SHOT`, `BEACON_HERO`, `STANDINGS` — each a
position+look-at pair it blends between with eased tweens plus a low-amplitude
handheld noise (breaks the "locked tripod" prototype read). This is the spine
B1 needs; every finding in this section becomes a shot registered on it.
→ BUILD new `estate/procession/board_camera.gd`; move `_flyover`/`push_to`/
`reset_camera` onto it. FILES: new `board_camera.gd`, `procession.gd`,
`executor_host.gd`. SIZE M.

**F2 — A travelling move shot, not a static overhead.** The MOVE phase
(`procession.gd:657`) currently holds the overhead while all four pawns hop.
Replace with a low, raking dolly that travels *along the drive* in the direction
of motion — the funeral procession reads as a procession, not a diagram. Because
all four move at once you cannot follow one; a wide low travelling shot keeps the
group and the destination stones both legible.
→ BUILD `MOVE_TRAVEL` shot driven during the existing move-tween await. FILES:
`board_camera.gd`, `procession.gd` `_round()`. SIZE S.

**F3 — Type-aware landing close-ups with a punch-in.** `reveal_anchor()`
(`board_path.gd:494`) returns one generic above-and-outside anchor for every
space. Make framing express the event: a WEEPING GRAVE gets a low angle looking
*up* at the headstone; the CODICIL gets a hero low angle so its gold glow flares
into lens; a VENDETTA gets a two-shot holding both pawns. Add a 0.15s overshoot
("punch-in" past the target, settle back) on arrival — the single most reliable
camera-juice trick ([GameAnalytics](https://www.gameanalytics.com/blog/squeezing-more-juice-out-of-your-game-design)).
→ BUILD per-type anchor table + overshoot ease. FILES: `board_camera.gd`,
`board_path.gd` (`reveal_anchor` → type-aware). SIZE M.

**F4 — A standings shot.** There is no camera beat that says "here is the pecking
order." Add a slow truck across the four pawns ordered by Deeds (or a pull-up-and-
back) fired at round end and before each minigame block, synced to the HUD chip
highlight. Pairs with F21.
→ BUILD `STANDINGS` shot. FILES: `board_camera.gd`, `procession.gd`. SIZE S.

**F5 — Wire the board into MomentScribe (instant replay / newsreel feed).** The
board calls only `VerifyCapture.snap()` (dev screenshots); it never calls
`MomentScribe.capture()`, so the night's newsreel and Family Album get *nothing*
from the flagship mode. Add capture calls at the deciding beats — the Deed that
crosses `deed_goal-1`, a decisive vendetta win, the heir crown — with
priority 3/2. Near-zero effort, and it plugs the board into the estate's memory
ceremony that already exists. This IS the "instant replay" of a 2026 broadcast.
→ BUILD `MomentScribe.capture(...)` calls beside existing `VerifyCapture.snap`
sites. FILES: `procession.gd` (`_resolve_codicil`, `_resolve_vendetta`,
`_heir_crowned`). SIZE S. **[Top joy-per-effort.]**

---

## 2. THE HOST EMBODIED

Current state: the Executor is a `Node` (not even a `Node3D`) that owns a
lower-third `RichTextLabel` and moves the camera (`executor_host.gd`). He is a
caption, not a person. The reference set: MC Ballyhoo is "extravagant and
energetic in both speech and manner … often flailing around with excitement"
([MarioWiki](https://www.mariowiki.com/MC_Ballyhoo_%26_Big_Top)); Jamboree TV
stages an actual **television studio** with a host Toad, a crew, and a critter
**audience** ([Nintendo Life](https://www.nintendolife.com/guides/super-mario-party-jamboree-nintendo-switch-2-edition-plus-jamboree-tv-all-new-minigames-and-modes)).
Available tech (per doc 23): a **static Meshy figure with puppet-style transform
animation, no rigging**. That is enough — the animation research is emphatic that
*alive* comes from breathing idles, secondary motion, and squash/anticipation,
not from skeletal rigs ([Game Anim 12 principles](https://www.gameanim.com/2019/05/15/the-12-principles-of-animation-in-video-games/),
[MoCap Online idle guide](https://mocaponline.com/blogs/mocap-news/idle-animation-game-dev-guide)).

**F6 — Give him a body and a place to stand.** Promote the Executor to hold a
child `Node3D` body (the Forge wave-2 host figure) placed at a lectern near the
manor gate (space 0), or riding the hearse at the head of the drive. On reveals,
instead of only pushing the camera at the victim, sometimes cut to a TWO_SHOT
(F3): Executor in the foreground, the doomed pawn over his shoulder. He presides.
→ BUILD body node + fixed placement + a lectern prop anchor. FILES:
`executor_host.gd`, `board_path.gd` (lectern/host anchor). SIZE M.

**F7 — A puppet gesture library (transform-only).** With no rig, animate the
static mesh (and a few child transforms — an arm, a hat, a cloak) via
position/rotation/scale tweens:
- **Breathing idle** — 1–2 cm vertical sway on a ~15–20/min cycle (the research's
  foundational "alive" tell). Runs whenever he is on screen.
- **Present** — lean + rotate toward the stone being revealed.
- **Tut-tut** — a small Y-rotation head-wobble on a grave loss.
- **Approve** — a slow nod on a Codicil claim.
- **Arms-up / rise** — on THE HOUSE AWAKENS.
- **Secondary motion** — a cloak/hat child that lags the body with a cheap
  spring, so every move has follow-through (the trick that makes limited
  animation read as more frames than it has).
→ BUILD `executor_body.gd` gesture table (each gesture = a tween recipe). FILES:
new `executor_body.gd`, `executor_host.gd`. SIZE M–L. **[B2 core.]**

**F8 — Anticipation for comic timing.** Give `executor.say()` an optional gesture
argument. Before a cruel punchline the host does a tiny lean-back (anticipation),
then snaps forward on the reveal — "anticipation makes the subsequent action feel
earned" ([GameJuice / Disney 12](https://gamejuice.co.uk/articles/disney-12-animation-principles-games)).
A subtle scale-squash on emphasis words. Cheap once F7 exists, and it is what
turns a line-reader into a comedian.
→ BUILD gesture hook on `say()`. FILES: `executor_host.gd`. SIZE S (after F7).

**F9 — Colour commentary in the dead air.** The Executor only speaks at landings.
Fill the MOVE gap (pawns travelling) and the pre-reveal beat with dry asides that
react to *board state*, not just the space: a needle when the leader extends, a
note when someone has ridden blanks all night, a "the estate is watching" when a
seat can't afford the Codicil. Expands the line pools (feeds B5 writing) and
means the host is never silent while something is happening.
→ BUILD `_between_reveal_aside()` + new pools (LEADER_EXTENDS, IDLE_TAUNT,
SKINT). FILES: `executor_host.gd`, `procession.gd` `_round()`. SIZE M.

---

## 3. SPACE-EVENT PAYOFFS

Current state: each `_resolve_*` in `procession.gd` fires one `Sfx.play()` + one
text line. Good boards make each space a *decision grammar* with a legible payoff
([League of Gamemakers on tile readability](https://www.leagueofgamemakers.com/what-the-font-type-tips-for-board-game-designers/)).
The unifying build here is a **per-space FX spawner** on `board_path.gd`
(one-shot `GPUParticles3D` + light flash keyed by space type) plus a **flying-
number** helper (grudge/Deed deltas physically travel from the stone to the HUD
chip). Both are reused by every space below and by §4; particle/popup tech is
already in `minigames/tilt`, `orbital`, `dead_weight`.

**F10 — SHRINE (+3, gain).** The lamppost prop flares warm; a rising column of
soft green motes lifts off the stone; the pawn does a small hop of relief; the
`+3♠` label arcs from the shrine to the player's chip. (`grudge` sfx already
plays.)
→ BUILD fx spawner + flying-number. FILES: `board_path.gd` (spawner),
`procession.gd` `_resolve_shrine`. SIZE M (the reusable half).

**F11 — WEEPING GRAVE (−2 / owner toll).** The headstone weeps a thin blue drip;
the pawn slumps (squash); a low mournful sfx; the `−2♠` falls and shatters — or,
if a monument toll, arcs to the owner's chip while their grave-side votive
(`board_path.gd:248`) flares as it collects.
→ BUILD grave fx + toll transfer arc (reuses F10 helper). FILES: `board_path.gd`,
`procession.gd` `_resolve_grave`. SIZE M.

**F12 — TOLLGATE (claim / pass).** On claim, the wrought-iron arch drops its
gate-bar and lights in the owner's colour (set the arch's emissive), a
chain/coin sfx, and a small owner-colour banner hangs on the arch **persistently**
— so the board itself shows who owns which gate (readability + flair). On a
pass-through toll, a turnstile click + coins arc payer→owner.
→ BUILD arch owner-tint + persistent banner + pass fx. FILES: `board_path.gd`
(`set_tollgate_owner` → also tints/banners), `procession.gd`
`_resolve_tollgate` / `_pay_passthrough_tolls`. SIZE M.

**F13 — SÉANCE (the one visible wheel).** Doc 18 Q1 promised the planchette would
become the SÉANCE space's event mechanic; today `_resolve_seance` picks a slot
via `rng` and prints text instantly. Build the actual spin: the planchette prop
(`GEN_PLANCHETTE`) rotates over a four-slot dial and decelerates onto the slot
the sim already chose (deterministic-safe — the visual animates *to* a decided
result), purple glow + ghost-whisper sfx, the medium pawn lifts. Reuse
`minigames/seance/seance_arrow.gd` for the spinner maths.
→ BUILD `seance_wheel.gd` (3D or overlay) driven from the chosen slot. FILES: new
`estate/procession/seance_wheel.gd`, `procession.gd` `_resolve_seance`.
SIZE M–L. **[High joy — it is the séance finally happening on screen.]**

**F14 — VENDETTA (sealed 1v1 wager).** `_resolve_vendetta` resolves silently in
text. Stage the duel: TWO_SHOT (F3) of the two pawns; they slide to face each
other; two sealed envelopes/coins rise and flip simultaneously; the winner's pawn
lunges, the loser recoils (transform tweens); red duel key light. On-brand — the
estate's soul is 1v1 spite.
→ BUILD duel staging beat. FILES: `procession.gd` `_resolve_vendetta`,
`board_camera.gd`. SIZE M.

**F15 — STALL (item).** A quick shop flourish: the crate lid pops, the acquired
item's card flips up on the lower-third with its icon + rule (the item grammar is
already announced text in `board_spaces.ITEMS`), a hand-off sfx. Telegraphs which
sabotage was taken (overlaps §4/§7).
→ BUILD item-card flip. FILES: `procession.gd` `_resolve_stall`. SIZE S–M.

**F16 — BLANK / PATH STONE.** Even "nothing happens" needs a beat or it reads as
a bug. A dry shrug line (exists in `Executor.BLANK`) + a tiny dust puff + a hollow
wood-block tick. The comedy is the anticlimax; sell it.
→ BUILD minimal blank fx. FILES: `board_path.gd`, `procession.gd` reveal default.
SIZE S.

---

## 4. DEED / ITEM FLAIR

Pummel Party's identity is that sabotage is "gleefully unfair … over the top and
comical" — a wrecking ball ragdolls you, an exploding eggplant sends people flying
([Refined Geek](https://therefinedgeek.com.au/index.php/2025/04/21/pummel-party-a-friendly-beatdown/),
[Gideon's Gaming](https://gideonsgaming.com/pummel-party-review-my-kind-of-party/)).
Our sabotage is currently invisible arithmetic.

**F17 — The Deed purchase is the money shot; right now it is one sfx + a
teleport.** `_resolve_codicil` plays `match_win`, prints a line, and the beacon
*teleports* to a new space via `board.set_beacon(new_idx)` (`:890`). Build the
climax the whole economy converges on: BEACON_HERO camera push; the gold glow
flares and pulses; a wax-sealed Deed scroll rises from the pedestal and flies to
the buyer's chip; a stamp-thud; the price visibly drains from their grudge. Then
the relocation is **shown, not teleported** — a gold will-o'-wisp streaks from the
old space to the new one so every player SEES where the target moved (a
readability *and* drama win; today the moving Star just vanishes and reappears).
Capture a MomentScribe still here (F5).
→ BUILD purchase beat + `set_beacon` travel animation. FILES: `procession.gd`
`_resolve_codicil`, `board_path.gd` `set_beacon`. SIZE M–L. **[Top joy-per-effort.]**

**F18 — Item-use telegraphs.** Items apply silently with a `_flash_line`
(`_apply_item_movement`, `_resolve_grave` salt branch). Each needs a *visible*
cause→effect: the MOURNING PIN glints and the pawn springs one extra hop; the
BLACK RIBBON visibly ties around the leader's pawn and drags it back a space;
GRAVE SALT scatters white particles and the grave's drip (F11) stops. Sabotage
you can see is sabotage you can laugh at.
→ BUILD three item telegraph beats. FILES: `procession.gd` item paths,
`board_path.gd` fx. SIZE M.

**F19 — Show held items on the HUD.** `items[]` (pin/ribbon/salt counts) is
tracked but never displayed, so players cannot plan around each other's
inventory — the core of item strategy. Add small item pips to each player's chip
(`_build_hud`/`_refresh_hud`), glyph+count (colour-blind-safe).
→ BUILD chip item tray. FILES: `procession.gd` `_build_hud`, `_refresh_hud`.
SIZE S–M. (Readability overlap with §7.)

---

## 5. INTERSTITIALS

Current state: ROUND N is a silently-updated top-bar label; the minigame pick is
a plain `_announce_text("THE WAKE PAUSES FOR A GAME\n<NAME>")` (`:958`). Superstars
sped turns by cutting bloated cutscenes, but it kept the *legible chapter
structure* — the "GET READY" splash, the roulette, the VS card — because those
tell you where you are ([CBR](https://www.cbr.com/mario-party-superstars-better-than-super-mario-party/)).
The film-shader tech (`newsreel.gdshader`) and its intertitle card style are
already shipped and unused outside the newsreel.

**F20 — Round banners.** Between rounds, a brief ornate wipe card — "ROUND 3 · THE
WAKE CONTINUES" — sliding in on a black gothic bar, holding ~1s, wiping off. Reuse
the newsreel intertitle font/rule ornament for house consistency. Gives the night
chapters and a natural skip point.
→ BUILD round-banner helper (a styled variant of `_announce_text`). FILES:
`procession.gd` `_run_night` loop. SIZE S.

**F21 — Standings wipe.** Before each minigame block and at round end, a quick
card: four `PlayerBadge` portraits ranked by Deeds with counts, animating rank
changes (a pawn that overtook slides up its row). Pairs with the STANDINGS camera
(F4). Keeps the whole table oriented to the race.
→ BUILD standings card. FILES: new `estate/procession/standings_card.gd` or extend
the announce layer; reuse `PlayerBadge`. SIZE M.

**F22 — Minigame roulette + GET READY.** `_minigame_block` already picks the game
via `CONTRACT_POOL[rng...]`; wrap it in the Mario-Party roulette — a reel of the
game titles/icons that decelerates onto the chosen game (animates to the decided
result; deterministic-safe), then a "GET READY" splash and the game's how-to
card. Highest-recognition "this is a party game" beat in the genre.
→ BUILD roulette UI over the existing pick. FILES: `procession.gd`
`_minigame_block`, small roulette scene. SIZE M.

**F23 — A film-shader stinger.** Reuse `newsreel.gdshader` for a ~1s sepia/gate-
flicker flash — run the THE HOUSE AWAKENS announce through it so it reads as a
horror title card, or flash it over the standings as "the estate remembers." Pure
reuse of shipped tech, deeply on-brand.
→ BUILD apply shader material to an announce beat. FILES: `procession.gd` announce
layer. SIZE S.

---

## 6. DEAD SEATS  (feeds the GHOST MEDDLING lane — be generous)

The cardinal party-game sin is a player with nothing to do
([TV Tropes: Player Elimination](https://tvtropes.org/pmwiki/pmwiki.php/Main/PlayerElimination)).
Two distinct dead-seat surfaces exist here:

- **Board-level micro-waiting** — during the serial REVEAL cascade, three players
  watch one landing resolve. This is *intentional* (the shared "ohhh" beat, doc 13
  §A5) but it is passive.
- **Minigame elimination** — the block runs anthology games; knock-out games
  create true spectators.

The gold standards to steal from: **Jackbox's "enhanced spectator"** — out-players
still affect the outcome, voting to bias hazards or spinning a wheel slice that
changes the game ([Jackbox: audience play-along](https://www.jackboxgames.com/blog/how-audience-play-along-differs-in-each-jackbox-game));
**Blindfire** — spectators trigger arena traps and score if a survivor dies
([Game Rant](https://gamerant.com/blindfire-multiplayer-interview/)); **Mario Kart
DS** — the eliminated become ghosts that drop item boxes for the living. The
principle across all three: *give the dead a small, safe, ATTRIBUTED lever over
the living.*

**F24 — Reveal-cascade REACT buttons (board-native).** During the serial reveal,
let the three waiting players tap a face-button to float their badge reaction — a
laugh, a jeer, a wince — over the victim's stone, attributed and harmless. Turns
the enforced watch beat into communal, visible schadenfreude (which IS ILL WILL's
content). No sim impact; pure expression.
→ BUILD reaction poll + floating badge fx in the reveal window. FILES:
`procession.gd` `_reveal_landing`, reaction fx. SIZE M. **[Top joy-per-effort;
board-native, not just minigames.]**

**F25 — Ghost meddling in elimination minigames (the B6 core).** When a player is
knocked out of a block game they become a poltergeist with small, safe,
*attributed* interactions — a rattle that shakes a survivor's screen edge, a gust
that nudges a trajectory, a candle flicker that briefly dims a light — each one
labelled ("BLUE's ghost rattles the gate") so it is social, never anonymous RNG.
A slow-charging meddle meter keeps it a garnish, not a determinant (Pummel's
warning: late-game swings that become noise, doc 13 §A2.5). Ghost/poltergeist
actors already exist to reskin (`dead_weight/poltergeist.gd`,
`last_will/lw_ghost.gd`).
→ BUILD a cross-cutting `core/ghost_meddling.gd` kit + per-minigame opt-in hooks.
FILES: new `core/ghost_meddling.gd`, minigame integration points. SIZE L.
(Separate lane — flagged for scope.)

**F26 — The dead become the audience (Jackbox model).** Out-players in a block
game get a legible lever: vote which surviving rival draws the next hazard, or
stake a sliver of their own grudge into a "wake pool" on who wins the block. Keeps
the eliminated economically active — the estate's grudge economy already does
this at the macro level (doc 13 §A2.6); this extends it into the dead minutes.
→ BUILD out-player betting/vote UI on the minigame result hook. FILES: minigame
result contract, small betting overlay. SIZE M–L.

**F27 — Idle business for waiting pawns.** During ceremony holds and (future)
sequential beats, waiting pawns do ambient business — lean on a headstone, kick a
pebble, flinch when a crow lands on the trailing pawn's head. Reuses the Ambient
Life Kit (B3). Converts dead air into character rather than into a frozen diorama.
→ BUILD pawn idle-business hooks. FILES: `board_path.gd` pawns, B3 ambient kit.
SIZE M.

**F28 — Ghost mourners quoting the chronicle (audience made of your past).** The
board's edges hold spectator ghosts drawn from `EstateState.chronicle` — previous
nights' losers — drifting with speech bubbles that quote *real* chronicle lines
("BLUE has not forgiven the betrayal of Night 2"). The Jamboree-TV critter
audience, but the audience is your own history. Overlaps B3; a spectacular
dead-seat *and* memory beat.
→ BUILD chronicle-fed ghost spectators at the board perimeter. FILES: B3 ambient
kit + `EstateState.chronicle` read, `board_path.gd` perimeter. SIZE M.

---

## 7. READABILITY

The board already does the fundamentals right — each stone carries an emissive
rune, a colour rim ring, AND a billboard text tag (`board_path.gd:199–221`), never
colour alone, which is exactly the "bold outline + colour + icon, glance-readable"
standard ([League of Gamemakers](https://www.leagueofgamemakers.com/what-the-font-type-tips-for-board-game-designers/)).
The gaps are about *anticipation* — knowing what a move will do *before* it
resolves, which is the steer-toward-a-space decision Mario Party is built on.

**F29 — Space-target preview during the putt.** Today you charge the putt meter
blind — you see power, not destination. As a player charges (`pawn_putt.gd`
meter), map the current ratio to the space it would reach and highlight that stone
on the drive + ghost its rule ("SHRINE +3") as a tooltip. This converts the putt
from a raw power meter into the actual *decision* ("do I want to land on the
grave or overshoot to the shrine?"). The rule strings already exist
(`board_spaces.rule()`).
→ BUILD ratio→space projection highlight + rule tooltip. FILES: `pawn_putt.gd`
(the meter already knows the ratio→spaces map via `spaces_for_power`),
`board_path.gd` (highlight a stone), `board_spaces.gd` (`rule`). SIZE M–L.
**[Highest design value — restores the core MP decision.]**

**F30 — Codicil position telegraph.** The beacon moves each claim and players must
always know where it is and how far. It has a gold `OmniLight` glow
(`board_path.gd:362`) but no board-wide or per-pawn cue. Add a tall gold light
beam/pillar from the beacon (visible over furniture from any angle) and a small
"◆ 5 →" distance pip on each pawn's tag. Combined with the relocation streak
(F17), the moving target is never lost.
→ BUILD sky-beam + per-pawn distance pip. FILES: `board_path.gd` beacon, HUD.
SIZE S–M.

**F31 — Colour-blind consistency audit.** The stones are exemplary; ensure the new
elements match — flying numbers (F10/F11) carry glyph+sign not just colour, owner
banners (F12) carry the owner's `PlayerBadge.glyph`, item pips (F19) carry glyph+
count. A small consistency pass as the new visuals land, not a separate build.
→ BUILD audit + fixups alongside §3–4. FILES: `board_path.gd`, `procession.gd`.
SIZE S.

**F32 — A one-time board legend at night start.** `board_spaces.legend_text()`
already exists and is unused. Flash it once during `_intro` (after the will
clauses) so a first-timer can read the drive. Free.
→ BUILD one announce card from `legend_text()`. FILES: `procession.gd` `_intro`.
SIZE S.

---

## 8. WILDCARD — something no Mario Party has done, native to a funeral drive

**F33 (PRIMARY) — THE EULOGY: a procedurally-authored closing monologue from the
night's real conduct.** Mario Party cannot do this — it has no persistent
per-player narrative; its bonus stars are a stat readout. ILL WILL already tracks
everything needed: `stats[]` holds each seat's `moved / graves / lost / duels /
shrines / deeds_bought / spent`, and the chronicle holds cross-night history. At
the will-reading, before the heir is crowned, the embodied Executor (§2) delivers
a short generated eulogy that names each player by what they *actually did*
tonight — "We commend RED, who wept at four graves and betrayed no one but
themselves; and BLUE, who bought three Deeds with other people's grief" — over the
newsreel stills (F5) run through the film shader. It is the literal thesis of the
project ("a party you cannot remember was not a party" — `moment_scribe.gd`), it
lands the funeral, and it is almost pure reuse: `stats[]` + templated lines +
`Newsreel` + the Executor voice.
→ BUILD a stat→eulogy line generator + a will-reading eulogy beat. FILES: new
`estate/procession/eulogy.gd`, `procession.gd` `_will_reading`, reuse `Newsreel`.
SIZE M. **[The improvement Alex would never guess — highest thesis-fit.]**

**F34 (RUNNER-UP) — THE DRIVE BURIES ITSELF.** Mario Party's board is a static
loop with no felt direction. Make ours *directional and ending*: as the group
advances toward the Deed goal, lanterns the procession has passed extinguish
behind it and the crypt/manor gate at the destination brightens — the board
visibly buries itself as the night closes, and everyone can SEE the end
approaching. Drive it off the existing `FinalStretch` escalation
(`play_started`/`escalate`/`round_reset`) already attached at `procession.gd:392`.
Converts the abstract Deed-goal progress into moving gothic spectacle.
→ BUILD progress→lantern-extinguish + destination-glow, hung on FinalStretch
callbacks. FILES: `board_path.gd` (lantern state), `procession.gd`
(FinalStretch hooks). SIZE M.

*(A third idea, logged not specced: THE DECEASED PRESIDES — an effigy/portrait of
the dead relative on the manor whose tilt/expression reacts to the standings,
approving of the cruelest heir. A diegetic scoreboard. Deferred behind F33/F34.)*

---

## RANKING — joy per effort (director's read)

1. **F17** Deed money-shot + shown beacon relocation — M–L. The economy's climax; currently a teleport.
2. **F24** Reveal-cascade REACT buttons — M. Board-native dead-seat kill; communal schadenfreude.
3. **F5** Wire the board into MomentScribe — S. Cheapest possible; feeds newsreel/album/replay.
4. **F13** Séance wheel actually spins — M–L. Delivers the doc-18 promise; the one visible wheel.
5. **F7/F8** Executor puppet gestures + anticipation — M. The host gets a body and timing (B2 core).
6. **F33** THE EULOGY — M. The unguessable one; thesis-fit; near-pure reuse.
7. **F10/F11** Flying grudge numbers on shrine/grave — M. One reusable helper juices every economy beat.
8. **F22** Minigame roulette + GET READY — M. Highest-recognition party-game beat.
9. **F29** Space-target preview on the putt — M–L. Restores the core steer-toward decision.
10. **F1/F2/F3** Camera director + travel move + type-aware landings — M. The B1 spine.
11. **F20/F23** Round banners + film-shader stinger — S. Cheap chapter structure from shipped tech.
12. **F30** Codicil sky-beam + distance pips — S–M. Never lose the moving target.
13. **F12** Tollgate owner banner/tint — M. Persistent ownership on the board itself.
14. **F34** The drive buries itself — M. Directional gothic spectacle off FinalStretch.
15. **F25/F26** Ghost meddling + audience betting — L. Biggest, separate B6 lane; the dead get a lever.

---

*Sources — presentation/broadcast focus (mechanics sources live in doc 13):
Jamboree camera/pacing critique ([VGC](https://www.videogameschronicle.com/review/mario-party-jamboree-switch-2/),
[Pocket Tactics](https://www.pockettactics.com/super-mario-party-jamboree/tv-review),
[Nintendo Life modes](https://www.nintendolife.com/guides/super-mario-party-jamboree-nintendo-switch-2-edition-plus-jamboree-tv-all-new-minigames-and-modes));
host design ([MC Ballyhoo, MarioWiki](https://www.mariowiki.com/MC_Ballyhoo_%26_Big_Top));
Pummel meanness ([Refined Geek](https://therefinedgeek.com.au/index.php/2025/04/21/pummel-party-a-friendly-beatdown/),
[Gideon's Gaming](https://gideonsgaming.com/pummel-party-review-my-kind-of-party/));
game-feel/juice ([GameAnalytics](https://www.gameanalytics.com/blog/squeezing-more-juice-out-of-your-game-design),
[GameJuice / Disney 12](https://gamejuice.co.uk/articles/disney-12-animation-principles-games));
limited-animation life ([Game Anim](https://www.gameanim.com/2019/05/15/the-12-principles-of-animation-in-video-games/),
[MoCap Online idle guide](https://mocaponline.com/blogs/mocap-news/idle-animation-game-dev-guide));
dead-seat engagement ([Jackbox audience](https://www.jackboxgames.com/blog/how-audience-play-along-differs-in-each-jackbox-game),
[Blindfire spectator traps](https://gamerant.com/blindfire-multiplayer-interview/),
[Player Elimination, TV Tropes](https://tvtropes.org/pmwiki/pmwiki.php/Main/PlayerElimination));
board readability ([League of Gamemakers](https://www.leagueofgamemakers.com/what-the-font-type-tips-for-board-game-designers/),
[Matt Paquette on tabletop type](https://www.mattpaquette.com/design-blog/2018/7/8/typography-tabletop-games)).*
