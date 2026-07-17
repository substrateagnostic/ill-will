# R2 — Gacha/F2P Mechanics, Ethically Transplanted Into ILL WILL

*Research lane R2, 2026-07-17. Read-only pass over STORE-BLURB.md, docs/design/ (esp. 20, 23, 24, 26), core/, estate/. No repo files modified.*

## 0. The frame

Mobile/F2P games are the most heavily play-tested engagement machines ever built. Almost every
mechanic in them is a *fun* mechanic that was later harnessed to a wallet. The test applied to each
candidate below: **strip the monetization; does the residual psychology still produce joy in a
living room where four people can see each other's faces?** If the residual psychology is
*obligation, anxiety, or deception*, it does not come in the house, however good the costume.

ILL WILL is unusually well-positioned for this transplant because the estate fiction is a
bureaucracy — and F2P meta-systems (currencies, ledgers, catalogs, grants, dockets) are literally
bureaucracy. The reskin is not a stretch; it is a homecoming.

### What the house already owns (grounding)

| Existing system | File | Relevance |
|---|---|---|
| LEGACY currency + wardrobe (vanity-only store) | `estate/estate_state.gd`, `estate/wardrobe_panel.gd` | premium-currency slot, already ethical (earned only, buys vanity only) |
| Chronicle / grudge ledger (lifetime tallies) | `estate/estate_state.gd` (`chronicle`, `chronicle_event()`) | stat spine for any milestone/pity system |
| Family album (archived newsreel stills) | `estate/family_album.gd`, `core/moment_scribe.gd` | a collection album already exists for *moments* |
| Séance wheel, minigame roulette | `estate/procession/seance_wheel.gd`, `minigame_roulette.gd` | house pattern: presentation is pure theater over a decided result; draws no rng; receipt-safe |
| Will reading / eulogy / podium ceremonies | `estate/procession/eulogy.gd`, `core/podium.gd`, doc 20 | the night already ends in a ceremony chain — natural mount point for reveals |
| Monuments, graffiti, gate statues | `estate/monuments_view.gd`, `estate_state.gd` | persistent trophies, already Zeigarnik-adjacent |
| Vendetta, kill matrix, royalties | `estate_state.gd`, STORE-BLURB | grudge-as-currency already shipped |
| Voice bible (probate deadpan, two-beat lines, no exclamation marks) | doc 26 | every string below must pass it |

**House constraint inherited from the wheel/roulette comments:** any new spectacle must animate
*toward* an already-decided result and draw no rng of its own. Every transplant below respects this.

---

## 1. Candidate mechanics, one at a time

### 1.1 Pity systems (gacha guarantee / spark) — TRANSPLANT ✓

**The psychology.** Pity systems (guaranteed rare after N failures; spark = accumulate 200 pull
tickets, buy the thing outright) exist because bounded worst-case loss is more tolerable — and more
*motivating* — than open-ended bad luck. Players demonstrably prefer a visible guarantee over
statistically more generous but unbounded odds. In gacha this is harnessed to keep whales pulling;
stripped of spending, the residual is pure **loss-protection with a visible countdown**, which is
the exact medicine for the classic party-game wound: the player who is losing all night and knows it.

