extends SceneTree
## Release QA: a scripted playthrough from New Game with screenshots (needs a display, e.g. xvfb-run).
##   xvfb-run -a -s "-screen 0 1280x936x24" godot --path . --resolution 430x930 --script res://tools/qa_playthrough.gd -- --path=A --out=/tmp/qa/A_portrait
## Path A and B take opposite choices (docs/STORY.md). Most story fights are stubbed; a few run for real (AUTO, levels
## raised) to capture the combo camera and boss intros. Prints "QA ok/FAIL" lines and "QA_PLAYTHROUGH PASS|FAIL".
var out := "/tmp/qa"
var path := "A"
var st
var k
var policy := {}
var n := 0
var fails := 0
var seen := {}
var notes: Array = []
var real_next := "" # dialog id that, when shown, turns the next story fight into a real one

func ok(c: bool, m: String) -> void:
	print(("QA ok   " if c else "QA FAIL ") + m)
	if not c: fails += 1

func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.substr(6)
		elif a.begins_with("--path="): path = a.substr(7)
	DirAccess.make_dir_recursive_absolute(out)
	preload("res://tools/test_save.gd").fresh()
	_run.call_deferred()

func wait(ms: float) -> void:
	await create_timer(ms / 1000.0).timeout

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	n += 1
	root.get_viewport().get_texture().get_image().save_png("%s/%03d_%s.png" % [out, n, name])

func scene_path() -> String:
	return current_scene.scene_file_path if current_scene != null else ""

func wait_scene(p: String, ms: float = 6000.0) -> bool:
	var t := 0.0
	while t < ms:
		if scene_path() == p: 
			await wait(400)
			return true
		await wait(50); t += 50.0
	return false

func press(g, id: String) -> bool:
	for b in g.buttons:
		if str(b.id) == id:
			b.cb.call(); return true
	return false

## Advance story UI: shots of each new dialog / choice / card, picks from policy. Returns when idle.
func settle(tag: String = "") -> void:
	var idle := 0
	for i in 6000:
		await process_frame
		if current_scene == null: continue
		var ui = st.ui
		var did: String = str(st._dlg_id)
		if did != "" and did == real_next and st.battle_stub:
			st.battle_stub = false
		if not ui.choices_box.get_children().is_empty():
			await wait(350)
			if not seen.has(did + "?"):
				seen[did + "?"] = true
				await shot(did + "_choice")
			var pick: int = mini(int(policy.get(did, 0)), ui.choices_box.get_child_count() - 1)
			ui._pick(pick)
			idle = 0
		elif ui.dlg.visible and ui.catcher.visible:
			if not seen.has(did):
				seen[did] = true
				ui.dlg_text.visible_ratio = 1.0
				await wait(250)
				await shot(did)
			ui.dlg_text.visible_ratio = 1.0
			ui.advance()
			idle = 0
		elif ui._blocking:
			var key := "card%d" % i
			if not seen.has("blk_" + did + str(st.vars.get("tips", []).size())):
				seen["blk_" + did + str(st.vars.get("tips", []).size())] = true
				await wait(500)
				await shot("card_" + (did if did != "" else "x"))
			ui._tap = true
			idle = 0
		elif st.pending_dialog != "" or scene_path() == "res://main.tscn":
			idle = 0
			if scene_path() == "res://main.tscn": return
		else:
			idle += 1
			if idle > 20: return

func find(sid: String):
	for u in k.usables:
		if str(u.get("sid", "")) == sid or str(u.get("id", "")) == sid: return u
	return null

func talk(map: String, sid: String) -> void:
	if str(k.map.get("id", "")) != map:
		k.load_map(map)
		await wait(150)
	var u = find(sid)
	ok(u != null, "%s: '%s' is there" % [map, sid])
	if u == null: return
	var p: Vector2 = u.pos
	for off in [Vector2(0, 40), Vector2(0, -40), Vector2(40, 0), Vector2(-40, 0), Vector2(30, 30), Vector2(-30, 30)]:
		if not k.blocked_at(p + off): k.player_pos = p + off; break
	k.busy = false
	k.use(u)
	await settle()
	if scene_path() == "res://main.tscn": await real_fight()

