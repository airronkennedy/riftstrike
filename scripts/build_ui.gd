extends RefCounted
# Build screen: per keeper, pick a Class, slot abilities (Loadout), and order the AUTO battle plan (Sequence).
# Data: scripts/quest_rpg.gd. Logic: game.gd set_class / toggle_loadout / seq_of / seq_pick.
const QuestRPG = preload("res://scripts/quest_rpg.gd")
var tab := 0 # 0 class, 1 loadout, 2 sequence

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
		func(): g.menu_back(), ["Class", "Loadout", "Sequence"], tab, func(i): tab = i, "bld_tab")
	var d: Rect2 = g.hero_picker("bld_hero_", area, short, func(hn, hs): return "Lv." + str(int(hs.level)) + "  " + str(hs.cls))
	var name: String = g.selected_hero()
	if tab == 0: _draw_class(g, name, d, short)
	elif tab == 1: _draw_loadout(g, name, d, short)
	else: _draw_seq(g, name, d, short)

# ------------------------------------------------------------------ class
func _draw_class(g: Object, name: String, d: Rect2, short: bool) -> void:
	var cur: String = str(g.CHAR[name].cls)
	g.text("%s is a %s. Changing class swaps stats and the ability pool, and resets the loadout and sequence to that class's defaults." % [name, cur],
		d.position.x + 2.0, d.position.y + 8.0, g.fit_size("x".repeat(150), 12.0, d.size.x, 8.0), g.UI_MUTED, "left")
	var ids: Array = QuestRPG.CLASS_ORDER
	var cols: int = 3 if d.size.x >= 480.0 else 2
	var gap: float = 8.0
	var top: float = d.position.y + 22.0
	var rows: int = int(ceil(float(ids.size()) / float(cols)))
	var cw: float = (d.size.x - gap * float(cols - 1)) / float(cols)
	var ch: float = minf(150.0, (d.end.y - top - gap * float(rows - 1)) / float(rows))
	for i in ids.size():
		var cls: String = ids[i]
		var c: Dictionary = QuestRPG.CLASSES[cls]
		var r := Rect2(d.position.x + float(i % cols) * (cw + gap), top + float(i / cols) * (ch + gap), cw, ch)
		var sel: bool = cls == cur
		g.rbox(r, 16.0, g.UI_GOLD_L if sel else g.UI_CARD, g.UI_GOLD if sel else g.UI_LINE, 2.5 if sel else 1.5)
		g.text(cls, r.position.x + 12.0, r.position.y + 16.0, 18.0 if not short else 15.0, g.UI_GOLD if sel else g.UI_INK, "left")
		g.text(("CURRENT · " if sel else "") + str(c.role), r.end.x - 10.0, r.position.y + 16.0, 11.0, g.UI_GOLD if sel else g.UI_TEAL_D, "right")
		var lines: Array = g.wrap_words(str(c.blurb), 12.0, r.size.x - 22.0)
		var ly: float = r.position.y + 38.0
		for ln in lines.slice(0, 2):
			g.text(str(ln), r.position.x + 12.0, ly, 12.0, g.UI_MUTED, "left"); ly += 15.0
		var parts: Array = []
		for k in ["hp", "atk", "def", "armor", "crit", "speed"]:
			if int(c.get(k, 0)) != 0: parts.append("%s +%d" % [{"hp": "HP", "atk": "ATK", "def": "DEF", "armor": "ARM", "crit": "CRIT", "speed": "SPD"}[k], int(c[k])])
		var pk: String = "  ".join(parts)
		g.text(pk, r.position.x + 12.0, r.end.y - 30.0, g.fit_size(pk, 11.0, r.size.x - 22.0, 8.0), g.UI_INK, "left")
		var pool: Array = g.RPG_POOL_IDS.get(cls, [])
		var names: Array = []
		for id in pool.slice(0, 3): names.append(str(g.ABILITY_DEFS[id].name))
		var nl: String = ", ".join(names) + " …"
		g.text(nl, r.position.x + 12.0, r.end.y - 13.0, g.fit_size(nl, 11.0, r.size.x - 22.0, 8.0), g.UI_TEAL_D, "left")
		var cc: String = cls
		g.add_btn("bld_cls_" + cls, r, func(): g.set_class(name, cc); g.sfx.tone(784, 0.05, "triangle", 0.03))

# ------------------------------------------------------------------ loadout
func _src_tag(g: Object, name: String, id: String) -> String:
	if str(g.SIG_AB.get(name, "")) == id: return "Signature"
	return "Class" if str(g.ABILITY_DEFS[id].src) == "class" else "Subclass"

