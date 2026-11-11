extends RefCounted
# Stats screen: COMPARE (every hero side by side, best value per stat highlighted) and
# BREAKDOWN (one hero; what Base, Class, Subclass, Level, Focus and Gear each add).
# Reads the game node's data (HERO_BASE, CLASS_DEFS, SUB_DEFS, ITEM_DEFS, EQUIP …).

const KEYS := ["hp", "atk", "def", "armor", "crit", "mana", "speed"]
const LABELS := {"hp": "HP", "atk": "ATK", "def": "DEF", "armor": "ARMOR", "crit": "CRIT", "mana": "MANA", "speed": "SPEED"}
var mode := "compare"
var hero := 0


func open(start_hero: int = 0) -> void:
	hero = start_hero


func _pack(src: Dictionary) -> Dictionary:
	var d: Dictionary = {}
	for k in KEYS:
		d[k] = int(src.get(k, 0))
	return d


func breakdown(g: Object, name: String) -> Dictionary:
	var loadout: Dictionary = g.CHAR.get(name, {})
	var cls: String = str(loadout.get("cls", "Knight"))
	var sub: String = str(loadout.get("sub", "Riftblade"))
	var base: Dictionary = _pack(g.HERO_BASE.get(name, {}))
	var cpk: Dictionary = _pack(g.CLASS_DEFS.get(cls, {}))
	var spk: Dictionary = _pack(g.SUB_DEFS.get(sub, {}))
	var lv: int = g.hero_level(name)
	var lvl_all: Dictionary = _pack(g.level_bonus(lv, sub))
	var focus: String = g.sub_focus_stat(sub)
	# Focus share = this sub's level bonus minus a sub with a different focus.
	var other_sub := sub
	for s in g.SUB_FOCUS.keys():
		if str(g.SUB_FOCUS[s]) != focus:
			other_sub = str(s)
			break
	var lvl_other: Dictionary = _pack(g.level_bonus(lv, other_sub))
	var fpk: Dictionary = {}
	var lpk: Dictionary = {}
	for k in KEYS:
		fpk[k] = 0
		lpk[k] = int(lvl_all[k])
	if other_sub != sub:
		fpk[focus] = int(lvl_all[focus]) - int(lvl_other[focus])
		lpk[focus] = int(lvl_all[focus]) - int(fpk[focus])
	var gpk: Dictionary = _pack({})
	var gear_names: Array = []
	var eq: Dictionary = g.EQUIP.get(name, {})
	for slot in g.SLOT_IDS:
		var iid: String = str(eq.get(slot, ""))
		if iid != "" and g.ITEM_DEFS.has(iid):
			var it: Dictionary = g.ITEM_DEFS[iid]
			gear_names.append(str(it.get("name", iid)))
			for k in KEYS:
				gpk[k] = int(gpk[k]) + int(it.get(k, 0))
	var fin: Dictionary = g.compute_hero_stats(name)
	return {"cls": cls, "sub": sub, "level": lv, "focus": focus, "gear": gear_names,
		"cols": [["Base", base], ["Class", cpk], ["Sub", spk], ["Level", lpk], ["Focus", fpk], ["Gear", gpk]], "final": fin}


func draw(g: Object, vw: float, vh: float) -> void:
	g.draw_rect(Rect2(0, 0, vw, vh), Color(0.06, 0.12, 0.13, 0.94))
	var short: bool = vh <= 430
	var bh: float = 40.0 if short else 48.0
	g.ui_button("st_back", Rect2(8, 6, 104.0 if short else 120.0, bh), "BACK", true, 16, 28, func(): g.close_stats())
	var tw: float = 130.0 if short else 150.0
	g.ui_button("st_cmp", Rect2(vw / 2 - tw - 4, 6, tw, bh), "COMPARE", mode != "compare", 15, 28, func(): mode = "compare")
	g.ui_button("st_brk", Rect2(vw / 2 + 4, 6, tw, bh), "BREAKDOWN", mode != "breakdown", 15, 28, func(): mode = "breakdown")
	var top: float = 6 + bh + 8
	var panel := Rect2(8, top, vw - 16, vh - top - 8)
	g.css9(g.IMG.carved, panel.position.x, panel.position.y, panel.size.x, panel.size.y, 20.0 if short else 26.0)
	var inner := panel.grow(-(18.0 if short else 24.0))
	if mode == "compare":
		_draw_compare(g, inner, short)
	else:
		_draw_breakdown(g, inner, short)


