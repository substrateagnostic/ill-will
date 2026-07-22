extends Node
## Autoload EstateState: persistent estate data and the current roster.
## Schema-v1 classic-run keys are archived opaquely during the v2 migration;
## no live game flow consumes or reinterprets their Trail stone indices.

const LEGACY_SAVE_PATH := "user://estate_save.json"
const SAVE_DIR := "user://saves"
const STARTING_GRUDGE := 2
const SAVE_SCHEMA := 2

var pending_play: bool = false  # slot panel picked an estate: auto-PLAY after the
                           # scene reload instead of dumping back on the title
var players: Array = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var monuments: Array = []
var graffiti: Array = []
var ledger: Array = []
var gate_statues: Array = []
# THE GRUDGE LEDGER (THE ESTATE'S MEMORY): cross-night lifetime tallies keyed by
# player name — derived from what the house already records (ledger winners +
# superlatives, monuments, gate statues), plus a live events accumulator that
# games may feed via chronicle_event(). Read back as Executor-voiced
# observations in chronicle_lines(). Persisted in the slot save.
var chronicle: Dictionary = {}
var nights_played: int = 0
# Persistent per-player wallet + owned cosmetics. LEGACY is earned at
# night's end (your points + champion bonus) and only buys vanity.
var legacy: Dictionary = {}
var wardrobe: Dictionary = {}

var current_slot: int = 1
var run_active: bool = false
var run_night: int = 0
var at_boundary: bool = false
var run_match_nights: int = 3
var run_turn_cap: int = 12
var run_board_seed: int = 0
var run_positions: Array = []
var run_pennies: Array = []
var run_wreaths: Array = []
var run_inventory: Array = []
var classic_run_archive: Dictionary = {}
var _migration_retag_pending: bool = false
var _save_write_blocked: bool = false
var house_rules_shown: bool = false

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
	var old: String = ProjectSettings.globalize_path(LEGACY_SAVE_PATH)
	var slot1: String = ProjectSettings.globalize_path(slot_path(1))
	if FileAccess.file_exists(old) and not FileAccess.file_exists(slot1):
		DirAccess.copy_absolute(old, slot1)
		print("MIGRATE estate_save.json -> saves/slot_1.json")

func slot_path(n: int) -> String:
	return "%s/slot_%d.json" % [SAVE_DIR, n]

## One-line summary for the slot picker ("" = empty slot).
func slot_summary(n: int) -> String:
	if not FileAccess.file_exists(slot_path(n)):
		return ""
	var file: FileAccess = FileAccess.open(slot_path(n), FileAccess.READ)
	if file == null:
		return ""
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not data is Dictionary:
		return ""
	var nights: int = int((data as Dictionary).get("nights_played", 0))
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
	run_match_nights = 3
	run_turn_cap = 12
	run_board_seed = 0
	run_positions = []
	run_pennies = []
	run_wreaths = []
	run_inventory = []
	classic_run_archive = {}
	_migration_retag_pending = false
	_save_write_blocked = false
	house_rules_shown = false
	load_estate()

## NEW GAME: a fresh estate on this slot (wipes its history).
func new_game(n: int) -> void:
	current_slot = clampi(n, 1, 3)
	var p: String = ProjectSettings.globalize_path(slot_path(current_slot))
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
	var idx: Array = range(players.size())
	idx.sort_custom(func(a, b):
		if players[a].points != players[b].points:
			return players[a].points > players[b].points
		return a < b)
	return idx

func _plural(n: int, word: String) -> String:
	return "%d %s" % [n, word if n == 1 else word + "s"]

func add_monument(owner_idx: int, label: String) -> void:
	var pl: Dictionary = players[owner_idx]
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

