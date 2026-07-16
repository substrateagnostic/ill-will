# PALLBEARERS — verification

The anthology's first TEAM game. A 2v2 coffin race down a graveyard lane to the
crypt — everyone is late for the funeral. Contract module registered in
`estate.gd` as `pallbearers`. Root of `minigames/pallbearers/pallbearers.tscn`,
extends `Minigame`.

## The pieces

| File | Role |
|------|------|
| `pallbearers.gd` | Controller: the blended carry sim, divergence/drop clock, hazards, HUD, results, online mirror, CLI. |
| `pb_carrier.gd` | `PBCarrier` — a KayKit bearer, pinned to a coffin end (render-only). |
| `pb_coffin.gd` | `PBCoffin` — the coffin + THE DECEASED (a wrapped shroud); lid pop, sway, complaint bubble. Meshy swap seam `COFFIN_GLB`. |
| `pb_bots.gd` | `PBBots` — seeded cooperative carriers (fumble = beatable). |

## THE CARRY (the heart)

A pair carries one coffin. Its velocity is the **blend** of both carriers' sticks,
scaled by how much they **agree**:

- `speed_factor = 0.15 + sync*0.85`, where `sync = (dot(s0,s1)+1)/2`. Aligned
  sticks sprint at `MAX_SPEED 3.6`; opposed sticks crawl.
- A **divergence** meter climbs while the sticks disagree (`DIV_GAIN 0.9/s` at full
  opposition) or on slick mud (`MUD_SLIP 0.28/s`), and bleeds while the carry is
  smooth (`DIV_RECOVER 0.7/s`). At `1.0` the coffin **drops**.
- A hard hazard (gate, mourner-at-speed) drops instantly.

On a drop the lid pops and **the deceased spills out** (a pooled voice-bible
complaint); both bearers **mash** to restuff (`RESTUFF_NEED 14` combined mashes,
~1.4s). A fresh grip after a reseat is briefly drop-immune (`grace`) so a coffin
can escape the mud it fell in.

## THE TWIST — HOP (the jump button)

- **Solo hop**: a lopsided jostle — `+0.22` divergence + a lateral lurch. Can nudge
  you over a mud lip, but it is a risk.
- **Synced hop** (both bearers within `HOP_SYNC 0.16s`): a **HEAVE** — clears `0.4`
  divergence and bursts forward (`HOP_BURST 2.4`). Rewards coordination.
- Either way the coffin clatters (and the dead grumble) loud enough to tempt the
  other team into looking over.

## HAZARDS (fixed, deterministic; both lanes symmetric)

- **Mud** at z≈8.6 and z≈2.4: half speed + slip (divergence).
- **Swinging gate** at z≈-1.5 on a `4.2s` timer: cross while it is >55% shut and the
  coffin drops. Bots cut it close, so a fraction of approaches get clipped.
- **Mourner procession** at z≈-6.2: two lines **converge symmetrically** from both
  verges (a single sweep would always reach one lane first — that was a measured
  25/75 lane bias; converging fixes it to ~50/50). Ram them at speed = a drop;
  slow = a soft block (wait or weave).
- **Downhill** z≈-9.5..-14.5: drop here and the coffin **runs away** toward the crypt
  (`RUNAWAY_SPEED 5.5`, decaying) — chase it down, then restuff.

## SCORING (design call — LOGGED)

There is no team scoring anywhere else in the anthology; this is the first. The
shell (`estate_state.apply_results`) awards party currency **strictly by placement
rank** `[5,3,2,1]` and **ignores the module's `points` dict**. So the fair team
mapping is expressed in the **placement order**: BOTH winners are placed ahead of
BOTH losers (winning team banks 5+3, losing team 2+1). The intra-pair split
(5-vs-3, 2-vs-1) is decided by the **smoothest-carrier** tiebreak — the individual
flourish. The reported `points` dict (`4` per winner, `1` per loser) is the
ResultsBoard **display** score only. Smoothness also drives a `royalty` +
`The Steady Hand` monument for the steadiest bearer, and a `grudge` per drop for
fumblers. `kill_events` is empty (a race has no PvP kills — kept honest).

## Bots (beatable, not braindead)

Two bots on a team compute the **same** target, so they carry smooth; a bot paired
with a lone human **follows the human's lead** (matches their stick) to keep
divergence low. Each bot occasionally **fumbles** (a seeded stumble, more often on
mud) which diverges the carry and sometimes drops it — a coordinated human pair
that never fumbles out-carries them. Bots wait out the gate, slow for mourners,
heave over mud, and mash to restuff (chasing a runaway first). The bot RNG is
hash+warmed so consecutive seeds don't correlate into a lane advantage.

