extends SceneTree
# Combo review capture: target select, focus, then a fixed-step frame sequence of a full party turn (30 fps),
# plus the Build Attack Order tab.
#   xvfb-run -s "-screen 0 1280x720x24" godot --path . --resolution 1280x720 --script res://tools/shot_combo.gd -- --out=/tmp/aqc
var g
var out := "/tmp/aqc"
var smart := true
func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.substr(6)
		if a == "--random": smart = false
	DirAccess.make_dir_recursive_absolute(out + "/frames")
	g = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(g)
	_run()
func shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out + "/" + n + ".png")
func tick(ms: float) -> void:
	g.layout()
	var tot: float = ms * float(g.speed)
	while tot > 0.0:
		var s := minf(tot, 17.0)
		if not g.paused: g.step(s)
		tot -= s
	if g.HUD != null and g.G != null: g.HUD.update(g, ms)
	g.battle_cam_update(ms * float(g.speed) if not g.paused else 0.0)
	g.ui_in = minf(1.0, g.ui_in + ms / 380.0)
	g.queue_redraw()
	await process_frame
func run_for(ms: float) -> void:
	var t := 0.0
	while t < ms:
		await tick(33.0); t += 33.0
func _run() -> void:
	await create_timer(0.8).timeout
	g.set_process(false)
	g.sfx.muted = true
	var C = load("res://scripts/combo.gd")
	var party: Array = g.party_names()
	if smart:
		var pf: Array = []
		for h in party: pf.append(C.frames(str(g.CHAR[h].cls)))
		var plan: Dictionary = C.best_plan(pf)
		g.HERO_ORDER = []; g.HERO_DELAY = {}
		for j in plan.order.size():
			g.HERO_ORDER.append(party[plan.order[j]]); g.HERO_DELAY[party[plan.order[j]]] = plan.delays[j]
	g.AUTO = false
	var qf = root.get_node("QuestFlow")
	qf.in_kingdom_battle = true
	g.encounter = qf.encounter_for("forest", 3)
	g.new_battle(3); g.phase = "battle"; g.paused = false; g.screen = ""
	g.begin_timeline()
	await run_for(900)
	await shot("c1_target_select")
	g.bf_cycle_focus(1)
	await run_for(300)
	await shot("c2_focus")
	g.bf_launch()
	var i := 0
	var best_sp := -1
	while (g.G.mode == "strike" or i < 10) and i < 220:
		await tick(33.0)
		await RenderingServer.frame_post_draw
		var im: Image = root.get_viewport().get_texture().get_image()
		im.save_png(out + "/frames/f%03d.png" % i)
		var tc = g.G.turnc
		if tc.sparks > best_sp and tc.sparks >= 3 and g.HUD.spark_pop > 0.8:
			best_sp = tc.sparks; im.save_png(out + "/c3_spark.png")
		i += 1
	await run_for(330)
	await shot("c4_summary")
	print("frames ", i, " hits ", g.G.summary.get("hits", 0), " sparks ", g.G.summary.get("sparks", 0))
	# enemy turn: hurt reactions on the party
	var guard := 0
	while not (g.G.side == "red" and g.G.turnc.running) and guard < 200 and g.phase == "battle":
		await tick(33.0); guard += 1
	await run_for(800)
	await shot("c7_enemy_turn")
	# finish the fight on AUTO for the victory reaction
	g.AUTO = true
	guard = 0
	while g.phase == "battle" and guard < 2000:
		await tick(33.0); guard += 1
	await run_for(600)
	await shot("c8_victory")
	qf.in_kingdom_battle = false
	# Build > Attack Order: first as a random order, then after "Suggest order"
	g.phase = "title"; g.G = null
	var o: Array = g.party_names().duplicate()
	o.reverse()
	g.HERO_ORDER = o; g.HERO_DELAY = {}
	g.open_build(); g.BUILD.tab = 3
	await run_for(500)
	await shot("c5_order_unsorted")
	var C2 = load("res://scripts/combo.gd")
	var pf2: Array = []
	for h in o: pf2.append(C2.frames(str(g.CHAR[h].cls)))
	var plan2: Dictionary = C2.best_plan(pf2)
	var o2: Array = []
	for pi in plan2.order: o2.append(o[pi])
	for j in o2.size(): g.HERO_DELAY[o2[j]] = float(plan2.delays[j])
	g.HERO_ORDER = o2
	await run_for(300)
	await shot("c6_order_suggested")
	quit()
