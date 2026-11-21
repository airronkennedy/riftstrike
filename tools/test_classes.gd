extends SceneTree
## Classes, divination, signatures and auto-cast tactics (docs/CLASSES.md).
##   XDG_DATA_HOME=$(mktemp -d) godot --headless --path . --script res://tools/test_classes.gd
const Diviner = preload("res://scripts/classes/diviner.gd")
const Signatures = preload("res://scripts/classes/signatures.gd")
const Tactics = preload("res://scripts/classes/tactics.gd")
const QuestRPG = preload("res://scripts/quest_rpg.gd")
var g
var fails := 0

func _init() -> void:
	preload("res://tools/test_save.gd").fresh()
	g = load("res://main.tscn").instantiate()
	root.add_child(g)
	_run()

func ok(c: bool, what: String) -> void:
	print(("ok   " if c else "FAIL ") + what)
	if not c: fails += 1

func wait(ms: float) -> void:
	await create_timer(ms / 1000.0).timeout

func unit(nm: String):
	for u in g.alive("blue"):
		if u.name == nm: return u
	return null

func _run() -> void:
	await wait(300)
	g.sfx.muted = true
	var st = root.get_node("Story")
	var nm := "Bramwell" if g.CHAR.has("Bramwell") else str(g.HERO_NAMES[0])
	ok(g.HERO_NAMES.size() >= 1, "keepers loaded (%s)" % ", ".join(g.HERO_NAMES))
	# ---------------------------------------------------------- 1. per-class levels (DQ9)
	g.CLASS_XP = {}; g.SUB_XP = {}
	var c0: String = str(g.CHAR[nm].cls)
	var s0: String = str(g.CHAR[nm].sub)
	g.grant_hero_xp(nm, QuestRPG.xp_floor(5))
	ok(g.class_level(nm, c0) == 5, "%s %s Lv5 after EXP" % [nm, c0])
	var sub_before: int = g.sub_level(nm, s0)
	var new_c := "Mage" if c0 != "Mage" and s0 != "Mage" else "Monk"
	ok(Diviner.start_level(g, nm) == 3, "a new calling starts at half the best level, rounded up (Lv%d)" % Diviner.start_level(g, nm))
	var r: Dictionary = Diviner.divine(g, nm, new_c, "class")
	ok(r.ok and str(g.CHAR[nm].cls) == new_c and g.hero_level(nm) == 3 and r.fresh, "divine %s -> %s Lv3, a new calling" % [nm, new_c])
	ok(g.class_level(nm, c0) == 5, "the old class keeps Lv5")
	g.grant_hero_xp(nm, 300)
	var mage_lv: int = g.class_level(nm, new_c)
	r = Diviner.divine(g, nm, c0, "class")
	ok(r.ok and not r.fresh and g.hero_level(nm) == 5, "switching back resumes %s Lv5" % c0)
	ok(g.class_level(nm, new_c) == mage_lv, "and %s keeps its level for later (Lv%d)" % [new_c, mage_lv])
	ok(g.sub_level(nm, s0) >= sub_before, "subclass untouched by a class change")
	# ---------------------------------------------------------- 2. subclasses keep their own level too
	var sub_new := "Bard" if c0 != "Bard" and s0 != "Bard" else "Ranger"
	r = Diviner.divine(g, nm, sub_new, "sub")
	ok(r.ok and str(g.CHAR[nm].sub) == sub_new and g.sub_level(nm, sub_new) == Diviner.start_level(g, nm), "new subclass %s starts at Lv%d" % [sub_new, Diviner.start_level(g, nm)])
	var s0_lv: int = g.sub_level(nm, s0)
	r = Diviner.divine(g, nm, s0, "sub")
	ok(r.ok and g.sub_level(nm, s0) == s0_lv, "the old subclass resumes at Lv%d" % s0_lv)
	# swap: the subclass picked as the class
	r = Diviner.divine(g, nm, s0, "class")
	ok(r.ok and r.swapped and str(g.CHAR[nm].cls) == s0 and str(g.CHAR[nm].sub) == c0, "picking the subclass as class swaps them (%s / %s)" % [g.CHAR[nm].cls, g.CHAR[nm].sub])
	ok(g.sub_level(nm, c0) >= 1 and g.class_level(nm, c0) == 5, "after the swap both books are kept")
	Diviner.divine(g, nm, c0, "class") # back to the start: class c0, sub s0
	ok(str(g.CHAR[nm].cls) == c0 and str(g.CHAR[nm].sub) == s0, "swap back restores %s / %s" % [c0, s0])
	# ---------------------------------------------------------- 3. unlocks
	ok(Diviner.unlocked(self, "Warlock") and Diviner.unlocked(self, "Bard"), "outside story play every calling is open")
	st.started = true
	st.flags.clear()
	ok(not Diviner.unlocked(self, "Warlock") and not Diviner.unlocked(self, "Bard") and Diviner.unlocked(self, "Mage"), "story: Warlock and Bard wait, the eight core callings are open")
	st.flags["sq_bell_done"] = true
	ok(Diviner.unlocked(self, "Bard") and not Diviner.unlocked(self, "Warlock"), "the Quiet Bell opens Bard")
	st.flags["s_kindling"] = true
	ok(Diviner.unlocked(self, "Warlock"), "Kindling Night opens Warlock")
	st.started = false; st.flags.clear()
	# ---------------------------------------------------------- 4. Attack Order timings
	g.HERO_ORDER = []; g.HERO_DELAY = {}
	r = Diviner.divine(g, nm, new_c, "class")
	ok(bool(r.timing.auto), "untouched Build: the suggested order adapts by itself")
	var party: Array = g.party_names()
	if party.size() >= 2:
		var o: Array = party.duplicate(); o.reverse()
		g.set_attack_order(o)
		for p in o: g.HERO_DELAY[p] = 0.0
		r = Diviner.divine(g, nm, c0, "class")
		ok(not bool(r.timing.auto) and g.attack_order() == o, "hand-set order kept after a class change")
		ok(float(r.timing.after) + 0.03 >= float(r.timing.before), "re-tuned delays spark at least as well (%.2f -> %.2f)" % [float(r.timing.before), float(r.timing.after)])
		var ok_d := true
		for p in o: ok_d = ok_d and g.HERO_DELAY.has(p) and float(g.HERO_DELAY[p]) >= 0.0 and float(g.HERO_DELAY[p]) <= 500.0
		ok(ok_d, "delays re-written for every keeper in the order")
		g.HERO_ORDER = []; g.HERO_DELAY = {}
	else:
		Diviner.divine(g, nm, c0, "class")
	# ---------------------------------------------------------- 5. signatures
	for h in ["Bramwell", "Grieve", "Halvard", "Corvin", "Ilsabet"]:
		if not g.CHAR.has(h): continue
		var sid := Signatures.id_for(g, h)
		ok(sid != "" and g.ABILITY_DEFS.has(sid) and g.ABILITY_DEFS.has(sid + "_x"), "%s has a signature (%s) and its empowered twin" % [h, sid])
		ok(g.seq_of(h).any(func(rr): return str(rr[0]) == sid), "%s's default tactics include it" % h)
		ok(not g.loadout_of(h).has(sid) and g.loadout_of(h).size() <= 4, "%s: the signature rides on top of class 2 + subclass 2" % h)
	# ---------------------------------------------------------- 6. tactics in battle
	g.CLASS_XP[nm][str(g.CHAR[nm].cls)] = QuestRPG.xp_floor(5)
	var sig := Signatures.id_for(g, nm)
	g.AB_SEQ[nm] = [[sig, "always"]]
	g.new_battle(3); g.phase = "battle"; g.begin_player_turn()
	var u = unit(nm)
	ok(u != null, "lead in battle")
	if u != null:
		u.gauge = 100.0
		var pick: String = g.seq_pick(u)
		ok(pick.begins_with(sig), "an 'always' rule fires the signature (%s)" % pick)
		ok(g.seq_pick(u) != pick or pick == "", "a signature fires once per battle")
		u.remove_meta("sig_used")
		Tactics.set_off(g, nm, sig, true)
		ok(g.seq_pick(u) == "", "auto-cast OFF: never fires")
		Tactics.set_off(g, nm, sig, false)
		# empowered by class
		if Signatures.ROWS.has(nm) and Signatures.ROWS[nm].has("classes"):
			var want: String = Signatures.ROWS[nm].classes[0]
			g.set_class(nm, want); g.CLASS_XP[nm][want] = QuestRPG.xp_floor(5)
			g.AB_SEQ[nm] = [[sig, "always"]]
			u.remove_meta("sig_used")
			ok(g.seq_pick(u) == sig + "_x", "as a %s the signature is EMPOWERED" % want)
			g.set_class(nm, c0)
		# hold rule
		u.remove_meta("sig_used")
		g.AB_SEQ[nm] = [[Tactics.HOLD, "always"], [sig, "always"]]
		ok(g.seq_pick(u) == "", "'Save Brave Burst' holds the gauge when its condition passes")
		g.AB_SEQ[nm] = [[Tactics.HOLD, "boss"], [sig, "always"]]
		var has_boss: bool = g.seq_condition_ok(u, "boss")
		ok(g.seq_pick(u).begins_with(sig) != has_boss, "hold-on-boss only holds when a boss/elite is here")
		# new conditions
		for a in g.alive("blue"): a.hp = a.maxhp
		ok(not g.seq_condition_ok(u, "ally_40"), "ally < 40%: false at full HP")
		u.hp = int(u.maxhp * 0.3)
		ok(g.seq_condition_ok(u, "ally_40"), "ally < 40%: true when someone is low")
		u.hp = u.maxhp
		g.G.summary = {"sparks": 3}
		ok(g.seq_condition_ok(u, "combo_3"), "combo 3+: true after a 3-spark turn")
		g.G.summary = {"sparks": 1}
		ok(not g.seq_condition_ok(u, "combo_3"), "combo 3+: false after a 1-spark turn")
		ok(g.seq_condition_ok(u, "turn_1") == (g.G.turn <= 1), "battle start")
	# ---------------------------------------------------------- 7. save / load
	g.AB_SEQ[nm] = [[Tactics.HOLD, "no_boss"], [sig, "boss"]]
	Tactics.set_off(g, nm, str(g.class_ability_ids(nm)[0]), true)
	g.save_cfg()
	g.AB_SEQ = {}; g.AB_OFF = {}
	g.load_cfg()
	ok(str(g.seq_of(nm)[0][0]) == Tactics.HOLD and str(g.seq_of(nm)[0][1]) == "no_boss", "tactics rules saved and loaded")
	ok(Tactics.is_off(g, nm, str(g.class_ability_ids(nm)[0])), "auto-cast toggles saved and loaded")
	# migration: a plan saved before signatures gets the signature on top once
	g.SIG_SEEN.erase(nm)
	g.AB_SEQ[nm] = [[str(g.class_ability_ids(nm)[0]), "always"]]
	Tactics.migrate(g, nm)
	ok(str(g.AB_SEQ[nm][0][0]) == sig, "old saves: the signature rule is added on top once")
	g.AB_SEQ.erase(nm); g.AB_OFF.erase(nm); g.seq_of(nm)
	# ---------------------------------------------------------- 8. the divination screen
	g.phase = "title"
	g.open_diviner(true)
	await wait(200)
	var ui = g.diviner_ui
	ok(ui != null and ui.step == "hero", "divination screen opens on the keepers")
	var hb = ui.content.find_child("hero_" + nm, true, false)
	ok(hb != null, "a card per keeper")
	if hb != null: hb.pressed.emit()
	await wait(100)
	ok(ui.step == "list" and ui.hero == nm, "tap a keeper -> the callings")
	var rows := 0
	for cls in QuestRPG.CLASS_ORDER:
		if ui.content.find_child("cls_" + cls, true, false) != null: rows += 1
	ok(rows == 10, "all 10 callings listed (%d)" % rows)
	var cur_btn = ui.content.find_child("cls_" + str(g.CHAR[nm].cls), true, false)
	ok(cur_btn != null and cur_btn.disabled, "the current class can't be picked again")
	var target := "Cleric" if str(g.CHAR[nm].cls) != "Cleric" and str(g.CHAR[nm].sub) != "Cleric" else "Monk"
	var tb = ui.content.find_child("cls_" + target, true, false)
	tb.pressed.emit()
	await wait(100)
	ok(ui.step == "confirm", "pick -> confirm")
	var go = ui.content.find_child("divine", true, false)
	go.pressed.emit()
	await wait(400)
	ok(ui.step == "reveal" and str(g.CHAR[nm].cls) == target, "the ritual reveals %s the %s" % [nm, target])
	ok(ui.content.find_child("reveal", true, false) != null, "reveal card shown")
	# keyboard / pad: ui_cancel steps back
	var ev := InputEventAction.new(); ev.action = "ui_cancel"; ev.pressed = true
	ui._show("list"); await wait(50)
	ui._unhandled_input(ev); await wait(50)
	ok(ui.step == "hero", "ui_cancel (Esc / B) goes back a step")
	ok(root.gui_get_focus_owner() != null, "a button has focus for keyboard / gamepad")
	# portrait phone layout
	root.size = Vector2i(430, 930)
	await wait(100)
	ok(ui.portrait, "portrait layout on a phone-shaped window")
	ui.hero = nm; ui._show("list"); await wait(100)
	var row = ui.content.find_child("cls_Warrior", true, false)
	ok(row != null and row.size.x <= 430.0 / ui.s + 1.0, "rows fit the phone width")
	root.size = Vector2i(1024, 576)
	Diviner.divine(g, nm, c0, "class")
	print("CLASSES ", "PASS" if fails == 0 else "FAIL %d" % fails)
	quit()
