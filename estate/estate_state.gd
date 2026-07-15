extends Node
## Autoload EstateState: night-level party state + the persistent estate.
## Per-night: points ladder, grudge purses, pot, games played.
## Per-RUN (a full game): trail positions + tollgates persist across
## nights until someone reaches the manor — then the run is over.
## Persistent per SLOT (user://saves/slot_N.json): the whole estate —
## monuments, graffiti, ledger, legacy, wardrobe, plus the active run.

const LEGACY_SAVE_PATH := "user://estate_save.json"
const SAVE_DIR := "user://saves"
const STARTING_GRUDGE := 2

var night_length := 3
var night_length_forced := false  # --night=N pins it (soaks) over the pref
var pending_play := false  # slot panel picked an estate: auto-PLAY after the
                           # scene reload instead of dumping back on the title
var games_played := 0
var pot := 0
var players: Array = []
var bets := {}
var rng := RandomNumberGenerator.new()

var monuments: Array = []
var graffiti: Array = []
var ledger: Array = []
var gate_statues: Array = []
# THE GRUDGE LEDGER (THE ESTATE'S MEMORY): cross-night lifetime tallies keyed by
# player name — derived from what the house already records (ledger winners +
# superlatives, monuments, gate statues), plus a live events accumulator that
# games may feed via chronicle_event(). Read back as Executor-voiced
# observations in chronicle_lines(). Persisted in the slot save.
var chronicle := {}
var nights_played := 0
# Persistent per-player wallet + owned cosmetics. LEGACY is earned at
# night's end (your points + champion bonus) and only buys vanity.
var legacy := {}
var wardrobe := {}

var trail_pos := {}
var tollgates := {}
# Run state (a RUN = one full game: nights until someone takes the manor).
var current_slot := 1
var run_active := false
var run_night := 0        # nights completed within this run
var at_boundary := false  # true while the estate rests between nights
# First-night onboarding: the HOUSE RULES card is shown ONCE per estate, on the
# opening auction of a brand-new slot. Persisted so it never lectures a veteran.
var house_rules_shown := false
var last_deltas := {}
var night_stats := {}
# Directed kill counts for the night: "killer>victim" -> count. Fed by
# the module contract's optional kill_events; powers the NEMESIS award.
var kill_matrix := {}
# Standing VENDETTA from last night's ledger: {hunter, prey} — armed at
# start_night, settled when the PREY kills the HUNTER in any game.
var vendetta := {}
var vendetta_settled_by := -1

func _ready() -> void:
	rng.randomize()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))
	_migrate_to_slots()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--night="):
			night_length = clampi(int(arg.trim_prefix("--night=")), 1, 9)
			night_length_forced = true
		elif arg.begins_with("--seed="):
			rng.seed = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--slot="):
			current_slot = clampi(int(arg.trim_prefix("--slot=")), 1, 3)
		elif arg == "--fresh-estate":
			_wipe_save()
	load_estate()

## Pre-slots saves become slot 1, once.
func _migrate_to_slots() -> void:
	var old := ProjectSettings.globalize_path(LEGACY_SAVE_PATH)
	var slot1 := ProjectSettings.globalize_path(slot_path(1))
	if FileAccess.file_exists(old) and not FileAccess.file_exists(slot1):
		DirAccess.copy_absolute(old, slot1)
		print("MIGRATE estate_save.json -> saves/slot_1.json")

func slot_path(n: int) -> String:
	return "%s/slot_%d.json" % [SAVE_DIR, n]

## One-line summary for the slot picker ("" = empty slot).
func slot_summary(n: int) -> String:
	if not FileAccess.file_exists(slot_path(n)):
		return ""
	var data = JSON.parse_string(FileAccess.open(slot_path(n), FileAccess.READ).get_as_text())
	if not data is Dictionary:
		return ""
	var nights := int(data.get("nights_played", 0))
	var run: Dictionary = data.get("run", {})
	var tag := "at rest"
	if bool(run.get("active", false)):
		tag = "night %d underway" % (int(run.get("run_night", 0)) + 1)
	return "estate of %s — %s" % [_plural(nights, "night"), tag]

