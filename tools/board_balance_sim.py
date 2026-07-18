"""ILL WILL board-rework balance simulator (night 7, design phase).

Simulates 3-night games of the proposed unified board mode under three
night-ending variants, 10k games each, and reports the balance metrics the
design doc (28) needs:

  A  FINAL BELL      - board resets nightly; first crossing rings the bell,
                       everyone else gets exactly one more turn, then arrival
                       wreaths 10/7/4/2 are paid by arrival order (unfinished
                       pawns ranked by distance). Turn-cap 12 fallback.
  B  LONG PROCESSION - one continuous 120-stone board across all 3 nights;
                       each night is a fixed 8 turns; NO arrival scoring at
                       all (wreaths come only from minigames + awards +
                       liquidation).
  C  HYBRID WARP     - continuous board, fixed 8-turn nights, but crossing
                       the finish pays a one-time +8 wreaths and warps the
                       pawn back to the gate (MP star-loop style).

Economy under test (from RA-board-design.md sections 6-7):
  pennies  (shop):    minigame payout 10/6/3/1 per cycle; spaces +-; items.
  wreaths  (victory): minigame placement 3/2/1/0 per cycle; arrival (A/C);
                      3 announced night awards x4 wreaths; liquidation
                      floor(pennies/10) at game end.

Roll: R-D candidate B (d6, geometric kernel k=1.6, crit k=3.2).

Usage:  python tools/board_balance_sim.py [--games 10000] [--seed 7]
"""

import argparse
import random
from collections import defaultdict

N_FACES = 6          # overridable via --faces (die-size study, night 7)
BIAS_K = 1.6
CRIT_K = 3.2

PENNY_PAYOUT = [10, 6, 3, 1]        # minigame placements 1st..4th
MINIGAME_WREATHS = [2, 1, 1, 0]     # per-cycle victory points (v2 tuning held)
SEANCE_WREATH_CHANCE = 0.30         # v2: share of seance events that swing a wreath
RUBBER_DISCOUNT = 0.7               # v2: last place buys at 30% off (MP2/3)
ARRIVAL_WREATHS = [10, 7, 4, 2]     # variant A, by arrival/distance order
CROSSING_BONUS_C = 8                # variant C one-time crossing prize
AWARD_WREATHS = 4                   # per announced night award (3 per night)
LIQUIDATION_RATE = 10               # pennies per wreath at game end

TRACK_A = 40                        # stones, nightly board (variant A); --track
TRACK_BC = 120                      # stones, continuous board (B and C)
TURN_CAP_A = 12
TURNS_BC = 8

# Space-landing distribution per RA ratios (plain 45, offering 20, event 15,
# box 8, grave 5, toll 4, remainder forks handled as route modifiers).
SPACES = [("plain", 0.45), ("offering", 0.20), ("event", 0.15),
          ("box", 0.08), ("grave", 0.05), ("toll", 0.04), ("plain2", 0.03)]


def weight_kernel(p, k):
    c = 1.0 + max(0.0, min(1.0, p)) * (N_FACES - 1)
    raw = [k ** -abs(i - c) for i in range(1, N_FACES + 1)]
    t = sum(raw)
    return [w / t for w in raw]


def sample_face(weights, rng):
    r = rng.random()
    acc = 0.0
    for i, w in enumerate(weights):
        acc += w
        if r < acc:
            return i + 1
    return N_FACES


class Player:
    def __init__(self, idx, mg_skill, roll_sd, crit_rate):
        self.idx = idx
        self.mg_skill = mg_skill      # minigame strength (Plackett-Luce weight)
        self.roll_sd = roll_sd        # slider release noise
        self.crit_rate = crit_rate    # chance a deliberate crit lands
        self.reset_game()

    def reset_game(self):
        self.wreaths = 0
        self.pennies = 5
        self.pos = 0
        self.mg_wins = 0
        self.spaces_moved = 0
        self.graves = 0
        self.pennies_earned = 0
        self.pennies_spent = 0
        self.arrivals = []            # arrival ranks collected (variant A)
        self.item_boost = 0           # pending +move from LUCKY PENNY etc.

    def roll(self, rng, want_high):
        # players aim high when behind on the track, mid otherwise
        target_p = 0.95 if want_high else 0.6
        p = max(0.0, min(1.0, rng.gauss(target_p, self.roll_sd)))
        k = CRIT_K if rng.random() < self.crit_rate else BIAS_K
        return sample_face(weight_kernel(p, k), rng)


