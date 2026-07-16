extends Object
class_name Voice
## Presentation-side line pools for ILL WILL (see docs/design/26-voice-bible).
##
## Selection uses a LOCAL RandomNumberGenerator, seeded off the system clock —
## never the game's simulation RNG and never on a receipt/tally path. Drawing a
## flavor banner must never perturb sim determinism or a --*test receipt, so this
## helper keeps its own independent stream. Output is display-only: every caller
## feeds the result straight into a Label / RichTextLabel and nothing else.
##
## This is Voice B's variety engine — the line that fires most often needs the
## most variants (Hades' lesson, doc §2). Pools live next to the code that shows
## them; this file only picks.

static var _rng: RandomNumberGenerator = null


static func _stream() -> RandomNumberGenerator:
	if _rng == null:
		_rng = RandomNumberGenerator.new()
		_rng.randomize()
	return _rng


## Draw one line from `pool`. Presentation-only. Safe from any display path;
## never call where a receipt or tally reads the returned text.
static func pick(pool: PackedStringArray) -> String:
	if pool.is_empty():
		return ""
	var r: RandomNumberGenerator = _stream()
	var idx: int = r.randi_range(0, pool.size() - 1)
	var line: String = pool[idx]
	return line


## Draw one line, then fill its %-placeholders from `args` (in order). Every
## line in `pool` must carry the same placeholder count as `args`.
static func pick_fmt(pool: PackedStringArray, args: Array) -> String:
	var line: String = pick(pool)
	if line.is_empty() or args.is_empty():
		return line
	return line % args
