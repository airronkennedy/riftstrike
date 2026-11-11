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
	var short: bool = vh <= 430
	var helper: String = "Every hero side by side. Green = best, red = lowest. Tap a name for details." if mode == "compare" else "Where each stat comes from."
	var area: Rect2 = g.menu_sheet("st_back", "Stats", helper, func(): g.close_stats(), ["Compare", "Breakdown"], 0 if mode == "compare" else 1, func(i): mode = "compare" if i == 0 else "breakdown", "st_tab")
	if mode == "compare":
		_draw_compare(g, area, short)
	else:
		_draw_breakdown(g, area, short)


func _draw_compare(g: Object, r: Rect2, short: bool) -> void:
	var names: Array = g.SQUAD.duplicate()
	var n: int = names.size()
	var label_w: float = clampf(r.size.x * 0.13, 62.0, 96.0)
	var cw: float = (r.size.x - label_w) / maxf(1.0, float(n))
	var head_h: float = 50.0 if short else 64.0
	var rg: float = 4.0 if short else 6.0
	var rh: float = minf(40.0, (r.size.y - head_h - 6.0 - rg * float(KEYS.size() - 1)) / float(KEYS.size()))
	var fs: float = clampf(rh * 0.5, 12.0, 17.0)
	var finals: Array = []
	for nm in names:
		finals.append(g.compute_hero_stats(str(nm)))
	# hero header cards (tap for breakdown)
	for i in n:
		var hx: float = r.position.x + label_w + cw * i
		var hr := Rect2(hx + 3.0, r.position.y, cw - 6.0, head_h)
		var bench: bool = i >= g.PARTY_SIZE
		var down: bool = g.pressed_id == "st_h%d" % i
		g.rbox(hr, 18.0, g.UI_CARD, g.UI_TEAL if down else g.UI_LINE, 2.0 if down else 1.5)
		var nm2: String = str(names[i])
		var f: Dictionary = finals[i]
		g.text(nm2, hr.get_center().x, hr.position.y + head_h * 0.27, g.fit_size(nm2, 15.0 if short else 17.0, hr.size.x - 10.0, 10.0), g.UI_INK, "center")
		var l2: String = "Lv." + str(int(f.level)) + "  " + str(f.cls)
		g.text(l2, hr.get_center().x, hr.position.y + head_h * 0.55, g.fit_size(l2, 11.0, hr.size.x - 10.0, 8.0), g.UI_MUTED, "center")
		var tag: String = "Bench" if bench else ("Lead" if i == 0 else str(f.sub))
		g.text(tag, hr.get_center().x, hr.position.y + head_h * 0.8, g.fit_size(tag, 10.0, hr.size.x - 10.0, 7.0), g.UI_GOLD_D if i == 0 else (g.UI_LOCK if bench else g.UI_TEAL_D), "center")
		g.add_btn("st_h%d" % i, hr, func(): _pick(i))
	var y: float = r.position.y + head_h + 6.0
	for ki in KEYS.size():
		var k: String = KEYS[ki]
		var row := Rect2(r.position.x, y, r.size.x, rh)
		g.rbox(row, rh / 2.0, Color(1, 1, 1, 0.7), g.UI_LINE, 1.0)
		g.text(LABELS[k], r.position.x + 16.0, y + rh * 0.5, fs * 0.85, g.UI_MUTED, "left")
		var best := -1
		var worst := 1 << 30
		for f3 in finals:
			best = maxi(best, int(f3[k]))
			worst = mini(worst, int(f3[k]))
		for i in n:
			var cxx: float = r.position.x + label_w + cw * i + cw / 2.0
			var v: int = int(finals[i][k])
			var s: String = str(v) + ("%" if k == "crit" else "")
			if k == "mana":
				s = "+" + str(v)
			var is_best: bool = v == best and best != worst
			var is_worst: bool = v == worst and best != worst
			if is_best:
				g.chip(s, cxx, y + rh * 0.5, fs, g.UI_GOOD_L, g.UI_GOOD, "center")
			elif is_worst:
				g.chip(s, cxx, y + rh * 0.5, fs, g.UI_BAD_L, g.UI_BAD, "center")
			else:
				g.text(s, cxx, y + rh * 0.5, fs, g.UI_INK, "center")
		y += rh + rg


func _pick(i: int) -> void:
	hero = i
	mode = "breakdown"