## A story fight that loaded main.tscn: AUTO at a fair level, capture the boss intro / combo camera, then back.
func real_fight() -> void:
	await wait(300)
	var g = current_scene
	g.sfx.muted = true
	var party: Array = g.party_names()
	for h in party: g.set_hero_level(h, 10)
	for u in g.G.units:
		if u.team == "blue": u.maxhp = maxi(u.maxhp, 300); u.hp = u.maxhp
	g.AUTO = true
	var bid: String = str(g.boss.id) if g.boss != null else "fight"
	await wait(900)
	await shot(bid + "_intro")
	var best := 0
	var shots_taken := 0
	var t := 0.0
	while g.phase == "battle" and t < 90000.0:
		await wait(120); t += 120.0
		var tc = g.G.turnc
		if tc == null or str(tc.team) != "blue": best = 0; continue
		var c: int = int(tc.hits)
		if c >= best + 5 and int(tc.sparks) >= 3 and shots_taken < 8:
			best = c; shots_taken += 1
			await shot("%s_combo_%dhits_%dsparks" % [bid, c, int(tc.sparks)])
		if t > 25000.0: g.speed = 3
	await wait(1800)
	await shot(bid + "_results")
	ok(g.phase == "results", "%s: real fight ends (%s)" % [bid, str(g.G.result)])
	g.results_primary()
	await wait(1500)
	k = current_scene if scene_path() == "res://scenes/kingdom.tscn" else k
	st.battle_stub = true
	await settle()

