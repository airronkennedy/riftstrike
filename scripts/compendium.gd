extends RefCounted
# Compendium (title screen): every class with its class abilities, then every subclass with
# its subclass abilities, each with on-screen text for what it does.
# Reads the game node's data (CLASS_IDS, CLASS_DEFS, CHAR, ABILITY_DEFS, SUB_DEFS …) and
# draws with its soft menu helpers (menu_sheet, pill, rbox, chip, seg_tabs, text, wrap_words).
# Class abilities are per hero (unique kit); a class run by two heroes shows both kits.

const Upcoming = preload("res://scripts/upcoming_classes.gd")
const CLASS_UNLOCKS := [1, 11, 21, 31, 41, 51, 61, 71, 81, 99] # mirrors game.gd
const PACK_KEYS := ["hp", "atk", "def", "armor", "crit", "mana", "speed"]
const PACK_LABELS := {"hp": "HP", "atk": "ATK", "def": "DEF", "armor": "ARM", "crit": "CRIT", "mana": "MANA", "speed": "SPD"}
const STAT_SHORT := {"atk": "ATK", "def": "DEF", "armor": "ARM", "speed": "SPD", "crit": "CRIT"}
const KIND_ROLE := {"warrior": "Melee", "archer": "Ranged", "pawn": "Tank"}
const AB_TAG := {"damage_single": "One foe", "damage_all_enemies": "All foes", "buff_self": "Self buff",
	"buff_party": "Party buff", "heal_single": "Heal", "heal_party": "Party heal"}

var tab := 0 # 0 = classes, 1 = subclasses
var cls_i := 0
var sub_i := 0
var kit_i := 0
var page := 0
var pages := 1


func open() -> void:
	tab = 0
	cls_i = 0
	sub_i = 0
	kit_i = 0
	page = 0


# ------------------------------------------------------------------ data
func _ab_from_def(d: Dictionary) -> Dictionary:
	return {"name": str(d.name), "blurb": str(d.blurb), "kind": str(d.kind), "params": d.params, "lv": int(d.lv)}


func class_entries(g: Object) -> Array:
	var out: Array = []
	for cls in g.CLASS_IDS:
		if not g.CLASS_DEFS.has(cls):
			continue
		var kits: Array = []
		for h in g.HERO_NAMES:
			if str(g.CHAR[h].cls) == str(cls):
				var abl: Array = []
				for id in g.class_ability_ids(h):
					if g.ABILITY_DEFS.has(id):
						abl.append(_ab_from_def(g.ABILITY_DEFS[id]))
				kits.append({"hero": str(h), "abl": abl})
		out.append({"name": str(cls), "def": g.CLASS_DEFS[cls], "kits": kits, "upcoming": false})
	for cls2 in Upcoming.ORDER:
		if not g.CLASS_DEFS.has(cls2) or g.CLASS_IDS.has(cls2):
			continue
		var kit: Dictionary = Upcoming.KITS[cls2]
		var rows: Array = kit.rows
		var abs2: Array = []
		for i in rows.size():
			var r: Array = rows[i]
			abs2.append({"name": r[1], "blurb": r[2], "kind": r[3], "params": r[4],
				"lv": int(CLASS_UNLOCKS[mini(i, CLASS_UNLOCKS.size() - 1)])})
		out.append({"name": str(cls2), "def": g.CLASS_DEFS[cls2], "kits": [{"hero": str(kit.hero), "abl": abs2}], "upcoming": true})
	return out


func sub_entries(g: Object) -> Array:
	var out: Array = []
	for sub in g.SUB_IDS:
		var abl: Array = []
		for id in g.sub_ability_ids(sub):
			if g.ABILITY_DEFS.has(id):
				abl.append(_ab_from_def(g.ABILITY_DEFS[id]))
		var runners: Array = []
		for h in g.HERO_NAMES:
			if str(g.CHAR[h].sub) == str(sub):
				runners.append(str(h))
		out.append({"name": str(sub), "def": g.SUB_DEFS.get(sub, {}), "abl": abl, "runners": runners,
			"focus": str(g.FOCUS_LABELS.get(g.sub_focus_stat(sub), "ATK"))})
	return out


