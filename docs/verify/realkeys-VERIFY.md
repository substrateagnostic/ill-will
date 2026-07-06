# realkeys-VERIFY — In-game hint bars show the player's REAL keys

First outside tester's best UX note:

> "Have the action keys correspond to what the actual button is, instead of
> making the user look in the settings. So Space = Shove/Decree and E = Dash and
> Guard."

Every game showed a generic legend like `A = SHOVE   B = HOP` — meaningless to a
keyboard player, who never presses a face button labelled "A". This pass
retrofits the persistent main HINT BARS in five games to print the LIVE per-seat
binding via `PlayerInput.describe_binding(p, action)` — the same API the
How-to-Play cards already trust.

Scope touched (this lane only — presentation, no logic): `minigames/tilt/`,
`minigames/mower/`, `minigames/orbital/`, `minigames/throne/`,
`minigames/dead_weight/`, and this doc + `docs/verify/realkeys-shots/`. No shared
autoload, `.tscn`, `scripts/`, `estate/`, or `project.godot` change. Deterministic
receipts are untouched (text only). The recently-added dead-state hint lines in
`dead_weight` / `tilt` already used `describe_binding` and were left as-is — the
MAIN bars are now consistent with them.

## The standardized bar format (director: apply this to the remaining games)

Each game gained three tiny, self-contained helpers (no shared file, so no
collision with the other lanes running tonight):

```gdscript
func _human_seats() -> Array:            # non-bot seats with a real device
func _btn_hint(action, label) -> String: # one button's live legend
func _controls_bar() -> String:          # the whole bar, or "" -> generic fallback
```

`_btn_hint(action, label)` is the reusable primitive. Rules, in order:

1. **All human seats share the binding text** (common: everyone on pads) → show
   it once: `"%s = %s" % [key, label]` → `(A) = SHOVE`, or `Space = SHOVE` for a
   lone keyboard human.
2. **Seats differ** (mixed keyboard + pad) → compact per-seat form
   `"%s: %s" % [label, key/NAME · key/NAME …]` → `SHOVE: Space/RED · Enter/BLUE`.
   NAME is the seat's identity color (`GameState.PLAYER_NAMES[i]` = RED/BLUE/GOLD/MINT).
3. **No human seats** (all-bot demo) → `_controls_bar()` returns the game's
   original generic string. Nothing to personalize; receipts/demos byte-identical.

All labels are plain `Label` nodes (no BBCode), so the format is plain text with
`/NAME` tags rather than color badges — clean and readable with four seats sharing
one bar. Bindings are fixed per match, so the bar is built once when the match /
round starts (in `begin()` / `_start_round()`); no live polling.

Per-game bar (human seats present):

| Game | Bar template |
|------|--------------|
| tilt | `MOVE   ·   {a:SHOVE}   ·   {b:BRACE}   \|   FALL AND YOU RETURN AS A SEAGULL` |
| mower | `MOVE = STEER   ·   {a:RAM HORN}   ·   {b:BOOST}   \|   COVERAGE IS SCORE` |
| orbital | `MOVE walk   ·   {a:THROW (hold) / CATCH (tap)}   ·   {b:JUMP the gap}` |
| throne | `MOVE   ·   {a:SHOVE / DECREE}   ·   {b:DASH / GUARD}   \|   SIT THE THRONE TO REIGN` |
| dead_weight | `MOVE   ·   {a:SHOVE}   ·   {b:HOP}   ·   THE DEAD POSSESS THE FURNITURE` |

## Verification (windowed, screenshots read by eye)

`user://party_setup.json` was backed up, then staged so `PlayerInput.load_setup()`
(run by the PartySetup autoload at boot) yields a MIXED-device roster on
standalone self-start:

```json
{"devices":{"0":-1,"1":-2,"2":-3,"3":-3},
 "bots":{"0":false,"1":false,"2":true,"3":true}}
```

- **P0 = RED** → device -1 (keyboard LEFT: WASD move, `Space`=a, `E`=b) — human
- **P1 = BLUE** → device -2 (keyboard RIGHT: arrows, `Enter`=a, `Shift`=b) — human
- **P2/P3 = GOLD/MINT** → bots

Each game launched windowed (no `--headless`) via
`godot --path . res://minigames/<g>/<g>.tscn -- --shots=120 --outdir=…`; the
`VerifyCapture` harness grabs the real rendered viewport. Every log line confirmed
`bots=[false, false, true, true]`. The staged file was restored afterward.

Observed bars (mixed keyboard-vs-keyboard → the per-seat "differ" form):

| Game | Bar as rendered | Shot |
|------|-----------------|------|
| tilt | `MOVE · SHOVE: Space/RED · Enter/BLUE · BRACE: E/RED · Shift/BLUE \| FALL AND YOU RETURN AS A SEAGULL` | `realkeys-shots/tilt.png` |
| mower | `MOVE = STEER · RAM HORN: Space/RED · Enter/BLUE · BOOST: E/RED · Shift/BLUE \| COVERAGE IS SCORE` | `realkeys-shots/mower.png` |
| orbital | `MOVE walk · THROW (hold) / CATCH (tap): Space/RED · Enter/BLUE · JUMP the gap: E/RED · Shift/BLUE` | `realkeys-shots/orbital.png` |
| throne | `MOVE · SHOVE / DECREE: Space/RED · Enter/BLUE · DASH / GUARD: E/RED · Shift/BLUE \| SIT THE THRONE TO REIGN` | `realkeys-shots/throne.png` |
| dead_weight | `MOVE · SHOVE: Space/RED · Enter/BLUE · HOP: E/RED · Shift/BLUE · THE DEAD POSSESS THE FURNITURE` | `realkeys-shots/dead_weight.png` |

Both fallback branches were exercised on tilt:

- **All-bot** (`--tiltbots`, `bots=[true×4]`) → generic bar preserved:
  `MOVE - A = SHOVE (ANSWER A SHOVE TO CLASH!) - B = BRACE | FALL … (A = BOMB)`
  (`realkeys-shots/tilt_allbot.png`).
- **Single human** (P0 only human, `bots=[false,true,true,true]`) → the all-same
  branch collapses to `MOVE · Space = SHOVE · E = BRACE | FALL AND YOU RETURN AS A
  SEAGULL` (`realkeys-shots/tilt_solo.png`).

Godot 4.6.2, headless `--import` pass clean (my scripts register with no parse
error; the only errors are the first-run cold-cache asset imports, gone on the
second pass).
