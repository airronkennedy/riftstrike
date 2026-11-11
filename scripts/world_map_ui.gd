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
	var short: bool = vh <= 430
	var helper: String = "Tap an area to see its details. Drag to pan." if tab == "region" else "Built tiles of Act I. The white dot is you."
	var area: Rect2 = g.menu_sheet("map_back", "Map", helper, func(): g.close_world_map(), ["Region", "Local"], 0 if tab == "region" else 1, func(i): tab = "region" if i == 0 else "local", "map_tab")
	var info_w: float = 0.0 if area.size.x < 600 else minf(280.0, area.size.x * 0.32)
	var gap: float = 12.0
	var info_h: float = 0.0 if info_w > 0 else (70.0 if short else 92.0)
	_map_rect = Rect2(area.position.x, area.position.y, area.size.x - info_w - (gap if info_w > 0 else 0.0), area.size.y - (info_h + gap if info_h > 0 else 0.0))
	g.rbox(_map_rect, 22.0, Color(0.13, 0.3, 0.32, 1))
	if tab == "region":
		_draw_region(g, now)
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
	var lx: float = _map_rect.position.x + 22
	var ly: float = _map_rect.end.y - 22
	g.rbox(Rect2(_map_rect.position.x + 10, ly - 13, minf(_map_rect.size.x - 20, 470.0), 26), 13.0, Color(0.03, 0.1, 0.11, 0.7))
	var items: Array = [["town", "Town"], ["wild", "Wild"], ["route", "Route"], ["dungeon", "Dungeon"], ["final", "Final"]]
	for it in items:
		g.draw_circle(Vector2(lx + 5, ly), 5, KIND_COL[it[0]])
		g.text(it[1], lx + 14, ly, 11, Color.WHITE, "left", 2, Color(0, 0, 0, 0.9))
		lx += 22 + g.text_w(it[1], 11) + 6
	_lock_icon(g, Vector2(lx + 6, ly), false)
	g.text("Story gate", lx + 16, ly, 11, Color.WHITE, "left", 2, Color(0, 0, 0, 0.9))


func _lock_icon(g: Object, p: Vector2, open: bool) -> void:
	var col: Color = Color("#58d68d") if open else Color("#ff5a4a")
	g.rbox(Rect2(p.x - 6, p.y - 2, 12, 10), 3.0, Color(0, 0, 0, 0.8))
	g.rbox(Rect2(p.x - 5, p.y - 1, 10, 8), 2.5, col)
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
