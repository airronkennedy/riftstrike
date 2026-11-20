extends RefCounted
## Airron's Quest side-view battle HUD, drawn in the Airron's Fall UI language (chamfered ash panels,
## gold hairlines, Cinzel headings, Rajdhani labels, parchment text) with a modern finish:
## eased panel slides, a sliding turn timeline, raised active card, warm lighting and drifting embers.
## Layout (landscape): turn timeline across the top, command menu upper right, party cards bottom right,
## speed / auto / tips bar bottom left. game.gd owns the rules; this file only draws and routes taps.

const GOLD := AfTheme.GOLD_DARK # shared Airron's Fall palette (scripts/ui/af_theme.gd)
const GOLD_HI := AfTheme.GOLD
const PARCH := AfTheme.INK
const PARCH_DIM := AfTheme.MUTED
const EMBER := AfTheme.EMBER
const ASH := Color(0.086, 0.074, 0.06, 0.9)
const INK := Color(0.035, 0.03, 0.025, 0.94)
const FOE := AfTheme.CORAL
const HP_G := Color("#6fcf6a")
const MP_B := Color("#5aa8ff")
const YEL := Color("#f2c94c")

## Command rows: [id, label, icon, tooltip]
const CMDS := [
	["attack", "Attack", "greatsword-slash", "Strike one foe with your weapon. Builds MP."],
	["abilities", "Abilities", "chain-spark", "Spend a full MP bar on one of your four slotted abilities."],
	["defend", "Defend", "ember-aegis", "Brace: Defense and Armor up until your next turn, +30 MP."],
	["items", "Items", "field-medkit", "Potions heal the weakest ally. Ethers give +50 MP."],
	["escape", "Escape", "swift-feet", "Leave the fight. Bosses won't wait for you."],
]
const ICONS := ["greatsword-slash", "chain-spark", "ember-aegis", "field-medkit", "swift-feet", "chest", "vital-spark",
	"second-wind", "bright-mind", "ember-bolt", "prayer-knot", "starfall", "spire-lance", "bellstroke"]
const KIND_ICON := {"damage_single": "spire-lance", "damage_all_enemies": "starfall", "buff_self": "ember-aegis",
	"buff_party": "bellstroke", "heal_single": "vital-spark", "heal_party": "prayer-knot"}

var ic := {}
var panel_in := 0.0 # 0..1 command panel slide
var tl_shift := 0.0 # 1 -> 0 after the timeline advances
var last_active = null
var raise := {} # unit -> 0..1 card lift
var embers: Array = []
var ember_acc := 0.0
var t := 0.0
var k := 1.0 # UI scale
var tips_hover := -1

func _init() -> void:
	for n in ICONS:
		var p = "res://assets/af/icons/%s.png" % n
		if ResourceLoader.exists(p): ic[n] = load(p)

