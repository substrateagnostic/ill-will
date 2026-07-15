# 14 — AAA UX Standard: Controller Assignment, Menus, Scoreboards, HUD, Juice

Date: 2026-07-15. Engine: Godot 4.6.2. Author: design-research agent. Docs-only,
web-researched, all claims cited. Trigger: the anthology's new hard requirement
— **every player has their own controller** — plus a general standardization
pass on menu/HUD/results conventions ahead of a AAA-polish push.

This doc is a **reference spec**, not a per-game gap list (doc 09 already does
per-game staging gaps; doc 04 already covers the estate-as-menu redesign and
the settings checklist). This doc supplies the *numbers and named precedents*
those docs assume, adds the controller-assignment research the new requirement
demands, and closes with a checklist an implementation team can build against
plus a priority order grounded in **what `core/party_setup.gd` and
`core/podium.gd` already do today** (both read in full for this doc — see §7).

---

## 1. Controller assignment & lobby

### 1.1 Named references, what each actually teaches

**Overcooked / Overcooked 2** — the welcome screen is the device-claim screen
itself: press **Space** to claim the keyboard seat, press **A** on any pad to
claim that pad's seat; a *split-controller* mode also exists where one pad is
halved between two cooks for couches with fewer pads than players [OC-1]. The
lesson: claiming a seat and picking your input device are **the same action**,
not two menus.

**TowerFall Ascension** — from the character-select screen, each additional
human presses any button on **their own controller** to fill the next slot; no
central "assign" step. Notably the devs explicitly steer players away from
2-player-on-one-keyboard because most keyboards can't register enough
simultaneous keys (rollover) to run two independent movesets reliably [TF-1] —
directly relevant if a keyboard is ever offered as a fallback seat: pick two
non-overlapping key clusters (e.g. WASD+space vs arrows+enter) and test
n-key-rollover on real hardware before shipping it as a "real" seat, not just
during development.

**Fall Guys** — included as the **negative** reference. Despite being shaped
exactly like a couch party game, Fall Guys shipped with **no split-screen or
local co-op at all**; plugging in a second pad does nothing, and the "couch"
experience is really four separate online clients sharing a room [FG-1][FG-2].
The lesson for us is architectural, not cosmetic: **couch-first is a design
commitment made at the input layer**, not a feature bolted on after the game
is built online-first. (ILL WILL already made the correct call here — this is
a citation for *why* the new "own controller" requirement matters, not a
pattern to imitate.)

**Super Smash Bros. Ultimate** — controller **port order maps directly to
seat order** (P1–P4 left to right) and that port identity is load-bearing UI
— the "same color glitch" is a named, documented failure state when two
players' identity colors collide, which the game actively prevents by forcing
a re-pick [SMASH-PORT][SMASH-COLOR]. Lesson: **seat order and color must be
validated as a pair** — never let two active seats resolve to the same
identity color, and always show which physical port/pad maps to which seat.

**Party Animals** — the concrete **hot-join** precedent: plugging in a new
controller mid-lobby (not mid-*match*, but mid-*session*) surfaces an explicit
confirmation dialog, **"ADD NEW LOCAL PLAYER WITH THIS CONTROLLER? YES/NO"**,
triggered by a deliberate button press (RT) rather than merely being detected
[PA-1][PA-2]. The confirm step matters: it's the difference between "a
controller twitched near the couch" and "a fifth person picked it up on
purpose."

**Jackbox Party Pack** — the boundary case worth naming even though it's not
local-pad-based at all: a phone joining via a 4-letter room code at
jackbox.tv *is* "the player's own controller" in spirit — one device, one
person, no seat-stealing possible by construction — and the first joiner
becomes **VIP** with the exclusive "start" button [JBX-1]. Useful for our
online mirror: the room-code/VIP pattern is the right model for the *online*
lobby even though local seats use pad-claiming.

**Nintendo Switch pairing** — pads are paired through a dedicated system
screen (hold SYNC ≥1s) *before* any game sees them; the console assigns a
**player-LED position**, not a color, and caps at 4 (Switch) / 8 (Switch 2)
paired controllers [NIN-1]. Relevant mainly as a contrast: we don't control
a system-level pairing screen, so our in-game join flow has to do double duty
(pairing *and* seat-claiming) that Nintendo splits across two layers.