func load_slot(n: int) -> void:
	current_slot = clampi(n, 1, 3)
	monuments = []
	graffiti = []
	ledger = []
	gate_statues = []
	chronicle = {}
	legacy = {}
	wardrobe = {}
	nights_played = 0
	run_active = false
	run_night = 0
	at_boundary = false
	house_rules_shown = false
	trail_pos = {}
	tollgates = {}
	load_estate()

## NEW GAME: a fresh estate on this slot (wipes its history).
func new_game(n: int) -> void:
	current_slot = clampi(n, 1, 3)
	var p := ProjectSettings.globalize_path(slot_path(current_slot))
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(p)
	load_slot(current_slot)

## Populate the roster WITHOUT starting a night — the estate scene needs
## players for walkers/trail/exhibitions while sitting at the title.
func ensure_players(player_count: int) -> void:
	if not players.is_empty():
		return
	for i in player_count:
		if not trail_pos.has(i):
			trail_pos[i] = 0
		players.append({
			"index": i,
			"name": GameState.PLAYER_NAMES[i],
			"color": GameState.PLAYER_COLORS[i],
			"points": 0,
			"grudge": STARTING_GRUDGE,
		})

func start_night(player_count: int) -> void:
	games_played = 0
	pot = 0
	bets.clear()
	players.clear()
	last_deltas.clear()
	night_stats.clear()
	kill_matrix.clear()
	vendetta_settled_by = -1
	vendetta = {}
	# Trail + tollgates persist across nights WITHIN a run — the climb to
	# the manor is the full game. A fresh run starts everyone at the gates.
	if not run_active:
		run_active = true
		run_night = 0
		trail_pos.clear()
		tollgates.clear()
		for i in player_count:
			trail_pos[i] = 0
	at_boundary = false
	if not ledger.is_empty():
		var last: Dictionary = ledger.back()
		var nem: Dictionary = last.get("nemesis", {})
		if not nem.is_empty():
			vendetta = {"hunter": int(nem.hunter), "prey": int(nem.prey)}
			print("VENDETTA armed hunter=%d prey=%d" % [vendetta.hunter, vendetta.prey])
	for i in player_count:
		if not trail_pos.has(i):
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
	# NEMESIS counts each hunter>prey pair AT MOST ONCE PER GAME — dense
	# contact games (mower: 82 events/match) must not own the matrix.
	# The award reads as cross-game persistence: they came for you again.
	var pairs_this_game := {}
	for ke in results.get("kill_events", []):
		var killer: int = int(ke.get("killer", -1))
		var victim: int = int(ke.get("victim", -1))
		if killer >= 0 and victim >= 0 and killer != victim:
			night_stats[killer].kills += 1
			pairs_this_game["%d>%d" % [killer, victim]] = true
			if not vendetta.is_empty() and vendetta_settled_by < 0 \
					and killer == int(vendetta.prey) and victim == int(vendetta.hunter):
				vendetta_settled_by = killer
				players[killer].grudge += 3
				ticker.append("VENDETTA SETTLED — %s repays %s (+3♠)" % [players[killer].name, players[victim].name])
				add_graffiti("%s settled the vendetta against %s" % [players[killer].name, players[victim].name])
	for pair in pairs_this_game:
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
func _best_kill_pair() -> Dictionary:
	var best_pair := ""
	var best_n := 1
	for pair in kill_matrix:
		if int(kill_matrix[pair]) > best_n:
			best_n = int(kill_matrix[pair])
			best_pair = pair
	if best_pair == "":
		return {}
	var kp := best_pair.split(">")
	return {"hunter": int(kp[0]), "prey": int(kp[1]), "n": best_n}

