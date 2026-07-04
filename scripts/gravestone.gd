extends Node3D

func setup(color: Color, round_num: int) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.6
	$BasePlate.set_surface_override_material(0, mat)
	$Epitaph.text = "R.I.P.\nR%d" % round_num
	$Epitaph.modulate = color.lightened(0.5)
