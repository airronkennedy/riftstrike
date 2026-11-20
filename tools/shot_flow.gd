extends SceneTree
# Main-loop review shots: godot --path . --resolution 1024x576 --script res://tools/shot_flow.gd -- --out=/tmp/aqf
var out := "/tmp/aqf"
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
	await shot("f1_title_new")
	root.get_node("QuestFlow").new_game()
	await wait(1500)
	await shot("f2_kingdom_town")
	current_scene.load_map("castle")
	await wait(900)
	await shot("f3_castle")
	current_scene.load_map("overworld")
	await wait(900)
	await shot("f4_overworld")
	current_scene.save_game()
	root.get_node("Encounters").start_random_battle("highlands")
	await wait(900)
	current_scene.AUTO = false
	var g = current_scene
	var guard := 0
	while guard < 200 and not (g.G.active != null and g.G.active.team == "blue" and g.G.mode == "select"):
		await wait(50); guard += 1
	await wait(500)
	await shot("f5_battle_highlands")
	g.run_battle()
	await wait(1500)
	change_scene_to_file("res://main.tscn")
	await wait(900)
	await shot("f6_title_continue")
	quit()
