extends RefCounted
# Build screen: per keeper, pick a Class and a Subclass (2 + 2 abilities, each with its own level),
# and order the AUTO battle plan (Sequence). Data: scripts/quest_rpg.gd. Logic: game.gd set_class / set_sub / seq_of / seq_pick.
const QuestRPG = preload("res://scripts/quest_rpg.gd")
var tab := 0 # 0 class, 1 subclass, 2 sequence

func open() -> void:
	tab = 0

func key(g: Object, k: int) -> void:
	if k == KEY_ESCAPE or k == KEY_P or k == KEY_BACKSPACE:
		g.menu_back()
	elif k == KEY_TAB:
		tab = (tab + 1) % 3
	elif k == KEY_1: tab = 0
	elif k == KEY_2: tab = 1
	elif k == KEY_3: tab = 2
	elif k == KEY_UP or k == KEY_LEFT:
		g.select_hero(g.char_sel - 1)
	elif k == KEY_DOWN or k == KEY_RIGHT:
		g.select_hero(g.char_sel + 1)

func draw(g: Object, vw: float, vh: float) -> void:
	var short: bool = vh <= 430
	var area: Rect2 = g.menu_sheet("bld_back", "Build", "Class, abilities and the AUTO battle plan for each keeper.",
		func(): g.menu_back(), ["Class", "Subclass", "Sequence"], tab, func(i): tab = i, "bld_tab")
	var d: Rect2 = g.hero_picker("bld_hero_", area, short, func(hn, hs): return "Lv." + str(int(hs.level)) + "  " + str(hs.cls))
	var name: String = g.selected_hero()
	if tab == 0: _draw_class(g, name, d, short)
	elif tab == 1: _draw_loadout(g, name, d, short)
	else: _draw_seq(g, name, d, short)

# ------------------------------------------------------------------ class + subclass
const STAT_LABEL := {"hp": "HP", "atk": "ATK", "def": "DEF", "armor": "ARM", "crit": "CRIT", "speed": "SPD", "mana": "MP"}

## Top strip: current class / subclass with levels, EXP bar, and the 4 abilities (locked ones dimmed).
func _summary(g: Object, name: String, d: Rect2) -> float:
	var cls: String = str(g.CHAR[name].cls)
	var sub: String = str(g.CHAR[name].sub)
	var cl: int = g.class_level(name, cls)
	var sl: int = g.sub_level(name, sub)
	var y: float = d.position.y + 8.0
	var head := "%s  ·  %s Lv.%d  /  %s subclass Lv.%d" % [name, cls, cl, sub, sl]
	g.text(head, d.position.x + 2.0, y, g.fit_size(head, 13.0, d.size.x * 0.6, 9.0), g.UI_INK, "left")
	# class EXP bar
	var bw: float = minf(220.0, d.size.x * 0.34)
	var br := Rect2(d.end.x - bw, y - 4.0, bw, 8.0)
	var nxt: int = g.xp_to_next(cl)
	var cur: int = g.hero_xp(name) if cls == str(g.CHAR[name].cls) else 0
	g.rbox(br, 3.0, g.UI_CARD, g.UI_LINE, 1.0)
	if nxt > 0: g.rbox(Rect2(br.position, Vector2(br.size.x * clampf(float(cur) / float(nxt), 0.0, 1.0), br.size.y)), 3.0, g.UI_GOLD, Color(0, 0, 0, 0), 0.0)
	else: g.rbox(br, 3.0, g.UI_GOLD, Color(0, 0, 0, 0), 0.0)
	var et := ("EXP %d / %d" % [cur, nxt]) if nxt > 0 else "MAX LEVEL"
	g.text(et, br.position.x - 8.0, y, 11.0, g.UI_MUTED, "right")
	y += 16.0
	var ids: Array = g.class_ability_ids(name) + g.sub_ability_ids(sub)
	var gap := 6.0
	var cw: float = (d.size.x - gap * 3.0) / 4.0
	for i in ids.size():
		var id: String = str(ids[i])
		var ab: Dictionary = g.ABILITY_DEFS[id]
		var ok: bool = g.ab_unlocked(name, id)
		var r := Rect2(d.position.x + float(i) * (cw + gap), y, cw, 34.0)
		g.rbox(r, 10.0, g.UI_GOLD_L if ok else g.UI_CARD, g.UI_GOLD if ok else g.UI_LINE, 1.2)
		var nm: String = str(ab.name)
		g.text(nm, r.position.x + 8.0, r.position.y + 11.0, g.fit_size(nm, 13.0, cw - 60.0, 8.0), g.UI_INK if ok else g.UI_MUTED, "left")
		var tag: String = ("CLASS" if str(ab.src) == "class" else "SUB") if ok else ("%s Lv.%d" % ["class" if str(ab.src) == "class" else "sub", int(ab.lv)])
		g.text(tag, r.end.x - 6.0, r.position.y + 11.0, 9.0, g.UI_GOLD if ok else g.UI_LOCK, "right")
		var ef: String = g.ab_effect_line(id)
		g.text(ef, r.position.x + 8.0, r.position.y + 25.0, g.fit_size(ef, 10.0, cw - 14.0, 7.0), g.ab_color(id) if ok else g.UI_MUTED, "left")
	return y + 34.0 + 8.0

