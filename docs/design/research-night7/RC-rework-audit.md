# R-C — Load-Bearing Repo Audit for the ONE-GAME Rework (2026-07-18)

Research lane R-C, night 7. Read-only audit of `un_party_game` (Godot 4.6.2)
against the producer spec: merge PROCESSION + CLASSIC into one Mario-Party-like
game — winding track across a larger estate, route splits, hazards/item
boxes/stores, NPC spectators, character minifigs, over-shoulder roll camera,
sequential turns, two currencies (shop + victory), 3 board-nights per game with
estate interludes. Scrap: auction, map voting, player voting.

Everything below is read from code, with file:line anchors. No code was changed.

---

## 1. THE TWO MODES TODAY

The project's main scene is `estate/estate.tscn`; `estate/estate.gd` (3,224
lines) is simultaneously the title screen, the lobby, the walkabout hub, the
classic night loop, and the online mirror host. `core/party_setup.gd` is NOT a
mode switch — it is the always-on ESC settings overlay (seats/controls/audio/
video/access + the GAME tab prefs `night_length`, `mg_rounds`, `deed_goal`,
`theater_in_pool`) plus `quit_to_title()` / `free_stray_root_nodes()` (the
zombie-module sweeper) and the W6 Executor "non-play voice."

**The fork in the road** is `estate.gd::_build_play_panel()` (line 373): the
PLAY menu offers **THE PROCESSION** (featured; Deed-goal dial 4/6/9 →
`_enter_procession`, line 455) and **CLASSIC NIGHTS** (→ `_play_pressed`,
line 350).

### CLASSIC NIGHTS — what it actually is

The auctioned-minigame night loop plus the trail-parade meta-game. Flow per
`estate.gd` `Phase` enum {LOBBY, SELECTOR, GROUNDS, TILES, AUCTION, CHOOSING,
GAME, RECKONING, NIGHT_END, TITLE}:

1. `_play_pressed` → `EstateState.start_night(4)` — resumes a run at its
   between-nights boundary or starts fresh at the auction.
2. Per game (`night_length` = 3/5/7 games per night, pref):
   - First night of a fresh slot: **HOUSE RULES** card (`howto_cards.gd`).
     Night 2+: **STANDING GRUDGE** card (`saga_cards.gd`).
   - **AUCTION** (`_enter_auction`, 1703): 3 minigames sampled without
     replacement from a 10-16 game pool; players bid **grudge ♠** to choose;
     no bids → cheapest seat chooses. **Side bets** (bet 1♠ on the winner —
     this is the closest thing to "player voting") ride the auction panel.
   - **CHOOSING** → GET READY card / module IntroCard (double-gate collapse) →
     **GAME**: module instanced (contract minigames as estate children;
     `"gamestate"` PAR at tree root), `begin({roster, rounds, rng_seed,
     practice})`.
   - `_on_module_finished` (2009): match podium → `EstateState.apply_results`
     — placements pay **points** 5/3/2/1, `currency_events` pay **grudge ♠**,
     `kill_events` feed vendetta/nemesis — → **RECKONING** ticker.
3. After `night_length` games, **NIGHT_END ceremonies** (`_night_ceremonies`,
   2153): night podium + gate statue → newsreel (MomentScribe stills) →
   family-album archive → **will reading** (superlatives + chronicle lines +
   eulogy receipt) → **NIGHT PARADE** (`_run_parade`, 2103): every pawn
   advances on the 26-stone spiral trail (`estate/trail.gd`, tollgates at
   8/16) by their night points; reaching stone 25 = summit.
4. Summit → `_run_over` → heir podium → **THE FINAL AUDIT**
   (`_enter_funeral_statistics`) → title. Otherwise `_start_boundary` →
   **GROUNDS** free roam (walkabout, wardrobe, trap tiles, album, theater)
   → next night. A RUN is open-ended: nights repeat until someone summits.

### THE PROCESSION — what it actually is

A self-contained board-mode scene (`estate/procession/procession.tscn`,
`procession.gd` 1,940 lines) instanced at the tree root. Two boots:
`ProcessionBoot` autoload (`--procession` CLI, verification path) or the estate
merge path `begin({roster, seed, deed_goal})` (mutually exclusive via
`_started`). It supplies its own camera, HUD, EnvKit environment, and economy.