static func ease_out(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return 1.0 - pow(1.0 - x, 3.0)

# ---------------------------------------------------------------- animation tick
func update(g, dt_ms: float) -> void:
	var dt = dt_ms / 1000.0
	t += dt
	var G = g.G
	if G == null: return
	k = clampf(g.VHc / 560.0, 0.82, 1.25)
	if G.active != last_active:
		last_active = G.active
		tl_shift = 1.0
		panel_in = 0.0
	tl_shift = maxf(0.0, tl_shift - dt * 4.0)
	var want_panel: bool = show_menu(g)
	panel_in = clampf(panel_in + (dt * 3.2 if want_panel else -dt * 6.0), 0.0, 1.0)
	for u in G.units:
		if u.team != "blue": continue
		var goal = 1.0 if u == G.active else 0.0
		raise[u] = lerpf(float(raise.get(u, 0.0)), goal, minf(1.0, dt * 10.0))
	# embers rise from the ground line
	ember_acc += dt * 14.0
	while ember_acc >= 1.0:
		ember_acc -= 1.0
		embers.append({"x": randf() * g.VWc, "y": g.VHc * (0.75 + randf() * 0.3), "vx": randf_range(-14, 14), "vy": -randf_range(22, 60),
			"life": randf_range(3.0, 6.5), "age": 0.0, "s": randf_range(1.0, 2.6), "ph": randf() * TAU})
	for i in range(embers.size() - 1, -1, -1):
		var e: Dictionary = embers[i]
		e.age += dt
		e.x += (e.vx + sin(t * 1.3 + e.ph) * 10.0) * dt
		e.y += e.vy * dt
		if e.age >= e.life: embers.remove_at(i)

func show_menu(g) -> bool:
	var G = g.G
	return g.phase == "battle" and G != null and G.ctb and G.active != null and G.active.team == "blue" and G.mode == "select" and not g.AUTO

# ---------------------------------------------------------------- backdrop + light (screen space, before the world)
func draw_backdrop(g) -> void:
	var VW: float = g.VWc
	var VH: float = g.VHc
	var bg: Texture2D = g.IMG.get("bg_" + g.battle_area, null)
	if bg != null:
		var bw = float(bg.get_width()); var bh = float(bg.get_height())
		var s = maxf(VW / bw, VH / bh) * 1.04
		var drift = sin(t * 0.07) * 6.0 # slow parallax breathing
		g.img(bg, 0, 0, bw, bh, (VW - bw * s) / 2.0 + drift, (VH - bh * s) / 2.0 - VH * 0.02, bw * s, bh * s, Color(0.8, 0.76, 0.72))
	# floor: darken the lower band so units read, plus a warm light pool in the middle of the field
	var fl = PackedVector2Array([Vector2(0, VH * 0.52), Vector2(VW, VH * 0.52), Vector2(VW, VH), Vector2(0, VH)])
	g.draw_polygon(fl, PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0.03, 0.02, 0.015, 0.78), Color(0.03, 0.02, 0.015, 0.78)]))
	var pulse = 0.85 + 0.15 * sin(t * 1.7)
	for i in 6:
		var f = float(i) / 6.0
		g.fill_ellipse(VW * 0.5, VH * 0.7, VW * (0.5 - f * 0.3), VH * (0.16 - f * 0.09), Color(1.0, 0.55, 0.22, 0.025 * pulse))
	draw_embers(g, 0.8)

func draw_embers(g, alpha: float) -> void:
	for e in embers:
		var a: float = sin(PI * float(e.age) / float(e.life)) * alpha
		g.draw_circle(Vector2(e.x, e.y), float(e.s) * 2.6, Color(1.0, 0.45, 0.15, 0.10 * a))
		g.draw_circle(Vector2(e.x, e.y), float(e.s), Color(1.0, 0.75, 0.4, 0.85 * a))

## Screen edge vignette (after the world, before the HUD).
func draw_vignette(g) -> void:
	var VW: float = g.VWc
	var VH: float = g.VHc
	var c0 = Color(0, 0, 0, 0.55); var c1 = Color(0, 0, 0, 0)
	var e = minf(VW, VH) * 0.18
	g.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(e, 0), Vector2(e, VH), Vector2(0, VH)]), PackedColorArray([c0, c1, c1, c0]))
	g.draw_polygon(PackedVector2Array([Vector2(VW - e, 0), Vector2(VW, 0), Vector2(VW, VH), Vector2(VW - e, VH)]), PackedColorArray([c1, c0, c0, c1]))
	g.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(VW, 0), Vector2(VW, e * 0.8), Vector2(0, e * 0.8)]), PackedColorArray([c0, c0, c1, c1]))

