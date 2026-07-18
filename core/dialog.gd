extends Node
## DIALOG — the single source of truth for every player-facing line of PROSE in
## ILL WILL (Executor speeches, estate instructions, game-intro guides, ceremony
## readings). All of it lives in ONE hand-editable file, res://dialog/dialog.json,
## so Alex can rewrite any line without touching a .gd script. Speech pools, the
## instruction cards, and the ceremony readings all pull their text through here.
##
## The JSON is a tree of nested objects; leaves are either a String or an Array of
## strings. A dotted key walks the tree ("executor.pause" -> the whole pool;
## "executor.pause.1" -> one line of it). Two accessors:
##   Dialog.text(key)  -> String   (a lone line; if the leaf is an array, line 0)
##   Dialog.paras(key) -> Array    (paragraphs / pool variants; a lone String
##                                   is wrapped as a one-element array)
##
## GRACEFUL BY DESIGN: a missing key never crashes the game. text() returns the
## key itself and pushes a warning; paras() returns [key]. Placeholders ({name},
## %s, %d) are stored verbatim and formatted at the call site — never here.

const DIALOG_PATH := "res://dialog/dialog.json"

var _data: Dictionary = {}
var _loaded := false

func _ready() -> void:
	reload()

## (Re)read dialog.json from disk. Safe to call at runtime — a dev can edit the
## file and call Dialog.reload() to see it live.
func reload() -> void:
	_data = {}
	_loaded = false
	if not FileAccess.file_exists(DIALOG_PATH):
		push_warning("Dialog: %s not found — every key will fall back to itself." % DIALOG_PATH)
		return
	var f := FileAccess.open(DIALOG_PATH, FileAccess.READ)
	if f == null:
		push_warning("Dialog: could not open %s (err %d)." % [DIALOG_PATH, FileAccess.get_open_error()])
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		_data = parsed
		_loaded = true
	else:
		push_warning("Dialog: %s did not parse to a JSON object." % DIALOG_PATH)

## Walk a dotted key through the nested tree. Dictionaries index by segment;
## Arrays index by a trailing integer segment. Returns null if the path breaks.
func _resolve(key: String) -> Variant:
	var cur: Variant = _data
	for seg in key.split("."):
		if cur is Dictionary and (cur as Dictionary).has(seg):
			cur = (cur as Dictionary)[seg]
		elif cur is Array and seg.is_valid_int():
			var idx := int(seg)
			var arr := cur as Array
			if idx < 0 or idx >= arr.size():
				return null
			cur = arr[idx]
		else:
			return null
	return cur

## True if the key resolves to something (String or Array). Lets a call site
## keep its own inline fallback for an optional line without tripping a warning.
func has(key: String) -> bool:
	var v: Variant = _resolve(key)
	return v is String or v is Array

## One line for `key`. A String leaf is returned as-is; an Array leaf returns its
## first element (handy for a titled single line stored beside a pool). Missing
## key -> the key itself, with a warning, so the game reads oddly but never dies.
func text(key: String) -> String:
	var v: Variant = _resolve(key)
	if v is String:
		return v as String
	if v is Array and not (v as Array).is_empty():
		return String((v as Array)[0])
	push_warning("Dialog.text: missing key '%s'" % key)
	return key

## The paragraph list / pool for `key`. An Array leaf is returned verbatim (its
## size is stable, so a seeded RNG pick over it stays deterministic); a lone
## String is wrapped as [str]. Missing key -> [key], with a warning.
func paras(key: String) -> Array:
	var v: Variant = _resolve(key)
	if v is Array:
		return v as Array
	if v is String:
		return [v as String]
	push_warning("Dialog.paras: missing key '%s'" % key)
	return [key]
