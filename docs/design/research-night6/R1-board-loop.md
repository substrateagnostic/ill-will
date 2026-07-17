# R1 — Board-Loop Research: What THE PROCESSION Lacks (2026-07-17)

Research lane R1, night 6. Lens: party board-game loop mastery — Mario Party
evolution, Pummel Party, 100% Orange Juice, Dokapon Kingdom, Wits & Wagers /
Jackbox betting. Grounded against the shipped board loop in
`estate/procession/` (procession.gd 1542 lines, board_spaces.gd, presets.gd)
and prior internal research (docs/design/13-board-mode-research.md, 03, 18).

Doc 13 already metabolized: simultaneity vs schadenfreude, Jamboree Pro Rules
transparency, Koopathlon, session-length dials, two-currency economies. This
report does NOT re-litigate those — it hunts what the *built* PROCESSION still
lacks that the genre has since proven out, with a bias toward one-overnight
builds.

---

## 1. Where the built loop stands (read from code, not docs)

The good news first: the build already lands the genre's hardest fixes.

- **Downtime**: parallel putt-roll + staggered Executor reveal
  (procession.gd `_round()`, lines 726–802) — the doc 13 §A5 wedge, real.
- **Transparency**: every space rule announced (board_spaces.gd TABLE), will
  clauses read before the first putt (`_intro()`, 667–673), Codicil location
  always visible, no hidden arbiters. This is Jamboree Pro Rules compliance
  before Nintendo shipped it.
- **Two-currency economy**: Grudge (soft) → Deeds (hard) at a roving Codicil
  with escalating price (10 + 2/deed, codicil.gd).
- **Loser stays active**: grudge flows from suffering; ghosts at estate level.

Now the gaps, each mapped to a game that proves the fix.

---

## 2. Gap: the last-3-turns problem — the night just... ends

**Current code**: `_check_win()` fires the instant anyone hits `deed_goal`;
the only endgame escalation is `final_kit.escalate()` (core/final_stretch.gd —
music + warm-red screen edge) triggered at deed_goal−1
(procession.gd:1155). No rules change, no announced final stretch, no last
chance for the table.

