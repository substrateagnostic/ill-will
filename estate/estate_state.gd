extends Node
## Autoload EstateState: persistent estate data and the current roster.
## Historical classic-run keys are round-tripped opaquely until a dedicated
## save-schema migration retires them; no live game flow consumes them.

const LEGACY_SAVE_PATH := "user://estate_save.json"
const SAVE_DIR := "user://saves"
const STARTING_GRUDGE := 2

var pending_play := false  # slot panel picked an estate: auto-PLAY after the
                           # scene reload instead of dumping back on the title
var players: Array = []
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
var current_slot := 1
var run_active := false
var run_night := 0
var at_boundary := false
var house_rules_shown := false

func _ready() -> void:
	rng.randomize()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))
	_migrate_to_slots()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
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
	return "estate of %s" % _plural(nights, "night")

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

## Populate the roster for the estate shell, exhibitions, and Procession.
func ensure_players(player_count: int) -> void:
	if not players.is_empty():
		return
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

func _plural(n: int, word: String) -> String:
	return "%d %s" % [n, word if n == 1 else word + "s"]

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
