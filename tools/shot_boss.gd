extends SceneTree
# Boss fight capture: intro cut-in, a signature telegraph, a phase change and the finishing blow (+ frame sequences).
#   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --resolution 1280x720 --script res://tools/shot_boss.gd -- --boss=ash_sovereign --out=/tmp/boss
var g
var out := "/tmp/boss"
var id := "ash_sovereign"
var frames := true
var fi := 0
func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.substr(6)
		if a.begins_with("--boss="): id = a.substr(7)
		if a == "--no-frames": frames = false
	DirAccess.make_dir_recursive_absolute(out + "/frames")
	preload("res://tools/test_save.gd").fresh()
	g = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(g)
	_run()
func shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out + "/" + n + ".png")
func tick(ms: float, rec: bool = false) -> void:
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
	if rec and frames:
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out + "/frames/%04d.png" % fi); fi += 1
func run_for(ms: float, rec: bool = false) -> void:
	var t := 0.0
	while t < ms:
		await tick(33.0, rec); t += 33.0
func _run() -> void:
	await create_timer(0.8).timeout
	g.set_process(false)
	g.sfx.muted = true
	var C = load("res://scripts/combo.gd")
	var party: Array = g.party_names()
	var pf: Array = []
	for h in party: pf.append(C.frames(str(g.CHAR[h].cls)))
	var plan: Dictionary = C.best_plan(pf)
	g.HERO_ORDER = []; g.HERO_DELAY = {}
	for j in plan.order.size():
		g.HERO_ORDER.append(party[plan.order[j]]); g.HERO_DELAY[party[plan.order[j]]] = plan.delays[j]
	for h in party: g.set_hero_level(h, 7)
	g.AUTO = true
	g.start_boss_battle(id)
	var b = g.boss
	# 1) intro cut-in
	await run_for(1700, true)
	await shot("b1_intro")
	await run_for(1900, true)
	# 2) first party turn, then force the signature on the boss's turn and catch the telegraph
	b.sig_due = true
	b.boss_turns = 0
	var guard := 0
	while (b.tele.is_empty() or float(b.tele.t) < 550.0) and guard < 600 and g.phase == "battle":
		await tick(33.0, true); guard += 1
		if g.G.side == "blue": b.sig_due = true
	await shot("b2_signature")
	await run_for(1600, true)
	# 3) phase change: drop the boss to just above the next threshold; the next hit crosses it
	var ph: Array = b.d.phases
	if ph.size() > 1 and g.phase == "battle":
		b.unit.hp = int(float(b.unit.maxhp) * float(ph[1].at)) + 4
		guard = 0
		while b.phase < 1 and guard < 900 and g.phase == "battle":
			await tick(33.0, true); guard += 1
		await run_for(330, true)
		await shot("b3_phase")
		await run_for(1200, true)
	# 4) finishing blow: leave the boss a sliver; capture the slow-motion beat and the victory push-in
	if g.phase == "battle" and b.unit != null and not b.unit.dead:
		b.unit.hp = maxi(1, int(b.unit.maxhp * 0.02))
		for u in g.G.units:
			if u.team == "blue": u.hp = u.maxhp
		guard = 0
		while b.finish_t < 0.0 and guard < 1500 and g.phase == "battle":
			await tick(33.0, true); guard += 1
		await run_for(300, true)
		await shot("b4_finishing_blow")
		await run_for(1600, true)
		await shot("b5_victory")
		await run_for(1500, true)
	print("boss shots: ", out, " frames ", fi, " phase ", b.phase, " result ", g.G.result)
	preload("res://tools/test_save.gd").fresh()
	quit()
