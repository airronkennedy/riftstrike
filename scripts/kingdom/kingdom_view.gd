class_name KingdomView
extends RefCounted
## Drawing nodes for the kingdom scenes: shader ground, scattered detail layers, y-sorted props and actors with soft
## directional shadows, a parallax foreground of occluders, ambient life, the minimap and the touch joystick.
## Art: assets/kingdom (new kingdom sprites + procedural tiles, see docs/ASSET_LICENSES.md) and assets/af.

const TILE := 64.0
const K := "res://assets/kingdom/"
const GEN := "res://assets/af/gen/"
const SPRITE_SCALE := 2.0 # kingdom sprites are native pixel art drawn at 2x

# Kingdom sprites: bw = footprint width as a fraction of the sprite, bh = footprint depth (native px). chim = chimney
# (fraction of width, fraction of height from the top) for smoke. sway = wind shader. light = warm point light.
const KDEFS := {
	"tree_oak": {"bw": 0.2, "bh": 6, "sway": true}, "tree_pine": {"bw": 0.25, "bh": 6, "sway": true},
	"tree_willow": {"bw": 0.2, "bh": 6, "sway": true}, "bush": {"bw": 0.7, "bh": 8, "sway": true},
	"shrine": {"bw": 0.9, "bh": 10, "light": Vector2(0, -0.85)}, "cave_mouth": {"bw": 0.9, "bh": 14},
	"ruin": {"bw": 0.9, "bh": 14}, "cairn": {"bw": 0.7, "bh": 10}, "well": {"bw": 0.8, "bh": 14},
	"market_stall": {"bw": 0.9, "bh": 12}, "fence": {"bw": 1.0, "bh": 5}, "throne": {"bw": 0.9, "bh": 14},
	"pillar": {"bw": 0.9, "bh": 8}, "banner": {"bw": 0.0, "bh": 0, "sway": true}, "brazier": {"bw": 0.6, "bh": 6, "light": Vector2(0, -0.85)},
	"barrels": {"bw": 0.9, "bh": 12},
	"bld_store": {"bw": 0.78, "bh": 18, "chim": Vector2(0.83, 0.12)}, "bld_inn": {"bw": 0.78, "bh": 18, "chim": Vector2(0.72, 0.05)},
	"bld_cottage": {"bw": 0.8, "bh": 18, "chim": Vector2(0.84, 0.1)}, "bld_townhouse": {"bw": 0.8, "bh": 18, "chim": Vector2(0.2, 0.1)},
	"bld_smithy": {"bw": 0.8, "bh": 18, "chim": Vector2(0.78, 0.06)}, "bld_chapel": {"bw": 0.6, "bh": 18},
	"bld_gatehouse": {"bw": 0.9, "bh": 16}, "bld_tower": {"bw": 0.35, "bh": 14}, "bld_farmhouse": {"bw": 0.7, "bh": 18, "chim": Vector2(0.62, 0.05)},
	"boulder": {"bw": 0.8, "bh": 10}, "stump": {"bw": 0.5, "bh": 6}, "log": {"bw": 0.8, "bh": 6},
	"lamp_post": {"bw": 0.4, "bh": 4, "light": Vector2(0, -0.85)}, "signpost": {"bw": 0.3, "bh": 4}, "hay_bale": {"bw": 0.8, "bh": 12},
	"planter": {"bw": 0.9, "bh": 10, "sway": false},
	"window_stained": {"bw": 0.0, "bh": 0, "light": Vector2(0, -0.5)}, "sconce": {"bw": 0.0, "bh": 0, "light": Vector2(0, -0.8)},
	"armor_stand": {"bw": 0.7, "bh": 8}, "candelabra": {"bw": 0.5, "bh": 6, "light": Vector2(0, -0.8)},
	"banquet_table": {"bw": 0.95, "bh": 18}, "bookshelf": {"bw": 0.95, "bh": 10}, "knight_statue": {"bw": 0.8, "bh": 10},
	"urn_plant": {"bw": 0.6, "bh": 8}, "stairs": {"bw": 0.0, "bh": 0}, "chandelier": {"bw": 0.0, "bh": 0, "light": Vector2(0, -0.4)},
	"weapon_rack": {"bw": 0.9, "bh": 8}, "rug_round": {"bw": 0.0, "bh": 0},
}
# Old Airron's Fall atlas sprites still used (flames, chest).
const DEFS := {
	"fire": {"f": "fx_flame.png", "fw": 128, "fh": 128, "ax": 64, "ay": 104, "bw": 28, "bh": 14, "n": 7},
	"chest": {"f": "res://assets/af/props/ember-chest.png", "fw": 99, "fh": 99, "ax": 50, "ay": 88, "bw": 60, "bh": 24},
}

