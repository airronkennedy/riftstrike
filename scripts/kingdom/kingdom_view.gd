class_name KingdomView
extends RefCounted
## Drawing nodes for the kingdom scenes: tile ground, y-sorted props / actors with soft shadows, the minimap and the
## touch joystick. All art is Airron's Fall art already in assets/af (gen atlases, heroes, props).

const TILE := 64.0
const GEN := "res://assets/af/gen/"

# Sprite layouts (same frames as scripts/world.gd PROP_DEFS). bw/bh/by: blocking footprint at scale 1.
const DEFS := {
	"castle_blue": {"f": "castle_blue.png", "fw": 320, "fh": 256, "ax": 160, "ay": 228, "bw": 250, "bh": 70},
	"castle_ruin": {"f": "castle_ruin.png", "fw": 320, "fh": 256, "ax": 160, "ay": 228, "bw": 220, "bh": 50},
	"house_blue": {"f": "house_blue.png", "fw": 128, "fh": 192, "ax": 64, "ay": 171, "bw": 74, "bh": 38},
	"house_red": {"f": "house_red.png", "fw": 128, "fh": 192, "ax": 64, "ay": 171, "bw": 74, "bh": 38},
	"house_yellow": {"f": "house_yellow.png", "fw": 128, "fh": 192, "ax": 64, "ay": 171, "bw": 74, "bh": 38},
	"house_purple": {"f": "house_purple.png", "fw": 128, "fh": 192, "ax": 64, "ay": 171, "bw": 74, "bh": 38},
	"hut": {"f": "hut.png", "fw": 128, "fh": 192, "ax": 64, "ay": 171, "bw": 70, "bh": 36},
	"tower_yellow": {"f": "tower_yellow.png", "fw": 128, "fh": 256, "ax": 64, "ay": 235, "bw": 97, "bh": 43},
	"tower_ruin": {"f": "tower_ruin.png", "fw": 128, "fh": 256, "ax": 64, "ay": 235, "bw": 80, "bh": 30},
	"wtower": {"f": "watchtower.png", "fw": 256, "fh": 192, "ax": 128, "ay": 172, "bw": 90, "bh": 30},
	"goldmine": {"f": "mine.png", "fw": 192, "fh": 128, "ax": 96, "ay": 112, "bw": 150, "bh": 40},
	"deco18": {"f": "deco_18.png", "fw": 192, "fh": 192, "ax": 96, "ay": 170, "bw": 30, "bh": 16},
	"tree": {"f": "tree.png", "fw": 192, "fh": 192, "ax": 96, "ay": 178, "bw": 0, "bh": 0, "n": 4},
	"fire": {"f": "fx_flame.png", "fw": 128, "fh": 128, "ax": 64, "ay": 104, "bw": 28, "bh": 14, "n": 7},
	"chest": {"f": "res://assets/af/props/ember-chest.png", "fw": 99, "fh": 99, "ax": 50, "ay": 88, "bw": 60, "bh": 24},
}

static var _tex: Dictionary = {}


