class_name Minigame
extends Node3D
## THE MODULE CONTRACT for anthology minigames. External builders: read this
## file top to bottom; docs/specs/anthology-module-contract.md is the prose
## version.
##
## A minigame is one scene whose root extends Minigame (or duck-types it:
## same signal + method). The party shell instantiates it, calls begin(),
## and waits for `finished`. The minigame NEVER touches global scores or
## scene-switching — it reports results and the shell handles the rest.
##
## CONFIG dictionary passed to begin():
##   roster: Array of player dicts:
##     { index: int,            # stable player id 0..3
##       name: String,          # display name ("RED")
##       color: Color,          # identity color, use it everywhere
##       char_scene: String,    # res:// path to KayKit .glb for avatars
##       device: int }          # PlayerInput device id (see player_input.gd)
##   rounds: int                # requested length knob (game interprets)
##   rng_seed: int              # SEED YOUR RNG FROM THIS; no Date/randomize
##   practice: bool             # true = hub training mode, no stakes
##
## RESULTS dictionary emitted via finished:
##   placements: Array[int]     # player indices best->worst (ties: earlier
##                              #   index first; include EVERY roster player)
##   points: Dictionary         # player index -> int score earned (raw,
##                              #   shell converts to party currency)
##   currency_events: Array of  # the spite economy - report these!
##     { type: String,          # "royalty" | "grudge"
##       player: int, amount: int, reason: String }
##   highlights: Array[String]  # 0-3 one-liners for the recap screen,
##                              #   e.g. "BLUE died to BLUE'S own crusher"
##   monuments: Array of        # OPTIONAL permanent marks for the board
##     { player: int, kind: String, label: String }

signal finished(results: Dictionary)

func begin(_config: Dictionary) -> void:
	push_error("Minigame.begin() not implemented")

## Call this instead of emitting `finished` directly - it validates shape.
func report_finished(results: Dictionary) -> void:
	var problems := validate_results(results, -1)
	for p in problems:
		push_warning("Minigame results problem: " + p)
	finished.emit(results)

static func validate_results(r: Dictionary, roster_size: int) -> Array:
	var problems: Array = []
	if not r.has("placements") or not r.placements is Array:
		problems.append("missing placements array")
	elif roster_size > 0 and r.placements.size() != roster_size:
		problems.append("placements must include every roster player")
	if not r.has("points") or not r.points is Dictionary:
		problems.append("missing points dictionary")
	for ev in r.get("currency_events", []):
		if not (ev.has("type") and ev.has("player") and ev.has("amount")):
			problems.append("malformed currency_event: " + str(ev))
	return problems
