extends SceneTree
# Combat regression checks (logic only, no screenshots). Use a private save dir:
#   XDG_DATA_HOME=/tmp/combat-xdg godot --headless --path . --script res://tools/test_combat.gd
var g
var fails: Array = []
func _init() -> void:
	g = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(g)
	_run()

func setup_party(lv: int) -> void:
	for h in g.HERO_NAMES:
		g.HERO_PROG[h] = {"level": lv, "xp": 0}; g.HERO_MP[h] = 0.0
		g.AB_EQUIP.erase(h); g.AB_AUTO.erase(h); g.validate_ab_equip(h)

func run_until(cond: Callable, limit := 6000) -> int:
	var i := 0
	while i < limit and not cond.call():
		g.step(17); i += 1
	return i

func _run() -> void:
	await create_timer(0.3).timeout
	g.sfx.muted = true
	g.encounter = {}
	setup_party(1)
	t_ranged_single_action()
	t_ability_not_combo()
	t_debuff_duration()
	t_armor_floor()
	t_boss_two_actions()
	t_auto_heal_hold()
	t_sim_no_stuck()
	print("COMBAT_TEST ", "PASS" if fails.is_empty() else "FAIL " + str(fails))
	quit()

## A ranged enemy fires once per normal attack, even when its target is inside melee follow-up range.
func t_ranged_single_action() -> void:
	for trial in 6:
		g.new_battle(1); g.phase = "battle"; g.begin_player_turn()
		var boss = g.alive("red")[0]
		boss.gauge = 0.0
		var front = null
		for u in g.alive("blue"):
			if front == null or absf(u.x - boss.x) < absf(front.x - boss.x): front = u
		g.combat_trace = []
		g.G.queue = []
		g.begin_enemy_turn()
		for u in g.G.queue: if u.plan != null: u.plan.target = front
		var acts := {}
		run_until(func():
			for u in g.G.units:
				if u.team == "red" and u.act != null: acts[u.act] = true
			return g.G.side == "blue" or g.phase != "battle")
		var hits := 0
		for e in g.combat_trace:
			if e.src == boss.name and not e.splash: hits += 1
		if hits != acts.size():
			fails.append("ranged boss: %d hits from %d actions" % [hits, acts.size()]); return
	g.combat_trace = null

## Damage abilities land as their own hit (ab flag), never folded into a COMBO.
func t_ability_not_combo() -> void:
	var casts := 0
	var ab_hits := 0
	for trial in 8:
		g.new_battle(1); g.phase = "battle"; g.begin_player_turn()
		g.combat_trace = []
		var dmg_ab := {}
		for u in g.alive("blue"):
			u.gauge = 100.0
			if str(g.ABILITY_DEFS[u.ab_class].kind) == "damage_single":
				g.queue_ability(u, u.ab_class); dmg_ab[u.name] = true; casts += 1
			else:
				g.toggle_queue(u)
		g.execute_orders()
		run_until(func(): return g.G.side == "red" or g.phase != "battle")
		for e in g.combat_trace:
			if e.ab and dmg_ab.has(e.src): ab_hits += 1
			if e.combo and e.ab: fails.append("ability hit inside combo")
	if ab_hits < casts: fails.append("ability hits %d < casts %d" % [ab_hits, casts])
	g.combat_trace = null

## A 2-turn debuff on a foe covers two of the foe's turns.
func t_debuff_duration() -> void:
	g.new_battle(3); g.phase = "battle"; g.begin_player_turn()
	var e = g.alive("red")[0]
	var base: int = e.atk
	g.add_mod(e, "atk", -12, 2)
	var seen: Array = []
	for k in 3:
		g.begin_enemy_turn(); seen.append(e.atk)
		g.begin_player_turn()
	if not (seen[0] < base and seen[1] < base and seen[2] == base):
		fails.append("debuff turns base=%d seen=%s" % [base, str(seen)])
	# A self buff still covers two enemy turns.
	var h = g.alive("blue")[0]
	var hb: int = h.def
	g.add_mod(h, "def", 20, 2)
	var hs: Array = []
	for k in 3:
		g.begin_enemy_turn(); hs.append(h.def)
		g.begin_player_turn()
	if not (hs[0] > hb and hs[1] > hb and hs[2] == hb):
		fails.append("buff turns base=%d seen=%s" % [hb, str(hs)])

## Armor can blunt a hit but not erase it.
func t_armor_floor() -> void:
	g.new_battle(3)
	var t = g.alive("red")[0]
	t.def = 1; t.armor = 999
	var d: int = g.mitigate_raw(100.0, t)
	if d < 20: fails.append("armor floor dmg %d" % d)

## Raid boss acts twice per enemy turn, one action after the other.
func t_boss_two_actions() -> void:
	g.new_battle(1); g.phase = "battle"; g.begin_player_turn()
	var boss = g.alive("red")[0]
	boss.gauge = 0.0
	g.begin_enemy_turn()
	var acts := {}
	var overlap := false
	var prev = null
	run_until(func():
		if boss.act != null:
			if prev != null and boss.act != prev and acts.has(prev) and prev.stage != "done":
				pass
			acts[boss.act] = true; prev = boss.act
		return g.G.side == "blue" or g.phase != "battle")
	if g.phase == "battle" and acts.size() != 2: fails.append("boss actions %d" % acts.size())

## AUTO keeps a heal ability banked while nobody is hurt.
func t_auto_heal_hold() -> void:
	setup_party(31)
	var nm := "Lanning"
	g.AB_EQUIP[nm].cls = "rallying_stand"
	g.AB_AUTO[nm] = "rallying_stand"
	g.new_battle(3); g.phase = "battle"; g.begin_player_turn()
	var ln = null
	for u in g.alive("blue"):
		if u.name == nm: ln = u
	if ln == null: return
	ln.ab_class = "rallying_stand"
	ln.gauge = 100.0
	g.AUTO = true
	g.auto_queue_turn()
	if ln.ab_queued != "": fails.append("auto healed at full HP")
	g.AUTO = false
	setup_party(1)

func t_sim_no_stuck() -> void:
	g.AUTO = true
	for k in 30:
		g.new_battle((k % 3) + 1); g.phase = "battle"; g.begin_player_turn()
		var n := run_until(func(): return g.phase != "battle", 90000)
		if g.phase == "battle": fails.append("stuck in mode %d turn %d" % [(k % 3) + 1, g.G.turn])
		g.phase = "title"
	g.AUTO = false