# ---------------------------------------------------------------- world-space unit overlays
func unit_overlay(g, u) -> void:
	if u.dead or u.gone: return
	var G = g.G
	var h: float = float(u.K.head) * g.uS(u)
	var x: float = u.x
	var top: float = u.y - h - 14.0
	var active: bool = G.active == u
	if active:
		# light pool + bobbing gold chevron over the active unit
		for i in 4:
			g.fill_ellipse(x, u.y - 2, 40.0 - i * 7.0, 12.0 - i * 2.0, Color(1.0, 0.7, 0.3, 0.07))
		var by = top - 16.0 + sin(t * 5.0) * 3.0
		g.draw_colored_polygon(PackedVector2Array([Vector2(x - 8, by - 6), Vector2(x + 8, by - 6), Vector2(x, by + 4)]), GOLD_HI)
	if u.team == "red":
		var w = clampf(h * 0.7, 46.0, 96.0)
		var bx = x - w / 2.0
		var hp: float = clampf(float(u.hp) / maxf(1.0, float(u.maxhp)), 0.0, 1.0)
		g.draw_rect(Rect2(bx - 1, top - 1, w + 2, 6), Color(0, 0, 0, 0.75))
		g.draw_rect(Rect2(bx, top, w * hp, 4), FOE.lightened(0.1))
		g.draw_rect(Rect2(bx, top + 5, w * clampf(float(u.gauge) / 100.0, 0.0, 1.0), 2), YEL)
		var lt: String = str(u.letter)
		g.draw_colored_polygon(diamond(Vector2(bx - 12, top + 2), 9), INK)
		g.draw_polyline(closed(diamond(Vector2(bx - 12, top + 2), 9)), FOE, 1.2, true)
		g.text(lt, bx - 12, top + 2, 11, PARCH)
		if targeting(g):
			var p = 0.5 + 0.5 * sin(t * 7.0)
			g.stroke_ellipse(x, u.y - 2, 34 + p * 5, 11 + p * 2, Color(GOLD_HI.r, GOLD_HI.g, GOLD_HI.b, 0.6 + p * 0.4), 2.0)
			g.draw_polyline(closed(diamond(Vector2(x, u.y - h * 0.55), 14 + p * 3)), GOLD_HI, 1.6, true)

func targeting(g) -> bool:
	return show_menu(g) and g.G.cmd == "target"

static func diamond(c: Vector2, r: float) -> PackedVector2Array:
	return PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])

static func closed(p: PackedVector2Array) -> PackedVector2Array:
	var q = p.duplicate(); q.append(p[0]); return q

# ---------------------------------------------------------------- HUD (screen space)
func draw(g) -> void:
	var G = g.G
	if G == null: return
	draw_vignette(g)
	draw_timeline(g)
	if panel_in > 0.01: draw_command(g)
	elif g.AUTO and g.phase == "battle": draw_auto_panel(g)
	draw_cards(g)
	draw_bar(g)

func portrait(g, u, c: Vector2, r: float, border: Color, bw: float) -> void:
	g.draw_colored_polygon(diamond(c, r), INK)
	g.draw_colored_polygon(diamond(c, r * 0.92), (FOE if u.team == "red" else GOLD).darkened(0.72))
	var tex: Texture2D = g.IMG.get(u.K.img, null)
	if tex != null:
		var f: Dictionary = u.K.f
		var fw = float(f.fw); var fh = float(f.fh)
		var side = minf(fw, fh) * 0.62
		var src = Rect2((fw - side) / 2.0, fh * 0.06, side, side)
		var d = r * 1.3
		var dst = Rect2(c.x - d / 2.0, c.y - d / 2.0, d, d)
		if u.team == "blue": dst = Rect2(dst.position.x, dst.position.y, -d, d)
		g.draw_texture_rect_region(tex, dst, src)
	g.draw_polyline(closed(diamond(c, r)), border, bw, true)

