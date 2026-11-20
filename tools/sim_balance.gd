extends SceneTree
## Balance sweep for auto-levelled wild fights (docs/BALANCE.md).
##   godot --headless --path . -s res://tools/sim_balance.gd -- --n=40 [--seed=1] [--hp=1.0] [--levels=1,5,10] [--chain] [--mode=weakest|threat|elite|backline]
##   [--tiers=miniboss,regular] story fight at exactly the party level  [--region=forest]
## For each party level L: n AUTO fights (target select skipped, 1x time) against the region foes for L, levelled by
## QuestRPG.foe_level(L). Prints win rate, party HP left, fight length, team turns, EXP per keeper, fights to next level,
## and the hours-to-Lv10 estimate from QuestRPG.LOOP_OVERHEAD_S / SELECT_S. --hp starts the party at that HP share.
## --chain plays the n fights back to back like the kingdom does: HP carries over through QuestRPG.hp_after_battle
## and a loss sends the party to the inn (full HP for the next fight).
const REGIONS := {1: "meadow", 2: "road", 3: "road", 4: "forest", 5: "forest", 6: "shore", 7: "shore", 8: "highlands", 9: "highlands", 10: "highlands"}

func _init() -> void:
	preload("res://tools/test_save.gd").fresh() # new-game user data every run
	_run.call_deferred()

func _run() -> void:
	var n := 40
	var hp0 := 1.0
	var chain := false
	var tiers: Array = []
	var region := ""
	var levels: Array = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--n="): n = int(a.substr(4))
		elif a.begins_with("--seed="): seed(int(a.substr(7)))
		elif a.begins_with("--hp="): hp0 = float(a.substr(5))
		elif a == "--chain": chain = true
		elif a.begins_with("--tiers="): tiers = Array(a.substr(8).split(",")) # story fight, e.g. --tiers=boss,regular
		elif a.begins_with("--region="): region = a.substr(9)
		elif a.begins_with("--mode="): TargetSelect._mode = a.substr(7) # Auto target setting for this run (not saved)
		elif a.begins_with("--levels="):
			levels = []
			for s in a.substr(9).split(","): levels.append(int(s))
	var Q = load("res://scripts/quest_rpg.gd")
	change_scene_to_file("res://main.tscn")
	await create_timer(0.6).timeout
	var g = current_scene
	g.sfx.muted = true
	var qf = root.get_node("QuestFlow")
	var save_cfg: String = ProjectSettings.globalize_path("user://kingdom.cfg")
	print("party: ", ", ".join(g.party_names()), "   auto target: ", TargetSelect.label())
	print("lvl  region     win%  hp left  fight s  turns  EXP/keeper  fights to next  elite win%")
	var all_w := 0
	var all_n := 0
	var hours := 0.0
	for L in levels:
		var wins := 0; var secs := 0.0; var xp := 0.0; var hpl := 0.0; var turns := 0.0
		var el_n := 0; var el_w := 0
		var carry := hp0
		for i in n:
			g.CLASS_XP = {}; g.SUB_XP = {}
			for h in g.party_names():
				g.set_hero_level(h, L)
				g.SUB_XP[h] = {str(g.CHAR[h].sub): Q.xp_floor(L)}
				g.HERO_MP[h] = 0.0
			qf.in_kingdom_battle = true
			var e: Dictionary = qf.encounter_for(region if region != "" else REGIONS[L], Q.foe_level(L) if tiers.is_empty() else L)
			if not tiers.is_empty():
				e.tiers = tiers; e.elite = false
				var ks: Array = (e.kinds as Array).duplicate()
				while ks.size() < tiers.size(): ks.append(ks[0])
				e.kinds = ks.slice(0, tiers.size())
			g.encounter = e
			g.new_battle(3)
			for u in g.G.units:
				if u.team == "blue": u.hp = maxi(1, int(roundf(float(u.maxhp) * carry))); u.shown_hp = u.hp
			g.phase = "battle"; g.screen = ""; g.AUTO = true
			g.begin_timeline()
			var guard := 0
			while g.phase == "battle" and guard < 40000:
				g.step(17); guard += 1
			var tot_hp := 0.0; var max_hp := 0.0
			for u in g.G.units:
				if u.team == "blue": tot_hp += maxf(0.0, u.hp); max_hp += u.maxhp
			turns += g.G.turn
			while g.phase == "ending" and guard < 60000:
				g.step(17); guard += 1
			var won: bool = g.G.result == "win"
			if won: wins += 1
			if bool(e.elite):
				el_n += 1
				if won: el_w += 1
			hpl += tot_hp / maxf(1.0, max_hp)
			if chain:
				# kingdom loop: HP carries into the next fight (QuestRPG.hp_after_battle); a loss means a rest at the inn
				carry = Q.hp_after_battle(won, tot_hp / maxf(1.0, max_hp)) if won else 1.0
			secs += g.G.t / 1000.0
			var gs: Dictionary = g.last_xp_gains
			var tot := 0.0
			for k in gs: tot += float(gs[k])
			xp += tot / maxf(1.0, float(gs.size()))
		var per := xp / n
		var need: int = Q.XP_TO_NEXT[mini(L - 1, 8)] if L < 10 else 0
		var fights := need / maxf(1.0, per)
		var loop_s: float = secs / n + Q.LOOP_OVERHEAD_S + Q.SELECT_S * turns / n
		if L < 10: hours += fights * loop_s / 3600.0
		print("%3d  %-9s  %4d%%   %4d%%   %6.1f  %5.1f   %8.1f   %8.1f        %s" % [L, REGIONS[L], int(roundf(100.0 * wins / n)), int(roundf(100.0 * hpl / n)),
			secs / n, turns / n, per, fights, ("%d%% of %d" % [int(roundf(100.0 * el_w / el_n)), el_n]) if el_n > 0 else "-"])
		all_w += wins; all_n += n
	print("overall AUTO win rate %.1f%% (%d/%d)" % [100.0 * all_w / maxf(1.0, all_n), all_w, all_n])
	if levels.size() == 10: print("estimated time Lv1 -> Lv10: %.2f h (fight + %.0f s loop + %.1f s target select per turn)" % [hours, Q.LOOP_OVERHEAD_S, Q.SELECT_S])
	qf.in_kingdom_battle = false
	g.CLASS_XP = {}; g.SUB_XP = {}
	if FileAccess.file_exists("user://kingdom.cfg"): DirAccess.remove_absolute(save_cfg)
	quit()

