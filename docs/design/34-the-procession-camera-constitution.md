# 34 — THE PROCESSION: The Camera Constitution

*Night 7 lane (2026-07-20). Producer ruling #77 (Alex, verbatim intent) made
law. The precursor doc the CAMERA REWORK lane builds against — the lane does
NOT open until the perf probe (§3) passes. Reads with doc 28 §9 (downtime /
thinking budget), doc 24 F1–F3 (the director spine), and
`estate/procession/board_camera.gd` (the shot vocabulary + the three-clause
camera law carried in its comments). No code here. This is the contract.*

---

## 0. The ruling (producer-decided)

Alex, 2026-07-20, verbatim intent:

- Downtime is only downtime when you can't strategize.
- The roll camera must show what's upcoming.
- Movement must be followable.

The failure it names: today the roll holds a static whole-board overhead,
showing nothing you can plan against, while the figurines teleport-hop across a
diagram between turns. The eye can't follow, the mind can't scheme. The genre's
oldest sin in our clothes.

The direction (producer-decided):

- A **Smite-style high third-person camera** over your own figurine during
  quiet time. The player owns it — **zoom and rotate**.
- A **quarter-size PIP** window that follows whichever OTHER seat is acting,
  so you plan while you watch.
- **THE DIRECTOR** commandeers the whole frame only for appointment
  television: **Estate Stirs ceremonies, vendettas, FINAL BELL, arrivals.**

Below: that ruling made precise (**[LAW]**) or a proposal (**[PROPOSED]**).

## 1. Player-owned time vs director-owned time

**[LAW: the split. PROPOSED: the enumerations.]**

Two owners of the frame. Never both at once (§2).

**PLAYER-OWNED TIME** — the strategy layer. The camera answers to the player:
orbit, zoom, survey. This is doc 28 §9's "thinking budget" given a lens.

Enumerated (proposed):
- Your own ROLL PHASE — your figurine, the road ahead, the aim-heatmap stones
  glowing up-frame (doc 28 §15).
- Any OTHER seat's roll — your orbit stays live; the acting seat rides the PIP.
- Between-turn stillness — survey the board, read the three award races, price
  your next fork.
- Shopping at the Peddler's Cart; pre-commit planning (doc 35).

**DIRECTOR-OWNED TIME** — appointment television. The player's orbit yields;
the director takes the whole frame and tells the story. The ceremony grammar
of doc 24 lives here.

Enumerated:
- **[LAW]** Estate Stirs ceremonies — omens, the major/minor firing, the
  money-shot vocabulary (doc 28 §4).
- **[LAW]** Vendettas / GRUDGE MATCH — the two-shot duel (doc 24 F14).
- **[LAW]** FINAL BELL and arrivals — crossing the Manor Gate (doc 28 §8).
- **[PROPOSED]** the opening flyover/establish, the will-reading eulogy, night
  awards, the minigame roulette + GET READY. Ceremonies by nature; fold them
  under the director unless Alex wants any of them player-skippable.

The rule that decides disputes: **if the player could strategize during it, it
is player-owned. If it is a story the whole table must watch, it is the
director's.** Downtime dies in the first category; drama lives in the second.

Camera control does NOT spend the 4-button verb budget (doc 28 §0a). Orbit +
zoom live on the right stick / mouse — orthogonal to the face buttons.
**[PROPOSED]**

## 2. The three-clause camera ownership law  **[LAW]**

Carried from `board_camera.gd` and the wrong-way-stills post-mortem
(resume-the-eleventh/twelfth-watch). The bug: `executor_host`'s aim flag was
immortal — it re-aimed the shared camera at the host's own face EVERY FRAME,
beating the director's rotation. The cure was a law. It is now constitutional,
and the PIP forces it to grow a fourth clause.

The main camera has, every frame, exactly ONE authority. That authority must:

1. **Be CURRENT.** Ownership is explicit and handed off (`activate()` /
   `hold()`), never implicit, never immortal. An owner that has yielded writes
   nothing. An aim lives no longer than the owner's own tween
   (generation-tokened).
2. **Be the only POSITION driver.** The current owner is the sole writer of the
   main camera's `global_position` this frame. No second node touches it.
3. **Be the only AIMER.** The current owner is the sole writer of the main
   camera's `look_at`. No second node re-aims.

Handoff is the whole discipline. The director `activate()`s for appointment TV;
the player orbit yields to `hold()`. The appointment ends; the director
`hold()`s; the orbit reclaims CURRENT. One master at a time — the estate
answers to one camera.

**Clause 4 — the PIP is a separate world.  [PROPOSED, forced by the rework]**
The PIP is its own `Camera3D` in its own `SubViewport`, and never reads or
writes the main camera (nor the reverse). Two cameras, two independent owners,
zero cross-writes; clauses 1–3 apply to each on its own. The board feeds the
PIP the acting seat; the player owns the main frame. They cannot fight because
they cannot touch.

