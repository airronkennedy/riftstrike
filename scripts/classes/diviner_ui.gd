extends CanvasLayer
## The divination screen (docs/CLASSES.md): pick a keeper, browse all 10 callings (class or subclass) with that keeper's
## level in each, a flavor line and the 2 abilities, then a short ritual (glowing circle, flash, chime, reveal card).
## Built from Controls in the Airron's Fall theme, so touch, mouse, keyboard and gamepad (ui_* actions) all work.
## Opened by game.gd when QuestFlow.pending_screen == "diviner"; emits `closed` when the player leaves.
signal closed

const Diviner = preload("res://scripts/classes/diviner.gd")
const Signatures = preload("res://scripts/classes/signatures.gd")
const QuestRPG = preload("res://scripts/quest_rpg.gd")
const STAR := Color("#9fb8ff")
const NIGHT := Color("#0d0f1f")
const VIOLET := Color("#6f5bd6")

var g # game.gd
var root: Control
var bg: Backdrop
var s := 1.0
var step := "hero" # hero | list | confirm | ritual | reveal
var hero := ""
var mode := "class"
var pick := ""
var result := {}
var fast := false # tests: skip the ritual timing
var reduced := false
var portrait := false
var head_line: Label
var content: Control
var leave_btn: Button
var ritual: RitualFX
var _busy := false

func _ready() -> void:
	layer = 60
	root = Control.new()
	root.theme = AfTheme.get_theme()
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	bg = Backdrop.new()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	get_viewport().size_changed.connect(_relayout)
	hero = str(g.party_names()[0]) if g != null and not g.party_names().is_empty() else ""
	_relayout()
	root.modulate.a = 0.0
	root.create_tween().tween_property(root, "modulate:a", 1.0, 0.05 if fast else 0.35)

func _relayout() -> void:
	var vs := get_viewport().get_visible_rect().size
	s = clampf(minf(vs.x, vs.y) / 560.0, 0.85, 2.5)
	root.scale = Vector2(s, s)
	root.size = vs / s
	bg.size = root.size
	var was := portrait
	portrait = root.size.y > root.size.x
	if content == null or was != portrait: _show(step if step != "ritual" else "reveal")
	elif content != null: _fit_content()

func _fit_content() -> void:
	var m := 10.0 if portrait else 16.0
	var top := 108.0 if portrait else 100.0
	content.position = Vector2(m, top)
	content.size = Vector2(root.size.x - 2.0 * m, root.size.y - top - m)

# ------------------------------------------------------------------ steps
func _clear() -> void:
	for c in root.get_children():
		if c != bg: c.queue_free()

func _show(st: String) -> void:
	step = st
	_clear()
	_header()
	content = Control.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(content)
	_fit_content()
	match st:
		"hero": _hero_step()
		"list": _list_step()
		"confirm": _confirm_step()
		"reveal": _reveal_step()
	_focus_first.call_deferred()

func _focus_first() -> void:
	if content == null or not is_instance_valid(content): return
	var b := _first_button(content)
	if b != null: b.grab_focus()

func _first_button(n: Node) -> Button:
	for c in n.get_children():
		if c is Button and not (c as Button).disabled and c.visible: return c
		var r := _first_button(c)
		if r != null: return r
	return null

const LINES := {
	"hero": "Sit, sit. Whose stars are we reading? Mind the candles. The last knight sat on one.",
	"list": "%s. The sky has opinions about you. Pick a calling, and I'll ask it nicely.",
	"confirm": "The stars don't do refunds. Well, they do. You just come back and ask again.",
	"reveal": "There. Written in light. Go and be it, before the candle notices.",
}

