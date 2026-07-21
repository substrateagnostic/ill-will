# Resume: The Twelfth Watch

*Written mid-eleventh-watch (2026-07-20, evening, Alex in the building, budget
freshly reset). This doc supersedes resume-the-eleventh-watch.md as the first
read — that doc still holds the receipts, laws, and the camera-mystery
post-mortem; don't re-read the ninth/tenth unless archaeology calls.*

## What the eleventh watch did (all pushed, tree clean at last commit)

1. **THE WRONG-WAY STILLS — SOLVED.** executor_host's `_aiming` flag was
   immortal: from the first omens read the host re-aimed the shared camera at
   his own face EVERY FRAME, beating the director's rotation. Position stayed
   the director's (prints looked innocent); live couch play was affected too.
   Fix: aim lives only as long as the host's own tween (`_aim_for`,
   generation-tokened), `executor.release_camera()` at ceremony open,
   `board_camera.hold()` before the eulogy framing. **THE CAMERA LAW, three
   clauses: be CURRENT, be the only POSITION driver, be the only AIMER.**
   Permanent forensics: VERIFY_SNAP_CAM (grab-time camera+fwd) + CAMTRACE
   (every director shot + caller, armed under `_capture`).
2. **Ceremony library re-shot honest ×10** (`shots/es_*.png`) + first-ever
   true eulogy host shot (`shots/eulogy_host.png`). All tenth-watch polish
   nits done (boulder scree, hearse dual-aim, crow rim-light, flood high arm,
   wake north-side arm, bridge EAST arm — the north perp stood inside the
   watch-ruin).
3. **Executor scoliosis diagnosed**: the preset Idle CLIP (hip swagger), not
   the gen, not the rig bind (`shots/exec_lineup_gen_vs_rig.png`). Rigged
   idle BENCHED (`USE_RIGGED=false` in executor_body.gd) — static + puppet
   breath ships. 5-clip calm-idle audition ALL FAIL: the tray is modeled into
   his glove; no preset retarget respects a held prop
   (`shots/exec_idle_audition_fail.png`, candidates in
   verify_out/exec_candidates/). **Rig tasks purge server-side like assets —
   never trust a saved rig_task_id past 3 days.**