func night_superlatives(champ: int) -> Array:
	var awards: Array = []
	var order := standings()
	if vendetta_settled_by >= 0:
		awards.append({"player": vendetta_settled_by, "title": "THE RECKONER",
			"line": "settled last night's vendetta in blood"})
	var nem := _best_kill_pair()
	if not nem.is_empty():
		awards.append({"player": int(nem.hunter), "title": "NEMESIS OF %s" % players[int(nem.prey)].name,
			"line": "came for them in %d different games tonight" % int(nem.n)})
	var work := _stat_leader("wins", order)
	if work >= 0 and work != champ:
		awards.append({"player": work, "title": "THE WORKHORSE",
			"line": "won %s and still lost the night" % _plural(night_stats[work].wins, "game")})
	var arch := _stat_leader("royalties", order)
	if arch >= 0:
		awards.append({"player": arch, "title": "THE ARCHITECT",
			"line": "collected %s in blood money" % _plural(night_stats[arch].royalties, "royalty payment")})
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
	ledger.append({"night": nights_played, "winner": pl.name, "awards": award_log,
		"nemesis": _best_kill_pair()})
	if not awards.is_empty():
		var top: Dictionary = awards[0]
		add_graffiti("N%d: %s was %s" % [nights_played + 1, players[top.player].name, top.title])
	add_monument(champ, "%s — Champion of Night %d" % [pl.name, nights_played + 1])
	for pl2 in players:
		legacy[int(pl2.index)] = int(legacy.get(int(pl2.index), 0)) + int(pl2.points)
	legacy[champ] = int(legacy.get(champ, 0)) + 5
	nights_played += 1
	run_night += 1
	at_boundary = true
	_rebuild_chronicle()
	save_estate()
	return pl

## Someone reached the manor: the RUN (the full game) is over.
func finish_run(champ: int) -> Dictionary:
	var pl = players[champ]
	run_active = false
	at_boundary = false
	add_monument(champ, "%s — TOOK THE MANOR (run of %d nights)" % [pl.name, run_night])
	add_graffiti("%s took the manor after %d nights" % [pl.name, run_night])
	legacy[champ] = int(legacy.get(champ, 0)) + 15
	_rebuild_chronicle()
	save_estate()
	print("RUN_OVER heir=%s nights=%d" % [pl.name, run_night])
	return pl

## The first-night HOUSE RULES card was shown for this estate — persist so it
## never lectures the same slot twice (a WIPE & START FRESH resets it).
func mark_house_rules_shown() -> void:
	house_rules_shown = true
	save_estate()

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
	var f := FileAccess.open(slot_path(current_slot), FileAccess.WRITE)
	if f:
		var leg := {}
		var ward := {}
		var tp := {}
		var tg := {}
		for k in legacy:
			leg[str(k)] = legacy[k]
		for k in wardrobe:
			ward[str(k)] = wardrobe[k]
		for k in trail_pos:
			tp[str(k)] = trail_pos[k]
		for k in tollgates:
			tg[str(k)] = tollgates[k]
		f.store_string(JSON.stringify({
			"monuments": monuments, "graffiti": graffiti,
			"ledger": ledger, "nights_played": nights_played,
			"gate_statues": gate_statues, "chronicle": chronicle,
			"legacy": leg, "wardrobe": ward,
			"house_rules_shown": house_rules_shown,
			"run": {"active": run_active, "run_night": run_night,
				"at_boundary": at_boundary, "trail_pos": tp, "tollgates": tg},
		}, "  "))

