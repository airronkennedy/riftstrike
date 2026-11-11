extends SceneTree
# Visual smoke test: godot --path . --script res://tools/shot_world.gd -- --out=/tmp/ws
var g
var out := "/tmp/ws"
func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	var sc: PackedScene = load("res://main.tscn")
	g = sc.instantiate()
	root.add_child(g)
	_run()
func shot(n: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out + "/" + n + ".png")
func wait(ms: float) -> void:
	await create_timer(ms / 1000.0).timeout
func _run() -> void:
	await wait(600)
	await shot("00_title")
	g.ow_ready = false
	g.open_overworld()
	await wait(900)
	await shot("01_rivenbrook")
	g.ow_menu_open = true
	await wait(200)
	await shot("02_menu")
	g.ow_open_menu_screen("map")
	await wait(300)
	await shot("03_map_region")
	g.WMAP.tab = "local"
	await wait(200)
	await shot("04_map_local")
	g.resume_overworld()
	g.ow_open_menu_screen("stats")
	await wait(200)
	await shot("05_stats_compare")
	g.STATS.mode = "breakdown"
	await wait(200)
	await shot("06_stats_breakdown")
	g.resume_overworld()
	# walk east out of town into the meadow
	g.ow_x = 1150.0; g.ow_y = 500.0; g.ow_tx = g.ow_x; g.ow_ty = g.ow_y
	g.ow_camx = g.ow_x; g.ow_camy = g.ow_y
	await wait(700)
	await shot("07_meadow_banner")
	# into wild grass at (23,4)
	g.ow_x = 23 * 64 + 32.0; g.ow_y = 4 * 64 + 40.0; g.ow_camx = g.ow_x; g.ow_camy = g.ow_y
	g.WORLD.enc_mult = 4.0
	var guard := 0
	while g.phase != "battle" and guard < 400:
		var tx: float = (20 if (guard / 40) % 2 == 0 else 27) * 64 + 32.0
		if absf(g.ow_x - tx) < 8: guard += 40 - guard % 40
		g.ow_tx = tx; g.ow_ty = g.ow_y
		await wait(50)
		guard += 1
	await wait(500)
	await shot("08_in_grass_or_battle")
	print("phase ", g.phase, " enc ", g.encounter)
	await wait(1200)
	await shot("09_battle")
	var px: float = g.ow_x
	g.run_battle()
	await wait(300)
	await shot("10_after_run")
	print("after run phase ", g.phase, " screen ", g.screen, " pos ", g.ow_x, " same ", absf(g.ow_x - px) < 0.1)
	# gate toast near the fort north gate
	g.ow_x = 105 * 64 + 32.0; g.ow_y = 18 * 64 + 40.0; g.ow_camx = g.ow_x; g.ow_camy = g.ow_y
	g.ow_tx = g.ow_x; g.ow_ty = 22 * 64.0
	await wait(900)
	await shot("11_fort_gate")
	g.ow_x = 70 * 64 + 32.0; g.ow_y = 8 * 64 + 40.0; g.ow_camx = g.ow_x; g.ow_camy = g.ow_y; g.ow_tx = g.ow_x; g.ow_ty = g.ow_y
	await wait(900)
	await shot("12_thornwick")
	# full encounter win flow with AUTO
	g.WORLD.enc_mult = 1.0
	g.start_encounter({"area": "brookside_meadow", "kinds": ["torch", "barrel"], "level": 3})
	g.AUTO = true
	g.speed = 3
	guard = 0
	while g.phase != "results" and guard < 600:
		await wait(100); guard += 1
	g.AUTO = false
	await wait(500)
	await shot("13_results")
	print("result ", g.G.result, " ", g.res.get("lines", []).size())
	g.results_primary()
	await wait(300)
	await shot("14_back_overworld")
	print("final phase ", g.phase, " screen ", g.screen)
	quit()
