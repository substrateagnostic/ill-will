class_name ProcessionEulogy
extends RefCounted
## THE EULOGY (doc 24 F33) — the night's wildcard, and its thesis.
##
## A procedurally-authored closing monologue assembled from the night's REAL
## conduct: `procession.stats[]` (each seat's moved / graves / lost / duels /
## shrines / deeds_bought / spent), the ending Deeds and Grudge, and the
## EstateState chronicle. It names each mourner by what they ACTUALLY did — who
## grasped, who bled, who hoarded, who took from no one — surfaces one genuine
## kindness if one occurred, then undercuts it administratively. Mario Party
## cannot do this: it has no persistent per-player narrative. ILL WILL does.
##
## The embodied Executor reads it over the lower-third at the will-reading, right
## before the heir is crowned (the body IS present there — the board is still up;
## the newsreel proper is another lane's wiring, so this delivers as embodied
## lower-thirds, the sanctioned fallback in the brief). It must never repeat its
## framing two nights running, so the OPENER and CLOSER indices are persisted to
## our own small file and excluded on the next build.
##
## PRESENTATION ONLY. Selection draws from a PRESENTATION rng seeded off the
## night, never the sim stream, and delivery is gated behind `not _fast`, so the
## headless soak never assembles or reads a word of it and the receipt holds.

const LAST_FILE := "user://saves/eulogy_last.json"

# ---- framing + commendation pools ---------------------------------------------
# All the eulogy's prose now lives in dialog.json ("eulogy.*"); these getters
# fetch the current pools. %s/%d slots are documented per pool below and filled at
# the call site. Selection indexes by pool SIZE (no-repeat guard on opener/closer,
# random elsewhere), so an edit that keeps each pool's line count stays stable.
static var OPENER: Array:
	get: return Dialog.paras("eulogy.opener")
static var CLOSER: Array:
	get: return Dialog.paras("eulogy.closer")
static var L_HEIR: Array:              # [name, deeds_phrase]
	get: return Dialog.paras("eulogy.heir")
static var L_BETRAYED: Array:          # [name, lost]
	get: return Dialog.paras("eulogy.betrayed")
static var L_BLOODY: Array:            # [name, duels]
	get: return Dialog.paras("eulogy.bloody")
static var L_HOARDER: Array:           # [name, grudge]
	get: return Dialog.paras("eulogy.hoarder")
static var L_MOURNER: Array:           # [name, graves_phrase]
	get: return Dialog.paras("eulogy.mourner")
static var L_PIOUS: Array:             # [name, shrines_phrase]
	get: return Dialog.paras("eulogy.pious")
static var L_IDLE: Array:              # [name]
	get: return Dialog.paras("eulogy.idle")
static var L_WARM: Array:              # [name, graves_phrase]
	get: return Dialog.paras("eulogy.warm")

