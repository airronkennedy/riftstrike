extends SceneTree
## Dungeon + boss tests (docs/DUNGEON.md, docs/BOSSES.md):
##   godot --headless --path . -s res://tools/test_dungeon.gd
var fails := 0
func ok(c: bool, msg: String) -> void:
	print(("PASS  " if c else "FAIL  ") + msg)
	if not c: fails += 1

func _init() -> void:
	preload("res://tools/test_save.gd").fresh()
	DungeonGate.reset()
	_run.call_deferred()

func reach(fi: int, from: Vector2i, open: Dictionary) -> Dictionary:
	var sz := DungeonMaps.size(fi)
	var seen := {from: true}
	var q: Array = [from]
	while not q.is_empty():
		var c: Vector2i = q.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if n.x < 0 or n.y < 0 or n.x >= sz.x or n.y >= sz.y or seen.has(n): continue
			if DungeonMaps.walkable(fi, n, open): seen[n] = true; q.append(n)
	return seen

func touches(seen: Dictionary, c: Vector2i) -> bool:
	for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if seen.has(c + d): return true
	return false

func _run() -> void:
	# ---- 1) maps
	for fi in DungeonMaps.FLOORS.size():
		var rows: Array = DungeonMaps.rows(fi)
		var w: int = str(rows[0]).length()
		ok(rows.all(func(r): return str(r).length() == w), "floor %d is rectangular (%dx%d)" % [fi + 1, w, rows.size()])
		var start: Vector2i = DungeonMaps.find(fi, "S") if fi == 0 else DungeonMaps.find(fi, "<")
		var all_open := reach(fi, start, {"G": true, "D": true})
		var closed := reach(fi, start, {})
		for ch in ["C", "L", "D", "G", "P", "B", ">"]:
			for c in DungeonMaps.find_all(fi, ch):
				ok(touches(all_open, c), "floor %d: %s at %s reachable" % [fi + 1, ch, str(c)])
		var down: Vector2i = DungeonMaps.find(fi, ">")
		if down.x >= 0: ok(not touches(closed, down), "floor %d: the stairs down are gated until the lever / key" % [fi + 1])
		for k in (DungeonMaps.floor_def(fi).chests as Dictionary).keys():
			var p: PackedStringArray = str(k).split(",")
			ok(DungeonMaps.at(fi, Vector2i(int(p[1]), int(p[0]))) == "C", "floor %d: chest data %s sits on a chest" % [fi + 1, k])
	var f2: Dictionary = DungeonMaps.floor_def(1)
	ok((f2.chests as Dictionary).values().any(func(c): return bool(c.get("key", false))), "floor 2 has a chest with its key")
	ok(DungeonMaps.find(2, "P").x >= 0 and DungeonMaps.find(2, "B").x >= 0, "floor 3 has a save point before the boss door")
	# ---- 2) boss data
	var Q = load("res://scripts/quest_rpg.gd")
	for id in BossDefs.BOSSES.keys():
		var d: Dictionary = BossDefs.get_def(id)
		var ph: Array = d.phases
		ok(ph.size() >= 2 and float(ph[0].at) >= 0.999, "%s: %d phases from full HP" % [id, ph.size()])
		var sorted := true
		for i in range(1, ph.size()): if float(ph[i].at) >= float(ph[i - 1].at): sorted = false
		ok(sorted, "%s: phase thresholds go down" % id)
		for p2 in ph:
			for s in p2.sig: ok(BossDefs.SIGNATURES.has(s), "%s: signature %s defined" % [id, s])
		var e: Dictionary = BossDefs.encounter(id, 5)
		ok(Q.FOE_TIER.has(str(e.tiers[0])) and load("res://scripts/af_roster.gd").FOES.has(str(e.foe_ids[0])), "%s: tier %s and art %s exist (balance hooks)" % [id, e.tiers[0], e.foe_ids[0]])
		var ln: Dictionary = BossDefs.lines(id)
		ok(str(ln.intro) != "" and str(ln.victory) != "" and (ln.phase as Array).size() >= ph.size() - 1, "%s: intro, phase and victory lines" % id)
	# ---- 3) dungeon scene: beats, danger meter, floors
	var en = root.get_node("Encounters")
	var qf = root.get_node("QuestFlow")
	if en.random_battle_requested.is_connected(qf._on_battle_requested): en.random_battle_requested.disconnect(qf._on_battle_requested)
	var asked: Array = []
	var cb := func(r): asked.append(r)
	en.random_battle_requested.connect(cb)
	var dn = (load("res://scenes/dungeon.tscn") as PackedScene).instantiate()
	dn.shots_mode = true
	root.add_child(dn)
	await process_frame; await process_frame
	ok(dn.floor_i == 0 and DungeonMaps.at(0, dn.cell_of(dn.pos)) != "#", "dungeon opens on floor 1 at the entrance")
	var g0: int = dn.gold
	dn.pos = dn.cell_center(Vector2i(15, 4)); await process_frame
	ok(dn.near.get("kind", "") == "chest", "next to the floor 1 chest")
	dn.use(dn.near); dn.dialog.visible = false
	ok(dn.gold == g0 + 80, "chest pays 80 gold (%d -> %d)" % [g0, dn.gold])
	var gate: Vector2i = DungeonMaps.find(0, "G")
	ok(not DungeonMaps.walkable(0, gate, dn.fopen()), "portcullis starts shut")
	dn.pos = dn.cell_center(Vector2i(21, 5)); await process_frame
	dn.use(dn.near); dn.dialog.visible = false
	ok(DungeonMaps.walkable(0, gate, dn.fopen()) and not dn.astar.is_point_solid(gate), "the lever opens the portcullis (and the pathfinder knows)")
	# danger meter -> Encounters
	dn.meter = 0.0
	dn.pos = dn.cell_center(Vector2i(12, 9))
	var steps := 0
	while asked.is_empty() and steps < 4000:
		dn.drag_vec = Vector2(40, 0) if (steps / 60) % 2 == 0 else Vector2(-40, 0)
		dn._process(1.0 / 60.0); steps += 1
	dn.drag_vec = Vector2.ZERO
	ok(asked.size() == 1 and str(asked[0]) == "deeps_1", "walking fills the danger meter and asks Encounters for a deeps_1 battle (%s after %d frames)" % [str(asked), steps])
	ok(dn.meter < 0.05 and qf.return_scene == DungeonGate.SCENE, "meter resets and the fight returns to the dungeon")
	qf.return_scene = ""
	var enc: Dictionary = qf.encounter_for("deeps_1", 4)
	ok(str(enc.area) == "coalvein-deeps" and int(enc.level) == 4, "QuestFlow builds the deeps_1 encounter")
	dn.busy = false
	# stairs down -> floor 2; key + locked door
	dn.pos = dn.cell_center(DungeonMaps.find(0, ">")); dn.stair_grace = 0.0
	dn._check_step_triggers()
	for i in 4: await process_frame
	ok(dn.floor_i == 1, "the stairs lead to floor 2")
	var door: Vector2i = DungeonMaps.find(1, "D")
	dn.pos = dn.cell_center(door + Vector2i(0, 1)); await process_frame
	dn.use(dn.near); dn.dialog.visible = false
	ok(not bool(dn.fopen().D), "the vault door stays locked without the key")
	dn.pos = dn.cell_center(Vector2i(5, 13)); await process_frame
	dn.use(dn.near); dn.dialog.visible = false
	ok(dn.keys.has("deeps_2"), "the floor 2 chest holds the Vault Key")
	dn.pos = dn.cell_center(door + Vector2i(0, 1)); await process_frame
	dn.use(dn.near); dn.dialog.visible = false
	ok(bool(dn.fopen().D), "the key opens the vault door")
	# floor 3 shrine heals + saves
	dn.load_floor(2, dn.cell_center(DungeonMaps.find(2, "P") + Vector2i(0, 1)))
	dn.hp = 3
	await process_frame
	dn.use(dn.near); dn.dialog.visible = false
	var cf := ConfigFile.new(); cf.load(DungeonGate.SAVE)
	ok(dn.hp == dn.hp_max and int(cf.get_value("progress", "floor", -1)) == 2, "the ember shrine heals the party and saves on floor 3")
	ok(not dn._encounters_here(), "no random battles in the boss hall")
	dn.queue_free()
	en.random_battle_requested.disconnect(cb)
	en.random_battle_requested.connect(qf._on_battle_requested)
	# ---- 4) boss fights on the real battle (intro, phases, finishing blow, Bosses signal)
	change_scene_to_file("res://main.tscn")
	await create_timer(0.6).timeout
	var g = current_scene
	g.sfx.muted = true
	var C = load("res://scripts/combo.gd")
	var party: Array = g.party_names()
	var pf: Array = []
	for h in party: pf.append(C.frames(str(g.CHAR[h].cls)))
	var plan: Dictionary = C.best_plan(pf)
	var smart: Array = []
	var sdel := {}
	for j in plan.order.size(): smart.append(party[plan.order[j]]); sdel[party[plan.order[j]]] = plan.delays[j]
	for id in BossDefs.BOSSES.keys():
		var res := {"random": [0, 0, 0], "smart": [0, 0, 0]}
		for mode in ["random", "smart"]:
			for i in 8:
				for h in party: g.set_hero_level(h, 7); g.HERO_MP[h] = 0.0
				if mode == "random":
					var o2: Array = party.duplicate(); o2.shuffle(); g.HERO_ORDER = o2; g.HERO_DELAY = {}
				else:
					g.HERO_ORDER = smart; g.HERO_DELAY = sdel
				g.AUTO = true
				g.start_boss_battle(id)
				if i == 0 and mode == "smart":
					ok(g.boss != null and g.G.mode == "intro" and g.boss.unit.tier == str(BossDefs.get_def(id).tier), "%s: fight opens on the intro cut-in" % id)
				var guard := 0
				while g.phase == "battle" and guard < 60000:
					g.step(17); guard += 1
				var bf = g.boss
				if g.G.result == "win":
					res[mode][0] += 1
					if mode == "smart" and i == 0:
						ok(bf.phase >= 1 and bf.finish_t >= 0.0, "%s: a win passes a phase change and plays the finishing blow" % id)
				res[mode][1] += g.res_combo_hits; res[mode][2] += g.res_combo_sparks
				g.encounter = {}; g.boss = null; g.phase = "title"
		var rr: float = float(res.random[2]) / maxf(1.0, res.random[1])
		var sr: float = float(res.smart[2]) / maxf(1.0, res.smart[1])
		print("  %s: random order %d/8 wins, %.0f%% sparks  ·  suggested order %d/8 wins, %.0f%% sparks" % [id, res.random[0], rr * 100, res.smart[0], sr * 100])
		ok(sr > rr + 0.15 and int(res.smart[0]) >= int(res.random[0]), "%s: a good Attack Order sparks clearly more and wins at least as often" % id)
	# Bosses.finish -> boss_defeated(id) after the scene swap, recorded
	var bs = root.get_node("Bosses")
	bs.reset()
	var got: Array = []
	bs.boss_defeated.connect(func(id): got.append(id))
	g.AUTO = true
	for h in party: g.set_hero_level(h, 10)
	bs.return_scene = "res://main.tscn"
	g.start_boss_battle("unlit_regnant")
	g.boss.unit.hp = 1
	var gd := 0
	while g.phase == "battle" and gd < 60000: g.step(17); gd += 1
	g.boss_return(g.G.result == "win")
	for i in 8: await process_frame
	ok(got == ["unlit_regnant"] and bs.is_defeated("unlit_regnant"), "a win emits Bosses.boss_defeated and is saved (%s)" % str(got))
	bs.reset()
	preload("res://tools/test_save.gd").fresh()
	DungeonGate.reset()
	print("DUNGEON_TEST ", "PASS" if fails == 0 else "FAIL (%d)" % fails)
	quit(1 if fails > 0 else 0)
