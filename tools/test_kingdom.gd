extends SceneTree
## Kingdom / overworld checks: map shapes, every spot / warp / npc reachable, danger meter only on the overworld,
## start_random_battle(region_id) fires with a region, shop buy/sell and inn rest.
## godot --headless --path . --script res://tools/test_kingdom.gd
var fails := 0

func ok(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond: fails += 1

func _init() -> void:
	preload("res://tools/test_save.gd").fresh() # new-game user data every run
	_run.call_deferred()

func _run() -> void:
	var KS: PackedScene = load("res://scenes/kingdom.tscn")
	var enc: Node = root.get_node_or_null("Encounters")
	if enc == null:
		enc = load("res://scripts/encounters.gd").new()
		enc.name = "Encounters"
		root.add_child(enc)
	var k = KS.instantiate()
	root.add_child(k)
	await process_frame
	for id in ["town", "castle", "house", "overworld"]:
		k.load_map(id)
		var rows: Array = k.rows
		var wide := true
		for r in rows:
			wide = wide and (r as String).length() == k.W
		ok(wide, "%s: %dx%d rows all same width" % [id, k.W, k.H])
		ok(not k.blocked_at(k.player_pos), "%s: start is walkable" % id)
		# BFS over 16 px steps from the start using the real collision.
		var seen := {}
		var q: Array = [k.player_pos]
		var stepv := 16.0
		seen[Vector2i(k.player_pos / stepv)] = true
		var reach: Array = []
		while not q.is_empty() and reach.size() < 40000:
			var p: Vector2 = q.pop_back()
			reach.append(p)
			for d in [Vector2(stepv, 0), Vector2(-stepv, 0), Vector2(0, stepv), Vector2(0, -stepv)]:
				var n: Vector2 = p + d
				var key := Vector2i(n / stepv)
				if seen.has(key) or k.blocked_at(n):
					continue
				seen[key] = true
				q.append(n)
		var near_any := func(target: Vector2, rad: float) -> bool:
			for p in reach:
				if (p as Vector2).distance_to(target) < rad: return true
			return false
		for u in k.usables:
			ok(near_any.call(u.pos, 70.0), "%s: %s '%s' reachable" % [id, u.kind, u.name])
		for w in k.map.warps:
			var rc: Rect2 = w.rect
			ok(near_any.call((rc.position + rc.size / 2.0) * 64.0, 40.0), "%s: warp '%s' reachable" % [id, w.name])
			var dest: Dictionary = KingdomMaps.get_map(str(w.to))
			ok(not dest.is_empty(), "%s: warp target %s exists" % [id, w.to])
	# Danger meter: walking in town never calls the hook; the overworld does, with a region id.
	var got: Array = []
	k.allow_warps = false
	enc.random_battle_requested.connect(func(r): got.append(r); enc.finish_random_battle(true))
	k.load_map("town")
	k.meter = 0.0
	var walked := _walk(k, 4000.0)
	ok(walked > 1000.0 and got.is_empty() and k.meter == 0.0, "town: %d px walked, no battle, meter stays 0" % int(walked))
	k.load_map("overworld")
	k.meter = 0.0
	walked = _walk(k, 64.0 * 70.0)
	ok(got.size() >= 1, "overworld: %d px walked -> start_random_battle fired %d times %s" % [int(walked), got.size(), str(got)])
	ok(got.size() > 0 and KingdomMaps.REGIONS.has(str(got[0])), "region id is a known region")
	ok(k.meter < 1.0, "meter reset after battle (%.2f)" % k.meter)
	# Shop + inn
	var iid: String = k.item_defs.keys()[0]
	k.gold = 500
	var bag0: int = k.bag.size()
	ok(k.buy(iid) and k.bag.size() == bag0 + 1 and k.gold == 500 - k.price_of(iid), "shop: bought %s for %dg" % [iid, k.price_of(iid)])
	ok(k.sell(iid) and k.bag.size() == bag0, "shop: sold it back")
	ok(k.item_defs.size() >= 10, "shop uses game.gd ITEM_DEFS (%d items)" % k.item_defs.size())
	k.party_hp = 5
	k.gold = 50
	k.rest_at_inn()
	await create_timer(1.6).timeout
	ok(k.party_hp == k.party_hp_max and k.gold == 50 - k.INN_COST, "inn: hp restored, %d gold charged" % k.INN_COST)
	var cf := ConfigFile.new()
	ok(cf.load(k.SAVE_PATH) == OK and int(cf.get_value("kingdom", "hp", 0)) == k.party_hp_max, "inn: saved to %s" % k.SAVE_PATH)
	# Floating joystick + multitouch routing (KingdomTouch, pure logic)
	var tch := KingdomTouch.new()
	tch.size = 118.0
	tch.hit_ui = func(p: Vector2) -> String: return "use" if p.x > 300.0 else ""
	var r := tch.radius()
	var acts: Array = tch.handle(_touch(0, Vector2(100, 100), true), 0.0)
	ok(tch.active() and acts.size() == 1 and acts[0].type == "stick_start", "touch: finger on the field spawns the stick there")
	tch.handle(_drag(0, Vector2(100 + r * 0.08, 100)), 0.05)
	ok(tch.vec == Vector2.ZERO, "touch: dead zone (8% push -> no movement)")
	tch.handle(_drag(0, Vector2(100 + r * 0.55, 100)), 0.1)
	ok(absf(tch.vec.length() - 0.5) < 0.01, "touch: analog speed (55%% push -> %.2f)" % tch.vec.length())
	tch.handle(_drag(0, Vector2(100 + r * 3.0, 100)), 0.15)
	ok(absf(tch.knob.length() - r) < 0.01 and absf(tch.vec.x - 1.0) < 0.01, "touch: knob clamped to 31% of the base, full speed")
	acts = tch.handle(_touch(1, Vector2(350, 100), true), 0.2)
	ok(acts.size() == 1 and acts[0].type == "ui_down" and acts[0].name == "use" and tch.vec.x > 0.99, "touch: second finger presses Use while the stick is held")
	acts = tch.handle(_touch(1, Vector2(352, 102), false), 0.3)
	ok(acts.size() == 1 and acts[0].type == "ui_up" and acts[0].inside and tch.active(), "touch: Use released inside fires, stick still held")
	tch.handle(_touch(2, Vector2(200, 300), true), 0.4)
	acts = tch.handle(_touch(2, Vector2(203, 301), false), 0.5)
	ok(acts.size() == 1 and acts[0].type == "tap", "touch: quick tap with another finger = tap (use / walk)")
	acts = tch.handle(_touch(0, Vector2(400, 100), false), 1.0)
	ok(not tch.active() and tch.vec == Vector2.ZERO and acts[0].type == "stick_end" and acts.size() == 1, "touch: lifting the stick finger stops (no tap after a drag)")
	# In the scene: stick walks the hero, Use with a second finger, tap the person to talk
	root.size = Vector2i(1024, 576) # headless windows start tiny
	k.load_map("town")
	k.touch_ui = true
	var npc: Dictionary = {}
	for u in k.usables:
		if u.kind == "npc": npc = u; break
	k.player_pos = npc.pos + Vector2(0, 40)
	k.player.position = k.player_pos
	await process_frame
	await process_frame
	ok(k.near == npc and k.use_btn.shown, "use button pops in near %s (%s)" % [npc.name, KingdomView.icon_for(npc)])
	k.player_pos = Vector2(12.0, 15.5) * 64.0
	await process_frame
	var x0: float = k.player_pos.x
	var vsz: Vector2 = k.get_viewport_rect().size
	var sp := Vector2(vsz.x * 0.3, vsz.y * 0.6)
	k._input(_touch(0, sp, true))
	k._input(_drag(0, sp + Vector2(200, 0)))
	for i in 10: k._move(0.05)
	ok(k.player_pos.x > x0 + 50.0 and k.stick.visible, "scene: floating stick walks the hero (+%d px)" % int(k.player_pos.x - x0))
	k._input(_touch(0, sp + Vector2(200, 0), false))
	k.player_pos = npc.pos + Vector2(0, 40)
	await process_frame
	await process_frame
	k._input(_touch(0, sp, true))
	var uc: Vector2 = k.use_btn.get_global_rect().get_center()
	k._input(_touch(1, uc, true))
	k._input(_touch(1, uc, false))
	ok(_talking(k) and k.touch.active(), "scene: Use pressed with finger 2 while finger 1 holds the stick")
	k._input(_touch(0, sp, false))
	await _hush(k)
	k.tap_at(k.get_canvas_transform() * (npc.pos + Vector2(0, -30)))
	ok(_talking(k), "scene: quick tap on the person talks to them")
	await _hush(k)
	ok(not Input.emulate_mouse_from_touch, "no mouse emulation on the field")
	# Story UI (scripts/story/story_ui.gd): journal button, story dialogs
	var sui = k._story_ui()
	if sui == null:
		ok(false, "story ui present")
	else:
		sui.story.pending_dialog = ""
		sui.close_all()
		sui.set_hud_visible(true)
		sui._layout()
		await process_frame
		var jc: Vector2 = sui.quests_btn.get_global_rect().get_center()
		sui.quests_btn.visible = true # headless: the test's current scene counts as "in battle", which hides the story HUD
		k._input(_touch(3, jc, true))
		ok(not k.touch.active(), "story: no joystick under the journal button")
		k._input(_touch(3, jc, false))
		await process_frame
		ok(sui.journal.visible, "story: tapping the journal button opens the journal")
		ok(Input.emulate_mouse_from_touch, "story: journal open -> taps go to its buttons (mouse emulation on)")
		var bjoy := InputEventJoypadButton.new(); bjoy.button_index = JOY_BUTTON_B; bjoy.pressed = true
		k._unhandled_input(bjoy)
		sui.journal.visible = false
		await process_frame
		sui.show_lines([["vellin", "One."], ["vellin", "Two."], ["vellin", "Three."], ["vellin", "Four."]], func(): pass)
		await process_frame
		k._input(_touch(4, sp, true))
		ok(not k.touch.active() and Input.emulate_mouse_from_touch, "story: no joystick over an open story dialog; taps reach it")
		k._input(_touch(4, sp, false))
		sui.dlg_text.visible_ratio = 1.0
		k.use_or_advance()
		ok(sui._line_i == 1, "story: Use advances the story dialog")
		sui.dlg_text.visible_ratio = 1.0
		var ajoy := InputEventJoypadButton.new(); ajoy.button_index = JOY_BUTTON_A; ajoy.pressed = true
		k._unhandled_input(ajoy)
		ok(sui._line_i == 2, "story: gamepad A advances it")
		sui.dlg_text.visible_ratio = 1.0
		var ek := InputEventKey.new(); ek.physical_keycode = KEY_E; ek.pressed = true
		sui._input(ek)
		ok(sui._line_i == 3, "story: keyboard E advances it")
		ok(not k.use_btn.shown, "story: Use button steps aside during the dialog")
		await _hush(k)
	print("RESULT: %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails else 0)

# Walk a scripted zig-zag via step_move and feed distance to the meter like _process does.
func _walk(k, total: float) -> float:
	var done := 0.0
	var dirs := [Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0), Vector2(0, -1)]
	var i := 0
	var stuck := 0
	while done < total and stuck < 400:
		var m: float = k.step_move(dirs[i % 4] * 8.0)
		if m < 0.5:
			i += 1; stuck += 1
		else:
			stuck = 0
			done += m
			k._after_move(m)
			if k.busy:
				k.busy = false
		if int(done) % 512 < 8: i += 1
	return done


func _touch(i: int, p: Vector2, down: bool) -> InputEventScreenTouch:
	var t := InputEventScreenTouch.new()
	t.index = i; t.position = p; t.pressed = down
	return t

func _drag(i: int, p: Vector2) -> InputEventScreenDrag:
	var d := InputEventScreenDrag.new()
	d.index = i; d.position = p
	return d


func _talking(k) -> bool:
	return k.dialog.visible or k._story_dialog_open()

func _hush(k) -> void:
	k.dialog.visible = false
	var sui = k._story_ui()
	if sui: sui.close_all(); sui.dlg.visible = false
	await process_frame
	await process_frame