## Build the eulogy — 6-9 lines, fully formatted. Returns
## {lines: Array[String], opener: int, closer: int} so the caller can persist
## the framing choices for the no-repeat guard.
static func build(roster: Array, stats: Array, deeds: Array, grudge: Array,
		prng: RandomNumberGenerator, last: Dictionary, chron: String = "") -> Dictionary:
	var n: int = roster.size()
	var lines: Array[String] = []

	# --- opener (exclude last night's) ---
	var op := _pick_avoiding(OPENER.size(), int(last.get("opener", -1)), prng)
	lines.append(String(OPENER[op]))

	# --- superlatives from the real night ---
	var heir := _argmax_deeds(deeds, grudge)
	# The one genuine kindness: a seat that won no duel (took from no rival) AND
	# actually suffered a loss (so it is restraint, not luck). Prefer the one who
	# bled the most among them — the most-wronged pacifist.
	var kind := -1
	for i in n:
		var st: Dictionary = stats[i]
		if int(st.get("duels", 0)) == 0 and int(st.get("lost", 0)) > 0:
			if kind < 0 or int(st.get("lost", 0)) > int((stats[kind] as Dictionary).get("lost", 0)):
				kind = i

	# --- one commendation per seat, keyed to its most salient deed. Each seat
	# gets a DISTINCT descriptor (assigned greedily by salience) so no template
	# family repeats within a single eulogy. Ordered by Deeds ascending so the
	# heir's line lands last. ---
	var order: Array = []
	for i in n:
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		if int(deeds[a]) != int(deeds[b]):
			return int(deeds[a]) < int(deeds[b])
		return a < b)
	var heir_gets_line := int(deeds[heir]) > 0
	var need: Array = []
	for seat in order:
		if int(seat) == kind:
			continue
		if int(seat) == heir and heir_gets_line:
			continue
		need.append(int(seat))
	var assigned := _assign_descriptors(need, stats, grudge)
	for seat in order:
		if int(seat) == kind:
			continue   # the warm line covers this seat, near the end
		if int(seat) == heir and heir_gets_line:
			var hname := String((roster[seat] as Dictionary).get("name", "SOMEONE"))
			lines.append(String(_pick(L_HEIR, prng)) % [hname, _deeds_phrase(int(deeds[seat]))])
		else:
			lines.append(_format_desc(String(assigned.get(int(seat), "idle")),
				int(seat), roster, stats, grudge, prng))

	# --- the warm line (if a kindness happened) ---
	if kind >= 0:
		var gname := String((roster[kind] as Dictionary).get("name", "SOMEONE"))
		var gph := _graves_phrase(int((stats[kind] as Dictionary).get("graves", 0)))
		lines.append(String(_pick(L_WARM, prng)) % [gname, gph])

	# --- a chronicle echo, if the estate remembers anything across nights ---
	if chron != "":
		lines.append(Dialog.text("eulogy.chronicle_prefix") + chron)

	# --- closer (exclude last night's) ---
	var cl := _pick_avoiding(CLOSER.size(), int(last.get("closer", -1)), prng)
	lines.append(String(CLOSER[cl]))

	return {"lines": lines, "opener": op, "closer": cl}

## Salience of each descriptor for one seat. Hoarding is a FAT purse and NO
## claim; if they bought a Deed they plainly spent, so the hoarder read collapses.
static func _scores(seat: int, stats: Array, grudge: Array) -> Dictionary:
	var st: Dictionary = stats[seat]
	var bought := int(st.get("deeds_bought", 0))
	var g := int(grudge[seat])
	return {
		"bloody": float(st.get("duels", 0)) * 2.0,
		"betrayed": float(st.get("lost", 0)) * 1.0,
		"hoarder": (float(g) * 0.2) if bought > 0 else float(g) * 0.9,
		"mourner": float(st.get("graves", 0)) * 1.6,
		"pious": float(st.get("shrines", 0)) * 1.2,
	}

## Greedily give each seat a DISTINCT descriptor (highest salience first), so no
## two seats draw the same template family in one eulogy. Seats with nothing to
## say fall to "idle".
static func _assign_descriptors(seats: Array, stats: Array, grudge: Array) -> Dictionary:
	var triples: Array = []
	for seat in seats:
		var sc := _scores(int(seat), stats, grudge)
		for d in sc:
			triples.append({"seat": int(seat), "desc": String(d), "v": float(sc[d])})
	triples.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["v"]) > float(b["v"]))
	var out: Dictionary = {}
	var used_desc: Dictionary = {}
	for t in triples:
		var s := int(t["seat"])
		var d := String(t["desc"])
		if out.has(s) or used_desc.has(d) or float(t["v"]) <= 0.0:
			continue
		out[s] = d
		used_desc[d] = true
	for seat in seats:
		if not out.has(int(seat)):
			out[int(seat)] = "idle"
	return out

## Format one seat's assigned descriptor into a line.
static func _format_desc(desc: String, seat: int, roster: Array, stats: Array,
		grudge: Array, prng: RandomNumberGenerator) -> String:
	var name := String((roster[seat] as Dictionary).get("name", "SOMEONE"))
	var st: Dictionary = stats[seat]
	match desc:
		"bloody": return String(_pick(L_BLOODY, prng)) % [name, _count_phrase(int(st.get("duels", 0)), "score", "scores")]
		"betrayed": return String(_pick(L_BETRAYED, prng)) % [name, int(st.get("lost", 0))]
		"hoarder": return String(_pick(L_HOARDER, prng)) % [name, int(grudge[seat])]
		"mourner": return String(_pick(L_MOURNER, prng)) % [name, _graves_phrase(int(st.get("graves", 0)))]
		"pious": return String(_pick(L_PIOUS, prng)) % [name, _shrines_phrase(int(st.get("shrines", 0)))]
	return String(_pick(L_IDLE, prng)) % [name]

