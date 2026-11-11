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
	"dungeon": Color("#c0504d"), "final": Color("#b84dff"), "secret": Color("#7aa6c2"), "postgame": Color("#7aa6c2"),
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
			im.set_pixel(c, r, col)
	local_tex = ImageTexture.create_from_image(im)


func drag(d: Vector2) -> void:
	pan += d


func zoom_by(f: float) -> void:
	zoom = clampf(zoom * f, 0.6, 3.0)


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
	g.draw_rect(Rect2(0, 0, vw, vh), Color(0.06, 0.12, 0.13, 0.94))
	var short: bool = vh <= 430
	var bh: float = 40.0 if short else 48.0
	g.ui_button("map_back", Rect2(8, 6, 104.0 if short else 120.0, bh), "BACK", true, 16, 28, func(): g.close_world_map())
	var tw: float = 118.0 if short else 132.0
	g.ui_button("map_tab_r", Rect2(vw / 2 - tw - 4, 6, tw, bh), "REGION", tab != "region", 15, 28, func(): tab = "region")
	g.ui_button("map_tab_l", Rect2(vw / 2 + 4, 6, tw, bh), "LOCAL", tab != "local", 15, 28, func(): tab = "local")
	var zb: float = bh
	g.sq_button("map_zin", Rect2(vw - 8 - zb, 6, zb, zb), "+", func(): zoom_by(1.25))
	g.sq_button("map_zout", Rect2(vw - 16 - 2 * zb, 6, zb, zb), "-", func(): zoom_by(0.8))
	var top: float = 6 + bh + 6
	var info_w: float = 0.0 if vw < 640 else minf(280.0, vw * 0.3)
	_map_rect = Rect2(8, top, vw - 16 - info_w - (8 if info_w > 0 else 0), vh - top - 8)
	if info_w == 0.0:
		_map_rect.size.y -= 74.0
	g.draw_rect(_map_rect, Color(0.13, 0.3, 0.32, 1))
	if tab == "region":
		_draw_region(g, now)
	else:
		_draw_local(g, now, px, py)
	# details panel
	var pr: Rect2
	if info_w > 0:
		pr = Rect2(vw - 8 - info_w, top, info_w, vh - top - 8)
	else:
		pr = Rect2(8, vh - 8 - 70, vw - 16, 70)
	g.draw_rect(pr, Color(0.98, 0.93, 0.8, 0.96))
	_draw_info(g, pr, info_w == 0.0)


func _to_screen(m: Vector2) -> Vector2:
	var mr := _map_rect.grow(-28)
	var base := Vector2(mr.position.x + m.x / 100.0 * mr.size.x, mr.position.y + m.y / 100.0 * mr.size.y)
	var c := _map_rect.get_center()
	return c + (base - c) * zoom + pan


func _draw_region(g: Object, now: float) -> void:
	var fs: float = clampf(_map_rect.size.x * 0.016, 10.0, 13.0) * clampf(zoom, 1.0, 1.6)
	# links
	for l in W.links:
		var ld: Dictionary = l
		var a: Dictionary = W.area(str(ld.from))
		var b: Dictionary = W.area(str(ld.to))
		if a.is_empty() or b.is_empty():
			continue
		var pa: Vector2 = _to_screen(Vector2(a.map[0], a.map[1]))
		var pb: Vector2 = _to_screen(Vector2(b.map[0], b.map[1]))
		var gid: String = str(ld.get("gate", ""))
		var optional: bool = bool(a.get("optional", false)) or bool(b.get("optional", false))
		var col := Color(1, 0.95, 0.8, 0.85)
		if optional:
			col = Color(0.8, 0.9, 1.0, 0.6)
		g.draw_line(pa, pb, Color(0, 0, 0, 0.5), 5.0)
		g.draw_line(pa, pb, col, 2.5)
		if gid != "":
			var mid: Vector2 = (pa + pb) / 2.0
			var open: bool = W.gate_open(gid)
			_lock_icon(g, mid, open)
	# nodes
	for id in W.area_order:
		var a2: Dictionary = W.area(id)
		var p: Vector2 = _to_screen(Vector2(a2.map[0], a2.map[1]))
		var kcol: Color = KIND_COL.get(str(a2.kind), Color.WHITE)
		var built: String = str(a2.get("built", "planned"))
		var r: float = 9.0 if str(a2.kind) == "town" or str(a2.kind) == "final" else 7.0
		r *= clampf(zoom, 1.0, 1.5)
		var fill: Color = kcol if built != "planned" else Color(kcol.r, kcol.g, kcol.b, 0.45)
		g.draw_circle(p, r + 2.5, Color(0, 0, 0, 0.7))
		g.draw_circle(p, r, fill)
		if built == "walkable":
			g.draw_arc(p, r + 4.0, 0, TAU, 24, Color(1, 1, 1, 0.9), 1.5)
		if id == sel:
			g.draw_arc(p, r + 7.0, 0, TAU, 24, Color("#ffe27a"), 2.5)
		if id == W.cur_area:
			var pulse: float = 0.5 + 0.5 * sin(now / 220.0)
			g.draw_arc(p, r + 9.0 + pulse * 4.0, 0, TAU, 28, Color(0.4, 0.9, 1.0, 0.95), 3.0)
			g.text("YOU", p.x, p.y - r - 16, fs, Color("#9ff0ff"), "center", 3, Color(0, 0, 0, 0.9))
		var label: String = str(a2.name)
		g.text(label, p.x, p.y + r + fs * 0.9, fs, Color.WHITE if built != "planned" else Color(1, 1, 1, 0.75), "center", 3, Color(0, 0, 0, 0.9))
		g.text(W.rec_text(id), p.x, p.y + r + fs * 2.0, fs * 0.85, Color("#ffd98a"), "center", 3, Color(0, 0, 0, 0.9))
		_node_rects.append([Rect2(p.x - 26, p.y - 16, 52, 40), id])
	# legend
	var lx: float = _map_rect.position.x + 10
	var ly: float = _map_rect.end.y - 14
	var items: Array = [["town", "Town"], ["wild", "Wild"], ["route", "Route"], ["dungeon", "Dungeon"], ["final", "Final"]]
	for it in items:
		g.draw_circle(Vector2(lx + 5, ly), 5, KIND_COL[it[0]])
		g.text(it[1], lx + 14, ly, 11, Color.WHITE, "left", 2, Color(0, 0, 0, 0.9))
		lx += 22 + g.text_w(it[1], 11) + 6
	_lock_icon(g, Vector2(lx + 6, ly), false)
	g.text("Story gate", lx + 16, ly, 11, Color.WHITE, "left", 2, Color(0, 0, 0, 0.9))


