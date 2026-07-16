extends Node3D
## Podium probe (E1 — THE CORONATION). Instantiates the reusable end-of-session
## Podium and stages FOUR fake heirs — the real KayKit character scenes the game
## uses, distinct colours/names, ranks 0-3, each wearing a cosmetic hat — so the
## redressed estate set can be judged from screenshots. Uses stage_entries (NOT
## present) so the tableau holds indefinitely; VerifyCapture handles --shots+quit.
##
## Run (windowed, so the viewport renders):
##   godot --path . tools/podium_probe.tscn -- --shots=2,3,90 --outdir=verify_out/e1_podium
## Precedent: tools/monument_probe.tscn/gd.

const CHAR_SCENES := [
	"res://assets/models/kaykit/Barbarian.glb",
	"res://assets/models/kaykit/Knight.glb",
	"res://assets/models/kaykit/Mage.glb",
	"res://assets/models/kaykit/Rogue.glb",
]
# rank -> [name, colour, cosmetic hat id] — hats prove the tableau frames with
# worn cosmetics, per the podium contract.
const HEIRS := [
	["GOLD", Color(0.95, 0.78, 0.20), "tophat_monocle"],
	["RED", Color(0.90, 0.25, 0.22), "viking_helm"],
	["BLUE", Color(0.30, 0.50, 0.95), "party_cone"],
	["MINT", Color(0.35, 0.90, 0.65), "jester_cap"],
]

func _ready() -> void:
	var podium := Podium.new()
	add_child(podium)
	var entries: Array = []
	for rank in HEIRS.size():
		var h: Array = HEIRS[rank]
		entries.append({
			"name": h[0], "color": h[1], "rank": rank,
			"char_scene": load(CHAR_SCENES[rank]),
			"cosmetics": [h[2]],
		})
	podium.stage_entries(entries)
	print("PODIUM_PROBE staged=%d" % entries.size())
