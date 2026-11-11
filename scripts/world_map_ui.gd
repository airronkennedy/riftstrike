extends RefCounted
# Full-region map screen. Two tabs: REGION (whole planned graph: every named area, links,
# branches, rec levels, story gates, player position) and LOCAL (built tiles, player dot).
# Drawn with the game node's helpers; pan by drag, zoom with +/-; tap an area for details.

var W = null # world.gd instance
var tab := "region"
var zoom := 1.0
var pan := Vector2.ZERO
var sel := ""
var local_tex: ImageTexture = null
var _node_rects: Array = [] # [Rect2, id]
var _map_rect := Rect2()

const KIND_COL := {
	"town": Color("#f2c14e"), "wild": Color("#6cc24a"), "route": Color("#d9b77a"),
	"dungeon": Color("#e0736b"), "final": Color("#b98bff"), "secret": Color("#8fc3e6"), "postgame": Color("#8fc3e6"),
}


func setup(world) -> void:
	W = world
	_build_local_tex()


func open() -> void:
	sel = W.cur_area if W != null else ""
	zoom = 1.0
	pan = Vector2.ZERO


func _build_local_tex() -> void:
	if W == null or W.W == 0:
		return
	var im := Image.create(W.W, W.H, false, Image.FORMAT_RGBA8)
	for r in W.H:
		for c in W.W:
			var ch: int = W.ch_at(c, r)
			var col := Color("#2f7f8c")
			if ch == W.C_GRASS or ch == W.C_BUSH:
				col = Color("#7fb04a")
			elif ch == W.C_WILD:
				col = Color("#3f8a2e")
			elif ch == W.C_SAND:
				col = Color("#e6cf86")
			elif ch == W.C_TREE:
				col = Color("#2c5a2a")
			elif ch == W.C_ROCK:
				col = Color("#7d7b78")
			elif ch == W.C_GATE:
				col = Color("#d23a2a")
			elif ch == W.C_BRIDGE:
				col = Color("#9a6a3a")
			elif ch == W.C_FLOOR:
				col = Color("#a9a7a2")
			elif ch == W.C_RUBBLE:
				col = Color("#8c857a")
			elif ch == W.C_WALL:
				col = Color("#4a4f58")
			elif ch == W.C_LAVA:
				col = Color("#e0561c")
			elif ch == W.C_ICE:
				col = Color("#dff2fb")
			if ch != W.C_WATER and ch != W.C_BRIDGE and ch != W.C_GATE and ch != W.C_LAVA:
				var st: Dictionary = W.style_at(c, r)
				if st.has("map"):
					col = col.lerp(st.map, 0.55)
			im.set_pixel(c, r, col)
	local_tex = ImageTexture.create_from_image(im)


func drag(d: Vector2) -> void:
	pan += d


func zoom_by(f: float) -> void:
	zoom = clampf(zoom * f, 0.7, 4.0)


func _status(id: String) -> String:
	var a: Dictionary = W.area(id)
	var b: String = str(a.get("built", "planned"))
	if b == "walkable":
		return "Walkable now"
	if b == "stub":
		return "Entrance built, sealed"
	return "Planned (not built yet)"


func _gate_for(a: String, b: String) -> String:
	for l in W.links:
		var ld: Dictionary = l
		if (str(ld.from) == a and str(ld.to) == b) or (str(ld.from) == b and str(ld.to) == a):
			return str(ld.get("gate", ""))
	return ""


