extends RefCounted
# Riftstrike overworld: data-driven tile world, named areas, story gates, wild encounters.
# Data: res://data/world.json (graph, rec levels, gates, flags), world_tiles.json (area/gate tile
# rects, props), world_map.txt (one char per 64px tile), encounters.json (wild tables).
# Drawing calls back into the game node (g.img, g.draw_frame, g.text …) during its _draw.

const TILE := 64.0
const CH := 8 # chunk size in tiles for prop buckets

var ok := false
var err := ""
var data: Dictionary = {}
var tiles_cfg: Dictionary = {}
var enc_cfg: Dictionary = {}
var areas: Dictionary = {} # id -> area dict
var area_order: Array = []
var gates: Dictionary = {} # id -> gate dict
var links: Array = []
var W := 0
var H := 0
var grid := PackedByteArray()
var area_grid := PackedInt32Array()
var gate_grid := PackedInt32Array()
var area_ids: Array = []
var gate_ids: Array = []
var chunks: Dictionary = {} # int key -> Array of prop dicts
var CW := 0
var CHH := 0
var flags: Dictionary = {}
var gates_enabled := true
var folded: Dictionary = {} # retired area id -> kept area id
var flag_aliases: Dictionary = {}
var zones: Array = [] # [{name, area, rects}] named parts inside an area
var area_bbox: Dictionary = {} # id -> Rect2i of its tile rects

# runtime
var cur_area := ""
var cur_zone := ""
var banner_t := -1.0
var banner_area := ""
var toast := ""
var toast_t := -1.0
var step_acc := 0.0
var steps_since := 0
var grace := 0
var enc_mult := 1.0
var last_x := 0.0
var last_y := 0.0

const C_WATER := 126 # ~
const C_GRASS := 46 # .
const C_SAND := 58 # :
const C_WILD := 34 # "
const C_TREE := 84 # T
const C_ROCK := 82 # R
const C_BUSH := 98 # b
const C_GATE := 88 # X


func load_all() -> bool:
	data = _read_json("res://data/world.json")
	tiles_cfg = _read_json("res://data/world_tiles.json")
	enc_cfg = _read_json("res://data/encounters.json")
	if data.is_empty() or tiles_cfg.is_empty():
		err = "world data missing"
		return false
	gates_enabled = bool(data.get("gates_enabled", true))
	folded = data.get("folded", {})
	flag_aliases = data.get("flag_aliases", {})
	for a in data.get("areas", []):
		var ad: Dictionary = a
		areas[str(ad.id)] = ad
		area_order.append(str(ad.id))
	for gt in data.get("gates", []):
		var gd: Dictionary = gt
		gates[str(gd.id)] = gd
	links = data.get("links", [])
	for f in data.get("start_flags", []):
		flags[str(f)] = true
	_load_grid()
	_build_chunks()
	ok = true
	return true


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var txt: String = FileAccess.get_file_as_string(path)
	var v: Variant = JSON.parse_string(txt)
	if v is Dictionary:
		return v
	return {}


func _load_grid() -> void:
	var txt: String = FileAccess.get_file_as_string("res://data/world_map.txt")
	var rows: PackedStringArray = txt.strip_edges(false, true).split("\n")
	H = rows.size()
	W = 0
	for r in rows:
		W = maxi(W, r.length())
	grid.resize(W * H)
	grid.fill(C_WATER)
	for y in H:
		var row: String = rows[y]
		var buf: PackedByteArray = row.to_ascii_buffer()
		for x in buf.size():
			grid[y * W + x] = buf[x]
	area_grid.resize(W * H)
	area_grid.fill(-1)
	gate_grid.resize(W * H)
	gate_grid.fill(-1)
	for a in tiles_cfg.get("areas", []):
		var ad: Dictionary = a
		var idx: int = area_ids.size()
		area_ids.append(canon(str(ad.id)))
		for z in ad.get("zones", []):
			var zd: Dictionary = z
			zones.append({"name": str(zd.get("name", "")), "area": canon(str(ad.id)), "rects": zd.get("rects", [])})
		for rc in ad.get("rects", []):
			var q: Array = rc
			var rr := Rect2i(int(q[0]), int(q[1]), int(q[2]) - int(q[0]) + 1, int(q[3]) - int(q[1]) + 1)
			var aid: String = canon(str(ad.id))
			area_bbox[aid] = rr if not area_bbox.has(aid) else (area_bbox[aid] as Rect2i).merge(rr)
			for y in range(int(q[1]), int(q[3]) + 1):
				for x in range(int(q[0]), int(q[2]) + 1):
					if x >= 0 and y >= 0 and x < W and y < H and area_grid[y * W + x] == -1:
						area_grid[y * W + x] = idx
	for gt in tiles_cfg.get("gates", []):
		var gd: Dictionary = gt
		var gi: int = gate_ids.size()
		gate_ids.append(str(gd.id))
		for rc in gd.get("rects", []):
			var q: Array = rc
			for y in range(int(q[1]), int(q[3]) + 1):
				for x in range(int(q[0]), int(q[2]) + 1):
					if x >= 0 and y >= 0 and x < W and y < H:
						gate_grid[y * W + x] = gi


