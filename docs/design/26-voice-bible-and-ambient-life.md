# 26 — The Voice Bible & Ambient Life of the Estate

*The writing standard for the whole ILL WILL anthology, plus a troupe of
humorous background NPCs for the estate grounds and the Procession board.*

Written 2026-07-16 from a read of the shipped player-facing strings
(`estate/`, `core/moment_scribe.gd`, the Procession host, and four minigames)
and a scan of how acclaimed comedy games write to a room. No code was changed;
this is the reference the strings should be edited *toward*, on their own
schedule.

---

## 0. The finding, in one breath

The estate already has a voice. It is one of the best things in the build. The
Executor, the chronicle, the newsreel, the will-reading and the Procession host
all speak the same immaculate, dry, probate humor — legalese deployed deadpan,
cruelty filed as bookkeeping, affection recorded as a liability. That register
is the anthology's crown jewel and this doc's gold standard.

The problem is **two voices, not one.** The estate speaks in probate. The
*minigame floor* — the banners that flash mid-round — too often drops into
generic arcade hype: `GRAB IT!`, `ROB THE WAKE!`, `GREED PUNISHED!`, `GET
READY`, exclamation marks everywhere, gamer-speak like `GRIEFED`. Those lines
belong to a cheaper game. They are the seams this doc exists to close.

The fix is **not** to make every banner a two-sentence Executor aside — a banner
must read at a glance while someone is being shoved off a platter. The fix is to
recognize the anthology has **two registers that share one dialect**, and to
hold the floor to the estate's dialect even when it has to shout.

---

## 1. THE VOICE BIBLE

### 1.1 The register, in one paragraph

