extends SceneTree
# Menu screenshots: godot --path . --resolution 960x540 --script res://tools/shot_menus.gd -- --out=/tmp/ms
var g
var out := "/tmp/ms"
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
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out + "/" + n + ".png")
func wait(ms: float) -> void:
	await create_timer(ms / 1000.0).timeout
func _run() -> void:
	await wait(700)
	await shot("00_title")
	g.ow_ready = false
	g.open_overworld()
	await wait(600)
	await shot("01_overworld")
	g.ow_menu_open = true
	await wait(150)
	await shot("02_ow_menu")
	g.ow_open_menu_screen("inv")
	g.inv_tab = "gear"
	await wait(250)
	await shot("03_inv_gear")
	g._inv_tap_slot("weapon")
	await wait(150)
	await shot("03b_inv_gear_slot")
	g._set_inv_tab("abilities")
	await wait(200)
	await shot("04_inv_abilities")
	g.menu_back()
	g.ow_open_menu_screen("party")
	await wait(200)
	await shot("05_party")
	g.menu_back()
	g.ow_open_menu_screen("chars")
	await wait(200)
	await shot("06_chars")
	g.menu_back()
	g.ow_open_menu_screen("stats")
	await wait(200)
	await shot("07_stats_compare")
	g.STATS.mode = "breakdown"
	await wait(200)
	await shot("08_stats_breakdown")
	g.resume_overworld()
	g.ow_open_menu_screen("map")
	await wait(250)
	await shot("09_map_region")
	g.WMAP.tab = "local"
	await wait(200)
	await shot("10_map_local")
	g.resume_overworld()
	print("after menus screen=", g.screen, " phase=", g.phase)
	var auto0: bool = g.AUTO
	g.AUTO = false
	g.start_fight(3)
	await wait(600)
	var us: Array = g.alive("blue")
	us[0].gauge = 100.0
	g.toggle_queue(us[0])
	g.toggle_queue(us[1])
	g._set_ab_focus(us[0])
	await wait(300)
	await shot("11_battle_abilities")
	g.AUTO = true
	g.speed = 3
	var guard := 0
	while g.phase != "results" and guard < 900:
		await wait(100); guard += 1
	await wait(600)
	await shot("12_results")
	g.AUTO = auto0
	g.save_cfg()
	quit()
