extends CanvasLayer
## Story UI in the Airron's Fall style (AfTheme: ash panels, carved frame, Cinzel / Rajdhani / Cormorant, ember +
## gold). Owned by the Story autoload so it works over any scene:
##   dialog box (portrait, name plate, typewriter text, tap / E to advance, choice buttons, keys 1-3),
##   objective tracker + Quests button + edge arrow toward the objective (kingdom only),
##   journal (Main Story / Side Quests / Chronicle), recruit fanfare, act title cards, the Lantern spark card,
##   battle intro flash, toasts, one-time tips and the epilogue.

const StoryData = preload("res://scripts/story/story_data.gd")
const TYPE_CPS := 52.0

const TIPS := {
	"journal": ["Your journal", "The Quests button (or J) opens your journal. The tracker at the top left always shows what to do next, and the gold arrow points the way."],
	"danger": ["Danger outside the walls", "Out on Cinderreach the Danger meter fills as you walk. When it's full, a battle starts. Wild fights get bigger as your party grows."],
	"order": ["Attack Order", "A new keeper joined. Quests > Attack Order opens Build: tap Suggest order to fit them in, so everyone's hits land on the same foe together and Spark."],
	"home": ["All four sparks", "The Lantern is full. Take it home to King Orlan in Castle Emberhold. The gold arrow shows the way."],
	"talk": ["Talking", "Walk up to anyone with a ! or ? and tap them (or press E). Tap to skip the text, tap again to continue."],
}

var story
var root: Control
var s := 1.0
var catcher: Control
var dlg: PanelContainer
var dlg_portrait_box: PanelContainer
var dlg_portrait: TextureRect
var dlg_name: Label
var dlg_title: Label
var dlg_text: Label
var dlg_more: Control
var choices_box: VBoxContainer
var tracker: PanelContainer
var tr_act: Label
var tr_title: Label
var tr_text: Label
var tr_rec: Label
var quests_btn: Button
var arrow: Control
var journal: PanelContainer
var j_tabs: Array = []
var j_body: VBoxContainer
var j_tab := 0
var toast_panel: PanelContainer
var toast_label: Label
var tip_panel: PanelContainer
var tip_title: Label
var tip_text: Label
var overlay: ColorRect
var card: PanelContainer
var card_box: VBoxContainer

var _lines: Array = []
var _line_i := 0
var _lines_cb: Callable
var _choice_cb: Callable
var _chars := 0.0
var _speaker := ""
var _blocking := false
var _tap := false
var _hud := false
var _toasts: Array = []
var _toast_t := 0.0
var _tip_t := 0.0
var _wd_t := 0.0 # watchdog: how long the dialog has looked stuck
var _block_t := 0.0 # watchdog: how long a blocking card has run with nothing on screen
var _tip_held := false # a tip hidden while a dialog / journal / card is open
var _pulse := 0.0
var fast := false
var _dlg_tw: Tween
var want_build := false # a boss lesson's "Open Attack Order" was tapped (Story opens Build after the card)
var j_build: Button # tests: cards and typewriter finish at once


func _ready() -> void:
	layer = 30
	# Dialogs keep typing / taking taps even if the tree is paused (a paused tree must never strand a dialog).
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.theme = AfTheme.get_theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build()


func _rm() -> bool:
	var k = story.kingdom if story else null
	return k != null and is_instance_valid(k) and bool(k.reduced_motion)


