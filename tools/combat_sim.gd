extends SceneTree
# Combat balance harness (AUTO play, no rendering of results). Prints one JSON line per scenario.
# Run with a private save dir so it never touches a real save:
#   XDG_DATA_HOME=/tmp/combat-xdg godot --headless --path . --script res://tools/combat_sim.gd -- --n=40 --levels=1,10,25,50,99
# Options: --n=fights per scenario, --levels=list, --modes=1,2,3, --wild=1 (also run wild encounters), --best=1 (equip highest unlocked abilities)
var g
var args := {}
func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			var kv := a.substr(2).split("=")
			args[kv[0]] = kv[1]
	var sc: PackedScene = load("res://main.tscn")
	g = sc.instantiate()
	root.add_child(g)
	_run()

func wait(ms: float) -> void:
	await create_timer(ms / 1000.0).timeout

func set_levels(lv: int, best: bool) -> void:
	for h in g.HERO_NAMES:
		g.HERO_PROG[h] = {"level": lv, "xp": 0}
		g.HERO_MP[h] = 0.0
		g.AB_EQUIP.erase(h)
		g.AB_AUTO.erase(h)
		g.validate_ab_equip(h)
		if best:
			var c: Array = g.unlocked_class_ids(h)
			var s: Array = g.unlocked_sub_ids(h)
			if c.size() > 0: g.AB_EQUIP[h].cls = pick_best(c)
			if s.size() > 0: g.AB_EQUIP[h].sub = pick_best(s)

## Newest unlocked damage ability (what a player chasing damage would equip); newest overall if none.
func pick_best(ids: Array) -> String:
	for i in range(ids.size() - 1, -1, -1):
		if str(g.ABILITY_DEFS[ids[i]].kind).begins_with("damage"): return ids[i]
	return ids[ids.size() - 1]

func fight(mode: int, enc: Dictionary) -> Dictionary:
	if enc.is_empty():
		g.encounter = {}
		g.new_battle(mode)
	else:
		g.encounter = enc
		g.new_battle(3)
	g.phase = "battle"; g.paused = false; g.screen = ""
	g.begin_player_turn()
	g.AUTO = true
	g.combat_trace = []
	var guard := 0
	var casts := 0
	var seen := {}
	var red_specials := 0
	var max_hit := 0
	var heal_total := 0
	var last_hp := {}
	while g.phase == "battle" and guard < 90000:
		g.step(17); guard += 1
		for u in g.G.units:
			if u.act != null and not seen.has(u.act):
				seen[u.act] = true
				if u.act.ability != "": casts += 1
				if u.act.special: red_specials += 1
	var res := {"result": g.G.result if g.phase != "battle" else "stuck", "turns": g.G.turn, "casts": casts, "rspec": red_specials}
	var bl := 0; var bhp := 0.0; var bmax := 0.0
	var dmg := {}
	for u in g.G.units:
		if u.team == "blue":
			bmax += u.maxhp; bhp += maxi(0, u.hp)
			if not u.dead: bl += 1
			dmg[u.name] = u.dmg
	res["alive"] = bl
	res["hp_pct"] = bhp / maxf(1.0, bmax)
	res["dmg"] = dmg
	var rd := 0
	for u in g.G.units:
		if u.team == "red": rd += u.dmg
	res["red_dmg"] = rd
	var cb := 0.0; var abd := 0.0; var tot := 0.0
	for e in g.combat_trace:
		var blue := false
		for u in g.G.units:
			if u.name == e.src and u.team == "blue": blue = true
		if not blue: continue
		tot += e.dmg
		if e.combo: cb += e.dmg
		if e.ab: abd += e.dmg
	res["combo_share"] = cb / maxf(1.0, tot)
	res["ab_share"] = abd / maxf(1.0, tot)
	g.combat_trace = null
	# finish ending phase so the next fight starts clean
	var g2 := 0
	while g.phase == "ending" and g2 < 400:
		g.step(17); g2 += 1
	g.phase = "title"; g.screen = "title"
	return res

