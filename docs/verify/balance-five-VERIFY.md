# THE FIVE — signed-off balance changes — verification record

Date: 2026-07-07. Godot 4.6.2 (Windows), worktree branch. The five parked
BALANCE items from `docs/design/09-aaa-gap-analysis.md` ("Balance sign-off
shortlist": throne overtime §9.1, tilt overtime-instead-of-split §3.3, tilt
gull assist §3.4, dead_weight HOUSE AWAKENS §8.3, understudy casting
compression §12.3) — all five signed off by Alex — are implemented, one
commit per game.

Method: each game's existing balance/tally harness ran BEFORE (clean HEAD)
and AFTER (this branch), 3 seeds each; where behavior intentionally changes,
the new baseline is documented below with justification. A full 4-bot match
was driven to `finished()` for every touched game. Worktree import cache
seeded from the main project, then `godot --headless --editor --import
--quit --path .` (clean).

---

## 1. THRONE — OVERTIME WHILE CONTESTED (doc 09 §9.1)

**Change** (`minigames/throne/throne.gd`): at 0:00, if the crown is contested
— throne vacant / mid-coronation scramble, king's grip below full (mid-siege),
or any challenger within `CONTEST_RADIUS = 2.5` m of the dais — the match does
not end. Banner **"THE COURT WILL NOT ADJOURN"**; play continues until a king
holds a clean `OT_SETTLE = 3.0` s uncontested reign (seated, no challenger in
striking range). Hard cap `OVERTIME_CAP = 30` s, then the current leader wins.
Crisis double-pay persists through overtime (remaining time stays ≤ 30 s, so
the existing `CRISIS_TIME` test keeps paying ×2 — intentional: overtime
seconds are the most valuable of the match, per the KOTH genre rule the doc
cites [KOTH-1]). Timer shows `OT n` counting down the cap, hot red, and the
persistent crisis line becomes "THE COURT WILL NOT ADJOURN — THRONE PAYS
DOUBLE" for the whole of overtime — the flash banner loses its slot whenever
a dethrone lands on the horn (observed in filming: with four bots the horn
instant is usually a kill instant, and the kill deserves the banner).

### Harness: `--thronebalance`, seeds 1-3 (100 s match, FX on, realtime)