def play_minigame(players, rng):
    """Plackett-Luce placement draw weighted by minigame skill."""
    pool = list(players)
    order = []
    while pool:
        weights = [p.mg_skill * rng.uniform(0.5, 1.5) for p in pool]
        total = sum(weights)
        r = rng.random() * total
        acc = 0.0
        for i, w in enumerate(weights):
            acc += w
            if r < acc:
                order.append(pool.pop(i))
                break
        else:
            order.append(pool.pop())
    return order  # 1st..4th


def land_space(pl, rng):
    r = rng.random()
    acc = 0.0
    for name, prob in SPACES:
        acc += prob
        if r < acc:
            break
    if name == "offering":
        pl.pennies += 3
        pl.pennies_earned += 3
    elif name == "event":
        if rng.random() < SEANCE_WREATH_CHANCE:
            pl.wreaths += rng.choice([-1, 1, 1])   # seance touches the will itself
            pl.wreaths = max(0, pl.wreaths)
        else:
            swing = rng.choice([-2, -1, 1, 2, 3])
            pl.pennies = max(0, pl.pennies + swing)
            if swing > 0:
                pl.pennies_earned += swing
    elif name == "box":
        pl.item_boost += rng.choice([1, 1, 2])   # free movement trinket
    elif name == "grave":
        pl.pennies = max(0, pl.pennies - 3)
        pl.graves += 1
    elif name == "toll":
        pl.pennies = max(0, pl.pennies - 2)


def shop(pl, players, leader, rng):
    """One buy opportunity per turn cycle, greedy strategy. Last place on the
    wreath tally shops at a discount (MP2/3 rubber-banding, legible/opt-in);
    sabotage appetite scales with wreath deficit (social catch-up, R-A 3b)."""
    last = min(players, key=lambda q: q.wreaths)
    disc = RUBBER_DISCOUNT if pl is last else 1.0
    bell_cost = int(12 * disc)
    crow_cost = int(10 * disc)
    lucky_cost = max(3, int(5 * disc))
    deficit = max(0, max(q.wreaths for q in players) - pl.wreaths)
    aggro = min(1.6, 1.0 + deficit / 25.0)
    if pl.pennies >= bell_cost and pl is not leader \
            and rng.random() < 0.4 * aggro:
        pl.pennies -= bell_cost                   # FUNERAL BELL: leader -3
        pl.pennies_spent += bell_cost
        leader.pos = max(0, leader.pos - 3)
    elif pl.pennies >= crow_cost and pl.pennies < 20 and pl is not leader \
            and rng.random() < 0.3 * aggro:
        pl.pennies -= crow_cost                   # CROW'S CUT: steal 5
        pl.pennies_spent += crow_cost
        victim = leader if leader.pennies >= 5 else max(
            players, key=lambda q: q.pennies)
        take = min(5, victim.pennies)
        victim.pennies -= take
        pl.pennies += take
        pl.pennies_earned += take
    elif pl.pennies >= lucky_cost and rng.random() < 0.5:
        pl.pennies -= lucky_cost                  # LUCKY PENNY: +2 next roll
        pl.pennies_spent += lucky_cost
        pl.item_boost += 2


def pick_leader(players, rng, track_len=None):
    """Random among tied maxima - the real game breaks ties by player choice.
    Pawns already home (through the gate) are beyond the reach of grudges."""
    pool = players
    if track_len is not None:
        on_track = [q for q in players if q.pos < track_len]
        if on_track:
            pool = on_track
    best = max(q.pos for q in pool)
    return rng.choice([q for q in pool if q.pos == best])


def take_turn(pl, players, track_len, rng):
    leader = pick_leader(players, rng, track_len)
    want_high = pl.pos < leader.pos or pl is leader
    move = pl.roll(rng, want_high) + pl.item_boost
    pl.item_boost = 0
    pl.pos += move
    pl.spaces_moved += move
    land_space(pl, rng)
    shop(pl, players, leader, rng)
    return pl.pos >= track_len


