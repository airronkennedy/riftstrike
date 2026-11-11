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
var styles: Array = [] # biome looks from world_tiles.json "styles" (code tints only, no extra art)
var style_ids: Dictionary = {} # style name -> index
var style_grid := PackedInt32Array() # per tile style index or -1
var spawns: Dictionary = {} # area id -> Vector2i spawn tile (debug ?warp= and tests)

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
const C_BRIDGE := 61 # = wooden bridge / boardwalk over water (walkable)
const C_FLOOR := 44 # , stone floor (dungeon interiors, plazas)
const C_RUBBLE := 59 # ; rubble floor: dungeon floor where monsters lurk (encounters like wild grass)
const C_WALL := 35 # # dungeon / cliff wall (blocks)
const C_LAVA := 76 # L molten rock (blocks)
const C_ICE := 95 # _ frozen lake / packed snow road (walkable)


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
	var st_cfg: Dictionary = tiles_cfg.get("styles", {})
	for sk in st_cfg:
		style_ids[str(sk)] = styles.size()
		styles.append(_parse_style(st_cfg[sk]))
	style_grid.resize(W * H)
	style_grid.fill(-1)
	for a in tiles_cfg.get("areas", []):
		var ad: Dictionary = a
		var idx: int = area_ids.size()
		if ad.has("spawn"):
			spawns[canon(str(ad.id))] = Vector2i(int(ad.spawn[0]), int(ad.spawn[1]))
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
						if ad.has("style"):
							style_grid[y * W + x] = int(style_ids.get(str(ad.style), -1))
	# Zone looks override their area (e.g. a crystal canyon inside the red steppe).
	for a2 in tiles_cfg.get("areas", []):
		for z2 in (a2 as Dictionary).get("zones", []):
			var zd2: Dictionary = z2
			if not zd2.has("style"):
				continue
			var si: int = int(style_ids.get(str(zd2.style), -1))
			for rc2 in zd2.get("rects", []):
				var q2: Array = rc2
				for y2 in range(int(q2[1]), int(q2[3]) + 1):
					for x2 in range(int(q2[0]), int(q2[2]) + 1):
						if x2 >= 0 and y2 >= 0 and x2 < W and y2 < H:
							style_grid[y2 * W + x2] = si
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


func _parse_style(v: Variant) -> Dictionary:
	var d: Dictionary = v if v is Dictionary else {}
	var out: Dictionary = {}
	for k in ["grass", "overlay", "tree", "wild", "floor", "wall", "rock", "road", "water", "map"]:
		if d.has(k):
			var a: Array = d[k]
			out[k] = Color(float(a[0]), float(a[1]), float(a[2]), float(a[3]) if a.size() > 3 else 1.0)
	out["snow"] = bool(d.get("snow", false))
	out["embers"] = bool(d.get("embers", false))
	return out


func style_at(c: int, r: int) -> Dictionary:
	if c < 0 or r < 0 or c >= W or r >= H:
		return {}
	var i: int = style_grid[r * W + c]
	return styles[i] if i >= 0 else {}


func spawn_pos(id: String) -> Vector2:
	var aid: String = canon(id)
	if spawns.has(aid):
		var t: Vector2i = spawns[aid]
		return Vector2(t.x * TILE + 32.0, t.y * TILE + 40.0)
	if area_bbox.has(aid):
		var bb: Rect2i = area_bbox[aid]
		for rr in range(bb.position.y, bb.end.y):
			for cc in range(bb.position.x, bb.end.x):
				if area_at(cc * TILE + 32.0, rr * TILE + 32.0) == aid and not tile_blocked(cc, rr) and not blocked_at(cc * TILE + 32.0, rr * TILE + 40.0):
					return Vector2(cc * TILE + 32.0, rr * TILE + 40.0)
	return start_pos()


func ch_at(c: int, r: int) -> int:
	if c < 0 or r < 0 or c >= W or r >= H:
		return C_WATER
	return grid[r * W + c]