static func mods_text(mods: Array) -> String:
	var parts: Array = []
	for m in mods:
		var stat: String = str(m[0])
		parts.append("%s %+d" % [str(STAT_SHORT.get(stat, stat.to_upper())), int(m[1])])
	return ", ".join(parts)


## Same wording as game.gd ab_effect_line, built from a row so upcoming kits read the same.
static func effect_line(ab: Dictionary) -> String:
	var p: Dictionary = ab.params
	var kind: String = str(ab.kind)
	var out: String = ""
	if kind == "damage_single":
		out = "Hits one foe x%.1f" % float(p.get("mult", 1.0))
	elif kind == "damage_all_enemies":
		out = "Hits all foes x%.1f" % float(p.get("mult", 1.0))
	elif kind == "heal_single":
		var size_s: String = "large" if float(p.get("pct", 0.0)) >= 0.4 else "medium"
		out = ("Heals self (%s)" % size_s) if bool(p.get("self", false)) else ("Heals one ally (%s)" % size_s)
	elif kind == "heal_party":
		var pct: float = float(p.get("pct", 0.0))
		out = "Heals party (%s)" % ("large" if pct >= 0.45 else ("medium" if pct >= 0.2 else "small"))
	elif kind == "buff_self":
		out = "Self " + mods_text(p.get("buffs", [])) + " %dT" % int(p.get("turns", 1))
	elif kind == "buff_party":
		out = "Party " + mods_text(p.get("buffs", [])) + " %dT" % int(p.get("turns", 1))
	if p.has("debuff"):
		out += " · Foe " + mods_text(p.debuff) + " %dT" % int(p.get("dturns", 2))
	if p.has("self_buff"):
		out += " · Self " + mods_text(p.self_buff) + " %dT" % int(p.get("sturns", 2))
	if p.has("party_buff"):
		out += " · Party " + mods_text(p.party_buff) + " %dT" % int(p.get("pturns", 2))
	return out


static func kind_color(kind: String) -> Color:
	if kind == "heal_single" or kind == "heal_party":
		return Color("#5dff8a")
	if kind == "buff_self" or kind == "buff_party":
		return Color("#7fd8ff")
	return Color("#c98bff")


static func pack_text(d: Dictionary) -> String:
	var parts: Array = []
	for k in PACK_KEYS:
		var v: int = int(d.get(k, 0))
		if v != 0:
			parts.append("%s %+d" % [PACK_LABELS[k], v])
	return "  ".join(parts)


# ------------------------------------------------------------------ navigation
func _count(g: Object) -> int:
	return class_entries(g).size() if tab == 0 else sub_entries(g).size()


func set_tab(i: int) -> void:
	if i == tab:
		return
	tab = i
	kit_i = 0
	page = 0


func step_entry(g: Object, dir: int) -> void:
	var n: int = maxi(1, _count(g))
	if tab == 0:
		cls_i = (cls_i + dir + n) % n
	else:
		sub_i = (sub_i + dir + n) % n
	kit_i = 0
	page = 0
	g.sfx.tone(700, 0.04, "triangle", 0.03)


func _set_kit(i: int) -> void:
	kit_i = i
	page = 0


func _set_page(i: int) -> void:
	page = i


func step_page(dir: int) -> void:
	page = clampi(page + dir, 0, maxi(0, pages - 1))


func key(g: Object, k: int) -> void:
	if k == KEY_ESCAPE or k == KEY_P or k == KEY_BACKSPACE:
		g.menu_back()
	elif k == KEY_LEFT:
		step_entry(g, -1)
	elif k == KEY_RIGHT:
		step_entry(g, 1)
	elif k == KEY_UP:
		step_page(-1)
	elif k == KEY_DOWN:
		step_page(1)
	elif k == KEY_TAB:
		set_tab(1 - tab)
	elif k == KEY_1:
		set_tab(0)
	elif k == KEY_2:
		set_tab(1)


