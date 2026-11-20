extends SceneTree
## Regenerates res://themes/airrons_fall.tres from scripts/ui/af_theme.gd.
## godot --headless --path . --script res://tools/build_af_theme.gd
func _init() -> void:
	var t: Theme = AfTheme.build()
	var err := ResourceSaver.save(t, AfTheme.THEME_PATH)
	print("saved ", AfTheme.THEME_PATH, " err=", err)
	quit(0 if err == OK else 1)
