# R-A — Board Design Research (Night 7, 2026-07-18)

Research lane **R-A** for ILL WILL's mode merge. Design research + web
synthesis only; **no code touched**. Grounded against the shipped board loop
(`estate/procession/` — `procession.gd`, `board_spaces.gd`, `presets.gd`,
`codicil.gd`) and prior internal research (docs **03**, **13**, **27**, and
**research-night6/R1-board-loop.md**), which this report extends rather than
re-litigates.

## What changed in the producer spec (why this lane exists)

The night-7 spec is a genuine pivot, not a tweak. Three prior conclusions are
now **overturned** and must be re-researched with fresh numbers:

1. **Simultaneity is rescinded.** Docs 13/R1 built the whole loop on "parallel
   putt + staggered reveal" to kill downtime. The new spec says *rolls are
   sequential, over-shoulder camera follows each roll* — i.e. **classic Mario
   Party feel restored**, and with it the genre's #1 sin (downtime) is a live
   problem again. Section 2 addresses this directly.
2. **Victory-by-purchase is scrapped.** The built loop is "first to N Deeds
   wins" (buy Deeds at the Codicil). The new spec **decides the winner
   Mario-Party-style by end-of-game TOTALS** (leftover shop currency + ranked
   arrival awards + minigame placements + specials), **not race position**.
   That is a bonus-star/Pummel-awards model grafted onto an A-to-B race.
3. **The board becomes A-to-B, and first arrival ends the night** — replacing
   the looping star-chase. This is the sharpest design risk in the spec and
   gets its own section (6).

Also scrapped per spec: auction, map voting, player voting. Two currencies
remain (shop + victory), the board is much larger with **2+ route splits**
(graveyards / valleys / woods), fixed hazards / random boxes / powerups /
stores, and NPCs. Player pieces are character minifigs; 3 nights per game.

---

## SECTION 1 — Mario Party board design evolution (MP1 → Jamboree)

### 1a. Topology: branching A-to-B/loop hybrids, never a single track

Mainline Mario Party boards are **branching loops** (or branching A-to-B on a
few boards): a mostly-connected circuit with **junctions/forks** spread through
it so the player is choosing a direction, not just riding a rail. The genre's
own worst-received experiment proves the branching is load-bearing:

- **MP9/MP10 "car" mode** put all four players in one vehicle on a linear
  track with no forks. It is the **single most-hated decision in the series'
  history** — "removes all strategy and autonomy," "you can't diverge off a
  path," "no modification of turns … you're at the mercy of the car." The
  vast majority of the community rejected it. **Lesson for ILL WILL: individual
  pawns + real forks are non-negotiable.** The spec's "character minifigs +
  2+ route splits" is exactly right; do not regress toward a single rail.

Design rule from the community canon: *"Junctions need to be spread throughout
the board to avoid too many turns of players simply rolling with no choices …
The best boards give players something to do at every turn."* Route incentives
are **risk/reward asymmetries**: a **longer, safer route with a shop** vs. a
**shorter, event-dense route** that can swing the game. Good boards make each
region visually distinct and force you to **read opponents' intended path** at
the fork.

### 1b. Space-type ratios — actual per-board counts

Concrete distributions (each board is one closed count, so ratios are exact):

**Yoshi's Tropical Island — original MP1 (55 spaces total):**

| Type | Count | % of board |
|---|---|---|
| Blue (+3 coins) | 34 | 62% |
| Red (−3 coins) | 3 | 5% |
| Happening (event) | 7 | 13% |
| Mini-Game | 4 | 7% |
| Mushroom | 3 | 5% |
| ! / Chance | 2 | 4% |
| Bowser | 2 | 4% |

**Yoshi's Tropical Island — Mario Party Superstars remake (55 spaces total):**

| Type | Count | % of board |
|---|---|---|
| Blue | 23 | 42% |
| Lucky | 11 | 20% |
| Event | 7 | 13% |
| Red | 5 | 9% |
| Bowser | 3 | 5% |
| Item | 3 | 5% |
| VS | 2 | 4% |
| Chance Time | 1 | 2% |

**Koopa's Seasie Soiree — MP4 (~86 spaces):** 43 Blue (50%), 13 Happening
(15%), 13 Mushroom (15%), 4 Fortune, 4 Battle, 4 Bowser, 3 Red (3.5%), 2
Springy.

**Western Land — MP2:** 114 spaces = **largest traditional board in the
series** (useful ceiling for "much larger estate").

**The durable ratio pattern (steal this):**
- **Blue is the floor, and it shrank over 20 years.** 62% (MP1) → 50% (MP4) →
  **42%** (Superstars). Modern design deliberately trades plain "+3" tiles for
  tiles where **something happens**.
- **Red is deliberately rare: 3–9%.** Pure punishment is seasoning, never a
  staple. (ILL WILL currently over-punishes by feel; keep hazards ≤ ~10% of
  stones.)
- **Event/Happening is stable at ~13–15%** across every era — the board's
  personality lives here.
