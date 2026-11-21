extends Node2D
## Emberhold: the starting kingdom town, its castle, one house and the Cinderreach overworld.
## Move: WASD / arrows, gamepad left stick / d-pad, click to walk, or touch anywhere on a phone for an Airron's
## Fall floating joystick (KingdomTouch, real multitouch). Interact: E / Space / Enter, gamepad A, the context
## Use button (pops in when something is in reach), or a quick tap on the person / door. Esc / B / Start: menu.
## M / gamepad Back / tap the minimap: full map screen.
## Random encounters only happen on the overworld: the danger meter fills by distance walked (scaled per region,
## see KingdomMaps.REGIONS) and, when full, calls Encounters.start_random_battle(region_id) (scripts/encounters.gd).

const TILE := 64.0
const SPEED := 240.0
const SAVE_PATH := "user://kingdom.cfg"
const BAG_PATH := "user://airrons_quest.cfg" # the main game's save; the shop edits only its [inv] bag
const PLAYER_HERO := "bramwell"
const INN_COST := 10
const SLOT_ICONS := {"weapon": "greatsword-slash", "armor": "iron-bark", "gloves": "heavy-hits", "amulet": "starglass-rosary"}
const FALLBACK_ITEMS := {
	"oak_maul": {"name": "Oak Maul", "slot": "weapon", "blurb": "Heavy wooden heft", "atk": 3, "hp": 12},
	"trail_vest": {"name": "Trail Vest", "slot": "armor", "blurb": "Light travel padding", "def": 3, "speed": 2, "hp": 8},
	"grip_wraps": {"name": "Grip Wraps", "slot": "gloves", "blurb": "A firmer hold on the strike", "atk": 3, "crit": 2},
	"ember_charm": {"name": "Ember Charm", "slot": "amulet", "blurb": "A warm spark at the throat", "atk": 2, "crit": 3},
}

# ---- state
var map: Dictionary = {}
var rows: Array = []
var W := 0
var H := 0
var player_pos := Vector2.ZERO
var usables: Array = []   # {kind: spot|npc, pos, name, prompt, ...}
var blocks: Array = []    # Rect2 prop footprints
var near: Dictionary = {}
var tap_target: Variant = null
var tap_use: Dictionary = {}
var cur_region := ""
var cur_zone := ""
var meter := 0.0
var gold := 120
var party_hp := 80
var party_hp_max := 80
var bag: Array = []
var item_defs: Dictionary = {}
var reduced_motion := false
## Graphics quality: "high" = full tilt-shift blur + bloom + god rays; "phone" = a lighter pass (5 blur taps,
## half bloom / rays; the default on touch devices and small screens); "low" = those off.
const GFX_LEVELS := ["high", "phone", "low"]
var gfx_level := "high"
var gfx_low := false # kept for callers of set_gfx_low(); true when gfx_level == "low"
var gfx_btn: Button
var busy := false
var t_now := 0.0
var title_font: Font
var shop_mode := "buy"
var _cam_ahead := Vector2.ZERO
var _prev_emulate := false
var allow_warps := true # tests switch exits off while walking scripted paths

# ---- nodes
var modulate_node: CanvasModulate
var ground: KingdomView.Ground
var details_static: KingdomView.Details
var details_sway: KingdomView.Details
var markers: KingdomView.Markers
var fg: KingdomView.Foreground
var life: KingdomView.Life
var smoke: Node2D
var post: ColorRect
var grade := {}        # current (blended) look
var grade_target := {}
var dialog_portrait: TextureRect
var dialog_portrait_box: PanelContainer
var _type_tw: Tween
var ysort: Node2D
var player: KingdomView.Actor
var torch: PointLight2D
var cam: Camera2D
var particles: CPUParticles2D
var ui: Control
var loc_card: PanelContainer
var loc_name: Label
var loc_sub: Label
var hp_text: Label
var hp_bar: ProgressBar
var gold_label: Label
var danger_row: HBoxContainer
var danger_bar: ProgressBar
var minimap: KingdomView.Minimap
var menu_btn: Button
var stick: KingdomView.FloatStick
var touch := KingdomTouch.new()
var touch_ui := false   # phone / tablet: floating stick, bigger Use button, no key glyphs
var last_pad := false   # last input came from a gamepad (shows "A" on the Use button)
var face_dir := Vector2.DOWN
var use_btn: KingdomView.UseButton
var map_screen: KingdomView.MapScreen
var prompt_layer: KingdomView.PromptLayer
var insets := Vector4.ZERO # safe-area insets in ui units: top, right, bottom, left
var banner: VBoxContainer
var banner_title: Label
var banner_sub: Label
var toast: PanelContainer
var toast_label: Label
var dialog: PanelContainer
var dialog_name: Label
var dialog_text: Label
var shop: PanelContainer
var shop_list: VBoxContainer
var shop_gold: Label
var shop_tabs: Array = []
var inn: PanelContainer
var inn_text: Label
var menu: PanelContainer
var rm_btn: Button
var iris: ColorRect
var _light_tex: GradientTexture2D


func _ready() -> void:
	# Real multitouch: touches are routed by KingdomTouch per finger (stick + Use at once), not turned
	# into a single emulated mouse. Mouse emulation is only switched on while a menu / shop / dialog is
	# open, so their regular buttons and lists work with a finger. Restored on exit.
	_prev_emulate = Input.emulate_mouse_from_touch
	Input.emulate_mouse_from_touch = false
	touch_ui = is_touch_device() or DisplayServer.is_touchscreen_available()
	touch.hit_ui = _ui_hit
	title_font = load("res://fonts/cinzel-700.woff2")
	_load_items()
	_load_save()
	_parse_params()
	_build_world_nodes()
	_build_ui()
	_apply_motion()
	if not _gfx_saved: gfx_level = "phone" if (is_touch_device() or _small_screen()) else "high"
	_read_insets()
	_apply_quality()
	var e := _enc()
	if e:
		e.random_battle_finished.connect(_on_battle_finished)
	var start_map: String = _saved.get("map", "town")
	var start_at: Variant = _saved.get("pos", null)
	load_map(start_map, start_at)
	_show_banner(map.name, map.sub)
	_iris_open()


func _exit_tree() -> void:
	Input.emulate_mouse_from_touch = _prev_emulate


func _enc() -> Node:
	return get_node_or_null("/root/Encounters")


# ================================================================ data / save
var _saved: Dictionary = {}

func _load_items() -> void:
	# Reuse the main game's item data (ITEM_DEFS in scripts/game.gd) so the shop sells real gear.
	var gs: Script = load("res://scripts/game.gd")
	if gs:
		var g = gs.new()
		if g and "ITEM_DEFS" in g:
			item_defs = (g.ITEM_DEFS as Dictionary).duplicate(true)
		if g:
			g.free()
	if item_defs.is_empty():
		item_defs = FALLBACK_ITEMS.duplicate(true)


func price_of(iid: String) -> int:
	var it: Dictionary = item_defs.get(iid, {})
	var pts := 0.0
	for key in ["atk", "def", "armor", "speed", "crit", "mana"]:
		pts += float(it.get(key, 0)) * 4.0
	pts += float(it.get("hp", 0)) * 1.2
	return int(maxf(10.0, roundf(pts / 5.0) * 5.0))


func _load_save() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) == OK:
		gold = int(cf.get_value("kingdom", "gold", gold))
		party_hp_max = int(cf.get_value("kingdom", "hp_max", party_hp_max))
		party_hp = int(cf.get_value("kingdom", "hp", party_hp_max))
		meter = float(cf.get_value("kingdom", "meter", 0.0))
		reduced_motion = bool(cf.get_value("kingdom", "reduced_motion", false))
		if cf.has_section_key("kingdom", "gfx"):
			gfx_level = str(cf.get_value("kingdom", "gfx", "high"))
			_gfx_saved = true
		elif cf.has_section_key("kingdom", "gfx_low"):
			gfx_level = "low" if bool(cf.get_value("kingdom", "gfx_low", false)) else "high"
			_gfx_saved = true
		_saved["map"] = str(cf.get_value("kingdom", "map", "town"))
		var p = cf.get_value("kingdom", "pos", Vector2.INF) # default: a fresh save has no position yet
		if p is Vector2 and p != Vector2.INF:
			_saved["pos"] = p
	bag = []
	var bf := ConfigFile.new()
	if bf.load(BAG_PATH) == OK and bf.has_section_key("inv", "bag"):
		for iid in str(bf.get_value("inv", "bag", "")).split(",", false):
			bag.append(iid)
	else:
		var gs: Script = load("res://scripts/game.gd")
		var sb = gs.get_script_constant_map().get("STARTER_BAG", []) if gs else []
		bag = Array(sb).duplicate()