func summarize(tag: String, rs: Array) -> void:
	var w := 0; var l := 0; var d := 0; var s := 0
	var turns := 0.0; var casts := 0.0; var alive := 0.0; var hp := 0.0; var maxt := 0
	var dmg := {}
	var cs := 0.0; var abs_ := 0.0
	for r in rs:
		cs += r.combo_share; abs_ += r.ab_share
		match r.result:
			"win": w += 1
			"lose": l += 1
			"draw": d += 1
			_: s += 1
		turns += r.turns; casts += r.casts; alive += r.alive; hp += r.hp_pct; maxt = maxi(maxt, r.turns)
		for k in r.dmg: dmg[k] = dmg.get(k, 0) + r.dmg[k]
	var n := float(rs.size())
	var tot := 0.0
	for k in dmg: tot += dmg[k]
	var share := {}
	for k in dmg: share[k] = snappedf(dmg[k] / maxf(1.0, tot), 0.01)
	print("SIM ", JSON.stringify({"tag": tag, "n": rs.size(), "win": w, "lose": l, "draw": d, "stuck": s,
		"turns": snappedf(turns / n, 0.1), "max_turns": maxt, "casts": snappedf(casts / n, 0.1), "combo": snappedf(cs / n, 0.01), "abdmg": snappedf(abs_ / n, 0.01), "alive": snappedf(alive / n, 0.1), "hp": snappedf(hp / n, 0.01), "share": share}))

func _run() -> void:
	await wait(300)
	g.sfx.muted = true
	# --set=VAR:val,VAR:val overrides game.gd vars; --scale=key:val overrides encounters.json scaling (tuning sweeps).
	if args.has("set"):
		for kv in str(args.set).split(","):
			var p := kv.split(":")
			g.set(p[0], float(p[1]))
	if args.has("scale"):
		for kv in str(args.scale).split(","):
			var p2 := kv.split(":")
			g.WORLD.enc_cfg.scaling[p2[0]] = float(p2[1])
	var n := int(args.get("n", "30"))
	var best: bool = args.get("best", "1") == "1"
	var levels: Array = []
	for s in str(args.get("levels", "1,10,25,50,99")).split(","): levels.append(int(s))
	var modes: Array = []
	for s in str(args.get("modes", "3,2,1")).split(","): modes.append(int(s))
	for lv in levels:
		for mode in modes:
			var rs: Array = []
			for i in n:
				set_levels(lv, best)
				rs.append(fight(mode, {}))
			summarize("L%d raid6v%d" % [lv, mode], rs)
		if args.has("zones"):
			# --zones=15,25,35 enemy levels; --gap=0 hero level offset over the zone (uses lv as gap list when --gaps given)
			pass
		if args.get("wild", "0") == "1":
			for kinds in [["torch"], ["torch", "barrel"], ["torch", "barrel", "tnt"], ["tnt", "tnt", "barrel"]]:
				var rs2: Array = []
				for i in n:
					set_levels(lv, best)
					rs2.append(fight(3, {"kinds": kinds, "level": lv, "area": "brookside_wilds"}))
				summarize("L%d wild %s" % [lv, "+".join(kinds)], rs2)
	if args.has("zones"):
		for z in str(args.zones).split(","):
			for gp in str(args.get("gaps", "0,5,10")).split(","):
				var zl := int(z); var hl := mini(99, zl + int(gp))
				var rs3: Array = []
				for kinds in [["torch", "barrel"], ["torch", "barrel", "tnt"], ["tnt", "tnt", "barrel"], ["barrel", "barrel"]]:
					for i in maxi(1, n / 4):
						set_levels(hl, best)
						rs3.append(fight(3, {"kinds": kinds, "level": zl, "area": "x"}))
				summarize("zone L%d hero L%d" % [zl, hl], rs3)
	quit()
