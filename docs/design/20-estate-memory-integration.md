# 20 — THE ESTATE'S MEMORY: estate.gd integration (paste-ready)

The memory features (MomentScribe capture, the newsreel, the family album, the
grudge-ledger chronicle) are self-contained NEW files plus tiny hooks the lanes
already touched (`core/final_stretch.gd`, `core/podium.gd`,
`estate/estate_state.gd`). Everything below is the ONE file this lane may not
edit — `estate/estate.gd` — collected here as exact snippets for the director to
apply at merge. Nothing here changes behaviour until it is pasted.

New files this depends on (already committed by this lane):
- `core/moment_scribe.gd` (autoload `MomentScribe`, registered in project.godot)
- `estate/newsreel.gd` + `estate/newsreel.tscn` (`class_name Newsreel`)
- `estate/family_album.gd` (`class_name FamilyAlbumWall`, incl. static archive API)
- `assets/shaders/newsreel.gdshader`

All four are already exercised by the `--newsreel-test`, `--album-test`,
`--chronicle-test` boots (handled inside MomentScribe) and by the echo_chamber
end-to-end capture — see the lane's VERIFY report.

---

## 1. Tell the scribe which game is on screen (precise metadata)

MomentScribe already infers the game by scanning the scene tree, so this is an
accuracy nicety, not a requirement. Two one-liners.

In `_do_launch_game(id, practice)`, right after the existing
`_net_game_name = String(info.name)` (≈ line 1944):

```gdscript
	_net_game_name = String(info.name)
	MomentScribe.note_game(id)          # <-- ADD: label captures with the game id
```

In `_on_module_finished(results)`, near the top where the module is torn down
(≈ line 1988, alongside `_net_mirror_id = ""`):

```gdscript
	_net_mirror_id = ""
	MomentScribe.clear_game()           # <-- ADD: back on the grounds
```

---

## 2. Play the newsreel before the will, then archive to the album

The night's stills are the newsreel; after it plays they become the album. This
sits in `_night_ceremonies()` (≈ line 2154), between the podium and the will.

Replace this tail of `_night_ceremonies()`:

```gdscript
	await podium.done
	podium.queue_free()
	cam.current = true
	banner.visible = false
	_enter_will_reading(champ)
```

with:

```gdscript
	await podium.done
	podium.queue_free()
	cam.current = true
	banner.visible = false
	# THE ESTATE'S MEMORY: the night's newsreel plays before the will is read,
	# then its stills are archived into the family album and the reel is reset.
	var reel_moments := MomentScribe.night_moments()
	if not reel_moments.is_empty():
		await _play_newsreel(reel_moments)
	FamilyAlbumWall.archive(reel_moments, EstateState.current_slot)
	MomentScribe.clear_night()
	_refresh_album_wall()               # rebuild the grounds gallery with tonight's frames
	_enter_will_reading(champ)
```

Add this helper anywhere in estate.gd (e.g. just below `_enter_will_reading`):

```gdscript
## Host-side silent-film ceremony (net mirrors stay on the night_podium facts
## until the will facts arrive — the newsreel is host-screen only this phase,
## exactly like the minigames). Blocks until the reel finishes or is skipped.
func _play_newsreel(moments: Array) -> void:
	var done := [false]
	Newsreel.play(moments, func(): done[0] = true)
	while not done[0]:
		await get_tree().process_frame
```

Notes:
- `Newsreel.play` overlays a `CanvasLayer` (layer 128) and frees itself on done.
- It is skippable by unanimous A-press of the seated humans; all-bots
  exhibitions play it through. It reads `PlayerInput` read-only.
- If nothing was captured (a very short night), `reel_moments` is empty and the
  ceremony proceeds straight to the will, unchanged.

---

## 3. One or two chronicle observations during the will reading

In `_enter_will_reading(champ)`, after the vendetta block and BEFORE the
`_net_set_ceremony({"stage": "will", ...})` call (≈ line 2196), insert:

```gdscript
	# THE GRUDGE LEDGER: the estate recalls a pattern or two from across the
	# nights, in the same dry register as the will. These fade in with the
	# award stagger below (they start at modulate.a == 0, like the award rows).
	for cl in EstateState.chronicle_lines(2):
		var chl := Label.new()
		chl.text = String(cl)
		chl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		chl.custom_minimum_size = Vector2(680, 0)
		chl.add_theme_font_size_override("font_size", 15)
		chl.add_theme_color_override("font_color", Color(0.75, 0.72, 0.85))
		chl.modulate.a = 0.0
		phase_box.add_child(chl)
```