static var _tex: Dictionary = {}
static var sway_mat: ShaderMaterial
static var add_mat: CanvasItemMaterial


static func tex(path: String) -> Texture2D:
	if not _tex.has(path):
		var full := path
		if not path.begins_with("res://"):
			full = (K + path + ".png") if KDEFS.has(path) or ResourceLoader.exists(K + path + ".png") else GEN + path
		_tex[path] = load(full) if ResourceLoader.exists(full) else null
	return _tex[path]


static func hero_tex(id: String) -> Texture2D:
	return tex("res://assets/af/heroes/%s.png" % id)


static func materials() -> void:
	if sway_mat == null:
		sway_mat = ShaderMaterial.new()
		sway_mat.shader = load("res://shaders/wind_sway.gdshader")
		add_mat = CanvasItemMaterial.new()
		add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		add_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED


## Footprint rect of a kingdom sprite placed with its foot at `at`, or an empty Rect2 if it doesn't block.
static func footprint(kind: String, at: Vector2, s: float) -> Rect2:
	var d: Dictionary = KDEFS.get(kind, {})
	var tx := tex(kind)
	if d.is_empty() or tx == null or float(d.bw) <= 0.0:
		return Rect2()
	var bw: float = tx.get_width() * s * float(d.bw)
	var bh: float = float(d.bh) * s
	return Rect2(at.x - bw / 2.0, at.y - bh, bw, bh + 4.0)


static func soft_shadow(n: CanvasItem, at: Vector2, w: float, alpha: float = 0.32, skew: float = 0.12) -> void:
	# Stacked ellipses, nudged toward the lower right (the key light is upper left): a soft directional contact shadow.
	for i in 3:
		var k := 1.0 - float(i) * 0.2
		var pts := PackedVector2Array()
		for a in 20:
			var t := TAU * float(a) / 20.0
			pts.append(at + Vector2(w * skew * k, 3.0) + Vector2(cos(t) * w * k * 0.55, sin(t) * w * k * 0.17))
		n.draw_colored_polygon(pts, Color(0.02, 0.01, 0.03, alpha * 0.38))


# ------------------------------------------------------------------ ground
class Ground extends Node2D:
	var k
	var mat: ShaderMaterial
	var pad := 0.0
	func setup() -> void:
		mat = ShaderMaterial.new()
		mat.shader = load("res://shaders/kingdom_ground.gdshader")
		for pair in [["t_grass", "grass"], ["t_forest", "forest_floor"], ["t_high", "highland"], ["t_sand", "sand"], ["t_road", "road"],
				["t_cobble", "cobble"], ["t_flag", "flagstone"], ["t_carpet", "carpet"], ["t_wall", "wall"], ["t_cliff", "cliff"]]:
			mat.set_shader_parameter(pair[0], load("res://assets/kingdom/tiles/%s.png" % pair[1]))
		material = mat
	func rebuild() -> void:
		var img := Image.create(k.W, k.H, false, Image.FORMAT_R8)
		for r in k.H:
			for c in k.W:
				img.set_pixel(c, r, Color(float(k.terrain_id(c, r)) / 255.0, 0, 0))
		mat.set_shader_parameter("map_tex", ImageTexture.create_from_image(img))
		mat.set_shader_parameter("map_size", Vector2(k.W, k.H))
		var outdoor: bool = k.map.get("id", "") == "overworld"
		mat.set_shader_parameter("outside_id", 0 if outdoor else (1 if k.map.get("id", "") == "town" else 9))
		mat.set_shader_parameter("clouds", 1.0 if outdoor else 0.0)
		pad = TILE * 14.0 if outdoor else TILE * 6.0
		queue_redraw()
	func _draw() -> void:
		draw_rect(Rect2(-pad, -pad, k.W * TILE + pad * 2.0, k.H * TILE + pad * 2.0), Color.WHITE)


# --------------------------------------------- flat scattered details (drawn once)
class Details extends Node2D:
	var items: Array = [] # {tex, pos, s, flip}
	func _draw() -> void:
		for it in items:
			var tx: Texture2D = it.tex
			if tx == null: continue
			var s: float = it.s
			var w := tx.get_width() * s
			var h := tx.get_height() * s
			var dst := Rect2(it.pos.x - w / 2.0, it.pos.y - h, w, h)
			if it.flip:
				dst = Rect2(dst.end.x, dst.position.y, -w, h)
			draw_texture_rect(tx, dst, false)