# ------------------------------------------------------------------ draw
func draw(g: Object, vw: float, vh: float) -> void:
	var short: bool = vh <= 430
	var area: Rect2 = g.menu_sheet("cmp_back", "Compendium", "Every class and subclass, and what each ability does.",
		func(): g.menu_back(), ["Classes", "Subclasses"], tab, func(i): set_tab(i), "cmp_tab")
	var entries: Array = class_entries(g) if tab == 0 else sub_entries(g)
	if entries.is_empty():
		return
	var idx: int = cls_i if tab == 0 else sub_i
	idx = clampi(idx, 0, entries.size() - 1)
	var e: Dictionary = entries[idx]
	var y: float = area.position.y
	y += _draw_head(g, e, idx, entries.size(), Rect2(area.position.x, y, area.size.x, 0.0), short) + (6.0 if short else 10.0)
	var abl: Array = []
	var label: String = ""
	var capstone: int = -1
	if tab == 0:
		var kits: Array = e.kits
		if kits.size() > 1:
			var names: Array = []
			for kt in kits:
				names.append(str(kt.hero) + "'s kit")
			var th: float = 34.0 if short else 40.0
			kit_i = clampi(kit_i, 0, kits.size() - 1)
			g.seg_tabs("cmp_kit", Rect2(area.position.x, y, area.size.x, th), names, kit_i, 13.0 if short else 15.0, func(i): _set_kit(i))
			y += th + (6.0 if short else 8.0)
		if kits.is_empty():
			_draw_empty(g, e, Rect2(area.position.x, y, area.size.x, area.end.y - y), short)
			return
		var kit: Dictionary = kits[clampi(kit_i, 0, kits.size() - 1)]
		abl = kit.abl
		capstone = abl.size() - 1
		var hero: String = str(kit.hero)
		if e.upcoming:
			label = "%s's kit · coming with the new art · Lv 1, 11 … 81, 99" % hero
		else:
			label = "%s's class kit · unique to %s · Lv 1, 11 … 81, 99" % [hero, hero]
	else:
		abl = e.abl
		label = "Subclass abilities · shared by anyone running %s · Lv 1, 20, 40, 60, 80" % str(e.name)
	var lfs: float = g.fit_size(label, 11.0 if short else 12.0, area.size.x - 8.0, 8.0)
	g.text(label, area.position.x + 4.0, y + 6.0, lfs, g.UI_MUTED, "left")
	y += 16.0 if short else 20.0
	_draw_abilities(g, abl, capstone, Rect2(area.position.x, y, area.size.x, area.end.y - y), short)


