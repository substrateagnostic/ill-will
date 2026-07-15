# 19 — THE PROCESSION: Integration & Merge Notes (2026-07-15)

How the finished board mode (`estate/procession/`) plugs into the estate shell.
Built per doc 18 (locked spec) and doc 13 §C Approach A. This lane owns ONLY
`estate/procession/` + one autoload line in `project.godot`; it does not touch
`estate.gd`, `core/party_setup.gd`, `core/player_input.gd`, or `minigames/*`.

## Two ways the board boots

1. **CLI (works today, no estate.gd change):** the `ProcessionBoot` autoload
   (`estate/procession/procession_boot.gd`, registered in `project.godot`) swaps
   the main scene to `procession.tscn` when `--procession` is on the command
   line, then the scene self-bootstraps its roster/seed/preset from the CLI:

   ```
   godot --path . -- --procession --seed=7 --autoplay=all-bots --deedgoal=4
   ```

   Flags the scene reads (see `procession.gd::_parse_cli`):
   `--seed=N` · `--deedgoal=4|6|9` · `--preset=quick_wake|short|full|vigil` ·
   `--autoplay=all-bots` (forces bots + fast, deterministic soak) ·
   `--realmini` (launch REAL minigame modules instead of the deterministic
   fast-sim) · `--slowsim` (keep ceremonies at full length for capture).

2. **From the estate PLAY menu (the merge):** paste the snippet below into
   `estate.gd`. `begin(config)` and the deferred self-bootstrap are mutually
   exclusive (a `_started` guard), so calling `begin()` from the shell wins and
   the CLI path stays dormant.

## The ≤20-line snippet the director pastes into estate.gd

Add a PLAY/selector button (`proc.pressed.connect(_enter_procession)`), then:

```gdscript
func _enter_procession() -> void:
    phase = Phase.GAME
    _net_set_ceremony({}); Music.stop(); _hide_title()
    banner.visible = false; phase_panel.visible = false
    var proc: Node = load("res://estate/procession/procession.tscn").instantiate()
    get_tree().root.add_child(proc)            # root, like modules (zombie-swept)
    var roster: Array = []
    for pl in EstateState.players:
        roster.append({"index": pl.index, "name": pl.name, "color": pl.color,
            "char_scene": CHAR_PATHS[pl.index], "device": PlayerInput.device_of(pl.index),
            "bot": _is_bot(pl.index)})
    proc.night_over.connect(func(_tally):
        if is_instance_valid(proc): proc.queue_free()
        _enter_selector(), CONNECT_ONE_SHOT)
    proc.begin({"roster": roster, "seed": EstateState.rng.randi(),
        "deed_goal": clampi(int(PartySetup.pref("deed_goal", 4)), 4, 9)})
```

`night_over(tally: Dictionary)` fires once at HEIR CROWNED; the tally carries
`{seed, preset, rounds, heir, heir_name, grudge[], deeds[], moved[], positions[]}`.
The heir is already written to `EstateState.monuments` (kind=`"heir"`) and the
estate saved before the signal fires, so the shell only needs to fold the scene
and return home.

## Online mirror (Phase 2 pump — one line at merge)

`procession.gd` exposes `_net_state()` / `_net_apply()` from day one, matching
the greed/estate house pattern. To fan it to guests, the shell reuses its
existing 20 Hz module pump exactly as for a contract minigame — set the mirror
id when the board launches:

```gdscript
if NetSession.is_host() and proc.has_method("_net_state"):
    _net_mirror_id = "procession"; _net_module_seq = 0; _net_module_accum = 0.0
```

Guests boot the same scene in mirror mode (`NetSession.is_client()` → the scene
simulates nothing and renders `_net_apply` truth only). Putt intents are
seat-attributed via `pawn_putt.submit_remote_intent(seat, power, release_tick)`;
the host simulates and mirrors resolve identically.

## Optional night-setup dial

`PartySetup.pref("deed_goal", 4)` gates length (4/6/9 = Short/Full/Vigil). The
QUICK WAKE preset (`--preset=quick_wake`, decision-layer-off, minigame score =
movement, two laps) is the old Pilgrimage Trail's soul, preserved as a preset.
Expose the dial in the lobby the same way `mg_rounds` is exposed — no board
code change needed; `begin({"preset": "quick_wake"})` or `{"deed_goal": 6}`.

## Files delivered

| File | Role |
|---|---|
| `procession.gd` | night state machine + HUD + net mirror + tally |
| `board_path.gd` | 24-space looping rail, furniture, roving Codicil beacon |
| `board_spaces.gd` | the announced space grammar (effects table) |
| `pawn_putt.gd` | simultaneous hold-release putt roll (frozen Par physics) |
| `codicil.gd` | Deed economy (10 + 2/Deed) + relocation |
| `executor_host.gd` | reveal cascade voice (~40 dry line variants) + camera |
| `presets.gd` | Quick Wake / Short / Full / Vigil dials |
| `procession.tscn` | self-bootable scene (root = procession.gd) |
| `procession_boot.gd` | `--procession` CLI boot autoload |