# ================================================================ build
func _build() -> void:
	# HUD: tracker, Quests button, arrow
	arrow = Control.new()
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow.draw.connect(_draw_arrow)
	root.add_child(arrow)
	tracker = PanelContainer.new()
	tracker.theme_type_variation = "ToastPanel"
	tracker.mouse_filter = Control.MOUSE_FILTER_STOP
	tracker.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT: open_journal())
	root.add_child(tracker)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 0)
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tracker.add_child(tv)
	var th := HBoxContainer.new()
	th.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tv.add_child(th)
	tr_act = _label("", "MutedLabel", 12)
	tr_act.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	th.add_child(tr_act)
	tr_rec = _label("", "", 12)
	tr_rec.add_theme_color_override("font_color", AfTheme.EMBER_LIGHT)
	th.add_child(tr_rec)
	tr_title = _label("", "HeaderLabel", 16)
	tv.add_child(tr_title)
	tr_text = _label("", "", 15)
	tr_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tv.add_child(tr_text)
	quests_btn = Button.new()
	quests_btn.text = "Quests"
	quests_btn.add_theme_font_size_override("font_size", 17)
	quests_btn.pressed.connect(open_journal)
	AfTheme.add_press_juice(quests_btn, _rm)
	root.add_child(quests_btn)
	# Tap catcher behind the dialog: a tap anywhere advances.
	catcher = Control.new()
	catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	catcher.visible = false
	catcher.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT: advance())
	root.add_child(catcher)
	# Dialog
	dlg = PanelContainer.new()
	dlg.theme_type_variation = "FramedPanel"
	dlg.visible = false
	dlg.mouse_filter = Control.MOUSE_FILTER_STOP
	dlg.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT: advance())
	root.add_child(dlg)
	var dh := HBoxContainer.new()
	dh.add_theme_constant_override("separation", 16)
	dh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dlg.add_child(dh)
	dlg_portrait_box = PanelContainer.new()
	var pb := StyleBoxFlat.new()
	pb.bg_color = Color(AfTheme.CARD, 0.95)
	pb.border_color = AfTheme.GOLD_DARK
	pb.set_border_width_all(2)
	pb.corner_radius_top_left = 12; pb.corner_radius_bottom_right = 12
	pb.set_content_margin_all(4)
	dlg_portrait_box.add_theme_stylebox_override("panel", pb)
	dlg_portrait_box.custom_minimum_size = Vector2(112, 112)
	dlg_portrait_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	dlg_portrait_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dh.add_child(dlg_portrait_box)
	dlg_portrait = TextureRect.new()
	dlg_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dlg_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	dlg_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dlg_portrait_box.add_child(dlg_portrait)
	var dv := VBoxContainer.new()
	dv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dv.add_theme_constant_override("separation", 2)
	dv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dh.add_child(dv)
	var nh := HBoxContainer.new()
	nh.add_theme_constant_override("separation", 10)
	nh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dv.add_child(nh)
	dlg_name = _label("", "HeaderLabel", 22)
	nh.add_child(dlg_name)
	dlg_title = _label("", "MutedLabel", 14)
	dlg_title.size_flags_vertical = Control.SIZE_SHRINK_END
	nh.add_child(dlg_title)
	dlg_text = _label("", "", 21)
	dlg_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dlg_text.custom_minimum_size = Vector2(0, 84)
	dlg_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dv.add_child(dlg_text)
	dlg_more = Control.new()
	dlg_more.custom_minimum_size = Vector2(0, 14)
	dlg_more.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dlg_more.draw.connect(func():
		if dlg_text.visible_ratio < 1.0 or not choices_box.get_children().is_empty(): return
		var x := dlg_more.size.x - 14.0
		var y := 2.0 + (0.0 if _rm() else absf(sin(Time.get_ticks_msec() * 0.006)) * 4.0)
		dlg_more.draw_colored_polygon(PackedVector2Array([Vector2(x - 8, y), Vector2(x + 8, y), Vector2(x, y + 9)]), AfTheme.EMBER_LIGHT))
	dv.add_child(dlg_more)
	choices_box = VBoxContainer.new()
	choices_box.add_theme_constant_override("separation", 8)
	root.add_child(choices_box)
	# Journal
	journal = PanelContainer.new()
	journal.theme_type_variation = "FramedPanel"
	journal.visible = false
	root.add_child(journal)
	var jv := VBoxContainer.new()
	jv.add_theme_constant_override("separation", 10)
	journal.add_child(jv)
	var jh := HBoxContainer.new()
	jv.add_child(jh)
	var jt := _label("Journal", "HeaderLabel", 26)
	jt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	jh.add_child(jt)
	var jb := Button.new()
	jb.text = "Attack Order"
	jb.tooltip_text = "Party & Attack Order (Build)"
	jb.custom_minimum_size = Vector2(132, 44)
	jb.pressed.connect(func(): close_journal(); story.open_build())
	AfTheme.add_press_juice(jb, _rm)
	jh.add_child(jb)
	j_build = jb
	var jc := Button.new()
	jc.text = "Close"
	jc.custom_minimum_size = Vector2(96, 44)
	jc.pressed.connect(close_journal)
	AfTheme.add_press_juice(jc, _rm)
	jh.add_child(jc)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	jv.add_child(tabs)
	for i in 3:
		var b := Button.new()
		b.text = ["Main Story", "Side Quests", "Chronicle"][i]
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 44)
		var idx := i
		b.pressed.connect(func(): j_tab = idx; _fill_journal())
		tabs.add_child(b)
		j_tabs.append(b)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	jv.add_child(sc)
	j_body = VBoxContainer.new()
	j_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	j_body.add_theme_constant_override("separation", 8)
	sc.add_child(j_body)
	# Toast + tip
	toast_panel = PanelContainer.new()
	toast_panel.theme_type_variation = "ToastPanel"
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_panel.visible = false
	root.add_child(toast_panel)
	toast_label = _label("", "", 18)
	toast_label.add_theme_color_override("font_color", AfTheme.GOLD)
	toast_panel.add_child(toast_label)
	tip_panel = PanelContainer.new()
	tip_panel.theme_type_variation = "ToastPanel"
	tip_panel.visible = false
	tip_panel.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed: tip_panel.visible = false)
	root.add_child(tip_panel)
	var tpv := VBoxContainer.new()
	tpv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip_panel.add_child(tpv)
	tip_title = _label("", "HeaderLabel", 16)
	tpv.add_child(tip_title)
	tip_text = _label("", "", 15)
	tip_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tpv.add_child(tip_text)
	# Full-screen cards (act titles, fanfare, sparks, epilogue)
	overlay = ColorRect.new()
	overlay.color = Color(0.03, 0.02, 0.015, 0.0)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	overlay.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT: _tap = true)
	root.add_child(overlay)
	card = PanelContainer.new()
	card.theme_type_variation = "FramedPanel"
	card.visible = false
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(card)
	card_box = VBoxContainer.new()
	card_box.alignment = BoxContainer.ALIGNMENT_CENTER
	card_box.add_theme_constant_override("separation", 10)
	card_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(card_box)


func _label(t: String, variation: String, fs: int) -> Label:
	var l := Label.new()
	l.text = t
	if variation != "": l.theme_type_variation = variation
	l.add_theme_font_size_override("font_size", fs)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


# ================================================================ frame
func _process(delta: float) -> void:
	_layout()
	_watchdog(delta)
	if dlg.visible and dlg_text.visible_ratio < 1.0:
		_chars += delta * TYPE_CPS
		dlg_text.visible_characters = int(_chars)
		if dlg_text.visible_characters >= dlg_text.get_total_character_count(): dlg_text.visible_ratio = 1.0
	if dlg.visible: dlg_more.queue_redraw()
	# Tips and toasts belong to the field (kingdom / dungeon): hide them over the title, Build and battles
	# (main.tscn); queued toasts wait for the field.
	var cs := get_tree().current_scene
	if cs != null and cs.scene_file_path == "res://main.tscn":
		if tip_panel.visible: tip_panel.visible = false
		_tip_held = false
		if toast_panel.visible: toast_panel.visible = false
		arrow.queue_redraw()
		return
	if toast_panel.visible:
		_toast_t -= delta
		if _toast_t <= 0.0:
			if _toasts.is_empty(): AfTheme.pop_out(toast_panel, _rm())
			else: _show_next_toast()
	elif not _toasts.is_empty(): _show_next_toast()
	# Hold a tip while a dialog, the journal or a story card is up: hide it and keep its time, then bring it back.
	var busy: bool = dlg.visible or journal.visible or card.visible
	if busy and tip_panel.visible:
		tip_panel.visible = false
		_tip_held = true
	elif not busy and _tip_held:
		_tip_held = false
		if _tip_t > 0.0: AfTheme.pop_in(tip_panel, _rm())
	if tip_panel.visible:
		_tip_t -= delta
		if _tip_t <= 0.0: AfTheme.pop_out(tip_panel, _rm())
	if _pulse > 0.0:
		_pulse = maxf(0.0, _pulse - delta)
		var g := sin(_pulse * 10.0) * 0.5 + 0.5
		tracker.modulate = Color(1, 1, 1).lerp(Color(1.25, 1.1, 0.8), g * minf(1.0, _pulse))
	arrow.queue_redraw()


