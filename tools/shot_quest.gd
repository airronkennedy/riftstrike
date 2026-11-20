extends SceneTree
# Airron's Quest review shots: godot --path . --resolution 960x540 --script res://tools/shot_quest.gd -- --out=/tmp/aq
var g
var out := "/tmp/aq"
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
func _run() -> void:
	await wait(800)
	await shot("01_title")
	g.open_compendium()
	g.COMP.set_tab(2)
	await wait(250)
	await shot("02_keepers_p1")
	g.COMP.step_page(1)
	await wait(200)
	await shot("03_keepers_p2")
	g.COMP.set_tab(3)
	await wait(200)
	await shot("04_foes")
	g.menu_back()
	g.AUTO = false
	for n in [3, 2, 1]:
		g.start_fight(n)
		await wait(1700)
		await shot("%02d_battle_%s" % [8 - n * 1, {3: "raid", 2: "elite", 1: "boss"}[n]])
	g.AUTO = true
	g.speed = 3
	var guard := 0
	while g.phase != "results" and guard < 900:
		await wait(100); guard += 1
	await wait(600)
	await shot("08_results")
	quit()