func _header() -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	hb.position = Vector2(12, 8)
	hb.size = Vector2(root.size.x - 24, 92)
	root.add_child(hb)
	var face := TextureRect.new()
	face.texture = load("res://assets/af/heroes/adeyo.png")
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.custom_minimum_size = Vector2(52, 92)
	hb.add_child(face)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 0)
	hb.add_child(v)
	var nm := Label.new()
	nm.text = "Adeyo  ·  The Star-Reader"
	nm.theme_type_variation = "HeaderLabel"
	nm.add_theme_font_size_override("font_size", 20 if portrait else 24)
	nm.add_theme_color_override("font_color", Color("#cfe0ff"))
	v.add_child(nm)
	head_line = Label.new()
	head_line.theme_type_variation = "FlavorLabel"
	head_line.add_theme_font_size_override("font_size", 16 if portrait else 19)
	head_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head_line.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var ln: String = str(LINES.get(step, ""))
	head_line.text = ln % hero if ln.contains("%s") else ln
	v.add_child(head_line)
	leave_btn = Button.new()
	leave_btn.text = "Leave"
	leave_btn.custom_minimum_size = Vector2(88, 44)
	leave_btn.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	leave_btn.pressed.connect(close)
	AfTheme.add_press_juice(leave_btn, func(): return reduced)
	hb.add_child(leave_btn)

func _label(t: String, fs: int, col: Color = AfTheme.INK, variation: String = "") -> Label:
	var l := Label.new()
	l.text = t
	if variation != "": l.theme_type_variation = variation
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _tex(name: String) -> Texture2D:
	var p := "res://assets/af/heroes/%s.png" % name.to_lower()
	return load(p) if ResourceLoader.exists(p) else null

func _sig_text(name: String) -> String:
	var id := Signatures.id_for(g, name)
	return str(g.ABILITY_DEFS[id].name) if id != "" else ""

## Step 1: the keepers. Each card: portrait, class + level, subclass + level, signature.
func _hero_step() -> void:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.follow_focus = true
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.add_child(sc)
	var grid := GridContainer.new()
	grid.columns = 2 if portrait else mini(5, maxi(1, g.HERO_NAMES.size()))
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(grid)
	var cw: float = (content.size.x - 10.0 * float(grid.columns - 1)) / float(grid.columns) - 2.0
	for nm in g.HERO_NAMES:
		var b := Button.new()
		b.name = "hero_" + str(nm)
		b.custom_minimum_size = Vector2(cw, 214 if portrait else 250)
		b.pressed.connect(func(): hero = str(nm); g.sfx.tone(660, 0.05, "triangle", 0.03); _show("list"))
		AfTheme.add_press_juice(b, func(): return reduced)
		grid.add_child(b)
		var v := VBoxContainer.new()
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.offset_left = 10; v.offset_right = -10; v.offset_top = 8; v.offset_bottom = -8
		v.add_theme_constant_override("separation", 2)
		b.add_child(v)
		var tr := TextureRect.new()
		tr.texture = _tex(str(nm))
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(0, 92 if portrait else 120)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(tr)
		var t := _label(str(nm), 20, AfTheme.GOLD, "HeaderLabel")
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(t)
		var c: String = str(g.CHAR[nm].cls)
		var sb: String = str(g.CHAR[nm].sub)
		var l1 := _label("%s  Lv %d" % [c, g.class_level(nm, c)], 16)
		l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l1)
		var l2 := _label("Sub: %s  Lv %d" % [sb, g.sub_level(nm, sb)], 14, AfTheme.MUTED)
		l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l2)
		var sg := _sig_text(str(nm))
		if sg != "":
			var l3 := _label("Signature: " + sg + (" +" if Signatures.class_match(str(nm), c) else ""), 14, STAR)
			l3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l3.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.add_child(l3)