## Grid of all classes. mode "class": tap to make it the class. mode "sub": tap to make it the subclass.
func _grid(g: Object, name: String, d: Rect2, top: float, mode: String, short: bool) -> void:
	var cur_c: String = str(g.CHAR[name].cls)
	var cur_s: String = str(g.CHAR[name].sub)
	var ids: Array = QuestRPG.CLASS_ORDER
	var cols: int = 5 if d.size.x >= 620.0 else (4 if d.size.x >= 480.0 else 2)
	var gap: float = 6.0
	var rows: int = int(ceil(float(ids.size()) / float(cols)))
	var cw: float = (d.size.x - gap * float(cols - 1)) / float(cols)
	var ch: float = minf(150.0, (d.end.y - top - gap * float(rows - 1)) / float(rows))
	for i in ids.size():
		var cls: String = ids[i]
		var c: Dictionary = QuestRPG.CLASSES[cls]
		var r := Rect2(d.position.x + float(i % cols) * (cw + gap), top + float(i / cols) * (ch + gap), cw, ch)
		var sel: bool = cls == (cur_c if mode == "class" else cur_s)
		var other: bool = cls == (cur_s if mode == "class" else cur_c)
		var lv: int = g.class_level(name, cls) if mode == "class" else g.sub_level(name, cls)
		g.rbox(r, 14.0, g.UI_GOLD_L if sel else g.UI_CARD, g.UI_GOLD if sel else g.UI_LINE, 2.0 if sel else 1.2)
		var x0: float = r.position.x + 8.0
		g.text(cls, x0, r.position.y + 13.0, g.fit_size(cls, 15.0, cw - 52.0, 10.0), g.UI_GOLD if sel else g.UI_INK, "left")
		g.text("Lv.%d" % lv, r.end.x - 7.0, r.position.y + 13.0, 11.0, g.UI_GOLD if lv > 1 or sel else g.UI_MUTED, "right")
		var tag: String = ("EQUIPPED" if sel else (("SUBCLASS" if mode == "class" else "CLASS") if other else str(c.role)))
		g.text(tag, x0, r.position.y + 27.0, 9.0, g.UI_GOLD if sel else (g.UI_LOCK if other else g.UI_TEAL_D), "left")
		var parts: Array = []
		var share: float = 1.0 if mode == "class" else QuestRPG.SUB_STAT_SHARE
		for k in ["hp", "atk", "def", "crit", "speed"]:
			var v := int(roundf(float(c.get(k, 0)) * share))
			if v != 0: parts.append("%s+%d" % [STAT_LABEL[k], v])
		var pk: String = " ".join(parts)
		g.text(pk, x0, r.position.y + 41.0, g.fit_size(pk, 10.0, cw - 14.0, 7.0), g.UI_INK, "left")
		var rows_ab: Array = c.abilities if mode == "class" else c.sub_abilities
		var ay: float = r.position.y + 57.0
		for rr in rows_ab:
			if ay > r.end.y - 8.0: break
			var have: bool = lv >= int(rr[5])
			var an: String = str(rr[1]) + ("" if have else "  Lv.%d" % int(rr[5]))
			g.text(an, x0, ay, g.fit_size(an, 11.0, cw - 14.0, 7.0), g.UI_TEAL_D if have else g.UI_MUTED, "left")
			ay += 14.0
		if not short and ay < r.end.y - 22.0:
			var bl: Array = g.wrap_words(str(c.blurb), 10.0, cw - 14.0)
			for ln in bl.slice(0, int((r.end.y - ay - 4.0) / 12.0)):
				g.text(str(ln), x0, ay + 2.0, 10.0, g.UI_MUTED, "left"); ay += 12.0
		var cc: String = cls
		if mode == "class":
			g.add_btn("bld_cls_" + cls, r, func(): g.set_class(name, cc); g.sfx.tone(784, 0.05, "triangle", 0.03))
		else:
			g.add_btn("bld_sub_" + cls, r, func():
				var okk: bool = cc != str(g.CHAR[name].cls)
				if okk: g.set_sub(name, cc)
				g.sfx.tone(784 if okk else 220, 0.05, "triangle", 0.03))

