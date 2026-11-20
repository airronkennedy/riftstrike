extends SceneTree
## Target select before each party turn (scripts/target_select.gd, game.gd bf_select / bf_launch).
##   godot --headless --path . --script res://tools/test_target_select.gd
## No command menu; the window auto-continues; a tap focuses the team and sticks until that foe dies; the Auto target
## setting picks the right foe; party_select_started / party_target_locked fire before the attack sequence runs;
## encounter.tiers / foe_ids build mini-boss and boss fights (story hooks).
var fails := 0
func ok(c: bool, m: String) -> void:
	print(("ok   " if c else "FAIL ") + m)
	if not c: fails += 1
var events: Array = []
func _init() -> void:
	preload("res://tools/test_save.gd").fresh() # new-game user data every run
	_run.call_deferred()
func run_until(g, cond: Callable, max_ms: float) -> float:
	var t := 0.0
	while t < max_ms and not cond.call():
		g.step(17); t += 17.0
	return t
func _run() -> void:
	var keep_mode := TargetSelect.mode()
	change_scene_to_file("res://main.tscn")
	await create_timer(0.6).timeout
	var g = current_scene
	g.sfx.muted = true
	var qf = root.get_node("QuestFlow")
	g.party_select_started.connect(func(turn): events.append(["select", turn, g.G.turnc.running]))
	g.party_target_locked.connect(func(f): events.append(["locked", f, g.G.turnc.running]))
	# ---- a region fight with the window on (AUTO off)
	qf.in_kingdom_battle = true
	g.encounter = qf.encounter_for("forest", 3)
	g.new_battle(3)
	g.phase = "battle"; g.screen = ""; g.AUTO = false; g.paused = false
	g.begin_timeline()
	ok(g.G.bf and g.G.mode == "select", "battle opens on target select")
	ok(not ("cmd" in g.G) and not g.has_method("cmd_attack") and not g.has_method("manual_execute"), "no turn-based command menu left")
	ok(events.size() == 1 and events[0][0] == "select" and events[0][1] == 1, "party_select_started(1) fired")
	# auto-continue: nobody taps -> the team attacks once the countdown runs out
	var waited := run_until(g, func(): return g.G.mode != "select", 10000.0)
	ok(g.G.mode == "strike" and absf(waited - g.SELECT_MS) < 120.0, "auto-continues after %.0f ms (SELECT_MS %.0f)" % [waited, g.SELECT_MS])
	ok(events.size() == 2 and events[1][0] == "locked" and events[1][1] != null and not events[1][2], "party_target_locked(focus) fires before the attack sequence")
	ok(g.G.turnc.running and g.G.turnc.team == "blue", "combo attack sequence runs after targeting")
	ok(not g.G.focus_tapped, "untapped focus came from the Auto target setting")
	# next party turn: tap a foe
	run_until(g, func(): return g.G.mode == "select" or g.phase != "battle", 30000.0)
	ok(g.G.mode == "select" and g.G.turn == 2, "turn 2 target select")
	var foes: Array = g.alive("red")
	var pick = foes[foes.size() - 1]
	var ev0 := events.size()
	g.bf_focus(pick)
	ok(g.G.focus == pick and g.G.focus_tapped and g.G.mode == "strike", "tap focuses the team and attacks at once")
	ok(events.size() == ev0 + 1 and events[ev0][1] == pick, "locked on the tapped foe")
	# the tapped focus sticks into the next turn while it lives
	run_until(g, func(): return g.G.mode == "select" or g.phase != "battle", 30000.0)
	if g.phase == "battle" and not pick.dead:
		ok(g.G.focus == pick, "tapped focus kept next turn")
	elif g.phase == "battle":
		ok(g.G.focus == null, "dead focus cleared")
	# AUTO skips the window entirely
	g.AUTO = true
	if g.G.mode == "select":
		g.step(17)
		ok(g.G.mode == "strike", "AUTO skips target select")
	# a whole fight with AUTO never stalls
	run_until(g, func(): return g.phase != "battle", 120000.0)
	ok(g.phase != "battle", "AUTO fight finishes (%s)" % g.phase)
	# ---- the setting picks the right foe
	g.encounter = qf.encounter_for("highlands", 6)
	g.encounter.elite = true
	g.new_battle(3)
	g.phase = "battle"; g.AUTO = false
	g.begin_timeline()
	var fs: Array = g.alive("red")
	fs[1].hp = 5
	TargetSelect.set_mode("weakest")
	ok(g.bf_auto_target() == fs[1], "Finish Off: least HP left")
	TargetSelect.set_mode("threat")
	var hi = fs[0]
	for f in fs:
		if f.atk > hi.atk: hi = f
	ok(g.bf_auto_target() == hi, "Biggest Threat: highest ATK")
	TargetSelect.set_mode("elite")
	ok(str(g.bf_auto_target().tier) == "elite", "Elites First: the elite")
	TargetSelect.set_mode("backline")
	var bl = g.bf_auto_target()
	var has_ranged := false
	for f in fs:
		if str(f.K.get("ranged", "")) != "": has_ranged = true
	ok(not has_ranged or str(bl.K.get("ranged", "")) != "", "Backline First: a ranged foe when there is one")
	TargetSelect.set_mode("threat")
	TargetSelect._mode = ""
	ok(TargetSelect.mode() == "threat", "setting saved in user://targeting.cfg")
	ok(TargetSelect.cycle() == "elite" and TargetSelect.label() == "Elites First", "menu cycles the setting")
	# ---- story hooks: encounter.tiers / foe_ids make a mini-boss or a final boss
	var e2: Dictionary = qf.encounter_for("highlands", 6)
	e2.kinds = ["barrel", "torch"]; e2.elite = false
	e2.tiers = ["boss", "regular"]; e2.foe_ids = ["matron", ""]
	g.encounter = e2
	g.new_battle(3)
	var reds: Array = g.alive("red")
	ok(reds.size() == 2 and str(reds[0].tier) == "boss" and str(reds[1].tier) == "regular", "encounter.tiers sets a boss")
	ok(str(reds[0].name) == "Matron of Cinders", "encounter.foe_ids picks the boss art/name (%s)" % reds[0].name)
	ok(reds[0].maxhp > reds[1].maxhp * 1.5, "boss HP well above its escort (%d vs %d)" % [reds[0].maxhp, reds[1].maxhp])
	e2 = qf.encounter_for("forest", 4)
	e2.tiers = ["miniboss"]; e2.elite = false
	g.encounter = e2
	g.new_battle(3)
	ok(str(g.alive("red")[0].tier) == "miniboss", "encounter.tiers sets a mini-boss")
	var QR = load("res://scripts/quest_rpg.gd")
	ok(QR.foe_xp("boss", 5) > QR.foe_xp("miniboss", 5) and QR.foe_xp("miniboss", 5) > QR.foe_xp("elite", 5), "boss > mini-boss > elite EXP")
	TargetSelect.set_mode(keep_mode)
	qf.in_kingdom_battle = false
	print("TARGET_SELECT ", "PASS" if fails == 0 else "FAIL %d" % fails)
	quit(1 if fails > 0 else 0)
