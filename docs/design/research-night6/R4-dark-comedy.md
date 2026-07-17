# R4 — Dark-Comedy Presentation & Writing Devices for ILL WILL

*Research lane R4. Lens: stealable PRESENTATION and WRITING devices from games that
nail death comedy. Grounded in `docs/design/26-voice-bible-and-ambient-life.md`,
`STORE-BLURB.md`, and a direct read of the shipped estate/procession/executor/newsreel
code. Every device names the EXACT screen/system/line in ILL WILL where it lands, and
drafts copy in the estate's dialect. Ship-soon bias: prefer copy/presentation wins
buildable in one night.*

---

## 0. The landing-zone map (what the code already gives us)

Confirmed from source, so every device below points at a real hook:

| System | File | What it is | Pooling? |
|---|---|---|---|
| Procession reveal pools | `estate/procession/executor_host.gd:15-122` | ~40 seeded variants (GREETING, SHRINE, GRAVE, BLANK, ROUND_OPENER, WILL_OPEN…), drawn by `pick(pool, rng, args)` | ✅ seeded, net-safe |
| Executor `aside()` | `executor_host.gd:189` | dry colour-commentary during dead air, presentation RNG only (never touches sim) | ✅ seeded |
| Chronicle observations | `estate/estate_state.gd:589-678` | 25+ data-gated Executor lines across nights ("None mention kindness.") | ✅ shuffled |
| Night superlatives | `estate/estate_state.gd:274-308` | Titled awards: THE SNAKE / DOORMAT / ARCHITECT / HOARDER / LANDLORD / WORKHORSE / RECKONER / NEMESIS OF %s, one dry line each | data-gated |
| Will-reading eulogy | `estate/estate.gd:2145-2210` | Staggered fade-in: head + award rows + 2 chronicle lines + vendetta notice, then a button | copy in place |
| Newsreel intertitles | `estate/newsreel.gd:222-371` | Silent-film cards: ACT + Roman numerals + `"caption"` + flavor; "AN UNRECORDED NIGHT", "— FIN —" | structural |
| Intro/how-to card | `core/ui_kit/intro_card.gd:117-204`; `estate/howto_cards.gd` | Per-game goal + LIVE control glyphs + a **rotating `TIP:` line**; `GET_READY_HEADS` pool | ✅ tips rotate |
| Floor banners (Voice B) | `minigames/*/*.gd`, `scripts/main.gd` | In-round action banners; register being pulled up to the estate's dialect | some pooled |
| Death certificate | `scripts/main.gd:672` | `"%s, DECEASED\nCAUSE OF DEATH: %s"` | single |
| Podium + manor arrival | `estate.gd:2126` (`_flash "WINS THE NIGHT"`), `estate_state.gd:386` (`finish_run`) | Night-win banner + run-end monument | single |
| Ghost meddling ("no dead seats") | STORE-BLURB feature | eliminated return as ONE attributed act of mischief | thin copy — opportunity |
| Monument labels | `estate_state.gd:346-374` | `"%s — Champion of Night %d"`, `"TOOK THE MANOR"` | plain — opportunity |

**Two greenfield gaps — no system exists, cheap to add, high payoff:**
- **No career / funeral-statistics / performance-review / achievements screen.** All the data
  exists (`night_stats`, `ledger`, `chronicle`, `legacy`) and nothing audits a whole RUN.
- **No narrator behavior when the player is NOT playing** — pause, idle, quit-confirm,
  rematch/return are all silent. The Stanley Parable's single best trick is unused here.

**Pooling rule (bible §2, confirmed in code):** new fiction pools MUST draw from the
seeded `ProcessionExecutor.pick()` / `EstateState.rng` so couch and net mirror hear the
same line. Never `randi()` a fiction banner — it desyncs the mirror (`executor_host.gd:281`).

---

## 1. THE TOP 5 (one-night wins)

