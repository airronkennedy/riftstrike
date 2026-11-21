extends RefCounted
# Build screen: per keeper, pick a Class and a Subclass (2 + 2 abilities, each with its own level),
# and order the AUTO battle plan (Sequence). Data: scripts/quest_rpg.gd. Logic: game.gd set_class / set_sub / seq_of / seq_pick.
const QuestRPG = preload("res://scripts/quest_rpg.gd")
var tab := 0 # 0 class, 1 subclass, 2 sequence, 3 attack order
var pick_slot := -1 # Attack Order: tapped row waiting for a second tap to swap
var _rate_key := ""
var _rate := 0.0
var _drag_from := -1

func open() -> void:
	tab = 0

func key(g: Object, k: int) -> void:
	if k == KEY_ESCAPE or k == KEY_P or k == KEY_BACKSPACE:
		g.menu_back()
	elif k == KEY_TAB:
		tab = (tab + 1) % 4
	elif k == KEY_1: tab = 0
	elif k == KEY_2: tab = 1
	elif k == KEY_3: tab = 2
	elif k == KEY_4: tab = 3
	elif k == KEY_UP or k == KEY_LEFT:
		g.select_hero(g.char_sel - 1)
	elif k == KEY_DOWN or k == KEY_RIGHT:
		g.select_hero(g.char_sel + 1)

func draw(g: Object, vw: float, vh: float) -> void:
	var short: bool = vh <= 430
	var area: Rect2 = g.menu_sheet("bld_back", "Build", "Class, abilities, auto-cast tactics and the party's attack order.",
		func(): g.menu_back(), ["Class", "Subclass", "Tactics", "Attack Order"], tab, func(i): tab = i, "bld_tab")
	if tab == 3:
		_draw_order(g, area, short)
		return
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
	var ids: Array = g._sig_list(name) + g.class_ability_ids(name) + g.sub_ability_ids(sub)
	var gap := 6.0
	var cw: float = (d.size.x - gap * float(ids.size() - 1)) / float(maxi(1, ids.size()))
	for i in ids.size():
		var id: String = str(ids[i])
		var ab: Dictionary = g.ABILITY_DEFS[id]
		var ok: bool = g.ab_unlocked(name, id)
		var r := Rect2(d.position.x + float(i) * (cw + gap), y, cw, 34.0)
		g.rbox(r, 10.0, g.UI_GOLD_L if ok else g.UI_CARD, g.UI_GOLD if ok else g.UI_LINE, 1.2)
		var nm: String = str(ab.name)
		g.text(nm, r.position.x + 8.0, r.position.y + 11.0, g.fit_size(nm, 13.0, cw - 60.0, 8.0), g.UI_INK if ok else g.UI_MUTED, "left")
		var sg: bool = str(ab.src) == "sig"
		var tag: String = ("SIGNATURE" if sg else ("CLASS" if str(ab.src) == "class" else "SUB")) if ok else ("%s Lv.%d" % ["class" if str(ab.src) == "class" else "sub", int(ab.lv)])
		if sg and Signatures.class_match(name, cls): tag = "SIG+"
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

## Tactics (docs/CLASSES.md): the keeper's auto-cast rules, set up out of battle. Each row: ability (tap to cycle,
## incl. "Save Brave Burst"), its condition (tap to cycle), an Auto ON/OFF toggle, move up/down, remove.
## Phone portrait stacks each rule on two lines.
const Tactics = preload("res://scripts/classes/tactics.gd")
const Signatures = preload("res://scripts/classes/signatures.gd")
func _rule_choices(g: Object, name: String) -> Array:
	return g._sig_list(name) + g.loadout_of(name) + [Tactics.HOLD]

func _rule_name(g: Object, id: String) -> String:
	if id == Tactics.HOLD: return "Save Brave Burst"
	return str(g.ABILITY_DEFS[id].name) if g.ABILITY_DEFS.has(id) else id

