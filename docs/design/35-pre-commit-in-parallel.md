# 35 — PRE-COMMIT IN PARALLEL

*Night 7 lane (2026-07-20). The RA §2 recommendation-3
(research-night7/RA-board-design.md) that "fell through every crack"
(resume-the-twelfth-watch), promoted to a spec proposal. Reads with doc 28
(§5 the roll, §9 downtime, the §15 addendum resolution-order rules), doc 34
(the camera constitution — pre-commit renders in player-owned time), doc 24.
Terse. No code.*

---

## 0. The idea

RA §2, verbatim: *"While player A rolls, B/C/D pre-pick their fork and pre-buy
from the cart on their own screen-corner, so their turn resolves instantly when
it comes around."*

Sequential rolls restored the genre's oldest tax: ~half a session watching
other people move (RA §2). The frequent all-play minigame is one re-sync;
pre-commit is the other. A waiting seat that has already chosen resolves in a
blink when its turn lands. The dead air between turns becomes planning — and the
planning was going to happen anyway. Pre-commit just moves it earlier and hides
the latency.

Bots already do this. Pre-commit is the human catching up to the bot (§4).

## 1. What is pre-committable — and what is NOT  **[the hard constraint]**

**THE CONSTRAINT (state it first; it decides everything):** anything that draws
from a sim rng stream at commit time is NOT pre-committable. Draws happen at
**resolution**, in **seat order** — never at commit. Pre-commit records an
**intent** (a menu choice), nothing more. The intent is replayed at the seat's
own resolution slot, where the real draw (if any) fires in canonical order.
Receipts stay byte-identical **by construction** — no rng stream is touched a
moment early, and no draw is reordered.

**Pre-committable (intent only, no draw at commit):**
- **The crossroads fork** — pick garden / hollow / valley ahead of your turn.
  Routing is deterministic; applied when you move.
- **A Peddler's Cart pre-buy** — but only from the cart's **fixed** inventory
  (doc 28 §6 — fixed prices, fixed stock). Deterministic. Safe.
- **An item arm** — queue which item you'll use and its target. Target
  selection is deterministic (you name a rival). Applied at your resolution
  slot, in seat order (doc 28 §15 resolution rules).

**NOT pre-committable (draws rng at commit):**
- **The roll itself** — the LAST BREATH meter is a live skill input, and the d8
  draw lands at release (doc 28 §5). You cannot pre-release.
- **GRAVE GOODS / any random box** — the item is an rng draw. Open it at
  resolution or not at all.
- **The Séance wheel** — the slot is drawn from the events stream. Spun at
  resolution.
- Anything whose outcome is a seeded draw. The intent may point AT it; the
  result is decided in seat order.

Validation is at resolution, and resolution is authoritative. If a
pre-committed fork is voided by an Estate Stir reroute (doc 28 §4), or you never
reach the cart, or the pennies moved out from under a pre-buy — the intent is
discarded or re-prompted. Pre-commit is a convenience, never a lock on a world
that changed.

## 2. Input model — the 4-button verb budget on a waiting seat

The verb budget (doc 28 §0a: four buttons, on-turn) is a **per-context** budget.
A waiting seat is not on-turn — it spends none of its on-turn verbs. So the same
four face buttons carry a different, small verb set while waiting, and never
more than four are live at once.

Waiting-seat contexts share the face buttons:
- **Default waiting** — REACT glyphs / heckle (doc 28 §9, the F24 system).
- **PLAN mode** — the pre-commit tray. The four faces become: **fork · cart ·
  item-arm · confirm** (cancel = back).

**[PROPOSED]** Enter PLAN from a shoulder button (or a held face button);
release returns to REACT. One toggle, no new on-turn verbs, budget intact. See
§6 Q4.

## 3. UI — rendering without stealing the active frame

Pre-commit is a **player-owned-time** activity (doc 34 §1). It renders in
player-owned surfaces — never the director's frame, never over the acting seat's
roll.

- **Online / one-human** (doc 28 §12): the planner's screen is their own. The
  pre-commit tray lives in **their** quiet-time frame — beside their Smite orbit
  (doc 34) — while the acting seat rides the PIP. No contention: your plan is on
  your screen.