func draw(g: Object, vw: float, vh: float, now: float, px: float, py: float) -> void:
	_node_rects = []
	var short: bool = vh <= 430
	var helper: String = "The whole Riftmarch. Tap a place for details. Drag to pan, +/- to zoom." if tab == "region" else "Built tiles you can walk now. The white dot is you."
	var area: Rect2 = g.menu_sheet("map_back", "Map", helper, func(): g.close_world_map(), ["Region", "Local"], 0 if tab == "region" else 1, func(i): tab = "region" if i == 0 else "local", "map_tab")
	var info_w: float = 0.0 if area.size.x < 600 else minf(280.0, area.size.x * 0.32)
	var gap: float = 12.0
	var info_h: float = 0.0 if info_w > 0 else (70.0 if short else 92.0)
	_map_rect = Rect2(area.position.x, area.position.y, area.size.x - info_w - (gap if info_w > 0 else 0.0), area.size.y - (info_h + gap if info_h > 0 else 0.0))
	g.rbox(_map_rect, 22.0, Color(0.13, 0.3, 0.32, 1))
	if tab == "region":
		_draw_region(g, now, px, py)
	else:
		_draw_local(g, now, px, py)
	var zb: float = 36.0 if short else 42.0
	g.pill("map_zin", Rect2(_map_rect.end.x - 10.0 - zb, _map_rect.position.y + 10.0, zb, zb), "+", "soft", 22.0, func(): zoom_by(1.25))
	g.pill("map_zout", Rect2(_map_rect.end.x - 18.0 - 2.0 * zb, _map_rect.position.y + 10.0, zb, zb), "-", "soft", 22.0, func(): zoom_by(0.8))
	# details card
	var pr: Rect2
	if info_w > 0:
		pr = Rect2(area.end.x - info_w, area.position.y, info_w, area.size.y)
	else:
		pr = Rect2(area.position.x, area.end.y - info_h, area.size.x, info_h)
	g.rbox(pr, 22.0, g.UI_CARD, g.UI_LINE, 1.5)
	_draw_info(g, pr, info_w == 0.0)


func _map_size() -> Vector2:
	var ms: Array = W.data.get("map_size", [1280, 700])
	return Vector2(float(ms[0]), float(ms[1]))


var legend_h := 0.0


func _plot_rect() -> Rect2:
	var mr := _map_rect.grow(-16)
	mr.size.y -= legend_h
	return mr


func _scale() -> float:
	var mr := _plot_rect()
	var ms := _map_size()
	return minf(mr.size.x / ms.x, mr.size.y / ms.y) * zoom


func _to_screen(m: Vector2) -> Vector2:
	var ms := _map_size()
	var s: float = _scale()
	return _plot_rect().get_center() + (m - ms / 2.0) * s + pan


func _box_rect(a: Dictionary) -> Rect2:
	if a.has("box"):
		var b: Array = a.box
		var p0: Vector2 = _to_screen(Vector2(float(b[0]), float(b[1])))
		var s: float = _scale()
		return Rect2(p0, Vector2(float(b[2]), float(b[3])) * s)
	var ms := _map_size()
	var c: Vector2 = _to_screen(Vector2(float(a.map[0]) / 100.0 * ms.x, float(a.map[1]) / 100.0 * ms.y))
	return Rect2(c - Vector2(30, 20), Vector2(60, 40))


# Where the segment from the box centre toward `to` leaves the box.
func _edge(r: Rect2, to: Vector2) -> Vector2:
	var c: Vector2 = r.get_center()
	var d: Vector2 = to - c
	if d.length() < 0.01:
		return c
	var tx: float = (r.size.x / 2.0) / absf(d.x) if absf(d.x) > 0.001 else 1e9
	var ty: float = (r.size.y / 2.0) / absf(d.y) if absf(d.y) > 0.001 else 1e9
	return c + d * minf(1.0, minf(tx, ty))


# Liang-Barsky clip of a segment to the map panel. Returns [] when fully outside.
func _clip_seg(a: Vector2, b: Vector2) -> Array:
	var r := _map_rect.grow(-4)
	var t0 := 0.0
	var t1 := 1.0
	var d: Vector2 = b - a
	var ps: Array = [-d.x, d.x, -d.y, d.y]
	var qs: Array = [a.x - r.position.x, r.end.x - a.x, a.y - r.position.y, r.end.y - a.y]
	for i in 4:
		var pp: float = ps[i]
		var qq: float = qs[i]
		if absf(pp) < 0.0001:
			if qq < 0.0:
				return []
		else:
			var t: float = qq / pp
			if pp < 0.0:
				t0 = maxf(t0, t)
			else:
				t1 = minf(t1, t)
	if t0 > t1:
		return []
	return [a + d * t0, a + d * t1]