func save_estate() -> bool:
	if _save_write_blocked:
		push_error("EstateState: save blocked until the pre-schema slot is archived safely")
		return false
	var f: FileAccess = FileAccess.open(slot_path(current_slot), FileAccess.WRITE)
	if f == null:
		return false
	var leg: Dictionary = {}
	var ward: Dictionary = {}
	for k in legacy:
		leg[str(k)] = legacy[k]
	for k in wardrobe:
		ward[str(k)] = wardrobe[k]
	var data: Dictionary = {
		"schema": SAVE_SCHEMA,
		"monuments": monuments, "graffiti": graffiti,
		"ledger": ledger, "nights_played": nights_played,
		"gate_statues": gate_statues, "chronicle": chronicle,
		"legacy": leg, "wardrobe": ward,
		"house_rules_shown": house_rules_shown,
		"run": {
			"active": run_active,
			"match_nights": run_match_nights,
			"turn_cap": run_turn_cap,
			"night_index": run_night,
			"at_boundary": at_boundary,
			"board_seed": run_board_seed,
			"positions": run_positions,
			"pennies": run_pennies,
			"wreaths": run_wreaths,
			"inventory": run_inventory,
		},
	}
	if not classic_run_archive.is_empty():
		data["classic_run_archive"] = classic_run_archive
	f.store_string(JSON.stringify(data, "  "))
	f.close()
	return true

func load_estate() -> void:
	if not FileAccess.file_exists(slot_path(current_slot)):
		return
	var f: FileAccess = FileAccess.open(slot_path(current_slot), FileAccess.READ)
	if f == null:
		return
	var source_text: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(source_text)
	if parsed is Dictionary:
		var data: Dictionary = _migrate_save_data(parsed as Dictionary)
		monuments = data.get("monuments", [])
		graffiti = data.get("graffiti", [])
		ledger = data.get("ledger", [])
		gate_statues = data.get("gate_statues", [])
		chronicle = data.get("chronicle", {})
		nights_played = int(data.get("nights_played", 0))
		var saved_legacy: Dictionary = data.get("legacy", {})
		for k in saved_legacy:
			legacy[int(k)] = int(saved_legacy[k])
		var saved_wardrobe: Dictionary = data.get("wardrobe", {})
		for k in saved_wardrobe:
			wardrobe[int(k)] = Array(saved_wardrobe[k])
		# Grandfather clause: saves from before the wardrobe existed get
		# credit for prior service, so nobody starts the store broke.
		if not data.has("legacy") and nights_played > 0:
			for i in 4:
				legacy[i] = nights_played * 15
		house_rules_shown = bool(data.get("house_rules_shown", false))
		var run: Dictionary = data.get("run", {})
		run_active = bool(run.get("active", false))
		run_match_nights = clampi(int(run.get("match_nights", 3)), 1, 5)
		run_turn_cap = clampi(int(run.get("turn_cap", 12)), 4, 40)
		run_night = int(run.get("night_index", 0))
		at_boundary = bool(run.get("at_boundary", false))
		run_board_seed = int(run.get("board_seed", 0))
		run_positions = Array(run.get("positions", []))
		run_pennies = Array(run.get("pennies", []))
		run_wreaths = Array(run.get("wreaths", []))
		run_inventory = Array(run.get("inventory", []))
		var archive_value: Variant = data.get("classic_run_archive", {})
		classic_run_archive = (archive_value as Dictionary).duplicate(true) \
			if archive_value is Dictionary else {}
		_rebuild_chronicle()
		if _migration_retag_pending:
			if save_estate():
				_migration_retag_pending = false
				print("SAVE_MIGRATION slot_%d re-tagged schema=%d" % [current_slot, SAVE_SCHEMA])
			else:
				push_error("SAVE_MIGRATION could not re-tag slot_%d" % current_slot)

## Version-absent files are schema 1. Copy the entire file before rewriting it,
## then retire its classic Trail run. An active run is embedded opaquely under
## classic_run_archive as well: its stone indices are evidence, never graph IDs.
func _migrate_save_data(source: Dictionary) -> Dictionary:
	var source_schema: int = int(source.get("schema", 1))
	if source_schema >= SAVE_SCHEMA:
		return source
	if not _archive_pre_schema_slot():
		_save_write_blocked = true
		push_error("SAVE_MIGRATION refused to rewrite slot_%d: archive copy failed" % current_slot)
		return source
	var migrated: Dictionary = source.duplicate(true)
	var legacy_run_value: Variant = migrated.get("run", {})
	var legacy_run: Dictionary = (legacy_run_value as Dictionary).duplicate(true) \
		if legacy_run_value is Dictionary else {}
	if bool(legacy_run.get("active", false)):
		migrated["classic_run_archive"] = {
			"schema": 1,
			"kind": "classic_trail",
			"notice": "Archived classic Trail state; stone indices are not Procession graph nodes.",
			"run": legacy_run,
		}
		push_warning("SAVE_MIGRATION archived active classic Trail run in slot_%d; it will not be resumed as graph state" % current_slot)
	migrated["run"] = _empty_run_payload()
	migrated["schema"] = SAVE_SCHEMA
	_migration_retag_pending = true
	return migrated

