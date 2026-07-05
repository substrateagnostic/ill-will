# LAST WILL — verification

Survival gauntlet over the dusk void where DYING IS A POWER: the eliminated
pause the whole world for six seconds, draft a will (bless one survivor,
curse another), then haunt the platform edge as gust-throwing onlookers.
Best-of-3. The dead decide who wins; the living audition for their favor.

Root scene: `minigames/last_will/last_will.tscn` (extends `Minigame`).
Self-starts standalone 0.5s after `_ready` with a default 4-player config
(KayKit chars, colors/names from `GameState` consts, seed from `--seed=N`
or 1). When the shell calls `begin(config)` first, the self-start skips.

## Per-player bots (fleet convention)

The bot driver skips roster entries with `"bot": false`; entries without
the key fall back to `PlayerInput.is_bot(index)`. In the standalone default
config, players on real devices are humans and unassigned/shared devices
get bots. `--willbots` forces everyone. Bot wills are SPITEFUL by decree:
curse the current round leader, bless the second-worst survivor; the card
pick is seeded-random.

## How to run

Standalone (humans on gamepads / keyboard halves via PlayerInput):
```
godot --path . minigames/last_will/last_will.tscn
```

All-bot demo:
```
godot --path . minigames/last_will/last_will.tscn -- --willbots --seed=3
```

CLI user args (after `--`):
- `--willbots` — every player is a seeded self-play bot
- `--seed=N` (default 1), `--players=N` (2..4), `--willrounds=N` (1..5)
- `--willtally` — headless evidence mode: full bot match fast-forwarded
  with dt pinned to 1/60 (time_scale + physics_ticks_per_second scaled
  together, Swap Meet's trick), prints `WILL_TALLY`, quits
- `--willkill=T:P,...` — force-eliminate player P at round-time T (round 1
  only; deterministic will-theater screenshots)
- `--willskip=T` — jump round 1 to time T (replays the shrink chain,
  skips stale hazards; sudden-death screenshots)
- `--willtest=squish` — self-test: a stationary pawn must be flattened by
  an aimed boulder
- plus the global `--shots=N,...` / `--outdir=` harness

Import pass after adding files (run, exits clean):
```
godot --headless --editor --import --quit --path .
```

## MUST list (spec v1) — all done

- [x] Shrinking platform — chapel-yard flagstone rings over a dusk void;
      outer ring crumbles at 20s, mid at 40s, and at 60s SUDDEN DEATH
      drops the core ring too: only a candle-lit r=1.8 pillar remains.
      Every shrink is telegraphed 2s with red-pulsing stones + banner.
- [x] 2 telegraphed hazards — windmill-blade pendulum (red strip along the
      sweep line, creak, then 3-6 swings; contact = violent launch) and a
      rolling-boulder spawner alternating sides (glowing lane + "!", then
      SQUISH on grounded contact; hop over it — airborne is safe).
- [x] Shove (A) / hop (B) — 5 m/s sumo control, knockback scales with
      attacker speed, hit-pause + shake on landed shoves.
- [x] Elimination -> WILL DRAFT: world FREEZES (living pawns + hazards +
      gusts + effect timers halt; ghost spectators keep swaying), 6-second
      draft: 3 cards (each pairs one blessing + one curse; seeded shuffle
      pairs all six effects every draft), then bless-target and
      curse-target steps with a pointing SKELETAL HAND cursor + pulsing
      ring over the candidate, world-peek dim so the couch sees who.
- [x] Card effects exactly as spec'd — bless: shield (eats 1 hit — shove,
      blade, or squish), swiftness (+20% 10s), coin (+1 point instant);
      curse: sluggish (-20% 8s), butterfingers (shove disabled 6s, invalid
      buzz on attempts), haunted (wisp chases 8s, contact = stumble,
      re-arms 1.6s).
- [x] Caps — 1 active blessing + 1 active curse per player, newest
      replaces (a replaced haunted also despawns its wisp). Puppetmaster
      claims survive replacement: the cap governs effects, not gratitude.
- [x] 2P carry-over (generalized) — the will ALWAYS fires, including the
      round-ending death; if the round is already decided, timed effects
      carry into the next round's opening seconds and the bless claims the
      NEXT round's puppetmaster. Coin is always instant. On the final
      round they fade ("the will fades with the match"); coin still pays.