# A point between two boxes for a gate's lock that is not on top of another place.
func _lock_spot(ea: Vector2, eb: Vector2, ida: String, idb: String) -> Vector2:
	var ts: Array = [0.5, 0.4, 0.6, 0.3, 0.7, 0.2, 0.8, 0.12, 0.88, 0.05, 0.95]
	for t in ts:
		var p: Vector2 = ea.lerp(eb, float(t))
		var hit := false
		for id in W.area_order:
			if id == ida or id == idb:
				continue
			if _box_rect(W.area(id)).grow(6.0).has_point(p):
				hit = true
				break
		if not hit:
			return p
	return ea.lerp(eb, 0.5)


func _draw_region(g: Object, now: float, px: float, py: float) -> void:
	var s: float = _scale()
	var clip := _map_rect.grow(-4)
	var nfs: float = clampf(15.0 * s / 0.55, 9.0, 22.0)
	# whole-region land plate
	var ms := _map_size()
	var plate := Rect2(_to_screen(Vector2.ZERO), ms * s).intersection(clip)
	if plate.size.x > 0 and plate.size.y > 0:
		g.rbox(plate, 18.0, Color(0.2, 0.42, 0.42, 0.55))
	# links (under the blocks)
	var locks: Array = []
	for l in W.links:
		var ld: Dictionary = l
		var a: Dictionary = W.area(str(ld.from))
		var b: Dictionary = W.area(str(ld.to))
		if a.is_empty() or b.is_empty():
			continue
		var ra: Rect2 = _box_rect(a)
		var rb: Rect2 = _box_rect(b)
		var gid: String = str(ld.get("gate", ""))
		var seg: Array = _clip_seg(ra.get_center(), rb.get_center())
		if seg.is_empty():
			continue
		var optional: bool = bool(a.get("optional", false)) or bool(b.get("optional", false))
		var col := Color(1, 0.96, 0.84, 0.95)
		if gid != "":
			col = Color("#ff8a7a") if not W.gate_open(gid) else Color("#8ff0b0")
		elif optional:
			col = Color(0.82, 0.92, 1.0, 0.8)
		var lw: float = clampf(7.0 * s / 0.55, 4.0, 10.0)
		g.draw_line(seg[0], seg[1], Color(0.02, 0.1, 0.1, 0.55), lw + 4.0, true)
		if gid != "":
			g.draw_dashed_line(seg[0], seg[1], col, lw, lw * 2.2, true)
		else:
			g.draw_line(seg[0], seg[1], col, lw, true)
		if gid != "":
			var ea: Vector2 = _edge(ra, rb.get_center())
			var eb: Vector2 = _edge(rb, ra.get_center())
			var mid: Vector2 = _lock_spot(ea, eb, str(ld.from), str(ld.to))
			var dup := false
			for lk0 in locks:
				if (lk0[0] as Vector2).distance_to(mid) < 18.0:
					dup = true
			if clip.has_point(mid) and not dup:
				locks.append([mid, W.gate_open(gid)])
	# territory blocks
	var you_pt := Vector2(-1, -1)
	var you_r := Rect2()
	for id in W.area_order:
		var a2: Dictionary = W.area(id)
		var br: Rect2 = _box_rect(a2)
		_node_rects.append([br, id])
		var vis: Rect2 = br.intersection(clip)
		if vis.size.x <= 1.0 or vis.size.y <= 1.0:
			continue
		var kcol: Color = KIND_COL.get(str(a2.kind), Color.WHITE)
		var built: String = str(a2.get("built", "planned"))
		var rad: float = clampf(18.0 * s / 0.55, 8.0, 26.0)
		var fill: Color = Color(kcol.r, kcol.g, kcol.b, 1.0) if built != "planned" else kcol.lerp(Color(0.13, 0.3, 0.32), 0.5)
		var border: Color = Color(1, 1, 1, 0.95) if built == "walkable" else Color(1, 1, 1, 0.35)
		var bw: float = 3.0 if built == "walkable" else 1.5
		g.rbox(vis, rad, fill, border, bw, 4.0)
		if built == "stub":
			g.rbox(vis.grow(-5.0), maxf(4.0, rad - 4.0), Color(0, 0, 0, 0), Color(1, 1, 1, 0.55), 1.5)
		if id == sel:
			g.rbox(vis.grow(4.0), rad + 4.0, Color(0, 0, 0, 0), Color("#ffe27a"), 3.5)
		if id == W.cur_area:
			var pulse: float = 0.5 + 0.5 * sin(now / 220.0)
			g.rbox(vis.grow(6.0 + pulse * 3.0), rad + 6.0, Color(0, 0, 0, 0), Color(0.45, 0.92, 1.0, 0.9), 3.0)
			var fr: Vector2 = W.area_frac(id, px, py)
			you_pt = br.position + Vector2(br.size.x * (0.12 + 0.76 * fr.x), br.size.y * (0.12 + 0.76 * fr.y))
			you_r = br
		# labels
		# keep labels inside the visible part of the block (and inside the panel)
		if vis.size.y < nfs * 2.4 or vis.size.x < 48.0:
			continue
		var c: Vector2 = vis.get_center()
		var ink: Color = Color("#1d2a2a") if built != "planned" else Color(1, 1, 1, 0.95)
		var halo: Color = Color(1, 1, 1, 0.55) if built != "planned" else Color(0, 0, 0, 0.6)
		var nm: String = str(a2.name)
		var f1: float = g.fit_size(nm, nfs, vis.size.x - 10.0, 8.0)
		var lines: int = 2
		var lm: String = str(a2.get("landmark", ""))
		var show_lm: bool = lm != "" and vis.size.y > nfs * 4.6
		if show_lm:
			lines = 3
		var y0: float = c.y - (lines - 1) * nfs * 0.55
		g.text(nm, c.x, y0, f1, ink, "center", 2.5, halo)
		var lv: String = W.rec_text(id) + ("  · optional" if bool(a2.get("optional", false)) else "")
		g.text(lv, c.x, y0 + nfs * 1.05, g.fit_size(lv, nfs * 0.78, vis.size.x - 10.0, 7.0), Color("#5a3d00") if built != "planned" else Color("#ffe6a8"), "center", 2.0, halo)
		if show_lm:
			g.text(lm, c.x, y0 + nfs * 2.05, g.fit_size(lm, nfs * 0.7, vis.size.x - 10.0, 7.0), ink, "center", 2.0, halo)
	for lk in locks:
		_lock_icon(g, lk[0], bool(lk[1]), clampf(s / 0.55, 0.9, 1.6))
	# YOU marker
	if you_pt.x >= 0 and clip.has_point(you_pt):
		var pulse2: float = 0.5 + 0.5 * sin(now / 200.0)
		g.draw_circle(you_pt, 9.0 + pulse2 * 5.0, Color(0.4, 0.9, 1.0, 0.35))
		g.draw_circle(you_pt, 7.0, Color(0.02, 0.1, 0.1, 0.9))
		g.draw_circle(you_pt, 5.0, Color("#9ff0ff"))
		var ty: float = you_pt.y - 18.0
		g.chip("YOU", you_pt.x, ty, 11.0, Color("#0e3b40"), Color("#9ff0ff"), "center")
	# legend
	var lx: float = _map_rect.position.x + 22
	var ly: float = _map_rect.end.y - 22
	var items: Array = [["town", "Town"], ["wild", "Wild"], ["dungeon", "Dungeon"], ["final", "Final"], ["postgame", "Post-game"]]
	var lwid: float = 30.0
	for it in items:
		lwid += 26.0 + g.text_w(it[1], 11)
	lwid += 30.0 + g.text_w("Story gate", 11) + 30.0 + g.text_w("Walkable", 11)
	legend_h = 30.0 if lwid < _map_rect.size.x - 20 else 0.0
	if lwid < _map_rect.size.x - 20:
		g.rbox(Rect2(_map_rect.position.x + 10, ly - 14, lwid, 28), 14.0, Color(0.03, 0.1, 0.11, 0.78))
		for it in items:
			g.rbox(Rect2(lx, ly - 6, 12, 12), 4.0, KIND_COL[it[0]])
			g.text(it[1], lx + 17, ly, 11, Color.WHITE, "left", 2, Color(0, 0, 0, 0.9))
			lx += 26 + g.text_w(it[1], 11)
		_lock_icon(g, Vector2(lx + 6, ly), false, 1.0)
		g.text("Story gate", lx + 16, ly, 11, Color.WHITE, "left", 2, Color(0, 0, 0, 0.9))
		lx += 30 + g.text_w("Story gate", 11)
		g.rbox(Rect2(lx, ly - 6, 12, 12), 4.0, Color(0, 0, 0, 0), Color.WHITE, 2.0)
		g.text("Walkable", lx + 17, ly, 11, Color.WHITE, "left", 2, Color(0, 0, 0, 0.9))