# ------------------------------------------------------------- y-sorted prop
class Prop extends Node2D:
	var k
	var kind := ""
	var s := 1.0
	var ph := 0
	var flip := false
	var tint := Color.WHITE
	var animated := false
	func _draw() -> void:
		var t: float = 0.0 if k.reduced_motion else k.t_now
		if kind.begins_with("statue:"):
			var tx := KingdomView.hero_tex(kind.substr(7))
			KingdomView.soft_shadow(self, Vector2(0, 2), 70.0)
			draw_rect(Rect2(-34, -22, 68, 22), Color("#6b5c50"))
			draw_rect(Rect2(-34, -22, 68, 5), Color("#857669"))
			if tx:
				var hh: float = tx.get_height() * s
				var ww: float = tx.get_width() * s
				draw_texture_rect(tx, Rect2(-ww / 2.0, -22 - hh, ww, hh), false, Color(0.62, 0.6, 0.58))
			return
		if KingdomView.KDEFS.has(kind):
			var tx2 := KingdomView.tex(kind)
			if tx2 == null: return
			var w := tx2.get_width() * s
			var h := tx2.get_height() * s
			var d: Dictionary = KingdomView.KDEFS[kind]
			if float(d.bw) > 0.0 or kind.begins_with("tree") or kind == "bush":
				KingdomView.soft_shadow(self, Vector2(0, -2), w * (0.75 if kind.begins_with("bld") else 0.6), 0.42 if kind.begins_with("bld") else 0.36)
			var dst := Rect2(-w / 2.0, -h + 2.0, w, h)
			if flip:
				dst = Rect2(dst.end.x, dst.position.y, -w, h)
			draw_texture_rect(tx2, dst, false, tint)
			return
		var d2: Dictionary = KingdomView.DEFS.get(kind, {})
		if d2.is_empty(): return
		var tx3: Texture2D = KingdomView.tex(str(d2.f))
		var n: int = int(d2.get("n", 1))
		var fr := (int(t * 10.0) + ph) % n if n > 1 else 0
		var fw := float(d2.fw)
		var fh := float(d2.fh)
		if kind != "fire":
			KingdomView.soft_shadow(self, Vector2(0, 0), fw * s * 0.6)
		draw_texture_rect_region(tx3, Rect2(-float(d2.ax) * s, -float(d2.ay) * s, fw * s, fh * s), Rect2(fr * fw, 0, fw, fh))


# ----------------------------------------------------- hero / npc actor
class Actor extends Node2D:
	var k
	var hero := "bramwell"
	var facing := 1.0
	var walking := false
	var is_player := false
	func _draw() -> void:
		var tx := KingdomView.hero_tex(hero)
		var bob := 0.0
		if walking and not k.reduced_motion:
			bob = absf(sin(k.t_now * 11.0)) * 4.0
		elif not k.reduced_motion:
			bob = sin(k.t_now * 2.2 + position.x) * 0.8 # idle breathing
		KingdomView.soft_shadow(self, Vector2(0, 0), 44.0 - bob * 2.0, 0.5)
		if tx == null:
			draw_circle(Vector2(0, -30), 18, AfTheme.EMBER)
			return
		var h := 78.0
		var sc := h / float(tx.get_height())
		var w := float(tx.get_width()) * sc
		var dst := Rect2(-w / 2.0, -h - bob + 6.0, w, h)
		if facing < 0:
			dst = Rect2(w / 2.0, dst.position.y, -w, h)
		draw_texture_rect(tx, dst, false)
		if not is_player and k.near.get("node") == self:
			var y := -h - 16.0 - (0.0 if k.reduced_motion else absf(sin(k.t_now * 4.0)) * 4.0)
			draw_colored_polygon(PackedVector2Array([Vector2(-7, y - 8), Vector2(7, y - 8), Vector2(0, y)]), AfTheme.GOLD)


# --------------------------------------- parallax foreground occluders (closer than the world)
class Foreground extends Node2D:
	var k
	var items: Array = [] # {tex, pos (world), s, dark, par}
	func _draw() -> void:
		var cc: Vector2 = k.cam.get_screen_center_position()
		for it in items:
			var tx: Texture2D = it.tex
			if tx == null: continue
			var p: Vector2 = it.pos + (it.pos - cc) * float(it.par)
			var w := tx.get_width() * float(it.s)
			var h := tx.get_height() * float(it.s)
			# fade an occluder that sits over the hero so the player never loses sight of them
			var pd: float = (p + Vector2(0, -h * 0.5)).distance_to(k.player_pos + (k.player_pos - cc) * float(it.par))
			var al := clampf((pd - w * 0.25) / (w * 0.5), 0.15, 0.96)
			var c: Color = Color(it.dark, it.dark, it.dark * 1.1, al)
			draw_texture_rect(tx, Rect2(p.x - w / 2.0, p.y - h, w, h), false, c)