Determinism (doc 24 §0, unchanged): neither camera draws from the sim rng; sway
is a pure function of the clock; under `fast` both snap and the headless receipt
renders nothing.

## 3. The PIP spec sketch + the REQUIRED perf probe

**[PROPOSED spec. LAW: the probe gates the lane.]**

**Sketch:**
- **One** `SubViewport`. One PIP, ever. Never two. (A second render is the
  whole cost; a third is out of budget.)
- **Quarter-res.** The PIP is a thumbnail — render it at a quarter of the main
  viewport's linear resolution and let it be soft.
- **Aggressive far cull.** The PIP camera carries a short far-plane and a tight
  cull — it shows the acting seat and their immediate stones, not the whole
  estate. Board furniture beyond a few stones is culled hard.
- **Board-fed.** The PIP owner is the board; its content is the acting seat's
  over-shoulder / landing framing (§5) — shots that already exist, pointed at
  whoever's up.

**The probe (LAW — the rework lane does not open until this passes):**

A second scene render is not free. Before a line of the lane is written,
measure it:

- Scene: **the w6 forecourt framing** — the Manor Gate forecourt, the densest
  single view the board renders.
- Condition: **PIP live** — the second render active, following a seat.
- Metrics: **draw calls** and **frame time**, main + PIP combined.
- Budget: **< 1500 draw calls** combined, within the **integrated-GPU frame
  budget** (doc 28 §0a grounds bar — 60 fps ≈ 16.6 ms/frame, "gently push the
  no-real-GPU-needed spec without pushing it").

If PIP blows the budget on the forecourt, the fixes in priority order: harder
far cull → lower PIP res → cap the PIP to the acting seat's figurine + one
stone → PIP only during the roll phase. Do not open the lane on a hope.

## 4. Design once, use twice — Swap Meet  **[LAW: share the architecture]**

The PIP is one extra render target. Swap Meet's couch split-screen ask is up to
four — genuine split-screen, the one minigame that breaks doc 14's
shared-camera rule on purpose. (Producer punch-list; coupled to the camera-PIP
as "design once, use twice" — resume-the-twelfth-watch.) Same primitive
underneath: a pool of `SubViewport` render targets with a hard cap, a
quarter-res option, and per-view cull tuning. Doc 25 §3.2 already reparents a
launched module into a `SubViewportContainer` — the tech is in the tree.

Build a **ViewportKit** once:
- N extra `SubViewport`s from a fixed pool — cap enforced. The board takes 1;
  Swap Meet takes up to 4; nothing takes more.
- Per-view resolution scale + far-cull knobs. The PIP wants quarter-res + tight
  cull; a split-screen quadrant wants full res + normal cull.
- One place to measure, one place to cap.

The board PIP and Swap Meet's split-screen are the same kit at two settings.
Design once, use twice. The perf probe (§3) is the kit's first customer.

## 5. Migration — what survives, what dies  **[PROPOSED]**

The shot vocabulary in `board_camera.gd` is not thrown away. It is re-sorted
into the two owners.

**Survive (director-owned ceremony grammar):**
- `establish`, `flyover` — the opening tour.
- `two_shot` — the vendetta duel.
- `beacon_hero`, `standings` — the money-shots.
- `landing_push` — the type-aware close-up, now also the PIP's payoff frame.
- The Estate Stirs money-shot vocabulary; the eulogy / will-reading framing.

**Survive (roll-phase, re-homed):**
- `over_shoulder` — the acting seat's main frame AND the PIP's source. It
  already runs the heatmap stones up-frame — it was always "show what's
  upcoming." It only needed to stop being the ONLY seat's view.
- `travel_cut` + `landing_push` — followable movement for the acting seat, PIP
  content for the rest.

**Die:**
- **The forced whole-board overhead between turns.** This is the ruling's
  target: it shows nothing you can plan against. It becomes a *director beat
  only* — a deliberate reveal after an Estate Stir reroute, say — never the
  between-turn resting state. `whole_board` the shot lives; `whole_board` the
  resting state dies.
- **[PROPOSED]** `move_travel` (the all-four-at-once raking dolly, doc 24 F2)
  is demoted. Sequential single-seat movement is followed by the Smite camera /
  PIP, not a group dolly. Keep `move_travel` only if a simultaneous-move beat
  survives elsewhere; otherwise retire it.

## 6. Status + sequencing

- Sequenced **after** the G4 reaper drama (#81) and the grounds fill (#83) —
  producer, resume-the-twelfth-watch.
- The perf probe (§3) is the gate. It can run now against the w6 forecourt; it
  does not wait on the lane.
- Couples with doc 35 (pre-commit): a player-owned-time activity rendering in
  the surfaces this doc defines.
- Open for Alex: §1 director-time enumerations, §2 clause-4 PIP law, §3 budget
  numbers, §5 survivor list, camera-on-right-stick (§1).

над. нашу. присутствие. память.