func _draw_class(g: Object, name: String, d: Rect2, short: bool) -> void:
	var top := _summary(g, name, d)
	g.text("CLASS: stats + 2 abilities. Each class levels on its own (cap %d). Picking your subclass's class swaps the two." % QuestRPG.LEVEL_CAP,
		d.position.x + 2.0, top, g.fit_size("x".repeat(120), 11.0, d.size.x, 8.0), g.UI_MUTED, "left")
	_grid(g, name, d, top + 12.0, "class", short)

func _draw_loadout(g: Object, name: String, d: Rect2, short: bool) -> void:
	var top := _summary(g, name, d)
	g.text("SUBCLASS: any other class adds %d%% of its stats + its 2 subclass abilities. It levels separately at half the EXP." % int(QuestRPG.SUB_STAT_SHARE * 100),
		d.position.x + 2.0, top, g.fit_size("x".repeat(120), 11.0, d.size.x, 8.0), g.UI_MUTED, "left")
	_grid(g, name, d, top + 12.0, "sub", short)

# ------------------------------------------------------------------ sequence
func _cycle(arr: Array, cur: String) -> String:
	if arr.is_empty(): return cur
	var i: int = arr.find(cur)
	return str(arr[(i + 1) % arr.size()])

func _move(name: String, g: Object, i: int, dir: int) -> void:
	var s: Array = g.seq_of(name).duplicate(true)
	var j: int = i + dir
	if j < 0 or j >= s.size(): return
	var t = s[i]; s[i] = s[j]; s[j] = t
	g.AB_SEQ[name] = s; g.save_cfg()

