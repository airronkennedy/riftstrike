extends SceneTree
# Dungeon review shots: each floor and its beats (chest, lever + portcullis, locked door, save point, boss door).
#   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --resolution 1280x720 --script res://tools/shot_dungeon.gd -- --out=/tmp/dun
var d
var out := "/tmp/dun"
func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	preload("res://tools/test_save.gd").fresh()
	DungeonGate.reset()
	d = (load("res://scenes/dungeon.tscn") as PackedScene).instantiate()
	d.shots_mode = true
	root.add_child(d)
	_run()
func shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out + "/" + n + ".png")
func wait(n: int = 8) -> void:
	for i in n: await process_frame
func stand(floor_i: int, cell: Vector2i, off: Vector2 = Vector2(0, 44)) -> void:
	if d.floor_i != floor_i: d.load_floor(floor_i, d.cell_center(cell) + off)
	d.pos = d.cell_center(cell) + off
	d.cam.position = d.pos; d.cam.reset_smoothing()
	await wait(4)
	d.cam.reset_smoothing()
	await wait(6)
func close_dialog() -> void:
	d.dlg_queue = []; d._dlg_choices = []
	d.dialog.visible = false
	var st = root.get_node_or_null("Story")
	if st != null: st.ui.close_all()
	await wait(2)
func story_lines(n: int) -> void:
	var st = root.get_node("Story")
	for i in n:
		await wait(30)
		st.ui.dlg_text.visible_ratio = 1.0; st.ui.advance()
	await wait(40)
	st.ui.dlg_text.visible_ratio = 1.0
	await wait(4)
func _run() -> void:
	var st = root.get_node_or_null("Story")
	if st != null: st.reset(); st.battle_stub = true
	await wait(10)
	# 1) floor 1 overview near the entrance, danger meter partly full
	d.meter = 0.62
	await stand(0, Vector2i(12, 12), Vector2.ZERO)
	await wait(40)
	await shot("d1_floor1")
	# 2) chest
	await stand(0, Vector2i(15, 3), Vector2(0, 46))
	d.use(d.near)
	await wait(12)
	await shot("d2_chest")
	await close_dialog()
	# 3) lever + portcullis (the Tithe Collector stands in front of it)
	await stand(0, Vector2i(21, 5), Vector2(0, 0))
	await shot("d3_lever_before")
	d.use(d.near)
	await wait(20)
	await shot("d3_lever_gate_open")
	await close_dialog()
	# 4) floor 1 guardian: the story's f1_enter dialog
	await stand(0, Vector2i(20, 4), Vector2(0, 10))
	d.use(d.near)
	await story_lines(0)
	await shot("d4_guardian_tithe")
	await close_dialog()
	# 5) floor 2: the Knellbearer, then the locked door (guardian cleared)
	await stand(1, Vector2i(20, 7), Vector2(0, 8))
	d.use(d.near)
	await story_lines(0)
	await shot("d5_floor2_knellbearer")
	await close_dialog()
	if st != null: st.set_flag("bastion_f2")
	d._refresh_astar()
	await stand(1, Vector2i(20, 6), Vector2(0, 8))
	d.use(d.near)
	await wait(12)
	await shot("d6_floor2_locked_door")
	await close_dialog()
	# 6) floor 3: ember shrine save point
	await stand(2, Vector2i(13, 6), Vector2(0, 0))
	d.use(d.near)
	await wait(12)
	await shot("d7_floor3_save_point")
	await close_dialog()
	# 7) the throne doors: final_confront (Taren)
	await stand(2, Vector2i(13, 2), Vector2(0, 0))
	d.use(d.near)
	await story_lines(1)
	await shot("d8_throne_final_confront")
	await close_dialog()
	print("dungeon shots: ", out)
	if st != null: st.reset(); st.battle_stub = false
	preload("res://tools/test_save.gd").fresh()
	DungeonGate.reset()
	quit()