func draw_timeline(g) -> void:
	var G = g.G
	var x0: float = g.SAFE_L + 12.0 * k
	var xb: float = g.VWc - g.SAFE_R - 12.0 * k
	var y: float = g.SAFE_T + 34.0 * k
	var R = 27.0 * k
	var r = 15.0 * k
	var bigc = Vector2(x0 + R, y)
	var xa = bigc.x + R + 10.0 * k
	# track: an ash bar with a gold hairline and ornament ends
	g.rbox(Rect2(xa - 4, y - r - 4, xb - xa + 4, r * 2 + 8), 10, Color(0.07, 0.06, 0.05, 0.78), Color.WHITE, 1.0)
	var n = clampi(int((xb - xa) / (r * 2.7)), 5, 14)
	var step = (xb - xa) / float(n)
	var list: Array = g.timeline_preview(n + 1)
	var sh = ease_out(1.0 - tl_shift) # 0 right after a turn passes
	g.save()
	for i in range(list.size() - 1, -1, -1):
		var u = list[i]
		var cx = xa + step * (float(i) + 0.5) + step * (1.0 - sh)
		if cx > xb - r * 0.4: continue
		var a = 1.0 if i < n - 1 else 0.6
		var col: Color = FOE if u.team == "red" else GOLD
		g._alpha = a
		portrait(g, u, Vector2(cx, y), r, col, 1.3)
		if u.team == "red":
			g.text(str(u.letter), cx + r * 0.7, y + r * 0.75, 10 * k, PARCH, "center", 3.0)
		if i == 0:
			g.text("NEXT", cx, y + r + 9 * k, 9 * k, GOLD_HI, "center")
	g.restore()
	# active unit: the large diamond with a slow glow
	var act = G.active
	if act != null and not act.dead:
		var glow = 0.5 + 0.5 * sin(t * 3.0)
		for i in 3:
			g.draw_colored_polygon(diamond(bigc, R + 3 + i * 3 + glow * 2), Color(1.0, 0.62, 0.25, 0.08))
		var s = 0.8 + 0.2 * ease_out(1.0 - tl_shift)
		portrait(g, act, bigc, R * s, GOLD_HI if act.team == "blue" else FOE, 2.0)
		var nm: String = str(act.name).to_upper()
		var old: Font = g._font_override
		g._font_override = g.FONT_TITLE
		g.text(nm, bigc.x - R + 2, y + R + 11 * k, 12 * k, PARCH, "left", 3.0)
		g._font_override = old
		g.text("TURN " + str(G.turn), bigc.x - R + 2, y + R + 25 * k, 9 * k, GOLD, "left", 3.0)

func cmd_rows(g) -> Array:
	var G = g.G
	var u = G.active
	var rows: Array = []
	if G.cmd == "abilities":
		for id in g.loadout_of(u.name):
			if not g.ABILITY_DEFS.has(id): continue
			var ab: Dictionary = g.ABILITY_DEFS[id]
			rows.append({"id": "ab:" + id, "label": str(ab.name), "icon": KIND_ICON.get(str(ab.kind), "bright-mind"), "tip": str(ab.get("blurb", ab.get("desc", ""))),
				"right": "MP 100", "off": float(u.gauge) < g.AB_MP})
		rows.append({"id": "back", "label": "Back", "icon": "", "tip": "", "right": "", "off": false})
	elif G.cmd == "items":
		rows.append({"id": "it:potion", "label": "Potion", "icon": "vital-spark", "tip": "Heals the weakest ally 35%.", "right": "x" + str(G.items.get("potion", 0)), "off": int(G.items.get("potion", 0)) <= 0})
		rows.append({"id": "it:ether", "label": "Ether", "icon": "prayer-knot", "tip": "+50 MP to the active keeper.", "right": "x" + str(G.items.get("ether", 0)), "off": int(G.items.get("ether", 0)) <= 0})
		rows.append({"id": "back", "label": "Back", "icon": "", "tip": "", "right": "", "off": false})
	elif G.cmd == "target":
		for e in g.alive("red"):
			rows.append({"id": "tg", "unit": e, "label": str(e.name), "icon": "", "tip": "Tap a foe on the field or pick one here.", "right": str(e.letter), "off": false})
		rows.append({"id": "back", "label": "Back", "icon": "", "tip": "", "right": "", "off": false})
	else:
		for c in CMDS:
			var off: bool = c[0] == "abilities" and float(u.gauge) < g.AB_MP
			rows.append({"id": c[0], "label": c[1], "icon": c[2], "tip": c[3], "right": "", "off": off})
	return rows

