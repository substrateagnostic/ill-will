class_name GreedBots
extends RefCounted
## Seeded self-play bots (spec MUST). Each player gets one brain blending two
## drives, drawn from the seeded RNG so runs are reproducible per seed:
##   greed  — how fat the pot must get before this bot lunges for a grab
##   mugger — how eagerly it abandons the pot to chase & tackle the carrier
## To guarantee contest (not a solo-grabber runaway), the roster is seeded so at
## least one bot leans mugger and at least one leans greedy. decide() runs once
## per physics tick per player, in player order, so the RNG stream is
## deterministic.

## Playtest: "make greed bots contest the pot and intercept credibly (they
## currently can score 0 as pure muggers)." A heavy-mugger bot (high mugger[],
## high grab_threshold) could chase every carrier all match, whiff every
## tackle (dashes/distance save the carrier), and never once fall back to
## grabbing the pot directly — a real hunter would eventually give up a cold
## trail and take the sure thing instead. FRUSTRATION_LIMIT is how long a bot
## chases without landing a tackle before it does exactly that.
const FRUSTRATION_LIMIT := 6.0
const EAGER_WINDOW := 5.0     # after giving up a cold chase: how long the bot
                               # stays eager to grab instead of holding out
const EAGER_THRESHOLD := 9.0  # effective grab_threshold while eager (well under
                               # the 11-32 normal range, so the sure thing wins)

## VERIFY known-issue follow-up: "passive personality combo can still bank
## ZERO the whole match." drought_t (below) tracks seconds since a player's
## points last increased AT ALL — bank, floor coin, royalty, anything. It's
## the one signal in this file that's immune to every dead end an earlier pass
## kept tripping over: a from-scratch soak (seeds 1, 4, 6, 7) found THREE
## distinct ways a bot can go scoreless —
##   1. idling: mugger<=0.6 + a high grab_threshold means it never chases (pot
##      rarely gets fat, other bots keep resetting it) and never grabs (own
##      threshold never comes up first).
##   2. active-but-outmatched: a bot grabs/chases readily but a rival with a
##      hot mugger[] roll camps the pot and snipes every carrier in ~0.5s with
##      no cooldown — the victim never gets far enough away to have a chance.
##   3. carrier-stuck: unrelated to any of the above (see CARRY_STUCK_LIMIT).
## The first attempt at fix #1 used its own idle timer (guard_t, since
## removed) mirroring FRUSTRATION_LIMIT's "reset only on genuine progress"
## shape — but every plausible reset point turned out to have a false
## positive: pot flickering LOOSE for under a second after a distant drop,
## or `out["grab"]=true` firing every tick a bot is merely in range and
## HOLDING (the controller still needs GRAB_TIME=0.6s before a grab actually
## lands) all reset it prematurely, in different seeds, whack-a-mole style —
## each fix for one seed's false-reset promptly surfaced a different one.
## drought_t sidesteps the entire class of bug: it doesn't care WHAT the bot
## was attempting, only whether its POINTS actually went up, which is the one
## thing every one of those false positives had in common: none of them do.
## eager (below) is DROUGHT_EAGER_LIMIT seconds of scoring nothing OR the
## existing short frustrated-chase window — either way, holding out for a
## perfect opportunity loses to taking the sure thing.
const DROUGHT_EAGER_LIMIT := 15.0

## Second follow-up (case 2 above): once self-help via DROUGHT_EAGER_LIMIT
## still isn't enough — a player who's gone MERCY_DROUGHT seconds with NOTHING
## gets a break from non-droughted rivals' active chases (below). Two
## droughted players still fight each other normally; this only mutes a
## rival who's doing FINE from dogpiling one who's doing badly.
const MERCY_DROUGHT := 20.0

## Third follow-up (case 3 above, seed 6): the carrier's own steering is just
## "move straight at my chute" — no real pathfinding — so it can wedge into a
## crate/wall corner and never resolve (status log: carrier unchanged for
## 20+ seconds straight, holding a pot too cheap for anyone to bother
## contesting — an unrelated bug, not a threshold/personality one).
## CARRY_STUCK_LIMIT: if distance-to-goal hasn't meaningfully shrunk in this
## many seconds, the direct line is jammed; swing the heading off-axis (a
## fixed per-player angle, so it's deterministic, not dithering) and take a
## free/cheap dash to help punch through — a person shouldering past an
## obstacle at an angle instead of walking straight into it forever.
const CARRY_STUCK_LIMIT := 2.0

var rng := RandomNumberGenerator.new()
var grab_threshold: Array = []      # per player: pot value that triggers a grab
var mugger: Array = []              # per player 0..1: chase-the-carrier drive
var wander_ang: Array = []
var wander_t: Array = []
var chase_frustration: Array = []   # per player: seconds spent chasing since the last tackle landed
var eager_t: Array = []             # per player: >0 while eager after giving up a chase
var drought_t: Array = []           # per player: seconds since their points last increased at all
var points_seen: Array = []         # per player: last observed g.points[p], to detect the increase above
var carry_stuck_t: Array = []       # per player: seconds carrying with no meaningful progress toward the chute
var carry_last_dist: Array = []     # per player: last tick's distance-to-chute while carrying