func _draw_seq(g: Object, name: String, d: Rect2, short: bool) -> void:
	var seq: Array = g.seq_of(name)
	var lo: Array = g.loadout_of(name)
	var narrow: bool = d.size.x < 560.0
	var help := "Gauge full: the FIRST rule that passes auto-casts (top to bottom). None pass: a normal attack, gauge kept."
	g.text(help, d.position.x + 2.0, d.position.y + 8.0, g.fit_size(help, 12.0, d.size.x, 8.0), g.UI_MUTED, "left")
	var y: float = d.position.y + 22.0
	var rh: float = 38.0 if short else 46.0
	var gap: float = 6.0
	var sb: float = rh - 8.0
	for i in seq.size():
		var rr: Array = seq[i]
		var id: String = str(rr[0])
		var cond: String = str(rr[1])
		var hold: bool = id == Tactics.HOLD
		var sig: bool = not hold and g.ABILITY_DEFS.has(id) and str(g.ABILITY_DEFS[id].get("src", "")) == "sig"
		var live: bool = hold or lo.find(id) >= 0 or (sig and g.ab_unlocked(name, id))
		var off: bool = not hold and Tactics.is_off(g, name, id)
		var tall: float = rh * 2.0 + 4.0 if narrow else rh
		var r := Rect2(d.position.x, y, d.size.x, tall)
		if r.end.y > d.end.y - rh: break
		g.rbox(r, 14.0, g.UI_CARD, g.UI_GOLD if (sig and not off) else (g.UI_TEAL_D if i == 0 else g.UI_LINE), 1.5)
		g.text("#%d" % (i + 1), r.position.x + 20.0, r.position.y + rh / 2.0, 15.0, g.UI_GOLD)
		var ii: int = i
		var row_w: float = r.size.x - 40.0 - 4.0
		var aw: float = (row_w - (sb + 6.0) * 1.0 - 70.0) if narrow else minf(230.0, (r.size.x - 5.0 * (sb + 6.0) - 120.0) * 0.5)
		var ar := Rect2(r.position.x + 40.0, r.position.y + 4.0, aw, rh - 8.0)
		var an: String = ("SIG · " if sig else "") + _rule_name(g, id) + ("" if live else "  (locked)")
		g.pill("bld_sa_%d" % i, ar, an, ("gold" if sig else "primary") if (live and not off) else "soft", 13.0, func():
			var s: Array = g.seq_of(name).duplicate(true)
			s[ii][0] = _cycle(_rule_choices(g, name), str(s[ii][0])); g.AB_SEQ[name] = s; g.save_cfg())
		# auto-cast toggle
		var tr := Rect2(ar.end.x + 6.0, r.position.y + 4.0, 64.0, rh - 8.0)
		if not hold:
			g.pill("bld_st_%d" % i, tr, "OFF" if off else "AUTO", "soft" if off else "tealsoft", 12.0, func():
				Tactics.set_off(g, name, id, not Tactics.is_off(g, name, id)); g.save_cfg())
		var cy: float = r.position.y + (rh + 4.0 if narrow else 0.0)
		var cx: float = r.position.x + 40.0 if narrow else tr.end.x + 8.0
		var cw: float = (r.size.x - 40.0 - 3.0 * (sb + 6.0) - 22.0) if narrow else aw
		if not narrow: g.text("if", cx + 6.0, r.position.y + rh / 2.0, 13.0, g.UI_MUTED); cx += 18.0
		var cr := Rect2(cx, cy + 4.0, cw, rh - 8.0)
		g.pill("bld_sc_%d" % i, cr, Tactics.label(cond), "gold" if cond != "always" else "soft", 12.0, func():
			var s2: Array = g.seq_of(name).duplicate(true)
			s2[ii][1] = _cycle(Tactics.COND_ORDER, str(s2[ii][1])); g.AB_SEQ[name] = s2; g.save_cfg())
		var bx: float = r.end.x - 3.0 * (sb + 6.0)
		g.pill("bld_su_%d" % i, Rect2(bx, cy + 4.0, sb, sb), "", "soft", 13.0, func(): _move(name, g, ii, -1), false, i == 0, false, "", "up")
		g.pill("bld_sd_%d" % i, Rect2(bx + sb + 6.0, cy + 4.0, sb, sb), "", "soft", 13.0, func(): _move(name, g, ii, 1), false, i == seq.size() - 1, false, "", "down")
		g.pill("bld_sx_%d" % i, Rect2(bx + 2.0 * (sb + 6.0), cy + 4.0, sb, sb), "X", "danger", 13.0, func():
			var s3: Array = g.seq_of(name).duplicate(true)
			s3.remove_at(ii); g.AB_SEQ[name] = s3; g.save_cfg(), false, sig)
		y += tall + gap
	var bw: float = minf(150.0, (d.size.x - 10.0) / 2.0)
	var by: float = minf(y + 4.0, d.end.y - rh)
	g.pill("bld_add", Rect2(d.position.x, by, bw, rh - 6.0), "+ Add rule", "primary", 14.0, func():
		var s4: Array = g.seq_of(name).duplicate(true)
		var l2: Array = g.loadout_of(name)
		s4.append([str(l2[0]) if l2.size() > 0 else Tactics.HOLD, "always"]); g.AB_SEQ[name] = s4; g.save_cfg(), seq.size() >= QuestRPG.MAX_RULES)
	g.pill("bld_reset", Rect2(d.position.x + bw + 10.0, by, bw, rh - 6.0), "Reset to default", "soft", 13.0, func():
		g.AB_SEQ.erase(name); g.AB_OFF.erase(name); g.seq_of(name); g.save_cfg())