func _kui() -> Variant:
	var k = story.kingdom if story else null
	if k != null and is_instance_valid(k) and k.get("ui") != null: return k.ui
	return null


func _layout() -> void:
	var vs := get_viewport().get_visible_rect().size
	var kui = _kui()
	if kui != null: s = kui.scale.x
	else: s = clampf(minf(vs.x, vs.y) / 560.0, 0.85, 2.5)
	root.scale = Vector2(s, s)
	var w := vs.x / s
	var h := vs.y / s
	root.size = Vector2(w, h)
	var m := 12.0
	var portrait := h > w
	# Tracker under the kingdom's location card; Quests under its Menu button.
	var k = story.kingdom if story else null
	var tx := m
	var ty := 120.0
	var qpos := Vector2(w - 84 - m, 180)
	if k != null and is_instance_valid(k) and k.get("loc_card") != null:
		tx = k.loc_card.position.x
		ty = k.loc_card.position.y + k.loc_card.size.y + 8.0
		qpos = Vector2(k.menu_btn.position.x, k.menu_btn.position.y + k.menu_btn.size.y + 8.0)
	var tw := minf(270.0, w * (0.5 if portrait else 0.32))
	tracker.custom_minimum_size = Vector2(tw, 0)
	tracker.size = Vector2(tw, 0)
	tracker.position = Vector2(tx, ty)
	quests_btn.size = Vector2(84, 40)
	quests_btn.position = qpos
	arrow.size = Vector2(w, h)
	catcher.size = Vector2(w, h)
	overlay.size = Vector2(w, h)
	# Dialog at the bottom, choices stacked above it.
	var dw := minf(w - 2 * m, 680.0)
	dlg.custom_minimum_size = Vector2(dw, 0)
	dlg.size = Vector2(dw, 0)
	dlg.position = Vector2((w - dw) / 2.0, h - dlg.size.y - m)
	var cw := minf(dw, 460.0)
	choices_box.size = Vector2(cw, 0)
	choices_box.position = Vector2((w - cw) / 2.0, maxf(8.0, dlg.position.y - choices_box.size.y - 10.0))
	var jw := minf(w - 2 * m, 620.0)
	journal.size = Vector2(jw, minf(h - 2 * m, 540.0))
	journal.position = (Vector2(w, h) - journal.size) / 2.0
	toast_panel.size = Vector2.ZERO
	toast_panel.position = Vector2((w - toast_panel.size.x) / 2.0, _toast_y(portrait))
	var tpw := minf(w - 2 * m, 380.0)
	tip_panel.custom_minimum_size = Vector2(tpw, 0)
	tip_panel.size = Vector2(tpw, 0)
	tip_panel.position = Vector2((w - tpw) / 2.0, h * (0.42 if portrait else 0.3))
	var cdw := minf(w - 2 * m, 520.0)
	card.custom_minimum_size = Vector2(cdw, 0)
	card.size = Vector2(cdw, 0)
	card.position = (Vector2(w, h) - card.size) / 2.0


func set_hud_visible(on: bool) -> void:
	var show := on and not is_open()
	_hud = on
	tracker.visible = show and not story.objective().is_empty()
	quests_btn.visible = on and not card.visible
	arrow.visible = show


func is_open() -> bool:
	return dlg.visible or journal.visible or _blocking or not choices_box.get_children().is_empty()


func close_all() -> void:
	close_dialog()
	journal.visible = false
	card.visible = false
	overlay.visible = false
	_blocking = false


# ================================================================ dialog
## The kingdom's map-title banner fades out as soon as a story dialog, card or the journal opens, so the two
## never stack on top of each other (the banner is purely decorative; the location card keeps the name).
func _hush_banner() -> void:
	var k = story.kingdom if story else null
	if k == null or not is_instance_valid(k) or k.get("banner") == null: return
	var b: Control = k.banner
	if b.modulate.a <= 0.01: return
	if k.get("_banner_tw") != null and k._banner_tw.is_valid(): k._banner_tw.kill()
	var tw := b.create_tween()
	tw.tween_property(b, "modulate:a", 0.0, 0.18)


## Toasts sit just under the map banner while it's showing, never on top of it.
func _toast_y(portrait: bool) -> float:
	var y := 70.0 if not portrait else 150.0
	var k = story.kingdom if story else null
	if k != null and is_instance_valid(k) and k.get("banner") != null and (k.banner as Control).modulate.a > 0.05:
		var b: Control = k.banner
		var ks: float = k.ui.scale.x if k.get("ui") != null else 1.0
		y = maxf(y, (b.global_position.y + b.size.y * ks) / s + 10.0)
	return y


func show_lines(lines: Array, cb: Callable) -> void:
	_hush_banner()
	_lines = lines
	_line_i = 0
	_lines_cb = cb
	catcher.visible = true
	if _dlg_tw and _dlg_tw.is_valid():
		_dlg_tw.kill() # a closing dialog must not hide the next one
		dlg.visible = false
	if not dlg.visible:
		AfTheme.pop_in(dlg, _rm())
	_show_line()


func _show_line() -> void:
	var l: Array = _lines[_line_i]
	var who: String = l[0]
	var c: Dictionary = StoryData.CAST.get(who, {"name": who.capitalize(), "art": who})
	var narr := who == "narr"
	dlg_name.visible = not narr
	dlg_title.visible = not narr and c.has("title")
	dlg_name.text = str(c.get("name", ""))
	dlg_title.text = str(c.get("title", ""))
	var art: String = str(c.get("art", ""))
	dlg_portrait_box.visible = art != ""
	if art != "":
		var path := ("res://assets/af/foes/foe-%s.png" % art.substr(4)) if art.begins_with("foe:") else ("res://assets/af/heroes/%s.png" % art)
		dlg_portrait.texture = load(path) if ResourceLoader.exists(path) else null
		dlg_portrait.flip_h = who == "bramwell"
		if who != _speaker and not _rm():
			dlg_portrait_box.pivot_offset = dlg_portrait_box.size / 2.0
			dlg_portrait_box.scale = Vector2(0.86, 0.86)
			dlg_portrait_box.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(dlg_portrait_box, "scale", Vector2.ONE, 0.22)
	_speaker = who
	dlg_text.theme_type_variation = "FlavorLabel" if narr else ""
	dlg_text.add_theme_font_size_override("font_size", 22 if narr else 21)
	dlg_text.add_theme_color_override("font_color", Color("#d9cdb4") if narr else AfTheme.INK)
	dlg_text.text = str(l[1])
	_chars = 0.0
	if _rm(): dlg_text.visible_ratio = 1.0
	else: dlg_text.visible_characters = 0