static func tex(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(path if path.begins_with("res://") else GEN + path)
	return _tex[path]


static func hero_tex(id: String) -> Texture2D:
	return tex("res://assets/af/heroes/%s.png" % id)


static func soft_shadow(n: CanvasItem, at: Vector2, w: float, alpha: float = 0.32) -> void:
	# Three stacked ellipses = a cheap soft-edged contact shadow.
	for i in 3:
		var k := 1.0 - float(i) * 0.22
		var pts := PackedVector2Array()
		for a in 18:
			var t := TAU * float(a) / 18.0
			pts.append(at + Vector2(cos(t) * w * k * 0.5, sin(t) * w * k * 0.16))
		n.draw_colored_polygon(pts, Color(0, 0, 0, alpha * 0.4))


# ------------------------------------------------------------------ ground
class Ground extends Node2D:
	var k # kingdom.gd
	func _draw() -> void:
		var rows: Array = k.rows
		if rows.is_empty():
			return
		var flat: Texture2D = KingdomView.tex("tilemap_flat.png")
		var view: Rect2 = k.view_rect().grow(TILE)
		var c0: int = maxi(0, int(view.position.x / TILE))
		var c1: int = mini(k.W - 1, int(view.end.x / TILE))
		var r0: int = maxi(0, int(view.position.y / TILE))
		var r1: int = mini(k.H - 1, int(view.end.y / TILE))
		var indoor: bool = k.map.get("id", "") in ["castle", "house"]
		var t: float = 0.0 if k.reduced_motion else k.t_now
		for r in range(r0, r1 + 1):
			for c in range(c0, c1 + 1):
				var ch: String = k.ch_at(c, r)
				var rc := Rect2(c * TILE, r * TILE, TILE, TILE)
				if ch == "~":
					draw_rect(rc, Color("#1d3640"))
					var wv := sin(t * 1.4 + c * 0.9 + r * 0.6)
					draw_line(rc.position + Vector2(10, 22 + wv * 3), rc.position + Vector2(34, 22 + wv * 3), Color(0.55, 0.8, 0.85, 0.16), 2.0)
					draw_line(rc.position + Vector2(30, 46 - wv * 3), rc.position + Vector2(54, 46 - wv * 3), Color(0.55, 0.8, 0.85, 0.12), 2.0)
					continue
				if indoor:
					_flag(rc, ch, c, r)
					continue
				var tint := Color.WHITE
				if ch == "f" or ch == "T":
					tint = Color(0.62, 0.8, 0.6)
				elif ch == "^" or ch == "#":
					tint = Color(0.92, 0.84, 0.76)
				var sx: int = _edge(k.is_land(c - 1, r), k.is_land(c + 1, r))
				var sy: int = _edge(k.is_land(c, r - 1), k.is_land(c, r + 1))
				draw_texture_rect_region(flat, rc, Rect2(sx * 64, sy * 64, 64, 64), tint)
				if ch == "," or ch == ":":
					var same := func(cc: int, rr: int) -> bool: return k.ch_at(cc, rr) == ch
					var sx2: int = _edge(same.call(c - 1, r), same.call(c + 1, r))
					var sy2: int = _edge(same.call(c, r - 1), same.call(c, r + 1))
					draw_texture_rect_region(flat, rc, Rect2(320 + sx2 * 64, sy2 * 64, 64, 64), Color(1.0, 0.92, 0.74) if ch == ":" else Color.WHITE)
				elif ch == "#":
					_rock(rc, c, r)
		# spot rings (gold, gently pulsing) under the y-sorted layer
		for s in k.usables:
			if s.get("kind", "") != "spot":
				continue
			var p: Vector2 = s.pos
			var pulse := 0.5 + 0.5 * sin(t * 3.0 + p.x * 0.01)
			draw_arc(p, 22.0 + 3.0 * pulse, 0, TAU, 28, Color(AfTheme.GOLD, 0.35 + 0.25 * pulse), 2.5)
			if k.map.get("id", "") == "overworld":
				var f: Font = k.title_font
				var nm: String = s.name
				var sz := f.get_string_size(nm, HORIZONTAL_ALIGNMENT_CENTER, -1, 15)
				draw_string_outline(f, p + Vector2(-sz.x / 2.0, 44), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 5, Color(0.08, 0.06, 0.05, 0.9))
				draw_string(f, p + Vector2(-sz.x / 2.0, 44), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, AfTheme.GOLD)

	func _edge(l: bool, r: bool) -> int:
		if l and r: return 1
		if r: return 0
		if l: return 2
		return 3

	func _flag(rc: Rect2, ch: String, c: int, r: int) -> void:
		if ch == "#":
			draw_rect(rc, Color("#1b1714"))
			var below: bool = k.ch_at(c, r + 1) != "#" and r + 1 < k.H
			if below:
				# wall face: brick courses lit from the room
				draw_rect(Rect2(rc.position.x, rc.position.y + 16, TILE, 48), Color("#3a312a"))
				for i in 3:
					var yy := rc.position.y + 16 + i * 16
					draw_line(Vector2(rc.position.x, yy), Vector2(rc.end.x, yy), Color(0, 0, 0, 0.35), 2.0)
					var off := 0.0 if i % 2 == 0 else 32.0
					draw_line(Vector2(rc.position.x + off + 16, yy), Vector2(rc.position.x + off + 16, yy + 16), Color(0, 0, 0, 0.3), 2.0)
				draw_rect(Rect2(rc.position.x, rc.position.y + 12, TILE, 4), Color("#5a4a3c"))
			return
		var base := Color("#5b5249")
		draw_rect(rc, base)
		var h: int = (c * 73856093) ^ (r * 19349663)
		for q in 4:
			var sx := rc.position.x + float(q % 2) * 32.0
			var sy := rc.position.y + float(q / 2) * 32.0
			draw_rect(Rect2(sx + 2, sy + 2, 28, 28), base.lightened(0.04 + float((h >> q) & 3) * 0.03))
		if ch == "c":
			draw_rect(rc, Color("#7a2620"))
			if k.ch_at(c - 1, r) != "c":
				draw_rect(Rect2(rc.position.x + 4, rc.position.y, 4, TILE), AfTheme.GOLD_DARK)
			if k.ch_at(c + 1, r) != "c":
				draw_rect(Rect2(rc.end.x - 8, rc.position.y, 4, TILE), AfTheme.GOLD_DARK)

	func _rock(rc: Rect2, c: int, r: int) -> void:
		draw_rect(rc.grow(-4), Color("#4a3f37"))
		draw_rect(Rect2(rc.position.x + 4, rc.position.y + 4, TILE - 8, 14), Color("#6b5c50"))
		draw_line(rc.position + Vector2(14, 30), rc.position + Vector2(40, 52), Color(0, 0, 0, 0.35), 2.0)


# ------------------------------------------------------------- y-sorted prop
class Prop extends Node2D:
	var k
	var kind := ""
	var s := 1.0
	var ph := 0
	var flip := false
	func _draw() -> void:
		var t: float = 0.0 if k.reduced_motion else k.t_now
		if kind == "pillar":
			KingdomView.soft_shadow(self, Vector2(0, 2), 54.0)
			draw_rect(Rect2(-20, -112, 40, 112), Color("#6e6258"))
			draw_rect(Rect2(-20, -112, 10, 112), Color("#857669"))
			draw_rect(Rect2(-26, -120, 52, 12), Color("#8d7d6e"))
			draw_rect(Rect2(-26, -8, 52, 10), Color("#4e443c"))
			return
		if kind == "throne":
			KingdomView.soft_shadow(self, Vector2(0, 4), 150.0, 0.4)
			draw_rect(Rect2(-56, -38, 112, 20), Color("#5a3c22"))
			draw_rect(Rect2(-44, -150, 88, 120), AfTheme.GOLD_DARK)
			draw_rect(Rect2(-34, -138, 68, 96), Color("#7a2620"))
			draw_circle(Vector2(0, -158), 16, AfTheme.GOLD)
			draw_circle(Vector2(0, -158), 8, AfTheme.EMBER)
			draw_rect(Rect2(-50, -48, 100, 16), AfTheme.GOLD)
			return
		if kind == "shrine":
			KingdomView.soft_shadow(self, Vector2(0, 2), 90.0)
			draw_rect(Rect2(-38, -18, 76, 18), Color("#6b5c50"))
			draw_rect(Rect2(-24, -58, 48, 42), Color("#857669"))
			draw_rect(Rect2(-30, -64, 60, 8), Color("#9a8a7a"))
			var ff := int(t * 10.0) % 7
			draw_texture_rect_region(KingdomView.tex("fx_flame.png"), Rect2(-32, -118, 64, 64), Rect2(ff * 128, 0, 128, 128))
			return
		if kind.begins_with("statue:"):
			var tx := KingdomView.hero_tex(kind.substr(7))
			KingdomView.soft_shadow(self, Vector2(0, 2), 70.0)
			draw_rect(Rect2(-34, -22, 68, 22), Color("#6b5c50"))
			if tx:
				var hh: float = tx.get_height() * s
				var ww: float = tx.get_width() * s
				draw_texture_rect(tx, Rect2(-ww / 2.0, -22 - hh, ww, hh), false, Color(0.6, 0.58, 0.56))
			return
		var d: Dictionary = KingdomView.DEFS.get(kind, {})
		if d.is_empty():
			return
		var tx2: Texture2D = KingdomView.tex(str(d.f))
		var n: int = int(d.get("n", 1))
		var fps := 10.0 if kind == "fire" else 5.0
		var fr := (int(t * fps) + ph) % n if n > 1 else 0
		var fw := float(d.fw)
		var fh := float(d.fh)
		if kind != "fire":
			KingdomView.soft_shadow(self, Vector2(0, 0), maxf(40.0, float(d.bw) * s * 1.15 if float(d.bw) > 0 else fw * s * 0.5))
		var dst := Rect2(-float(d.ax) * s, -float(d.ay) * s, fw * s, fh * s)
		if flip:
			dst = Rect2(dst.position.x + dst.size.x, dst.position.y, -dst.size.x, dst.size.y)
		draw_texture_rect_region(tx2, dst, Rect2(fr * fw, 0, fw, fh))


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
		KingdomView.soft_shadow(self, Vector2(0, 2), 46.0 - bob * 2.0, 0.42)
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
			draw_arc(Vector2(0, -h - 14), 8, 0, TAU, 16, AfTheme.GOLD, 3.0)


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
