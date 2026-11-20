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


# ------------------------------------------------------------------ prompt icons (vector, AF palette)
## Which icon a usable gets: door / bag / bed / talk / look / flame.
static func icon_for(u: Dictionary) -> String:
	if u.is_empty():
		return ""
	match str(u.get("action", "")):
		"warp": return "door"
		"shop": return "bag"
		"inn": return "bed"
	if u.get("kind", "") == "npc":
		return "talk"
	if bool(u.get("calm", false)):
		return "flame"
	return "look"


static func draw_icon(ci: CanvasItem, kind: String, c: Vector2, r: float, col: Color) -> void:
	var w := maxf(1.5, r * 0.16)
	match kind:
		"door":
			var pts := PackedVector2Array()
			pts.append(c + Vector2(-r * 0.55, r * 0.8))
			for i in 13:
				var a := PI + PI * float(i) / 12.0
				pts.append(c + Vector2(cos(a) * r * 0.55, -r * 0.15 + sin(a) * r * 0.62))
			pts.append(c + Vector2(r * 0.55, r * 0.8))
			ci.draw_polyline(pts, col, w, true)
			ci.draw_line(c + Vector2(-r * 0.8, r * 0.8), c + Vector2(r * 0.8, r * 0.8), col, w)
			ci.draw_circle(c + Vector2(r * 0.25, r * 0.25), w * 0.8, col)
		"bag":
			ci.draw_rect(Rect2(c + Vector2(-r * 0.62, -r * 0.2), Vector2(r * 1.24, r * 1.0)), col, false, w)
			ci.draw_arc(c + Vector2(0, -r * 0.2), r * 0.38, PI, TAU, 12, col, w)
			ci.draw_circle(c + Vector2(0, r * 0.25), w * 0.9, col)
		"bed":
			ci.draw_line(c + Vector2(-r * 0.8, -r * 0.55), c + Vector2(-r * 0.8, r * 0.7), col, w)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.8, r * 0.05), Vector2(r * 1.6, r * 0.38)), col, false, w)
			ci.draw_line(c + Vector2(r * 0.8, r * 0.43), c + Vector2(r * 0.8, r * 0.7), col, w)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.62, -r * 0.3), Vector2(r * 0.5, r * 0.3)), col)
			ci.draw_arc(c + Vector2(r * 0.35, -r * 0.45), r * 0.3, PI * 0.6, PI * 1.9, 12, col, w)
		"talk":
			var rr := Rect2(c + Vector2(-r * 0.75, -r * 0.6), Vector2(r * 1.5, r * 1.0))
			ci.draw_rect(rr, col, false, w)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.35, r * 0.4), c + Vector2(-r * 0.05, r * 0.4), c + Vector2(-r * 0.45, r * 0.85)]), col)
			for i in 3:
				ci.draw_circle(c + Vector2(-r * 0.35 + r * 0.35 * i, -r * 0.1), w * 0.75, col)
		"flame":
			var f := PackedVector2Array([c + Vector2(0, -r * 0.85), c + Vector2(r * 0.5, -r * 0.05), c + Vector2(r * 0.42, r * 0.5),
				c + Vector2(0, r * 0.8), c + Vector2(-r * 0.42, r * 0.5), c + Vector2(-r * 0.5, -r * 0.05), c + Vector2(0, -r * 0.85)])
			ci.draw_polyline(f, col, w, true)
			ci.draw_circle(c + Vector2(0, r * 0.35), r * 0.2, col)
		_: # look: an eye
			var e := PackedVector2Array()
			for i in 17:
				var a := TAU * float(i) / 16.0
				e.append(c + Vector2(cos(a) * r * 0.8, sin(a) * r * 0.42))
			ci.draw_polyline(e, col, w, true)
			ci.draw_circle(c, r * 0.24, col)


