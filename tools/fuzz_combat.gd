extends SceneTree
# Random manual-play fuzz: queues, abilities, AUTO/pause/speed toggles, orientation flips, RUN.
# Checks invariants every step and that no fight stalls. --n=fights --seed=S
#   XDG_DATA_HOME=/tmp/combat-xdg godot --headless --path . --script res://tools/fuzz_combat.gd -- --n=200
var g
var args := {}
var fails: Array = []
func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			var kv := a.substr(2).split("=")
			args[kv[0]] = kv[1]
	g = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(g)
	_run()

var base := {}
func snap() -> void:
	base = {}
	for u in g.G.units:
		base[u] = {"atk": u.atk, "def": u.def, "armor": u.armor, "crit": u.crit, "speed": u.speed}

func check(tag: String) -> void:
	for u in g.G.units:
		if base.has(u):
			for st3 in ["atk", "def", "armor", "crit", "speed"]:
				var want: int = int(base[u][st3])
				for b in u.buffs:
					if str(b.stat) == st3: want += int(b.d)
				if int(u.get(st3)) != want: fails.append("%s %s %s=%d want %d buffs=%s" % [tag, u.name, st3, int(u.get(st3)), want, str(u.buffs)])
		if u.hp < 0 or u.hp > u.maxhp: fails.append("%s hp %s %d/%d" % [tag, u.name, u.hp, u.maxhp])
		if u.gauge < 0.0 or u.gauge > 100.0: fails.append("%s gauge %s %f" % [tag, u.name, u.gauge])
		if u.dead and u.hp > 0: fails.append("%s dead with hp %s" % [tag, u.name])
		if not u.dead and u.hp <= 0: fails.append("%s alive at 0 %s" % [tag, u.name])
		for st in ["atk", "def", "speed"]:
			if int(u.get(st)) < 1: fails.append("%s %s %s<1" % [tag, u.name, st])
		for st2 in ["armor", "crit"]:
			if int(u.get(st2)) < 0: fails.append("%s %s %s<0" % [tag, u.name, st2])

func _run() -> void:
	await create_timer(0.3).timeout
	g.sfx.muted = true
	if args.has("seed"): seed(int(args.seed))
	var n := int(args.get("n", "100"))
	var stats := {"win": 0, "lose": 0, "draw": 0, "run": 0, "flips": 0, "abil": 0}
	for f in n:
		var lv: int = [1, 5, 20, 45, 80, 99][randi() % 6]
		for h in g.HERO_NAMES:
			g.HERO_PROG[h] = {"level": lv, "xp": 0}
			g.HERO_MP[h] = randf() * 100.0
			g.AB_EQUIP.erase(h); g.AB_AUTO.erase(h); g.validate_ab_equip(h)
			var c: Array = g.unlocked_class_ids(h)
			var s: Array = g.unlocked_sub_ids(h)
			if c.size() > 0: g.AB_EQUIP[h].cls = c[randi() % c.size()]
			if s.size() > 0: g.AB_EQUIP[h].sub = s[randi() % s.size()]
		g.CHAR["Rico"].sub = g.SUB_IDS[randi() % g.SUB_IDS.size()]
		g.CHAR["Lanning"].sub = g.SUB_IDS[randi() % g.SUB_IDS.size()]
		g.SQUAD.shuffle()
		g.AUTO = false
		g.speed = 1
		if randf() < 0.35:
			var kinds: Array = []
			for k in 1 + randi() % 3: kinds.append(["torch", "barrel", "tnt"][randi() % 3])
			g.start_encounter({"kinds": kinds, "level": lv, "area": "brookside_wilds"})
		else:
			g.start_fight(1 + randi() % 3)
		snap()
		var guard := 0
		var last_turn := 0
		var turn_steps := 0
		var mods_before := {}
		while g.phase == "battle" or g.phase == "ending":
			guard += 1
			if guard > 120000: fails.append("fight %d guard (mode %s turn %d side %s)" % [f, g.G.mode, g.G.turn, g.G.side]); break
			if g.phase == "battle" and g.G.mode == "select" and not g.AUTO:
				var al: Array = g.alive("blue")
				al.shuffle()
				for u in al.slice(0, 1 + randi() % al.size()):
					g.toggle_queue(u)
					if u.gauge >= 100.0 and randf() < 0.7:
						var id: String = u.ab_class if randf() < 0.5 else u.ab_sub
						if id != "": g.queue_ability(u, id); stats.abil += 1
					if randf() < 0.1: g.toggle_queue(u) # un-queue again
				if randf() < 0.05: g.clear_queue()
				if randf() < 0.1: g.queue_all()
				g.execute_orders()
			var r := randf()
			if r < 0.002: g.AUTO = not g.AUTO
			elif r < 0.004: g.toggle_speed()
			elif r < 0.0045:
				g.remap_units(not g.PORT); g.set_orientation(not g.PORT); g.build_terrain(); stats.flips += 1
			elif r < 0.0047 and g.phase == "battle":
				g.run_battle(); stats.run += 1; break
			if g.paused: g.paused = false
			g.step(17)
			if g.G.turn != last_turn:
				last_turn = g.G.turn; turn_steps = 0
			else:
				turn_steps += 1
				if turn_steps > 4000 and g.G.mode != "select":
					fails.append("fight %d turn %d stalled in %s/%s" % [f, g.G.turn, g.G.side, g.G.mode]); break
			if guard % 7 == 0: check("f%d" % f)
			if g.screen == "results": break
		if g.G.result != "": stats[g.G.result] = stats.get(g.G.result, 0) + 1
		# buffs must be fully unwound when a unit's mods expire
		if g.PORT: g.remap_units(false); g.set_orientation(false); g.build_terrain()
		g.to_title()
		if fails.size() > 20: break
	print("FUZZ ", JSON.stringify(stats), " ", "PASS" if fails.is_empty() else "FAIL " + str(fails.slice(0, 20)))
	quit()