func _draw_compare(g: Object, r: Rect2, short: bool) -> void:
	var names: Array = g.SQUAD.duplicate()
	var n: int = names.size()
	var label_w: float = minf(90.0, r.size.x * 0.16)
	var cw: float = (r.size.x - label_w) / maxf(1.0, float(n))
	var rows: int = KEYS.size() + 3 # header, class/sub, level + stats
	var rh: float = minf(34.0, r.size.y / float(rows))
	var fs: float = clampf(rh * 0.46, 11.0, 16.0)
	var ink := Color("#3a2412")
	var y: float = r.position.y
	var finals: Array = []
	for nm in names:
		finals.append(g.compute_hero_stats(str(nm)))
	for i in n:
		var x: float = r.position.x + label_w + cw * i + cw / 2
		var nm2: String = str(names[i])
		var col: Color = Color("#1c4f8a") if i < g.PARTY_SIZE else Color("#7a6a55")
		g.text(nm2, x, y + rh * 0.5, fs * 1.05, col, "center")
		g.add_btn("st_h%d" % i, Rect2(x - cw / 2, y, cw, rh * 3), func(): _pick(i))
	g.text("Party", r.position.x, y + rh * 0.5, fs * 0.85, Color("#7a4a1c"), "left")
	y += rh
	for i in n:
		var x2: float = r.position.x + label_w + cw * i + cw / 2
		var f: Dictionary = finals[i]
		g.text(str(f.cls) + " / " + str(f.sub), x2, y + rh * 0.5, fs * 0.78, ink, "center")
	g.text("Class", r.position.x, y + rh * 0.5, fs * 0.85, Color("#7a4a1c"), "left")
	y += rh
	for i in n:
		var x3: float = r.position.x + label_w + cw * i + cw / 2
		var f2: Dictionary = finals[i]
		g.text("Lv." + str(int(f2.level)) + (" · bench" if i >= g.PARTY_SIZE else ""), x3, y + rh * 0.5, fs * 0.8, ink, "center")
	g.text("Level", r.position.x, y + rh * 0.5, fs * 0.85, Color("#7a4a1c"), "left")
	y += rh
	for ki in KEYS.size():
		var k: String = KEYS[ki]
		if ki % 2 == 0:
			g.draw_rect(Rect2(r.position.x - 4, y, r.size.x + 8, rh), Color(0.55, 0.35, 0.15, 0.10))
		g.text(LABELS[k], r.position.x, y + rh * 0.5, fs, Color("#7a4a1c"), "left")
		var best := -1
		var worst := 1 << 30
		for f3 in finals:
			best = maxi(best, int(f3[k]))
			worst = mini(worst, int(f3[k]))
		var vmax: float = maxf(1.0, float(best))
		for i in n:
			var x4: float = r.position.x + label_w + cw * i
			var v: int = int(finals[i][k])
			var bw: float = (cw - 14) * float(v) / vmax
			g.draw_rect(Rect2(x4 + 7, y + rh - 7, bw, 4), Color("#2a6fb0") if v == best else Color(0.35, 0.25, 0.15, 0.35))
			var vc: Color = Color("#1c6a3a") if v == best else (Color("#9e2c2c") if v == worst and best != worst else ink)
			g.text(str(v), x4 + cw / 2, y + rh * 0.42, fs * 1.05, vc, "center")
		y += rh
	g.text("Green = best, red = lowest. Tap a name for the full breakdown.", r.get_center().x, minf(y + rh * 0.5, r.end.y - 4), fs * 0.78, Color("#6b4a2a"), "center")