func setup(seed_value: int, n: int) -> void:
	rng.seed = seed_value
	grab_threshold.clear()
	mugger.clear()
	wander_ang.clear()
	wander_t.clear()
	chase_frustration.clear()
	eager_t.clear()
	drought_t.clear()
	points_seen.clear()
	carry_stuck_t.clear()
	carry_last_dist.clear()
	for i in n:
		grab_threshold.append(rng.randf_range(11.0, 32.0))
		mugger.append(rng.randf_range(0.35, 0.95))
		wander_ang.append(rng.randf_range(0.0, TAU))
		wander_t.append(0.0)
		chase_frustration.append(0.0)
		eager_t.append(0.0)
		drought_t.append(0.0)
		points_seen.append(0)
		carry_stuck_t.append(0.0)
		carry_last_dist.append(-1.0)
	# guarantee drama: force one strong mugger and one eager grabber
	if n >= 2:
		mugger[0] = 0.9
		grab_threshold[0] = 26.0        # p0 hangs back and hunts
		grab_threshold[1] = 12.0
		mugger[1] = 0.4                 # p1 lunges for the pot early


## g is the greed.gd root. Returns {move: Vector2, grab: bool, tackle: bool,
## dash: bool}. The controller still validates ranges/cooldowns.
func decide(p: int, g, delta: float) -> Dictionary:
	var me: GreedPlayer = g.players[p]
	var out := {"move": Vector2.ZERO, "grab": false, "tackle": false, "dash": false}

	# Scoring-drought bookkeeping runs unconditionally (even stunned/can't-act)
	# so time-without-scoring keeps counting no matter WHY this player hasn't
	# scored — idling, chasing, or just repeatedly getting mugged. See
	# DROUGHT_EAGER_LIMIT / MERCY_DROUGHT above for why this is the one signal
	# in this file worth building the whole comeback logic on.
	var cur_points: int = int(g.points[p])
	if cur_points > int(points_seen[p]):
		drought_t[p] = 0.0
	else:
		drought_t[p] = float(drought_t[p]) + delta
	points_seen[p] = cur_points

	if not me.can_act():
		return out
	var my_pos := Vector2(me.global_position.x, me.global_position.z)

	eager_t[p] = maxf(0.0, float(eager_t[p]) - delta)
	# Eager if EITHER a short window after giving up a frustrated chase, OR a
	# sustained scoring drought — either way, the sure thing beats holding out.
	var eager: bool = float(eager_t[p]) > 0.0 or float(drought_t[p]) >= DROUGHT_EAGER_LIMIT

	if not me.is_carrier:
		carry_stuck_t[p] = 0.0
		carry_last_dist[p] = -1.0

	# ---- I am the carrier: run to my chute, dash if a hunter is closing ----
	if me.is_carrier:
		chase_frustration[p] = 0.0
		var goal: Vector2 = g.chute_pos(p)
		var to_goal := goal - my_pos
		var dist := to_goal.length()
		# Stuck-carrier escape (see CARRY_STUCK_LIMIT above): only counts
		# meaningful shrinkage as progress, so oscillating in place near a
		# corner still trips it.
		if float(carry_last_dist[p]) < 0.0 or dist < float(carry_last_dist[p]) - 0.25:
			carry_stuck_t[p] = 0.0
		else:
			carry_stuck_t[p] = float(carry_stuck_t[p]) + delta
		carry_last_dist[p] = dist
		var dir := to_goal.normalized() if dist > 0.2 else Vector2.ZERO
		var stuck: bool = float(carry_stuck_t[p]) > CARRY_STUCK_LIMIT
		if stuck and dir != Vector2.ZERO:
			dir = dir.rotated(deg_to_rad(65.0) * (1.0 if p % 2 == 0 else -1.0))
		out["move"] = dir
		var hunter_d := _nearest_other_dist(p, g, my_pos)
		if (hunter_d < 3.0 and g.pot_value > 6) or stuck:
			if me.dash_cd <= 0.0:
				out["dash"] = true
		return out

	var carrier: int = g.carrier_index
	# ---- someone else is carrying: mug them ----
	if carrier >= 0 and carrier != p:
		# MERCY (see MERCY_DROUGHT above): a rival who's gone this long without
		# scoring ANYTHING gets a break from a hunter who's doing fine — unless
		# I'm droughted too, in which case it's still a fair fight between two
		# strugglers. Bail before even looking at range/aim: this is "don't
		# bother," not "whiff on purpose."
		if float(drought_t[carrier]) >= MERCY_DROUGHT and float(drought_t[p]) < MERCY_DROUGHT:
			return _guard(p, g, my_pos, delta, out)
		var cp: GreedPlayer = g.players[carrier]
		var cpos := Vector2(cp.global_position.x, cp.global_position.z)
		# lead the carrier a touch so we cut them off, not tail them
		var cvel := Vector2(cp.velocity.x, cp.velocity.z)
		var aim := cpos + cvel * 0.12
		var to_c := aim - my_pos
		var d := my_pos.distance_to(cpos)
		# only worth mugging a pot with real value on it — small pots we let
		# bank so the cycle resets (prevents a grab/drop grieflock at centre).
		# A heavy mugger (mugger[p] > 0.6) is willing to engage a thinner pot
		# than a lukewarm one — its whole personality is denial, not the haul.
		# eager loosens the same bar for anyone else who's gone too long
		# without scoring.
		var worth_it: bool = g.pot_value >= (4.0 if (mugger[p] > 0.6 or eager) else 7.0)
		# A bot chasing without ever landing a tackle gives up after
		# FRUSTRATION_LIMIT seconds of continuous pursuit — a real hunter
		# doesn't chase a cold trail forever — and goes eager to grab for a
		# while instead (below).
		var frustrated: bool = float(chase_frustration[p]) >= FRUSTRATION_LIMIT
		var want_chase: bool = worth_it and not frustrated \
			and (mugger[p] > 0.6 or eager or g.pot_value >= grab_threshold[p] * 0.7)
		if want_chase:
			chase_frustration[p] = float(chase_frustration[p]) + delta
			out["move"] = to_c.normalized() if to_c.length() > 0.1 else Vector2.ZERO
			if d < g.TACKLE_RANGE * 0.95 and cp.can_be_tackled():
				out["tackle"] = true
			elif d > 2.4 and me.dash_cd <= 0.0:
				out["dash"] = true   # close the gap
			return out
		if frustrated:
			chase_frustration[p] = 0.0
			eager_t[p] = EAGER_WINDOW
		return _guard(p, g, my_pos, delta, out)

	# the hunt (if any) is over — reset the cold-trail clock for next time
	chase_frustration[p] = 0.0

	# ---- pot is grabbable (pedestal or loose): grab it if fat enough --------
	var pot_pos: Vector2 = g.pot_world_2d()
	var to_pot := pot_pos - my_pos
	var pd := to_pot.length()
	var opportunist: bool = g.pot_value >= 8 and pd < 2.4 and _am_closest_to_pot(p, g)
	# eager (drought or a just-abandoned cold chase): the sure thing beats
	# holding out for a fat pot that may never come.
	var effective_threshold: float = minf(float(grab_threshold[p]), EAGER_THRESHOLD) \
		if eager else float(grab_threshold[p])
	if g.pot_value >= effective_threshold or g.pot_state == g.PotState.LOOSE or opportunist:
		out["move"] = to_pot.normalized() if pd > 0.1 else Vector2.ZERO
		if pd < g.GRAB_RANGE * 0.85:
			out["grab"] = true
			out["move"] = Vector2.ZERO
		return out
	# not greedy enough yet: camp near the pedestal, poised to pounce or grab
	return _guard(p, g, my_pos, delta, out)


