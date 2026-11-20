extends SceneTree
## Spark combo checks (docs/COMBO.md).
##   godot --headless --path . --script res://tools/test_combo.gd   (SWEEP_N=battles per case, default 12)
## 1) timing math (random 5-keeper parties): random attack orders spark ~20-35% of hits, the best order + delays ~60-80%.
## 2) real AUTO battles with the current party: random order vs the Build "Suggest" plan.
## 3) team-turn flow: target select, focus, no manual command menu, hits/sparks counted, summary written.
var fails := 0
func ok(c: bool, m: String) -> void:
	print(("ok   " if c else "FAIL ") + m)
	if not c: fails += 1
func _init() -> void:
	preload("res://tools/test_save.gd").fresh() # new-game user data every run
	_run.call_deferred()

func _run() -> void:
	var n := int(OS.get_environment("SWEEP_N")) if OS.get_environment("SWEEP_N") != "" else 12
	var C = load("res://scripts/combo.gd")
	# ---- 1) math over random 4-class parties
	var names: Array = C.FRAMES.keys()
	var seed_rng := RandomNumberGenerator.new(); seed_rng.seed = 11
	var rs := 0.0
	var bs := 0.0
	var parties := 40
	for k in parties:
		var pick: Array = []
		var pool := names.duplicate()
		for i in 5:
			pick.append(pool.pop_at(seed_rng.randi() % pool.size()))
		var fr: Array = []
		for c in pick: fr.append(C.frames(c))
		rs += C.spark_rate(fr, [0.0, 0.0, 0.0, 0.0, 0.0], 40, k)
		var plan: Dictionary = C.best_plan(fr)
		var o: Array = []
		for i in plan.order: o.append(fr[i])
		bs += C.spark_rate(o, plan.delays, 40, k + 500)
	rs /= parties; bs /= parties
	print("timing math: random order %.1f%% sparks, best plan %.1f%%" % [rs * 100, bs * 100])
	ok(rs >= 0.18 and rs <= 0.38, "random order sparks ~20-35%% (%.1f%%)" % (rs * 100))
	ok(bs >= 0.58 and bs <= 0.85, "smart order + delays sparks ~60-80%% (%.1f%%)" % (bs * 100))
	ok(C.traits(C.frames("Rogue")).contains("Fast") and C.traits(C.frames("Mage")).contains("Slow"), "speed tags: Rogue Fast, Mage Slow")
	var w0: Dictionary = C.window(C.frames("Mage"), 0, 0.0)
	var w1: Dictionary = C.window(C.frames("Rogue"), 1, 0.0)
	ok(w1.first < w0.last and w1.last > w0.first, "Mage first + Rogue second overlap their hit windows")
	# ---- 2) real battles
	change_scene_to_file("res://main.tscn")
	await create_timer(0.6).timeout
	var g = current_scene
	g.sfx.muted = true
	var qf = root.get_node("QuestFlow")
	var party: Array = g.party_names()
	var pf: Array = []
	for h in party: pf.append(C.frames(str(g.CHAR[h].cls)))
	var plan2: Dictionary = C.best_plan(pf)
	var smart: Array = []
	var sdel := {}
	for j in plan2.order.size():
		smart.append(party[plan2.order[j]]); sdel[party[plan2.order[j]]] = plan2.delays[j]
	var classes: Array = []
	for h in party: classes.append(str(g.CHAR[h].cls))
	print("party: %s  suggested order: %s  delays: %s  (math %.0f%%)" % [", ".join(classes), ", ".join(smart), str(plan2.delays), plan2.rate * 100])
	var res := {}
	for mode in ["random", "smart"]:
		var hits := 0
		var sparks := 0
		var wins := 0
		var secs := 0.0
		for i in n:
			if mode == "random":
				var o2: Array = party.duplicate(); o2.shuffle()
				g.HERO_ORDER = o2; g.HERO_DELAY = {}
			else:
				g.HERO_ORDER = smart; g.HERO_DELAY = sdel
			for h in party: g.HERO_MP[h] = 0.0
			qf.in_kingdom_battle = true
			g.encounter = qf.encounter_for("forest", 3)
			g.new_battle(3)
			g.phase = "battle"; g.screen = ""; g.AUTO = true
			g.begin_timeline()
			var guard := 0
			while g.phase == "battle" and guard < 40000:
				g.step(17); guard += 1
			hits += g.res_combo_hits; sparks += g.res_combo_sparks
			if g.G.result == "win": wins += 1
			secs += g.G.t / 1000.0
		var rate := float(sparks) / maxf(1.0, float(hits))
		res[mode] = rate
		print("%-6s order: %5.1f%% of party hits spark, %d hits/battle, win %d/%d, %.1f s/battle" % [mode, rate * 100, hits / n, wins, n, secs / n])
	ok(float(res.smart) > float(res.random) + 0.15, "in battle, the smart order sparks clearly more (%.0f%% vs %.0f%%)" % [res.smart * 100, res.random * 100])
	# ---- 3) flow
	g.AUTO = false
	g.encounter = qf.encounter_for("meadow", 1)
	g.new_battle(3); g.phase = "battle"; g.screen = ""
	g.begin_timeline()
	ok(g.G.bf and g.G.mode == "select", "party turn opens with target select")
	ok(not g.has_method("cmd_attack") and not g.has_method("manual_execute"), "no manual command menu")
	var foe = g.alive("red")[0]
	g.bf_focus(foe)
	ok(g.G.focus == foe and g.G.mode == "strike", "tapping an enemy focuses it and starts the team attack")
	var guard2 := 0
	while g.G.mode == "strike" and guard2 < 3000:
		g.step(17); guard2 += 1
	ok(int(g.G.summary.get("hits", 0)) >= party.size(), "turn summary counts the party's hits (%d)" % int(g.G.summary.get("hits", 0)))
	g.G.mode = "select"; g.G.sel_t = 50.0
	g.step(17); g.step(17); g.step(17); g.step(17)
	ok(g.G.mode != "select", "target select times out into an automatic attack")
	qf.in_kingdom_battle = false
	print("COMBO ", "PASS" if fails == 0 else "FAIL %d" % fails)
	quit()