- **"Good-luck" tiles ballooned in modern MP:** Superstars added an **11-tile
  Lucky bucket (20%)** that didn't exist in MP1. The modern lesson is **more
  positive variance, not more punishment** — the table wants upside surprises.
- **Item tiles are lean (~5%)** because items also come from shops; hazards
  (Bowser/Red) sit at ~4–5% each.

Rough target grammar for a large ILL WILL board (~80–110 stones):
**40–50% plain/path, ~15% event(séance), ~15% good-luck(offering), ~8–10%
store+item/box, ~5% hazard(grave), ~5% NPC/toll, remainder forks & special.**

### 1c. Star placement / relocation logic (the moving target)

Classic MP keeps **exactly one active Star space** at a time; a Star costs
**20 coins**; the instant you buy it, the Star **relocates to a different
predetermined spot** (never the one you just bought). That indirection — a
soft currency converted to a hard one **at a moving target you must physically
reach** — is the engine that makes the lead contestable and sabotage-able.
Modern transparency (**Jamboree Pro Rules**) now **shows the next Star
location up front** so the endgame is a legible footrace, not a lottery.

The spec **removes star-buying** (winner by totals). That deletes MP's central
"steer toward a moving thing" decision. **Recommendation: don't lose the moving
target — reassign it.** Make a **roving cache/checkpoint** (a "GRAVE GOODS"
box, a relocating NPC, or the séance) the thing players steer toward each
cycle, so the board still poses "which fork gets me to the good thing first."

### 1d. Item & shop economics — price tiers vs. income

**Mario Party Superstars shop (exact coin prices):**

| Item | Price | Tier |
|---|---|---|
| Mushroom / Cursed Dice / Skeleton Key | 3 | budget |
| Double Dice | 5 | budget |
| Chomp Call / Warp Block | 7 | budget |
| Triple Dice | 10 | mid |
| Custom Dice Block | 12 | mid |
| Plunder Chest (steal an item) | 20 | premium |
| Golden Pipe (warp to the Star) | 25 | premium |
| Hidden-Block Card | 40 | premium |

Tiers: **budget 3–7 / mid 10–12 / premium 20–40.** Income anchors: **Blue
+3/space; minigame winner ≈ 10 coins; Star = 20.** So a Star ≈ **~7 blue
spaces or ~2 minigame wins**, and the **best warp item (25) costs MORE than
the Star it warps you to (20)** — the price *is* the decision. Rubber-banding
is baked into the shop: in **MP2/MP3, "the lower-placed the player and the
later the turn, the more valuable and more numerous the offered items"** — a
legible, opt-in catch-up, not an invisible hand.

**Recommendation:** mirror the ratio, not the numbers. If a minigame win pays
~8–10 shop-coin, price the **best items at ~2 wins (20–25)** and trash items
at ~half a win (3–5). Anything cheaper than ~⅓ of a minigame win becomes an
auto-buy and stops being a decision.

### 1e. Session length vs. turn count

- Superstars: **10 turns ≈ 30 min; 30 turns ≈ 90 min.** Community consensus:
  **30 turns is the "real game."**
- Any 20-turn classic MP game ≈ **~90 min, of which ~50% is spent watching
  other players move** (see Section 2).
- **Ship length as a dial** (Pummel lesson): default short. ILL WILL already
  does this (`presets.gd`: Quick Wake / Short 4 / Full 6 / Vigil 9). Keep it.

### 1f. Board events that mutate topology mid-game (steal-list)

Boards that physically rewire themselves mid-match are the series' most
memorable:

- **Mega Wiggler's Tree Party (Jamboree):** a giant Wiggler rotates on each
  bell/event, and **the spaces on its back form a new connecting path** each
  rotation — the graph literally changes.
- **King Bowser's Keep:** an event space (or the "Bowser Byway Lever" item)
  **flips the direction of the dangerous path.**
- **Yoshi's Tropical Island:** a Happening space **swaps two islands**,
  changing which goal is reachable.
- **Mario's Rainbow Castle:** a **rainbow bridge appears** on completion.

**Recommendation for ILL WILL:** one **announced** topology mutation per board
is a huge value-per-hour beat and fits the theme cleanly — e.g. a **funeral
bell / the crypt opening** at a fixed board event that unlocks a shortcut
through the mausoleum, or **the bog floods** and closes the valley route for a
few turns. Keep it announced (Pro Rules discipline: nothing hidden decides).

---

## SECTION 2 — Downtime in sequential-turn games (now a live problem again)

Because the spec **restored sequential rolls + over-shoulder cam**, downtime is
back on the table. The numbers are brutal and well-documented:

- **~50% of a Mario Party session is spent watching other people move.** With
  20 turns ≈ 90 min, that's ~45 minutes of not-your-turn.
- Superstars' only fix was **shortening turns** (it cut the gimmick cutscenes
  that "artificially lengthened" turns) — it **never solved sequential
  downtime**, just trimmed it.
