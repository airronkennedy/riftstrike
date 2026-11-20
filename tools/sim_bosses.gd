extends SceneTree
## Boss balance sweep (docs/BOSSES.md):
##   godot --headless --path . -s res://tools/sim_bosses.gd -- --n=40 [--levels=4,7,10] [--boss=ash_sovereign]
## For each boss and party level: n AUTO fights per Attack Order: random (bad), default (party order, untouched Build)
## and smart (the suggested order, Combo.best_plan). Prints win %, spark rate on all party hits, Breaks, phases reached, signatures and fight length.
const C = preload("res://scripts/combo.gd")

func _init() -> void:
	preload("res://tools/test_save.gd").fresh()
	_run.call_deferred()

func _run() -> void:
	var n := 30
	var levels: Array = [4, 7, 10]
	var only := ""
	var modes: Array = ["random", "default", "smart"]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--n="): n = int(a.substr(4))
		elif a.begins_with("--boss="): only = a.substr(7)
		elif a.begins_with("--modes="): modes = Array(a.substr(8).split(","))
		elif a.begins_with("--seed="): seed(int(a.substr(7)))
		elif a.begins_with("--levels="):
			levels = []
			for s in a.substr(9).split(","): levels.append(int(s))
	var Q = load("res://scripts/quest_rpg.gd")
	change_scene_to_file("res://main.tscn")
	await create_timer(0.6).timeout
	var g = current_scene
	g.sfx.muted = true
	var party: Array = g.party_names()
	var pf: Array = []
	for h in party: pf.append(C.frames(str(g.CHAR[h].cls)))
	var plan: Dictionary = C.best_plan(pf)
	var smart: Array = []
	var sdel := {}
	for j in plan.order.size():
		smart.append(party[plan.order[j]]); sdel[party[plan.order[j]]] = plan.delays[j]
	print("party: ", ", ".join(party), "   suggested order: ", ", ".join(smart))
	print("boss            lvl  order   win%  spark%  breaks  phase  sigs  turns  fight s")
	var out := {}
	for id in BossDefs.BOSSES.keys():
		if only != "" and id != only: continue
		for L in levels:
			for mode in modes:
				var wins := 0; var hits := 0; var sparks := 0; var breaks := 0; var ph := 0.0; var sigs := 0; var turns := 0; var secs := 0.0
				for i in n:
					g.CLASS_XP = {}; g.SUB_XP = {}
					for h in party:
						g.set_hero_level(h, L)
						g.SUB_XP[h] = {str(g.CHAR[h].sub): Q.xp_floor(L)}
						g.HERO_MP[h] = 0.0
					if mode == "random":
						var o2: Array = party.duplicate(); o2.shuffle()
						g.HERO_ORDER = o2; g.HERO_DELAY = {}
					elif mode == "default":
						g.HERO_ORDER = party.duplicate(); g.HERO_DELAY = {}
					else:
						g.HERO_ORDER = smart; g.HERO_DELAY = sdel
					g.AUTO = true
					g.start_boss_battle(id)
					var guard := 0
					while g.phase == "battle" and guard < 60000:
						g.step(17); guard += 1
					var bf = g.boss
					if g.G.result == "win": wins += 1
					hits += g.res_combo_hits; sparks += g.res_combo_sparks
					if bf != null:
						breaks += int(bf.stats.breaks); ph += float(bf.phase + 1); sigs += int(bf.stats.sigs)
					turns += g.G.turn; secs += g.G.t / 1000.0
					g.encounter = {}; g.boss = null; g.phase = "title"
				var wr: float = 100.0 * wins / n
				out["%s_%d_%s" % [id, L, mode]] = wr
				print("%-15s %3d  %-6s  %4d%%  %5.1f%%  %6.1f  %5.2f  %4.1f  %5.1f  %6.1f" % [id, L, mode, int(roundf(wr)), 100.0 * sparks / maxf(1.0, hits),
					float(breaks) / n, ph / n, float(sigs) / n, float(turns) / n, secs / n])
	g.CLASS_XP = {}; g.SUB_XP = {}
	preload("res://tools/test_save.gd").fresh()
	quit()