Night loop (`_run_night`, 770):
- Intro: establishing flyover (skippable) + **will clauses** announced up
  front (3 stat races each worth +1 Deed at the reading).
- Rounds, until win or 60-round cap:
  - **ROLL** — all four pawns charge the **pawn putt** meter simultaneously
    (`pawn_putt.gd`: frozen PAR physics projected to 1-6 spaces; W8
    "reshuffled green" re-deals band values every roll).
  - **MOVE** — all pawns hop at once around a fixed **24-space loop**
    (`board_path.gd` LAYOUT: 6 shrine, 5 grave, 3 stall, 1 codicil-berth,
    2 séance, 2 tollgate, 2 vendetta, 3 blank; the Codicil beacon roves).
  - **REVEAL** — the Executor (`executor_host.gd` + embodied
    `executor_body.gd`) resolves landings one victim at a time with the
    named-shot camera (`board_camera.gd`).
  - Every 2nd round: **minigame block** — stall item handout, roulette
    theater, then a REAL contract minigame (or the deterministic MINISIM
    under soak); placements pay 5/3/2/1 **grudge ♠**.
  - Every 3rd round: **THE HOUSE AWAKENS** (all-in setback event) + interim
    reading of clause leaders.
- Win: `deeds[i] >= deed_goal` (or `moved_total >= movement_goal` in the
  QUICK WAKE preset). Deeds ◆ are bought at the roving Codicil for grudge
  (10 + 2×deeds held, `codicil.gd`).
- Close: will reading (+1 Deed per clause) → procedural **eulogy**
  (`eulogy.gd`) → **HEIR CROWNED** podium → `night_over(tally)` →
  the estate folds the scene and returns to the title.

### Where they diverge (the duplication the rework erases)

| Axis | CLASSIC | PROCESSION |
|---|---|---|
| Board | 26-stone spiral trail, advance by night points, once per night | 24-space loop, advance by putt roll, every round |
| Session | open-ended run (nights until summit) | one self-contained night |
| Economy | EstateState points + grudge + legacy + pot | local `grudge[]` + `deeds[]` arrays |
| Minigame cadence | the night IS minigames (auction picks each) | minigame every 2nd round (rng picks) |
| Executor | UI-label quips in estate panels | embodied host + reveal cascade + camera |
| Save writes | full run state each dawn | heir monument + graffiti only |
| Movement verb | none (parade is automatic) | simultaneous putt meter |

Neither "map voting" nor a standalone "player voting" system exists as named
features in code: PAR's course is picked via `GameState.course_id` (menu), the
auction's pick-of-3 is the minigame-selection mechanism, and the side-bet rows
in `_enter_auction` are the player-vote analogue. All three die with the
auction. (Séance/Understudy contain *in-game* vote mechanics — those are
minigame internals and untouched.)

---

## 2. INVENTORY TABLE

Verdicts against the new loop (hub → ready → board night [roll → move →
minigame] → first-across-the-end → estate interlude → ×3 nights → totals).

