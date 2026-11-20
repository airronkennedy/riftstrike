extends SceneTree
# Logic test: AUTO queues + fires the marked auto ability; MP carries between fights; auto pick clears on swap.
# (turn-1 MP regen still applies on top of the carried bar)
# godot --headless --path . --script res://tools/test_auto_mp.gd
var g
func _init() -> void:
	preload("res://tools/test_save.gd").fresh() # new-game user data every run
	var sc: PackedScene = load("res://main.tscn")
	g = sc.instantiate()
	root.add_child(g)
	_run()
func wait(ms: float) -> void:
	await create_timer(ms / 1000.0).timeout
func _run() -> void:
	await wait(300)
	var fails: Array = []
	g.sfx.muted = true
	var saved_auto: bool = g.AUTO
	var nm: String = g.lead_name()
	var cid: String = g.equipped_class_ab(nm)
	var sid: String = g.equipped_sub_ab(nm)
	# sequence: an "always" rule on a slotted ability is what AUTO fires
	g.AB_SEQ[nm] = [[sid, "always"], [cid, "always"]]
	if g.seq_of(nm)[0][0] != sid: fails.append("seq set")
	# loadout = unlocked class abilities + unlocked subclass abilities (2 + 2 at full unlock)
	if g.loadout_of(nm).find(sid) < 0 or str(g.ABILITY_DEFS[sid].src) != "sub": fails.append("sub ability in loadout")
	var cls0: String = str(g.CHAR[nm].cls)
	var sub0: String = str(g.CHAR[nm].sub)
	g.set_sub(nm, cls0)
	if str(g.CHAR[nm].sub) != sub0: fails.append("sub may not equal class")
	g.set_class(nm, sub0)
	if str(g.CHAR[nm].cls) != sub0 or str(g.CHAR[nm].sub) != cls0: fails.append("class/sub swap")
	g.set_class(nm, cls0)
	if str(g.CHAR[nm].cls) != cls0 or str(g.CHAR[nm].sub) != sub0: fails.append("swap back")
	g.AB_SEQ[nm] = [[sid, "always"], [cid, "always"]]
	g.AB_SEQ[nm] = [[cid, "always"]]
	# MP carry: set HERO_MP and start a fight
	for h in g.HERO_NAMES: g.HERO_MP[h] = 37.0
	g.HERO_MP[nm] = 100.0
	g.AUTO = false
	g.start_fight(3)
	for u in g.G.units:
		# party turn regen may already be applied on top of the carried bar
		var base := 100.0 if u.name == nm else 37.0
		if u.team == "blue" and absf(u.gauge - base) > 0.01 and absf(u.gauge - minf(100.0, base + float(u.mana_regen))) > 0.01: fails.append("start mp " + u.name + " " + str(u.gauge))
	# AUTO turn
	g.AUTO = true
	g.step(17)
	var lead_u = null
	for u in g.G.units:
		if u.team == "blue" and u.name == nm: lead_u = u
	# team turns: AUTO skips target select and the whole party strikes (scripts/combo_turn.gd)
	if g.G.mode == "select": fails.append("auto did not execute")
	if g.G.turnc == null or g.G.turnc.strikes.size() != g.alive("blue").size(): fails.append("whole party should strike")
	var cast := false
	var guard := 0
	while guard < 4000 and g.phase == "battle" and not cast:
		g.step(17); guard += 1
		if lead_u.gauge < 50.0: cast = true
	if not cast: fails.append("auto ability not cast (gauge %d)" % int(lead_u.gauge))
	# set a mid MP, run, check carry
	g.AUTO = false
	while g.phase == "battle" and g.G.mode != "select" and guard < 3000:
		g.step(17); guard += 1
	lead_u.gauge = 64.0
	g.run_battle()
	if absf(float(g.HERO_MP[nm]) - 64.0) > 0.01: fails.append("run carry " + str(g.HERO_MP[nm]))
	var cf := ConfigFile.new(); cf.load("user://airrons_quest.cfg")
	if int(cf.get_value("mp", nm, -1)) != 64: fails.append("saved mp " + str(cf.get_value("mp", nm, -1)))
	g.start_fight(2)
	for u in g.G.units:
		if u.team == "blue" and u.name == nm and absf(u.gauge - 64.0) > 0.01 and absf(u.gauge - minf(100.0, 64.0 + float(u.mana_regen))) > 0.01: fails.append("next fight mp " + str(u.gauge))
	# no ability marked: full MP, AUTO -> basic attack, MP not spent by ability
	g.run_battle()
	g.AB_SEQ[nm] = [[cid, "boss"]]
	g.HERO_MP[nm] = 100.0
	g.start_fight(3)
	g.AUTO = true
	g.step(17)
	for u in g.G.units:
		if u.team == "blue" and u.name == nm and u.ab_queued != "": fails.append("no-auto queued ability")
	g.AUTO = false
	g.run_battle()
	# swapping the marked ability clears it
	g.AB_AUTO[nm] = cid
	var others: Array = g.unlocked_class_ids(nm)
	if others.size() > 1:
		var other: String = others[1] if others[0] == cid else others[0]
		g.equip_ability(nm, other)
		if g.auto_ab(nm) != "": fails.append("swap did not clear auto")
		g.equip_ability(nm, cid)
	g.AB_AUTO[nm] = cid
	g.AUTO = saved_auto
	g.save_cfg()
	print("AUTO_MP_TEST ", "PASS" if fails.is_empty() else "FAIL " + str(fails))
	quit()