func _guard(p: int, g, my_pos: Vector2, delta: float, out: Dictionary) -> Dictionary:
	wander_t[p] -= delta
	if wander_t[p] <= 0.0:
		wander_t[p] = rng.randf_range(1.0, 2.2)
		wander_ang[p] += rng.randf_range(-1.3, 1.3)
	# loiter on my own side of the vault, between pot and chute — poised to
	# grab a fattening pot or cut off a banker, without swarming dead-centre
	var bias: Vector2 = g.chute_pos(p).normalized() * 2.9
	var orbit := Vector2(cos(wander_ang[p]), sin(wander_ang[p])) * 1.7
	var target := bias + orbit
	var to_t := target - my_pos
	out["move"] = to_t.normalized() if to_t.length() > 0.5 else Vector2.ZERO
	return out


func _nearest_other_dist(p: int, g, my_pos: Vector2) -> float:
	var best := 999.0
	for q in g.players.size():
		if q == p:
			continue
		var o: GreedPlayer = g.players[q]
		var d: float = Vector2(o.global_position.x, o.global_position.z).distance_to(my_pos)
		best = minf(best, d)
	return best


func _am_closest_to_pot(p: int, g) -> bool:
	var pot_pos: Vector2 = g.pot_world_2d()
	var mine: float = Vector2(g.players[p].global_position.x, g.players[p].global_position.z).distance_to(pot_pos)
	for q in g.players.size():
		if q == p:
			continue
		var o: GreedPlayer = g.players[q]
		if not o.can_act() or o.is_carrier:
			continue
		var d: float = Vector2(o.global_position.x, o.global_position.z).distance_to(pot_pos)
		if d < mine:
			return false
	return true