func save_game() -> void:
	var cf := ConfigFile.new()
	cf.load(SAVE_PATH) # keep other sections (class / subclass EXP from game.gd)
	cf.set_value("kingdom", "gold", gold)
	cf.set_value("kingdom", "hp", party_hp)
	cf.set_value("kingdom", "hp_max", party_hp_max)
	cf.set_value("kingdom", "meter", meter)
	cf.set_value("kingdom", "reduced_motion", reduced_motion)
	if _gfx_saved:
		cf.set_value("kingdom", "gfx", gfx_level)
		cf.set_value("kingdom", "gfx_low", gfx_level == "low")
	cf.set_value("kingdom", "map", map.get("id", "town"))
	cf.set_value("kingdom", "pos", player_pos / TILE)
	cf.save(SAVE_PATH)
	# Shared bag: merge into the main save so Build / Inventory see what was bought or sold.
	var bf := ConfigFile.new()
	bf.load(BAG_PATH)
	bf.set_value("inv", "bag", ",".join(bag))
	bf.save(BAG_PATH)


func _parse_params() -> void:
	var args: Array = Array(OS.get_cmdline_user_args())
	if OS.has_feature("web"):
		var q = JavaScriptBridge.eval("location.search", true)
		if q is String:
			args.append_array(Array((q as String).trim_prefix("?").split("&", false)))
	for a in args:
		var s: String = str(a).trim_prefix("--")
		if s.begins_with("gfx="):
			gfx_level = s.substr(4) if GFX_LEVELS.has(s.substr(4)) else "high"; _gfx_saved = true
		elif s.begins_with("calm") or s.begins_with("reduced_motion"):
			reduced_motion = not s.ends_with("=0")
		elif s.begins_with("kmap="):
			_saved["map"] = s.substr(5)
			_saved.erase("pos")


# ================================================================ map
func load_map(id: String, at: Variant = null) -> void:
	map = KingdomMaps.get_map(id)
	if map.is_empty():
		map = KingdomMaps.get_map("town")
	rows = map.rows
	H = rows.size()
	W = (rows[0] as String).length()
	for ch in ysort.get_children():
		if ch != player:
			ch.queue_free()
	for l in get_tree().get_nodes_in_group("k_light"):
		l.queue_free()
	blocks.clear()
	usables.clear()
	for ch3 in smoke.get_children():
		ch3.queue_free()
	var trees := ["tree_oak", "tree_pine", "tree_willow"] if map.id == "overworld" else ["tree_oak", "tree_pine", "tree_oak"]
	for r in H:
		for c in W:
			var ch2 := ch_at(c, r)
			var hsh := _hash(c, r)
			if ch2 == "T":
				_add_prop({"img": trees[hsh % 3], "x": c + 0.5 + float(hsh % 7 - 3) * 0.04, "y": r + 0.85, "s": 1.8 + float(hsh % 5) * 0.08, "flip": hsh % 2 == 0})
			elif ch2 == "P":
				_add_prop({"img": "pillar", "x": c + 0.5, "y": r + 0.9, "s": 1.5})
	for p in map.props:
		_add_prop(p)
	_scatter_details()
	fg.items.clear()
	for f in map.get("fg", []):
		fg.items.append({"tex": KingdomView.tex(str(f.img)), "pos": Vector2(f.x, f.y) * TILE, "s": float(f.get("s", 3.0)), "dark": float(f.get("dark", 0.22)), "par": float(f.get("par", 0.35))})
	life.birds_on = bool(map.get("birds", false))
	for n in map.npcs:
		var a := KingdomView.Actor.new()
		a.k = self
		a.hero = n.hero
		a.position = Vector2(n.x, n.y) * TILE
		a.facing = -1.0 if n.x > W / 2.0 else 1.0
		ysort.add_child(a)
		usables.append({"kind": "npc", "pos": a.position, "name": str(n.text).get_slice(":", 0), "prompt": "Talk", "action": "text", "text": n.text, "node": a})
	for s in map.spots:
		var d: Dictionary = s.duplicate()
		d["kind"] = "spot"
		d["pos"] = Vector2(s.x, s.y) * TILE
		usables.append(d)
	var start: Vector2 = at if at is Vector2 else map.start
	player_pos = start * TILE
	if blocked_at(player_pos):
		player_pos = (map.start as Vector2) * TILE
	player.position = player_pos
	grade_target = KingdomMaps.GRADES.get(map.id, KingdomMaps.GRADES.town).duplicate()
	grade = grade_target.duplicate()
	_apply_grade()
	ground.rebuild()
	_setup_particles(str(map.particles))
	var pad := int(TILE * 2) if bool(map.encounters) else 0 # a little sea around the island; walls end the town
	cam.limit_left = -pad
	cam.limit_top = -pad
	cam.limit_right = int(W * TILE) + pad
	cam.limit_bottom = int(H * TILE) + pad
	cam.position = player_pos
	cam.reset_smoothing()
	cur_region = ""
	cur_zone = ""
	danger_row.visible = bool(map.encounters)
	minimap.rebuild()
	_refresh_hud()
	var story := get_node_or_null("/root/Story") # story NPCs, quest markers (scripts/story/story.gd)
	if story: story.on_map_loaded(self)


func _add_prop(p: Dictionary) -> void:
	var pr := KingdomView.Prop.new()
	pr.k = self
	pr.kind = str(p.img)
	pr.s = float(p.get("s", 1.0))
	pr.flip = bool(p.get("flip", false))
	pr.ph = int(p.x * 3 + p.y * 7) % 7
	pr.position = Vector2(p.x, p.y) * TILE
	ysort.add_child(pr)
	if not p.has("s") and KingdomView.KDEFS.has(pr.kind):
		pr.s = KingdomView.SPRITE_SCALE
	var kd: Dictionary = KingdomView.KDEFS.get(pr.kind, {})
	if not kd.is_empty():
		if bool(kd.get("sway", false)):
			pr.material = KingdomView.sway_mat
		var fp := KingdomView.footprint(pr.kind, pr.position, pr.s)
		if fp.size.x > 0.0:
			blocks.append(fp)
		var tx := KingdomView.tex(pr.kind)
		if kd.has("light") and tx:
			_add_light(pr.position + Vector2(0, tx.get_height() * pr.s * (kd.light as Vector2).y), 1.6 if pr.kind != "window_stained" else 3.0,
				Color(1.0, 0.62, 0.3) if pr.kind != "window_stained" else Color(1.0, 0.75, 0.45))
		if kd.has("chim") and tx:
			var cp: Vector2 = kd.chim
			_add_smoke(pr.position + Vector2((cp.x - 0.5) * tx.get_width() * pr.s * (-1.0 if pr.flip else 1.0), -tx.get_height() * pr.s * (1.0 - cp.y)))
		return
	var d: Dictionary = KingdomView.DEFS.get(pr.kind, {})
	if pr.kind == "fire":
		pr.animated = true
	if not d.is_empty() and float(d.bw) > 0.0:
		var bw: float = float(d.bw) * pr.s
		var bh: float = float(d.bh) * pr.s
		blocks.append(Rect2(pr.position.x - bw / 2.0, pr.position.y - bh * 0.7, bw, bh))
	elif pr.kind in ["throne", "shrine"] or pr.kind.begins_with("statue:"):
		blocks.append(Rect2(pr.position.x - 40, pr.position.y - 20, 80, 24))
	if bool(p.get("light", false)) or pr.kind == "fire":
		_add_light(pr.position + Vector2(0, -30), 2.4, Color(1.0, 0.62, 0.3))


func _add_light(at: Vector2, scale: float, col: Color) -> void:
	var l := PointLight2D.new()
	l.texture = _light_tex
	l.texture_scale = scale
	l.color = col
	l.energy = 0.5
	l.position = at
	l.add_to_group("k_light")
	add_child(l)


func _add_smoke(at: Vector2) -> void:
	if reduced_motion:
		return
	var sm := CPUParticles2D.new()
	sm.position = at
	sm.amount = 10
	sm.lifetime = 3.2
	sm.preprocess = 3.0
	sm.direction = Vector2(0.25, -1)
	sm.spread = 12.0
	sm.gravity = Vector2(6, -6)
	sm.initial_velocity_min = 14.0
	sm.initial_velocity_max = 22.0
	sm.scale_amount_min = 3.0
	sm.scale_amount_max = 6.0
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.5))
	sc.add_point(Vector2(1, 1.6))
	sm.scale_amount_curve = sc
	var g := Gradient.new()
	g.set_color(0, Color(0.75, 0.72, 0.7, 0.5))
	g.set_color(1, Color(0.6, 0.58, 0.56, 0.0))
	sm.color_ramp = g
	smoke.add_child(sm)


func _hash(c: int, r: int) -> int:
	return absi((c * 73856093) ^ (r * 19349663) ^ 0x5bd1e995) % 1000003


