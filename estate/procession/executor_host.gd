class_name ProcessionExecutor
extends Node
## THE EXECUTOR — dice-master and host of the wake. He owns the serial half of
## every round: the staggered REVEAL cascade where each landing is named, one
## victim at a time, camera pushed in. His register is the will-reading voice
## from estate.gd — dry, formal, and quietly delighted by everyone's misfortune.
##
## Presentation only: the state machine (procession.gd) decides WHAT happened
## and applies it; the Executor only decides how cruelly to phrase it. All line
## choices are drawn from a passed-in seeded RNG, so the couch and a net mirror
## hear the same eulogy.

# ~40 dry line variants, pooled by the beat they narrate. %s slots are filled
# by procession.gd with player names (already colour-tagged in the banner).
const GREETING := [
	"Good evening. You are all here for the reading, whether you know it or not.",
	"Welcome to the procession. Please keep your grudges inside the carriage at all times.",
	"The estate is open. The estate is always open. The estate is never glad to see you.",
	"Four mourners, one manor, no witnesses worth the name. Let us begin.",
]
const SHRINE := [
	"%s kneels at the shrine and is rewarded. The shrine will want that back.",
	"The shrine blesses %s (+3♠). It has low standards and a long memory.",
	"%s gains at the shrine. Piety pays, this once, under protest.",
	"The saints smile on %s. The saints have never met %s.",
	"%s is favoured. The estate has logged the anomaly for review.",
]
const GRAVE := [
	"%s weeps at the grave (−2♠). The grave has wept harder for less.",
	"The weeping grave takes its due from %s. It does not itemise.",
	"%s pays the ground what the ground is owed. Everyone does, eventually.",
	"A grave for %s. Not theirs. Not yet. Two grudge, all the same.",
	"%s mourns, briefly and expensively.",
]
const GRAVE_TOLL := [
	"%s weeps on %s's monument — and %s collects the tears (%d♠).",
	"The grave belongs to %s. %s learns this the way everyone does: by paying.",
	"%s's headstone bills %s %d♠ for the trespass. The dead keep excellent books.",
]
const STALL := [
	"%s takes something sharp from the stall. No refunds, no receipts, no remorse.",
	"The stall arms %s. The stall would like it noted it warned nobody.",
	"%s pockets a grievance-in-a-box. Do use it responsibly, which is to say don't.",
	"%s shops the stall. The estate approves of premeditation.",
]
const CODICIL := [
	"%s buys a Deed. The ink is wet and already contested.",
	"%s claims the Codicil. Somewhere a lawyer feels a disturbance and smiles.",
	"A Deed to %s. Ownership is nine-tenths of the haunting.",
	"%s pays the Codicil's price. The price, naturally, goes up.",
	"%s takes a Deed and the Codicil takes a walk. Chase it.",
]
const CODICIL_SHORT := [
	"%s eyes the Codicil and finds the price beyond them. The estate is not a charity.",
	"The Codicil declines %s for want of funds. Grieve, then earn.",
]
const SEANCE := [
	"The planchette moves. Nobody admits to pushing it. The estate has its suspicions.",
	"A séance opens. The dead are, as ever, unhelpfully opinionated.",
	"The circle turns for the whole table. Misery, at last, distributed fairly.",
	"The medium speaks. The estate transcribes. Everyone pays attention or pays later.",
]
const TOLLGATE_TAKE := [
	"%s owns the tollgate now. Congratulations on the paperwork.",
	"The tollgate answers to %s. Passage will cost the rest of you dearly and often.",
	"%s collects the pot and the deed to the gate. A landlord is born, unmourned.",
]
const TOLLGATE_PASS := [
	"%s passes %s's gate and pays for the privilege (2♠).",
	"The tollgate bills %s on the way through. %s does not rise to thank them.",
]
const VENDETTA := [
	"%s and %s settle it the estate's way — quietly, and for money.",
	"A vendetta ripens between %s and %s. The higher stake walks away heavier.",
	"%s stares at %s across five spaces. Sealed bids. Old wounds. New debts.",
]
const VENDETTA_RESULT := [
	"%s out-stakes %s and takes the difference. Grudges compound.",
	"%s wins the wager over %s. The estate admires a decisive cruelty.",
	"The vendetta breaks %s's way. %s adds it to the list they keep.",
]
const BLANK := [
	"%s lands on nothing. A merciful administrative error.",
	"%s finds bare stone. The estate resents the missed opportunity.",
	"Nothing befalls %s. This is not the same as safety.",
]
const HOUSE_AWAKENS := [
	"THE HOUSE AWAKENS. The manor's shadow walks the drive. Reach a safe stone or fall behind.",
	"Something in the house remembers you. Run for the marked stones.",
	"The shadow sweeps the procession. It is not particular about whom it catches.",
]
const HOUSE_LOSER := [
	"The shadow takes %s two steps back. The house keeps what it touches.",
	"%s is caught in the dark and slips back. The estate does not offer a hand.",
]
const WILL_OPEN := [
	"The estate has reviewed the evening's conduct and finds it, on the whole, actionable.",
	"The will is read. It was written some time ago, and about all of you.",
]

var banner: RichTextLabel = null   # procession supplies the reveal banner
var cam: Camera3D = null           # procession supplies the live camera

func setup(reveal_banner: RichTextLabel, camera: Camera3D) -> void:
	banner = reveal_banner
	cam = camera

## Fill one line from a pool by seeded index (deterministic).
static func pick(pool: Array, rng: RandomNumberGenerator, args: Array = []) -> String:
	var raw: String = String(pool[rng.randi_range(0, pool.size() - 1)])
	if args.is_empty():
		return raw
	return raw % args

## Show a reveal line in the banner, colour-keyed to the acting seat. The push-
## in is driven by procession (it owns the anchor); this only paints the text.
func say(text: String, color: Color) -> void:
	if banner == null:
		return
	banner.clear()
	banner.push_color(color)
	banner.push_font_size(40)
	banner.append_text(text)
	banner.pop_all()
	banner.visible = true

func clear_banner() -> void:
	if banner:
		banner.visible = false

var _aim := Vector3.ZERO   # live look-at target, tracked every frame while set
var _aiming := false

func _process(_delta: float) -> void:
	# Keeping the aim in _process lets a position tween and the look direction
	# resolve together without a fragile per-step method tween.
	if _aiming and is_instance_valid(cam):
		cam.look_at(_aim, Vector3.UP)

## THE DECIDING-MOMENT push toward a landing (reuses the FinalStretch language).
func push_to(anchor: Vector3, look_at: Vector3) -> void:
	if cam == null:
		return
	_aim = look_at
	_aiming = true
	var tw := cam.create_tween()
	tw.tween_property(cam, "global_position", anchor, 0.5) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func reset_camera(home_pos: Vector3, look_at: Vector3, dur := 0.5) -> void:
	if cam == null:
		return
	_aim = look_at
	_aiming = true
	var tw := cam.create_tween()
	tw.tween_property(cam, "global_position", home_pos, dur) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