## Header card: arrows to page through entries, name, chips, blurb, stat package. Returns its height.
func _draw_head(g: Object, e: Dictionary, idx: int, n: int, r0: Rect2, short: bool) -> float:
	var upcoming: bool = tab == 0 and bool(e.upcoming)
	var d: Dictionary = e.def
	var blurb: String = str(d.get("blurb", ""))
	var pack: String = pack_text(d)
	var narrow: bool = r0.size.x < 520.0
	var ab: float = 34.0 if short else 42.0
	var tw: float = r0.size.x - ab * 2.0 - 36.0
	var name: String = str(e.name)
	var nfs: float = g.fit_size(name, 20.0 if short else 26.0, tw, 13.0)
	var cfs: float = 10.0 if short else 11.0
	var chips: Array = []
	if tab == 0:
		chips.append(["%s %d / %d" % ["Upcoming" if upcoming else "Class", idx + 1, n], g.UI_GOLD if upcoming else g.UI_TEAL_L, Color("#3d2706") if upcoming else g.UI_TEAL_D])
		var role: String = str(KIND_ROLE.get(str(d.get("kind", "")), "Melee"))
		var heroes: Array = []
		for kt in e.kits:
			heroes.append(str(kt.hero))
		if upcoming:
			chips.append([role + " · for " + ", ".join(heroes), g.UI_GOLD_L.lerp(g.UI_GOLD, 0.3), Color("#7a5208")])
			chips.append(["Locks when art lands", Color(g.UI_INK.r, g.UI_INK.g, g.UI_INK.b, 0.08), g.UI_INK])
		elif heroes.size() > 0:
			chips.append([role + " · " + ", ".join(heroes), g.UI_GOLD_L, Color("#7a5208")])
		else:
			chips.append([role + " · no hero yet", Color(g.UI_LOCK.r, g.UI_LOCK.g, g.UI_LOCK.b, 0.22), g.UI_MUTED])
	else:
		chips.append(["Subclass %d / %d" % [idx + 1, n], g.UI_TEAL_L, g.UI_TEAL_D])
		chips.append(["Focus " + str(e.focus), g.UI_GOLD_L, Color("#7a5208")])
		chips.append(["Run by " + ", ".join(e.runners) if e.runners.size() > 0 else "Any hero can swap in", Color(g.UI_INK.r, g.UI_INK.g, g.UI_INK.b, 0.08), g.UI_INK])
	var top_pad: float = 13.0 if short else 21.0
	var chip_gap: float = 10.0 if short else 15.0
	var row_h: float = cfs + 10.0
	var rows: Array = _chip_rows(g, chips, tw, cfs)
	var chip_h: float = float(maxi(1, rows.size())) * row_h
	var after_chip: float = 14.0 if short else 19.0
	var bfs: float = 11.0 if short else 13.0
	var split_pack: bool = narrow and not short
	var blurb_h: float = (17.0 + 14.0) if split_pack else (bfs + 6.0)
	var bot_pad: float = 12.0 if short else 16.0
	var hh: float = top_pad + nfs * 0.5 + chip_gap + chip_h + after_chip + blurb_h + bot_pad
	hh = maxf(hh, ab + 16.0)
	var r := Rect2(r0.position.x, r0.position.y, r0.size.x, hh)
	g.rbox(r, 22.0, g.UI_GOLD_L if upcoming else g.UI_CARD, g.UI_GOLD if upcoming else g.UI_LINE, 2.0, 3.0)
	var cx: float = r.get_center().x
	var ny: float = r.position.y + top_pad
	var aby: float = ny - ab / 2.0
	aby = clampf(aby, r.position.y + 6.0, r.end.y - 6.0 - ab)
	g.pill("cmp_prev", Rect2(r.position.x + 8.0, aby, ab, ab), "", "primary", 18.0, func(): step_entry(g, -1), false, false, false, "", "left")
	g.pill("cmp_next", Rect2(r.end.x - 8.0 - ab, aby, ab, ab), "", "primary", 18.0, func(): step_entry(g, 1), false, false, false, "", "right")
	g.text(name, cx, ny, nfs, g.UI_INK)
	var cy: float = ny + nfs * 0.5 + chip_gap
	_draw_chip_rows(g, rows, cx, cy, cfs, row_h)
	var by: float = cy + chip_h - row_h * 0.5 + after_chip
	if split_pack:
		g.text(blurb, cx, by, g.fit_size(blurb, bfs, tw, 8.0), g.UI_MUTED)
		g.text(pack, cx, by + 17.0, g.fit_size(pack, 11.0, tw, 8.0), g.UI_TEAL_D)
	else:
		var line: String = blurb + "   ·   " + pack
		g.text(line, cx, by, g.fit_size(line, bfs, tw, 8.0), g.UI_MUTED)
	return hh