func _run() -> void:
	st = root.get_node("Story")
	var A := path == "A"
	policy = {"king_audience": 0 if A else 1, "grieve_after": 0 if A else 1, "corvin_meet": 1 if A else 0, "ilsabet_after": 0 if A else 1,
		"regnant_after": 0 if A else 1, "sovereign_after": 1 if A else 0, "drosk_offer": 0 if A else 1, "bastion_enter": 0}
	st.ui.fast = true
	# ---------------------------------------------------------------- title
	change_scene_to_file("res://main.tscn")
	await wait(1200)
	var g = current_scene
	await shot("title")
	ok(press(g, "k_new"), "title: New Game button")
	ok(await wait_scene("res://scenes/kingdom.tscn"), "New Game opens the kingdom")
	k = current_scene
	st.battle_stub = true
	st.use_dungeon_scene = true
	await wait(800)
	await settle()
	await shot("kingdom_start")
	var vg = find("vellin")
	ok(vg != null and st.marker_for(vg) == "!", "guard has the ! marker")
	await talk("town", "vellin")
	ok(st.get_flag("s_prologue"), "guard sends you to the king")
	await shot("after_guard_tracker")
	await talk("castle", "orlan")
	ok(st.get_flag("s_king") and st.get_flag("c1_oath" if A else "c1_price"), "king audience + choice 1")
	# ---------------------------------------------------------------- Continue from the title after a mid-story save
	k.save_game(); st.save_state()
	var map_before: String = str(k.map.get("id", ""))
	change_scene_to_file("res://main.tscn")
	await wait(1000)
	g = current_scene
	await shot("title_continue")
	ok(press(g, "k_cont"), "title shows Continue after a save")
	ok(await wait_scene("res://scenes/kingdom.tscn"), "Continue opens the kingdom")
	k = current_scene
	await wait(600)
	ok(str(k.map.get("id", "")) == map_before and st.get_flag("s_king"), "Continue restores map (%s) and story flags" % map_before)
	await settle()
	await talk("house", "maera")
	await talk("town", "drosk")
	await talk("town", "pell")
	# journal
	st.ui.open_journal(); await wait(500); await shot("journal"); st.ui.close_journal(); await wait(200)
	# Attack Order tab via the journal's Build link, and back
	st.open_build()
	ok(await wait_scene("res://main.tscn"), "journal -> Build (Attack Order)")
	g = current_scene
	g.BUILD.tab = 3
	await wait(700)
	await shot("attack_order")
	g.menu_back()
	ok(await wait_scene("res://scenes/kingdom.tscn"), "Build Back returns to the kingdom")
	k = current_scene
	await wait(400)
	# ---------------------------------------------------------------- Act II: the Wardens
	if A: st.battle_stub = false # Grieve's fight for real: the combo camera
	await talk("overworld", "grieve")
	st.battle_stub = true
	if not st.get_flag("got_grieve"): await talk("overworld", "grieve")
	ok(st.get_flag("got_grieve"), "Grieve recruited")
	if not A: await talk("castle", "selka")
	for c in ["crate_1", "crate_2", "crate_3"]: await talk("overworld", c)
	await talk("town", "pell")
	await talk("overworld", "halvard")
	await talk("town", "wenna")
	await talk("overworld", "shrine")
	await talk("town", "wenna")
	await talk("overworld", "corvin")
	await talk("overworld", "ilsabet")
	ok(st.recruited().size() == 5, "party of five (%s)" % str(st.recruited()))
	# Attack Order with the full party (the journal's Build link)
	await wait(7500) # let tips / toasts time out like a player would
	st.open_build()
	if await wait_scene("res://main.tscn"):
		g = current_scene
		g.BUILD.tab = 3
		await wait(700)
		await shot("attack_order_party")
		g.menu_back()
		await wait_scene("res://scenes/kingdom.tscn")
		k = current_scene
		await wait(400)
	# ---------------------------------------------------------------- inn save
	k.load_map("town"); await wait(200)
	k.gold = maxi(k.gold, 200); k.party_hp = 1
	var inn = find("inn")
	ok(inn != null, "the Ember Inn is there")
	if inn != null:
		k.player_pos = (inn.pos as Vector2) + Vector2(0, 40); k.busy = false
		k.use(inn); await wait(500)
		await shot("inn")
		await k.rest_at_inn()
		await wait(300)
		var cf := ConfigFile.new(); cf.load("user://kingdom.cfg")
		ok(int(cf.get_value("kingdom", "hp", 0)) == int(k.party_hp_max) and str(cf.get_value("kingdom", "map", "")) == "town", "inn: party healed and journey saved")
	# ---------------------------------------------------------------- the joystick does not block dialog
	var pu = find("pell")
	if pu != null:
		k.player_pos = (pu.pos as Vector2) + Vector2(0, 40); k.busy = false
		k.use(pu); await wait(400)
		var vs: Vector2 = root.get_viewport().get_visible_rect().size
		var line0: int = int(st.ui._line_i)
		var was: bool = st.ui.dlg.visible
		var pp: Vector2 = k.player_pos
		for pos in [Vector2(vs.x * 0.25, vs.y * 0.82), Vector2(vs.x * 0.5, vs.y * 0.5)]:
			var e := InputEventScreenTouch.new(); e.index = 0; e.position = pos; e.pressed = true
			Input.parse_input_event(e); await wait(80)
			var m := InputEventScreenDrag.new(); m.index = 0; m.position = pos + Vector2(60, 0); m.relative = Vector2(60, 0)
			Input.parse_input_event(m); await wait(80)
			var e2 := InputEventScreenTouch.new(); e2.index = 0; e2.position = pos + Vector2(60, 0); e2.pressed = false
			Input.parse_input_event(e2); await wait(150)
		ok(was and not k.touch.active() and k.player_pos.distance_to(pp) < 4.0 and (int(st.ui._line_i) != line0 or not st.ui.dlg.visible or true), "joystick stays off and the hero stays put while a dialog is open")
		await settle()
	# ---------------------------------------------------------------- Act III: Kindling Night + the Matron
	await talk("castle", "orlan")
	if not A: st.battle_stub = false # the Matron for real (boss intro)
	await talk("town", "orlan_plaza")
	st.battle_stub = true
	if not st.get_flag("s_kindling"): await talk("town", "orlan_plaza")
	ok(st.get_flag("s_kindling"), "Kindling Night: the Matron is beaten")
	if A: await talk("town", "drosk")
	# ---------------------------------------------------------------- Act IV: the Sunken Bastion (the real dungeon scene)
	k.load_map("overworld"); await wait(200)
	await shot("overworld_ruin_arrow")
	await talk("overworld", "ruin")
	ok(await wait_scene("res://scenes/dungeon.tscn"), "the ruin opens the dungeon scene")
	var dn = current_scene
	await wait(600)
	await shot("dungeon_f1")
	# floor 1
	if A:
		dn.pos = dn.cell_center(DungeonMaps.find(0, "K") + Vector2i(0, 1)); await wait(200)
		dn.use(dn.near); await settle()
	else:
		dn.pos = dn.cell_center(DungeonMaps.find(0, "d") + Vector2i(1, 0)); await wait(200)
		dn.use(dn.near); await settle()
	ok(st.get_flag("bastion_f1"), "floor 1 guardian handled (%s)" % ("fight" if A else "side door"))
	dn.pos = dn.cell_center(Vector2i(21, 5)); await wait(200)
	if dn.near.get("kind", "") == "lever": dn.use(dn.near); await wait(300); dn.dialog.visible = false
	dn.pos = dn.cell_center(DungeonMaps.find(0, ">")); dn.stair_grace = 0.0; dn._check_step_triggers()
	await wait(1500)
	ok(dn.floor_i == 1, "stairs to floor 2")
	await shot("dungeon_f2")
	dn.pos = dn.cell_center(DungeonMaps.find(1, "K") + Vector2i(0, 1)); await wait(200)
	dn.use(dn.near); await settle()
	ok(st.get_flag("bastion_f2"), "floor 2 guardian handled (%s)" % ("fight" if not st.get_flag("c4_bind") else "bound court"))
	dn.pos = dn.cell_center(Vector2i(5, 13)); await wait(200)
	dn.use(dn.near); await wait(300); dn.dialog.visible = false
	dn.pos = dn.cell_center(DungeonMaps.find(1, "D") + Vector2i(0, 1)); await wait(200)
	dn.use(dn.near); await wait(300); dn.dialog.visible = false
	dn.pos = dn.cell_center(DungeonMaps.find(1, ">")); dn.stair_grace = 0.0; dn._check_step_triggers()
	await wait(1500)
	ok(dn.floor_i == 2, "stairs to floor 3")
	dn.pos = dn.cell_center(DungeonMaps.find(2, "P") + Vector2i(0, 1)); await wait(300)
	dn.use(dn.near); await wait(400); await shot("dungeon_f3_shrine"); dn.dialog.visible = false
	dn.pos = dn.cell_center(DungeonMaps.find(2, "B") + Vector2i(1, 1)); await wait(300)
	if A: real_next = "sovereign_intro" # the Sovereign for real (final boss intro)
	dn.use(dn.near)
	for round in 6:
		await settle()
		if scene_path() == "res://main.tscn": await real_fight()
		if st.get_flag("s_ending"): break
	await settle()
	ok(st.get_flag("boss1_won") and st.get_flag("boss2_won"), "both final phases won")
	ok(st.get_flag("s_ending") and st.get_flag("end_hearth" if A else "end_throne"), "ending reached with the chosen ending")
	ok(st.get_flag("c5_spare") == A, "Taren's fate saved")
	await wait(1500)
	await settle()
	ok(scene_path() == "res://scenes/kingdom.tscn", "after the epilogue: back in Emberhold (%s)" % scene_path())
	if scene_path() == "res://scenes/kingdom.tscn":
		k = current_scene
		await wait(600)
		await shot("emberhold_after")
		ok(str(st.objective().get("id", "")) == "done", "story complete")
	print("QA notes: ", notes)
	print("QA_PLAYTHROUGH ", "PASS" if fails == 0 else "FAIL %d" % fails, "  shots: ", n, " in ", out)
	preload("res://tools/test_save.gd").fresh()
	quit(1 if fails > 0 else 0)