func _pick(i: int) -> void:
	hero = i
	mode = "breakdown"


func _draw_breakdown(g: Object, r: Rect2, short: bool) -> void:
	var names: Array = g.SQUAD
	hero = clampi(hero, 0, names.size() - 1)
	var name: String = str(names[hero])
	var b: Dictionary = breakdown(g, name)
	var ink := Color("#3a2412")
	var bw: float = 44.0
	g.ui_button("st_prev", Rect2(r.position.x, r.position.y - 4, bw, 40), "<", false, 18, 16, func(): hero = (hero - 1 + names.size()) % names.size())
	g.ui_button("st_next", Rect2(r.end.x - bw, r.position.y - 4, bw, 40), ">", false, 18, 16, func(): hero = (hero + 1) % names.size())
	var fs: float = 17.0 if short else 20.0
	g.text(name + "  ·  Lv." + str(int(b.level)), r.get_center().x, r.position.y + 10, fs, Color("#1c4f8a"), "center")
	var gear: Array = b.gear
	var sub_line: String = str(b.cls) + " / " + str(b.sub) + "  ·  Focus " + str(g.FOCUS_LABELS.get(str(b.focus), "ATK")) + "  ·  Gear: " + (", ".join(gear) if gear.size() > 0 else "none")
	g.text(sub_line, r.get_center().x, r.position.y + 10 + fs, 12.0 if short else 13.0, ink, "center")
	var y: float = r.position.y + 14 + fs * 2.0
	var cols: Array = b.cols
	var label_w: float = minf(80.0, r.size.x * 0.14)
	var ncol: int = cols.size() + 1
	var cw: float = (r.size.x - label_w) / float(ncol)
	var rows: int = KEYS.size() + 1
	var rh: float = minf(32.0, (r.end.y - y) / float(rows))
	var tfs: float = clampf(rh * 0.5, 11.0, 16.0)
	for ci in cols.size():
		g.text(str(cols[ci][0]), r.position.x + label_w + cw * ci + cw / 2, y + rh * 0.5, tfs * 0.9, Color("#7a4a1c"), "center")
	g.text("TOTAL", r.position.x + label_w + cw * cols.size() + cw / 2, y + rh * 0.5, tfs * 0.9, Color("#1c4f8a"), "center")
	y += rh
	var fin: Dictionary = b.final
	for ki in KEYS.size():
		var k: String = KEYS[ki]
		if ki % 2 == 0:
			g.draw_rect(Rect2(r.position.x - 4, y, r.size.x + 8, rh), Color(0.55, 0.35, 0.15, 0.10))
		g.text(LABELS[k], r.position.x, y + rh * 0.5, tfs, Color("#7a4a1c"), "left")
		var sum := 0
		for ci in cols.size():
			var v: int = int(cols[ci][1][k])
			sum += v
			var s: String = str(v)
			var c: Color = ink
			if ci > 0:
				if v > 0:
					s = "+" + str(v)
					c = Color("#1c6a3a")
				elif v < 0:
					c = Color("#9e2c2c")
				else:
					s = "·"
					c = Color(0.35, 0.25, 0.15, 0.4)
			g.text(s, r.position.x + label_w + cw * ci + cw / 2, y + rh * 0.5, tfs, c, "center")
		var tot: int = int(fin[k])
		var capped: bool = tot != sum
		g.text(str(tot) + ("*" if capped else ""), r.position.x + label_w + cw * cols.size() + cw / 2, y + rh * 0.5, tfs * 1.1, Color("#1c4f8a"), "center")
		y += rh
	g.text("Focus = extra level growth on the subclass's focus stat.  * = clamped to the stat cap/floor.", r.get_center().x, minf(y + 10, r.end.y - 2), 11.0, Color("#6b4a2a"), "center")
