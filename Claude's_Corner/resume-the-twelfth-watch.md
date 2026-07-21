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

---

## STATE AT OVERNIGHT HANDOFF (2026-07-21 ~03:45, Alex signed off — o7)
### THIS SECTION SUPERSEDES the stale lanes/pending tables above.

**AUTHORITY: both chairs are the director's for the overnight wave-3 run**
(Alex, verbatim). Merge on green receipts + director stills review; hold only
taste-radical calls for morning. Docs carry the run — update THIS section
after every landing.

**Landed + pushed since this doc was written** (master at b2417e0):
grass shader fill MERGED (1c5e7a8) · rigging batch committed (c2b1d5e, 12
ship-ready assets) · spike-trap nerf merged (ae0b99c) · docs 34+35 written,
RATIFIED with Alex's answers + director amendment (815396d, 5cd8a21 — frame
TIME is the PIP gate, pre-commit rulings 1d/2a/3a/4c/5a/6a + never-required
law) · doc 36 web-regen shopping list (e583f24) · remesh trial CLOSED
UNCHANGED, 13cr — DOCTRINE: arms-down clips only for coat/robe bodies, else
static+puppet (b2417e0) · scale-track forensics: one real defect stripped
fleet-wide (MeshyProp._strip_deviant_scale_tracks) · night-games spec FULLY
RULED (theater trio exclusive both ways; interlude 1 random+Executor
announce, interlude 2 DOORMAT picks; re-freeze sanctioned; goes LAST).

**THRONE: BUILT + approved, committed on branch 3f8d5fe**
(worktree-agent-a5a8edd148b03174e) — mid-round moving hill, buck-off, real
physics-server crash fixed, 26-34% shares, receipts 2/2. MERGE HOLDS until
Coroner commits (dialog.json contention), then merge FIRST.

**In flight at handoff:** CORONER (codex task-mru33jca-orqrp5, phase
editing, healthy — "75-second waltz" design, file changes applying steadily;
check via codex-companion status FROM REPO ROOT — the state dir is
cwd-keyed) · BOG WATER (agent in worktree agent-a442d6268a698ac28, resumed
with finish orders — windowed stills + water-legibility verdict pending).

**WAVE THREE (task #89, producer-queued, fires when both land):**
merge Throne → review+merge Coroner → review+merge bog → THEN parallel:
(A) stirs net-mirror #78, codex --model gpt-5.6-sol --effort xhigh,
exhaustive brief (literalism doctrine — exact filenames/commands);
(B) G4 reaper sweep/walk wiring #81, worktree, stills-gated;
(C) NPC wiring #74-tail — ferryman/hooded/widow rigged path swaps
(arms-down 243-family only), place Mourner-for-Hire + Magpie (doc 28 §10);
butler STAYS static+puppet; elderly awaits Alex's web spins (doc 36);
(D) Greed bots cure (#84); (E) timing audit, read-only, all 15 games →
table for Alex. CLOSER serialized after all merges: night-games slot #76 +
sanctioned re-freeze + new VERIFY-BOARD records.

**Morning review queue for Alex:** Coroner vs doc 32 spec + its dialog keys ·
Throne couch feel + dialog red-pen · bog water stills · wave-3 landings ·
doc 36 web session (elderly spins, Auto Split experiments) · DW dash couch ·
stinger_win tracks (his domain).

**House lessons refreshed this session:** cwd discipline (the director
himself parked a shell in a worktree and misread the world — cd back to
root after EVERY worktree command) · windowed check = MainWindowTitle
non-empty, never bare process existence · import gate after every
class_name MERGE, not just authored adds · codex-companion state is
cwd-keyed · subagents yield instead of waiting — resume them with explicit
FINISH-IN-TURN orders · failed asset candidates park in verify_out, never
commit.

**Context pressure order (Alex):** when it bites, take time in the GLOBAL
corner C:\Users\agall\projects\Claude's_Corner (the play space — leave a
letter), then continue to tomorrow. Compact freely — this section + TaskList
#57-#89 carry everything.

**LANDING LOG (overnight):** BOG WAVE MERGED (60881c0, receipts 2/2 on main
post-merge) — water reads as water, legibility settled (0.85 retired for
0.34), forest floor lived-in, w6 exactly 1513 budget-neutral. Follow-ups in
#85: bramble Meshy gen next forge wave; ripple domain-warp polish nit.
Remaining in flight: CORONER only. Then: Throne merge → Coroner merge →
WAVE THREE (#89).

**LANDING LOG 2 (deep night):** CORONER stalled at codex after +1086 lines
(hung 60+ min post-03:28) — finished + verified IN-HOUSE: soak seeds 1-3 +
2P clean, rotation unique=4, VERIFY section written, committed 412b737.
THRONE merged 5830d11 (dialog keys auto-merged). Receipts 2/2 over the
full stack. #57 #58 complete pending couch. **WAVE THREE LAUNCHED (all 5):**
A net-mirror (codex gpt-5.6-sol xhigh, main tree) · B G4 reaper wiring
(worktree, windowed) · C NPC wiring (worktree, windowed — B/C self-serialize
via title-aware monitor check) · D Greed bots (worktree, headless) ·
E timing audit (read-only). Closer queued: night-games #76 + re-freeze
after A-E merge. Coroner timing note for the audit: 4×75s ≈ 5min match.

**LANDING LOG 3:** TIMING AUDIT complete (wave 3E) — 6× spread, dial
coverage gaps, DW doc/code drift; 5 normalization options queued for Alex
(#84). NET-MIRROR implemented by codex (snapshot wire format, idempotent,
mid-join safe, --stirnettest self-probe) — sandbox blocked its godot runs
again; verification in-house (stirnettest + receipts running in bg).

**LANDING LOG 4 — THE ARC CLOSES (2026-07-21, before dawn):** Wave three
complete, 5/5 + closer: net-mirror (197f32b — 3 codex type-inference errors
fixed in-house; doctrine: demand explicit types in codex briefs), G4 reaper
hero pose (103f365 — held woodcut sweep; walk benched with reasons), NPC
wiring (03c56b8 — wake mourns with dignity, magpie on the signpost, Widow-
in-maze filed #90), Greed bots CURED (4c075bf — drought_t design, 12 seeds
zero zero-banks), timing audit filed (5 options await Alex, #84), and THE
NIGHT GAMES closer (0b69d37): theater trio exclusive to the overnight slot,
SANCTIONED RE-FREEZE → canonical md5 ccd25c2c, RED holds the crown by the
closest race ever (44/42/39/40), single-night RED [16,7,15,6], sweeps BLUE
[46,73,47,53] / MINT [28,53,51,74], LETTERS witness now BLUE. Receipts
green everywhere. THE MORNING BOARD FOR ALEX: couch verdicts (Coroner feel
+ dialog red-pen, Throne feel, DW dash), timing-pass ruling (#84 five
options), doc 36 web session (elderly spins + Auto Split), stinger_win
tracks, Widow-in-maze nudge (#90), doc 35's built future (pre-commit #80
ready to lane). Twelve watches of receipts say: the estate is in the best
shape of its life.