- **Jamboree's Koopathlon** is the genre's actual answer: **deletes dice**,
  runs **simultaneous split-screen for up to 20 players**, movement = your
  minigame score. Near-zero downtime — but it also flattens the shared
  "ohhh he landed on it" couch beat.

**How the spec already helps itself:** the loop is `roll phase → minigame
(every cycle) → winner gets shop currency`. That is **far more minigame-dense
than Mario Party** (MP plays one minigame per *full round of four turns*; the
spec plays one per cycle). Frequent all-play minigames are the best natural
re-sync — the sequential part is only the roll phase. Protect that.

**Recommendations (keep over-shoulder intimacy, cut the dead air):**

1. **Turn-time budget, hard-capped.** Roll act ≤ **3–5 s** (skill meter), pawn
   travel **1.5–2 s** with a hold-to-fast-forward, one **Executor one-liner**
   (no cutscene). Target a **full 4-player roll phase ≤ 30–40 s**.
2. **Give the three waiters a job every single turn.** Port R1's **BOOK OF THE
   DEAD** sealed bet (bet on who wins the coming minigame) into the roll phase,
   plus the F-key react/heckle glyphs (doc 24). *Betting on other people's
   turns is itself a party game* (Wits & Wagers / Jackbox proof) and takes
   downtime to zero because everyone has stakes on every resolution.
3. **Pre-commit in parallel.** While player A rolls, B/C/D **pre-pick their
   fork and pre-buy from the cart** on their own screen-corner, so their turn
   resolves instantly when it comes around.
4. **Camera director cuts to the punchline, not the walk** (doc 24 board
   broadcast already exists) — show the landing, skip the stroll.
5. **Cap NPC/store dialogue to one beat.** The moment an NPC turn runs longer
   than a roll, you've reintroduced the cutscene tax Superstars deleted.

---

## SECTION 3 — End-game bonus awards & catch-up (the emotional engine)

### 3a. Bonus-star categories across the series (full enumeration)

These are the "totals" the spec's victory model is really asking for. Enduring
categories (name — what it rewards — era):

- **Minigame Star** — most coins won in minigames — **every game**.
- **Rich Star** — most total coins collected incl. spent/stolen — SMP,
  Superstars, Jamboree (replaced the older **Coin Star** = most held, MP1–5).
- **Eventful / Happening Star** — landed on most event spaces — all but MP9.
- **Sightseer / Running Star** — moved the most spaces — MP7,8,DS, modern.
- **Shopping Star** — spent the most coins at shops — MP7,8, Superstars,
  Jamboree.
- **Misfortune / Unlucky Star** — landed on most unlucky spaces — MP7,8, SMP,
  Superstars, Jamboree.
- **Slowpoke Star** — lowest dice totals (rewards bad luck) — MP9,10, modern.
- **Item / Orb Star** — used the most items — MP6,7,8,DS, modern.
- **Bowser Space Star** — landed on most Bowser spaces — Superstars, Jamboree.
- Plus game-specific: Hex, Friendship, Duel, Loner, Ally, Buddy, Doormat,
  Stompy, Balloon, Champion, Dice Block, etc.

**How many are awarded (this is the balance knob):**
- **MP1–6:** always **3** bonus stars.
- **MP7–9:** 6 possible, **3 awarded at random.**
- **MP10:** 5 possible, **2 awarded.**
- **Super Mario Party:** **2** standard, **3 if the game reached 20+ turns.**
- **Superstars / Jamboree:** **2** standard, **3 if 30+ turns.**
- **Jamboree Pro Rules:** **1 bonus, announced up front.**

The load-bearing fact: **a bonus star is worth exactly as much as a bought
star** (one point), and handing out **3 at the end routinely flips the
winner** — which is *the point*. It's the "puncher's chance" that keeps last
place alive to the final turn. **But hidden bonus stars are the series' #1
grievance** ("I lost because they hand out stars for *failing*"), which is why
Jamboree's fix was to **announce which award is live and make the race for it
legible during play** — not to remove it.

### 3b. Catch-up / rubber-banding — quantified, and the taxonomy

- **Shop rubber-banding (MP2/3):** trailing + late-game players get **more and
  better items offered.** Legible, opt-in.
- **Bonus stars themselves** are the primary rubber-band (reward non-winning
  behavior — Slowpoke, Unlucky, Eventful).
- **Dokapon's Darkling** (best-loved catch-up in the genre): last place can
  **opt in** to become a **time-boxed** revenge avatar with tripled stats that
  hunts leaders and steals **soft standing, never the win condition**. Beloved
  precisely because it's opt-in + announced + time-boxed, and it's a *person*
  hunting the leader, not the game's thumb on the scale.
- **Catch-up taxonomy** (Fantastic Factories): **Systematic** (leader headwind,
  e.g. Power Grid's worse auction order), **Social** (players target the
  leader, e.g. Catan's robber), **Perception** (hide scores so nobody feels
  hopeless). Key warning: **"leader headwind" ≠ true catch-up** (both players
  scale equally), and **blue-shell catch-up feels patronizing** when the winner
  becomes "whoever scores once everyone's out of ammo." **Best practice: social
  targeting + obscured hopelessness over mechanical handicap.**

