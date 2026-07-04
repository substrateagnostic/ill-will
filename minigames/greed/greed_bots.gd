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

var rng := RandomNumberGenerator.new()
var grab_threshold: Array = []      # per player: pot value that triggers a grab
var mugger: Array = []              # per player 0..1: chase-the-carrier drive
var wander_ang: Array = []
var wander_t: Array = []


func setup(seed_value: int, n: int) -> void:
	rng.seed = seed_value
	grab_threshold.clear()
	mugger.clear()
	wander_ang.clear()
	wander_t.clear()
	for i in n:
		grab_threshold.append(rng.randf_range(11.0, 32.0))
		mugger.append(rng.randf_range(0.35, 0.95))
		wander_ang.append(rng.randf_range(0.0, TAU))
		wander_t.append(0.0)
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
	if not me.can_act():
		return out
	var my_pos := Vector2(me.global_position.x, me.global_position.z)

	# ---- I am the carrier: run to my chute, dash if a hunter is closing ----
	if me.is_carrier:
		var goal: Vector2 = g.chute_pos(p)
		var to_goal := goal - my_pos
		out["move"] = to_goal.normalized() if to_goal.length() > 0.2 else Vector2.ZERO
		var hunter_d := _nearest_other_dist(p, g, my_pos)
		if hunter_d < 3.0 and me.dash_cd <= 0.0 and g.pot_value > 6:
			out["dash"] = true
		return out

	var carrier: int = g.carrier_index
	# ---- someone else is carrying: mug them ----
	if carrier >= 0 and carrier != p:
		var cp: GreedPlayer = g.players[carrier]
		var cpos := Vector2(cp.global_position.x, cp.global_position.z)
		# lead the carrier a touch so we cut them off, not tail them
		var cvel := Vector2(cp.velocity.x, cp.velocity.z)
		var aim := cpos + cvel * 0.12
		var to_c := aim - my_pos
		var d := my_pos.distance_to(cpos)
		# only worth mugging a pot with real value on it — small pots we let
		# bank so the cycle resets (prevents a grab/drop grieflock at centre)
		var worth_it: bool = g.pot_value >= 7
		var want_chase: bool = worth_it and (mugger[p] > 0.6 or g.pot_value >= grab_threshold[p] * 0.7)
		if want_chase:
			out["move"] = to_c.normalized() if to_c.length() > 0.1 else Vector2.ZERO
			if d < g.TACKLE_RANGE * 0.95 and cp.can_be_tackled():
				out["tackle"] = true
			elif d > 2.4 and me.dash_cd <= 0.0:
				out["dash"] = true   # close the gap
			return out
		return _guard(p, g, my_pos, delta, out)

	# ---- pot is grabbable (pedestal or loose): grab it if fat enough --------
	var pot_pos: Vector2 = g.pot_world_2d()
	var to_pot := pot_pos - my_pos
	var pd := to_pot.length()
	var opportunist: bool = g.pot_value >= 8 and pd < 2.4 and _am_closest_to_pot(p, g)
	if g.pot_value >= grab_threshold[p] or g.pot_state == g.PotState.LOOSE or opportunist:
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