| seed | BEFORE max share | AFTER max share | overtime |
|---|---|---|---|
| 1 | 31.4% PASS (GOLD; deth 9/6/11/10) | **25.9% PASS** (shares 25.0/24.3/25.9/24.9) | entered (grip=1/3 at horn), **settled +12.0s** — RED held a clean 3.0s reign at t=112.0 |
| 2 | 32.1% PASS (RED 32.1/BLUE 7.7/GOLD 30.7/MINT 29.5) | 31.7% PASS (31.7/18.6/27.5/22.2) | not entered (rerun — the first attempt's godot process died mid-match; FX-on realtime probes are not run-to-run frame-identical, per throne VERIFY.md) |
| 3 | 36.8% PASS | **36.8% PASS — identical** | not entered (horn found the king settled) — the control case: an uncontested finish reproduces the old outcome exactly |

All seeds stay far under the 55% fairness cap. New receipt line in the
balance block: `THRONE_OT seed=N entered=<bool> len=<s> end=settled|cap|none`.

### New-baseline justification
Bots contest the dais almost permanently (VERIFY.md: throne occupied ~79-80%
of the match), so all-bot lobbies enter overtime often and sometimes ride it
to the +30s cap (full-match receipt below). That is the designed worst case:
the cap bounds the match at 130s and the leader-wins rule keeps the result
identical to the old horn in that case — overtime can only *change* an
outcome when someone completes the dethrone the horn used to interrupt.
Human matches settle sooner (a clean 3s reign only requires challengers to
be outside 2.5m).

### Full 4-bot match to finished()
`--thronebots --seed=2 --fixed-fps 60` (headless): `THRONE_OVERTIME t=100.0
contested (challenger_near)` → `THRONE_OT_END t=130.0 cap: +30s elapsed,
current leader wins` → `THRONE_MATCH_OVER champ=RED pts=51 placements=[0, 2,
3, 1]` with 48 kill_events, 4 monuments — results contract intact through
overtime, `report_finished` reached.

### Windowed screenshots (read by eye; verify_out/ is gitignored)
- `balance5/` (seed 2, matchtime 30): play continuing past 0:00 — red `OT
  30`/`OT 29` timer, RED dethrones BLUE *during overtime*, crown physics,
  RED's score ticking up under crisis pay.
- `balance5b/` (seed 9): one frame carries the whole ruling — red `OT 28`,
  persistent line "THE COURT WILL NOT ADJOURN — THRONE PAYS DOUBLE", and the
  "RED DETHRONES GOLD" drama banner coexisting (the slot conflict that
  motivated moving the ruling onto the crisis line).

---

## 2. TILT — OVERTIME INSTEAD OF SPLIT (doc 09 §3.3)

**Change** (`minigames/tilt/tilt.gd`, `platter.gd`): a timeout with >1
survivor no longer splits the pot. Banner **"THE ESTATE SPLITS NOTHING /
OVERTIME"**; 20 s of overtime on a sudden-death platter whose tilt gain runs
at **1.5× on top of the sudden-death gain** (platter `overtime_scale`, net
2.40× vs base — receipt: `overtime start standing=N gain=2.40x window=20s`).
If sudden death somehow isn't live yet at the horn, overtime starts it. Only
if the sea *still* refuses a verdict at +20 s does the old split fire, now
labeled `overtime_split` ("THE SEA REFUSES A VERDICT").

**1.5× interpretation** (judgment call, documented): the task says "sudden-
death platter tilt at 1.5x tilt rate". Sudden death (gain 1.6×) is already in
force at any tie-horn, so overtime multiplies *that*: 1.6 × 1.5 = 2.40×
target-tilt gain. Doc 09 asked for gain 2.0 over 10s; the signed version is
20s at 2.4× — strictly meaner, in the same spirit (the platter itself breaks
the tie).

### Harness before AND after
- `--tilttest=idle` PASS, exit 0 (both) — spring-damper stability untouched.
- `--tilttest=edge` PASS, slid off at t=0.83 s (both) — slide model untouched.
- Shipping-length soaks (60 s × 5 rounds, seeds 7/9/13, `--fixed-fps 60`):
  **fall sequences frame-identical before/after** (e.g. seed 13 falls at
  frames 9838, 12914 in both); all 15 rounds per seed end `last_stand` in
  both. At shipping length ties are already rare — overtime is the safety
  net, not a new regime.

### New-baseline: the tie regime (30 s rounds — the config where splits lived)
`--tiltbots --roundtime=30 --rounds=3`, seeds 7/5/11, HEAD vs branch:

| | BEFORE (HEAD) | AFTER |
|---|---|---|
| round outcomes (9 rounds) | **7 × `timeout` (split the pot), 2 × last_stand** | **9 × last_stand — zero splits** |
| overtime entries | n/a | 8 (one round resolved at the horn naturally) |

Every horn-tie entered overtime and resolved to a true last winner within
0.1–9.6 s of OT:

```
seed 7:  OT@31.4 (4 standing) -> last_stand @37.8   | OT@105.4 (3) -> last_stand @111.9
seed 5:  OT@31.4 (3) -> @35.2 | OT@69.9 (3) -> @79.5 | OT@114.1 (2) -> @114.2
seed 11: OT@31.4 (3) -> @37.6 | OT@72.2 (4) -> @81.0 | OT@115.6 (3) -> @121.0
```

The anticlimax ending (doc 09 §3.3 "timeout splits points quietly") is gone;
the split is still reachable in principle after +20 s, paying exactly the old
shares.

## 3. TILT — GULL ASSIST ROYALTY (doc 09 §3.4)

**Change** (`minigames/tilt/tilt.gd`): a fall within `GULL_KO_WINDOW = 2.0` s
of a guano slip (standing in a splat, or a direct hit) is the seagull's KO.
The player who most recently shoved that victim within `GULL_ASSIST_WINDOW =
3.0` s collects **+1 royalty** ("softened X for Y's gull"), kill_events cause
`"gull_assist"`, killer = shover. Banner "AIR RAID! Y'S GULL SINKS X — Z
COLLECTS". Splats now carry their owning gull (`_slip_owner`); slips are
tracked per pawn (`_slip_gull` / `_slip_t`). A pure gull KO with no recent
shove stays `ring_out` killer -1, as before (only the assist case was signed
off; doc 09's original wording paid the gull — the signed wording pays the
shover; the gull keeps its `gull_hits` stat/highlight. Judgment call,
recorded).

### Determinism receipts
- Soak fall sequences frame-identical before/after (above) — attribution
  changed, the sim did not.
- **Organic case, seed 13** (60 s soak, both runs): the fall at frame 9838
  was `shover=-1` (uncredited) BEFORE; AFTER it is `cause=gull_assist,
  killer=RED, victim=MINT` + royalty `"softened MINT for RED's gull"` — RED
  shoved MINT at t=159.10 (2.7 s before the fall, outside the old 1.5 s
  royalty window), RED's own gull's guano hit MINT at t=161.75, MINT fell at
  t=161.82.
- **New self-test** `--tilttest=gull` (house "Risks & tests" pattern): pawn0
  at the rim, p1's shove lands via the real `apply_knock` path, gull p2's
  splat arrives the same tick, pawn0 goes over 0.1 s later →
  `TILTTEST gull RESULT: PASS (cause=gull_assist killer=1 victim=0
  royalty_p1=true t=0.62)`, exit 0.

### Banner note
When the gull-assist fall is also the round-ending fall (as in the seed-13
organic case), the round-win banner claims the slot immediately — exact
parity with the existing "X SHOVED Y OVERBOARD!" banner, which has always
yielded in that case. Mid-round assists show "AIR RAID!" for its full 2.0 s.

### Full 4-bot match to finished()
Seeds 7/9/13 shipping soaks run to `match_end` with the full results contract
(placements/points/currency/kill_events incl. one `gull_assist`), quitafter
past `report_finished`.

---

## 4. DEAD WEIGHT — THE HOUSE AWAKENS (doc 09 §8.3)

**Change** (`minigames/dead_weight/dead_weight.gd`, `poltergeist.gd`): in the
final 30 s of the 75 s round (`_house_awakens_at()`), ghost possess-cooldowns
drop by half — `POSSESS_CD 4.0 → 2.0` on every release, and any cooldown
already running is halved on the spot (`DWGhost.house_awakens()`). Banner
**"THE HOUSE AWAKENS"**; the room dims to candlelight (ambient 0.62→0.40, sun
1.25→0.85 over 1.4 s, four guttering candles with flicker) — all fx behind
`fx_on()`, so none of it exists in `--dwbalance`. Receipt lines:
`DW_HOUSE_AWAKENS round=N t=… cd_scale=0.5 ghosts=N` at the trigger and
`DW_GHOST_CD pN release cd=2.0s (house awake)` whenever the halved cooldown
is actually handed to a ghost.

**Balance-sim mapping** (judgment call, documented): `--dwbalance` rounds cap
at 22 s, where "final 30 s" is meaningless. The awakening triggers at the
same *fraction* of the cap instead — `maxf(cap−30, cap×0.6)`; 45/75 = 60%, so
live play gets exactly T-30 and the 22 s sim rounds awaken at 13.2 s,
measuring the same regime reproducibly. Balance receipt block prints
`HOUSE_AWAKENS at=13.2s of 22.0s cap (live: 45s of 75s) POSSESS_CD 4.0->2.0`.
`--dwawaken=S` (verify-only, ignored in balance mode) forces the moment early
so the candlelight can be filmed.

### Harness: `--dwbalance=20`, seeds 1/3/7

| seed | BEFORE living win % | AFTER living win % | awaken receipts in the sim |
|---|---|---|---|
| 1 | 65.0% (shove 5 / ghost 7 / void 8; poss 38, hits 70, avg 15.3s) | **65.0% — identical splits and telemetry** | 13 × `DW_HOUSE_AWAKENS`, 9 × `DW_GHOST_CD … cd=2.0s` |
| 3 | 60.0% (4/8/8) | **60.0% — identical** | 12 awakens, 8 halved-cd releases |
| 7 | 75.0% (4/5/11) | **75.0% — identical** | 15 awakens, 12 halved-cd releases |

All inside the 55-75% living-win target band, and the halved cooldown
demonstrably reaches ghost hands in the reproducible sim (`DW_GHOST_CD`
receipt) without moving the band. The 22 s sim rounds barely
overlap the awaken window (avg round ≈ 15 s), so the probe's job here is
proving the band holds and the sim stays deterministic — the live effect
lives in the 45-75 s window of real rounds, where a full possess-fling cycle
is ~6-10 s and halving the 4 s gap adds roughly one extra furniture assault
per surviving ghost.

### Full 4-bot match to finished()
`--dwbots --seed=5 --fixed-fps 60`: `DW_HOUSE_AWAKENS round=1 t=45.0s` and
`round=3 t=45.0s` (round 2 ended before 45 s — correct), match to
`DW_MATCH_OVER champ=RED pts=9`, kill_events contract intact.

---

## 5. UNDERSTUDY — CASTING COMPRESSION (doc 09 §12.3)

**Change** (`minigames/understudy/understudy.gd`): the eyes-closed casting
ceremony pays its teaching cost once. Roll-call (the eyes-open "learn your
colour's voice" pass, 2.0 s intro + 4 × 1.75 s) runs **only in Act 1**; from
Act 2 the per-seat silence between one seat's eyes-down and the next summons
tightens `CAST_GAP 2.0 s → CAST_GAP_LATER 1.2 s`. The voice-summons language
itself — three pitched ticks + the fourth as the card flips, seat pitches
0.90/1.00/1.12/1.26 — is untouched and plays every round. Receipts:
`US_CASTING act=N rollcall=yes|no seat_gap=…` / `US_CASTING_DONE act=N
wall=…s` (non-tally only).

### Harness: `--ustally`, seeds 1/2/3 — byte-identical
Totals unchanged (s1 RED=9 BLUE=9 GOLD=6 MINT=7 champ=RED; s2 champ=BLUE 9;
s3 champ=BLUE 9); `diff` of before/after tally logs: **byte-identical for all
three seeds** (the tally path never runs roll-call or gaps, and every new
print is gated `not _tally`). One after-run appended a stray engine
exit-warning (`ObjectDB instances leaked at exit`) — a rerun of the same seed
was byte-identical to the baseline, so that is Godot shutdown noise, not game
output.

### Wall-clock receipts (windowed, realtime, seed 1, `--usrounds=2`;
bot read-beats are seeded, so both runs share the same think times)

| span (US_ROUND → first cue) | BEFORE | AFTER | delta |
|---|---|---|---|
| Act 1 (roll-call kept) | 32.4 s | 31.8 s | −0.6 s (3 gaps × 0.2) |
| Act 2 | 29.0 s | **16.8 s** | **−12.1 s** (roll-call 9.0 + 3 gaps × 1.0 ≈ 12.0 predicted) |

Across the shipping 4-round night: ≈ **37 s of dead ceremony removed** (3 ×
12.1 + 0.6), all of it silence and re-teaching, none of it play. AFTER
casting-phase walls: Act 1 24.8 s → Act 2 13.3 s.

### Full 4-bot match to finished()
`--usbots --seed=1 --fixed-fps 60` (headless, 4 rounds): `US_CASTING act=1
rollcall=yes seat_gap=2.0s`, acts 2-4 `rollcall=no seat_gap=1.2s`,
`US_MATCH_OVER champ=RED pts=9` + full `US_RESULTS` via `report_finished`.

---

## Cross-cutting notes

- **Import pass**: worktree `.godot/imported` seeded from the main project
  (same asset content), then `godot --headless --editor --import --quit`
  exits 0.
- **One incident**: the first BEFORE-receipt batch had to be re-captured —
  a stopped background script survived its kill on Windows and re-ran the
  harnesses after the branch code was restored, overwriting three games'
  baseline logs. Authentic baselines were re-generated by swapping the HEAD
  versions of the five touched scripts back in, re-running the harnesses,
  and byte-verifying the branch files were restored (`RESTORED_OK` per file).
  Throne baselines were unaffected (verified free of any `THRONE_OT` marker).
- Frozen constants untouched: putt physics, TRAPS_PER_BUILD, tilt shove/clash
  numbers, throne grip/decree numbers, DW prop drive/knock numbers.
