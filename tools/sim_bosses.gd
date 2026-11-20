extends SceneTree
## Boss balance sweep (docs/BOSSES.md):
##   godot --headless --path . -s res://tools/sim_bosses.gd -- --n=40 [--levels=7,9] [--boss=boss_sovereign] [--modes=random,default,smart]
## Default levels per boss: its story recommended level (BossDefs level) and one above.
## For each boss and party level: n AUTO fights per Attack Order: random (a shuffled order, no delays), party (the
## squad order as listed, no delays), default (untouched Build: the game's auto_plan) and smart (Combo.best_plan here).
## --carry: the Sovereign starts with the HP share the party had left after a Regnant fight (sampled from the
## Regnant runs of the same order; a loss there means a retry at full HP). --enrage=turn,step,max overrides
## QuestRPG.BOSS_ENRAGE. Prints win %, spark rate on all party hits, Breaks, phases reached, signatures and fight length.
const C = preload("res://scripts/combo.gd")

func _init() -> void:
	preload("res://tools/test_save.gd").fresh()
	_run.call_deferred()

func _run() -> void:
	var n := 30
	var levels: Array = []
	var only := ""
	var modes: Array = ["random", "party", "default", "smart"]
	var carry := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--n="): n = int(a.substr(4))
		elif a.begins_with("--boss="): only = a.substr(7)
		elif a.begins_with("--modes="): modes = Array(a.substr(8).split(","))
		elif a.begins_with("--seed="): seed(int(a.substr(7)))
		elif a.begins_with("--enrage="):
			var ev: PackedStringArray = a.substr(9).split(",")
			var QR = load("res://scripts/quest_rpg.gd")
			QR.BOSS_ENRAGE = {"turn": int(ev[0]), "step": float(ev[1]), "max": float(ev[2])}
		elif a == "--carry": carry = true
		elif a.begins_with("--tune="):
			# --tune=hp,atk[,break[,spark]] : scale every BossDefs.TUNE row (what-if sweeps; not saved)
			var tv: PackedStringArray = a.substr(7).split(",")
			for bid in BossDefs.TUNE:
				BossDefs.TUNE[bid].hp = float(BossDefs.TUNE[bid].hp) * float(tv[0])
				BossDefs.TUNE[bid].atk = float(BossDefs.TUNE[bid].atk) * float(tv[1] if tv.size() > 1 else "1")
				if tv.size() > 2: BossDefs.TUNE[bid]["break"] = float(BossDefs.TUNE[bid].get("break", 1.0)) * float(tv[2])
				if tv.size() > 3: BossDefs.TUNE[bid]["spark"] = float(tv[3])
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
	var reg_left := {} # order mode -> Array of party HP shares left after Regnant wins
	for id in BossDefs.BOSSES.keys():
		if only != "" and id != only: continue
		var lv: Array = levels
		if lv.is_empty():
			var l0 := int(BossDefs.get_def(id).get("level", 7))
			lv = [l0] if l0 >= 10 else [l0, l0 + 1]
		for L in lv:
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
					elif mode == "shuffled":
						# what the game does when a player drags the order around: auto delays frozen, order shuffled
						g.HERO_ORDER = []; g.HERO_DELAY = {}
						var dl: Dictionary = g.attack_delays().duplicate()
						var o3: Array = party.duplicate(); o3.shuffle()
						g.HERO_ORDER = o3; g.HERO_DELAY = dl
					elif mode == "party":
						g.HERO_ORDER = party.duplicate(); g.HERO_DELAY = {}
					elif mode == "default":
						g.HERO_ORDER = []; g.HERO_DELAY = {} # untouched Build: the game's suggested order (auto_plan)
					elif mode.begins_with("fixed:"):
						# fixed:<i,j,...> party indices, no delays (diagnostics)
						var fo: Array = []
						for ix in mode.substr(6).split("."): fo.append(party[int(ix)])
						g.HERO_ORDER = fo; g.HERO_DELAY = {}
					else:
						g.HERO_ORDER = smart; g.HERO_DELAY = sdel
					g.AUTO = true
					g.start_boss_battle(id)
					if carry and id == "boss_sovereign":
						var pool: Array = reg_left.get(mode, [])
						# story: QuestFlow.finish_battle (QuestRPG.hp_after_battle) then "Pull Taren out" burns 25%
						var f0: float = Q.hp_after_battle(true, float(pool[randi() % pool.size()])) * 0.75 if not pool.is_empty() else 0.75
						for u in g.G.units:
							if u.team == "blue": u.hp = maxi(1, int(roundf(float(u.maxhp) * f0))); u.shown_hp = u.hp
					var guard := 0
					while g.phase == "battle" and guard < 60000:
						g.step(17); guard += 1
					var bf = g.boss
					if g.G.result == "win": wins += 1
					if id == "boss_regnant" and g.G.result == "win":
						var hl := 0.0; var hm := 0.0
						for u in g.G.units:
							if u.team == "blue": hl += maxf(0.0, float(u.hp)) if not u.dead else 0.0; hm += float(u.maxhp)
						if not reg_left.has(mode): reg_left[mode] = []
						reg_left[mode].append(hl / maxf(1.0, hm))
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
