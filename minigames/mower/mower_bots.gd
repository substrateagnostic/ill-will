class_name MowerBots
extends RefCounted
## Seeded self-play mower bots (spec MUST). One brain per player, personality
## drawn from the seeded RNG so a seed reproduces the same match. decide() is
## called once per tick per player in player order to keep the RNG stream
## deterministic.
##
## Strategy: SPACE-FILLING coverage. Probe several candidate headings; each
## scores by how much uncut(+2)/enemy(+1) turf lies ahead vs own(0)/bed/wall
## (heavy penalty). Steer toward the best. Opportunistic ram when a rival sits
## just ahead and the horn is off cooldown. Boost on long clear runs.

var rng := RandomNumberGenerator.new()
var aggr: Array = []       # ram eagerness 0..1
var greed: Array = []      # steal vs fresh preference
var wander: Array = []     # slow heading drift
var boost_love: Array = []

const PROBE_DIST := 3.2
const PROBE_STEPS := 12

func setup(seed_value: int, n: int) -> void:
	rng.seed = seed_value
	aggr.clear(); greed.clear(); wander.clear(); boost_love.clear()
	for i in n:
		aggr.append(rng.randf_range(0.35, 0.95))
		greed.append(rng.randf_range(0.4, 1.0))
		wander.append(rng.randf_range(0.0, TAU))
		boost_love.append(rng.randf_range(0.2, 0.8))

func decide(p: int, g, delta: float) -> Dictionary:
	var m: MowerUnit = g.mowers[p]
	if m.spin_t > 0.0:
		return {"move": Vector2.ZERO, "a": false, "b": false}
	var lawn: MowerLawn = g.lawn

	# --- pick best heading by probing candidate directions ---
	var base := m.facing.angle()
	wander[p] += rng.randf_range(-0.6, 0.6) * delta
	var best_dir := m.facing
	var best_score := -1e9
	var offsets := [-1.1, -0.55, -0.2, 0.0, 0.2, 0.55, 1.1]
	for off in offsets:
		var ang: float = base + off + 0.15 * sin(wander[p])
		var dir := Vector2(cos(ang), sin(ang))
		var score := _probe(m.pos, dir, p, lawn, greed[p])
		# prefer keeping momentum (less zig-zag) and staying on the lawn
		score -= absf(off) * 0.6
		if score > best_score:
			best_score = score
			best_dir = dir

	# --- opportunistic ram: rival just ahead, horn ready ---
	var press_a := false
	var victim := -1
	var vd := 999.0
	for q in g.mowers.size():
		if q == p:
			continue
		var other: MowerUnit = g.mowers[q]
		if other.spin_t > 0.0:
			continue
		var to := other.pos - m.pos
		var dist := to.length()
		if dist < vd:
			vd = dist
			victim = q
	if victim >= 0 and vd < 2.4 and m.ram_cd <= 0.0:
		var vm: MowerUnit = g.mowers[victim]
		var to_v := (vm.pos - m.pos).normalized()
		var aim: float = m.facing.normalized().dot(to_v)
		if aim > 0.72:
			# chase the ram: steer at them and honk
			best_dir = (best_dir * 0.35 + to_v * 0.65).normalized()
			if rng.randf() < 0.5 + 0.5 * aggr[p]:
				press_a = true

	# --- boost on a clear forward run ---
	var straight: float = m.facing.normalized().dot(best_dir.normalized())
	var press_b: bool = m.fuel > 0.4 and straight > 0.9 and best_score > 3.0 \
		and rng.randf() < boost_love[p]

	return {"move": best_dir, "a": press_a, "b": press_b}

## Sample cells along `dir`; reward unmowed/enemy turf, punish beds & the
## world edge so bots naturally fill space and turn before the fence.
func _probe(from: Vector2, dir: Vector2, p: int, lawn: MowerLawn, g_greed: float) -> float:
	var d := dir.normalized()
	var score := 0.0
	var mine := p + 1
	for s in range(1, PROBE_STEPS + 1):
		var t := PROBE_DIST * float(s) / float(PROBE_STEPS)
		var w := from + d * t
		if absf(w.x) > MowerLawn.HX - 0.4 or absf(w.y) > MowerLawn.HZ - 0.4:
			score -= 6.0   # heading into the fence
			break
		var code := lawn.owner_at_world(w)
		var falloff := 1.0 - 0.5 * float(s) / float(PROBE_STEPS)
		if code == MowerLawn.BLOCKED:
			score -= 4.0 * falloff
		elif code == 0:
			score += 2.0 * falloff       # fresh grass, best
		elif code == mine:
			score += 0.05 * falloff      # already ours, low value
		else:
			score += (1.0 + 0.6 * g_greed) * falloff  # steal enemy turf
	return score
