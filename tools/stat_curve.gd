extends SceneTree
# Prints hero stats by level and raid enemy stats: godot --headless --path . --script res://tools/stat_curve.gd
func _init() -> void:
	var g = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(g)
	await create_timer(0.2).timeout
	for lv in [1, 10, 25, 50, 75, 99]:
		var line := "L%d " % lv
		for h in g.HERO_NAMES:
			g.HERO_PROG[h] = {"level": lv, "xp": 0}
			var st: Dictionary = g.compute_hero_stats(h)
			line += "%s hp%d atk%d def%d arm%d spd%d | " % [h.substr(0, 3), st.hp, st.atk, st.def, st.armor, st.speed]
		print(line)
	for k in ["torch", "tnt", "barrel", "necro"]:
		for n in [3, 2, 1]:
			var s: Dictionary = g.char_stats("Voss", k, "red", n)
			print("%s n%d hp%d atk%d def%d arm%d" % [k, n, s.hp, s.atk, s.def, s.armor])
	quit()