## Centered chips, wrapping to another row instead of dropping ones that do not fit.
func _chip_rows(g: Object, chips: Array, maxw: float, fsz: float) -> Array:
	var gap: float = 6.0
	var rows: Array = []
	var cur: Array = []
	var total: float = 0.0
	for c in chips:
		var w: float = g.text_w(str(c[0]), fsz) + fsz * 1.2
		var add: float = w + (gap if cur.size() > 0 else 0.0)
		if cur.size() > 0 and total + add > maxw:
			rows.append({"chips": cur, "w": total})
			cur = [c]
			total = w
		else:
			cur.append(c)
			total += add
	if cur.size() > 0:
		rows.append({"chips": cur, "w": total})
	return rows


func _draw_chip_rows(g: Object, rows: Array, cx: float, cy: float, fsz: float, row_h: float) -> void:
	var gap: float = 6.0
	var y: float = cy
	for row in rows:
		var x: float = cx - float(row.w) / 2.0
		for c2 in row.chips:
			x += g.chip(str(c2[0]), x, y, fsz, c2[1], c2[2], "left") + gap
		y += row_h




func _draw_empty(g: Object, e: Dictionary, r: Rect2, short: bool) -> void:
	var box := Rect2(r.position.x, r.position.y, r.size.x, minf(r.size.y, 92.0 if short else 110.0))
	g.rbox(box, 22.0, Color(1, 1, 1, 0.55), g.UI_LINE, 1.5)
	var msg: String = "No hero runs %s yet. Class abilities are a unique 10-ability kit per hero, so %s gets its kit when a hero is locked to it." % [str(e.name), str(e.name)]
	var lines: Array = g.wrap_words(msg, 13.0, box.size.x - 40.0)
	var ly: float = box.get_center().y - float(lines.size() - 1) * 9.0
	for ln in lines:
		g.text(str(ln), box.get_center().x, ly, 13.0, g.UI_MUTED)
		ly += 18.0


## Pages abilities into cards that fit the space: two columns on wide screens, one on phones.
func _draw_abilities(g: Object, abl: Array, capstone: int, r: Rect2, short: bool) -> void:
	var n: int = abl.size()
	if n == 0:
		return
	var cols: int = 2 if r.size.x >= 620.0 else 1
	var gap: float = 6.0 if short else 8.0
	var cw: float = (r.size.x - gap * float(cols - 1)) / float(cols)
	var badge: float = 40.0 if short else 46.0
	var wrap_w: float = cw - badge - 34.0
	var nfs: float = 14.0 if short else 16.0
	var efs: float = 11.0 if short else 12.0
	var bfs: float = 11.0 if short else 12.5
	var lh: float = bfs + 4.0
	var max_lines: int = 1
	for a in abl:
		max_lines = maxi(max_lines, blurb_lines(g, str(a.blurb), bfs, wrap_w, short).size())
	var pad: float = 7.0 if short else 10.0
	var need: float = pad * 2.0 + nfs + 4.0 + efs + 4.0 + lh * float(max_lines)
	need = maxf(need, badge + pad * 2.0 - 4.0)
	var pager_h: float = 34.0 if short else 40.0
	var rows_fit: int = maxi(1, int(floor((r.size.y + gap) / (need + gap))))
	var per_page: int = rows_fit * cols
	if per_page < n:
		rows_fit = maxi(1, int(floor((r.size.y - pager_h - gap + gap) / (need + gap))))
		per_page = rows_fit * cols
	pages = int(ceil(float(n) / float(per_page)))
	page = clampi(page, 0, pages - 1)
	var list_h: float = r.size.y - (pager_h + gap if pages > 1 else 0.0)
	var start: int = page * per_page
	var cnt: int = mini(per_page, n - start)
	var rows_here: int = int(ceil(float(cnt) / float(cols)))
	var rows_all: int = int(ceil(float(mini(per_page, n)) / float(cols)))
	var ch: float = minf(need * 1.3, (list_h - gap * float(rows_all - 1)) / float(maxi(1, rows_all)))
	ch = maxf(ch, need)
	for k in cnt:
		var i: int = start + k
		var col: int = k / rows_here if cols > 1 else 0
		var row: int = k % rows_here if cols > 1 else k
		var cr := Rect2(r.position.x + float(col) * (cw + gap), r.position.y + float(row) * (ch + gap), cw, ch)
		_ability_card(g, abl[i], i == capstone, cr, badge, nfs, efs, bfs, lh, short)
	if pages > 1:
		var labels: Array = []
		for p in pages:
			var a0: int = p * per_page
			var a1: int = mini(n, a0 + per_page) - 1
			labels.append("Lv %d–%d" % [int(abl[a0].lv), int(abl[a1].lv)])
		var pr := Rect2(r.position.x, r.end.y - pager_h, r.size.x, pager_h)
		g.seg_tabs("cmp_pg", pr, labels, page, 13.0 if short else 15.0, func(i): _set_page(i))


