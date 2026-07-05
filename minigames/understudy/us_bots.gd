class_name USBots
extends RefCounted
## Seeded, legible self-play brains for THE UNDERSTUDY. One personality vector
## per player from the seeded RNG so a given seed reproduces exactly. Bots read
## the controller `g` for all live state (house pattern, cf. LWBots).
##
## Determinism note: pick_cue() and decide_vote() consume the RNG, so the
## controller calls each EXACTLY ONCE per beat / per round and caches the
## result — never once per frame.
##
## LEGIBILITY CONTRACT (why a bot did what it did, in plain sight):
##   CAST at rehearsal    -> delivers an ON-SCRIPT cue (they read the script).
##   UNDERSTUDY rehearsal -> narrows the play from the cues already spoken and
##                           echoes a fitting word; acting EARLY, with little to
##                           go on, it must gamble and often slips OFF-SCRIPT —
##                           that slip is the tell.
##   CAST at the vote     -> accuses whoever slipped off-script (the tell); with
##                           no slip to go on it can only guess, so a clean
##                           blend splits the cast — the 2v2 the scoring breaks.
##   UNDERSTUDY vote      -> frames a cast member to muddy the count.

var rng := RandomNumberGenerator.new()
var _bias: Array = []           # n x n seeded suspicion bias in [0,1)
var _cue_variety: Array = []    # seeded offset so mirror bots differ

func setup(seed_value: int, n: int) -> void:
	rng.seed = seed_value
	_bias.clear()
	_cue_variety.clear()
	for i in n:
		var row: Array = []
		for j in n:
			row.append(rng.randf())
		_bias.append(row)
		_cue_variety.append(rng.randi_range(0, 97))

## Deterministic "reading" pause for the private casting reveal (seconds).
func read_beat(p: int) -> float:
	return 0.5 + 0.25 * float(_cue_variety[p] % 4)

## Which cue (index into g.cur_grid) this bot delivers. Consumes RNG — call once.
func pick_cue(p: int, g) -> int:
	var grid: Array = g.cur_grid
	if grid.is_empty():
		return 0
	if p != g.round_understudy:
		# CAST: pick an on-script word (they know tonight's play)
		var trues: Array = []
		for i in grid.size():
			if g.word_in_play(str(grid[i]), g.tonight_play):
				trues.append(i)
		if trues.is_empty():
			return rng.randi_range(0, grid.size() - 1)
		return int(trues[_cue_variety[p] % trues.size()])

	# UNDERSTUDY: which plays are still consistent with the on-script cues heard?
	var evidence: Array = []
	for h in g.cue_history:
		if bool(h.on_script):
			evidence.append(str(h.word))
	var candidates: Array = []
	for key in g.play_keys():
		var ok := true
		for w in evidence:
			if not g.word_in_play(str(w), str(key)):
				ok = false
				break
		if ok:
			candidates.append(str(key))
	if candidates.is_empty():
		candidates = g.play_keys()

	# how many candidate plays does each grid word fit? (higher = safer echo)
	var best_i := 0
	var best_fit := -1
	for i in grid.size():
		var fit := 0
		for key in candidates:
			if g.word_in_play(str(grid[i]), str(key)):
				fit += 1
		if fit > best_fit:
			best_fit = fit
			best_i = i

	# commit to the safe echo only when the read is strong; else gamble (slip)
	var commit := 0.25
	if candidates.size() == 1 and evidence.size() >= 2:
		commit = 0.95
	elif candidates.size() <= 2 and evidence.size() >= 1:
		commit = 0.6
	if rng.randf() < commit:
		return best_i
	return rng.randi_range(0, grid.size() - 1)

## The accused player's index for voter seat p. Consumes RNG — call once/round.
func decide_vote(p: int, g) -> int:
	var n: int = g.players.size()
	if p == g.round_understudy:
		# frame the cast member the room is likeliest to distrust
		var best := -1
		var best_s := -1e9
		for m in n:
			if m == p or m == g.round_understudy:
				continue
			var notoriety := float(g.offscript_count.get(m, 0)) * 5.0
			for c in n:
				if c == m or c == g.round_understudy:
					continue
				notoriety += float(_bias[c][m])
			notoriety += rng.randf() * 0.6
			if notoriety > best_s:
				best_s = notoriety
				best = m
		return best if best >= 0 else _first_other(p, n)

	# CAST: the off-script slip is the tell; with none, a nervous fresh guess
	var any_slip := false
	for m in n:
		if int(g.offscript_count.get(m, 0)) > 0:
			any_slip = true
			break
	var best2 := -1
	var best_s2 := -1e9
	for m in n:
		if m == p:
			continue
		var susp := 0.0
		if any_slip:
			susp = float(g.offscript_count.get(m, 0)) * 100.0 + float(_bias[p][m])
		else:
			# no evidence -> a fresh per-round roll so the cast scatters instead
			# of deadlocking on one static scapegoat every act
			susp = rng.randf() * 4.0 + float(_bias[p][m])
		if susp > best_s2:
			best_s2 = susp
			best2 = m
	return best2 if best2 >= 0 else _first_other(p, n)

func _first_other(p: int, n: int) -> int:
	for m in n:
		if m != p:
			return m
	return 0
