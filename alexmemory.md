# ALEX MEMORY — running log of things worth your review
*Claude maintains this. Newest entries at top of the log. The NEEDS YOU
section is always current. Skim top-down; nothing below the fold is urgent.*

---

## NEEDS YOU (current)

- **☀️☀️ MORNING MENU #2 — play this before the 5pm reset. Everything
  landed. THIRTEEN games, and the estate reaches across the wire.**
  1. **`build\illwill.exe`** — rebuilt from final master (all of tonight
     in it). Your session's headline acts:
     - **PAR v4: your characters PLAY GOLF now.** Walk to the ball,
       address, hold-release power, swing — through the frozen physics
       (byte-identical receipts). Your Smite skill-shot camera note
       applied and verified: whole lane readable while aiming. v3 drag
       putt survives as SETTINGS pref `par_drag_putt` if the swing
       isn't it. Bonus: the agent found + root-fixed a REAL v3 bug
       (black hole killing resting balls between rounds → zombie
       turns) that may explain your "sunk but went again."
     - **LAST WILL is the funeral procession race** — chapel → graveyard
       → THE CRYPT, 3 lives, die → draft a CURSE into a named stretch
       of road (author plaque, persists across races), out of lives →
       ghost. First to the crypt inherits.
     - **MASKED BALL** (theater act 3): find yourself among 20 identical
       dancers by feel, dance like furniture, one unmask mark. The
       feather-glint self-ID is the cleverest trick in the anthology.
     - **ONLINE PHASE 1 IS REAL**: title → HOST NIGHT gives a 6-char
       code; a friend on your LAN joins, claims a seat, walks YOUR
       grounds, readies across the wire. Internet friends need UDP 8910
       forwarded this phase (or Steam Remote Play meanwhile). Test solo
       with two instances: `--net=host` / `--net=join=127.0.0.1:8910`.
     - Andrew's list: ALL FIXED — mower 45s, throne 100s, auction
       dupes, QUIT TO TITLE (ESC), echo apron camping (THE RING
       DEMANDS), echo honors rounds, swap ramp unstick, greed tie-break
       (tied human now beats bot), caddies face the green, real keys in
       hint bars ("Space = SHOVE"), eyes-closed VOICE ROLL-CALL in both
       theater games, and every shove in the anthology has HIT-KIT
       weight + cooldown rings.
  2. **Your sign-off list** (balance, 2 min): throne overtime while
     contested · tilt overtime · gull assist royalty · DW house-awakens
     · understudy casting compression. Say yes/no per item.
  3. **Music** — six slots wait in assets/music/. Your ear, your call.
  4. **Tomorrow's plan is written**: docs/design/11-final-day-plan.md
     (online phase 2 fleet, AAA remainders, rituals, handoff). Fire the
     fighter prompt from projects/second-prompt-draft.md in a FRESH
     session.
  5. One wink: the Executor has a rare new greeting about a seagull.

