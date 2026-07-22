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
