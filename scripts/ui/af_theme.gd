class_name AfTheme
extends RefCounted
## Airron's Fall UI look as a reusable Godot Theme: the warm ash-brown panels, cream text, ember-orange primary,
## gold accent, carved panel frame and the Cinzel / Rajdhani / Cormorant fonts that Airron's Fall ships.
## Use it anywhere: `control.theme = AfTheme.get_theme()` (or load res://themes/airrons_fall.tres).
## Type variations: HeaderLabel, MutedLabel, FlavorLabel, PrimaryButton, FramedPanel, DangerBar, ToastPanel.

# Palette (same values as the Airron's Fall CSS port in scripts/game.gd)
const INK := Color("#ece3cf")
const MUTED := Color("#a89c88")
const SHEET := Color("#241f19")
const CARD := Color("#2f2820")
const LINE := Color("#4d4033")
const EMBER := Color("#e8763a")
const EMBER_LIGHT := Color("#f0a066")
const EMBER_DARK := Color("#4a3020")
const GOLD := Color("#ead266")
const GOLD_DARK := Color("#c8a94a")
const CORAL := Color("#d2463c")
const GOOD := Color("#23874d")

const THEME_PATH := "res://themes/airrons_fall.tres"
static var _cached: Theme = null


static func get_theme() -> Theme:
	if _cached == null:
		_cached = load(THEME_PATH) as Theme if ResourceLoader.exists(THEME_PATH) else null
		if _cached == null:
			_cached = build()
	return _cached


static func _box(fill: Color, border: Color, bw: int, rad: int, shadow: int = 0, pad: int = 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(rad)
	sb.corner_detail = 10
	sb.anti_aliasing = true
	sb.set_content_margin_all(pad)
	if shadow > 0:
		sb.shadow_color = Color(0, 0, 0, 0.45)
		sb.shadow_size = shadow
		sb.shadow_offset = Vector2(0, shadow * 0.4)
	return sb


static func build() -> Theme:
	var t := Theme.new()
	var body: FontFile = load("res://fonts/rajdhani-600.woff2")
	var bold: FontFile = load("res://fonts/rajdhani-700.woff2")
	var title: FontFile = load("res://fonts/cinzel-700.woff2")
	var flavor: FontFile = load("res://fonts/cormorant-500-italic.woff2")
	t.default_font = body
	t.default_font_size = 18
	# Panels: flat ash sheet, and the carved Airron's Fall frame (ui_panel_9) for dialogs.
	t.set_stylebox("panel", "Panel", _box(Color(SHEET, 0.96), LINE, 2, 14, 10))
	t.set_stylebox("panel", "PanelContainer", _box(Color(SHEET, 0.96), LINE, 2, 14, 10, 14))
	var frame := StyleBoxTexture.new()
	frame.texture = load("res://assets/af/gen/ui_panel_9.png")
	frame.set_texture_margin_all(28)
	frame.set_content_margin_all(22)
	t.set_type_variation("FramedPanel", "PanelContainer")
	t.set_stylebox("panel", "FramedPanel", frame)
	t.set_type_variation("ToastPanel", "PanelContainer")
	t.set_stylebox("panel", "ToastPanel", _box(Color(SHEET, 0.9), GOLD_DARK, 2, 22, 8, 10))
	# Labels
	t.set_color("font_color", "Label", INK)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.55))
	t.set_constant("shadow_offset_y", "Label", 2)
	t.set_type_variation("HeaderLabel", "Label")
	t.set_font("font", "HeaderLabel", title)
	t.set_font_size("font_size", "HeaderLabel", 24)
	t.set_color("font_color", "HeaderLabel", GOLD)
	t.set_type_variation("MutedLabel", "Label")
	t.set_color("font_color", "MutedLabel", MUTED)
	t.set_font_size("font_size", "MutedLabel", 16)
	t.set_type_variation("FlavorLabel", "Label")
	t.set_font("font", "FlavorLabel", flavor)
	t.set_font_size("font_size", "FlavorLabel", 21)
	t.set_color("font_color", "FlavorLabel", INK)
	# Buttons: soft card pill, ember border on hover, gold focus ring (keyboard / pad)
	t.set_font("font", "Button", bold)
	t.set_font_size("font_size", "Button", 19)
	t.set_stylebox("normal", "Button", _box(CARD, LINE, 2, 22, 4, 12))
	t.set_stylebox("hover", "Button", _box(CARD.lightened(0.06), EMBER, 2, 22, 6, 12))
	t.set_stylebox("pressed", "Button", _box(EMBER_DARK, EMBER_LIGHT, 2, 22, 2, 12))
	t.set_stylebox("disabled", "Button", _box(Color(CARD, 0.6), Color(LINE, 0.6), 2, 22, 0, 12))
	t.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), GOLD, 2, 22, 0, 12))
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", EMBER_LIGHT)
	t.set_color("font_disabled_color", "Button", MUTED)
	t.set_type_variation("PrimaryButton", "Button")
	t.set_stylebox("normal", "PrimaryButton", _box(EMBER, EMBER_LIGHT, 2, 22, 6, 12))
	t.set_stylebox("hover", "PrimaryButton", _box(EMBER.lightened(0.08), GOLD, 2, 22, 8, 12))
	t.set_stylebox("pressed", "PrimaryButton", _box(EMBER.darkened(0.15), GOLD, 2, 22, 2, 12))
	t.set_color("font_color", "PrimaryButton", Color.WHITE)
	t.set_color("font_hover_color", "PrimaryButton", Color.WHITE)
	t.set_color("font_pressed_color", "PrimaryButton", GOLD)
	# Bars: danger meter (ember fill on an ash track)
	t.set_stylebox("background", "ProgressBar", _box(CARD, LINE, 2, 9, 0, 0))
	t.set_stylebox("fill", "ProgressBar", _box(GOLD_DARK, GOLD, 1, 9, 0, 0))
	t.set_type_variation("DangerBar", "ProgressBar")
	t.set_stylebox("fill", "DangerBar", _box(EMBER, GOLD, 1, 9, 0, 0))
	t.set_color("font_color", "ProgressBar", INK)
	return t


## Juicy press: scale the button down while held, spring back on release. Skipped when reduced motion is on.
static func add_press_juice(b: BaseButton, reduced_motion: Callable) -> void:
	b.resized.connect(func(): b.pivot_offset = b.size / 2.0)
	b.button_down.connect(func():
		if reduced_motion.call(): return
		b.create_tween().tween_property(b, "scale", Vector2(0.92, 0.92), 0.06))
	b.button_up.connect(func():
		if reduced_motion.call(): b.scale = Vector2.ONE; return
		b.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(b, "scale", Vector2.ONE, 0.18))


## Tweened open: fade + small scale pop (fade only when reduced motion is on).
static func pop_in(c: Control, reduced: bool) -> void:
	c.visible = true
	c.pivot_offset = c.size / 2.0
	c.modulate.a = 0.0
	c.scale = Vector2.ONE if reduced else Vector2(0.9, 0.9)
	var tw := c.create_tween().set_parallel(true)
	tw.tween_property(c, "modulate:a", 1.0, 0.12 if reduced else 0.18)
	if not reduced:
		tw.tween_property(c, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func pop_out(c: Control, reduced: bool) -> void:
	if not c.visible: return
	c.pivot_offset = c.size / 2.0
	var tw := c.create_tween().set_parallel(true)
	tw.tween_property(c, "modulate:a", 0.0, 0.1 if reduced else 0.14)
	if not reduced:
		tw.tween_property(c, "scale", Vector2(0.94, 0.94), 0.14)
	tw.chain().tween_callback(func(): c.visible = false)