**Recommendation for ILL WILL:** the estate already owns the *best* version of
this — **player-authored, attributed sabotage** (grudge, monuments, epitaphs).
Lean on **social catch-up** (items/curses the table aims at the leader) and
**announced comeback awards**, and avoid invisible rubber-bands. Announce the
3 special awards **at night start** (Pro Rules) and make their races **visible
mid-night** (R1's Interim Reading) — that alone converts the biggest genre
grievance into a strength.

---

## SECTION 4 — Adult / indie analogs

### 4a. Pummel Party — the closest analog (study it hard)

**Structure & economy (exact where documented):**
- **Single currency: KEYS.** Start with **35 keys**; a **trophy/goblet costs
  40 keys**; on purchase the **trophy relocates** (gold light points to the
  next spot). Minigames pay keys **down to 6th place** on a decreasing scale
  (top places ≈ 4–6 keys, minigame-dependent).
- **Items are FREE from item tiles** — there is **no coin currency and no item
  shop.** You pick items up by landing on tiles (top minigame finishers also
  get items). This is the crucial structural difference from Mario Party.
- **15 board items**, most **aimed at other players**: **Magnet** (steal keys
  or an item off a chosen target), **Giga Laser** (one-shot atomize anyone on
  the map), **Nuclear Waste Barrel** (disable a target's items + bleed their
  keys for ~3 rounds), **Dark Summoning Staff** (a patrolling killer),
  **Eggplant** (RC bomb), plus Boxing Glove, Shotgun, Rocket Skewer, Wrecking
  Ball, Bee Hive, Swap Portal, Present, Health Kit, Tactical Cactus Disguise,
  Arcade Challenge.
- **End-game awards (extra goblets), customizable:** Most Keys Gained, Most
  Damage Dealt, Most Minigames Won.
- **Everything is a dial:** goblets-to-win / turn cap, which items spawn,
  dice min/max.

**What works:** aimed, chosen cruelty (you decide to gang the leader — catch-up
that never feels like the game cheating); full configurability; the trophy as a
relocating target; awards that reward non-winners.

**What players complain about (verbatim themes):** minigames get
**repetitive** and are "underdesigned to uninspired"; **visibility** problems
(characters "not bright enough, no outline," games too fast); **forced random
minigames you dislike**; and the big one — **"there's no way to make a
comeback … aside from a single extremely rare object, there's no way to steal
currency from other players."** Also: **binary AI** (trivial or unbeatable).

**Direct lessons for ILL WILL:**
1. **Two currencies beat Pummel's one.** Pummel folds money and victory into
   "keys," so every steal is a direct win-swing and the economy has no relief
   valve. The spec's **shop-currency vs victory-currency split fixes exactly
   the comeback/inflation complaint** — steal the *shop* currency freely
   (drama, no permanent damage), keep victory harder to touch.
2. **Put a real, cheap comeback tool in the store** (the "steal currency" item
   Pummel infamously lacks) — but have it steal **shop** coin, not victory
   points.
3. **Legibility:** bright minifig outlines, readable board icons (ILL WILL's
   `board_spaces.gd` already enforces one public meaning per stone — keep it).
4. **Curate the minigame roll** so nobody is trapped in a game they hate; the
   spec's "rare powerup lets a player pick the minigame" is the right pressure
   valve.

### 4b. Dokapon Kingdom — the two-layer economy + the friendship-destroyer

- **Two economic layers: cash (G) + net worth (towns).** Win = **highest Net
  Worth at the end of a fixed number of weeks** (Normal), or **most cash when
  the game ends** (Story). **This validates the spec's core: a party board can
  decide the winner by end-of-run TOTALS, not by who finished/led.**
- Towns generate **weekly taxes**; **invest** to raise a town's value and
  unlock valuable **Local Items**; **jobs pay a weekly salary** (up to **3×**
  with a bonus goal); you can **rob shops and mayors**. Death penalty: lose
  **¼–½ of your money** + items.
- **Attributed, lingering humiliation** is the whole reputation: **rename a
  loser** (shown to everyone), graffiti their face, force a haircut. ILL WILL
  already owns this thesis (grudge ledger, epitaphs, crows) — R1's Epitaph
  recommendation is the board's version.

### 4c. 100% Orange Juice — the objective ladder

- Win = **first to Norma 6.** Ladder (**choose one condition per level**):
  N1 = 10 stars (fixed); N2 = 30 stars **or** 2 battle wins; N3 = 70 **or** 5;
  N4 = 120 **or** 9; N5 = 200 **or** 14.
- **Chapter-start bonus:** every turn each player auto-gets stars scaled by
  level + chapters passed — a built-in **income floor + soft catch-up** so
  nobody falls unrecoverably behind on the star track.
- Steal the **legible "how close is the end" ladder** (great for a long Vigil
  preset), **not** its strictly-sequential turn structure (full downtime).

### 4d. Board Game Online (Frostbolt Games, browser, since 2009)

- The **purest A-to-B analog to the new spec: first to cross the finish line
  wins.** Movement + a deep bag of **Items, Skills, Spells, and random events**;
  currency = **rupees**; famously **absurd adult humor**. Running 15+ years on
  this exact loop proves **an A-to-B race is a viable multiplayer party spine**
  — but note it manages the race entirely through **heavy item/spell swinginess
  and events** (teleports, curses, setbacks), and the race *is* the win (no
  separate totals). ILL WILL's hybrid (race triggers night-end, **totals decide
  winner**) is more novel and needs the Section-6 guardrails BGO doesn't.

