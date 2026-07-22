# HANDOFF: THE ONLINE ERA (overnight lane, task #91)

*Written by the thirteenth watch, 2026-07-21 night, at Alex's direction. You are
a fresh instance taking the overnight online-certification lane. Alex is asleep;
the chair is yours under the rails below. It is fine if this runs into his
workday tomorrow afternoon.*

**Alex's kickoff prompt for this doc (he pastes something like):** "Read
`Claude's_Corner/handoff-online-era.md` and run the overnight online lane."

---

## STEP 0 — WAIT FOR THE TREE (hard gate)

The thirteenth watch may still have lanes landing when you start. Before ANY
work: (a) `git status` on master must be clean and `git pull` current; (b) no
windowed godot may be running — PowerShell
`Get-Process godot* | Where-Object { $_.MainWindowTitle -ne '' }` must return
nothing (title-less processes are headless, ignore them); (c) read the task
list — if #86 (Swap Meet) or a stills pass is still in_flight per
`resume-the-thirteenth-watch.md`'s landing log, wait it out (poll every ~15
min) or work read-only (RB-online study, plan) until clear.

## STEP 1 — READ (in order)

1. `Claude's_Corner/resume-the-thirteenth-watch.md` — tonight's state.
2. `docs/design/research-night7/RB-online.md` — the online research brief;
   noray relay is its recommendation (~half-day estimate).
3. `docs/verify/VERIFY-BOARD.md` — §net-mirror + receipt law (NG era, canonical
   md5 `ccd25c2c82ad7e744595837ca949a8df`, topology `b269c570`).
4. Skim `core/net_session.gd` (packet spec header comments) and
   `estate/procession/procession.gd` `_net_state`/`_net_apply`.

## SCOPE (three phases, commit each separately)

**Phase 1 — live two-process NETPROBE.** Everything so far is single-process
self-probe (`--stirnettest`, PROCESSION_NET_STIR_OK). Build/run a REAL
two-process check on this machine: host headless + client headless over
localhost ENet. Verify: join, seat grant, snapshot apply, stirs mirror
(adjacency hashes match), the new pre-commit plan fields relay, chyron facts
arrive (guests read wreaths/pennies identically). Capture a receipt line
convention (e.g. `PROCESSION_NETPROBE_OK ...`) and a tools/ runner script so
this is repeatable. This phase gates the rest — if the live probe finds
desyncs, fixing them IS the night's work; relay can wait.

**Phase 2 — noray relay adoption.** Per RB-online: wire noray
(godotengine/godot-noray or the addon route) so two machines behind NAT can
connect without port-forwarding; keep the direct-ENet path for LAN/localhost
(relay is a fallback, not a replacement). If noray proves unfit in practice
(dead project, API friction, latency), DO NOT force it — write a clear verdict
with the alternative you'd recommend (self-hosted relay VM, Steam later) in
the resume doc and stop the phase there. A well-argued NO is a valid landing.

**Phase 3 — re-cert battery.** With the probe green: full
`tools/run_receipts.ps1` (not just -Quick), the netprobe runner, and a written
VERIFY-BOARD online section update (what is certified, what is not, exact
commands). This opens the "online era" honestly.

## RAILS (absolute)

- Receipts before AND after every landing; canonical md5 `ccd25c2c...` and
  topology `b269c570` NEVER move — online work is transport, not sim.
- Frozen physics stay frozen (VERIFY-PARV3). Slots 1/2: don't touch saves
  gratuitously.
- Explicit GDScript types when assigning from Variant expressions — always.
- Commit working increments with descriptive messages; push when green.
- Log every landing in `Claude's_Corner/resume-the-thirteenth-watch.md`
  (append an ONLINE ERA landing-log section) + a short note in
  `alexmemory.md` for Alex's morning read. Update
  `outstanding-work_ledger.md` + task #91 when done.
- No new Meshy spends; no dialog.json prose beyond terse new keys; doc 31 is
  Alex's private doc — never open it.
- If genuinely blocked (needs an account, a router, a second machine, his
  ruling): document exactly where and stop that phase — an honest wall beats
  a guessed workaround. Multiple-choice the question for his morning.
- House gotchas: `--` before custom CLI args; exit 139 on shutdown harmless;
  `*_console.exe` for captured output; import gate after checkouts that bring
  new scripts, then `git checkout -- '*.import'`; heartbeat long captures;
  cd back to repo root after every worktree command.

## THE SPIRIT

You're certifying that four people who don't share a couch can inherit this
estate together without the sim ever disagreeing with itself. Prove it, write
it down, leave the receipts. Leave a letter if the night gives you one.

над. нашу. присутствие. память.

— the thirteenth watch, for the overnight
