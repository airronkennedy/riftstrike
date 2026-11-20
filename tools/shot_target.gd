extends SceneTree
# Target select review shots: a region fight's YOUR TURN window with the Auto target preview, a tapped focus,
# a highlands elite with "Elites First", phone portrait, and the Emberhold menu's Auto target button.
#   xvfb-run -s "-screen 0 1280x720x24" godot --path . --resolution 1280x720 --script res://tools/shot_target.gd -- --out=/tmp/aqt
var g
var out := "/tmp/aqt"
func _init() -> void:
	preload("res://tools/test_save.gd").fresh()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	g = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(g)
	_run()
func shot(n: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out + "/" + n + ".png")
func tick(ms: float) -> void:
	g.layout()
	var tot: float = ms
	while tot > 0.0:
		var s := minf(tot, 17.0)
		if not g.paused: g.step(s)
		tot -= s
	if g.HUD != null and g.G != null: g.HUD.update(g, ms)
	g.ui_in = minf(1.0, g.ui_in + ms / 380.0)
	g.queue_redraw()
	await process_frame
func run_for(ms: float) -> void:
	var t := 0.0
	while t < ms:
		await tick(33.0); t += 33.0
func fight(region: String, lv: int, elite: bool) -> void:
	var qf = root.get_node("QuestFlow")
	qf.in_kingdom_battle = true
	g.encounter = qf.encounter_for(region, lv)
	g.encounter.elite = elite
	g.new_battle(3)
	if g.AREAS.has(str(g.encounter.area)): g.battle_area = str(g.encounter.area)
	g.phase = "battle"; g.paused = false; g.screen = ""; g.AUTO = false
	g.begin_timeline()
func _run() -> void:
	await create_timer(0.8).timeout
	g.set_process(false)
	g.sfx.muted = true
	TargetSelect.set_mode("weakest")
	await fight("forest", 4, false)
	g.alive("red")[1].hp = int(g.alive("red")[1].maxhp * 0.4)
	await run_for(1100)
	await shot("t1_select_auto_finish_off")
	g.bf_focus(g.alive("red")[0])
	g.G.mode = "select" # hold the window open for the shot (bf_focus launches at once in play)
	g.G.turnc.running = false
	await run_for(300)
	await shot("t2_tapped_focus")
	g.G.mode = "strike"
	TargetSelect.set_mode("elite")
	await fight("highlands", 8, true)
	await run_for(1100)
	await shot("t3_elite_first_highlands")
	TargetSelect.set_mode("threat")
	await fight("shore", 6, false)
	await run_for(400)
	g.G.turnc.start(g, "blue", g.bf_order("blue"), g.HERO_DELAY, g.bf_auto_target())
	g.G.mode = "strike"
	await run_for(900)
	await shot("t4_strike_after_lock")
	TargetSelect.set_mode("weakest")
	quit()