func run_row(g, row: Dictionary) -> void:
	var G = g.G
	var id: String = row.id
	if row.get("off", false) and id != "abilities":
		g.sfx.tone(220, 0.05, "square", 0.02); return
	match id:
		"attack": g.cmd_attack()
		"abilities": G.cmd = "abilities"; g.cmd_hover = 0; g.sfx.tone(660, 0.04, "triangle", 0.03)
		"defend": g.cmd_defend()
		"items": G.cmd = "items"; g.cmd_hover = 0; g.sfx.tone(660, 0.04, "triangle", 0.03)
		"escape": g.run_away()
		"back": G.cmd = ""; G.pending = {}; g.cmd_hover = 0; g.sfx.tone(440, 0.04, "triangle", 0.03)
		"tg": g.cmd_target(row.unit)
		_:
			if id.begins_with("ab:"): g.cmd_ability(id.substr(3))
			elif id.begins_with("it:"): g.cmd_item(id.substr(3))

func panel_rect(g) -> Rect2:
	var w = 236.0 * k
	var x: float = g.VWc - g.SAFE_R - 12.0 * k - w
	var y: float = g.SAFE_T + 112.0 * k
	return Rect2(x, y, w, 0)

func draw_command(g) -> void:
	var G = g.G
	var u = G.active
	if u == null: return
	var rows = cmd_rows(g)
	g.cmd_hover = clampi(g.cmd_hover, 0, rows.size() - 1)
	var e = ease_out(panel_in)
	var pr = panel_rect(g)
	var rh = 36.0 * k
	var head = 40.0 * k
	var h = head + rows.size() * (rh + 4.0 * k) + 10.0 * k
	var r = Rect2(pr.position.x + (1.0 - e) * 46.0, pr.position.y, pr.size.x, h)
	g.save(); g._alpha = e
	# hero bust rising out of the panel top
	var tex: Texture2D = g.IMG.get(u.K.img, null)
	if tex != null:
		var f: Dictionary = u.K.f
		var fw = float(f.fw); var fh = float(f.fh)
		var bh = 60.0 * k
		var bw = bh * fw / (fh * 0.55)
		var src = Rect2(0, 0, fw, fh * 0.55)
		var dst = Rect2(r.end.x - bw - 6 * k, r.position.y - bh + 14 * k, -bw, bh)
		g.draw_texture_rect_region(tex, dst, src, Color(1, 1, 1, e))
	g.rbox(r, 18, Color(0.08, 0.068, 0.055, 0.86), Color.WHITE, 1.4, 6)
	var old: Font = g._font_override
	g._font_override = g.FONT_TITLE
	var title: String = {"abilities": "ABILITIES", "items": "ITEMS", "target": "CHOOSE A TARGET"}.get(G.cmd, str(u.name).to_upper())
	g.text(title, r.position.x + 16 * k, r.position.y + head * 0.55, 15 * k, PARCH, "left")
	g._font_override = old
	var gy: float = r.position.y + head - 2
	g.draw_line(Vector2(r.position.x + 14 * k, gy), Vector2(r.end.x - 14 * k, gy), Color(GOLD.r, GOLD.g, GOLD.b, 0.45), 1.0)
	var mouse: Vector2 = g.mouse_pos
	for i in rows.size():
		var row: Dictionary = rows[i]
		var rr = Rect2(r.position.x + 10 * k, gy + 6 * k + i * (rh + 4 * k), r.size.x - 20 * k, rh)
		if rr.has_point(mouse) and g.mouse_moved: g.cmd_hover = i
		var hot: bool = g.cmd_hover == i
		var off: bool = row.get("off", false)
		if hot:
			var sweep = 0.6 + 0.4 * sin(t * 4.0)
			g.draw_polygon(g.af_chamfer(rr, 8 * k), PackedColorArray([Color(0.93, 0.48, 0.23, 0.42 * sweep), Color(0.93, 0.48, 0.23, 0.08), Color(0.93, 0.48, 0.23, 0.08), Color(0.93, 0.48, 0.23, 0.08), Color(0.93, 0.48, 0.23, 0.42 * sweep), Color(0.93, 0.48, 0.23, 0.42 * sweep)]))
			g.draw_polyline(closed(g.af_chamfer(rr, 8 * k)), GOLD, 1.2, true)
			g.draw_colored_polygon(diamond(Vector2(rr.position.x - 2, rr.get_center().y), 4.5 * k), GOLD_HI)
		else:
			g.draw_polyline(closed(g.af_chamfer(rr, 8 * k)), Color(GOLD.r, GOLD.g, GOLD.b, 0.22), 1.0, true)
		var lx = rr.position.x + 12 * k
		var ik: String = row.get("icon", "")
		if ic.has(ik):
			var isz = rh - 10 * k
			var ir = Rect2(lx, rr.get_center().y - isz / 2.0, isz, isz)
			g.draw_colored_polygon(g.af_chamfer(ir, isz * 0.22), INK)
			g.draw_polyline(closed(g.af_chamfer(ir, isz * 0.22)), Color(GOLD.r, GOLD.g, GOLD.b, 0.7), 1.0, true)
			g.draw_texture_rect(ic[ik], ir.grow(-isz * 0.12), false, Color(1, 1, 1, 0.45 if off else 1.0))
			lx += isz + 10 * k
		elif row.has("unit"):
			portrait(g, row.unit, Vector2(lx + 10 * k, rr.get_center().y), 12 * k, FOE, 1.0)
			lx += 28 * k
		var fg: Color = PARCH_DIM.darkened(0.3) if off else (GOLD_HI if hot else PARCH)
		g.text(spaced(str(row.label).to_upper()), lx, rr.get_center().y, 13 * k, fg, "left")
		if str(row.get("right", "")) != "":
			g.text(str(row.right), rr.end.x - 10 * k, rr.get_center().y, 11 * k, MP_B if str(row.right).begins_with("MP") else PARCH_DIM, "right")
		g.add_btn("cmd_%d_%s" % [i, row.id], rr, func(): g.cmd_hover = i; run_row(g, row))
	# tooltip to the left of the highlighted command
	if g.tips_on and g.cmd_hover < rows.size() and str(rows[g.cmd_hover].tip) != "":
		var tip: String = rows[g.cmd_hover].tip
		var tw = 200.0 * k
		var lines: Array = g.wrap_words(tip, 12 * k, tw - 20 * k)
		var th = 14 * k + lines.size() * 15 * k
		var ty = gy + 6 * k + g.cmd_hover * (rh + 4 * k) + rh / 2.0 - th / 2.0
		var tr = Rect2(r.position.x - tw - 8 * k, ty, tw, th)
		g.rbox(tr, 10, Color(0.06, 0.05, 0.04, 0.92), Color.WHITE, 1.0, 3)
		for li in lines.size():
			g.text(str(lines[li]), tr.position.x + 10 * k, tr.position.y + 7 * k + 7.5 * k + li * 15 * k, 12 * k, PARCH, "left")
	g.restore()