**The estate is a bureaucracy that outlived its family and now processes grief
as paperwork.** It speaks of death as an administrative event, of money as the
only sincerity, and of kindness as an anomaly it has logged for review. Its
humor is never a joke it tells; it is the *gap* between the horror on screen
(betrayal, ruin, a body) and the flat clerical tone the estate uses to file it.
The Executor — the estate's voice — is never cruel out of passion; he is
indifferent, and indifference to horror is funnier than malice. Sentences are
complete and end in periods. Observations land in **two beats**: a plain
statement, then a drier codicil that undercuts it (*"The shrine blesses you. It
has low standards and a long memory."*). Nobody is ever flattered, praise is
taxed on arrival, and the estate refers to itself in the third person as an
institution — *"The estate remembers"* — because it has no feelings, only
records, and it forgets nothing however politely it is asked.

### 1.2 The cousins we're writing next to

- **Grim Fandango** — the closest relative. Schafer set a film-noir crime
  register *inside a bureaucracy of death* (the DoD, travel visas, sales
  quotas). The joke is that the afterlife runs on paperwork and everyone plays
  it straight. That deadpan-institutional-death register is *exactly* ours —
  the estate is the Department of Death Recordkeeping.
- **Hades (Supergiant)** — reactive lines earn their humor through *volume and
  specificity*: the narrator/characters have a distinct thing to say for the
  *specific* event, and repetition is the enemy immersion dies on. Their
  answer was sheer variant count. Ours can't be 21,000 lines, but the lesson
  holds: **the line that fires most often needs the most variants.**
- **The Stanley Parable** — deadpan escalation. The humor is timing and the
  refusal to raise its voice; the narrator gets *drier* as things get worse,
  never louder. The estate should do the same — its worst news is its flattest
  line.
- **Untitled Goose Game** — wordless comedy: set-up + punchline delivered by
  *behavior*, no text at all. This is the model for the ambient troupe in §3.
  The best background gag needs zero words; it just needs a loop with a beat.

### 1.3 The ten rules

1. **The Executor never uses an exclamation mark.** Emphasis comes from
   understatement, not volume. (The minigame floor — §1.4 Voice B — may spend
   *one*, rarely. The estate proper spends none.)
2. **Death is administrative.** A death is a filing, a transfer, a line in a
   ledger — never a tragedy the estate dignifies as one. *"Two grudge, all the
   same."* Cause of death is a form field, not a scream.
3. **Affection is expressed as liability.** Warmth, mercy, and friendship
   appear only as costs, risks, or clerical irregularities. Kindness is *"the
   anomaly the estate has logged for review."*
4. **Land the second beat.** The register's engine is the two-part line: flat
   statement, then a drier codicil that undercuts it. If an estate line is one
   sentence, check whether it dropped its punchline. (Rule of thumb: *the
   estate observes in two beats; the floor hits in one.*)
5. **The estate is an institution, in third person, in the present tense.**
   *"The estate remembers." "The house keeps what it touches."* Never "I,"
   never a mood — only records and policy. The Executor is its mouth, not its
   heart.
6. **Cruelty is bookkeeping, not spite.** The estate does not gloat; it
   *notes, logs, files, itemises, declines to itemise, rounds up, opens a book,
   keeps the receipts.* Accounting verbs, applied to human pain, deadpan.
7. **Legalese, deployed precisely and without winking.** *Codicil, deed,
   actionable, in candour, retroactively, on principle, for want of funds,
   under protest.* Used correctly. The joke is that it's sincere.
8. **No engineer-speak, ever, in player-facing fiction.** `REMOTE — plays from
   their own machine`, `mirror`, `bot`, `griefed` are bugs in the world. The
   estate says *"attends from a distant house,"* *"plays itself until further
   notice."* (Diagnostic prints and dev flags are exempt — they aren't fiction.)
9. **Specificity over hype. Name the thing; never cheerlead.** The estate
   *announces, describes, or bills* — it does not say `GET READY` or `GO`. A
   generic arcade interjection is the sound of a different game leaking in.
10. **The player is never flattered.** *"no one, on principle, is flattered."*
    Where praise appears it is immediately taxed — *"Piety pays, this once,
    under protest."* The estate's respect is only ever grudging, and its
    grudges are only ever respected.

### 1.4 Two registers, one dialect

| | **VOICE A — THE ESTATE** | **VOICE B — THE FLOOR** |
|---|---|---|
| Who | Executor, chronicle, newsreel, will, auction, house rules, lobby quips, Procession host | In-minigame action banners, round starts, kill callouts, pot flashes |
| Where | `estate/*`, `core/moment_scribe.gd`, `estate/procession/executor_host.gd` | `minigames/*/*.gd`, `scripts/main.gd` |
| Length | Full sentences, two beats, periods | ≤ 4 words ideal, glanceable, readable on the 10th viewing |
| Exclamation | Never | At most one, rationed |
| Tone | Dry probate, indifferent | Punchy — but in the estate's *dialect*, not generic arcade |
| Test | "Would the Executor sign this?" | "Is this the estate shouting, or a stock party game?" |

The floor is *allowed to shout.* It is not allowed to shout in someone else's
voice. `GRAB IT!` is a stock game shouting. `THE POT SITS UNGUARDED` is the
estate shouting. Same length, same read speed, same beat — one belongs to us.

### 1.5 Exemplar rewrites — BEFORE (shipped) → AFTER (toward)

The gold-standard lines are already in the build; these rewrites pull the
*floor* up to them and tighten a few functional estate strings. `[V-B]` = the
line is Voice B (floor), where a single punchy beat is correct.

1. `minigames/greed/greed.gd:441` `[V-B]`
   BEFORE: **"GRAB IT!"** (fires every round start, no variant)
   AFTER: **"THE POT IS UNGUARDED"** / pool with *"CLAIM IT," "THE POT SITS
   OPEN," "NO ONE OWNS IT YET."* Kills the generic hype; still one-glance.

2. `minigames/widows_gaze/widows_gaze.gd:352` `[V-B]`
   BEFORE: **"ROB THE WAKE!"** (fires every steal window)
   AFTER: **"SHE WEEPS — CREEP"** / pool with *"THE PARLOR IS OPEN," "HER BACK
   IS TURNED," "GO, QUIETLY."*

3. `minigames/greed/greed.gd:352` `[V-B]`
   BEFORE: **"GREED PUNISHED!\nTHE POT SCATTERS"**
   AFTER: **"TOO GREEDY.\nTHE POT SCATTERS"** — the second line was always
   good; cut the `PUNISHED!` hype and let the consequence carry it.

4. `minigames/greed/greed.gd:1029` `[V-B]`
   BEFORE: **"LAST BANKS!"**
   AFTER: **"THE CHUTE CLOSES SOON"** / *"LAST CALL AT THE CHUTE."*

5. `minigames/greed/greed.gd:385`
   BEFORE: **"%s WINS GREED INC.!"**
   AFTER (results `win_title`): **"{name} KEEPS THE POT — AND THE ENMITY"**
   (matches Widow's Gaze's excellent `"{name} INHERITS THE WAKE"` model.)

6. `scripts/main.gd:672` `[V-B]`
   BEFORE: **"%s DIED!\nDEATH BY: %s"**
   AFTER: **"%s, DECEASED\nCAUSE OF DEATH: %s"** — a death certificate, not a
   scoreboard. This is the register hiding in plain sight; `DEATH BY` → `CAUSE
   OF DEATH` does the whole job.

7. `scripts/main.gd:500` `[V-B]`
   BEFORE: **"TOO SLOW — TRAP FORFEITED"**
   AFTER: **"TOO SLOW. THE CLAIM LAPSES."** — a forfeited trap is a lapsed
   filing.

8. `scripts/main.gd:552` `[V-B]`
   BEFORE: **"%s HIT THE ADVENTURE GUTTER!"** ("adventure gutter" is stock
   mini-golf, off-world)
   AFTER: **"%s STRAYED FROM THE PLOT"** (the estate has plots; the pun is
   free and on-register).

9. `scripts/main.gd:865` `[V-B]` — **banned word**
   BEFORE: **"%s GRIEFED %s"** (`griefed` = gamer-speak, rule 8)
   AFTER: **"%s WRONGED %s"** / *"%s SETTLED UP WITH %s."*

10. `scripts/main.gd:310` `[V-B]`
    BEFORE: **"CHAOS ROUND\nNO WAITING — ALL LIVE"**
    AFTER: **"EVERY CLAIM AT ONCE\nNO ONE WAITS THEIR TURN"** — keeps the
    "everyone goes simultaneously" read, loses the generic `CHAOS`.

11. `estate/estate.gd:409` / `estate/howto_cards.gd:409` — **banned phrase**
    BEFORE: **"GET READY — %s"** (the exact hype rule 9 forbids, in our own UI)
    AFTER: **"TAKE YOUR PLACES — %s"** / *"THE ESTATE IS SEATING YOU — %s."*

12. `estate/estate.gd:1626`
    BEFORE: **"THE AUCTION — bid grudge to choose the game"** (single-shot,
    every auction, no variant)
    AFTER: pool headers — **"THE AUCTION — spite is legal tender," "THE
    AUCTION — the estate accepts grudge and exact change," "THE AUCTION —
    generosity is not on the block."** (Lifts the already-great `exec_lines`
    into the header slot.)

