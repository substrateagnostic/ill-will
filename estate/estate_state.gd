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
var nights_played := 0

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
	for rank in placements.size():
		var p: int = placements[rank]
		var gain: int = pts[rank] if rank < pts.size() else 0
		players[p].points += gain
		ticker.append("%s finishes #%d  (+%d pts)" % [players[p].name, rank + 1, gain])
	for ev in results.get("currency_events", []):
		var p: int = ev.player
		if ev.type == "grudge":
			players[p].grudge += ev.amount
			ticker.append("%s +%d♠  (%s)" % [players[p].name, ev.amount, ev.get("reason", "")])
		elif ev.type == "royalty":
			players[p].points += 0
			ticker.append("%s royalty: %s" % [players[p].name, ev.get("reason", "")])
	if not placements.is_empty():
		var winner: int = placements[0]
		var paid := 0
		for p in bets:
			if bets[p] == winner and p != winner:
				var payout: int = mini(2, pot)
				pot -= payout
				players[p].grudge += payout
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

func end_night() -> Dictionary:
	var champ: int = standings()[0]
	var pl = players[champ]
	ledger.append({"night": nights_played, "winner": pl.name})
	add_monument(champ, "%s — Champion of Night %d" % [pl.name, nights_played + 1])
	nights_played += 1
	save_estate()
	return pl

func save_estate() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({
			"monuments": monuments, "graffiti": graffiti,
			"ledger": ledger, "nights_played": nights_played,
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
		nights_played = int(data.get("nights_played", 0))

func _wipe_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
