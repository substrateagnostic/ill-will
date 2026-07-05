extends Node
## Autoload EstateState: night-level party state + the persistent estate.
## Per-night: points ladder, grudge purses, pot, games played.
## Persistent (user://estate_save.json): monuments, graffiti, night ledger.

const SAVE_PATH := "user://estate_save.json"
const STARTING_GRUDGE := 2

var night_length := 3
var games_played := 0
var pot := 0
var players: Array = []
var bets := {}
var rng := RandomNumberGenerator.new()

var monuments: Array = []
var graffiti: Array = []
var ledger: Array = []
var gate_statues: Array = []
var nights_played := 0
# Persistent per-player wallet + owned cosmetics. LEGACY is earned at
# night's end (your points + champion bonus) and only buys vanity.
var legacy := {}
var wardrobe := {}

var trail_pos := {}
var tollgates := {}
var last_deltas := {}
var night_stats := {}
# Directed kill counts for the night: "killer>victim" -> count. Fed by
# the module contract's optional kill_events; powers the NEMESIS award.
var kill_matrix := {}

func _ready() -> void:
	rng.randomize()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--night="):
			night_length = clampi(int(arg.trim_prefix("--night=")), 1, 9)
		elif arg.begins_with("--seed="):
			rng.seed = int(arg.trim_prefix("--seed="))
		elif arg == "--fresh-estate":
			_wipe_save()
	load_estate()

func start_night(player_count: int) -> void:
	games_played = 0
	pot = 0
	bets.clear()
	players.clear()
	trail_pos.clear()
	tollgates.clear()
	last_deltas.clear()
	night_stats.clear()
	kill_matrix.clear()
	for i in player_count:
		trail_pos[i] = 0
		night_stats[i] = {"wins": 0, "lasts": 0, "royalties": 0,
			"grudge_earned": 0, "bets_won": 0, "tolls": 0, "kills": 0}
	for i in player_count:
		players.append({
			"index": i,
			"name": GameState.PLAYER_NAMES[i],
			"color": GameState.PLAYER_COLORS[i],
			"points": 0,
			"grudge": STARTING_GRUDGE,
		})

func standings() -> Array:
	var idx := range(players.size())
	idx.sort_custom(func(a, b):
		if players[a].points != players[b].points:
			return players[a].points > players[b].points
		return a < b)
	return idx

func apply_results(results: Dictionary) -> Array:
	var ticker: Array = []
	var placements: Array = results.get("placements", [])
	var pts := [5, 3, 2, 1]
	last_deltas.clear()
	for rank in placements.size():
		var p: int = placements[rank]
		var gain: int = pts[rank] if rank < pts.size() else 0
		players[p].points += gain
		last_deltas[p] = gain
		ticker.append("%s finishes #%d  (+%d pts)" % [players[p].name, rank + 1, gain])
	if placements.size() >= 2:
		night_stats[placements[0]].wins += 1
		night_stats[placements.back()].lasts += 1
	for ke in results.get("kill_events", []):
		var killer: int = int(ke.get("killer", -1))
		var victim: int = int(ke.get("victim", -1))
		if killer >= 0 and victim >= 0 and killer != victim:
			night_stats[killer].kills += 1
			var pair := "%d>%d" % [killer, victim]
			kill_matrix[pair] = int(kill_matrix.get(pair, 0)) + 1
	for ev in results.get("currency_events", []):
		var p: int = ev.player
		if ev.type == "grudge":
			players[p].grudge += ev.amount
			if ev.amount > 0:
				night_stats[p].grudge_earned += ev.amount
			ticker.append("%s +%d♠  (%s)" % [players[p].name, ev.amount, ev.get("reason", "")])
		elif ev.type == "royalty":
			night_stats[p].royalties += 1
			ticker.append("%s royalty: %s" % [players[p].name, ev.get("reason", "")])
	if not placements.is_empty():
		var winner: int = placements[0]
		var paid := 0
		for p in bets:
			if bets[p] == winner and p != winner:
				var payout: int = mini(2, pot)
				pot -= payout
				players[p].grudge += payout
				night_stats[p].bets_won += 1
				paid += 1
				ticker.append("%s's bet pays out (+%d♠)" % [players[p].name, payout])
		if paid == 0 and pot > 0:
			ticker.append("the pot holds %d♠" % pot)
	for hl in results.get("highlights", []):
		add_graffiti(str(hl))
		ticker.append("carved: \"%s\"" % str(hl))
	for m in results.get("monuments", []):
		add_monument(m.get("player", 0), m.get("label", "?"))
		ticker.append("MONUMENT: %s" % m.get("label", "?"))
	bets.clear()
	for pl in players:
		pl.grudge += 1
	games_played += 1
	return ticker

func record_toll(owner_idx: int, amount: int) -> void:
	night_stats[owner_idx].tolls += amount