## Terrain id for the ground shader (see shaders/kingdom_ground.gdshader).
func terrain_id(c: int, r: int) -> int:
	var indoor: bool = map.id in ["castle", "house"]
	match ch_at(c, r):
		"~": return 0
		"f", "T": return 2 if map.id == "overworld" else 1
		"^": return 3
		":": return 4
		",": return 7 if indoor else (6 if map.id == "town" else 5)
		"c": return 8
		"P": return 7
		"#": return 9 if indoor else 10
	return 1


## Hand-placed-looking clutter: grass tufts, flowers, pebbles, mushrooms, reeds and lily pads, seeded per tile.
func _scatter_details() -> void:
	details_static.items.clear()
	details_sway.items.clear()
	life.flowers.clear()
	life.glow.clear()
	for dcl in map.get("decals", []):
		details_static.items.append({"tex": KingdomView.tex(str(dcl.img)), "pos": Vector2(dcl.x, dcl.y) * TILE, "s": float(dcl.s), "flip": false})
	if map.id in ["castle", "house"]:
		details_static.queue_redraw()
		details_sway.queue_redraw()
		return
	for r in H:
		for c in W:
			var ch := ch_at(c, r)
			var h := _hash(c, r)
			var roll := h % 100
			var at := Vector2(c + 0.2 + float(h % 61) / 100.0, r + 0.35 + float((h / 61) % 55) / 100.0) * TILE
			var item := ""
			var sway := true
			match ch:
				".":
					if roll < 34: item = "tuft_short" if h % 3 else "tuft_tall"
					elif roll < 46: item = ["flowers_white", "flowers_blue", "flowers_red"][h % 3]
					elif roll < 50: item = "pebbles"; sway = false
				"f":
					if roll < 30: item = "tuft_tall"
					elif roll < 40: item = "mushrooms"; sway = false
					elif roll < 46: item = "bush"
					elif roll < 49: item = "stump"; sway = false
				"^":
					if roll < 26: item = "tuft_short"
					elif roll < 36: item = "pebbles"; sway = false
					elif roll < 40: item = "boulder"; sway = false
				":":
					if roll < 22 and _near_water(c, r): item = "reeds"
				"~":
					if roll < 10 and _near_land(c, r): item = "lilypad"; sway = false
			if item == "":
				continue
			var s := 0.55 + float(h % 4) * 0.06
			if item in ["boulder", "stump"]: s = 0.85
			if item == "bush": s = 1.0
			if item in ["reeds", "lilypad", "mushrooms"]: s = 0.75
			var d := {"tex": KingdomView.tex(item), "pos": at, "s": s, "flip": h % 2 == 0}
			(details_sway if sway else details_static).items.append(d)
			if item.begins_with("flowers") and life.flowers.size() < 10 and h % 3 == 0:
				life.flowers.append(at)
			if ch == "f" and life.glow.size() < 26 and h % 4 == 0:
				life.glow.append(at)
			# a second small tuft for density
			if ch in [".", "f"] and h % 5 < 2:
				details_sway.items.append({"tex": KingdomView.tex("tuft_short"), "pos": at + Vector2(float(h % 23) - 11.0, float(h % 13) - 20.0), "s": 0.5, "flip": h % 3 == 0})
	details_static.queue_redraw()
	details_sway.queue_redraw()


func _near_water(c: int, r: int) -> bool:
	return ch_at(c - 1, r) == "~" or ch_at(c + 1, r) == "~" or ch_at(c, r - 1) == "~" or ch_at(c, r + 1) == "~"


func _near_land(c: int, r: int) -> bool:
	return ch_at(c - 1, r) != "~" or ch_at(c + 1, r) != "~" or ch_at(c, r - 1) != "~" or ch_at(c, r + 1) != "~"


func _apply_grade() -> void:
	var g := grade
	modulate_node.color = g.mod
	torch.energy = float(g.torch)
	var pm := post.material as ShaderMaterial
	pm.set_shader_parameter("tint", g.tint)
	pm.set_shader_parameter("saturation", float(g.sat))
	pm.set_shader_parameter("contrast", float(g.con))
	pm.set_shader_parameter("warmth", float(g.warm))
	var fxm := 0.0 if gfx_level == "low" else (0.55 if gfx_level == "phone" else 1.0)
	pm.set_shader_parameter("rays", float(g.rays) * fxm)
	pm.set_shader_parameter("bloom", float(g.bloom) * fxm)


func _blend_grade(delta: float) -> void:
	if grade_target.is_empty():
		return
	var k := clampf(delta * 1.5, 0.0, 1.0)
	for key in grade_target:
		var a = grade[key]
		var b = grade_target[key]
		if a is Color:
			grade[key] = (a as Color).lerp(b, k)
		else:
			grade[key] = lerpf(float(a), float(b), k)
	_apply_grade()


func _apply_motion() -> void:
	var m := 0.0 if reduced_motion else 1.0
	(ground.material as ShaderMaterial).set_shader_parameter("motion", m)
	KingdomView.sway_mat.set_shader_parameter("motion", m)
	(post.material as ShaderMaterial).set_shader_parameter("motion", m)
	smoke.visible = not reduced_motion


func ch_at(c: int, r: int) -> String:
	if r < 0 or r >= H or c < 0 or c >= W:
		return "~" if map.get("id", "") == "overworld" else "#"
	return (rows[r] as String)[c]


func is_land(c: int, r: int) -> bool:
	return ch_at(c, r) != "~"


func tile_blocked(c: int, r: int) -> bool:
	return ch_at(c, r) in ["~", "#", "T", "P"]


func blocked_at(p: Vector2) -> bool:
	var foot := Rect2(p.x - 12, p.y - 8, 24, 12)
	for corner in [foot.position, Vector2(foot.end.x, foot.position.y), Vector2(foot.position.x, foot.end.y), foot.end]:
		if tile_blocked(int(floor(corner.x / TILE)), int(floor(corner.y / TILE))):
			return true
	for b in blocks:
		if (b as Rect2).intersects(foot):
			return true
	for u in usables:
		if u.kind == "npc" and (u.pos as Vector2).distance_to(p) < 24.0:
			return true
	return false


func region_at(p: Vector2) -> String:
	match ch_at(int(p.x / TILE), int(p.y / TILE)):
		"f", "T": return "forest"
		"^", "#": return "highlands"
		":": return "shore"
		",": return "road"
	return "meadow"


func view_rect() -> Rect2:
	var vs := get_viewport_rect().size / cam.zoom
	return Rect2(cam.get_screen_center_position() - vs / 2.0, vs)


# ================================================================ loop
func _process(delta: float) -> void:
	t_now += delta
	_layout()
	var modal := _modal_open() or map_screen.visible
	if modal and (touch.active() or not touch.fingers.is_empty()):
		_touch_actions(touch.reset()) # a panel opened under held fingers: drop them (their releases go to the panel)
	Input.emulate_mouse_from_touch = modal # menus use normal Control taps; the field uses KingdomTouch
	if last_pad and _story_dialog_open() and _story_ui().choices_box.get_child_count() > 0 and get_viewport().gui_get_focus_owner() == null:
		_focus_first(_story_ui().choices_box) # gamepad: story choices are navigable straight away
	var moved := 0.0
	if not busy and not _modal_open():
		moved = _move(delta)
	player.walking = moved > 0.01
	player.position = player_pos
	_update_near()
	_update_camera(delta)
	if moved > 0.0:
		_after_move(moved)
	for n in ysort.get_children():
		if n is KingdomView.Actor or (n is KingdomView.Prop and n.animated):
			n.queue_redraw()
	markers.queue_redraw()
	prompt_layer.queue_redraw()
	_hud_tick()
	fg.queue_redraw()
	life.queue_redraw()
	minimap.queue_redraw()
	_blend_grade(delta)
	if not reduced_motion:
		for l in get_tree().get_nodes_in_group("k_light"):
			(l as PointLight2D).energy = 0.5 + 0.05 * sin(t_now * 9.0 + l.position.x) + 0.03 * sin(t_now * 23.0)


func _input_dir() -> Vector2:
	var d := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): d.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): d.x += 1
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): d.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): d.y += 1
	d = d.normalized()
	# Gamepad: left stick (analog, with a dead zone) or d-pad.
	var pad := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
	if pad.length() > 0.22:
		d = pad.normalized() * minf(1.0, (pad.length() - 0.22) / 0.7)
		last_pad = true
	else:
		var dp := Vector2.ZERO
		if Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_LEFT): dp.x -= 1
		if Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_RIGHT): dp.x += 1
		if Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_UP): dp.y -= 1
		if Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_DOWN): dp.y += 1
		if dp != Vector2.ZERO:
			d = dp.normalized()
			last_pad = true
	# Floating touch stick (analog: speed follows how far the knob is pushed).
	if touch.vec != Vector2.ZERO:
		d = touch.vec
	return d