**Why it adds fun on a couch.** Mario Party rubber-bands *covertly* (hidden catch-up dice, rigged
item drops) and players resent it when they smell it. The gacha insight is the opposite: make the
mercy VISIBLE and let the room watch the meter fill. The losing player gets a thing to anticipate;
the winning players get to dread it; the estate gets a joke ("this is not kindness, it is
actuarial"). Visibility converts rubber-banding from suspected cheating into shared theater.

**The transplant — THE ESTATE TAKES PITY.** A hardship docket: a player who finishes N consecutive
minigames with zero points (or is last on the trail at a round boundary — tune to whichever signal
`night_stats` / trail positions already expose) accrues visible DESTITUTION stamps on their player
badge. At the third stamp the board pauses for a small broadcast beat: the Executor files a
*hardship grant* — a modest, fixed award (grudge, a free trap, a deed discount voucher — fixed and
deterministic, decided by the sim, revealed by theater). Voice: *"The estate takes pity. The estate
would like the record to show it was not moved."* Crucially the grant is **modest** — pity is a
floor, not a ladder; it must never make losing a strategy (the classic Mario Party Star-handout
failure mode).

**Dark part stripped:** in gacha, pity exists to justify continued *spending* toward the threshold.
Here nothing is spent; the meter fills from misfortune alone.

**Build pointers:** stamp accrual in `estate/estate_state.gd` beside `night_stats`; badge pips via
`core/player_badge.gd`; the grant beat as a Procession broadcast moment using the doc-24 reveal
machinery in `estate/procession/procession.gd` + `executor_host.gd` line pool. Est. 4–6 h.

---

### 1.2 Multi-pull ceremony + rarity tell (banner reveal) — TRANSPLANT ✓

**The psychology.** The 10-pull is a *ceremony*: a pre-reveal "tell" (glow color, rainbow flash,
wax-seal sparkle) signals the rarity tier before the item shows, converting a database roll into
15 seconds of escalating group anticipation. The tell is the genius part — anticipation with
partial information beats both full surprise and full knowledge. In live gacha communities,
multi-pulls are *social events* (streamed, watched together) — which is to say the mechanic was
always secretly a couch mechanic that got trapped in a phone.

**Why it adds fun on a couch.** The couch is the original multi-pull audience. Four people watching
one sealed envelope with a gold wax seal is better television than four people watching a shop menu.

**The transplant — THE BEQUEST.** At the will reading (mount point already exists: doc 20's
`_night_ceremonies()` chain in `estate/estate.gd`), each player receives one sealed parcel from the
deceased — the night's champion gets the estate's best. Parcels open in reverse standings order
(loser first — kinder, and builds to the champion). The **wax seal color is the tell**: tallow =
a LEGACY stipend; silver = a wardrobe item the player doesn't own; gold = a rare wardrobe item or
a monument embellishment. Contents are decided by the sim before the ceremony (no dupes ever — pick
from unowned stock; if wardrobe is complete, it degrades gracefully to LEGACY with the line *"The
estate notes you already have everything. The estate finds that suspicious."*). The reveal animates
toward the decided result, wheel-style.

**Dark parts stripped:** no purchase (parcels are earned by finishing the night); no dupes/shard
conversion (gacha's dupe economy exists purely to absorb spend); no rate-up FOMO. The direct-buy
wardrobe remains untouched — the bequest is a gift channel, not a replacement for deterministic
purchase.

**Build pointers:** parcel UI + seal tint as a small Control in the ceremony chain
(`estate/estate.gd` `_night_ceremonies()`, after the newsreel, before `_enter_will_reading` or as
the will reading's opening beat); stock selection from `WardrobePanel.WARDROBE_PRICES` minus
`owned_cosmetics()`; persist via existing `legacy`/`wardrobe` dicts. Est. 5–8 h.

---

### 1.3 Collection album / set completion — TRANSPLANT ✓ (with the timer amputated)

**The psychology.** Monopoly GO's sticker albums run on set-completion drive (the Zeigarnik itch of
visible empty slots), escalating per-set rewards, and the hunter-gatherer completion instinct. It is
one of the most reliable engagement engines known. Its dark half is the **expiry timer** — albums
vanish in weeks, converting a pleasant itch into scheduled anxiety and burnout ("players becoming
physically and mentally exhausted" is in the trade press *about the flagship product*).

**Why it adds fun on a couch.** The estate already proved the appetite: monuments, graffiti, the
family album. What's missing is the *structured want* — named sets with visible empty silhouettes,
so a group can say "we still don't have the SEANCE one" and mean it. Sets give multi-night groups a
shared shopping list of experiences (not purchases): each empty slot is a reason to pick a specific
minigame next night.

**The transplant — THE ESTATE INVENTORY (heirloom catalog).** A probate inventory pinned up on the
grounds: named sets of heirlooms — *"The Deceased's Effects, Vol. I"* — where each heirloom is
earned by a specific accomplishment in a specific game (win MOWER without touching a flowerbed →
*"one (1) spark plug, still warm"*). Empty slots show silhouettes and the earning condition in
probate language. Completing a set erects a display case on the grounds (monument pipeline reuse)
and pays a LEGACY assessment. **No expiry. Ever.** Scope to ONE volume (12 items) for an overnight;
more volumes are content, not code.

**Dark parts stripped:** the timer (appointment anxiety), sticker *packs* (the randomized
acquisition layer — heirlooms here are earned by named deeds, never rolled), and trading-as-social-
obligation.

**Build pointers:** earn conditions hook `EstateState.chronicle_event()` (already a generic event
bus); persistence beside `monuments`; grounds panel modeled on `estate/monuments_view.gd` /
`family_album.gd`. Est. 6–9 h for one 12-item volume including strings.

---

### 1.4 Daily login rewards / streaks — TRANSPLANT THE RITUAL, BAN THE STREAK ✓/✗

**The psychology.** Login bonuses build a Fogg-style habit loop (cue → trivial action → payoff);
streaks add loss aversion (a 30-day streak breaking hurts more than the rewards were ever worth).
The *ritual* half is genuinely pleasant — arrival ceremonies, being greeted, the day's table being
set. The *streak* half is a dark pattern outright: it manufactures obligation, punishes absence,
and its entire power source is anxiety. Research on engagement rewards ("Daily Quests or Daily
Pests") lands the same split: rewards for showing up are fine; penalties for not showing up are the
poison.

**Why the ritual adds fun on a couch.** ILL WILL's sessions are real nights, weeks apart. The
moment a returning estate loads is the game's single most emotionally loaded beat — grudges
waiting, monuments standing — and right now it is a slot-picker line. F2P knows exactly how to
honor an arrival; steal that.

**The transplant — VISITATION HOURS.** When a slot with `nights_played > 0` is opened, a short
arrival ceremony: the gates; the Executor noting the absence to the day (*"Forty-one days. The
estate counted each one. It had little else to do."* — save one timestamp to make this work); a
one-line docket of standing business (armed vendetta, unfinished run, last champion); and a small
**condolence disbursement** of LEGACY to each seated player, flat, unconditional. **The inversion
is the whole ethics:** absence is never penalized and never resets anything — the longer you were
gone, the drier the line. The streak is replaced by a bureaucracy that missed you and refuses to
say so.

**Dark parts stripped:** streaks, lapse penalties, calendar appointments, escalating day-N tables
(day-7-jackpot structures exist to force consecutive attendance).

**Build pointers:** timestamp + nights in slot save (`estate_state.gd` save/load); ceremony panel
at estate entry (`estate/estate.gd` lobby path, near where `house_rules_shown` gates the House
Rules card — same once-per-entry pattern); Executor lines per voice bible doc 26. Est. 3–4 h.

---

### 1.5 Battle pass / season track — TRANSPLANT THE LADDER, BAN THE SEASON ✓/✗ — **THE BIG SWING**

**The psychology.** Battle passes work because progression is *visible* — a numbered ladder where
every tier is a named milestone, converting playtime into a legible climb (goal-setting theory +
goal-gradient acceleration near each tier). The dark half is the **season**: expiry converts the
ladder into a treadmill, and sunk-cost ("wasting your investment if you don't play") does the rest.

**Why it adds fun on a couch.** The estate persists across real nights but its long arc is
diffuse — monuments accumulate, but nothing *counts down toward anything*. A visible ladder gives a
recurring group a shared campaign: "two more clauses and the mausoleum opens." That is the same
social glue as a D&D campaign tracker.

**The transplant — THE PROBATE DOCKET.** Probate of the estate itself proceeds in numbered clauses
(one ladder per save slot, 10–12 clauses for v1). Clauses advance from *collective* play — nights
completed, total deeds ever bought, total kills recorded, sets completed, monuments raised — all
already in `chronicle`/`ledger`. Each clause unlocks estate-wide vanity: new wardrobe stock
"released from the vault" (staggers the flat 8-hat store into discoveries), a monument style, a
graffiti stencil, a new crow, a gate ornament, an attract-mode reel. **No expiry, no per-player
track (collective — the couch climbs together, no pass-envy between seats), no skip mechanism.**

**Plus one free psychology rider — the endowed-progress effect:** the canonical Nunes & Drèze
punch-card study (10 slots with 2 pre-stamped beats 8 blank slots, 34% vs 19% completion) transplants
as pure fiction: every new estate's docket opens with **clauses 1 and 2 already stamped** —
*"executed by the deceased, prior to becoming the deceased."* Funny, free, and measurably
motivating.

**Dark parts stripped:** the season/expiry, paid tiers, tier skips, daily-quest feeders, and
per-player competitive tracks.

**Build pointers:** clause definitions + progress derivation in `estate_state.gd` (pure functions
over `chronicle`/`ledger`/`nights_played`); a docket panel on the grounds (reuse the
`monuments_view.gd` panel pattern); gating reads in `wardrobe_panel.gd` stock list; advancement
beat in the night-end ceremony chain. Est. 8–12 h — the one labeled big swing.

---

### 1.6 Achievement toasts — TRANSPLANT, CAPPED ✓

**The psychology.** A milestone toast converts a number into an *event* — the unlock moment
produces a response plain counters never do, and shared unlock moments bond a room. The failure
mode is noise: toast spam trains blindness and (per doc 26) mid-round banners are already the
anthology's weakest register.

**The transplant — CODICIL NOTICES.** First-time-ever chronicle events (first kill of a returning
rival, first monument, hundredth recorded death, a vendetta settled) file a small stamped notice —
paper slip, wax stamp *thunk*, one two-beat line — during board phases or results screens **only**,
never mid-minigame. Hard cap: 2 per night, queue the rest into the eulogy (the Executor reads the
overflow, which is funnier anyway). `MomentScribe`/`chronicle_event()` already see every event;
this is presentation only. Est. ~3 h.

---

### 1.7 Prize-wheel stop button (illusion of control) — INVERT INTO A JOKE ✓ (cheap delight)

**The psychology.** Letting players "stop" a wheel whose outcome is predetermined measurably
increases engagement via illusory agency — and in gambling contexts it is a dark pattern precisely
because the agency is fake and induces spend. ILL WILL's house style is aggressively honest about
this exact thing (the séance wheel's own comments: "pure theater... never decides anything").

**The transplant — honesty as the punchline.** Give the séance wheel a STOP prompt for the current
player. Pressing it does nothing to the outcome — *visibly* nothing; the wheel completes its
deceleration with perfect indifference — and the Executor notes: *"The wheel has received your
input. The wheel will proceed."* The dark pattern, mocked to its face, in-register. One press
handler + one line pool. Est. 1–2 h. (The real agency budget is already spent correctly: the putt
IS the dice.)

---

## 2. DO NOT TRANSPLANT — even defanged

1. **Streaks / lapse penalties / appointment mechanics.** Power source is loss-aversion anxiety and
   calendar obligation. A couch game that punishes a group for having lives punishes its own
   premise. (Visitation Hours deliberately inverts this.)
2. **Expiring collections / limited-time albums & events.** Scarcity-by-deadline converts the
   completion itch into scheduled stress and burnout; documented player exhaustion in Monopoly GO.
   Collections here are permanent or they don't exist.
3. **Losses disguised as wins.** Celebrating a net loss with win fanfare (e.g., fanfaring 2 points
   gained while 5 grudge was lost) measurably distorts decision-making. House rule: fanfare only
   net-positive outcomes; the estate files net losses in its dry register, where they're funnier
   anyway.
4. **Engineered near-misses.** Systematically showing the jackpot one tick away spikes win-circuit
   arousal on a loss. Theatrical deceleration onto the TRUE result (current wheel/roulette
   behavior) is fine; biasing presentation to *manufacture* almost-won is not. Never add "the
   needle hesitates one wedge short of ruin" logic.
5. **Randomized acquisition of desired items (loot boxes), dupes, and shard/pity-currency
   conversion.** Even money-free, rolling for a *specific wanted thing* imports gambling's
   frustration loop. The Bequest stays a gift (no spend), no-dupe, tell-first; the wardrobe stays
   deterministic purchase.
6. **Rate-up / FOMO banners.** "Featured now, gone Tuesday" is artificial scarcity with no couch
   upside. Anything the estate ever offers remains available.
7. **Fake agency that stays fake.** A stop button players *believe* works is deception; either make
   agency real (the putt) or make the fakery the joke (1.7).
8. **Endowed progress as deception at scale** — pre-stamping is charming once, in fiction, on a
   vanity ladder (1.5); using it on *economy* tracks (deeds, points) to manipulate pacing would be
   rubber-banding in a trench coat. Keep it off anything competitive.

## 3. Priority order for an overnight

1. **Visitation Hours** (3–4 h) — highest emotion-per-hour, touches only entry flow.
2. **The Estate Takes Pity** (4–6 h) — fixes the loser experience, the genre's oldest wound.
3. **The Bequest** (5–8 h) — the night gets a closing ceremony worthy of its opening ones.
4. **Codicil Notices** (3 h) — cheap; do only if B5 writing bandwidth exists for the line pools.
5. **Séance wheel STOP joke** (1–2 h) — dessert.
6. **BIG SWING: The Probate Docket** (8–12 h) — its own lane/night; unlocks re-staging the
   wardrobe and gives multi-night groups a campaign arc. The Estate Inventory (1.3) can later hang
   its set-completion rewards off docket clauses, so build the docket first if both are wanted.

## Sources

- [MWM — Pity System glossary](https://mwm.ai/glossary/pity-system)
- [GamerBraves — Pity or No Pity: guarantee systems in gacha](https://www.gamerbraves.com/pity-or-no-pity-a-look-at-guarantee-systems-in-gacha/)
- [Massively Overpowered — Gachapwned: pity and free content](https://massivelyop.com/2025/05/16/gachapwned-how-gacha-mechanics-use-pity-and-free-content-to-encourage-spending-money/)
- [Wikipedia — Gacha game](https://en.wikipedia.org/wiki/Gacha_game)
- [Epic Games Store — Gacha games explained: banners, pulls, pity](https://store.epicgames.com/news/gacha-games-explained-banners-pulls-pity-systems-and-more?lang=en-US)
- [GameWith — Arknights: Endfield gacha animations (rarity tells)](https://gamewith.net/akendfield/72597)
- [GameWith — NTE gacha animations](https://gamewith.net/nte/74109)
- [TheGamer — Monopoly GO sticker albums guide](https://www.thegamer.com/monopoly-go-sticker-albums-faq-complete-guide/)
- [IGGM — Monopoly GO album mechanics & event pressure](https://www.iggm.com/news/monopoly-go-the-simpsons-album-mechanics-event-guide-collect-episode-sticker-sets)
- [Springer, J. Gambling Studies — LDWs and near misses: systematic review](https://link.springer.com/article/10.1007/s10899-017-9688-0)
- [Wikipedia — Near-miss effect](https://en.wikipedia.org/wiki/Near-miss_effect)
- [Casino Center — near-miss effect and player behavior](https://www.casinocenter.com/slot-machine-psychology-how-the-near-miss-effect-drives-player-behavior-in-online-gaming/)
- [Medium/Bootcamp — Streaks and daily rewards as habit-forming systems](https://medium.com/design-bootcamp/streaks-and-daily-rewards-as-habit-forming-systems-dab7f5a34539)
- [Speedway Media — Daily login bonus psychology](https://speedwaymedia.com/2026/04/29/daily-login-bonus-psychology-how-streak-rewards-shape-habits-and-when-to-step-back/)
- [ResearchGate — Daily Quests or Daily Pests? Engagement rewards in games](https://www.researchgate.net/publication/365003534_Daily_Quests_or_Daily_Pests_The_Benefits_and_Pitfalls_of_Engagement_Rewards_in_Games)
- [TechInBengali — Chris Wilson's dark-pattern taxonomy in games](https://en.techinbengali.com/chris-wilson-dark-patterns-games-psychological-manipulation-explained/)
- [Deconstructor of Fun — Battle Passes: everything you ought to know](https://www.deconstructoroffun.com/blog/2022/6/4/battle-passes-analysis)
- [G2G News — psychology behind battle passes](https://g2g.news/gaming/hooked-on-rewards-the-psychology-behind-battle-passes-in-free-to-play-games/)
- [forokd — psychological tricks of season passes](https://forokd.com/psychological-tricks-behind-season-passes-and-how-they-boost-sales/)
- [Game Developer — Endowed Progress Effect and game quests (Nunes & Drèze)](https://www.gamedeveloper.com/game-platforms/the-psychology-of-games-the-endowed-progress-effect-and-game-quests)
- [Learning Loop — Endowed progress effect](https://learningloop.io/plays/psychology/endowed-progress-effect)
- [Yu-kai Chou — the power of milestone unlocks](https://yukaichou.com/advanced-gamification/the-power-of-milestone-unlocks-in-gamification-design/)
- [Game Developer — Achievement Design 101](https://www.gamedeveloper.com/design/achievement-design-101)
- [DigiWheel — why players love spin-to-win](https://digiwheel.com/why-players-love-spin-to-win-mechanics/)
- [QJEP — Let me take the wheel: illusory control and sense of agency](https://www.tandfonline.com/doi/full/10.1080/17470218.2016.1206128)