func ch_at(c: int, r: int) -> int:
	if c < 0 or r < 0 or c >= W or r >= H:
		return C_WATER
	return grid[r * W + c]


func is_land(c: int, r: int) -> bool:
	return ch_at(c, r) != C_WATER


func _hash(c: int, r: int) -> int:
	var h: int = (c * 73856093) ^ (r * 19349663)
	return absi(h) % 1000


func _build_chunks() -> void:
	CW = int(ceil(float(W) / CH))
	CHH = int(ceil(float(H) / CH))
	chunks = {}
	for r in H:
		for c in W:
			var ch: int = grid[r * W + c]
			var hv: int = _hash(c, r)
			if ch == C_TREE:
				var sc: float = 0.56 + float(hv % 4) * 0.035
				var jx: float = float(hv % 13) - 6.0
				_add_prop({"kind": "tree", "x": c * TILE + 32.0 + jx, "y": r * TILE + 54.0, "s": sc, "ph": hv % 4, "fw": 192.0, "fh": 192.0, "n": 4, "ax": 96.0, "ay": 178.0, "img": "tree", "fps": 6.0})
			elif ch == C_ROCK:
				_add_prop({"kind": "rock", "x": c * TILE + 32.0, "y": r * TILE + 46.0, "s": 0.8, "ph": hv % 8, "fw": 128.0, "fh": 128.0, "n": 8, "ax": 64.0, "ay": 72.0, "img": "rocks1" if hv % 2 == 0 else "rocks3", "fps": 7.0})
	for p in tiles_cfg.get("props", []):
		var pd: Dictionary = p
		var im: String = str(pd.get("img", "tower"))
		var px: float = float(pd.x) * TILE + 32.0
		var py: float = float(pd.y) * TILE + 48.0
		var sc2: float = float(pd.get("s", 0.8))
		var pr: Dictionary = {"kind": im, "x": px, "y": py, "s": sc2, "ph": 0, "n": 1, "img": im, "fps": 1.0, "flip": bool(pd.get("flip", false))}
		if im == "tower":
			pr.merge({"fw": 128.0, "fh": 256.0, "ax": 64.0, "ay": 235.0})
			pr["block"] = Rect2(px - 34.0 * sc2 / 0.7, py - 26.0 * sc2 / 0.7, 68.0 * sc2 / 0.7, 30.0 * sc2 / 0.7)
		else:
			pr.merge({"fw": 128.0, "fh": 192.0, "ax": 64.0, "ay": 171.0})
			pr["block"] = Rect2(px - 35.0 * sc2, py - 24.0 * sc2, 70.0 * sc2, 36.0 * sc2)
		_add_prop(pr)


func _add_prop(p: Dictionary) -> void:
	var cx: int = clampi(int(float(p.x) / TILE) / CH, 0, maxi(0, CW - 1))
	var cy: int = clampi(int(float(p.y) / TILE) / CH, 0, maxi(0, CHH - 1))
	var key: int = cy * CW + cx
	if not chunks.has(key):
		chunks[key] = []
	chunks[key].append(p)


# ------------------------------------------------------------- queries
func world_rect() -> Rect2:
	return Rect2(0, 0, W * TILE, H * TILE)


func start_pos() -> Vector2:
	var s: Array = tiles_cfg.get("start", [10, 8])
	return Vector2(float(s[0]) * TILE + 32.0, float(s[1]) * TILE + 40.0)