# ------------------------------------------------------------------ attack order (docs/COMBO.md)
const Combo = preload("res://scripts/combo.gd")
const SPARK_GREEN := Color("#7fc83a")

func _order_frames(g: Object, order: Array) -> Array:
	var fr: Array = []
	for nm in order: fr.append(Combo.frames(str(g.CHAR[nm].cls)))
	return fr

func _delays(g: Object, order: Array) -> Array:
	var d: Array = []
	var hd: Dictionary = g.attack_delays() # the suggested delays while the Build is untouched
	for nm in order: d.append(float(hd.get(nm, 0.0)))
	return d

func _swap(g: Object, a: int, b: int) -> void:
	var o: Array = g.attack_order()
	if a < 0 or b < 0 or a >= o.size() or b >= o.size() or a == b: return
	var t = o[a]; o[a] = o[b]; o[b] = t
	g.set_attack_order(o)
	g.sfx.tone(660 + b * 40, 0.05, "triangle", 0.03)

## Rows (one per keeper, in attack order) with timing traits, reorder + delay controls, and a timeline that
## shows each keeper's expected hit window (solid), its jitter range (faint), hit ticks, and spark overlaps (green).
func _draw_order(g: Object, area: Rect2, short: bool) -> void:
	var order: Array = g.attack_order()
	var fr := _order_frames(g, order)
	var dl := _delays(g, order)
	var key := ",".join(order) + "|" + str(dl)
	if key != _rate_key:
		_rate_key = key
		_rate = Combo.spark_rate(fr, dl, 80)
	var d := area.grow(-4.0)
	var help := "Keepers attack top to bottom, %.2fs apart. Hits from two keepers on one foe within %d ms SPARK (+50%% damage). Slow, late-hitting keepers early and fast ones after them line up. Tap two rows to swap them." % [Combo.SLOT_STAGGER / 1000.0, int(Combo.SPARK_WINDOW)]
	var hy: float = d.position.y + 22.0
	if d.size.x < 600.0:
		var lines: Array = g.wrap_words(help, 10.0, d.size.x - 4.0)
		for li in lines.size():
			g.text(str(lines[li]), d.position.x + 2.0, d.position.y + 8.0 + li * 12.0, 10.0, g.UI_MUTED, "left")
		hy = d.position.y + 8.0 + lines.size() * 12.0 + 4.0
	else:
		g.text(help, d.position.x + 2.0, d.position.y + 8.0, g.fit_size(help, 12.0, d.size.x, 8.0), g.UI_MUTED, "left")
	var rate_s := "Expected sparks: %d%% of hits" % int(roundf(_rate * 100.0))
	var rcol: Color = SPARK_GREEN if _rate >= 0.55 else (g.UI_GOLD if _rate >= 0.35 else g.UI_INK)
	g.text(rate_s, d.position.x + 2.0, hy + 14.0, 17.0, rcol, "left")
	var stacked: bool = d.size.x < 600.0 # phone portrait: rows on top, timeline below
	var bw := 150.0 if not stacked else (d.size.x - 10.0) / 2.0
	var by0: float = hy if not stacked else hy + 26.0
	g.pill("bld_ord_suggest", Rect2(d.end.x - bw * 2.0 - 10.0, by0, bw, 30.0), "Suggest order", "primary", 13.0, func():
		var plan: Dictionary = Combo.best_plan(_order_frames(g, order))
		var o2: Array = []
		for i in plan.order: o2.append(order[i])
		for j in o2.size(): g.HERO_DELAY[o2[j]] = float(plan.delays[j])
		g.set_attack_order(o2); pick_slot = -1
		g.sfx.tone(988, 0.08, "triangle", 0.035))
	g.pill("bld_ord_reset", Rect2(d.end.x - bw, by0, bw, 30.0), "Reset delays", "soft", 13.0, func():
		g.HERO_DELAY = {}; g.save_cfg(); pick_slot = -1)
	var top: float = by0 + 40.0
	var n: int = order.size()
	var rh: float = clampf((d.end.y - top - 30.0) / maxf(1.0, float(n)) - 6.0, 34.0, 76.0)
	var lw: float = minf(390.0, d.size.x * 0.44) # left column: names + controls
	var tl := Rect2(d.position.x + lw + 10.0, top, d.size.x - lw - 10.0, float(n) * (rh + 6.0) - 6.0)
	var lane_step: float = rh + 6.0
	var lane_y0: float = top
	var lane_hh: float = rh
	if stacked:
		rh = clampf((d.end.y - top) * 0.5 / maxf(1.0, float(n)) - 6.0, 30.0, 52.0)
		lw = d.size.x
		var ty: float = top + float(n) * (rh + 6.0) + 10.0
		tl = Rect2(d.position.x + 4.0, ty, d.size.x - 8.0, maxf(80.0, d.end.y - ty - 36.0))
		lane_step = tl.size.y / maxf(1.0, float(n))
		lane_y0 = tl.position.y
		lane_hh = lane_step - 4.0
	# timeline scale
	var tmax := 0.0
	var wins: Array = []
	for i in n:
		var w: Dictionary = Combo.window(fr[i], i, dl[i])
		wins.append(w)
		tmax = maxf(tmax, float(w.last) + float(w.jit_end))
	tmax = ceilf((tmax + 150.0) / 500.0) * 500.0
	var sx := func(ms: float) -> float: return tl.position.x + tl.size.x * clampf(ms / tmax, 0.0, 1.0)
	g.rbox(tl.grow(4.0), 10.0, g.UI_CARD, g.UI_LINE, 1.0)
	var tick := 0.0
	while tick <= tmax:
		var x: float = sx.call(tick)
		g.draw_line(Vector2(x, tl.position.y - 2.0), Vector2(x, tl.end.y + 2.0), Color(g.UI_LINE.r, g.UI_LINE.g, g.UI_LINE.b, 0.35), 1.0)
		g.text("%.1fs" % (tick / 1000.0), x, tl.end.y + 14.0, 10.0, g.UI_MUTED)
		tick += 500.0
	# spark overlaps: pairwise window intersections (core windows), drawn as green bands across both lanes
	for i in n:
		for j in range(i + 1, n):
			var a0: float = maxf(float(wins[i].first), float(wins[j].first)) - Combo.SPARK_WINDOW * 0.5
			var a1: float = minf(float(wins[i].last), float(wins[j].last)) + Combo.SPARK_WINDOW * 0.5
			if a1 <= a0: continue
			var y0: float = lane_y0 + float(i) * lane_step
			var y1: float = lane_y0 + float(j) * lane_step + lane_hh
			var band := Rect2(sx.call(a0), y0, maxf(2.0, sx.call(a1) - sx.call(a0)), y1 - y0)
			g.draw_rect(band, Color(SPARK_GREEN.r, SPARK_GREEN.g, SPARK_GREEN.b, 0.16))
			g.draw_rect(band, Color(SPARK_GREEN.r, SPARK_GREEN.g, SPARK_GREEN.b, 0.5), false, 1.0)
	for i in n:
		var nm: String = order[i]
		var f: Dictionary = fr[i]
		var y: float = top + float(i) * (rh + 6.0)
		var row := Rect2(d.position.x, y, lw, rh)
		var picked: bool = pick_slot == i
		g.rbox(row, 12.0, g.UI_GOLD_L if picked else g.UI_CARD, g.UI_GOLD if picked else g.UI_LINE, 1.6 if picked else 1.0)
		g.text("#%d" % (i + 1), row.position.x + 18.0, row.get_center().y, 15.0, g.UI_GOLD)
		var cls: String = str(g.CHAR[nm].cls)
		g.text(nm, row.position.x + 36.0, row.position.y + rh * 0.32, g.fit_size(nm, 14.0, 110.0, 9.0), g.UI_INK, "left")
		var tr := Combo.traits(f)
		var tag := Combo.speed_tag(f)
		var tcol: Color = SPARK_GREEN if tag == "Fast" else (g.UI_GOLD if tag == "Steady" else Color("#c0603a"))
		g.text(cls + " · " + str(f.style), row.position.x + 36.0, row.position.y + rh * 0.62, 10.0, g.UI_MUTED, "left")
		if rh >= 44.0: g.text(tr, row.position.x + 36.0, row.position.y + rh * 0.86, g.fit_size(tr, 10.0, 130.0, 7.0), tcol, "left")
		else: g.text(tag, row.end.x - 4.0 * (minf(rh - 10.0, 30.0) + 4.0) - 62.0, row.get_center().y, 10.0, tcol, "right")
		# controls: up / down, delay - / +
		var bs: float = minf(rh - 10.0, 30.0)
		var bx: float = row.end.x - 4.0 * (bs + 4.0) - 56.0
		var ii := i
		g.pill("bld_ou_%d" % i, Rect2(bx, row.position.y + (rh - bs) / 2.0, bs, bs), "", "soft", 12.0, func(): _swap(g, ii, ii - 1); pick_slot = -1, false, i == 0, false, "", "up")
		g.pill("bld_od_%d" % i, Rect2(bx + bs + 4.0, row.position.y + (rh - bs) / 2.0, bs, bs), "", "soft", 12.0, func(): _swap(g, ii, ii + 1); pick_slot = -1, false, i == n - 1, false, "", "down")
		var dx: float = bx + 2.0 * (bs + 4.0) + 6.0
		var dv: float = float(dl[i])
		g.pill("bld_om_%d" % i, Rect2(dx, row.position.y + (rh - bs) / 2.0, bs, bs), "-", "soft", 14.0, func(): g.set_hero_delay(nm, dv - Combo.DELAY_STEP), false, dv <= 0.0)
		g.text("+%dms" % int(dv), dx + bs + 28.0, row.get_center().y, 11.0, g.UI_GOLD if dv > 0.0 else g.UI_MUTED)
		g.pill("bld_op_%d" % i, Rect2(dx + bs + 56.0, row.position.y + (rh - bs) / 2.0, bs, bs), "+", "soft", 14.0, func(): g.set_hero_delay(nm, dv + Combo.DELAY_STEP), false, dv >= Combo.DELAY_MAX)
		# tap the name area: pick, then tap another row to swap (tap-to-reorder)
		g.add_btn("bld_opick_%d" % i, Rect2(row.position.x, row.position.y, bx - row.position.x - 4.0, rh), func():
			if pick_slot < 0: pick_slot = ii; g.sfx.tone(784, 0.04, "triangle", 0.025)
			elif pick_slot == ii: pick_slot = -1
			else: _swap(g, pick_slot, ii); pick_slot = -1)
		# lane: jitter range (faint), core window (solid), hit ticks
		var w: Dictionary = wins[i]
		var ly: float = lane_y0 + float(i) * lane_step + lane_hh * 0.5
		var lh: float = minf(16.0, lane_hh * 0.36)
		var j0: float = float(w.first) - float(w.jit)
		var j1: float = float(w.last) + float(w.jit_end)
		var accent: Color = Color("#e08a3c") if str(f.style) == "melee" else (Color("#58a8e0") if str(f.style) == "ranged" else Color("#b07ae0"))
		var t0: float = float(i) * Combo.SLOT_STAGGER + float(dl[i])
		g.draw_line(Vector2(sx.call(t0), ly), Vector2(sx.call(float(w.first)), ly), Color(accent.r, accent.g, accent.b, 0.45), 1.5)
		g.draw_circle(Vector2(sx.call(t0), ly), 3.0, accent)
		g.draw_rect(Rect2(sx.call(j0), ly - lh * 0.5 - 3.0, sx.call(j1) - sx.call(j0), lh + 6.0), Color(accent.r, accent.g, accent.b, 0.18))
		g.draw_rect(Rect2(sx.call(float(w.first)), ly - lh * 0.5, maxf(3.0, sx.call(float(w.last)) - sx.call(float(w.first))), lh), Color(accent.r, accent.g, accent.b, 0.75))
		for h in int(f.hits):
			var hx: float = sx.call(float(w.first) + float(f.interval) * float(h))
			g.draw_line(Vector2(hx, ly - lh * 0.5 - 4.0), Vector2(hx, ly + lh * 0.5 + 4.0), Color(1, 0.97, 0.9, 0.95), 2.0)
		if sx.call(j1) < tl.end.x - 50.0: g.text(str(nm), sx.call(j1) + 6.0, ly, 10.0, g.UI_MUTED, "left")
	var leg := "Dot = start · line = dash / windup · bar = hit window (ticks = hits) · faint = jitter · green = spark overlap · Brave Bursts hit about twice as often"
	g.text(leg, d.position.x + 2.0, d.end.y - 6.0, g.fit_size(leg, 11.0, d.size.x, 7.0), g.UI_MUTED, "left")