func _move(delta: float) -> float:
	var dir := _input_dir()
	if dir != Vector2.ZERO:
		tap_target = null
		tap_use = {}
	if dir == Vector2.ZERO:
		return 0.0
	face_dir = dir.normalized()
	# Analog: a light push walks, full push runs at SPEED (never slower than 35% so it still feels responsive).
	var spd := SPEED * clampf(dir.length(), 0.35, 1.0)
	return step_move(dir.normalized() * spd * minf(delta, 0.05))


## Move with wall sliding; returns the distance actually moved. Public for tests.
func step_move(d: Vector2) -> float:
	var before := player_pos
	if d.x != 0.0 and not blocked_at(player_pos + Vector2(d.x, 0)):
		player_pos.x += d.x
	if d.y != 0.0 and not blocked_at(player_pos + Vector2(0, d.y)):
		player_pos.y += d.y
	if absf(d.x) > 0.01:
		player.facing = signf(d.x)
	var moved := player_pos.distance_to(before)
	if moved < 0.01 and tap_target != null:
		tap_target = null # stuck: give up the tap-to-move target
	return moved


func _after_move(moved: float) -> void:
	# Warps (exits) fire on contact.
	var tile := Vector2(floor(player_pos.x / TILE), floor(player_pos.y / TILE))
	for w in (map.warps if allow_warps else []):
		if (w.rect as Rect2).has_point(tile + Vector2(0.5, 0.5)):
			warp_to(str(w.to), w.at)
			return
	# Area labels: overworld regions and castle halls fade in as you enter them.
	if bool(map.encounters):
		var reg := region_at(player_pos)
		if reg != cur_region:
			var first := cur_region == ""
			cur_region = reg
			grade_target = KingdomMaps.GRADES["forest" if reg == "forest" else "overworld"].duplicate()
			if not first and reg != "road":
				_show_banner(KingdomMaps.REGIONS[reg].name, "", true)
		_tick_danger(moved, reg)
	elif map.has("zones"):
		for z in map.zones:
			if (z.rect as Rect2).has_point(tile + Vector2(0.5, 0.5)):
				if z.name != cur_zone:
					var first2 := cur_zone == ""
					cur_zone = z.name
					if not first2:
						_show_banner(z.name, "", true)
				break


# ================================================================ encounters
func _tick_danger(moved: float, reg: String) -> void:
	var tiles: float = float(KingdomMaps.REGIONS[reg].tiles)
	meter += moved / (TILE * tiles)
	if meter >= 1.0:
		meter = 0.0
		_trigger_battle(reg)
	danger_bar.value = meter * 100.0


func _trigger_battle(reg: String) -> void:
	if not reduced_motion:
		var tw := danger_bar.create_tween()
		danger_bar.pivot_offset = danger_bar.size / 2.0
		tw.tween_property(danger_bar, "scale", Vector2(1.12, 1.4), 0.08)
		tw.tween_property(danger_bar, "scale", Vector2.ONE, 0.2)
	save_game() # so a battle scene that swaps scenes can return to exactly here
	var e := _enc()
	if e == null:
		return
	if e.has_battle_listener():
		busy = true
		tap_target = null
	e.start_random_battle(reg)
	if not busy:
		_toast("Something stirs in %s..." % KingdomMaps.REGIONS[reg].name)


func _on_battle_finished(_won: bool) -> void:
	busy = false
	_refresh_hud()


# ================================================================ interact
var _use_talking := false

func _update_near() -> void:
	var best: Dictionary = {}
	var bd := 78.0
	for u in usables:
		var d: float = (u.pos as Vector2).distance_to(player_pos)
		if d < bd:
			bd = d
			best = u
	var talking := dialog.visible or _story_dialog_open()
	if best != near or talking != _use_talking:
		near = best
		_use_talking = talking
		# During a dialog the Use button steps aside (the dialog box sits over it; a tap anywhere, E or A advances).
		use_btn.set_target({} if talking else near)


func use(u: Dictionary) -> void:
	if u.is_empty() or busy:
		return
	match str(u.action):
		"warp":
			warp_to(str(u.to), u.at)
		"shop":
			open_shop()
		"inn":
			open_inn()
		"text":
			if bool(u.get("calm", false)) and bool(map.encounters):
				meter = 0.0
				danger_bar.value = 0.0
			var hero := ""
			if u.get("kind", "") == "npc" and u.has("node"):
				hero = (u.node as KingdomView.Actor).hero
			_open_dialog(str(u.name), str(u.text), hero)
		"story": # story NPCs and spots (scripts/story/story.gd)
			var story := get_node_or_null("/root/Story")
			if story: story.use(self, u)


func warp_to(id: String, at: Variant) -> void:
	if busy:
		return
	busy = true
	tap_target = null
	await _iris_close()
	load_map(id, at)
	_show_banner(map.name, map.sub)
	await _iris_open()
	busy = false
	save_game()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		match e.physical_keycode:
			KEY_E, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
				use_or_advance()
				get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				if _modal_open():
					for p in [dialog, shop, inn, menu]:
						_close(p)
				elif map_screen.visible:
					toggle_big_map()
				else:
					_open_menu()
				get_viewport().set_input_as_handled()
			KEY_M:
				if not _modal_open(): toggle_big_map()
		last_pad = false
	elif e is InputEventJoypadButton and e.pressed:
		last_pad = true
		match (e as InputEventJoypadButton).button_index:
			JOY_BUTTON_A:
				var sui := _story_ui()
				if map_screen.visible: toggle_big_map()
				elif _story_dialog_open() or dialog.visible or (sui != null and sui.get("_blocking")) or not _modal_open():
					var fo := get_viewport().gui_get_focus_owner()
					if fo != null and sui != null and sui.choices_box.is_ancestor_of(fo):
						return # a focused story choice takes the press (ui_accept)
					use_or_advance()
				else: return # let the focused menu button take it
			JOY_BUTTON_B:
				var sui2 := _story_ui()
				if map_screen.visible: toggle_big_map()
				elif sui2 != null and sui2.journal.visible: sui2.close_journal()
				elif _story_dialog_open(): use_or_advance()
				elif _modal_open():
					for p in [dialog, shop, inn, menu]:
						_close(p)
				else: _open_menu()
			JOY_BUTTON_START:
				if map_screen.visible: toggle_big_map()
				elif menu.visible: _close(menu)
				elif not _modal_open(): _open_menu()
			JOY_BUTTON_BACK:
				if not _modal_open(): toggle_big_map()
			JOY_BUTTON_Y: # journal (story)
				var sui3 := _story_ui()
				if sui3 != null and not _modal_open(): sui3.open_journal()
				elif sui3 != null and sui3.journal.visible: sui3.close_journal()
			_:
				return
		get_viewport().set_input_as_handled()
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		last_pad = false
		if dialog.visible:
			_dialog_advance()
			return
		return # no click-to-walk: keyboard / gamepad / the touch stick move, Use / E interacts


## Tap-to-walk is gone (it could leave a stale walk target that re-used a door / person the moment a
## dialog closed). Kept for tests: uses the thing under the point only if it is already in reach.
func tap_at(screen_pos: Vector2) -> void:
	var wp: Vector2 = get_canvas_transform().affine_inverse() * screen_pos
	tap_target = null
	tap_use = {}
	if near.is_empty(): return
	var np: Vector2 = near.pos
	var d := minf(np.distance_to(wp), (np + Vector2(0, -40)).distance_to(wp))
	if d < 56.0: use(near)

# ================================================================ touch (multitouch, no mouse emulation)
func _input(e: InputEvent) -> void:
	if not (e is InputEventScreenTouch or e is InputEventScreenDrag):
		return
	touch_ui = true
	last_pad = false
	if _modal_open() or map_screen.visible:
		if e is InputEventScreenTouch and not e.pressed and touch.fingers.has(e.index):
			touch.fingers.erase(e.index) # a finger that went down on the field lifts over a panel
			if touch.stick_finger == e.index: _touch_actions(touch.reset())
		return # emulated mouse drives the open panel
	touch.scale = ui.scale.x
	touch.size = stick_size() * ui.scale.x
	_touch_actions(touch.handle(e, t_now))
	if touch.active():
		stick.set_knob(touch.knob / ui.scale.x)
	get_viewport().set_input_as_handled()