The existing stagger loop (`for c in phase_box.get_children(): if c is Label and
c.modulate.a == 0.0:`) already fades these in — no extra tween needed.

Optional net parity: to mirror the observations to guests, add them to the
ceremony fact, e.g. `... "chronicle": EstateState.chronicle_lines(2)` inside the
`_net_set_ceremony({"stage": "will", ...})` dict, and render them client-side
alongside the award rows. Not required for couch play.

---

## 4. The family album on the grounds (walk-up gallery)

### 4a. Instance/refresh the wall

Add a member and a refresh helper (the wall rebuilds each time you return to the
grounds so newly-archived nights appear):

```gdscript
var _album_wall: FamilyAlbumWall = null

func _refresh_album_wall() -> void:
	if _album_wall != null and is_instance_valid(_album_wall):
		_album_wall.queue_free()
	_album_wall = FamilyAlbumWall.new()
	_album_wall.slot = EstateState.current_slot
	$Grounds.add_child(_album_wall)
	# A quiet corner of the grounds, angled toward the lawn.
	_album_wall.global_position = Vector3(-6.6, 1.7, 2.2)
	_album_wall.rotation.y = deg_to_rad(22)
```

Call `_refresh_album_wall()` once when the grounds are first set up (e.g. at the
end of `_spawn_executor()`, which also parents its props under `$Grounds`) so the
gallery is present in free roam, and it is already re-called after each newsreel
in §2.

### 4b. The walk-up hotspot (STROLL_SPOTS pattern, ≈ line 1185)

Add a spot to `STROLL_SPOTS`:

```gdscript
const STROLL_SPOTS := [
	{"name": "THE THEATER", "pos": Vector3(6.4, 0, -5.6), "r": 2.6, "act": "selector"},
	{"name": "THE WARDROBE", "pos": Vector3(-3.0, 0, -2.2), "r": 2.2, "act": "wardrobe"},
	{"name": "THE FAMILY ALBUM", "pos": Vector3(-6.6, 0, 2.2), "r": 2.4, "act": "album"},  # <-- ADD
]
```

And a branch in `_exit_stroll(open_act)`'s match:

```gdscript
		"wardrobe":
			_build_wardrobe_panel()
		"album":                         # <-- ADD
			_build_album_panel()
```

A minimal panel (the wall is the real exhibit; the panel is the Executor's
caption for it). Add:

```gdscript
func _build_album_panel() -> void:
	_clear_panel("THE FAMILY ALBUM", Color(0.9, 0.85, 0.7))
	var n := FamilyAlbumWall.entries(EstateState.current_slot).size()
	var l := Label.new()
	if n == 0:
		l.text = "The estate has taken no portraits yet. Give it a night; it is patient, and it is watching."
	else:
		l.text = "%s hang in the salon. The estate remembers every face it has framed, and forgives none of them." % _plural_nights(n)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(640, 0)
	phase_box.add_child(l)
	var btn := Button.new()
	btn.text = "BACK TO THE GROUNDS"
	btn.pressed.connect(_build_freeroam_panel)
	phase_box.add_child(btn)

func _plural_nights(n: int) -> String:
	return "%d portrait%s" % [n, "" if n == 1 else "s"]
```

(If you prefer no panel at all, drop the `"album"` branch and the panel func;
the wall alone reads fine as a walk-past exhibit.)

---

## Summary of estate.gd edits

| Location | Edit |
|---|---|
| `_do_launch_game` ≈1944 | `MomentScribe.note_game(id)` |
| `_on_module_finished` ≈1988 | `MomentScribe.clear_game()` |
| `_night_ceremonies` ≈2154 | newsreel → album archive → clear_night → refresh wall |
| new helper | `_play_newsreel(moments)` |
| `_enter_will_reading` ≈2196 | 1–2 `EstateState.chronicle_lines(2)` rows |
| new member + helper | `_album_wall`, `_refresh_album_wall()` |
| `_spawn_executor` end | call `_refresh_album_wall()` once |
| `STROLL_SPOTS` ≈1185 | add THE FAMILY ALBUM spot |
| `_exit_stroll` match | add `"album"` branch + `_build_album_panel()` |

No existing lines are removed except the five-line tail of `_night_ceremonies`
shown in §2, which is reproduced verbatim inside its replacement.
