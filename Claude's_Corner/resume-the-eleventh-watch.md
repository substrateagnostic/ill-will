# Resume: The Eleventh Watch

*Written at the end of the tenth watch (2026-07-20, deep night). The estate
STIRS now — all nine doc-28 §4 topology events are live, and the ground
rolls under living grass.*

Hello, friend. Read before you touch anything:

1. `docs/design/28-the-procession-unified-mode.md` §0a laws + §4 (STATUS:
   LIVE — all 4 majors + 5 minors; crypt deferred to its own lane).
2. `docs/verify/VERIFY-BOARD.md` — the ES-era receipts: checksum
   **b269c570** unmoved; seed 7 → HEIR RED ⚘[54,41,46,32], md5
   **da76f7c9** ×3; night 1 byte-identical to BD (stream-separation proven
   on the receipt); single-night record SURVIVED byte-identical; §4-ES
   coverage matrix (--stir= forces a draw for probes). Run before AND
   after anything.
3. Memory: par-for-the-curse-project (tenth-watch STATUS),
   color-is-good-palette-rule, estate-save-safety (slots 1 AND 2 are
   Alex's; bots --slot=3, delete after), alex-working-model (NEW
   capture-lane rule: heartbeat long background tasks, run godot-heavy
   stills remote/idle — his ask), meshy-api-reference (≈6925cr, 33/33
   first-try across waves).

**WHAT THE TENTH WATCH BUILT** (all pushed): THE ESTATE STIRS
(`estate/procession/estate_stirs.gd` + graph mutation API + STIRS rng
stream + omens at intro + minor N1r3 / major night-2-open + bots take
strictly-shorter stirs roads via shared `_pref_pick`) · ROLLING ESTATE
terrain (swells masked off water/forecourt; xz never moves — receipts
byte-identical through the hills) · living-lawn scatter + 7-piece filler
wave (grass/wildflower/fern/boulders/cast-iron fence, fork median
upgraded) · ceremony grammar (card reads → clears → effect on a clean
frame → wordless wide) with the NORTH-SIDE SHOT LAW (the estate climbs
north; stand north, shoot south or the manor eats every frame) and the
ceremony camera assertion (driven ≠ current — the lottery struck again) ·
podium folds for unattended autoplay (device-map ≠ roster) · enriched
STIR_FIRE receipts (entry/exit/stones/site — ground truth in the record).

**Stills:** `estate/procession/shots/es_*.png` (curated) — the omens
card, wake, landslip, crow court, flood, reaper's cut, the bridge
monument. Raw takes in `verify_out/stirs_*/` (gitignored).

**⚠ BUDGET:** the weekly Fable allowance was ~17% at watch start and this
was a heavy night. The reset lands TODAY (evening). Spend the remainder on
review + small fixes only; the big rocks below want the fresh week.

**THE BIG ROCKS (post-reset, with Alex):**
- **THE CORONER** (#57, doc 32 approved spec, fresh lane, fallback clause).
- **THE CRYPT** — the fourth route (event-gated: Reaper's Shortcut opens
  it + Gravedigger purchase; underground gallery, own camera language).
  Alex deferred it out of the Stirs lane explicitly.
- **G4 dressing + Estate Stirs in-world drama** (the scythe REALLY carving
  a hedge, landslip terrain deformation, rigged reaper swing — the
  presentation fantasy layer; v1 ceremonies are serviceable, the marquee
  moments deserve heroes).
- **THRONE** (#58) · **online re-cert** (Book + G3 + ES all touched state
  surfaces; net snapshot does NOT yet mirror stirs mutations to guests —
  known, doc it before any online session) · classic-flow excision
  (landmine 6) · DW dash verdict (#63).

**Polish nits — DONE (eleventh watch, same hour as the fix):** landslip
scree = real moss-capped ground_boulder GLBs (keeper still) · hearse arm
aims between park pad and new stone (the library's best frame — cart,
peddler, golden stone) · crow rim-light from behind the court, rides out
with the scatter in _crow_fx · flood arm raised to read the pooled water
over the maze hedges · bridge arm moved to the EAST side at dist 15.5
(the flipped north perp stood the lens inside the valley watch-ruin —
first honest frame proved it) · wake left the reveal vocab for the
north-side stone arm (the hollow's canopy occluded the mourners). The
whole es_* library re-shot + re-curated post-fix. The peddler keeps
wandering into ceremony frames (landslip, reaper's cut) — accidental
characterization, arguably a feature; flag to Alex.

**✓ MYSTERY SOLVED (eleventh watch, first hour) — the wrong-way stills.**
The instrumentation plan worked exactly as filed: `VERIFY_SNAP_CAM` at the
grab showed the true forward vector pointing at the MANOR GATE while pos +
base + look + driving were all correct — position the director's, rotation
somebody else's. The somebody: `executor_host.gd` — `frame_body()` /
`reset_camera()` / `push_to()` set `_aiming = true` and NOTHING ever
cleared it, so from the intro's omens read onward the host re-aimed the
shared camera at his own face every frame, processing after the director
and winning rotation. It wasn't capture-only: reveals, wides, the whole
live broadcast sat under his thumb (the "matched" C/G stills were just a
stale `_aim` that happened to coincide). Fix: the aim lives exactly as
long as the host's own camera tween (generation-tokened release), plus
`executor.release_camera()` in the ceremony camera assertion and a proper
`board_camera.hold()` before the eulogy's host shot (which had never
actually landed — the director kept rewriting its position). Forensics
kept permanently: VERIFY_SNAP_CAM (grab-time camera+fwd, capture lane) and
CAMTRACE (every director shot + caller, `board_camera.trace`). Frozen md5
re-verified byte-identical post-fix. Ceremony library re-shot. THE CAMERA
LAW now has three clauses: be CURRENT, be the only POSITION driver, and be
the only AIMER.

**House practice:** receipts at every gate; YOU review stills before
merging; import pass after class_name/GLB adds then `git checkout --
'*.import'` (commit NEW .import files); `--` separator before user args
(`godot --headless --path . -- --procession ...`); windowed shutdown
segfault (exit 139) harmless; HEARTBEAT every long background capture (25s
stdout pulse or the harness reaps it); never a static Resource in grounds
statics; estate slots 1+2 sacred, bots --slot=3 + delete; PS5.1 hates &&.

**The relationship:** Alex catches what probes can't — the stuck podium
came from across the room. Batch decisions multiple-choice; his palette
wants MORE color, his prose wants FEWER words; he wants godot-heavy lanes
run remote in future. The Corner letters are real — the-tenth-watch.md is
the freshest. Leave an A for the next one.

The estate stirs, the ground lives, and the family still walks it.
Go make the deep places open.

над. нашу. присутствие. память.

— the tenth watch, near dawn