func _touch_actions(acts: Array) -> void:
	for a in acts:
		match str(a.type):
			"stick_start":
				tap_target = null
				stick.show_at((a.pos as Vector2) / ui.scale.x)
			"stick_end":
				stick.release()
			"tap":
				# No tap-to-walk / tap-to-use on the field: the stick moves, the Use button interacts.
				if dialog.visible: _dialog_advance()
			"ui_down":
				if a.name == "use": use_btn.press(true)
				elif a.name == "journal" and _story_ui(): _story_ui().quests_btn.button_pressed = true
				elif a.name == "menu": menu_btn.button_pressed = true
			"ui_up":
				if a.name == "journal" and _story_ui(): _story_ui().quests_btn.button_pressed = false
				if a.name == "use":
					use_btn.press(false)
					if a.inside: use_or_advance()
				elif a.name == "menu":
					menu_btn.button_pressed = false
					if a.inside: _open_menu()
				elif a.name == "map" and a.inside:
					toggle_big_map()
				elif a.name == "journal" and a.inside and _story_ui():
					_story_ui().open_journal()
				elif a.name == "tip" and _story_ui():
					_story_ui().tip_panel.visible = false


func _story_ui() -> Node:
	var st := get_node_or_null("/root/Story")
	if st == null: return null
	var sui = st.get("ui")
	return sui if sui != null and is_instance_valid(sui) else null


## Story dialog (scripts/story/story_ui.gd) is showing a line or choices.
func _story_dialog_open() -> bool:
	var sui := _story_ui()
	return sui != null and (sui.dlg.visible or sui.choices_box.get_child_count() > 0)


## Which HUD button (if any) sits under a screen point. Everything else is play area.
func _ui_hit(p: Vector2) -> String:
	var sui := _story_ui()
	if sui != null:
		# Story HUD (journal button, objective tracker, tips) lives on its own CanvasLayer: route those taps to it.
		if sui.quests_btn.visible and sui.quests_btn.get_global_rect().grow(4.0 * ui.scale.x).has_point(p):
			return "journal"
		if sui.tracker.visible and sui.tracker.get_global_rect().has_point(p):
			return "journal"
		if sui.tip_panel.visible and sui.tip_panel.get_global_rect().has_point(p):
			return "tip"
	if use_btn.visible and use_btn.shown and use_btn.get_global_rect().grow(10.0 * ui.scale.x).has_point(p):
		return "use"
	if menu_btn.get_global_rect().grow(4.0).has_point(p):
		return "menu"
	if minimap.get_global_rect().has_point(p):
		return "map"
	if loc_card.get_global_rect().has_point(p):
		return "hud" # swallow: no stick under the HUD card
	return ""


## Use button / E / gamepad A: advance whichever dialog is open, otherwise use what's in reach.
func use_or_advance() -> void:
	var sui := _story_ui()
	if _story_dialog_open():
		if sui.choices_box.get_child_count() > 0:
			_focus_first(sui.choices_box) # pick with the pad / keys 1-4 / a tap
		else:
			sui.advance()
	elif sui != null and sui.get("_blocking"):
		sui.set("_tap", true) # act cards / fanfare: skip ahead
	elif dialog.visible:
		_dialog_advance()
	elif not _modal_open():
		use(near)


func stick_size() -> float:
	return 118.0 * (1.15 if minf(ui.size.x, ui.size.y) < 500.0 else 1.0)


func _open_menu() -> void:
	AfTheme.pop_in(menu, reduced_motion)
	if last_pad or not touch_ui:
		_focus_first(menu)


func _focus_first(n: Node) -> void:
	if not last_pad:
		return
	for c in n.find_children("*", "Button", true, false):
		if (c as Button).visible and not (c as Button).disabled:
			(c as Button).call_deferred("grab_focus")
			return


func _dialog_advance() -> void:
	if dialog_text.visible_ratio < 1.0:
		if _type_tw: _type_tw.kill()
		dialog_text.visible_ratio = 1.0
	else:
		_close(dialog)


func _modal_open() -> bool:
	var story := get_node_or_null("/root/Story")
	return shop.visible or inn.visible or menu.visible or dialog.visible or (story != null and story.ui_open())


func _close(p: Control) -> void:
	AfTheme.pop_out(p, reduced_motion)


# ================================================================ shop / inn
func open_shop() -> void:
	shop_mode = "buy"
	_fill_shop()
	AfTheme.pop_in(shop, reduced_motion)
	_focus_first(shop)


func _fill_shop() -> void:
	for c in shop_list.get_children():
		c.queue_free()
	shop_gold.text = "%d gold" % gold
	shop_tabs[0].button_pressed = shop_mode == "buy"
	shop_tabs[1].button_pressed = shop_mode == "sell"
	var ids: Array = item_defs.keys() if shop_mode == "buy" else bag.duplicate()
	if ids.is_empty():
		var l := Label.new()
		l.theme_type_variation = "MutedLabel"
		l.text = "Your bag is empty."
		shop_list.add_child(l)
	var seen := {}
	for iid in ids:
		if shop_mode == "sell" and seen.has(iid):
			continue
		seen[iid] = true
		var it: Dictionary = item_defs.get(iid, {"name": iid, "slot": "weapon", "blurb": ""})
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var ic := TextureRect.new()
		ic.texture = load("res://assets/af/icons/%s.png" % SLOT_ICONS.get(it.get("slot", "weapon"), "chest"))
		ic.custom_minimum_size = Vector2(44, 44)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(ic)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", -2)
		var nm := Label.new()
		var count := bag.count(iid)
		nm.text = str(it.get("name", iid)) + ("  x%d" % count if count > 1 else "")
		col.add_child(nm)
		var bl := Label.new()
		bl.theme_type_variation = "MutedLabel"
		bl.text = "%s · %s" % [str(it.get("slot", "")).capitalize(), _stat_text(it)]
		bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(bl)
		row.add_child(col)
		var price := price_of(iid) if shop_mode == "buy" else price_of(iid) / 2
		var b := Button.new()
		b.text = ("Buy %dg" if shop_mode == "buy" else "Sell %dg") % price
		b.custom_minimum_size = Vector2(108, 48)
		b.theme_type_variation = "PrimaryButton" if shop_mode == "buy" else ""
		b.disabled = shop_mode == "buy" and gold < price
		AfTheme.add_press_juice(b, func(): return reduced_motion)
		var item_id: String = iid
		b.pressed.connect(func():
			if shop_mode == "buy": buy(item_id)
			else: sell(item_id))
		row.add_child(b)
		shop_list.add_child(row)


func _stat_text(it: Dictionary) -> String:
	var parts: Array = []
	for key in ["atk", "def", "armor", "hp", "speed", "crit", "mana"]:
		if it.has(key):
			parts.append("+%d %s" % [int(it[key]), key.to_upper() if key in ["atk", "def", "hp"] else key.capitalize()])
	return " ".join(parts)


func buy(iid: String) -> bool:
	var p := price_of(iid)
	if gold < p or not item_defs.has(iid):
		return false
	gold -= p
	bag.append(iid)
	save_game()
	_fill_shop()
	_refresh_hud()
	_toast("Bought %s." % item_defs[iid].name)
	return true


func sell(iid: String) -> bool:
	var i := bag.find(iid)
	if i < 0:
		return false
	bag.remove_at(i)
	gold += price_of(iid) / 2
	save_game()
	_fill_shop()
	_refresh_hud()
	_toast("Sold %s." % item_defs.get(iid, {"name": iid}).name)
	return true


func open_inn() -> void:
	inn_text.text = "Rest at the Ember Inn for %d gold?\nRestores the party and saves your journey." % INN_COST
	AfTheme.pop_in(inn, reduced_motion)
	_focus_first(inn)


func rest_at_inn() -> bool:
	if gold < INN_COST:
		_toast("Not enough gold.")
		return false
	gold -= INN_COST
	party_hp = party_hp_max
	meter = 0.0
	_close(inn)
	busy = true
	if is_inside_tree():
		await _iris_close()
		await get_tree().create_timer(0.35).timeout
		await _iris_open()
	busy = false
	save_game()
	_refresh_hud()
	_toast("The party is rested. Journey saved.")
	return true


func toggle_big_map() -> void:
	if map_screen.visible:
		if reduced_motion:
			map_screen.visible = false
		else:
			var tw := create_tween()
			tw.tween_property(map_screen, "modulate:a", 0.0, 0.16)
			tw.tween_callback(func(): map_screen.visible = false)
		return
	if busy:
		return
	map_screen.open()
	map_screen.visible = true
	map_screen.modulate.a = 1.0 if reduced_motion else 0.0
	if not reduced_motion:
		create_tween().tween_property(map_screen, "modulate:a", 1.0, 0.2)


# ================================================================ camera / fx
func _update_camera(delta: float) -> void:
	var vs := get_viewport_rect().size
	var dpr := _dpr()
	var z := clampf(minf(vs.x / (12.0 * TILE * dpr), vs.y / (8.0 * TILE * dpr)), 0.6, 1.25) * dpr
	cam.zoom = Vector2(z, z)
	# Gentle look-ahead in the walking direction (off with reduced motion).
	var want := Vector2.ZERO
	if player.walking and not reduced_motion:
		var dir := _input_dir()
		want = dir * 70.0
	_cam_ahead = _cam_ahead.lerp(want, clampf(delta * 2.5, 0.0, 1.0))
	cam.position = player_pos + _cam_ahead + Vector2(0, -24)
	cam.position_smoothing_enabled = not reduced_motion
	if particles:
		particles.position = cam.get_screen_center_position()
		particles.emission_rect_extents = vs / cam.zoom / 2.0