func load_estate() -> void:
	if not FileAccess.file_exists(slot_path(current_slot)):
		return
	var f := FileAccess.open(slot_path(current_slot), FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		monuments = data.get("monuments", [])
		graffiti = data.get("graffiti", [])
		ledger = data.get("ledger", [])
		gate_statues = data.get("gate_statues", [])
		chronicle = data.get("chronicle", {})
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
		house_rules_shown = bool(data.get("house_rules_shown", false))
		var run: Dictionary = data.get("run", {})
		run_active = bool(run.get("active", false))
		run_night = int(run.get("run_night", 0))
		at_boundary = bool(run.get("at_boundary", false))
		for k in run.get("trail_pos", {}):
			trail_pos[int(k)] = int(run.trail_pos[k])
		for k in run.get("tollgates", {}):
			tollgates[int(k)] = int(run.tollgates[k])
		_rebuild_chronicle()

func _wipe_save() -> void:
	if FileAccess.file_exists(slot_path(current_slot)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(slot_path(current_slot)))

# ============ THE GRUDGE LEDGER — the cross-night chronicle ============
## Lifetime memory keyed by player name, derived from what the house already
## records, read back as Executor-voiced observations during the will reading.

## Games may feed facts the ledger never sees (kind is a free string, e.g.
## "backstab"). NOT wired into any game tonight — the API exists for a later
## pass to enrich the memory without touching this file again.
func chronicle_event(kind: String, p: int, _meta := {}) -> void:
	var pname := _player_name(p)
	if pname == "":
		return
	var ev: Dictionary = _chron_rec(pname)["events"]
	ev[kind] = int(ev.get(kind, 0)) + 1
	save_estate()

func _player_name(p: int) -> String:
	if p >= 0 and p < players.size():
		return String(players[p].name)
	if p >= 0 and p < GameState.PLAYER_NAMES.size():
		return String(GameState.PLAYER_NAMES[p])
	return ""

## Fetch-or-create a per-name record; backfills keys for older saves.
func _chron_rec(pname: String) -> Dictionary:
	if not chronicle.has("by_name"):
		chronicle["by_name"] = {}
	var by: Dictionary = chronicle["by_name"]
	if not by.has(pname):
		by[pname] = {}
	var r: Dictionary = by[pname]
	for k in ["nights_won", "monuments", "manor_taken", "lasts"]:
		if not r.has(k):
			r[k] = 0
	for k in ["titles", "nemesis_of", "events"]:
		if not r.has(k):
			r[k] = {}
	return r

## Rebuild the DERIVED tallies from history (ledger winners + superlatives,
## monuments, gate statues) while preserving the game-fed events accumulator
## that history cannot reconstruct.
func _rebuild_chronicle() -> void:
	var saved_events := {}
	if chronicle.has("by_name"):
		for nm in chronicle["by_name"]:
			var r = chronicle["by_name"][nm]
			if r is Dictionary and r.has("events"):
				saved_events[nm] = (r["events"] as Dictionary).duplicate(true)
	chronicle = {"by_name": {}, "nights_recorded": ledger.size()}
	for entry in ledger:
		var winner := String(entry.get("winner", ""))
		if winner != "":
			_chron_rec(winner)["nights_won"] += 1
		for aw in entry.get("awards", []):
			var who := String(aw.get("who", ""))
			var title := String(aw.get("title", ""))
			if who == "" or title == "":
				continue
			var rec := _chron_rec(who)
			var key := title
			if title.begins_with("NEMESIS OF "):
				var prey := title.substr("NEMESIS OF ".length())
				var nof: Dictionary = rec["nemesis_of"]
				nof[prey] = int(nof.get(prey, 0)) + 1
				key = "THE NEMESIS"
			var tt: Dictionary = rec["titles"]
			tt[key] = int(tt.get(key, 0)) + 1
			if key == "THE DOORMAT":
				rec["lasts"] += 1
	for m in monuments:
		var owner := String(m.get("owner", ""))
		if owner == "":
			continue
		var mr := _chron_rec(owner)
		mr["monuments"] += 1
		if String(m.get("label", "")).find("TOOK THE MANOR") >= 0:
			mr["manor_taken"] += 1
	for nm in saved_events:
		_chron_rec(nm)["events"] = saved_events[nm]

func _num_word(n: int) -> String:
	match n:
		1: return "once"
		2: return "twice"
		3: return "three times"
		4: return "four times"
		5: return "five times"
	return "%d times" % n

func _title_bare(t: String) -> String:
	return t.trim_prefix("THE ")

func _humanize(kind: String) -> String:
	return kind.replace("_", " ")

## Executor-voiced observations across nights (Saki register: dry, immaculate,
## lethal). 25+ templates; only those with the data to earn them fire. Pass a
## limit>0 to draw that many at random (deterministic against the estate seed).
func chronicle_lines(limit := 0) -> Array:
	var pool: Array = []
	var by: Dictionary = chronicle.get("by_name", {})
	for pname in by:
		var r: Dictionary = by[pname]
		var won := int(r.get("nights_won", 0))
		var mons := int(r.get("monuments", 0))
		var lasts := int(r.get("lasts", 0))
		var manor := int(r.get("manor_taken", 0))
		var titles: Dictionary = r.get("titles", {})
		var nof: Dictionary = r.get("nemesis_of", {})
		var events: Dictionary = r.get("events", {})
		var title_total := 0
		for t in titles:
			title_total += int(titles[t])
			if int(titles[t]) >= 2:
				pool.append("%s has taken the %s award %s. The house is beginning to expect it." % [pname, _title_bare(String(t)), _num_word(int(titles[t]))])
		if mons >= 3:
			pool.append("%s has erected %s. None mention kindness." % [pname, _plural(mons, "monument")])
		elif mons == 2:
			pool.append("%s has raised two monuments. The estate is running short of dignified lawn." % pname)
		elif mons == 1:
			pool.append("%s left a single monument. The estate finds the modesty suspicious." % pname)
		if won >= 3:
			pool.append("%s has won %s. Somewhere a will is being redrafted in their favour." % [pname, _plural(won, "night")])
		elif won == 2:
			pool.append("%s has won twice now. The other portraits have begun to mutter." % pname)
		elif won == 1:
			pool.append("%s has won a night, once. They mention it often; the estate, less so." % pname)
		if won == 0 and (mons > 0 or lasts > 0):
			pool.append("%s has never won a night. The estate admires the consistency of it." % pname)
		if won >= 1 and lasts >= 1:
			pool.append("%s has topped a night and bottomed one. The estate calls this range." % pname)
		if lasts >= 3:
			pool.append("%s has finished dead last on %s. The estate keeps a chair warm, and low." % [pname, _plural(lasts, "occasion")])
		elif lasts == 2:
			pool.append("%s has come last twice. The estate does not pity; it merely notes." % pname)
		for prey in nof:
			if int(nof[prey]) >= 2:
				pool.append("%s has hunted %s across %s. The estate no longer records it as coincidence." % [pname, prey, _plural(int(nof[prey]), "night")])
			else:
				pool.append("%s came for %s, once. The estate has opened a file, in pencil." % [pname, prey])
		if manor >= 1:
			pool.append("%s took the manor, once. The keys have not been seen since, nor missed." % pname)
		if int(titles.get("THE SNAKE", 0)) >= 1:
			pool.append("%s has cashed a bet against a friend before. The estate keeps the receipts." % pname)
		if int(titles.get("THE HOARDER", 0)) >= 1:
			pool.append("%s hoards grudge the way this house hoards portraits — compulsively, and forever." % pname)
		if int(titles.get("THE ARCHITECT", 0)) >= 1:
			pool.append("%s has been paid in blood money before. The ledger rounds up." % pname)
		if int(titles.get("THE LANDLORD", 0)) >= 1:
			pool.append("%s once bled the tollgates dry. The gates remember every coin." % pname)
		if int(titles.get("THE WORKHORSE", 0)) >= 1:
			pool.append("%s has won games and still lost nights. The estate calls this character-building." % pname)
		if int(titles.get("THE RECKONER", 0)) >= 1:
			pool.append("%s has settled a vendetta in blood. The estate approved the paperwork retroactively." % pname)
		if int(titles.get("THE DOORMAT", 0)) >= 1:
			pool.append("%s has worn the DOORMAT more than once suits a person. The estate finds it fits." % pname)
		if int(titles.get("THE NEMESIS", 0)) >= 1:
			pool.append("%s has made a career of someone else's misfortune. The house calls that ambition." % pname)
		if title_total >= 4:
			pool.append("%s has collected %s of dubious distinction. The estate is compiling a retrospective." % [pname, _plural(title_total, "title")])
		for kind in events:
			if int(events[kind]) >= 1:
				pool.append("%s has a documented habit of %s. The estate stopped being surprised some nights ago." % [pname, _humanize(String(kind))])
	var nights := int(chronicle.get("nights_recorded", 0))
	if nights >= 1:
		pool.append("The estate has recorded %s. It forgets none of them, however politely it is asked." % _plural(nights, "night"))
	if nights >= 4:
		pool.append("Four nights in, and no one has yet been kind without an audience. The estate had wagered as much.")
	var top_name := ""
	var top_mon := -1
	for pname in by:
		var mc := int(by[pname].get("monuments", 0))
		if mc > top_mon:
			top_mon = mc
			top_name = pname
	if top_name != "" and top_mon >= 2:
		pool.append("%s has more stones on the lawn than anyone. The estate assumes this is what they wanted." % top_name)
	pool.append("The estate has reviewed its records and finds everyone, on balance, guilty of something.")
	pool.append("Memory is the only inheritance the estate offers freely. It is also the one no one asked for.")
	if limit > 0 and pool.size() > limit:
		var copy := pool.duplicate()
		for i in range(copy.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp = copy[i]
			copy[i] = copy[j]
			copy[j] = tmp
		return copy.slice(0, limit)
	return pool