# ---- delivery ----------------------------------------------------------------
## Read the eulogy over the lower-third, framed on the embodied host. Gated
## behind `not _fast`; uses the procession's own `_beat` so all-players-press-A
## still skips it, and its `_cap_snap` for the verification still.
static func deliver(proc: Node, executor: Object) -> void:
	if proc._fast:
		return
	var prng := RandomNumberGenerator.new()
	var night := 0
	var es := proc.get_node_or_null(^"/root/EstateState")
	if es != null:
		night = int(es.nights_played)
	prng.seed = hash("eulogy_%d_%d" % [int(proc.seed_value), night])
	var last := _load_last()
	# Pull one cross-night chronicle fact WITHOUT touching EstateState's rng —
	# chronicle_lines(0) returns the unshuffled pool; we pick with our own prng.
	var chron := ""
	if es != null and es.has_method("chronicle_lines"):
		var pool: Array = es.chronicle_lines(0)
		if not pool.is_empty():
			chron = String(pool[prng.randi_range(0, pool.size() - 1)])
	var built := build(proc.roster, proc.stats, proc.deeds, proc.grudge, prng, last, chron)
	var lines: Array = built["lines"]
	_save_last({"opener": int(built["opener"]), "closer": int(built["closer"])})

	proc._hide_announce()
	proc._reveal_seat = -1
	if executor.has_body():
		executor.frame_body(1.1)
		await proc.get_tree().create_timer(0.7).timeout
	var gold := Color(0.94, 0.86, 0.55)
	for i in lines.size():
		print("EULOGY %02d | %s" % [i + 1, String(lines[i])])   # verify aid (dev-only print)
		executor.say_eulogy(String(lines[i]), gold, i)
		if proc._capture and i == 1:
			await proc._cap_snap("eulogy")
		await proc._beat(3.2)
	executor.clear_banner()
	executor.settle_body()
	if executor.board != null:
		executor.reset_camera(proc._cam_home, executor.board.CENTER, 0.6)

# ---- helpers -----------------------------------------------------------------
static func _argmax_deeds(deeds: Array, grudge: Array) -> int:
	var best := 0
	for i in range(1, deeds.size()):
		if int(deeds[i]) > int(deeds[best]) \
				or (int(deeds[i]) == int(deeds[best]) and int(grudge[i]) > int(grudge[best])):
			best = i
	return best

static func _pick(pool: Array, prng: RandomNumberGenerator) -> String:
	return String(pool[prng.randi_range(0, pool.size() - 1)])

static func _pick_avoiding(size: int, avoid: int, prng: RandomNumberGenerator) -> int:
	if size <= 1:
		return 0
	var idx := prng.randi_range(0, size - 1)
	if idx == avoid:
		idx = (idx + 1) % size
	return idx

static func _deeds_phrase(n: int) -> String:
	if n <= 1:
		return "a single Deed"
	return "%d Deeds" % n

static func _graves_phrase(n: int) -> String:
	if n <= 0:
		return "no graves at all"
	if n == 1:
		return "a single grave"
	return "%s graves" % _num_word(n)

static func _shrines_phrase(n: int) -> String:
	if n == 1:
		return "once"
	return "%s times" % _num_word(n)

static func _count_phrase(n: int, one: String, many: String) -> String:
	if n <= 1:
		return "a lone %s" % one
	return "%s %s" % [_num_word(n), many]

static func _num_word(n: int) -> String:
	match n:
		2: return "two"
		3: return "three"
		4: return "four"
		5: return "five"
		6: return "six"
	return str(n)

static func _load_last() -> Dictionary:
	if not FileAccess.file_exists(LAST_FILE):
		return {}
	var f := FileAccess.open(LAST_FILE, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}

static func _save_last(sig: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://saves"))
	var f := FileAccess.open(LAST_FILE, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(sig))
