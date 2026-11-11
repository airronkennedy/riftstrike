extends SceneTree
# godot --headless --path . --script res://tools/test_world.gd
func _init() -> void:
	var W = preload("res://scripts/world.gd").new()
	if not W.load_all():
		print("FAIL load ", W.err); quit(1); return
	print("grid ", W.W, "x", W.H, " areas ", W.areas.size(), " gates ", W.gates.size(), " chunks ", W.chunks.size())
	var s: Vector2 = W.start_pos()
	print("start ", s, " area ", W.area_at(s.x, s.y), " blocked ", W.blocked_at(s.x, s.y))
	# BFS over tiles from start
	var seen := {}
	var q: Array = [Vector2i(int(s.x / 64), int(s.y / 64))]
	seen[q[0]] = true
	var reach := {}
	while q.size() > 0:
		var t: Vector2i = q.pop_back()
		reach[W.area_at(t.x * 64 + 32, t.y * 64 + 32)] = true
		for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			var n: Vector2i = t + d
			if not seen.has(n) and not W.tile_blocked(n.x, n.y):
				seen[n] = true
				q.append(n)
	print("reachable areas (gates locked): ", reach.keys())
	W.gates_enabled = false
	seen = {}; q = [Vector2i(int(s.x / 64), int(s.y / 64))]; reach = {}
	while q.size() > 0:
		var t2: Vector2i = q.pop_back()
		reach[W.area_at(t2.x * 64 + 32, t2.y * 64 + 32)] = true
		for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			var n2: Vector2i = t2 + d
			if not seen.has(n2) and not W.tile_blocked(n2.x, n2.y):
				seen[n2] = true
				q.append(n2)
	print("reachable (gates off): ", reach.keys())
	W.gates_enabled = true
	# encounter sim: walk inside wild grass in Brookside Meadow
	var wild: Array = []
	for r in W.H:
		for c in W.W:
			if W.ch_at(c, r) == W.C_WILD and W.area_at(c * 64 + 32, r * 64 + 32) == "brookside_meadow":
				wild.append(Vector2(c * 64 + 32, r * 64 + 32))
	print("meadow wild tiles ", wild.size())
	var steps_between: Array = []
	var cnt := 0
	var px := 0.0
	var x: float = wild[0].x
	var y: float = wild[0].y
	W.tick(x, y, 16, false)
	W.reset_grace()
	for i in 20000:
		x += 3.0  # walking 3px/frame
		var walked: float = 3.0
		px += walked
		if not W.in_wild(x, y):
			x = wild[i % wild.size()].x; y = wild[i % wild.size()].y
			W.last_x = x; W.last_y = y
			continue
		var ev: Dictionary = W.tick(x, y, 16, true)
		if ev.has("encounter"):
			cnt += 1
			steps_between.append(px / 64.0)
			px = 0.0
			if cnt <= 3: print("enc ", ev.encounter, " xp ", W.encounter_xp(ev.encounter), " mult ", W.enemy_mult(int(ev.encounter.level)))
	var tot := 0.0
	for v in steps_between: tot += v
	print("encounters ", cnt, " avg tiles walked between ", tot / maxf(1, cnt))
	print("gate open g_fort_north ", W.gate_open("g_fort_north"))
	W.set_flag("thornwick_pass")
	print("after pass ", W.gate_open("g_fort_north"), " royal ", W.gate_open("g_royal_ward"))
	quit()