func _lock_icon(g: Object, p: Vector2, open: bool) -> void:
	var col: Color = Color("#58d68d") if open else Color("#ff5a4a")
	g.draw_rect(Rect2(p.x - 6, p.y - 2, 12, 9), Color(0, 0, 0, 0.8))
	g.draw_rect(Rect2(p.x - 5, p.y - 1, 10, 7), col)
	g.draw_arc(p + Vector2(0, -2), 4.0, PI, TAU if not open else PI * 1.6, 10, col, 2.0)


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
	var pp := o + Vector2(px / W.TILE * s, py / W.TILE * s)
	var pulse: float = 0.5 + 0.5 * sin(now / 200.0)
	g.draw_circle(pp, 4.0 + pulse * 3.0, Color(0.4, 0.9, 1.0, 0.5))
	g.draw_circle(pp, 3.5, Color.WHITE)


func _draw_info(g: Object, pr: Rect2, compact: bool) -> void:
	var id: String = sel if sel != "" else W.cur_area
	var a: Dictionary = W.area(id)
	if a.is_empty():
		return
	var x: float = pr.position.x + 12
	var y: float = pr.position.y + 16
	var ink := Color("#3a2412")
	var fs: float = 15.0 if compact else 18.0
	g.text(str(a.name), x, y, fs, Color("#1c4f8a"), "left")
	var acts: Dictionary = W.data.get("acts", {})
	var line2: String = "Recommended " + W.rec_text(id) + "  ·  " + str(a.kind).capitalize() + ("  ·  optional" if bool(a.get("optional", false)) else "")
	if compact:
		g.text(line2 + "  ·  " + _status(id), x, y + 20, 12, ink, "left")
		g.text(str(a.get("blurb", "")), x, y + 38, 12, ink, "left")
		return
	y += 24
	g.text(str(acts.get(str(int(a.act)), "")), x, y, 13, Color("#7a4a1c"), "left")
	y += 20
	g.text(line2, x, y, 13, ink, "left")
	y += 20
	g.text(_status(id), x, y, 13, Color("#1c6a3a") if str(a.get("built", "")) == "walkable" else Color("#9e2c2c"), "left")
	y += 24
	for ln in g.wrap_words(str(a.get("blurb", "")), 13, pr.size.x - 24):
		g.text(str(ln), x, y, 13, ink, "left")
		y += 18
	y += 6
	g.text("Connects to:", x, y, 13, Color("#7a4a1c"), "left")
	y += 18
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
		var tag: String = ""
		if gid != "":
			tag = "  (open)" if W.gate_open(gid) else "  (locked)"
		g.text("· " + W.area_name(other) + tag, x, y, 12, ink if gid == "" or W.gate_open(gid) else Color("#9e2c2c"), "left")
		y += 16
		if gid != "" and not W.gate_open(gid) and y < pr.end.y - 30:
			var gd: Dictionary = W.gates.get(gid, {})
			for ln2 in g.wrap_words(str(gd.get("locked_text", "")), 11, pr.size.x - 34):
				g.text(str(ln2), x + 10, y, 11, Color("#6b4a2a"), "left")
				y += 14
		if y > pr.end.y - 16:
			break


# returns true if consumed
func tap(p: Vector2) -> bool:
	if not _map_rect.has_point(p):
		return false
	if tab == "region":
		var best := ""
		var bd := 1e9
		for nr in _node_rects:
			var r: Rect2 = nr[0]
			if r.grow(6).has_point(p):
				var d: float = r.get_center().distance_to(p)
				if d < bd:
					bd = d
					best = str(nr[1])
		if best != "":
			sel = best
			return true
	return false