func advance() -> void:
	if not dlg.visible or not choices_box.get_children().is_empty(): return
	if dlg_text.visible_ratio < 1.0:
		dlg_text.visible_ratio = 1.0
		return
	_line_i += 1
	if _line_i < _lines.size():
		_show_line()
	else:
		var cb := _lines_cb
		_lines_cb = Callable()
		if cb.is_valid(): cb.call()


func show_choices(texts: Array, cb: Callable) -> void:
	_choice_cb = cb
	for c in choices_box.get_children(): c.queue_free()
	if dlg.visible: dlg_text.visible_ratio = 1.0
	catcher.visible = true
	for i in texts.size():
		var b := Button.new()
		b.text = "%d   %s" % [i + 1, texts[i]]
		b.theme_type_variation = "PrimaryButton" if i == 0 else ""
		b.custom_minimum_size = Vector2(0, 54)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var idx := i
		b.pressed.connect(func(): _pick(idx))
		AfTheme.add_press_juice(b, _rm)
		choices_box.add_child(b)
		if not _rm():
			b.modulate.a = 0.0
			var tw := b.create_tween()
			tw.tween_interval(0.06 * i)
			tw.tween_property(b, "modulate:a", 1.0, 0.18)
	choices_box.reset_size()


func _pick(i: int) -> void:
	if choices_box.get_children().is_empty(): return
	for c in choices_box.get_children():
		choices_box.remove_child(c)
		c.queue_free()
	var cb := _choice_cb
	_choice_cb = Callable()
	if cb.is_valid(): cb.call(i)


func close_dialog() -> void:
	for c in choices_box.get_children():
		choices_box.remove_child(c)
		c.queue_free()
	catcher.visible = false
	_speaker = ""
	if not dlg.visible: return
	if _rm():
		dlg.visible = false
		return
	dlg.pivot_offset = dlg.size / 2.0
	_dlg_tw = dlg.create_tween().set_parallel(true)
	_dlg_tw.tween_property(dlg, "modulate:a", 0.0, 0.14)
	_dlg_tw.tween_property(dlg, "scale", Vector2(0.96, 0.96), 0.14)
	_dlg_tw.chain().tween_callback(func(): dlg.visible = false)


## A story dialog, choice list or blocking card is on screen and owns every tap.
func wants_taps() -> bool:
	return dlg.visible or _blocking or not choices_box.get_children().is_empty()


## Touch never depends on mouse emulation (the kingdom only turns it on while a panel is open; the dungeon
## and battle screens drive touch themselves): any finger anywhere on screen advances the dialog, taps a
## choice / card button under it, or skips a card. Emulated mouse clicks are dropped meanwhile so one tap is
## one step.
func _touch_tap(pos: Vector2) -> void:
	var hit := _button_at(pos)
	if hit != null:
		hit.pressed.emit()
		return
	if not choices_box.get_children().is_empty(): return # with choices up, only a choice moves on
	if dlg.visible: advance()
	else: _tap = true


func _button_at(pos: Vector2) -> Button:
	var pools: Array = []
	pools.append_array(choices_box.get_children())
	if card.visible: pools.append_array(card_box.get_children())
	for c in pools:
		var b := c as Button
		if b == null or not b.is_visible_in_tree() or b.disabled or b.is_queued_for_deletion(): continue
		var local: Vector2 = b.get_global_transform_with_canvas().affine_inverse() * pos
		if Rect2(Vector2.ZERO, b.size).grow(6.0).has_point(local): return b
	return null


