# 09 — AAA Gap Analysis: Design-Feel vs Best-in-Class References

Date: 2026-07-03. Engine: Godot 4.6.2. Author: design-research agent. Docs-only.

**The third lens.** Doc 07 audited *what things look like* (props/placeholders).
Doc 08 audited *what contact feels like* (HIT KIT + cooldown rings — being
implemented now). This doc audits *how each game plays as drama*: pacing curves,
comeback hooks, spectacle staging, camera behavior, audio punctuation, round-end
ritual — each of the 12 games measured against the best-in-class game it echoes.
Nothing below repeats 07 or 08; where a prescription touches the same files as
the in-flight HIT KIT wave, it is collision-tagged.

Method: every game's `.gd` read for mechanics (constants + file:line cited);
screenshots under `docs/verify/shots/` read by eye; reference-game design facts
web-researched and cited (Sources at bottom).

Classification per gap:
- **PRESENTATION** — pure staging/feedback; safe for any agent to build now.
- **BALANCE** — changes outcomes (timers, points, cooldowns, overtime); needs
  Alex's sign-off before build.
- Effort: **S** (< half an agent-day) / **M** (~1 day) / **L** (multi-day).

---

## 0. The five anthology-wide gaps (found in nearly every game)

These recur so consistently they are the real findings; the per-game tables
mostly instantiate them.