## Blurb as 1–2 lines; on short (landscape phone) screens squeeze to one line when it still reads.
func blurb_lines(g: Object, s: String, fsz: float, w: float, short: bool) -> Array:
	if short and g.text_w(s, 9.0) <= w:
		return [s]
	var lines: Array = g.wrap_words(s, fsz, w)
	if lines.size() > 2:
		lines = [lines[0], " ".join(lines.slice(1))]
	return lines


func _ability_card(g: Object, a: Dictionary, cap: bool, r: Rect2, badge: float, nfs: float, efs: float, bfs: float, lh: float, short: bool) -> void:
	var kind: String = str(a.kind)
	var col: Color = kind_color(kind)
	g.rbox(r, minf(18.0, r.size.y / 2.0), g.UI_GOLD_L if cap else g.UI_CARD, g.UI_GOLD if cap else g.UI_LINE, 2.0 if cap else 1.5)
	var bs: float = minf(badge, r.size.y - 12.0)
	var br := Rect2(r.position.x + 9.0, r.get_center().y - bs / 2.0, bs, bs)
	g.rbox(br, bs * 0.32, col.lerp(Color.WHITE, 0.35), col.darkened(0.25), 2.0)
	g.text("LV", br.get_center().x, br.position.y + bs * 0.27, 9.0 if short else 10.0, g.UI_INK.lerp(col, 0.25))
	var lv_s: String = str(int(a.lv))
	g.text(lv_s, br.get_center().x, br.position.y + bs * 0.64, g.fit_size(lv_s, 17.0 if short else 20.0, bs - 6.0, 10.0), g.UI_INK)
	var x: float = br.end.x + 12.0
	var right: float = r.end.x - 10.0
	var tw: float = right - x
	var lines: Array = blurb_lines(g, str(a.blurb), bfs, tw, short)
	var body_h: float = nfs + 4.0 + efs + 4.0 + lh * float(lines.size())
	var y: float = r.get_center().y - body_h / 2.0
	# name + small tag chip on the right
	var tag: String = ("Capstone · " if cap else "") + str(AB_TAG.get(kind, ""))
	var tfs: float = 9.0 if short else 10.0
	var tag_w: float = g.text_w(tag, tfs) + tfs * 1.2
	var name: String = str(a.name)
	var name_w: float = tw - tag_w - 8.0
	g.text(name, x, y + nfs * 0.5, g.fit_size(name, nfs, name_w, 9.0), g.UI_INK, "left")
	g.chip(tag, right, y + nfs * 0.5, tfs, g.UI_GOLD if cap else g.UI_TEAL_L, Color("#3d2706") if cap else g.UI_TEAL_D, "right")
	y += nfs + 4.0
	var el: String = effect_line(a)
	g.text(el, x, y + efs * 0.5, g.fit_size(el, efs, tw, 7.0), g.UI_TEAL_D, "left")
	y += efs + 4.0
	for ln in lines:
		var s: String = str(ln)
		g.text(s, x, y + lh * 0.5, g.fit_size(s, bfs, tw, 7.0), g.UI_MUTED, "left")
		y += lh