# ------------------------------------------------------------------ minimap (HUD, top right)
class Minimap extends Control:
	var k
	var img_tex: ImageTexture
	func rebuild() -> void:
		img_tex = ImageTexture.create_from_image(make_image(k))
		queue_redraw()
	static func make_image(kk) -> Image:
		var img := Image.create(kk.W, kk.H, false, Image.FORMAT_RGBA8)
		for r in kk.H:
			for c in kk.W:
				img.set_pixel(c, r, col_of(kk.ch_at(c, r)))
		return img
	static func col_of(ch: String) -> Color:
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
	func _draw() -> void:
		if img_tex == null:
			return
		var full := Rect2(Vector2.ZERO, size)
		draw_style_box(get_theme_stylebox("panel", "FramedPanel"), full)
		var inner := full.grow(-7.0)
		# Zoomed window that follows the hero (modern minimap), clipped to the frame.
		var zoom := 4.0 if k.map.get("id", "") == "overworld" else 5.0
		var src_size := inner.size / zoom
		var center: Vector2 = k.player_pos / TILE
		var src := Rect2(center - src_size / 2.0, src_size)
		src.position.x = clampf(src.position.x, 0.0, maxf(0.0, k.W - src_size.x))
		src.position.y = clampf(src.position.y, 0.0, maxf(0.0, k.H - src_size.y))
		draw_rect(inner, Color("#14110e"))
		var dst := inner
		if src_size.x > k.W:
			dst.size.x = k.W * zoom; dst.position.x += (inner.size.x - dst.size.x) / 2.0; src.size.x = k.W; src.position.x = 0
		if src_size.y > k.H:
			dst.size.y = k.H * zoom; dst.position.y += (inner.size.y - dst.size.y) / 2.0; src.size.y = k.H; src.position.y = 0
		draw_texture_rect_region(img_tex, dst, src)
		var to_px := func(tp: Vector2) -> Vector2: return dst.position + (tp - src.position) * zoom
		for s in k.usables:
			var sp: Vector2 = to_px.call(s.pos / TILE)
			if not inner.has_point(sp):
				continue
			if s.get("kind", "") == "spot":
				draw_colored_polygon(PackedVector2Array([sp + Vector2(0, -4), sp + Vector2(4, 0), sp + Vector2(0, 4), sp + Vector2(-4, 0)]), AfTheme.GOLD)
			elif s.get("kind", "") == "npc":
				draw_circle(sp, 2.2, Color(AfTheme.INK, 0.8))
		var pp: Vector2 = to_px.call(k.player_pos / TILE)
		var pulse := 0.0 if k.reduced_motion else 0.5 + 0.5 * sin(k.t_now * 5.0)
		draw_circle(pp, 7.0 + 2.0 * pulse, Color(AfTheme.EMBER, 0.3))
		var f: Vector2 = k.face_dir
		var sd := Vector2(-f.y, f.x)
		draw_colored_polygon(PackedVector2Array([pp + f * 6.5, pp - f * 4.0 + sd * 4.5, pp - f * 2.0, pp - f * 4.0 - sd * 4.5]), AfTheme.EMBER_LIGHT)
		# Vignette edge + compass N + "open map" glyph
		draw_rect(inner, Color(AfTheme.LINE, 0.9), false, 1.0)
		var font: Font = k.title_font
		draw_string_outline(font, Vector2(size.x / 2.0 - 4, 17), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, Color(0.05, 0.04, 0.03, 0.9))
		draw_string(font, Vector2(size.x / 2.0 - 4, 17), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, AfTheme.GOLD)
		var gc := Vector2(size.x - 16, size.y - 16)
		draw_circle(gc, 9.0, Color(0.06, 0.05, 0.04, 0.8))
		draw_arc(gc, 9.0, 0, TAU, 20, Color(AfTheme.GOLD, 0.7), 1.2)
		for sgn in [-1.0, 1.0]:
			draw_line(gc + Vector2(sgn * 4, -4) , gc + Vector2(sgn * 4, 4), Color(AfTheme.GOLD, 0.9), 1.4)
		draw_line(gc + Vector2(-4, 0), gc + Vector2(4, 0), Color(AfTheme.GOLD, 0.9), 1.4)
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			k.toggle_big_map()
			accept_event()


