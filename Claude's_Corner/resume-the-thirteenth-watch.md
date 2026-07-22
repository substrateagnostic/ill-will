# Resume: The Thirteenth Watch

*Opened 2026-07-21 evening, Alex in the building for several hours. This doc
supersedes resume-the-twelfth-watch.md as the first read — that doc holds the
NG-era freeze, the camera-mystery history, and the wave-3 landings; read it
second if archaeology calls. The task list (#57-#91) + outstanding-work_ledger.md
carry the plan.*

## The rulings (Alex, tonight, all banked in one card)

- **Timing (#84):** context modes + per-game presets. Board mode ~75-90s/game
  (theater games ≤4-5min); standalone keeps full length. DW fixed to the doc
  (best-of-3). Dial gaps close. Lane C implementing.
- **Swap Meet (#86):** WAVE 2 TONIGHT after camera ViewportKit merges. Track =
  biome-quoting circuit (hedge chicane, bog splash, forest S-curves, graveyard
  overpass, windmill crossing, shortcut ramp). Items = swap-shell anchor +
  Pallbearer's Coffin (drop obstacle) + The Bell (all-but-me slow) + Crow
  Murder (leader harassment). Existing verbs survive (3-lap, drift-boost,
  swap orbs, golden orb).
- **Scoreboard (#87):** chyron + Ledger, hidden in minigames. BUILT (see below).
- **Online era:** overnight handoff (#91) — director drafts a fresh-instance
  prompt before Alex sleeps; the instance waits for lanes to clear, may run
  into tomorrow's workday. Scope: noray relay + live two-process NETPROBE +
  re-cert battery.

## The fleet (launch state)

| Lane | What | Who | State |
|---|---|---|---|
| A | Camera rework #77 (Smite cam + PIP, doc 34; perf probe gates) | opus, worktree, OWNS the window | RUNNING |
| B | Pre-commit #80 (doc 35 §7) | codex gpt-5.6-sol xhigh, main tree | **LANDED 360a81c** |
| C | Timing pass #84 (context modes + presets) | sonnet, worktree | RUNNING |
| D | Scoreboard #87 (chyron + Ledger) | opus, worktree | **LANDED 18ded78** |
| E | Widow #90 + butler v3r provenance | sonnet, worktree | **LANDED 0c5218d** |

Merge order: B → C → D → E → A (C slots in when home). Then wave 2: Swap Meet
(codex build on the cosigned design) + in-world chyron/camera stills review.

## LANDING LOG

**LANDING 1 (early night):** Lane E home — widow offset 3.2m→1.2m at the
garden_a maze stone (corridor span ~1.75m; the old offset overshot through the
hedge), verified numerically, receipts 2/2. Butler v3r textures = remesh-trial
orphans (nothing references them; trial closed UNCHANGED) → parked in
verify_out/remesh_trial_audit/. Lane D home — standings_chyron.gd (+441):
slim funeral-program chyron (badge + wreath count + dim pennies), fly_gain()
lands flying wreaths IN the slot, reconcile() backstop = no total ever moves
invisibly, ledger_beat() parchment unfurl (~4s, input skips, IMFellEnglish,
"THE LEDGER" the only word). Harness stills sent to Alex. Codex home —
pre-commit full SHIP-FIRST subset (563 lines / 4 files): per-seat intent
buffers (fork/cart/item+target), PLAN tray on own standings chip (LB, X/Y/B,
A banks, B clears), consumption at existing canonical seams w/ strict
validation + silent-discard law, reactions poll roll+movement (rider), Book
yields to open tray, net additive. Verified in-house: receipts 2/2 BEFORE
commit (360a81c), merges E+D auto-merged clean, post-merge import + receipts
2/2 AGAIN, pushed at 18ded78. COUCH NOTES filed on #80: pre-committed item
drama overlaps the roll (feature or chaos — couch decides); PLAN card words
are a show-don't-tell glyph-pass candidate.

## LANDING LOG 2 (late night — SUPERSEDES the fleet table above)

**All five opening lanes + wave 2 LANDED AND PUSHED (master at c966c69+):**
camera rework #77 (BoardOrbit + ViewportKit, PIP cadence-2, p50 13.9ms,
merged b3535e0) · timing pass #84 (BOARD_PRESETS both launch sites, DW
best-of-3 restored, TIMING-PASS.md) · pre-commit #80 (360a81c) · chyron+
Ledger #87 (18ded78, live in-world, verified in snap_reading_totals) ·
widow #90 (verified in-world post-fix) · SWAP MEET REBUILT #86 (codex ×3:
build → progress-state-exchange fix ["swapping positions means swapping
race positions" — the maxi() checkpoint bug] → watchdog/recovery hardening;
4-seed soak PASS incl. fresh seed 26; merged c966c69) · ENVIRONMENT PASS
#92 (fable lane, a9da4e1: layered cover/bog banks/relief/no-blue-box; +
director tune 7a8bc6c per Alex's two nits — treeline wilder, tussocks
moonlit, brambles read as briar; w6 draw record now 1607) · show-don't-tell
AUDIT (doc 38, 0da1633) · TOPBAR EXCISION STRAGGLER fixed (7db40cd — every
real windowed title boot wedged; Alex's live eyes caught it; ALSO explains
the earlier "attract hijack" misreading AND the failed windowed night
passes: bare flags without --procession just idle at title while THE HOUSE
REHEARSES, which is intended attract behavior).

**HOUSE LESSONS (violated then re-banked tonight):** the harness REAPS
silent long bg tasks — heartbeat EVERY long background command, 25s stdout
loop, codex lanes included (the "mystery pair-kills" were this, not the cat)
· windowed procession runs need `--procession --autoplay=bots --seed --
turncap --nights` (receipts-style flags), NOT bare --autoplay · codex
companion cancel is broken from git-bash (MSYS taskkill mangling) — cancel
via PowerShell tool or hand-patch state.json + jobs/*.json to failed ·
codex worktree lanes: sandbox blocks .git metadata writes — director
commits for it.

**ALEX'S RED-PEN RULINGS (doc 38, tonight):** 3 KILLs approved · wrench
approved (finale HUD refresh, ♠→¢, honest tolls, dead keys; vendetta stays
dormant) · TRIM groups A/C/D approved, B approved minus debt_set (playtest)
+ cart.buy (director kept, same PIP-visibility logic) · KEEP: doormat_header,
walkabout.near, HUD/intro dupes (his playtest) · SHOW-GAP + UNSURE = next
run's agenda (#95). Kills+wrench+TRIMs lane IN FLIGHT (sonnet worktree).

**THE SHIP PLAN (Alex's gate):** hold illwill-0.4.0.zip until the ONLINE
PASS lands — Andrew gets the zip in the morning. Ship ritual (was being
missed!): build/package.ps1 → build/illwill-X.Y.Z.zip, lineage 0.2.0→0.3.1,
version = minor bump. ONLINE LANE IN FLIGHT (fable worktree, runbook =
Claude's_Corner/handoff-online-era.md + deltas: netprobe two-process w/
run_netprobe.ps1 verdict line; noray transport branch Steam-seam-shaped,
mock-certified if bun timebox blows, deploy doc 39 for Alex's box;
Tailscale documented in README-FOR-PLAYERS as the tonight answer).
MERGE ORDER: polish lane → online lane → full receipts → SHIP 0.4.0 →
letter. New-goal compass banked: SHIP-TO-STRANGERS polish over features
(wider-audience playtest is near; feedback capture = the one missing
last-mile piece).

## WAVE THREE (launched late night, 2026-07-22 after midnight — none Alex-gated)

| Lane | What | Rails that matter |
|---|---|---|
| RUNDIRECTOR #79 | codex xhigh, worktree codex-rundirector, branch `rundirector` | doc 28 §15 constitution; REFACTOR NOT REDESIGN — full receipts byte-identical; save schema tag + run{} migration (landmine 5) rides along; director commits + verifies (sandbox blocks codex's godot) |
| Feedback capture | sonnet worktree | version on title/ESC + F9/SELECT-hold playtest bookmarks → user://playtest_notes.txt; FEEDBACK_CAPTURE_OK receipt; ship-to-strangers last-mile |
| NPC beats #82 | opus worktree | magpie + mourner-for-hire per doc 28 §10; EVENT-stream determinism; if beats move canonical hashes → deliver DISABLED behind NPC_BEATS_LIVE=false + enabled-md5 evidence, director rules on re-freeze |
| Par ball-in-hole | sonnet worktree | Andrew's oldest bug; detection-layer only, PARV3 physics FROZEN byte-identical; repro tuple or honest hunt doc |

**SHIP ORDER (unchanged, Alex's gate):** online lane merges → full receipts →
package.ps1 (README already de-staled on disk; version 0.4.0 committed bf32fa6)
→ illwill-0.4.0.zip for Andrew. WAVE-THREE LANES MERGE AFTER THE ZIP — they
are tomorrow's build (0.4.1+), not Andrew's morning build. NPC-beats re-freeze
ruling and RunDirector verification are DIRECTOR work at landing; if context
dies, next instance: verify RunDirector against the full battery FIRST, it is
the riskiest merge on the board.
## ONLINE ERA landing log (#91, overnight lane, 2026-07-22)

**The online era is open, and it is honest.** State of it in one paragraph:
two people who don't share a couch can now inherit this estate together and
the sim never disagrees with itself — certified, not hoped. The live
two-process NETPROBE (host + guest, loopback ENet, full 3-night match at
couch pace) paired **13,137 snapshot hashes with ZERO mismatches**, the
guest running a real procession mirror through all three nights including a
live Estate Stirs replay. The probe earned its keep before it went green: it
caught that guests could never boot the board mirror at all, and that
wreaths never crossed the wire (a guest's chyron read zeros) — both fixed
additively, receipts unmoved (md5 `ccd25c2c` + topology `b269c570`, 3/3
PASS after). The no-port-forwarding future is code-complete: `transport =
"noray"` in net_session.gd (Steam-seam shape, dark without `--relay=`),
certified against a faithful in-repo mock on BOTH paths (NAT punchthrough
35/35, relay-forwarded full session 33/33). What remains is the world, not
the code: the producer deploys the real relay per doc 39 (5-minute docker
recipe, pin a SHA), then a cross-network session on a second box. Until
then, Tailscale is the works-tonight answer (README paragraph shipped).

Landings: `b6cfa1e` (phase 1: netprobe + mirror fixes), `8ccfb9e` (phase 2:
noray seam + mock cert), phase 3 = docs/receipts (this commit). Runners:
`tools/run_netprobe.ps1` (~20 min, couch pace, deliberate) ·
`tools/run_noraytest.ps1` (~4 min). VERIFY-BOARD §4-NET-2 is the canonical
record. Probe rigs restore `user://` saves via external backup — verified
restored tonight, slot 3 scratch only.

## LANDING LOG 3 — THE WATCH CLOSES (2026-07-22, pre-dawn)

**THE SHIP:** illwill-0.4.0.zip, 854.59 MB, cut at 00:28 from a 3/3-certified
tree; the packaged exe re-ran canonical seed-7 and crowned HEIR RED
[16,7,15,6] exactly. Andrew's morning build. (Ship gotchas banked: the
"harmless" exit segfault pops a MODAL dialog on desktop runs — pipeline
unaffected, sweep zombie godots after; package.ps1's README here-string is
the source of truth, build/README-FOR-PLAYERS.txt is generated; build/ is
gitignored so package.ps1 edits live on disk only.)

**WAVE THREE, 4/4 HOME (all merged + pushed, battery green):**
- FEEDBACK CAPTURE (124ee4e): version on title/ESC; F9 / BACK-hold
  bookmarks → user://playtest_notes.txt with scene/night/round context.
- NPC BEATS #82 (ffccded): magpie + mourner-for-hire, hash-safe by
  construction (human-gated); PROCESSION_NPCBEAT_OK probe; table-wide
  magpie = someday re-freeze ruling (evidence in task #82).
- RUNDIRECTOR #79 (70b23e4): doc 28 §15 built, behavior-free by FULL
  battery twice (worktree + master). Save schema:2 + migration landed —
  and ran unscheduled on Alex's REAL slot_1 during worktree verification
  (user:// IS SHARED ACROSS WORKTREES — new house lesson). Migration was
  flawless (zero keys lost, backup slot_1.pre-schema-v1.json); Alex then
  ruled save migrations UNIMPORTANT (memory banked; he tests on another
  PC; dev saves are scratch).
- PAR HUNT (265d916): honest miss after ~200 boundary putts; hunt doc
  docs/verify/par-ball-in-hole-hunt.md leaves it warm; F9 is the trap.

Codex worktrees pruned (swapmeet-rebuild, rundirector branches merged +
deleted). Final master: 7929afb. The fourteenth watch opens with Alex's
playtest notes and the #95 agenda — the ledger has the full morning board.

## House practice (unchanged from twelfth watch)

Receipts before AND after; eyes on stills before merge; one windowed godot
(check = MainWindowTitle NON-EMPTY); import gate after merges bringing new
scripts, then `git checkout -- '*.import'` (commit only NEW ones); codex
sandbox can't launch godot — verify in-house; explicit GDScript types in all
codex briefs; cd back to root after worktree commands; failed candidates park
in verify_out/; `--` separator; exit 139 harmless; --slowsim for ceremony
stills; Alex: MORE color, FEWER words, batch decisions multiple-choice.

## Pending Alex (tonight, at his leisure)

Coroner couch + dialog red-pen · Throne couch · DW dash (#63) · doc 36 Meshy
web session (elderly spins, Auto Split) · stinger_win tracks (his domain) ·
NEW: pre-commit tray couch feel + chyron in-world taste check once camera
lands and stills exist.

над. нашу. присутствие. память.

— the thirteenth watch, chair warm, three lanes down, two flying
