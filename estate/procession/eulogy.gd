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

# ---- framing pools (no-repeat-two-nights on opener/closer) -------------------
const OPENER := [
	"We are gathered, as the estate is always gathered, to read aloud what the night had already decided.",
	"The wake is spent. The estate will now account for it, name by name, as it accounts for everything.",
	"Sit. The reading is brief, the verdicts briefer, and the estate has never once been kept waiting.",
	"The night is closed. What follows is not eulogy so much as itemisation, in the estate's steady hand.",
	"Attend. The estate has balanced the evening, and finds, as always, that grief was the only currency spent freely.",
]
const CLOSER := [
	"The will is written. It was always written. Take your grief to the door; the estate keeps the rest.",
	"So concludes the reckoning. The estate thanks you for your custom, and remembers all of it, however politely it is asked.",
	"That is the night, entire and without appeal. The manor will see you again; it always does.",
	"The reading rests. Your debts are noted, your kindnesses doubted, and the door is, as ever, that way.",
	"The estate closes the ledger. Nothing is forgiven, but everything is filed, which the estate finds nearly the same.",
]

# ---- per-descriptor commendations (2-3 variants; %s slots documented) --------
const L_HEIR := [           # [name, deeds_phrase]
	"We commend %s, who bought %s with other people's grief and now owns a house that owns them back.",
	"%s took %s tonight and called it grief management. The estate calls it acquisition, and files it so.",
	"To %s, who leaves with %s and the room's resentment — an heir the estate can, at last, do business with.",
]
const L_BETRAYED := [       # [name, lost]
	"We remember %s, who bled %d Grudge into other hands and called it Tuesday.",
	"%s paid %d Grudge to graves and gates tonight, sincerely and without recourse. The estate rounds the sincerity down.",
	"%s gave %d Grudge to the ground and the tolls. Generosity, the estate notes, is only ever involuntary here.",
]
const L_BLOODY := [         # [name, duels]
	"%s settled matters %s tonight, quietly and for money. The estate approved the paperwork retroactively.",
	"To %s, who won %s and lost the room. The estate keeps the receipts, and the room.",
]
const L_HOARDER := [        # [name, grudge]
	"%s ends the night %d Grudge richer and not one Deed the wiser. The estate admires a full purse and an empty claim.",
	"%s hoarded %d Grudge and spent it on nothing. The manor respects the discipline; the will does not reward it.",
]
const L_MOURNER := [        # [name, graves_phrase]
	"%s wept at %s tonight, expensively. Grief, the estate observes, is the one thing here that pays no dividend.",
	"%s knelt at %s and asked the dead for nothing they could give. The estate found the manners unusual.",
]
const L_PIOUS := [          # [name, shrines_phrase]
	"%s knelt at %s and was rewarded, this once, under protest. Piety, the estate notes, is a poor annuity.",
	"%s took the shrines' small mercies %s over. The saints have never met them, and intend to keep it that way.",
]
const L_IDLE := [           # [name]
	"%s walked the drive and troubled no one, which the estate finds either saintly or suspicious, and files as both.",
	"%s spent the night largely unbilled. The estate resents the missed opportunity, and notes the name.",
]
# The one warm line — a genuine kindness, then undercut. [name, graves_phrase]
const L_WARM := [
	"And %s — who took from no one all night, and wept at %s besides — was, in the estate's cold estimation, almost kind. The anomaly has been logged for review.",
	"One kindness is recorded: %s harmed no one tonight, and paid at %s for the privilege. The estate has filed it under mercy, provisionally, in pencil.",
]

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

	# --- one commendation per seat, keyed to its most salient deed ---
	# Order the seats by Deeds ascending so the heir's line lands last.
	var order: Array = []
	for i in n:
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		if int(deeds[a]) != int(deeds[b]):
			return int(deeds[a]) < int(deeds[b])
		return a < b)
	for seat in order:
		if int(seat) == kind:
			continue   # the warm line covers this seat, near the end
		lines.append(_seat_line(int(seat), roster, stats, deeds, grudge, heir, prng))

	# --- the warm line (if a kindness happened) ---
	if kind >= 0:
		var gname := String((roster[kind] as Dictionary).get("name", "SOMEONE"))
		var gph := _graves_phrase(int((stats[kind] as Dictionary).get("graves", 0)))
		lines.append(String(_pick(L_WARM, prng)) % [gname, gph])

	# --- a chronicle echo, if the estate remembers anything across nights ---
	if chron != "":
		lines.append("The estate adds, for the record: " + chron)

	# --- closer (exclude last night's) ---
	var cl := _pick_avoiding(CLOSER.size(), int(last.get("closer", -1)), prng)
	lines.append(String(CLOSER[cl]))

	return {"lines": lines, "opener": op, "closer": cl}

## One seat's line, keyed to the stat that most defines their night.
static func _seat_line(seat: int, roster: Array, stats: Array, deeds: Array,
		grudge: Array, heir: int, prng: RandomNumberGenerator) -> String:
	var name := String((roster[seat] as Dictionary).get("name", "SOMEONE"))
	var st: Dictionary = stats[seat]
	var lost := int(st.get("lost", 0))
	var duels := int(st.get("duels", 0))
	var graves := int(st.get("graves", 0))
	var shrines := int(st.get("shrines", 0))
	var bought := int(st.get("deeds_bought", 0))
	var g := int(grudge[seat])
	if seat == heir and int(deeds[seat]) > 0:
		return String(_pick(L_HEIR, prng)) % [name, _deeds_phrase(int(deeds[seat]))]
	# salience-scored descriptors
	var best := "idle"
	var best_v := 0.0
	# Hoarding is a FAT purse and NO claim; if they bought a Deed they plainly
	# spent, so the hoarder read collapses and their other deeds speak instead.
	var cand := {
		"bloody": float(duels) * 2.0,
		"betrayed": float(lost) * 1.0,
		"hoarder": (float(g) * 0.2) if bought > 0 else float(g) * 0.9,
		"mourner": float(graves) * 1.6,
		"pious": float(shrines) * 1.2,
	}
	for k in cand:
		if float(cand[k]) > best_v:
			best_v = float(cand[k])
			best = String(k)
	match best:
		"bloody": return String(_pick(L_BLOODY, prng)) % [name, _count_phrase(duels, "score", "scores")]
		"betrayed": return String(_pick(L_BETRAYED, prng)) % [name, lost]
		"hoarder": return String(_pick(L_HOARDER, prng)) % [name, g]
		"mourner": return String(_pick(L_MOURNER, prng)) % [name, _graves_phrase(graves)]
		"pious": return String(_pick(L_PIOUS, prng)) % [name, _shrines_phrase(shrines)]
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
