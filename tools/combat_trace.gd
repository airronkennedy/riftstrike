extends SceneTree
# One AUTO fight with a per-hit log. --mode=1|2|3 --lv=1 --kinds=torch,barrel (wild) --seed=N
var g
var args := {}
func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			var kv := a.substr(2).split("=")
			args[kv[0]] = kv[1]
	g = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(g)
	_run()
func _run() -> void:
	await create_timer(0.3).timeout
	g.sfx.muted = true
	if args.has("seed"): seed(int(args.seed))
	var lv := int(args.get("lv", "1"))
	for h in g.HERO_NAMES:
		g.HERO_PROG[h] = {"level": lv, "xp": 0}; g.HERO_MP[h] = 0.0
		g.AB_EQUIP.erase(h); g.AB_AUTO.erase(h); g.validate_ab_equip(h)
	if args.has("kinds"):
		g.encounter = {"kinds": str(args.kinds).split(","), "level": lv, "area": "brookside_wilds"}
		g.new_battle(3)
	else:
		g.encounter = {}
		g.new_battle(int(args.get("mode", "1")))
	g.phase = "battle"; g.begin_player_turn(); g.AUTO = true
	g.combat_trace = []
	for u in g.G.units:
		print("UNIT %s %s %s hp=%d atk=%d def=%d arm=%d crit=%d mana=%d spd=%d ab=%s/%s" % [u.team, u.name, u.kind, u.hp, u.atk, u.def, u.armor, u.crit, u.mana_regen, u.speed, u.ab_class, u.ab_sub])
	var guard := 0
	var seen := {}
	while g.phase == "battle" and guard < 90000:
		g.step(17); guard += 1
		for u in g.G.units:
			if u.act != null and not seen.has(u.act):
				seen[u.act] = true
				print("T%d %s ACT %s -> %s%s" % [g.G.turn, u.name, u.act.stage, u.act.target.name if u.act.target else "-", (" ABILITY " + u.act.ability) if u.act.ability != "" else (" SPECIAL" if u.act.special else "")])
		while g.combat_trace.size() > 0:
			var e: Dictionary = g.combat_trace.pop_front()
			print("T%d   %s -> %s %d%s%s%s%s" % [e.turn, e.src, e.dst, e.dmg, " COMBO" if e.combo else "", " AB" if e.ab else "", " CRIT" if e.crit else "", " splash" if e.splash else ""])
	print("RESULT ", g.G.result, " turns ", g.G.turn)
	quit()
