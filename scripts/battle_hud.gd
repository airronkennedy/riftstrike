extends RefCounted
## Airron's Quest side-view battle HUD, drawn in the Airron's Fall UI language (chamfered ash panels,
## gold hairlines, Cinzel headings, Rajdhani labels, parchment text) with a modern finish:
## combo counter pops, SPARK feedback, a target-select prompt with countdown, warm lighting and drifting embers.
## Battles are always automatic (team turns, scripts/combo_turn.gd). Layout (landscape): combo counter upper right,
## target-select prompt top centre, party cards bottom right, speed / AUTO / pause / tips bar bottom left.

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

const ICONS := ["greatsword-slash", "chain-spark", "ember-aegis", "field-medkit", "swift-feet", "chest", "vital-spark",
	"second-wind", "bright-mind", "ember-bolt", "prayer-knot", "starfall", "spire-lance", "bellstroke"]
const KIND_ICON := {"damage_single": "spire-lance", "damage_all_enemies": "starfall", "buff_self": "ember-aegis",
	"buff_party": "bellstroke", "heal_single": "vital-spark", "heal_party": "prayer-knot"}

var ic := {}
var last_hits := 0
var hit_pop := 0.0 # 1 -> 0 after each new combo hit
var spark_pop := 0.0
var last_sparks := 0
var sel_in := 0.0 # 0..1 target prompt slide
var raise := {} # unit -> 0..1 card lift
var embers: Array = []
var ember_acc := 0.0
var t := 0.0
var k := 1.0 # UI scale
var tips_hover := -1
var auto_pick = null # target-select preview: the foe the Auto target setting would pick

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
	k = clampf(minf(g.VHc, g.VWc * 1.25) / 560.0, 0.82, 1.25)
	var tc = G.turnc
	if tc != null and tc.team == "blue":
		if tc.hits > last_hits: hit_pop = 1.0
		if tc.sparks > last_sparks: spark_pop = 1.0
		last_hits = tc.hits; last_sparks = tc.sparks
	hit_pop = maxf(0.0, hit_pop - dt * 6.0)
	spark_pop = maxf(0.0, spark_pop - dt * 4.0)
	sel_in = clampf(sel_in + (dt * 5.0 if selecting(g) else -dt * 7.0), 0.0, 1.0)
	auto_pick = g.bf_auto_target() if selecting(g) else null
	for u in G.units:
		if u.team != "blue": continue
		var striking: bool = tc != null and tc.running and tc.team == "blue" and absf(u.x - u.hx) > 4.0
		raise[u] = lerpf(float(raise.get(u, 0.0)), 1.0 if striking or u.gauge >= g.AB_MP else 0.0, minf(1.0, dt * 10.0))
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

func selecting(g) -> bool:
	var G = g.G
	return g.phase == "battle" and G != null and G.bf and G.mode == "select" and not g.AUTO

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
		var focused: bool = G.focus == u
		if selecting(g) and G.focus == null and auto_pick == u:
			# who the team will hit if the countdown runs out (the Auto target setting)
			var ap = 0.5 + 0.5 * sin(t * 4.0)
			g.stroke_ellipse(x, u.y - 2, 38 + ap * 4, 12 + ap * 2, Color(0.62, 0.86, 1.0, 0.55 + 0.35 * ap), 2.0)
			g.text("AUTO", x, top - 12.0, 10, Color(0.72, 0.9, 1.0))
		if selecting(g) or focused:
			var p = 0.5 + 0.5 * sin(t * (9.0 if focused else 5.0))
			var c = GOLD_HI if focused else Color(GOLD_HI.r, GOLD_HI.g, GOLD_HI.b, 0.35 + 0.3 * p)
			g.stroke_ellipse(x, u.y - 2, 34 + p * 5, 11 + p * 2, c, 2.4 if focused else 1.6)
			if focused:
				var cy = u.y - h * 0.55
				var rr = 20.0 + p * 3.0
				for a in 4:
					var ang = a * PI / 2.0 + t * 1.4
					var d = Vector2(cos(ang), sin(ang))
					g.draw_line(Vector2(x, cy) + d * rr, Vector2(x, cy) + d * (rr + 9.0), GOLD_HI, 2.0)
				g.text("FOCUS", x, top - 12.0, 10, GOLD_HI)

static func diamond(c: Vector2, r: float) -> PackedVector2Array:
	return PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])

static func closed(p: PackedVector2Array) -> PackedVector2Array:
	var q = p.duplicate(); q.append(p[0]); return q

# ---------------------------------------------------------------- HUD (screen space)
func draw(g) -> void:
	var G = g.G
	if G == null: return
	draw_vignette(g)
	draw_combo(g)
	if sel_in > 0.01: draw_select(g)
	draw_summary(g)
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