**What the genre proves**: every mainline Mario Party since MP1 has a
**Last Five Turns Event** — the game *formally announces* the homestretch,
reads the standings, and changes the rules (coin values spike, star prices
shift, the trailing player gets a boost picked by a visible wheel in MP DS's
"Final 5 Frenzy") ([MarioWiki: Last Five Turns Event](https://www.mariowiki.com/Last_Five_Turns_Event),
[Giant Bomb concept page](https://www.giantbomb.com/last-five-turns-event/3015-3010/),
[Mario Party Legacy on MP5's version](https://mariopartylegacy.com/2011/07/mario-party-5s-last-5-turns-event/)).
Jamboree Pro Rules additionally *shows the next Star location up front* so the
endgame is a legible footrace, not a lottery
([ScreenRant on Jamboree's luck fixes](https://screenrant.com/mario-party-jamboree-fixes-luck-mechanics/)).
The tension of a party board's climax is manufactured by an announced state
change, and THE PROCESSION currently has the music for it but not the rules.

**Recommendation — THE FINAL RITES** (one ceremony + three rule flips, all
announced by the Executor when any seat reaches deed_goal−1):

1. The Codicil **stops relocating** and plants at the manor gate — the final
   Deed's location is public and fixed (Pro Rules' "next star shown"). Everyone
   putts at the same target; the reveal cascade becomes a footrace.
2. **All grudge gains and losses double** (Last Five Turns' coin madness) —
   shrines +6, graves −4, tolls 4. One `mult` int threaded through the resolve
   functions; every doubled popup is its own joke in this tone.
3. Vendetta reach widens 5 → 8 — the table's last legal instrument of spite.

Executor ceremony card + banner line; the standings read aloud
("Three mourners remain within reach of the estate. One does not.").
Estate deadpan writes itself.

**Effort**: 4–6 h (state flag, ceremony card, multiplier, beacon pin, copy).
**Risk**: low — pure addition, no existing rule changes; receipts change only
after the flag fires, so seed-verification stays clean up to the trigger.

---

## 3. Gap: announced bonus stars nobody can track — the clause race is invisible

**Current code**: three will clauses announced at `_intro()` and paid at
`_will_reading()` (procession.gd:608–616, 1353–1378). Each pays **+1 Deed**;
with the default goal of 4 that's a possible 75%-of-goal swing resolved in one
card at the end — and *no one can see who is currently winning any clause*
mid-night. `stats[]` tracks moved/lost/duels the whole time; the data exists,
the display doesn't.

**What the genre proves**: hidden end-of-game bonus stars are Mario Party's
single most-hated mechanic — "I lost because they hand out bonus stars for
*failing*" ([MarioWiki: Bonus Star](https://www.mariowiki.com/Bonus_Star),
doc 13 §A2). Jamboree's fix was not just announcing *which* star is in play
but making the race for it **legible during play**
([ScreenRant](https://screenrant.com/mario-party-jamboree-fixes-luck-mechanics/)).
Announcing at minute 0 and paying at minute 25 is transparency in the legal
sense only — by the reading, nobody remembers the terms. A clause you can
*see yourself losing* is a clause you play for; that's the entire difference
between a puncher's chance and a lottery ticket.

**Recommendation — THE INTERIM READING**: 

- Cheapest version (do this): each HOUSE AWAKENS (every 3rd round), the
  Executor appends one line per clause to the ceremony card: current leader's
  name + stat ("THE MOST BETRAYED — Aldous, 7♠ bled"). Zero new UI; string
  formatting over existing `stats[]` + `_stat_leader()`.
- Nice version if time allows: a small persistent clause strip under the
  topbar with three glyphs that tint to the current leader's seat colour and
  pulse on lead change (a lead-change is a MomentScribe-worthy beat).

**Effort**: 1–2 h for the Executor line; +2–3 h for the HUD strip.
**Risk**: near zero. Highest fun-per-hour item in this report.

---

## 4. Gap: the vendetta duel is a coin flip wearing a duel's clothes

**Current code**: `_resolve_vendetta()` (procession.gd:1084–1110) — "sealed
0–3 grudge wager" — but `_stake_for()` (1183–1186) rolls
`rng.randi_range(0, 3)` **for humans and bots alike**. The bot branch and the
human branch are literally identical lines. The game's signature
player-vs-player instrument — the one carrying the estate's nemesis soul onto
the board (doc 18 Q6) — currently involves zero player decisions. It's a
random transfer with duel copy.

**What the genre proves**: Dokapon Kingdom is *the* "friendship destroyer"
([NeoGAF RTTP](https://www.neogaf.com/threads/rttp-dokapon-kingdom-the-greatest-friendship-destroying-video-board-game-game-ever.937015/),
[Den of Square analysis](https://xb-squaredx.tumblr.com/post/165891966067/dokapon-kingdom-the-destroyer-of-friendships))
and its whole reputation rests on PvP fights where you **choose** to commit
and the loser suffers **attributed, visible, lingering humiliation**: the
victor loots the body, then picks a Prank — rename the loser (everywhere, for
everyone to read), draw graffiti on their face, force a ridiculous haircut
([Dokapon Wiki: Prank](https://dokapon.fandom.com/wiki/Prank),
[Carly Smith: "Kill Your Friends — Dokapon wants you to"](https://www.carlysmith.net/blog/2011/04/kill-your-friends-its-okay-dokapon.html)).
The mechanical transfer is forgettable; the *mark* is what people scream
about. ILL WILL already owns this thesis at estate level (graffiti, crows,
grudge ledger) — the board duel just never cashes it.

**Recommendation — SEALED STAKES + THE EPITAPH** (two halves, same feature):

1. **Real sealed stakes.** On a vendetta trigger, both seats get a 2.5 s
   sealed pick: hold A to raise 0→3 (reuse the putt meter's hold-release
   grammar; bots keep the rng draw, remote seats fall back to rng until a net
   intent exists). Reveal simultaneously in the cascade. Suddenly it's poker:
   stake 0 to insult them, stake 3 to gut them.
2. **The Epitaph (Dokapon Prank, estate register).** The duel winner picks
   from 3 seeded epitaph words ("MOIST", "SOLVENT", "BRIEFLY MOURNED", pool in
   board_spaces or voice bible); the word appears as a small Label3D hung on
   the loser's pawn for the rest of the night, in the winner's seat colour,
   attributed. Feed it to `EstateState.add_graffiti()` so the crows can quote
   it next night. Cosmetic only — never touches the economy, so it violates
   nothing in the "catch-up only via legible suffering" ruling.

**Effort**: 5–7 h (stake UI 3, epitaph label + pool + graffiti hook 2–3).
**Risk**: low-medium — touches the reveal cascade timing; the sealed-pick
window needs a bot/remote fallback (specified above). Receipt note: keep the
rng draw for bots identical so seeded soaks shift minimally.

---

## 5. Gap: waiting players spectate the minigame with nothing riding on it

**Current code**: every 2nd round, roulette lands on a game, everyone plays,
RECKONING pays 5/3/2/1 grudge (procession.gd:1206–1249). Between reveal
cascades the *other three* players' engagement instrument is the F24 react
buttons — expressive, but stakeless.

**What the genre proves**: Wits & Wagers' core discovery is that **betting on
other people's performance is itself a party game** — you don't bet on your
own answer, downtime hits zero because every player has money on every
resolution ([Wikipedia](https://en.wikipedia.org/wiki/Wits_and_Wagers),
[Father Geek review](https://fathergeek.com/wits-and-wagers-party/)). Jackbox
industrialized it for spectators: Trivia Murder Party's audience wagers on
*which player dies*
([Jackbox audience play-along](https://www.jackboxgames.com/blog/how-audience-play-along-differs-in-each-jackbox-game),
[TMP wiki](https://jackboxgames.fandom.com/wiki/Trivia_Murder_Party)). And the
estate ALREADY has this muscle — grounds betting and auction side-bets exist
in the estate night loop (alexmemory.md: "Side bets moved into the auction",
`EstateState.bets`) — the board mode just never inherited it.

**Recommendation — THE BOOK OF THE DEAD (sealed minigame bets)**: while the
roulette spins (dead time today), each seat sealed-picks one name: who WINS
the coming minigame. Bet on yourself: +2♠ if right. Bet on a rival: +4♠ if
right (Wits & Wagers' pay-more-for-riskier-line). Reveal picks *before* the
game starts — "Three of you have bet against Aldous. Aldous, the estate
apologises" is a free comedy beat and an instant alliance/target dynamic
inside the minigame itself. Reckoning card gains one line per correct book.

**Effort**: 4–6 h (pick UI over the roulette wait, reveal line, payout in
reckoning, net mirror of picks as facts).
**Risk**: medium — adds a beat to the block (keep the pick window inside the
roulette spin so net added time ≈ 0); bots pick by deed-leader heuristic.

---

## 6. Gap: items are weather, not decisions

**Current code**: THE STALL and the pre-minigame handout both give a *random*
item (`_resolve_stall` 1015–1027, `_minigame_block` 1209–1217). The black
ribbon auto-targets the deed leader with no aimer input. Three items total.
Doc 18's session structure promised "AUCTION (item shop)" in the block; the
build simplified it to random handouts — and STORE-BLURB.md still sells "Bid
your spite at the auction" (currently true only of the estate-level game
auction, not the board).

**What the genre proves**: Pummel Party's board fun is *choosing and aiming*
cruelty — the magnet cone that rips keys off whoever strays close, the Giga
Laser you point at a name ([Pummel Party items wiki](https://pummel-party.fandom.com/wiki/Items),
[Gideon's Gaming review](https://gideonsgaming.com/pummel-party-review-my-kind-of-party/)).
Its reviewers consistently note the leader gets targeted *because players
decide to*, which is catch-up that never feels like the game's thumb on the
scale ([The Refined Geek](https://therefinedgeek.com.au/index.php/2025/04/21/pummel-party-a-friendly-beatdown/)).
Jamboree's item lesson runs the same way: the buddy you *steal by passing* is
the fun part ([MarioWiki: Jamboree Buddy](https://www.mariowiki.com/Jamboree_Buddy)).
Random handouts produce none of these sentences at the couch.

**Recommendation — THE STALL SHOWS ITS WARES**: landing on the Stall (and the
block handout) presents **3 face-up cards, pick 1** — 3 s hold-to-pick, bots
pick by simple valuation, remote falls back to first card. Same three items to
start; the choice alone converts weather into agency. If the hour budget
allows, add a fourth item that *aims*: **WREATH OF DEBT** — place it on any
stone within your putt preview; first rival to land pays you 3♠ (an
author-attributed trap: the royalties thesis, on the board, in one item).

**Effort**: 3–5 h for pick-1-of-3; +3 h for the wreath.
**Risk**: low for the pick; the wreath touches board state + net facts
(medium), cuttable without losing the core.

---

## 7. Honourable mentions (found while reading; not top-5)

- **THE HOUSE AWAKENS is RNG dressed as skill.** Copy says pawns "putt for
  safety"; code rolls `rng.randf() < 0.45 + 0.1*(no deeds)` (procession.gd:1320).
  Doc 18's own pillar is "nothing hidden decides." A 3-second real safety putt
  (reuse the meter, sweet-spot = safe) would make it honest — but it adds a
  serial beat, so it competes with pacing. Flagging, not recommending tonight.
- **Séance wheel has no teeth**: all four slots are mild positives
  (board_spaces.gd SEANCE_WHEEL). One spicy-but-announced slot ("THE TABLE
  TURNS — deed leader and deed laggard swap stones") would earn the purple.
- **100% OJ's Norma ladder** (escalating personal objectives,
  [Norma wiki](https://100orangejuice.fandom.com/wiki/Norma)) remains the best
  model if a VIGIL-length preset ever drags — per-player "next objective"
  cards would pace a 9-deed night. Not a v1 need.

---

## 8. THE BIG SWING (clearly labeled, not a top-5 item)

### THE DISINHERITED — Dokapon's Darkling, in probate dress

Dokapon Kingdom's most famous system: linger in last place and the game
offers you the **Darkling** — surrender your holdings, become a time-boxed
avatar of revenge with tripled stats and multiple movement spinners, hunt the
people who beat you, then convert your havoc back into standing when it ends
([Dokapon Wiki: Darkling](https://dokapon.fandom.com/wiki/Darkling_(Kingdom)),
[Den of Square](https://xb-squaredx.tumblr.com/post/165891966067/dokapon-kingdom-the-destroyer-of-friendships)).
It is the genre's only *beloved* catch-up mechanic, because it isn't charity —
it's **opt-in, announced, time-boxed power** that steals soft standing, not
the win condition. The runaway leader isn't robbed by the game; they're
hunted by a person, which is drama instead of theft
([BGG: rubber-banding vs snowballing](https://boardgamegeek.com/thread/904667/rubber-banding-vs-snowballing-catch-up-vs-stay-ahe),
[Booknibs on catch-up legibility](https://booknibs.com/nibs/the-rubber-band-effect-how-catch-up-mechanics-keep-players-engaged)).

**ILL WILL translation**: at a HOUSE AWAKENS, if one seat is strictly last in
both deeds and grudge, the Executor makes the offer, in writing: *"The estate
notes you have nothing. The estate offers terms."* Accept (hold A; declinable)
→ for the next 2 rounds that pawn wears the black veil:

- cannot buy Deeds (the cost — mirrors Darkling forfeiting towns),
- putt meter gains a second sweet-spot band (double-range movement — the
  Darkling's extra spinners),
- immune to graves and tolls,
- landing on a stone within 1 of any rival: **siphon 2♠** (attributed, popped),
- one-time act: defile one monument (its owner's toll silenced for the night,
  graffiti written).

Veil lifts automatically; siphoned grudge stays. No deed is ever touched, so
the leader's actual win progress is never stolen — Pro Rules-compatible spite.
Estate hooks are pre-paid: veil cosmetic, graffiti, crows, eulogy clause
("tonight, the estate briefly employed a wraith").

**Effort**: 10–14 h (state machine, putt-band variant, siphon rule, veil
visual, offer ceremony, bot policy, net facts). **Risk**: high-variance —
balance can tip patronizing (too strong) or pointless (too weak); needs one
soak night with bot-only autoplay tuning. Ship only if a full overnight lane
is free after the top-5.

---

## 9. Build-order suggestion for one overnight

1. Interim clause reading (1–2 h) — pure copy, immediate payoff.
2. FINAL RITES (4–6 h) — the night now has a third act.
3. Vendetta sealed stakes + epitaph (5–7 h) — the signature drama beat.
4. Stall pick-1-of-3 (3–5 h) — agency for cheap.
5. Book of the Dead bets (4–6 h) — if lanes remain; it's the most
   parallel-safe (isolated to the minigame block).

Items 1+2+3 together ≈ one focused lane-night and convert the board's weakest
stretch (mid-night sag → abrupt end) into an arc: stakes visible all night,
formally escalated, personally settled.

---

## Sources

- [MarioWiki — Last Five Turns Event](https://www.mariowiki.com/Last_Five_Turns_Event)
- [Mario Party Legacy — MP5's Last 5 Turns Event](https://mariopartylegacy.com/2011/07/mario-party-5s-last-5-turns-event/)
- [Giant Bomb — Last Five Turns Event](https://www.giantbomb.com/last-five-turns-event/3015-3010/)
- [MarioWiki — Bonus Star](https://www.mariowiki.com/Bonus_Star)
- [ScreenRant — How Jamboree fixes Mario Party's luck](https://screenrant.com/mario-party-jamboree-fixes-luck-mechanics/)
- [MarioWiki — Jamboree Buddy](https://www.mariowiki.com/Jamboree_Buddy)
- [Dokapon Wiki — Darkling (Kingdom)](https://dokapon.fandom.com/wiki/Darkling_(Kingdom))
- [Dokapon Wiki — Prank](https://dokapon.fandom.com/wiki/Prank)
- [NeoGAF — RTTP: Dokapon Kingdom, greatest friendship-destroying board game](https://www.neogaf.com/threads/rttp-dokapon-kingdom-the-greatest-friendship-destroying-video-board-game-game-ever.937015/)
- [Den of Square — Dokapon Kingdom: The Destroyer of Friendships](https://xb-squaredx.tumblr.com/post/165891966067/dokapon-kingdom-the-destroyer-of-friendships)
- [Carly Smith — Kill Your Friends. It's okay, Dokapon wants you to.](https://www.carlysmith.net/blog/2011/04/kill-your-friends-its-okay-dokapon.html)
- [Pummel Party Wiki — Items](https://pummel-party.fandom.com/wiki/Items)
- [Gideon's Gaming — Pummel Party review](https://gideonsgaming.com/pummel-party-review-my-kind-of-party/)
- [The Refined Geek — Pummel Party: A Friendly Beatdown](https://therefinedgeek.com.au/index.php/2025/04/21/pummel-party-a-friendly-beatdown/)
- [Wikipedia — Wits and Wagers](https://en.wikipedia.org/wiki/Wits_and_Wagers)
- [Father Geek — Wits & Wagers Party review](https://fathergeek.com/wits-and-wagers-party/)
- [Jackbox Games — How audience play-along differs in each game](https://www.jackboxgames.com/blog/how-audience-play-along-differs-in-each-jackbox-game)
- [Jackbox Wiki — Trivia Murder Party (audience wagers on eliminations)](https://jackboxgames.fandom.com/wiki/Trivia_Murder_Party)
- [100% OJ Wiki — Norma](https://100orangejuice.fandom.com/wiki/Norma)
- [100% OJ Wiki — Bounty Hunt Overview](https://100orangejuice.fandom.com/wiki/Bounty_Hunt_Overview)
- [BGG — Rubber-banding vs snowballing](https://boardgamegeek.com/thread/904667/rubber-banding-vs-snowballing-catch-up-vs-stay-ahe)
- [Booknibs — The Rubber Band Effect](https://booknibs.com/nibs/the-rubber-band-effect-how-catch-up-mechanics-keep-players-engaged)
- Internal: docs/design/13-board-mode-research.md, 18-procession-build-spec.md, 03-board-research-digest.md; estate/procession/procession.gd, board_spaces.gd, presets.gd; core/final_stretch.gd; estate/estate_state.gd