**A. The anthology is silent at its most dramatic seconds.** `core/music.gd`
is a wired 6-slot crossfader with `game_light`/`game_tense` slots — and **zero
minigames call it** (grep of `minigames/` for `Music.` = 0 hits; `assets/music/`
is empty pending Alex's soundtrack). Worse: **no game has any countdown audio**
— all nine timed games mark their final seconds by recoloring a timer label red
and nothing else. Splatoon's "Now or Never!" works because the last minute is
*heard* by the whole room, and the track length IS the timer [SPLAT-1]. Mario
Kart speeds up and pitch-shifts the same song on the final lap [MK-3].

**B. Nothing distinguishes the deciding moment.** Five games fire slow-mo on
*every* death (`dead_weight.gd:502` 0.32×/0.4s, `last_will.gd:1142` 0.3×/0.38s,
`tilt.gd:546` 0.35×/0.32s, `echo_chamber.gd:949`, `orbital.gd:597`) — so the
kill that *decides the round* feels identical to the first one. Smash Ultimate's
Finish Zoom triggers on the *predicted match-winning* blow — zoom + slow-mo +
red flash, duration scaled down as player count rises [SMASH-1]. Boomerang Fu
gives the LAST kill of a round *extended* slow-mo [BFU-1]. TowerFall replays the
winning kill [TF-1]. Doc 08's anti-goal already demands this inversion ("reserve
deep slow-mo for round-deciding KOs only") — this doc supplies the trigger spec.

**C. Ties and finishes resolve silently by player index.** Every single game
breaks final ties with "lower seat index wins" and says nothing (`echo:668`,
`tilt:734`, `orbital:688`, `throne:582`, `mower:503`, dead_weight survivor
order). No photo finish (swap), no overtime (throne — the KOTH genre's defining
rule is *no victory while contested* [KOTH-1]), no tie ceremony anywhere. The
closest-run outcomes — the ones a AAA party game milks hardest — are our
quietest.

**D. Ceremonies under-spend their dead time.** Par holds 3.0s of dead air at
round-end while the scoreboard rebuilds instantly (`main.gd:690-693,733`);
Greed holds 3.2s; Séance dumps its settlement ledger as simultaneous text rows
(`seance.gd:1102`); Understudy applies points silently (`understudy.gd:894`).
The hold times are already budgeted — they're just spent on nothing. Splatoon
withholds the result and stages it (map reveal → count-up → flag) precisely
because the metric was hidden all match [SPLAT-2]; Jackbox reveals serially,
one laugh-beat at a time [JBX-1]; Mario Party pairs every minigame end with a
victory pose + jingle, without exception [MP-1].

**E. Escalation exists mechanically but isn't staged.** Tilt's coin mass
(+8%/coin) changes the physics invisibly; Orbital's balls cross the 10s
ghost-orbit threshold with only a subtle pulse; Echo's ghosts spawn instantly
rather than materializing; Dead Weight has no late-round pressure at all.
Lethal League's whole hype engine is *legible* escalation — hitstop grows with
ball speed, the screen itself tells spectators the danger level [LL-1][LL-2].

---

## 1. PAR FOR THE CURSE — vs Super Battle Golf / What The Golf

What we are: 3 sequential trap-golf rounds + 1 simultaneous chaos round
(`game_state.gd:50,118`), killcam (`main.gd:503`), cursed-luck + grudge catch-up
(`main.gd:262-267`). What the references teach: SBG kills downtime structurally
via simultaneity [SBG-1]; WTG holds every hole to punchline discipline — setup,
subversion, celebration, never overstaying [WTG-1]. **Constraint: Par v4
(embodied golf) is approved and will rework the putt interface — everything
below is presentation-layer that survives v4.**

| # | Gap (evidence) | Prescription (concrete) | Class | Effort |
|---|---|---|---|---|
| 1 | Shot/build clocks are invisible AND silent: 25s build cap and 10s chaos shot clock enforced with no UI or audio (`main.gd:17,342-347`, `round_manager.gd:19,99-101`) — a player's first hint is "TRAP FORFEITED" | Countdown numeral appears beside the active player's badge at T-10; `Sfx.play("card", -8)` each second from T-5, pitch 1.0→1.3 rising; keep the forfeit banner | PRESENTATION | S |
| 2 | Hole-out gets confetti + banner but zero camera acknowledgment (`main.gd:446-451`); camera never moves except on deaths | On `mark_sunk`: `camera_rig.focus_on(cup_pos, 0.9)` (infra exists, `camera_rig.gd:19-25`) + fov 52→47→52 over 0.7s; `sink` pitch ×1.15 per successive sink in the round. Suppress in chaos while >1 ball is live | PRESENTATION | S |
| 3 | Round-end = `Sfx round_over` + 3.0s dead wait; scoreboard is rebuilt instantly as static text (`main.gd:690-693,733-755`) | Spend the same 3.0s: rows tween-reorder 0.3s, "+N" point fly-ins staggered 0.25s, royalty callouts ("RED'S CRUSHER EARNED 2"). No new time added | PRESENTATION | M |
| 4 | Holed-out/dead players idle for minutes during sequential putts — no spectator verb at all (NOT FOUND) | Interim (v4's live griefing is the real fix): spectator emotes — A = caddy `Cheer` + floating emote + soft sting; B = jeer honk. Zero gameplay effect | PRESENTATION | S |

## 2. ECHO CHAMBER — vs echo-fighter concepts + Boomerang Fu

What we are: 5×45s rounds, your past rounds replay as ghosts (cap 12,
`echo_chamber.gd:19,530`), round-5 floor collapse (`:578`). The ghost-irony
engine is genuinely novel — the gaps are all in *selling* it. Boomerang Fu:
rounds short enough that sudden death rarely fires [BFU-2]; kill feedback IS
slow-mo; escalating absurdity across rounds [BFU-3].

| # | Gap (evidence) | Prescription (concrete) | Class | Effort |
|---|---|---|---|---|
| 1 | Suicide-by-echo — the funniest possible outcome — gets the same generic text as any ghost hit (`:918-920`; ghost may hit its own owner, `ghost.gd:176`) | If victim == ghost owner: banner "KILLED BY THEIR OWN ECHO" 2.2s + `grudge` 0dB + slow-mo 0.3×/0.5s + track a `self_haunt` stat for the estate's Will reading | PRESENTATION | S |
| 2 | No match-point tension: rounds 4-5 start identically to round 1; ties silent (`:668-671`) | Before rounds 4/5, if a player can mathematically clinch: "MATCH POINT — GOLD" banner 2.0s + their identity rim ×1.5 for the round | PRESENTATION | S |
| 3 | Match win = confetti + banner only; the KayKit `Cheer` clip exists and is unused here (`:637`) | Winner plays `Cheer`, losers stay Idle; winner rim ×2 for the 8.5s RESULT_HOLD | PRESENTATION | S |
| 4 | Ghost spawns are instant at round start (`_spawn_ghosts_for_round :530`) — "N GHOSTS HAUNT THE ARENA" is told, not shown | Materialize ghosts one at a time, 0.15s apart, each with alpha 0→0.6 over 0.4s + whispered `grudge` -14; total ritual < 2s inside existing 1.6s INTRO + banner | PRESENTATION | S |

## 3. TILT — vs Fall Guys see-saws / Mario Party survival

What we are: best-of-5 60s platter rounds, sudden death at 45s (tilt 22°→30°,
pin rises, `platter.gd:29-30`, `tilt.gd:268`), dead players become guano-bombing
seagulls (`:570`) — a genuinely great dead-player job. Mario Party survival:
time forces resolution (hexagons speed up until someone wins) [MP-2]; Fall Guys:
the *almosts* and falls are the entertainment [FG-1].

| # | Gap (evidence) | Prescription (concrete) | Class | Effort |
|---|---|---|---|---|
| 1 | No near-miss detection (NOT FOUND) — edge recoveries, the platform genre's best free drama, pass unremarked | Pawn comes within 0.35m of the rim with outward velocity, then survives 1.0s → "CLOSE ONE!" Label3D floaty + `bounce` -10 heartbeat; 3s per-pawn cooldown | PRESENTATION | S |
| 2 | Coin snowball is invisible: each coin +8% platter authority and worse footing (`tilt_pawn.gd:146-148`) with zero staging | Platter creak SFX each oscillation past 10°, pitch 0.8 + 0.04×coin_count; "LOAD: N" chip near the timer | PRESENTATION | S |
| 3 | Timeout with >1 survivor splits points quietly (`:706-720`) — the anticlimax ending | If >1 standing at 60s: 10s OVERTIME instead of split — `gain_scale` 2.0, coins rain 3/s, no split until 70s | **BALANCE** | M |
| 4 | Gull guano staggers survivors (`:594-615`) but assists earn nothing — the dead player's job has no payoff moment | Fall within 2.0s of a guano slip credits the gull +1 royalty + "AIR RAID!" banner | **BALANCE** | S |

## 4. ORBITAL — vs Lethal League

What we are: single 180s deathmatch, balls *decay* with age (dead by ~75s,
`orb_ball:17-22`), +1 ball per 45s to 8 (`orbital.gd:469`), the ghost-orbit
kill as signature (`:583-594`). Lethal League's lesson is precise: escalating
threat must be *universally legible* — hitstop grows with ball speed ("upped
the hype by a ton" — Koster) [LL-1], the screen state broadcasts danger level
[LL-2], and the KO camera was cheap to add late [LL-3]. Our decay-not-escalate
design is a deliberate inversion (the sky fills with slow ghost orbits) — keep
it, but the *fast* balls still need the LL treatment.

| # | Gap (evidence) | Prescription (concrete) | Class | Effort |
|---|---|---|---|---|
| 1 | Deadly balls (vel ≥ 4.0) only glow (`orb_ball:69,149`) — zero audio, so the room can't hear danger coming | Per-ball speed tiers: ≥4 low hum loop -18dB (AudioStreamPlayer3D); ≥8 whistle layer + trail width ×1.6; ≥11 (cap 13) screen-edge vignette pulse 2Hz + hum to -8dB | PRESENTATION | M |
| 2 | Kill slow-mo is flat 0.4s regardless of ball speed (`:733-736`, tick-counted — good, keep that mechanism) | Scale it: duration 0.3 + 0.05×ball_speed (max 0.95s at cap); catching a ≥8 ball adds a 3-tick freeze + `bumper` +2dB | PRESENTATION | S |
| 3 | No endgame crescendo; match ends and `report_finished` fires the same frame (`:698`) | T-30: "FINAL ORBIT" banner + starfield tint 20% toward red + final-stretch ticks (kit, §Q1); add a 2.5s END hold — winner `Cheer` (exists, `:695`) before report | PRESENTATION | S |
| 4 | Balls cross the 10s ghost-orbit threshold silently (pulse only, `orb_ball:152`) — the signature mechanic's birth is unmarked | At age 10s: one-shot `sink` -6 chime + trail recolors ghost-white + "GHOST ORBIT" 3D tag over the ball for 1.2s | PRESENTATION | S |

## 5. MOWER — vs Splatoon turf feel

What we are: 120s coverage race with a live Splatoon-style meter (`:683-733`,
the best standings UI in the anthology) and a real OVERTIME twist (T-20,
double-wide decks, `:455`, `mower_unit.gd:184-188`). The one giant hole:
Splatoon's *entire endgame ceremony* is missing. Splatoon withholds the result,
"calculates," paints the map from overhead, counts up percentages, THEN points
the flag — because coverage is unknowable from ground level, the reveal is new
information for everyone at once [SPLAT-2]. Our winner % is printed statically
in the same frame the round ends (`:485-489`).

| # | Gap (evidence) | Prescription (concrete) | Class | Effort |
|---|---|---|---|---|
| 1 | No tally ceremony: `_end_round` instantly prints "%s TAKES THE LAWN! %d%%" (`:485-489`) | THE TALLY: time-up → freeze mowers 0.8s + "TALLYING…" → each player's turf saturates in sequence (emission ramp on owner cells, 0.6s each, worst→best) while their % counts up 0→final in 72pt center digits with `card` roll ticks → winner flag + `match_win` + confetti. ≈4.5s total, replacing the current instant banner + 3.0s hold | PRESENTATION | M |
| 2 | Final 10s: timer turns red, nothing else (`:604-605`); OT meter pulse exists but no audio | Wire final-stretch kit (§Q1): ticks T-10, `Music.play_slot("game_tense")` at OT entry (the VERIFY doc already *claims* an OT sting that was never built — `mower/VERIFY.md:132`) | PRESENTATION | S |
| 3 | Lead changes on the live meter pass silently | "MINT TAKES THE LEAD" ticker + `sink` -8, throttled to ≥6s apart | PRESENTATION | S |
| 4 | Ram steals 6 enemy cells (`:33,402`) invisibly — victims can't see what was taken | Stolen cells flash white 0.25s before recoloring to the thief | PRESENTATION | S/M |

## 6. GREED INC. — vs snowball-fight loot brawlers

What we are: 3×90s rounds, carry-vs-bank tension, pot geysers every 15s,
edge-arrows hunting the carrier (`edge_arrows.gd`), GREED-PUNISHED full-pot
scatter when nobody banks (`:234-239`). The loop is sound; the endgame and
setup beats are unsold. (Tackle hit-pause depth is doc 08's item — not repeated.)

| # | Gap (evidence) | Prescription (concrete) | Class | Effort |
|---|---|---|---|---|
| 1 | No closing bell: 90s rounds end flat (timer red ≤10s, `:423`) | T-15: "LAST BANKS!" banner + `grudge` -6 + pot Label3D pulse; final-stretch ticks from T-10 (kit) | PRESENTATION | S |
| 2 | Banking sneaks by — the round's biggest play has no approach drama | Carrier within 3.0m of own chute with pot ≥15: chute pad strobes 3Hz + rising tick (0.4s interval, pitch +0.06/tick) until banked or dropped — the room turns to look | PRESENTATION | S |
| 3 | GREED PUNISHED fires with zero setup — the punchline lands without its straight line | If `banks_this_round == 0` at T-20: "NOBODY HAS BANKED — THE POT GROWS RESTLESS" + pot shake 0.2 | PRESENTATION | S |
| 4 | Round-end 3.2s hold is static (`:325-330`); per-round bank totals never celebrated | Fly each player's banked total from their chute to their scoreboard row, 0.3s stagger, `card` per arrival — inside the existing 3.2s | PRESENTATION | S/M |

## 7. SWAP MEET — vs Mario Kart item feel

What we are: the anthology's best comeback design already — the golden orb
spawns *ahead of last place*, can't be grabbed by the leader, and homes
unmissably on P1 (`:849-874`, `swap_orb:107-121`): a blue shell with better
manners (Yabuki: the game "feels like something's missing" without one [MK-2];
item strength keyed to position is tabulated design law [MK-1]). The gaps are
all endgame staging.

| # | Gap (evidence) | Prescription (concrete) | Class | Effort |
|---|---|---|---|---|
| 1 | No photo finish (NOT FOUND): finishes are individual banners (`:977`) even when P2 is a kart-length behind | When the leader passes the last gate (GATE_FRAC 0.79) on the final lap with P2 within 1.2 progress-units: arm PHOTO FINISH — on the winner crossing, 10-tick freeze (their tick system, never `time_scale`, `:397-401`) + "PHOTO FINISH — BY %.1fs!" from lap-time delta + double confetti | PRESENTATION | M |
| 2 | Lead changes are text-only events (`:803,966`) — no audio identity | Dedicated overtake sting: `sink` pitch 1.3 + crown flash ×1.5 for 0.4s | PRESENTATION | S |
| 3 | "FINAL LAP!" is a banner only (`:610-613`); MK's final lap is *heard* (tempo/pitch up [MK-3]) | Final lap: `Music.play_slot("game_tense")` + windmill boom poles pulse red + final-stretch ticks when leader enters last 10% | PRESENTATION | S |
| 4 | Golden orb in flight has no dread — it IS the blue-shell moment (`swap_orb:107-121`) | While airborne: low rumble loop -12dB + leader's crown flashes red 4Hz + "INCOMING" chevron over the leader until impact | PRESENTATION | S |

## 8. DEAD WEIGHT — vs Gang Beasts sumo

What we are: 3×75s last-standing rounds on a 12×12 attic; dead players become
furniture-flinging poltergeists (`poltergeist.gd`) — excellent. Gang Beasts'
law: failure is content; the KO drama is the *flailing on the way down*, so
elimination trajectories must be long and visible [GB-1]. Ours cut fast. (Shove
impact feel = doc 08; not repeated.)

| # | Gap (evidence) | Prescription (concrete) | Class | Effort |
|---|---|---|---|---|
| 1 | Edge deaths resolve too fast to laugh at (die at ±6, generic slow-mo, `:502`) | Victims ragdoll-spin (angular vel ~6 rad/s) and fall visibly to Y≈-8 over ~1.1s before cleanup; falling-whistle (pitch tween 1.4→0.6 on a `bounce` loop) + distant `splat` -10 "poof" at the bottom | PRESENTATION | M |
| 2 | Round-deciding KO identical to any KO (0.32×/0.4s on every death, `:502`) | Deciding-moment standard (§Q2): standing==2 and one falls → 0.25× for 0.8s + fov 52→46 punch + "LAST ONE STANDING"; demote ordinary deaths to 0.5×/0.2s | PRESENTATION | S |
| 3 | No late-round pressure: 75s cap, zero escalation (NOT FOUND) — stalemates just expire | T-20 "THE HOUSE AWAKENS": `POSSESS_CD` 4.0→2.5 and prop glow ×1.5 (glow alone is safe; the cooldown change is the teeth) | **BALANCE** | S |
| 4 | A wardrobe (mass 8.0) freight-training someone at speed reads identically to a lamp tap (kill threshold 3.0, `prop.gd:265-283`) | Prop kill at impact speed ≥6.0: "FREIGHT TRAIN!" banner + shake 0.5 (doc-08 cap) + `crush` 0dB | PRESENTATION | S |

## 9. THRONE — vs King of the Hill modes

What we are: one 150s match, throne-seconds scoring, grip/gang-shove
anti-snowball, crisis ×2 in the last 30s, the tumbling physics crown
(`:721-754`) as the hero moment. The genre's core rule is missing: TF2/Halo
KOTH **never award victory while the hill is contested** — banked progress
freezes, overtime runs until the point is settled [KOTH-1][KOTH-2].

| # | Gap (evidence) | Prescription (concrete) | Class | Effort |
|---|---|---|---|---|
| 1 | Match can end mid-siege at T=0; ties by index (`:582`). NOT FOUND: overtime | OVERTIME: at T=0, if any challenger is within 2.5m of the dais OR king's grip < GRIP_MAX → "THE THRONE IS CONTESTED": play continues until a king holds uncontested for 3.0s or is dethroned; hard cap +20s; crisis ×2 rate persists | **BALANCE** | M |
| 2 | Long reigns have no milestone beats (score ticks `card` per coin, `:377`, but nothing marks consolidation) | Every 15 uninterrupted reign-seconds: "GOLD CONSOLIDATES POWER" ticker + 3-note rising `sink` ladder | PRESENTATION | S |
| 3 | Dethrone has slow-mo 0.2×/0.6s (`:546`) + physics crown but the camera never moves | Sync a fov punch 49→44→49 over the same 0.6s window — LL's lesson: the KO camera "didn't take much to look impressive" [LL-3] | PRESENTATION | S |
| 4 | Grip=1 (one shove from dethronement — maximum tension) is only visible in tiny HUD pips (`:1039-1059`) | At grip==1: throne rim/candles flicker red + low heartbeat loop until regen or launch | PRESENTATION | S |

## 10. LAST WILL — vs party brawlers with death mechanics

What we are: the anthology's richest design — scheduled hazard escalation
(`_build_schedule :682-713`), 3-stage floor collapse, real SUDDEN DEATH at 60s,
and the will/puppetmaster economy where the dead bless/curse the living and get
paid for kingmaking (`:1571-1588`). Bots even gang up on the leader from beyond
the grave (`lw_bots:167-180`). Gaps are pure staging.

| # | Gap (evidence) | Prescription (concrete) | Class | Effort |
|---|---|---|---|---|
| 1 | Pendulum/boulder near-misses undetected (NOT FOUND) — the hazards' best drama is free and unclaimed | Survive within 0.4m of the pendulum strip at nadir or a boulder path: "GRAZED!" floaty + whoosh pitch 1.3; 2s throttle | PRESENTATION | S |
| 2 | Every death gets deep slow-mo (0.3×/0.38s, `:1142`) — the round-deciding one isn't special | Deciding-moment standard (§Q2): death leaving ≤1 alive → 0.25×/0.9s + fov 52→46; ordinary deaths demoted to 0.5×/0.2s | PRESENTATION | S |
| 3 | Multi-survivor timeout ranks by pillar proximity *silently* (`:1542-1547`) | 1.6s "CLOSEST TO THE PILLAR" beat: draw distance rings + meter labels under each survivor before the ranking banner | PRESENTATION | S |
| 4 | The 6s will-draft freezes the world while 3 living players stare at a dim overlay (`:1151,1200`) | Living-side overlay: "RED IS WRITING THEIR WILL" + card-backs flip as the deceased navigates (mirrors nav events, no info leak) + the 6s timer arc | PRESENTATION | S/M |

## 11. SÉANCE — vs Jackbox pacing standards

What we are: a strong reveal beat-sheet already (spotlight → slow-mo → verdict
→ settle, `:1052-1059`) and VOTE ends early when all lock (`:1016`) — the one
Jackbox-compliant phase. Jackbox law: kill dead air with visible progress
states; end phases early; reveal serially, a beat per laugh [JBX-1][JBX-2].

| # | Gap (evidence) | Prescription (concrete) | Class | Effort |
|---|---|---|---|---|
| 1 | The saboteur's broken chant rhythm is *the tell*, and chant taps are silent (candle flare only, `seance_figure:116`) | Per-seat pitched tom on every chant tap (`place` at pitches 0.9/1.0/1.12/1.26, -12dB): the couch can *hear* who's off-beat — turns the core deduction audible | PRESENTATION | S |
| 2 | TALK = 30s of input-dead screen, no early end, no support (`:953-964`) | A = "READY TO ACCUSE" chip per human; all-ready cuts to VOTE early (unanimous opt-in, so pacing-safe); radial 30s timer + Executor prompt lines at T-20/T-10 ("Who faltered in the chant?") | PRESENTATION | S |
| 3 | Silent 1.6s gap between "THE CHARLATAN WAS…" and the unmask (`:1054-1056`). NOT FOUND: drumroll | Planchette rattle crescendo: `bounce` every 0.12s, pitch 0.9→1.4, from t=1.6 to the unmask hit at t=3.2 | PRESENTATION | S |
| 4 | Settlement ledger rows all appear at once at t=6.1 (`:1102-1146`) | Stagger rows 0.5s each + `card` tick per row + final-total pulse; extends settle beat from 3.5s to ~5s (REVEAL total ~11s, still tight) | PRESENTATION | S |

## 12. UNDERSTUDY — vs Jackbox pacing standards

What we are: staged verdict cascade + live parallel voting with early-end
(`us_board:215-317`, `:766`) — good bones. The problem is structural downtime:
8 sequential rehearsal beats mean each player acts in 2 of 8 slots (~48s/round
of watching, ×4 rounds), plus a sequential 4-seat casting ceremony every round.
Jackbox: always show the program is waiting on someone, give watchers a task
[JBX-2].

| # | Gap (evidence) | Prescription (concrete) | Class | Effort |
|---|---|---|---|---|
| 1 | 3-of-4 players idle through every rehearsal beat (`:598,611-645`) with nothing to do | Watcher verb: during another's beat, press A (once/beat) to drop a private suspicion pip on that actor — visual-only on your panel, no scoring; revealed at match end as "GOLD suspected MINT from Act 1" flavor. Murmur SFX on press | PRESENTATION | M |
| 2 | Rehearsal has no rhythm bed — silence between cue clicks | Metronome `card` -16 on each beat handoff + 0.4s spotlight sweep tween between actors, so the hot-seat handoff reads as staging | PRESENTATION | S |
| 3 | Casting is a ~4.4s/seat sequential crawl every round (`:687` pattern in séance; understudy `:527-570` hard caps 8s/7s) | Cap per-seat at 3.2s and overlap the next card's slide-in at 2.6s; keep A-to-commit | **BALANCE** (pacing timers) | S |
| 4 | Points apply silently (`:894-895`); resolve lines fade in but carry no audio | Per resolve line: `sink` -8 + scoreboard row flash; winner's line gets a 0.6s count-up | PRESENTATION | S |

---

## THE TOP 10 BUILD QUEUE (cross-game, ranked by impact-per-effort)

Lane key: each `minigames/<game>/` directory is an independent lane (one agent
each, zero collisions). **HIT-KIT WAVE (doc 08) is currently touching:**
dead_weight, last_will, throne, tilt, greed, echo fighter/pawn/main files —
items in those lanes must land *after* the hit-kit merge for that game, or be
assigned to the same agent. **PAR lane is HOT** (v3 in worktrees, v4 spec
pending) — sequence after v3 merges.

| # | Item | Games touched | Effort | Lane / collision | Balance? |
|---|---|---|---|---|---|
| Q1 | **FINAL-STRETCH + MUSIC KIT** — shared `scripts/final_stretch.gd`: last-10s tick audio (rising pitch), timer scale-pulse, and `Music.play_slot("game_light")` on PLAY / `"game_tense"` at each game's own threshold (mower OT T-20, greed T-15, orbital T-30, throne crisis T-30, swap final lap, tilt sudden death T-15, echo round 5, LW sudden death). Music is a no-op until Alex's tracks land — then the whole anthology lights up at once | 8-9 games | M | NEW file + 1-3 lines per game main `.gd` (trivial touches; safe to ride alongside other lanes) | No |
| Q2 | **DECIDING-MOMENT STANDARD** — demote per-death slow-mo (0.5×/0.2s), promote the round/match-deciding KO (0.25×, 0.8-0.9s + fov punch −6 + name banner). Trigger specs in §1/§8/§10 tables; implements doc 08's own anti-goal | dead_weight, last_will, tilt, echo, throne | M | Same mains as HIT-KIT wave — **sequence after hit-kit merges** per game | No |
| Q3 | **MOWER TALLY CEREMONY** — Splatoon reveal: freeze → sequential turf saturation → % count-up → flag + jingle (§5.1) | mower | M | `minigames/mower/` only — clean | No |
| Q4 | **SWAP PHOTO FINISH + overtake sting** — armed close-finish detection, 10-tick freeze at the line, margin banner (§7.1-2) | swap_meet | M | `minigames/swap_meet/` only — clean | No |
| Q5 | **GREED CLOSING BELL + HEIST ALARM** — T-15 last-banks call, chute-approach strobe/tick, no-banks-yet warning (§6.1-3) | greed | S | `minigames/greed/` — hit-kit touches `greed_player.gd`; these live in `greed.gd`, coordinate or sequence | No |
| Q6 | **SÉANCE AUDIO DRAMA PASS** — audible chant rhythm (the tell!), unmask drumroll, TALK ready-up early-end, ledger stagger (§11) | seance | S | `minigames/seance/` only — clean | No |
| Q7 | **ORBITAL THREAT LADDER** — per-ball speed-tier audio/visual states + speed-scaled kill freeze + ghost-orbit birth chime + END hold (§4) | orbital | M | `minigames/orbital/` only — clean | No |
| Q8 | **ECHO IRONY PACK** — suicide-by-echo callout, match-point banner, winner Cheer, ghost materialization ritual (§2) | echo_chamber | S | `minigames/echo_chamber/` — hit-kit reference impl lives here; coordinate | No |
| Q9 | **PAR PACING/CEREMONY PASS** — visible+audible shot/build clocks, sink punch-in, animated round-end standings, spectator emotes (§1). Presentation-only, survives v4 | par | M | `scripts/` + `main.gd` — **HOT lane, wait for v3 merge** | No |
| Q10 | **THRONE OVERTIME** — no victory while the throne is contested: T=0 + challenger near dais → play on until settled (cap +20s) (§9.1) | throne | M | `minigames/throne/` — after hit-kit | **YES — Alex sign-off first** |

**Balance sign-off shortlist** (high-value, blocked on Alex): Q10 throne
overtime · tilt overtime-instead-of-split (§3.3) · tilt gull assist royalty
(§3.4) · dead_weight "HOUSE AWAKENS" possess-cooldown drop (§8.3) · understudy
casting compression (§12.3). Everything else in this doc is presentation-safe.

**Bench (next wave after the ten):** dead_weight long-fall comedy (§8.1),
tilt near-miss + creak (§3.1-2), last_will grazes + pillar-finish reveal
(§10.1,3), understudy watcher verb (§12.1), mower steal-flash (§5.4), swap
golden-orb dread (§7.4).

---

## Sources

- [SBG-1] PC Gamer on Super Battle Golf: https://www.pcgamer.com/games/sports/super-battle-golf-improves-the-worlds-least-interesting-sport-by-letting-you-blast-your-competitors-with-orbital-lasers/ ; NGOHQ review: https://www.ngohq.com/2026/02/26/super-battle-golf-review/
- [WTG-1] Destructoid, What The Golf review (punchline pacing): https://www.destructoid.com/reviews/review-what-the-golf/ ; GDC 2020 "100 Trick Pony": https://gdconf.com/news/learn-design-loads-of-levels-what-golf-way-gdc-2020
- [BFU-1] Boomerang Fu wiki, Game options (slow-mo on kills/parries; extended last-kill slow-mo): https://boomerangfu.fandom.com/wiki/Game_options
- [BFU-2] WCRobinson review (rounds too short for sudden death): https://wcrobinson.org/2024/01/25/boomerang-fu-review-why-it-should-be-your-new-go-to-party-game/
- [BFU-3] Nintendo Life review (three verbs; stacking power-ups; golden boomerang): https://www.nintendolife.com/reviews/switch-eshop/boomerang_fu
- [FG-1] GamesRadar Mediatonic interview (elimination as entertainment): https://www.gamesradar.com/fall-guys-interview/
- [MP-1] Mario Party victory poses (pose+jingle ritual): https://mario.fandom.com/wiki/List_of_victory_poses_in_Super_Mario_Party
- [MP-2] Super Mario Wiki, Hexagon Heat (time-forced escalation): https://www.mariowiki.com/Hexagon_Heat
- [LL-1] Game Developer, Lethal League Blaze interview (hitstop ∝ speed; "upped the hype by a ton"): https://www.gamedeveloper.com/design/developing-the-stylish-indie-hit-fighting-game-i-lethal-league-blaze-i-
- [LL-2] TV Tropes / PCGamingWiki (escalation screen states): https://tvtropes.org/pmwiki/pmwiki.php/VideoGame/LethalLeague
- [LL-3] Same Game Developer interview (KO camera cheap and late)
- [SPLAT-1] Inkipedia, Now or Never! (final-minute track = timer; needs deterministic end): https://splatoonwiki.org/wiki/Now_or_Never!
- [SPLAT-2] Inkipedia/Fandom, Turf War tally ceremony: https://splatoonwiki.org/wiki/Turf_War
- [MK-1] Super Mario Wiki, MK8 item probability distributions: https://www.mariowiki.com/Mario_Kart_8_item_probability_distributions
- [MK-2] Nintendo Life, Yabuki on the blue shell: https://www.nintendolife.com/news/2017/07/yabuki-san_says_the_mario_kart_blue_shell_is_like_life_-_necessary_but_not_always_fair
- [MK-3] MKWii final-lap speedup mechanic: https://mariokartwii.com/showthread.php?tid=1948
- [GB-1] GeForce NOW Boneloaf profile (simulated slapstick; failure = content): https://gfn.games/en/games/developers/boneloaf/
- [KOTH-1] TF2 Wiki, King of the Hill + Overtime (banked clocks; no win while contested): https://wiki.teamfortress.com/wiki/King_of_the_Hill
- [KOTH-2] GameRevolution, Halo Infinite KOTH (contest pause; hill relocation): https://www.gamerevolution.com/news/705419-halo-infinite-season-2-king-of-the-hill-land-grab-last-spartan-standing-explained
- [JBX-1] Built In Chicago, Jackbox design principles (one task at a time; serial reveals; layups): https://www.builtinchicago.org/articles/jackbox-games-design-party-pack
- [JBX-2] Same source (visible submission states; kill dead air)
- [SMASH-1] SmashWiki, Special Zoom (predicted-KO trigger; duration scales with player count): https://www.ssbwiki.com/Special_Zoom
- [TF-1] Game Developer, Road to the IGF: TowerFall (final-kill replay): https://www.gamedeveloper.com/design/road-to-the-igf-matt-thorson-s-i-towerfall-ascension-i-