static func spaced(s: String) -> String:
	# letter-spaced uppercase labels, like the Airron's Fall menu items
	var out = ""
	for i in s.length():
		out += s[i]
		if i < s.length() - 1 and s[i] != " ": out += "\u200a"
	return out

func draw_auto_panel(g) -> void:
	var pr = panel_rect(g)
	var r = Rect2(pr.position.x + pr.size.x * 0.25, g.SAFE_T + 74.0 * k, pr.size.x * 0.75, 66 * k)
	g.rbox(r, 14, Color(0.08, 0.068, 0.055, 0.8), Color.WHITE, 1.2, 4)
	var old: Font = g._font_override
	g._font_override = g.FONT_TITLE
	g.text("AUTO BATTLE", r.position.x + 14 * k, r.position.y + 17 * k, 12 * k, GOLD_HI, "left")
	g._font_override = old
	g.text("Keepers follow their Build plan", r.position.x + 14 * k, r.position.y + 34 * k, 11 * k, PARCH_DIM, "left")
	var br = Rect2(r.position.x + 12 * k, r.position.y + 44 * k, r.size.x - 24 * k, 16 * k)
	g.text("tap AUTO below to take command", br.get_center().x, br.get_center().y, 10 * k, GOLD, "center")

func draw_cards(g) -> void:
	var G = g.G
	var party: Array = G.units.filter(func(x): return x.team == "blue")
	if party.is_empty(): return
	var x1: float = g.VWc - g.SAFE_R - 10.0 * k
	var x0: float = maxf(g.VWc * 0.3, g.SAFE_L + 250.0 * k)
	var gap = 6.0 * k
	var cw = minf(156.0 * k, (x1 - x0 - gap * (party.size() - 1)) / party.size())
	var ch = 72.0 * k
	var y: float = g.VHc - g.SAFE_B - 8.0 * k - ch
	var x = x1 - cw * party.size() - gap * (party.size() - 1)
	for u in party:
		var lift: float = float(raise.get(u, 0.0))
		var r = Rect2(x, y - lift * 12.0 * k, cw, ch)
		var hot: bool = G.active == u
		if hot:
			for i in 3:
				g.draw_colored_polygon(g.af_chamfer(r.grow(2.0 + i * 2.5), 12 * k), Color(1.0, 0.6, 0.25, 0.07 * lift))
		var fill = Color(0.09, 0.075, 0.06, 0.88).lerp(Color(0.16, 0.11, 0.07, 0.94), lift)
		g.save()
		if u.dead: g._alpha = 0.55
		g.rbox(r, 16, fill, Color.WHITE if hot else Color(GOLD.r, GOLD.g, GOLD.b, 0.5), 1.3 if hot else 1.0, 3)
		var px = r.position.x + 9 * k
		var nm: String = str(u.name).to_upper()
		var fs = 12.0 * k
		while fs > 8 and g.text_w(nm, fs) > cw - 58 * k: fs -= 0.5
		g.text(nm, px, r.position.y + 12 * k, fs, GOLD_HI if hot else PARCH, "left")
		# class / level chip
		var lv = str(g.hero_level(u.name)) if g.CHAR.has(u.name) else "1"
		var chip = str(u.cls).substr(0, 3).to_upper() + " " + lv
		var cwid: float = g.text_w(chip, 9 * k) + 10 * k
		var cr = Rect2(r.end.x - cwid - 7 * k, r.position.y + 5 * k, cwid, 14 * k)
		g.draw_colored_polygon(g.af_chamfer(cr, 4 * k), INK)
		g.draw_polyline(closed(g.af_chamfer(cr, 4 * k)), Color(GOLD.r, GOLD.g, GOLD.b, 0.8 if hot else 0.4), 1.0, true)
		g.text(chip, cr.get_center().x, cr.get_center().y, 9 * k, GOLD if hot else PARCH_DIM)
		var bw = cw - 18 * k
		var hp: float = clampf(float(u.hp) / maxf(1.0, float(u.maxhp)), 0.0, 1.0)
		var mp: float = clampf(float(u.gauge) / g.AB_MP, 0.0, 1.0)
		var by = r.position.y + 25 * k
		g.text("HP", px, by + 5 * k, 9 * k, PARCH_DIM, "left")
		g.text(str(maxi(0, int(u.hp))), r.end.x - 9 * k, by + 5 * k, 12 * k, PARCH, "right")
		bar(g, Rect2(px, by + 12 * k, bw, 4 * k), hp, HP_G if hp > 0.3 else FOE)
		by += 20 * k
		g.text("MP", px, by + 5 * k, 9 * k, PARCH_DIM, "left")
		g.text(str(int(u.gauge)), r.end.x - 9 * k, by + 5 * k, 12 * k, PARCH, "right")
		bar(g, Rect2(px, by + 12 * k, bw, 4 * k), mp, MP_B, mp >= 1.0)
		# two small gauge slots: buffs up / ready ability
		var sy = r.end.y - 9 * k
		var ready = mp >= 1.0
		var buffed: bool = u.buffs.size() > 0
		for si in 2:
			var on: bool = ready if si == 0 else buffed
			var sc = Vector2(px + 4 * k + si * 12 * k, sy)
			g.draw_colored_polygon(diamond(sc, 4 * k), (MP_B if si == 0 else GOLD_HI) if on else Color(0.2, 0.17, 0.13))
		if u.dead:
			g.text("FALLEN", r.get_center().x, r.end.y - 9 * k, 9 * k, FOE, "center")
		g.restore()
		x += cw + gap