## End-of-night superlatives from night_stats. Skips zero-data awards.
## champ is excluded from WORKHORSE (their glory is the podium).
func night_superlatives(champ: int) -> Array:
	var awards: Array = []
	var order := standings()
	var best_pair := ""
	var best_n := 1
	for pair in kill_matrix:
		if int(kill_matrix[pair]) > best_n:
			best_n = int(kill_matrix[pair])
			best_pair = pair
	if best_pair != "":
		var kp := best_pair.split(">")
		awards.append({"player": int(kp[0]), "title": "NEMESIS OF %s" % players[int(kp[1])].name,
			"line": "hunted them down %d times tonight" % best_n})
	var work := _stat_leader("wins", order)
	if work >= 0 and work != champ:
		awards.append({"player": work, "title": "THE WORKHORSE",
			"line": "won %s and still lost the night" % _plural(night_stats[work].wins, "game")})
	var arch := _stat_leader("royalties", order)
	if arch >= 0:
		awards.append({"player": arch, "title": "THE ARCHITECT",
			"line": "their handiwork claimed %s" % _plural(night_stats[arch].royalties, "victim")})
	var snake := _stat_leader("bets_won", order)
	if snake >= 0:
		awards.append({"player": snake, "title": "THE SNAKE",
			"line": "cashed %s against their friends" % _plural(night_stats[snake].bets_won, "bet")})
	var lord := _stat_leader("tolls", order)
	if lord >= 0:
		awards.append({"player": lord, "title": "THE LANDLORD",
			"line": "bled %d♠ out of the tollgates" % night_stats[lord].tolls})
	var mat := _stat_leader("lasts", order, true)
	if mat >= 0:
		awards.append({"player": mat, "title": "THE DOORMAT",
			"line": "finished dead last %s. forgive them." % _plural(night_stats[mat].lasts, "time")})
	var hoard := _stat_leader("grudge_earned", order)
	if hoard >= 0:
		awards.append({"player": hoard, "title": "THE HOARDER",
			"line": "amassed %d♠ of pure spite" % night_stats[hoard].grudge_earned})
	return awards.slice(0, 5)

func _plural(n: int, word: String) -> String:
	return "%d %s" % [n, word if n == 1 else word + "s"]

## Strict-max leader for a stat; ties go to the better-placed player
## (worse-placed when reversed — the DOORMAT deserves it more).
func _stat_leader(key: String, order: Array, rev := false) -> int:
	var seq: Array = order.duplicate()
	if rev:
		seq.reverse()
	var best := -1
	for p in seq:
		var v: int = night_stats[p][key]
		if v > 0 and (best < 0 or v > night_stats[best][key]):
			best = p
	return best

func steal_grudge(victim: int, thief: int, amount := 1) -> int:
	var taken: int = mini(amount, players[victim].grudge)
	players[victim].grudge -= taken
	players[thief].grudge += taken
	return taken

func spend_grudge(p: int, amount: int) -> bool:
	if players[p].grudge < amount:
		return false
	players[p].grudge -= amount
	return true

func place_bet(p: int, target: int) -> bool:
	if players[p].grudge < 1 or bets.has(p):
		return false
	players[p].grudge -= 1
	pot += 1
	bets[p] = target
	return true

func add_monument(owner_idx: int, label: String) -> void:
	var pl = players[owner_idx]
	monuments.append({
		"owner": pl.name,
		"color": pl.color.to_html(),
		"label": label,
		"night": nights_played,
	})

func add_graffiti(line: String) -> void:
	graffiti.append(line)
	if graffiti.size() > 24:
		graffiti.pop_front()

func end_night(champ_override := -1) -> Dictionary:
	var champ: int = champ_override if champ_override >= 0 else furthest_on_trail()
	var pl = players[champ]
	var awards := night_superlatives(champ)
	var award_log: Array = []
	for aw in awards:
		award_log.append({"who": players[aw.player].name,
			"title": aw.title, "line": aw.line})
	gate_statues.append({"owner": pl.name, "color": pl.color.to_html(), "night": nights_played})
	ledger.append({"night": nights_played, "winner": pl.name, "awards": award_log})
	if not awards.is_empty():
		var top: Dictionary = awards[0]
		add_graffiti("N%d: %s was %s" % [nights_played + 1, players[top.player].name, top.title])
	add_monument(champ, "%s — Champion of Night %d" % [pl.name, nights_played + 1])
	for pl2 in players:
		legacy[int(pl2.index)] = int(legacy.get(int(pl2.index), 0)) + int(pl2.points)
	legacy[champ] = int(legacy.get(champ, 0)) + 5
	nights_played += 1
	save_estate()
	return pl

func legacy_of(p: int) -> int:
	return int(legacy.get(p, 0))

func owned_cosmetics(p: int) -> Array:
	if not wardrobe.has(p):
		wardrobe[p] = []
	return wardrobe[p]

func buy_cosmetic(p: int, id: String, price: int) -> bool:
	if id in owned_cosmetics(p) or legacy_of(p) < price:
		return false
	legacy[p] = legacy_of(p) - price
	owned_cosmetics(p).append(id)
	save_estate()
	return true

func furthest_on_trail() -> int:
	var order := standings()
	var best: int = order[0]
	for p in trail_pos:
		if trail_pos[p] > trail_pos[best]:
			best = p
		elif trail_pos[p] == trail_pos[best] and players[p].points > players[best].points:
			best = p
	return best

func save_estate() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		var leg := {}
		var ward := {}
		for k in legacy:
			leg[str(k)] = legacy[k]
		for k in wardrobe:
			ward[str(k)] = wardrobe[k]
		f.store_string(JSON.stringify({
			"monuments": monuments, "graffiti": graffiti,
			"ledger": ledger, "nights_played": nights_played,
			"gate_statues": gate_statues,
			"legacy": leg, "wardrobe": ward,
		}, "  "))

func load_estate() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		monuments = data.get("monuments", [])
		graffiti = data.get("graffiti", [])
		ledger = data.get("ledger", [])
		gate_statues = data.get("gate_statues", [])
		nights_played = int(data.get("nights_played", 0))
		for k in data.get("legacy", {}):
			legacy[int(k)] = int(data.legacy[k])
		for k in data.get("wardrobe", {}):
			wardrobe[int(k)] = Array(data.wardrobe[k])
		# Grandfather clause: saves from before the wardrobe existed get
		# credit for prior service, so nobody starts the store broke.
		if not data.has("legacy") and nights_played > 0:
			for i in 4:
				legacy[i] = nights_played * 15

func _wipe_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
