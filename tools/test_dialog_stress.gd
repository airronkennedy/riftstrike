extends SceneTree
## Touch stress test for story dialogs and the field (needs a display for real input dispatch):
##   xvfb-run -a -s "-screen 0 1280x936x24" godot --path . --resolution 430x930 --script res://tools/test_dialog_stress.gd
## Every story dialog is opened in portrait and driven only by synthetic touches (Input.parse_input_event, so
## the game's own mouse emulation applies): rapid taps, taps while typing / fading, multi-touch, held fingers,
## releases on another frame, and taps aimed at choice / card buttons. A dialog must always finish; one that
## makes no progress for STALL_S while being tapped is a soft-lock. Then random touches while walking with the
## stick in the kingdom and the dungeon: the hero must stop when the finger lifts and never walk on his own.
## Prints "STRESS ok/FAIL" lines and "DIALOG_STRESS PASS|FAIL".
const StoryDialog = preload("res://scripts/story/story_dialog.gd")
const STALL_S := 8.0
const DIALOG_MAX_S := 60.0
var st
var fails := 0
var rng := RandomNumberGenerator.new()
var held := {} # finger index -> position

func ok(c: bool, m: String) -> void:
	print(("STRESS ok   " if c else "STRESS FAIL ") + m)
	if not c: fails += 1

func _init() -> void:
	rng.seed = int(OS.get_environment("STRESS_SEED")) if OS.get_environment("STRESS_SEED") != "" else 1337
	preload("res://tools/test_save.gd").fresh()
	_run.call_deferred()

func wait(ms: float) -> void:
	await create_timer(ms / 1000.0).timeout

func scene_path() -> String:
	return current_scene.scene_file_path if current_scene != null else ""

func win_size() -> Vector2:
	return Vector2(root.size)

## viewport (canvas) point -> window point for parse_input_event
func to_win(p: Vector2) -> Vector2:
	return root.get_final_transform() * p