| File / system | Role today | Verdict |
|---|---|---|
| `estate/procession/procession.gd` | board-night engine, round loop, economy, reveal cascade, net mirror | **ADAPTS** — becomes the game's core scene. Survives: round skeleton, reveal cascade, HUD chips, `_beat`/skip discipline, `_net_state` pump, tally/receipt idiom. Changes: simultaneous roll → sequential turns; loop → linear track with splits; deed-goal win → cross-the-finish win; minigame every 2nd round → every round; local economy → the two shared currencies |
| `estate/procession/board_path.gd` | fixed 24-space closed ring, parametric positions, pawns, furniture, Codicil beacon | **SCRAPPED/REBUILT** — ring topology (posmod everywhere, `_ring_dist`, `space_pos(i)` as pure ring function) cannot express a winding track with 2+ route splits; needs a node-graph board. **Salvage**: the Meshy swap-point catalogue + fallbacks, grave variants, per-type furniture placement, hop-tween `advance_pawn`, putt-preview reticles |
| `estate/procession/board_spaces.gd` | space grammar table (type → name/icon/color/rule/bot_value) | **ADAPTS** — exactly the data shape hazards / item boxes / stores need; contents change |
| `estate/procession/pawn_putt.gd` | simultaneous hold/release skill meter (frozen PAR physics, W8 re-dealt bands) | **SCRAPPED** — replaced by the Madden-style oscillating slider. **Salvage**: PuttMeter corner-Control chrome, bot release-at-target-ratio determinism, tick-based (not wall-clock) roll discipline, `{seat, power, release_tick}` net shape |
| `estate/procession/board_camera.gd` | named-shot director (ESTABLISH/FLYOVER/MOVE_TRAVEL/LANDING_PUSH/TWO_SHOT/BEACON_HERO/STANDINGS), deterministic sway, snaps under `fast` | **ADAPTS** — vocabulary and fast/headless discipline survive; every anchor reads `board.CENTER` / `space_pos()` / `reveal_shot()` (board_path.gd:673) and must be re-derived per track node. The over-shoulder roll shot is NEW (sequential turns make it natural — one mover at a time). Note: `executor_host.gd` also drives the same Camera3D (push_to/reset_camera) — fold into the director during the rework |
| `estate/procession/board_minimap.gd` | parchment ring inset | **ADAPTS/REBUILD** — chrome survives; ring projection dies with splits (needs graph layout) |
| `estate/procession/codicil.gd` | roving hard-currency desk (10 + 2/deed) | **ADAPTS or SCRAPPED** — decision for Alex: under "stores on spaces + victory currency," the Codicil pattern (buy the victory unit at a visible, escalating price) is the Mario-Party star and maps 1:1 onto the new board's store spaces; otherwise it dies with deeds |
| `estate/procession/executor_host.gd` + `executor_body.gd` | Executor line pools + embodied host + gestures | **ADAPTS** — the reveal cascade fits sequential turns even better (it's already one-victim-at-a-time). Line pools are keyed to space types and ♠/◆ glyphs — rewrite with the new space set and currency names |
| `estate/procession/seance_wheel.gd`, `minigame_roulette.gd` | decided-result theater (wheel, pre-minigame reel) | **SURVIVES** — the "animate TOWARD a decided result, draw no rng" pattern is exactly right for item boxes / space events |
| `estate/procession/board_fx.gd` | flying attributed numbers + Deed token | **SURVIVES** (retarget glyphs) |
| `estate/procession/vendetta_stakes.gd` | sealed 0-3 wager overlay (presentation-only) | **ADAPTS** — keep iff a duel space survives on the new board; cheap either way |
| `estate/procession/eulogy.gd` | procedural closing eulogy from real night stats | **SURVIVES** — feeds straight into the estate interlude / end-of-game reading |
| `estate/procession/presets.gd` | 4 session-length presets | **ADAPTS** — becomes board-length / lap-count dials; QUICK_WAKE's score-is-movement mode is close to the new "minigame winner gets currency, board decides" split and may simply die |
| `estate/procession/procession_boot.gd` | `--procession` CLI boot autoload | **SURVIVES** — stays the headless receipt entry for the new board |
| `estate/saga_cards.gd` | STANDING GRUDGE / FUNERAL AUDIT / EULOGY RECEIPT (reads ledger/chronicle only, no writes) | **SURVIVES** — slots directly into the interlude and end-of-game |
| `core/ui_kit/results_board.gd` | standardized freeze→reveal→count-up→winner ceremony | **SURVIVES as-is** — and is the natural chassis for the Mario-Party end-of-game totals reveal |
| Auction code (`estate.gd` 1703-1881 `_enter_auction`/`_on_bid`/`_update_auction_clock`/`_bots_bid`/`_resolve_auction` + `_net_auction_flavor`/`_client_build_auction_rows` + AUCTION/CHOOSING phases) | minigame selection by grudge bidding | **SCRAPPED** (~250 lines + net facts + HowtoCards house-rules copy that explains it) |
| Side bets / player voting (`estate.gd` bet rows 1791-1821; `EstateState.place_bet`/`bets`/`pot` payouts 232-244, 338-344) | bet 1♠ on the game winner | **SCRAPPED** |
| Map voting | — | **n/a** — does not exist; PAR course pick (`GameState.course_id`) and the auction pick-of-3 are the analogues; both go |
| Trap tiles (`estate/trap_tile.gd`, TILES phase, `_place_tile`/`_on_tile_tripped`) | grounds ambush economy | **SCRAPPED as a phase** — the concept ("seed a hazard on the shared board") is worth carrying to the new board's hazard spaces |
| Trail + parade (`estate/trail.gd`, `_run_parade`, tollgates, summit) | classic meta-board | **SCRAPPED** — the new board IS the progress. Gate statues (`$Trail.add_statue`) survive as ceremony set-dressing relocated to the hub |
| `core/moment_scribe.gd` | best-8 stills per night, priority-ranked, headless no-op | **SURVIVES as-is** — new board just calls `capture()` at its beats |
| `estate/newsreel.gd`, `estate/family_album.gd`, `estate/monuments_view.gd`, graffiti wall | the estate's memory | **SURVIVES** — interlude beats |
| `core/final_stretch.gd` | endgame music/vignette/tick kit | **SURVIVES as-is** — attach at "final stretch of the track" |
| `core/shake_kit.gd`, `core/env_kit.gd` | roll shake; MOONLIT/CANDLELIT/STAGELIT house look | **SURVIVES as-is** |
| `core/cosmetics.gd` + `estate/wardrobe_panel.gd` | hat registry + LEGACY-priced store | **SURVIVES** — the interlude store; touched only by the currency rename (prices are in LEGACY) |
| Walkabout (`estate/walker.gd`, stroll mode, hotspots) | hub traversal w/ real jump | **SURVIVES** — the spec's hub is exactly this |
| Rigged characters (KayKit `Barbarian/Knight/Mage/Rogue.glb`; `CHAR_SCENES` declared in ~15 files) | seat-indexed heroes everywhere; anims Idle/Walking_A/Running_A/Jump_*/Hit_A/Death_A; BoneAttachments head/hand_l/hand_r/chest (Rogue's head created at runtime) | **SURVIVES → PROMOTED** — board minifigs = replace `board_path.gd:499 _make_pawn()` (today a colored **CapsuleMesh + Label3D**, not a character) with scaled KayKit rigs (precedent scales: walker 0.78, avatar 0.7). Cosmetics already attach via `Cosmetics.apply_to_character` |
| Run-alongside spectators | — | **NEW** — nearest machinery: `core/ambient_life.gd` troupe + `AmbientLife.rigged_or_null()` + Meshy rigged NPCs (`executor_butler_idle`, groundskeeper, 3 mourners). CRITICAL: rigged Meshy GLBs must be sized via `MeshyProp.instance_rigged` native-height math, never AABB (armature ×100 trap, meshy-troupe-VERIFY §scale) |
| Bots | universal rule `legacy_flag OR roster[i].bot` (VERIFY-BOTMIX); procession `_bot_targets()` value-seeking + seeded jitter; per-minigame inline bots + `us_bots.gd`; PAR `--parbots` | **SURVIVES** — minigame bots untouched; board bot adapts to sequential turns + slider timing (release-at-ratio logic carries over) |
| Online mirror (`core/net_session.gd`, estate 5/20 Hz pumps, `procession._net_state/_net_apply`) | host-simulates / client-renders | **ADAPTS** — the pump seam survives verbatim; the procession snapshot dict gains track-node positions and loses deed fields |
| `estate/estate.gd` | everything-shell | **ADAPTS (major surgery)** — keeps title/slots/lobby/ready-room/grounds/ceremonies/net mirror; loses AUCTION/TILES/CHOOSING/RECKONING phases; night loop delegates to the board scene 3× per game |
| `estate/estate_state.gd` | night + run + slot persistence | **ADAPTS** — see §4 |
| `core/podium.gd`, `core/transition.gd`, `core/music.gd`, `core/voice.gd`, `core/ambience.gd`, ui_kit | shared ceremony/AV kit | **SURVIVES as-is** |
| 14 minigames (`minigames/*`) + PAR (`scripts/*`, `scenes/courses/*`) | the anthology | **SURVIVES untouched** — contract `begin({roster, rounds, rng_seed})` → `finished({placements, currency_events, ...})` is exactly what the new "minigame every board round" needs. PAR's odd `"gamestate"` mode is pre-existing debt, not new work |
| `estate/mock_game.gd` | instant fake minigame | **SURVIVES** — the perfect stub for board-loop soaks |
| `core/frontend_director.gd`, `core/attract_mode.gd` | title composition + attract | **SURVIVES** |
| `core/howto_cards.gd` | house rules + GET READY + per-game cards | **ADAPTS** — ready-gate machinery survives; house-rules copy rewritten for the new economy |

---

## 3. CURRENCIES TODAY → TWO

Nine point-like resources exist; two are persisted. (Full mint/spend/display
site list verified in code; line anchors below are the load-bearing ones.)

| # | Resource | Glyph | Owner | Persisted | Mode | Fate under 2-currency |
|---|---|---|---|---|---|---|
| 1 | points (5/3/2/1 per placement) | — | `EstateState.players.points` (:193-200) / `GameState.players.score` | no (rolls into legacy) | both | → **VICTORY** currency (Mario-Party end totals) |
| 2 | grudge | ♠ | `EstateState.players.grudge` (start 2; ~10 mint/spend sites) | no | classic | → **SHOP** currency |
| 3 | grudge (separate array!) | ♠ | `procession.grudge[]` (start 5; shrine +3, grave −2, tolls, reckoning 5/3/2/1, codicil spend) | no | procession | → **SHOP** currency (unify with #2 — today they are unrelated variables) |
| 4 | deeds | ◆ | `procession.deeds[]` (codicil buy, will clauses; win at goal) | no (heir → monument label) | procession | → **VICTORY** currency |
| 5 | legacy | — | `EstateState.legacy{}` (:376-377, 392) — wardrobe wallet | **YES** (save key `legacy`) | classic | fold into SHOP currency **or** keep as the only persistent wallet — decision; wardrobe prices (`wardrobe_panel.gd` 10-30) re-denominate either way |
| 6 | pot | ♠ | `EstateState.pot` (auction bids + bets) | no | classic | **dies** with auction/bets |
| 7 | vendetta stake (0-3) | pips | transient wager | no | procession | stays a SHOP-currency wager if duels survive |
| 8 | trail_pos + tollgates | — | `EstateState` run block | **YES** (`run.*`) | classic | **dies** → replaced by board-night progress |
| 9 | royalty | — | `currency_events` type `"royalty"` → `night_stats` only (feeds THE ARCHITECT award) | no | both | stat, not currency — keep as award feed |

**Blast radius of the collapse** (largest first):
1. `procession.gd` — the whole economy (grudge/deeds arrays, chips `"%d♠ ◆%d"`,
   codicil, reckoning, tolls, séance rules) — but this file is being reworked
   anyway.
2. `estate_state.gd` — ~10 grudge sites + `apply_results` + legacy accrual.
3. `estate.gd` — auction/bets/tiles/tolls spends (~10 sites, mostly in code
   that is being scrapped).
4. **All 14 minigames** emit `currency_events` `{type:"grudge"|"royalty"}`.
   Recommendation: **keep the internal type string `"grudge"`** and rename
   only at display level — otherwise 14 modules + their frozen per-game
   receipts get touched for a string.
5. Strings: Executor pools (executor_host.gd has ♠/◆ inside ~15 line pools),
   house-rules card, howto cards, saga_cards eulogy receipt lines, board
   space rules (`board_spaces.summary_rules`), wardrobe "LEGACY" labels.
6. Receipts: any receipt asserting tally arrays or ♠ totals (§5).

Normie-legible naming is a producer call; the code wants one **display-name
constant per currency** in one place (a `Currency` helper or GameState consts)
so the next rename is a two-line diff — today "♠"/"Grudge"/"Deed"/"LEGACY" are
hard-coded in dozens of format strings.

---

## 4. ESTATE SAVE COMPAT (slot_1 = Alex's REAL 5-night estate)

Schema (`estate_state.gd::save_estate` 430-453 / `load_estate` 455-485),
`user://saves/slot_N.json`:

```
monuments[]      {owner, color, label, night, [kind:"heir"]}   ← procession heirs too
graffiti[]       last 24 lines
ledger[]         {night, winner, awards[{who,title,line}], nemesis{hunter,prey,n}}
nights_played    int
gate_statues[]   {owner, color, night}
chronicle        {by_name{...derived + events accumulator}, nights_recorded}
legacy{}         seat → int   (wardrobe wallet)          ← PERSISTED CURRENCY
wardrobe{}       seat → [cosmetic ids]
house_rules_shown bool
run{}            {active, run_night, at_boundary, trail_pos{}, tollgates{}}
```

Side files (untouched by the rework unless currencies rename them):
`user://cosmetics.json` (equipped loadouts), `user://prefs.json`,
`user://party_setup.json`, `user://saves/moments/<session>/` + album archive.

**A migration MUST preserve** (this is the estate's memory — the product
thesis): `monuments` (incl. `kind:"heir"`), `ledger` (awards feed the
chronicle rebuild), `gate_statues`, `graffiti`, `nights_played`,
`chronicle.by_name.*.events` (the ONLY part `_rebuild_chronicle()` cannot
reconstruct from ledger/monuments), `legacy`, `wardrobe`,
`house_rules_shown`.

**Fields the rework touches**:
- `run{}` — `trail_pos`/`tollgates` die with the trail. New run shape needs:
  board-night index (1-3), per-seat board-node position, per-seat wallets if
  a night can be suspended mid-board, board layout seed. The loader is
  tolerant (`get()` with defaults everywhere), so **additive keys are safe
  and stale keys are silently ignored** — a slot_1 loaded by the new build
  simply sees an inactive run and offers a fresh game. That is acceptable:
  Alex's 5 nights of history live OUTSIDE `run{}`.
- `legacy` — only if the currency fold renames/re-denominates it; migrate by
  1:1 balance copy under the new key, never wipe.
- Recommend adding a `"schema": 2` version tag on first new-format write, and
  keeping the read path accepting version-absent (v1) files forever.

**Safety rails already in repo**: `_migrate_to_slots()` precedent (copy, never
move); memory file `estate-save-safety.md` — bot runs use `--slot=3` scratch
and delete `%APPDATA%\Godot\app_userdata\ILL WILL\saves\slot_3.json` after;
back up slot_1.json before any overnight session that touches the loader.
Note `--fresh-estate` wipes the CURRENT slot — never combine it with default
slot 1.

---

## 5. RECEIPT BLAST RADIUS

Mechanics first: a "receipt" here is a **frozen command line + its expected
stdout line(s)**, recorded verbatim in a `VERIFY*.md` — there is no receipt
database. Two harness autoloads make it work (`scripts/verify_capture.gd` for
Par/main captures; `procession_boot.gd` + `procession.gd::_parse_cli` for the
board), plus per-minigame in-scene flag parsers printing `*_ASSERT … PASS` /
`*_DETERMINISM … OK` lines. There is **no suite runner** — each receipt is
re-run by hand; the universal precondition every doc repeats is the import
gate `godot --headless --editor --import --quit --path .` (exit 0).

**What dies with the rework:**
- **The procession seed-7 receipt** — canonical home
  `docs/verify/meshy-troupe-VERIFY.md:168-170`:
  `godot --headless --path . -- --procession --seed=7 --deedgoal=4
  --autoplay=bots` → `PROCESSION_HEIR BLUE (seed 7, 17 rounds)` + the
  `PROCESSION_TALLY` JSON (seed/preset/rounds/heir/grudge[]/deeds[]/moved[]/
  positions[] — positions are indices into the fixed 24-ring). Also frozen in
  docs 19/23/24, alexmemory, and the `procession_boot.gd` header. Any change
  to rng draw order, board size, movement verb, or economy re-freezes it —
  the rework changes ALL four, so it is dead on arrival (precedent: W8's
  band re-deal already deliberately re-froze it once, `pawn_putt.gd` header).
- **`docs/verify/online-ceremonies-VERIFY.md`** (ONLINE PHASE 3) — estate
  ceremony mirror: podiums, the RECKONING ♠ ticker, will reading, parade,
  heir; asserts `NETPROBE_RESULTS RED:pts=…,grudge=…` per seat. Parade and
  the pts/grudge shape both die.
- **`docs/verify/parity-night4-VERIFY.md`** — full-night estate flow +
  reckoning parity (`NETHASH_MOD` digests over grudge awards).
- **Every `online-<game>-VERIFY.md` + host/client log pair** — each mirrors
  one minigame but *enters and exits through estate ceremonies + reckoning*
  and asserts grudge/♠ lines; the minigame halves stay true, the estate
  bookends re-freeze.
- Estate night-loop smoke receipts: `--estate --estatebots --mockonly
  --night=1` (`NIGHT_OVER → WILL_READ → PARADE → DAWN`), `--auctiontest`
  (the one estate-coupled flag inside `verify_capture.gd`), `--strolltest`,
  `--readytest`, the `--grudgetest`-family stagings that enter via
  `_enter_auction`, and VERIFY-BOTMIX's *shell-launch* half (its standalone
  per-game runs survive).
- Board-coupled capture flags: `--vendettatest`, `--longnames`,
  putt-preview/meter shots, flyover/board_wide/grave_detail showcase,
  minimap/W9 shots — all re-staged on the new board.

**What survives untouched:** every per-minigame receipt — the 11
`minigames/*/VERIFY.md` (echo `ECHO_DETERMINISM max_err=0.000000`, orbital
`CIRC_OK`/`ORBITAL_ASSERT`, greed `GREED_INTERCEPT`, mower
`MOWER_COVERAGE_ASSERT`, swap `SWAPMEET_ASSERT`, tilt idle/edge, dead_weight
living-win band, throne balance, widows_gaze tally, last_will squish,
pallbearers) plus VERIFY-AIM, VERIFY-PARV3 (minus `--auctiontest`), and the
single-game feature docs (hitkit/killstyle/kills/mower-tally/
swap-photofinish/seance-*/orbital-threat/lastwill-v2). They enter via their
own scenes/flags with their own seeds and never touch the board or estate
economy. The module contract is unchanged by the rework, so their frozen logs
stay byte-valid. (Caveat: if the `currency_events` type string were renamed,
every game's receipt that logs those events would re-freeze — hence the §3
recommendation to keep `"grudge"` internally.)

**Re-founding procedure for the new board's receipts:**
1. Keep the boot seam: `--procession`-equivalent flag + `--seed=N` +
   `--autoplay=bots` + preset dial, headless, deterministic MINISIM for
   minigame blocks, `Engine.time_scale` compression, tally printed as one
   JSON line + per-seat lines (the existing `_emit_tally` idiom is correct —
   copy it).
2. Freeze in this order, one receipt per layer, so a later failure localizes:
   (a) **board topology receipt** — print the generated track: node count,
   per-type counts, split points, checksum; assert stable per seed.
   (b) **movement receipt** — N sequential turns, slider under bot control,
   positions after each turn.
   (c) **full-night receipt** — seed sweep (at least seeds 1/7/11 × short
   preset): winner, night length in turns, final wallet arrays.
   (d) **3-night game receipt** — the new outer loop with mock_game as the
   minigame, asserting end-of-game totals.
3. Re-freeze the online mirror pair (host log / client log byte-compare of
   `_net_state` facts) only after (c) stabilizes.
4. Record the new frozen lines in a fresh `VERIFY-BOARD.md` + alexmemory, and
   explicitly retire the seed-7 line there so nobody "fixes" a soak back to
   BLUE/17. Since no suite runner exists today, this is the moment to add a
   trivial `tools/run_receipts.ps1` that replays the board + estate-loop
   receipt commands and greps their frozen lines — re-founding is when the
   command list is shortest.
5. Known harness gotchas to respect (memory: verification-runtime-gotchas):
   frame-indexed captures vs 144 Hz (tick-based waits, never seconds), the
   harmless shutdown segfault after `quit()`, and receipt-filter pitfalls
   (grep the tally line, not the whole log).

---

## 6. NIGHT / CEREMONY SYSTEMS → THE ESTATE INTERLUDE

The rework's "estate interlude between board nights" is almost fully stocked
from existing parts:

- **Will reading** — two implementations exist today: the estate's
  (`_enter_will_reading`: superlatives from `night_stats`, chronicle lines,
  saga eulogy-receipt block) and the procession's (`_will_reading`: 3 deed
  clauses + `ProcessionEulogy`). MERGE: the board night ends with the clause
  reading (bonus victory currency = Mario Party bonus stars — the clause
  system already IS this), and the interlude reads the superlatives +
  chronicle + eulogy. `night_stats` needs re-pointing at board-night data.
- **Night parade** — dies with the trail; its dramatic function (visualize
  the night's standings as motion) is absorbed by the board itself. Keep the
  gate-statue beat (`$Trail.add_statue` → relocate statues to the hub gate).
- **Monuments** — untouched; each board night's winner mints a monument
  (`add_monument`), the heir path already writes `kind:"heir"`. The hub's
  monument lawn is the persistence showcase — keep feeding it.
- **House rules card** — survives as the one-time primer; copy rewritten for
  two currencies + board rules (`HowtoCards.show_house_rules`).
- **Standing Grudge** — survives verbatim as the night-2/night-3 opener
  (`SagaCards.maybe_show_standing_grudge` reads only ledger/chronicle).
- **FINAL AUDIT** — survives as the end-of-GAME close (after night 3's
  Mario-Party totals), `funeral_audit_lines(heir)` unchanged.
- **Newsreel + Family Album** — survive; run them in the interlude
  (`MomentScribe.night_moments()` → `Newsreel.play` → `FamilyAlbumWall
  .archive` → `clear_night()`), with the board's capture beats feeding them.
- **Podium** — per-minigame podium survives; the end-of-game totals ceremony
  should be built on `results_board.gd` + `podium.gd` (both data-driven).
- **Online** — the ceremony mirror (stage facts on the 5 Hz channel, guests
  restage locally) survives; the auction facts die, board-night facts extend
  the existing `_net_ceremony` vocabulary.

---

## 7. EFFORT MAP

Dependency order matters more than size here. Phases sized for overnight
lanes; each ends committed with a receipt.

- **Phase 0 — decisions + safety (cheap, before any lane):** freeze the two
  currency names + which persists; freeze board data model (node graph with
  `next[]` edges, splits as choice nodes); back up slot_1.json; declare the
  seed-7 receipt retired.
- **Phase 1 — board core (1 overnight, the riskiest lane):** new
  `board_graph.gd` (winding track, splits, per-type spaces, larger estate
  layout reusing the Meshy swap-point catalogue) + sequential-turn rewrite of
  the round loop in a forked procession scene + Madden oscillating slider
  (new file replacing pawn_putt; bot release logic ported) + capsule pawns
  kept temporarily. Receipts (a)+(b) frozen same night.
- **Phase 2 — economy + cadence (1 overnight):** two-currency collapse
  (§3 order: helper consts → procession → estate_state → display strings),
  minigame-every-round via the existing contract (mock_game first, then real
  pool), item boxes/hazards/stores as space resolvers. Receipt (c).
- **Phase 3 — game shape (1 overnight):** estate.gd surgery — remove
  AUCTION/TILES/CHOOSING/RECKONING, wire hub → board night ×3 → interlude
  (will reading, wardrobe/store, grounds minigame slot) → totals + FINAL
  AUDIT; save schema v2 + migration. Receipt (d) + slot-3 soak against a
  copied real save.
- **Phase 4 — presentation (1-2 overnights, parallelizable after P1):**
  minifig pawns (KayKit rigs on the board, cosmetics attached), over-shoulder
  roll camera as a new named shot + re-derived anchors, run-alongside
  spectator troupe (AmbientLife pattern), minimap graph view, Executor line
  re-pools.
- **Phase 5 — online + broadcast re-cert (1 overnight):** extend
  `_net_state`/ceremony facts, host/guest byte-compare, MomentScribe beats,
  VERIFY-BOARD.md consolidation.

**Riskiest 3:**
1. **Ring → graph board topology** (P1) — `posmod`/`_ring_dist`/parametric
   `space_pos` assumptions are load-bearing in board_path, minimap, camera
   anchors (`reveal_shot` table), bot targeting, putt previews, tolls
   ("pass-through" logic), and `_net_state`. Underestimating this cascades
   into every later phase.
2. **estate.gd surgery** (P3) — 3,224 lines with the online mirror woven
   through every phase transition (`_net_set_ceremony` at each boundary);
   removing phases without breaking the guest restaging or the zombie-sweep
   invariants is delicate. Mitigation: delete phases only after P1/P2 board
   receipts are green, and keep the ceremony-fact vocabulary additive.
3. **Currency collapse across saves + receipts** (P2/P3) — the `legacy`
   persistence fold and the temptation to rename `currency_events` types.
   Wrong move re-freezes 14 minigames' receipts and risks the real slot_1
   wallet. Mitigation: display-layer rename only, additive save keys, 1:1
   legacy migration, slot-3 scratch testing per estate-save-safety.