func _draw_loadout(g: Object, name: String, d: Rect2, short: bool) -> void:
	var lo: Array = g.loadout_of(name)
	var n: int = QuestRPG.LOADOUT_SLOTS
	g.text("Slotted (%d/%d) · tap one to remove it" % [lo.size(), n], d.position.x + 2.0, d.position.y + 8.0, 12.0, g.UI_MUTED, "left")
	var gap: float = 8.0
	var sw: float = (d.size.x - gap * float(n - 1)) / float(n)
	var sh: float = 50.0 if short else 62.0
	var y: float = d.position.y + 20.0
	for i in n:
		var r := Rect2(d.position.x + float(i) * (sw + gap), y, sw, sh)
		if i < lo.size():
			var id: String = str(lo[i])
			g.rbox(r, 14.0, g.UI_GOLD_L, g.UI_GOLD, 2.0)
			var nm: String = str(g.ABILITY_DEFS[id].name)
			g.text(nm, r.get_center().x, r.position.y + sh * 0.34, g.fit_size(nm, 15.0, sw - 12.0, 9.0), g.UI_INK)
			var ef: String = g.ab_effect_line(id)
			g.text(ef, r.get_center().x, r.position.y + sh * 0.72, g.fit_size(ef, 11.0, sw - 12.0, 7.0), g.ab_color(id))
			var iid: String = id
			g.add_btn("bld_slot_%d" % i, r, func(): g.toggle_loadout(name, iid); g.sfx.tone(440, 0.05, "triangle", 0.03))
		else:
			g.rbox(r, 14.0, g.UI_CARD, g.UI_LINE, 1.5)
			g.text("Empty slot", r.get_center().x, r.get_center().y, 13.0, g.UI_MUTED)
	y += sh + 12.0
	var pool: Array = g.class_ability_ids(name) + g.sub_ability_ids(str(g.CHAR[name].sub))
	g.text("%s pool · %s subclass · tap to slot" % [str(g.CHAR[name].cls), str(g.CHAR[name].sub)], d.position.x + 2.0, y, 12.0, g.UI_MUTED, "left")
	y += 12.0
	var cols: int = 2
	var cw: float = (d.size.x - gap) / 2.0
	var rows: int = int(ceil(float(pool.size()) / 2.0))
	var rh: float = clampf((d.end.y - y - gap * float(rows - 1)) / float(maxi(1, rows)), 24.0, 44.0)
	for i in pool.size():
		var id2: String = str(pool[i])
		if not g.ABILITY_DEFS.has(id2): continue
		var r2 := Rect2(d.position.x + float(i % cols) * (cw + gap), y + float(i / cols) * (rh + 4.0), cw, rh)
		var slotted: bool = lo.find(id2) >= 0
		var ok: bool = g.ab_unlocked(name, id2)
		g.rbox(r2, rh / 2.0, g.UI_GOLD_L if slotted else g.UI_CARD, g.UI_GOLD if slotted else g.UI_LINE, 1.5)
		var nm2: String = str(g.ABILITY_DEFS[id2].name)
		var tag: String = _src_tag(g, name, id2) if ok else "Lv %d" % int(g.ABILITY_DEFS[id2].lv)
		g.text(nm2, r2.position.x + 14.0, r2.get_center().y - (6.0 if rh > 34.0 else 0.0), 13.0, g.UI_INK if ok else g.UI_MUTED, "left")
		if rh > 34.0:
			var ef2: String = g.ab_effect_line(id2)
			g.text(ef2, r2.position.x + 14.0, r2.get_center().y + 9.0, g.fit_size(ef2, 10.0, cw - 110.0, 7.0), g.ab_color(id2) if ok else g.UI_MUTED, "left")
		g.text(("ON · " if slotted else "") + tag, r2.end.x - 12.0, r2.get_center().y, 11.0, g.UI_GOLD if slotted else (g.UI_TEAL_D if ok else g.UI_LOCK), "right")
		if ok:
			var tid: String = id2
			g.add_btn("bld_pool_" + id2, r2, func():
				var good: bool = g.toggle_loadout(name, tid)
				g.sfx.tone(784 if good else 220, 0.05, "triangle", 0.03))

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
		var an: String = str(g.ABILITY_DEFS[id].name) + ("" if live else "  (not slotted)")
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
	g.text("Tap an ability to cycle your slotted ones · tap the rule to cycle checks", d.position.x + 2.0 * bw + 26.0, by + (rh - 6.0) / 2.0,
		g.fit_size("Tap an ability to cycle your slotted ones · tap the rule to cycle checks", 11.0, d.size.x - 2.0 * bw - 30.0, 7.0), g.UI_MUTED, "left")