## Big escalating hit counter while the party strikes (and briefly after).
func draw_combo(g) -> void:
	var G = g.G
	var tc = G.turnc
	if tc == null: return
	var live: bool = tc.running and tc.team == "blue"
	var n: int = tc.hits if live else int(G.summary.get("hits", 0))
	var age: float = 0.0 if live else float(G.summary.get("t", 99999.0))
	if n <= 0 or age > 1500.0: return
	if not live and g.VHc > g.VWc: return # portrait: the summary plate takes over
	var a = 1.0 if age < 1100.0 else 1.0 - (age - 1100.0) / 400.0
	var sp: int = tc.sparks if live else int(G.summary.get("sparks", 0))
	var x: float = g.VWc - g.SAFE_R - 24.0 * k
	var y: float = g.SAFE_T + (64.0 if g.VHc > g.VWc else 96.0) * k
	var col = PARCH
	if n >= 30: col = Color("#b8ff6a")
	elif n >= 20: col = EMBER
	elif n >= 10: col = GOLD_HI
	var sc = 1.0 + 0.35 * ease_out(hit_pop)
	var fs = (40.0 + minf(float(n), 40.0) * 0.5) * k * sc
	var old: Font = g._font_override
	g._font_override = g.FONT_TITLE
	g.save(); g._alpha = a
	# soft dark plate so the counter reads over busy fights
	for i in 4:
		g.fill_ellipse(x - 60.0 * k, y + 12.0 * k, (120.0 - i * 18.0) * k, (46.0 - i * 7.0) * k, Color(0.02, 0.015, 0.01, 0.16))
	g.text(str(n), x - 70.0 * k, y, fs, col, "right", 5.0, Color(0.06, 0.03, 0.02, 0.95))
	g.text("HITS", x, y + 4.0 * k, 18.0 * k, GOLD_HI, "right", 3.0, Color(0.06, 0.03, 0.02, 0.95))
	g._font_override = old
	if sp > 0:
		var ss = 1.0 + 0.4 * ease_out(spark_pop)
		g.text("%d SPARK%s" % [sp, "" if sp == 1 else "S"], x, y + 32.0 * k, 15.0 * k * ss, Color("#c8ff7a"), "right", 3.0, Color(0.04, 0.06, 0.02, 0.95))
	g.restore()

## Turn summary plate after the party's turn: total hits, sparks, spark rate, damage.
func draw_summary(g) -> void:
	var G = g.G
	if not G.summary.has("t") or g.phase != "battle": return
	var age: float = float(G.summary.t)
	if age > 1600.0 or int(G.summary.hits) <= 0: return
	var ain = ease_out(age / 180.0)
	var a = ain if age < 1250.0 else 1.0 - (age - 1250.0) / 350.0
	var w = minf(360.0 * k, g.VWc - 16.0)
	var h = 54.0 * k
	var r = Rect2((g.VWc - w) / 2.0, g.SAFE_T + 14.0 * k - (1.0 - ain) * 14.0, w, h)
	g.save(); g._alpha = a
	g.rbox(r, 14, Color(0.07, 0.055, 0.045, 0.9), Color.WHITE, 1.2, 4)
	var old: Font = g._font_override
	g._font_override = g.FONT_TITLE
	g.text("COMBO  %d HITS" % int(G.summary.hits), r.get_center().x, r.position.y + 18.0 * k, 17.0 * k, GOLD_HI)
	g._font_override = old
	var line = "%d sparks (%d%%)  ·  %d damage" % [int(G.summary.sparks), int(roundf(float(G.summary.rate) * 100.0)), int(G.summary.dmg)]
	g.text(line, r.get_center().x, r.position.y + 38.0 * k, 12.0 * k, Color("#c8ff7a") if int(G.summary.sparks) > 0 else PARCH_DIM)
	g.restore()