# ----------------------------------------------- ambient life: birds, butterflies, fireflies
class Life extends Node2D:
	var k
	var flowers: Array = []   # butterfly anchors
	var glow: Array = []      # firefly anchors
	var birds_on := false
	func _draw() -> void:
		if k.reduced_motion:
			return
		var t: float = k.t_now
		# butterflies: small two-tone flappers looping around flowers
		for i in flowers.size():
			var a: Vector2 = flowers[i]
			var ph := float(i) * 1.7
			var p := a + Vector2(sin(t * 0.7 + ph) * 26.0, cos(t * 0.9 + ph * 1.3) * 14.0 - 22.0)
			var flap := absf(sin(t * 14.0 + ph))
			var c: Color = [Color("#f0a066"), Color("#ead266"), Color("#ece3cf"), Color("#9fb7e0")][i % 4]
			draw_rect(Rect2(p.x - 1.0 - 4.0 * flap, p.y - 2, 4.0 * flap, 4), c)
			draw_rect(Rect2(p.x + 1.0, p.y - 2, 4.0 * flap, 4), c)
			draw_rect(Rect2(p.x - 1, p.y - 2, 2, 5), Color(0.1, 0.08, 0.06))
		# fireflies (additive glow)
		for i in glow.size():
			var g: Vector2 = glow[i]
			var ph2 := float(i) * 2.3
			var p2 := g + Vector2(sin(t * 0.5 + ph2) * 30.0, sin(t * 0.37 + ph2 * 0.7) * 20.0 - 30.0)
			var on := 0.5 + 0.5 * sin(t * 2.2 + ph2 * 3.0)
			draw_circle(p2, 7.0, Color(0.9, 0.8, 0.3, 0.12 * on))
			draw_rect(Rect2(p2 - Vector2(1.5, 1.5), Vector2(3, 3)), Color(1.0, 0.92, 0.55, 0.9 * on))
		# a small flock crossing now and then, with ground shadows
		if birds_on:
			var cyc := fmod(t, 26.0) / 14.0
			if cyc <= 1.0:
				var v: Rect2 = k.view_rect()
				var base := Vector2(v.position.x - 60.0 + (v.size.x + 120.0) * cyc, v.position.y + v.size.y * 0.25)
				for j in 4:
					var bp := base + Vector2(-float(j) * 26.0, float(j % 2) * 16.0 + sin(t * 3.0 + j) * 4.0)
					var f := sin(t * 12.0 + float(j))
					draw_polyline(PackedVector2Array([bp + Vector2(-8, -3 * f), bp, bp + Vector2(8, -3 * f)]), Color(0.1, 0.08, 0.07), 2.0)
					draw_circle(bp + Vector2(40, 150), 4.0, Color(0, 0, 0, 0.12))


# ------------------------------------------------------------------ minimap
class Minimap extends Control:
	var k
	var img_tex: ImageTexture
	var big := false
	func rebuild() -> void:
		var img := Image.create(k.W, k.H, false, Image.FORMAT_RGBA8)
		for r in k.H:
			for c in k.W:
				img.set_pixel(c, r, _col(k.ch_at(c, r)))
		img_tex = ImageTexture.create_from_image(img)
		queue_redraw()
	func _col(ch: String) -> Color:
		match ch:
			"~": return Color("#1d3640")
			",": return Color("#8a6a48")
			":": return Color("#b59a6e")
			"f", "T": return Color("#2f4a2c")
			"^": return Color("#6b6a52")
			"#": return Color("#2a2420")
			"c": return Color("#7a2620")
			"P": return Color("#3a312a")
		return Color("#4c5e40")
	func map_rect() -> Rect2:
		var fit: float = minf((size.x - 12.0) / k.W, (size.y - 12.0) / k.H)
		var ms := Vector2(k.W, k.H) * fit
		return Rect2((size - ms) / 2.0, ms)
	func _draw() -> void:
		if img_tex == null:
			return
		draw_style_box(get_theme_stylebox("panel", "Panel"), Rect2(Vector2.ZERO, size))
		var mr := map_rect()
		draw_texture_rect(img_tex, mr, false)
		var sc: float = mr.size.x / float(k.W)
		for s in k.usables:
			if s.get("kind", "") == "spot":
				draw_circle(mr.position + s.pos / TILE * sc, 3.0 if not big else 5.0, AfTheme.GOLD)
		var pp: Vector2 = mr.position + k.player_pos / TILE * sc
		var pulse := 0.0 if k.reduced_motion else 0.5 + 0.5 * sin(k.t_now * 5.0)
		draw_circle(pp, 6.0 + 2.0 * pulse, Color(AfTheme.EMBER, 0.35))
		draw_circle(pp, 4.0, AfTheme.EMBER_LIGHT)
		if big:
			var v: Rect2 = k.view_rect()
			draw_rect(Rect2(mr.position + v.position / TILE * sc, v.size / TILE * sc), Color(AfTheme.INK, 0.6), false, 1.5)
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			k.toggle_big_map()
			accept_event()