- **Shared couch, four humans, one screen** (doc 14 — ILL WILL is
  shared-camera, not split-screen): the acting seat owns the main 3D frame. A
  waiting seat's pre-commit renders in its **HUD lane** — its standings chip
  expands into a small plan card (fork icon, queued item, cart selection). It
  does **not** open a second 3D view on the shared screen. The board stays
  legible; the roll stays center-stage.

Either way the rule holds: **the pre-commit UI never touches the active seat's
frame.** It ties straight to doc 34's split — planning is quiet-time, quiet-time
is the player's, and the player's surfaces are theirs alone.

**[PROPOSED]** The couch plan-card is HUD-only; the Smite orbit is a per-client
luxury (online / vs-bots). Confirm against doc 34 §1.

## 4. Bots — human-parity, zero sim change

Bots already decide at resolution, in queue order, with a single host rng draw
per release (doc 28 §5). They have no latency to hide — they compute the instant
their slot comes up.

Pre-commit gives the human that same instantness. It changes **nothing** about
the bot path: no new decision code, no new draw, no reordering. The bot resolves
as it always did; the human, having pre-filled an intent, now resolves just as
fast. Pre-commit is human parity with the bots — closing a UX gap, not a sim
gap.

This is why it is safe by design. The sim already assumes every seat's choice is
available at its resolution slot — that is how bots run. Pre-commit changes only
*when the human supplied it* (earlier, off-turn), not *when it is applied* (its
slot, in order).

## 5. Receipts analysis

**Presentation-only (no receipt surface):**
- The PLAN tray, the intent buffer, the HUD plan-card / quiet-time render.
- Fork pre-pick — deterministic routing, applied at your move.
- Fixed-cart pre-buy — deterministic price + stock.
- Item-arm + target selection — deterministic choice.

These record a choice and replay it exactly where the on-turn prompt would have
stood. No rng stream is read at commit. No draw moves. **Receipts byte-identical
by construction.**

**Touches resolution order (handle with care, NOT the first ship):**
- Item application order. Doc 28 §15 fixes the rules: movement items apply
  before travel; offensive items don't stack per target per roll; reposition
  effects don't trigger crossed spaces. A pre-armed item MUST still resolve in
  the seat's canonical slot, in that order — never early because it was queued
  early. Honor that and item-arm stays presentation-only; violate it and
  receipts drift.
- Anything reaching for a random box / séance / roll — excluded already by §1's
  constraint.

**SHIP-FIRST (the safe subset):**
> Fork pre-pick + fixed-cart pre-buy + item-arm-with-target — each recorded as
> intent, replayed at resolution in seat order, validated (discarded on reroute
> / no-land / no-funds). This subset touches **no** rng at commit and reorders
> **no** draw. It is receipts-safe by construction. Ship it first. Everything
> richer waits behind a receipt.

## 6. OPEN QUESTIONS (producer)

1. **Couch pre-commit UI** — where does a waiting seat's plan render on the
   shared screen?
   (a) standings chip expands to a plan card · (b) a fixed corner tray ·
   (c) couch shows nothing — pre-commit is online / vs-bots only ·
   (d) (a) by default, richer online.
2. **Invalidated fork** (Estate Stir reroute mid-cycle) —
   (a) silently discard + re-prompt at your turn · (b) auto-pick the nearest
   equivalent fork · (c) flash "your route changed," re-prompt.
3. **Pre-buy you can't afford at resolution** (pennies moved) —
   (a) cancel the buy · (b) buy the cheapest affordable item · (c) hold the
   intent, buy when affordable.
4. **PLAN vs REACT on the same buttons** —
   (a) hold-to-plan modal · (b) a dedicated toggle button · (c) a shoulder
   button opens the plan tray.
5. **Pre-commit during the FINAL BELL last turn** — the homestretch is a
   shared-attention beat (doc 28 §8).
   (a) pre-commit stays ON throughout · (b) OFF during the last turn, everyone
   watches the bell.
6. **Scope of the first ship** — the §5 SHIP-FIRST subset, or fork-pre-pick
   alone as the smallest proof?
   (a) full SHIP-FIRST subset · (b) fork-only first, cart + item-arm next.

над. нашу. присутствие. память.
