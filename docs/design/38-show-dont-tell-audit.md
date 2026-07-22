# 38 — Show-Don't-Tell Audit

The house rule: no dialog line TELLs what the screen already SHOWs. This doc inventories every player-facing prose surface (dialog.json + the call sites that render it) and classifies each against that rule. It's the working doc for the producer's red-pen pass — every cut below is a PROPOSAL, not a shipped edit.

Method: full read of dialog/dialog.json, then every `Dialog.text/paras/has` call site plus `_flash_line`/`executor.say`/`_announce_text`/intro-card call sites across estate/, estate/procession/, minigames/*, core/. For each, read enough surrounding code to know what's actually rendered at that moment (HUD chips, flying-number popups, board props, control chips, other banners) before calling KILL. Where the visual couldn't be confirmed, the line is UNSURE, never a guessed KILL.

**Correction to the brief's assumed glyph**: the penny glyph the game actually renders is **¢** (`Spaces.PENNY_GLYPH`, `estate/procession/board_spaces.gd:34`), not ♠. The wreath glyph ⚘ is correct. Several dialog.json lines and one hardcoded `.gd` string hardcode a literal ♠ that never matches what's on screen — see Bonus Findings.

## Summary Counts

| Category | Count |
|---|---|
| KILL | 3 |
| TRIM (proposed cuts) | ~42 |
| SHOW-GAP | 9 |
| UNSURE | 7 |
| DEAD (never called) | 14 keys/pools (~29 lines) |
| DORMANT (called only from unreachable code) | 5 keys/systems |
| KEEP | remainder (majority) — voice/flavor or the only place the info appears |

---

## KILL

| Key | Line | Screen evidence | File:line |
|---|---|---|---|
| `procession.standings.header` / `.line` | "THE WREATH STANDINGS" / "#%d  %s — %d⚘ · %d¢" | Every seat's persistent HUD chip is already showing this exact rank+name+wreaths+pennies tuple, unobscured, for the full 3.0s the banner is up. Same sort function (`_roll_order()`) drives both. `_announce_text`/`_hide_announce` never hide the chip row. | `estate/procession/procession.gd:2307-2309` (banner); `:1050-1060` (chip) |
| `maskedball_coroner.present` | "Four knives. Four dances." | Fires the SAME frame as `maskedball_coroner.open` ("Four turns of the knife. Everybody carries it once.") — three simultaneous widgets (banner, sub-banner, executor line) all say "four rounds" at once. | `minigames/masked_ball/masked_ball.gd:445-447` |
| `intro.understudy.tips[2]` | "Aim with the stick, lock your vote in with A." | The SAME intro card's control chip reads "move: CHOOSE / a: COMMIT" simultaneously, and the persistent in-match HUD repeats "STICK = CHOOSE · COMMIT" verbatim once play starts. Triple redundant, no surviving unique content. | `minigames/understudy/understudy.gd:298` (chip: `:281-287`; HUD: `:646-647`) |

---

## TRIM proposals

Grouped by pattern — the same fix likely applies to every row in a group.

### Pattern A — a parenthetical/appended number duplicates a flying popup

Bug note: several of these hardcode a fixed toll (e.g. "−2♠") while the code actually pays `mini(N, grudge[seat])` — a capped amount that can be *less* than the hardcoded number when the seat is poor. The text can be flatly wrong, independent of the redundancy. Flagged where it applies.

| Key | Line | Popup evidence | File:line |
|---|---|---|---|
| `executor.offering` (variant 2) | "The road provides for %s (+3♠). The road will remember. Will you?" | `_pop_grudge(seat, 3)` fires the same +3 immediately before. | `procession.gd:3961-3962` |
| `executor.grave` (variant 1) | "%s weeps at the grave (−2♠). The grave has wept harder for less." | `_pop_grudge(seat, -loss)`, `loss = mini(2, grudge[seat])` — **hardcoded "−2♠" can mismatch the real, smaller toll.** | `procession.gd:3981-3985` |
| `executor.grave_toll` (variants 1, 4) | "…and %s collects the tears (%d♠)." / "…keeps the difference (%d♠), and the grudge." | `_pop_transfer(seat, owner, toll)` fires the identical amount immediately before (these use `%d`, so no mismatch risk — just redundant). | `procession.gd:3977-3979` |
| `executor.ferry` (variant 1) | "%s meets the Ferryman (−2♠). The crossing is short. The bill is not." | `_pop_grudge(seat, -pay)`, `pay = mini(2, grudge[seat])` — **same mismatch risk as grave.** | `procession.gd:4009-4015` |
| `executor.ferry` (variant 4, soft) | "Two pennies to cross, and %s pays. The river keeps the receipts." | Same popup/mismatch risk, spelled out in words rather than a numeral — producer's call whether the phrasing is worth the risk. | `procession.gd:4009-4015` |
| `procession.narration.ferry_pass` | "%s pays the Ferryman in passing (−2♠)" | `_pop_at(...)` fires the identical amount immediately before. Also uses the wrong glyph (♠ vs ¢). | `procession.gd:3789-3793` |
| `procession.items.crow` | "%s's CROW'S CUT strips %d%s from %s." | `_pop_transfer(target, seat, pay)` fires immediately before, identical amount. | `procession.gd:3254-3255` |
| `procession.items.debt_paid` | "%s lands on a WREATH OF DEBT — %d%s owed to %s." | `_pop_transfer(seat, owner, pay)` fires immediately before, identical amount. (Marker itself is already cleared by this point, so the naming half still carries some value.) | `procession.gd:3389-3391` |
| `procession.stirs.crow_strike` | "The court finds %s guilty of passing (−3¢). Scattered, satisfied." | `_pop_at(...)` fires the identical amount immediately before; "Scattered" also duplicates the crow-scatter animation that fires right after (`_scatter_crows()`). | `procession.gd:3815-3820` |
| `procession.stirs.wake_toast` | "%s toasts the departed (−2¢). The wake repays in rumors." | `_pop_grudge(seat, -toast)` fires the identical amount immediately before. Keep the second clause — it's the only explanation for the free séance spin that follows. | `procession.gd:3853-3859` |
| `procession.interim.line` (award-race lines only, not the will-clause lines) | "◆ %s — %s leads, %s" | `_tracker_live = true; _refresh_award_tracker()` arms the persistent "THE THREE RACES" widget with the identical title+leader+stat **in the same function**, and that widget then repeats it live for the rest of the night. | `procession.gd:4306-4321` (banner); `:1098-1120` (tracker) |
| `procession.reckoning.line` (pennies clause) | "%s  #%d  +%d¢ +%d⚘" | `_pop_grudge(p, pd)` fires the identical pennies delta in the same loop. (Wreath delta has no popup counterpart — weaker case, producer's call. Rank number: see UNSURE.) | `procession.gd:4573-4588` |
| `procession.will_reading.line` (trailing total only) | "%s — %s (%s)  +1 Wreath → ⚘%d" | The chyron wreath-gain popup fires the same beat, and `_refresh_hud()` runs immediately after the banner posts — the chip already shows the new total for nearly the whole 3.4s display. Keep "+1 Wreath" (paired with the popup, the actual moment of scoring); cut "→ ⚘%d" (the stale-by-the-time-you-read-it running total). | `procession.gd:4866-4881` |
| `procession.arrival.line` (arrived seats' rank number only; straggler rank is novel, KEEP) | "#%d  %s  +%d⚘" | For seats that have already crossed, the chip is simultaneously showing "HOME #%d" — the identical rank, from the identical source data (`arrival_order`). | `procession.gd:2484-2496` (banner); `:1054-1055` (chip) |

### Pattern B — a board prop or animation already shows what the line states

| Key | Line | Evidence | File:line |
|---|---|---|---|
| `procession.items.shovel` | "%s digs ahead four stones with the PALLBEARER'S SHOVEL. Nothing dares trigger." | `board.advance_pawn_path` animates the pawn hopping the 4 stones one at a time, visibly. Keep "nothing dares trigger" — that a hazard check was skipped isn't visible from the hop alone. | `procession.gd:3295-3308` |
| `procession.items.debt_set` | "%s lays a WREATH OF DEBT upon this stone." | `board.set_debt_marker()` spawns a persistent, owner-colored ring **plus a Label3D reading "DEBT"** on the stone — already announces the trap. Producer's call on how much name-attribution to keep (color alone is harder to read than text). | `procession.gd:3231-3232`; marker: `board_graph.gd:1449-1478` |
| `procession.cart.buy` | "%s buys %s (−%d¢)." | Double redundant: the ware was just clicked as a picker entry (already showing its name+price), and `_pop_grudge(seat, -price)` fires the identical price immediately before. | `procession.gd:3571-3573` |
| `procession.narration.seance_stir` | "The planchette stirs for %s. The circle turns…" | `seance_wheel.spin_to(slot)` visibly animates the needle turning in the same beat — "The circle turns…" narrates it directly. Keep the seat attribution, nothing else names the medium. | `procession.gd:4037-4047`; wheel: `estate/procession/seance_wheel.gd:141-165` |
| `maskedball_coroner.correct` | "A guest. The knife is satisfied." | Simultaneous with a "✓ %s" banner + placement sub-banner. Cut "A guest." (redundant with ✓); "The knife is satisfied" has no visual equivalent. | `minigames/masked_ball/masked_ball.gd:1415-1418` |
| `maskedball_coroner.wrong` | "Furniture. Let the red wax answer." | Fires the same instant `mark_wax_cross()` applies a literal red-emissive wax-X to the accuser's dancer, alongside a "✕" banner + placement sub-banner. Near-KILL — producer may want to cut the whole line and let the visual carry it. | `masked_ball.gd:1434-1440`; wax mesh: `minigames/masked_ball/mb_dancer.gd:227-257` |

### Pattern C — line duplicates the podium/results winner display

The brief's own canonical example ("announcing the winner over a podium that already shows the winner") shows up in four places:

| Key | Line | Evidence | File:line |
|---|---|---|---|
| `procession.heir.crown_wreaths` / `crown_joint` | "%s INHERITS THE ESTATE\n%d⚘ AT THE READING" / "JOINT HEIRS — %s\n%d⚘ APIECE. THE ESTATE SIGHS." | Announced literally *over* the 3D Podium (`core/podium.gd`), which already stages rank blocks, a Label3D name tag per entrant in their color, and a wreath prop at the champion's plinth — the code comment even says "KEEP the announce layer so the crown banner reads over the podium." Cut "%s INHERITS THE ESTATE" (podium already shows who); keep the wreath-count clause (not shown on the podium itself). | `procession.gd:4899-4949`; podium: `core/podium.gd:277-367` |
| `maskedball_coroner.winner` | "%s leaves with the dance." | Fires right after a "%s ♛" crown banner (badge+color+crown glyph) and confetti. Cut "%s"; keep "leaves with the dance" as the unique idiom. | `masked_ball.gd:1691, 1746, 1749` |
| `eulogy.heir` | "We commend %s, who bought %s with other people's grief…" (%s=name, %s=wreath-count phrase) | The persistent HUD chip is still showing every seat's wreath total throughout the eulogy (chips aren't hidden until `_heir_crowned`, which runs *after*); the totals card one screen earlier and the crown banner one screen later both restate the identical number. Cut the wreath-count restatement; keep the editorializing clause — that's the one thing not shown anywhere. | `estate/procession/eulogy.gd:104-105` |
| `eulogy.hoarder` | "%s ends the night %d pennies richer and not one wreath the wiser…" | `grudge[seat]` is the exact value on the chip, simultaneously, and on the totals card one beat earlier. Cut the raw pennies count; keep the pennies-vs-wreaths *comparison* — that connection isn't shown anywhere even though both numbers are. | `eulogy.gd:173` |

### Pattern D — intro-card tip duplicates its own card's control chip, or the persistent in-match HUD

| Key | Line | Duplicate of | File:line |
|---|---|---|---|
| `intro.maskedball_coroner.tips[0]` | "Guests follow the clock, bowl, and west-hall icons. Dancers fake them too." | Persistent in-round HUD renders the same 3 icons for the whole match. Keep "Dancers fake them too." | `masked_ball.gd:429`; HUD: `:1035-1036` |
| `intro.maskedball_coroner.tips[1]` | "The public Coroner walks close and presses the action once." | Same card's chip already reads "a: BOW / ACCUSE." Keep the proximity + one-shot clarification. | `masked_ball.gd:429` |
| `intro.orbital.tips[1]` | "Hop near the gap between two planets to jump to the next one." | Persistent HUD reads "JUMP the gap" for the whole match. Keep the spatial detail. | `minigames/orbital/orbital.gd:335`; HUD: `:407-409` |
| `intro.echo.tips[1]` | "Hold STRIKE to charge a heavy swing; hold DASH to parry and riposte." | Same card's chips already read "STRIKE (hold: HEAVY)" / "DASH (hold: PARRY)." Keep "…and riposte." | `minigames/echo_chamber/echo_chamber.gd:311` |
| `intro.deadweight.tips[0]` | "Shove rivals over the edge; a HOP dodges a shove and repositions." | First clause duplicates the goal line on the same card. Keep the HOP-dodge note. | `minigames/dead_weight/dead_weight.gd:389` |
| `intro.deadweight.tips[1]` | "Hold SHOVE to charge a SUPER SMASH — a slow, telegraphed radial blast." | Same card's chip: "a: SHOVE (hold = SMASH)." Keep the shape/speed detail. | `dead_weight.gd:389` |
| `intro.deadweight.tips[3]` | "Double-tap a direction to DASH — a quick burst to dodge or reposition." | Persistent HUD reads "MOVE (2x-tap = DASH)" for the whole match verbatim. | `dead_weight.gd:389`; HUD: `:919-921` |
| `intro.greed.tips[0]` | "Carry the pot to YOUR chute and hold to bank the coins as points." | Persistent HUD tail reads "CARRY THE POT TO YOUR CHUTE TO BANK IT" — near word-for-word. Consider cutting entirely once gameplay starts. | `minigames/greed/greed.gd:252`; HUD: `:1174-1176` |
| `intro.widowsgaze.goal` | "…FREEZE when she turns — or be taken." | Persistent HUD tail reads "FREEZE WHEN SHE TURNS" verbatim. Keep the opening framing ("Rob the wake while she weeps"). | `minigames/widows_gaze/widows_gaze.gd:319`; HUD: `:1222-1224` |
| `intro.widowsgaze.tips[0]` | "Hold A by a relic to lift it, carry it home, press A at your chest to bank." | Same card's chip: "a: GRAB / BANK." Keep the spatial detail. | `widows_gaze.gd:320` |
| `intro.pallbearers.tips[0]` | "The coffin moves on the BLEND of both sticks. Pull the same way to sprint." | Same card's chip ("move: CARRY, both steer") and the persistent HUD tail ("STEER TOGETHER"). Also shares the exact phrase "the BLEND of both … sticks" with `howto.goals.pallbearers` word-for-word — the strongest exact-text duplicate found in the whole audit. Keep "Pull the same way to sprint." | `minigames/pallbearers/pallbearers.gd:268` |
| `intro.lastwill.tips[2]` | "First through the crypt door takes the estate." | Restates `intro.lastwill.goal` ("first body to the crypt inherits") on the SAME card. This tip slot is genuinely spare — swap for unshown info (the winner's-curse catch-up mechanic). | `minigames/last_will/last_will.gd:333` |

### Ungrouped

| Key | Line | Evidence | File:line |
|---|---|---|---|
| `executor.round_opener` (all 6 variants) | "Round %d. The mourners take their marks; the estate takes notes." (+5 more, same "Round %d." prefix) | The topbar's `_round_lbl` chip permanently reads "ROUND %d / %d" — not just simultaneous, *always* on screen. Cut the "Round %d." prefix from every variant; keep the flavor clause. | `procession.gd:2654`; chip: `:1039` |
| `executor.arrival` (appended text, in code not JSON) | ...+ "  (HOME #%d)" | The arriving seat's chip flips to "purse  HOME #%d" the same beat (`_refresh_hud()` runs right after). Cut the appended suffix. | `procession.gd:4018-4024`; chip: `:1054-1055` |
| `executor.seance` (appended text, in code not JSON) | ...+ "  [%s — %s]" (wheel title, rule) | `seance_wheel.gd` draws each wedge's title as text on the wheel itself — the needle has already settled on a labeled wedge by the time this appends. Cut the title repeat; keep "[%s]" (the rule), which the wheel doesn't show. | `procession.gd:4071` |
| `procession.book.selfbet_ribbing` | "%s wagered on %s." + joke | The self-bet reveal strip is still on screen (2.0s hold, cleared after) showing the bettor's own badge twice across the arrow — a literal render of "wagered on themselves." Cut the factual clause; keep the joke. | `procession.gd:4564-4568` |
| `procession.interlude.doormat_header` / `.sub` / `.line` (soft) | "%s HOLDS THE DOORMAT'S PRIVILEGE" / "Bottom of the wreaths…" / "%s, lowest in wreaths, calls for %s." | "Lowest in wreaths" is inferable by comparing the 4 chips' ranks, but no chip ever states it in words — softer case than `standings`. Producer's call whether "inferable by comparison" counts as "shown." | `procession.gd:4472-4482` |
| `estate.walkabout.near` (THE THEATER case only) | "%s — A: enter %s  ·  B: desk" | THE THEATER (and THE EXECUTOR, a separate landmark) already carries a floating Label3D name sign. THE WARDROBE / FAMILY ALBUM / LYCHGATE have no equivalent sign, so the same template is only redundant for 1 of 4 spots. Either add signs to the other 3 (then trim all 4), or leave as-is. | `estate/estate.gd:1367`; signs: `:1185-1213` |

---

## SHOW-GAP

Lines carrying info the screen doesn't show anywhere — candidates for a future visual, not cuts.

| Key | Line | What's missing on screen | Candidate visual |
|---|---|---|---|
| `eulogy.mourner` | "%s wept at %s tonight, expensively…" (graves count) | No aggregate "graves visited" counter exists anywhere (chip, tracker, interim reading) — only ephemeral per-visit popups. | A graves-visited tally riding the HUD chip or a stat-tracker row, like pennies/wreaths already do. |
| `eulogy.pious` | "%s knelt at %s and was rewarded under protest…" (shrines count) | Same — no aggregate shrine-visit counter anywhere. | Same as above. |
| `eulogy.warm` (graves clause) | "…and wept at %s besides…" | Same graves-count gap. Note: the framing itself ("almost kind, how unusual") is irreplaceable — only the embedded number is a gap. | Same as above. |
| `procession.items.lucky_spent` | "%s rides the LUCKY PENNY (+%d stones)." | The bonus hop isn't visually decomposed from the base roll — one combined animation. | A distinct color/particle on the bonus portion of the hop. |
| `procession.items.invitation` | "%s seals THE INVITATION. The next game will be %s." | No immediate HUD confirmation — the round-strip's 📖 tag only updates at the next draw point, not now. | An instant "NEXT: <game>" badge. |
| `procession.items.box_full` | "%s's hands are full. The box keeps its secrets." | The item glyph row caps at 3 but never shows a "3/3" or "FULL" state. | An explicit FULL marker on the glyph row. |
| `procession.awards.tie_note` | "…the estate's coin turned, in full view" | The tie-break is a silent RNG call — no coin-flip/dice animation exists at all. The line asserts a visible fairness ritual the game never shows. | An actual coin-flip/dice effect at the tie-break moment. |
| `procession.stirs.fire.flood` | "GARDEN ROW IS CLOSED. Two turns.\n…" | "Two turns" is the sole place a duration is ever stated — no HUD countdown, and the closed fork is dropped from the crossroads options silently, with no "CLOSED" label. | A "CLOSED — N turns" badge on the crossroads/garden fork. |
| `maskedball_coroner.none` | "The knife went hungry. Third is the kindest sentence." | "Third" place is never spelled out in text — only inferable from glyph position in the podium banner. | A numbered-placement HUD/podium label. |

---

## UNSURE

Could not confirm what's on screen at the moment — flagging the open question rather than guessing.

| Key | Open question | File:line |
|---|---|---|
| `eulogy.betrayed` | Same stat (`lost`) as a will clause read once at the mid-night interim reading — but the eulogy uses the final total via its own salience scoring, which may name a different seat or a larger number than what was read mid-night. Is the value ever actually identical/simultaneous, or just conceptually similar? | `eulogy.gd:172`; interim: `procession.gd:4335` |
| `eulogy.bloody` | Same question, for the `duels` clause. | `eulogy.gd:171`; interim: `procession.gd:4336` |
| `eulogy.chronicle_prefix` | Prefixes a cross-night `EstateState.chronicle_lines()` fact — is that fact shown elsewhere (graffiti wall, monument plaque)? Not traced; outside this pass's file scope. | `eulogy.gd:118` |
| `estate.walkabout.stroll_banner` | Possible one-frame race: `_poll_stroll()` runs every process frame once strolling starts and immediately overwrites this banner's text on the very next frame. Is there actually a visible window to read it, or has it been effectively invisible in every night played? Worth an engineer's five-minute check independent of the dialog question. | `estate/estate.gd:1323, 1349-1378, 1488-1494` |
| `procession.reckoning.line` (the "#%d" rank clause specifically) | Likely duplicates the individual minigame's own ResultsBoard placement screen shown moments earlier — that's a different file per minigame (10 of them), not verified in this pass. | `procession.gd:4585-4588` |
| `intro.throne.tips[3]` | "Longest total reign wins, not whoever sits last." Does `throne.gd` ever surface a live "longest reign" readout mid-match? Not traced. | `minigames/throne/throne.gd:308` |
| `maskedball_coroner.highlight_correct` / `.highlight_wrong` | Read like post-game recap/highlight-reel lines. The consuming recap/results screen (wherever `report_finished()`'s output actually renders) wasn't traced — if it already shows a round-by-round table, these become KILL candidates. | `masked_ball.gd:1719-1723` |

---

## DEAD (defined in dialog.json, never called by any code)

- `procession.heir.crown` and `procession.heir.crown_gate` — zero references anywhere; the live crown path uses `crown_wreaths`/`crown_joint` exclusively.
- `executor.shrine`, `.stall`, `.codicil`, `.codicil_short`, `.tollgate_take`, `.tollgate_pass`, `.bell`, `.house_loser` — 8 keys, ~29 lines of prose. Their static getters exist in `executor_host.gd` but nothing calls them; they're orphans of the ring-board layout replaced by the graph board (doc 28's "Great Rework"). **A whole legacy narration system that no longer narrates anything.**
- `procession.narration.pin`, `.ribbon`, `.grave_salt` — orphans of the same rework; `board_spaces.gd` comments the matching item IDs "RETIRED with the priced cart (kept so old saves parse)."
- `intro.maskedball.name` / `.goal` / `.tips` — orphaned when Masked Ball was redesigned into THE CORONER (doc 32); a stale code comment still cites this key by name, but nothing calls it.

## DORMANT (called only from code the shipped board can't reach)

- `executor.vendetta`, `executor.vendetta_result`, `procession.narration.vendetta_alone`, `procession.narration.vendetta_wash` — all live inside `_resolve_vendetta()`, gated on a `Spaces.VENDETTA` board tile that the shipped `estate_procession` board declares zero of. The code's own comment: *"Dormant, not dead."*
- `procession.epitaph_graffiti` (+ the `EPITAPHS` pool + `_hang_epitaph`/`_render_epitaph`) — reachable only through a vendetta win, so it inherits the same dormancy. Even if revived, it isn't a simultaneous-screen duplicate (it writes to a log read much later) — the redundancy risk would be against whatever UI eventually surfaces `EstateState.graffiti`, not against anything in this file.

---

## Bonus structural findings

- **Glyph mismatch, widespread**: the real penny glyph is ¢ (`Spaces.PENNY_GLYPH`). A literal ♠ is hardcoded instead in: `executor.offering` (v2), `executor.grave` (v1), `executor.grave_toll` (v1, v4), `executor.ferry` (v1), `procession.narration.ferry_pass`, `procession.interim.metric_bled`, and one `.gd`-side append at `procession.gd:4113` (`executor.vendetta_result`'s appended stakes text). None of these ever render next to an actual ♠ on screen.
- **Two independent goal-text systems, shown back-to-back**: the exhibition/practice flow shows `howto.goals.<id>` (via `howto_cards.gd`) then, once the game loads, `intro.<id>.goal` (via `core/ui_kit/intro_card.gd`) — two separately-written paraphrases of the same one or two facts, in a row, from subsystems that don't know about each other. Concrete word-for-word overlaps: `pallbearers` ("the BLEND of both … sticks," both places) and `throne` (the estate "heav[ing]" the throne, both places). Doesn't fire simultaneously so it isn't a per-line KILL, but it's worth the producer's call on whether one namespace should defer to the other.
- **`howto.goals.maskedball` describes the wrong, superseded game.** It still reads "…curtsy for points or unmask a human… wrong guess: you flash" — the old Hidden-in-Plain-Sight ruleset. The game that actually launches (`masked_ball.tscn`) is now THE CORONER (icon errands, one accuser, red wax) per the file's own top comment. This is a content bug, not a redundancy — flagging since it surfaced during this pass.
- **`howto.goals.orbital` states the wrong planet count**: "Dodgeball on a tiny planet" (singular). Both `intro.orbital.goal` and the code's own top comment agree it's three planets.
- **The finale inverts the usual pattern**: `procession.finale.totals_header` reuses the exact `standings.line` template flagged KILL above, but because no `_refresh_hud()` runs after the finale's liquidation-bonus math, the chip is briefly *stale* there — making this instance the one accurate place the true total appears, i.e. KEEP, not KILL. Same template, opposite verdict, four ceremonies apart — a reminder that "does a widget with this data exist" isn't enough; order-of-operations has to be checked every time.
- **Wreath-gain popups are inconsistent**: `will_reading` and `awards.pay_line` route wreath grants through a chyron flying-number; `reckoning` (minigame settlement) grants wreaths in the same function but never pops them. Worth an FX-consistency flag independent of the prose trim.
- **Hardcoded (non-JSON) narration bypassing Dialog** spotted in passing: the objective label's `"☠ THE BELL HAS RUNG — LAST TURN"` / `"LYCHGATE → MANOR GATE"`, the chip's whole purse/rank/route format strings, the round-label format, `estate.gd`'s Family Album panel header (the one hardcoded exception among otherwise-Dialog-routed panel headers), and `_resolve_box`'s appended ware-name suffix. None of these are prose (mostly UI format strings), so out of scope for cutting, but flagged per the brief's ask.