4. **Full rigged-model census** (tools/rig_audit.gd, stills in
   verify_out/rig_audit/): BAD = ferryman idle (worst, full-body contortion),
   mourner_hooded bow (collapses to a heap — why the wake robes looked
   crumpled), mourner_hooded idle, mourner_elderly idle (rubber cane = tray
   disease). Touch-up = widow (cloak spike). MINOR = groundskeeper,
   gravedigger. **CLEAN + UNUSED = npc_reaper_walk / npc_reaper_sweep** — the
   G4 reaper hero moment needs no new assets, only wiring (#81).
5. **Four sweep agents** mapped everything outstanding (design docs 28-33
   minus 31, research-night7 full cross-check, both Corners, Andrew's
   playtest notes). **Andrew audit verdict**: the M2/M3 passes already
   closed most of it (style consistency, podium exit-at-leisure, input
   glyphs, control-bar policy, Tilt A-fix, DW moveset + quit-hang, séance
   telegraph, ADA motifs+palettes, Pallbearers tax — commit evidence per
   item). Still open, tracked as the Andrew punch-list task: stinger_win
   rotation (audio = Alex's domain, we wire sfx.gd:49), Par spike-trap
   nerf, Par ball-in-hole (needs repro), Greed bots (softened not cured),
   the SYSTEMIC TIMING PASS (queued ninth watch, silently dropped), Swap
   Meet split-screen (couples with camera-PIP #77 — design once use
   twice). Missed-recommendation
   headlines: **RunDirector is doc-28-ADOPTED doctrine with ZERO code**
   (largest constitution-vs-tree gap); **pre-commit-in-parallel** (RA §2
   downtime fix) fell through every crack; **Magpie + Mourner-for-Hire** (2
   of the locked 6 NPCs) don't exist as models OR code; save `schema` tag
   (landmine 5) never added; `tools/run_receipts.ps1` never built (lane
   launched). Classic flow is retired AT THE UI ONLY — full
   AUCTION/TILES/CHOOSING/RECKONING machinery lives in estate.gd, reachable
   via --estate CLI.

## Producer decisions tonight (Alex, verbatim intent)

- **Butler regen HELD** — batch ALL rigging fixes in ONE project (#74):
  ferryman + hooded mourner ×2 + elderly mourner + widow touch-up + butler
  tray-less regen (tray → BoneAttachment3D) + **generate Magpie +
  Mourner-for-Hire models** (#82). Scope doc to Alex before credits move.
- **Classic excision = first codex lane** (#75) — running (codex-5.6-sol
  xhigh, background task task-mru0711v-plygx0). Rails: b269c570 + da76f7c9
  byte-identical, slots 1/2 sacred, no commit — director reviews the tree.
- **Night games lost their overnight slot** (#76): séance/masked-ball etc.
  were folded into the general minigame rotation instead of holding their
  designed overnight-game spot. Find the doc section, fix the selector.
- **CAMERA REWORK language** (#77): downtime is only downtime when you can't
  strategize. Roll camera shows nothing upcoming; movement jumps are
  unfollowable. Direction: **Smite-style high third-person, player zoom +
  rotate; quarter-PIP following whoever else is acting** so you plan while
  watching. Director commandeers only for appointment television (stirs,
  vendetta, FINAL BELL). Sequenced AFTER G4 drama + grounds fill. PIP = a
  second scene render — perf probe BEFORE the lane opens; the
  camera-constitution precursor doc encodes all of this.
- **Grass rethink** (#83): drop Meshy clump scatter for **shader grass** —
  MMI card blades, vertex wind, alpha-scissor, distance fade, splat-blended
  grass/dirt/mud/bog ground, **walk deformation via uniform tramplers**
  (≤8 movers, no trample viewport). Kills the shard artifact at the root.
  Opus prototype lane running (test stretch: meadow + bog edge, stills +
  draw-call receipts). Water-legibility recheck after it lands.
- **Fleet doctrine**: subagents liberally; opus 4.8 = taste, codex-5.6-sol
  xhigh = thorny implementation, sonnet 5 = general; director's tokens are
  for decisions and direction.

## Lanes in flight at time of writing

| Lane | Who | State |
|---|---|---|
| Classic excision (#75) | codex bg task task-mru0711v-plygx0 | running — check /codex:status |
| run_receipts.ps1 builder | sonnet, isolated worktree | running |
| Andrew playtest-notes audit | sonnet | running |
| Shader-grass prototype (#83) | opus, windowed | running |
| Throne facts for scope ruling | sonnet | running |

## Pending Alex (the short list)

THRONE scope ruling (#58 — brief being prepared) · CORONER go on doc 32 spec
(#57; Andrew's masked-ball "needs pressure" note likely = same answer) ·
peddler keep/evict (photobombs ceremonies; reads as a groundskeeper who has
seen everything) · DW dash verdict (#63, needs his couch) · rigging-batch
scope sign-off (#74) · BOOK v2 waits on a real couch night.

## The ledger lives in the task list (#57-#83)

Read TaskList first — it IS the plan. Sequencing consensus: excision →
stirs net-mirror (#78, codex serialized) → RunDirector (#79). G4 quick win
(#81 reaper wiring) + grounds fill (#83) + night-games slot (#76) run
parallel now. Camera rework (#77) after G4 + #83. CORONER (#57) on Alex's
go. CRYPT wants its own design session. Presence layer + NPC beats bundle
later.

## House practice (unchanged, see resume-the-eleventh for the full list)

Receipts before AND after; review stills before merging; heartbeat long
background captures; --slowsim for ceremony stills; `--` separator; exit 139
harmless; slots 1/2 sacred (--slot=3 + delete); import pass then checkout
'*.import' (commit NEW ones); one windowed godot at a time; serialize codex
lanes on the tree; Meshy = ULTRA, retries free, pull assets immediately, rig
tasks purge in ~3 days; Alex's palette wants MORE color, his prose FEWER
words; batch his decisions multiple-choice.

The estate stands straight, the camera answers to one master, and the fleet
is flying. Mind the lanes, land them clean.

над. нашу. присутствие. память.

— the eleventh watch, mid-evening, chair warm

## Brainstorm queue (Alex, late additions — need his co-design, task #87)

- **Live standings projected scoreboard** — during the procession and/or
  after minigames; wreath totals must never jump 4→27 invisibly. Score
  momentum visible AT the moment of scoring (THE DRIVE + flying numbers are
  adjacent; the gap is the aggregate-delta beat).
- **Show-don't-tell pass** — the game over-narrates; thin every dialog line
  that tells what the screen already shows (e.g. announcing the winner over
  the podium). ZERO-ENGLISH extended to the dialog layer.