# ------------------------------------------------------------------ full map screen (M)
class MapScreen extends Control:
	var k
	var img_tex: ImageTexture
	var legend: Array = []   # [{n, name, pos, icon}]
	var regions: Array = []  # [{name, pos}] overworld region names at their centres
	func open() -> void:
		# Soft, modern map: the tile map upscaled with smoothing, then lightly shaded.
		var img: Image = Minimap.make_image(k)
		img.resize(k.W * 8, k.H * 8, Image.INTERPOLATE_CUBIC)
		img_tex = ImageTexture.create_from_image(img)
		legend.clear()
		var n := 1
		for s in k.usables:
			if s.get("kind", "") == "npc":
				continue
			legend.append({"n": n, "name": str(s.name), "pos": s.pos / TILE, "icon": KingdomView.icon_for(s)})
			n += 1
		regions.clear()
		if k.map.get("id", "") == "overworld":
			var acc := {}
			for r in k.H:
				for c in k.W:
					var reg: String = k.region_at(Vector2(c + 0.5, r + 0.5) * TILE)
					if reg in ["meadow", "forest", "highlands"] and k.is_land(c, r):
						if not acc.has(reg): acc[reg] = [Vector2.ZERO, 0]
						acc[reg][0] += Vector2(c + 0.5, r + 0.5)
						acc[reg][1] += 1
			for reg in acc:
				regions.append({"name": str(KingdomMaps.REGIONS[reg].name), "pos": acc[reg][0] / float(acc[reg][1])})
		queue_redraw()
	func _process(_d: float) -> void:
		if visible:
			queue_redraw()
	func frame_rect() -> Rect2:
		var ins: Rect2 = k.safe_rect_ui()
		return ins.grow(-10.0)
	func _draw() -> void:
		if img_tex == null:
			return
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.035, 0.028, 0.022, 0.86))
		var fr := frame_rect()
		var portrait := fr.size.y > fr.size.x
		var cols := 2 if portrait else 1
		var rows_n: int = ceili(legend.size() / float(cols))
		var leg_h := 28.0 * rows_n + 8.0
		if portrait:
			# Shrink the frame to its content (map + legend) and centre it, instead of a tall empty card.
			var aw := fr.size.x - 36.0
			var mh := minf(aw / k.W * k.H, fr.size.y - 86.0 - 40.0 - leg_h - 18.0)
			var ch := 86.0 + mh + 18.0 + leg_h + 40.0
			fr = Rect2(fr.position.x, fr.position.y + (fr.size.y - ch) / 2.0, fr.size.x, ch)
		draw_style_box(get_theme_stylebox("panel", "FramedPanel"), fr)
		var font: Font = k.title_font
		var body: Font = get_theme_default_font()
		var title: String = k.map.get("name", "")
		var tsz := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 28)
		draw_string(font, Vector2(fr.position.x + (fr.size.x - tsz.x) / 2.0, fr.position.y + 42), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, AfTheme.GOLD)
		var sub: String = k.map.get("sub", "")
		var ssz := body.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
		draw_string(body, Vector2(fr.position.x + (fr.size.x - ssz.x) / 2.0, fr.position.y + 62), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, AfTheme.MUTED)
		var cx0 := fr.position.x + fr.size.x / 2.0
		draw_line(Vector2(cx0 - 90, fr.position.y + 74), Vector2(cx0 + 90, fr.position.y + 74), Color(AfTheme.GOLD, 0.5), 1.0)
		var area := Rect2(fr.position + Vector2(18, 86), fr.size - Vector2(36, 86 + 40))
		var mr: Rect2
		var leg: Rect2
		if portrait:
			var fit: float = minf(area.size.x / k.W, (area.size.y - leg_h - 18.0) / k.H)
			var ms := Vector2(k.W, k.H) * fit
			mr = Rect2(Vector2(area.position.x + (area.size.x - ms.x) / 2.0, area.position.y), ms)
			leg = Rect2(area.position.x, mr.end.y + 18.0, area.size.x, leg_h)
		else:
			var lw := minf(area.size.x * 0.34, 260.0)
			leg = Rect2(area.end.x - lw, area.position.y + 6, lw, area.size.y)
			var ma := Rect2(area.position, Vector2(area.size.x - lw - 14, area.size.y))
			var fit2: float = minf(ma.size.x / k.W, ma.size.y / k.H)
			var ms2 := Vector2(k.W, k.H) * fit2
			mr = Rect2(ma.position + (ma.size - ms2) / 2.0, ms2)
		var fit3: float = mr.size.x / float(k.W)
		draw_rect(mr.grow(6), Color(0.0, 0.0, 0.0, 0.35))
		draw_texture_rect(img_tex, mr, false)
		draw_rect(mr.grow(1), Color(AfTheme.GOLD_DARK, 0.75), false, 1.5)
		for corner in [mr.position, Vector2(mr.end.x, mr.position.y), mr.end, Vector2(mr.position.x, mr.end.y)]:
			draw_colored_polygon(PackedVector2Array([corner + Vector2(0, -5), corner + Vector2(5, 0), corner + Vector2(0, 5), corner + Vector2(-5, 0)]), AfTheme.GOLD)
		for rg in regions:
			var rp: Vector2 = mr.position + rg.pos * fit3
			var rn: String = str(rg.name).to_upper()
			var rs := font.get_string_size(rn, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
			draw_string_outline(font, rp - Vector2(rs.x / 2.0, -4), rn, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 4, Color(0.05, 0.04, 0.03, 0.7))
			draw_string(font, rp - Vector2(rs.x / 2.0, -4), rn, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(AfTheme.INK, 0.75))
		var t: float = 0.0 if k.reduced_motion else k.t_now
		for it in legend:
			var p: Vector2 = mr.position + it.pos * fit3
			draw_circle(p + Vector2(0, 2), 10.0, Color(0, 0, 0, 0.35))
			draw_circle(p, 10.0, Color(0.07, 0.05, 0.04, 0.92))
			draw_arc(p, 10.0, 0, TAU, 20, AfTheme.GOLD, 1.5, true)
			var ns := str(it.n)
			var nsz := body.get_string_size(ns, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
			draw_string(body, p + Vector2(-nsz.x / 2.0, 4.5), ns, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, AfTheme.GOLD)
		var pp: Vector2 = mr.position + k.player_pos / TILE * fit3
		var pulse := 0.5 + 0.5 * sin(t * 4.0)
		draw_circle(pp, 9.0 + 6.0 * pulse, Color(AfTheme.EMBER, 0.28 * (1.0 - pulse) + 0.08))
		draw_circle(pp, 6.5, AfTheme.EMBER_LIGHT)
		draw_arc(pp, 6.5, 0, TAU, 16, Color(0.1, 0.06, 0.04), 1.5, true)
		var you := "You"
		draw_string_outline(body, pp + Vector2(10, -8), you, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, Color(0.05, 0.04, 0.03, 0.85))
		draw_string(body, pp + Vector2(10, -8), you, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, AfTheme.EMBER_LIGHT)
		# legend
		var cw := leg.size.x / cols
		for i in legend.size():
			var it: Dictionary = legend[i]
			var cx := leg.position.x + cw * (i % cols)
			var cy := leg.position.y + 12 + 28.0 * (i / cols)
			if cy > fr.end.y - 44:
				break
			draw_circle(Vector2(cx + 10, cy), 9.0, Color(0.07, 0.05, 0.04, 0.9))
			draw_arc(Vector2(cx + 10, cy), 9.0, 0, TAU, 18, AfTheme.GOLD, 1.2, true)
			var ns := str(it.n)
			draw_string(body, Vector2(cx + 10 - body.get_string_size(ns, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x / 2.0, cy + 4), ns, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, AfTheme.GOLD)
			KingdomView.draw_icon(self, str(it.icon), Vector2(cx + 30, cy), 7.0, AfTheme.EMBER_LIGHT)
			draw_string(body, Vector2(cx + 42, cy + 5), str(it.name), HORIZONTAL_ALIGNMENT_LEFT, cw - 46, 14, AfTheme.INK)
		var close := "Tap anywhere to close" if k.touch_ui else ("B to close" if k.last_pad else "M / Esc to close")
		var csz := body.get_string_size(close, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
		draw_string(body, Vector2(fr.position.x + (fr.size.x - csz.x) / 2.0, fr.end.y - 16), close, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, AfTheme.MUTED)
	func _gui_input(e: InputEvent) -> void:
		if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
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


# ------------------------------------------------------------- floating touch joystick (Airron's Fall)
## Visual only; KingdomTouch owns the logic. Matches AF: 118 px base, knob 37%, dark radial base with a
## thin gold ring, ember knob, quick scale-in, fades out on release.
class FloatStick extends Control:
	var k
	var knob := Vector2.ZERO
	var on := false
	var _tw: Tween
	func show_at(p: Vector2) -> void:
		position = p
		knob = Vector2.ZERO
		on = true
		visible = true
		if _tw: _tw.kill()
		if k.reduced_motion:
			modulate.a = 0.9; scale = Vector2.ONE
		else:
			modulate.a = 0.0; scale = Vector2(0.85, 0.85)
			_tw = create_tween().set_parallel(true)
			_tw.tween_property(self, "modulate:a", 0.9, 0.12)
			_tw.tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		queue_redraw()
	func release() -> void:
		on = false
		if _tw: _tw.kill()
		if k.reduced_motion:
			visible = false
			return
		_tw = create_tween()
		_tw.tween_property(self, "modulate:a", 0.0, 0.18)
		_tw.tween_callback(func(): visible = false)
	func set_knob(v: Vector2) -> void:
		knob = v
		queue_redraw()
	func _draw() -> void:
		var R: float = k.stick_size() * 0.5
		# base: radial dark gradient (rgba(10,9,8,.12) -> .32) + inset gold ring
		for i in 6:
			var f := 1.0 - float(i) / 6.0
			draw_circle(Vector2.ZERO, R * f, Color(0.04, 0.035, 0.03, 0.06 + 0.04 * float(i == 0)))
		draw_arc(Vector2.ZERO, R - 1.5, 0, TAU, 48, Color(0.85, 0.68, 0.38, 0.28 * 1.6), 2.0, true)
		# direction hint ticks
		for a in [0.0, PI * 0.5, PI, PI * 1.5]:
			var d := Vector2(cos(a), sin(a))
			draw_line(d * (R - 10), d * (R - 5), Color(0.85, 0.68, 0.38, 0.35), 2.0)
		# knob: ember radial (lit from 40% height) + warm ring
		var kr := R * 0.74 # knob = 0.37 * size
		var kc := knob
		for i in 5:
			var f := 1.0 - float(i) / 5.0
			draw_circle(kc + Vector2(0, -kr * 0.2 * (1.0 - f)), kr * f, Color(1.0, 0.62 + 0.12 * float(i) / 5.0, 0.36, 0.14 + 0.06 * float(i)))
		draw_arc(kc, kr - 1.0, 0, TAU, 36, Color(1.0, 0.84, 0.59, 0.55), 1.6, true)


# ------------------------------------------------------------- context Use button
## Hidden until something is in reach, then pops in with the prompt's icon and pulses.
## Pressed by KingdomTouch (per finger, multitouch) or a desktop mouse click.
class UseButton extends Control:
	var k
	var prompt := ""
	var icon := ""
	var shown := false
	var held := false
	var _tw: Tween
	func set_target(u: Dictionary) -> void:
		var want := not u.is_empty()
		if want:
			prompt = str(u.prompt)
			icon = KingdomView.icon_for(u)
		if want == shown:
			queue_redraw()
			return
		shown = want
		if _tw: _tw.kill()
		pivot_offset = size / 2.0
		if want:
			visible = true
		if k.reduced_motion:
			visible = want; modulate.a = 1.0; scale = Vector2.ONE
			return
		_tw = create_tween().set_parallel(true)
		_tw.tween_property(self, "modulate:a", 1.0 if want else 0.0, 0.14)
		_tw.tween_property(self, "scale", Vector2.ONE if want else Vector2(0.7, 0.7), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if not want:
			_tw.chain().tween_callback(func(): if not shown: visible = false)
	func press(on: bool) -> void:
		held = on
		pivot_offset = size / 2.0
		scale = Vector2(0.92, 0.92) if on else Vector2.ONE
		queue_redraw()
	func _process(_d: float) -> void:
		if visible:
			queue_redraw()
	func _draw() -> void:
		var c := size / 2.0
		var R := minf(size.x, size.y) * 0.5 - 4.0
		var t: float = 0.0 if k.reduced_motion else k.t_now
		var pulse := 0.5 + 0.5 * sin(t * 4.2)
		if not k.reduced_motion:
			draw_arc(c, R + 2.0 + 5.0 * pulse, 0, TAU, 48, Color(AfTheme.EMBER, 0.45 * (1.0 - pulse)), 3.0, true)
		draw_circle(c + Vector2(0, 3), R, Color(0, 0, 0, 0.35))
		draw_circle(c, R, Color(AfTheme.EMBER_DARK.lerp(AfTheme.SHEET, 0.3), 0.94))
		draw_circle(c, R * 0.86, Color(AfTheme.EMBER, 0.92 if held else 0.78))
		draw_circle(c + Vector2(0, -R * 0.25), R * 0.55, Color(AfTheme.EMBER_LIGHT, 0.35))
		draw_arc(c, R, 0, TAU, 48, AfTheme.GOLD, 2.5, true)
		KingdomView.draw_icon(self, icon, c + Vector2(0, -R * 0.16), R * 0.38, Color(0.12, 0.07, 0.04))
		var f: Font = k.title_font
		var fs := int(clampf(R * 0.3, 11.0, 17.0))
		var sz := f.get_string_size(prompt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		draw_string(f, c + Vector2(-sz.x / 2.0, R * 0.58), prompt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.12, 0.07, 0.04))
		if not k.touch_ui:
			var key: String = "A" if k.last_pad else "E"
			var kc := c + Vector2(R * 0.72, -R * 0.72)
			draw_circle(kc, 11.0, AfTheme.SHEET)
			draw_arc(kc, 11.0, 0, TAU, 20, AfTheme.GOLD, 1.5)
			var ksz := f.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
			draw_string(f, kc + Vector2(-ksz.x / 2.0, 5), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, AfTheme.GOLD)
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			press(e.pressed)
			if not e.pressed and Rect2(Vector2.ZERO, size).has_point(e.position):
				k.use_or_advance()
			accept_event()


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
			if k.map.get("id", "") == "overworld" and s != k.near: # the prompt card names it when in reach
				var f: Font = k.title_font
				var nm: String = s.name
				var sz := f.get_string_size(nm, HORIZONTAL_ALIGNMENT_CENTER, -1, 15)
				draw_string_outline(f, p + Vector2(-sz.x / 2.0, 46), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 6, Color(0.08, 0.06, 0.05, 0.9))
				draw_string(f, p + Vector2(-sz.x / 2.0, 46), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, AfTheme.GOLD)


# ------------------------------------------- interact prompt (world space, above sprites)
class PromptLayer extends Node2D:
	var k
	func _draw() -> void:
		# Interact prompt: a small AF card with the action icon floating over whatever is in reach.
		var u: Dictionary = k.near
		if u.is_empty() or k.busy or k._modal_open():
			return
		var bob := 0.0 if k.reduced_motion else sin(k.t_now * 3.2) * 3.0
		var tp: Vector2 = u.pos + Vector2(0, (-92.0 if u.get("kind", "") == "npc" else -58.0) + bob)
		var ff: Font = k.title_font
		var label := "%s  %s" % [str(u.prompt), str(u.name)]
		var lsz := ff.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
		var bw := lsz.x + 44.0
		var br := Rect2(tp - Vector2(bw / 2.0, 15.0), Vector2(bw, 30.0))
		draw_rect(Rect2(br.position + Vector2(0, 3), br.size), Color(0, 0, 0, 0.3))
		draw_rect(br, Color(AfTheme.SHEET, 0.94))
		draw_rect(br, Color(AfTheme.GOLD_DARK, 0.9), false, 1.5)
		draw_colored_polygon(PackedVector2Array([tp + Vector2(-6, 15), tp + Vector2(6, 15), tp + Vector2(0, 22)]), Color(AfTheme.SHEET, 0.94))
		KingdomView.draw_icon(self, KingdomView.icon_for(u), br.position + Vector2(17, 15), 8.0, AfTheme.EMBER_LIGHT)
		draw_string(ff, br.position + Vector2(32, 20), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, AfTheme.INK)