### ★1 — The Executor narrates when you STOP playing  (The Stanley Parable)
**Device:** the narrator's most-loved behavior is commenting on *inaction* — he resents
having to describe you (*"Stanley just stood there doing nothing at all. He seems to think
I have nothing better to do…"*), and his composure **cracks by degrees** into one clipped
ALL-CAPS clause, then recovers. Pure copy on events that already fire.
**Where it lands:** three currently-silent hooks — (a) the **pause menu** overlay,
(b) an **idle timer** in estate free-roam / lobby (~20s no input), (c) the **quit-confirm**
dialog. Each draws a seeded pool via the `pick()` pattern. No new screens.
**Sample line (idle):** *"The estate notes GOLD has not moved in some time. It is used to
being kept waiting. It has never once been kept waiting so thoroughly."*
**Effort:** 3–4h. Highest delight-per-hour in this report; greenfield behavior, no new art.

### ★2 — Event→line reactivity bank, with a for-you / against-you split  (Darkest Dungeon)
**Device:** DD's whole narrator is a **trigger→short-line lookup table** — each discrete
event fires one 3–10-word line from a small pool, and the *same* event reads as terse
approval when it helps you and quiet dread when it hurts you (crit-by-you *"Masterfully
executed!"* vs crit-on-you *"Death waits for the slightest lapse."*). Cheapest reactivity in
games. ILL WILL has this for procession *spaces* but NOT for cross-cutting drama.
**Where it lands:** wire the Executor's `aside()` (`executor_host.gd:189`) and the minigame
floor to anthology-wide events — **elimination, comeback, betrayal, a tie, a near-wipe** —
each with a `for_you` and `against_you` pool. Makes the Executor feel omniscient across all
15 games from one afternoon of copy + a trigger table.
**Sample (a rival inherits at your expense):** *"RED takes what was nearly yours. The estate
admires the timing, and files your objection where it files the rest."*
**Effort:** 4–5h for full coverage; ships partial (start with elimination + comeback).

### ★3 — Funeral Statistics: the RUN-END audit + self-aware Commendations  (Death and Taxes × Stanley Parable)
**Device:** Death and Taxes reframes a tenure of reaping as an **office performance review**
(death as KPIs); Stanley's **anti-achievements** insult the accomplishment and cite **fake
authoritative statistics** (*"94% of people who select that button are…"*; the "Commitment"
unlock: *"CONGRATULATIONS, EMPLOYEE… I ADMIRE YOU IMMENSELY. WELL DONE!"* read as faintly
threatening). Directly fulfils the brief's "funeral statistics" and "achievement/stat
framing" asks.
**Where it lands:** a new **RUN-END audit card** at `finish_run` (`estate_state.gd:386`) /
manor arrival, reusing the will-reading stagger layout and the existing
`night_stats`/`ledger`/`chronicle`/`legacy` data — no new data, just a screen that itemises
them as a probate audit, with 2–3 mock-precise stats and self-souring commendations.
**Sample line:** *"Tenure: 5 nights. Kindnesses recorded: 0. Grudges settled in blood: 3.
You rank in the 3rd percentile of grievers. The estate rates the account: actionable."*
**Effort:** 5–6h (new card scene + a stat→line formatter + 6–8 audit rows). Biggest of the
five, but the single most memorable capstone and it hits two named brief categories.

### ★4 — The eulogy as an itemised receipt: affection in the liability column  (Cult of the Lamb)
**Device:** CotL renders **grief as a quantified transaction** — a funeral pays *+20 Faith*
(gated behind "interred ≥1 day"), remains are "reallocated." Mourning as an audited payout.
This is literally the bible's rule 3 ("affection is expressed as liability") made a receipt.
The will-reading already lists award rows — push it into full receipt framing.
**Where it lands:** the **will-reading eulogy** (`estate.gd:2145`). Add a receipt header and
a "liability column" line where any warmth is booked as a cost. The award rows stay; the
frame changes.
**Sample line:** *"FUNERAL PROCESSED. Goodwill recognised: +1, provisional. Kindness logged
to the liability column, pending audit. Remains: reallocated. Thank you for choosing the
estate."*
**Effort:** 3h (header + column copy on the existing stagger; no new screen).

### ★5 — The dead reach back: "4 minutes before death" ghost re-entry  (Ghost Trick / A Mortician's Tale)
**Device:** Ghost Trick makes the dead **playful and matter-of-fact**, reaching back to nudge
ONE small thing against a deadpan countdown (its whole verb is "4 minutes before death"), and
states terminal status as an immutable clause (*"You'll only exist until morning. I'm afraid
that fact can't be changed."*). A Mortician's Tale gives every corpse a **dignified one-line
bio**. ILL WILL's "no dead seats" ghost already performs one attributed act — the copy is thin.
**Where it lands:** the ghost-meddling attribution banner (the eliminated player's single
act) gets a seeded pool framing it as the late guest reaching back under a return-window
clause; same treatment enriches the **death certificate** (`main.gd:672`).
**Sample line:** *"The late RED, return window four minutes, reaches back to move one cup
three inches. It is enough. It was always, the estate suspects, going to be enough."*
**Effort:** 2–3h (one pool + wire the existing ghost-act event; certificate is a scoped swap).

**One-night shortlist, delight-per-hour:** ★1 (idle/pause narrator) → ★5 (ghost re-entry) →
★4 (eulogy receipt) → ★2 (event→line bank) → ★3 (funeral stats — biggest, most worth it).

---

## 2. Full device catalogue, by source game

Effort = rough solo-night hours. ★ = made the top 5.

### 2.1 The Stanley Parable — the drying narrator / the system that talks back
- ★ **Narrate the non-play (idle / pause / quit) + composure that cracks.** See ★1. Flat 95%
  of the time; the rare one-clause ALL-CAPS break is the laugh. (3–4h)
- ★ **Fake authoritative statistics.** *"94% of all people who select that button are…"* —
  false precision delivered at audit grade. Ours: *"98% of heirs who chose this predecease
  the estate."* / *"You are in the 3rd percentile of grievers."* Drops into ★3's stat screen
  and Executor barks. (pure copy, in ★3)
- ★ **Anti-achievements / self-insulting Commendations.** "Unachievable" (*"It is impossible
  to get this achievement"*), "Go Outside" (don't play 5 years), and mock-HR praise that
  reads as a threat. Ours: an **Estate Commendations** panel — impossible ones ("SOLE HEIR —
  awarded only when all others are deceased; cannot be earned this session"), grim-condition
  ones ("PRODIGAL — return to the table after leaving in anger"), one over-warm Executor
  blurb. (pure copy, folds into ★3)
- **Third-person past-tense narration of the player.** *"Stanley was so bad at following
  directions…"* — insult smuggled inside "objective" prose, and it implies your choices are
  pre-written. The estate already nails this (`WILL_OPEN`, "a page it wrote in advance").
  KEEP; add one sibling that names a specific player's choice as already-recorded. (1h)
- **Understating catastrophe as a clerical slip.** *"oh dear… this is all a spoiler!"* — total
  collapse played as mild filing embarrassment (same DNA as Grim Fandango's mass-poisoning
  triage). Ours, on a round break / game-warp: *"This outcome was not on the docket. A
  correction has been noted. Please disregard the preceding death."* (1–2h)
- **The IT-desk register when the fiction breaks.** Omniscient narrator collapses to fumbling
  help-desk. Ours, on any glitch/edge case: *"One moment. The record appears to be… please
  hold. Do not read the next line."* (1h, optional)
- **Meta-commentary on restart / return.** Stanley mocks replaying. Our `"press R for a
  rematch"` (`main.gd:935`) + return-to-lobby are silent. Add a return-aware lobby sibling:
  *"You have come back. The estate expected nothing else, and prepared nothing."* (folds into
  `estate.gd:1169` pool, 1h)

### 2.2 Darkest Dungeon — the event-triggered Ancestor
- ★ **Event→line lookup table (the architecture) + for-you/against-you split.** See ★2. The
  highest-ROI reactivity primitive. (4–5h)
- **Aphorism-as-comment (grim scripture that fits anything).** *"Overconfidence is a slow and
  insidious killer."* Freestanding maxims apply to any moment, so a tiny pool covers many.
  Ours: probate-proverbs on transitions/loading — *"Grief is merely inheritance that has not
  yet been itemised."* Doubles as `intro_card` footnote copy. (1–2h)
- **Bleak consolation on loss (menace + comfort in one line).** *"You will endure this loss
  and learn from it."* Ours, loser copy: *"You are not the first to leave this table with
  nothing. The estate keeps excellent records of those who did."* (1h)
- **Cadence-as-content on slow deaths.** *"Slowly, gently, this is how a life is taken."* —
  comma/ellipsis pacing makes the line *feel* like the slow kill. Ours, for score-bleed
  eliminations: *"One asset, then another, then the good silver… this is how an estate is
  emptied."* (copy technique, 1h)
- **Rule-of-three, inverted flat.** DD peaks with *"Destroy! Them! ALL!"* — its one non-deadpan
  register. Ours should INVERT it: deliver the triple stone-faced — *"Contest the will.
  Contest it again. Contest it a third time. It changes nothing."* The escalating form
  fighting the flat tone is itself the joke. (copy, 30m)

### 2.3 Grim Fandango — the Department of Death
- **Moral worth as a customer loyalty / travel tier.** Purest souls ride the luxury **Number
  Nine** (crosses the land of the dead in four minutes); everyone else **walks four years**.
  Virtue is a fare class. Ours: reframe podium placement / manor-taking as **modes of
  departure** — the heir rides the shipped hearse (`board_hearse_cart.glb`, the "Cortège of
  One"); the rest are "issued walking papers." Cashes in an asset we already own.
  *"GOLD departs by hearse, first class, mourned by no one. The rest are issued walking papers;
  the estate has locked the gate behind you."* (2–3h — podium `_flash` + `finish_run`)
- **Catastrophe filed as a queue/triage problem.** *"Too many dead to assign specific cases,
  so all clients are FIRST COME FIRST SERVE!"* — mass horror deflated to throughput policy.
  Ours: the **CHAOS round** transition banner (bible §1.5 #10, `main.gd:310`) —
  *"MULTIPLE DECEDENTS. CASES PROCESSED FIRST COME, FIRST SERVE."* (1h)
- **Office-infrastructure comedy — paperwork IS the machinery.** Eternity gated on an unsigned
  work order and a temperamental mail tube. Ours: `intro_card` loading cards styled as
  forms/memos — *"FORM 9-C: NOTICE OF INTENT TO GRIEVE — see reverse."* (reuses the tip
  rotator, 1–2h)
- **Reaper-as-service-desk / commission vocabulary.** *"I'm your new travel agent"*; *"as you
  reap, so shall you receive your commission."* Sacred cadence + mercenary rider. Ours: the
  **auction header** implies the estate is working a quota (bible §1.5 #12, `estate.gd:1626`)
  — *"THE AUCTION — the estate is short of its quota of grudges and will make it up in you."*
  (folds into planned auction pool, 30m)
- **Noir deadpan as the delivery voice.** Weary, self-serious, never winking. This is a voice
  rule ILL WILL already holds; the note is: never let the Executor acknowledge the joke.

### 2.4 Cult of the Lamb — cute/grim contrast
- ★ **Funeral / eulogy as an itemised receipt (grief quantified).** See ★4. Funeral = +20
  Faith, remains "reallocated." (3h)
- **Cuteness-as-permission → probate-voice-as-permission (design law).** Director: *"the cute
  art… allows us to put horrendous things in the game without it feeling too horrible."* Our
  wrapper is the administrative register — it doesn't decorate the darkness, it *licenses* it.
  Actionable: keep a literal checklist of "what is an estate/probate" (wills, executors,
  liabilities, deeds, liens, funerals) and make sure each is a mechanic AND a copy motif.
  (north-star, not a task)
- **Doctrine / atrocity rendered as a flat perk-tile menu.** CotL lists "Murder" and
  "Cannibalism" as neutral upgrade tiles. Ours: an **Estate Bylaws / Doctrine** screen where
  clauses have deadpan names + mechanical upsides — *"Clause 7: Predation — resolve disputes
  permanently. Effect: −1 heir, +estate morale."* Horror lives in the menu-chrome mismatch.
  (bigger build; the copy convention is free once a menu exists)
- **Escalation-of-the-euphemistic-motion.** A follower laundered a personal grudge through
  doctrine, escalating *lock them up → kill them*; players can even accuse *themselves*. Ours:
  grievances as rising legalese — *"Motion to censure" → "Motion to disinherit" → "Motion to
  inter"* — obviously personal. Self-accusation gag: *"I move to disinherit myself; I know what
  I did."* (1–2h, great vendetta flavor)
- **Follower mundane thoughts against a grim backdrop.** *"The Leader looks fluffy today."*
  Ours: crow gossip / ghost murmurs that ignore the carnage — *"The heir looks well-rested,
  for a murderer."* Feeds the §3 ambient troupe's crow voice. (folds into chronicle/crow
  pools, 1h)

### 2.5 Ghost Trick — the chatty dead
- ★ **"4 minutes before death" re-entry + terminal-condition-as-clause.** See ★5. (2–3h)
- **Self-aware object-corpse deadpan.** *"I mean, look at me. I'm a desk lamp."* Grand
  metaphysical status stated as bored fact. Ours, for ghost players: *"The deceased retains no
  standing but continues to hold views."* (in ★5's pool)
- **Villain self-intro as comic epitaph (grand title + undercutting clause).** *"They call me
  'Nearsighted Jeego,' but I never let my prey get away."* A compact epitaph formula. Ours,
  **monument inscriptions** (`estate_state.gd:346`): *"Here lies GOLD, 'The Undefeated.'
  Record: one win, four forfeits."* Turns flat "Champion of Night N" labels into jokes. (1–2h)
- **Oblivious near-death victim running gag.** One character survives absurd repeated hazards,
  never noticing. Ours: a ledger tally that "remembers" near-misses a player ignores —
  *"Near-fatal incidents this estate: 7. Awareness: none."* (folds into chronicle, 1h)
- **Death as a puzzle state, not an ending.** The **lastwill** minigame already freezes the
  world on death so the deceased writes a curse into the road (`howto_cards.gd:21`) — a
  shipped Ghost-Trick beat. KEEP; echo the framing in the certificate copy. (1h)

### 2.6 Darkest Dungeon-style titled states (afflictions ↔ virtues)
- ★-adjacent **Titled afflictions + one taxed VIRTUE.** Ours' superlatives (THE SNAKE, THE
  DOORMAT) *are* DD afflictions; missing is a **virtue**, taxed on arrival (bible rule 10).
  Add one rare grudging virtue award in `night_superlatives()` (`estate_state.gd:274`):
  *"THE MERCIFUL — GOLD spared someone they had the votes to ruin. The estate logged the
  anomaly and adjusted their handicap to suit."* (3h; strong, just missed the top 5)

### 2.7 Disco Elysium — personified internal systems (bonus)
- **Bickering personified estate-voices.** DE's skills editorialize in distinct registers
  (Volition, Electrochemistry, Inland Empire). Ours: give the estate's *faculties* voices —
  **The Ledger** (cold, numeric), **The Will** (legalistic, passive-aggressive), **Sentiment**
  (weepy, over-attached — records affection as liability), **The Crows** (gossip). On a
  decision, two chime in with conflicting one-liners; plays cold-bureaucracy against
  sappy-sentiment for tonal contrast. Faint version already exists (the grave "bills," the
  shrine "has standards"). Cheap partial: 1–2 more attributed asides. (1h partial; full is >1
  night and risks over-cluttering the deadpan — keep it light)
- **Thought-Cabinet slow-internalize with a pretentious name.** DE "researches" a Thought over
  time into a permanent effect, named like an essay (*"Hobocop," "Wompty-Dompty Dom Centre"*).
  Ours: the estate "internalises" a **Grudge/Fixation** over rounds — joke names (*"The Nephew
  Question," "Posthumous Spite," "Fiduciary Denial"*) — temporary quirk now, permanent estate
  trait once it "resolves," shown as a pending ledger entry. Cashes the persistent-memory
  conceit. (folds into `chronicle_lines`, 1h for the copy layer)

### 2.8 Death and Taxes — the reaper's office
- ★ **Performance review / funeral statistics.** Fate evaluates you on days 7/14/28 as a
  performance review, usually a flat "everything seems to be in order." See ★3 — the KPI /
  appraisal reframe is the headline steal. (5–6h)
- **The vague-on-purpose Work Order memo.** Each day opens with a quota note deliberately
  ambiguous so you mess up ("kill six people, two with a law background, two under 35"). Ours:
  open a round with a **stamped work order** — *"Distribute the following bequests. Note:
  'sentimental value' is not a recognised asset class."* Vague, filterable, quietly
  threatening. (1–2h, `intro_card`/round-opener)
- **Corporate menace in the boss's voice (Fate).** Threats delivered as staffing/budget
  constraints — *"I do not have the materials to make another spawn."* Cruelty filed as
  logistics. This is exactly the Executor's register; steal the *praise-as-liability* move:
  *"Your handling of the deceased's affairs was adequate. This has been noted. Nothing is
  ever un-noted."* (copy, in ★3)
- **The absurd cause-of-death read-back.** A clean checkbox ("die") outputs a slapstick
  obituary — *"choked to death on a sandwich."* Sterile input, ridiculous output. Ours:
  extends the **death certificate** (`main.gd:672`) with a specific manner-of-death pool —
  *"Cause of death: recorded as 'misadventure involving a decorative sword he was repeatedly
  warned about.'"* (2h; enriches ★5)
- **News headlines as consequence feedback.** The world reacts to your reaping in ticker-tape
  headlines; you infer your own guilt. Ours: a between-round **PROBATE GAZETTE** obituary
  column reporting player fallout as neutral news — *"Local family 'surprised' by contents of
  updated will."* The **newsreel** is already the visual cousin of this. (2h)
- **The Executor's desk (set-dressing physicality).** D&T's running gag is cramming everything
  into desk drawers, "even the fax machine." Ours: a persistent Executor's-desk frame — a fax
  that never stops, a dead office plant catalogued as an asset, a "MISCELLANEOUS EFFECTS"
  drawer. Cheap set dressing that sells "Department of Death Recordkeeping." (art, not copy)

### 2.9 A Mortician's Tale — death-positive, quiet dignity
- **The Inbox as the whole story engine.** Nearly all narrative arrives as emails on one work
  computer — highest narrative-per-pixel device researched. Ours: an **Executor's Inbox** as
  connective tissue between games (heirs, creditors, the county clerk, the Executor in one flat
  list). Build once, reuse forever. (3–4h if a new screen; folds partially into ★3/footnotes)
- **Register-switching by adjacency (tonal whiplash for free).** A somber client request sits
  next to a coworker oversharing; ordering the messages does the emotional work, no transitions
  written. Ours: stack the inbox so a genuinely sad bequest sits directly beneath a creditor's
  aggressively cheerful collections notice. Juxtaposition = joke. (copy discipline)
- **The in-world periodical ("Funerals Monthly").** A trade newsletter delivers real funeral
  trivia diegetically, slipping dark facts past the player as "industry news." Ours: a
  recurring **PROBATE QUARTERLY / The Recordkeeper** bulletin — real-ish probate trivia
  deadpan ("This issue: escheatment, or what the State does with people who die owning things
  but knowing no one"). Reusable flavor filler; pairs with the DD aphorism/footnote idea. (2h)
- **Same channel, curdling voice (the corporate buyout).** An indie home is bought by a chain
  that KEEPS the mom-and-pop name but floods the same inbox with colder corporate demands —
  the villain arrives with no cutscene, just a tonal shift in the copy. Ours: mid-run, the
  Executor's letterhead subtly changes — a new *"per Estate Services, LLC"* footer, more
  legalese, warmth drained out. The bureaucracy gets bought; the copy tells you. (distinctive;
  >1 night, needs a run-arc hook — flag for later)
- **Dignity through one mundane wrong detail (dark comedy without jokes).** It never tells a
  joke; it reports an ordinary slightly-wrong detail straight-faced (a child "impatiently
  playing a handheld game" during a funeral) and lets you supply the laugh — the purest match
  for the no-exclamation ethos. Ours: *"The remains were interred. The service was
  well-attended. Refreshments were declined."* (copy technique, north-star)

### 2.10 Frog Detective — deadpan absurdist interviews
- **The auto-filling snarky notebook (the joke-delivery surface).** After each talk the
  detective auto-writes a pithy editorial entry you read "just for the jokes" — the narrator's
  inner voice made browsable. Ours: the **Ledger of Misdeeds** already fits — have the Executor
  auto-append a dry one-liner per player action — *"Filed under: things the deceased would have
  hated."* Makes the ledger the primary joke surface, not just a scoreboard. (2h; overlaps
  chronicle/graffiti)
- **The record leaks a feeling it shouldn't (affection as liability, literally).** Frog
  Detective's "objective" notes leak bias — *"I hope he isn't the culprit."* Ours: the
  supposedly-neutral ledger occasionally leaks warmth — *"Bequest recorded. (This one was fond
  of you. This is not legally relevant.)"* This is the bible's rule 3 as a mechanic. (in the
  ledger pass above)
- **Asymmetric dialogue volume.** The detective gives 100 words to a suspect's clipped
  one-word answers; the length mismatch is the joke before you read it. Ours: the Executor
  over-narrates, the counter-party replies in one clipped line — *"The Executor read the
  seventeen-clause codicil in full. The heir said, 'k.'"* (copy, 1h)
- **Deadpan absurd assertions stated as settled fact.** *"You're not going to jail, jail isn't
  real."* Nonsense in the cadence of the obvious, no wink. Ours: Executor policy non-sequiturs
  — *"Grief is not a deductible expense. This has been litigated."* (copy pool, 1h)
- **The investigation UI as a powerless toy (decorative rigor).** Interviews are exhaust-the-
  list with no fail state; "suspect" stickers are cosmetic only — you LARP rigor over a system
  that doesn't grade you. Ours: a case-file/accusation UI with stamps and red string whose
  "rigor" is decorative, while the Executor's flat narration reminds you none of it is binding.
  The pageantry is the comedy. (2–3h, overlaps Paradise Killer case file)

### 2.11 Paradise Killer — the case file & the trial
- **★-adjacent "Start the Trial" whenever you like (the always-live ceremonial button).** You
  can open the trial at any time on a thin case; the game never gates you, and the wrong person
  is "executed without remorse." A big ceremonial button that's always live turns accusation
  into a dare. Ours: an always-available **"READ THE WILL / RENDER THE VERDICT"** action —
  players can trigger the reckoning early with a thin ledger and the Executor proceeds without
  objection; the wrong heir inherits. Permission to fail dramatically is the fun. (2–3h; strong
  — nearly made the top 5)
- **Rename EVERYTHING in probate-deadpan (total aesthetic commitment).** PK names everything to
  the hilt (protagonist "Lady Love Dies," the "Crime To End All Crimes"); "every name and bit of
  flavor text is dripping with aesthetic commitment." Ours: a **copy-only pass over existing UI**
  — Results → **"FINAL DISPOSITION OF THE ESTATE"**; scoreboard → **"LEDGER OF MISDEEDS"**;
  every stat/button/exhibit gets a probate name. Pure one-night text work, outsized payoff —
  the cheapest high-yield item in this report. (2–3h sweep)
- **Counts / Matters — the case split into discrete filed phases.** PK chunks the trial into
  per-crime Case File phases (testimony vs physical evidence, each filed under a suspect). Ours:
  structure the reckoning as discrete **"Counts" / "Matters"** in the estate file — one per
  misdeed on the ledger — each resolved by the Executor reading the filed evidence back in dry
  legal sequence. (folds into ★3 / the ledger)
- **The court considers only what you correctly filed (bureaucracy as fate).** PK's assistant
  auto-presents evidence only if you collected AND filed it under the right suspect — bad
  paperwork lets the guilty walk. Ours: *"The court can only consider what was correctly
  docketed. The rest is hearsay and grief."* (copy, 1h)
- **Settled as recorded, not as it truly happened (no true ending).** The verdict reflects the
  case you built, never validated against objective truth — you're author and quietly
  complicit. Deeply on-theme for cruelty-as-bookkeeping. Ours, closing the file: *"The estate
  is settled. Whether it is settled correctly is not a question this office is equipped to
  answer."* (copy, 30m)
- **Named evidence with dry flavor.** Each royalty **trap/curse** a player authors gets a
  titled case-file entry — *"EXHIBIT: the thing GOLD left on the third hole. Filed under
  premeditation."* (2h, overlaps Frog Detective's decorative case file)

### 2.12 Honorable mentions that nearly made the top 5
- **Paradise Killer "rename everything" sweep** — cheapest high-yield item in the report; a
  text-only pass turning generic UI labels into probate-deadpan. Missed the five only because
  it's a diffuse polish pass, not one discrete landing.
- **Frog Detective ledger-that-leaks-a-feeling** — the purest single expression of the bible's
  "affection as liability" rule; folds cheaply into the existing chronicle/graffiti.
- **Grim Fandango travel-tier departure at the podium** — cashes in the shipped hearse asset
  (§2.3); 2–3h, delightful, kept out only to give the five more range.
- **Titled VIRTUE award (DD, §2.6)** — the one missing half of the afflictions system.

---

## 3. Cross-cutting principles worth reasserting

- **The three transferable primitives (subagent synthesis):**
  1. **Category-swap the vocabulary (Grim Fandango).** Never say the grim thing plainly; say
     it in the wrong register — fare class, commission, work order, receipt. Push into every
     UI string.
  2. **Composure that cracks by degrees (Stanley).** Flat 95% of the time; the rare one-clause
     break ("oh dear," one ALL-CAPS clause) is the laugh. Deadpan is the baseline the joke
     violates. **Rarity is the whole value — ration it.**
  3. **A trigger→line lookup table (Darkest Dungeon).** Cheapest reactivity in games; a
     for-you/against-you split doubles perceived intelligence for free.
- **The line that fires most often needs the most variants** (Hades, bible §2). The idle/pause
  narrator (★1) and any floor banner repeat hardest — pool them 4–6 deep.
- **Every fiction pool draws from the seeded RNG** (`pick()` / `EstateState.rng`) so couch and
  mirror match. No `randi()` in fiction. (`executor_host.gd:281`)
- **Praise is taxed on arrival** (bible rule 10). The virtue award, any achievement, any
  performance-review compliment must sour in the second beat.
- **The worst news is the flattest line** (Stanley/DD). Death certificate, wipe warning,
  funeral stats: no exclamation, no drama — the clerical calm IS the joke.
- **Reuse the rotator you already have.** `intro_card`'s `TIP:` line is the single
  highest-frequency text surface; a second "FOOTNOTE" register there is nearly free reach.

---

## 4. Sources

Web research via three lane subagents plus direct read of the ILL WILL source and doc 26.
Grim Fandango: Wikiquote, Grim Fandango Network dialogue, Wikipedia (Number Nine).
Stanley Parable: Wikiquote, TheGamer, TrueSteamAchievements ("Unachievable").
Darkest Dungeon: Steam "Ancestor's quotes" guide (530463929), Darkest Dungeon Wiki.
Ghost Trick: LP Archive Update 02, Wikipedia. Cult of the Lamb: Game Developer dev
interview, ritual/doctrine references. Disco Elysium: discoelysium.wiki.gg Thought Cabinet.
Death and Taxes: GamingOnLinux, Wikipedia, Fandom (Fate), GameLuster review. A Mortician's
Tale: Destructoid review, deathisawhale.com. Frog Detective: Kotaku, WayTooManyGames,
buried-treasure.org, Adventure Game Hotspot. Paradise Killer: Neoseeker trials walkthrough,
Wikipedia, theeliteinstitute.net.
Verified in-repo hooks cited by `file:line` throughout. NOTE: Fandom/TVTropes/PC Gamer
blocked automated fetches (402/403) for several games, so a handful of verbatim quotes came
via search-result excerpts — spot-check any line before shipping it verbatim.