func area_at(x: float, y: float) -> String:
	var c: int = int(floor(x / TILE))
	var r: int = int(floor(y / TILE))
	if c < 0 or r < 0 or c >= W or r >= H:
		return ""
	var i: int = area_grid[r * W + c]
	return area_ids[i] if i >= 0 else ""


func canon(id: String) -> String:
	# Retired (folded) area ids resolve to the area that absorbed them.
	if areas.has(id):
		return id
	return str(folded.get(id, id))


func area(id: String) -> Dictionary:
	return areas.get(canon(id), {})


func zone_at(x: float, y: float) -> String:
	var c: int = int(floor(x / TILE))
	var r: int = int(floor(y / TILE))
	for z in zones:
		var zd: Dictionary = z
		for rc in zd.rects:
			var q: Array = rc
			if c >= int(q[0]) and c <= int(q[2]) and r >= int(q[1]) and r <= int(q[3]):
				return str(zd.name)
	return ""


func enc_table(area_id: String, zone: String = "") -> Dictionary:
	var tbl: Dictionary = enc_cfg.get("areas", {}).get(canon(area_id), {})
	if zone != "" and tbl.has("zones"):
		var zt: Dictionary = tbl.zones
		if zt.has(zone):
			return zt[zone]
	return tbl


# Player position inside an area's built tiles, 0..1 on each axis (for the region map).
func area_frac(id: String, x: float, y: float) -> Vector2:
	if not area_bbox.has(id):
		return Vector2(0.5, 0.5)
	var bb: Rect2i = area_bbox[id]
	return Vector2(clampf((x / TILE - bb.position.x) / maxf(1.0, bb.size.x), 0.0, 1.0), clampf((y / TILE - bb.position.y) / maxf(1.0, bb.size.y), 0.0, 1.0))


func area_name(id: String) -> String:
	var a: Dictionary = area(id)
	return str(a.get("name", id))


func rec_text(id: String) -> String:
	var a: Dictionary = area(id)
	if a.is_empty():
		return ""
	var lo: int = int(a.get("rec", 1))
	var hi: int = int(a.get("rec_max", lo))
	return "Lv. %d" % lo if hi <= lo else "Lv. %d–%d" % [lo, hi]


func wardens_down() -> int:
	var n := 0
	for w in data.get("wardens", []):
		if flags.get(str(w), false):
			n += 1
	return n


func gate_open(gid: String) -> bool:
	if not gates_enabled:
		return true
	if not gates.has(gid):
		return true
	var gd: Dictionary = gates[gid]
	if not bool(gd.get("enabled", true)):
		return true
	for f in gd.get("flags_all", []):
		if not flags.get(str(f), false):
			return false
	var any: Array = gd.get("flags_any", [])
	if any.size() > 0:
		var hit := false
		for f in any:
			if flags.get(str(f), false):
				hit = true
		if not hit:
			return false
	if wardens_down() < int(gd.get("wardens_min", 0)):
		return false
	return true


func set_flag(f0: String, on: bool = true) -> void:
	var f: String = str(flag_aliases.get(f0, f0))
	if on:
		flags[f] = true
	else:
		flags.erase(f)


func tile_blocked(c: int, r: int) -> bool:
	var ch: int = ch_at(c, r)
	if ch == C_WATER or ch == C_TREE or ch == C_ROCK:
		return true
	if ch == C_GATE:
		var gi: int = gate_grid[r * W + c]
		if gi >= 0 and not gate_open(str(gate_ids[gi])):
			return true
	return false


func gate_at_tile(c: int, r: int) -> String:
	if c < 0 or r < 0 or c >= W or r >= H:
		return ""
	var gi: int = gate_grid[r * W + c]
	return str(gate_ids[gi]) if gi >= 0 else ""


func blocked_at(x: float, y: float) -> bool:
	# Lead's foot box (20x12) against tiles and prop blocks.
	var pts: Array = [Vector2(x - 10, y - 6), Vector2(x + 10, y - 6), Vector2(x - 10, y + 6), Vector2(x + 10, y + 6)]
	for p in pts:
		var v: Vector2 = p
		if tile_blocked(int(floor(v.x / TILE)), int(floor(v.y / TILE))):
			return true
	var fr := Rect2(x - 10, y - 8, 20, 16)
	var cx: int = int(x / TILE) / CH
	var cy: int = int(y / TILE) / CH
	for oy in range(-1, 2):
		for ox in range(-1, 2):
			var key: int = (cy + oy) * CW + (cx + ox)
			if cx + ox < 0 or cy + oy < 0 or cx + ox >= CW or cy + oy >= CHH or not chunks.has(key):
				continue
			for p in chunks[key]:
				var pd: Dictionary = p
				if pd.has("block"):
					var br: Rect2 = pd.block
					if fr.intersects(br):
						return true
	return false