AWARD_POOL = [
    ("BLOODIEST HAND", lambda p: p.mg_wins),          # skill
    ("LONGEST PROCESSION", lambda p: p.spaces_moved), # roll luck
    ("MOST MOURNED", lambda p: p.graves),             # inverse luck
    ("HEAVY PURSE", lambda p: p.pennies_earned),      # earning behavior
    ("GENEROUS TO A FAULT", lambda p: p.pennies_spent),  # spending behavior
]


def night_awards(players, rng):
    """3 of 5 awards drawn and announced at night start (Jamboree Pro Rules:
    announced, races visible mid-night - never a hidden lottery)."""
    for _, key in rng.sample(AWARD_POOL, 3):
        top = max(key(p) for p in players)
        if top > 0:
            best = rng.choice([p for p in players if key(p) == top])
            best.wreaths += AWARD_WREATHS


def run_cycle(players, order_idx, track_len, rng, variant, night_state):
    """One cycle = sequential rolls for all seats + one minigame."""
    crossed = []
    for i in order_idx:
        pl = players[i]
        if variant == "A" and pl.pos >= track_len:
            continue                         # crossed pawns rest at the gate
        done = take_turn(pl, players, track_len, rng)
        if done:
            if variant == "A":
                pl.pos = track_len           # lock at the gate (no overshoot race)
                crossed.append(pl)
            elif variant == "C":
                pl.wreaths += CROSSING_BONUS_C
                pl.pos -= track_len          # warp back through the gate
    order = play_minigame(players, rng)
    for rank, pl in enumerate(order):
        pl.pennies += PENNY_PAYOUT[rank]
        pl.pennies_earned += PENNY_PAYOUT[rank]
        pl.wreaths += MINIGAME_WREATHS[rank]
    order[0].mg_wins += 1
    return crossed


def roll_order(players, rng):
    """Design rule: roll order = current wreath standings, LEADER FIRST.
    Leader commits blind; trailers act with full information. Ties random."""
    ranked = sorted(players, key=lambda p: (-p.wreaths, rng.random()))
    return [p.idx for p in ranked]


def play_night(players, rng, variant, night_no):
    if variant == "A":
        for pl in players:
            pl.pos = 0
        turns = 0
        arrived = []                 # players in true crossing order
        bell = False
        bell_turns_left = 0
        while True:
            turns += 1
            crossed = run_cycle(players, roll_order(players, rng), TRACK_A,
                                rng, "A", {})
            arrived.extend(crossed)
            if not bell and (crossed or turns >= TURN_CAP_A):
                bell = True
                bell_turns_left = 1 if crossed else 0   # cap fires: no extra
            elif bell:
                bell_turns_left -= 1
            if bell and bell_turns_left < 0 or (bell and bell_turns_left == 0):
                break
        # arrival order: crossing order first, then distance; ties random
        rest = sorted([p for p in players if p not in arrived],
                      key=lambda p: (-p.pos, rng.random()))
        for rank, pl in enumerate(arrived + rest):
            pl.wreaths += ARRIVAL_WREATHS[rank]
            pl.arrivals.append(rank)
        night_awards(players, rng)
        return turns
    else:
        for _ in range(TURNS_BC):
            run_cycle(players, roll_order(players, rng), TRACK_BC, rng,
                      variant, {})
        night_awards(players, rng)
        return TURNS_BC


def play_game(rng, variant, skills):
    players = [Player(i, *skills[i]) for i in range(4)]
    night1_leader = None
    night1_last = None
    night_lengths = []
    for night in range(3):
        night_lengths.append(play_night(players, rng, variant, night))
        if night == 0:
            ranked = sorted(players, key=lambda p: (-p.wreaths, rng.random()))
            night1_leader = ranked[0].idx
            night1_last = ranked[-1].idx
    for pl in players:
        pl.wreaths += pl.pennies // LIQUIDATION_RATE
    # final tie-break: pennies, then a coin flip (real game: a sudden-death duel)
    final = sorted(players, key=lambda p: (-p.wreaths, -p.pennies, rng.random()))
    return {
        "winner": final[0].idx,
        "final": final,
        "night1_leader": night1_leader,
        "night1_last": night1_last,
        "night_lengths": night_lengths,
        "players": players,
    }


