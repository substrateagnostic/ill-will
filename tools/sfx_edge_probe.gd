extends SceneTree
## Verification probe: load each declicked UI sample the way the game does and
## read the imported AudioStreamWAV's raw PCM to prove first == last == 0.
## Run: godot --headless --path . --script res://tools/sfx_edge_probe.gd

func _initialize() -> void:
	var names := ["click_001", "click_002", "click_003",
		"confirmation_001", "drop_001", "error_004", "bong_001"]
	for n in names:
		var s: AudioStreamWAV = load("res://assets/audio/%s.wav" % n)
		var data: PackedByteArray = s.data
		var fmt := s.format          # 1 = FORMAT_16_BITS
		var stereo := s.stereo
		# 16-bit little-endian PCM: first sample at byte 0, last at byte size-2.
		var first := data.decode_s16(0)
		var last := data.decode_s16(data.size() - 2)
		var peak := 0
		var i := 0
		while i < data.size():
			var v: int = abs(data.decode_s16(i))
			if v > peak:
				peak = v
			i += 2
		print("SFXEDGE %-17s fmt=%d stereo=%s bytes=%5d first=%d last=%d peak=%d"
			% [n, fmt, str(stereo), data.size(), first, last, peak])
	quit()
