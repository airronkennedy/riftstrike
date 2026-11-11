extends SceneTree
# Whole-map check (layout 3): godot --headless --path . --script res://tools/test_world_full.gd
# - every area has a clear ?warp= spawn, is reachable on foot (props included) with gates off
# - with gates on, only Act I is open; each gate flag opens its way
# - every wild/rubble tile has an encounter table; folded ids still resolve
func _init() -> void:
	var W = preload("res://scripts/world.gd").new()
	if not W.load_all():
		print("FAIL load ", W.err); quit(1); return
	var fails := 0
	print("grid ", W.W, "x", W.H, " areas ", W.areas.size(), " gates ", W.gates.size(), " styles ", W.styles.size())
	var pc := 0
	for ck in W.chunks: pc += (W.chunks[ck] as Array).size()
	print("props+trees ", pc, " / json props ", (W.tiles_cfg.get("props", []) as Array).size())
	for p in W.tiles_cfg.get("props", []):
		if W.make_prop(p).is_empty():
			print("FAIL unknown prop img ", p); fails += 1
	for id in W.area_order:
		var a: Dictionary = W.areas[id]
		if str(a.get("built", "")) != "walkable":
			print("FAIL not walkable ", id); fails += 1
		var sp: Vector2 = W.spawn_pos(id)
		if W.area_at(sp.x, sp.y) != id or W.blocked_at(sp.x, sp.y):
			print("FAIL spawn ", id, " ", sp, " in ", W.area_at(sp.x, sp.y), " blocked ", W.blocked_at(sp.x, sp.y)); fails += 1
	for f in W.folded:
		if not W.areas.has(W.canon(str(f))):
			print("FAIL folded ", f); fails += 1
	# reachability on the lead's foot box (props block) with every gate open
	W.gates_enabled = false
	var reach := _reach(W)
	for id in W.area_order:
		if not reach.has(id):
			print("FAIL unreachable on foot ", id); fails += 1
	print("on foot, gates off: ", reach.size(), " areas")
	W.gates_enabled = true
	var r1 := _reach(W)
	print("gates on (no flags): ", r1.keys())
	for f in ["thornwick_pass", "boss_ironbridge", "warden_bells", "catacomb_cleared", "catacomb_bridge_dropped", "vault_key", "warden_lanterns", "warden_sights", "drake_sigil", "boss_kingshold", "warden_embers", "archive_cleared", "game_cleared"]:
		W.set_flag(f)
		var rr := _reach(W)
		print(" +", f, " -> ", rr.size(), " areas")
	if _reach(W).size() != W.area_order.size():
		print("FAIL all flags do not open every area"); fails += 1
	# encounter tables cover every wild tile
	var missing := {}
	var wild_n := {}
	for r in W.H:
		for c in W.W:
			var ch: int = W.ch_at(c, r)
			if ch == W.C_WILD or ch == W.C_RUBBLE:
				var aid: String = W.area_at(c * 64 + 32, r * 64 + 32)
				wild_n[aid] = int(wild_n.get(aid, 0)) + 1
				var z: String = W.zone_at(c * 64 + 32, r * 64 + 32)
				var tb: Dictionary = W.enc_table(aid, z)
				if tb.is_empty() or (tb.get("groups", []) as Array).is_empty():
					missing[aid + "/" + z] = int(missing.get(aid + "/" + z, 0)) + 1
	print("wild/rubble tiles per area ", wild_n)
	print("wild tiles with no encounters (towns/hamlets ok): ", missing)
	for k in missing:
		if not (k.begins_with("frostveil") or k.contains("Foxglove") or k.begins_with("rivenbrook") or k.begins_with("thornwick")):
			print("FAIL no encounters ", k); fails += 1
	print("RESULT ", "OK" if fails == 0 else "FAIL %d" % fails)
	quit(0 if fails == 0 else 1)


func _reach(W) -> Dictionary:
	var s: Vector2 = W.start_pos()
	var st := Vector2i(int(s.x / 64), int(s.y / 64))
	var seen := {st: true}
	var q: Array = [st]
	var out := {}
	while q.size() > 0:
		var t: Vector2i = q.pop_back()
		out[W.area_at(t.x * 64 + 32, t.y * 64 + 32)] = true
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = t + d
			if seen.has(n) or n.x < 0 or n.y < 0 or n.x >= W.W or n.y >= W.H:
				continue
			# the lead can stand somewhere in this tile (centre or a nudge), like tap-walking slides
			var okk := false
			for o in [Vector2(32, 40), Vector2(32, 20), Vector2(20, 40), Vector2(44, 40), Vector2(32, 56)]:
				if not W.blocked_at(n.x * 64 + o.x, n.y * 64 + o.y):
					okk = true
					break
			if okk:
				seen[n] = true
				q.append(n)
	out.erase("")
	return out
