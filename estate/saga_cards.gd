class_name SagaCards
extends RefCounted

## THE CEREMONY SAGA (W2). The estate keeps a real cross-night chronicle but has
## only ever whispered it. These three beats make the saga speak, in the estate's
## own probate register (doc 26): death is administrative, kindness is a
## liability, no one is flattered and nothing is shouted. All player-facing voice
## for the saga lives HERE, in one reviewable place; estate.gd only renders it.
##
##   1. STANDING GRUDGE  — a night-open card: who reigns, who is on a streak,
##      who remains winless, and any armed reprisal. Before the first auction.
##   2. FUNERAL AUDIT    — the run-end itemised audit, after the heir is named.
##   3. EULOGY RECEIPT   — the will-reading's closing transaction block.
##
## Every function reads ONLY what the slot already records (ledger, chronicle,
## monuments, night_stats). No new schema, no writes.

# ---- shared helpers -------------------------------------------------------

static func _plural(n: int, word: String) -> String:
	return "%d %s" % [n, word if n == 1 else word + "s"]

## "three-peat" is the idiom for a third straight; past that the estate just counts.
static func _peat(n: int) -> String:
	match n:
		3: return "three-peat"
		4: return "four-peat"
		5: return "five-peat"
	return "%d straight" % n

static func _name_idx(name: String) -> int:
	return GameState.PLAYER_NAMES.find(name)

static func _by_name() -> Dictionary:
	return EstateState.chronicle.get("by_name", {})

# ---- 1. STANDING GRUDGE ---------------------------------------------------

## Only a human table on night 2+ earns the opening card: nights already on the
## books (nights_played > 0), the night's first auction (games_played == 0), and
## not shown yet this night. Soaks (all bots) and guests (clients) skip it, per
## the READY_GATE_TIME idiom — a soak never sees the ceremony chrome.
static func should_show_standing_grudge(estate) -> bool:
	if NetSession.is_client() or estate._all_bots():
		return false
	if EstateState.nights_played <= 0 or EstateState.games_played != 0:
		return false
	if EstateState.ledger.is_empty():
		return false
	return estate._standing_grudge_night != EstateState.nights_played

static func maybe_show_standing_grudge(estate) -> bool:
	if not should_show_standing_grudge(estate):
		return false
	show_standing_grudge(estate)
	return true

## The standing accounts, read as the estate reviews them before play. 3-6 lines:
## the reigning heir (and a streak, if one stands), the most persistent of the
## winless, and any reprisal still open on the books. Each line carries `who`
## (a player index, or -1 for the institution) so estate.gd can colour it.
static func standing_grudge_lines() -> Array:
	var lines: Array = []
	var ledger: Array = EstateState.ledger
	if ledger.is_empty():
		return lines
	var by: Dictionary = _by_name()
	var reigning: String = String((ledger.back() as Dictionary).get("winner", ""))
	var reign_idx: int = _name_idx(reigning)
	var reign_wins: int = int((by.get(reigning, {}) as Dictionary).get("nights_won", 0))
	# Tail streak: consecutive most-recent nights taken by the reigning name.
	var streak: int = 0
	for k in range(ledger.size() - 1, -1, -1):
		if String((ledger[k] as Dictionary).get("winner", "")) == reigning:
			streak += 1
		else:
			break
	if streak >= 2:
		lines.append({"text": "The estate has answered to %s %s running." % [reigning, _plural(streak, "night")], "who": reign_idx})
		lines.append({"text": "%s goes for the %s tonight. The estate keeps a chisel warm, on principle." % [reigning, _peat(streak + 1)], "who": reign_idx})
	else:
		lines.append({"text": "The estate answers, for now, to %s, with %s to their name." % [reigning, _plural(reign_wins, "night")], "who": reign_idx})
	# A sole leader in total nights, if it is not the reigning name, is noted too.
	var best_wins: int = -1
	var leaders: Array = []
	for nm in by:
		var w: int = int((by[nm] as Dictionary).get("nights_won", 0))
		if w > best_wins:
			best_wins = w
			leaders = [String(nm)]
		elif w == best_wins:
			leaders.append(String(nm))
	if best_wins > 0 and leaders.size() == 1 and String(leaders[0]) != reigning:
		var ldr: String = String(leaders[0])
		lines.append({"text": "%s holds more nights than anyone, and holds them without apology." % ldr, "who": _name_idx(ldr)})
	# The winless: the one with the longest record of finishing last.
	var winless: String = ""
	var most_lasts: int = 0
	for nm in by:
		var rec: Dictionary = by[nm]
		if int(rec.get("nights_won", 0)) == 0:
			var l: int = int(rec.get("lasts", 0))
			if l > most_lasts:
				most_lasts = l
				winless = String(nm)
	if winless != "":
		lines.append({"text": "%s remains, in the estate's assessment, persistent." % winless, "who": _name_idx(winless)})
	# An armed reprisal (last night's nemesis, unsettled): the account left open.
	var vend: Dictionary = EstateState.vendetta
	if not vend.is_empty() and EstateState.vendetta_settled_by < 0:
		var hunter: int = int(vend.get("hunter", -1))
		var prey: int = int(vend.get("prey", -1))
		if hunter >= 0 and prey >= 0:
			var hn: String = GameState.PLAYER_NAMES[hunter]
			var pn: String = GameState.PLAYER_NAMES[prey]
			lines.append({"text": "A reprisal stands on the books: %s came for %s. The estate has left the matter open." % [hn, pn], "who": prey})
	return lines