13. `minigames/widows_gaze/widows_gaze.gd:586` `[V-B]`
    BEFORE: **"%s FED %s TO THE WIDOW!"**
    AFTER: **"%s FED %s TO THE WIDOW"** — drop the `!`; the sentence is already
    the darkest thing on screen and doesn't need help.

14. `minigames/greed/greed.gd:715` `[V-B]`
    BEFORE: **"%s MUGGED %s!"**
    AFTER: **"%s RELIEVED %s OF IT"** — theft as a courtesy, estate-voiced.

15. `estate/estate.gd:2058` (will-reading head, identical every night of a run)
    BEFORE: **"The estate has reviewed the evening's conduct and finds it, on
    the whole, actionable.\n%s wins the night."** (perfect line — but verbatim
    on nights 1–9)
    AFTER: keep as the anchor; **add 3 sibling variants** so a long run doesn't
    echo (see §2). E.g. *"The estate has audited the evening and finds no one
    blameless. %s is merely least so."*

16. `estate/net_lobby.gd:70` — **engineer-speak in fiction**
    BEFORE: **"THE WIRE TO %s WENT DEAD — %s PLAYS ITSELF UNTIL FURTHER
    NOTICE"** (half-right: "plays itself" is great, "the wire" is techy)
    AFTER: **"%s HAS BEEN CALLED AWAY — THE ESTATE WILL KEEP THEIR SEAT, AND
    THEIR GRUDGES"** — a guest leaving, not a dropped socket.

