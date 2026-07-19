# ALEX MEMORY — running log of things worth your review
*Claude maintains this. Newest entries at top of the log. The NEEDS YOU
section is always current. Skim top-down; nothing below the fold is urgent.*

---

## NEEDS YOU (current)

- **🕯️ M5 — SÉANCE/UNDERSTUDY TELEGRAPH + ACCESSIBILITY (branch
  `worktree-agent-a4d85ccfbaf0facc1`, not merged).** Two complaints, both
  closed:
  1. **"If you can see the arrows, you can see who's unfaithful"** — the
     séance's spectral pull-arrows (prior pass) showed every sitter's TRUE
     heading continuously; a saboteur's retarget pattern converged to
     certainty well inside the 90s sitting. Fix: arrows now split PRESENCE
     (always live — a hand's effort, harmless) from HEADING (gated to a
     ~0.14s CATCH WINDOW right after each beat, the same instant the spirit
     flame already brightens — reused verbatim, no new formula). Outside the
     window the arrow holds its last-caught heading, frozen. Reading the
     table now costs looking away from your own chant/steering — a glance
     shows a stale snapshot, only a sustained watch builds a pattern. Doc:
     `docs/verify/seance-telegraph-VERIFY.md`. Two other options considered
     (surges-only, plain jitter/lag) and rejected — both wrote off in the
     doc's own prior "one knob to turn" note; the beat-gate was the one that
     didn't either overcorrect or fail to move the needle.
  2. **"Voiceover for the colours, who should look/not look — ADA
     compliance."** No VO pipeline, no new audio: each seat now gets a
     distinct existing-bank MOTIF (not just a pitch-shifted click) — RED
     bell_small, BLUE bell_toll, GOLD organ_stab, MINT raven, same mapping in
     BOTH theater games, same pitch anchors as before. LOOK = the triple-tick
     summons at that motif; a NEW "don't look" cue (`_play_standdown_tick`)
     fires the same family, one note, pitched down, when a seat's private
     window closes. Paired with `PlayerInput.rumble` on that seat's OWN pad
     only, at both edges (already existed, was just unused here — no-ops
     correctly for bots/remote/keyboard). Audited the shape-glyph rule
     ("never colour alone") across both games' cast/casting overlays — every
     colour cue already carries ● ▲ ■ ◆, nothing was missing. Doc:
     `docs/verify/theater-motifs-VERIFY.md`.

  **Receipts:** all presentation-only — séance tally seed 5/1 and understudy
  tally seed 1/2/3 byte-identical to the frozen baselines; board topology
  checksum b269c570 and the seed-7 3-night HEIR GOLD [36,41,56,43] match
  both re-verified unmoved. Screenshots:
  `docs/verify/shots/seance_telegraph_midround.png`,
  `seance_motif_cast.png`, `understudy_reveal.png` (+ 3 other understudy
  shots refreshed at this machine's window size, content unchanged).

- **🔔🔔🔔🔔🔔🔔🔔 MORNING MENU #7 — THE SEVENTH WATCH (2026-07-18→19). The
  night the game became one game.**

  **TL;DR: THE GREAT REWORK IS BUILT AND PLAYABLE.** Doc 28 went from
  approved constitution to running code in one night: board graph (3 roads,
  76 stones, crossroads route-picks), d8 LAST BREATH slider with the
  always-on aim heatmap, PENNIES/WREATHS economy, priced Peddler's Cart,
  FINAL BELL with escalating arrival wreaths, 3-of-5 announced night
  awards, LETTERS OF ADMINISTRATION, figurine pawns, over-shoulder roll
  camera, interlude grounds minigames (random → DOORMAT picks), THE
  READING finale with joint-heirs tie chain, and 12 Meshy heroes placed —
  including a DORMANT REAPER waiting at the graveyard edge for the Estate
  Stirs lane. **Playtest build: `build/illwill-0.3.0.zip`** (or run from
  source: PLAY → THE PROCESSION → NIGHTS 3 · TURN CAP 12 → GO — GATHER
  THE MOURNERS).

  **PLAYTEST WITH:** your gamepad from the title onward (L1's fix means A/B
  finally work on every menu — Godot shipped `ui_accept` with no pad
  button, that was the whole plague). A full 3-night match at defaults
  should run ~60-90 min; NIGHTS 1 is the quick taste.

  **KNOWN NITS (flagged, not hidden):** heatmap % labels can collide with
  stone names at some camera angles · figurine cosmetics-carry is wired
  but unverified with a hat equipped · pause-menu TABS still need a mouse
  click (shoulder-button binding queued) · human rolls can't skip the
  over-shoulder shot (you aim with it; bots' shots are B-skippable) · the
  Executor still tween-walks at the gate (rigged swap queued) · all new
  ceremony prose is FIRST DRAFT for your dialog.json pen.

  **RECEIPTS:** match seed 7 → HEIR GOLD [36,41,56,43] ×3 · seeds 1/11
  recorded · topology checksum b269c570 never moved all night · your
  slot_1 AND slot_2 saves verified untouched · Meshy balance 975 after
  425cr (12/12 shipped, widow re-forged once — v1 was "a blank white
  shroud, no figure").

  **QUEUED NEXT (your call on order):** Estate Stirs events (the Reaper
  MOVES — scythe carves the crypt open), THE CRYPT route, Book of the
  Dead sealed bets, presence layer (heckling at the board), classic-code
  full excision, online re-cert (Tailscale works today per RB), music
  (your domain, whenever). Full research: docs/design/research-night7/ +
  doc 28. Older detail below.

- **🪙 P2 SHIPPED — THE PROCESSION IS A COMPLETE, PLAYTESTABLE GAME (2026-07-18).**
  The economy + cycle-loop lane landed on top of P1a's graph board. What you
  can play TODAY (`PLAY → THE PROCESSION`, or
  `godot --path . -- --procession --seed=7 --turncap=12`):
  **sequential LAST BREATH rolls (d8, leader first)** with the **always-on AIM
  HEATMAP** (live landing % down your road, crit sharpening included) ·
  **PENNIES ¢ / WREATHS ⚘** (display rename only — internals keep "grudge",
  all 14 minigame receipts untouched) · **a minigame EVERY cycle** from the
  full 15-game catalog, drawn without replacement (pennies 10/6/3/1 +
  wreaths 2/1/1/0, Pallbearers pays by TEAM) · **THE PEDDLER'S CART priced**
  (10 wares, LUCKY PENNY→WILL-O'-THE-WISP; cap 3, one move item/turn,
  no-stack sabotage; wreath-last shops 30% off, announced) · **escalating
  arrival wreaths 8/5/3/1 → 10/6/3/2 → 12/7/4/2** · **3 announced night
  awards** (races visible at the interim reading, ties broken by the
  estate's coin in full view) · **LETTERS OF ADMINISTRATION** (seed 11:
  BLUE takes them nights 2–3 and climbs 4→47 wreaths — the dignity floor
  works) · **the 3-night match** ending in **THE READING** (liquidation,
  totals stream by stream, most wreaths inherits; joint heirs before any
  coin flip). Receipts re-frozen deterministic ×3 in
  `docs/verify/VERIFY-BOARD.md`; the old putt receipt is superseded with
  honors; topology checksum b269c570 never moved. Screenshots in
  `estate/procession/shots/p2_*.png`. **Your pen:** cart prices, award
  pool, and all new dialog lines (`procession.items/cart/awards/letters/
  finale` in dialog.json) are first-draft — rewrite freely.

- **🔔 NIGHT 7 — THE REWORK PLAN AWAITS YOUR PEN (2026-07-18).**
  **The full unified-mode design is at `docs/design/28-the-procession-unified-mode.md`**
  — THE PROCESSION becomes the whole game (classic retires, auction/votes
  scrapped), PENNIES + WREATHS economy with every number specified, THE LAST
  BREATH roll meter (700ms slider, honest auditable weights, 45ms crit),
  branching 3-route board (~90 stones) with THE ESTATE STIRS topology events
  (Reaper's scythe shortcut, bone bridge, flood, hungry grave, wandering
  hearse), FINAL BELL night-end, 3-of-5 announced night awards, Book of the
  Dead side bets. **Monte Carlo receipts (90k games,
  tools/board_balance_sim.py):** seat-fair to ±0.5%, good-friend skill edge
  wins ~50%, comeback ~17% (LETTERS mercy draw closes the gap), FINAL BELL
  beats your continuous-board alt on drama at equal balance — but B is one
  flag in the sim if you want to feel it. Sim discovered four structural
  laws now in the doc: standings roll order (leader rolls first, blind),
  home pawns untouchable, explicit tie-breaks, award de-correlation
  (earnings-based awards measurably boost sharks — pool stays luck/behavior
  weighted). **NOTHING IS BUILT until you mark this up.** Codex second
  opinion lands as an addendum. Playtest bugs from your notes: ALL FIXED
  and pushed tonight (gamepad everywhere incl. every estate screen + pad
  A/B on menus — Godot ships ui_accept with no gamepad button, that was
  the whole plague; dialog → one editable `dialog/dialog.json` (317
  strings, hand-rewrite freely), Nintendo pager with ring countdown, guides
  2×, DEAD WEIGHT off-map hole now fatal, SHUT THE ESTATE quit button).

- **🌙🌙🌙🌙🌙🌙 MORNING MENU #6 — THE SIXTH WATCH (2026-07-17). The night
  the fleet went out, and everything came back.**

  **THE SHAPE:** a 10-lane research fleet first (Fable ×2, Opus ×3, Sonnet
  ×4, GPT-5.6 via Codex — full dossier at docs/design/27, raw reports in
  docs/design/research-night6/), then 8 build lanes + 4 director builds.
  **11 merges + 3 direct commits, every receipt green at every gate, zip
  rebuilt.** Your real save was never touched (verified; fresh backup
  .bak-night6; all bot runs used a scratch slot 3).

  **YOUR THREE CALLS, SHIPPED:**
  1. **Moonlit walkabout** — title → hub → board is one continuous night.
  2. **THE RESHUFFLED GREEN (W8)** — the putt bands re-deal every roll:
     same six physics windows, values dealt fresh (one shared layout, all
     seats), bots aim at wherever their number landed, colors travel with
     values, "HOLD A · PICK YOUR NUMBER". ⚠ This deliberately RE-FROZE the
     receipt: seed 7 is now **HEIR MINT, 21 rounds** (was BLUE/17) —
     commit ac2b2a1 records both worlds.
  3. **PROCESSION AAA PASS (W9)** — every ceremony text surface is now
     overflow-proof (tested with "CLEMENTINE ASHWORTH-VANE"-grade names),
     **THE DRIVE minimap** (parchment corner inset: stones, pawn glyphs,
     Codicil diamond, gate) rides MOVE/REVEAL and mirrors to guests, the
     Executor no longer clips his lantern (re-seated in the gate's clear
     lane), and the board camera opens on a gentle 3/4 with eased dollies
     instead of hard cuts.

  **THE REST OF THE NIGHT:**
  - **BOARD DRAMA (W1):** THE INTERIM READING (will-clause leaders read at
    each HOUSE AWAKENS — the 25-minute lottery is now a race you can see);
    **sealed vendetta stakes** — humans hold-to-raise 0–3 under a wax seal,
    revealed with a beat (bots/remote keep RNG, so soaks stay pure); the
    duel winner hangs an **epitaph** on the loser's pawn ("BRIEFLY
    MOURNED") for the night.
  - **CEREMONY SAGA (W2):** THE STANDING GRUDGE night-open card (your
    5-night history finally gets performed — reigning heir, streaks, the
    winless, armed reprisals); **THE FINAL AUDIT** at run-end ("Kindnesses
    recorded: none. The estate had budgeted for this."); the eulogy closes
    as an itemised receipt ("Remains: reallocated.").
  - **ARENA REVEALS (W3+Z3, 150cr, balance 1460 — no top-up needed):**
    crows on every outdoor horizon (the motif bird was in zero arenas);
    TILT's sea holds a drowned-heirs graveyard, a circling fin, and **the
    drowned colossus hand** you asked about; echo's round-5 ring-out
    reveals a green-lit bone heap + grasping hands at the well bottom;
    the throne got its stained-glass clerestory; PALLBEARERS' capsule
    mourners are real rigged mourners now. The leviathan was honestly
    rejected twice (Meshy kept giving it legs). WIDOW'S GAZE joined the
    house AGX look (last FILMIC holdout; the watch-dim tell untouched).
  - **SOUND + FEEL (W4+W5):** the countdown tick finally plays its
    purpose-built sample (most-heard SFX in the game); stingers ride every
    deciding-moment camera punch; menus speak the shipped-but-orphaned
    ui_* family; the podium bell ducks the music; rotational screenshake
    house-wide; fov punches for the six punchless games; and the
    project's **first controller rumble** — bring a pad tomorrow. (W5
    caught + exempted a real one: rolling orbital's camera desyncs its
    sim — the camera basis IS its control frame. Documented in-code.)
  - **STANLEY HOOKS (W6):** the Executor narrates when you pause, idle
    20s, or quit ("The estate has never successfully stopped anyone.");
    the séance wheel's STOP button — press it; RESULTS surfaces read
    FINAL DISPOSITION / {NAME} INHERITS; QUIT is LEAVE THE ESTATE.
  - **INTRO CARDS (W7):** masked_ball, séance ("One of you was paid to
    make it fail."), orbital, echo — the four worst-taught games teach
    themselves now. Plus the PALLBEARERS double-card bug is dead.

  **PLAYTHROUGH NOTES FOR TODAY:**
  - A capture run reset the shell's party_setup.json to all-bots — one
    visit to the SEATS tab fixes it (your save slots were never touched).
  - Night 6's Standing Grudge on your real save will read compact (GOLD
    reigning with 1, MINT winless ×3) — correct; it grows with history.
  - Known nits (flagged, not built): pawn nametags cluster at the gate on
    round 1; putt-meter names clip past ~18 chars; the will-reading's
    bottom line kisses the frame at absolute-max name length; mower's
    "TALLYING..." is the last generic results title.

  **DECISIONS QUEUED (research dossier, doc 27 — none built, all scoped):**
  THE DISINHERITED (Dokapon-style opt-in last-place power, the big swing);
  THE RECORDS (walk-up almanac lectern); "PREVIOUSLY, ON THE ESTATE"
  (Newsreel cold-open recap); THE BEQUEST (wax-seal parcels at the will);
  VISITATION HOURS (return ceremony); prediction/side-bet layer (3 shapes,
  doctrine-safe); Codicil contested-crossing seat-bias fix (sim change =
  another receipt bump — bundle with the next one); board-length profiles
  + no-repeat game docket (GPT-5.6's sharpest find); LETTERS OF
  ADMINISTRATION (pity as probate paperwork).

- **🌤️ AFTERNOON ENCORE (2026-07-16, pre-Chicago).** You asked for the
  podium, the Executor's body, and rigging at the director's discretion.
  Delivered, 4 merges, receipts green, zip rebuilt:
  - **THE CORONATION (E1):** the podium ceremony left the prototype —
    moonlit EnvKit, dark stone plinths with IM Fell numerals, the family
    crypt behind the champion, lantern pools, ash/ember fall, a funeral
    wreath at plinth one, and fourth place lying beside a plain headstone
    of their own. Every game's ending upgraded at once; contract and net
    mirror rule untouched. Probe: tools/podium_probe.tscn.
  - **THE EXECUTOR BREATHES (E2):** board + estate-grounds bodies swapped
    to the rigged Meshy idle (native scale via new
    MeshyProp.instance_rigged; tween idle drops to a whisper so the two
    rhythms never fight; gesture library intact; static fallback kept).
    He also breathes through his own eulogy — same object.
  - **THE RIGGING WAVE (E3, 27cr):** Old Rake + both mourners play real
    skeletal loops (the hooded one performs a 7.3s Gentleman's Bow); the
    STARE now freezes Old Rake's loop mid-frame. DISCOVERY: the full
    **680-clip Meshy animation library is reachable** (public catalog +
    style_02 retarget proven) — a characterful re-pick (e.g. Dozing
    Elderly, id 38) is now a report-only change. No raking clip exists;
    Old Rake keeps his prop honestly.
  - ~~YOUR TONAL CALL~~ **ANSWERED 07-17: moonlit walkabout, shipped
    night 6** ("much better moon. I mean mood.").

- **☀️☀️☀️☀️☀️ MORNING MENU #5 — THE FIFTH WATCH (2026-07-16). The night
  the estate became a broadcast — and survived a Windows update.**

  **THE SHAPE OF THE WATCH:** night thesis (doc 23): night 4 built the
  board; night 5 makes it a show. 7 lane merges landed overnight; then an
  unscheduled Windows update rebooted the box mid-fleet (~04:30). Nothing
  was lost: master was clean and pushed, and the two in-flight lanes left
  everything harvestable in their worktrees. The morning director
  harvested both, ran a DIRECTOR'S SCREENING of the integrated build,
  spun two more lanes off its findings, and closed out at **11 merges,
  v0.2.0 packaged, every receipt green.**

  **HEADLINES:**
  1. **THE BOARD IS A BROADCAST.** Cameras that know where the story is
     (flyover, landing push-ins, deed money-shot), an Executor with a
     body and a silver tray who leans in when stakes deserve it, THE
     EULOGY composed from the night's real ledger, a séance wheel that
     spins, flying attributed numbers, react buttons for the waiting.
  2. **GAME #15: PALLBEARERS** — 2v2 blended-stick coffin carry; drop
     the deceased and he files a complaint.
  3. **THE FRONT DOOR JOINED THE HOUSE (D1, the screening's big find).**
     The title was still kawaii-green pills on a daylight lawn; it now
     wears the event-card stationery — ink panels, gold hairline, IM
     Fell, moonlit manor gate as the hero, candy stall hidden. Your
     delegated gothic-serif call, exercised. Review: PLAY's full-gold
     focus ring, verify_out/d1_postmerge/shot_0300.png.
  4. **NO DEAD SEATS (B6).** The dead get ONE attributed verb. Honest
     survey: only echo_chamber ("STIRRED A COLD DRAFT", sim, mirrored)
     and orbital ("RATTLED THE VOID", per-screen cosmetic) truly
     eliminate anyone without an existing ghost — the rest keep their
     own actors. Human-input-only BY CONSTRUCTION: all-bot receipts
     byte-identical, no new network messages. Full judgment calls at the
     NIGHT 5 — B6 log entry below.
  5. **THE GROUNDS GREW A CAST (Z2+B3+B8).** 10 new troupe props (all
     KEEP), gossiping crows, Old Rake, ghost queue; four plainest arenas
     dressed (TILT's moonlit coastline, GREED's antechamber, MOWER's
     graveyard, SWAP MEET's grounds) — verified against each camera's
     actual frustum. **THE RIG TRIAL PASSED**: executor_butler_idle.glb
     breathes a real Meshy idle for 8 credits — an animation lane is now
     safe to build on (scale caveat in docs/verify/meshy-troupe-VERIFY.md).
  6. **v0.2.0 IS IN THE TRUNK.** build/illwill-0.2.0.zip (~411 MB),
     release exe boot-tested clean (the shutdown segfault is editor-only,
     absent from the export template). README now leads with THE
     PROCESSION; STORE-BLURB knows what nights 4–5 built. Chicago-ready.

  **THE DIRECTOR'S SCREENING (new practice, worth keeping):** ran the
  integrated build like dailies — a full windowed board night (seed 11,
  18 rounds, heir crowned) + title/attract sampling. Three alarms
  dissolved under systematic follow-up, all one root cause: **your box
  renders at 144Hz**, so frame-indexed shot timings aren't 60fps-seconds
  (lesson banked to project memory). What it really caught: the front
  door (headline 3) and GREED's score panel haunting the intro card as
  an empty gray slab (fixed, receipt unchanged).

  **JUDGMENT CALLS FOR YOUR EYE:** crow re-roll refused a flight pose
  twice → kept as a second standing GALLERY silhouette, never airborne ·
  B6 wired 2 games not 4 (the codebase only has 2 that qualify) · title
  gothic-serif applied to button labels too (all-caps stays legible;
  revert to sans is one stylebox if you disagree) · version bumped
  0.1.0 → 0.2.0.

  **OPEN THREADS (none urgent):** the Executor's board body still uses
  transform-tween puppetry — the rigged idle GLB is landed and the
  EXECUTOR_GLB swap seam exists when you want him breathing on the
  board · music bus routing is built; composition awaits its composer ·
  the board's midfield reads dark in wide shots — one center-dressing
  beat would finish the flyover.

  **MERGED THIS WATCH (receipts green + screenshots director-read):**
  - ✅ **THE EXECUTOR EMBODIED** (B2): the host has a BODY at the manor
    gate — breathing idle, stakes-scaled lean-in before each reveal, nod/
    tut gestures; expanded line pools; **THE EULOGY** (procedural closing
    monologue from the night's real stats, never repeats two nights
    running); IM Fell English on the lower-thirds. Seed-7 receipt
    byte-identical.
  - ✅ **THE WRITING PASS** (B5): voice bible applied anthology-wide.
    "%s, DECEASED / CAUSE OF DEATH: %s" · "TAKE YOUR PLACES" · bots
    "play themselves; need no manual" · new core/voice.gd pools. 3
    receipt tripwires byte-identical.
  - ✅ **KNOWN-DEBT SWEEP** (Z1): all four morning-menu-#4 debts dead —
    jump rides the online packet (16/16 probe asserts); real-key hint
    bars in ALL games now (brief had it inverted: greed/lw/throne were
    the broken ones); GET READY/IntroCard double-gate collapsed (couch:
    IntroCard only; online: minimal EVERYONE IN sync); **newsreel plays
    on guests** (full ~7.4kB JPEG still transfer, not the fallback).
  - ✅ **AMBIENT LIFE** (B3): the grounds breathe — THE GALLERY (crows
    that gossip real chronicle lines, face whoever's losing, fall silent
    when you approach), Old Rake the groundskeeper (jump near his leaves;
    endure the stare), a ghost queue at a door that never opens, fog/
    embers/distant caws, a vengeful seagull, one guttering runt lantern.
  - ✅ **FRONT-END AAA** (B4): **gamepad pause** (START works — a
    controller-only player literally couldn't pause before); **attract
    mode** ("THE HOUSE REHEARSES" — idle 45s → bots play under a 1920s
    film wash); title recomposed (stale debug bg image was covering the
    live 3D!); settings double-panel bug fixed at root + AMBIENCE
    slider + 5s quit-hold.

  - ✅ **BOARD BROADCAST** (B1): the Procession watches itself like TV —
    opening flyover, type-aware landing close-ups, the DEED MONEY-SHOT
    (wax-seal card flies to the buyer, beacon visibly relocates), the
    séance wheel actually spins, flying attributed +/− numbers, minigame
    ROULETTE, putt TARGET PREVIEW (beams+chevrons on projected stones),
    reveal-cascade REACT buttons (HA!/OOF/OOH glyphs), board moments now
    feed the newsreel. Seed-7 receipt byte-identical through all 8
    features + the merge.
  - ✅ **GAME #15: PALLBEARERS** (B7): the anthology's first TEAM game.
    2v2, one coffin per pair, moves on the BLEND of both sticks; drop it
    and the deceased spills out complaining ("You have dropped me before
    the mourners. Note it for the record.") — mash to restuff; swinging
    gate, mud, mourner crossings, downhill runaway; synced-hop HEAVE;
    online mirror + byte-identical receipts. Director nit fixed on the
    way in: the heir crown banner no longer shows the SEED to real
    players.

  - ✅ **MESHY FORGE WAVE 2** (Z2, harvested after an unscheduled Windows
    update rebooted the box mid-run — nothing lost, all GLBs were already
    downloaded): 10 troupe/board props on master (mourners, groundskeeper,
    two crows, hearse, carry-coffin, wreath, obelisk, hooded mourner, urn);
    monument obelisk-GLB wiring with BoxMesh fallback; **THE RIG TRIAL
    PASSED** — executor_butler_idle.glb plays a 4s Meshy preset idle for
    8 credits (rigging+animation endpoints work; scale caveat documented
    in docs/verify/meshy-troupe-VERIFY.md: never AABB-size a rigged GLB).
    Crow re-roll verdict was honest: it refused a flight pose twice, so
    it ships as a second GALLERY standing silhouette, never airborne.
    Seed-7 receipt byte-identical post-merge.

  - ✅ **GHOST MEDDLING** (B6, relaunched post-reboot — the kit survived
    the reboot untracked and needed ZERO fixes): dead humans in
    echo_chamber and orbital become drifting wisps with one slow-charging
    MEDDLE verb, every use attributed in the estate register. Receipts
    byte-identical by construction.
  - ✅ **ARENA DRESSING** (B8): TILT coastline, GREED antechamber, MOWER
    graveyard, SWAP MEET grounds — shared ArenaDressing helper; 10 of 14
    other arenas were already enclosed/dressed. Four receipts
    byte-identical.
  - ✅ **THE FRONT DOOR** (D1, from the screening): title menu in funeral
    stationery, IM Fell tagline/labels, moonlit grounds, manor gate
    reframe, gold gamepad focus ring. Every grounds mutation restores
    exactly on dismiss; attract + settings + board receipt verified.
  - ✅ **Director inline:** GREED intro-card gray-slab fix ·
    STORE-BLURB/README refresh (THE PROCESSION leads) · v0.2.0 bump ·
    seed banner autoplay-only (confirmed working in screening).

- **☀️☀️☀️☀️ MORNING MENU #4 — THE FOURTH WATCH (2026-07-15). The night
  you asked for a board game, and the estate grew one.**

  **THE HEADLINES (16 merges, all pushed, all receipts green):**
  1. **THE PROCESSION IS PLAYABLE.** Press PLAY → "how does the estate
     settle its debts tonight?" → THE PROCESSION. Everyone putts their
     pawn at once (frozen golf physics ARE the dice — sweet-spot bands
     for exact space targeting), pawns move together, then the Executor
     reveals landings one by one. Roving CODICIL sells DEEDS; shrines,
     weeping graves that pay their monument owners, tollgates, séance
     wheel, nemesis vendetta wagers; minigame every 2nd round; HOUSE
     AWAKENS every 3rd; will clauses announced up front; most Deeds
     inherits. ~25 min default, Deed-goal dial in the menu. It's dressed
     as a moonlit funeral drive (Meshy props, MOONLIT light, broadcast
     lower-thirds). Quick CLI taste: `godot --path . -- --procession
     --seed=7 --deedgoal=4`
  2. **GAME #14: THE WIDOW'S GAZE** — red-light-green-light at the wake.
     Rob relics beside the coffin, FREEZE when she turns, and (the twist)
     shove someone as the sting plays — the Widow takes them, attributed.
     Tuned to the razor: 0.5s sting window vs 0.465s best human stop.
  3. **EVERY PLAYER HAS A CONTROLLER NOW (INPUT 2.0):** press-A-to-join
     + READY badges, pad-disconnect → pause + 3 recovery paths (cert-
     grade), real brand glyphs on cards, hold-to-confirm on QUIT/wipe.
  4. **14/14 ONLINE + the worst online bug dead:** Par crossed the wire
     (byte-identical receipts; guests see killcams). Host-pause no longer
     strands guests — they get "the estate holds its breath" and resume
     digest-verified. Remote guests can now BID in the auction.
  5. **THE ESTATE REMEMBERS OUT LOUD:** deciding moments auto-captured →
     THE NEWSREEL plays them as decayed 1920s film before the will;
     THE FAMILY ALBUM hangs each night's stills on the grounds;
     THE CHRONICLE gossips in the lobby and the will-reading ("GOLD has
     erected 4 monuments. None mention kindness.")
  6. **The whole anthology got the house look** (AGX + three light
     presets, per-game judgment), **32 Meshy props** (~$22 of credits),
     **AAA SFX bank** (40 keys/105 variants, CC0), **jump/hop** (real
     jump on the grounds walker — go feel it), **UI kit** (intro cards,
     staged results, transition wipes, all four seats always listed).

  **YOUR PLAYTEST LIST (in order of joy):** (a) a full PROCESSION night
  with pads on the couch; (b) THE WIDOW'S GAZE with humans — try the
  sting-shove murder; (c) walk the grounds: jump around, find THE FAMILY
  ALBUM wall, let a night end and watch THE NEWSREEL; (d) yank a
  controller mid-game (the overlay should catch it); (e) online: host +
  join on the LAN, open ESC as host (guests should see the curtain, not
  freeze), bid from the guest seat, and if you can — a par round across
  the wire; (f) SFX veto pass: `godot --path .
  res://tools/sfx_audition.tscn` then answer the 9 MORNING CALLS in
  docs/design/21-sfx-overhaul.md.

  **DECISION CARDS — ✅ RATIFIED as-decided by Alex 2026-07-16 ("decision
  cards were good as decided"), from the road, no playtest yet. SFX calls
  stand, board rulings stand, Meshy quirks (WELCOME MUT doormat, green-man
  waypoint) stay as canon, gothic serif choice delegated to the director
  (night 5 will pick an OFL face for the Executor's lower-thirds).**
  Original cards for reference: doc 21 §MORNING CALLS
  (SFX, 9 items) · doc 18's eight board calls (all made by me — override
  any) · Meshy quirks kept for your veto: the DOORMAT trophy reads
  "WELCOME MUT", the waypoint stone grew a green-man face · gothic serif
  font for the Executor's lower-thirds (repo has none — want to pick one?).

  **KNOWN-OPEN (small, listed honestly):** hop doesn't ride the remote
  input packet yet (couch-only, ~10-line stitch); some non-swept games'
  hint bars still show abstract "A =" in all-bot fallback (greed/
  last_will/throne fixed; others listed in UI lane report); estate GET
  READY gate + game intro card double-gate (pre-existing); newsreel is
  host-screen-only online (doc 20 flags the parity field); echo bot
  matches still not byte-reproducible (pre-existing, chaotic).

- **🌒 NIGHT 4 UNDERWAY (2026-07-15, the fourth watch).** New director seated;
  full-autonomy mandate received. The month-scale plan is written and committed:
  `docs/design/17-directors-plan-2026-07-15.md` — Input 2.0 (pad per player),
  AAA UI kit, Meshy Forge (key found in Dead_Attestation/.env; spend-freely
  budget confirmed), THE BOARD (flagship: "The Procession" — estate grounds as
  literal board, simultaneous pawn-putting as dice, Executor-narrated reveals),
  jump sweep, orbital far-side silhouettes, couch-online parity, new games,
  graphics pass, and three surprises (NEWSREEL / GRUDGE LEDGER / FAMILY ALBUM).
  Research docs 13–16 landing tonight. Decisions the brief queued for you are
  being made by the director per your delegation — each logged below as it's
  made, overridable in the morning.

  **DIRECTOR'S RULINGS (night 4, batch 1):**
  - **THE BOARD = "THE PROCESSION"** (doc 18 has all eight calls + spec).
    Highlights: movement = PUTT YOUR PAWN (frozen golf physics as the dice);
    hard currency = **DEEDS** (you're the T&E attorney — it had to be);
    parallel roll+move with staggered Executor reveals (parallelize the
    boring part, serialize the funny part); zero hidden arbiters; default
    session ~25 min with a Deed-goal dial; Trail absorbed as the QUICK WAKE
    preset; nemesis Vendetta spaces IN. Building full Approach A tonight.
  - **JUMP RULING:** research (doc 16) found every shove check already
    flattens Y — so: universal *expressive hop* (provably zero balance
    impact) on a new third button for walking games (echo/throne/greed),
    REAL traversal jump for the estate walker (the Mario Party board-jump
    analog), existing hops/jumps untouched (orbital/DW/LW/par-grief),
    vehicles/seated/masked-ball exempt. Your "people expect jump" and the
    2-verb module contract both survive — the own-controller mandate is
    what unlocks the third button.
  - **ORBITAL VISIBILITY:** full-body per-player-color silhouettes through
    planets (extending the marker-orb no_depth_test trick already in the
    code), plus occluded-ball ghost dots. Camera/minimap/transparency
    approaches ruled out for control-frame and clutter reasons (doc 16).
  - **CODEX NOTE:** account rejected model 'codex-5.6-sol'; lanes rerun on
    the CLI default model (your correction to gpt-5.6-sol applied for later
    lanes).

  **MERGED (night 4):**
  - ✅ **AAA UI KIT (results half)** (merge b1cbeab): core/ui_kit/ —
    ResultsBoard (freeze → count-up rows → protected winner beat, hold-A
    skip), IntroCard (Mario Party-style load card w/ real bindings + READY
    ring), TransitionWipe (iris/curtain), HudStrip (player chips, lead
    pulse). Mower + tilt adopted as exemplars; mower's Splatoon tally now
    rides the kit via a signal seam (its turf saturation still animates in
    lockstep). Nits queued for wave 2: card/hint-bar notation consistency,
    a banner-stacking beat, always list all 4 seats.
  - ✅ **JUMP LANDED** (merge d9b7ca2): new third input "jump" (pad X /
    Q / R-Ctrl / Space-on-mouse) — expressive hop in echo/throne/greed
    (apex 0.30m, airtime 0.40s, squash + dust + 0.5s cd; provably
    cosmetic — every shove/range check Y-flattens, receipts unchanged:
    echo determinism 0.000000, greed intercept 0.80, throne balance
    pass), REAL jump for your estate walker (1.1m, coyote 0.10s, buffer
    0.15s, jump-cut — tuned for your hands, go feel it on the grounds).
    Bots hop at spawn/triumphs for personality. Known-open: hop doesn't
    ride the remote input packet yet (couch-only; ten-line stitch listed
    for a future pass). DW/LW/orbital/par hops untouched.
  - ✅ **HOST-PAUSE BUG DEAD + GUEST BIDDING** (merge f6b4b35): root cause
    was NOT a dropped connection — the 20Hz pump rode the estate's pausable
    _process. Now: pause is announced over the always-polled socket; guests
    get a curtain ("THE HOST HAS PAUSED — the estate holds its breath —
    your seat is held"); resume is digest-verified in sync; guest ESC no
    longer streams raw input while in their own settings. BONUS: remote
    guests can now BID in the auction (RAISE paddle — "The Executor accepts
    grudge, resentment, and exact change."). A long-standing known-open
    (remote bidding) is closed.
  - ✅ **PAR IS ONLINE — 14/14 ACROSS THE WIRE** (merge f6b4b35): the crown
    jewel crossed last. All putts/trap-builds now flow through seat-
    attributed intents into the frozen debug_putt entry point; couch
    receipts byte-identical (fairway5 168 lines, widows13 231 lines,
    diffed line-for-line); a remote guest placed a trap, putted 7 strokes,
    and watched GOLD'S THE CRUSHER — SIGNED WORK killcam mirrored on their
    screen. Two small estate-side snippets remain (doc 22 §7) — director
    applies them after the last UI lane merges.
  - ✅ **THE CRITICAL PATH: SPLIT + INPUT 2.0 + INTEGRATIONS** (merge
    76dde67): estate.gd 3375→2702 lines (monuments/wardrobe/howto/net-lobby
    extracted to modules). **INPUT 2.0 live:** press-A-to-join + READY
    badges in the lobby, pad-disconnect → pause overlay with three recovery
    paths (reconnect / A on another pad / host holds B for bot), real
    brand glyphs on the HOWTO cards, hold-to-confirm on QUIT (3s) and slot
    wipe (5s). **PLAY is now a rite chooser:** THE PROCESSION featured with
    the Deed-goal dial; CLASSIC NIGHTS beneath. **The estate remembers out
    loud:** newsreel plays before the will, album wall hangs on the
    grounds (walk-up hotspot), chronicle lines in the will-reading AND the
    lobby greets you with ledger gossip. (Codex built much of INPUT 2.0
    before wedging — the takeover verified and finished it.)
  - ✅ **THE PROCESSION GOT ITS FACE** (merge e6afe0b): the board is now a
    moonlit funeral drive — carnival tents and pink kart RETIRED; green-man
    waypoint lanterns, wrought tollgate arch, codicil pedestal in the one
    warm pool of light, five gravestone styles by space, hearse + grim
    signpost at the start, crypt door/angel/well/dead trees on the
    perimeter. Space discs are dark stone with emissive color rims +
    engraved runes (never color alone). Executor reveals ride a broadcast
    lower-third with the player's badge. Meters unclipped + parchment-
    framed. Three real bugs fixed en route (a %s leaking into banners,
    !is_inside_tree spam ×17→0, a camera-snap race). Seed-7 receipt
    re-verified post-merge: heir BLUE, 17 rounds — byte-identical.
    One follow-up noted: repo has no gothic serif font (Baloo2 used);
    adding one is a taste call for you.
  - ✅ **SFX AAA PASS** (merge 7e122ce): 40 keys / 105 variants, all CC0
    (6 Kenney packs + OpenGameArt; license ledger in assets/audio/), all
    processed to the house declick bar (44.1k/16-bit, razor onsets on
    impacts, bit-zeroed edges, −1dBFS impacts; 8.5MB total). Old keys
    unchanged, 7 gained anti-canned round-robin variants; new families:
    impact tiers, whooshes, UI set, stingers, countdown ticks, bell/raven/
    creak/thunder/chain/coffin/projector gothic kit + 3 ambience beds
    (core/ambience.gd, wired into nothing yet). **YOUR VETO SURFACE:**
    `godot --path . res://tools/sfx_audition.tscn` — arrows + Enter to
    audition everything. 9 taste calls await you in docs/design/21-sfx-
    overhaul.md §MORNING CALLS (organ stab, stingers, crowd, which keys
    get swapped in games...). Music untouched — your domain.
  - ✅ **THE WHOLE ANTHOLOGY HAS THE HOUSE LOOK** (merge d9bbe0a): EnvKit
    applied to all 12 original games (echo ring now blooms hot gold —
    root cause was emission 0.6 below the 1.0 glow threshold), with real
    per-game judgment: séance kept its candle intimacy (eyes-closed dark
    IS a mechanic), masked ball kept the warm ballroom + cool rim for
    crowd separation, tilt chose MOONLIT so the tilt-shadow on the sea
    still reads, orbital got AGX+glow only (x-ray silhouettes verified
    intact). Net −65 lines. All receipts pass. Before/afters:
    worktree verify_out/lookdev2/.
  - ✅ **MESHY FORGE + 32 PROPS** (merge 4bef01f): manifest-driven
    pipeline (tools/meshy_forge.ps1, key never committed), 32/32 props
    landed for 1080 credits (~$22): 8 gravestone styles, all 8 will-
    reading award statuettes (the tipped scales, the cobra, the crossed
    daggers...), 8 board-furniture pieces, 8 estate dressings. Contact
    sheets: docs/verify/shots/meshy_forge_group*.png. Two kept quirks
    for your veto: the DOORMAT trophy reads "WELCOME MUT", and the
    waypoint stone grew a green-man face. Procession dressing swap is
    in flight now.
  - ✅ **THE PROCESSION — THE BOARD IS REAL** (merge 43bcee0): the Mario
    Party loop, playable end to end tonight. ~24 spaces looping the manor
    drive; every round all four putt their pawns AT ONCE (corner meters,
    sweet-spot bands = exact space targeting, frozen golf physics as the
    dice), pawns move at once, then the Executor reveals landings one by
    one ("GOLD gains at the shrine. Piety pays, this once, under
    protest."). Roving CODICIL sells DEEDS (10 grudge +2/held); shrines,
    weeping graves (player monuments collect tolls!), stalls, tollgates,
    séance wheel, nemesis vendetta wagers; minigame block every 2nd round,
    HOUSE AWAKENS every 3rd; will-reading clauses announced up front; most
    Deeds INHERITS. Presets: Quick Wake ~20min / Short ~25 / Full / Vigil.
    Deterministic: seed 7 twice → identical tally (verified again post-
    merge: heir BLUE, 17 rounds). **Try it now:**
    `godot --path . -- --procession --seed=7 --deedgoal=4` (bots), or
    without --autoplay for a human seat. Known polish queue (task 16):
    board dressing is placeholder-cheerful (carnival tents, pink kart
    hearse — Meshy props + MOONLIT pass incoming), reveal banner needs a
    scrim, PLAY-menu entry lands with the estate split merge.
  - ✅ **GAME #14: THE WIDOW'S GAZE** (merge 8d621b0): red-light-green-light
    at the wake — creep up the parlor, rob relics from beside the coffin,
    FREEZE when she turns. The ILL WILL twist: shove someone as the sting
    plays and the Widow takes them (attributed murder, +1 + royalty).
    Movement-feel tuned for your hands: 0.5s sting window vs 0.465s
    best-case human stop (react 0.25s + friction bleed 0.215s) — barely
    possible, exactly as specced. T-25 fake-outs with a learnable falling
    third note. Full net mirror day one; sobs/stings play client-side.
    Bots stride at 0.87× with mourning rests so humans out-hustle them.
    Play: MINIGAMES → THE WIDOW'S GAZE. Bugs to expect: none known;
    seed-11 tally receipt in minigames/widows_gaze/VERIFY.md.
  - ✅ **THE ESTATE'S MEMORY** (merge 0948268): the night's biggest surprise,
    shipped in three parts. **THE NEWSREEL** — deciding moments and victors
    are captured automatically (MomentScribe hooks the shared fov_punch/
    podium chokepoints, zero game edits) and replayed before the will as
    decayed 1920s silent film: intertitle cards ('ACT I — "THE DECIDING
    MOMENT" — as it happened in ECHO CHAMBER'), sepia/grain/scratch/gate-
    flicker shader, in-shader Ken Burns. **THE FAMILY ALBUM** — each night's
    stills archived + hung as gilt-framed photos on a salon wall in free
    roam ("...and N more nights remembered"). **THE GRUDGE LEDGER** — cross-
    night chronicle in the save; the Executor now says things like "GOLD
    has erected 4 monuments. None mention kindness." Test: --newsreel-test
    / --album-test / --chronicle-test. estate.gd wiring lands with the
    split merge (snippet in docs/design/20).
    ⚠️ Housekeeping: your saves were additively backed up (*.bak-night4);
    a Procession bot-night wrote an heir into slot_1 via shared user:// —
    the clean copy will be restored at verification night.
  - ✅ **LOOK-DEV: EnvKit house look** (merge 75a2c40): core/env_kit.gd —
    AGX tonemap + MOONLIT/CANDLELIT/STAGELIT presets (one shadowed key
    light, glow-on-emissives, SSAO, fog; 60fps held). Applied: echo
    (STAGELIT — the ghosts perform in a dark theater), throne + dead_weight
    (CANDLELIT, dust motes in the attic; HOUSE AWAKENS dim survives).
    Before/afters in the worktree verify_out/lookdev/. Director's nit sent
    back: echo's gold ring lost heat under AGX — fix in flight with the
    sweep to the remaining 9 games.
  - ✅ **ORBITAL FAIRNESS FIX** (merge 7c8c4c1): occluded pawns now show
    identity-colored x-ray silhouettes through planets (skinned-mesh
    duplicates, occlusion-gated by an analytic ray-vs-sphere test — no
    always-on tint wash); occluded balls get a pale ghost dot (suppressed
    while held). Sim untouched: seed-7 bot receipt byte-identical to
    baseline. Try it: humans and bots finally see the same game. Demo:
    `godot --path . res://minigames/orbital/orbital.tscn -- --orbtest=xray`

- **☀️☀️☀️ MORNING MENU #3 — THE FINAL FABLE MORNING. Read this one.**
  The overnight run delivered EVERYTHING on the board. Headlines:
  1. **THE WHOLE GAME IS ONLINE.** 12 of 13 games mirror across the
     wire (all but par — phase 3 by design), PLUS the auction board,
     match podiums (with hats), THE READING word-for-word, and the
     parade stone-by-stone. A guest joins with a 6-char code and lives
     the whole night. Best receipts of the night: a remote player WON
     Masked Ball and took a "Belle of the Ball" monument; another
     gusted the living from beyond the grave in Last Will; another was
     killed by its own echo with the irony banner synced tick-for-tick.
  2. **PAR v4 IS COMPLETE (all 3 waves).** Live chaos griefing — your
     day-one wish: four avatars brawling on the course, shoves flinch
     shots mid-swing, early-trigger traps — plus THE WIDOW'S WALK
     flagship (chasm, land bridge, elevated green) and 1.4x courses.
     Physics still frozen, byte-identical receipts throughout.
  3. **YOUR MUSIC IS WIRED DEEP**: the FINAL STRETCH kit escalates
     every game into your game_tense track at its own dramatic
     threshold (crisis, sudden death, final lap, final orbit, the
     house awakening). Deciding moments get the deep freeze.
  4. **STEAM IS PREPPED**: GodotSteam vendored behind the transport
     seam; ENet untouched; publish-day checklist in doc 12. Needs only
     a real appid whenever you decide.
  5. Round-2 bugs: ALL DEAD (zombie module stacking, NEW GAME dead-end,
     audio pop at the waveform level, tee glare, trap theft = your
     crusher ghost, per-tee no-build). Plus HOUSE RULES card (45s to
     read), package: build/illwill-0.1.0.zip + icon + blurb + name scan.
  **TONIGHT'S PLAYTEST CHECKLIST (evening, before the ~6h bugfix
  window):** (a) a full night start to finish — listen for your own
  tracks turning tense; (b) par chaos griefing feel on a pad + the
  Widow's Walk chasm (fair or cruel?); (c) LAST WILL v2 race + curse
  drafting; (d) MASKED BALL with eyes open; (e) online: second machine
  on the LAN joins with the code, or two instances on one box
  (--net=host / --net=join=127.0.0.1:8910); (f) known watch-items: MP3
  loop seams (tell me which track breathes), DW bot lip-stalemate
  (documented, unfixed — needs your ruling), echo bot matches aren't
  byte-reproducible on ANY build (chaotic physics, pre-existing,
  documented). Report bugs in one dump; I'll triage into the 6 hours.

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

### 2026-07-16 — Z1 KNOWN-DEBT SWEEP: all four morning-menu #4 debts paid (branch z1-debt-sweep)
Night 5's Wave-0 debt lane. Four commits, one per fix, receipts green:
1. **Hint bars never say "A =" again** (a79418d). The `_hint_seats()`
   seat-0 fallback (your mower/tilt/widows exemplar) swept into the ten
   remaining bar-owning games + par's build hint (which told an all-bot
   demo to CLICK TO PLACE). Bars now always match the intro card
   (Space/E/Q). 10 receipts diffed pristine-vs-changed: byte-identical
   (throne/seance wobble reproduced pristine-vs-pristine — noise floor,
   verdict lines identical). Shots: verify_out/hintbars/.
2. **The hop crosses the wire** (e01b540). jump + presses_jump ride the
   30 Hz input packet with the same dropped-tap rescue as A/B; old
   builds decode jump=false (dict packets, nothing to version). 16/16
   probe asserts + host/join wire smoke, 0 errors. verify_out/jump_wire/.
3. **Double-gate collapsed** (0b0e815). Games with their own IntroCard
   (8 of them, flagged in MODULES) skip the estate GET READY on the
   couch; online it shrinks to a minimal EVERYONE IN sync (the only
   cross-estate hold — remote A / ready_toggle still land). Non-intro
   games keep the full card. --readytest now proves all three faces.
   Shots: verify_out/gate/.
4. **THE NEWSREEL plays on guest screens** (df8a647). Host ships each
   kept still as a ~360px JPEG (~7 kB each, reel <= ~150 kB/night) +
   intertitles over a new reliable ceremony-media pipe; guests roll the
   same Newsreel scene; the will facts fold a straggler. Full paired
   probe night: same ACT I card on both screens, clean fold, 0 errors.
   Shots: verify_out/newsreel_net/.
FLAG: my first worktree adoption collided with the procession lane —
commit 691a841 (identical content to a79418d) sits harmlessly in that
lane's branch history; merging both branches is clean (same changes).

### 2026-07-15 — MESHY FORGE: 32 new props (graves / awards / board / estate) on meshy-6 (agent worktree)
The prop library for the estate's next dressing pass exists. A new
manifest-driven batch tool (`tools/meshy_forge.ps1` + `tools/meshy_manifest.json`)
generated **32 props, 32/32 KEEP**: 8 gravestones, 8 will-reading superlative
trophies (WORKHORSE ox → RECKONER tipped scales), 8 funeral-procession board
furniture pieces (tollgate arch, codicil pedestal, hearse cart, planchette,
crypt door...), 8 estate dressing pieces (dead tree, raven fountain, lit
lamppost, broken angel...). First batch on **meshy-6** (priors were meshy-5);
same proven house-style suffix, PBR off, low-poly 8k. Pilot of 3 confirmed
30 credits/prop before the full spend. 4 props re-rolled once after I read
the contact sheet (nemesis daggers, deed token, cherub, codicil scroll — all
v2s landed clean). **Spend: 1080 credits total** (960 shipped + 120 retired
v1s; task IDs all in `tools/meshy_forge_report.json`). YOUR REVIEW:
`docs/verify/shots/meshy_forge_*.png` (9 sheets) + verdict table in
`docs/verify/meshy-forge-VERIFY.md`. Note for the sheet read: the DOORMAT
trophy says "WELCOME MUT" (AI typo — I kept it, it's funnier; re-roll if it
grates) and the waypoint stone grew a hollow-eyed green-man face (creepier
than briefed, kept). NOT integrated — GLBs live in
`assets/models/meshy/generated/`, monuments/board wiring is another lane's.
`tools/asset_probe.gd` gained additive `--dir=`/`--groups=` flags (defaults
unchanged).

### 2026-07-07 — ONLINE PHASE 3: remote guests get THE DRAMA (podiums + night ceremonies + auction card) (estate-online agent worktree)
The biggest online gap is closed: guests no longer stare at the spectate
card while the couch gets the fireworks. A remote friend now sees, on their
own screen: the **match podium** (same tableau, same confetti, **their
bought hats** — host wardrobe rides the facts), the full **RECKONING
ticker**, the **night podium** with the WINS-THE-NIGHT banner, **THE READING
OF THE WILL word-for-word** with the couch's 0.45 s stagger (this one's the
money shot: `docs/verify/cer_netshots_join/snap_will_reading_mirror_13917.png`
vs host `snap_will_reading_14211.png`), **THE PARADE** animating stone-by-
stone on their own trail, the free-roam boundary handoff, and (code-complete)
the RUN-OVER heir ceremony. Plus the **auction is finally visible online**:
block, bids, clock, pot, Executor quip, vendetta book — read-only ("the
couch holds the paddles tonight"; remote bidding is a named later chore).
HOW: no new RPCs — host narrates ceremony stages as facts on the existing
5 Hz lobby channel; `podium.gd` got an additive `stage_entries()` so the
client restages the SAME scene and the HOST decides when it folds. Receipts:
two-instance probe on private port 9473 end-to-end in 110 s, twice;
NETHASH 98/98 + 28/28 zero mismatches; import pass, estatebots ceremony
soak, auctiontest PASS, strolltest, readytest, couch-tape probe all green;
user:// backed up + restored byte-identical. Full story:
`docs/verify/online-ceremonies-VERIFY.md`. Honest gaps: guest top bar,
local lawn décor, static guest ticker, run-over stage not probe-driven yet.

### 2026-07-07 — REAL-KEYS HINT BARS (5 games) + ECHO "killed by your own echo" irony pack (agent worktree)
Two presentation deliverables, verified WINDOWED by eye (RTX 4050, Vulkan).

**Bars now print real keys, not `A`/`B`.** Ported the `realkeys-VERIFY.md`
template (the 3 self-contained helpers) into the last five bar-owning games:
`echo_chamber` (it had NO bar — added a bottom-center one), `swap_meet`,
`last_will`, `masked_ball`, `seance` (its SITTING chant bar ONLY — the
`_net_state`/`_net_apply` mirror paths untouched). Mixed kb-vs-kb roster all
rendered the per-seat "differ" form, e.g. last_will:
`SHOVE: Space/RED · Enter/BLUE · HOP: E/RED · Shift/BLUE`. Both fallback
branches verified on last_will (single-human collapses to `Space = SHOVE`;
all-bot keeps the byte-identical generic legend). Shots in
`docs/verify/polish-bars-irony-shots/`.

**ECHO irony pack (doc 09 §2.1).** Dying to your OWN recorded ghost now says
so: big center banner `KILLED BY THEIR OWN ECHO`, `grudge` 0dB, slow-mo
0.3×/0.5s, a tracked `self_haunt` stat → prepended results highlight
(carved at the will) + a `kill_events` cause slug `self_echo` (killer==victim,
so NEMESIS rightly skips it). Confirmed end-to-end: `ECHO_SELF_HAUNT` fires,
`KILL_EVENTS` carries two `"cause":"self_echo"` entries, match completes clean.

DECISIONS ALEX MAY WANT TO REVIEW:
1. **Determinism call.** The ghost-drift receipt (`max_err=0.000000`, all
   rounds) is byte-identical before/after — that's the hard invariant and it
   holds (transform-based replay). But echo's kill/placement ORDER was never
   reproducible run-to-run even in the ORIGINAL code: I ran the unmodified
   binary twice at `seed=1` and the kills diverged after round 1 (the hit-pause
   uses a real-time timer + bots draw RNG per tick → wall-clock-coupled). So
   the irony slow-mo can't be blamed for placement drift, and I did NOT
   re-baseline or touch scoring. Flagged in case you want the kill order made
   deterministic someday (would need a tick-counted freeze, not a real-time
   timer — same pattern swap_meet already uses).
2. **Echo bar is NEW** (echo had only a "GHOSTS: N" label). Placed bottom-
   center, shown ~8.5s then hidden, label from the estate how-to card
   (a=STRIKE, b=DASH/hold PARRY). If you'd rather it persist, one-line change.
3. Scope: implemented ONLY doc 09 §2.1 (the self-haunt callout), per the
   task's framing ("the killed by your own echo celebration"). The other §2
   items (match-point banner, winner Cheer, ghost materialization) are still
   on the bench.

### 2026-07-07 — ONLINE PHASE 2, ARENA MIRROR #1 — THE THRONE (agent worktree)
The first REALTIME arena plays online. Proves the séance house pattern carries
a Jolt-physics brawl, not just UI/turn games: **physics stays host-side; the
client renders interpolated transforms and fires all the juice from state
deltas.** Two instances, one machine, a full ~2-min match with a remote seat 1.

- Mirrored on the client (screenshots read by eye,
  `docs/verify/throne_netshots_join/`): the whole arena — the crowned king on
  the dais with the gold-stream fountain + the `♔` crown glyph in the score
  panel (`snap_mirror_reign`); the guard-wall lifecycle; and the
  **SUCCESSION CRISIS — THRONE PAYS DOUBLE** banner + hot-red timer
  (`snap_mirror_crisis`). The probe match even ran into OVERTIME, so **THE
  COURT WILL NOT ADJOURN** was exercised across the wire.
- Juice from counters, not events: decree blast → shockwave+shake+boom; grip
  drain → king pop+shake; dethrone → slow-beat echo + the crown tumbles off
  the seat as a physics body. Drop-tolerant, one pipe.
- Royals are frozen + net_mirror on the client (Royal._physics_process /
  _update_anim short-circuit); throne.gd's _mirror_tick lerps each toward the
  latest snapshot and keeps the grip-pip HUD + cooldown rings glued to the king.
- Receipts: `--thronebalance` (real match, FX) is wall-clock-coupled by its
  slow-mo beats and wanders run-to-run on identical code — so the byte receipt
  is the no-FX fixed-step `--thronebalancefast`, byte-identical to a
  pristine-HEAD worktree (seeds 1/2/3, shares + dethronings + OT all equal).
  NETHASH_MOD 43/43 client digests matched the host (zero disagreements);
  bandwidth mean ~855 B/snap (≈17 kB/s @ 20 Hz); user:// saves restored,
  md5-verified.
- Lanes: `minigames/throne/**` + `docs/verify/` only. Estate + net_session
  UNTOUCHED. (Honest gap: the ragdoll TUMBLE spin isn't mirrored — position +
  Hit_A + the tumbling crown are; the fallen slides but stays upright.)

### 2026-07-07 — ONLINE PHASE 2, GAME MIRROR #2 — THE UNDERSTUDY (agent worktree)
The second theater game plays ONLINE end to end. It rode the séance house
pattern nearly free (same hidden-info shape). The win worth seeing:

THE MONEY-SHOT PAIR (two PNGs, one casting window, remote seat 1 = a CAST
member so its private card is THE PLAY):
- HOST screen: `SUMMONED ACROSS THE WIRE · THE SCRIPT IS DELIVERED TO THEIR
  SCREEN ALONE`. The machine running the whole sim shows a REDACTED card.
- CAST CLIENT screen: `TONIGHT'S PLAY · THE SHIPWRECK · You have read the
  script.` The play flash exists on exactly one screen — and it's the right
  one. The understudy's peer would instead get the "you never got the
  script" card. Nobody learns another's role. Online is structurally better
  than couch here (no eyes-closed honor system on the wire).
  `docs/verify/us_netshots_{host,join}/`.

- Mirrored, both screens: the casting theater, the rehearsal cue grid + the
  actors' delivered-cue status labels, the live vote board (carets forming,
  accusation chips), and the verdict — `THEY WALK — RED WAS THE UNDERSTUDY`
  with RED spotlit and the scoreboard's `(u/s)` tag revealed at RESOLVE
  exactly as on the host.
- Per-peer voice summons: each remote seat hears ONLY its own colour called
  (roll-call + cast ticks ride the private channel). Blind-table trust →
  structural privacy across the wire.
- Real-keys hint bar retrofit (realkeys-VERIFY template): the persistent bar
  now prints the player's LIVE key (`STICK = CHOOSE · Space = COMMIT`), not a
  generic "A". Self-contained helpers, presentation-only.
- Receipts: US_TALLY byte-identical to a pristine-HEAD worktree (seeds
  1/2/3) — transport provably didn't touch the sim; NETHASH_MOD 43/43 +
  46/46 snapshot digests matched; bandwidth mean ~907 B/snap (≈18 kB/s @
  20 Hz); user:// saves restored, md5-verified.
- Lanes touched: `minigames/understudy/**` + `docs/verify/` only. Estate
  shell + net_session UNTOUCHED (the generic 20 Hz pump just works).

### 2026-07-07 — ONLINE WAVE 2×: GREED + DEAD WEIGHT mirrors, and greed's CLOSING BELL (agent worktree)

Two more games play across the wire on the séance's house pattern, plus the
owner-signed Q5 polish. Docs: `docs/verify/online-greed-VERIFY.md`,
`docs/verify/online-deadweight-VERIFY.md`, `docs/verify/greedbell-shots/`.

- **GREED INC. mirror:** two-instance night (pool=greed, remote seat 1 on
  the tape) — 89/89 snapshot digests matched host↔client, ~927 B median
  snapshots (~18.5 kB/s per guest), paired shots read by eye: GRABBED!,
  MINT MUGGED GOLD! (with the -2 dash-leak flash on both), GOLD BANKS 6!
  (coin rain both screens), and LAST BANKS! with the pot's number caught
  MID-PULSE on both. The grab-hold ring fills smoothly on the mirror (local
  extrapolation at the host's rate) — the 0.6 s tension survives the wire.
- **THE CLOSING BELL (doc 09 §6.1-3):** T-20 "NOBODY HAS BANKED — THE POT
  GROWS RESTLESS" + pot tremble, T-15 "LAST BANKS!" + pot-number pulse +
  grudge sting, T-10 rising tick ladder, and the §6.2 approach drama — a
  15+ pot within 3 m of its own chute strobes that pad at 3 Hz with ticks
  rising +0.06/0.4 s until banked or dropped. Rang at T-15 in BOTH rounds
  of the live online night, and on the guest's screen. Bell facts ride the
  snapshot. `--greedbellcap` films all four beats (staged clock, live code).
- **GREED real keys:** the main hint bar now prints live bindings
  (`Space = GRAB (hold) / TACKLE · E = DASH`), realkeys template; a guest's
  mirror builds the bar from ITS OWN machine's bindings.
- **DEAD WEIGHT mirror (first Jolt-heavy port):** every rigid body freezes
  client-side and puppets from snapshots — 12 furniture transforms with
  slerped quaternions stream, so the POSSESSED ARMCHAIR LUNGE plays in the
  guest's room with the same glow/wobble/sparks (fired locally from
  deltas). 68/68 digests matched; ~2.0 kB snapshots (~41 kB/s per guest —
  fattest mirror yet, still nothing next to video). HOUSE AWAKENS
  candlelight mirrors from one bool. Money-shot pair on film: the
  gold-possessed prop mid-slam, sparks on both screens.
- **Receipts:** `--greedtest=intercept` (3 seeds) and `--dwbalance=20`
  (3 seeds) byte-identical to a pristine-HEAD worktree, re-verified after
  every host-side addition. user:// backed up before any run, prefs staged
  to mg_rounds=2 for short nights, everything restored md5-identical.

DECISIONS ALEX MAY WANT TO REVIEW:
1. **DW stalemate observed on the couch sim itself:** with two input-idle
   humans, bots shove them ONTO the lip and then edge-avoidance refuses to
   finish the job — a full 150 s night with zero deaths. Pre-existing couch
   behavior (not the mirror), documented in the DW VERIFY doc. Worth a
   balance pass: let bots commit past |3.6| when the victim is already on
   the lip, or nudge lip-campers.
2. `--dwevict=N` evidence pin added (séance `--seancechar` precedent): fells
   a seat through the REAL `_fall()` path 1 s into round 1 so probe nights
   always film the poltergeist arc. Loud log line, fenced out of balance
   sims, never set in real play.
3. Ghosts have no possess-cooldown widget on the couch, so the mirror has
   nothing to mirror for it (fighters' shove/hop rings ARE mirrored). If a
   ghost CD ring ever ships couch-side, add one number per ghost row.
4. Windows probe-rig gotcha now documented in the greed VERIFY doc: the
   winget godot shim DETACHES windowed instances from redirected shells and
   parent+child shred a `>`-redirected log. Fix: engine `--log-file` per
   instance (used tonight) or pipe through `cat`.

NEXT (fan-out): tilt/mower/throne are pure-kinematic ports on the same
pattern; swap/echo/orbital/last_will remain of the realtime set; podium
mirroring still the shared phase-3 chore.

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

---

## ESTATE + PACKAGING NIGHT (2026-07-07, Fable) — House Rules card + the ship kit

Two deliverables, both verified on Godot 4.6.2, real user:// saves backed up
and restored byte-identical.

### 1. First-night HOUSE RULES card (estate/estate.gd + estate_state.gd flag)
- On the OPENING auction of a brand-new estate ONLY (games_played 0, run_night
  0, nights_played 0, and never taught before) the Executor delivers a five-line
  economy primer BEFORE the auction: POINTS (the ladder), ♠ GRUDGE (bids + trap
  tiles), ROYALTIES (your traps pay YOU), THE TRAIL (first to the manor
  inherits), THE READING (nightly ledger, nobody flattered). Dry Saki register,
  exclamation-free.
- Seated humans press A to continue (the GET READY chip pattern — PRESS A flips
  to READY). Bots, remote guests, and the shared/mouse seat (-3) are auto-ready.
  A 5s countdown auto-advances so nothing ever stalls.
- Shown ONCE PER SLOT: `house_rules_shown` persists in the slot save (flag-only
  change to estate_state.gd). WIPE & START FRESH resets it (re-teaches a truly
  new estate). Auto-skips for all-bot tables and net clients.
- Regression-safe by construction: `--auctiontest` still PASSes (veteran save
  skips the card; a forced-fresh run auto-advances in 5s and still reaches
  GAME); `--estate --estatebots` fresh soak skips the card entirely (0
  HOUSE_RULES lines, 0 script errors). New windowed proof hook
  `--houserulestest` (self backs-up/restores the slot); screenshot at
  docs/verify/shots/snap_house_rules_0062.png, read by eye.

### 2. The ship package (icon / build script / blurb / name scan)
- ICON: assets/ui/illwill.ico — gold SPADE (grudge currency) on dark-plum
  parchment + LuckiestGuy logotype; 6 layers, spade-only below 48px so it reads
  at 16. Generator build/generate_icon.py (pure Pillow). Wired into
  export_presets.cfg; confirmed embedded in the exported exe (Explorer shows the
  spade). assets/ui/icon.png (256) committed for the runtime icon.
- build/package.ps1 (PS 5.1): import -> export-release Windows Desktop ->
  illwill.exe -> zip {exe + README-FOR-PLAYERS.txt + STORE-BLURB.md} ->
  build/illwill-0.1.0.zip. PROVEN this session (196.94 MB zip). Note the gotcha
  it solves: the plain Godot editor exe detaches, so the script prefers the
  *_console.exe build and polls the exe until its size stabilizes.
- STORE-BLURB.md (repo root): ~150-word house-voice itch.io pitch + feature
  bullets (13 games, persistent estate, vendettas, royalties, couch + online).
- NAME SCAN in docs/design/13-ship-package.md (d): factual list of games / film
  / music / books / brands named "Ill Will" + a strictly-descriptive collision
  summary. NO legal conclusions — that's the attorney-owner's call.

DECISIONS / THINGS TO REVIEW:
1. DIRECTOR ACTION — project.godot (owned by another agent tonight): add under
   [application] to set the RUNTIME window/taskbar icon (export icon only skins
   the .exe file):
     config/icon="res://assets/ui/icon.png"
     config/windows_native_icon="res://assets/ui/illwill.ico"
2. HOUSE_RULES_TIME is 5.0s (the auto-advance/bot cap, per the brief). It is the
   hard ceiling even for humans — they can press A to advance sooner. Bump the
   one const in estate.gd if playtests want more reading time.
3. Package version (0.1.0) is read from export_presets.cfg
   application/file_version — bump there and the zip name follows.
4. NAME SCAN is descriptive only: two released games already carry the exact
   name ("illWill" FPS 2023, "Ill Will" RPG Maker 2012); the name is far more
   crowded outside games (film shorts, Nas's label, Dan Chaon novel, Ill Will
   Press). Your call on what that means.

## 2026-07-07 — GODOTSTEAM PREP (phase-3 transport seam) — netcode transport agent

WHAT LANDED
- Vendored GodotSteam GDExtension 4.20 (Steamworks SDK 1.64, MIT) into
  addons/godotsteam — win64 + linux64 only (18 MB; other platforms re-extract
  from the upstream zip, SHA-256 in the doc). Editor-updater plugin
  deliberately stripped: nothing phones home, version pinned by hand.
- core/net_session.gd grew the transport seam (additive, +213/-7):
  transport="enet"|"steam", steam_available/steam_running/steam_status/
  preferred_transport, host_night_steam() (createLobby -> host_with_lobby),
  join_night_steam() (joinLobby -> connect_to_lobby), overlay-invite
  auto-join (join_requested), open_steam_invite_overlay(),
  --transport=enet|steam CLI, join targets "steam:LOBBYID" / bare 15+
  digits. All Steam access duck-typed (Engine.get_singleton/ClassDB) — the
  file parses and runs identically where Steam does not exist.
- steam_appid.txt = 480 (SpaceWar) at project root, DEV ONLY — never ship it
  next to an exe. NOT exported into the PCK (plain .txt).
- project.godot needed ZERO lines: Godot 4.6 auto-registers .gdextension at
  import (.godot/extension_list.cfg verified).
- docs/design/12-steam-transport.md: research receipts (versions/URLs/API
  signatures verified against upstream repo), seam API, publish-day
  checklist ($100 Steam Direct, appid swap = ONE constant, steamcmd depot,
  RTM), what cannot be tested without Steam + a second account.

RECEIPTS (all green tonight, Steam NOT installed on this machine)
- Import pass clean; extension listed; soak (--estate --estatebots) exit 0,
  zero script errors, ZERO steam output (silent absence proven).
- Invite-code selftest 5/5 PASS (unchanged).
- NETPROBE couch A/B byte-identical AND byte-identical to master baseline —
  the sim is untouched by the seam.
- Two-instance ENet handshake (host+join, both roles rerun): full night,
  NETPROBE_RESULTS identical to couch AND to master's relay run, NETHASH
  27/27 pairs identical.
- --transport=steam --net=host with no Steam: one quiet line, err=2
  fallback to enet host, exit 0, zero errors.

DECISIONS ALEX MAY WANT TO REVIEW
1. CLI --net=host WITHOUT --transport= stays ENet forever (auto-detect
   OFFERS steam via preferred_transport() for the estate UI; it never
   silently switches the CLI) — protects every existing receipt.
2. Vendored only win64+linux64 binaries (18 MB vs 93 MB full).
3. Two-instance-one-machine testing is impossible over Steam transport (one
   client = one SteamID) — ENet keeps that rig forever.

HAZARDS FOUND (pre-existing, estate lane, NOT fixed — out of my lanes)
- Shared user:// two-instance leak, now characterized: if the JOIN instance
  outlives the host's save-restore (kill mid-flight, lingering window), it
  rewrites party_setup.json with remote-seat residue (seat1 device=-99,
  bot=false). The NEXT netprobe run then claims seat 2 and FAILs "no remote
  claim on seat 1". Tonight's first divergent NETPROBE_RESULTS traced to
  exactly this dirty start state — NOT the seam. Antidote: external backup
  of user:// before any netprobe session; ensure seat 1 is a bot in
  party_setup.json. Root-fix candidate for the estate pass: netprobe join
  flow should never PartySetup.save().
- OWNER NOTE: tonight's rig churn rewrote user://party_setup.json a few
  times; final state is self-consistent (seat0 human KBM, seats1-3 bots) but
  your exact pre-tonight seat/device cache was not recoverable. 10-second
  reseat via ESC SEATS. estate_save/cosmetics/slot saves untouched (mtimes
  pre-run).

NEEDS-OWNER (5-minute smoke once Steam is installed + logged in)
  godot --path . -- --transport=steam --net=host
  expect: NET steam up as '<persona>' (appid 480) -> NET steam lobby <id>
  open; shift+tab overlay renders. Full two-account night needs a second
  machine/account. Estate HOST NIGHT UI wiring (preferred_transport(),
  overlay invite button, persona names) = phase-3 estate pass, deliberately
  not touched tonight.

## ONLINE PHASE 2, MIRRORS #2 + #3 — TILT & MOWER MAYHEM (2026-07-07, overnight)

Two more games play online end to end via the séance house pattern
(mirror guard / begin() fence / _net_state()/_net_apply(); estate and
net_session untouched — the generic pump does everything). Receipts in
docs/verify/online-tilt-VERIFY.md + online-mower-VERIFY.md. Handoff note:
this lane's builder hit its usage limit mid-verification; a second agent
picked up the uncommitted worktree, read every diff and netshot cold, ran
the missing mower probe + re-ran ALL couch receipts, and finished the docs.
The work product survived the handoff intact — nothing had to be rebuilt.

TILT (probe night was already run; verified + documented):
- Full 2-round match with a remote seat 1: sudden death both rounds, a real
  OVERTIME, 9 gull bombs from the fallen remote player over the wire, and
  "MINT WINS TILT!" mirrored to the letter. Match-end screenshot pair is
  functionally identical down to the two gulls hovering off the east rim.
- The platter tilt vector is the whole game and it mirrors beautifully: a
  60 fps exponential chase of a 20 Hz snapshot lands on the host's frame
  (tilting pair read by eye — same disc attitude, same pawns, same timer).
- NETHASH_MOD 29/29 delivered digests matched (one datagram dropped — seq
  960 — and the counters-not-events pattern absorbed it invisibly, which is
  the whole argument for the pattern). ~1 kB snapshots → ≈21 kB/s per guest.

MOWER (probe run + verified this session):
- THE GRID DECISION, for review: the 64x48 lawn rides the wire as ONE
  deflate-compressed full grid at 10 Hz (latest-wins) instead of diffs or
  paint events. Reason: full-state is self-healing by construction (a drop
  costs 100 ms of freshness, never a permanently lost cell — diffs/events
  on an unreliable channel need ack/repair layers). Measured: 3072 raw
  cells deflate to 53 B (fresh) – 435 B (peak mix). Grid adds ~3.9 kB/s;
  whole game ≈14.5 kB/s per guest — CHEAPER than tilt, lawn included.
- The lawn pair read by eye: cell-for-cell identical stripes on both
  screens mid-match, and the mirror's scoreboard percentages (41/21/11/9)
  are RE-DERIVED from its own applied grid through couch coverage_pct —
  same numbers because same cells. MOWGRID digests 15/15 matched.
- The Splatoon tally ceremony is NOT streamed: the mirror gets placements +
  the final grid and stages the whole reveal locally (camera pull, count-up,
  stamp). Screenshot pairs: both screens frozen at "RED 14%" mid-count-up,
  both closing on "MINT TAKES THE LAWN! 43%".

COUCH DETERMINISM, RE-RUN COLD AT FINAL CODE STATE (pristine d0a1f18
worktree vs this tree, fresh runs): tilt idle/edge/gull PASS byte-identical,
tilt 3-round soak 236 TILT_EVT + KILL_EVENTS byte-identical, mower covtest
sum=100.0000% PASS + soak sim-identical (KILL_EVENTS n=16 both; only
wall-clock perf telemetry differs). Transport provably touched nothing.
One doc claim corrected during verification: the draft said "17 kill_events"
— every log (including the original builder's own) says 16.

WORTH KNOWING (shared dev machine, overnight fleet):
- The probe pair shares one user:// and BOTH instances run the .npbak
  dance; the later quitter can re-land the staged party (party_setup came
  back with seat 1 human). The outer md5 backup/restore caught it —
  that outer backup is house law for a reason.
- Four neighbour lanes were live during this session (greed probe, throne
  balance, par, understudy). Nothing was killed blindly; the mower probe
  waited for the greed pair to drain and used private port 9412 + the
  g_aa41 private binary name, per the anti-fratricide notes in the tilt doc.

STILL OPEN (unchanged phase-2/3 chores): podium not mirrored (spectate
card), local echo v1 none, killcam-skip gating for games that have one.

================================================================================
2026-07-07 — PAR v4 WAVES 2+3: LIVE CHAOS GRIEFING + THE WIDOW'S WALK
(flagship builder; branch worktree-agent-a17949b6b8362a717, commits b7582ab +
e84199c + verify doc; docs/verify/par-v4-wave23-VERIFY.md has all receipts)
================================================================================

WHAT SHIPPED:
- WAVE 2 — your day-one wish, live griefing in chaos: all four characters are
  ON the course during the chaos round. Pads/kb-halves/KBM direct-control
  their griefer (MOVE, A=SHOVE with the full HIT KIT feel, B=HOP over the
  knee-high walls — or, standing at a powered trap, TRIGGER it early: crusher
  slams NOW, fan gusts, bumper kicks, windmill lurches). Pure-mouse seats
  auto-grief via a seeded seek-bot; their own shots stay mouse. Shoving the
  golfer mid-shot flinches the SHOT: aiming = staggered (no stroke lost), a
  live charge fires immediately with a 13-degree jolt. Griefing pays GRUDGE +
  a "GRIEFED" highlight — never points. Cup has a hard exclusion disc (no
  camping the hole, receipt: probe walked at the cup for 10s, held at 1.24m
  vs the 1.30m ring). Dead players' characters get back up and keep griefing.
- THE INVARIANT HELD, ADAPTED PER YOUR NOTE: avatars still never touch balls
  (wave-1 collision exceptions permanent). Ball paths v3-vs-embodied are
  still BYTE-identical to 0.1mm (old fairway, scaled fairway, and the
  widow's walk chasm line, tick-aligned).
- WAVE 3 — five courses now: fairway x1.4 (8x29, hop-over walk aprons),
  dogleg x1.4 (elbow cut-corner deck), green 16x16, gauntlet + raised north
  catwalk, and THE WIDOW'S WALK: 9x30 spine, mausoleum on the tee meadow, a
  3m chasm with a 2.5m land bridge (miss = gutter channel that delivers
  NEAR but not AT the green; shoved characters fall in — "X SHOVED Y INTO
  THE CHASM"), switchback around a second monument, elevated green ringed by
  a knee-high wall with a funnel-banked ramp mouth, catwalk highways down
  both flanks. Random course draw + --course= include it.
- Real-keys bars in par per your tester's note: putt bar shows the CURRENT
  seat's live verbs ("AIM: MOUSE - HOLD LMB..." / "AIM: W/A/S/D - HOLD
  Space..."), chaos bar merges the griefers' real keys.

RECEIPTS (all in the VERIFY doc, screenshots read by eye):
- Wave-2 exit criterion DONE: bot cadence now counts PHYSICS TICKS (was
  wall-clock). Same-seed 4-round bot matches, run twice: every stroke, grief
  action, death and result BYTE-IDENTICAL (fairway 328/168 lines, widow's
  231). Receipt harness = --fixed-fps 60.
- 8 full matches to MATCH_OVER, zero script errors (fairway/dogleg/widow's
  x2 seeds + green + gauntlet). Estate boot + killcam + import clean.

DECISIONS ALEX MAY WANT TO REVIEW:
1. Spec's wave-2 ball-contact verbs (body-block/shove the BALL) were replaced
   by avatar-vs-avatar per your directive; the trap early-trigger survived on
   the B button (hop when not at a trap). Trap trigger zones are distance-
   based (footprint + 1m), not the spec's GriefTrigger Areas — same behavior,
   no trap-scene surgery.
2. Flinch penalty design (spec left it open): stagger at address (no stroke
   lost), instant fire + 13-degree deflection mid-charge, deflection
   mid-swing; 1.2s immunity so chain-stuns can't lock a seat. Numbers all
   feed the same frozen debug_putt.
3. Bots got one new heuristic: elevation-aware putt power (sqrt(2g*climb)
   boost) so they can buy the widow's ramp — without it a full bot match
   ended 0-0-0-0 (nobody could climb). Same rng draw count, sim untouched.
4. Chaos stays on the overview camera (readability with 4 live balls), so
   brawls read small at flagship scale — if you want hero shots of shoves,
   a punch-in chaos cam is a v5 polish candidate.
5. Widow's walk gutter delivers at the ramp mouth centerline (0,-11.8) —
   generous, but bots and humans both need the funnel; move it off-axis if
   playtests say the gutter line is too kind.

NEXT: your hands on the couch — grief feel (shove/hop on pads), whether the
chasm reads as fair, and whether the flagship's bot DNF rate (higher by
design) plays as drama or drag.

## ONLINE PHASE 2, MIRROR — MASKED BALL, the privacy case (2026-07-07, overnight)

The identity-hiding game plays online end to end via the house pattern
(mirror guard / begin() fence / _net_state()/_net_apply()/_mirror_tick();
estate + net_session untouched). Receipts: docs/verify/online-maskedball-
VERIFY.md, two probe nights, logs + windowed shot pairs read by eye.

THE PRIVACY VERDICT (the reason this lane existed): the snapshot leaks NO
seat->dancer mapping. Field-by-field audit in the doc; the shape of it:
- The 20-dancer block is BODY-indexed (one PackedInt32Array, 7 quantized
  ints per body); player and NPC bodies stream identical fields at identical
  precision. Glints ride ONE untagged per-body counter — feather pulses,
  NPC decoys and kill lunges are indistinguishable on the wire.
- seat<->body pairs exist ONLY in cumulative reveal/waste rows, each minted
  at the frame the couch prints the same badge. The client's rng_seed is 0
  (estate mirror contract), so the seeded deal can't be recomputed; the
  mirror's _body_of stays EMPTY — pre-reveal, the mapping does not exist in
  client memory at all.
- send_module_private: NOT USED, and that's the finding. The couch has no
  private beat — the glint is public; only its CORRELATION with your own
  hidden stick means anything, and a correlation with your own hands is a
  secret no packet can carry. The seance proved hidden info gets BETTER
  online; masked ball proves the dual: when the secret is a correlation,
  honest mirroring preserves it with zero machinery. The privacy core of
  this port is a list of things NOT sent.
- Honest delta, on the record: PERFECT RECALL. A packet logger remembers
  public facts better than couch eyes (e.g. decoy glints are never <2.0s
  apart while the feather cd is 1.4s — sustained feathering is provably
  human to a tool, and merely noticeable to a couch). No new facts, better
  memory of published ones. Friends-lobby trust posture per spec.

THE FEATHER-GLINT CROSSED THE WIRE, MEASURED: probe client feathered 0.30
for 8s -> host MB_GLINT seat=1 body=13 at 13.0/14.4/15.8/17.2/18.6/20.0
(exact 1.4s GLINT_CD cadence off relayed analog input) -> client rendered
glints on body 13 at 13.1/14.4/15.8/17.2/18.6/20.1 — 6/6 pairs, worst skew
one snapshot beat — buried among 37 decoy glints in the same window.

PROBE RIG NOTE (new trick, reusable): the NETPROBE tape can't feather (unit
moves only), so the join ran WITHOUT --nettape and the mirror drove its own
seat via PlayerInput.set_remote_state — the _dbg_aim seam, networked — so
NetSession's real 30 Hz sampler streamed genuine packets (stroll, feather,
B mark, curtsies). Lobby READY handled by the probe's 30s timeout, the GET
READY gate by its own 15s countdown: estate-standard paths, zero edits.
The remote's B unmasked MINT at t=23 across the wire, it scored 3 real
curtsies via injected strolls, WON the ball (16 pts) and took the "BLUE,
Belle of the Ball" monument — a remote player winning the social game is
the best liveness receipt this lane could have produced.

FIX FOUND BY THE PROBE: report_finished() kills the 20 Hz pump the same
tick, so a champ fact set in _finish_match never reaches mirrors — night 1's
client missed the confetti. Pattern note for later lanes: any fact minted in
the same tick as finished() must be PRE-ANNOUNCED a beat earlier (masked
ball now sets champ at reveal t_end+0.4s; couch byte-identity re-verified).

NUMBERS: NETHASH_MOD 48/48 + 47/47 digest pairs identical across the two
nights; walker channel 162/162; snapshots median 1372 B (max 1796 at the
ledger beat) ~= 27 kB/s per guest at 20 Hz — the dancer block ships as a
pre-quantized PackedInt32Array (cm/mrad), the brief's "quantized positions"
taken up front. Couch --mbtally seeds 1/2/3: FULL logs byte-identical to
pristine HEAD (d36154f), re-diffed after the last edit. Regressions:
import clean, AUCTIONTEST PASS (against a fresh slot — the saved run sits
at a night-5 boundary and parks --auctiontest on the resume card; slot set
aside and restored by hash), estatebots + strolltest zero script errors.
user:// 5-file md5 backup/restore verified; private port 9473 + private
binary name per the anti-fratricide house notes; no foreign PIDs touched.

STILL OPEN (unchanged): podium not mirrored (champ beat on the mirror is
~0.5s of confetti before the fold), mirror hint bar shows the generic
legend, keyboard couch players can't feather (binary move — pre-existing
couch reality, pads only; unchanged online).

================================================================
FINAL STRETCH + DECIDING MOMENT (AAA queue Q1+Q2, the last two items)
game-feel agent, overnight — for Alex's review
================================================================

WHAT SHIPPED (all presentation; receipts byte-identical, see
docs/verify/finalstretch-VERIFY.md):

- core/final_stretch.gd — THE FINAL STRETCH kit. One shared helper: the
  anthology finally PLAYS your music. game_light under every timed game,
  crossfade to game_tense at each game's own threshold, a warm-red screen-
  edge nudge, last-10s rising tick ladder (exact-pitch pool, greed's bell
  cadence generalized) + timer pulse. Wired into NINE games: tilt (sudden
  death), mower (OT — the sting its VERIFY always claimed), greed (the
  CLOSING BELL brings the tense track; bell keeps its own ticks, no
  double-trigger), throne (succession crisis), orbital (NEW T-30 "FINAL
  ORBIT" beat + Executor line + starfield 20% toward red), swap (final
  lap + distance tick ladder over the last 10%), echo (round 5 plays
  tense start-to-finish, "THE ESTATE COLLECTS ITS ECHOES"), dead_weight
  (HOUSE AWAKENS), last_will (the final race plays tense; Executor:
  "The final race. The estate settles all accounts tonight.").
- All five mirrored games fire it CLIENT-side from facts already on the
  wire (sd/ot/bell/hot/aw + clocks). Snapshots grew by zero bytes.
- THE DECIDING MOMENT (Q2): deep slow-mo is now RESERVED. Ordinary deaths
  demoted to 0.5x/0.2s in tilt/dead_weight/last_will (echo was already
  compliant); the round/match-DECIDING kill promotes to 0.25x for
  0.8-0.9s + a real-time fov punch (-5/-6) + a name banner ("LAST ONE
  STANDING" in DW, "THE DYING SECONDS CLAIM X" in echo round-5 endings).
  Throne got doc 09 §9.3's exact call: dethrone keeps its 0.2x/0.6s crown
  tumble and gains the synced 49->44->49 punch (host + mirror).
  Reduced-motion: punches no-op, freezes fall back to the demoted beat.

JUDGMENT CALLS (flag if you disagree):
1. Where a game already had a bespoke endgame beat, the kit added ONLY
   music + nudge + pulse (doc 09's reconciliation rule) — no second
   banner, no second tick ladder. Greed's kit ticks are OFF by option.
2. Echo's "deciding kill" = any KO in round 5's last 10s (no time to
   answer it). With respawns there is no literal last-one-standing there.
3. Last will's fov punch is the will theater's existing -6 beat — the
   deep freeze slots under it; no second camera move added.
4. tilt tests still call the demoted slow-mo (receipts unaffected,
   tick-driven) — deciding promotion is fenced out of --tilttest.

RECEIPTS: 9 harnesses byte-diffed vs a git-stash baseline (tilttest x3,
covtest, willtally, thronebalancefast, greedtest, mbtally, dwbalance=20
seed 1 still LIVING WIN 65.0%). Six raw-identical; mower/dw/lw differ
only in wall-clock perf ms + Godot exit-noise lines (proven run-to-run
noise on identical code; sim lines byte-identical). Full 4-bot matches
to finished() in all nine touched games, 0 script errors. Estate boot
smoke clean. Windowed stills read by eye in docs/verify/
finalstretch-shots/: final stretch in greed/tilt/orbital/dw/echo,
deciding freeze in tilt/dw/echo (fov punch visibly IN on all three).

WITH THE REAL TRACKS IN assets/music/, THIS IS THE WAVE WHERE THE WHOLE
ANTHOLOGY LIGHTS UP AT ONCE — the kit was a no-op until your soundtrack
landed; now every game's last seconds are heard.

================================================================
2026-07-07 — ONLINE MIRRORS, THE FINAL PAIR: ORBITAL + LAST WILL
(online-mirror agent; branch worktree-agent-ac940a8125f5036c9)
================================================================

WHAT LANDED: the last two game mirrors. Every game in the anthology
except par now plays across the wire — a guest's screen runs the real
scene as a render mirror while the host owns every fact.

- ORBITAL: the whole threat ladder crossed for FREE — heat glow, trail
  burn, threat tones and the danger vignette are all derived from ball
  VELOCITY, which is exactly what the snapshot carries. Balls dead-reckon
  between 20 Hz beats; the aim preview reads the mirrored basis frame;
  the hold-fill charge advances locally like greed's grab. The probe's
  remote seat STOLE an 11-second orbit out of the sky, threw it back and
  killed GOLD with it — catch, throw, kill, all over the relay.
- LAST WILL: the course's MEMORY is the payload. The active curse set
  (slot + kind + author + side seed) streams complete every snapshot, so
  a curse installing mid-race rises on the client with its author color
  and NAME PLAQUE, and a late-booting mirror rebuilds the whole accreted
  road. The 6s WILL DRAFT freeze stops BOTH screens; the draft is public
  on the couch (one shared screen), so the mirror shows the same cards/
  cursor/clock honestly — zero private sends. The probe night accreted
  a FULL nine-curse slate; the dead remote player drafted three wills
  and gusted the living 3x from the pew.

JUDGMENT CALLS (flag if you disagree):
1. Orbital defers report_finished by 0.45s (couch podium arrives half a
   beat later) so END/champ/banner facts reach mirrors — the masked-ball
   lesson, applied at the source. Prints stay inline; receipts identical.
2. Last will pre-announces the champ 0.4s early via the RACE_END
   sequencer (totals are final at _end_race), and mirrors build the win
   banner locally — the host's own banner is minted the same tick as
   report_finished and can never arrive.
3. LW boulders/gusts REPLAY locally from spawn facts (deterministic over
   static geometry) instead of streaming transforms; squish is fenced on
   mirrors (deaths are host facts). Drift bound: one snapshot beat,
   nudged.
4. Probe nights ran with a STAGED party_setup.json (live save had seats
   0+1 human, which parks a joiner on seat 2 while the rig watches seat
   1). Original restored + md5-verified after.

RECEIPTS: --orbbots and --willtally seeds 1/2/3 byte-identical to a
pristine HEAD worktree (only known run-to-run engine exit-noise wobble,
seen on both trees). Two probe nights, zero script errors in all four
logs; NETHASH_MOD 82/82 + 82/82 digest pairs, walkers 200/200 + 200/200.
Bandwidth: orbital ~33 kB/s/guest, last will ~51 kB/s/guest (the fattest
mirror yet — it carries the whole road). Paired windowed shots read by
eye: orbital top-heat + catch + FINAL ORBIT pairs near pixel-identical;
last will draft pair pixel-identical, curse pair with the ▲ BLUE plaque
legible on the client, crypt-finish pair one story from two cameras.
Docs: docs/verify/online-orbital-VERIFY.md, online-lastwill-VERIFY.md.
Estate smoke + auctiontest + strolltest clean; import clean.

THE MILESTONE: with these two, ONLINE PHASE 2 GAME COVERAGE IS COMPLETE
— 13 of 13 non-par games mirror across the wire. What remains online is
ceremony polish (podium mirroring) and par itself.

================================================================
ONLINE MIRRORS: ECHO CHAMBER + SWAP MEET (the last arena pair)
online-mirror agent, overnight — for Alex's review
================================================================

WHAT SHIPPED (house pattern, spec 10 §4.3; net_session/estate untouched):

- ECHO CHAMBER mirror (echo_chamber.gd +~330, fighter.gd +45, ghost.gd
  +18). The call that defines the port: GHOSTS ARE STREAMED, NOT
  RE-SIMULATED — fighters and ghosts share one body-indexed
  PackedInt32Array (stride 8, cm/mrad), so the mirror renders exactly the
  poses the host's replayer computed. Zero drift risk, measured cost 32 B
  per ghost per snapshot (12-ghost cap ≈ 7.7 kB/s of the ~14 kB/s total —
  half the seance's footprint). Parry/bounty/self-haunt/deciding-moment
  ride counters; banners ride text facts; ring warning blinks at 4 Hz
  from a LOCAL clock (only the steady flag rides the wire, so the alarm
  can't alias against 20 Hz); shrink rides a flag edge into the shared
  _shrink_fx().
- SWAP MEET mirror (swap_meet.gd +~400, swap_kart +8, swap_orb +1). Karts
  stride-12 in one int block INCLUDING progress/finished/place — so
  _positions_list, the ladder HUD, the lap label and the FINAL STRETCH
  distance ladder run client-side through the same functions the host
  runs. Orbs id-keyed; SWAP ritual (both beam positions) + PHOTO FINISH
  (winner/chaser/delta) + knocks/thuds/gates/claims/stings ride counters;
  banner+event line replay the couch's own flashers off [gen,text] facts.
  ~20 kB/s per guest.
- Lesson 1 applied (facts minted the tick of report_finished never reach
  mirrors): echo pre-announces the champ and defers ONLY the report emit
  by 0.5 s (prints stay same-tick; couch gains 0.5 s of winner tableau the
  estate used to cut off at frame one). Swap needed nothing — its END
  already reports 1.8 s late; verified the champ fact landed pre-fold both
  nights. Photo-finish facts are minted mid-race, structurally safe.
- Lesson 2 applied: FinalStretch fires client-side from facts the HUD
  already carries (echo rn/rmax/rem; swap fl flip + progress). Zero extra
  bytes.

RECEIPTS:
- Echo probe nights (port 9617, private binary g_es93): night 2 canonical.
  61/61 received digests identical (1 of 62 sampled snapshots dropped in
  flight — the unreliable channel doing its job; night 1: 62/62). The
  REMOTE seat was KILLED BY ITS OWN ECHO in round 2 — the irony banner
  pair is in echo_netshots_* read at the same timer tick. r5 pair: both
  screens at 25.0, GHOSTS: 9, echo-for-echo identical. Ghost-drift assert
  0.000000 through the online night itself.
- Swap probe nights: 78/78 + 5/5 digests. Organic 3-lap night (remote kart
  steered + THREW ORBS over the wire, overtakes/golden/final-lap all
  mirrored) + a --swapnetdemo night for the money shot: genuine
  PHOTO FINISH through the real _finish_kart path — both screens frozen at
  0:02 with GOLD & MINT pinned at the line, mirror caught mid-flashbulb —
  plus one scripted orb drop for the SWAPPED! beam pair.
- Couch: swap event logs byte-identical to pristine HEAD (seeds 1/2/11;
  seed-1 "diff" is Godot's flaky exit-time ObjectDB warning, present on
  pristine reruns too). --swaptest=immunity re-run PASS after the one
  shared-hook touch (_drop_orb_on now leads a moving target in the
  victim's frame; parked test karts have speed 0 — byte-unchanged).

JUDGMENT CALLS (flag if you disagree):
1. ECHO'S COUCH BASELINE IS NOT CROSS-RUN REPRODUCIBLE — ON PRISTINE HEAD.
   Two sequential pristine runs of the same seed diverge from ~round 3
   (real CharacterBody3D physics; chaotic amplification). I did NOT chase
   it: it predates this lane, echo's own receipts only ever claimed
   within-run ghost determinism, and swap (hand-integrated) diffs clean.
   Receipt shape for echo: control diffs (pristine-vs-pristine noise
   floor) + structural invariants (ghost ramp 0/4/8/12, all
   ECHO_DETERMINISM 0.000000, ECHO_SHRINK tick-exact t=2.26 both trees) +
   the armed assert. Documented prominently in online-echo-VERIFY.md.
   Worth a future lane if you want echo bot-replays byte-stable.
2. Echo's 0.5 s report deferral is a real (tiny) couch timing change —
   the only sim-adjacent edit in either lane. Alternative was a champ the
   client never sees. masked_ball precedent, but echo's couch gains the
   pause too since its report was same-tick with the tableau.
3. --swapnetdemo (photo-dash restage + one scripted drop) is a probe rig
   behind its flag, mb-netdemo precedent. The organic night produced 50
   throws / 0 connects (sparse 2-bot traffic) — real tables bring their
   own traffic; I did not inflate bot aggression to force it.
4. Mirror does not reproduce tick-counted freezes (swap hit-stop/photo
   freeze) or echo's slow-mo dips — frozen host karts read as frozen
   through the stream; a mirror stalling its own clock would fight the
   snapshots. Throne precedent.

Docs: online-echo-VERIFY.md + online-swap-VERIFY.md (+ committed probe
logs and windowed snap pairs). user:// backed up/restored, md5s
re-verified, no .npbak leftovers, only my own PIDs touched.

================================================================================
NIGHT 5 — B6 (GHOST MEDDLING): dead humans get one attributed verb
================================================================================

Doc 24 §6 doctrine made real: an eliminated HUMAN seat becomes a colour-tinted
WISP (name + cooldown ring + "MEDDLE READY") for its respawn window and gets ONE
small, safe, ATTRIBUTED verb on A. Harvested the predecessor's never-committed
core/ghost_meddle.gd, reviewed it against the live tree — compiled clean, ZERO
fixes needed; every API it calls verified (CooldownRing, PlayerBadge.glyph,
PlayerInput.get_move/just_pressed/get_aim_dir/get_aim_stick/describe_binding,
PartySetup.pref, NetSession.my_seat, Sfx via CooldownRing). Committed the kit
alone first (a52896e).

WIRED 2 GAMES (echo_chamber + orbital) — the ONLY two that qualify. Exhaustive
survey: 4 games already own a dead-seat actor (dead_weight/poltergeist,
last_will/lw_ghost, masked_ball/mb_ghost, tilt/seagull — left alone); the other 8
(greed, mower, throne, swap_meet, seance, understudy, pallbearers, widows_gaze)
have NO respawn queue + NO eliminated flag — only brief stuns/knockdowns of still-
EMBODIED players (greed 1s, mower spin_out, throne dethrone) or no death at all,
so a wisp would break the fiction and double-represent a live body. echo_chamber
+ orbital are the only games with a genuine temporary-dead (respawn-queue) window
and no mechanic. Quality over count — I did not force wisps where the doctrine
("eliminated players become poltergeists") doesn't hold.

- echo_chamber (3e39948): SIM meddle "STIRRED A COLD DRAFT" — a 0.22s spectral
  STAGGER of the living within 3.2m. Stagger adds NO velocity => can't ring
  anyone out; skips a fighter already over the ring => never decides a death in
  progress. Rides the fighter snapshot to mirrors, no new net messages. Wired on
  both the sim path (_on_death/_process_respawns) and the mirror alive-edge.
- orbital (a7c2120): PRESENTATION-only "RATTLED THE VOID" — a cosmetic spectral
  pulse. In an all-balls-are-lethal arena a sim nudge could KILL, so the meddle
  touches no ball/score/kill/sim-rng; each screen renders its own. Fixed-hover
  wisp (drift=false) at the death spot.
- Kit fix (2635bac): drift=false now truly holds the FULL 3D death spot (spawn_at
  was force-setting y=hover_y + a floor-plane ring — flat-floor assumptions that
  detached the wisp in orbital's radial world). drift=true path byte-unchanged.

RECEIPT-SAFE BY CONSTRUCTION: a wisp is raised ONLY for a non-bot seat
(not fighters[i].is_bot / not bot_enabled[i]), so all-bot CLI runs never build one
and never call the meddle handler. Verified byte-identical vs pre-meddle HEAD:
- echo: 5x ECHO_DETERMINISM max_err=0.000000 + ECHO_MATCH_OVER champ=BLUE
  placements=[1,3,0,2] IDENTICAL before/after (--echobots --echofast=3 --seed=1).
  The bounty-kill line ORDER jitters +/-1 run-to-run — this is the pre-existing
  echo couch chaos already flagged in this file (real CharacterBody3D physics,
  diverges from ~round 3); the mode-independent invariants are exact.
- orbital: KILL/HOP log + ORBITAL_RESULTS placements=[3,0,2,1]
  points={0:13,1:6,2:10,3:14} + ORBITAL_ASSERT PASS all BYTE-IDENTICAL (orbital
  never touches Engine.time_scale, so it's fully deterministic; --orbbots --seed=7
  --fast=10 --autoquit). Zero ORB_MEDDLE lines both trees.

Live-wisp screenshots via gated dev flags (--echomeddleshot / --orbmeddleshot,
windowed, OFF in every receipt path; _ring_test / --orbtest precedent):
verify_out/echo_meddle_wisp.png (RED wisp, killed seat reads RED 0) +
verify_out/orbital_meddle_wisp.png (RED fixed-hover wisp against the stars).

JUDGMENT CALLS (flag if you disagree):
1. Only 2 games wired, not the "2-4 more" the brief hoped for. The codebase
   honestly only has 2 qualifying games (survey above). Forcing a 3rd into a
   stun/knockdown game would violate MISCHIEF-NOT-MURDER and put a ghost next to
   a still-alive body. Held the line on doctrine + quality.
2. echo's meddle is a stagger (interrupts an action) — the one sim-touching
   verb. Guarded so it can never ring-out or touch a death-in-progress, kept to
   0.22s (a flinch). If you'd rather the dead never touch the living at all,
   swap it to presentation-only like orbital (one-line change of the handler +
   presentation_only=true). I judged a felt "haunting" worth the tiny reach.
3. For a SIM meddle online, the attribution toast + gust sfx fire host-side only
   (the remote guest sees the stagger via the pose stream, not their own toast).
   Pre-accepted by the kit's SIM-vs-presentation split; no new net messages, per
   the brief. Couch (primary mode) shows everything.
4. Added two gated dev capture flags to the shipping game files (echo/orbital).
   Precedent: _ring_test, --orbtest, --aimprobe. Never in a receipt path;
   re-ran both receipts with the flag code present — still byte-identical.

---

## Night 5 — E3 THE RIGGING WAVE (real bones for the graveyard troupe)

Generalized the sanctioned rig trial into `tools/meshy_rig_wave.ps1` (resumable,
manifest-driven, one model at a time, per-model report save; a FAILED animation
is logged not fatal) → `tools/meshy_rig_wave_report.json`.

BIG FINDING worth keeping: Meshy's preset catalog is a PUBLIC json,
`GET https://api.meshy.ai/web/public/animations/resources` (`result.list`, 680
clips: id=action_id, name, key, category, rigType, isFree). The trial only ever
proved rigType `style_01` (Idle id 0). 671 of 680 clips are `style_02` — nearly
every expressive/funeral pose. THIS WAVE PROVED the auto-rig retargets style_02:
Gentlemans Bow (action_id 42, style_02) succeeded on the hooded mourner rig
(clip `Armature|Gentlemans_Bow|baselayer`, 7.30s). So the WHOLE 680-clip library
is reachable from our `/openapi/v1/rigging` output, not just the 4 style_01/biped
freebies. Future troupes/executors can pull Formal Bow 41, Dozing Elderly 38,
Depressed Turn 579, Kneel 365, etc. by id.

NO raking/sweeping preset exists — every "sweep" is martial (Sweep Kick etc.).
So Old Rake keeps his procedural rake prop over a real skeletal idle (honest to
the library). Reported, not faked.

Rigged 3 humanoids (27 cr total: 3 rigs ×5 + 4 anims ×3). Native heights
RECORDED in the report (instance_rigged needs them): groundskeeper 1.8 m,
elderly 1.65 m, hooded 1.75 m. Outputs in assets/models/meshy/generated/:
`npc_groundskeeper_idle`, `npc_mourner_elderly_idle`, `npc_mourner_hooded_idle`,
`npc_mourner_hooded_bow` (.glb). Each extracted an embedded `*_texture_0.png` on
Godot import (butler precedent) — committed with .import sidecars. Same AABB
caveat holds (rigged mesh reads 0.01×0.02×0.01; only `instance_rigged` scaling
is safe).

Wiring (core/ambient_life.gd, presentation only): each member prefers its
animated GLB via new `AmbientLife.rigged_or_null([...], native, target)`, else
the old static+procedural path. Old Rake: rigged idle + kept rake/leaves; his
skeletal loop now FREEZES (speed_scale 0) for the STARE (the stop IS the joke)
and resumes on exit. Mourners: front elder on idle (keeps watch gag), back
hooded prefers the bow (pays respects); the continuous whole-body ghost hover is
GATED OFF on the rigged path (it fought the loop) — shuffle/step-aside/watch
beats kept, both still ghostified. Crows/gull/atmosphere/lantern/door untouched.

Verify: probe `--animate` PROBE_ANIM prints for all 4 clips; windowed estate via
the B3 `--ambienttest` harness with AMBIENT_RIGGED code-path receipts for all 3;
headless import clean; procession seed=7 = `PROCESSION_HEIR BLUE (17 rounds)`
unchanged. Shots: docs/verify/shots/meshy_rig_wave_{audition,audition2,
estate_groundskeeper,estate_queue}.png. Full writeup: docs/verify/meshy-troupe-VERIFY.md.

JUDGMENT CALLS (flag if you disagree):
1. Matched the STATIC target heights the old path used (groundskeeper 1.35,
   mourners 1.32 scene-units) so the swap is invisible — a realistic Meshy human
   at 1.35 reads slightly shorter than the ~1.5 KayKit players, which is fine
   for background NPCs. If you want them player-height, bump those two literals.
2. Hooded mourner wired to the BOW (repeated slow bow = paying respects at a
   grave). If it reads too busy looped, its own idle GLB already ships as the
   one-line fallback (swap the const order in GhostQueue.build).
3. Elderly + groundskeeper on plain Idle (0) — cleanest grief/labor read given
   no dedicated mourning-stand or rake clip. style_02 is now proven, so a
   characterful re-pick (e.g. Dozing Elderly 38) is a report-only change later.

---

## R-C (night 7): load-bearing repo audit for the one-game rework — REPORT ONLY

Full audit: docs/design/research-night7/RC-rework-audit.md (no code touched,
nothing committed, no game runs). Condensed verdicts:

- CLASSIC = auction-minigame night loop + 26-stone trail parade in estate.gd;
  PROCESSION = self-contained 24-loop board scene. The fork is
  estate.gd::_build_play_panel (455/_enter_procession vs 350/_play_pressed).
- ADAPTS: procession.gd (becomes THE game — sequential turns, track w/ splits),
  board_spaces grammar, board_camera (anchors re-derived; over-shoulder = new
  shot), executor host, estate.gd (major surgery), estate_state (save v2).
- SCRAPPED: pawn_putt (→ Madden oscillating slider; keep bot release logic),
  board_path ring topology (→ node graph), auction + side bets + trail/parade
  + trap-tile phase. "Map voting" doesn't exist in code — auction pick-of-3
  and PAR course pick are the analogues; both go.
- SURVIVES AS-IS: all 14 minigames + contract, results_board, podium,
  MomentScribe/newsreel/album, saga_cards (Standing Grudge / eulogy receipt /
  FINAL AUDIT), final_stretch, shake/env kits, cosmetics+wardrobe, walkabout,
  bots rule (roster[i].bot), seance_wheel/roulette theater, mock_game.
- CURRENCIES: 9 resources today; only `legacy` + `run{trail_pos,tollgates}`
  persist. Collapse: SHOP ← grudge ♠ (two unrelated arrays today!), VICTORY ←
  deeds ◆ / points. Keep currency_events type string "grudge" internally
  (else 14 minigame receipts re-freeze); rename display-side via one const.
- SAVE: slot_1's 5 nights live OUTSIDE run{} (monuments/ledger/chronicle.events/
  legacy/wardrobe/statues/graffiti) — loader is get()-tolerant, additive keys
  safe. Migrate legacy 1:1, add "schema":2, never wipe. Bot tests --slot=3.
- RECEIPTS: seed-7 board receipt (meshy-troupe-VERIFY:168, HEIR BLUE/17) dies;
  online-ceremonies, parity-night4, all online-<game> estate bookends, and
  --auctiontest die. All per-minigame receipts survive. Re-found in layers:
  topology → movement → full night → 3-night game → net pair; add a
  tools/run_receipts.ps1 while the list is short.
- TOP 3 RISKS: (1) ring→graph topology cascade (minimap/camera/bots/tolls/
  net_state), (2) estate.gd surgery with the net ceremony mirror woven through
  every phase, (3) currency collapse vs saves + receipt strings.

## P1a — BOARD GRAPH SURGERY LANDED (worktree lane, night 7+1)

The riskiest cut of the rework is in: the 24-ring is gone, THE PROCESSION now
runs LYCHGATE → MANOR GATE over a branching graph. For your review:

- **The board**: 76 stones / 79 edges. GARDEN ROW (safe/long, offerings +
  Peddler's Cart) · HOLLOW WOODS (short/wild, boxes + séances) · WEEPING
  VALLEY (gamble, open graves + Ferryman's Toll). Two crossroads (split +
  mid-track switch), merge before the gate. Walked path 28-32 stones
  (producer's d8 numbers); doc-28 §3 ratios hit within ~1.5 points. ALL of it
  is data — one BOARD dict in board_graph.gd (routes/stones/ratios/anchors).
- **The night**: putt (unchanged pawn_putt) → graph walk → crossroads picks
  (humans: A/B/C prompt, gamepad-first; bots: leader→garden, last→valley,
  25% seeded wildcard) → THE FINAL BELL (first crossing = one last turn for
  everyone else) → arrival order, then distance ranking at turn cap 12.
- **Retired**: Codicil purchase stop (file kept, unwired), --deedgoal/--preset
  flags, player-owned tollgates (Ferryman takes a flat 2 now), vendetta
  stones on the base board (resolution kept dormant for future board data).
- **Receipts** (docs/verify/VERIFY-BOARD.md is the new home):
  - OLD ring record retired in writing: PROCESSION_HEIR MINT (seed 7, 21 rounds).
  - NEW frozen: `godot --headless --path . -- --procession --seed=7
    --turncap=12 --autoplay=bots` → **PROCESSION_HEIR RED (seed 7, 9 rounds)**,
    bell round 8, arrivals RED/GOLD/BLUE, MINT caught 2 out. Deterministic ×3.
  - Topology: `--boardgraphtest` → 76 nodes/79 edges, per-route lengths,
    ratio table, per-node distance-to-finish, fork reachability OK, checksum
    b269c570. Night-independent (LAYOUT rng seeded from board data).
  - Five NAMED rng streams now (LAYOUT/ROLL/EVENT/VOICE/DRAMA) so voice-pool
    edits and future events can't shift each other's receipts.
- **Screenshots**: estate/procession/shots/ — full board, crossroads prompt,
  THE DRIVE route-ribbon minimap.
- **Left for the other lanes**: LAST BREATH meter + d8 (P1b), pennies/wreaths
  + priced cart + arrival wreaths + 3-night loop (P2), estate.gd surgery (P3),
  online pair re-cert (P5). Estate shell still boots clean (smoke-tested);
  slot saves untouched.

## P3 — THE PRESENTATION PASS (worktree lane, night 7+2)

The working game now looks and feels like the game. Playtest-ready. For your
review:

- **Figurine pawns (your locked call, doc 28 §11b)**: the capsules are gone.
  Each seat's real character mesh, frozen mid-idle (a sculpt, never an actor),
  on a round seat-coloured base with a ceramic glaze overlay; wardrobe hats
  carry onto the toy. They HOP stone-to-stone with a dry woody clack
  (impact_wood, quiet — no new audio).
- **Over-shoulder roll camera**: every LAST BREATH roll frames over the
  figurine's shoulder, heatmap percentages glowing down its road. First
  showing eases in; after that it hard-cuts (and B skips a bot's cinematic).
  Release CUTS to the landing area; hold-A fast-forwards the hop tween 3×.
  At the lychgate the shot swings outside the arch posts (the hero model
  swallowed a tight shoulder frame — found on stills, fixed).
- **The thinking budget (doc 28 §9)**: the standings strip is REAL now — and
  note: **P2's chip row never rendered at all** (BOTTOM_WIDE preset grew
  downward off-screen; visible in P2's own committed stills). Fixed, split
  around the meter's lane, and extended: wreath rank, route icon, pennies ¢,
  wreaths ⚘, held-item glyphs (cap 3). THE DRIVE now rides the roll phase
  too, and THE THREE RACES get a compact live tracker (arms at the interim
  reading; capture arms it at the announcement since bot tables skip interim).
- **ZF wave placed**: lychgate + manor_gate heroes at the ends, peddlers_cart
  at the cart, checkpoint shrines at both crossroads + the merge, grave-goods
  coffers, ferryman + skiff at the first valley toll, gravedigger/widow
  idling by their routes. THE REAPER stands DORMANT at the graveyard edge —
  standing sculpt, scythe planted beside him, one faint sickly pool of light.
  He does nothing. He's just... present. (Estate Stirs wakes him later.)
- **Hub simplification**: PLAY is THE PROCESSION only — nights + turn-cap
  dials + GO. Flow: PLAY → seats/lobby → walkabout → READY AT THE LYCHGATE
  (button + a walk-up gate spot) → the match. Classic Nights retired at the
  UI level only; its code sleeps on disk for the excision lane.
- **THE INTERLUDE (doc 28 §2)**: between nights, after the will reading +
  LAST RITES, one grounds minigame — interlude 1 dealt from the night's
  unplayed games, interlude 2 picked by the DOORMAT (bottom wreaths, no
  repeat of interlude 1; bots seeded, humans pure input). Normal settlement.
  **Sanctioned receipt change**: match record re-frozen ×3 — seed 7 → HEIR
  GOLD [36,41,56,43] (was RED [61,32,45,48], superseded and documented);
  seed 1 → BLUE; seed 11 → GOLD, still the LETTERS witness. Single-night +
  topology receipts byte-identical (checksum b269c570 unmoved).
- **The Par adapter is REAL**: catalog launch:"legacy" now does the estate's
  gamestate dance (GameState reset, root placement, finished(results)
  duck-type, EnvKit stands down). Probe: `--parprobe --autoplay=bots` →
  placements [0,3,1,2], exit 0. And real couches now play REAL minigames
  every cycle (soaks keep the deterministic minisim).
- **Screenshots**: estate/procession/shots/p3_*.png — figurines mid-match,
  over-shoulder heatmap, standings+DRIVE, both dressed gates, the dormant
  Reaper, the simplified PLAY panel.

---

## M2 — UI CONSISTENCY PASS (Andrew's playtest, branch worktree-agent-ade5427d0ed690e62)

Four complaints from your friend's playtest, all fixed. No in-game HUDs touched, no receipts moved.

- **The bright green is gone.** The old `assets/ui/theme.tres` green-pill buttons clashed with the
  title door's funeral-stationery look. New `core/ui_kit/stationery.gd` is now the ONE definition of
  the house look (ink panels, gold hairline, IM Fell, gold focus lift), lifted verbatim from
  `estate.gd _style_title_button` (D1). Applied to every front-of-house desk through the shared
  `_clear_panel → _focus_panel_deferred` choke point (PLAY, NEW GAME, MINIGAMES, WARDROBE, HOST/JOIN
  NIGHT, lobby, free roam) plus explicit calls in the SETTINGS overlay and the wardrobe seat row.
  `_style_title_button` now delegates to the kit, so the door and the desks can never drift again.
  Seat-color accents preserved (the wardrobe RED/BLUE/GOLD/MINT swatches keep their colors); L1's
  gold focus ring preserved (the kit's focus box == `UiFocus._RING_GOLD`).
- **No more getting stuck on the podium.** The procession heir crown held a forced 6s. Now, once the
  coronation reads (~1.6s), any seat's A / click / Enter leaves at your leisure — a subtle pulsing
  "A · CONTINUE" with the device's own glyph. All-bot / verify auto-advances on the clock (the
  _fast 0.2s path is untouched, so receipts are safe). `core/podium.gd await_continue()`, wired into
  the procession crown + `Podium.present()`.
- **Hint bars are "always on" now.** Removed the flash-then-hide / N-second declutter from tilt,
  echo_chamber, orbital, swap_meet, greed, widows_gaze, pallbearers. (mower, last_will, understudy,
  throne, dead_weight, seance, masked_ball were already persistent; par is turn-based and surfaces
  its controls per shot.)
- **Instructions match the device each seat holds.** IntroCard was feature-detecting a global
  `InputGlyphs.glyph(seat, action)` that never existed — added the bridge, so all 15 games' intro
  cards now render the glyph for the seat's device (pad button vs KBM key), text fallback via
  describe_binding. Hint bars were already device-aware.

**Verify:** board receipts unmoved — seed 7 → HEIR GOLD [36,41,56,43], boardgraph checksum b269c570.
slot_1.json sha unchanged (autoplay skips the estate save). Import clean; unrelated .import churn reverted.
Screenshots in verify_out/m2 (gitignored): menu_play/settings/wardrobe, game_introcard + game_hintbar
for both kbm & pad, shot_01xx podium with the SPACE · CONTINUE affordance. Re-capture any time with
`--m2shots=kbm|pad --shots=999999 --outdir=verify_out/m2` and `podium_probe.tscn -- --affordance`.
