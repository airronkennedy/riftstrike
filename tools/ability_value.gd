extends SceneTree
# Ability value sweep: for each ability, its owner (or a carrier of the subclass) auto-casts it while the rest of
# the party runs default kits. Reports party HP left / turns per ability.  --n=40 --lv=99 --mode=2 --heroes=Airron,...
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
func reset(lv: int) -> void:
	for h in g.HERO_NAMES:
		g.HERO_PROG[h] = {"level": lv, "xp": 0}; g.HERO_MP[h] = 0.0
		g.AB_EQUIP.erase(h); g.AB_AUTO.erase(h); g.validate_ab_equip(h)
func fight(mode: int) -> Array:
	g.encounter = {}
	g.new_battle(mode); g.phase = "battle"; g.begin_player_turn(); g.AUTO = true
	var guard := 0
	while g.phase == "battle" and guard < 90000:
		g.step(17); guard += 1
	var hp := 0.0; var mx := 0.0
	for u in g.G.units:
		if u.team == "blue": hp += maxi(0, u.hp); mx += u.maxhp
	var r := [1 if g.G.result == "win" else 0, hp / mx, g.G.turn]
	while g.phase == "ending": g.step(17)
	g.phase = "title"
	return r
func _run() -> void:
	await create_timer(0.3).timeout
	g.sfx.muted = true
	if args.has("set"):
		for kv in str(args.set).split(","):
			var pp := kv.split(":")
			g.set(pp[0], float(pp[1]))
	var n := int(args.get("n", "40")); var lv := int(args.get("lv", "99")); var mode := int(args.get("mode", "2"))
	var heroes: Array = str(args.get("heroes", "Airron,Christian,Weston,Wiesen,Lanning")).split(",")
	g.SQUAD = ["Airron", "Christian", "Weston", "Wiesen", "Lanning", "Rico"]
	var jobs: Array = []
	for h in heroes:
		for id in g.AB_CLASS_LIST[h]: jobs.append([h, id, ""])
	if args.has("subs"):
		for sub in str(args.subs).split(","):
			for id in g.AB_SUB_LIST[sub]: jobs.append([str(args.get("carrier", "Christian")), id, sub])
	# baseline: nobody casts on the tested hero (basic attacks only)
	jobs.push_front([heroes[0], "", ""])
	for j in jobs:
		var w := 0; var hp := 0.0; var t := 0.0
		for i in n:
			reset(lv)
			if j[2] != "": g.CHAR[j[0]].sub = j[2]
			g.validate_ab_equip(j[0])
			if j[1] != "":
				var key: String = "cls" if str(g.ABILITY_DEFS[j[1]].src) == "class" else "sub"
				g.AB_EQUIP[j[0]][key] = j[1]
			g.AB_AUTO[j[0]] = j[1]
			var r := fight(mode)
			w += r[0]; hp += r[1]; t += r[2]
		var kind: String = str(g.ABILITY_DEFS[j[1]].kind) if j[1] != "" else "-"
		print("AV %-9s %-18s %-18s win %2d/%d hp %.3f turns %.2f" % [j[0], j[1] if j[1] != "" else "(basic only)", kind, w, n, hp / n, t / n])
	g.CHAR["Christian"].sub = "Vanguard"
	quit()
