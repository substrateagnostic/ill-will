# R8 — Meta-Progression Across Nights: Making Night 10 Feel Like a Saga

**Lane:** R8 (read-only research). **Game:** ILL WILL (Godot 4.6.2, 15-game estate/probate
party anthology). **Date:** 2026-07-17.

**Thesis:** ILL WILL already has *more* cross-night memory infrastructure than almost any
shipped party game. The gap is not **capture** — it's **ceremony and browsability**. The
estate records everything and then whispers it once (a random chronicle line during the
will, a crow muttering, 8 stones on the lawn) and lets it scroll off. Dwarf Fortress taught
us the memory only becomes a *saga* when players can **sit and browse it**; Hades taught us
that returning should feel like **an ongoing conversation, not a reset**; WWE taught us that
**named grudges with escalating tiers** are what a living room actually shouts about. Every
pitch below turns data the estate ALREADY persists into shared theater. Only one (#2) adds a
new ceremony beat; none require a schema change, and none touch the real save except to read.

---

## What already exists (so we build ON it, never rebuild it)

Grounding read of `estate/estate_state.gd`, `estate/family_album.gd`, `core/moment_scribe.gd`,
`estate/newsreel.gd`, `estate/monuments_view.gd`, `estate/procession/eulogy.gd`,
`core/ambient_life.gd`, plus the **real** dev save at
`%APPDATA%/Roaming/Godot/app_userdata/ILL WILL/saves/slot_1.json` (5 nights of real play).

**Persistent data on disk right now (per slot):**

| Field | Shape | Where written |
|---|---|---|
| `ledger[]` | `{night, winner, awards[{who,title,line}], nemesis{hunter,prey,n}}` | `estate_state.gd:369` |
| `chronicle.by_name[NAME]` | `{nights_won, monuments, lasts, manor_taken, titles{}, nemesis_of{}, events{}}` | `_rebuild_chronicle` `estate_state.gd:532` |
| `monuments[]` | `{owner, color, label, night}` | `add_monument` `:346` |
| `gate_statues[]` | `{owner, color, night}` (one per night's champ) | `end_night` `:368` |
| `graffiti[]` | raw strings, capped 24 | `add_graffiti` `:355` |
| `legacy{idx:int}` | lifetime points-currency per seat | `end_night` `:376` |
| `wardrobe{idx:[ids]}` | owned cosmetics | `buy_cosmetic` `:412` |
| `run{trail_pos, tollgates, run_night, active}` | the climb-to-manor across nights | `save_estate` `:451` |
| album `photos[]` | `{caption, file(png), night, game, players[]}` incl. a **"THE VICTOR"** portrait/night | `family_album.gd:46` |
| moment stills | best-8 PNGs/night on disk | `moment_scribe.gd` |

**Presentation surfaces that already read it:** monuments on lawn (8 newest, `monuments_view.gd:13`),
graffiti wall (10 newest as raw text `:70`), family album wall + walk-up desk (`estate.gd:1367`),
the **newsreel** silent film before the will (`newsreel.gd`, engine is fully reusable via
`Newsreel.play(moments, on_done)` `:66`), Executor chronicle lines during will-reading
(`estate.gd:2179`), the procedural **eulogy** (`eulogy.gd`), lobby greeting that names last
night's award-winner (`_executor_greeting` `estate.gd:1220`), and crows that gossip
`chronicle_lines()` verbatim (`ambient_life.gd:441`).

**The real save proves the appetite is already being fed:** 5 nights recorded. Champions
N1 RED, N2 BLUE, N3 BLUE (back-to-back — a dynasty seed), N4 RED, N5 GOLD. Monument counts:
RED 4, BLUE 2, GOLD 1, MINT 0. **MINT: 0 nights won, THE DOORMAT ×3, dead-last ×3** — the
estate has organically produced a lovable-loser arc it currently does almost nothing with.
`nemesis_of` is empty across all four names (no kill_events fired yet in this save) — so any
rivalry surface is **correct but sparse today, and blooms as kill-games get played**. Flag noted
in #4.

**Reference-game takeaways** (Rogue Legacy, Hades, Dwarf Fortress, WWE 2K, Cult of the Lamb,
Animal Crossing) are folded into each pitch's rationale rather than listed separately.
Sources at the end.

---

## THE TOP 5

### 1. THE RECORDS — the estate's browsable almanac (FLAGSHIP; pure read)

**Pitch.** A walk-up lectern on the grounds ("THE RECORDS", third landmark beside THE
WARDROBE and THE FAMILY ALBUM) and a menu twin, opening a paged, controller-navigable **book
of the estate** — the Dwarf-Fortress-legends-mode move the store blurb already promises
("a growing ledger… a hall of past heirs") but the game never actually renders as a place you
can *read*. Tabs:

- **HALL OF HEIRS** — one line per night, oldest→newest: night number, the champion (their
  color swatch), and — the money shot — the album's **"THE VICTOR"** portrait for that night
  hung beside it (album `players[]` already tags which seat won). Walking this is your season
  in faces. This is the "hall of past heirs" verbatim.
- **THE TITLES** — every superlative and who has worn it how often, drawn straight from
  `chronicle.by_name[].titles`. In the real save this instantly reads: *"THE DOORMAT — MINT
  ×3, RED ×1, BLUE ×1."* A living-room roast generator with zero new data.
- **THE MONUMENTS** — the full monument index (the lawn only shows 8; `monuments_view.gd:19`
  slices the rest away with a "+N older stones" label — this tab is where they live).
- **THE STANDINGS OF RECORD** — lifetime nights-won / manor-takings per name from the
  chronicle, i.e. the all-time dynasty table.

Everything is Executor-captioned in the existing Saki register. This is the single highest-
leverage thing the memory system is missing: a **destination** where the accumulated history
stops being ephemeral whispers and becomes a thing the couch pages through and argues over
between games — exactly what makes browsing DF legends and Animal Crossing's remembered
callbacks feel like *your* world remembering *you*.

**What existing data it rides.** 100% read-only: `ledger[]`, `chronicle.by_name`,
`monuments[]`, `gate_statues[]`, `legacy{}`, and `FamilyAlbumWall.entries()` photos
(`family_album.gd:79`). No new fields, no writes, no risk to the sacred save. Slots into the
proven `STROLL_SPOTS`/`_exit_stroll` pattern (`estate.gd:1304`, `:1322`) exactly like the
album desk was added — one array entry, one match branch, one `_build_records_panel()`.

**Effort.** 8–12 h (the paged panel + controller nav + loading victor portraits is the bulk;
all data accessors already exist).

**Risk.** Low. Pure presentation, additive, mirrors an existing panel. Only real hazard is
UI scope creep on the paging widget — cap it to the four tabs above for v1.

---

### 2. "PREVIOUSLY, ON THE ESTATE" — the cold-open recap (THE ONE BIG SWING)

**Pitch.** Each night after the first opens with a 15–25s **"PREVIOUSLY, ON THE ESTATE"**
recap — a TV-season cold open — assembled from *last* night's archived album stills and
ledger headlines, run through the **newsreel engine that already exists and is already built
for exactly this**. Where tonight's newsreel plays at the *end* before the will
(`newsreel.gd`), this plays last night's at the *start*, so every night becomes an episode in
a season with a "last time…" and a "…tune in." Content is trivial to assemble: pull
`FamilyAlbumWall.entries(slot)` filtered to `night == nights_played-1`, prepend one Executor
intertitle per ledger headline ("BLUE TOOK THE CROWN — AGAIN", "MINT FELL, AS IS TRADITION"),
and hand the array to `Newsreel.play()`. The reigning champ's "THE VICTOR" portrait is the
closing card, held under the line *"…and returns tonight to defend it."*

This is the big swing because it does the thing the whole design keeps reaching for — making
returning feel like a **continuing conversation** (the Hades lesson: come back and the story
*resumes*) — as a shared, sit-back, everyone-watches ceremony rather than a whisper only one
player half-hears. It bookends the existing end-of-night newsreel into a real episodic rhythm.

**What existing data it rides.** Album `photos[]` (already archived per night with captions,
game, and `players[]`), `ledger[]` headlines, and the **entire `Newsreel` class unchanged** —
`Newsreel.play(moments, on_done)` already takes exactly this array shape and already handles
Ken Burns, sepia shader, intertitles, projector audio, and unanimous-skip. We're feeding a
proven engine older frames.

**Effort.** 6–9 h (recap-assembly helper + one Executor intertitle template pass + the
night-start hook; the engine, shader, and audio are done).

**Risk.** Medium — and only because it's the one idea that adds a beat at **session start**,
where pacing sins are unforgivable. Mitigations, all cheap: fire **only** when
`nights_played > 0`; keep it ≤25s; inherit the newsreel's existing unanimous-A skip; and gate
it behind a pref so a soak/`--fast` boot never assembles it (mirror the eulogy's `not _fast`
guard, `eulogy.gd:206`). Net: host-screen-only at night start, same as the end newsreel.

---

### 3. THE STANDING GRUDGE — champion & vendetta night-open taunts (Executor card)

**Pitch.** Before game 1 each night, the Executor delivers a short **"THE STANDING GRUDGE"**
card that reads the chronicle and frames tonight's stakes like a WWE go-home promo:

- **The reigning heir** (last `ledger` winner) is named and dared: *"BLUE wears last night's
  crown. The estate expects them to lose it with dignity, and expects to be disappointed."*
- **Streaks/dynasties** (consecutive `ledger` winners): *"BLUE goes for the three-peat.
  Two portraits already mutter; a third would be unbearable."*
- **The winless** (chronicle `nights_won == 0` with nights recorded): *"MINT has survived
  five nights without a crown. The estate has stopped calling it bad luck and started calling
  it character."* (The real save's MINT is *built* for this.)
- **The armed vendetta** — the game **already computes** last night's nemesis into a
  `vendetta{hunter, prey}` at `start_night` (`estate_state.gd:162`) and currently spends it on
  a bare `print()`. Give it a banner: *"A VENDETTA IS ARMED — GOLD hunts RED. Settle it in
  blood and the estate will pay you for it."* This is the WWE grudge-match card, and the
  payout logic (`+3♠`, `THE RECKONER`) already fires when it's settled (`:214`).

This is the cheapest possible "night 10 feels like a saga" win: it makes the *opening* of each
night reference the accumulated history out loud, to the whole room, before a single putt.

**What existing data it rides.** `ledger[]` (last winner + consecutive-winner scan),
`chronicle.by_name[].nights_won`, and the already-populated `vendetta{}`. No new persistence —
it surfaces a value (`vendetta`) that's currently computed and thrown away in a print.

**Effort.** 3–5 h (a `_night_open_card()` builder + ~15 Saki lines; reuses the existing
banner/announce and the `_executor_greeting` pattern at `estate.gd:1220`).

**Risk.** Low. Additive card, skippable, presentation-only.

---

### 4. THE FEUD BOOK — head-to-head rivalry records (the WWE tab)

**Pitch.** ILL WILL tracks who kills whom (`kill_matrix`, `estate_state.gd:53`) and persists
it per-name as `nemesis_of` (`:551`), but never shows the **head-to-head** — the one thing a
living room reliably turns tribal over. Surface a **FEUD BOOK** (a tab inside #1's Records, or
a standalone page) listing every ordered rivalry with its cross-night kill count and an
escalating **intensity tier** — *grudge → feud → blood feud → vendetta* — exactly the WWE 2K
Low→Very-High rivalry ladder that makes wrestling grudges legible. Then wire two callbacks:
(a) the **BOOKMAKER** offers flavored odds on a live feud (*"the house is taking action on the
RED–GOLD rematch"*), and (b) the auction can seed a "REMATCH" tag when two feuding seats are in
contention. This makes cross-night violence *accumulate into named stories* instead of
resetting each night — the Hades/WWE fusion.

**What existing data it rides.** `chronicle.by_name[].nemesis_of{prey: n}`,
`ledger[].nemesis`, and per-night `kill_matrix`. Read-only presentation; the tiers are just
thresholds on counts the estate already keeps.

**Effort.** 4–6 h as a Records tab (less if merged into #1); +2 h for the bookmaker/auction
flavor hooks.

**Risk.** Low-medium. **Data caveat, flagged honestly:** in the current real save every
`nemesis_of` is empty (no kill-games have logged events yet), so this reads thin *today* and
comes alive only as kill-heavy games (mower, dodgeball, PALLBEARERS) accrue nights. It ships
correct and grows into itself — but don't demo it on the current slot expecting fireworks.
Cheap de-risk: also count PvP "trip"/duel graffiti lines as low-tier feud fuel so it has
something to say on night 2.

---

### 5. THE LAWN THAT READS — self-titling monuments + a saga graffiti wall

**Pitch.** Two small upgrades that make the *physical* estate narrate its own history as you
walk it (the Cult-of-the-Lamb / Animal-Crossing "the place itself remembers" pleasure):

- **Self-titling monuments.** Champion stones are currently labeled generically —
  *"RED — Champion of Night 4"* (`add_monument`, `estate_state.gd:374`). Title them from the
  night's *defining superlative or moment caption* instead: *"RED, who came dead last and won
  anyway"* (from that night's DOORMAT award + win), or the album's deciding-moment caption.
  The lawn stops being a row of identical trophies and becomes a **readable timeline of how
  each crown was actually won.**
- **The saga wall.** The graffiti wall dumps 10 raw strings as one text blob
  (`monuments_view.gd:70`). Render it as a **chronological carved scroll with night dividers**
  ("— NIGHT 3 —") so it reads like an epitaph ledger, not a debug log — the same lines, given
  the dignity of order and a frame.

Individually minor; together they're what turns *the act of walking to the next game* into
passing your own monuments and reading your own history — the ambient saga that costs no new
screen and no new data.

**What existing data it rides.** `monuments[].label` + `ledger[].awards` + album captions for
the titling; the existing `graffiti[]` array (which already carries "N3: BLUE was THE
ARCHITECT" night markers — the divider data is literally already in the strings) for the wall.

**Effort.** 3–5 h total (label-composition helper at monument-creation time + a wall-render
pass that groups by the "N#:" prefix already present).

**Risk.** Low. The monument-label change is the only one that alters *written* data going
forward (label text), which is cosmetic and non-breaking; old stones keep their old labels.
Everything else is render-side.

---

## Recommended sequencing

1. **#3 (night-open taunts)** first — 3–5 h, immediately makes every night reference the saga
   out loud, and rescues the already-computed vendetta from a `print()`.
2. **#1 (THE RECORDS)** next — the flagship destination; also the natural host for #4's tab.
3. **#5 (the lawn that reads)** — cheap ambient polish that compounds with #1.
4. **#2 (PREVIOUSLY ON)** — the big swing; do it once the above prove the appetite, since it's
   the only session-start-pacing risk.
5. **#4 (Feud Book)** — ship it folded into #1, knowing it blooms over more kill-game nights.

**Combined "saga pass" (#1+#3+#5):** ~14–22 h, all read-only or cosmetic, zero schema change,
zero risk to the real monuments — and it's the difference between an estate that *records* and
an estate the living room *revisits*.

---

## Sources

- [Rogue Legacy — Grokipedia](https://grokipedia.com/page/Rogue_Legacy) · [Traits, Rogue Legacy Wiki](https://roguelegacy.wiki.gg/wiki/Traits) · [Rogue Legacy: Genealogical Rogue-Like — Game Wisdom](https://game-wisdom.com/analysis/rogue-legacy-genealogical-rogue-like)
- [Supergiant's Hades word count — Cultured Vultures](https://culturedvultures.com/supergiant-hades-word-count-dialogue/) · [Hades Quotes — Hades Wiki](https://hades.fandom.com/wiki/Hades/Quotes_(Hades))
- [DF2014: Legends — Dwarf Fortress Wiki](https://dwarffortresswiki.org/index.php/DF2014:Legends) · [Legends Mode explained — gamepressure](https://www.gamepressure.com/newsroom/dwarf-fortress-steam-edition-modes-legends-mode-explained/zc4dbb) · [Automatic Interactive Documentation for Emergent Story Discovery — ACM](https://dl.acm.org/doi/fullHtml/10.1145/3555858.3555909)
- [WWE 2K23 Rivalry Guide — SmackDown Hotel](https://www.thesmackdownhotel.com/news/wwe2k23/wwe-2k23-universe-mode-rivalry-guide-all-cutscenes-and-what-they-do) · [WWE 2K25 Rivalry Promos — GameRant](https://gamerant.com/wwe-2k25-how-create-rivalries-guide-rivalry-promos-explained/)
- [Cult of the Lamb Followers — Fandom](https://cult-of-the-lamb.fandom.com/wiki/Followers)
- [Animal Crossing villagers have memory — TheGamer](https://www.thegamer.com/animal-crossing-new-horizons-villagers-have-memory/)