def run_variant(variant, games, seed, skills, label):
    rng = random.Random(seed)
    wins = defaultdict(int)
    snowball = comeback = robbed = 0
    gaps = []
    lengths = []
    skilled_wins = 0
    for _ in range(games):
        g = play_game(rng, variant, skills)
        wins[g["winner"]] += 1
        if g["winner"] == g["night1_leader"]:
            snowball += 1
        last = next(p for p in g["players"] if p.idx == g["night1_last"])
        rank_of_last = g["final"].index(last)
        if rank_of_last <= 1:
            comeback += 1
        best_mg = max(g["players"], key=lambda p: p.mg_wins)
        if best_mg.idx != g["winner"]:
            robbed += 1
        gaps.append(g["final"][0].wreaths - g["final"][-1].wreaths)
        lengths.extend(g["night_lengths"])
        if g["winner"] == 0:
            skilled_wins += 1
    n = float(games)
    print(f"\n=== VARIANT {variant} - {label} ({games} games) ===")
    print(f"  win rates by seat:      "
          + "  ".join(f"P{i}:{wins[i]/n:5.1%}" for i in range(4)))
    print(f"  snowball  (n1 leader wins game):        {snowball/n:6.1%}")
    print(f"  comeback  (n1 last finishes top-2):     {comeback/n:6.1%}")
    print(f"  robbed    (best minigamer loses game):  {robbed/n:6.1%}")
    print(f"  skilled-seat win rate (P0):             {skilled_wins/n:6.1%}")
    print(f"  avg night length (turns):               "
          f"{sum(lengths)/len(lengths):5.2f}")
    print(f"  avg 1st-vs-4th wreath gap:              "
          f"{sum(gaps)/len(gaps):5.1f}")


def main():
    global N_FACES, TRACK_A
    ap = argparse.ArgumentParser()
    ap.add_argument("--games", type=int, default=10000)
    ap.add_argument("--seed", type=int, default=7)
    ap.add_argument("--equal", action="store_true",
                    help="all seats identical skill (seat-order fairness check)")
    ap.add_argument("--skill", type=float, default=1.35,
                    help="P0 minigame skill multiplier (default 1.35)")
    ap.add_argument("--faces", type=int, default=6,
                    help="die size (default 6)")
    ap.add_argument("--track", type=int, default=40,
                    help="variant-A nightly track length (default 40)")
    ap.add_argument("--variant", choices=["A", "B", "C", "all"], default="all")
    args = ap.parse_args()

    N_FACES = args.faces
    TRACK_A = args.track

    if args.equal:
        skills = [(1.0, 0.06, 0.18)] * 4
    else:
        # P0 skilled, P1-P2 average, P3 weak: (mg_skill, roll_sd, crit_rate)
        skills = [(args.skill, 0.045, 0.30), (1.0, 0.06, 0.18),
                  (1.0, 0.06, 0.18), (0.75, 0.09, 0.10)]

    print("ILL WILL board rework - Monte Carlo balance sim")
    print(f"seed={args.seed}  games/variant={args.games}  "
          f"d{args.faces}  track={args.track}")
    if args.equal:
        print("skills: ALL SEATS EQUAL (fairness check)")
    else:
        print(f"skills: P0 skilled ({args.skill}), P1-P2 avg, P3 weak (0.75)")
    if args.variant in ("A", "all"):
        run_variant("A", args.games, args.seed, skills,
                    f"FINAL BELL (d{args.faces}, track {args.track})")
    if args.variant in ("B", "all"):
        run_variant("B", args.games, args.seed, skills,
                    "LONG PROCESSION (continuous, no arrival scoring)")
    if args.variant in ("C", "all"):
        run_variant("C", args.games, args.seed, skills,
                    "HYBRID WARP (continuous, +8 crossing, loop)")


if __name__ == "__main__":
    main()
