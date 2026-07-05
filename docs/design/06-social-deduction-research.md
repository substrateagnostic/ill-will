# Social Deduction at 4 Seats — research for the Theater

*2026-07-05. Research-only digest for the Theater venue (see
`05-director-notes-2026-07-05.md` → "The Theater"). Brief: 4-player couch,
one screen, gamepad/keyboard, verb budget = **stick + A + B** per player, no
phones, no typing, no drawing. Optional gamepad rumble. Goal: pick 2–3 social
formats that actually sing at exactly four seats and feed the estate's
grudge/royalty economy. Owner's stated pick: bluff-&-vote (Spyfall-style
odd-one-out). Owner liked the sabotage angle of the rejected trail-Saboteur
but not its execution.*

---

## (a) The 4-player problem, stated crisply

Most of the genre is balanced for 6–10. At exactly four, three distinct
failure modes bite:

1. **Blend-in games have nowhere to hide.** Spyfall, A Fake Artist Goes to
   New York, and The Chameleon are all "one person doesn't share the secret,
   act natural." Their fun scales with the size of the crowd the odd-one-out
   disappears into. Spyfall's own reviewers call four "really the bare
   minimum… it was pretty simple to figure out who the spy was, and there
   were no rounds during which the spy won" — the interrogation exhausts the
   suspect pool before the timer runs
   ([mechanicsofmagic.com](https://mechanicsofmagic.com/2022/04/07/critical-play-spyfall-10/),
   [amyflo.medium.com](https://amyflo.medium.com/critical-play-spyfall-fbbdb745c8c8)).
   A Fake Artist sets its floor at **five** precisely because the fake's job
   is too easy to spot below that
   ([whatsericplaying.com](https://whatsericplaying.com/2017/08/14/a-fake-artist-goes-to-new-york/),
   [shutupandsitdown.com](https://www.shutupandsitdown.com/games/a-fake-artist-goes-to-new-york/)).

2. **Majority-elimination voting degenerates into a 2v2 stalemate — and the
   tiebreak hands the game to the hidden player.** This is the concrete
   mechanism behind the owner's instinct. The Chameleon "really needs at
   least 5 people — when playing with 4, voting often results in ties, and
   since the start player breaks ties, the Chameleon often wins by simply
   choosing someone who wasn't him"
   ([theologyofgames.com](https://www.theologyofgames.com/blog/2018/3/22/you-come-and-go-a-single-take-review-of-chameleon)).
   Any format that resolves by "the table votes one person out" inherits this.

3. **Mafia math collapses.** The theoretical Mafia floor is four (2 mafia,
   2 town), but at that ratio the deduction is trivial — everyone knows the
   split, and one wrong lynch ends it
   ([Social deduction game — Wikipedia](https://en.wikipedia.org/wiki/Social_deduction_game),
   [Mafia — Wikipedia](https://en.wikipedia.org/wiki/Mafia_(party_game))).
   Blood on the Clocktower needs a Storyteller + 5 minimum and only comes
   alive at 7–15
   ([wiki.bloodontheclocktower.com/Setup](https://wiki.bloodontheclocktower.com/Setup)).
   Goose Goose Duck wants 5 minimum, best 6+
   ([gamertweak.com](https://gamertweak.com/how-many-players-goose-goose-duck/)).
   Among Us technically starts at four but its detection tools (vitals,
   cameras, task-witnessing) assume a dozen bodies
   ([Among Us — Wikipedia](https://en.wikipedia.org/wiki/Among_Us)).

**The three design escapes** (every good 4-player pitch below uses at least
two of them):

- **Give the hidden player a TASK, not just a hiding job.** Insider's whole
  innovation: the table cooperatively guesses a word *first*, and the traitor
  is secretly steering that shared task — so the round is satisfying even
  before anyone is unmasked, and behavior (not headcount) is the tell
  ([whatsericplaying.com/insider](https://whatsericplaying.com/2017/07/17/insider/),
  [dailyworkerplacement.com](https://dailyworkerplacement.com/2017/01/13/insider-20-questions-with-a-traitor/)).
- **Score every player's guess individually; never require a majority.**
  Distributed scoring dodges the 2v2 tie entirely — nobody needs a plurality,
  so ties are meaningless.
- **Make the secret emergent from play instead of assigned on a screen.**
  Hidden in Plain Sight hides you *as a body in a crowd of identical NPCs* —
  a 2–4-player local game whose deduction works fine at four because the NPC
  crowd supplies the hiding space the human table can't
  ([store.steampowered.com/app/303590](https://store.steampowered.com/app/303590/Hidden_in_Plain_Sight/),
  [popmatters.com](https://www.popmatters.com/performance-and-deception-in-hidden-in-plain-sight-2495488566.html)).

---

## (b) Format survey — 4-player verdicts

Input demand column flags what each needs beyond our budget (talk is fine —
couch is in-person; typing/drawing/phones are disqualifiers).

| Format | Floor where it sings | At 4 | Input demand | Verdict for the Theater |
|---|---|---|---|---|
| **Spyfall** | 5–6 | Bare-minimum; spy almost never wins, interrogation outs them fast ([src](https://mechanicsofmagic.com/2022/04/07/critical-play-spyfall-10/)) | Talk (fine); needs per-player secret location | Salvageable only if questioning is capped + scoring distributed |
| **A Fake Artist Goes to NY** | 5 | Below floor — fake too easy to spot ([src](https://whatsericplaying.com/2017/08/14/a-fake-artist-goes-to-new-york/)) | **Drawing** | Out (no drawing on stick+A+B) |
| **The Chameleon** | 5+ | Vote ties + tiebreak favors the hidden player ([src](https://www.theologyofgames.com/blog/2018/3/22/you-come-and-go-a-single-take-review-of-chameleon)) | Talk + per-player secret word | Only with distributed scoring, not majority-elimination |
| **Werewords** | 5–6 (4 min) | Playable: a Mayor answers yes/no while table guesses a word; werewolf hides in the guessing. But Mayor sits out deduction; thin at 4 ([src](https://gamerules.com/rules/werewords/)) | Talk; Mayor needs private word; **needs a yes/no oracle** | Fits if the **Executor** is the oracle (frees all 4 to play) |
| **Insider** | 4–8 | **Works at 4.** Co-op word-guess with a hidden steerer; behavior is the tell ([src](https://whatsericplaying.com/2017/07/17/insider/)) | Talk; 1 private role + Master role | **Strong** — model for Pitch 2 |
| **Coup** | 4–6 | Solid floor at 4; elimination bluff, no single traitor to stalemate ([src](https://www.theboardgamefamily.com/2014/09/coup-card-game-review/)) | Hidden 2-card hand per player | Delivery-heavy (private hands); playable but not couch-elegant |
| **Skull** | 3–6 | **Sings at 4.** Pure bluff, *no roles, no voting-out* — tension is distributed by design ([src](https://www.shutupandsitdown.com/games/skull/)) | Hidden face-down disc = 1 private bit (trivial on A/B) | **Excellent two-button fit**; bluff without the vote-tie trap |
| **Push the Button (Jackbox)** | 6+ | Weak at 4 — aliens don't even learn their teammates under 4-in-room; 15–20 min ([src](https://jackboxgames.fandom.com/wiki/Push_the_Button)) | **Phones**; too long | Out (phones, length) |
| **Fakin' It (Jackbox)** | 4–6 | Works, and it's *in-person only* — relies on reading faces, can't be streamed ([src](https://jackboxgames.fandom.com/wiki/Fakin'_It)) | Physical (raise hands, point) — no per-player screen | Good precedent for couch; validates face-reading over hidden text |
| **Among Us / Goose Goose Duck** | 6–10 | Detection tools assume many bodies; GGD wants 5 min ([src](https://gamertweak.com/how-many-players-goose-goose-duck/)) | Per-player screens | Out (per-player screens) |
| **Blood on the Clocktower** | 7–15 (+Storyteller) | Unfit — needs a dedicated Storyteller and 5 min just to seat ([src](https://wiki.bloodontheclocktower.com/Setup)) | Storyteller + big table | Out |
| **Split the Room / Fibbage** | 4–8 | Fine games, but writing/typing | **Typing** | Out |
| **Garticphone-likes / Salem** | 4+ | Drawing telephone / long accusation hand-management | **Drawing / long** | Out |
| **Hidden in Plain Sight** | **2–4 local** | **Best-in-class at 4** — hide as a body among identical NPCs; deduction is motion, not headcount ([src](https://store.steampowered.com/app/303590/Hidden_in_Plain_Sight/)) | Controllers only, **no secret screen at all** | **Strong** — model for Pitch 3 |

**Takeaways:** the games that survive at four either (i) drop roles/voting for
pure distributed bluff (**Skull**), (ii) wrap the traitor in a co-op task
(**Insider**), (iii) use an oracle to free all four to play (**Werewords** with
the Executor), or (iv) make the secret a body-in-a-crowd instead of a screen
reveal (**Hidden in Plain Sight**). Everything that resolves by "table votes
one out" or "blend into a crowd of humans" is a trap at four.

---

## (c) The one-screen secret-delivery problem

**The core tension.** Four people share one screen. Any secret the screen
shows, all four see. Fakin' It is instructive: it's one of the *only* Jackbox
games that can't be streamed or screenshared, because the hidden info lives in
players' faces, not on the screen — proof that the couch's strength is
in-person reading, and that on-screen hidden text is the thing to avoid
([jackboxgames.fandom.com/wiki/Fakin'_It](https://jackboxgames.fandom.com/wiki/Fakin'_It)).
Nintendo's answers on Switch are the reference set: rumble-coded info
(1-2-Switch "Ball Count"), eyes-closed audio phases, and honor-system
look-aways.

**Our constraints narrow the field hard.** No phones, no typing. Rumble is
**gamepad-only in Godot** (`Input.start_joy_vibration`) and *not wired in
`core/` today* — a keyboard or mouse player feels nothing. So rumble can only
ever be a **redundant** channel, never the sole secret carrier. That leaves
audio, eyes-closed, and timed private reveals — and, best of all, designs that
need **no delivery at all.**

**Ranked solutions for our input set (least awkward first):**

1. **Emergent secret — deliver nothing.** The secret is *which body on stage
   is a human* (Hidden in Plain Sight). Zero screen-reveal, zero eyes-closed,
   zero rumble; the deduction is emergent from motion. Ceiling: only works for
   body-in-crowd formats. **Least awkward by far.**
2. **One private bit via eyes-closed audio, narrated by the Executor.** For
   formats that need exactly one hidden role ("you are the traitor"), the
   One Night Ultimate Werewolf **app** is the shipped proof: a recorded
   narrator says "everyone, close your eyes," wakes the hidden role, and
   nobody has to sit out as moderator
   ([One Night app](https://apps.apple.com/us/app/one-night/id728175611),
   [alishasgamingblog](https://alishasgamingblog.wordpress.com/2016/08/08/everyone-close-your-eyes-one-night-ultimate-werewolf/)).
   **The Executor is our built-in narrator** — this is nearly free for us and
   theatrically on-brand. Low awkwardness *when only one bit is hidden.*
3. **Oracle offload — the hidden knowledge lives with the host, not a player.**
   Werewords keeps the secret word with a Mayor who only answers yes/no. If
   the **Executor** is the oracle, no player needs a private screen at all;
   all four play. Low awkwardness, but constrains the format to "guess what
   the host knows."
4. **Sequential timed private reveal** ("PLAYER 2 only — everyone else, eyes
   up," 3-2-1, flash, clear; repeat per seat). This is the honest cost of any
   *shared-word* odd-one-out (three players must learn a word the fourth must
   not). Widely shipped, but it's ~5s × 4 of stop-start and relies on the
   honor system. **Moderately awkward — minimize how many seats need it.**
5. **Rumble-coded secret.** Feel-a-pattern = you're the odd one (1-2-Switch
   lineage). Elegant on gamepads, invisible to keyboard/mouse players and not
   yet wired. **Only ever a redundant confirm, never the sole channel.**
6. **Controller-speaker audio** — our PC stack doesn't expose per-pad speakers
   reliably; **skip.**

**Design rule for the Theater:** prefer formats that need **zero or one**
hidden bit. Every additional per-seat secret you must show on the shared
screen adds an eyes-closed/look-away tax. The estate's pillar-1 "legible
deviousness — nothing hidden ever decides anything" is honored by the
**reveal**: the Theater is a walled garden where hidden info is allowed
*because it is always unmasked publicly within minutes and settled on the
visible ladder*, never as a silent adjustment.

---

## (d) Top 3 pitches for the Theater (ranked)

All three run 3–5 min (party-pacing target — a "5-minute resolution creates
addictive, high-energy bursts," and long deduction games drag on downtime
([boardgamesguide.com](https://boardgamesguide.com/tested-50-social-deduction-games-best-2026/),
[boardgamedesigncourse.com](https://boardgamedesigncourse.com/how-to-reduce-downtime-in-your-game/))).
All resolve into `placements` + `currency_events` per the module contract, so
the Reckoning pays them like any minigame. Voting, where it exists, is
**stick-to-target a portrait + A to lock** (B reserved as the format's action);
all use **simultaneous locked votes with distributed scoring** so the 4-player
tie/stalemate never resolves the round.

### #1 — THE SÉANCE  *(co-op + a paid saboteur — the sabotage angle, done right)*

**Elevator:** The four sit at the Executor's table to make a spirit spell out
a word. One of them was paid, in grudge, to make the séance fail — and not get
caught. (Insider's structure, inverted to sabotage to match the angle the
owner liked.)

- **Secret delivery (one bit, method #2):** eyes-closed Executor narration —
  *"Close your eyes. …Charlatan, the spirits are yours tonight."* Optional
  redundant rumble pulse to that pad. Only **one** player learns anything
  private; the other three share no secret. Cheapest possible delivery.
- **The co-op task (this is the Q4 answer — minimal task that makes sabotage
  detectable-but-deniable):** a shared **focus meter** decays over 90s. All
  four tap **A in rhythm** to push the planchette toward letters; the meter
  is legible to everyone *in aggregate*. Because four hands tap in parallel,
  no one can watch all of them — so a Charlatan mistiming taps (draining the
  meter) or nudging **B** onto a wrong letter is **deniable as clumsiness or
  lag**. The tell is behavioral, exactly like Insider's "who steered the
  conversation" — but negative. Word guessed before the meter dies = table
  wins; meter dies or timer runs out = spirits win (Charlatan wins).
- **Round flow (~4:00):** Cast (eyes-closed, 20s) → Séance co-op task
  (90s) → open talk while the buzzer looms (players accuse aloud, 30s) →
  **locked accusation vote** (stick+A, 15s) → Executor unmasks + settle (25s).
- **Votes with two buttons:** stick to swing the spotlight across the three
  other portraits, **A** to lock your single accusation; **B** stays the
  planchette action. Simultaneous reveal.
- **Economy:** the Charlatan is **paid grudge up front** (fits pillar-3 —
  grudge is the only currency for sabotage). If the séance **succeeds**, the
  three honest players split **royalty** (they profited from resisting).
  If it **fails and the Charlatan escapes**, they convert their grudge fee
  into a fat **royalty** payout — textbook "profited from the table's
  suffering." If **caught**, the Charlatan eats **grudge** and every player
  who fingered them earns **royalty**. Distributed — no majority needed.
- **Why it works at exactly 4:** the co-op task means the round is fun before
  anyone is unmasked (nobody waits to be voted out — pillar-2); the hidden
  player has a *task*, so 4p doesn't collapse to 2v2; behavioral+deniable
  detection scales *down* to four far better than crowd-blending scales; only
  one secret bit ever touches the screen.

### #2 — THE UNDERSTUDY  *(the owner's bluff-&-vote pick, re-engineered for 4)*

**Elevator:** The Executor casts a one-act play and hands everyone the same
SCENE — except one player got a blank script. Bluff your way through
rehearsal; find the faker.

- **Secret delivery (method #4, minimized):** sequential timed private reveal,
  dressed as theater — *"Lights down. PLAYER ONE, read your script…"* flashes
  the scene word (or `IMPROVISE` for the Understudy) for 3s, clears, next
  seat. ~20s total. This is the honest tax of any shared-word odd-one-out and
  the main reason this pitch ranks below the Séance.
- **The fix for Spyfall/Chameleon-at-4 (both escapes):** (1) **cap the
  rehearsal** — two rounds only, each player says exactly **one** spoken line
  that proves they know the scene. Unlimited interrogation is what outs the
  spy at four; capping preserves doubt. (2) **distributed scoring, never
  majority-elimination** — this is what kills the Chameleon 4p tie.
- **Round flow (~3:30):** Casting reveal (20s) → Rehearsal: 2 turns each,
  spotlight rotates, speak aloud, **A** to pass the spotlight (~90s) →
  **locked accusation** (stick+A, 20s) → if caught, the Understudy gets **one
  steal-guess** at the scene word, **B** to lock a word tile (20s) → unmask +
  settle (20s).
- **Votes with two buttons:** stick to target a portrait, **A** to lock;
  **B** is the Understudy's steal-guess only.
- **Economy:** each *informed* player who correctly fingers the Understudy
  earns **royalty**; the Understudy earns **royalty** for each vote they dodge
  (they thrived on the confusion). If caught, a correct steal-guess claws a
  chunk of grudge back into royalty (the faker who *read the room* still
  profits). Caught-and-wrong Understudy eats **grudge**.
- **Why it works at exactly 4:** distributed scoring means the 2v2 vote never
  stalemates the round; the two-line cap stops the small table from
  brute-forcing the faker; the *spoken* rehearsal supplies the social richness
  four bodies otherwise lack. It is, honestly, the thinnest of the three at
  four and carries the most delivery tax — but it is the smallest build and
  exactly the format the owner asked for.

### #3 — MASKED BALL  *(behavioral deduction — zero secret delivery)*

**Elevator:** The Theater stage floods with identical masked dancers. Four of
them are you. Complete your secret objective while spotting which dancers move
like humans — and mark one before the waltz ends. (Hidden in Plain Sight,
staged.)

- **Secret delivery: none.** Your identity *is* your controlled body; the
  deduction is "which dancer isn't an NPC." NPCs wander scripted loops; humans
  betray themselves by purposeful motion. This structurally dissolves the
  one-screen problem — nothing hidden is ever shown on the shared screen.
- **Round flow (~3:00):** a single 2:30 waltz. Players mingle among the crowd,
  complete a private objective (reach the balcony / curtsy to the throne 3×)
  for points, and spend their **one** mark. Reveal at the buzzer.
- **Votes with two buttons:** there is **no table vote** — elimination is the
  in-engine action, which sidesteps the vote-tie trap completely. **A** =
  a human action (dash/curtsy — advances your objective but risks looking
  non-NPC); **B** = **MARK** a dancer you believe is human (one shot, like
  HiPS's single bullet); stick = move.
- **Economy:** marking a human correctly = **royalty** (you exposed them for
  profit); being marked = **grudge** (you suffered); completing your secret
  objective = **points**. Fully distributed; reuses `roster[i].char_scene`
  KayKit dancers directly.
- **Why it works at exactly 4:** Hidden in Plain Sight is explicitly a 2–4
  local game and its deduction doesn't need a big table — the **NPC crowd** is
  the hiding space the four humans can't provide. No secret delivery, no vote
  ties, most robust-at-4 of the three. Cost: biggest build (crowd AI,
  objectives, tuned NPC motion) and it's action-deduction, not talk-and-bluff
  — so it belongs later, as the Theater's headliner, not the opener.

**Ranking rationale.** The Séance wins because it satisfies *both* of the
owner's expressed wants (Jackbox social energy **and** the sabotage angle),
is mathematically sound at four (co-op task + distributed payout), costs the
least secret-delivery (one bit via the Executor's voice), and slots perfectly
into the grudge→royalty rails. The Understudy is the familiar, smallest,
owner-requested opener but is inherently the thinnest at four and pays the
most delivery tax. Masked Ball is the strongest *structure* at four and the
most novel, but the biggest build and the least "talky" — a future headliner.

---

## (e) Verdict: can the trail-Saboteur return as a Theater special event?

**Yes — later, and only as an opt-in Theater-hosted night modifier with a
public settlement. Not as a silent always-on layer.**

Why it was "not quite right" bolted onto the pilgrimage trail: a
**night-long hidden traitor** violates pillar-1 (*legible deviousness —
nothing hidden ever decides anything*) and pillar-5 (*classic scoreboard
clarity — no hidden ladder adjustments*). Across a whole session it also
maximizes the genre's cardinal sin, downtime/paranoia, at estate scale — the
opposite of pillar-2 (*nobody ever waits*). A secret that steers a 90-minute
night and only resolves at the very end is exactly the "hour of administration"
that fast party groups reject
([hexagamers.com](https://hexagamers.com/best-social-deduction-board-games-2026/)).

But the **core idea survives** once it is bounded and legible, and the Theater
is the sanctioned container for it. Proposed return: **"The Long Con"** — a
Theater special event the Executor can invoke at a night's opening. One player
is secretly anointed Saboteur *for the whole night*; every Theater beat and
auction they quietly tilt banks **escrowed royalty**, revealed and settled
**only at the Will-reading** (night-end Reckoning). This keeps it:

- **legible at the settlement** — the ladder takes no hidden adjustment until
  the public reveal, so pillar-5 holds (the drama was hidden; the *outcome*
  was always going to be shown);
- **opt-in** — a special-event modifier, never the default night, so the
  baseline estate stays fully legible;
- **on the existing rails** — grudge escrow up front, royalty payout on a
  successful, unmasked-at-the-end con; the Executor (who already greets
  returning parties by their ledger) is the natural keeper of the secret.

So: the sabotage *feeling* the owner liked ships immediately and safely at
round scale as **The Séance**; the night-long version returns later as an
opt-in Theater event whose whole point is a big, public reveal at the Will —
which is the estate telling the story back, on brand.

---

## Sources

- Spyfall at low counts — mechanicsofmagic.com/2022/04/07/critical-play-spyfall-10, amyflo.medium.com/critical-play-spyfall-fbbdb745c8c8
- A Fake Artist floor of 5 — whatsericplaying.com/2017/08/14/a-fake-artist-goes-to-new-york, shutupandsitdown.com/games/a-fake-artist-goes-to-new-york
- Chameleon 4-player tie/tiebreak — theologyofgames.com/blog/2018/3/22/you-come-and-go-a-single-take-review-of-chameleon
- Werewords rules/Mayor oracle — gamerules.com/rules/werewords
- Insider (co-op task + hidden steerer) — whatsericplaying.com/2017/07/17/insider, dailyworkerplacement.com/2017/01/13/insider-20-questions-with-a-traitor
- Coup player count — theboardgamefamily.com/2014/09/coup-card-game-review
- Skull (pure bluff, no roles/voting) — shutupandsitdown.com/games/skull, amazon.com Skull listing (30-min, 3–6, few-min rounds)
- Push the Button (needs 6+, 15–20 min, phones) — jackboxgames.fandom.com/wiki/Push_the_Button
- Fakin' It (in-person only, face-reading) — jackboxgames.fandom.com/wiki/Fakin'_It
- Among Us / Goose Goose Duck counts — en.wikipedia.org/wiki/Among_Us, gamertweak.com/how-many-players-goose-goose-duck
- Blood on the Clocktower setup/floor — wiki.bloodontheclocktower.com/Setup
- Mafia/Social-deduction math — en.wikipedia.org/wiki/Mafia_(party_game), en.wikipedia.org/wiki/Social_deduction_game
- Hidden in Plain Sight (2–4 local, blend among NPCs) — store.steampowered.com/app/303590, popmatters.com/performance-and-deception-in-hidden-in-plain-sight-2495488566
- One Night Ultimate Werewolf app (eyes-closed audio narration) — apps.apple.com/us/app/one-night/id728175611, alishasgamingblog.wordpress.com/2016/08/08/everyone-close-your-eyes-one-night-ultimate-werewolf
- Party pacing / downtime — boardgamesguide.com/tested-50-social-deduction-games-best-2026, boardgamedesigncourse.com/how-to-reduce-downtime-in-your-game, hexagamers.com/best-social-deduction-board-games-2026