func _lock_icon(g: Object, p: Vector2, open: bool, k: float = 1.0) -> void:
	var col: Color = Color("#58d68d") if open else Color("#ff5a4a")
	g.draw_circle(p + Vector2(0, 1) * k, 11.0 * k, Color(0.03, 0.1, 0.11, 0.85))
	g.rbox(Rect2(p.x - 6 * k, p.y - 2 * k, 12 * k, 10 * k), 3.0 * k, Color(0, 0, 0, 0.8))
	g.rbox(Rect2(p.x - 5 * k, p.y - 1 * k, 10 * k, 8 * k), 2.5 * k, col)
	g.draw_arc(p + Vector2(0, -2) * k, 4.0 * k, PI, TAU if not open else PI * 1.6, 10, col, 2.0 * k)


func _draw_local(g: Object, now: float, px: float, py: float) -> void:
	if local_tex == null:
		return
	var mr := _map_rect.grow(-10)
	var s: float = minf(mr.size.x / float(W.W), mr.size.y / float(W.H)) * zoom
	var sz := Vector2(W.W * s, W.H * s)
	var o: Vector2 = mr.get_center() - sz / 2.0 + pan
	g.draw_texture_rect(local_tex, Rect2(o, sz), false)
	# area labels at rect centers
	for a in W.tiles_cfg.get("areas", []):
		var ad: Dictionary = a
		var q: Array = ad.rects[0]
		var cpos := o + Vector2((float(q[0]) + float(q[2]) + 1.0) / 2.0 * s, (float(q[1]) + float(q[3]) + 1.0) / 2.0 * s)
		g.text(W.area_name(str(ad.id)), cpos.x, cpos.y, clampf(s * 1.6, 10.0, 14.0), Color.WHITE, "center", 3, Color(0, 0, 0, 0.9))
		for z in ad.get("zones", []):
			var zd: Dictionary = z
			var zq: Array = zd.rects[0]
			if zq == q:
				g.text(str(zd.name), cpos.x, cpos.y + clampf(s * 1.6, 10.0, 14.0) + 2.0, clampf(s * 1.2, 9.0, 12.0), Color("#ffe6a8"), "center", 3, Color(0, 0, 0, 0.9))
				continue
			var zp := o + Vector2((float(zq[0]) + float(zq[2]) + 1.0) / 2.0 * s, (float(zq[1]) + float(zq[3]) + 1.0) / 2.0 * s)
			g.text(str(zd.name), zp.x, zp.y, clampf(s * 1.2, 9.0, 12.0), Color("#ffe6a8"), "center", 3, Color(0, 0, 0, 0.9))
	var pp := o + Vector2(px / W.TILE * s, py / W.TILE * s)
	var pulse: float = 0.5 + 0.5 * sin(now / 200.0)
	g.draw_circle(pp, 4.0 + pulse * 3.0, Color(0.4, 0.9, 1.0, 0.5))
	g.draw_circle(pp, 3.5, Color.WHITE)