17. `estate/howto_cards.gd:214`
    BEFORE: **"%s — REMOTE — plays from their own machine"**
    AFTER: **"%s — attends from a distant house"** (fiction layer). Keep the
    functional `REMOTE LINK · N ms` on the dev/status chip.

18. `minigames/greed/greed.gd:1020` — **KEEP (exemplar)**
    **"NOBODY HAS BANKED —\nTHE POT GROWS RESTLESS"** — this is Voice B done
    correctly: punchy, glanceable, and unmistakably *our* dialect. Use it as
    the template for every rewrite above.

19. `estate/estate.gd:481` — **KEEP (exemplar)**
    **"Wiping a slot erases that estate's monuments, ledger, and wardrobe. The
    Executor will pretend not to notice."** Two-beat, indifferent, perfect.

20. `estate/procession/executor_host.gd:22` — **KEEP (exemplar of the standard)**
    **"The shrine blesses %s (+3♠). It has low standards and a long memory."**
    This one line contains the whole bible: reward, then the codicil that sours
    it, no exclamation, bookkeeping cruelty. When in doubt, write toward this.

### 1.6 Banned constructions

- **Exclamation inflation.** More than one `!` in a line; any `!` in Voice A.
  `GRAB IT!!`, `PUNISHED!`, `WINS THE MATCH!` — the estate does not raise its
  voice, and the floor raises it once at most.
- **Generic arcade hype.** `GET READY`, `GO!`, `GO GO GO`, `NICE!`, `GREAT!`,
  `COMBO`, `PERFECT!`, `FIGHT!`, `READY?`. Name the specific thing instead.