---

## SECTION 5 — Two-currency economies (source/sink balance)

**The Mario Party engine, stated as a rule:** a **soft currency earned
constantly** (coins: +3/blue, ~10/minigame win) is converted into a **hard
currency that alone decides the winner** (stars: 20 coins each) **at a moving
target.** The tuning is load-bearing and has a proven failure case:
**Super Mario Party dropped stars to 10 coins and "coins meant almost
nothing"** — the economy flattened and reviewers panned it; **Superstars
restored 20 and it tightened again.** So: **the hard currency must cost enough
that earning it is a multi-turn project** (~2 minigame wins), or the soft
currency stops mattering.

**Source/sink per turn (Mario Party, ~4-player):**
- **Sources:** ~+3 per blue landed; ~+10 minigame win (less for lower places);
  event/bank jackpots.
- **Sinks:** −3 red; −20 star; item purchases 3–40; tolls/duels; Bowser/Boo
  theft.
- **Inflation control:** stars are a hard 20-coin sink that never cheapens;
  hazards + steals recycle coin between players; item prices stay fixed.

**Pummel's counter-example:** **one currency (keys)** doing both jobs → every
steal is a direct win-swing, late-game **key inflation makes swings feel like
noise**, and there's **no relief valve** (the #1 complaint). **The two-currency
split is the fix**, and the spec has it.

**How pricing creates decisions instead of auto-buys:** peg the **best items to
~2 minigame wins** and trash items to **~½ a win**; keep a **premium tier
(20–25)** so buying it means *not* saving toward victory that cycle. Anything
under ~⅓ of a minigame win is an auto-buy and should be a free tile pickup
(Pummel-style random box), not a store item.

**Where ILL WILL stands today** (`board_spaces.gd` / `codicil.gd`): Grudge
(soft) → Deeds (hard) at the **Codicil, priced 10 + 2 per Deed held** (a nice
escalating sink). Shrine +3 / Grave −2 / Toll 2 are the per-turn source/sink.
The spec **removes Deed-buying**, so the *hard* currency stops being a shop
sink and becomes **end-of-night victory points** — meaning the soft (shop)
currency now needs **its own compelling sinks** (stores, tolls, duels, comeback
steals) or it inflates like Pummel's keys. **Give the shop currency real things
to buy every cycle, or hoarding becomes the dominant strategy.**

---

## SECTION 6 — The spec's central tension: first-arrival-ends-night

**The setup.** Board is A-to-B; **the night ends the moment the first pawn
crosses the end**; the **winner is decided by totals** (leftover shop currency
+ ranked arrival awards [weighted highest] + minigame placements + specials).
This fuses two different traditions — Dokapon's "totals at end of a fixed run"
and BGO's "first-to-finish race" — and the seam has four real risks.

**Risk A — The leader controls game length AND profits most from ending it.**
If arrival-order awards are *weighted highest* and first arrival *ends the
night*, the frontrunner is doubly incentivized to rush: they both claim the
biggest award and **cut off everyone else's remaining turns.** That's a
snowball amplifier — the exact inverse of Mario Party, where **reaching a star
never ends the game** and the fixed turn count guarantees equal turns.

**Risk B — Unequal turn counts starve catch-up.** In sequential play, when P1
crosses, P2–P4 have taken fewer or equal turns and **never get their last
turn** → fewer minigames played → **less shop currency and fewer placement
awards for the players who most need them.** Catch-up needs *turns to happen
in*; first-arrival deletes them precisely for the trailing seats.

**Risk C — Double-counting the board lead.** "Arrival weighted highest" +
"arrival ends the night" counts the same lead twice. Mario Party never lets the
race position *be* the win — bonus stars deliberately reward **non-winning**
behavior. Weighting arrival highest re-imports the snowball MP spent 25 years
engineering out.

**Risk D — Anticlimax / no third act.** A runaway leader crossing at turn 5
while others are mid-board = an **abrupt stop, no Last-Five-Turns tension** (R1
already flagged "the night just ends"). MP manufactures its climax from an
*announced* homestretch, not from someone silently reaching the exit.

### Three resolutions that keep Alex's structure