**Xbox certification (TCR)** — this is not a style choice, it's a **hard
platform requirement**: when the active controller disconnects, the game must
detect it, pause, and show a platform-appropriate reconnect prompt; shipping
without this fails Xbox cert outright [XBOXTCR-1]. Treat "pause + reassignment
overlay on disconnect" as non-negotiable, not aspirational, even though we
ship on Steam first — it's the correct behavior on every platform, cert or not.

### 1.2 The exact UX beats of a join/lobby screen (synthesized from 1.1)

1. **Idle.** Every seat starts empty, each slot showing the literal glyph to
   press ("Press ⓐ" / "Press SPACE") — not a generic "waiting for players"
   label.
2. **Claim.** Pressing confirm on *any* unclaimed input device fills the next
   empty seat with that device's glyph, a default name, and the next unused
   identity color — one input, one seat, atomically (Overcooked, TowerFall).
3. **Customize.** While claimed, a seat's own device — and only that device —
   can cycle its color/character/name. No seat can steal another's input focus.
4. **Identity collision guard.** Two active seats resolving to the same color
   is a hard-blocked state, not a warning (Smash's "same color glitch" fix).
5. **Ready-up.** Each seat has an explicit ready toggle (not implicit from
   "seat is filled"); start is gated on all human seats ready, mirroring the
   Jackbox VIP-starts-only-when-ready pattern but per-seat rather than
   single-host.
6. **Leave.** Holding cancel/back on your *own* seat releases it to empty —
   never a route to touch someone else's seat.
7. **Hot-join** (lobby only, pre-match): a newly-detected pad on an empty
   seat prompts an explicit YES/NO confirm rather than auto-joining (Party
   Animals) — prevents a bumped controller from grabbing a seat.
8. **Mid-match disconnect.** Pause immediately, show which seat dropped by
   name/color, offer "press any button on a pad to reclaim this seat"; if
   nothing reclaims it inside a short window, the anthology's existing
   bot-takeover convention (doc 04) covers it. This is the TCR-mandated beat
   [XBOXTCR-1], not optional polish.

---

## 2. Menu systems

### 2.1 Title → gameplay depth

No codified industry "N inputs" benchmark exists in public sources — this is
a practice, not a published metric, so the number below is a range built from
named examples rather than a single citation:

- **UFO 50**'s hub is the gold-standard floor: a single unpaged 10×5 grid,
  **one confirm press launches any of the 50 games** [UFO50-1].
- **Jackbox** guests: room code + name, effectively **zero** menu depth once
  the code is known — the "menu" is a text field [JBX-1].
- **Mario Party** full-game mode: title → mode select → character select →
  board/stage select → minigame is a real multi-screen crawl (5–6 confirms);
  its **minigame-only modes** compress this to 2–3.

Doc 04 already set our house target — **<10s hub→gameplay** via a one-screen
5×2 grid — which sits correctly between the UFO 50 floor and Mario Party's
full-game ceiling. This doc doesn't move that target; it just confirms it's
the right neighborhood.

### 2.2 Pause menu — standard contents

Convention across the sources checked: **Resume** (top item, pre-focused —
resuming is the single most-used action so it should need zero navigation),
**Settings/Options**, optionally **Restart/Return to checkpoint**, **Quit to
Main Menu** [PAUSE-1]. For a 4-player couch game specifically, "Quit" is a
**shared-consequence action** (§2.4) — see the hold-to-confirm note below.

### 2.3 Settings categories — what's table-stakes now

Doc 04 already produced a ranked MUST/SHOULD/LATER checklist; this doc adds
the primary-source backing and a few items doc 04 didn't have numbers for:

| Category | Table-stakes item | Concrete parameter | Source |
|---|---|---|---|
| Video | Display mode | Windowed / Borderless Fullscreen / Exclusive Fullscreen | industry-standard triad |
| Video | VSync, resolution, FPS cap | — | — |
| Audio | Bus sliders | Master / Music / SFX (/ UI if split) | — |
| Accessibility | Colorblind modes | **3 CVD presets minimum**: protanopia, deuteranopia, tritanopia (Fortnite/Apex/Overwatch pattern) + never-color-alone backup (shape/icon/text) | [COLORBLIND-1][GAG-1] |
| Accessibility | Text size | Scalable to **200% of minimum default**; default minimum **26px @ 1080p / 52px @ 4K on console (10-foot)**, 18px/36px on PC/VR | [XAG101] |
| Accessibility | Text spacing (if >2 lines) | line spacing ≥1.5×, letter spacing ≥0.12×font, word spacing ≥0.16×font, paragraph spacing = 2×line spacing, line width ≤80 chars | [XAG101] |
| Accessibility | Screen-shake / flashing reduction | Rename as **"Effects Intensity"** not "epilepsy mode"; hard seizure-safety ceiling regardless of the toggle: flashes ≤3/sec, luminance flash <20% of screen, red-flash desaturated, high-contrast spatial patterns <20% of screen | [XAG118][GAG-2] |
| Accessibility | Haptics/rumble | Explicit **off** + **intensity** control wherever haptics are used; haptics must never be the sole carrier of information | [XAG110] |
| Accessibility | Hold-to-confirm for destructive actions | **3s** for individual/irreversible actions, up to **5s** for actions affecting other people | [HOLDCONFIRM-1] |
| Controls | Full remap, KB+M and pad separately | binding conflicts auto-swap rather than block (no unbindable state) | genre convention |
| Controls | Input glyphs | show the **actual detected** brand glyph set (Xbox/PlayStation/Switch/generic); unknown pad → neutral fallback glyph, never a wrong-brand guess | [GLYPH-1] |
| Controls | On-screen keyboard for controller-only name entry | required wherever text entry exists and a pad is the active input | [STEAMDECK-1] |
| UI | UI/text scale | independent of resolution; must reach 200% of the platform minimum | [XAG101] |

**Handheld reconciliation.** Steam Deck Verified's text-size floor is far
smaller than the console/TV number above — **minimum 9px, recommended 12px,
at 1280×800, calibrated for a ~12"/30cm viewing distance** [STEAMDECK-1] —
because a handheld sits in your hands, not six feet away on a couch. ILL WILL
is couch-first, so the **26px@1080p console/10-foot floor is the correct
baseline**, not the Deck number; if a handheld/portable build is ever
targeted, that's a *separate*, smaller UI-scale profile, not a relaxation of
the couch baseline.

### 2.4 Hold-to-confirm for shared-consequence actions

The general UX literature converges on **hold-duration scaled to blast
radius**: ~3s where only the actor loses something, up to ~5s where the
action affects other people or can't be undone [HOLDCONFIRM-1]. "Quit to
title" in a 4-player match is squarely the second case — it forfeits three
other people's night, not just the presser's — so it should sit at the
**5s end** of that range, not a single tap. See §7.4.

### 2.5 Focus/navigation conventions

Sourced directly from Microsoft's Xbox Accessibility Guidelines, which is the
most concrete public spec for this that exists:

- **Consistent order + consistent interaction across every screen** — same
  action always means the same button everywhere (A=select, B=back) [XAG112].
- **Wrap-around applies only to single-axis (linear) menus.** A menu where
  focus can only move up/down (or only left/right) should loop from last back
  to first. **Grid/multi-directional menus should NOT loop** — looping a 2D
  grid is disorienting, not helpful [XAG112].
- **LB/RB switch tabs, LT/RT switch pages** — this exact mapping is called
  out by name as the convention to preserve across screens; changing it
  screen-to-screen is explicitly flagged as a failure mode [XAG112].
- **B/back is always available and always in the same screen position**
  (bottom-left prompt is the common placement) [XAG112].
- **Every submenu has a persistent path back to the main/previous screen**
  — never a dead end [XAG112].
- **Dialogs steal focus to their first interactable control and hold it**
  there for the dialog's lifetime; focus must never land on something
  invisible or off-screen [XAG112][XAG113].
- **Focus indicators must combine ≥2 visual cues** (border + fill-color +
  weight/size change is the recommended combo) — color alone is not a valid
  focus indicator, mirroring the never-color-alone rule for player identity
  [XAG113].
- **Hold-to-repeat** on directional navigation has no single codified AAA
  number in public sources, but the common engine-default range is an
  **initial delay of ~300–500ms before repeating, then repeats every
  ~100–150ms** — treat this as a tunable starting point, not a hard citation.

---

## 3. Scoreboards / results

Doc 09 §0.D already cites Splatoon's tally reveal and Mario Party's
pose+jingle ritual as anthology-wide staging gaps — this section adds the
sequence-level detail for three more named results screens plus the
skippability convention, without repeating doc 09's per-game prescriptions.

### 3.1 Smash Ultimate results screen — the full beat sheet

1. Winning character's **victory pose** plays with dedicated victory music.
2. **Rankings display** — all participants shown in final placement order.
3. **Portraits + currency** earned, in bordered frames per player.
4. **Match stats** (KOs etc.) with a prompt to save the match as a replay.
5. **Detailed stats** screen (mode-dependent).
6. **Return prompt** back to stage/mode select [SMASH-RESULTS].

Two details worth stealing directly: **team victories sync every winning
character's pose to the leader's** rather than cutting between them
(one shared beat, not N sequential ones), and there's a documented
**special-case override** — winning via a Final Smash freezes on that
attack's own splash screen instead of running the normal sequence, i.e. the
system has an explicit hook for "this specific finish deserves its own
ending," which is exactly the "round-deciding moment gets bespoke treatment"
principle doc 09 §0.B already argues for [SMASH-RESULTS].

**Skippability**: any player's input skips the sequence, but **only before
the announcer states the winner's name** — the win reveal itself is
protected from being skipped past, only the pre-roll is [SMASH-SKIP].

### 3.2 Fall Guys — celebration-as-performed-bit, not banner

Each win plays one of a library of short **podium-based physical-comedy
beats**, not a static "YOU WIN" card — e.g. the default "Plinth Drop": the
bean leaps in celebration, then the podium comically drops out from under
them; other unlocks route a crown into the winner's hand via its own bit of
business (a Z-snap, a jack-in-the-box) [FG-3]. The lesson: **the win state is
a small performed scene**, staged with its own setup/punchline, not a
label slapped over gameplay.

### 3.3 Rocket League — noted gap in public sourcing

Rocket League has a car-podium celebration system (players can time a trick
to land as the post-match screen ends), but **no public source found gives
exact on-screen timing in seconds** for the podium sequence — flagged
explicitly rather than inventing a number. What *is* verifiable: the
celebration is player-triggered and time-boxed to the length of the results
screen itself, i.e. the ceremony's dead time is filled with player agency
instead of being pure spectation [RL-1].

### 3.4 Skippability convention — synthesized recommendation

Smash's model (any-player-skips, but not past the win reveal itself) is the
only concretely sourced pattern found. For a 4-player couch context
specifically, the safer variant is **any single player holds skip for a
short beat (~1–2s)** rather than a single tap: a tap-to-skip lets one
impatient player yank the ceremony away from three others who are still
watching their own placement animate in; a short hold gives the room a beat
to object by not letting go, without becoming a group-consensus gate (which
Jackbox-style pacing research already argues against — visible progress,
never a hard wait-for-everyone) [JBX-2, cited in doc 09]. This is a design
recommendation synthesized from the above, not a directly-sourced AAA
convention — flagged as such.

### 3.5 Placement animation patterns

Across all three named references, the common shape is: **freeze → reveal
new information (the room didn't already know the outcome) → count up/settle
→ hero beat on the winner**. Doc 09's Mower tally prescription (§5.1 of that
doc) already implements exactly this shape for one game; this doc confirms
it's the correct shape to replicate anthology-wide, not a one-off idea.

---

## 4. HUD conventions

### 4.1 Quadrant convention does NOT apply to us — important correction

The "corner-anchored per-player quadrant" convention is real, but it belongs
to **true split-screen** games (each player has their own camera/viewport,
e.g. Halo, Unreal Tournament) [HUD-1][HUD-2]. **ILL WILL is not split-screen**
— every game runs one shared camera (doc 08 §0: "a perspective camera
~45-48° above the ground plane," one viewport for all four players). Applying
quadrant-corner HUD to a shared-camera game would be a genre mismatch.

The correct reference class is **shared-camera couch party games**
(Overcooked, Moving Out, Party Animals, Mario Party's minigame views), whose
convention is instead:

- A **persistent player-order strip** (top or bottom screen edge), always in
  the same left-to-right seat order as the lobby (mirrors Smash's port-order
  rule, §1.1) — not four separate corner boxes.
- **World-space nameplates/identity anchors** under each character in the 3D
  scene itself — which the anthology already does (doc 08: "every contact
  game draws a color-emissive feet ring"). This *is* the correct convention
  for a shared camera, already implemented; no change needed here.

### 4.2 Timer placement and urgency states

Convention: timer lives top-center or top-edge, with a color/state escalation
— neutral → warning color at a threshold → red + pulsing/scaling in the
final stretch, typically paired with audio ticks in the last ~10s. This maps
directly onto the anthology's own `core/final_stretch.gd` (doc 09's Q1 item,
already built) — this doc's contribution is confirming that system already
matches the named-convention shape rather than needing redesign.

### 4.3 Off-screen indicators

Standard implementation: compute the screen-space line to the target,
project it to the point where that line crosses the visible rect, clamp the
indicator to a small inset (commonly 5–8%) from the true edge so the arrow
never visually clips, and rotate the glyph to point toward the target
[OFFSCREEN-1]. For us this matters specifically in the large/spread-out
arenas (Orbital, Mower, Dead Weight) where the single shared camera can lose
a player off-frame: fade the indicator in only past a distance threshold, and
color it to the owning player's identity color so it reads without a second
lookup.

### 4.4 10-foot UI text sizing — the numbers, restated for HUD use

Same XAG101 figures as §2.3 apply to HUD text specifically (timer numerals,
prompts, banners): **≥26px @ 1080p / ≥52px @ 4K on console**, scalable to
200% [XAG101]. This is the number to hold HUD text against during a polish
pass — measure actual rendered glyph height (ascender-to-descender), not the
nominal font-asset size, per XAG101's own measurement method (screenshot →
Paint → select ascender-to-descender box → read pixel height).

---

## 5. Game UI Database & named pattern references

**Game UI Database** (gameuidatabase.com) is the field's standard visual
reference: 1,300+ games, 55,000+ tagged UI screenshots, browsable by category
— relevant tags for this pass: *Pre-Game & Lobby*, *Character Select*,
*Matchmaking Lobby*, *Settings: Menu/Options/Audio/Gameplay*, *Loading
Screen*, *Tutorials and Guides*. Both **Super Mario Party** and **Party
Animals** are indexed there specifically under lobby/character-select tags —
the two closest genre neighbors to this anthology [GUIDB-1].

**Mario Party minigame intro cards — the exact pattern requested.** Before
each minigame, the game shows written instructions **alongside a small live
demo viewport** showing the minigame being played, and gives players a
window to physically press their own buttons and see their character react
in that demo space **before the real minigame's timer starts** — instruction,
demonstration, and a practice rep, all before stakes begin [MP-INSTR-1]. This
is a stronger pattern than a static "how to play" card: it's controls +
motion + a free practice input, not just text.

**How-to-Play cards.** Doc 04 already specced ours: secondary-button opens a
details card with a controls diagram + best scores, launched from the
selector grid. That already matches the Game UI Database's "Tutorials and
Guides" category convention (large diagram, minimal text) — no new
prescription here, just confirmation it's the right shape.

**Loading/transition wipes.** The named historical reference is Resident
Evil's door-opening transition, which hides level-load time behind a
diegetic, fully-obscuring motion rather than a blank bar [WIPE-1]. The
general rule extracted from the pattern-catalog sources: a wipe/shape/iris
transition should **fully obscure the screen for its own duration** and
should be sized to comfortably cover the *worst-case* load, not a fixed
cosmetic timer that can undershoot and reveal a hitch.

---

## 6. Juice standards for menus

### 6.1 Tween durations

| Interaction class | Duration | Source |
|---|---|---|
| Micro-interaction (toggle, checkbox, small state flip) | ~100ms | [NNG-1] |
| Standard element transition (button state, small panel) | 200–300ms | [NNG-1] |
| Hero transition (modal open, page push, large panel) | 300–400ms | [NNG-1] |
| Ceiling before it reads as sluggish | ~500ms | [NNG-1] |
| Entrance vs exit asymmetry | entrances slightly longer than exits (e.g. ~300ms in / ~200–250ms out) | [NNG-1] |
| Easing | **ease-out** for entrances (fast start, decelerate into place); avoid linear motion, which reads as artificial | [NNG-1] |

### 6.2 Sound-per-navigation

Build a small **"sound bible"**: one dedicated one-shot per interaction class
— hover/move-focus, select/confirm, cancel/back, error/denied, toggle-on,
toggle-off — applied consistently everywhere rather than ad hoc per screen
[SFX-1]. Technical baseline: **mono** for UI one-shots (keeps them consistent
across playback devices), loudness around **-18 to -14 LUFS** for routine
taps, with confirmations/errors allowed a little louder for salience [SFX-1].

### 6.3 Hover/selected states

Same rule as §2.5's focus-indicator requirement: combine **at least two**
simultaneous visual cues (border + fill + weight/scale bump is the standard
triad) — never color alone, both for accessibility and because a single cue
under couch lighting/TV viewing angles is easy to miss [XAG113].

### 6.4 Background motion / parallax

Keep ambient, non-interactive background motion **slow and clearly separate**
in speed/rhythm from the interactive-element tweens above, so the two don't
compete for the eye — and gate it behind the same reduce-motion/effects-
intensity toggle required for screen-shake and flashing (§2.3), since
slow-but-constant background motion is exactly the kind of "moving repeated
pattern" the seizure-safety guidance also flags at scale [XAG118].

---

## 7. Consolidated standards checklist

| # | Item | AAA convention | Concrete parameter | Source |
|---|---|---|---|---|
| 1 | Seat claiming | Press-your-own-device-to-claim, not a menu cycle | one input event → one seat filled | OC-1, TF-1 |
| 2 | Identity collision | Two seats can never share a color | hard-blocked, not warned | SMASH-COLOR |
| 3 | Hot-join (lobby) | New pad on empty seat prompts explicit confirm | Y/N dialog, not auto-join | PA-1 |
| 4 | Mid-match disconnect | Auto-pause + named reconnect overlay | platform-required, not optional | XBOXTCR-1 |
| 5 | Keyboard fallback seat | Non-overlapping key clusters, n-key-rollover tested | e.g. WASD+Space vs Arrows+Enter | TF-1 |
| 6 | Colorblind modes | 3 CVD presets minimum + never-color-alone | protan/deutan/tritan | COLORBLIND-1 |
| 7 | Text size (console/10-ft) | Scalable to 200% of minimum | ≥26px@1080p / ≥52px@4K | XAG101 |
| 8 | Text size (handheld, if ever targeted) | Smaller, closer-viewing profile | ≥9px (12px reco) @1280×800 | STEAMDECK-1 |
| 9 | Text spacing | Configurable or meets minimums | 1.5× line, 0.12×/0.16× letter/word, 80-char line | XAG101 |
| 10 | Screen-shake/flashing toggle | Labeled "Effects Intensity"; hard seizure ceiling regardless | ≤3 flashes/sec, <20% screen area | XAG118, GAG-2 |
| 11 | Haptics | Off + intensity control | never sole info carrier | XAG110 |
| 12 | Destructive/shared-consequence action | Hold-to-confirm, scaled to blast radius | 3s solo / up to 5s shared | HOLDCONFIRM-1 |
| 13 | Input glyphs | Match detected device brand; neutral fallback | Xbox/PS/Switch/generic sets | GLYPH-1 |
| 14 | Controller-only text entry | On-screen keyboard required | — | STEAMDECK-1 |
| 15 | Focus order | Consistent across all screens | same action = same button everywhere | XAG112 |
| 16 | Menu wrap-around | Linear menus loop; grids don't | — | XAG112 |
| 17 | Tab/page switching | LB/RB = tabs, LT/RT = pages | fixed mapping, never changes per-screen | XAG112 |
| 18 | Back navigation | Always available, always same screen position | bottom-left convention | XAG112 |
| 19 | Focus indicator | ≥2 simultaneous visual cues | border+fill+weight, never color alone | XAG113 |
| 20 | Hold-to-repeat | Initial delay then faster repeat | ~300–500ms delay, ~100–150ms repeat | engine-default convention (not hard-cited) |
| 21 | Pause menu order | Resume pre-focused at top | Resume / Settings / (Restart) / Quit | PAUSE-1 |
| 22 | Results skippability | Any-player skip, protected win-reveal beat | Smash: skip pre-roll, not the name reveal | SMASH-SKIP |
| 23 | Results skip input (couch variant) | Hold, not tap, to prevent one player yanking it from the room | ~1–2s hold (recommendation) | synthesized |
| 24 | Results sequence shape | Freeze → new info reveal → count-up/settle → winner hero beat | — | SMASH-RESULTS, FG-3, doc09 §0.D |
| 25 | HUD anchoring (shared camera, our case) | Player-order strip + world-space nameplates, NOT quadrant corners | quadrant is a split-screen-only convention | HUD-1, doc08 |
| 26 | Timer urgency states | Color escalation + audio ticks in final stretch | matches our own `final_stretch.gd` | genre convention, doc09 Q1 |
| 27 | Off-screen indicators | Edge-clamped, target-colored arrow | 5–8% inset from true edge | OFFSCREEN-1 |
| 28 | Menu tween duration | Scaled to element size | 100ms micro / 200-300ms standard / 300-400ms hero / 500ms ceiling | NNG-1 |
| 29 | Menu easing | Ease-out entrances | avoid linear | NNG-1 |
| 30 | UI sound bible | One dedicated one-shot per interaction class | mono, -18 to -14 LUFS | SFX-1 |

---

## 8. Prioritized gap-ordering for ILL WILL

Grounded in a direct read of `core/party_setup.gd` (the flat ESC overlay:
SEATS/CONTROLS/AUDIO/VIDEO/ACCESS tabs) and `core/podium.gd` (the 6.5s results
ceremony), both current as of this doc.

**Already meets or exceeds the standard — no action needed:**
- Colorblind palette has **4** options (classic + deutan + protan + tritan) —
  matches item 6 above exactly, plus identity already carries shape/name as
  backup (never-color-alone, confirmed in `party_setup.gd`'s own ACCESS-tab
  note).
- Screen-shake toggle exists in ACCESS.
- Full remap system with **auto-swap-on-conflict** (no unbindable state) —
  exceeds table-stakes item 11's spirit even beyond what was asked.
- Persistent "QUIT TO TITLE" escape hatch reachable from anywhere — matches
  item 18's "always a way back" rule.

**Gaps, ranked by impact × how directly the new "own controller" requirement
demands them:**

| Rank | Gap | Why it matters | Checklist ref |
|---|---|---|---|
| 1 | No press-to-join claim flow — device assignment today is a manual cycle-button (`DEVICE_CYCLE`) buried in the SEATS tab of the ESC menu, not a diegetic "press your own pad" claim | This is the headline ask of the new requirement; every named reference (Overcooked, TowerFall, Party Animals) claims a seat with the device's own input, not a menu click from seat 1's controller | #1 |
| 2 | No mid-match disconnect pause/reassignment overlay found | Hard platform requirement even off-Xbox; currently unclear what a dropped pad does mid-game | #4 |
| 3 | No input glyph system — SEATS/CONTROLS show text labels ("GAMEPAD 1", "KEYBOARD (WASD)") instead of brand glyphs | Fails the detected-device-glyph best practice everywhere prompts appear | #13 |
| 4 | "QUIT TO TITLE (forfeits the current game)" is a single press with zero confirmation, affecting 3 other players | Squarely the shared-consequence case the hold-to-confirm convention targets; recommend the 5s end of the range | #12 |
| 5 | No haptics/rumble toggle in ACCESS tab | Explicit gap against XAG110 wherever the anthology uses controller rumble | #11 |
| 6 | UI scale slider (100–130%) is unverified against the 26px@1080p base — confirm base font sizes actually clear the console minimum *before* the multiplier is applied | Silent failure mode: a 130%-scaled 18px font is still below the 26px floor | #7 |
| 7 | Hot-join confirm dialog (Party Animals pattern) not present for lobby-phase pad additions | Lower priority — current design already has a Ready Room per doc 04; verify it gates on explicit confirm, not silent auto-join | #3 |
| 8 | Podium ceremony skippability unconfirmed; if unskippable, add hold-to-skip | Minor — doc 09's Q3/Q9 ceremony work already tracks the *content* of results screens; this is just the skip-input gap | #23 |

---

## Sources

- [OC-1] Overcooked 2 device-join mechanics: https://gamefaqs.gamespot.com/boards/241209-overcooked-2/76895691 ; https://www.gameslearningsociety.org/wiki/how-do-you-set-up-multiplayer-overcooked/
- [TF-1] TowerFall Ascension local join + keyboard rollover caveat: https://www.co-optimus.com/game/3199/pc/towerfall-ascension.html ; https://steamcommunity.com/app/251470/discussions/0/618456760261730350/
- [FG-1] Fall Guys has no split-screen/local co-op: https://www.theloadout.com/fall-guys/split-screen
- [FG-2] Confirmation, second controller does nothing: https://www.gamerevolution.com/guides/654846-fall-guys-couch-co-op-local-multiplayer-splitscreen
- [FG-3] Fall Guys celebration ceremony descriptions (Plinth Drop, Z-Snap, Jack in a Box): https://fallguysultimateknockout.fandom.com/wiki/Celebrations
- [SMASH-PORT] Port priority / seat order: https://www.ssbwiki.com/Port_priority
- [SMASH-COLOR] Same color glitch (identity collision prevention): https://www.ssbwiki.com/Same_color_glitch
- [SMASH-RESULTS] Results screen sequence: https://www.ssbwiki.com/Results_screen
- [SMASH-SKIP] Skip-before-announcer convention: https://smashboards.com/threads/completed-skip-results-screen-new-code.423874/
- [PA-1] Party Animals hot-join confirm dialog: community-sourced via Steam guide search (see also) https://steamcommunity.com/sharedfiles/filedetails/?id=3039825569
- [PA-2] Party Animals RT-to-add-player: https://progameguides.com/party-animals/all-party-animals-controls-xbox-pc/
- [JBX-1] Jackbox room-code join + VIP: https://www.jackboxgames.com/how-to-play
- [XBOXTCR-1] Xbox certification, controller-disconnect pause requirement: https://learn.microsoft.com/en-us/gaming/gdk/docs/store/policies/console/console-certification-requirements-and-tests ; https://bugnet.io/blog/how-to-fix-console-controller-disconnect-requirement
- [NIN-1] Nintendo Switch controller pairing FAQ: https://en-americas-support.nintendo.com/app/answers/detail/a_id/22424/~/controller-pairing-on-nintendo-switch-faq
- [XAG101] Xbox Accessibility Guideline 101 (text size/spacing): https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/101
- [XAG110] Xbox Accessibility Guideline 110 (haptics): https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/110
- [XAG112] Xbox Accessibility Guideline 112 (UI navigation): https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/112
- [XAG113] Xbox Accessibility Guideline 113 (focus indicators): https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/113
- [XAG118] Xbox Accessibility Guideline 118 (photosensitivity thresholds): https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/118
- [STEAMDECK-1] Steam Deck Verified text-size/glyph/keyboard requirements: https://partner.steamgames.com/doc/steamdeck/recommendations
- [GAG-1] Game Accessibility Guidelines, colorblind mode: https://gameaccessibilityguidelines.com/basic/
- [GAG-2] Game Accessibility Guidelines, flashing/patterns: https://gameaccessibilityguidelines.com/avoid-flickering-images-and-repetitive-patterns/
- [COLORBLIND-1] Three-preset colorblind convention (Fortnite/Apex/Overwatch): https://www.switchbladegaming.com/game-settings/colorblind-players/
- [HOLDCONFIRM-1] Hold-to-confirm duration guidance for destructive actions: https://uxpsychology.substack.com/p/how-to-design-better-destructive ; https://medium.com/@tomj.pro/why-holding-buttons-is-superior-to-confirmation-dialogs-in-ux-design-69790ff30e06
- [PAUSE-1] Pause menu standard contents: https://medium.com/design-bootcamp/ux-ui-in-video-games-the-pause-menu-6f07e113e21e
- [GLYPH-1] Input glyph detection/fallback best practices: https://docs.mod.io/unreal/component-ui/gamepad-glyph-switching ; https://eviltwo.github.io/InputGlyphs_Docs/
- [HUD-1] Split-screen quadrant HUD convention (and its scope): https://www.gamedeveloper.com/design/shared-multi-split-screen-design
- [HUD-2] FPS corner-anchored HUD convention: https://www.wesplays.com/home/shooter-hud-analysis
- [OFFSCREEN-1] Off-screen indicator positioning technique: https://code.tutsplus.com/positioning-on-screen-indicators-to-point-to-off-screen-targets--gamedev-6644t
- [GUIDB-1] Game UI Database (lobby/character-select/settings/loading/tutorial categories; Super Mario Party & Party Animals indexed): https://www.gameuidatabase.com/
- [MP-INSTR-1] Mario Party minigame instructions + live demo pattern: https://www.imore.com/super-mario-party-beginners-guide
- [WIPE-1] Transition-screen design pattern, Resident Evil door reference: https://medium.com/@FredericRP/use-transition-screens-in-your-games-unity-f8742fea219b
- [UFO50-1] UFO 50's 10×5 unpaged grid select: https://steamcommunity.com/sharedfiles/filedetails/?id=3350227767
- [NNG-1] Nielsen Norman Group, UX animation duration and easing: https://www.nngroup.com/articles/animation-duration/
- [SFX-1] UI sound design best practices (sound bible, mono, LUFS targets): https://sfxengine.com/blog/best-practices-for-game-ui-sounds
- [RL-1] Rocket League podium celebration system (timing not publicly documented — noted gap): https://steamcommunity.com/sharedfiles/filedetails/?id=794631821
- [ITT2-1] It Takes Two split-screen UI design philosophy (context for shared-consequence co-op UI, not directly cited above but consulted): https://crm.bemka.com/it-takes-two-local-co-op-gameplay-on-one-screen-splitscreen-magic-for-two-players