func bar(g, r: Rect2, v: float, col: Color, full_glow := false) -> void:
	g.draw_rect(r.grow(1), Color(0, 0, 0, 0.7))
	g.draw_rect(Rect2(r.position, Vector2(r.size.x * v, r.size.y)), col)
	g.draw_rect(Rect2(r.position, Vector2(r.size.x * v, r.size.y * 0.4)), Color(1, 1, 1, 0.18))
	if full_glow:
		var p = 0.5 + 0.5 * sin(t * 6.0)
		g.draw_rect(r.grow(2), Color(col.r, col.g, col.b, 0.25 * p), false, 1.5)

func draw_bar(g) -> void:
	var x: float = g.SAFE_L + 10.0 * k
	var h = 30.0 * k
	var y: float = g.VHc - g.SAFE_B - 8.0 * k - h
	var items = [
		["spd", ">".repeat(g.speed), "Battle speed", func(): g.toggle_speed()],
		["auto", "AUTO", "Auto battle", func(): g.toggle_auto()],
		["pause", "II", "Pause", func(): g.toggle_pause()],
		["tips", "HIDE TIPS" if g.tips_on else "SHOW TIPS", "", func(): g.tips_on = not g.tips_on],
	]
	var tot = 0.0
	var ws: Array = []
	for it in items:
		var w: float = maxf(40.0 * k, g.text_w(it[1], 12 * k) + 22 * k)
		ws.append(w); tot += w + 4 * k
	var back = Rect2(x - 4 * k, y - 4 * k, tot + 4 * k, h + 8 * k)
	g.rbox(back, 10, Color(0.06, 0.05, 0.04, 0.72), Color.WHITE, 1.0)
	for i in items.size():
		var it: Array = items[i]
		var r = Rect2(x, y, ws[i], h)
		var on: bool = (it[0] == "auto" and g.AUTO) or (it[0] == "spd" and g.speed > 1) or (it[0] == "pause" and g.paused)
		var down: bool = g.pressed_id == "hud_" + it[0]
		if on:
			g.draw_polygon(g.af_chamfer(r, 7 * k), PackedColorArray([Color(0.93, 0.48, 0.23, 0.55), Color(0.93, 0.48, 0.23, 0.55), Color(0.6, 0.28, 0.12, 0.55), Color(0.6, 0.28, 0.12, 0.55), Color(0.6, 0.28, 0.12, 0.55), Color(0.93, 0.48, 0.23, 0.55)]))
		g.draw_polyline(closed(g.af_chamfer(r, 7 * k)), GOLD if on or down else Color(GOLD.r, GOLD.g, GOLD.b, 0.35), 1.0, true)
		g.text(str(it[1]), r.get_center().x, r.get_center().y + (1 if down else 0), 12 * k, GOLD_HI if on else PARCH, "center")
		g.add_btn("hud_" + it[0], r, it[3])
		x += ws[i] + 4 * k

## Keyboard: arrows / W S move the highlight, Enter / Space choose, Esc / Backspace go back, A toggles AUTO.
func key(g, kc: int) -> bool:
	if not show_menu(g): return false
	var rows = cmd_rows(g)
	match kc:
		KEY_UP, KEY_W: g.cmd_hover = posmod(g.cmd_hover - 1, rows.size()); g.mouse_moved = false; return true
		KEY_DOWN, KEY_S: g.cmd_hover = posmod(g.cmd_hover + 1, rows.size()); g.mouse_moved = false; return true
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE: run_row(g, rows[clampi(g.cmd_hover, 0, rows.size() - 1)]); return true
		KEY_ESCAPE, KEY_BACKSPACE:
			if g.G.cmd != "": run_row(g, {"id": "back"}); return true
	return false