## Step 2: all 10 callings for this keeper, as Class or as Subclass.
func _list_step() -> void:
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 8)
	content.add_child(v)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	v.add_child(bar)
	var back := Button.new()
	back.text = "Keepers"
	back.custom_minimum_size = Vector2(96, 44)
	back.pressed.connect(func(): _show("hero"))
	bar.add_child(back)
	for m in [["class", "Class"], ["sub", "Subclass"]]:
		var tb := Button.new()
		tb.name = "mode_" + str(m[0])
		tb.text = str(m[1])
		tb.toggle_mode = true
		tb.button_pressed = mode == str(m[0])
		tb.theme_type_variation = "PrimaryButton" if mode == str(m[0]) else ""
		tb.custom_minimum_size = Vector2(104, 44)
		var mm: String = str(m[0])
		tb.pressed.connect(func(): mode = mm; g.sfx.tone(587, 0.04, "triangle", 0.03); _show("list"))
		bar.add_child(tb)
	var info := _label("", 15, AfTheme.MUTED)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.text = "%s  ·  %s Lv %d  ·  sub %s Lv %d" % [hero, g.CHAR[hero].cls, g.class_level(hero, str(g.CHAR[hero].cls)), g.CHAR[hero].sub, g.sub_level(hero, str(g.CHAR[hero].sub))]
	if portrait:
		v.add_child(info)
	else:
		bar.add_child(info)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.follow_focus = true
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sc)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	sc.add_child(list)
	for cls in QuestRPG.CLASS_ORDER:
		list.add_child(_class_row(str(cls)))

func _class_row(cls: String) -> Button:
	var c: Dictionary = QuestRPG.CLASSES[cls]
	var cur: bool = (mode == "class" and str(g.CHAR[hero].cls) == cls) or (mode == "sub" and str(g.CHAR[hero].sub) == cls)
	var other: bool = (mode == "class" and str(g.CHAR[hero].sub) == cls) or (mode == "sub" and str(g.CHAR[hero].cls) == cls)
	var open: bool = Diviner.unlocked(get_tree(), cls)
	var b := Button.new()
	b.name = "cls_" + cls
	b.disabled = cur or not open
	b.custom_minimum_size = Vector2(0, 150 if portrait else 104)
	b.pressed.connect(func(): pick = cls; g.sfx.tone(784, 0.05, "triangle", 0.03); _show("confirm"))
	AfTheme.add_press_juice(b, func(): return reduced)
	var box: BoxContainer = VBoxContainer.new() if portrait else HBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 14; box.offset_right = -14; box.offset_top = 8; box.offset_bottom = -8
	box.add_theme_constant_override("separation", 4 if portrait else 14)
	b.add_child(box)
	# name + role + level
	var head: BoxContainer = HBoxContainer.new() if portrait else VBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.custom_minimum_size = Vector2(0 if portrait else 170, 0)
	box.add_child(head)
	var nm := _label(cls, 22, AfTheme.GOLD if open else AfTheme.MUTED, "HeaderLabel")
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL if portrait else Control.SIZE_FILL
	head.add_child(nm)
	var lvl: String
	if not open: lvl = "Not yet written"
	elif cur: lvl = "Current  ·  Lv %d" % (g.class_level(hero, cls) if mode == "class" else g.sub_level(hero, cls))
	elif Diviner.known(g, hero, cls, mode): lvl = "Lv %d  ·  resumes" % Diviner.level_after(g, hero, cls, mode)
	else: lvl = "New  ·  starts Lv %d" % Diviner.start_level(g, hero)
	var lv := _label(lvl, 15, STAR if open else AfTheme.MUTED)
	head.add_child(lv)
	head.add_child(_label(str(c.role) + ("  ·  now the " + ("subclass" if mode == "class" else "class") + " (swaps)" if other else ""), 13, AfTheme.MUTED))
	# flavor + abilities
	var mid := VBoxContainer.new()
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 2)
	box.add_child(mid)
	var fl := _label(str(Diviner.FLAVOR.get(cls, c.blurb)) if open else Diviner.unlock_hint(cls), 16, AfTheme.INK, "FlavorLabel")
	fl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mid.add_child(fl)
	var rows: Array = c.abilities if mode == "class" else c.sub_abilities
	var parts: Array = []
	for rr in rows: parts.append("%s (Lv %d): %s" % [rr[1], int(rr[5]), rr[2]])
	var ab := _label("  ·  ".join(parts), 13, Color("#c9b8ff") if open else AfTheme.MUTED)
	ab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mid.add_child(ab)
	if mode == "class" and Signatures.class_match(hero, cls):
		mid.add_child(_label("Empowers %s's signature: %s+" % [hero, _sig_text(hero)], 13, STAR))
	return b