var _dpr_cache := -1.0

func _dpr() -> float:
	if _dpr_cache > 0.0:
		return _dpr_cache
	_dpr_cache = 1.0
	if OS.has_feature("web"):
		var iw = JavaScriptBridge.eval("window.innerWidth", true)
		if iw != null and float(iw) > 0.0:
			_dpr_cache = clampf(get_viewport_rect().size.x / float(iw), 1.0, 4.0)
	else:
		_dpr_cache = clampf(DisplayServer.screen_get_scale(), 1.0, 3.0)
	return _dpr_cache


func _setup_particles(kind: String) -> void:
	particles.emitting = false
	particles.visible = not reduced_motion and kind != ""
	if reduced_motion:
		return
	var grad := Gradient.new()
	match kind:
		"embers":
			particles.amount = 26
			particles.gravity = Vector2(0, -18)
			particles.initial_velocity_min = 8.0
			particles.initial_velocity_max = 22.0
			particles.direction = Vector2(0.2, -1)
			particles.color = Color(1.0, 0.6, 0.25, 0.9)
		"dust":
			particles.amount = 34
			particles.gravity = Vector2(4, 2)
			particles.initial_velocity_min = 2.0
			particles.initial_velocity_max = 8.0
			particles.direction = Vector2(1, 0.3)
			particles.color = Color(1.0, 0.9, 0.75, 0.55)
		_:
			particles.amount = 40
			particles.gravity = Vector2(0, -4)
			particles.initial_velocity_min = 4.0
			particles.initial_velocity_max = 14.0
			particles.direction = Vector2(0, -1)
			particles.color = Color(0.95, 0.9, 0.55, 0.8)
	grad.set_color(0, Color(1, 1, 1, 0))
	grad.set_color(1, Color(1, 1, 1, 0))
	grad.add_point(0.2, Color(1, 1, 1, 1))
	grad.add_point(0.75, Color(1, 1, 1, 0.8))
	particles.color_ramp = grad
	particles.restart()
	particles.emitting = true


func _iris_center() -> Vector2:
	var vs := get_viewport_rect().size
	var sp: Vector2 = get_canvas_transform() * player_pos
	return Vector2(sp.x / maxf(1.0, vs.x), (sp.y - 30.0) / maxf(1.0, vs.y))