func blocking_gate_near(x: float, y: float, tx: float, ty: float) -> String:
	# Which locked gate (if any) sits just ahead of the lead toward the tap target.
	var d := Vector2(tx - x, ty - y)
	if d.length() < 1.0:
		return ""
	d = d.normalized()
	for k in [16.0, 32.0, 48.0]:
		var p := Vector2(x, y) + d * float(k)
		var gid: String = gate_at_tile(int(floor(p.x / TILE)), int(floor(p.y / TILE)))
		if gid != "" and not gate_open(gid):
			return gid
	return ""


func visible_props(view: Rect2) -> Array:
	var out: Array = []
	var c0: int = maxi(0, int(floor((view.position.x - 128.0) / TILE)) / CH)
	var c1: int = mini(CW - 1, int(floor((view.end.x + 128.0) / TILE)) / CH)
	var r0: int = maxi(0, int(floor((view.position.y - 64.0) / TILE)) / CH)
	var r1: int = mini(CHH - 1, int(floor((view.end.y + 256.0) / TILE)) / CH)
	for cy in range(r0, r1 + 1):
		for cx in range(c0, c1 + 1):
			var key: int = cy * CW + cx
			if chunks.has(key):
				out.append_array(chunks[key])
	return out


func in_wild(x: float, y: float) -> bool:
	return ch_at(int(floor(x / TILE)), int(floor(y / TILE))) == C_WILD


# ------------------------------------------------------------- per-frame logic
# Returns {} or one event: {"enter": id} | {"encounter": {...}}
func tick(x: float, y: float, dt: float, moving: bool) -> Dictionary:
	if banner_t >= 0.0:
		banner_t += dt
		if banner_t > 3200.0:
			banner_t = -1.0
	if toast_t >= 0.0:
		toast_t += dt
		if toast_t > 2600.0:
			toast_t = -1.0
	var out: Dictionary = {}
	var a: String = area_at(x, y)
	cur_zone = zone_at(x, y) if a != "" else ""
	if a != "" and a != cur_area:
		cur_area = a
		banner_area = a
		banner_t = 0.0
		out = {"enter": a}
	var moved: float = Vector2(x - last_x, y - last_y).length()
	last_x = x
	last_y = y
	if moving and moved > 0.0 and in_wild(x, y) and enc_mult > 0.0:
		step_acc += moved
		var step_px: float = float(enc_cfg.get("step_px", 64))
		while step_acc >= step_px:
			step_acc -= step_px
			if grace > 0:
				grace -= 1
				continue
			steps_since += 1
			var tbl: Dictionary = enc_table(a, cur_zone)
			if tbl.is_empty():
				continue
			var rate: float = float(tbl.get("rate", 0.08)) * enc_mult
			if randf() < rate or steps_since >= int(enc_cfg.get("pity_steps", 22)):
				var e: Dictionary = roll_encounter(a, cur_zone)
				if not e.is_empty():
					steps_since = 0
					grace = int(enc_cfg.get("grace_steps", 4))
					step_acc = 0.0
					return {"encounter": e}
	return out


func reset_grace() -> void:
	grace = int(enc_cfg.get("grace_steps", 4))
	step_acc = 0.0


func roll_encounter(area_id0: String, zone: String = "") -> Dictionary:
	var area_id: String = canon(area_id0)
	var tbl: Dictionary = enc_table(area_id, zone)
	var groups: Array = tbl.get("groups", [])
	if groups.is_empty():
		return {}
	var total := 0.0
	for gr in groups:
		total += float(gr.get("weight", 1))
	var roll: float = randf() * total
	var pick: Dictionary = groups[0]
	for gr in groups:
		roll -= float(gr.get("weight", 1))
		if roll <= 0.0:
			pick = gr
			break
	var lv: Array = pick.get("level", [1, 1])
	var level: int = randi_range(int(lv[0]), int(lv[1]))
	var kinds: Array = []
	for k in pick.get("kinds", ["torch"]):
		kinds.append(str(k))
	kinds = kinds.slice(0, 3)
	return {"area": area_id, "kinds": kinds, "level": level}


