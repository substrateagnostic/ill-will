class_name ShakeKit
extends RefCounted
## THE ROLL — the rotational half of the house screenshake (doc 08 §A.8, revisited).
##
## Every game's `_shake` drives a translational camera jitter only
## (`h_offset`/`v_offset`, or a `position` nudge). Jan Willem Nijman's "The Art of
## Screenshake" makes the point that pure positional jitter reads as a *glitch*;
## a fraction of a degree of camera ROLL is what reads as physical *force*. This
## helper adds that missing roll, layered on top of each site's existing envelope
## so it decays with the same `_shake` it already computes.
##
## PRESENTATION ONLY. It touches `Camera3D.rotation.z` and a private meta key on
## the camera. It never reads or writes sim state, an rng stream, physics, or the
## clock. Call sites pass a `jitter` value they ALREADY drew for the translational
## offset — no new random number is consumed, so every receipt stays byte-identical
## (the roll is a pure function of numbers the frame already had).
##
## MAGNITUDE: MAX_ROLL_DEG at full trauma (`_shake` ~= 1.0), scaling linearly down
## the existing decay envelope. Kept deliberately tiny — the diorama cameras sit at
## ~30-50deg pitch, where a large roll would swim (doc 08 §D warned against
## *big* roll at this distance); a tenth of a degree of jitter is the force signal,
## not a Dutch angle. At the anthology's heaviest shake (echo's 0.9) this is 0.45deg.
##
## DRIFT-FREE for both rig styles. `roll()` absolute-sets `rotation.z` relative to a
## per-camera base captured on first use, so it is correct whether the caller keeps
## a static camera basis (the `h_offset`/`v_offset` and position-only rigs) or
## rewrites `global_transform` to a stored base every frame (greed/widows/
## pallbearers). Static-basis rigs must call `clear()` from their rest branch (the
## same place they zero `h_offset`); transform-reset rigs need no `clear()` because
## their own reset already returns the basis to base each frame.

const MAX_ROLL_DEG := 0.5

## Apply this frame's roll. `trauma` is the caller's current `_shake`; `jitter` is a
## value in [-1, 1] REUSED from the translational-offset draw the caller just made.
static func roll(cam: Camera3D, trauma: float, jitter: float) -> void:
	if cam == null:
		return
	if not cam.has_meta(&"_shake_base_z"):
		cam.set_meta(&"_shake_base_z", cam.rotation.z)
	var ang := deg_to_rad(MAX_ROLL_DEG) * clampf(trauma, 0.0, 1.0) * clampf(jitter, -1.0, 1.0)
	cam.rotation.z = float(cam.get_meta(&"_shake_base_z")) + ang

## Settle the roll back to the captured base — mirror of `h_offset = 0` in the shake
## block's rest branch. No-op if the camera was never rolled.
static func clear(cam: Camera3D) -> void:
	if cam == null or not cam.has_meta(&"_shake_base_z"):
		return
	cam.rotation.z = float(cam.get_meta(&"_shake_base_z"))
