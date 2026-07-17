class_name ProcessionTextFit
extends RefCounted
## Deterministic text auto-fit for THE PROCESSION's presentation surfaces (the
## reveal lower-third, the centre ceremony cards). Pure geometry over a Font —
## no rng, no sim state, no node tree — so it is safe to call on the headless
## receipt path (it renders nothing and never touches the tally) and it returns
## the SAME size on the couch and a net mirror.
##
## The estate's readings, reckonings and eulogies carry a lot of copy, and long
## player names + long clause lines are the usual box-breakers. Rather than clip
## or scroll, every surface measures its worst-case content with the REAL font it
## will draw in and picks the largest size that fits the band — matching how the
## Label/RichTextLabel word-wraps, so what we measure is what gets painted.

## Largest integer size in [min_size, max_size] at which `text` — word-wrapped at
## `width` px, with '\n' honoured as hard breaks — fits within `height` px. Falls
## to `min_size` when even that overflows (the caller then relies on the band it
## grew, or accepts the floor).
static func fit_size(font: Font, text: String, width: float, height: float,
		max_size: int, min_size: int) -> int:
	if font == null or width <= 1.0:
		return max_size
	for size in range(max_size, min_size, -1):
		if wrapped_height(font, text, width, size) <= height:
			return size
	return min_size

## The pixel height `text` occupies when word-wrapped at `width` in `size`, using
## the same greedy break the engine's AUTOWRAP_WORD does. 1.22 line-lead matches
## the fallback face's default spacing closely enough for layout budgeting.
static func wrapped_height(font: Font, text: String, width: float, size: int) -> float:
	var line_h := font.get_height(size) * 1.22
	var total := 0
	for para in text.split("\n"):
		total += maxi(1, _line_count(font, String(para), width, size))
	return float(total) * line_h

## Greedy word-wrap line count for one paragraph (no embedded newlines). A single
## word wider than the band still counts as one line — the engine breaks it too,
## but for budgeting we never under-count the paragraph, so the fit stays safe.
static func _line_count(font: Font, para: String, width: float, size: int) -> int:
	if para.strip_edges() == "":
		return 1
	var words := para.split(" ", false)
	var lines := 1
	var cur := ""
	for w in words:
		var trial := w if cur == "" else cur + " " + w
		if font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= width:
			cur = trial
		else:
			lines += 1
			cur = String(w)
	return lines

## Truncate `text` to fit `width` at `size` on ONE line, appending an ellipsis if
## it must cut. For fixed-width single-line surfaces (a name chip) that must never
## bleed past their frame. Returns the whole string when it already fits.
static func ellipsize(font: Font, text: String, width: float, size: int) -> String:
	if font == null or font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= width:
		return text
	var ell := "…"
	var out := text
	while out.length() > 1:
		out = out.substr(0, out.length() - 1)
		if font.get_string_size(out + ell, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= width:
			return out.strip_edges(false, true) + ell
	return ell