func enemy_mult(level: int) -> Dictionary:
	var s: Dictionary = enc_cfg.get("scaling", {})
	var mx: float = float(s.get("max", 3.0))
	return {
		"hp": minf(mx, float(s.get("hp_base", 0.4)) + float(s.get("hp_per_level", 0.07)) * level),
		"atk": minf(mx, float(s.get("atk_base", 0.62)) + float(s.get("atk_per_level", 0.045)) * level),
		"def": minf(mx, float(s.get("def_base", 0.7)) + float(s.get("def_per_level", 0.035)) * level),
	}


func encounter_xp(e: Dictionary) -> int:
	var per: int = int(enc_cfg.get("xp_per_level", 9))
	var kinds: Array = e.get("kinds", [])
	return per * int(e.get("level", 1)) * maxi(1, kinds.size())


func show_toast(s: String) -> void:
	if toast_t >= 0.0 and toast == s:
		return
	toast = s
	toast_t = 0.0


func to_save() -> Dictionary:
	return {"flags": flags.keys(), "area": cur_area}


func from_save(d: Dictionary) -> void:
	flags = {}
	for f in d.get("flags", []):
		set_flag(str(f))


# ------------------------------------------------------------- drawing (inside g._draw, camera xf set)
func draw_ground(g: Object, view: Rect2, now: float) -> void:
	var c0: int = maxi(0, int(floor(view.position.x / TILE)) - 1)
	var c1: int = mini(W - 1, int(floor(view.end.x / TILE)) + 1)
	var r0: int = maxi(0, int(floor(view.position.y / TILE)) - 1)
	var r1: int = mini(H - 1, int(floor(view.end.y / TILE)) + 1)
	var flat: Texture2D = g.IMG.flat
	var foam: Texture2D = g.IMG.foam
	var ff: int = int(floorf(now / 110.0)) % 8
	# foam ring under coast tiles
	for r in range(r0, r1 + 1):
		for c in range(c0, c1 + 1):
			if not is_land(c, r):
				continue
			if not is_land(c - 1, r) or not is_land(c + 1, r) or not is_land(c, r - 1) or not is_land(c, r + 1):
				g.img(foam, ((ff + c + r) % 8) * 192, 0, 192, 192, c * TILE - 64, r * TILE - 64, 192, 192)
	var wild_tint := Color(0.74, 0.92, 0.62)
	for r in range(r0, r1 + 1):
		for c in range(c0, c1 + 1):
			var ch: int = ch_at(c, r)
			if ch == C_WATER:
				continue
			var sx: int = _edge_i(is_land(c - 1, r), is_land(c + 1, r))
			var sy: int = _edge_i(is_land(c, r - 1), is_land(c, r + 1))
			var tint: Color = wild_tint if ch == C_WILD else Color.WHITE
			g.img(flat, sx * 64, sy * 64, 64, 64, c * TILE, r * TILE, 64, 64, tint)
	# sand / road layer (autotiled against other sand)
	for r in range(r0, r1 + 1):
		for c in range(c0, c1 + 1):
			var ch2: int = ch_at(c, r)
			if ch2 != C_SAND and ch2 != C_GATE:
				continue
			var sx2: int = _edge_i(_sandy(c - 1, r), _sandy(c + 1, r))
			var sy2: int = _edge_i(_sandy(c, r - 1), _sandy(c, r + 1))
			g.img(flat, 320 + sx2 * 64, sy2 * 64, 64, 64, c * TILE, r * TILE, 64, 64)
	# wild-grass tufts, bushes, gate markers
	for r in range(r0, r1 + 1):
		for c in range(c0, c1 + 1):
			var ch3: int = ch_at(c, r)
			var hv: int = _hash(c, r)
			if ch3 == C_WILD:
				var sway: float = sin(now / 420.0 + float(c) * 0.7 + float(r) * 0.3) * 1.6
				for k in 3:
					var ox: float = float((hv * (k + 3)) % 44) + 2.0
					var oy: float = float((hv * (k + 7)) % 40) + 6.0
					var tex: Texture2D = g.IMG["deco11"] if (hv + k) % 3 == 0 else g.IMG["deco10"]
					g.img(tex, 0, 0, 64, 64, c * TILE + ox - 24 + sway, r * TILE + oy - 40, 48, 48)
			elif ch3 == C_BUSH:
				var bt: Texture2D = g.IMG["deco0" + str(7 + hv % 3)]
				g.img(bt, 0, 0, 64, 64, c * TILE, r * TILE - 8, 64, 64)
			elif ch3 == C_GATE:
				var gid: String = gate_at_tile(c, r)
				if gid != "" and not gate_open(gid):
					var pulse: float = 0.55 + 0.25 * sin(now / 260.0)
					g.draw_rect(Rect2(c * TILE + 4, r * TILE + 4, 56, 56), Color(0.85, 0.2, 0.15, 0.28 * pulse))
					g.img(g.IMG.rocks3, (hv % 8) * 128, 0, 128, 128, c * TILE - 16, r * TILE - 28, 96, 96)