func _empty_run_payload() -> Dictionary:
	return {
		"active": false,
		"match_nights": 3,
		"turn_cap": 12,
		"night_index": 0,
		"at_boundary": false,
		"board_seed": 0,
		"positions": [],
		"pennies": [],
		"wreaths": [],
		"inventory": [],
	}

func _archive_pre_schema_slot() -> bool:
	var source_path: String = ProjectSettings.globalize_path(slot_path(current_slot))
	var archive_user_path: String = slot_path(current_slot).trim_suffix(".json") \
		+ ".pre-schema-v1.json"
	var archive_path: String = ProjectSettings.globalize_path(archive_user_path)
	if FileAccess.file_exists(archive_path):
		return true
	var copy_error: int = DirAccess.copy_absolute(source_path, archive_path)
	if copy_error != OK:
		return false
	print("SAVE_MIGRATION archived %s -> %s" % [slot_path(current_slot), archive_user_path])
	return true

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
	var pname: String = _player_name(p)
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
	var saved_events: Dictionary = {}
	if chronicle.has("by_name"):
		for nm in chronicle["by_name"]:
			var record_value: Variant = chronicle["by_name"][nm]
			if record_value is Dictionary:
				var record: Dictionary = record_value as Dictionary
				if record.has("events"):
					saved_events[nm] = (record["events"] as Dictionary).duplicate(true)
	chronicle = {"by_name": {}, "nights_recorded": ledger.size()}
	for entry in ledger:
		var winner: String = String(entry.get("winner", ""))
		if winner != "":
			_chron_rec(winner)["nights_won"] += 1
		for aw in entry.get("awards", []):
			var who: String = String(aw.get("who", ""))
			var title: String = String(aw.get("title", ""))
			if who == "" or title == "":
				continue
			var rec: Dictionary = _chron_rec(who)
			var key: String = title
			if title.begins_with("NEMESIS OF "):
				var prey: String = title.substr("NEMESIS OF ".length())
				var nof: Dictionary = rec["nemesis_of"]
				nof[prey] = int(nof.get(prey, 0)) + 1
				key = "THE NEMESIS"
			var tt: Dictionary = rec["titles"]
			tt[key] = int(tt.get(key, 0)) + 1
			if key == "THE DOORMAT":
				rec["lasts"] += 1
	for m in monuments:
		var owner: String = String(m.get("owner", ""))
		if owner == "":
			continue
		var mr: Dictionary = _chron_rec(owner)
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
		var won: int = int(r.get("nights_won", 0))
		var mons: int = int(r.get("monuments", 0))
		var lasts: int = int(r.get("lasts", 0))
		var manor: int = int(r.get("manor_taken", 0))
		var titles: Dictionary = r.get("titles", {})
		var nof: Dictionary = r.get("nemesis_of", {})
		var events: Dictionary = r.get("events", {})
		var title_total: int = 0
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
	var nights: int = int(chronicle.get("nights_recorded", 0))
	if nights >= 1:
		pool.append("The estate has recorded %s. It forgets none of them, however politely it is asked." % _plural(nights, "night"))
	if nights >= 4:
		pool.append("Four nights in, and no one has yet been kind without an audience. The estate had wagered as much.")
	var top_name: String = ""
	var top_mon: int = -1
	for pname in by:
		var mc: int = int(by[pname].get("monuments", 0))
		if mc > top_mon:
			top_mon = mc
			top_name = pname
	if top_name != "" and top_mon >= 2:
		pool.append("%s has more stones on the lawn than anyone. The estate assumes this is what they wanted." % top_name)
	pool.append("The estate has reviewed its records and finds everyone, on balance, guilty of something.")
	pool.append("Memory is the only inheritance the estate offers freely. It is also the one no one asked for.")
	if limit > 0 and pool.size() > limit:
		var copy: Array = pool.duplicate()
		for i in range(copy.size() - 1, 0, -1):
			var j: int = rng.randi_range(0, i)
			var tmp: Variant = copy[i]
			copy[i] = copy[j]
			copy[j] = tmp
		return copy.slice(0, limit)
	return pool
