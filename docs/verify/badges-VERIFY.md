# Never-Color-Alone Accessibility Pass — VERIFY

Player identity in the anthology was pure color (P0 RED, P1 BLUE, P2 GOLD,
P3 MINT — colors from `scripts/game_state.gd`). A colorblind player could not
find themselves. This pass pairs every color use with a **SHAPE** so identity
travels as shape + color + name together.

Shape by player **index** (not color name): `0 = CIRCLE`, `1 = TRIANGLE`,
`2 = SQUARE`, `3 = DIAMOND`.

Godot 4.6.2, Windows. All screenshots captured WINDOWED via the `VerifyCapture`
`--shots=` harness (headless cannot render the viewport). Project imported clean
(`godot --headless --editor --import --quit --path .` — zero errors).

---

## Deliverable 1 — `core/player_badge.gd`

`class_name PlayerBadge extends Control`. Draws procedurally in `_draw()`
(`draw_circle` / `draw_colored_polygon` / `draw_rect` + outline stroke) — **no
font, no textures**, so it can never render as tofu.

- Filled with the player color, thin dark outline (`~9%` of size) for contrast
  on any background (verified legible on black, white-ish, tan, and space-dark).
- Configurable: `player_index`, `size_px` (drives `custom_minimum_size`),
  `color` (explicit override; falls back to a palette mirroring
  `GameState.PLAYER_COLORS`), `dim` (0..1 brightness for dead/eliminated).
- All properties `queue_redraw()` on set, so a badge can be re-pointed at a
  different player in-place (used by rank-sorted HUDs, below).
- `_init()` sets `mouse_filter = IGNORE` and `SIZE_SHRINK_CENTER` both axes so
  the shape stays square and vertically centered inside an HBox row instead of
  stretching to the tallest sibling.
- Static helpers: `shape_name(p) -> String`, `make(p, size_px) -> PlayerBadge`
  (one-line HUD integration), and `glyph(p) -> String` (● ▲ ■ ◆ for 3D tags).

---

## Deliverable 2 — 2D HUD badges in all nine games

Every game's scoreboard was a `VBoxContainer` (`score_rows` / `_score_rows`) of
bare `Label`s. Integration wraps each row in an `HBoxContainer` holding
`[PlayerBadge, Label]`, badge immediately LEFT of the name/score, sized to the
row's font (22–26 px), colored to that row's exact roster color. No HUD was
redesigned — same panels, fonts, sizes, tags, sort order.

| Game | Screenshot | Verdict |
|------|-----------|---------|
| tilt | `shots/badge_tilt.png` | PASS — ● RED ▲ BLUE ■ GOLD ◆ MINT, top-right panel. Fallen players' badges dimmed (GULL). |
| dead_weight | `shots/badge_dead_weight.png` | PASS — reads clearly on pure-black bg via outline. Dead/ghost badges dimmed. |
| echo_chamber | `shots/badge_echo_chamber.png` | PASS — rows reorder by placement; badge **reassigned per slot** so shape always matches its name. KO'd players dimmed. |
| greed | `shots/badge_greed.png` | PASS — top-right panel, sorted by points. |
| throne | `shots/badge_throne.png` | PASS — top-right panel. |
| mower | `shots/badge_mower.png` | PASS — top-left panel, sorted by coverage. |
| orbital | `shots/badge_orbital.png` | PASS — top-left, labels float on space bg (no panel), outline carries it. |
| swap_meet | `shots/badge_swap_meet.png` | PASS — P1..P4 rows ranked by race position; badge **reassigned per slot each frame**. |
| last_will | `shots/badge_last_will.png` | PASS — top-right panel. Dead players dimmed. |

Every badge was read back by eye at 1280x720 and checked for overlap, size, and
contrast. No overlaps; badge/name spacing is 6 px; badges sit centered on the
text cap-height.

### Ambiguous / judgment calls
- **Rank-sorted rows (echo_chamber, swap_meet):** these HUDs keep a fixed set of
  row widgets and re-point them at different players as standings change
  (echo per rebuild, swap every frame). A statically-created badge would show
  the wrong shape after the first reorder. Chosen fix: the badge's
  `player_index`/`color` are reassigned in the same update loop that sets the
  label text, so shape+color+name in a row are always the same player.
- **`dim` for eliminated state:** applied `dim ≈ 0.45` where a per-row
  dead/out flag was already computed — dead_weight (ghost/KO), tilt (GULL),
  last_will (`not alive`), echo_chamber (fighter not alive); swap_meet uses
  `0.6` for finished karts. greed/throne/mower/orbital have no per-row death
  state in the scoreboard, so their badges are always full-bright (matches the
  existing text, which also never dims there).
- **mower top-left corner artifact:** a small multicolor swatch sits above the
  score panel. It is **pre-existing** (a mower debug/legend element, unrelated
  to this pass) and was left untouched.

---

## Deliverable 3 — Label3D 3D name tags: glyphs render CLEANLY → shipped

**Probe:** `docs/verify/label3d_probe.tscn` renders ● ▲ ■ ◆ in a `Label3D`
using both the project default font (**Fredoka**, used by pawn/ghost name tags)
and **LuckiestGuy** (used by kart/orbital tags), plus a name-tag mimic row.

**Verdict: the glyphs render as proper filled shapes — NOT tofu boxes — in both
fonts.** Proof: `shots/badge_label3d_probe.png`.

Because they render cleanly, the shape glyph was prefixed to every per-player
3D name tag:

| Tag | File | Result |
|-----|------|--------|
| last_will pawn name | `minigames/last_will/lw_pawn.gd` | `"▲ BLUE"` etc. — see `shots/badge_last_will_3dtags.png` |
| last_will ghost-seat name | `minigames/last_will/lw_ghost.gd` | glyph-prefixed |
| swap_meet kart tag | `minigames/swap_meet/swap_kart.gd` | `"■ GOLD / ● RED / ▲ BLUE / ◆ MINT"` — see `shots/badge_swap_meet_3dtags.png` |

Non-identity `Label3D`s were intentionally left unchanged (they are not player
name tags): greed pot value, tilt floating combat text, last_will boulder
"BANG!" fx, swap_meet track "FINISH" banner.

---

## Files changed / added
- **New:** `core/player_badge.gd` (+ `.uid`)
- **New (verification):** `docs/verify/label3d_probe.tscn`, `label3d_probe.gd`,
  `docs/verify/badges-VERIFY.md`, `docs/verify/shots/badge_*.png`
- **Edited (2D HUD):** dead_weight, echo_chamber, greed, mower, throne, tilt,
  last_will, orbital, swap_meet `.gd`
- **Edited (3D tags):** lw_pawn, lw_ghost, swap_kart `.gd`

## Open items
- None blocking. All nine 2D HUDs and all three 3D name-tag families ship the
  shape. Glyphs verified to render in both project fonts.
- `.import` metadata churn from the import run is line-ending-only (empty
  content diff) and was deliberately kept out of the commit.
