# 13 — BOARD MODE: Research & Design Brief

*The big add. Playtesters' most consistent ask: "it needs a Mario Party-like
board game loop." Owner approved. This brief researches the genre, isolates the
load-bearing mechanics, and proposes how to build a board loop that ABSORBS
ILL WILL's existing systems (estate trail, auction, will-reading, vendetta,
free-roam, gravestone monuments) rather than bolting a second game on top.*

*No code here. This is the spec-before-the-spec. — Fable, 2026-07-15*

Related prior work (read alongside): `03-board-research-digest.md` (the
loved/resented digest), `the-estate-design.md` (the night loop + simultaneous
phases), `pilgrimage-trail-design.md` (leaderboard-as-terrain — the parade the
board mode promotes into a real loop).

---

## A. RESEARCH DIGEST

### A1. Why the Mario Party loop works — the load-bearing parts

**The two-currency economy is the engine.** Coins are earned constantly (minigames,
blue spaces at +3, [space reference](https://www.mariowiki.com/Space_(Mario_Party_series)));
Stars — the only thing that decides the winner — cost ~20 coins each and sit at a
**single, relocating Star Space** you must physically reach and buy
([Star, MarioWiki](https://www.mariowiki.com/Star_(Mario_Party_series))). The
genius is the *indirection*: you never win by playing well directly, you win by
converting a soft currency into a hard one at a moving target — which means the
lead is always contestable and you can be sabotaged *away from* your goal
(someone steals the Star out from under you, the Star relocates the turn before
you arrive). Two Mario Party titles prove the currency tuning is load-bearing:
Super Mario Party dropped Stars to 10 coins and "coins meant almost nothing,"
which reviewers felt flattened the competition; Superstars restored 20 and the
economy tightened again
([CBR](https://www.cbr.com/mario-party-superstars-better-than-super-mario-party/)).

**Space types are a decision grammar, not decoration.** The board is a menu of
outcomes you steer toward or away from: Blue (+3), Red (−3), Event (board-specific
happening), Item (draw a usable item), Star (buy the win token), Bank (pay 5 on
pass, jackpot on land), Duel (wager coins/Stars 1v1), VS (everyone antes), Bowser
(punishment), Lucky/Unlucky, Chance Time (steal)
([Space, MarioWiki](https://www.mariowiki.com/Space_(Mario_Party_series))). The
*load-bearing* ones are the handful that create a spend/steer decision every turn
(Blue/Red, Item, Star, and a player-facing steal/duel). The rest are flavor.

**The rhythm is the product.** board-turn → minigame → board-turn. The board
supplies pacing, positional drama, and status ("you can SEE who's winning" —
`pilgrimage-trail-design.md`); the minigame supplies the skill spike and the coin
injection. Neither carries a full session alone. Remove the board and you have a
minigame collection; remove the minigame and you have a slow spreadsheet.

**Player-authored persistence used to be here and was loved.** MP5–7 "Orbs" let
players seed spaces with their own traps that fired on rivals later — beloved, then
abandoned by the series (`03-board-research-digest.md`). This is the exact seam
ILL WILL already exploits with author-colored trap tiles and gravestone monuments.

**End-game bonus stars reward non-winning behavior — deliberately.** Bonus Stars
are handed out at match end for feats like most minigames won, most spaces moved,
most coins held, even *most unlucky*
([Bonus Star, MarioWiki](https://www.mariowiki.com/Bonus_Star)). Design intent: a
"puncher's chance" so the whole table stays engaged to the final turn
([Booknibs on rubber-banding](https://booknibs.com/nibs/the-rubber-band-effect-how-catch-up-mechanics-keep-players-engaged)).

### A2. The documented FAILURE modes (and who fixed what)

1. **Downtime — the genre's unsolved sin.** "The time you spend sitting around
   waiting for your turn kills engagement — players check their phones instead of
   plotting" ([BGDF](https://www.bgdf.com/blog/boardgame-downtime)). Standard fix
   is **simultaneous play** — everyone acts at once
   ([LynxLake](https://lynxlakegames.com/2024/05/30/board-game-mechanics-simultaneous-play/),
   [Entrogames: 7 ways to cut downtime](https://entrogames.substack.com/p/7-ways-to-reduce-downtime-in-your)).
   Mario Party never solved it on the board; it merely made turns *shorter*
   (Superstars cut the gimmick cutscenes that "artificially lengthened" turns,
   [CBR](https://www.cbr.com/mario-party-superstars-better-than-super-mario-party/)).
2. **RNG resentment.** Hidden end-game bonus stars are the #1 grievance — "I lost
   because they hand out bonus stars for *failing*"
   ([GameFAQs thread](https://gamefaqs.gamespot.com/boards/323655-mario-party-superstars/79735283));
   "utterly random pitfalls destroy any attempt at strategy"
   ([NeoGAF: why are party games rigged](https://www.neogaf.com/threads/why-are-so-many-party-games-rigged.358625/)).
   Nintendo's own fix is **Jamboree Pro Rules** (2024): bonus star announced *up
   front* (one of Sightseer/Eventful/Slowpoke), the next Star location is shown,
   **Chance Time removed**, hidden blocks removed, lucky spaces reduced to a known
   10 coins, Bowser fixed at −1 Star, Boo fixed at 15 coins, match fixed at 12
   turns ([ScreenRant: how Jamboree fixes luck](https://screenrant.com/mario-party-jamboree-fixes-luck-mechanics/),
   [GamesRadar](https://www.gamesradar.com/games/puzzle/with-super-mario-party-jamboree-nintendos-finally-letting-you-cut-out-the-random-nonsense-thats-defined-its-multiplayer-games-for-decades/)).
   The lesson isn't "remove luck," it's **announce it** — surprise is fine, hidden
   arbitration is not.
3. **Rubber-banding that patronizes.** When catch-up is too heavy the early game
   "feels pointless" — critics call it "Mario Karting"
   ([NeoGAF](https://www.neogaf.com/threads/why-are-so-many-party-games-rigged.358625/)).
   The defensible version is a *legible* puncher's chance, not an invisible hand
   that erases a lead.
4. **Session length.** Superstars: 10 turns ≈ 30 min (tutorial-only), 30 turns ≈
   90 min ([Attack of the Fanboy](https://attackofthefanboy.com/guides/mario-party-superstars-how-many-turns-are-there/),
   [GameFAQs](https://gamefaqs.gamespot.com/boards/189706-nintendo-switch/76934033)).
   The 20–30 turn "real game" is a ~60–90 min commitment — too long for a casual
   sit-down, and the single biggest reason people bounce off.
5. **Late-game currency inflation.** Pummel Party's items get so cheap late that
   swings become noise; and its AI is "binary" — trivial or unbeatable
   ([Gideon's Gaming](https://gideonsgaming.com/pummel-party-review-my-kind-of-party/)).
6. **Elimination feel.** Losing a minigame and then watching everyone else keep
   playing is the anti-pattern; the fix across the field is "loser stays
   economically active" (our grudge economy already does this — `03` digest).

### A3. The modern answer: Koopathlon (Jamboree, 2024)

This is the most important single reference. Koopathlon **deletes dice entirely**:
you play a minigame, your *score* is your movement, and board-advance + minigame
happen **simultaneously via split-screen** for up to 20 players racing laps
([Destructoid hands-on](https://www.destructoid.com/hands-on-super-mario-party-jamboree-preview/),
[Variety](https://variety.com/2024/digital/news/super-mario-party-jamboree-minigames-1236134550/),
[MarioWiki: Jamboree](https://www.mariowiki.com/Super_Mario_Party_Jamboree)). A coin
meter fills to grant an **item you aim at the player ahead of you** (targeted
schadenfreude, no board-space needed). Every third minigame, a 20-player Bowser
"Survivathon" hits *everyone at once*; losers fall back 10–40 spaces by placement.
Net effect: the board loop's dopamine (position, overtakes, sabotage) with **near-zero
downtime** because nobody waits for a dice roll. This is the template ILL WILL should
steal from — and it *already rhymes* with our Pilgrimage Trail (movement = earned,
no dice). The gap the Trail leaves is that it's a *parade/scoreboard*, not a
*decision space*; playtesters want the board to be a place you make choices, not
just a bar that fills. Koopathlon shows you can have both.

### A4. Shorter-session variants (the 20–40 min target)

- **Pummel Party**: literally everything is configurable — min/max dice, which
  items spawn, awards, and **goblets-to-win / turn cap** (set unlimited or set
  low) ([Game Rulesets wiki](https://pummel-party.fandom.com/wiki/Game_Rulesets),
  [Mod Settings](https://workshop.pummelparty.com/wiki/Mod_Settings)). The lesson:
  **ship the length as a dial**, not a fixed number, and default it *short*.
- **Koopathlon**: 5 laps, no per-player dice waiting → fast even at 20 players.
- **100% Orange Juice**: the "Norma" ladder — victory = reach Norma 6, each level
  a fresh *escalating objective* (collect N stars OR win N battles)
  ([Norma wiki](https://100orangejuice.fandom.com/wiki/Norma),
  [user guide](https://fruitbatfactory.com/100orange/userguide2.html)). A rising
  objective ladder gives a natural, legible "how close is the end" read — but OJ
  is still strictly sequential-turn, so it inherits full downtime. Steal the
  *ladder*, not the turn structure.

### A5. Simultaneity vs. schadenfreude (the crux question)

The genre's biggest sin is waiting; ILL WILL's *tone* is sabotage-comedy where
"watching others suffer IS content." These pull opposite directions only if you
parallelize the wrong thing. The insight from the research:

- **Rolling/moving is the boring serial part** (Mario Party makes you watch 3
  other people roll and walk — pure downtime).
- **Landing/consequence is the funny shared part** (the "OHHH he landed on it" beat).

Koopathlon and 100% OJ's simultaneous variants parallelize *everything*, which kills
downtime but also flattens the shared "ohhh" — everyone's heads-down in their own
split-screen. The unexploited sweet spot: **parallelize the roll+move, serialize
the reveal.** Everyone rolls and walks at once (no waiting); then the consequences
resolve in a fast staggered cascade the whole couch watches together. That is the
design lever ILL WILL should pull, and it's the spine of the recommendation below.

---

## B. ESSENTIAL MECHANICS — load-bearing vs. incidental

| Mechanic | Verdict | Why | ILL WILL treatment |
|---|---|---|---|
| Two-currency economy (soft coins → hard Star) | **LOAD-BEARING** | Indirection makes the lead contestable & sabotage-able | Grudge (soft, suffering-funded) → **Deeds** (hard win token) |
| A single **moving** win-target you must reach & buy | **LOAD-BEARING** | Creates the race, the overtake, the "stolen from under you" | Executor plants the next **Codicil/Deed** at a new spot each round |
| board-turn → minigame → board-turn rhythm | **LOAD-BEARING** | Pacing + skill spike + currency injection | Board rounds interleave the 13 anthology games |
| Player-seeded persistent effects (Orbs) | **LOAD-BEARING for US** | Loved in MP5–7, our whole thesis (author-colored traps, monuments) | Grave/trap tiles already exist; landable on the board |
| A player-vs-player steal/duel/toll | **LOAD-BEARING** | Turns the board social; feeds grudge/nemesis | Toll graves, Vendetta duel spaces |
| Announced end-game bonus awards for non-winners | **LOAD-BEARING (if transparent)** | The puncher's chance; keeps the table in it | Will-reading clauses, **announced at night start** |
| Item strategy (hold/aim at leader) | **LOAD-BEARING** | Sabotage agency between minigames | Auction/stall items; Koopathlon-style "aim at the pawn ahead" |
| Transparency of all rules & locations | **LOAD-BEARING** | Pro Rules = Nintendo's own 25-year fix | Our "legible deviousness" pillar; nothing hidden decides |
| Dice as the *sole* movement input | **INCIDENTAL / harmful** | Pure RNG resentment + downtime | Replace with **diegetic, skill-inflected roll acts** |
| Chance Time / hidden blocks / hidden bonus lottery | **INCIDENTAL / harmful** | #1 grievance; Pro Rules deletes them | Never ship a hidden arbiter |
| Sequential per-player turns | **INCIDENTAL / harmful** | Source of all downtime | Simultaneous roll+move |
| 20–30 turn fixed length | **INCIDENTAL / harmful** | 60–90 min bounces players | Ship length as a **dial**, default short |
| Board-specific gimmick cutscenes | **INCIDENTAL** | Superstars cut them to speed turns | Keep Executor beats short |
| Heavy invisible rubber-banding | **INCIDENTAL / harmful** | "Mario Karting" — patronizing | Catch-up only via *legible* suffering→grudge |

---

## C. THREE APPROACHES FOR ILL WILL

All three share one substrate so they can be built as presets of a single engine:
the **estate grounds are the literal board** (a looping carriage drive / funeral
procession road around the manor), players are their KayKit avatars riding pawns,
the **Executor is the dice-master/host** (announces the Codicil, calls the reveals,
reads the will), the **auction/stall is the item shop**, and the **will-reading is
the announced bonus ceremony**. They differ in how much the board is a *decision
space* vs. a *scoreboard*, and in session length.

### Diegetic "roll" — what movement means when everyone has a gamepad + a 3D avatar

Three candidate roll-acts, all performable simultaneously (each player on their own
screen-corner / gamepad), all skill-inflected to drain pure-RNG resentment:

- **PUTT YOUR PAWN** — reuse the *frozen* Par golf putt physics (power/angle meter);
  your pawn is a ball you putt down the drive; distance travelled = your move.
  Skill-based, on-brand (Par for the Curse heritage), zero new physics.
- **SPIN THE PLANCHETTE** — a séance-board roulette (reuse Theater séance UI); more
  luck, more spooky; good for a "cursed" space or a chaos round.
- **SMASH A GRAVESTONE** — timing/power meter; shards scatter = move value.

Recommendation: default to **PUTT** (skill + reuse), with planchette/smash as
space- or event-triggered variants so the "roll verb" itself has texture.

---

### APPROACH A — "THE PROCESSION" *(recommended)*

A full simultaneous board loop. The estate drive is a loop of ~24 spaces. Each
round every player putts their pawn at once, all pawns move at once, consequences
resolve in a staggered cascade. Victory = hold the most **Deeds** when the night's
goal hits. Deeds are bought with **Grudge** at the roving Codicil spot the Executor
relocates each round (the moving Star).

**Space grammar (estate-flavored):**

| Board space | MP analog | Effect |
|---|---|---|
| WEEPING GRAVE | Red / Unlucky | Lose Grudge; if the grave is a *player monument*, its owner collects the toll (vendetta + monument payoff) |
| SHRINE | Blue / Lucky | Gain Grudge or a one-shot blessing |
| THE STALL | Item space | Draw/buy a sabotage item (auction economy) |
| CODICIL | **Star space** | The moving win-target: pay Grudge → claim a **Deed** |
| SÉANCE CIRCLE | Event | A *pre-announced* communal happening (the transparent Chance-Time replacement) |
| TOLLGATE | Bank | Pass = pay the owner; land = collect the pot (from `pilgrimage-trail-design.md`) |
| VENDETTA | Duel | If your Nemesis is within N spaces, trigger a 1v1 wager minigame |

**Turn structure (text diagram):**

```
ROUND (all players simultaneous unless marked):
  [ROLL]   ~8s   4 players putt their pawns AT ONCE (own screen-corner). No waiting.
  [MOVE]   ~5s   All 4 pawns walk their distance AT ONCE; whole-board camera.
  [REVEAL] ~9s   STAGGERED: Executor calls each landing one-by-one -
                 "Player 3 ... the WEEPING GRAVE ... 3 grudge to the Widow."
                 <- this is the shared schadenfreude beat. Parallel move, serial payoff.
  --> every 2nd round: MINIGAME BLOCK
        [AUCTION ~20s] -> [MINIGAME ~90-120s] -> [RECKONING ~25s]
  --> every 3rd round: "THE HOUSE AWAKENS" all-in survivathon (Koopathlon's Bowser
        beat): everyone plays at once; losers slip back on the drive. Announced.

NIGHT END (goal reached OR round cap):
  [WILL-READING ~60-90s] Executor reads the pre-announced clauses, awarding bonus
        Deeds for feats (Most Betrayed / Longest Procession / Bloodiest Hand).
        Whoever holds the most Deeds INHERITS. Estate save written; monuments placed.
```

**Session-length math (4 players):**
- Board round = 8 + 5 + 9 ≈ **22s** (vs. ~2–3 min for 4 sequential MP turns — the
  simultaneity win is ~6–8×).
- Minigame block ≈ 20 + 105 + 25 ≈ **150s**.
- Pattern per "beat" = 2 board rounds (44s) + 1 minigame block (150s) ≈ **194s ≈ 3.2 min**.
- **Short Wake preset** (Deed goal 4, ~4 beats + will-reading): 4×3.2 + 1.5 ≈ **~25 min**.
- **Full Procession** (Deed goal 6, ~6 beats): 6×3.2 + 1.5 ≈ **~35 min**.
- **Long Vigil** (Deed goal 9, ~9 beats + one extra House Awakens): ≈ **~50 min**.
- Length ships as a **dial** (Pummel lesson), default Short Wake.

**Integration map:** estate grounds → the board; Executor → dice-master/host;
Grudge → coins; Deeds → Stars; Codicil → moving Star space; auction/stall → item
shop; will-reading → announced bonus ceremony; monuments/graves → landable
persistent player-seeded spaces (the beloved Orb mechanic, made permanent across
nights); Nemesis → Vendetta duel spaces; Tollgate/Shrine → straight from the
Pilgrimage Trail. **Nothing is replaced; everything is absorbed.** The Pilgrimage
Trail's "movement is earned, no dice" ethos survives — the board just adds the
decision layer (which space, which item, which Deed) the Trail lacked.

---

### APPROACH B — "THE KOOPATHLON WAKE" *(leanest / shortest / lowest new-tech)*

The board is a **status-mirror lap race**, not a decision space. Movement is earned
*entirely* by minigame score (pure Koopathlon). The drive has only a few hazard
graves and blessings; there is no per-round putt and no CODICIL to steer toward —
you advance by playing well, you sabotage via a filling item meter aimed at the
pawn ahead, and every third game "The House Awakens" knocks everyone back. This is
the existing **Pilgrimage Trail promoted with items + a survivathon.**

**Turn structure:**

```
LOOP:
  [MINIGAME ~90-120s]  all 4 play; SCORE = movement (Koopathlon).
  [ADVANCE ~15s]       all pawns walk their earned distance AT ONCE;
                       item-meter grants a sabotage aimed at the leader.
  every 3rd: [HOUSE AWAKENS ~60s] all-in; losers slip back.
FIRST TO THE MANOR GATES (or furthest at cap) INHERITS.
[WILL-READING ~60s] announced bonus Deeds.
```

**Session math (4p):** each loop ≈ 105 + 15 ≈ 2 min; race of ~8 minigames ≈ **~18–22 min**.
Shortest, least new tech (no diegetic-roll system, reuses Trail advancement +
minigame contract). **But:** the board isn't a *place you make choices* — it's a
bar that fills. This may not fully satisfy "we want a Mario Party board loop,"
because MP's soul is the *steer-toward-a-space* decision. Best role: the built-in
**"Quick Wake" preset** and the low-risk first build increment.

**Integration map:** same as A minus the space-decision grammar and the moving
Codicil; Deeds awarded by finish order + will clauses.

---

### APPROACH C — "THE RITES" *(objective-ladder / deepest / most different)*

Steal 100% OJ's **Norma ladder**: a small, dense board; victory = first to complete
an escalating ladder of **Rites** (Rite I: hold 3 Grudge; Rite II: win a Vendetta;
Rite III: claim a Deed; Rite IV: erect a monument; Rite V: reach the Manor). The
will-reading becomes the **norma-check ceremony** — you can only *ascend a Rite* by
stopping at the Manor stoop and having the Executor validate it, which creates a
race to the check-point, not just to the end.

**Turn structure:** closer to classic — sim roll+move, but Rite-checks are
individual stops, so it trends more sequential and **carries more downtime risk**.
~30–45 min. Most strategic, most different from Mario Party's feel, hardest to
keep loud and funny. Best role: a later "campaign/deep" mode, not the flagship.

**Integration map:** Rites ladder is new scaffolding; everything else absorbs as
in A. Higher design risk (the ladder must be legible at a glance or it feels like
homework).

---

## D. RANKED RECOMMENDATION

**1st — APPROACH A "The Procession," shipped with B as its "Quick Wake" preset.**

Rationale:
- **A is the only option that satisfies the literal ask.** Playtesters want a
  *Mario Party board loop* — the decision space, the steer-toward-a-space, the
  moving win-target you can be sabotaged away from. Only A has the load-bearing
  two-currency-plus-moving-target core (Section B). B is a scoreboard; C is a
  puzzle ladder.
- **A answers the genre's #1 sin without losing our tone.** The "parallel roll+move,
  serial reveal" structure (A5) deletes downtime *and* preserves — even
  concentrates — the schadenfreude beat that IS ILL WILL's content. No shipped
  party game does this; it's a genuine wedge.
- **A absorbs every existing system with zero orphans** (integration map). The
  Executor finally has a job every round; the auction becomes the item shop; the
  will-reading becomes the (transparent, Pro-Rules-correct) bonus ceremony; graves
  and monuments become the beloved-but-abandoned MP Orb mechanic, made *permanent
  across nights* — which is our unshipped-anywhere thesis.
- **One engine, three presets = the Pummel configurability lesson for free.** A at
  Deed-goal 4 ≈ 25 min; B (decision layer off) ≈ 20 min; A at goal 9 ≈ 50 min.
  Length is a dial, defaulted short — directly fixing the 60–90 min bounce.
- **Reuse minimizes new tech.** The diegetic roll reuses *frozen* Par putt physics
  and the séance UI; advancement reuses the Pilgrimage Trail parade; spaces reuse
  trap-tile + monument systems. The genuinely new code is: the roving Codicil/Deed
  economy, the staggered-reveal cascade, and the space-effect table.

**Build order:** ship **B first** (it's ~80% existing Trail + minigame contract,
proves the loop and the House-Awakens beat cheaply), then layer A's decision grammar
(putt-roll, spaces, Codicil) on the same engine. C is a post-launch "deep mode"
candidate, not now.

**2nd — B standalone** if scope must be minimal for a first playable; it's a real
improvement over the current parade-only Trail, but under-delivers on "board loop."

**3rd — C**, deferred; interesting, risky, tonally coldest.

---

## E. OPEN QUESTIONS FOR THE OWNER (multiple choice — batch these)

**Q1 — Movement verb (the "dice").**
 (a) PUTT your pawn — reuse frozen golf physics, skill-based *[recommended]*
 (b) SPIN a séance planchette — luck, spooky
 (c) SMASH a gravestone — timing meter
 (d) All three, rotating by space/event

**Q2 — What happens to the Pilgrimage Trail?**
 (a) Board mode *replaces* it
 (b) Keep both; Trail = the "Quick Wake" preset, Procession = full board *[recommended]*
 (c) Keep the Trail as-is; board mode is a separate 4th ceremony

**Q3 — Name of the hard/win currency (the "Star").**
 (a) Deeds  (b) Bequests  (c) Keys to the Manor  (d) other: __________

**Q4 — Default session length.**
 (a) Quick Wake ~20 min  (b) Short Procession ~25 min *[recommended default]*
 (c) Full Procession ~35 min  (d) Let the group set a Deed-goal each night (Pummel-style)

**Q5 — Simultaneity vs. schadenfreude dial.**
 (a) Parallel roll+move, *staggered* reveal — min downtime, keeps the group "ohhh" *[recommended]*
 (b) Parallel roll, *sequential* move+reveal — more schadenfreude, more downtime
 (c) Ship it as a toggle

**Q6 — Nemesis on the board?**
 (a) Yes — Vendetta duel spaces trigger a 1v1 wager when your nemesis is near *[recommended]*
 (b) No — keep duels out of the board loop

**Q7 — Hidden-info stance (sanity check, expected "none").**
 (a) Zero hidden arbiters; every clause/space/Codicil-location announced up front
     (Pro Rules + our "legible deviousness" pillar) *[recommended]*
 (b) One small hidden wrinkle for spice: __________

**Q8 — First build increment.**
 (a) Full Approach A now
 (b) Ship B (reuses Trail) first, then layer A on the same engine *[recommended]*
 (c) Spike the diegetic putt-roll as a standalone prototype before committing

---

*Sources inline throughout Section A. Primary references: Jamboree Pro Rules /
Koopathlon ([ScreenRant](https://screenrant.com/mario-party-jamboree-fixes-luck-mechanics/),
[Destructoid](https://www.destructoid.com/hands-on-super-mario-party-jamboree-preview/),
[MarioWiki](https://www.mariowiki.com/Super_Mario_Party_Jamboree)); space grammar
([MarioWiki](https://www.mariowiki.com/Space_(Mario_Party_series))); bonus-star
grievance ([GameFAQs](https://gamefaqs.gamespot.com/boards/323655-mario-party-superstars/79735283),
[Bonus Star wiki](https://www.mariowiki.com/Bonus_Star)); downtime/simultaneity
([BGDF](https://www.bgdf.com/blog/boardgame-downtime),
[LynxLake](https://lynxlakegames.com/2024/05/30/board-game-mechanics-simultaneous-play/),
[Entrogames](https://entrogames.substack.com/p/7-ways-to-reduce-downtime-in-your));
configurable length ([Pummel wiki](https://pummel-party.fandom.com/wiki/Game_Rulesets));
Norma ladder ([100% OJ wiki](https://100orangejuice.fandom.com/wiki/Norma));
session length ([Attack of the Fanboy](https://attackofthefanboy.com/guides/mario-party-superstars-how-many-turns-are-there/)).*