- [x] Ghost gusts — the dead sit on floating stone pews at the platform
      edge (Sit_Floor_Idle / Lie_Idle by parity, translucent ghost bodies,
      identity ring + headstone trim), every 10s a gust readies: aim with
      move (arrow), A releases a traveling wind wave that nudges everyone
      it touches (impulse 4.4; bypasses shields — it's a nudge, not a hit).
      Never out of the game.
- [x] Best-of-3 — ROUND n/3, everyone revives, platform rebuilt, carry-over
      wills announced at the next round's start.
- [x] Puppetmaster +2 — if the player YOU blessed wins the round the bless
      was active in, "THE DEAD HAND MOVES THE WORLD — X +2" banner at the
      round ceremony, +2 points, royalty event.
- [x] Results contract — placements (every roster player), points,
      currency_events (royalty +2 per puppetmaster, grudge +1 per
      elimination), highlights (decisive curses, champion outcomes, shove
      kills), monument "Kingmaker from the Grave" at 2+ puppet bonuses.
      Emitted via report_finished(); no validation warnings in headless
      full-match runs.
- [x] Seeded bots — all RNG from config.rng_seed (bots use seed ^ 0x717A57
      stream); survival brain dodges lanes/pendulum/edges imperfectly on
      purpose, hunts shoves; will-draft brain is random-but-spiteful.

SHOULD: spectral onlooker poses [x], haunted wisp [x].

## REQUIRED BOT EVIDENCE — >=2 wills per round avg across 5 seeds

`godot --headless --path . minigames/last_will/last_will.tscn -- --willtally --seed=N`

FINAL RESULTS (3 rounds each, 4 bots — every seed at the 3.00 maximum,
meaning every round resolved by eliminations, never by timeout):

```
WILL_TALLY seed=1 rounds=3 wills=9 wills_per_round=3.00
deaths: void=6 squish=3 | gusts=3  puppet_bonuses=4 carryovers=1
WILL_TALLY seed=2 rounds=3 wills=9 wills_per_round=3.00
deaths: void=6 squish=3 | gusts=16 puppet_bonuses=1 carryovers=2
WILL_TALLY seed=3 rounds=3 wills=9 wills_per_round=3.00
deaths: void=7 squish=2 | gusts=11 puppet_bonuses=2 carryovers=2
WILL_TALLY seed=4 rounds=3 wills=9 wills_per_round=3.00
deaths: void=8 squish=1 | gusts=6  puppet_bonuses=2 carryovers=2
WILL_TALLY seed=5 rounds=3 wills=9 wills_per_round=3.00
deaths: void=6 squish=3 | gusts=8  puppet_bonuses=4 carryovers=2
AVERAGE = 3.00 wills/round across 5 seeds  (target >=2)  PASS
```

Earlier tuning history: the first suite averaged 2.87 — and passed with a
GHOST hazard (see squish test below); a mid-build run averaged 2.33 with
rounds stalling at the 78s cap until the sudden-death pillar shrink and
the pillar-brawl bot fix (shove reflex now fires even while flee-panicked)
landed.

## 2P degenerate case (spec Risk)

Full 2P bot match, seed 9 (`--willtally --players=2`) — the dying breath
matters every round:

```
LW_DEATH round=1 t=18.5 BLUE SHOVES RED INTO THE DUSK
LW_WILL RED curses BLUE with sluggish (carry)
LW_ROUND_START 2/3
LW_CARRYOVER curse sluggish RED->BLUE        <- revenge opens round 2
LW_DEATH round=2 t=16.9 RED SHOVES BLUE INTO THE DUSK
LW_WILL BLUE blesses RED with shield (carry)
LW_ROUND_START 3/3
LW_CARRYOVER bless shield BLUE->RED
LW_DEATH round=3 t=57.0 THE BOULDER FLATTENS RED (squish)
LW_WILL RED curses BLUE with butterfingers (fades: match over)
totals: RED=3 BLUE=6
```

And in a separate 2P run (seed 4): a carried bless DELIVERED —
`LW_PUPPETMASTER RED +2 (blessed BLUE)` a full round after RED died.

The will still fires on the round-ending (only) death; curses/blesses
carry into the next round's first seconds; a carried bless that delivers
pays the puppetmaster +2 a round later. 2P scoring is 3/0. Note: the
>=2-wills metric is structurally a 4P target (a 2P round has at most one
will).

## Squish self-test

```
godot --headless --path . minigames/last_will/last_will.tscn -- --willtest=squish --seed=1
WILLTEST squish RESULT: PASS (t=3.58)
```

This test CAUGHT a real bug: boulders sank below deck at spawn (the
far-edge fall-off logic also fired on the spawn side), so every boulder in
the first tally suite was a ghost rolling under the yard. The fall now
only engages past mid-journey.

## Screenshots (committed in shots/, Godot-ignored; art-directed from PNGs)

Regenerate (windowed; frame indices are ~real-time and drift with fps):
```
godot --path . minigames/last_will/last_will.tscn -- --willbots --seed=3 --willkill=3:2,8:1 --shots=150,950,1170,1330,1480 --outdir=verify_out/lwA
godot --path . minigames/last_will/last_will.tscn -- --willbots --seed=2 --willrounds=1 --willkill=3:3,6:2,9:1 --shots=2000,4650,4820,5600 --outdir=verify_out/lwB
godot --path . minigames/last_will/last_will.tscn -- --willbots --players=2 --seed=4 --willkill=4:0 --shots=1550 --outdir=verify_out/lwC
godot --path . minigames/last_will/last_will.tscn -- --willbots --seed=7 --willskip=56 --shots=900,3200 --outdir=verify_out/lw8
```

- `screen_round_start.png` — the chapel-yard at dusk: flagstone rings,
  amber lanterns, gravestones, broken-arch island, purple void sea.
- `screen_will_cards.png` — THE SHOW: world frozen + dimmed, deceased's
  gold frame pulsing, memorial portrait (live KayKit bust, black ribbon),
  three parchment cards (bless half gold / curse half green, hand-drawn
  glyphs), 6s timer bar in the deceased's color.
- `screen_will_curse_target.png` — "☠ NOW... CURSE WHOM? ◄ BLUE ►", world
  peeking through the dim, bone-white SKELETAL HAND pointing down at the
  candidate over a pulsing ring in the deceased's color.
- `screen_will_resolution.png` — "GOLD BLESSES BLUE — A COIN /
  ...AND CURSES MINT — HAUNTED", wisp already materializing.
- `screen_wisp_hunt.png` — mid-round: the wisp's dotted green trail
  hunting BLUE across the yard; MINT's ghost pew aiming a gust top-right;
  scoreboard shows RED's inherited +1.
- `screen_puppetmaster.png` — "THE DEAD HAND MOVES THE WORLD — MINT +2"
  in MINT's color at the round ceremony (banner-token fix proven: the
  survival banner's timed hide no longer erases it).
- `screen_yard_crumbling.png` — the whole outer ring pulsing red under
  "THE YARD IS CRUMBLING!".
- `screen_sudden_death_pillar.png` — "ONLY THE PILLAR REMAINS": four
  pawns brawling on the candle-lit last pillar ringed by red-hot falling
  stone, boulders inbound.
- `screen_match_win.png` — champion alone on the yard, three ghost pews
  watching.
- `screen_2p_one_heir.png` — the 2P rule on screen: "ONE HEIR REMAINS:
  BLUE" with BLESS THEM / CURSE THEM panels from the drafted card.

## Design decisions & known issues

- Round timeout (rare, cap 78s): surviving players are ranked by distance
  to the platform center (earned position), then index; sudden death at
  60s plus the pillar make timeouts uncommon.
- Headed runs are not frame-identical to headless with the same seed (FX
  slow-mo waits in real time — same caveat as Dead Weight). Gameplay state
  advances on the physics tick; tally mode pins dt to 1/60.
- Gusts bypass shields intentionally: a shield eats one HIT (shove, blade,
  squish); a gust is a positional nudge. Documented in-code.
- The final death of the final round can still gift a coin (+1) — "the
  dead decide who wins" at match point is the game's thesis, but no
  puppetmaster claim attaches to a round already decided.

## Wishes

- A quill-scratch SFX and a low choir/organ drone for the will theater
  (currently: grudge bong + card clicks + confirm from the shared bank).
- KayKit skeleton arm / gravestone props — the hand cursor and headstones
  are box-built; silhouettes are fine, dedicated meshes would sing.
- A globe/lantern flicker shader for the chapel lanterns.