func _sandy(c: int, r: int) -> bool:
	var ch: int = ch_at(c, r)
	return ch == C_SAND or ch == C_GATE


func _edge_i(l_on: bool, r_on: bool) -> int:
	if l_on and r_on:
		return 1
	if r_on:
		return 0
	if l_on:
		return 2
	return 3


func draw_grass_over(g: Object, x: float, y: float, now: float) -> void:
	# Tufts in front of the lead's feet while wading through wild grass.
	if not in_wild(x, y):
		return
	var sway: float = sin(now / 300.0) * 2.0
	g.img(g.IMG["deco10"], 0, 0, 64, 64, x - 30 + sway, y - 30, 40, 40)
	g.img(g.IMG["deco11"], 0, 0, 64, 64, x - 6 - sway, y - 28, 40, 40)


# ------------------------------------------------------------- HUD (screen space)
func draw_hud(g: Object, vw: float, vh: float) -> void:
	if banner_t >= 0.0 and banner_area != "":
		var k: float = banner_t
		var al: float = 1.0
		if k < 400.0:
			al = k / 400.0
		elif k > 2500.0:
			al = maxf(0.0, 1.0 - (k - 2500.0) / 700.0)
		var fs: float = clampf(vw * 0.055, 26.0, 46.0)
		var cy: float = vh * 0.21
		var nm: String = area_name(banner_area)
		var a: Dictionary = area(banner_area)
		var kind: String = str(a.get("kind", ""))
		var lw: float = minf(vw * 0.8, maxf(260.0, g.text_w(nm, fs) + 80.0))
		g.rbox(Rect2(vw / 2 - lw / 2, cy - fs * 0.95, lw, fs * 2.55), 26.0, Color(0.03, 0.1, 0.11, 0.55 * al))
		g.rbox(Rect2(vw / 2 - lw / 2 + 30, cy + fs * 0.6, lw - 60, 3), 1.5, Color(1, 0.9, 0.6, 0.7 * al))
		g.text(nm, vw / 2, cy, fs, Color(1, 0.97, 0.88, al), "center", 4, Color(0, 0, 0, 0.85 * al))
		var sub: String = "Recommended " + rec_text(banner_area)
		if kind == "wild":
			sub += "  ·  wild area"
		g.text(sub, vw / 2, cy + fs * 1.15, clampf(fs * 0.48, 14.0, 20.0), Color(1, 0.88, 0.55, al), "center", 3, Color(0, 0, 0, 0.85 * al))
	if toast_t >= 0.0 and toast != "":
		var al2: float = 1.0 if toast_t < 2100.0 else maxf(0.0, 1.0 - (toast_t - 2100.0) / 500.0)
		var tfs: float = clampf(vw * 0.03, 14.0, 18.0)
		var tw: float = minf(vw * 0.9, g.text_w(toast, tfs) + 40.0)
		var ty: float = vh * 0.66
		g.rbox(Rect2(vw / 2 - tw / 2, ty - tfs, tw, tfs * 2.0), tfs, Color(0.35, 0.08, 0.05, 0.78 * al2))
		g.text(toast, vw / 2, ty, tfs, Color(1, 0.92, 0.85, al2), "center", 3, Color(0, 0, 0, 0.8 * al2))