## Step 3: confirm. What happens to levels, the subclass and the signature.
func _confirm_step() -> void:
	var p := PanelContainer.new()
	p.theme_type_variation = "FramedPanel"
	var w: float = minf(content.size.x, 620.0)
	p.custom_minimum_size = Vector2(w, 0)
	p.position = Vector2((content.size.x - w) / 2.0, 0)
	content.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	var role := "class" if mode == "class" else "subclass"
	var t := _label("Read %s's stars as a %s %s?" % [hero, pick, role], 22, AfTheme.GOLD, "HeaderLabel")
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(t)
	var lines: Array = []
	if Diviner.known(g, hero, pick, mode): lines.append("%s %s Lv %d: picks up right where it left off." % [pick, role, Diviner.level_after(g, hero, pick, mode)])
	else: lines.append("A new calling. The stars remember half of %s's best: it starts at Lv %d." % [hero, Diviner.start_level(g, hero)])
	var cur_c: String = str(g.CHAR[hero].cls)
	var cur_s: String = str(g.CHAR[hero].sub)
	if mode == "class":
		lines.append("%s %s keeps its level, ready for when you come back." % [cur_c, "class"])
		if pick == cur_s: lines.append("%s is the subclass now, so the two swap: %s becomes the subclass." % [pick, cur_c])
	else:
		if pick == cur_c: lines.append("%s is the class now, so the two swap: %s becomes the class." % [pick, cur_s])
	var sg := _sig_text(hero)
	if sg != "":
		var now_c: String = pick if mode == "class" else (cur_s if pick == cur_c else cur_c)
		if Signatures.class_match(hero, now_c): lines.append("Signature %s is EMPOWERED as a %s." % [sg, now_c])
		else: lines.append("Signature %s stays with %s whatever the calling. %s" % [sg, hero, Signatures.twist(hero)])
	lines.append("A hand-set Attack Order keeps its order; its timings are re-tuned for the new class.")
	for ln in lines:
		var l := _label("·  " + str(ln), 16)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	v.add_child(hb)
	var go := Button.new()
	go.name = "divine"
	go.text = "Begin the divination"
	go.theme_type_variation = "PrimaryButton"
	go.custom_minimum_size = Vector2(0, 50)
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go.pressed.connect(_divine)
	AfTheme.add_press_juice(go, func(): return reduced)
	hb.add_child(go)
	var no := Button.new()
	no.text = "Not yet"
	no.custom_minimum_size = Vector2(120, 50)
	no.pressed.connect(func(): _show("list"))
	hb.add_child(no)

## The ritual: circle draws itself, runes spin up, a flash and a chime, then the reveal card.
func _divine() -> void:
	if _busy: return
	_busy = true
	result = Diviner.divine(g, hero, pick, mode)
	step = "ritual"
	_clear()
	ritual = RitualFX.new()
	ritual.size = root.size
	ritual.mouse_filter = Control.MOUSE_FILTER_STOP
	ritual.portrait_tex = _tex(hero)
	root.add_child(ritual)
	var dur := 0.05 if fast else 2.1
	var notes := [523.25, 659.25, 783.99, 1046.5]
	if not fast:
		g.sfx.tone(196, 1.2, "sine", 0.03, 1.5)
		for i in notes.size():
			get_tree().create_timer(0.35 + i * 0.28).timeout.connect(func(): g.sfx.tone(notes[i], 0.5, "triangle", 0.03))
	var tw := ritual.create_tween()
	tw.tween_property(ritual, "t", 1.0, dur)
	await tw.finished
	if not fast:
		g.sfx.tone(1568, 0.7, "sine", 0.035); g.sfx.tone(2093, 0.9, "triangle", 0.02)
	_busy = false
	_show("reveal")
	var fl := ColorRect.new() # the flash, fading off the reveal card
	fl.color = Color(1, 1, 1, 1)
	fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fl.size = root.size
	root.add_child(fl)
	var tw2 := fl.create_tween()
	tw2.tween_property(fl, "color:a", 0.0, 0.05 if fast else 0.7)
	tw2.tween_callback(fl.queue_free)

