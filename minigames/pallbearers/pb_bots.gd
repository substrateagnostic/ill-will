class_name PBBots
extends RefCounted
## Seeded self-play pallbearers for PALLBEARERS. A carry is COOPERATIVE within a
## pair and COMPETITIVE between pairs, so bots must do two hard things well:
##   1. COORDINATE with their partner. Two bots on a team compute the SAME target
##      direction, so their blended sticks agree and the coffin runs smooth. A bot
##      paired with a lone human FOLLOWS the human's lead (matches their stick) so
##      the human's partner never fights them into a drop.
##   2. Read hazards — wait out a closing gate, slow for a mourner procession,
##      heave (a synced hop) over mud — and MASH to restuff a dropped deceased,
##      chasing it first if it ran away downhill.
##
## BEATABLE, not braindead: bots carry at ~0.88 pace, and each bot occasionally
## FUMBLES — a brief stumble where it pulls the wrong way (more often on slick
## mud), which diverges the carry and sometimes drops the coffin. A coordinated
## human pair that never fumbles out-carries them. Fumbles + gate/mourner
## misjudgment are all seeded, so bot-only runs are byte-reproducible per seed.
## decide() runs once per physics tick per carrier, in slot order, off a seeded RNG.

var rng := RandomNumberGenerator.new()
var skill: Array = []                  # per-slot: higher = fewer fumbles, better timing
var _fumble_cd: Array = []
var _fumble_t: Array = []
var _fumble_dir: Array = []
var _lane_bias: Array = []             # a small fixed lane offset (bearers aren't perfectly aligned)


func setup(seed_value: int, n_slots: int) -> void:
	# Hash + warm the RNG: consecutive integer seeds share correlated initial PCG
	# outputs, which would systematically favour one lane's slots. Hashing and
	# discarding the first draws decorrelates seeds so neither team is advantaged.
	rng.seed = hash(seed_value * 2654435761 + 1013904223)
	for _w in 12:
		rng.randf()
	skill.clear(); _fumble_cd.clear(); _fumble_t.clear(); _fumble_dir.clear(); _lane_bias.clear()
	for i in n_slots:
		skill.append(rng.randf_range(0.42, 0.84))
		_fumble_cd.append(rng.randf_range(2.5, 6.5))
		_fumble_t.append(0.0)
		_fumble_dir.append(Vector2.ZERO)
		_lane_bias.append(rng.randf_range(-0.25, 0.25))


## Returns {move: Vector2, hop: bool, mash: bool} for carrier `slot`. The
## controller validates every effect (blend, divergence, restuff) exactly as it
## does for a human.
func decide(slot: int, g, delta: float, partner_stick: Vector2, partner_human: bool) -> Dictionary:
	var out := {"move": Vector2.ZERO, "hop": false, "mash": false}
	var team: int = g.slot_team(slot)
	var tp: int = g.team_phase(team)
	var cpos: Vector2 = g.coffin_pos2(team)
	var mypos: Vector2 = g.carrier_pos2(slot)

	# --- dropped / restuff: chase the deceased, then mash it home ---
	if tp == g.TeamPhase.RUNAWAY:
		var to_c := cpos - mypos
		out["move"] = to_c.normalized() if to_c.length() > 0.3 else Vector2.ZERO
		return out
	if tp == g.TeamPhase.DROPPED or tp == g.TeamPhase.RESTUFF:
		# always attempt to mash (the controller only counts it once both bearers
		# are at the coffin and it is in the RESTUFF phase); drift toward the box
		var to_c := cpos - mypos
		out["move"] = to_c.normalized() if to_c.length() > 0.4 else Vector2.ZERO
		out["mash"] = rng.randf() < 0.6
		return out
	if tp == g.TeamPhase.DONE:
		return out

	# --- CARRY: the cooperative steer ---
	var in_mud: bool = g.team_in_mud(team)

	# FUMBLE clock: occasionally the bot stumbles and pulls the wrong way for a
	# beat (more often on mud). This is the imperfection that makes bots beatable
	# and gives the demo its drops.
	if float(_fumble_t[slot]) > 0.0:
		_fumble_t[slot] = float(_fumble_t[slot]) - delta
	elif float(_fumble_cd[slot]) <= 0.0:
		_fumble_cd[slot] = rng.randf_range(3.0, 7.0) * (0.7 if in_mud else 1.0)
		var p_fumble: float = (1.0 - float(skill[slot])) * (1.35 if in_mud else 0.8)
		if rng.randf() < p_fumble:
			_fumble_t[slot] = rng.randf_range(0.4, 0.8)
			var ang := rng.randf_range(-1.3, 1.3)
			_fumble_dir[slot] = Vector2(sin(ang), 0.35)   # hard lateral + a touch backward
	else:
		_fumble_cd[slot] = float(_fumble_cd[slot]) - delta

	if float(_fumble_t[slot]) > 0.0:
		# mid-stumble: pull off-line (the controller reads the divergence)
		out["move"] = (_fumble_dir[slot] as Vector2).normalized() * 0.8
		return out

	# base intent: forward toward the crypt (y = -1), nudged to lane centre + bias
	var center: float = g.lane_center_x(team) + float(_lane_bias[slot])
	var steer_x := clampf((center - cpos.x) * 0.6, -0.7, 0.7)
	var desired := Vector2(steer_x * 0.5, -1.0)

	# hazard: a closing gate just ahead — bots cut it a little close (greedy), so
	# some approaches get clipped as the bar swings across.
	if g.gate_blocks_ahead(team):
		desired = Vector2(steer_x * 0.4, 0.0)
	# hazard: a mourner procession across the lane — slow to a crawl
	var block: float = g.mourner_block(team)
	if block > 0.05:
		desired.y *= maxf(0.0, 1.0 - block * 1.25)

	# FOLLOW A HUMAN PARTNER: match their stick to keep divergence low
	if partner_human and partner_stick.length() > 0.15:
		var lead := partner_stick.normalized()
		desired = (lead * 0.6 + desired.normalized() * 0.4)

	if desired.length() > 1.0:
		desired = desired.normalized()
	out["move"] = desired * 0.88

	# HEAVE over mud: a SYNCED hop clears the patch. Both carriers read the same
	# team hop-window, so they hop the same tick and the controller rewards it.
	if g.hop_window(team):
		out["hop"] = (not partner_human) or rng.randf() < 0.5
	return out