func is_land(c: int, r: int) -> bool:
	var ch: int = ch_at(c, r)
	return ch != C_WATER and ch != C_BRIDGE


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
				var tp: Dictionary = {"kind": "tree", "x": c * TILE + 32.0 + jx, "y": r * TILE + 54.0, "s": sc, "ph": hv % 4, "fw": 192.0, "fh": 192.0, "n": 4, "ax": 96.0, "ay": 178.0, "img": "tree", "fps": 6.0}
				var ts: Dictionary = style_at(c, r)
				if ts.has("tree"):
					tp["mod"] = ts.tree
				_add_prop(tp)
			elif ch == C_ROCK:
				var rp: Dictionary = {"kind": "rock", "x": c * TILE + 32.0, "y": r * TILE + 46.0, "s": 0.8, "ph": hv % 8, "fw": 128.0, "fh": 128.0, "n": 8, "ax": 64.0, "ay": 72.0, "img": "rocks1" if hv % 2 == 0 else "rocks3", "fps": 7.0}
				var rs: Dictionary = style_at(c, r)
				if rs.has("rock"):
					rp["mod"] = rs.rock
				_add_prop(rp)
	for p in tiles_cfg.get("props", []):
		var pr: Dictionary = make_prop(p)
		if not pr.is_empty():
			_add_prop(pr)


# Sprite sheet layout per prop image key (all Tiny Swords, see docs/ASSET_LICENSES.md).
# fw/fh frame size, n frames on row 0, ax/ay foot anchor, bw/bh foot block at s=1 (0 = walk-through).
const PROP_DEFS := {
	"tower": {"fw": 128, "fh": 256, "ax": 64, "ay": 235, "bw": 97, "bh": 43, "by": 37},
	"tower_red": {"fw": 128, "fh": 256, "ax": 64, "ay": 235, "bw": 97, "bh": 43, "by": 37},
	"tower_yellow": {"fw": 128, "fh": 256, "ax": 64, "ay": 235, "bw": 97, "bh": 43, "by": 37},
	"tower_purple": {"fw": 128, "fh": 256, "ax": 64, "ay": 235, "bw": 97, "bh": 43, "by": 37},
	"tower_ruin": {"fw": 128, "fh": 256, "ax": 64, "ay": 235, "bw": 80, "bh": 30},
	"ghouse": {"fw": 128, "fh": 192, "ax": 64, "ay": 171, "bw": 70, "bh": 36, "by": 24},
	"ghouse_ruin": {"fw": 128, "fh": 192, "ax": 64, "ay": 171, "bw": 60, "bh": 28},
	"house_blue": {"fw": 128, "fh": 192, "ax": 64, "ay": 171, "bw": 74, "bh": 38},
	"house_red": {"fw": 128, "fh": 192, "ax": 64, "ay": 171, "bw": 74, "bh": 38},
	"house_yellow": {"fw": 128, "fh": 192, "ax": 64, "ay": 171, "bw": 74, "bh": 38},
	"house_purple": {"fw": 128, "fh": 192, "ax": 64, "ay": 171, "bw": 74, "bh": 38},
	"house_ruin": {"fw": 128, "fh": 192, "ax": 64, "ay": 171, "bw": 60, "bh": 28},
	"castle_blue": {"fw": 320, "fh": 256, "ax": 160, "ay": 228, "bw": 250, "bh": 70},
	"castle_red": {"fw": 320, "fh": 256, "ax": 160, "ay": 228, "bw": 250, "bh": 70},
	"castle_yellow": {"fw": 320, "fh": 256, "ax": 160, "ay": 228, "bw": 250, "bh": 70},
	"castle_purple": {"fw": 320, "fh": 256, "ax": 160, "ay": 228, "bw": 250, "bh": 70},
	"castle_ruin": {"fw": 320, "fh": 256, "ax": 160, "ay": 228, "bw": 220, "bh": 50},
	"wtower": {"fw": 256, "fh": 192, "ax": 128, "ay": 172, "bw": 90, "bh": 30, "n": 4, "fps": 6},
	"goldmine": {"fw": 192, "fh": 128, "ax": 96, "ay": 112, "bw": 150, "bh": 40},
	"rocks1": {"fw": 128, "fh": 128, "ax": 64, "ay": 72, "bw": 36, "bh": 22, "n": 8, "fps": 7},
	"rocks2": {"fw": 128, "fh": 128, "ax": 64, "ay": 72, "bw": 0, "bh": 0, "n": 8, "fps": 7},
	"rocks3": {"fw": 128, "fh": 128, "ax": 64, "ay": 72, "bw": 36, "bh": 22, "n": 8, "fps": 7},
	"rocks4": {"fw": 128, "fh": 128, "ax": 64, "ay": 72, "bw": 0, "bh": 0, "n": 8, "fps": 7},
	"sheep": {"fw": 128, "fh": 128, "ax": 64, "ay": 86, "bw": 30, "bh": 14, "n": 8, "fps": 8},
	"pawn": {"fw": 192, "fh": 192, "ax": 96, "ay": 134, "bw": 26, "bh": 14, "n": 6, "fps": 7},
	"warrior": {"fw": 192, "fh": 192, "ax": 96, "ay": 134, "bw": 26, "bh": 14, "n": 6, "fps": 7},
	"archer": {"fw": 192, "fh": 192, "ax": 96, "ay": 134, "bw": 26, "bh": 14, "n": 6, "fps": 7},
	"fire": {"fw": 128, "fh": 128, "ax": 64, "ay": 104, "bw": 28, "bh": 14, "n": 7, "fps": 10},
	"deco16": {"fw": 64, "fh": 128, "ax": 32, "ay": 118, "bw": 0, "bh": 0},
	"deco17": {"fw": 128, "fh": 128, "ax": 64, "ay": 116, "bw": 0, "bh": 0},
	"deco18": {"fw": 192, "fh": 192, "ax": 96, "ay": 170, "bw": 30, "bh": 16},
}


