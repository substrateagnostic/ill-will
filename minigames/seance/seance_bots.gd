class_name SeanceBots
extends RefCounted
## Seeded self-play brains for THE SÉANCE. Deterministic per rng_seed: all
## rolls come from one RNG consumed in tick order at a pinned dt.
##
## LEGIBILITY REQUIREMENTS (from the build brief):
## - Guesser bots nudge the planchette toward PLAUSIBLE letters of the
##   secret word with seeded noise. Implementation: each honest bot holds a
##   belief target — with probability `insight` it is the word's next
##   unrevealed letter (bots try to spell in order, which reads as intent),
##   otherwise a frequency-weighted plausible letter (E before Q). They tap
##   the chant close to the beat (small seeded jitter).
## - The saboteur bot steers SUBTLY wrong with occasional alibi moves: an
##   opening good-faith window (looks cooperative), then wrong-letter
##   targets that are themselves plausible-looking (smart sabotage imitates
##   honest error), degraded chant timing (drains focus deniably), and
##   emergency yanks (B surge) when a correct letter is about to commit —
##   gated by a roll so it is not a certainty anyone can clock.
##
## Voting: honest bots read the game's public-evidence `suspicion` tally
## through seeded noise (they are couch players, not auditors); the
## charlatan frames whichever honest player looks clumsiest.

var rng := RandomNumberGenerator.new()
var charlatan := -1

# per-player personality
var insight: Array = []        # honest: chance target = real next letter
var tap_sigma: Array = []      # chant timing jitter (seconds)
var skip_rate: Array = []      # chance to sit a beat out
var retarget_lo: Array = []
var retarget_hi: Array = []

# per-player state
var _target: Array = []        # current letter target ("" = none)
var _retarget_t: Array = []
var _beat_planned: Array = []  # beat index a tap was planned for
var _tap_offset: Array = []    # planned offset into the beat (s)
var _tapped: Array = []        # already fired for the planned beat
var _vote_lock_at: Array = []
var _vote_choice: Array = []
var _hover_t: Array = []

func setup(seed_value: int, n: int, charlatan_idx: int) -> void:
	rng.seed = seed_value
	charlatan = charlatan_idx
	insight.clear(); tap_sigma.clear(); skip_rate.clear()
	retarget_lo.clear(); retarget_hi.clear()
	_target.clear(); _retarget_t.clear()
	_beat_planned.clear(); _tap_offset.clear(); _tapped.clear()
	_vote_lock_at.clear(); _vote_choice.clear(); _hover_t.clear()
	for i in n:
		if i == charlatan_idx:
			insight.append(1.0)                      # knows the word cold
			tap_sigma.append(rng.randf_range(0.15, 0.2))
			skip_rate.append(rng.randf_range(0.1, 0.16))
		else:
			insight.append(rng.randf_range(0.45, 0.7))
			tap_sigma.append(rng.randf_range(0.055, 0.11))
			skip_rate.append(rng.randf_range(0.02, 0.06))
		retarget_lo.append(rng.randf_range(1.0, 1.5))
		retarget_hi.append(rng.randf_range(1.9, 2.6))
		_target.append("")
		_retarget_t.append(rng.randf_range(0.2, 0.8))
		_beat_planned.append(-1)
		_tap_offset.append(0.0)
		_tapped.append(true)
		_vote_lock_at.append(rng.randf_range(2.0, 7.5))
		_vote_choice.append(-1)
		_hover_t.append(0.0)