func _reveal_step() -> void:
	if result.is_empty(): _show("hero"); return
	var p := PanelContainer.new()
	p.name = "reveal"
	p.theme_type_variation = "FramedPanel"
	var w: float = minf(content.size.x, 560.0)
	p.custom_minimum_size = Vector2(w, 0)
	p.position = Vector2((content.size.x - w) / 2.0, 0)
	content.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var top := _label("THE STARS HAVE SPOKEN", 14, STAR)
	top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(top)
	var tr := TextureRect.new()
	tr.texture = _tex(hero)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(0, 110)
	v.add_child(tr)
	var cls: String = str(result.cls)
	var t := _label("%s, %s" % [hero, ("the " + cls) if result.mode == "class" else ("with a " + cls + " subclass")], 26, AfTheme.GOLD, "HeaderLabel")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(t)
	var lv := _label(("Lv %d  ·  a new calling" if result.fresh else "Lv %d  ·  resumed") % int(result.level), 18, STAR)
	lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(lv)
	var c: Dictionary = QuestRPG.CLASSES[cls]
	for rr in (c.abilities if result.mode == "class" else c.sub_abilities):
		var have: bool = int(result.level) >= int(rr[5])
		var l := _label("%s  ·  %s%s" % [rr[1], rr[2], "" if have else "  (Lv %d)" % int(rr[5])], 15, Color("#c9b8ff") if have else AfTheme.MUTED)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
	var notes: Array = ["Class %s  ·  Subclass %s" % [result["class"], result.sub]]
	if result.swapped: notes.append("Class and subclass swapped.")
	var sg := _sig_text(hero)
	if sg != "": notes.append(("Signature %s+ is empowered." % sg) if result.sig_plus else ("Signature: %s." % sg))
	var tm: Dictionary = result.timing
	if bool(tm.get("auto", false)): notes.append("Attack Order: the suggested order adapts on its own (spark rate %d%%)." % int(roundf(float(tm.after) * 100.0)))
	else: notes.append("Attack Order timings re-tuned: spark rate %d%% -> %d%%." % [int(roundf(float(tm.before) * 100.0)), int(roundf(float(tm.after) * 100.0))])
	for n in notes:
		var l2 := _label(str(n), 14, AfTheme.MUTED)
		l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l2)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	v.add_child(hb)
	var again := Button.new()
	again.name = "again"
	again.text = "Another reading"
	again.theme_type_variation = "PrimaryButton"
	again.custom_minimum_size = Vector2(0, 48)
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	again.pressed.connect(func(): _show("hero"))
	hb.add_child(again)
	var done := Button.new()
	done.text = "Done"
	done.custom_minimum_size = Vector2(110, 48)
	done.pressed.connect(close)
	hb.add_child(done)
	p.pivot_offset = Vector2(w / 2.0, 120)
	AfTheme.pop_in(p, reduced or fast)

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		match step:
			"list": _show("hero")
			"confirm": _show("list")
			"reveal", "hero": close()

func close() -> void:
	if _busy: return
	_busy = true
	var tw := root.create_tween()
	tw.tween_property(root, "modulate:a", 0.0, 0.05 if fast else 0.25)
	await tw.finished
	closed.emit()