- **Engineer / gamer-speak in fiction.** `bot`, `mirror`, `the wire`, `socket`,
  `remote machine`, `respawn`, `griefed`, `AFK`, `lag`, `sync`. (Fine in
  diagnostic `print()`s and CLI flags — those aren't the world talking.)
- **Cheerleading the player.** Second-person praise: `YOU'RE ON FIRE`, `AMAZING
  RUN`, `WELL DONE`. The estate does not flatter; if it must acknowledge skill,
  it bills it (*"impressive, and noted against you"*).
- **Sincere sentiment, unsalted.** Any line expressing warmth, hope, or comfort
  without a countervailing dry beat. Kindness must cost something.
- **Emoji and kaomoji** in estate/floor text (the ♠ grudge glyph is the sole
  sanctioned symbol; it is currency, not decoration).
- **Two exclamation registers colliding.** Don't stack `CHAOS ROUND!` +
  `ALL LIVE!` — one beat, one breath.
- **The naked verb of hype.** `SMASH`, `CRUSH`, `DOMINATE`, `DESTROY` as
  standalone encouragement. (They're fine as literal mechanics — a crusher
  head crushes — but not as morale.)

---

## 2. Line pools — where repetition kills the joke

Hades' lesson: **the line that fires most often needs the most variants.** A
joke told on the 2nd, 5th, and 9th viewing is only funny if it isn't the same
joke. Below, "current" is what's in the build; flag any 1-variant line that
fires more than once per session.

| Moment | Fires | Current variants | Target | Notes |
|---|---|---|---|---|
| **Round-start floor banner** (greed `GRAB IT!`, WG `ROB THE WAKE!`) | every round, every game | **1** each | **4–5** | Highest-repetition strings in the build. Top priority. |
| **Kill / theft attribution** (par death credit, WG "FED TO THE WIDOW", greed "MUGGED", tilt shove) | many per round | 1–2 | **5–6** | Vary the verb, keep the victim's name; this is where the estate's cruelty shines. |
| **Auction header** (`estate.gd:1626`) | every auction | **1** | **4** | Fold in the `exec_lines` pool (already 3, `estate.gd:1639`). |
| **Auction Executor quip** (`estate.gd:1639`) | every auction | 3 | **6** | Good already; extend so a 7-game night doesn't repeat. |
| **Will-reading head** (`estate.gd:2058`) | every night | **1** | **4** | Verbatim across a 9-night run right now. Anchor + 3 siblings. |
| **Lobby greeting** (`estate.gd:1169`) | every lobby entry | 4 + 1 rare | **keep** | Model implementation — ledger-driven, has a rare Easter line. |
| **Procession space landings** — SHRINE/GRAVE/STALL/CODICIL etc. (`executor_host.gd`) | every player, every round | 3–5 each | **keep**; bump `BLANK` (3→6) and `CODICIL_SHORT` (2→4) | `BLANK` fires most (any empty tile) yet has the fewest — raise it. |
| **Chronicle observations** (`estate_state.gd:589`) | 2 per will-reading | 25+ templates | **keep** | The jewel. Data-gated so only earned lines fire. Gold standard for pooling. |
| **Newsreel intertitles** (`newsreel.gd`) | per still | ACT-numbered + caption | **keep** | Structural variation (Roman numerals + moment caption) does the work. |
| **GET READY / take-your-places card** (`howto_cards.gd:409`) | every game launch | **1** header | **3** + rename | See rewrite #11; also the banned-phrase fix. |
| **Vendetta notice** (`estate.gd:1630`) | rare (only after a hunt) | 1 template | **keep** | Low frequency earns a single strong line. |
| **Results `win_title`** (per game) | once per match | 1 each | **keep, but theme each** | WG's `INHERITS THE WAKE` is the bar; greed/par/etc. should each get a bespoke estate-voiced one (rewrite #5). |

**Pooling implementation note:** the codebase already has the right pattern —
`ProcessionExecutor.pick(pool, rng, args)` (`executor_host.gd:109`) draws a
seeded line so the couch and a net mirror hear the *same* eulogy. New pools
should reuse it (or `EstateState.rng`) so online stays deterministic. Do **not**
`randi()` a floor banner without the seeded RNG — it desyncs the mirror.

---

## 3. The Ambient Life Troupe

Untitled Goose Game's rule: **a background gag is a set-up and a punchline
delivered by behavior, needing zero words.** Each troupe member below is a short
loop (2–4s blend, or a 30–90s sequence per the crowd-animation guidance) with a
*beat* — a pause where the joke lands — plus an optional chronicle speech bubble
for the ones that gossip.

### 3.0 Asset reality check (important)

The brief assumed a forge lane producing *"executor figure, mourners x2, crow,
groundskeeper, hearse, lantern posts."* The **actual** `tools/meshy_manifest.json`
+ `assets/models/meshy/` tells a different story:

| Brief assumed | Reality |
|---|---|
| executor figure | ✅ `executor_butler.glb` (shipped) |
| hearse | ✅ `generated/board_hearse_cart.glb` |
| lantern posts | ✅ `estate_lamppost`, `stone_lantern`, `board_waypoint_lantern` |
| crow | ⚠️ **only a static raven baked into `estate_dry_fountain.glb`** — no free rigged crow |
| mourners x2 | ❌ **not in the manifest** |
| groundskeeper | ❌ **not in the manifest** — though `estate_wheelbarrow` (a groundskeeper's prop) exists |
| — | ✅ bonus: `seagull.glb` exists and is **canon** (the first-guest field report, `estate.gd:1168`) |

So the troupe is split into **reuse-only** members (ship today with existing
assets + a shader/anim) and **needs-a-figure** members (flagged; either forge
`npc_*` or re-skin a KayKit walker). Character walkers already exist —
`Barbarian/Knight/Mage/Rogue.glb` (`estate.gd:1085`) — and can be re-textured
muted and puppeted as idle NPCs at near-zero asset cost, which is how the
reuse-first members work.

### 3.1 THE GROUNDSKEEPER — "Old Rake"

- **Behavior loop:** rakes three leaves (4s) → straightens, hand on back,
  surveys the pile → shoulders drop (a sigh) → the same three leaves respawn at
  his feet → rake again. The pile **never grows.** Occasionally a raked leaf
  rolls back downhill and he watches it, unmoving, for a full beat.
- **One-line gag:** Sisyphus with a rake. The lawn will outlast him and he
  knows it.
- **Lives:** SW corner by `estate_wheelbarrow` + `estate_dead_tree` (both exist).
- **Asset:** ⚠️ needs a figure — reuse KayKit `Barbarian.glb` re-textured in
  muted browns + a rake prop, **or** forge `npc_groundskeeper`. Reuses
  `estate_wheelbarrow`, `estate_dead_tree`.
- **Chronicle?** Yes, rarely — a small speech bubble mutters a real
  `chronicle_lines()` fact as if it's shop-talk: *"they say [NAME]'s raised
  four monuments. none of 'em mention kindness. i just do the leaves."*

### 3.2 THE PUNCTUAL MOURNER — "The Double-Booked Widower"

- **Behavior loop:** bows head at a headstone (6s) → checks a pocket watch →
  glances toward the gate → checks the watch **again** → dabs one eye → resumes
  the bow. The grief is real; the *appointment after it* is realer.
- **One-line gag:** he is very sorry, and he is going to be very late.
- **Lives:** the graves cluster (`grave_headstone_plain/cracked`, etc. — all
  exist).
- **Asset:** ❌ not in manifest — re-skin KayKit `Mage.glb` or `Rogue.glb` in
  black, **or** forge `npc_mourner_a`. Reuses the `grave_*` set.
- **Chronicle?** Yes — standing at a *monument*, his bubble reads the epitaph
  aloud, deadpan: the literal `"%s has erected four monuments. None mention
  kindness."` line — delivered as a man reading a gravestone, which is the
  joke's natural home.

### 3.3 THE GALLERY — crows with opinions

- **Behavior loop:** preen → hop along the rail → one caws, and a beat later
  (comic timing) another answers → all freeze and go silent when a walker comes
  near → resume once it passes. They physically **shuffle to face whoever is
  currently losing** the night.
- **One-line gag:** a peanut gallery that has already decided how you'll do.
- **Lives:** `estate_iron_gate`, `estate_dead_tree`, `estate_lamppost` (all
  exist).
- **Asset:** ⚠️ needs a **free** rigged crow — the only corvid in the manifest
  is the *static* raven fused into `estate_dry_fountain.glb`. Forge `crow`
  (simple 2-bone flap + hop) or extract/re-pose the fountain raven.
- **Chronicle?** **Yes — this is the centerpiece.** The crows *gossip.* A
  speech bubble over the flock cycles real `chronicle_lines()` — *"[NAME] came
  for [PREY], once. The estate has opened a file, in pencil."* — as overheard
  birds. It's the most natural vector for the estate's memory to leak into the
  grounds as ambient chatter, and it's explicitly encouraged. **Build this one.**

### 3.4 THE PATIENT GHOST — "The Queuer"

- **Behavior loop:** stands in an orderly queue of exactly one → shuffles
  forward 0.2m → waits → gestures *"after you"* to no one → when a living
  walker passes, lets them cut in front, then resettles at the back of the
  (empty) line.
- **One-line gag:** death did not cure his manners about queues.
- **Lives:** by `board_crypt_door` or the `auction_podium` (both exist).
- **Asset:** ✅ **reuse-only** — any KayKit walker + a translucent float shader.
  No new asset. Reuses existing character `.glb`s.
- **Chronicle?** Optional — a soft murmur: *"I was told there'd be a reading."*
  (Ties to the will-reading; keep it wordless-leaning per Goose-Game if bubbles
  get noisy.)

### 3.5 THE VENGEFUL SEAGULL — canon, wordless

- **Behavior loop:** wheels overhead → dives at a standing walker or prop →
  struts insolently → steals a leaf from Old Rake's pile (**crosses §3.1** —
  it's the seagull who undoes the raking) → drops a "gift" on the auction
  podium → wheels off.
- **One-line gag:** the estate's oldest grudge has feathers. It answers to no
  one and it remembers the auction podium specifically.
- **Lives:** everywhere, airborne.
- **Asset:** ✅ `seagull.glb` (shipped). No new asset.
- **Chronicle?** No — **wordless by design** (the Goose-Game anchor of the
  troupe; its whole bit is physical). Already honored in fiction: the rare
  lobby line *"The first guest left a note about the seagull… it agrees it was
  beautiful."* (`estate.gd:1168`). Let the bird earn that line on the lawn.

### 3.6 THE CORTÈGE OF ONE — the hearse that won't leave

- **Behavior loop:** the horseless hearse creaks forward 0.5m on the drive →
  halts → waits (8s) as if for a passenger taking their time → its curtain
  twitches (empty) → settles back to where it started. It never departs.
- **One-line gag:** a funeral that can't quite leave — because the estate never
  lets anyone.
- **Lives:** the front drive / `manor_gate`.
- **Asset:** ✅ `board_hearse_cart.glb` + a swinging `stone_lantern` /
  `board_waypoint_lantern` (all exist). No new asset.
- **Chronicle?** Yes — a small placard/board on the hearse slowly rotates a
  chronicle line: *"The estate has recorded five nights. It forgets none of
  them, however politely it is asked."*

### 3.7 THE MOODY LANTERNS — ambient life, no figure

- **Behavior loop:** every lantern glows steady except **one runt** that
  gutters on its own rhythm → dims → dark for ~1s → **pops** back a touch too
  bright → the nearest crow flaps off its perch (**crosses §3.3**) → settles.
- **One-line gag:** the estate's infrastructure has moods, and one lamp is
  having a worse night than you.
- **Lives:** the lantern line along the path.
- **Asset:** ✅ **reuse-only** — existing lantern props + a light animation
  curve. No new asset. (Goose-Game's lesson that *environment can be a
  character* — this is the wordless, figureless entry that costs nothing.)

### 3.8 Troupe summary

| # | Member | Chronicle? | Asset status | Crosses |
|---|---|---|---|---|
| 3.1 | Old Rake (groundskeeper) | rare mutter | ⚠️ needs figure (or re-skin Barbarian) | fed on by 3.5 |
| 3.2 | The Punctual Mourner | reads epitaphs | ❌ needs figure (or re-skin Mage/Rogue) | — |
| 3.3 | The Gallery (crows) | **YES — centerpiece gossip** | ⚠️ needs free crow | scatters in 3.7 |
| 3.4 | The Patient Ghost | optional murmur | ✅ reuse walker + shader | — |
| 3.5 | The Vengeful Seagull | no (wordless, canon) | ✅ `seagull.glb` | steals from 3.1 |
| 3.6 | The Cortège of One (hearse) | rotating placard | ✅ `board_hearse_cart` | — |
| 3.7 | The Moody Lanterns | no | ✅ reuse props | startles 3.3 |

**Ship order:** 3.4 / 3.5 / 3.7 first (zero new assets, immediate life on the
grounds), then 3.6, then commission the crow for 3.3 (the chronicle-gossip
payoff justifies the one forge), then the two human figures 3.1 / 3.2.

---

## 4. String audit table

`file:line` · current · verdict. **keep** = at the standard. **rewrite** = see
§1.5. **pool** = needs variants (§2). **KEEP★** = exemplar, write toward it.

| file:line | current (abbrev.) | verdict |
|---|---|---|
| `estate/estate.gd:543` | "a party nobody asked for" | KEEP★ |
| `estate/estate.gd:481` | "…The Executor will pretend not to notice." | KEEP★ |
| `estate/estate.gd:1157` | "…it was not, in candour, you." | KEEP★ |
| `estate/estate.gd:1168` | seagull first-guest rare line | KEEP★ |
| `estate/estate.gd:1169-1173` | lobby greeting pool (4) | keep |
| `estate/estate.gd:1626` | "THE AUCTION — bid grudge to choose the game" | rewrite + pool |
| `estate/estate.gd:1639` | exec_lines auction quip (3) | pool (→6) |
| `estate/estate.gd:1630` | vendetta notice ("opened a book on the reprisal") | keep |
| `estate/estate.gd:2058` | will-reading head ("…on the whole, actionable.") | KEEP★ + pool (→4) |
| `estate/estate.gd:2076` | "The matter of %s and %s remains open. The estate is patient." | KEEP★ |
| `estate/estate.gd:409` (`howto_cards.gd:409`) | "GET READY — %s" | rewrite (banned phrase) + pool |
| `estate/howto_cards.gd:214` | "%s — REMOTE — plays from their own machine" | rewrite (engineer-speak) |
| `estate/howto_cards.gd:289` | "You are new to the estate, so it will explain itself. Once…" | KEEP★ |
| `estate/howto_cards.gd:296-302` | house-rules five lines (ROYALTIES "kindest cruelty" etc.) | KEEP★ |
| `estate/howto_cards.gd:12-25` | HOWTO goals ("The lead is a rumor," "ramming is diplomacy") | KEEP★ |
| `estate/net_lobby.gd:70` | "THE WIRE TO %s WENT DEAD…" | rewrite (engineer-speak) |
| `estate/net_lobby.gd:51` | "%s JOINS FROM AFAR" | keep |
| `estate/procession/executor_host.gd:15-99` | all Procession pools (GREETING…WILL_OPEN) | KEEP★ |
| `executor_host.gd:82` (BLANK) | 3 variants, fires most often | pool (→6) |
| `executor_host.gd:53` (CODICIL_SHORT) | 2 variants | pool (→4) |
| `estate/estate_state.gd:274-308` | superlative award lines (THE SNAKE/DOORMAT…) | KEEP★ |
| `estate/estate_state.gd:589-678` | chronicle_lines (25+ templates) | KEEP★ |
| `estate/newsreel.gd:259,267` | title/end intertitles ("…in full and without mercy") | KEEP★ |
| `estate/newsreel.gd:223` | "AN UNRECORDED NIGHT / the estate remembers nothing it can show" | KEEP★ |
| `core/moment_scribe.gd:34` | DEFAULT_DECIDING "THE DECIDING MOMENT" | keep |
| `minigames/greed/greed.gd:441` | "GRAB IT!" | rewrite + pool (top priority) |
| `minigames/greed/greed.gd:352` | "GREED PUNISHED!\nTHE POT SCATTERS" | rewrite |
| `minigames/greed/greed.gd:1020` | "NOBODY HAS BANKED —\nTHE POT GROWS RESTLESS" | KEEP★ (Voice-B model) |
| `minigames/greed/greed.gd:1029` | "LAST BANKS!" | rewrite |
| `minigames/greed/greed.gd:385` | "%s WINS GREED INC.!" | rewrite (win_title) |
| `minigames/greed/greed.gd:715` | "%s MUGGED %s!" | rewrite + pool |
| `minigames/greed/greed.gd:211` | goal "The pot fills forever…slow, glowing target." | KEEP★ |
| `minigames/widows_gaze/widows_gaze.gd:352` | "ROB THE WAKE!" | rewrite + pool |
| `minigames/widows_gaze/widows_gaze.gd:317` | "THE WIDOW WEEPS" | keep |
| `minigames/widows_gaze/widows_gaze.gd:545` | "SHE GROWS SUSPICIOUS" | keep |
| `minigames/widows_gaze/widows_gaze.gd:586` | "%s FED %s TO THE WIDOW!" | rewrite (drop !) + pool |
| `minigames/widows_gaze/widows_gaze.gd:933-936` | "THE WILL IS READ / …INHERITS THE WAKE" | KEEP★ (win_title model) |
| `minigames/seance/seance.gd:393` | "the Theater presents" | KEEP★ |
| `minigames/seance/seance.gd:924` | "THE SITTING BEGINS" | keep |
| `minigames/seance/seance.gd:793` | cast card "YOUR COLOUR HAS A VOICE" | keep |
| `scripts/main.gd:672` | "%s DIED!\nDEATH BY: %s" | rewrite (→ death certificate) |
| `scripts/main.gd:500` | "TOO SLOW — TRAP FORFEITED" | rewrite |
| `scripts/main.gd:552` | "%s HIT THE ADVENTURE GUTTER!" | rewrite (off-world term) |
| `scripts/main.gd:865` | "%s GRIEFED %s" | rewrite (banned word) |
| `scripts/main.gd:294,310` | "CHAOS ROUND / NO WAITING — ALL LIVE" | rewrite |
| `scripts/main.gd:628` | "%s SINKS IT!" | keep (Voice B, one ! ok) |
| `scripts/main.gd:928` | "THE COURSE REMEMBERS" | KEEP★ |
| `scripts/main.gd:935` | "%s WINS THE MATCH!\n(press R for a rematch)" | rewrite (win_title theme) |

---

*Above. Ours. Presence. Memory. The estate forgets none of it, however politely
it is asked.*
