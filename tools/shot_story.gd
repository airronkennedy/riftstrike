extends SceneTree
## Main story screenshots, one beat per run:
##   xvfb-run -a godot --path . --resolution 1280x720 --script res://tools/shot_story.gd -- --beat=guard --out=/tmp/s.png
## Beats: guard, king, choice, recruit, journal, miniboss_intro, miniboss, dungeon, final_boss, epilogue
## Uses (and wipes) the user save, so run it with XDG_DATA_HOME=$(mktemp -d).
const SD = preload("res://scripts/story/story_data.gd")
var st
var k
var o := {"beat": "guard", "out": "/tmp/story.png"}

func _init() -> void:
	preload("res://tools/test_save.gd").fresh()
	_run.call_deferred()

func wait(ms: float) -> void:
	await create_timer(ms / 1000.0).timeout

func shot() -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(o.out)
	print("saved ", o.out)

func flags(list: Array, rec: Array = ["bramwell"]) -> void:
	st._begin()
	for f in list: st.flags[f] = true
	st._recruited = rec.duplicate()
	st.vars["chronicle"] = [["The King's Writ", "You swore the Warden's Oath."], ["Grieve's Reliquary", "You burned the reliquary. Grieve rests easier."]]
	st.save_state()

func kingdom(map: String, at: Vector2) -> void:
	change_scene_to_file("res://scenes/kingdom.tscn")
	await wait(400)
	k = current_scene
	k.load_map(map, at)
	await wait(2600) # let the map title banner fade

func lines_until_choice(max_lines: int = 20) -> void:
	for i in max_lines:
		await wait(60)
		if not st.ui.choices_box.get_children().is_empty(): return
		st.ui.dlg_text.visible_ratio = 1.0
		st.ui.advance()

func full_line() -> void:
	await wait(1600)
	st.ui.dlg_text.visible_ratio = 1.0
	await wait(150)

func battle(id: String, pre: Array, rec: Array) -> void:
	flags(pre, rec)
	await kingdom("overworld", Vector2(31, 23))
	st.start_battle(id)
	for i in 900:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == "res://main.tscn": break
	await wait(2600)
	var g = current_scene
	if "sfx" in g: g.sfx.muted = true

func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="): o[a.substr(2).get_slice("=", 0)] = a.get_slice("=", 1)
	st = root.get_node("Story")
	var act1 := ["s_prologue", "s_king", "s_maera"]
	var all5 := ["bramwell", "grieve", "halvard", "corvin", "ilsabet"]
	var act2 := act1 + ["c1_oath", "c2_burn", "loyal_grieve", "got_grieve", "got_halvard", "got_corvin", "c3_hunt", "loyal_corvin", "got_ilsabet", "c4_rest", "loyal_ilsabet", "s_return"]
	match o.beat:
		"guard":
			flags([])
			await kingdom("town", Vector2(13.7, 16.4))
			await shot()
		"king", "choice":
			flags(["s_prologue"])
			await kingdom("castle", Vector2(9, 6))
			st.start_dialog("king_audience")
			if o.beat == "king":
				st.ui.advance(); await wait(100); st.ui.advance()
				await full_line()
			else:
				await lines_until_choice()
				await wait(500)
			await shot()
		"recruit":
			flags(act1, ["bramwell"])
			await kingdom("overworld", Vector2(10.6, 15.6))
			st._recruit("grieve")
			st._flush_deferred()
			await wait(900)
			await shot()
		"journal":
			flags(act1 + ["c1_oath", "got_grieve", "c2_burn", "loyal_grieve", "sq_fire_on", "crate_1", "sq_book_bet"], ["bramwell", "grieve"])
			await kingdom("overworld", Vector2(12, 16))
			st.ui.open_journal()
			await wait(700)
			await shot()
		"miniboss_intro":
			flags(act2, all5)
			await kingdom("town", Vector2(11.1, 8.6))
			st.ui.battle_intro(SD.BATTLES["miniboss_matron"])
			await wait(900)
			await shot()
		"miniboss":
			await battle("miniboss_matron", act2, all5)
			await shot()
		"dungeon":
			flags(act2 + ["s_kindling", "c5_spare"], all5)
			await kingdom("overworld", Vector2(32, 22.6))
			st.enter_dungeon()
			await full_line()
			await shot()
		"final_boss":
			await battle("boss_sovereign", act2 + ["s_kindling", "s_bastion", "bastion_f1", "bastion_f2", "boss1_won", "c5_spare"], all5)
			await shot()
		"lesson_order", "lesson_spark", "lesson_boss":
			flags(act1 if o.beat != "lesson_boss" else act2, ["bramwell", "grieve"] if o.beat != "lesson_boss" else all5)
			await kingdom("overworld" if o.beat != "lesson_boss" else "castle", Vector2(10.6, 15.6) if o.beat != "lesson_boss" else Vector2(9, 6))
			st.ui.lesson(o.beat.substr(7))
			await wait(1400)
			await shot()
		"bark", "bark_late":
			flags([] if o.beat == "bark" else act2 + ["s_kindling"], ["bramwell"] if o.beat == "bark" else all5)
			await kingdom("town", Vector2(17.6, 11.9))
			await wait(1500)
			await shot()
		"banner":
			flags(act1)
			change_scene_to_file("res://scenes/kingdom.tscn")
			await wait(400)
			k = current_scene
			k.load_map("town", Vector2(13, 13))
			await wait(500)
			await shot()
		"four_sparks":
			flags(act2.filter(func(f): return f != "s_return"), all5)
			await kingdom("overworld", Vector2(20, 12))
			st.start_dialog("four_sparks")
			await full_line()
			await shot()
		"journal_boss":
			flags(act2, all5)
			await kingdom("castle", Vector2(9, 6))
			st.ui.open_journal()
			await wait(700)
			await shot()
		"epilogue":
			flags(act2 + ["s_kindling", "s_bastion", "bastion_f1", "bastion_f2", "boss1_won", "boss2_won", "c5_spare", "end_hearth"], all5)
			await kingdom("town", Vector2(12, 9.4))
			st._ending()
			await wait(1800)
			await shot()
	quit()