func touch(i: int, p: Vector2, down: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = i; e.position = p; e.pressed = down
	Input.parse_input_event(e)
	if down: held[i] = p
	else: held.erase(i)

func drag(i: int, p: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = i; e.position = p; e.relative = p - held.get(i, p)
	Input.parse_input_event(e)
	held[i] = p

func lift_all() -> void:
	for i in held.keys(): touch(i, held[i], false)

func rand_pt() -> Vector2:
	var s := win_size()
	return Vector2(rng.randf_range(2, s.x - 2), rng.randf_range(2, s.y - 2))

func target_pt() -> Vector2:
	# aim at a choice or card button half the time (that's the only way past a choice)
	var ui = st.ui
	var bs: Array = []
	for c in ui.choices_box.get_children(): if c is Button: bs.append(c)
	if ui.card.visible:
		for c in ui.card_box.get_children(): if c is Button: bs.append(c)
	if not bs.is_empty() and rng.randf() < 0.6:
		var b: Button = bs[rng.randi() % bs.size()]
		var xf: Transform2D = b.get_global_transform_with_canvas()
		return to_win(xf * (b.size * Vector2(rng.randf_range(0.1, 0.9), rng.randf_range(0.2, 0.8))))
	return rand_pt()

## One burst of hostile input.
func chaos() -> void:
	match rng.randi() % 7:
		0: # plain tap, release next frame(s)
			var p := target_pt(); touch(0, p, true); await process_frame; touch(0, p, false)
		1: # hammer: 4 taps in one frame
			for k in 4:
				var p := target_pt(); touch(k, p, true); touch(k, p, false)
		2: # two fingers down together, lift one at a time
			var a := target_pt(); var b := rand_pt()
			touch(0, a, true); touch(1, b, true); await process_frame
			touch(1, b, false); await wait(rng.randf_range(10, 200)); touch(0, a, false)
		3: # held finger that drags (a stick) while another taps
			var a := rand_pt(); touch(2, a, true)
			for k in 3:
				drag(2, a + Vector2(rng.randf_range(-80, 80), rng.randf_range(-80, 80))); await process_frame
			var p := target_pt(); touch(3, p, true); touch(3, p, false)
			touch(2, held.get(2, a), false)
		4: # long press
			var p := target_pt(); touch(0, p, true); await wait(rng.randf_range(300, 900)); touch(0, p, false)
		5: # random pause (taps at random times: during typing, fades, between lines)
			await wait(rng.randf_range(0, 350))
		6: # release with no press (a lost press) and a press with a late release
			var p := target_pt(); touch(5, p, false); touch(6, p, true); await wait(rng.randf_range(0, 120)); touch(6, p, false)

func progress_key() -> String:
	var ui = st.ui
	var ct := ""
	for c in ui.card_box.get_children():
		if c is Label: ct += (c as Label).text.left(16)
	return "%s|%d|%d|%s|%s|%s|%s|%s|%s" % [str(st._dlg_id), ui._line_i, ui.choices_box.get_child_count(), str(ui.dlg.visible), str(ui._blocking), str(ui.card.visible), ct, ui.dlg_text.text.left(16), scene_path()]

func busy() -> bool:
	return st.ui.wants_taps() or st.ui.overlay.visible

func back_to_field() -> void:
	if scene_path() != st.KINGDOM_SCENE and scene_path() != st.DUNGEON_SCENE:
		change_scene_to_file(st.KINGDOM_SCENE)
		await wait(900)

func _open(sc: String) -> void:
	if sc == st.DUNGEON_SCENE: st.enter_dungeon()
	else: change_scene_to_file(sc)
	await wait(1500)
	for k in 100: # an entry dialog: tap through it
		if not busy(): break
		await chaos(); await process_frame
	lift_all()

func _run() -> void:
	st = root.get_node("Story")
	change_scene_to_file(st.KINGDOM_SCENE)
	await wait(1500)
	st.battle_stub = true
	st.use_dungeon_scene = true
	if st.has_method("_begin") and not st.started: st._begin()
	var ids: Array = StoryDialog.D.keys()
	if OS.get_environment("STRESS_WALK_ONLY") != "": ids = ids.slice(0, 21) # quick run: a few dialogs, then walking
	ok(ids.size() > 20, "story has %d dialogs" % ids.size())
	var worst := 0.0
	var stuck: Array = []
	var n := 0
	for id in ids:
		await back_to_field()
		st.ui.close_all()
		lift_all()
		st.start_dialog(str(id))
		var t0 := Time.get_ticks_msec()
		var last_key := progress_key()
		var last_change := t0
		var quiet := 0
		while true:
			await chaos()
			await process_frame
			var now := Time.get_ticks_msec()
			var key := progress_key()
			if key != last_key: last_key = key; last_change = now
			if not busy():
				quiet += 1
				if quiet > 6: break
			else: quiet = 0
			if (now - last_change) / 1000.0 > STALL_S:
				stuck.append("%s (stalled: %s)" % [id, key]); break
			if (now - t0) / 1000.0 > DIALOG_MAX_S:
				stuck.append("%s (over %ds)" % [id, int(DIALOG_MAX_S)]); break
		lift_all()
		worst = maxf(worst, (Time.get_ticks_msec() - t0) / 1000.0)
		n += 1
		if stuck.size() > 5: break
	ok(stuck.is_empty(), "%d dialogs driven by random touch, none stuck (slowest %.1fs) %s" % [n, worst, str(stuck)])
	# ------------------------------------------------ walking: stick + random touches, portrait
	st.ui.close_all()
	preload("res://tools/test_save.gd").fresh() # walk on a fresh story (the dialog pass above set every flag)
	st.reset()
	DungeonGate.reset()
	for sc in [st.KINGDOM_SCENE, st.DUNGEON_SCENE]:
		await _open(sc)
		ok(scene_path() == sc, "walk test opened %s" % sc.get_file())
		if scene_path() != sc: continue
		var getp := func() -> Vector2:
			var f = current_scene
			if f == null: return Vector2.ZERO
			if f.get("player_pos") != null: return f.player_pos
			return f.pos if f.get("pos") is Vector2 else Vector2.ZERO
		var start: Vector2 = getp.call()
		var walked := 0.0
		var runaway := 0
		var left := 0
		for r in 40:
			if scene_path() != sc: # walked into a warp / random fight: that's play, not a lock; come back
				lift_all()
				for k in 200:
					if not busy() and scene_path() != st.MAIN_SCENE: break
					await chaos(); await process_frame
				await _open(sc)
				left += 1
				continue
			if busy(): # Use / a step trigger opened something: tap through it
				for k in 60:
					if not busy(): break
					await chaos(); await process_frame
				ok(not busy(), "%s: a dialog opened while walking closes by tapping" % sc.get_file())
				continue
			# stick finger lands anywhere, drags a bit, plus stray taps with other fingers
			var a := rand_pt()
			var pre: Vector2 = getp.call()
			touch(0, a, true)
			var dirv := Vector2.from_angle(rng.randf() * TAU) * 60.0
			for k in 12:
				drag(0, a + dirv * (0.3 + 0.07 * k)); await process_frame
				if rng.randf() < 0.3: var p := rand_pt(); touch(1, p, true); touch(1, p, false)
			await wait(150)
			if scene_path() == sc: walked += pre.distance_to(getp.call())
			touch(0, held.get(0, a), false)
			await wait(120)
			var p1: Vector2 = getp.call()
			await wait(300)
			if not busy() and scene_path() == sc and p1.distance_to(getp.call()) > 2.0: runaway += 1
			# a quick tap on the field must not walk anywhere
			var q: Vector2 = getp.call()
			var tp := rand_pt(); touch(0, tp, true); await process_frame; touch(0, tp, false)
			await wait(400)
			if not busy() and scene_path() == sc and q.distance_to(getp.call()) > 2.0: runaway += 1
		print("STRESS note %s: left the scene %d times (warps / fights) and came back" % [sc.get_file(), left])
		ok(walked > 20.0, "%s: the floating stick walks the hero (%.0f px)" % [sc.get_file(), walked])
		ok(runaway == 0, "%s: hero stops when the finger lifts and taps never walk (%d runaways)" % [sc.get_file(), runaway])
		if current_scene != null and current_scene.get("tap_target") != null: ok(false, "kingdom: no tap-to-walk target left")
	lift_all()
	print("DIALOG_STRESS %s" % ("PASS" if fails == 0 else "FAIL %d" % fails))
	quit(0 if fails == 0 else 1)