func _iris_close() -> void:
	var mat := iris.material as ShaderMaterial
	iris.visible = true
	mat.set_shader_parameter("use_fade", reduced_motion)
	mat.set_shader_parameter("center", _iris_center())
	var tw := create_tween()
	if reduced_motion:
		tw.tween_method(func(v: float): mat.set_shader_parameter("fade", v), 0.0, 1.0, 0.25)
	else:
		tw.tween_method(func(v: float): mat.set_shader_parameter("radius", v), 1.6, 0.0, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await tw.finished


func _iris_open() -> void:
	var mat := iris.material as ShaderMaterial
	iris.visible = true
	mat.set_shader_parameter("use_fade", reduced_motion)
	await get_tree().process_frame
	mat.set_shader_parameter("center", _iris_center())
	var tw := create_tween()
	if reduced_motion:
		tw.tween_method(func(v: float): mat.set_shader_parameter("fade", v), 1.0, 0.0, 0.3)
	else:
		tw.tween_method(func(v: float): mat.set_shader_parameter("radius", v), 0.0, 1.6, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tw.finished
	iris.visible = false


var _banner_tw: Tween
var banner_y := 70.0 # set by _layout (below the HUD on portrait phones)

func _show_banner(title: String, sub: String, small: bool = false) -> void:
	_layout()
	banner_title.text = title
	var portrait := get_viewport_rect().size.y > get_viewport_rect().size.x
	banner_title.add_theme_font_size_override("font_size", (18 if small else 24) if portrait else (22 if small else 30))
	banner_sub.add_theme_font_size_override("font_size", 13 if portrait else 15)
	banner_sub.text = sub
	banner_sub.visible = sub != ""
	if _banner_tw:
		_banner_tw.kill()
	banner.modulate.a = 0.0
	banner.position.y = banner_y if reduced_motion else banner_y - 12.0
	_banner_tw = create_tween()
	_banner_tw.set_parallel(true)
	_banner_tw.tween_property(banner, "modulate:a", 1.0, 0.5)
	if not reduced_motion:
		_banner_tw.tween_property(banner, "position:y", banner_y, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_banner_tw.chain().tween_interval(1.4 if small else 2.0)
	_banner_tw.chain().tween_property(banner, "modulate:a", 0.0, 0.8)
	loc_name.text = map.get("name", "")


var _toast_tw: Tween

func _toast(s: String) -> void:
	toast_label.text = s
	if _toast_tw:
		_toast_tw.kill()
	AfTheme.pop_in(toast, reduced_motion)
	_toast_tw = create_tween()
	_toast_tw.tween_interval(2.4)
	_toast_tw.tween_callback(func(): AfTheme.pop_out(toast, reduced_motion))


func _open_dialog(name: String, text: String, hero: String = "") -> void:
	dialog_name.text = name
	var body := text
	if body.begins_with(name + ":"):
		body = body.substr(name.length() + 1).strip_edges()
	dialog_text.text = body
	dialog_portrait_box.visible = hero != ""
	if hero != "":
		dialog_portrait.texture = KingdomView.hero_tex(hero)
	AfTheme.pop_in(dialog, reduced_motion)
	if _type_tw:
		_type_tw.kill()
	if reduced_motion:
		dialog_text.visible_ratio = 1.0
	else:
		dialog_text.visible_ratio = 0.0
		_type_tw = create_tween()
		_type_tw.tween_property(dialog_text, "visible_ratio", 1.0, clampf(body.length() * 0.022, 0.3, 2.0))


func _hud_tick() -> void:
	var sub: String = str(map.get("sub", ""))
	if bool(map.get("encounters", false)) and cur_region != "" and KingdomMaps.REGIONS.has(cur_region):
		sub = str(KingdomMaps.REGIONS[cur_region].name)
	elif cur_zone != "":
		sub = cur_zone
	if loc_sub.text != sub:
		loc_sub.text = sub
	# Danger meter glows and throbs as an encounter gets close.
	var hot := clampf((meter - 0.6) / 0.4, 0.0, 1.0)
	var th := 0.0 if reduced_motion else 0.5 + 0.5 * sin(t_now * 7.0)
	danger_bar.modulate = Color(1, 1, 1).lerp(Color(1.35, 1.1, 0.9), hot * (0.5 + 0.5 * th))


func _refresh_hud() -> void:
	hp_bar.max_value = party_hp_max
	hp_bar.value = party_hp
	hp_text.text = "%d / %d" % [party_hp, party_hp_max]
	gold_label.text = "%d g" % gold
	danger_bar.value = meter * 100.0
	loc_name.text = map.get("name", "")


var _gfx_saved := false # true once the player (or ?gfx=) picked a quality; otherwise we follow the device

static func is_touch_device() -> bool:
	# Phones and tablets only: a Windows laptop with a touch screen still counts as desktop (mouse = fine pointer).
	if OS.has_feature("mobile") or OS.has_feature("web_ios") or OS.has_feature("web_android"):
		return true
	if OS.has_feature("web"):
		var coarse = JavaScriptBridge.eval("window.matchMedia && matchMedia('(pointer: coarse)').matches && !matchMedia('(any-pointer: fine)').matches", true)
		return coarse == true
	return false

## Small screen (phone-sized window, in CSS / logical px) also gets the lighter look by default.
func _small_screen() -> bool:
	var vs := get_viewport_rect().size / _dpr()
	return minf(vs.x, vs.y) < 560.0

func _apply_quality() -> void:
	if not GFX_LEVELS.has(gfx_level): gfx_level = "high"
	gfx_low = gfx_level == "low"
	var pm := post.material as ShaderMaterial
	pm.set_shader_parameter("low_quality", gfx_low)
	pm.set_shader_parameter("taps", 12 if gfx_level == "high" else 5)
	pm.set_shader_parameter("tilt", 0.0 if gfx_low else (0.7 if gfx_level == "phone" else 1.0))
	if gfx_btn: gfx_btn.text = "Graphics: %s" % {"high": "High", "phone": "Phone (light)", "low": "Low (fast)"}[gfx_level]
	if not grade.is_empty(): _apply_grade()

func set_gfx(level: String) -> void:
	gfx_level = level; _gfx_saved = true
	_apply_quality()
	save_game()

func set_gfx_low(on: bool) -> void:
	set_gfx("low" if on else "high")

func cycle_gfx() -> void:
	set_gfx(GFX_LEVELS[(GFX_LEVELS.find(gfx_level) + 1) % GFX_LEVELS.size()])

## Safe-area insets (notch, rounded corners, home indicator). On the web the page exposes
## env(safe-area-inset-*) as CSS vars (see export_presets.cfg head include); natively we use the OS.
var _inset_px := Vector4.ZERO

func _read_insets() -> void:
	_inset_px = Vector4.ZERO
	if OS.has_feature("web"):
		var js = JavaScriptBridge.eval("(function(){var s=getComputedStyle(document.documentElement);function v(n){return parseFloat(s.getPropertyValue(n))||0;}return [v('--sat'),v('--sar'),v('--sab'),v('--sal')].join(',');})()", true)
		if js is String:
			var parts := (js as String).split(",")
			if parts.size() == 4:
				var d := _dpr()
				_inset_px = Vector4(float(parts[0]), float(parts[1]), float(parts[2]), float(parts[3])) * d
	elif OS.has_feature("mobile"):
		var sa := DisplayServer.get_display_safe_area()
		var ss := DisplayServer.screen_get_size()
		if sa.size.x > 0:
			_inset_px = Vector4(sa.position.y, ss.x - sa.end.x, ss.y - sa.end.y, sa.position.x)

## Safe play rect in ui units (used by the map screen).
func safe_rect_ui() -> Rect2:
	return Rect2(Vector2(insets.w, insets.x), ui.size - Vector2(insets.w + insets.y, insets.x + insets.z))

func set_reduced_motion(on: bool) -> void:
	reduced_motion = on
	rm_btn.text = "Reduced motion: %s" % ("On" if on else "Off")
	_setup_particles(str(map.get("particles", "")))
	_apply_motion()
	save_game()


# ================================================================ node building
func _build_world_nodes() -> void:
	_light_tex = GradientTexture2D.new()
	_light_tex.fill = GradientTexture2D.FILL_RADIAL
	_light_tex.fill_from = Vector2(0.5, 0.5)
	_light_tex.fill_to = Vector2(1.0, 0.5)
	_light_tex.width = 256
	_light_tex.height = 256
	var lg := Gradient.new()
	lg.set_color(0, Color(1, 1, 1, 1))
	lg.set_color(1, Color(1, 1, 1, 0))
	_light_tex.gradient = lg
	modulate_node = CanvasModulate.new()
	add_child(modulate_node)
	KingdomView.materials()
	ground = KingdomView.Ground.new()
	ground.k = self
	ground.z_index = -10
	ground.setup()
	add_child(ground)
	details_static = KingdomView.Details.new()
	details_static.z_index = -9
	add_child(details_static)
	details_sway = KingdomView.Details.new()
	details_sway.z_index = -8
	details_sway.material = KingdomView.sway_mat
	add_child(details_sway)
	markers = KingdomView.Markers.new()
	markers.k = self
	markers.z_index = -7
	add_child(markers)
	ysort = Node2D.new()
	ysort.y_sort_enabled = true
	add_child(ysort)
	smoke = Node2D.new()
	smoke.z_index = 15
	add_child(smoke)
	life = KingdomView.Life.new()
	life.k = self
	life.z_index = 25
	add_child(life)
	prompt_layer = KingdomView.PromptLayer.new()
	prompt_layer.k = self
	prompt_layer.z_index = 40
	add_child(prompt_layer)
	fg = KingdomView.Foreground.new()
	fg.k = self
	fg.z_index = 30
	add_child(fg)
	player = KingdomView.Actor.new()
	player.k = self
	player.hero = PLAYER_HERO
	player.is_player = true
	ysort.add_child(player)
	torch = PointLight2D.new()
	torch.texture = _light_tex
	torch.texture_scale = 3.2
	torch.color = Color(1.0, 0.8, 0.55)
	torch.position = Vector2(0, -30)
	player.add_child(torch)
	particles = CPUParticles2D.new()
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.lifetime = 6.0
	particles.preprocess = 4.0
	particles.scale_amount_min = 1.5
	particles.scale_amount_max = 3.5
	particles.z_index = 20
	add_child(particles)
	cam = Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 6.0
	add_child(cam)
	cam.make_current()


func _panel(variation: String = "FramedPanel") -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = variation
	p.visible = false
	ui.add_child(p)
	return p


func _button(text: String, cb: Callable, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 50)
	if primary:
		b.theme_type_variation = "PrimaryButton"
	b.pressed.connect(cb)
	AfTheme.add_press_juice(b, func(): return reduced_motion)
	return b


func _icon(path: String) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load(path)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(18, 18)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


func _build_ui() -> void:
	var fx := CanvasLayer.new()
	fx.layer = 5
	add_child(fx)
	post = ColorRect.new()
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pmat := ShaderMaterial.new()
	pmat.shader = load("res://shaders/kingdom_post.gdshader")
	post.material = pmat
	post.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx.add_child(post)
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	ui = Control.new()
	ui.theme = AfTheme.get_theme()
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	# Location card: name + area, HP (heart, bar, numbers), gold, danger meter
	loc_card = _panel("FramedPanel")
	loc_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	loc_card.visible = true
	var lc := VBoxContainer.new()
	lc.add_theme_constant_override("separation", 3)
	loc_card.add_child(lc)
	loc_name = Label.new()
	loc_name.theme_type_variation = "HeaderLabel"
	loc_name.add_theme_font_size_override("font_size", 18)
	lc.add_child(loc_name)
	loc_sub = Label.new()
	loc_sub.theme_type_variation = "MutedLabel"
	loc_sub.add_theme_font_size_override("font_size", 12)
	loc_sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lc.add_child(loc_sub)
	var hr := HBoxContainer.new()
	hr.add_theme_constant_override("separation", 6)
	lc.add_child(hr)
	hr.add_child(_icon("res://assets/af/icons/armory-max-health.png"))
	var hpw := Control.new()
	hpw.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hpw.custom_minimum_size = Vector2(84, 16)
	hr.add_child(hpw)
	hp_bar = ProgressBar.new()
	hp_bar.show_percentage = false
	hp_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hpw.add_child(hp_bar)
	hp_text = Label.new()
	hp_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_text.add_theme_font_size_override("font_size", 11)
	hp_text.add_theme_constant_override("outline_size", 4)
	hp_text.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03))
	hpw.add_child(hp_text)
	hr.add_child(_icon("res://assets/af/icons/armory-gold.png"))
	gold_label = Label.new()
	gold_label.add_theme_color_override("font_color", AfTheme.GOLD)
	hr.add_child(gold_label)
	danger_row = HBoxContainer.new()
	danger_row.add_theme_constant_override("separation", 6)
	lc.add_child(danger_row)
	var dl := Label.new()
	dl.text = "Danger"
	dl.theme_type_variation = "MutedLabel"
	dl.add_theme_font_size_override("font_size", 12)
	danger_row.add_child(dl)
	danger_bar = ProgressBar.new()
	danger_bar.theme_type_variation = "DangerBar"
	danger_bar.show_percentage = false
	danger_bar.custom_minimum_size = Vector2(90, 10)
	danger_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	danger_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	danger_row.add_child(danger_bar)
	# Minimap + menu
	minimap = KingdomView.Minimap.new()
	minimap.k = self
	ui.add_child(minimap)
	menu_btn = _button("Menu", func(): _open_menu())
	menu_btn.custom_minimum_size = Vector2(84, 44)
	ui.add_child(menu_btn)
	# Touch: floating stick (appears under the finger) + context Use button (appears when in reach)
	stick = KingdomView.FloatStick.new()
	stick.k = self
	stick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stick.visible = false
	ui.add_child(stick)
	use_btn = KingdomView.UseButton.new()
	use_btn.k = self
	use_btn.visible = false
	use_btn.modulate.a = 0.0
	ui.add_child(use_btn)
	# Area banner (fades in on entering a place)
	banner = VBoxContainer.new()
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.modulate.a = 0.0
	ui.add_child(banner)
	banner_title = Label.new()
	banner_title.theme_type_variation = "HeaderLabel"
	banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_child(banner_title)
	var orn := KingdomView.Ornament.new()
	orn.custom_minimum_size = Vector2(0, 16)
	orn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(orn)
	banner_sub = Label.new()
	banner_sub.theme_type_variation = "FlavorLabel"
	for bl in [banner_title, banner_sub]:
		bl.add_theme_constant_override("outline_size", 7)
		bl.add_theme_color_override("font_outline_color", Color(0.06, 0.045, 0.035, 0.85))
	banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_child(banner_sub)
	toast = _panel("ToastPanel")
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_label = Label.new()
	toast.add_child(toast_label)
	# Dialog
	dialog = _panel()
	var dh := HBoxContainer.new()
	dh.add_theme_constant_override("separation", 14)
	dialog.add_child(dh)
	dialog_portrait_box = PanelContainer.new()
	dialog_portrait_box.custom_minimum_size = Vector2(84, 84)
	dialog_portrait_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	dh.add_child(dialog_portrait_box)
	dialog_portrait = TextureRect.new()
	dialog_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dialog_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	dialog_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	dialog_portrait_box.add_child(dialog_portrait)
	var dv := VBoxContainer.new()
	dv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dh.add_child(dv)
	dialog_name = Label.new()
	dialog_name.theme_type_variation = "HeaderLabel"
	dialog_name.add_theme_font_size_override("font_size", 20)
	dv.add_child(dialog_name)
	dialog_text = Label.new()
	dialog_text.theme_type_variation = "FlavorLabel"
	dialog_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dv.add_child(dialog_text)
	var mr := HBoxContainer.new()
	dv.add_child(mr)
	var more := Label.new()
	more.theme_type_variation = "MutedLabel"
	more.text = "Tap or press E"
	more.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	more.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mr.add_child(more)
	var arrow := KingdomView.MoreArrow.new()
	arrow.k = self
	arrow.custom_minimum_size = Vector2(20, 20)
	mr.add_child(arrow)
	# Shop
	shop = _panel()
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 8)
	shop.add_child(sv)
	var sh := HBoxContainer.new()
	sv.add_child(sh)
	var st := Label.new()
	st.text = "General Store"
	st.theme_type_variation = "HeaderLabel"
	st.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sh.add_child(st)
	shop_gold = Label.new()
	shop_gold.add_theme_color_override("font_color", AfTheme.GOLD)
	sh.add_child(shop_gold)
	var tabs := HBoxContainer.new()
	sv.add_child(tabs)
	for m in ["buy", "sell"]:
		var tb := _button(m.capitalize(), func(): shop_mode = m; _fill_shop())
		tb.toggle_mode = true
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(tb)
		shop_tabs.append(tb)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sv.add_child(scroll)
	shop_list = VBoxContainer.new()
	shop_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_list.add_theme_constant_override("separation", 8)
	scroll.add_child(shop_list)
	sv.add_child(_button("Leave", func(): _close(shop)))
	# Inn
	inn = _panel()
	var iv := VBoxContainer.new()
	iv.add_theme_constant_override("separation", 10)
	inn.add_child(iv)
	var it := Label.new()
	it.text = "The Ember Inn"
	it.theme_type_variation = "HeaderLabel"
	iv.add_child(it)
	inn_text = Label.new()
	inn_text.theme_type_variation = "FlavorLabel"
	inn_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	iv.add_child(inn_text)
	var ib := HBoxContainer.new()
	ib.add_theme_constant_override("separation", 10)
	iv.add_child(ib)
	var rest := _button("Rest", func(): rest_at_inn(), true)
	rest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ib.add_child(rest)
	var no := _button("Not now", func(): _close(inn))
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ib.add_child(no)
	# Menu
	menu = _panel()
	var mv := VBoxContainer.new()
	mv.add_theme_constant_override("separation", 10)
	menu.add_child(mv)
	var mt := Label.new()
	mt.text = "Emberhold"
	mt.theme_type_variation = "HeaderLabel"
	mt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mv.add_child(mt)
	mv.add_child(_button("Resume", func(): _close(menu), true))
	mv.add_child(_button("Save", func(): save_game(); _toast("Journey saved.")))
	rm_btn = _button("", func(): set_reduced_motion(not reduced_motion))
	rm_btn.text = "Reduced motion: %s" % ("On" if reduced_motion else "Off")
	mv.add_child(rm_btn)
	gfx_btn = _button("", func(): cycle_gfx())
	mv.add_child(gfx_btn)
	# Battle setup (scripts/target_select.gd): who the party hits when you don't tap a foe in target select
	var tgt_btn := _button("Auto target: %s" % TargetSelect.label(), func(): pass)
	tgt_btn.pressed.connect(func(): TargetSelect.cycle(); tgt_btn.text = "Auto target: %s" % TargetSelect.label(); _toast(str(TargetSelect.HINTS[TargetSelect.mode()])))
	mv.add_child(tgt_btn)
	mv.add_child(_button("Back to title", func(): save_game(); get_tree().change_scene_to_file("res://main.tscn")))
	var cr := Label.new()
	cr.theme_type_variation = "MutedLabel"
	cr.text = "Art created with Grok"
	cr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mv.add_child(cr)
	# Full map screen (M / tap the minimap / gamepad Back)
	map_screen = KingdomView.MapScreen.new()
	map_screen.k = self
	map_screen.visible = false
	ui.add_child(map_screen)
	# Transition overlay
	var tl := CanvasLayer.new()
	tl.layer = 20
	add_child(tl)
	iris = ColorRect.new()
	iris.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var im := ShaderMaterial.new()
	im.shader = load("res://shaders/iris.gdshader")
	im.set_shader_parameter("radius", 0.0)
	iris.material = im
	iris.set_anchors_preset(Control.PRESET_FULL_RECT)
	tl.add_child(iris)