func _draw_breakdown(g: Object, r: Rect2, short: bool) -> void:
	var names: Array = g.SQUAD
	hero = clampi(hero, 0, names.size() - 1)
	var name: String = str(names[hero])
	var b: Dictionary = breakdown(g, name)
	var ab: float = 36.0 if short else 42.0
	g.pill("st_prev", Rect2(r.position.x, r.position.y, ab, ab), "", "tealsoft", 18.0, func(): hero = (hero - 1 + names.size()) % names.size(), false, false, false, "", "left")
	g.pill("st_next", Rect2(r.end.x - ab, r.position.y, ab, ab), "", "tealsoft", 18.0, func(): hero = (hero + 1) % names.size(), false, false, false, "", "right")
	var fs: float = 18.0 if short else 22.0
	g.text(name + "  ·  Lv." + str(int(b.level)), r.get_center().x, r.position.y + ab * 0.32, fs, g.UI_INK, "center")
	var gear: Array = b.gear
	var sub_line: String = str(b.cls) + " / " + str(b.sub) + "  ·  Focus " + str(g.FOCUS_LABELS.get(str(b.focus), "ATK")) + "  ·  Gear: " + (", ".join(gear) if gear.size() > 0 else "none")
	g.text(sub_line, r.get_center().x, r.position.y + ab * 0.32 + fs * 0.95, g.fit_size(sub_line, 12.0 if short else 13.0, r.size.x - ab * 2.0 - 24.0, 8.0), g.UI_MUTED, "center")
	var y: float = r.position.y + ab + (6.0 if short else 12.0)
	var cols: Array = b.cols
	var label_w: float = clampf(r.size.x * 0.12, 60.0, 90.0)
	var ncol: int = cols.size() + 1
	var cw: float = (r.size.x - label_w - 8.0) / float(ncol)
	var rg: float = 3.0 if short else 5.0
	var foot: float = 0.0 if short else 18.0
	var rh: float = minf(36.0, (r.end.y - y - foot - rg * float(KEYS.size())) / float(KEYS.size() + 1))
	var tfs: float = clampf(rh * 0.5, 11.0, 16.0)
	for ci in cols.size():
		g.chip(str(cols[ci][0]), r.position.x + label_w + cw * ci + cw / 2.0, y + rh * 0.5, tfs * 0.78, Color(g.UI_INK.r, g.UI_INK.g, g.UI_INK.b, 0.08), g.UI_MUTED, "center")
	g.chip("Total", r.position.x + label_w + cw * cols.size() + cw / 2.0, y + rh * 0.5, tfs * 0.78, g.UI_TEAL, Color.WHITE, "center")
	y += rh + rg
	var fin: Dictionary = b.final
	for ki in KEYS.size():
		var k: String = KEYS[ki]
		var row := Rect2(r.position.x, y, r.size.x, rh)
		g.rbox(row, rh / 2.0, Color(1, 1, 1, 0.7), g.UI_LINE, 1.0)
		g.text(LABELS[k], r.position.x + 16.0, y + rh * 0.5, tfs * 0.85, g.UI_MUTED, "left")
		var sum := 0
		for ci in cols.size():
			var v: int = int(cols[ci][1][k])
			sum += v
			var s: String = str(v)
			var c: Color = g.UI_INK
			if ci > 0:
				if v > 0:
					s = "+" + str(v)
					c = g.UI_GOOD
				elif v < 0:
					c = g.UI_BAD
				else:
					s = "·"
					c = Color(g.UI_LOCK.r, g.UI_LOCK.g, g.UI_LOCK.b, 0.7)
			g.text(s, r.position.x + label_w + cw * ci + cw / 2.0, y + rh * 0.5, tfs, c, "center")
		var tot: int = int(fin[k])
		var capped: bool = tot != sum
		var tr2 := Rect2(r.position.x + label_w + cw * cols.size() + 6.0, y + 3.0, cw - 8.0, rh - 6.0)
		g.rbox(tr2, tr2.size.y / 2.0, g.UI_TEAL_L)
		g.text(str(tot) + ("*" if capped else ""), tr2.get_center().x, tr2.get_center().y, tfs * 1.05, g.UI_TEAL_D, "center")
		y += rh + rg
	if not short:
		g.text("Focus = extra level growth on the subclass's focus stat  ·  * = held at the stat cap", r.get_center().x, r.end.y - 6.0, 11.0, g.UI_MUTED, "center")