## The card. Mirrors the HOUSE RULES beat: local, host-only chrome (guests hold on
## the prior stage, as they do for house rules), a plain dismiss button that opens
## the night's first auction. No per-frame gate machinery — a lone insurance timer
## keeps an idle table from stalling forever.
static func show_standing_grudge(estate) -> void:
	estate._standing_grudge_active = true
	estate._standing_grudge_night = EstateState.nights_played
	estate._strolling = false
	Sfx.play("card")
	estate._hide_title()
	estate.banner.visible = false
	estate._clear_panel("THE STANDING GRUDGE", Color(0.9, 0.8, 0.4))
	var sub := Label.new()
	sub.text = "Before the night opens, the estate reviews the accounts still standing."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(720, 0)
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", Color(0.85, 0.8, 0.95))
	estate.phase_box.add_child(sub)
	for line in standing_grudge_lines():
		var l := Label.new()
		l.text = "·  " + String(line.get("text", ""))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(720, 0)
		l.add_theme_font_size_override("font_size", 18)
		var who: int = int(line.get("who", -1))
		if who >= 0 and who < GameState.PLAYER_COLORS.size():
			l.add_theme_color_override("font_color", GameState.PLAYER_COLORS[who])
		estate.phase_box.add_child(l)
	var sig := Label.new()
	sig.text = "— The Executor"
	sig.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sig.add_theme_font_size_override("font_size", 15)
	sig.add_theme_color_override("font_color", Color(0.85, 0.8, 0.95))
	sig.modulate.a = 0.8
	estate.phase_box.add_child(sig)
	print("STANDING_GRUDGE shown night=%d games=%d" % [EstateState.nights_played + 1, EstateState.games_played])
	var btn := Button.new()
	btn.text = "TO THE FIRST AUCTION"
	btn.custom_minimum_size = Vector2(300, 54)
	btn.pressed.connect(func(): _dismiss_standing_grudge(estate))
	estate.phase_box.add_child(btn)
	btn.grab_focus()
	VerifyCapture.snap("standing_grudge")
	# Insurance only: an unattended table cannot hang on the card. The button is
	# the real exit; a stale timer that fires after a dismiss no-ops on the flag.
	estate.get_tree().create_timer(30.0).timeout.connect(func():
		if estate._standing_grudge_active:
			_dismiss_standing_grudge(estate))

static func _dismiss_standing_grudge(estate) -> void:
	if not estate._standing_grudge_active:
		return
	estate._standing_grudge_active = false
	Sfx.play("confirm")
	estate._enter_auction()

# ---- 2. FUNERAL AUDIT (run end) -------------------------------------------

## The estate closes the books when the manor changes hands. An itemised audit of
## the whole tenure, read-only over what the slot recorded: nights kept,
## monuments raised, reprisals settled, kindnesses (none — the estate had
## budgeted for this), then the heir, then a souring commendation. `who` colours
## the heir's line; -1 is the institution.
static func funeral_audit_lines(heir_idx: int) -> Array:
	var lines: Array = []
	var nights: int = EstateState.nights_played
	var monuments: int = EstateState.monuments.size()
	var reck: int = 0
	for e in EstateState.ledger:
		for aw in (e as Dictionary).get("awards", []):
			if String((aw as Dictionary).get("title", "")) == "THE RECKONER":
				reck += 1
	lines.append({"text": "Tenure: %s kept, and counted." % _plural(nights, "night"), "who": -1})
	if monuments > 0:
		lines.append({"text": "Monuments raised: %d. The lawn is spoken for." % monuments, "who": -1})
	else:
		lines.append({"text": "Monuments raised: none. The estate found the restraint suspicious.", "who": -1})
	if reck > 0:
		lines.append({"text": "Grudges settled: %s. The estate keeps the remainder open." % _plural(reck, "account"), "who": -1})
	else:
		lines.append({"text": "Grudges settled: none. The estate keeps every one of them open.", "who": -1})
	lines.append({"text": "Kindnesses recorded: none. The estate had budgeted for this.", "who": -1})
	if heir_idx >= 0 and heir_idx < GameState.PLAYER_NAMES.size():
		lines.append({"text": "The manor, and its debts, pass to %s." % GameState.PLAYER_NAMES[heir_idx], "who": heir_idx})
	# The commendation: souring, and its arithmetic is the estate's own. Fewer
	# reprisals settled reads as a lower class of griever; kindness never counts.
	var pct: int = clampi(3 + reck * 5, 1, 40)
	lines.append({"text": "The account ranks in the %s percentile of grievers. The estate rates it, in candour, actionable." % _ordinal(pct), "who": -1})
	return lines