## Target select: tap an enemy to focus the whole party, GO to attack now, or wait for the countdown.
func draw_select(g) -> void:
	var G = g.G
	var w = minf(430.0 * k, g.VWc * 0.6) if g.VWc > g.VHc else g.VWc - 16.0
	var h = 62.0 * k
	var e = ease_out(sel_in)
	var r = Rect2((g.VWc - w) / 2.0, g.SAFE_T + 10.0 * k - (1.0 - e) * 30.0, w, h)
	g.save(); g._alpha = e
	g.rbox(r, 14, Color(0.07, 0.058, 0.046, 0.9), Color.WHITE, 1.2, 4)
	var old: Font = g._font_override
	g._font_override = g.FONT_TITLE
	var head = "FOCUS: " + str(G.focus.name).to_upper() if G.focus != null and not G.focus.dead else "TAP A FOE  ·  AUTO: " + TargetSelect.label().to_upper()
	g.text(head, r.position.x + 16.0 * k, r.position.y + 17.0 * k, g.fit_size(head, 14.0 * k, w - 120.0 * k, 9.0), GOLD_HI, "left")
	g._font_override = old
	var order: Array = g.bf_order("blue")
	var names: Array = []
	for u in order: names.append(str(u.name))
	var sub = "Order: " + " > ".join(names)
	g.text(sub, r.position.x + 16.0 * k, r.position.y + 34.0 * k, g.fit_size(sub, 11.0 * k, w - 120.0 * k, 8.0), PARCH_DIM, "left")
	# countdown bar
	var frac = clampf(float(G.sel_t) / g.SELECT_MS, 0.0, 1.0)
	var br = Rect2(r.position.x + 16.0 * k, r.end.y - 12.0 * k, w - 120.0 * k, 4.0 * k)
	bar(g, br, frac, EMBER)
	g.text("auto in %.1fs" % (float(G.sel_t) / 1000.0) if not g.paused else "paused", br.end.x, br.position.y - 7.0 * k, 9.0 * k, PARCH_DIM, "right")
	var gb = Rect2(r.end.x - 92.0 * k, r.position.y + 10.0 * k, 80.0 * k, h - 20.0 * k)
	var p = 0.5 + 0.5 * sin(t * 5.0)
	g.draw_polygon(g.af_chamfer(gb, 8 * k), PackedColorArray([Color(0.93, 0.48, 0.23, 0.7 + 0.2 * p), Color(0.93, 0.48, 0.23, 0.7), Color(0.6, 0.28, 0.12, 0.8), Color(0.6, 0.28, 0.12, 0.8), Color(0.6, 0.28, 0.12, 0.8), Color(0.93, 0.48, 0.23, 0.7)]))
	g.draw_polyline(closed(g.af_chamfer(gb, 8 * k)), GOLD_HI, 1.2, true)
	g._font_override = g.FONT_TITLE
	g.text("GO", gb.get_center().x, gb.get_center().y, 18.0 * k, PARCH)
	g._font_override = old
	g.restore()
	g.add_btn("hud_go", gb, func(): g.bf_launch())

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
	var port: bool = g.VHc > g.VWc
	var cols: int = 3 if port else party.size()
	var row0_y: float = y
	if port:
		# phone portrait: 3-up grid across the full width, under the bar
		x0 = g.SAFE_L + 8.0 * k
		cw = (x1 - x0 - gap * 2.0) / 3.0
		ch = 60.0 * k
		var rows: int = int(ceil(float(party.size()) / 3.0))
		row0_y = g.VHc - g.SAFE_B - 8.0 * k - float(rows) * ch - float(rows - 1) * gap
	var idx := 0
	for u in party:
		if port:
			x = x0 + float(idx % cols) * (cw + gap)
			y = row0_y + float(idx / cols) * (ch + gap)
		idx += 1
		var lift: float = float(raise.get(u, 0.0))
		var r = Rect2(x, y - lift * 12.0 * k, cw, ch)
		var hot: bool = float(raise.get(u, 0.0)) > 0.5
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
		g.text("BB READY" if mp >= 1.0 else "BB", px, by + 5 * k, 9 * k, YEL if mp >= 1.0 else PARCH_DIM, "left")
		g.text(str(int(u.gauge)), r.end.x - 9 * k, by + 5 * k, 12 * k, PARCH, "right")
		bar(g, Rect2(px, by + 12 * k, bw, 4 * k), mp, YEL if mp >= 1.0 else MP_B, mp >= 1.0)
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
	if g.VHc > g.VWc:
		var n: int = g.G.units.filter(func(q): return q.team == "blue").size()
		var rows: int = int(ceil(float(n) / 3.0))
		y = g.VHc - g.SAFE_B - 8.0 * k - float(rows) * 60.0 * k - float(rows - 1) * 6.0 * k - h - 12.0 * k
	var items = [
		["spd", ">".repeat(g.speed), "Battle speed", func(): g.toggle_speed()],
		["auto", "AUTO", "Skip target select", func(): g.toggle_auto()],
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

## Keyboard in target select: arrows / A D pick the focus, Enter / Space attack now.
func key(g, kc: int) -> bool:
	if not selecting(g): return false
	match kc:
		KEY_LEFT, KEY_UP, KEY_A, KEY_W: g.bf_cycle_focus(-1); return true
		KEY_RIGHT, KEY_DOWN, KEY_D, KEY_S: g.bf_cycle_focus(1); return true
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE: g.bf_launch(); return true
	return false