**RESOLUTION 1 — THE FINAL BELL (equal-turns guarantee).** *[recommended,
cheap]* First arrival does **not** end the night instantly — it **rings the
Final Bell**: the crossing and arrival order are locked and announced, then
**every other player gets exactly ONE more full turn** (roll + the pending
minigame), so turn counts equalize to N/N+1, **then** totals are scored. This
is Mario Party's "Last Five Turns" compressed to "Last One Turn." It neutralizes
Risk A and B (nobody is denied their turns; the leader can't starve the table),
preserves the trigger Alex wants ("first arrival ends the night" → "first
arrival *starts the last turn*"), and manufactures the missing third act
(Risk D): an announced, standings-read homestretch. *Effort: low — a state flag
+ one ceremony beat; extends R1's FINAL RITES, already scoped there.*

**RESOLUTION 2 — CHECKPOINT SHRINES (spread the scoring across the board).**
*[recommended if the board is large — and the spec says it is]* Instead of
arrival being one winner-take-all lump, plant **2–4 monuments/checkpoints**
along the track (the relocating-target idea from 1c). **Reaching each awards
victory points in arrival order at that checkpoint.** A player who led early
but faded still **banked the early shrines**; a fast finisher banks the last.
This borrows 100% OJ's legible ladder and MP's moving target: victory-point
generation is **distributed across the whole board**, so **trailing players who
never finish still scored**, and "first to the end" becomes "first to the final
shrine" — same trigger, but the lead is no longer a single decisive lump.
**Weight the final gate highest but cap it below the sum of the other streams.**

**RESOLUTION 3 — TURN-CAP FALLBACK + DISTANCE RANKING (bound the length).**
*[recommended as a safety net]* The night **also** ends at a **fixed turn cap**
(a preset dial) even if nobody has crossed — **whichever comes first.** If the
cap fires, the arrival award is assigned by **distance along the track.** This
bounds session length (kills both "leader stalls forever" and "night drags"),
makes length a **dial** (Pummel lesson), and gives a clean fallback. Concretely:
Short night cap ≈ the distance a median roller covers in **~6–8 turns**; a
racer who crosses at turn 5 + Final Bell = ~6-turn night; if nobody crosses,
the cap ends it at ~8.

**The meta-fix underneath all three (Resolution 4 — decouple ender from
winner):** honor the spec's own instinct — **"winner decided Mario-Party-style,
not race position."** Make the finish a **solid but non-dominant** arrival
bonus, and make the **largest victory streams minigame placements + announced
special awards**, so a **trailing player who lost the race can still win the
night on totals.** Then **rushing to end the night surrenders minigame turns
to opponents** — the snowball inverts into a genuine risk/reward decision about
*when* to cross. Suggested balance so no single stream decides (mirrors MP's "3
bonus stars can flip it"):

| Victory stream | Target share of a typical winner's total |
|---|---|
| Minigame placements (per cycle) | ~30–35% |
| Arrival order + checkpoints | ~30–35% (final gate highest, but capped) |
| Announced special awards (3/night) | ~15–25% |
| Leftover shop currency (soft convert, e.g. 10 coin → 1 pt) | ~10–15% |

**Ship:** Final Bell (R1) + Turn-cap/distance fallback (R3) + non-dominant
arrival (R4) as the default; Checkpoint Shrines (R2) as the large-board upgrade.

---

## SECTION 7 — Mapping onto ILL WILL (legible, in-theme naming)

Alex wants **fewer estate/trust legalisms** — the board must read to a normie
at a glance. Current names lean legal ("Codicil," "Deed"). Below, every
recommendation is **funereal but instantly legible**.

### 7a. The two currencies (rename for legibility)

- **Shop currency (soft, earned from minigames, spent at stores):** currently
  *Grudge*. Keep the grudge *flavor* in the fiction but label the spendable
  thing as money a normie recognizes: **COINS** (or themed: **GRAVE PENNIES** —
  the coins-on-the-eyes folk image, still obviously "money"). Recommend
  **PENNIES**: legible, on-theme, funny ("two pennies for the ferryman").
- **Victory currency (decides the inheritor, tallied at the will-reading):**
  currently *Deeds* (a legalism). Recommend **WREATHS** — you *collect
  wreaths*, the one with the **most wreaths inherits**; visual, legible,
  darkly funny, zero legal jargon. (Alt: **RESPECTS**, as in "pay your
  respects.") The will-reading becomes the **bonus-star ceremony** where
  arrival, placements, leftover pennies, and specials all convert to Wreaths.

### 7b. Space grammar (legible names, MP analogs, in-theme)

| ILL WILL space | MP analog | Effect | Reads to a normie as |
|---|---|---|---|
| **PATH STONE** | Blank | nothing | plain tile |
| **OFFERING** | Blue / Lucky | **+3 pennies** | "good tile" |
| **OPEN GRAVE** | Red / Unlucky | lose pennies / stumble | "bad tile — a hole" |
| **THE PEDDLER'S CART** | Item Shop | **buy an item** (fixed spot) | "the store" |
| **GRAVE GOODS** (?-box) | Item Space | **free random item/powerup** | "? mystery box" |
| **CROSSROADS** | Junction | **pick your route** (yard/woods/valley) | "the fork" |
| **SÉANCE CIRCLE** | Event / Chance | spin the **visible** 4-slot wheel | "spooky event" |
| **THE FERRYMAN'S TOLL** | Bank / Toll | pass: pay owner; land: take the pot | "toll bridge" |
| **GRUDGE MATCH** | Duel | nemesis within N → 1v1 wager minigame | "the duel tile" |
| **CRYPT SHORTCUT** | Warp | skip ahead through the mausoleum | "shortcut" |
| Biome hazards: **BOG** (valley) slows / **ROOTS** (woods) snare | Happening | region hazard | "terrain trap" |

(Renames from current build: *Weeping Grave → OPEN GRAVE*, *Shrine → OFFERING*,
*Stall → PEDDLER'S CART*, *Tollgate → FERRYMAN'S TOLL*, *Vendetta → GRUDGE
MATCH*, *Codicil → retired* since victory isn't purchased. All within the same
`board_spaces.gd` public-fact table pattern.)

### 7c. The route splits (2+, per spec) — with MP-style incentives

- **THE GARDEN ROW (safe/long):** dense with **Offerings + the Peddler's
  Cart**; steady pennies, low variance. The "shop route."
- **THE HOLLOW WOODS (short/wild):** **Grave Goods boxes + Séance + Roots
  hazards**; fast but high-variance swings.
- **THE WEEPING VALLEY / BOG (gamble):** fastest **if** you catch the
  **Ferryman's shortcut**, but studded with **Open Graves + a Toll**.

Incentive design (straight from MP): the **safe route carries the store and
steady income**, the **short route is event-dense and swingy** — the decision
at the **Crossroads** is reading which fork your rivals need and denying it.

### 7d. NPCs to meet (spec wants NPCs — legible archetypes)

- **THE GRAVEDIGGER** — sells shovels / crypt shortcuts (movement items).
- **THE WIDOW** — gives or takes pennies; blessing/curse.
- **THE FERRYMAN (Charon)** — pay pennies to skip across the valley.
- **THE MOURNER-FOR-HIRE** — buy a special-award nomination (see 7e).
- **THE MAGPIE / CROW** — steals or gifts (random; the estate's crows already
  exist as lore).
- **THE EXECUTOR** — host at the **Manor Gate** (the finish); runs the Final
  Bell and the will-reading.

### 7e. Store inventory draft (bought with PENNIES; MP-tier pricing)

| Item | Penny cost | Tier | Effect | MP/analog |
|---|---|---|---|---|
| **LUCKY PENNY** | 3 | budget | +N to your next roll | Mushroom |
| **BLACK VEIL** | 5 | budget | negate your next Open Grave / hazard | (Grave Salt, exists) |
| **PALLBEARER'S SHOVEL** | 7 | budget | dig a shortcut, skip ahead X | Warp Block |
| **CROW'S CUT** | 10 | mid | **steal 5 pennies** from a chosen rival | Magnet/Plunder (the comeback Pummel lacks — steals SHOP coin only) |
| **FUNERAL BELL** | 12 | mid | drag the current leader back X spaces | Black Ribbon aimed (exists) |
| **WREATH OF DEBT** | 20 | premium | place a trap-wreath on a stone; first rival to land pays you (persistent, attributed) | MP5–7 Orb / the royalties thesis |
| **THE INVITATION** | 22 | premium/rare | **choose the next minigame** (the spec's "rare powerup") | curates the roll |
| **FALSE EULOGY** | 25 | premium | buy one guaranteed special-award nomination at the will-reading | Shopping-Star indirection |
| **WILL-O'-THE-WISP** | 25 | premium | teleport to the next NPC / checkpoint shrine | Golden Pipe |

Pricing rationale: minigame winner earns ~8–10 pennies, so **premium = ~2
wins**, trash = ~½ a win — MP's decision ratio, so nothing auto-buys and
saving-toward-victory competes with spending-to-sabotage each cycle.

### 7f. Special awards (the "bonus stars," announced at night start)

Legible, funereal, **announced up front** (Pro Rules), **race visible
mid-night** (R1 Interim Reading). Award **3 per night**:

- **LONGEST PROCESSION** — moved the most spaces (Sightseer).
- **MOST MOURNED** — landed on the most Open Graves / hazards (Misfortune —
  rewards suffering, on-brand).
- **HEAVY PURSE** — earned the most pennies all night (Rich).
- **BLOODIEST HAND** — won the most minigames (Minigame Star).
- **GENEROUS TO A FAULT** — spent the most pennies at carts (Shopping).
- **FIRST TO THE GRAVE** — arrival order (the race award — solid, not dominant).

Each worth a fixed Wreath value ≈ a couple of minigame placements — enough that
**3 of them can flip the night** (MP's balance), keeping last place alive to
the will-reading.

### 7g. The 3-night arc (matches the estate save loop)

Each night **resets the board** (spec) but **carries the running Wreath tally +
estate scars** (monuments, graffiti, epitaphs — the beloved-but-abandoned MP
Orb mechanic made *permanent across nights*, ILL WILL's unshipped-anywhere
thesis, per doc 03). **Final inheritor = most Wreaths across 3 nights** —
structurally Dokapon's "greatest net worth at the end of N weeks," in probate
dress. The estate interlude (will-reading, one grounds minigame, wardrobe,
special store) is the between-nights ceremony.

---

## Sources

**Mario Party — spaces, boards, economy, bonus stars, events:**
- [Space (Mario Party series) — MarioWiki](https://www.mariowiki.com/Space_(Mario_Party_series))
- [Yoshi's Tropical Island — MarioWiki (per-board space counts)](https://www.mariowiki.com/Yoshi's_Tropical_Island)
- [Board (Mario Party series) — MarioWiki](https://www.mariowiki.com/Board_(Mario_Party_series))
- [Bonus Star — MarioWiki (full category enumeration)](https://www.mariowiki.com/Bonus_Star)
- [Item Shop (Mario Party series) — MarioWiki (prices, rubber-banding)](https://www.mariowiki.com/Item_Shop_(Mario_Party_series))
- [Star (Mario Party series) — MarioWiki](https://www.mariowiki.com/Star_(Mario_Party_series))
- [Mario Party Superstars: Best Items To Spend Coins On — TheGamer](https://www.thegamer.com/mario-party-superstars-best-items-cost-coins/)
- [Item shop prices — GameFAQs (Superstars)](https://gamefaqs.gamespot.com/boards/323655-mario-party-superstars/79726607)
- [Mario Party Jamboree Boards breakdown — magzinepaper](https://magzinepaper.com/mario-party-jamboree-boards/)
- [The Art of the Party: Ten Best Mario Party Boards — Valley Voice (junction/route design)](https://sites.google.com/wallkillvrhs.org/the-valley-voice/issue-3/the-art-of-the-party-the-ten-best-mario-party-boards)
- [What are your thoughts on the car Mario Parties (9 & 10)? — ResetEra](https://www.resetera.com/threads/what-are-your-thoughts-on-the-car-mario-parties-9-10.29463/)
- [Was the car idea a bad idea? — GameFAQs (MP9)](https://gamefaqs.gamespot.com/boards/632974-mario-party-9/62154012)
- [How long does the average Mario Party take — GameFAQs (downtime/session)](https://gamefaqs.gamespot.com/boards/189706-nintendo-switch/76934033)
- [Turn Limit — GameFAQs (Superstars 30 turns)](https://gamefaqs.gamespot.com/boards/323655-mario-party-superstars/79679510)

**Adult / indie analogs:**
- [Pummel Party: An Overall Guide — SteamAH](https://steamah.com/pummel-party-an-overall-guide/)
- [An Overall Guide for Pummel Party — Steam Community](https://steamcommunity.com/sharedfiles/filedetails/?id=2066443349)
- [Pummel Party Items guide — gameplay.tips](https://gameplay.tips/guides/9298-pummel-party.html)
- [Pummel Party Review — Gideon's Gaming (binary AI, complaints)](https://gideonsgaming.com/pummel-party-review-my-kind-of-party/)
- [Pummel Party: A Friendly Beatdown — The Refined Geek](https://therefinedgeek.com.au/index.php/2025/04/21/pummel-party-a-friendly-beatdown/)
- [Pummel Party user reviews — Metacritic (repetition, comeback complaints)](https://www.metacritic.com/game/pummel-party/user-reviews/)
- [Money — Dokapon Wiki](https://dokapon.fandom.com/wiki/Money)
- [Town / Invest — Dokapon Wiki](https://dokapon.fandom.com/wiki/Town)
- [Dokapon Kingdom — TV Tropes (net-worth win, humiliation)](https://tvtropes.org/pmwiki/pmwiki.php/VideoGame/DokaponKingdom)
- [Norma — 100% Orange Juice Wiki (ladder thresholds)](https://100orangejuice.fandom.com/wiki/Norma)
- [Board Game Online — official (spells page)](https://boardgame-online.com/?page=spells)
- [Board Game Online Wiki — How to Play (Miraheze)](https://bgo.miraheze.org/wiki/How_to_Play)

**Catch-up / downtime theory:**
- [Catch Me If You Can: The Runaway Leader and Catch-Up Mechanics — Fantastic Factories (Medium)](https://fantastic-factories.medium.com/catch-me-if-you-can-the-runaway-leader-and-catch-up-mechanics-53f0356c440d)
- [Catch-Up Mechanisms: How Games Combat The Runaway Leader — The Thoughtful Gamer](https://thethoughtfulgamer.com/2017/03/28/catch-up-mechanisms/)

**Internal (grounding, not re-litigated):** docs/design/03-board-research-digest.md,
13-board-mode-research.md, 27-night6-research-dossier.md,
research-night6/R1-board-loop.md; estate/procession/{procession,board_spaces,presets,codicil}.gd.