static func _ordinal(n: int) -> String:
	var suffix := "th"
	if n % 100 < 11 or n % 100 > 13:
		match n % 10:
			1: suffix = "st"
			2: suffix = "nd"
			3: suffix = "rd"
	return "%d%s" % [n, suffix]

# ---- 3. EULOGY RECEIPT (will close) ---------------------------------------

## The will-reading's closing transaction block. The estate does not mourn; it
## processes. Goodwill is booked provisionally, kindness is filed as a liability
## pending an audit that will not come, and the remains are reallocated. Rendered
## as a stamped receipt at the foot of the reading.
static func eulogy_receipt_lines() -> Array:
	return [
		{"text": "FUNERAL PROCESSED.", "header": true},
		{"text": "Goodwill recognised: +1, provisional.", "header": false},
		{"text": "Kindness logged to the liability column, pending audit.", "header": false},
		{"text": "Remains: reallocated.", "header": false},
	]

# ---- verification hooks (dev-only, windowed; drive real card renders) ------

## Seat two humans (so the soak-skip does not fire), arm a reprisal so the
## vendetta line renders, then drive the real _enter_auction gate for a shot of
## THE STANDING GRUDGE. Reads whatever multi-night history the slot holds (run
## this on scratch slot 3). No save is written and no party_setup is touched —
## seat assignment here is in-memory only for the shot.
static func schedule_standing_grudge_test(estate) -> void:
	estate.get_tree().create_timer(1.2).timeout.connect(func():
		estate._hide_title()
		estate.get_node("UI/TopBar").set("visible", true)
		PlayerInput.assign(0, -1)
		PlayerInput.set_bot(0, false)
		PlayerInput.assign(1, -2)
		PlayerInput.set_bot(1, false)
		PlayerInput.set_bot(2, true)
		PlayerInput.set_bot(3, true)
		EstateState.games_played = 0
		# Arm a reprisal from the recorded history so the vendetta beat shows.
		if EstateState.vendetta.is_empty():
			EstateState.vendetta = {"hunter": 0, "prey": 3}
			EstateState.vendetta_settled_by = -1
		estate._standing_grudge_night = -1
		estate._rebuild_top_bar()
		estate._enter_auction()
		print("STANDINGGRUDGETEST active=%s" % str(estate._standing_grudge_active))
		estate.get_tree().create_timer(1.2).timeout.connect(func(): estate.get_tree().quit()))

## Drive the run-end audit card directly (heir = GOLD by default), over the
## slot's recorded history. Snaps "funeral_audit" from inside the card.
static func schedule_funeral_stats_test(estate) -> void:
	estate.get_tree().create_timer(1.2).timeout.connect(func():
		estate._hide_title()
		estate._dev_set_phase_night_end()
		estate._enter_funeral_statistics(2)
		# Wait past the fade-in stagger so the in-card snap lands before quit.
		estate.get_tree().create_timer(5.5).timeout.connect(func(): estate.get_tree().quit()))

## Drive the REAL run-over ceremony (podium -> heir -> THE FINAL AUDIT) end to
## end with an all-bot table, so the button/timer wiring out of _run_over into
## the audit is exercised, not just the audit card in isolation. Writes to the
## active slot (run this on scratch slot 3).
static func schedule_run_over_test(estate) -> void:
	estate.get_tree().create_timer(1.2).timeout.connect(func():
		for i in 4:
			PlayerInput.set_bot(i, true)
		estate._hide_title()
		estate._run_over(2)
		estate.get_tree().create_timer(12.0).timeout.connect(func(): estate.get_tree().quit()))

## Drive the will reading directly so the EULOGY RECEIPT close renders under the
## real chronicle lines. Snaps "will_reading" from inside the reading.
static func schedule_eulogy_receipt_test(estate) -> void:
	estate.get_tree().create_timer(1.2).timeout.connect(func():
		estate._hide_title()
		# start_night populates night_stats/players so night_superlatives (empty
		# awards here) does not read an unseeded dict. It writes no save.
		EstateState.start_night(4)
		estate._dev_set_phase_night_end()
		estate._enter_will_reading(EstateState.players[2])
		# Wait past the fade-in stagger so the in-reading snap lands before quit.
		estate.get_tree().create_timer(5.5).timeout.connect(func(): estate.get_tree().quit()))