func _draw_info(g: Object, pr: Rect2, compact: bool) -> void:
	var id: String = sel if sel != "" else W.cur_area
	var a: Dictionary = W.area(id)
	if a.is_empty():
		g.text("Tap an area on the map", pr.get_center().x, pr.get_center().y, 13.0, g.UI_MUTED, "center")
		return
	var x: float = pr.position.x + 16
	var y: float = pr.position.y + 20
	var ink: Color = g.UI_INK
	var walk: bool = str(a.get("built", "")) == "walkable"
	var fs: float = 16.0 if compact else 20.0
	var nm: String = str(a.name)
	g.text(nm, x, y, g.fit_size(nm, fs, pr.size.x - 32.0, 11.0), ink, "left")
	var acts: Dictionary = W.data.get("acts", {})
	y += 22 if compact else 28
	var cx: float = x
	cx += g.chip("Rec " + W.rec_text(id), cx, y, 11.0, g.UI_GOLD_L, Color("#7a5208")) + 6
	cx += g.chip(str(a.kind).capitalize(), cx, y, 11.0, Color(g.UI_INK.r, g.UI_INK.g, g.UI_INK.b, 0.08), g.UI_MUTED) + 6
	var stt: String = _status(id)
	if compact:
		stt = "Open" if walk else ("Sealed" if str(a.get("built", "")) == "stub" else "Coming later")
	if cx + g.text_w(stt, 11.0) + 20 < pr.end.x:
		cx += g.chip(stt, cx, y, 11.0, g.UI_GOOD_L if walk else g.UI_BAD_L, g.UI_GOOD if walk else g.UI_BAD) + 6
	if bool(a.get("optional", false)) and cx + 70 < pr.end.x:
		g.chip("Optional", cx, y, 11.0, g.UI_TEAL_L, g.UI_TEAL_D)
	if compact:
		var bl: String = str(a.get("blurb", ""))
		g.text(bl, x, y + 24, g.fit_size(bl, 12.0, pr.size.x - 32.0, 9.0), g.UI_MUTED, "left")
		return
	y += 26
	var act_s: String = str(acts.get(str(int(a.act)), ""))
	if act_s != "":
		g.text(act_s, x, y, g.fit_size(act_s, 12.0, pr.size.x - 32.0, 9.0), g.UI_TEAL_D, "left")
		y += 20
	for ln in g.wrap_words(str(a.get("blurb", "")), 13, pr.size.x - 32):
		g.text(str(ln), x, y, 13, ink, "left")
		y += 18
	for pair in [["INCLUDES", str(a.get("absorbs", ""))], ["LANDMARK", str(a.get("landmark", ""))]]:
		if str(pair[1]) == "" or y > pr.end.y - 90:
			continue
		y += 4
		g.text(str(pair[0]), x, y, 11, g.UI_MUTED, "left")
		y += 17
		for ln3 in g.wrap_words(str(pair[1]), 12, pr.size.x - 32):
			g.text(str(ln3), x, y, 12, ink, "left")
			y += 16
	y += 8
	g.text("CONNECTS TO", x, y, 11, g.UI_MUTED, "left")
	y += 20
	for l in W.links:
		var ld: Dictionary = l
		var other := ""
		if str(ld.from) == id:
			other = str(ld.to)
		elif str(ld.to) == id:
			other = str(ld.from)
		if other == "":
			continue
		var gid: String = str(ld.get("gate", ""))
		var locked: bool = gid != "" and not W.gate_open(gid)
		var on: String = W.area_name(other)
		g.text(on, x, y, g.fit_size(on, 13.0, pr.size.x - 100.0, 9.0), g.UI_LOCK if locked else ink, "left")
		if gid != "":
			g.chip("Locked" if locked else "Open", pr.end.x - 14, y, 10.0, g.UI_BAD_L if locked else g.UI_GOOD_L, g.UI_BAD if locked else g.UI_GOOD, "right")
		y += 20
		if locked and y < pr.end.y - 30:
			var gd: Dictionary = W.gates.get(gid, {})
			for ln2 in g.wrap_words(str(gd.get("locked_text", "")), 11, pr.size.x - 40):
				g.text(str(ln2), x + 10, y - 2, 11, g.UI_MUTED, "left")
				y += 14
			y += 4
		if y > pr.end.y - 16:
			break


# returns true if consumed
func tap(p: Vector2) -> bool:
	if not _map_rect.has_point(p):
		return false
	if tab == "region":
		var best := ""
		var ba := 1e18
		for nr in _node_rects:
			var r: Rect2 = nr[0]
			if r.grow(4).has_point(p) and r.get_area() < ba:
				ba = r.get_area()
				best = str(nr[1])
		if best != "":
			sel = best
			return true
	return false
