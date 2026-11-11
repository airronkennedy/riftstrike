extends SceneTree
# Compendium screenshots: godot --path . --resolution 390x844 --script res://tools/shot_compendium.gd -- --out=/tmp/cmp --dpr=1
var g
var out := "/tmp/cmp"
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
	g.open_compendium()
	await wait(200)
	await shot("01_class_knight")
	g.COMP.step_entry(g, 1)
	g.COMP._set_kit(1)
	await wait(200)
	await shot("02_class_warrior_rico")
	g.COMP.step_page(1)
	await wait(200)
	await shot("03_class_warrior_rico_p2")
	for i in 4: g.COMP.step_entry(g, 1)
	await wait(200)
	await shot("04_class_warden")
	g.COMP.step_entry(g, 1)
	await wait(200)
	await shot("05_upcoming_spell_breaker")
	g.COMP.step_entry(g, 1)
	await wait(200)
	await shot("06_upcoming_paladin")
	g.COMP.step_entry(g, 1)
	await wait(200)
	await shot("07_upcoming_warlock")
	g.COMP.set_tab(1)
	await wait(200)
	await shot("08_sub_riftblade")
	for i in 6: g.COMP.step_entry(g, 1)
	await wait(200)
	await shot("09_sub_sage")
	g.menu_back()
	await wait(200)
	print("after back screen=", g.screen, " phase=", g.phase)
	await shot("10_title_after_back")
	quit()