# ------------------------------------------------------------------ art
## Night sky: indigo gradient, twinkling stars, a slow sigil wheel behind everything.
class Backdrop extends Control:
	var stars: Array = []
	func _ready() -> void:
		var rng := RandomNumberGenerator.new(); rng.seed = 9
		for i in 90: stars.append([rng.randf(), rng.randf(), rng.randf_range(0.6, 2.0), rng.randf() * TAU])
	func _process(_d: float) -> void: queue_redraw()
	func _draw() -> void:
		var t := Time.get_ticks_msec() * 0.001
		var n := 14
		for i in n:
			var c := Color("#0b0d1c").lerp(Color("#231a3d"), float(i) / float(n - 1))
			draw_rect(Rect2(0, size.y * float(i) / n, size.x, size.y / n + 1.0), c)
		for st in stars:
			var a := 0.35 + 0.35 * sin(t * 1.3 + float(st[3]))
			draw_circle(Vector2(float(st[0]) * size.x, float(st[1]) * size.y), float(st[2]), Color(0.75, 0.82, 1.0, a))
		var c0 := Vector2(size.x * 0.5, size.y * 0.62)
		var r0 := minf(size.x, size.y) * 0.42
		draw_arc(c0, r0, 0, TAU, 96, Color(0.55, 0.5, 1.0, 0.08), 2.0)
		draw_arc(c0, r0 * 0.78, 0, TAU, 96, Color(0.55, 0.5, 1.0, 0.06), 1.5)
		for k in 12:
			var ang := t * 0.05 + k * TAU / 12.0
			draw_line(c0 + Vector2.from_angle(ang) * r0 * 0.78, c0 + Vector2.from_angle(ang) * r0, Color(0.6, 0.55, 1.0, 0.07), 1.5)

## The divination circle: rings trace in, runes orbit and speed up, light pillars rise, then a white flash.
class RitualFX extends Control:
	var t := 0.0
	var flash := 0.0
	var portrait_tex: Texture2D
	func _process(_d: float) -> void: queue_redraw()
	func _draw() -> void:
		var now := Time.get_ticks_msec() * 0.001
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.03, 0.08, 0.92))
		var c := size * Vector2(0.5, 0.55)
		var R := minf(size.x, size.y) * 0.34
		var e := clampf(t * 1.4, 0.0, 1.0)
		var glow := Color("#9fb8ff")
		for i in 3:
			var rr := R * (1.0 - i * 0.2)
			draw_arc(c, rr, -PI / 2, -PI / 2 + TAU * e, 120, Color(glow, 0.25 + 0.5 * e), 3.0 - i * 0.6)
			draw_arc(c, rr + 6, -PI / 2, -PI / 2 + TAU * e, 120, Color(glow, 0.08 * e), 10.0)
		var spin := now * (0.6 + 4.0 * t * t)
		for k in 8:
			var a := spin + k * TAU / 8.0
			var p := c + Vector2.from_angle(a) * R * 0.9
			draw_circle(p, 4.0 + 3.0 * t, Color(0.85, 0.9, 1.0, 0.5 + 0.5 * t))
			draw_line(c + Vector2.from_angle(a) * R * 0.6, p, Color(glow, 0.25 * e), 1.5)
		var hexa := PackedVector2Array()
		for k in 7: hexa.append(c + Vector2.from_angle(-spin * 0.5 + k * TAU / 6.0) * R * 0.6)
		draw_polyline(hexa, Color(glow, 0.45 * e), 2.0)
		if portrait_tex != null:
			var h := R * 1.1
			var w := h * float(portrait_tex.get_width()) / float(portrait_tex.get_height())
			draw_texture_rect(portrait_tex, Rect2(c - Vector2(w / 2.0, h * 0.62), Vector2(w, h)), false, Color(1, 1, 1, 0.4 + 0.6 * t))
		for k in 5: # light pillars
			var x := c.x + (k - 2) * R * 0.32
			draw_rect(Rect2(x - 3, c.y - R * 1.3 * t, 6, R * 1.3 * t), Color(0.8, 0.85, 1.0, 0.12 * t))
		if flash > 0.0: draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, flash))