func make_prop(p: Dictionary) -> Dictionary:
	# Props from world_tiles.json: {"img", "x", "y" (tile units, may be fractional), "s", "flip", "mod", "note"}.
	var im: String = str(p.get("img", "tower"))
	var px: float = float(p.x) * TILE + 32.0
	var py: float = float(p.y) * TILE + 48.0
	var sc: float = float(p.get("s", 0.8))
	var pr: Dictionary = {"kind": im, "x": px, "y": py, "s": sc, "ph": int(absf(px * 7.0 + py * 3.0)) % 8, "n": 1, "img": im, "fps": 1.0, "flip": bool(p.get("flip", false))}
	var df: Dictionary = PROP_DEFS.get(im, {})
	if df.is_empty() and im.begins_with("deco"):
		df = {"fw": 64, "fh": 64, "ax": 32, "ay": 54, "bw": 0, "bh": 0}
	if df.is_empty():
		return {}
	pr["fw"] = float(df.fw)
	pr["fh"] = float(df.fh)
	pr["ax"] = float(df.ax)
	pr["ay"] = float(df.ay)
	pr["n"] = int(df.get("n", 1))
	pr["fps"] = float(df.get("fps", 1))
	if p.has("mod"):
		var m: Array = p.mod
		pr["mod"] = Color(float(m[0]), float(m[1]), float(m[2]), float(m[3]) if m.size() > 3 else 1.0)
	var bw: float = float(df.bw) * sc
	var bh: float = float(df.bh) * sc
	if bool(p.get("walk", false)):
		bw = 0.0
	if bw > 0.0:
		pr["block"] = Rect2(px - bw / 2.0, py - float(df.get("by", float(df.bh) * 0.7)) * sc, bw, bh)
	return pr


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
	if ch == C_WATER or ch == C_TREE or ch == C_ROCK or ch == C_WALL or ch == C_LAVA:
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
	var ch: int = ch_at(int(floor(x / TILE)), int(floor(y / TILE)))
	return ch == C_WILD or ch == C_RUBBLE


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
	var elev: Texture2D = g.IMG.get("elev", null)
	var bridge: Texture2D = g.IMG.get("bridge", null)
	var ff: int = int(floorf(now / 110.0)) % 8
	# tinted water (frozen sea, bog water) under everything else
	for r in range(r0, r1 + 1):
		for c in range(c0, c1 + 1):
			var chw: int = ch_at(c, r)
			if chw == C_WATER or chw == C_BRIDGE:
				var sw: Dictionary = style_at(c, r)
				if chw == C_BRIDGE and (ch_at(c - 1, r) == C_LAVA or ch_at(c + 1, r) == C_LAVA or ch_at(c, r - 1) == C_LAVA or ch_at(c, r + 1) == C_LAVA):
					g.draw_rect(Rect2(c * TILE, r * TILE, TILE, TILE), Color(0.85, 0.3, 0.08))
				elif sw.has("water"):
					g.draw_rect(Rect2(c * TILE, r * TILE, TILE, TILE), sw.water)
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
			if ch == C_WATER or ch == C_BRIDGE:
				continue
			var sx: int = _edge_i(is_land(c - 1, r), is_land(c + 1, r))
			var sy: int = _edge_i(is_land(c, r - 1), is_land(c, r + 1))
			var st: Dictionary = style_at(c, r)
			var tint: Color = wild_tint if ch == C_WILD else Color.WHITE
			if st.has("grass"):
				tint = tint * (st.grass as Color)
			g.img(flat, sx * 64, sy * 64, 64, 64, c * TILE, r * TILE, 64, 64, tint)
			if ch == C_ICE:
				g.draw_rect(Rect2(c * TILE, r * TILE, TILE, TILE), Color(0.86, 0.95, 1.0, 0.86))
				if _hash(c, r) % 5 == 0:
					g.draw_line(Vector2(c * TILE + 10, r * TILE + 18), Vector2(c * TILE + 40, r * TILE + 34), Color(1, 1, 1, 0.9), 2.0)
			elif st.has("overlay") and ch != C_FLOOR and ch != C_RUBBLE and ch != C_WALL:
				g.draw_rect(Rect2(c * TILE, r * TILE, TILE, TILE), st.overlay)
	# sand / road layer (autotiled against other sand)
	for r in range(r0, r1 + 1):
		for c in range(c0, c1 + 1):
			var ch2: int = ch_at(c, r)
			if ch2 != C_SAND and ch2 != C_GATE and ch2 != C_FLOOR and ch2 != C_RUBBLE:
				continue
			var st2: Dictionary = style_at(c, r)
			if ch2 == C_FLOOR or ch2 == C_RUBBLE:
				# Flagstones drawn in code: a tinted base, per-stone shading and mortar seams.
				var fc: Color = st2.get("floor", Color(0.66, 0.66, 0.7))
				var base: Color = fc * Color(0.72, 0.72, 0.72)
				if ch2 == C_RUBBLE:
					base = base.darkened(0.12)
				g.draw_rect(Rect2(c * TILE, r * TILE, TILE, TILE), base)
				var hf: int = _hash(c, r)
				for k in 4:
					var sx3: float = c * TILE + float(k % 2) * 32.0 + (16.0 if (r * 2 + k / 2) % 2 == 1 and k % 2 == 0 else 0.0)
					var sy3: float = r * TILE + float(k / 2) * 32.0
					var sh: float = float((hf >> k) % 5) * 0.035
					g.draw_rect(Rect2(sx3 + 2, sy3 + 2, 28, 28), base.lightened(0.06 + sh))
				var seam := Color(0, 0, 0, 0.18)
				g.draw_line(Vector2(c * TILE, r * TILE + 1), Vector2(c * TILE + 64, r * TILE + 1), seam, 2.0)
				g.draw_line(Vector2(c * TILE, r * TILE + 33), Vector2(c * TILE + 64, r * TILE + 33), seam, 2.0)
				if ch2 == C_RUBBLE and hf % 3 == 0:
					g.draw_line(Vector2(c * TILE + 8, r * TILE + 12), Vector2(c * TILE + 30, r * TILE + 28), Color(0, 0, 0, 0.3), 2.0)
					g.draw_line(Vector2(c * TILE + 30, r * TILE + 28), Vector2(c * TILE + 26, r * TILE + 50), Color(0, 0, 0, 0.3), 2.0)
				continue
			var sx2: int = _edge_i(_sandy(c - 1, r), _sandy(c + 1, r))
			var sy2: int = _edge_i(_sandy(c, r - 1), _sandy(c, r + 1))
			g.img(flat, 320 + sx2 * 64, sy2 * 64, 64, 64, c * TILE, r * TILE, 64, 64, st2.get("road", Color.WHITE))
	# walls, lava, bridges
	for r in range(r0, r1 + 1):
		for c in range(c0, c1 + 1):
			var ch4: int = ch_at(c, r)
			if ch4 == C_WALL:
				var st4: Dictionary = style_at(c, r)
				var wc: Color = st4.get("wall", Color(0.78, 0.8, 0.86))
				var wl: bool = ch_at(c - 1, r) == C_WALL
				var wr: bool = ch_at(c + 1, r) == C_WALL
				var wu: bool = ch_at(c, r - 1) == C_WALL
				var wd: bool = ch_at(c, r + 1) == C_WALL
				var ex: int = _edge_i(wl, wr)
				if elev == null:
					g.draw_rect(Rect2(c * TILE, r * TILE, TILE, TILE), wc.darkened(0.4))
				elif wd:
					# plateau top (autotiled 3x3, col 3 = single-wide)
					g.img(elev, ex * 64, _edge_i(wu, true) * 64, 64, 64, c * TILE, r * TILE, 64, 64, wc)
				else:
					# bottom row of a wall: cliff face
					g.img(elev, ex * 64, 3 * 64, 64, 64, c * TILE, r * TILE, 64, 64, wc)
			elif ch4 == C_LAVA:
				var pulse: float = 0.5 + 0.5 * sin(now / 380.0 + float(c) * 0.9 + float(r) * 0.6)
				g.draw_rect(Rect2(c * TILE, r * TILE, TILE, TILE), Color(0.78, 0.22, 0.06).lerp(Color(1.0, 0.55, 0.12), pulse * 0.6))
				var hv4: int = _hash(c, r)
				g.draw_rect(Rect2(c * TILE + float(hv4 % 40), r * TILE + float((hv4 / 7) % 40), 18, 10), Color(0.35, 0.08, 0.04, 0.55))
				g.draw_circle(Vector2(c * TILE + float((hv4 * 3) % 56) + 4, r * TILE + float((hv4 * 5) % 56) + 4), 3.0 + 2.0 * pulse, Color(1.0, 0.85, 0.3, 0.8))
			elif ch4 == C_BRIDGE:
				var horiz: bool = _bridgeish(c - 1, r) or _bridgeish(c + 1, r)
				var vert: bool = _bridgeish(c, r - 1) or _bridgeish(c, r + 1)
				if bridge == null:
					g.draw_rect(Rect2(c * TILE + 4, r * TILE + 4, 56, 56), Color(0.6, 0.42, 0.24))
				elif horiz and not vert:
					var bx: int = 1
					if not _bridgeish(c - 1, r):
						bx = 0
					elif not _bridgeish(c + 1, r):
						bx = 2
					g.img(bridge, bx * 64, 0, 64, 64, c * TILE, r * TILE, 64, 64)
				else:
					var by: int = 2
					if not _bridgeish(c, r - 1):
						by = 1
					elif not _bridgeish(c, r + 1):
						by = 3
					g.img(bridge, 0, by * 64, 64, 64, c * TILE, r * TILE, 64, 64)
	# wild-grass tufts, bushes, rubble, gate markers
	for r in range(r0, r1 + 1):
		for c in range(c0, c1 + 1):
			var ch3: int = ch_at(c, r)
			var hv: int = _hash(c, r)
			if ch3 == C_WILD:
				var st3: Dictionary = style_at(c, r)
				var tt: Color = st3.get("wild", Color.WHITE)
				var sway: float = sin(now / 420.0 + float(c) * 0.7 + float(r) * 0.3) * 1.6
				for k in 3:
					var ox: float = float((hv * (k + 3)) % 44) + 2.0
					var oy: float = float((hv * (k + 7)) % 40) + 6.0
					var tex: Texture2D = g.IMG["deco11"] if (hv + k) % 3 == 0 else g.IMG["deco10"]
					g.img(tex, 0, 0, 64, 64, c * TILE + ox - 24 + sway, r * TILE + oy - 40, 48, 48, tt)
			elif ch3 == C_RUBBLE:
				for k2 in (1 if hv % 5 < 2 else 0):
					var ox2: float = float((hv * (k2 + 3)) % 40) + 4.0
					var oy2: float = float((hv * (k2 + 5)) % 36) + 8.0
					var rt: Texture2D = g.IMG.get("deco06" if (hv + k2) % 2 == 0 else "deco15", g.IMG["deco04"])
					g.img(rt, 0, 0, 64, 64, c * TILE + ox2 - 24, r * TILE + oy2 - 36, 44, 44)
			elif ch3 == C_BUSH:
				var bt: Texture2D = g.IMG["deco0" + str(7 + hv % 3)]
				var sb: Dictionary = style_at(c, r)
				g.img(bt, 0, 0, 64, 64, c * TILE, r * TILE - 8, 64, 64, sb.get("tree", Color.WHITE))
			elif ch3 == C_GATE:
				var gid: String = gate_at_tile(c, r)
				if gid != "" and not gate_open(gid):
					var pulse2: float = 0.55 + 0.25 * sin(now / 260.0)
					g.draw_rect(Rect2(c * TILE + 4, r * TILE + 4, 56, 56), Color(0.85, 0.2, 0.15, 0.28 * pulse2))
					g.img(g.IMG.rocks3, (hv % 8) * 128, 0, 128, 128, c * TILE - 16, r * TILE - 28, 96, 96)
	# falling snow / drifting embers for some looks (screen-cheap: a few dots per visible tile row)
	for r in range(r0, r1 + 1, 2):
		for c in range(c0, c1 + 1, 2):
			var se: Dictionary = style_at(c, r)
			if se.is_empty():
				continue
			if bool(se.get("snow", false)):
				var hs: int = _hash(c, r)
				var fy: float = fmod(now / 22.0 + float(hs), 128.0)
				var fx: float = float(hs % 100) + sin(now / 700.0 + float(hs)) * 8.0
				g.draw_circle(Vector2(c * TILE + fx, r * TILE + fy), 2.2, Color(1, 1, 1, 0.75))
			elif bool(se.get("embers", false)):
				var he: int = _hash(c, r)
				var ey: float = 128.0 - fmod(now / 30.0 + float(he), 128.0)
				var ex2: float = float(he % 100) + sin(now / 500.0 + float(he)) * 6.0
				g.draw_circle(Vector2(c * TILE + ex2, r * TILE + ey), 1.8, Color(1.0, 0.6, 0.2, 0.7))


func _sandy(c: int, r: int) -> bool:
	var ch: int = ch_at(c, r)
	return ch == C_SAND or ch == C_GATE


func _floorish(c: int, r: int) -> bool:
	var ch: int = ch_at(c, r)
	return ch == C_FLOOR or ch == C_RUBBLE or ch == C_WALL or ch == C_GATE


func _bridgeish(c: int, r: int) -> bool:
	var ch: int = ch_at(c, r)
	return ch == C_BRIDGE or ch == C_GATE


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
