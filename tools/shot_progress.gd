extends SceneTree
# Class/subclass/EXP + kingdom art review shots: godot --path . --resolution 1024x576 --script res://tools/shot_progress.gd -- --out=/tmp/aqx
var out := "/tmp/aqx"
func shot(n: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out + "/" + n + ".png")
func wait(ms: float) -> void:
	await create_timer(ms / 1000.0).timeout
func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()
func _run() -> void:
	change_scene_to_file("res://main.tscn")
	await wait(900)
	var g = current_scene
	g.sfx.muted = true
	var nm: String = g.lead_name()
	g.grant_hero_xp(nm, 1500)
	g.open_build()
	for t in 3:
		g.BUILD.tab = t
		await wait(300)
		await shot("x%d_build_%s" % [t + 1, ["class", "subclass", "sequence"][t]])
	g.menu_back()
	var qf = root.get_node("QuestFlow")
	qf.new_game()
	await wait(1600)
	await shot("x4_kingdom_town_high")
	current_scene.set_gfx_low(true)
	await wait(400)
	await shot("x5_kingdom_town_low")
	current_scene.set_gfx_low(false)
	current_scene.load_map("overworld")
	await wait(900)
	await shot("x6_overworld_high")
	current_scene.save_game()
	# force an elite highland fight
	var e: Dictionary = qf.encounter_for("highlands")
	e.elite = true
	qf.in_kingdom_battle = true; qf.pending_region = "highlands"
	change_scene_to_file("res://main.tscn")
	await wait(900)
	g = current_scene
	g.sfx.muted = true
	g.encounter = e
	g.new_battle(3); g.battle_area = "tollstone-quarry"
	g.phase = "battle"; g.screen = ""; g.AUTO = true; g.speed = 3
	g.begin_timeline()
	await wait(1500)
	await shot("x7_elite_battle")
	var guard := 0
	while g.phase != "results" and guard < 1500:
		await wait(50); guard += 1
	await wait(900)
	await shot("x8_results_exp")
	quit()