- **📋 ANDREW'S PLAYTEST — full triage** (his email, disposed item by item):
  FIXED TONIGHT: mower 120s→45s; throne 150s→100s; auction duplicate
  options (sample w/o replacement); QUIT TO TITLE in the ESC overlay.
  AGENTS ON IT: echo off-map camping exploit (ring enforcement + KO) +
  echo ignoring the rounds setting; swap ramp stuck-trap; greed
  grab-starvation fairness; par caddies facing wrong + sunk-ball
  "go again" investigation; eyes-closed flow in Séance/Understudy
  (his "how da hell do people know who should look" is RIGHT — fix is
  an audio roll-call: each seat learns its pitch eyes-open, then gets
  a triple-tick summons; gaps stretched).
  ALREADY COOKING WHEN HE WROTE: "actions feel loose/sloppy" = the HIT
  KIT waves (greed/throne/orbital merged; DW/LW in flight).
  TOMORROW (mechanical sweep): hint bars showing REAL keys ("Space =
  SHOVE" not "A = SHOVE") via describe_binding — his best UX note;
  plus a first-night HOUSE RULES card (currencies/bids/trail tutorial).
  THE BIG ONE (your call, endorsed): LAST WILL rebuilt as a Fall Guys
  obstacle gauntlet — **DELIVERED 7/06** (see today's LOG entry: procession
  race, curse-drafting intact, receipts green; needs its HOWTO card line
  merged into estate.gd). "YO IN TILT I CAN SHIT ON PEOPLE. Beautiful."
  — carving that into the graffiti wall someday.

- **🏰 THE FLOW IS THE GAME NOW (your big playtest note, built).**
  PLAY on the title = the full game instantly: nights of (auction →
  minigame + quick podium → reckoning) — no settings screen between —
  and at each night's end: NIGHT PODIUM → READING OF THE WILL → THE
  PARADE (once per night, by night totals) → **FREE ROAM** (the estate
  rests: walk the grounds by default, buy trap tiles, wardrobe/theater
  walk-ups, CONTINUE when ready). The trail now PERSISTS across nights —
  the run ends only when someone reaches the manor: podium by trail
  standing, "THE ESTATE HAS AN HEIR", Executor's condolences to everyone
  else. **SAVE SLOTS**: NEW GAME opens THE THREE ESTATES (each slot a
  whole estate universe; two-click wipe protection); your old save
  migrated to Slot 1; quitting mid-run resumes at the last between-nights
  rest. Side bets moved into the auction; night length (3 default),
  rounds per minigame, and theater-games-in-rotation live in SETTINGS →
  GAME. Also queued from your notes: game-feel research done (HIT KIT +
  COOLDOWN RING specs — greed/throne implementing now, DW/LW next),
  dead-state controls fix (left=move right=aim + on-screen instructions)
  and Séance pull-arrows both in flight.

- **🎟️ PLAYTEST BUILD READY — `build\illwill.exe` (rebuilt tonight).**
  Your three fixes, done and verified: (1) **TITLE SCREEN** — hatted
  cast backdrop, big PLAY → seat setup → the full night; SETTINGS +
  MINIGAMES below; swap the art anytime at `assets/ui/title_bg.png`.
  (2) **Moonwalking fixed** — echo/tilt/greed applied a 180° model-yaw
  offset; models now face where they walk (verified in live exhibition
  shots; gameplay yaw untouched). (3) **Model/color audit**: canonical
  on this build — RED=axe guy, BLUE=knight, GOLD=wizard, MINT=rogue in
  every game I probed and every screenshot; the one real scramble was
  Understudy's standalone fallback order (fixed). If RED goes wizard
  again tonight, tell me WHICH GAME. Bonus catch: the lobby ILL WILL
  banner was leaking into exhibition matches — hidden on game launch.

- **☀️ MORNING MENU — the overnight run is COMPLETE. Start here.**
  1. **Double-click `build\illwill.exe`** — the whole game, packed from
     final master, verified booting (12 games, wardrobe, your migrated
     history: the Executor greeted your ledger by name in my test).
  2. **Playtest priorities**: a full night (the Reading now opens with
     NEMESIS when earned — final soak produced "MINT, NEMESIS OF BLUE —
     came for them in 3 different games tonight"); THE SÉANCE and THE
     UNDERSTUDY at the theater (selector, "· at the theater ·" tags —
     is the Séance chant-tap load right with a pad in hand?); Par's new
     KILLCAM ("BLUE'S THE CRUSHER — SIGNED WORK" replay at the
     gravestone, click/space skips, never fires in chaos; determinism
     receipts byte-identical). Your Theater-photobomb bug: fixed and
     screenshot-verified inside a real game.
  3. **Music, whenever you're ready**: drop .ogg files at assets/music/
     (lobby/grounds/auction/ceremony/game_light/game_tense.ogg). Nothing
     else needed.
  4. **One doc worth your read**: the Par v4 EMBODIED GOLF spec
     (docs/superpowers/specs/2026-07-06-par-v4-embodied-golf-design.md)
     — 5 open questions, each with my recommended default; say "go"
     and the wave launches.
  5. Small watch-items: monument lawn now shows the 8 newest stones
     (older counted on a marker); Executor/Theater prop placement could
     use your eye on the grounds; Séance/Understudy card verbs came
     from their hint bars — correct me if they read wrong in play.

- **🌙 OVERNIGHT RUN — progress ledger (updating as the night goes).**
  Everything below is merged to master and smoke-tested unless noted:
  - **ILL WILL is real**: window title, lobby title card, exe metadata.
    Your saves MIGRATED automatically (the rename moved Godot's user://
    dir — a Migrate autoload copies estate history/seats/cosmetics over;
    nothing lost, verified).
  - **THE WARDROBE is open** (lobby button): LEGACY currency = your
    night points paid at each dawn (+5 champion; old saves grandfathered
    15/night). Prices 10-30; buy/wear/doff; walkers and the podium wear
    your hats. E2E-tested.
  - **How-to-Play cards**: every selector game now opens a card — goal,
    PLAY / PRACTICE / BACK, and CONTROLS TONIGHT rendered live from your
    actual bindings (your keybind idea, made structural).
  - **Press-A-to-join**: an unclaimed gamepad presses A in the lobby and
    takes the first BOT seat. Seat setup persists.
  - **THE EXECUTOR is on the grounds** (Meshy butler by the gates) and
    SPEAKS — Saki register throughout: ledger-aware lobby greeting
    ("We remembered BLUE as THE HOARDER, and see no reason to revise."),
    will-reading header ("...finds it, on the whole, actionable.").
  - **THE THEATER stands** on the right flank (red curtains, gold trim).
    THE SÉANCE (research pick #1: co-op spirit-board with a paid
    saboteur, Executor as medium) is being built by a Fable agent NOW.
    Research doc: docs/design/06-social-deduction-research.md — worth
    your read; it argues 4-player bluff-and-vote needed re-engineering
    and pitched three formats (Séance / Understudy / Masked Ball).
  - **Kill attribution fleet: ALL FOUR MERGED.** Every game reports
    kill_events; the Reading of the Will can now open with **NEMESIS OF
    <name> — hunted them down N times tonight**. (Director's ruling:
    Swap Meet's position-swaps are theft, not kills — filtered.)
  - **Style unification: echo/tilt/dead_weight now live at the same
    party** — echo's neon ghosts over a warm wooden well (stunning:
    docs/verify/shots/style_echo_r5_neon_on_warm.png), tilt at golden
    hour over an evening sea, dead_weight in a warm room with amber
    hazard trim. Par got scoreboard badges + a proper "CHAOS — EVERYONE
    AT ONCE" banner.
  - **Music scaffold ready**: drop .ogg files at assets/music/
    (lobby/grounds/auction/ceremony/game_light/game_tense.ogg) and the
    estate plays them with crossfades — zero code needed from you.
  - Cache: you were right — Max plans get the 1h TTL; a 48-min
    self-tick keeps my cache warm and drives the overnight loop.

- **🕯️ THE SÉANCE IS MERGED (the Theater's first social deduction,
  research pitch #1 — and it is gorgeous).** Four
  sitters share one planchette to spell a word only the Executor knows;
  one of them was paid 2 grudge to kill the sitting without getting
  caught. Eyes-closed casting, rhythm-chant focus meter (tealights snuff
  as it dies), anonymous B-surges, stick+A portrait vote, public unmask
  every time. Balance verified across 8 bot seeds: 4 fail / 4 success
  WITH the saboteur, 4/4 clean success when the saboteur bot plays
  honest — the paid hand IS the difference. Caught = one kill_event for
  NEMESIS (cause "seance"). Worth your playtest eyes: is the chant-tap
  load right with a real pad in hand? Shots:
  `docs/verify/shots/seance_*.png`; evidence:
  `docs/verify/seance-VERIFY.md`. Live in the selector under
  "· at the theater ·" alongside THE UNDERSTUDY (also merged — the
  eyes-down casting and NAME THE PRETENDER vote both passed review;
  its distributed scoring provably resolves 1-1-1-1 deadlocks).
  Sample clue from the Séance board: "Five letters. The estate's most
  permanent guest room." The Executor, at the verdict: "The word, for
  the record, was GRAVE."
- **⚙️ SETTINGS V2 SHIPPED (menus first-class, per your call).** ESC now
  opens a tabbed overlay anywhere: SEATS / CONTROLS / AUDIO / VIDEO /
  ACCESS. CONTROLS = full key remapping per device (WASD half, arrows
  half, KB+MOUSE movement) with a conflict-swap rule so nothing can go
  unbound, plus gamepad A/B swap. Your keybinds+onboarding instinct is
  now architecture: `PlayerInput.describe_binding()` means the coming
  How-to-Play cards render whatever is ACTUALLY bound — they can't lie.
  AUDIO tab has Master/Music/SFX sliders; **the Music bus exists and is
  wired, so tomorrow's soundtrack drops straight in.** 16-check keybind
  test PASS; tab screenshots reviewed. In flight: never-color-alone
  badge agent (shapes ● ▲ ■ ◆ beside every name in all 9 contract-game
  HUDs). Next: Ready Room press-A-to-join + How-to-Play cards.
- **📜 YOUR THREE IDEAS ARE ON THE BOOKS** (docs/design/
  05-director-notes-2026-07-05.md): (1) the host is THE EXECUTOR — a
  will needs one; Meshy butler who reads the Will, calls auctions, and
  greets you by your ledger history ("welcome back, THE SNAKE"); (2) the
  Theater — stage venue on the grounds for short couch-native social
  games, needs a brainstorm with you on which 2-3 formats fit 4 seats +
  two buttons; (3) Par v4 EMBODIED GOLF (characters walk and swing,
  live griefing in chaos) — approved direction, sequenced AFTER v3
  lands and you playtest it, so the waves don't collide. Meshy credits
  noted — plenty for the butler, the stage, and bigger courses.

- **🕯️ NEW CEREMONY: THE READING OF THE WILL.** After the podium, the
  night's superlatives are read like an inheritance — THE WORKHORSE (won
  the most games, still lost the night), THE ARCHITECT (most royalty
  kills), THE SNAKE (bets cashed against friends), THE LANDLORD (tollgate
  income), THE DOORMAT ("finished dead last 2 times. forgive them."),
  THE HOARDER (most spite amassed). Awards persist to the estate ledger
  and the top one is carved into the graffiti wall — the estate now tells
  the night's story back. Also fixed on the way: the night used to
  DEAD-END on the winner banner; "DAWN — BACK TO THE GATES" now returns
  you to the lobby. Screenshot: `verify_out/will/snap_will_reading_7002.png`.
- **🎩 COSMETICS ARE MERGED (relaunch to get them).** 8 Meshy hats fitted
  to all four characters — viking helm, tophat+monocle, halo, chef hat,
  party cone, jester cap, propeller beanie, flower crown. Stock headwear
  (Mage's wizard hat etc.) hides convincingly while a hat is worn; halo
  deliberately floats OVER the wizard hat. 16-check headless test PASS
  post-merge. Look at `docs/verify/shots/cosmetics_combo.png` — the
  monocle chain alone justifies the API bill. Store UI at the estate
  stall (prices in royalties/grudge, agent suggested a menu topping out
  at halo 300 — "earned innocence") is my next own-hands pass.
- **HANDOFF COMPLETE**: I'm the new director post-compaction; the thread
  held. Still in flight: Par v3 agent (8 new trap types, bigger courses,
  the Gauntlet, TRUE simultaneous chaos, OOB adventure gutters). Review
  culture unchanged — its screenshots get read before any merge.

- **🏰 THE ESTATE IS NOW THE MAIN MENU (relaunch again!).** Boot lands on
  the grounds under a "THE UN-PARTY" title card: seat cards (HUMAN/BOT +
  device, persisted), night length, START THE NIGHT, and a MINIGAMES(10)
  selector that launches exhibition matches (no stakes, returns to the
  selector). Screenshot: `verify_out/lobby/shot_0150.png`. Anthology title
  "THE UN-PARTY" is my placeholder — rename freely. Coming in later
  passes: Ready-Room press-A-to-join seats, How-to-Play cards + practice
  doors, full ESC settings tabs (research MUST list).
- **✅ UNBLOCKED — CONTINUE YOUR TEN-GAME NIGHT (relaunch first).** All
  three playtest issues fixed & committed: (1) Reckoning continue button
  was pushed off-screen by long tickers — panel now grows UPWARD + ticker
  capped at 8 lines; (2) Par back to 1 trap per round per your correction
  (more TYPES coming instead — agent building 8 new traps + bigger courses
  + a new large "Gauntlet" course + TRUE simultaneous chaos + OOB
  adventure gutters); (3) ramp-stranded balls now return to their last
  on-green lie ("X WENT EXPLORING — RETURNED").
- **Cosmetics: your wishlist is feasible and in flight** — rather than
  risky Meshy-rigged characters, we get 90% of the fantasy cheaply: Meshy
  HATS/ACCESSORIES on the existing KayKit rigs' head/handslot attachment
  bones (8 being generated + fitted now by a Fable agent). Store UI at the
  estate stall (spend royalties/grudge) is my pass after the menu work.
  Meshy-rigged custom characters stay on the later-experiments list.
- **My next own-hands pass while you play: estate-as-main-menu** (boot
  into the estate, Ready Room join seats, UFO-50-style 10-game selector
  panel + practice, ESC settings tabs per the research MUST list).

- **Menu research is IN** (`docs/design/04-menu-ux-research-digest.md`).
  Headlines: diegetic entry points + flat ESC panels for depth (no shipped
  hub game makes settings diegetic); DRG's walk-OR-hotkey dual pattern;
  UFO 50's one-screen grid + How-to-Play card is the selector gold
  standard; press-A-to-join Ready Room seats with HUMAN/BOT/EMPTY
  tri-state; and one CRITICAL accessibility note — our player identity is
  pure color, so we need never-color-alone icons across all HUDs. Full
  design doc for estate-as-main-menu comes to you WITH your playtest notes
  folded in.
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

### 2026-07-06 — ONLINE PHASE 1 IS REAL: two copies of ILL WILL played one night together
The spine from doc 10 is built and proven on this machine: **HOST NIGHT /
JOIN NIGHT on the title**, a 6-char invite code (`80CMWE` = your LAN
IP+port; loopback/LAN/port-forward this phase, Steam codes phase 3), remote
guests claim seats (`BLUE JOINS FROM AFAR`), their walkers stroll YOUR
grounds on relayed 30 Hz input through a new `_remote` seam in PlayerInput
(additive — couch untouched, all old CLI hooks green), READY + GET READY
gate work over the wire, disconnect flips the seat to BOT on the Executor
register ("THE WIRE TO BLUE WENT DEAD…"). Client sees a live lobby mirror +
walkers, and during games the honest spectate card + ladder (full game
mirrors = phase 2). **Proof, not vibes:** same seed + same input tape via
couch-injection vs the real network produced IDENTICAL night results — the
transport provably doesn't touch the sim; 27/27 mirror hashes matched;
evidence + screenshots in `docs/verify/online-phase1-VERIFY.md` /
`online_host_*.png` / `online_client_*.png`. **Bonus: the rig caught three
latent couch bugs** (READY chip double-toggle at high fps; panel rebuilds
silently breaking every chip/label update via node auto-rename; the START
waiting-list never updating live) — all fixed at the root. NEEDS YOU:
(1) to host real friends before Steam lands, forward UDP 8910 (or just use
Remote Play Together meanwhile); (2) the phase-3 Steam decision (GodotSteam
SteamMultiplayerPeer drops in behind NetSession — one file). Branch:
worktree-agent-aba80dc71b36f7a58, 2 commits.

### 2026-07-06 — ONLINE-FIRST ARCHITECTURE DECIDED (docs only, build day is tomorrow)
Your call ("online is 90% of 2026 play") is now a blueprint:
`docs/design/10-online-first-architecture.md`. The decision: **host runs the
ENTIRE sim exactly as couch; remote clients stream inputs into a new
`_remote` seam inside PlayerInput** (the same injection pattern your
--aimprobe hooks already prove) — zero minigame code changes for input; aim
relays as vectors, never raw mice. Clients mirror the match (same scene +
seed = free static worlds; host replicates actors/facts back). Lockstep is
buried with citations (Jolt isn't cross-machine deterministic); rollback
rejected (3-6 months for 2 games' feel). Audit found ONE real violator: PAR's
mouse controllers — so phase 1 = estate lobby + SÉANCE online (100%
PlayerInput, private role flashes get BETTER online), phase 2 = fleet fans
out per-game mirrors, phase 3 = par refactor + rejoin + Steam sockets. Steam
Remote Play Together is the zero-code fallback that works TONIGHT (4 pads,
and par's shared mouse is already RPT-shaped). Biggest risk named: the
per-game render mirror, not input. Verification runs two instances on one
machine + your existing TALLY harnesses as the transport regression suite.

### 2026-07-06 — LAST WILL v2: THE FUNERAL PROCESSION RACE (your call, built)
The rebuild you ordered after two playtests agreed it was too sumo-like.
Same module id/scene/contract, whole new body: a linear chapel -> winding
graveyard -> THE CRYPT gauntlet over the dusk void. 3 lives; every death
still buys the 6-second world-freeze WILL DRAFT (portrait + parchment cards
preserved) — but now the card is ONE CURSE written into a named stretch of
the route (SUMMON THE SCYTHE / GREASE THE FLAGSTONES / A GUST CORRIDOR /
RAISE THE DEAD across nine stretches: Lychgate Road ... the Crypt Steps).
Curses install in your color WITH A NAME PLAQUE, persist across races
(Par-style accretion; full slate = displace the oldest), and pay +2
royalties on kills (kill_events cause = curse slug). Out of lives -> ghost
pew that drifts alongside the race, same gust kit, +1 per gust kill. First
to the crypt inherits; Executor: "The first to the crypt inherits. The
estate finds this poetic."
Proofs: seeds 1/2/3 tally byte-identical (twice each), all nine 4-bot
races reach the crypt (41-55s race clock; wills 10-22 per match), squish
self-test PASS, contract validation 0 problems, 2P clean. Balance war
story + 7 eye-verified screens in docs/verify/lastwill-v2-VERIFY.md and
minigames/last_will/shots/. HOWTO card text (estate.gd is fenced from me)
needs your/the director's one-line merge — suggested lines are in my
handoff report. (Director: wired post-merge.)

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

### 2026-07-05 — THE KILLCAM shipped (commit ef23010)
When a ball dies to a trap in a NORMAL round, the table freezes ~1.6s and the
victim's final ~2s replays from a low camera near the killing trap: author-
colored vignette border + "AUTHOR'S TRAP — SIGNED WORK" banner (the sabotage-
authorship flex). Self-kills: "SELF-INFLICTED. THE ESTATE APPLAUDS." (no border,
Executor's register). CHAOS never pauses — credit banner only. Skippable (click/
space), bots auto-skip at 0.4s so soaks stay fast; one killcam per stroke.
- How it's cheap + safe: each ball keeps a per-tick global_transform ring buffer
  (~2.6s); replay is transform playback on a throwaway clone — real balls/traps/
  round state untouched. Windowed play holds the turn with get_tree().paused,
  which inserts ZERO physics ticks, so moving-trap phase (and thus outcomes) are
  identical. Headless/autoplay/--nokillcam make it a pure timeline no-op.
- Determinism proven both ways: same seed, killcam x2 == --nokillcam, 11/11
  gameplay-receipt lines byte-identical — headless AND windowed (with 2 real
  pauses executed). New flags: --nokillcam; verify-only --parquit, --killcamtest.
- Evidence: docs/verify/killcam-VERIFY.md + shots/killcam_{signed,self,chaos}.png.

### 2026-07-05 — Visual polish pass: full audit + 8 Meshy props (commits 3c547ec, 71cf56e)
ART DIRECTOR SWEEP. Phase 1: screenshotted the entire game (estate title/
grounds/auction/will-reading, all 11 standalone bot demos, Par + forced-trap
runs) and cataloged every primitive-mesh visual: 31 findings — 8 JARRING,
12 NOTICEABLE, 11 FINE-AS-IS (charming primitives like trail stones, throne
"candle" pillars, Understudy's box theater were deliberately left alone).
Ranked doc: docs/design/07-visual-polish-audit.md.

Phase 2 (8 Meshy generations, the cap; 0 failures): the whole DEAD WEIGHT
furniture set is now real furniture (wardrobe + table_lamp GLBs finally used,
new crate + red-cushion armchair; possession glow/dent rewired to GLB
materials), Greed vaults share the crate, Echo Chamber got broken marble
columns, Last Will's pendulum is a dark scythe on a shaft (was boxes+slats),
Par's crusher is an iron press head stretched to the EXACT hammer collider,
spinner is a wooden sweeper cross, fan is a caged pedestal fan, and the estate
market stall is a striped-canopy vendor stall (estate.tscn only — estate.gd
untouched per fence).

Every swap visual-only, proven vs git-stash baselines: greed intercept 0.80
PASS byte-identical, spinner forced-run log byte-identical, dwbalance 65.0%
(matches documented table; single dw runs proven non-deterministic even on
unchanged code), will tally identical mod ±0.1s stamps, estate bot night still
reaches THE READING OF THE WILL. Evidence: docs/verify/visual-polish-VERIFY.md
+ 31 polish_*.png shots.

BACKLOGGED (top items, ranked in the audit doc): monument obelisks + picnic
toys (both estate.gd-fenced — the red hex slabs on the lawn are now the
loudest placeholder left), shared gravestone prop (scenes/ root, outside my
fence; accretes all night in Par), Last Will lanterns -> stone_lantern.glb
(free swap, check perf with ~16 instances), magnet post, spikes, throne wall
dressing, crown. Saves: estate_save.json etc. backed up before runs and
restored after (hash-verified).

## 2026-07-06 — ORBITAL THREAT LADDER (AAA-gap #7, presentation only)

Layered a speed-tier danger ladder over Orbital Dodgeball, minigames/orbital/
only. Four pieces, all keyed to a per-ball heat factor hf = clamp((speed-4)/8):
(1) threat AUDIO — every deadly ball near a living player fires a pitched tone
from the existing bank asset (impactPlate_light_000), pitch 0.85->2.15 and
cadence 0.26s->0.07s by hf: a low hum tightening into a high whistle; (2) a
subtle red DANGER VIGNETTE that ramps with proximity x heat when a top-tier ball
passes a living player (capped 0.5 edge alpha); (3) ball/trail HEAT — emission
1x->2.7x, hue bled toward molten orange then hot-white, trail thickens, owner
hue kept readable at low/mid tiers; (4) speed-scaled KILL FREEZE as a VISUAL
punch (camera FOV punch-in + shake, faster ball = deeper+shorter).

Determinism was the whole game. The existing slow-mo scales the SIM timestep
(sdt = delta*0.3), so it's baked into KILL_EVENTS — touching its depth/duration
would move ball ages, spawns and time_left. So I left the sim slow-mo exactly
as-is and realised "speed-scaled freeze" purely as a _process visual layer. All
threat code runs in _process / the ball's _process / _do_kill's presentation
tail — no sim RNG, no sim writes (OrbBall._threat_phase is visual-only). Proof:
KILL_EVENTS byte-for-byte identical vs pre-change baseline across seeds 1/2/7/11
(diff = empty); seed-7 max_flight_age 46.4s unchanged; no script errors on a
full match with all FX active.

Reduced motion = the HIT KIT pattern: reads PartySetup.pref("screen_shake").
Off -> shake + FOV punch + vignette suppressed/softened (vignette 45%); audio +
heat stay on (not motion). Orbital previously shook the camera unconditionally;
now it honours the pref. Verified by staging the same threat moment with
screen_shake=false — vignette visibly dimmer, heat identical. prefs.json
(user://, was {}) backed up + restored.

New: --orbtest=threat staging mode (isolated test path) + windowed self-capture.
Evidence: docs/verify/orbital-threat-VERIFY.md, verify_out/orbital_threat_b.png
(top-tier ball + strong vignette) and orbital_threat_reducedmotion_b.png.

---

## Eyes-closed secret delivery — the VOICE SUMMONS (both theater games)

First outside tester (Andrew, round 1) on THE SÉANCE + THE UNDERSTUDY casting:
"Eyes closed section needs longer in betweens. Also how da hell if everyone eyes
are closed are people supposed to know who should look first." He's right — a
visual "LOOK NOW" is useless to a blind table. Fixed BOTH games, presentation/
timing only (word selection, roles, scoring, votes, bots all unchanged).

The fix reuses the seat-distinct chant pitch as one HOUSE LANGUAGE across both
games: RED 0.90 / BLUE 1.00 / GOLD 1.12 / MINT 1.26.
1. AUDIO SUMMONS — when it's a seat's turn, its pitch ticks THREE times (0.35s
   apart, -4 dB, louder than the -12 dB chant) BEFORE any private card, then a
   4th confirmation tick as the reveal turns up. No eyes needed to know it's you.
2. VOICE ROLL-CALL — during the casting intro, eyes OPEN, ~9s: "Your colour has
   a voice… RED, this one is yours" -> RED tick·tick·tick -> BLUE -> GOLD -> MINT,
   so everyone learns their tone before they ever close their eyes.
3. LONGER IN-BETWEENS — >=2.0s silence between one seat's eyes-down and the next
   summons; reveal holds +50% (seance 2.6->3.9s). Nothing rushes.
4. Reveal cards restated — seat name HUGE + standing "everyone else — eyes down ·
   listen for your voice".

Determinism was the constraint. Seance CAST draws no RNG (word+charlatan drawn in
begin() before CAST), so a longer/louder CAST can't move the sim. Understudy got
the same tiny pitched pool, but its roll-call (Cast.ROLLCALL) and inter-seat gap
(Cast.GAP) run ONLY when not _tally — headless takes the original straight-to-
_present_call path. All audio is _tally-guarded. Proof: tally sim lines
BYTE-IDENTICAL vs pre-change baseline — seance seed 5 (20 lines), understudy
seeds 1/2/3 (67 lines each), diff empty. Windowed logs show SEANCE_SUMMONS /
US_SUMMONS holding each seat's pitch, 3 per colour in the roll-call.

Evidence: docs/verify/eyesclosed-VERIFY.md; docs/verify/shots/seance_eyes_rollcall.png,
seance_eyes_summons.png, us_eyes_rollcall.png, us_eyes_summons.png. No user://
writes (bot/tally runs only).

## 2026-07-06 — MASKED BALL ships (Theater act #3, research pitch #3)

The one with no secret to deliver: 20 identical masked dancers (one Rogue
model, ivory half-mask on the head bone), 4 of them are the players, nobody
told which. Stick=drift at crowd speed (pace can never be the tell), FEATHER
the stick = your mask glints privately (NPC masks glint on seeded timers, so
the signal is the correlation with your own hidden hands — zero on-screen
secrets), A=curtsy (+2 in the throne circle, 3 max, announced UNNAMED — the
room only hears "somebody bowed for money"), B=UNMASK, one mark all waltz.
Human: +6, +2 royalty, victim ghosts out (kill_event cause "unmasked").
Furniture: −3, grudge, and your dancer FLASHES with your badge — the position
leak as a self-inflicted reveal moment. PlayerBadge exception is deliberate
and documented: no identity on any body mid-round; badges + seat pitches
(0.90/1.00/1.12/1.26) exist only at reveal moments.

Bots read only public evidence (unnamed pip coincidences split across
everyone mid-bow, waste-flashes, witnessed lunges as LEADS with a 2-5s shock
pause, stillness >4s) and fire only when the grab lands on their target —
never through a bystander. 18% seeded misfires supply organic wastes
(seed 12: BLUE flashes at t=125, then eats the revenge mark). Seeds 1-12:
0-3 kills per ball, all in the waltz's back half; peaceful balls exist.
Tally byte-identical across repeat runs, seeds 1/2/3.

Evidence: docs/verify/maskedball-VERIFY.md + docs/verify/shots/maskedball_*.png
(crowd / furniture flash / GOLD WAS HUMAN / last dance / ledger). Director
wiring suggestions (MODULES + HOWTO lines) at the bottom of the VERIFY doc.
Note: party_setup.json in user:// changed mid-session from a SIBLING agent's
backup/restore cycle, not this lane — my runs write nothing to user://
(verified against a pre-run snapshot; prefs/cosmetics/estate_save untouched).

## 2026-07-06 — PAR v4 WAVE 1: EMBODIED GOLF (agent worktree)

Par's characters stopped caddying and started playing. On your turn your KayKit
character walks to the ball (Walking_A, 3.0 m/s, 1.4s cap then teleport-dolly),
takes the 2H_Melee_Idle address stance, you aim + hold-release a POWER meter
(1.2->13 m/s over 1.1s ping-pong), and the 2H_Melee_Attack_Slice swing fires
the EXACT same debug_putt(power, angle) at the 0.18s contact frame. Devices:
-3 cursor+LMB, -4 get_aim_dir+A/LMB, pads/kb-halves stick heading+A. Bots use
their same seeded numbers, gated on AVATAR_ARRIVED, fired through the swing.
v3 drag putt survives behind PartySetup pref "par_drag_putt" (and --v3putt
restores the whole v3 interface). BUILD half untouched. Chaos = wave-1 rule:
still turn-based v3 chaos (embodied swings, diorama camera), griefing is wave 2.

YOUR CAMERA NOTE LANDED: shot camera is now a SMITE skill-shot frame — 2m back,
11.5m up (~53 deg), looking 6m down the aim line; from the fairway tee the
whole lane + traps + cup + aim dots read in one glance, golfer bottom-edge.
Contact blends 0.5s back to the diorama for the roll.

THE FROZEN-PHYSICS RECEIPT (the make-or-break): --traceall logs every ball
every physics tick at 0.1mm. v3-direct vs v4-swing runs, same seed + autoplay:
byte-identical ball paths on empty courses (seeds 11, 23). With TRAPS placed,
free-running diverges ONLY because powered traps are met at different absolute
ticks — proven benign by firing the v3 putts at the v4 swing's exact ticks
(--physputt): byte-identical through the whole trap field. Interface clean.

FOUND + FIXED a real pre-existing bug your playtests could have hit: a black
hole camping the tees kills RESTING balls during the next round's BUILD phase,
while the round manager is between rounds -> the death is never booked -> in
v4 that deadlocked the match (dogleg seed 6, deterministic), in v3 it silently
wasted up to 6 fake bot strokes per zombie. Now: dead/sunk balls are booked
resolved at putt-phase start, and the bot gate falls through to the v3 path if
the avatar can't address — turns always advance. Dogleg seed 6 now completes.

Receipts: full parbots matches to MATCH_OVER on all four courses (fairway s5+s9,
dogleg/green/gauntlet s6), 0 script errors; walk->swing gate 0 violations over
62 swings; killcam plays+auto-skips in windowed bot matches; chaos concurrency
peaks >=2 movers. docs/verify/par-v4-wave1-VERIFY.md has all commands.

NEEDS YOUR HANDS (playtest asks, in order):
1. Feel of hold-release power vs the old drag (pref "par_drag_putt" flips back).
2. Skill-shot camera pitch — I tuned to ~53deg for full-lane read; SMITE-y enough?
3. Aiming with mouse cursor from the high camera (and pad stick if you dig one out).
KNOWN LIMIT (flagging for wave 2): bot MATCH OUTCOMES are not run-to-run
reproducible (pre-existing v3 — bot think timers are wall-clock; tick-phased
traps amplify). The physics receipts sidestep it; wave 2's "reproducible chaos"
exit should move bot cadence to physics ticks.

---

SFX BUTTON-CLICK "POP" (playtest r2: "pop sound when I click buttons... wardrobe
and join night... sound isnt fully rendering") — ROOT-CAUSED + FIXED.

Not voice-stealing and not "generated samples" (Sfx loads Kenney .ogg, no synth).
The real cause: several UI .ogg samples start/end at a NON-ZERO amplitude, which is
a step discontinuity = a click by definition. Measured worst offenders: click_001
(played on every "card") starts at 6.1% of peak; click_003 is a 7ms tick that ends
at 3.5% of peak with a 2% DC offset, cut off mid-ring -> literally "isn't fully
rendering." bong_001 ("grudge") ends at 1.1%.

Fix (presentation only, Sfx.play() API unchanged): baked declicked 16-bit PCM WAVs
for the 7 one-shot UI samples (DC removal + ~2ms raised-cosine fade in/out) so each
starts AND ends at exactly 0; Sfx prefers the .wav, everything else still .ogg.
Deliberately did NOT re-encode as ogg (lossy Vorbis left a 13.5% tail on the 12ms
click_002 = a new pop) and did NOT touch looped samples (mower engine, orbital tone).
Also made the pool prefer a free voice before stealing the oldest.

Receipts (docs/verify/sfx-pop-VERIFY.md): in-engine probe shows all 7 imported WAVs
first==last==0, peak preserved; headless boot VERIFY_DONE 0 errors; windowed
--wardrobetest clean. I can't hear it — verified by waveform math. Join-night shares
the same card/confirm path as wardrobe, so it's covered.

================================================================
2026-07-07 — BALANCE FIVE: your signed-off changes are in (one commit per game)
================================================================
Doc 09's five parked BALANCE items, all signed by you, now live. Full receipts
in docs/verify/balance-five-VERIFY.md; the short version + my judgment calls:

1. THRONE — THE COURT WILL NOT ADJOURN (§9.1). Contested at 0:00 (vacant
   seat / drained grip / challenger within 2.5m of the dais) = no
   adjournment: play on until a clean 3s uncontested reign, cap +30s, then
   the current leader wins. Crisis double-pay persists through OT.
   Receipts: an uncontested horn reproduces the old outcome exactly (seed 3:
   36.8% max share both sides); seed 1 entered OT and EVENED the shares
   (31.4% -> 25.9% max). 55% fairness cap passes everywhere. Judgment: with
   four bots the horn instant is usually a kill instant, so the flash banner
   kept losing its slot to "X DETHRONES Y" — the persistent crisis line now
   carries "THE COURT WILL NOT ADJOURN — THRONE PAYS DOUBLE" for the whole
   of overtime, and the timer runs hot-red "OT n". Filmed, read by eye.

2. TILT — OVERTIME INSTEAD OF SPLIT (§3.3). Tie at the horn = "THE ESTATE
   SPLITS NOTHING / OVERTIME": 20s on a sudden-death platter at 1.5x tilt.
   Judgment: 1.5x multiplies the sudden-death gain already in force (1.6 x
   1.5 = 2.40x) — meaner than doc 09's 2.0x sketch, same spirit; the platter
   itself breaks the tie. The old split only fires if the sea refuses a
   verdict for 20 MORE seconds ("THE SEA REFUSES A VERDICT"). Receipt:
   30s-round probe, 3 seeds — HEAD split the pot in 7 of 9 rounds; the
   branch produced 9/9 true winners, 0 splits, every OT resolved in
   0.1-9.6s. Shipping 60s soaks: fall sequences frame-identical.

3. TILT — GULL ASSIST ROYALTY (§3.4). A gull KO (fall within 2s of a guano
   slip) pays +1 royalty to whoever shoved the victim within 3s: cause
   "gull_assist", killer = shover, banner "AIR RAID! X'S GULL SINKS Y — Z
   COLLECTS". Judgment: doc 09's first draft paid the GULL; the signed
   wording pays the SHOVER — I built the signed version (the gull keeps its
   direct-hit stats/highlights; a pure gull KO with no recent shove stays
   uncredited ring_out as before). New deterministic self-test
   --tilttest=gull PASSES; seed 13 even threw an organic case: RED softened
   MINT 2.7s before RED's own gull finished the job — outside the old 1.5s
   royalty window, inside the new 3s assist window.

4. DEAD WEIGHT — THE HOUSE AWAKENS (§8.3). Final 30s of every round: ghost
   possess-cooldowns halve (4.0 -> 2.0s; running cooldowns halved on the
   spot), the room dims to candlelight (four guttering candles), banner
   "THE HOUSE AWAKENS". All fx behind fx_on(). Judgment: the 22s balance-sim
   rounds map the window to the same FRACTION of the cap (60% = live T-30)
   so --dwbalance measures the same regime. Receipts: living-win band
   IDENTICAL before/after on all 3 seeds (65/60/75%) while DW_GHOST_CD
   lines prove the halved cooldown reaches ghost hands 8-12x per sim.
   --dwawaken=S (verify-only) films the moment early.

5. UNDERSTUDY — CASTING COMPRESSION (§12.3). Roll-call teaches the colours
   ONCE (Act 1); from Act 2 the eyes-down silences tighten 2.0s -> 1.2s.
   The voice-summons language (three pitched ticks + the flip tick) is
   untouched, every round. Wall receipts (windowed, realtime, same seeded
   bot beats): Act-2 casting span 29.0s -> 16.8s (-12.1s, predicted 12.0).
   Across a 4-round night ~37s of pure ceremony silence removed. --ustally
   byte-identical across 3 seeds.

Full 4-bot matches to finished() for all four games (logs in the verify
doc). One ops incident, documented there: a "stopped" background script
survived its kill on Windows and re-ran harnesses over my baseline logs —
baselines re-captured via HEAD-swapped scripts, restoration byte-verified.
Lesson learned: killing the shell does not kill its godot children; give
every phase its own output dir.

## 2026-07-06 — PAR ROUND 2: tester's three bugs, three root causes (agent worktree)

Outside tester (round 2) + your crusher report. Full story + receipts in
docs/verify/par-round2-VERIFY.md. Physics untouched.

1. TEE-OFF GLARE. Not a lighting regression — the new SMITE shot cam fills the
frame wall-to-wall with sunlit green + white wall caps. Fix scoped where the
problem is: SHOT mode tweens camera exposure to 0.58 over the existing blend,
DIORAMA stays at 1.0 (verified byte-identical build-view pixels). Reads
overcast-bright now; cyan pads / pink rings still pop. If you want it brighter
or dimmer it is ONE constant: SHOT_EXPOSURE in scripts/camera_rig.gd.

2. TRAP THEFT. Confirmed and nastier than reported: during a BOT's build turn
the shared mouse could move AND CONFIRM the bot's ghost (new --stealtest
receipt: synthetic click planted the bot's spikes 55 frames before its think
fired). Placement input is now seat-gated (human turns only — hotseat mouse
semantics unchanged), and draft cards grey out on bot turns. Bots place through
their own scan path, untouched, proven live after the fix.

3. YOUR CRUSHER. The ghost was never broken — placetest receipts show pad,
hammer and Meshy head lock-stepped with the root through a full drag, windowed
screenshots confirm. What you actually saw was bug 2: the bot CONFIRMED the
crusher out from under your cursor mid-drag (I reproduced the exact hijack),
and the disc still following your mouse belonged to the NEXT bot's ghost. The
"crusher on the tee" half was real though: tee no-build was ONE disc at the
tee CENTROID, so outer tees were exposed. Now every tee gets its own disc
(tee-probe receipt: crusher ON tee 0 = INVALID). Side effect worth knowing:
bot trap layouts per seed shift (legality changed), determinism itself intact.

Also learned the hard way, for future agents: core/migrate.gd resurrects
party_setup.json from the old "Par for the Curse" user dir — deleting the ILL
WILL copy does not give you a bot-free boot. Documented in the verify doc.

Regressions: autobuild/autoplay/tracepos clean, full 4-bot fairway match to
MATCH_OVER champ=MINT with chaos overlap peak 3, estate smoke clean, import
pass clean.

## ONLINE PHASE 2, GAME MIRROR #1 — THE SÉANCE (2026-07-06, overnight)

The first minigame now plays ONLINE end to end, and the port doubles as the
house pattern every other game copies. Séance was chosen by the spec (100%
PlayerInput, kinematic, deterministic, hidden-info showcase) — and the
verification night's randomly drawn secret word turned out to be **MIRROR**.
The spirits know what we're building.

WHAT WORKS NOW (all receipts in docs/verify/online-seance-VERIFY.md):
- A remote player in the estate lobby rides the night into a full séance:
  their inputs chant/steer/vote through the phase-1 relay (zero séance input
  changes), while their machine renders a live mirror of the sitting —
  planchette, letters, focus candles, pull-arrows, vote chips, verdict,
  settlement, all driven by a 20 Hz state dict (~1 kB → ≈21 kB/s per guest).
- **Hidden info got BETTER online, as promised:** the charlatan card goes
  rpc_id to that seat's machine ONLY. Screenshot pair: host shows "THE CARD
  IS DELIVERED TO THEIR SCREEN ALONE"; the client shows "THE WORD IS
  'MIRROR' — Bury it." The eyes-closed voice summons is likewise
  per-peer-private online — no honor system across the wire.
- Chant fairness: remote presses carry a beat-stamp of what THEIR screen
  showed (±150 ms trust window). 14/14 accepted on loopback; this is the
  piece that keeps rhythm judgment fair at real ping.
- Receipts: SEANCE_TALLY byte-identical to a pristine-HEAD worktree (seeds
  7/11/42) — the transport provably didn't touch the sim; NETHASH_MOD 56/56
  + 61/61 snapshot digests matched; user:// saves restored, md5-verified.

DECISIONS ALEX MAY WANT TO REVIEW:
1. Mirror juice fires from STATE DELTAS (counters), not an event channel —
   one pipe, drop-tolerant, and it's the pattern fan-out agents copy. If a
   game later needs guaranteed one-shot theater, private/reliable sends
   exist (the cast card uses one).
2. Other sitters' chant ticks on a mirror are quantized to 20 Hz (~50 ms) —
   the audible off-beat tell survives but is coarser than couch. Flagged in
   the doc; per-tap timestamps can ride the snapshot later if playtests care.
3. The podium isn't mirrored yet (client sees the spectate card for ~4 s
   between game end and reckoning). Phase-3 chore, listed.
4. NETPROBE tape now runs to tick 13500 (was 5400) so it can chant and vote
   through a real séance night; --seancechar=N exists as an evidence-only
   pin (logged loudly, never set in real play).

NEXT (fan-out wave, per the spec's port order): understudy rides this
pattern nearly free (same hidden-info shape), then throne/tilt/mower...
PATTERN NOTES section in the VERIFY doc says exactly what to copy verbatim
and what is séance-specific.
