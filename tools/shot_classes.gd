extends SceneTree
## Screenshots for docs/CLASSES.md, one beat per run:
##   xvfb-run -a godot --path . --resolution 1280x720 --script res://tools/shot_classes.gd -- --beat=list --out=/tmp/c.png
## Beats: inn, intro (Adeyo's dialog), heroes, list, sub, confirm, ritual, reveal, tactics, build, party.
## Add --portrait to shoot at 430x930 (pass --resolution 430x930 too).
const Diviner = preload("res://scripts/classes/diviner.gd")
var o := {"beat": "list", "out": "/tmp/classes.png"}
var g
var st

func _init() -> void:
	preload("res://tools/test_save.gd").fresh()
	_run()

func wait(ms: float) -> void:
	await create_timer(ms / 1000.0).timeout

func shot() -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(o.out)
	print("saved ", o.out)

func flags(list: Array, rec: Array) -> void:
	st._begin()
	for f in list: st.flags[f] = true
	st._recruited = rec.duplicate()
	st.save_state()

func main_scene() -> void:
	change_scene_to_file("res://main.tscn")
	await wait(700)
	g = current_scene
	g.sfx.muted = true
	# a lived-in party: a few levels in, one class tried before
	for nm in g.HERO_NAMES:
		g.CLASS_XP[nm] = {str(g.CHAR[nm].cls): preload("res://scripts/quest_rpg.gd").xp_floor(6)}
	if g.CHAR.has("Grieve"): g.CLASS_XP["Grieve"]["Monk"] = preload("res://scripts/quest_rpg.gd").xp_floor(4)
	g.save_cfg()

func _run() -> void:
	await process_frame
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="): o[a.substr(2).get_slice("=", 0)] = a.get_slice("=", 1)
	st = root.get_node("Story")
	var all5 := ["bramwell", "grieve", "halvard", "corvin", "ilsabet"]
	var mid := ["s_prologue", "s_king", "s_maera", "got_grieve", "got_halvard", "got_corvin", "got_ilsabet", "adeyo_on", "sq_bell_done"]
	match o.beat:
		"inn", "intro":
			flags(mid if o.beat == "inn" else ["s_prologue", "s_king", "s_maera", "got_grieve", "adeyo_on"], all5 if o.beat == "inn" else ["bramwell", "grieve"])
			if o.beat == "inn": st.flags["met_adeyo"] = true
			change_scene_to_file("res://scenes/kingdom.tscn")
			await wait(400)
			var k = current_scene
			k.load_map("inn", Vector2(8.6, 4.4))
			await wait(2600)
			if o.beat == "intro":
				st.ui.fast = false
				st.start_dialog("adeyo_intro")
				for i in 3:
					await wait(120); st.ui.dlg_text.visible_ratio = 1.0; st.ui.advance()
				await wait(1600); st.ui.dlg_text.visible_ratio = 1.0
				await wait(200)
			await shot()
		"heroes", "list", "sub", "confirm", "ritual", "reveal":
			flags(mid, all5)
			st.started = true
			await main_scene()
			g.open_diviner(false)
			var ui = g.diviner_ui
			await wait(600)
			if o.beat != "heroes":
				ui.hero = "Grieve" if g.CHAR.has("Grieve") else str(g.HERO_NAMES[0])
				ui.mode = "sub" if o.beat == "sub" else "class"
				ui._show("list")
				await wait(300)
			if o.beat in ["confirm", "ritual", "reveal"]:
				ui.pick = "Monk"
				ui._show("confirm")
				await wait(300)
			if o.beat in ["ritual", "reveal"]:
				ui._divine()
				await wait(1300 if o.beat == "ritual" else 3600)
			await shot()
		"tactics", "build":
			flags(mid, all5)
			await main_scene()
			g.new_battle(); g.phase = "title"
			g.open_build()
			g.char_sel = 1 if g.HERO_NAMES.size() > 1 else 0
			g.BUILD.tab = 2 if o.beat == "tactics" else 0
			await wait(800)
			await shot()
		"party":
			flags(mid, all5)
			await main_scene()
			g.new_battle(); g.phase = "title"
			g.open_party()
			await wait(800)
			await shot()
	quit()
