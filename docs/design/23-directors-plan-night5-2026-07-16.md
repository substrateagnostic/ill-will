# Director's Plan — Night 5 (2026-07-16)

*Fifth watch. Mandate: production/AAA across gameplay, writing, menus, graphics.
Comp for the flagship: "Mario Party if it was made in 2026." Backgrounds,
environments, humorous animated NPCs. New games welcome. Meshy for anything
without an asset (1007 credits banked). Research first. Find improvements Alex
would never guess. Month-plus of work, one night.*

## Where night 4 left the house

THE PROCESSION is playable and deterministic, but it is a *systems* triumph
dressed in a *prototype's* presentation: static camera pods, text-only space
events, an Executor who is a lower-third instead of a person. INPUT 2.0,
14/14 online, the estate's memory (newsreel/album/chronicle), house look,
32 Meshy props, SFX bank. Known-open debts listed in MORNING MENU #4.

## The night's thesis

Night 4 built the board. Night 5 makes it a *show*. A 2026 Mario Party is a
broadcast: cameras that know where the story is, a host with a body and
timing, a board that reacts, an audience of NPCs, and zero dead seats — the
eliminated get something to do. Everything else in the anthology gets pulled
up to that broadcast standard: front-end, settings, writing voice, arena
dressing.

## Waves

### WAVE R — research (docs 24–26, parallel, before flagship builds)
- **R1 · The 2026 board standard** (Opus): dissect modern party boards
  (Jamboree, Pummel Party, et al.): camera language, host characters, space
  events, item flair, downtime elimination, dead-player engagement. Every
  finding mapped to a concrete PROCESSION change with file pointers. → doc 24
- **R2 · Front-end AAA standard** (Sonnet): title screens, attract modes,
  settings/accessibility floors (colorblind, text scale, volume buses, shake
  toggle), pause conventions; audit ours against it. → doc 25
- **R3 · Ambient life + voice bible** (Sonnet): animated background NPCs in
  stylized games; humor delivery in party games; a written VOICE BIBLE for
  the estate's dry probate register; audit of existing strings. → doc 26

### WAVE 0 — immediate builds (launch with research)
- **Z1 · Known-debt sweep**: remote hop packet bit; abstract hint-bar
  fallback in unswept games; GET READY/intro-card double-gate; newsreel
  guest parity. All specified in docs 19–22.
- **Z2 · Meshy Forge wave 2**: the NPC troupe and board dressing downstream
  lanes need — Executor host figure, mourners, crow, groundskeeper, hearse,
  lantern posts — plus a sweep of remaining primitive placeholders.
  Budget ~450 credits of 1007.

### WAVE B — flagship builds (after research skim; worktrees; one task/agent)
- **B1 · PROCESSION CINEMA** (Opus): opening board flyover, putt/landing
  cameras, round banners and standings interstitials, space-event visual
  payoffs, Deed-purchase flair. The broadcast layer.
- **B2 · THE EXECUTOR EMBODIED** (Opus): the host gets a body — model,
  idle/gesture animation, positioned at reveals; expanded line pools;
  live commentary hooks (minigame chokepoints feed the lower-thirds).
- **B3 · AMBIENT LIFE KIT** (Opus/Sonnet): core kit for background life —
  crows that scatter, ghost mourners whose speech bubbles quote the actual
  CHRONICLE, groundskeeper, candles/fog/fireflies. Estate + Procession first.
- **B4 · FRONT-END AAA** (codex gpt-5.6-sol xhigh, harvest-pattern backup):
  title screen rework, attract mode (bots play under the newsreel shader),
  settings menu (buses, colorblind palettes, text scale, shake toggle),
  pause standard.
- **B5 · THE WRITING PASS** (Opus): voice bible applied everywhere — intro
  cards, howtos, results lines, Executor pools, chronicle. Variety so jokes
  don't repeat within a night.
- **B6 · GHOST MEDDLING** (Opus): the improvement he'd never guess —
  eliminated players become poltergeists with small, safe, *attributed*
  interactions (rattle, gust, flicker) in elimination games. Dead seats are
  the cardinal party-game sin; this kills it.
- **B7 · GAME #15** (Opus): chosen after R1. Current front-runner:
  PALLBEARERS — 2v2 coffin-carry relay chaos (couch co-op the mandate keeps
  asking for). Director decides post-research.
- **B8 · ARENA DRESSING** (Sonnet): horizon silhouettes and dressing for the
  plainest arenas, EnvKit + forge props.

### WAVE V — verification and close
Import + game-load smoke after every merge; procession receipt regression
(seed 7 → heir BLUE, 17 rounds) after every board-touching merge; director
reads screenshots before merging; push after merge; final soaks, fresh zip,
MORNING MENU #5, Corner letter, memory update.

## Standing rulings (carried from night 4, still overridable)
Frozen putt physics stay frozen (they are the dice). DEEDS/Grudge economy
unchanged unless research demands. Codex lanes: bounded tasks only, poll by
file-write times, harvest-and-takeover on wedge. Music remains Alex's domain
— tonight builds routing/stinger *infrastructure* only, no composition.

## Success criteria
A stranger who sits down at the title screen tonight should believe the
game shipped: a front-end with a settings menu, a board night that watches
itself like a broadcast, a host with hands, grounds that breathe, no dead
seats, and not one string that reads like an engineer wrote it.