# ----------------------------------------- banner ornament (gold rules + diamond, AF style)
class Ornament extends Control:
	func _draw() -> void:
		var c := size / 2.0
		var w := minf(size.x * 0.5, 190.0)
		draw_line(Vector2(c.x - w, c.y), Vector2(c.x - 14, c.y), Color(AfTheme.GOLD, 0.85), 2.0)
		draw_line(Vector2(c.x + 14, c.y), Vector2(c.x + w, c.y), Color(AfTheme.GOLD, 0.85), 2.0)
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -7), c + Vector2(7, 0), c + Vector2(0, 7), c + Vector2(-7, 0)]), AfTheme.EMBER)
		draw_circle(Vector2(c.x - w, c.y), 3.0, AfTheme.GOLD)
		draw_circle(Vector2(c.x + w, c.y), 3.0, AfTheme.GOLD)


# ------------------------------------------- bouncing "more" arrow for the dialog box
class MoreArrow extends Control:
	var k
	func _process(_d: float) -> void:
		queue_redraw()
	func _draw() -> void:
		var y := 0.0 if k.reduced_motion else absf(sin(k.t_now * 4.0)) * 4.0
		var c := Vector2(size.x / 2.0, size.y / 2.0 + y)
		draw_colored_polygon(PackedVector2Array([c + Vector2(-7, -4), c + Vector2(7, -4), c + Vector2(0, 5)]), AfTheme.GOLD)


# ------------------------------------------------------------- touch joystick
class Joystick extends Control:
	var k
	var vec := Vector2.ZERO
	var active := false
	var knob := Vector2.ZERO
	func _gui_input(e: InputEvent) -> void:
		var R := size.x * 0.5
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			active = e.pressed
			if not active:
				vec = Vector2.ZERO; knob = Vector2.ZERO
			else:
				_aim(e.position, R)
			accept_event()
		elif e is InputEventMouseMotion and active:
			_aim(e.position, R)
			accept_event()
		queue_redraw()
	func _aim(p: Vector2, R: float) -> void:
		var d := p - size / 2.0
		knob = d.limit_length(R * 0.62)
		vec = knob / (R * 0.62)
		if vec.length() < 0.18: vec = Vector2.ZERO
	func _draw() -> void:
		var c := size / 2.0
		var R := size.x * 0.5
		draw_circle(c, R, Color(AfTheme.SHEET, 0.55))
		draw_arc(c, R - 2, 0, TAU, 40, Color(AfTheme.LINE, 0.9), 3.0)
		draw_circle(c + knob, R * 0.36, Color(AfTheme.EMBER, 0.85 if active else 0.55))
		draw_arc(c + knob, R * 0.36, 0, TAU, 30, Color(AfTheme.GOLD, 0.8), 2.0)


# ------------------------------------------- spot rings + overworld landmark names
class Markers extends Node2D:
	var k
	func _draw() -> void:
		var t: float = 0.0 if k.reduced_motion else k.t_now
		for s in k.usables:
			if s.get("kind", "") != "spot":
				continue
			var p: Vector2 = s.pos
			var pulse := 0.5 + 0.5 * sin(t * 3.0 + p.x * 0.01)
			draw_arc(p, 22.0 + 3.0 * pulse, 0, TAU, 28, Color(AfTheme.GOLD, 0.3 + 0.25 * pulse), 2.5)
			draw_arc(p, 30.0 + 5.0 * pulse, 0, TAU, 32, Color(AfTheme.EMBER, 0.12 * pulse), 2.0)
			if k.map.get("id", "") == "overworld":
				var f: Font = k.title_font
				var nm: String = s.name
				var sz := f.get_string_size(nm, HORIZONTAL_ALIGNMENT_CENTER, -1, 15)
				draw_string_outline(f, p + Vector2(-sz.x / 2.0, 46), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 6, Color(0.08, 0.06, 0.05, 0.9))
				draw_string(f, p + Vector2(-sz.x / 2.0, 46), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, AfTheme.GOLD)