# ---------------------------------------------------------------- séance
## g = seance.gd root. Returns {move: Vector2, tap: bool, surge: bool}.
func decide_seance(p: int, g, delta: float) -> Dictionary:
	var move := Vector2.ZERO
	var tap := false
	var surge := false
	var sab: bool = (p == charlatan)

	# ---- retarget clock
	_retarget_t[p] -= delta
	if _retarget_t[p] <= 0.0 or _target[p] == "" or g.is_letter_settled(_target[p]):
		_retarget_t[p] = rng.randf_range(retarget_lo[p], retarget_hi[p])
		_target[p] = _pick_target(p, g)

	# ---- steer toward (or away from) letters
	var here: Vector3 = g.planchette.position
	if sab and g.dwell_letter != "" and g.is_letter_in_word(g.dwell_letter) \
			and g.dwell_t > g.DWELL_TIME * 0.25 and g.seance_elapsed > g.SAB_ALIBI_WINDOW:
		# emergency: a correct letter is charging — yank away, deniably
		var away: Vector3 = here - g.letter_pos(g.dwell_letter)
		away.y = 0.0
		if away.length() < 0.05:
			away = Vector3(1, 0, 0)
		move = Vector2(away.x, away.z).normalized()
		if rng.randf() < 0.12 and g.can_surge(p):
			surge = true
	elif _target[p] != "":
		var to: Vector3 = g.letter_pos(_target[p]) - here
		to.y = 0.0
		var d := to.length()
		if d > 0.05:
			var dir := Vector2(to.x, to.z).normalized()
			# seeded wobble so the pull looks like a hand, not a servo
			var wob := rng.randf_range(-0.5, 0.5)
			dir = dir.rotated(wob * 0.45)
			move = dir * clampf(d * 2.2, 0.35, 1.0)
			# opportunistic surge when far from where they want to be
			if d > 0.75 and g.can_surge(p) and rng.randf() < 0.012:
				surge = true
		else:
			move = Vector2.ZERO   # sit on the letter and let it channel

	# ---- chant taps: plan one tap per beat at a seeded offset
	var beat: int = g.beat_index()
	if _beat_planned[p] != beat:
		_beat_planned[p] = beat
		if rng.randf() < skip_rate[p]:
			_tapped[p] = true   # sits this beat out
		else:
			_tapped[p] = false
			var off := absf(rng.randfn(0.0, tap_sigma[p]))
			if sab and g.seance_elapsed > g.SAB_ALIBI_WINDOW and rng.randf() < 0.5:
				# deliberate late hit: lands outside the window, reads as lag
				off = g.TAP_WINDOW + rng.randf_range(0.06, 0.2)
			_tap_offset[p] = minf(off, g.BEAT_PERIOD * 0.48)
	if not _tapped[p] and g.beat_time() >= _tap_offset[p]:
		_tapped[p] = true
		tap = true

	return {"move": move, "tap": tap, "surge": surge}

func _pick_target(p: int, g) -> String:
	var sab: bool = (p == charlatan)
	if sab:
		if g.seance_elapsed <= g.SAB_ALIBI_WINDOW or rng.randf() < 0.2:
			# alibi move: help spell the truth for a while
			var next_real: String = g.next_needed_letter()
			if next_real != "":
				return next_real
		# sabotage: a plausible-LOOKING letter that is NOT in the word
		return _weighted_plausible(g, true)
	# honest: with `insight`, the next unrevealed word letter (they are
	# reading the Executor's clue well); otherwise a plausible blind guess
	if rng.randf() < insight[p]:
		var next_real2: String = g.next_needed_letter()
		if next_real2 != "":
			return next_real2
	return _weighted_plausible(g, false)

## Frequency-weighted pick among letters still on the board. When
## `exclude_word` (saboteur), word letters are skipped so the pull is
## always wrong — but the CHOICE mimics honest error (common letters).
func _weighted_plausible(g, exclude_word: bool) -> String:
	var pool: Array = []
	var weights: Array = []
	var total := 0.0
	for l in g.all_letters():
		if g.is_letter_settled(l):
			continue
		if exclude_word and g.is_letter_in_word(l):
			continue
		var w: float = SeanceWords.LETTER_WEIGHT.get(l, 1.0)
		pool.append(l)
		weights.append(w)
		total += w
	if pool.is_empty():
		return ""
	var roll := rng.randf() * total
	for i in pool.size():
		roll -= float(weights[i])
		if roll <= 0.0:
			return pool[i]
	return pool.back()

# ---------------------------------------------------------------- voting
## Returns the accused index once the bot is ready to lock, else -1.
## `others` = valid targets, `t` = seconds into the vote phase.
func decide_vote(p: int, g, others: Array, t: float) -> int:
	if t < _vote_lock_at[p]:
		return -1
	if _vote_choice[p] < 0:
		var best := -1
		var best_s := -1e9
		for o in others:
			var s: float = float(g.suspicion.get(o, 0.0))
			if p == charlatan:
				# frame job: the clumsiest-looking honest player
				s += rng.randf_range(0.0, 1.2)
			else:
				s += rng.randfn(0.0, 0.45)   # couch player, not an auditor
			if s > best_s:
				best_s = s
				best = o
		_vote_choice[p] = best
	return _vote_choice[p]

## Pre-lock hover drama: wander the spotlight between targets.
func hover_vote(p: int, _g, others: Array, delta: float, current: int) -> int:
	_hover_t[p] -= delta
	if _hover_t[p] <= 0.0:
		_hover_t[p] = rng.randf_range(0.5, 1.1)
		return others[rng.randi_range(0, others.size() - 1)]
	return current
