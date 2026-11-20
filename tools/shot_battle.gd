extends SceneTree
# Side-view battle review shots: godot --path . --resolution 1280x720 --script res://tools/shot_battle.gd -- --out=/tmp/aqb
var g
var out := "/tmp/aqb"
func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	g = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(g)
	_run()
func shot(n: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out + "/" + n + ".png")
func wait(ms: float) -> void:
	await create_timer(ms / 1000.0).timeout
func wait_blue() -> void:
	var guard := 0
	while guard < 200 and not (g.G.active != null and g.G.active.team == "blue" and g.G.mode == "select"):
		await wait(50); guard += 1
func _run() -> void:
	await wait(700)
	g.AUTO = false
	g.start_fight(3)
	await wait(1600)
	await wait_blue()
	await wait(500)
	await shot("b1_manual_menu")
	g.cmd_hover = 1
	g.G.cmd = "abilities"
	await wait(400)
	await shot("b2_abilities")
	g.G.cmd = ""
	g.cmd_attack()
	await wait(400)
	await shot("b3_target")
	var e = g.alive("red")[0]
	g.cmd_target(e)
	await wait(1400)
	await shot("b4_after_attack")
	g.AUTO = true
	g.start_fight(1)
	await wait(2600)
	await shot("b5_boss_auto")
	quit()