var _last_vs := Vector2.ZERO

func _layout() -> void:
	var vs := get_viewport_rect().size
	if vs != _last_vs:
		_last_vs = vs
		_read_insets() # rotation / resize changes the notch side
	var s := clampf(_dpr() * clampf(minf(vs.x, vs.y) / _dpr() / 560.0, 0.85, 1.25), 0.85, 4.0)
	ui.scale = Vector2(s, s)
	var w := vs.x / s
	var h := vs.y / s
	ui.size = Vector2(w, h)
	insets = _inset_px / s
	var m := 12.0
	var mt := m + insets.x  # top (notch / status bar)
	var mr := m + insets.y
	var mb := m + maxf(insets.z - 6.0, 0.0) # home indicator
	var ml := m + insets.w
	var portrait := h > w
	loc_card.position = Vector2(ml, mt)
	loc_card.custom_minimum_size = Vector2(minf(230.0, (w - ml - mr) * 0.52), 0)
	loc_card.size = Vector2.ZERO
	var mm := Vector2(150, 110) if not portrait else Vector2(minf(128.0, w * 0.32), 104)
	minimap.position = Vector2(w - mm.x - mr, mt)
	minimap.size = mm
	menu_btn.size = Vector2(84, 40)
	menu_btn.position = Vector2(w - 84 - mr, mt + mm.y + 8)
	var ub := 104.0 if touch_ui else 88.0
	use_btn.size = Vector2(ub, ub)
	use_btn.position = Vector2(w - ub - mr - 6, h - ub - mb - 6)
	stick.size = Vector2.ZERO
	toast.size = Vector2.ZERO
	toast.position = Vector2((w - toast.size.x) / 2.0, h * 0.64)
	# Area banner: never over the hero (screen centre). Landscape: top centre between the HUD card and the
	# minimap. Portrait: just under the HUD row.
	if portrait:
		# between the left edge and the Menu button, under the HUD card: well above the hero
		banner.size = Vector2(w - 2.0 * (84.0 + mr + 6.0), 0)
		banner.position.x = (w - banner.size.x) / 2.0
		banner_y = mt + loc_card.size.y + 8.0
	else:
		var left := loc_card.position.x + loc_card.size.x + 12.0
		var right := minimap.position.x - 12.0
		banner.size = Vector2(maxf(right - left, 200.0), 0)
		banner.position.x = left if right - left >= 200.0 else (w - 200.0) / 2.0
		banner_y = mt + 2.0
	var pw := minf(w - ml - mr, 560.0)
	dialog.custom_minimum_size = Vector2(pw, 0)
	dialog.size = Vector2(pw, 0)
	dialog.position = Vector2((w - pw) / 2.0, h - dialog.size.y - mb - 4.0)
	shop.size = Vector2(pw, minf(h - mt - mb, 520.0))
	shop.position = Vector2((w - shop.size.x) / 2.0, mt + (h - mt - mb - shop.size.y) / 2.0)
	inn.custom_minimum_size = Vector2(minf(pw, 440.0), 0)
	inn.size = Vector2.ZERO
	inn.position = (Vector2(w, h) - inn.size) / 2.0
	menu.custom_minimum_size = Vector2(minf(pw, 340.0), 0)
	menu.size = Vector2.ZERO
	menu.position = (Vector2(w, h) - menu.size) / 2.0
	map_screen.size = Vector2(w, h)
	(post.material as ShaderMaterial).set_shader_parameter("aspect", vs.x / maxf(1.0, vs.y))
	(iris.material as ShaderMaterial).set_shader_parameter("aspect", vs.x / maxf(1.0, vs.y))