func _input(e: InputEvent) -> void:
	if wants_taps() and not journal.visible:
		if e is InputEventScreenTouch:
			if e.pressed: _touch_tap(e.position)
			get_viewport().set_input_as_handled()
			return
		if e is InputEventScreenDrag:
			get_viewport().set_input_as_handled()
			return
		if e is InputEventMouseButton and e.device == InputEvent.DEVICE_ID_EMULATION:
			get_viewport().set_input_as_handled() # the finger already acted through _touch_tap
			return
	if e is InputEventKey and e.pressed and not e.echo:
		var kc: int = e.physical_keycode
		if dlg.visible or not choices_box.get_children().is_empty():
			if kc in [KEY_E, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
				advance()
				get_viewport().set_input_as_handled()
			elif kc >= KEY_1 and kc <= KEY_4 and not choices_box.get_children().is_empty():
				var i: int = kc - KEY_1
				if i < choices_box.get_child_count(): _pick(i)
				get_viewport().set_input_as_handled()
		elif _blocking and kc in [KEY_E, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			_tap = true
			get_viewport().set_input_as_handled()
		elif journal.visible and kc in [KEY_ESCAPE, KEY_J]:
			close_journal()
			get_viewport().set_input_as_handled()
		elif kc == KEY_J and _hud and not _kingdom_modal():
			open_journal()
			get_viewport().set_input_as_handled()


## Recovers a dialog that is on screen but can't take input: faded / shrunk by a killed tween, the tap catcher
## off, lines finished with nobody closing it, choices left invisible, or a blocking card with nothing showing.
func _watchdog(delta: float) -> void:
	var closing: bool = _dlg_tw != null and _dlg_tw.is_valid() and _dlg_tw.is_running()
	var has_choices: bool = not choices_box.get_children().is_empty()
	if dlg.visible and not closing:
		if not catcher.visible: catcher.visible = true
		var off: bool = dlg.modulate.a < 0.95 or dlg.scale.x < 0.97
		var done: bool = _line_i >= _lines.size() and not _lines_cb.is_valid() and not has_choices
		if off or done: _wd_t += delta
		else: _wd_t = 0.0
		if _wd_t > 0.8 and off:
			dlg.modulate.a = 1.0
			dlg.scale = Vector2.ONE
		if _wd_t > 2.5 and done:
			push_warning("story_ui watchdog: closing a finished dialog nobody closed")
			_wd_t = 0.0
			close_dialog()
	else:
		_wd_t = 0.0
	if has_choices:
		if not catcher.visible: catcher.visible = true
		for c in choices_box.get_children():
			var b := c as Control
			if b != null and b.modulate.a < 0.5 and b.get_tree() != null and not b.is_queued_for_deletion():
				b.set_meta("wd", float(b.get_meta("wd", 0.0)) + delta)
				if float(b.get_meta("wd")) > 0.8: b.modulate.a = 1.0
	if not has_choices and not dlg.visible and catcher.visible and not closing:
		catcher.visible = false # a stray catcher would swallow every tap on the field
	if _blocking and not card.visible and not overlay.visible:
		_block_t += delta
		if _block_t > 3.0:
			push_warning("story_ui watchdog: blocking with no card on screen")
			_tap = true
			_block_t = 0.0
	else:
		_block_t = 0.0


func _kingdom_modal() -> bool:
	var k = story.kingdom if story else null
	if k == null or not is_instance_valid(k): return false
	return k.shop.visible or k.inn.visible or k.menu.visible or k.dialog.visible


# ================================================================ tracker + arrow
func refresh_tracker(pulse: bool) -> void:
	var o: Dictionary = story.objective()
	if o.is_empty(): return
	tr_act.text = str(StoryData.ACTS.get(str(o.get("act", "")), "")).to_upper()
	tr_title.text = str(o.get("title", ""))
	tr_text.text = str(o.get("text", ""))
	var rec := int(o.get("rec", 0))
	tr_rec.text = ("Rec. Lv %d" % rec) if rec > 0 else ""
	if pulse:
		_pulse = 1.6
		toast("Quest updated: " + str(o.get("title", "")))


## Where the arrow should point: the objective on this map, or the exit toward its map. [] = nowhere.
func arrow_target() -> Array:
	var k = story.kingdom
	if k == null or not is_instance_valid(k): return []
	var o: Dictionary = story.objective()
	var tp: Array = o.get("target_pos", [])
	if tp.size() != 2: return []
	var here: String = str(k.map.get("id", ""))
	if str(tp[0]) == here: return [(tp[1] as Vector2) * k.TILE, false]
	var hop := _route(here, str(tp[0]))
	if hop == "": return []
	return [(StoryData.LINKS[here][hop] as Vector2) * k.TILE, true]


func _route(from: String, to: String) -> String:
	if not StoryData.LINKS.has(from): return ""
	var seen := {from: ""}
	var q: Array = [from]
	while not q.is_empty():
		var cur: String = q.pop_front()
		for nx in StoryData.LINKS.get(cur, {}):
			if seen.has(nx): continue
			seen[nx] = cur if cur != from else nx
			if nx == to: return seen[nx]
			q.append(nx)
	return ""


func _draw_arrow() -> void:
	var t := arrow_target()
	if t.is_empty(): return
	var k = story.kingdom
	if not is_instance_valid(k) or not k.is_inside_tree(): return
	var wp: Vector2 = t[0]
	var sp: Vector2 = (k.get_canvas_transform() * wp) / s
	var w := arrow.size.x
	var h := arrow.size.y
	var margin := 46.0
	if w < 200.0 or h < 200.0: return
	var on := Rect2(margin, margin + 40, w - 2 * margin, h - 2 * margin - 80).has_point(sp)
	var ppos: Vector2 = (k.get_canvas_transform() * k.player_pos) / s
	var dist := int(roundf(wp.distance_to(k.player_pos) / k.TILE))
	var tt := 0.0 if _rm() else Time.get_ticks_msec() * 0.001
	var font: Font = load("res://fonts/rajdhani-700.woff2")
	if on:
		if dist <= 2: return
		# On screen: a small bobbing chevron above the spot.
		var y := sp.y - 70.0 - absf(sin(tt * 3.0)) * 6.0
		if bool(t[1]): y = sp.y - 40.0 - absf(sin(tt * 3.0)) * 6.0
		arrow.draw_colored_polygon(PackedVector2Array([Vector2(sp.x - 11, y), Vector2(sp.x + 11, y), Vector2(sp.x, y + 13)]), Color(AfTheme.GOLD, 0.9))
		return
	var dir := (sp - ppos).normalized()
	if dir == Vector2.ZERO: return
	var c := Vector2(w, h) / 2.0
	var half := Vector2(w / 2.0 - margin, h / 2.0 - margin - 30)
	var sc := minf(half.x / maxf(0.001, absf(dir.x)), half.y / maxf(0.001, absf(dir.y)))
	var p := c + dir * sc
	var pulse := 0.5 + 0.5 * sin(tt * 4.0)
	arrow.draw_circle(p, 24.0, Color(AfTheme.SHEET, 0.85))
	arrow.draw_arc(p, 24.0, 0, TAU, 32, Color(AfTheme.GOLD, 0.6 + 0.4 * pulse), 2.5)
	var side := Vector2(-dir.y, dir.x)
	arrow.draw_colored_polygon(PackedVector2Array([p + dir * 16.0, p - dir * 8.0 + side * 10.0, p - dir * 3.0, p - dir * 8.0 - side * 10.0]), AfTheme.GOLD)
	var lbl := "%d" % dist
	var fs := 15
	var sz := font.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var lp := p - dir * 40.0 + Vector2(-sz.x / 2.0, fs * 0.35)
	arrow.draw_string_outline(font, lp, lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(0, 0, 0, 0.8))
	arrow.draw_string(font, lp, lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, AfTheme.GOLD)


# ================================================================ journal
func open_journal() -> void:
	if is_open() and not journal.visible: return
	_fill_journal()
	j_build.visible = story.kingdom != null and is_instance_valid(story.kingdom)
	_hush_banner()
	AfTheme.pop_in(journal, _rm())


func close_journal() -> void:
	AfTheme.pop_out(journal, _rm())
	journal.visible = false if _rm() else journal.visible


func _fill_journal() -> void:
	for i in j_tabs.size(): j_tabs[i].button_pressed = i == j_tab
	for c in j_body.get_children():
		j_body.remove_child(c)
		c.queue_free()
	match j_tab:
		0: _fill_main()
		1: _fill_side()
		2: _fill_chronicle()


func _row(title: String, text: String, state: String) -> void:
	# state: done / current / locked
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(AfTheme.CARD, 0.9 if state == "current" else 0.55)
	sb.border_color = AfTheme.EMBER if state == "current" else Color(AfTheme.LINE, 0.8)
	sb.set_border_width_all(2 if state == "current" else 1)
	sb.corner_radius_top_left = 10; sb.corner_radius_bottom_right = 10
	sb.set_content_margin_all(10)
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	p.add_child(v)
	var mark := "✓  " if state == "done" else ("▶  " if state == "current" else "")
	var t := _label(mark + title, "HeaderLabel" if state == "current" else "", 17 if state == "current" else 16)
	if state == "done": t.add_theme_color_override("font_color", AfTheme.MUTED)
	v.add_child(t)
	if text != "":
		var b := _label(text, "MutedLabel" if state != "current" else "", 15)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(b)
	j_body.add_child(p)


func _section(t: String) -> void:
	var l := _label(t.to_upper(), "MutedLabel", 13)
	l.add_theme_color_override("font_color", AfTheme.GOLD_DARK)
	j_body.add_child(l)


func _fill_main() -> void:
	var o: Dictionary = story.objective()
	var cur := str(o.get("id", ""))
	var last_act := ""
	var reached := true
	for st in StoryData.STEPS:
		var done: bool = story.get_flag(str(st.id))
		var is_cur: bool = str(st.id) == cur
		if not done and not is_cur and not reached: continue
		if str(st.act) != last_act:
			last_act = str(st.act)
			_section(str(StoryData.ACTS.get(last_act, "")))
		if done: _row(str(st.title), "", "done")
		elif is_cur:
			var rec := int(st.get("rec", 0))
			var hint := str(o.get("hint", ""))
			var lv := ("Recommended level %d. Story fights start at full HP." % rec) if rec > 0 else ""
			if str(st.id).begins_with("got_") and story.recruited().size() >= 2: lv += "\nBefore a Warden fight: Attack Order button above, then Suggest order."
			if st.get("boss", false): lv += "\nBoss ahead: set your Attack Order first (Attack Order button above, then Suggest order)."
			_row(str(st.title), str(st.text) + ("\n" + hint if hint != "" else "") + ("\n" + lv if lv != "" else ""), "current")
		elif str(st.act) == "II" and str(o.get("act", "")) == "II":
			_row(str(st.title), str(st.text) + " (any order)", "locked")
		if is_cur and str(st.act) != "II": reached = false
	if cur == "done":
		_section("Epilogue")
		_row("The End", "Emberhold is safe. Thank you for playing! Start a New Game to make other choices.", "current")
	_section("The Kindling Lantern")
	_row("Sparks: %d of 4" % story.sparks(), "Roots %s   Forge %s   Star %s   Tide %s" % [
		"●" if story.get_flag("got_grieve") else "○", "●" if story.get_flag("got_halvard") else "○",
		"●" if story.get_flag("got_corvin") else "○", "●" if story.get_flag("got_ilsabet") else "○"], "locked")


func _fill_side() -> void:
	var list: Array = story.side_quests()
	if list.is_empty():
		_row("No side quests yet", "Look for people in Emberhold with a pale blue !", "locked")
		return
	for q in list:
		var txt: String = q.text + (("   (%s)" % q.progress) if q.progress != "" and not q.done else "")
		_row(q.title, "" if q.done else txt, "done" if q.done else "current")


func _fill_chronicle() -> void:
	_section("Your party")
	for id in ["bramwell"] + StoryData.RECRUITS:
		var c: Dictionary = StoryData.CAST.get(id, {})
		var joined: bool = story.recruited().has(id)
		var loyal: bool = story.get_flag("loyal_" + id)
		var line := "Hero" if id == "bramwell" else ("Not yet found" if not joined else ("Loyal: stands by you" if loyal else "In the party, but not loyal"))
		_row(str(c.get("name", id)) + "  ·  " + str(c.get("title", "")), line, "current" if loyal or id == "bramwell" else ("locked" if not joined else "done"))
	_section("Choices you made")
	var ch: Array = story.chronicle()
	if ch.is_empty():
		_row("None yet", "Big decisions are written here as you make them.", "locked")
	for e in ch:
		_row(str(e.get("text", "")), str(e.get("act", "")), "done")


# ================================================================ toasts / tips
func toast(t: String) -> void:
	_toasts.append(t)


func _show_next_toast() -> void:
	toast_label.text = str(_toasts.pop_front())
	_toast_t = 2.6
	_layout()
	AfTheme.pop_in(toast_panel, _rm())


func tip(id: String) -> void:
	if not TIPS.has(id): return
	var seen: Array = story.vars.get("tips", [])
	if seen.has(id): return
	seen.append(id)
	story.vars["tips"] = seen
	story.save_state()
	tip_title.text = "Tip  ·  " + str(TIPS[id][0])
	tip_text.text = str(TIPS[id][1])
	_tip_t = 7.0
	AfTheme.pop_in(tip_panel, _rm())


# ================================================================ cards
func _card_clear() -> void:
	for c in card_box.get_children():
		card_box.remove_child(c)
		c.queue_free()


func _overlay_in(alpha: float) -> void:
	_hush_banner()
	overlay.visible = true
	var tw := overlay.create_tween()
	tw.tween_property(overlay, "color:a", alpha, 0.25)


func _overlay_out() -> void:
	var tw := overlay.create_tween()
	tw.tween_property(overlay, "color:a", 0.0, 0.3)
	tw.tween_callback(func(): overlay.visible = false)


## Wait for secs, or until the player taps (after a short minimum).
func _hold(secs: float, min_secs: float = 0.6) -> void:
	_tap = false
	var t := 0.0
	if fast: secs = 0.05
	while t < secs:
		await get_tree().process_frame
		t += get_process_delta_time()
		if _tap and t > min_secs: break
	_tap = false


func act_card(title: String) -> void:
	_blocking = true
	_overlay_in(0.72)
	_card_clear()
	card.self_modulate.a = 0.0 # title only, no frame
	var parts := title.split("  ·  ")
	var a := _label(parts[0].to_upper(), "MutedLabel", 18)
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	a.add_theme_color_override("font_color", AfTheme.EMBER_LIGHT)
	card_box.add_child(a)
	var orn := KingdomView.Ornament.new()
	orn.custom_minimum_size = Vector2(0, 16)
	card_box.add_child(orn)
	var b := _label(parts[1] if parts.size() > 1 else parts[0], "HeaderLabel", 40)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_box.add_child(b)
	card.reset_size()
	AfTheme.pop_in(card, _rm())
	await _hold(2.6)
	AfTheme.pop_out(card, _rm())
	_overlay_out()
	await get_tree().create_timer(0.3).timeout
	card.visible = false
	card.self_modulate.a = 1.0
	_blocking = false


func fanfare(id: String) -> void:
	_blocking = true
	_overlay_in(0.6)
	_card_clear()
	var c: Dictionary = StoryData.CAST.get(id, {})
	var top := _label("A NEW WARDEN JOINS", "MutedLabel", 15)
	top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_theme_color_override("font_color", AfTheme.EMBER_LIGHT)
	card_box.add_child(top)
	var img := TextureRect.new()
	img.texture = load("res://assets/af/heroes/%s.png" % id)
	img.custom_minimum_size = Vector2(0, 170)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card_box.add_child(img)
	var n := _label(str(c.get("name", id)) + " joins the party!", "HeaderLabel", 30)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_box.add_child(n)
	var t := _label(str(c.get("title", "")), "FlavorLabel", 21)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_box.add_child(t)
	var hint := _label("Party: %d keepers  ·  set the Attack Order in Build" % story.recruited().size(), "MutedLabel", 14)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_box.add_child(hint)
	card.reset_size()
	AfTheme.pop_in(card, _rm())
	if not _rm():
		img.pivot_offset = Vector2(card.size.x / 2.0, 85)
		img.scale = Vector2(0.6, 0.6)
		img.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(img, "scale", Vector2.ONE, 0.45)
	await _hold(2.8)
	AfTheme.pop_out(card, _rm())
	_overlay_out()
	await get_tree().create_timer(0.3).timeout
	card.visible = false
	_blocking = false


## Battle lessons before the first Warden fight (shown once each, tap to continue).
const LESSONS := {
	"order": ["How battles work  ·  1 of 2", "Attack Order",
		"Every turn your party attacks one after another, in the Attack Order: first slot first, the rest a beat behind.\nSet it up from Quests > Attack Order (Build), or just tap Suggest order there and it lines the party up for you. Fast hitters early, heavy hitters right after."],
	"boss": ["Boss ahead  ·  Kindling Night", "Set your Attack Order",
		"Bosses hit hard and punish a messy order. Before you meet the king on the plaza, open Quests > Attack Order and tap Suggest order (or line up fast hitters first yourself).\nNow that all five keepers are with you, every slot matters."],
	"final": ["Boss ahead  ·  The Sunken Bastion", "Check your Attack Order again",
		"The Bastion ends in two boss fights back to back, and only the Lantern's rally heals you between them. Your party has grown since the plaza: open Quests > Attack Order and tap Suggest order before you go down."],
	"spark": ["How battles work  ·  2 of 2", "Sparks",
		"When hits from two different keepers land on the same foe at almost the same moment, they Spark: +50% damage and more BB gauge.\nTap a foe as the turn starts to focus everyone on it, or let the party pick the weakest one.\n(The Lantern's sparks are different: those are the four Wardfires you're bringing home.)"],
}

## Little diagrams for the lessons: the party's Attack Order, and two hits landing together.
class LessonArt extends Control:
	var kind := "order"
	var party: Array = []
	var _tex := {}
	var t0 := 0
	func _process(_d: float) -> void: queue_redraw()
	func _draw() -> void:
		var f: Font = load("res://fonts/rajdhani-700.woff2")
		var tt := (Time.get_ticks_msec() - t0) * 0.001
		if kind == "order":
			var n := maxi(1, party.size())
			var gap := minf(120.0, size.x / float(n))
			var x0 := size.x / 2.0 - gap * float(n - 1) / 2.0
			for i in n:
				var id: String = str(party[i])
				if not _tex.has(id): _tex[id] = load("res://assets/af/heroes/%s.png" % id)
				var tx: Texture2D = _tex[id]
				var c := Vector2(x0 + gap * i, 62)
				var hop := maxf(0.0, sin(tt * 3.0 - i * 0.9)) * 8.0
				if tx:
					var h := 96.0
					var w := h * float(tx.get_width()) / float(tx.get_height())
					draw_texture_rect(tx, Rect2(c.x - w / 2.0, c.y - h / 2.0 - hop, w, h), false)
				draw_circle(c + Vector2(-30, 40), 13, AfTheme.EMBER)
				var s := str(i + 1)
				var sz := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
				draw_string(f, c + Vector2(-30 - sz.x / 2.0, 46), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, AfTheme.INK)
				if i < n - 1:
					var a := c + Vector2(gap * 0.38, 0)
					draw_line(a, a + Vector2(gap * 0.24, 0), AfTheme.GOLD, 3.0)
					draw_colored_polygon(PackedVector2Array([a + Vector2(gap * 0.24 + 8, 0), a + Vector2(gap * 0.24, -6), a + Vector2(gap * 0.24, 6)]), AfTheme.GOLD)
		else:
			var foe := Vector2(size.x / 2.0, 62)
			var cyc := fmod(tt, 2.2) / 2.2
			draw_circle(foe, 30, Color(AfTheme.CORAL, 0.25))
			draw_circle(foe, 18, AfTheme.CORAL)
			for side in [-1.0, 1.0]:
				var from := foe + Vector2(side * size.x * 0.36, -22)
				var k := clampf(cyc / 0.45, 0.0, 1.0)
				var p: Vector2 = from.lerp(foe, k)
				draw_line(from, p, Color(AfTheme.GOLD, 0.5), 3.0)
				draw_circle(p, 6, AfTheme.GOLD)
			if cyc > 0.45 and cyc < 0.85:
				var a := 1.0 - (cyc - 0.45) / 0.4
				for r in 3: draw_arc(foe, 26.0 + r * 10.0 + (cyc - 0.45) * 60.0, 0, TAU, 32, Color(1, 0.9, 0.5, a * 0.8), 3.0)
				var s := "SPARK!  x1.5"
				var sz := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 26)
				draw_string(f, foe + Vector2(-sz.x / 2.0, -40), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(AfTheme.GOLD, a))


func lesson(id: String) -> void:
	if not LESSONS.has(id): return
	var seen: Array = story.vars.get("tips", [])
	if seen.has("lesson_" + id): return
	seen.append("lesson_" + id)
	story.vars["tips"] = seen
	story.save_state()
	var L: Array = LESSONS[id]
	_blocking = true
	_overlay_in(0.7)
	_card_clear()
	var top := _label(str(L[0]).to_upper(), "MutedLabel", 15)
	top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_theme_color_override("font_color", AfTheme.EMBER_LIGHT)
	card_box.add_child(top)
	var art := LessonArt.new()
	art.kind = "spark" if id == "spark" else "order"
	art.party = story.recruited()
	art.t0 = Time.get_ticks_msec()
	art.custom_minimum_size = Vector2(0, 130)
	card_box.add_child(art)
	var title := _label(str(L[1]), "HeaderLabel", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_box.add_child(title)
	var body := _label(str(L[2]), "", 18)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_box.add_child(body)
	want_build = false
	var to_build: bool = id in ["boss", "final"] and story.kingdom != null and is_instance_valid(story.kingdom)
	if to_build: # boss lessons: one tap straight into Build, where Suggest order lives
		var bb := Button.new()
		bb.text = "Open Attack Order"
		bb.custom_minimum_size = Vector2(220, 46)
		bb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		bb.pressed.connect(func(): want_build = true; _tap = true)
		AfTheme.add_press_juice(bb, _rm)
		card_box.add_child(bb)
	var cont := _label("Tap anywhere else for later" if to_build else "Tap to continue", "MutedLabel", 14)
	cont.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_box.add_child(cont)
	card.reset_size()
	AfTheme.pop_in(card, _rm())
	await _hold(40.0, 1.2)
	AfTheme.pop_out(card, _rm())
	_overlay_out()
	await get_tree().create_timer(0.3).timeout
	card.visible = false
	_blocking = false


class SparkRow extends Control:
	var lit: Array = []
	var t0 := 0
	func _process(_d: float) -> void: queue_redraw()
	func _draw() -> void:
		var cols := [Color("#7fd36b"), Color("#fff2d6"), Color("#7fb6ff"), Color("#5fe0c8")]
		var names := ["Roots", "Forge", "Star", "Tide"]
		var f: Font = load("res://fonts/rajdhani-700.woff2")
		var n := 4
		var gap := size.x / float(n)
		var tt := (Time.get_ticks_msec() - t0) * 0.001
		for i in n:
			var c := Vector2(gap * (i + 0.5), 30)
			var on: bool = lit[i]
			var g := 0.5 + 0.5 * sin(tt * 4.0 + i)
			if on:
				draw_circle(c, 26.0 + 3.0 * g, Color(cols[i], 0.18))
				draw_circle(c, 15.0, cols[i])
				draw_circle(c, 7.0, Color(1, 1, 1, 0.85))
			else:
				draw_arc(c, 15.0, 0, TAU, 28, Color(AfTheme.LINE, 0.9), 2.0)
			var sz := f.get_string_size(names[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
			draw_string(f, c + Vector2(-sz.x / 2.0, 46), names[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, AfTheme.INK if on else AfTheme.MUTED)


func spark_card() -> void:
	_blocking = true
	_overlay_in(0.5)
	_card_clear()
	var h := _label("THE KINDLING LANTERN", "HeaderLabel", 24)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_box.add_child(h)
	var row := SparkRow.new()
	row.custom_minimum_size = Vector2(0, 80)
	row.t0 = Time.get_ticks_msec()
	for r in StoryData.RECRUITS: row.lit.append(story.get_flag("got_" + r))
	card_box.add_child(row)
	var n: int = story.sparks()
	var sub := _label("%d of 4 sparks" % n if n < 4 else "All four sparks! Take them home to the king.", "FlavorLabel", 21)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_box.add_child(sub)
	card.reset_size()
	AfTheme.pop_in(card, _rm())
	await _hold(2.4)
	AfTheme.pop_out(card, _rm())
	_overlay_out()
	await get_tree().create_timer(0.3).timeout
	card.visible = false
	_blocking = false


## A short flash before a story fight changes scene.
func battle_intro(b: Dictionary) -> void:
	_blocking = true
	var boss: bool = bool(b.get("boss", false))
	_overlay_in(0.55)
	_card_clear()
	var t := _label("BOSS BATTLE" if boss else "STORY BATTLE", "MutedLabel", 16)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_color_override("font_color", AfTheme.CORAL if boss else AfTheme.EMBER_LIGHT)
	card_box.add_child(t)
	var n := _label(str(b.get("banner", "")), "HeaderLabel", 32)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_box.add_child(n)
	card.reset_size()
	AfTheme.pop_in(card, _rm())
	await get_tree().create_timer(0.05 if fast else 1.1).timeout
	card.visible = false
	overlay.visible = false
	overlay.color.a = 0.0
	_blocking = false


## Epilogue cards, then THE END. Tap (or Continue) to go on.
func epilogue(cards: Array) -> void:
	_blocking = true
	_overlay_in(0.88)
	for i in cards.size() + 1:
		_card_clear()
		var last := i == cards.size()
		var title: String = "Thank you for playing" if last else str(cards[i][0])
		var text: String = "Airron's Quest  ·  The Tenth Kindling\n\nStory by Airron Kennedy, built on the Airron's Fall world.\nKeep exploring Cinderreach, or start a New Game to choose differently." if last else str(cards[i][1])
		var top := _label("THE END" if last else ("EPILOGUE  ·  %d / %d" % [i + 1, cards.size()]), "MutedLabel", 14)
		top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		top.add_theme_color_override("font_color", AfTheme.EMBER_LIGHT)
		card_box.add_child(top)
		var h := _label(title, "HeaderLabel", 30 if (i == 0 or last) else 26)
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card_box.add_child(h)
		var b := _label(text, "FlavorLabel", 21)
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card_box.add_child(b)
		var more := _label("Tap to continue", "MutedLabel", 13)
		more.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_box.add_child(more)
		card.reset_size()
		AfTheme.pop_in(card, _rm())
		await _hold(60.0, 0.8)
	AfTheme.pop_out(card, _rm())
	_overlay_out()
	await get_tree().create_timer(0.3).timeout
	card.visible = false
	_blocking = false
