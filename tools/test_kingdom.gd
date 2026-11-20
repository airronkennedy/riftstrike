extends SceneTree
## Kingdom / overworld checks: map shapes, every spot / warp / npc reachable, danger meter only on the overworld,
## start_random_battle(region_id) fires with a region, shop buy/sell and inn rest.
## godot --headless --path . --script res://tools/test_kingdom.gd
var fails := 0

func ok(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond: fails += 1

func _init() -> void:
	preload("res://tools/test_save.gd").fresh() # new-game user data every run
	_run.call_deferred()

func _run() -> void:
	var KS: PackedScene = load("res://scenes/kingdom.tscn")
	var enc: Node = root.get_node_or_null("Encounters")
	if enc == null:
		enc = load("res://scripts/encounters.gd").new()
		enc.name = "Encounters"
		root.add_child(enc)
	var k = KS.instantiate()
	root.add_child(k)
	await process_frame
	for id in ["town", "castle", "house", "overworld"]:
		k.load_map(id)
		var rows: Array = k.rows
		var wide := true
		for r in rows:
			wide = wide and (r as String).length() == k.W
		ok(wide, "%s: %dx%d rows all same width" % [id, k.W, k.H])
		ok(not k.blocked_at(k.player_pos), "%s: start is walkable" % id)
		# BFS over 16 px steps from the start using the real collision.
		var seen := {}
		var q: Array = [k.player_pos]
		var stepv := 16.0
		seen[Vector2i(k.player_pos / stepv)] = true
		var reach: Array = []
		while not q.is_empty() and reach.size() < 40000:
			var p: Vector2 = q.pop_back()
			reach.append(p)
			for d in [Vector2(stepv, 0), Vector2(-stepv, 0), Vector2(0, stepv), Vector2(0, -stepv)]:
				var n: Vector2 = p + d
				var key := Vector2i(n / stepv)
				if seen.has(key) or k.blocked_at(n):
					continue
				seen[key] = true
				q.append(n)
		var near_any := func(target: Vector2, rad: float) -> bool:
			for p in reach:
				if (p as Vector2).distance_to(target) < rad: return true
			return false
		for u in k.usables:
			ok(near_any.call(u.pos, 70.0), "%s: %s '%s' reachable" % [id, u.kind, u.name])
		for w in k.map.warps:
			var rc: Rect2 = w.rect
			ok(near_any.call((rc.position + rc.size / 2.0) * 64.0, 40.0), "%s: warp '%s' reachable" % [id, w.name])
			var dest: Dictionary = KingdomMaps.get_map(str(w.to))
			ok(not dest.is_empty(), "%s: warp target %s exists" % [id, w.to])
	# Danger meter: walking in town never calls the hook; the overworld does, with a region id.
	var got: Array = []
	k.allow_warps = false
	enc.random_battle_requested.connect(func(r): got.append(r); enc.finish_random_battle(true))
	k.load_map("town")
	k.meter = 0.0
	var walked := _walk(k, 4000.0)
	ok(walked > 1000.0 and got.is_empty() and k.meter == 0.0, "town: %d px walked, no battle, meter stays 0" % int(walked))
	k.load_map("overworld")
	k.meter = 0.0
	walked = _walk(k, 64.0 * 70.0)
	ok(got.size() >= 1, "overworld: %d px walked -> start_random_battle fired %d times %s" % [int(walked), got.size(), str(got)])
	ok(got.size() > 0 and KingdomMaps.REGIONS.has(str(got[0])), "region id is a known region")
	ok(k.meter < 1.0, "meter reset after battle (%.2f)" % k.meter)
	# Shop + inn
	var iid: String = k.item_defs.keys()[0]
	k.gold = 500
	var bag0: int = k.bag.size()
	ok(k.buy(iid) and k.bag.size() == bag0 + 1 and k.gold == 500 - k.price_of(iid), "shop: bought %s for %dg" % [iid, k.price_of(iid)])
	ok(k.sell(iid) and k.bag.size() == bag0, "shop: sold it back")
	ok(k.item_defs.size() >= 10, "shop uses game.gd ITEM_DEFS (%d items)" % k.item_defs.size())
	k.party_hp = 5
	k.gold = 50
	k.rest_at_inn()
	await create_timer(1.6).timeout
	ok(k.party_hp == k.party_hp_max and k.gold == 50 - k.INN_COST, "inn: hp restored, %d gold charged" % k.INN_COST)
	var cf := ConfigFile.new()
	ok(cf.load(k.SAVE_PATH) == OK and int(cf.get_value("kingdom", "hp", 0)) == k.party_hp_max, "inn: saved to %s" % k.SAVE_PATH)
	print("RESULT: %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails else 0)

# Walk a scripted zig-zag via step_move and feed distance to the meter like _process does.
func _walk(k, total: float) -> float:
	var done := 0.0
	var dirs := [Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0), Vector2(0, -1)]
	var i := 0
	var stuck := 0
	while done < total and stuck < 400:
		var m: float = k.step_move(dirs[i % 4] * 8.0)
		if m < 0.5:
			i += 1; stuck += 1
		else:
			stuck = 0
			done += m
			k._after_move(m)
			if k.busy:
				k.busy = false
		if int(done) % 512 < 8: i += 1
	return done
