extends Trap
## Short covered pipe. A ball rolling into either mouth passes straight through
## the channel and out the far end; a putt aimed OVER the tunnel is stopped by
## the roof. Static geometry only — the collision is two side walls plus a roof,
## open at both ends and along the floor so the ball can travel the bore.

func _init() -> void:
	trap_id = "tunnel"
	display_name = "TUNNEL"
	footprint_radius = 1.15
