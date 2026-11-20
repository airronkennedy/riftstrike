extends SceneTree
## Class / subclass EXP and levels + a balance sweep (docs/BALANCE.md).
##   godot --headless --path . --script res://tools/test_progression.gd -- --n=8
## Checks the curve math, EXP grant + level-up, save/load through user://kingdom.cfg, elites in high regions,
## then simulates AUTO region battles at several party levels and prints win rate, battle length and EXP.
var fails := 0
func ok(c: bool, m: String) -> void:
	print(("ok   " if c else "FAIL ") + m)
	if not c: fails += 1
func _init() -> void:
	_run.call_deferred()
func _run() -> void:
	var n := 8
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--n="): n = int(a.substr(4))
	var Q = load("res://scripts/quest_rpg.gd")
	ok(Q.xp_floor(10) == 10520, "Lv10 needs 10520 EXP (%d)" % Q.xp_floor(10))
	ok(Q.level_for_xp(0) == 1 and Q.level_for_xp(284) == 1 and Q.level_for_xp(285) == 2 and Q.level_for_xp(99999) == 10, "level_for_xp edges")
	ok(Q.CLASS_ORDER.size() >= 10, "%d classes" % Q.CLASS_ORDER.size())
	for c in Q.CLASS_ORDER:
		ok(Q.CLASSES[c].abilities.size() == 2 and Q.CLASSES[c].sub_abilities.size() == 2, c + ": 2 class + 2 subclass abilities")
	change_scene_to_file("res://main.tscn")
	await create_timer(0.6).timeout
	var g = current_scene
	g.sfx.muted = true
	var qf = root.get_node("QuestFlow")
	if FileAccess.file_exists("user://kingdom.cfg"): DirAccess.remove_absolute(ProjectSettings.globalize_path("user://kingdom.cfg"))
	g.CLASS_XP = {}; g.SUB_XP = {}
	var nm: String = g.lead_name()
	var cls: String = str(g.CHAR[nm].cls)
	var sub: String = str(g.CHAR[nm].sub)
	ok(g.hero_level(nm) == 1 and g.loadout_of(nm).size() == 2, "fresh keeper: Lv1, 2 abilities unlocked")
	var up: int = g.grant_hero_xp(nm, 1420)
	ok(up == 3 and g.hero_level(nm) == 4, "1420 EXP -> class Lv4 (%d)" % g.hero_level(nm))
	ok(g.sub_level(nm, sub) == 3, "subclass got half -> sub Lv3 (%d)" % g.sub_level(nm, sub))
	ok(g.loadout_of(nm).size() == 4, "Lv4 class + Lv3 sub: all 4 abilities")
	g.grant_hero_xp(nm, 999999)
	ok(g.hero_level(nm) == 10 and g.hero_xp(nm) == 0, "caps at Lv10")
	g.save_cfg()
	g.CLASS_XP = {}; g.SUB_XP = {}
	g.load_class_xp()
	ok(g.hero_level(nm) == 10 and g.sub_level(nm, sub) >= 3, "class EXP reloads from kingdom.cfg")
	var cf := ConfigFile.new(); cf.load("user://kingdom.cfg")
	ok(cf.has_section("class_xp"), "kingdom.cfg has class_xp")
	# a new class starts at Lv1; its own EXP track
	var other: String = Q.CLASS_ORDER[(Q.CLASS_ORDER.find(cls) + 3) % Q.CLASS_ORDER.size()]
	if other == sub: other = Q.CLASS_ORDER[(Q.CLASS_ORDER.find(cls) + 4) % Q.CLASS_ORDER.size()]
	g.set_class(nm, other)
	ok(g.hero_level(nm) == 1, "switching class: that class is Lv1")
	g.set_class(nm, cls)
	# elites only in higher regions
	var el := {"meadow": 0, "highlands": 0}
	for i in 400:
		for r in el.keys():
			if qf.encounter_for(r).elite: el[r] += 1
	ok(el.meadow == 0 and el.highlands > 50 and el.highlands < 150, "elites: meadow %d/400, highlands %d/400" % [el.meadow, el.highlands])
	# ---- balance sweep: party at level L vs region foes at level L (AUTO, 1x time)
	print("\nlevel  region     win%   avg battle s   EXP/keeper   battles to next")
	var regions := {1: "meadow", 3: "road", 5: "forest", 7: "shore", 9: "highlands"}
	for L in [1, 3, 5, 7, 9]:
		var wins := 0
		var secs := 0.0
		var xp := 0.0
		for i in n:
			g.CLASS_XP = {}; g.SUB_XP = {}
			for h in g.party_names():
				g.set_hero_level(h, L)
				g.SUB_XP[h] = {str(g.CHAR[h].sub): Q.xp_floor(L)}
				g.HERO_MP[h] = 0.0
			qf.in_kingdom_battle = true
			var e: Dictionary = qf.encounter_for(regions[L])
			e.level = L; e.mult = qf.foe_mult(L)
			g.encounter = e
			g.new_battle(3)
			g.phase = "battle"; g.screen = ""; g.AUTO = true
			g.begin_timeline()
			var guard := 0
			while g.phase == "battle" and guard < 40000:
				g.step(17); guard += 1
			while g.phase == "ending" and guard < 60000:
				g.step(17); guard += 1
			if g.G.result == "win": wins += 1
			secs += g.G.t / 1000.0
			var gs: Dictionary = g.last_xp_gains
			var tot := 0.0
			for k in gs: tot += float(gs[k])
			xp += tot / maxf(1.0, float(gs.size()))
		var per := xp / n
		var need: int = Q.XP_TO_NEXT[mini(L - 1, 8)]
		print("%5d  %-9s  %4d%%   %8.1f      %8.1f      %6.1f" % [L, regions[L], int(100.0 * wins / n), secs / n, per, need / maxf(1.0, per)])
		ok(wins >= int(n * 0.6), "Lv%d party wins most on-level fights (%d/%d)" % [L, wins, n])
	qf.in_kingdom_battle = false
	g.CLASS_XP = {}; g.SUB_XP = {}
	if FileAccess.file_exists("user://kingdom.cfg"): DirAccess.remove_absolute(ProjectSettings.globalize_path("user://kingdom.cfg"))
	print("PROGRESSION ", "PASS" if fails == 0 else "FAIL %d" % fails)
	quit()
