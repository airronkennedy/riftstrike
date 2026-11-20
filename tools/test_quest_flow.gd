extends SceneTree
## Main loop: title -> New Game -> kingdom -> danger meter battle (region foes) -> results -> back to the same kingdom spot,
## party HP lowered in user://kingdom.cfg.  godot --headless --path . --script res://tools/test_quest_flow.gd
var fails := 0
func ok(c: bool, m: String) -> void:
	print(("ok   " if c else "FAIL ") + m)
	if not c: fails += 1
func wait(ms: float) -> void:
	await create_timer(ms / 1000.0).timeout
func _init() -> void:
	preload("res://tools/test_save.gd").fresh() # new-game user data every run
	_run.call_deferred()
func _run() -> void:
	change_scene_to_file("res://main.tscn")
	await wait(600)
	var qf = root.get_node("QuestFlow")
	var enc = root.get_node("Encounters")
	ok(current_scene != null and current_scene.scene_file_path == "res://main.tscn", "title scene up")
	current_scene.sfx.muted = true
	qf.new_game()
	await wait(600)
	ok(current_scene.scene_file_path == "res://scenes/kingdom.tscn", "New Game opens the kingdom")
	var k = current_scene
	k.load_map("overworld")
	await wait(100)
	var spot: Vector2 = k.player_pos
	k.save_game()
	ok(enc.has_battle_listener(), "battle listener connected")
	enc.start_random_battle("forest")
	await wait(700)
	var g = current_scene
	ok(g.scene_file_path == "res://main.tscn" and g.phase == "battle", "region battle started")
	ok(g.battle_area == "gallowbough-orchard", "forest backdrop (" + str(g.battle_area) + ")")
	var forest := ["mote", "gnat", "brute", "moth", "chanter"]
	var foes_ok := true
	for u in g.G.units:
		if u.team == "red":
			var id := str(u.K.img).trim_prefix("f_")
			# the forest has an 8% elite roll (QuestFlow REGION_BATTLES): that foe wears AfRoster.FOE_ART.elite art
			# (leaper, tithe, knell, ...), so it was a 1-in-12 flake, not a leak from the dungeon pools
			var elite_art := false
			if str(u.tier) == "elite" and bool(g.encounter.get("elite", false)):
				for arts in preload("res://scripts/af_roster.gd").FOE_ART.elite.values(): if (arts as Array).has(id): elite_art = true
			if not forest.has(id) and not elite_art: foes_ok = false; print("  foe ", id, " tier ", u.tier)
	ok(foes_ok, "forest foe set")
	ok(g.G.ctb, "side-view timeline battle")
	g.sfx.muted = true
	g.AUTO = true; g.speed = 3
	var guard := 0
	while g.phase != "results" and guard < 1200:
		await wait(50); guard += 1
	ok(g.phase == "results", "battle finished (" + str(g.G.result) + ")")
	# make sure HP is lowered: knock the party down before returning
	for u in g.G.units:
		if u.team == "blue" and not u.dead: u.hp = int(u.maxhp * 0.5)
	g.results_primary()
	await wait(700)
	ok(current_scene.scene_file_path == "res://scenes/kingdom.tscn", "back in the kingdom")
	var k2 = current_scene
	ok(k2.map.get("id", "") == "overworld" and k2.player_pos.distance_to(spot) < 40.0, "same spot (%s vs %s)" % [k2.player_pos, spot])
	ok(k2.party_hp < k2.party_hp_max, "party HP lowered (%d/%d)" % [k2.party_hp, k2.party_hp_max])
	print("QUEST_FLOW ", "PASS" if fails == 0 else "FAIL %d" % fails)
	quit()
