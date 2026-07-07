# The Ship Package — 2026-07-07 (icon, build script, store blurb, name scan)

Everything needed to hand ILL WILL to a player who has never seen a terminal.
Estate/packaging lane. Companion to the first-night HOUSE RULES card (same
night's work; see the estate deliverable).

---

## (a) Icon — assets/ui/illwill.ico

A "sealed will" mark: a chunky gold **spade** (the estate's grudge currency) on
aged dark-plum parchment with a gold rim, wearing the LuckiestGuy logotype. The
`.ico` carries six layers — 256 / 128 / 64 / 48 / 32 / 16. The three large
layers stack the **ILL / WILL** wordmark under the spade; the three small layers
drop to a **spade-only seal** so the silhouette stays legible in a 16px taskbar
slot where text would smear.

- Generator: `build/generate_icon.py` (pure Pillow — draws the spade as a
  dilated union mask, so it needs no system spade glyph and scales crisply).
  Re-run any time with `python build/generate_icon.py`; per-size PNG proofs land
  in `build/icon_layers/`.
- Wired into `export_presets.cfg`:
  `application/icon="res://assets/ui/illwill.ico"` and
  `application/console_wrapper_icon="res://assets/ui/illwill.ico"`.
- Verified embedded in the exported `illwill.exe` (Explorer/taskbar shows the
  gold spade, not Godot's default robot).

**For the director — project.godot** (that file is owned by another agent
tonight; these lines set the *runtime* window/taskbar icon, which the export
`application/icon` does not cover). Add under `[application]`:

```
config/icon="res://assets/ui/icon.png"
config/windows_native_icon="res://assets/ui/illwill.ico"
```

`assets/ui/icon.png` (256px) is committed alongside the `.ico` for exactly this.
`config/icon` must be a PNG; `config/windows_native_icon` takes the `.ico`.

---

## (b) build/package.ps1 — rebuild + package

Windows PowerShell 5.1. Turns a clean checkout into a shippable zip:

1. Regenerates the icon if `assets/ui/illwill.ico` is missing (needs python).
2. Headless reimports the project (primes the `.godot` cache).
3. Exports a release **Windows Desktop** build — a single embedded-pck
   `build/illwill.exe`.
4. Writes `build/README-FOR-PLAYERS.txt` (controls quickstart, couch + online,
   port-forward note, Steam Remote Play tip).
5. Zips `illwill.exe` + `README-FOR-PLAYERS.txt` + `STORE-BLURB.md` into
   `build/illwill-<version>.zip` (version read from
   `export_presets.cfg application/file_version`).

```powershell
powershell -ExecutionPolicy Bypass -File build\package.ps1
# or point it at a specific engine:
powershell -File build\package.ps1 -Godot 'C:\path\to\Godot_console.exe'
```

**Gotcha it handles (documented so it is not re-discovered):** the plain Godot
Windows *editor* exe relaunches itself detached and returns immediately, so a
naive `&` sees the export "finish" before `illwill.exe` exists. `Resolve-Godot`
follows the WinGet symlink and prefers the sibling `*_console.exe` build (which
blocks and streams), and the exe check polls for the file to appear **and stop
growing** (a ~290 MB write + AV scan lags the process exit). No `&&`/`||`/
ternary; native exit codes read via `$LASTEXITCODE`; the README is a
single-quoted here-string (literal, no `$` interpolation surprises).

`build/` is gitignored, so the exe/zip/console-wrapper are never committed; only
`package.ps1` and `generate_icon.py` are tracked (force-added).

**Proof run (this session, Godot 4.6.2):**

```
Godot:    ...\Godot_v4.6.2-stable_win64_console.exe
Version:  0.1.0
Icon:     assets/ui/illwill.ico
Export:   Windows Desktop -> build\illwill.exe
PACKAGED  illwill-0.1.0.zip   (196.94 MB)
contents  illwill.exe  +  README-FOR-PLAYERS.txt  +  STORE-BLURB.md
```

---

## (c) STORE-BLURB.md — the itch.io pitch

Canonical pitch lives at repo-root `STORE-BLURB.md` (~150 words, house voice —
dry, Saki-adjacent) and ships inside the player zip. Summary: *a party game
about inheritance and betrayal* — a dead relative, an impeccable Executor,
thirteen unfair games between you and the manor. Bid spite at the auction, seed
traps that pay you when they take a friend, climb the trail, and end each night
at the Reading where nobody is flattered. Feature bullets: **13 minigames** won
at a live grudge auction; a **persistent estate** (monuments, graffiti, ledger,
wardrobe); **vendettas**; **royalties**; **the climb** to the manor; **4-player
couch + online host/join**. Edit `STORE-BLURB.md` to revise — it is the single
source the zip copies.

---

## (d) NAME SCAN — "ILL WILL" (factual collection)

Prepared for the attorney-owner. **Factual only — no legal conclusions, risk
ratings, or recommendations; he draws those.** Collected 2026-07-07 via web
search.

### Games
- **illWill** — old-school "boomer shooter" FPS (single dev, Slava Bushuev),
  PC/Steam, 2023-04-13, "Very Positive" —
  https://store.steampowered.com/app/1567000/illWill/
- **Ill Will** — turn-based dungeon-crawler RPG by LouisCyphre, RPG Maker VX,
  completed 2012-07-31 (2009 contest origin) — https://rpgmaker.net/games/1647/
- **ILL** — first-person survival-horror (Team Clout), announced 2027,
  PS5/Xbox Series/PC — titled "ILL," surfaces adjacent —
  https://store.steampowered.com/app/1757350/ILL/
- itch.io: no game titled "Ill Will" surfaced; nearest are unrelated titles
  named "Inheritance" — https://itch.io/games/tag-inheritance

### Film / TV
- **Ill Will** — short, dir. Jennifer Elster, 2001 — imdb.com/title/tt0283399/
- **Ill Will** — drama short, 2013 — imdb.com/title/tt3038086/
- **Ill Will** — stop-motion short, 2013 — imdb.com/title/tt3655338/
- **Ill Will** — action/crime short, 2014 — imdb.com/title/tt3822920/
- **Ill Will** — horror short, 2015 — imdb.com/title/tt4368810/
- **Ill Will** — drama short (heirs divide a fortune), 2021 —
  imdb.com/title/tt13930828/
- **Ill Will** — thriller short — imdb.com/title/tt11002868/
- **Ill Will** — TV series, "in development" (IMDbPro) —
  imdb.com/title/tt8063984/
- **No Ill Will** — drama short (near-variant), 2018 —
  imdb.com/title/tt9253666/

### Music
- **Ill Will Records** — label founded by Nas & Steve Stoute, 1999 (named for
  Willie "Ill Will" Graham) — en.wikipedia.org/wiki/Ill_Will_Records
- **Ill Will** — metal band (Encyclopaedia Metallum) —
  metal-archives.com/bands/Ill_Will/more
- **ILL WILL** — Houston hip-hop artist, active since 2004 (Apple/Spotify/SC) —
  music.apple.com/us/artist/ill-will/1476757942
- **ILL Will {Da South Most Hated}** — Bandcamp album —
  illheavenent.bandcamp.com/album/ill-will-show-2

### Books / Comics
- **Ill Will: A Novel** — Dan Chaon, 2017, Ballantine/PRH, bestseller —
  penguinrandomhouse.com/books/26150/ill-will-by-dan-chaon/
- **The Art of Ill Will: The Story of American Political Cartoons** — Donald
  Dewey, NYU Press — amazon.com/dp/0814720153
- **Ill Will** — character in *The Germs* comic strip —
  comicvine.gamespot.com/ill-will/4005-77402/
- **iLL WiLL PrEss: Underground Comic Collection** — Jonathan Ian Mathers —
  goodreads.com/book/show/21367133-ill-will-press

### Companies / Brands / Publishers
- **Ill Will Press** — animation studio behind *Neurotically Yours* / Foamy the
  Squirrel (J.I. Mathers); active merch + itch.io presence —
  illwillpress.itch.io / en.wikipedia.org/wiki/Neurotically_Yours
- **Ill Will Editions / Ill Will** — independent radical/anarchist publisher,
  since 2013 — illwill.com / store.illwilleditions.com
- **Ill Will Records** — also a business entity (see Music)

### Other
- **Ill Will** — Wikipedia disambiguation page (term maps to many entities) —
  en.wikipedia.org/wiki/Ill_Will

### Collision summary (descriptive only)
The name "Ill Will" (and variants "illWill," "Illwill," "iLL WiLL") appears
across many media categories and is a common English idiom, which drives a high
number of independent, unrelated uses. In the **games** space specifically the
name is used but not densely: two distinct released titles carry the exact name
— a 2023 Steam FPS "illWill" (single-word styling) and a 2012 RPG Maker
dungeon-crawler "Ill Will" — plus a separate, similarly-spelled but non-identical
upcoming Steam horror title "ILL" (2027); no game titled "Ill Will" surfaced on
itch.io. Outside games the name is more crowded: film/TV shows roughly eight-plus
short films and one in-development drama series titled "Ill Will," plus a nearby
variant "No Ill Will." Music and publishing hold the most prominent established
uses — Nas's "Ill Will Records," Dan Chaon's 2017 novel "Ill Will," the
long-running "Ill Will Press" animation brand, and the "Ill Will Editions"
publisher. Overall the term is widely reused across media, heaviest in film
shorts, music, and books/publishing, and comparatively lighter and non-identical
within video games.