func _draw_seq(g: Object, name: String, d: Rect2, short: bool) -> void:
	var seq: Array = g.seq_of(name)
	var lo: Array = g.loadout_of(name)
	g.text("When MP is full, AUTO fires the FIRST rule that passes (top to bottom). None pass: basic attack, MP is kept.",
		d.position.x + 2.0, d.position.y + 8.0, g.fit_size("x".repeat(110), 12.0, d.size.x, 8.0), g.UI_MUTED, "left")
	var y: float = d.position.y + 22.0
	var rh: float = 38.0 if short else 46.0
	var gap: float = 6.0
	var sb: float = rh - 8.0
	for i in seq.size():
		var rr: Array = seq[i]
		var id: String = str(rr[0])
		var cond: String = str(rr[1])
		var r := Rect2(d.position.x, y, d.size.x, rh)
		var live: bool = lo.find(id) >= 0
		g.rbox(r, 14.0, g.UI_CARD, g.UI_GOLD if i == 0 else g.UI_LINE, 1.5)
		g.text("#%d" % (i + 1), r.position.x + 20.0, r.get_center().y, 15.0, g.UI_GOLD)
		var aw: float = minf(220.0, (r.size.x - 4.0 * (sb + 6.0) - 60.0) * 0.48)
		var ar := Rect2(r.position.x + 40.0, r.position.y + 4.0, aw, rh - 8.0)
		var an: String = str(g.ABILITY_DEFS[id].name) + ("" if live else "  (locked)")
		var ii: int = i
		g.pill("bld_sa_%d" % i, ar, an, "primary" if live else "soft", 13.0, func():
			var s: Array = g.seq_of(name).duplicate(true)
			s[ii][0] = _cycle(g.loadout_of(name), str(s[ii][0])); g.AB_SEQ[name] = s; g.save_cfg())
		g.text("if", ar.end.x + 14.0, r.get_center().y, 13.0, g.UI_MUTED)
		var cr := Rect2(ar.end.x + 28.0, r.position.y + 4.0, aw, rh - 8.0)
		g.pill("bld_sc_%d" % i, cr, str(QuestRPG.CONDITIONS[cond]), "gold" if cond != "always" else "soft", 12.0, func():
			var s2: Array = g.seq_of(name).duplicate(true)
			s2[ii][1] = _cycle(QuestRPG.COND_ORDER, str(s2[ii][1])); g.AB_SEQ[name] = s2; g.save_cfg())
		var bx: float = r.end.x - 3.0 * (sb + 6.0)
		g.pill("bld_su_%d" % i, Rect2(bx, r.position.y + 4.0, sb, sb), "", "soft", 13.0, func(): _move(name, g, ii, -1), false, i == 0, false, "", "up")
		g.pill("bld_sd_%d" % i, Rect2(bx + sb + 6.0, r.position.y + 4.0, sb, sb), "", "soft", 13.0, func(): _move(name, g, ii, 1), false, i == seq.size() - 1, false, "", "down")
		g.pill("bld_sx_%d" % i, Rect2(bx + 2.0 * (sb + 6.0), r.position.y + 4.0, sb, sb), "X", "danger", 13.0, func():
			var s3: Array = g.seq_of(name).duplicate(true)
			s3.remove_at(ii); g.AB_SEQ[name] = s3; g.save_cfg())
		y += rh + gap
	var bw: float = 150.0
	var by: float = minf(y + 4.0, d.end.y - rh)
	g.pill("bld_add", Rect2(d.position.x, by, bw, rh - 6.0), "+ Add rule", "primary", 14.0, func():
		var s4: Array = g.seq_of(name).duplicate(true)
		var l2: Array = g.loadout_of(name)
		s4.append([str(l2[0]) if l2.size() > 0 else "", "always"]); g.AB_SEQ[name] = s4; g.save_cfg(), seq.size() >= QuestRPG.MAX_RULES)
	g.pill("bld_reset", Rect2(d.position.x + bw + 10.0, by, bw, rh - 6.0), "Reset to default", "soft", 13.0, func():
		g.AB_SEQ.erase(name); g.seq_of(name); g.save_cfg())
	g.text("Tap an ability to cycle your unlocked ones · tap the rule to cycle checks", d.position.x + 2.0 * bw + 26.0, by + (rh - 6.0) / 2.0,
		g.fit_size("Tap an ability to cycle your unlocked ones · tap the rule to cycle checks", 11.0, d.size.x - 2.0 * bw - 30.0, 7.0), g.UI_MUTED, "left")