## Determinism

The sim runs on a **fixed timestep** (`FIXED_DT = 1/60`), fully decoupled from
wall-clock — state is a pure function of seed and step count. `--pallbearertest`
soaks by running 12 fixed sub-steps per physics tick (12x faster real-time,
identical math). **Byte-identical run to run** (proven below). Engine.time_scale is
never used in the tally (it would scale the delta and change the integration).

## Commands run

```bash
GD=<godot 4.6.2>
# 1. headless import (clean — pre-existing theme/font/cosmetic errors only)
"$GD" --headless --editor --import --quit --path .

# 2. deterministic bot soak -> receipt, then quit (headless)
"$GD" --headless --path . res://minigames/pallbearers/pallbearers.tscn -- \
  --pallbearertest --seed=5

# 3. run the receipt twice and diff (must be byte-identical)  -> BYTE-IDENTICAL
# 4. windowed event-based screenshots
"$GD" --path . res://minigames/pallbearers/pallbearers.tscn -- \
  --pallbearercap --seed=8 --outdir=verify_out/pallbearers

# 5. whole-project game-load smoke: estate boots + launches via the contract path
"$GD" --headless --path . -- --estatebots --exhibtest=pallbearers --quittest=32
```

## Receipt (seed 5, shipping code, 0 SCRIPT ERRORs) — byte-identical run to run

```
PB_EVT t=9.53  | drop team=0 cause=gate z=-2.2 runaway=false
PB_EVT t=10.45 | reseat team=0 z=-2.2
PB_EVT t=15.02 | finish team=1 t=15.02
PB_TALLY seed=5 winner_team=1 finish_t=15.02 drops=[1, 0] gate=[1, 0]
  mourner=[0, 0] heaves=[2, 4] smooth=[RED=0.91, GOLD=0.91, BLUE=1.00, MINT=1.00]
  points={"0":1,"1":4,"2":1,"3":4} placements=[1, 3, 0, 2]
```

Balance across seeds 100-131 (32 all-bot matches): **team0 17 / team1 15** wins,
0 stalls, matches finish 13-17s. Drops/gate hits vary per seed; a clean pair wins
fast, a fumbling pair loses the race (and the dead complain about it).

## Screenshots (verify_out/pallbearers/, --pallbearercap --seed=8)

- `pallbearers_intro.png` — the Mario-Party intro card: title, one-line goal, LIVE
  bindings (W/A/S/D · Q · SPACE), rotating tip, READY ring, team lane bars.
- `pallbearers_carry.png` — mid-race: both pairs carrying gold-crossed coffins down
  the lanes, gate bars ahead, the dead grumbling ("Mind the corners." / "Noted.").
- `pallbearers_gate.png` — the swinging cemetery gate closing across both lanes as
  the coffins approach.
- `pallbearers_drop.png` — RED & GOLD DROPPED: the pale deceased spilled on the
  gravel, complaint up ("You have dropped me before the mourners. Note it for the
  record."), the other pair pressing on.
- `pallbearers_finish.png` — the photo finish at the lit crypt doors, "THE PALL IS
  SET DOWN".
- `pallbearers_results.png` — the ResultsBoard: "RED SETS DOWN THE PALL FIRST",
  placement rows with colorblind-safe badges (RED/GOLD 4, BLUE/MINT 1), STEADY
  callout, confetti, winners cheering at the crypt.

## Online

Host-authoritative 20 Hz mirror per the house pattern (docs/design/10). `_net_state()`
ships public facts only (coffin transforms, divergence, per-team phase, restuff frac,
carrier poses, gate frac, mourner phase, drop/heave counters, winner). `_net_apply()`
rebuilds from latest-state-wins and fires clatter/heave juice from counter deltas.
Endings are pre-announced: `_net_winner` is set at `_finish_match` and rides many
pumps during the ResultsBoard before `report_finished` (which stops the estate's
pump the same tick).

## CLI args

`--pallbearerbots` (all seats bot), `--pallbearertest` (headless soak → `PB_TALLY` +
quit), `--seed=N`, `--players=2..4`, `--roundtime=S`, `--pallbearercap`
(+ `--outdir=`) windowed event screenshots.

## Design deviations / notes

- The `points` dict is display-only; currency is placement-rank driven (see SCORING).
- No coffin GLB exists yet — the styled walnut+gold casket reads as a shipped prop
  behind the one-line `PBCoffin.COFFIN_GLB` swap seam. The deceased is a wrapped
  shroud (a KayKit body would read as a live person; a shroud reads as cargo).
- EnvKit MOONLIT, brightened (key 1.45 / ambient 0.78) + a soft overhead fill so
  the coffins and the spill read against the night ground.
