extends Node2D
## The Sunken Bastion (scenes/dungeon.tscn, docs/DUNGEON.md, docs/STORY.md Act IV): three floors under the ruin.
## Walk (WASD / arrows, tap or click to walk, drag to steer), E / Space / Enter or the Use button to interact.
## A danger meter fills as you walk and starts a random battle through the Encounters autoload (the same hook as the
## overworld); the fight runs in main.tscn and comes back here. Beats: chests, a lever and portcullis (floor 1), a locked
## door and its key (floor 2), an ember shrine save point and the sealed door of the final boss (floor 3).
## Story beats (DungeonGate.flag / Story): the Tithe Collector guards floor 1 (the Reliquary Key side door skips it),
## the Knellbearer guards floor 2 (the bound drowned court clears it), and the throne plays "final_confront".

const TILE := DungeonMaps.TILE
const WALL_H := 20.0 # front face of a wall, drawn in the wall cell's lower part
const SPEED := 190.0
const R := 13.0 # hero collision radius

var floor_i := 0
var fdef: Dictionary = {}
var open := {} # per floor id: {"G": bool, "D": bool, "chests": Array of "row,col"}
var keys := {} # floor id -> true when its key is found
var meter := 0.0
var gold := 120
var hp := 80
var hp_max := 80
var cleared := false
var pos := Vector2.ZERO
var facing := 1.0
var walking := false
var t_now := 0.0
var busy := false
var stair_grace := 0.0
var path: Array = []
var drag_from = null
var drag_vec := Vector2.ZERO
var near: Dictionary = {}
var reduced_motion := false
var shots_mode := false

var tex := {}
var ground: Texture2D
var cam: Camera2D
var torch: PointLight2D
var lights: Array = []
var modulate_node: CanvasModulate
var embers: CPUParticles2D
var astar := AStarGrid2D.new()

# UI
var ui: Control
var loc_name: Label
var loc_sub: Label
var hp_bar: ProgressBar
var gold_label: Label
var danger_bar: ProgressBar
var use_btn: Button
var menu_btn: Button
var menu: PanelContainer
var hint: PanelContainer
var hint_label: Label
var toast: PanelContainer
var toast_label: Label
var toast_t := 0.0
var banner: Control
var banner_title: Label
var banner_sub: Label
var banner_t := 99.0
var dialog: PanelContainer
var dlg_name: Label
var dlg_text: Label
var dlg_buttons: HBoxContainer
var dlg_queue: Array = []
var dlg_done: Callable
var end_card: PanelContainer
var fade: ColorRect
var vignette: TextureRect

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--shots": shots_mode = true
	_load_tex()
	_load_save()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dfloor="):
			floor_i = clampi(int(a.substr(9)) - 1, 0, DungeonMaps.FLOORS.size() - 1); pos = Vector2.ZERO
	_build_world()
	_build_ui()
	load_floor(floor_i, pos if pos != Vector2.ZERO else Vector2(-1, -1))
	var bs := get_node_or_null("/root/Bosses")
	if bs != null:
		bs.boss_defeated.connect(_on_boss_defeated)
		bs.boss_failed.connect(_on_boss_failed)
	var en := get_node_or_null("/root/Encounters")
	if en != null: en.random_battle_finished.connect(func(_w): meter = 0.0)
	var st := DungeonGate.story()
	if st != null:
		if st.has_signal("flag_changed"): st.flag_changed.connect(func(_n, _v): _refresh_astar())
		# battle_stub (tests) resolves story fights without leaving; in play the scene is swapped out instead
		if st.has_signal("battle_finished"): st.battle_finished.connect(func(_id, _w): busy = false; _refresh_astar(); _fade(0.0))

# ---------------------------------------------------------------- data / save
func _load_tex() -> void:
	for n in ["brazier", "pillar", "knight_statue", "stairs", "shrine", "sconce", "cairn", "urn_plant", "barrels", "boulder"]:
		var p := "res://assets/kingdom/%s.png" % n
		if ResourceLoader.exists(p): tex[n] = load(p)
	for n in ["wall", "flagstone", "cliff"]:
		var p2 := "res://assets/kingdom/tiles/%s.png" % n
		if ResourceLoader.exists(p2): tex["t_" + n] = load(p2)
	tex["chest"] = load("res://assets/af/props/ember-chest.png")
	tex["flame"] = load("res://assets/af/gen/fx_flame.png")
	tex["hero"] = load("res://assets/af/heroes/bramwell.png")
	for n in ["tithe", "knell"]: tex["foe_" + n] = load("res://assets/af/foes/foe-%s.png" % n)

func _load_save() -> void:
	var cf := ConfigFile.new()
	if cf.load(DungeonGate.SAVE) == OK:
		floor_i = int(cf.get_value("progress", "floor", 0))
		var p = cf.get_value("progress", "pos", null)
		if p is Vector2: pos = p * TILE
		meter = float(cf.get_value("progress", "meter", 0.0))
		open = cf.get_value("progress", "open", {})
		keys = cf.get_value("progress", "keys", {})
	cleared = DungeonGate.cleared()
	var kf := ConfigFile.new()
	if kf.load(DungeonGate.KINGDOM_SAVE) == OK:
		gold = int(kf.get_value("kingdom", "gold", gold))
		hp_max = int(kf.get_value("kingdom", "hp_max", hp_max))
		hp = int(kf.get_value("kingdom", "hp", hp_max))
		reduced_motion = bool(kf.get_value("kingdom", "reduced_motion", false))

func save_game() -> void:
	var cf := ConfigFile.new()
	cf.load(DungeonGate.SAVE)
	cf.set_value("progress", "floor", floor_i)
	cf.set_value("progress", "pos", pos / TILE)
	cf.set_value("progress", "meter", meter)
	cf.set_value("progress", "open", open)
	cf.set_value("progress", "keys", keys)
	cf.save(DungeonGate.SAVE)
	var kf := ConfigFile.new()
	kf.load(DungeonGate.KINGDOM_SAVE)
	kf.set_value("kingdom", "gold", gold)
	kf.set_value("kingdom", "hp", hp)
	kf.set_value("kingdom", "hp_max", hp_max)
	kf.save(DungeonGate.KINGDOM_SAVE)

func fopen() -> Dictionary:
	var id: String = str(fdef.id)
	if not open.has(id): open[id] = {"G": false, "D": false, "d": false, "chests": []}
	var o: Dictionary = open[id]
	var gf := str(fdef.get("guardian_flag", ""))
	o["K"] = gf != "" and DungeonGate.flag(gf)
	return o

# ---------------------------------------------------------------- world
func _build_world() -> void:
	modulate_node = CanvasModulate.new()
	add_child(modulate_node)
	cam = Camera2D.new()
	cam.position_smoothing_enabled = not reduced_motion
	cam.position_smoothing_speed = 7.0
	add_child(cam)
	cam.make_current()
	torch = _make_light(Color(1.0, 0.74, 0.5), 1.15, 1.35)
	embers = CPUParticles2D.new()
	embers.amount = 40
	embers.lifetime = 5.0
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(620, 380)
	embers.direction = Vector2(0, -1)
	embers.spread = 30.0
	embers.gravity = Vector2(0, -6)
	embers.initial_velocity_min = 6.0
	embers.initial_velocity_max = 22.0
	embers.scale_amount_min = 1.2
	embers.scale_amount_max = 2.6
	embers.color = Color(1.0, 0.55, 0.2, 0.8)
	embers.emitting = not reduced_motion
	add_child(embers)

var _light_tex: GradientTexture2D
func _make_light(col: Color, energy: float, sc: float) -> PointLight2D:
	if _light_tex == null:
		_light_tex = GradientTexture2D.new()
		_light_tex.fill = GradientTexture2D.FILL_RADIAL
		_light_tex.fill_from = Vector2(0.5, 0.5)
		_light_tex.fill_to = Vector2(1.0, 0.5)
		_light_tex.width = 256; _light_tex.height = 256
		var gr := Gradient.new()
		gr.set_color(0, Color(1, 1, 1, 1)); gr.set_color(1, Color(1, 1, 1, 0))
		gr.add_point(0.45, Color(1, 1, 1, 0.45))
		_light_tex.gradient = gr
	var l := PointLight2D.new()
	l.texture = _light_tex
	l.color = col
	l.energy = energy
	l.texture_scale = sc * 3.0
	add_child(l)
	return l

func load_floor(i: int, at: Vector2) -> void:
	floor_i = i
	fdef = DungeonMaps.floor_def(i)
	ground = load("res://assets/af/areas/area-%s-ground.png" % str(fdef.ground))
	modulate_node.color = fdef.ambient
	for l in lights: l.queue_free()
	lights = []
	for c in DungeonMaps.find_all(i, "b"):
		var l := _make_light(fdef.light, 1.05, 0.95); l.position = cell_center(c) + Vector2(0, -24); lights.append(l)
	var lava: Array = DungeonMaps.find_all(i, "~")
	for j in lava.size():
		if j % 4 == 0:
			var l2 := _make_light(Color(1.0, 0.42, 0.15) if str(fdef.get("liquid", "lava")) == "lava" else Color(0.35, 0.8, 0.85), 0.55 if str(fdef.get("liquid", "lava")) == "lava" else 0.3, 0.75); l2.position = cell_center(lava[j]); lights.append(l2)
	for c in DungeonMaps.find_all(i, "P"):
		var l3 := _make_light(Color(0.55, 0.85, 1.0), 1.0, 0.95); l3.position = cell_center(c) + Vector2(0, -18); lights.append(l3)
	var bd: Array = DungeonMaps.find_all(i, "B")
	if not bd.is_empty():
		var l4 := _make_light(Color(1.0, 0.45, 0.25) if not cleared else Color(1.0, 0.85, 0.55), 1.6, 1.1); l4.position = cell_center(bd[1 if bd.size() > 1 else 0]) + Vector2(0, 30); lights.append(l4)
	var sz := DungeonMaps.size(i)
	astar = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, sz.x, sz.y)
	astar.cell_size = Vector2(TILE, TILE)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	_refresh_astar()
	if at.x < 0:
		var st: Vector2i = DungeonMaps.find(i, "S")
		if st.x < 0: st = DungeonMaps.find(i, "<")
		pos = cell_center(st) + Vector2(0, -TILE * 0.9)
		if not walkable_px(pos): pos = cell_center(st)
	else:
		pos = at
	stair_grace = 0.6
	cam.position = pos
	cam.reset_smoothing()
	var lim := Vector2(sz) * TILE
	cam.limit_left = -int(TILE * 2); cam.limit_top = -int(TILE * 2)
	cam.limit_right = int(lim.x + TILE * 2); cam.limit_bottom = int(lim.y + TILE * 2)
	_show_banner(str(fdef.name), str(fdef.sub))
	queue_redraw()
	_update_ui()

func _refresh_astar() -> void:
	var sz := DungeonMaps.size(floor_i)
	for y in sz.y:
		for x in sz.x:
			astar.set_point_solid(Vector2i(x, y), not DungeonMaps.walkable(floor_i, Vector2i(x, y), fopen()))

func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / TILE)), int(floor(p.y / TILE)))

func cell_center(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(0.5, 0.5)) * TILE

func walkable_px(p: Vector2) -> bool:
	for o in [Vector2(-R, 0), Vector2(R, 0), Vector2(0, -R * 0.6), Vector2(0, R * 0.6)]:
		if not DungeonMaps.walkable(floor_i, cell_of(p + o), fopen()): return false
	return true

# ---------------------------------------------------------------- per frame
func _process(delta: float) -> void:
	t_now += delta
	stair_grace = maxf(0.0, stair_grace - delta)
	var moved := 0.0
	if not busy and not _modal_open():
		moved = _move(delta)
	walking = moved > 0.1
	if moved > 0.0 and bool(_encounters_here()):
		meter += moved / (TILE * float(fdef.get("rate", 30.0)))
		if meter >= 1.0:
			_start_battle()
	torch.position = pos + Vector2(0, -30)
	torch.energy = 1.15 + (0.0 if reduced_motion else sin(t_now * 9.0) * 0.08 + sin(t_now * 23.0) * 0.05)
	for l in lights:
		if not reduced_motion: l.energy *= 1.0 + sin(t_now * 7.0 + l.position.x) * 0.004
	cam.position = pos + Vector2(0, -20)
	embers.position = cam.position
	_update_near()
	if not busy and stair_grace <= 0.0: _check_step_triggers()
	if toast_t > 0.0:
		toast_t -= delta
		if toast_t <= 0.0: AfTheme.pop_out(toast, reduced_motion)
	if banner_t < 3.0:
		banner_t += delta
		banner.modulate.a = clampf(banner_t / 0.35, 0.0, 1.0) * clampf((2.6 - banner_t) / 0.5, 0.0, 1.0)
	danger_bar.value = meter * 100.0
	queue_redraw()

func _encounters_here() -> bool:
	if cleared and floor_i == 2: return false
	var safe: int = int(fdef.get("safe_rows", 0))
	if safe > 0 and cell_of(pos).y < safe: return false
	return true

func _input_dir() -> Vector2:
	var v := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): v.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): v.x += 1
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): v.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): v.y += 1
	if drag_vec.length() > 18.0: v = drag_vec.normalized()
	return v.normalized() if v.length() > 1.0 else v

func _move(delta: float) -> float:
	var dir := _input_dir()
	if dir != Vector2.ZERO: path = []
	elif not path.is_empty():
		var nxt: Vector2 = path[0]
		if pos.distance_to(nxt) < 6.0:
			path.pop_front()
			if path.is_empty(): return 0.0
			nxt = path[0]
		dir = (nxt - pos).normalized()
	if dir == Vector2.ZERO: return 0.0
	if absf(dir.x) > 0.1: facing = signf(dir.x)
	var step := dir * SPEED * delta
	var start := pos
	var np := pos + Vector2(step.x, 0)
	if walkable_px(np): pos = np
	np = pos + Vector2(0, step.y)
	if walkable_px(np): pos = np
	return start.distance_to(pos)

func walk_to(world: Vector2) -> void:
	var from := cell_of(pos)
	var to := cell_of(world)
	if not astar.region.has_point(to): return
	if astar.is_point_solid(to):
		# tapped a usable thing: walk next to it
		var best := Vector2i(-1, -1)
		for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
			var c: Vector2i = to + d
			if astar.region.has_point(c) and not astar.is_point_solid(c):
				if best.x < 0 or Vector2(c).distance_to(Vector2(from)) < Vector2(best).distance_to(Vector2(from)): best = c
		if best.x < 0: return
		to = best
	var cells: Array = astar.get_id_path(from, to)
	path = []
	for c in cells.slice(1): path.append(cell_center(c))
	if not path.is_empty() and astar.is_point_solid(cell_of(world)) == false:
		path[path.size() - 1] = world

# ---------------------------------------------------------------- interactables
func usables() -> Array:
	var out: Array = []
	var o := fopen()
	for c in DungeonMaps.find_all(floor_i, "C"):
		var k := "%d,%d" % [c.y, c.x]
		if not (o.chests as Array).has(k): out.append({"kind": "chest", "cell": c, "prompt": "Open", "name": "Chest", "key": k})
	for c in DungeonMaps.find_all(floor_i, "L"):
		out.append({"kind": "lever", "cell": c, "prompt": "Pull", "name": "Lever" if not bool(o.G) else "Lever (pulled)"})
	for c in DungeonMaps.find_all(floor_i, "D"):
		if not bool(o.D): out.append({"kind": "door", "cell": c, "prompt": "Unlock" if keys.has(str(fdef.id)) else "Look", "name": "Locked door"})
	for c in DungeonMaps.find_all(floor_i, "G"):
		if not bool(o.G): out.append({"kind": "gate", "cell": c, "prompt": "Look", "name": "Portcullis"})
	for c in DungeonMaps.find_all(floor_i, "K"):
		if not bool(o.K): out.append({"kind": "guardian", "cell": c, "prompt": "Face", "name": str(BossDefs.get_def(str(fdef.guardian)).get("name", "Guardian"))})
	for c in DungeonMaps.find_all(floor_i, "d"):
		if not bool(o.get("d", false)): out.append({"kind": "side", "cell": c, "prompt": "Unlock" if DungeonGate.flag(str(fdef.get("side_flag", ""))) else "Look", "name": "Side door"})
	for c in DungeonMaps.find_all(floor_i, "P"):
		out.append({"kind": "shrine", "cell": c, "prompt": "Rest", "name": "Ember shrine"})
	var bd: Array = DungeonMaps.find_all(floor_i, "B")
	if not bd.is_empty():
		out.append({"kind": "boss", "cell": bd[bd.size() / 2], "prompt": "Leave" if cleared else "Enter", "name": "The Unlit Throne" if not cleared else "The way up"})
	return out

func _update_near() -> void:
	var best: Dictionary = {}
	var bd := 1e9
	for u in usables():
		var cs: Array = [u.cell]
		if u.kind == "boss": cs = DungeonMaps.find_all(floor_i, "B")
		for c in cs:
			var d: float = pos.distance_to(cell_center(c) + Vector2(0, 8))
			if d < TILE * 1.35 and d < bd: bd = d; best = u
	if best.get("cell", null) != near.get("cell", null) or best.get("prompt", "") != near.get("prompt", ""):
		near = best
		var has := not near.is_empty()
		use_btn.disabled = not has
		use_btn.text = str(near.prompt) if has else "Use"
		if has and not dialog.visible:
			hint_label.text = "%s  ·  %s" % [near.prompt, near.name]
			AfTheme.pop_in(hint, reduced_motion)
		else:
			AfTheme.pop_out(hint, reduced_motion)

func use(u: Dictionary) -> void:
	if u.is_empty() or busy or _modal_open(): return
	var o := fopen()
	match str(u.kind):
		"chest":
			var cd: Dictionary = (fdef.chests as Dictionary).get(str(u.key), {"gold": 25, "text": "A few coins."})
			(o.chests as Array).append(str(u.key))
			gold += int(cd.get("gold", 0))
			if float(cd.get("heal", 0.0)) > 0.0: hp = mini(hp_max, hp + int(hp_max * float(cd.heal)))
			if bool(cd.get("key", false)): keys[str(fdef.id)] = true
			_burst(cell_center(u.cell), Color(1.0, 0.8, 0.4))
			save_game()
			say("Chest", str(cd.text))
		"lever":
			if bool(o.G):
				say("Lever", "It's already down. The way is open.")
			else:
				o.G = true
				_refresh_astar(); save_game()
				for g in DungeonMaps.find_all(floor_i, "G"): _burst(cell_center(g), Color(0.9, 0.85, 0.7))
				say("Lever", str(fdef.get("lever_text", "Something opens.")))
		"door":
			if keys.has(str(fdef.id)):
				o.D = true
				_refresh_astar(); save_game()
				_burst(cell_center(u.cell), Color(1.0, 0.7, 0.35))
				say("Locked door", "The %s turns. The door swings inward." % str(fdef.get("key", "key")))
			else:
				say("Locked door", str(fdef.get("door_text", "Locked.")))
		"gate":
			say("Portcullis", "Iron bars, rusted shut. There must be a lever somewhere on this floor.")
		"shrine":
			hp = hp_max; meter = 0.0
			save_game()
			_burst(cell_center(u.cell), Color(0.6, 0.9, 1.0))
			say("Ember shrine", "Warm light washes over the party. HP restored, and your progress is saved.\nBeyond the sealed door, something vast is breathing.")
		"guardian":
			_face_guardian()
		"side":
			if DungeonGate.flag(str(fdef.get("side_flag", ""))):
				o["d"] = true
				_refresh_astar(); save_game()
				_burst(cell_center(u.cell), Color(0.7, 0.95, 0.9))
				var st := DungeonGate.story()
				if st != null and not DungeonGate.flag(str(fdef.guardian_flag)): st.start_dialog("f1_skip", func(): _refresh_astar())
				else: say("Side door", "The Reliquary Key turns. The side door opens onto a dry stair around the guardian.")
			else:
				say("Side door", "A narrow door in the wall, sealed with a reliquary lock. Someone in Emberhold might know its key.")
		"shrine":
			hp = hp_max; meter = 0.0
			save_game()
			_burst(cell_center(u.cell), Color(0.6, 0.9, 1.0))
			say("Ember shrine", "Warm light washes over the party. HP restored, and your progress is saved.\nBeyond the black-glass doors, something is breathing.")
		"boss":
			_face_throne()

## Floor guardian: the story's dialog + fight (or Bosses on its own). The bound drowned court clears floor 2's.
func _face_guardian() -> void:
	var gid := str(fdef.get("guardian", ""))
	var st := DungeonGate.story()
	save_game()
	if st != null:
		if str(fdef.get("bind_flag", "")) != "" and DungeonGate.flag(str(fdef.bind_flag)):
			st.start_dialog("f2_bind", func(): _refresh_astar())
		else:
			st.start_dialog("f1_enter" if floor_i == 0 else "f2_enter", func(): _story_fight(gid))
		return
	var gd: Dictionary = BossDefs.get_def(gid)
	say_seq([[str(gd.name), "\u201c" + str(BossDefs.lines(gid).intro) + "\u201d"]], [["Fight", func(): _start_boss(gid)], ["Not yet", func(): pass]])

## The throne room: the story's final sequence (both final phases chain from "final_confront"), or Bosses alone.
func _face_throne() -> void:
	var st := DungeonGate.story()
	if cleared:
		say("The way up", "The Bastion is quiet. Go back up to Emberhold?", [["Go up", func(): DungeonGate.leave(get_tree())], ["Stay", func(): pass]])
		return
	save_game()
	var first := not DungeonGate.flag("boss1_won")
	if st != null:
		st.start_dialog("final_confront" if first else "sovereign_intro")
		return
	var id: String = DungeonGate.FIRST_BOSS if first else DungeonGate.FINAL_BOSS
	var pre: Array = [["The Unlit Throne", "Black-glass doors, warm to the touch. They open at your hand."],
		[str(BossDefs.get_def(id).name), "\u201c" + str(BossDefs.lines(id).intro) + "\u201d"]]
	say_seq(pre, [["Enter", func(): _start_boss(id)], ["Not yet", func(): pass]])

func _story_fight(id: String) -> void:
	busy = true
	save_game()
	await _fade(1.0)
	var st := DungeonGate.story()
	if st != null: st.start_battle(id)

func _check_step_triggers() -> void:
	var ch := DungeonMaps.at(floor_i, cell_of(pos))
	match ch:
		">":
			_change_floor(floor_i + 1, "<")
		"<":
			if floor_i > 0: _change_floor(floor_i - 1, ">")
		"S":
			if cell_of(pos).y >= DungeonMaps.find(floor_i, "S").y and pos.y > cell_center(DungeonMaps.find(floor_i, "S")).y + 6.0:
				busy = true
				save_game()
				await _fade(1.0)
				DungeonGate.leave(get_tree())

func _change_floor(i: int, arrive: String) -> void:
	busy = true
	await _fade(1.0)
	var c: Vector2i = DungeonMaps.find(i, arrive)
	var f2 := DungeonMaps.floor_def(i)
	fdef = f2
	floor_i = i
	# arrive one step off the stairs
	var at := cell_center(c)
	for d in [Vector2(0, TILE), Vector2(0, -TILE), Vector2(TILE, 0), Vector2(-TILE, 0)]:
		if DungeonMaps.walkable(i, cell_of(at + d), fopen()) and DungeonMaps.at(i, cell_of(at + d)) == ".": at += d; break
	load_floor(i, at)
	save_game()
	await _fade(0.0)
	busy = false

func _start_battle() -> void:
	meter = 0.0
	save_game()
	var en := get_node_or_null("/root/Encounters")
	var qf := get_node_or_null("/root/QuestFlow")
	if en == null or not en.has_battle_listener():
		toast_msg("Something stirs in the dark... (no battle scene connected)")
		return
	busy = true
	if qf != null: qf.return_scene = DungeonGate.SCENE
	await _fade(1.0)
	en.start_random_battle(str(fdef.id))

func _start_boss(id: String) -> void:
	busy = true
	save_game()
	await _fade(1.0)
	var bs := get_node_or_null("/root/Bosses")
	if bs != null: bs.start_boss(id, DungeonGate.SCENE)

## Bosses (no Story): record the flag the story would set, then the next beat.
func _on_boss_defeated(id: String) -> void:
	if DungeonGate.story() != null: return # the story plays its own after-fight dialog here
	var flag_of := {"guardian_f1": "bastion_f1", "guardian_f2": "bastion_f2", "boss_regnant": "boss1_won", "boss_sovereign": "boss2_won"}
	if flag_of.has(id): DungeonGate.set_flag(flag_of[id])
	_refresh_astar()
	_load_hp()
	if id == DungeonGate.FIRST_BOSS:
		say_seq([[str(BossDefs.get_def(id).name), "\u201c" + str(BossDefs.lines(id).victory) + "\u201d"],
			["The Unlit Throne", "The floor splits open. Far below, something vast opens one grey eye."]], [], func(): _face_throne())
		return
	if id != DungeonGate.FINAL_BOSS:
		say(str(BossDefs.get_def(id).name), "\u201c" + str(BossDefs.lines(id).victory) + "\u201d")
		return
	cleared = true
	_load_hp()
	save_game()
	load_floor(2, cell_center(DungeonMaps.find(2, "B")) + Vector2(0, TILE * 1.6))
	var ln: Dictionary = BossDefs.lines(id)
	say_seq([[str(BossDefs.get_def(id).name), "\u201c" + str(ln.get("victory", "")) + "\u201d"],
		["The Unlit Throne", "The Sovereign comes apart like a burned-out log, and the Bastion goes quiet. The Heart-Coal is warm in your hand."]], [], func(): _show_end_card())

func _on_boss_failed(id: String) -> void:
	if DungeonGate.story() != null: return
	_load_hp()
	if not id.begins_with("boss_"):
		say("The Bastion", "The party falls back, singed but breathing. Rest at a shrine, then face it again.")
		return
	var p: Vector2i = DungeonMaps.find(2, "P")
	load_floor(2, cell_center(p) + Vector2(0, TILE))
	say("Ember shrine", "The party wakes at the shrine, singed but breathing. Rest, then try the door again.")

func _load_hp() -> void:
	var kf := ConfigFile.new()
	if kf.load(DungeonGate.KINGDOM_SAVE) == OK:
		hp = int(kf.get_value("kingdom", "hp", hp)); hp_max = int(kf.get_value("kingdom", "hp_max", hp_max))

var fx: Array = []
func _burst(p: Vector2, c: Color) -> void:
	fx.append({"p": p, "t": 0.0, "c": c})

# ---------------------------------------------------------------- input
func _modal_open() -> bool:
	var st := DungeonGate.story()
	return dialog.visible or menu.visible or end_card.visible or (st != null and st.has_method("ui_open") and bool(st.ui_open()))

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		match e.physical_keycode:
			KEY_E, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
				if dialog.visible: _dialog_advance()
				elif not _modal_open(): use(near)
				get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				if menu.visible: AfTheme.pop_out(menu, reduced_motion)
				else: AfTheme.pop_in(menu, reduced_motion)
	var press := false
	var release := false
	var ppos := Vector2.ZERO
	if e is InputEventScreenTouch:
		press = e.pressed; release = not e.pressed; ppos = e.position
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		press = e.pressed; release = not e.pressed; ppos = e.position
	if press:
		if dialog.visible: _dialog_advance(); return
		if _modal_open() or busy: return
		drag_from = ppos; drag_vec = Vector2.ZERO
	elif release and drag_from != null:
		if drag_vec.length() < 18.0:
			var wp := get_canvas_transform().affine_inverse() * ppos
			# tap a usable thing you're next to: use it; else walk there
			var c := cell_of(wp)
			if not near.is_empty() and (near.cell == c or (near.kind == "boss" and DungeonMaps.at(floor_i, c) == "B")): use(near)
			else: walk_to(wp)
		drag_from = null; drag_vec = Vector2.ZERO
	if (e is InputEventScreenDrag or e is InputEventMouseMotion) and drag_from != null:
		drag_vec = e.position - drag_from

# ---------------------------------------------------------------- drawing
func _draw() -> void:
	var sz := DungeonMaps.size(floor_i)
	var o := fopen()
	var tint: Color = fdef.tint
	# floor + lava
	for y in sz.y:
		for x in sz.x:
			var c := Vector2i(x, y)
			var ch := DungeonMaps.at(floor_i, c)
			var r := Rect2(Vector2(c) * TILE, Vector2(TILE, TILE))
			if ch == "#": continue
			if ch == "~" or ch == "=":
				_draw_lava(r, c)
				if ch == "=": _draw_bridge(r)
				continue
			var v: float = 0.92 + 0.08 * float(hash(c) % 100) / 100.0
			draw_texture_rect_region(ground, r, Rect2(fposmod(x * 48.0, 96.0), fposmod(y * 48.0, 96.0), 48, 48), Color(tint.r * v, tint.g * v, tint.b * v))
			if ch == ",":
				for k in 4:
					var hh: int = hash(c * 7 + Vector2i(k, k * 3))
					draw_circle(r.position + Vector2(8 + hh % 32, 10 + (hh / 32) % 30), 2.0 + float(hh % 3), Color(0.12, 0.09, 0.08, 0.8))
	# soft occlusion on floor cells next to walls
	for y in sz.y:
		for x in sz.x:
			var c2 := Vector2i(x, y)
			if DungeonMaps.at(floor_i, c2) == "#": continue
			var p := Vector2(c2) * TILE
			if DungeonMaps.at(floor_i, c2 + Vector2i(0, -1)) == "#":
				draw_rect(Rect2(p, Vector2(TILE, 14)), Color(0, 0, 0, 0.32))
				draw_rect(Rect2(p, Vector2(TILE, 6)), Color(0, 0, 0, 0.28))
			if DungeonMaps.at(floor_i, c2 + Vector2i(-1, 0)) == "#": draw_rect(Rect2(p, Vector2(8, TILE)), Color(0, 0, 0, 0.22))
			if DungeonMaps.at(floor_i, c2 + Vector2i(1, 0)) == "#": draw_rect(Rect2(p + Vector2(TILE - 8, 0), Vector2(8, TILE)), Color(0, 0, 0, 0.22))
	# y-sorted: walls, props, hero
	var list: Array = []
	for y in sz.y:
		for x in sz.x:
			var c3 := Vector2i(x, y)
			var ch3 := DungeonMaps.at(floor_i, c3)
			if ch3 == "#" or "bpsCLGDPB<>SKd".contains(ch3): list.append([float(y) * TILE + TILE, c3, ch3])
	list.append([pos.y, null, "hero"])
	list.sort_custom(func(a, b): return a[0] < b[0])
	for it in list:
		if it[2] == "hero": _draw_hero()
		else: _draw_cell(it[1], it[2], o)
	# bursts
	for i in range(fx.size() - 1, -1, -1):
		var f: Dictionary = fx[i]
		f.t = float(f.t) + get_process_delta_time()
		var k: float = float(f.t) / 0.7
		if k >= 1.0: fx.remove_at(i); continue
		var col: Color = f.c
		draw_arc(f.p + Vector2(0, -10), 10.0 + 50.0 * k, 0, TAU, 32, Color(col.r, col.g, col.b, 0.8 * (1.0 - k)), 3.0)
		for j in 8:
			var a := TAU * float(j) / 8.0 + float(f.t)
			draw_circle(f.p + Vector2(cos(a), sin(a) * 0.6) * (14.0 + 46.0 * k) + Vector2(0, -16), 2.5 * (1.0 - k), Color(col.r, col.g, col.b, 1.0 - k))
	# tap-to-walk target
	if not path.is_empty():
		var tp: Vector2 = path[path.size() - 1]
		draw_arc(tp, 10.0 + sin(t_now * 8.0) * 2.0, 0, TAU, 24, Color(AfTheme.GOLD.r, AfTheme.GOLD.g, AfTheme.GOLD.b, 0.6), 2.0)

func _draw_lava(r: Rect2, c: Vector2i) -> void:
	var t := t_now if not reduced_motion else 0.0
	if str(fdef.get("liquid", "lava")) == "water":
		_draw_water(r, c, t); return
	draw_rect(r, Color(0.2, 0.04, 0.02))
	# slow molten blobs + thin bright seams
	for k in 2:
		var cx: float = r.position.x + fposmod(float(hash(c + Vector2i(k, 0)) % 48) + t * (8.0 + k * 5.0), TILE)
		var cy: float = r.position.y + 12.0 + k * 22.0 + sin(t * 1.3 + c.x + k) * 4.0
		_ellipse(Vector2(cx, cy), 14.0, 7.0, Color(0.85, 0.28, 0.06, 0.55))
		_ellipse(Vector2(cx, cy), 7.0, 3.5, Color(1.0, 0.62, 0.2, 0.6 + 0.2 * sin(t * 3.0 + k)))
	for k in 2:
		var yy: float = r.position.y + 16.0 + k * 18.0 + sin(t * 1.6 + c.x * 0.9 + k) * 3.0
		draw_line(Vector2(r.position.x, yy), Vector2(r.end.x, yy + sin(c.x + k) * 4.0), Color(1.0, 0.55, 0.18, 0.35 + 0.15 * sin(t * 2.0 + c.y + k)), 1.5)
	# dark crust where the lava meets rock
	for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		var nb := DungeonMaps.at(floor_i, c + d)
		if nb != "~" and nb != "=":
			var e := Rect2(r.position, Vector2(TILE, 5))
			if d.y > 0: e = Rect2(r.position + Vector2(0, TILE - 5), Vector2(TILE, 5))
			elif d.x < 0: e = Rect2(r.position, Vector2(5, TILE))
			elif d.x > 0: e = Rect2(r.position + Vector2(TILE - 5, 0), Vector2(5, TILE))
			draw_rect(e, Color(0.08, 0.05, 0.04, 0.9))
			draw_rect(e.grow(-1.5), Color(1.0, 0.5, 0.15, 0.25))

## Black water (the Drowned Gate): dark, slow ripples, a pale glint, a wet rim on the stone.
func _draw_water(r: Rect2, c: Vector2i, t: float) -> void:
	draw_rect(r, Color(0.03, 0.07, 0.09))
	for k in 2:
		var cx: float = r.position.x + fposmod(float(hash(c + Vector2i(k, 3)) % 48) + t * (5.0 + k * 3.0), TILE)
		var cy: float = r.position.y + 14.0 + k * 20.0 + sin(t * 0.9 + c.x + k) * 3.0
		_ellipse(Vector2(cx, cy), 15.0, 6.0, Color(0.1, 0.22, 0.26, 0.6))
	for k in 2:
		var yy: float = r.position.y + 12.0 + k * 22.0 + sin(t * 1.1 + c.x * 0.7 + k) * 2.5
		draw_line(Vector2(r.position.x + 4, yy), Vector2(r.end.x - 4, yy + sin(c.y + k) * 3.0), Color(0.55, 0.85, 0.9, 0.12 + 0.08 * sin(t * 1.7 + c.y + k)), 1.2)
	for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		var nb := DungeonMaps.at(floor_i, c + d)
		if nb != "~" and nb != "=":
			var e := Rect2(r.position, Vector2(TILE, 4))
			if d.y > 0: e = Rect2(r.position + Vector2(0, TILE - 4), Vector2(TILE, 4))
			elif d.x < 0: e = Rect2(r.position, Vector2(4, TILE))
			elif d.x > 0: e = Rect2(r.position + Vector2(TILE - 4, 0), Vector2(4, TILE))
			draw_rect(e, Color(0.05, 0.06, 0.07, 0.9))
			draw_rect(e.grow(-1.0), Color(0.5, 0.8, 0.85, 0.12))

func _draw_bridge(r: Rect2) -> void:
	draw_rect(Rect2(r.position + Vector2(0, 8), Vector2(TILE, TILE - 16)), Color(0.24, 0.2, 0.18))
	for k in 4:
		draw_rect(Rect2(r.position + Vector2(2 + k * 12, 10), Vector2(10, TILE - 20)), Color(0.36, 0.3, 0.26))
	draw_line(r.position + Vector2(0, 8), r.position + Vector2(TILE, 8), Color(0.1, 0.08, 0.07), 2.0)
	draw_line(r.position + Vector2(0, TILE - 8), r.position + Vector2(TILE, TILE - 8), Color(0.1, 0.08, 0.07), 2.0)

func _draw_wall(c: Vector2i) -> void:
	var p := Vector2(c) * TILE
	var below_open: bool = DungeonMaps.at(floor_i, c + Vector2i(0, 1)) != "#"
	var wt: Texture2D = tex.get("t_wall")
	var top := Rect2(p, Vector2(TILE, TILE - (WALL_H if below_open else 0.0)))
	var tint: Color = fdef.tint
	if wt != null: draw_texture_rect(wt, top, true, Color(0.42 * tint.r, 0.4 * tint.g, 0.42 * tint.b))
	else: draw_rect(top, Color(0.16, 0.14, 0.13))
	# dark cap so the maze reads as solid rock; lit rim where it meets the floor
	draw_rect(top, Color(0.04, 0.03, 0.03, 0.45))
	if below_open:
		var fr := Rect2(p + Vector2(0, TILE - WALL_H), Vector2(TILE, WALL_H))
		if wt != null: draw_texture_rect(wt, fr, true, Color(0.62 * tint.r, 0.56 * tint.g, 0.52 * tint.b))
		else: draw_rect(fr, Color(0.26, 0.22, 0.2))
		draw_rect(Rect2(fr.position, Vector2(TILE, 3)), Color(1.0, 0.62, 0.32, 0.35))
		draw_rect(Rect2(fr.position + Vector2(0, WALL_H - 4), Vector2(TILE, 4)), Color(0, 0, 0, 0.35))
	for d in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1)]:
		if DungeonMaps.at(floor_i, c + d) != "#":
			var e: Rect2
			if d.x < 0: e = Rect2(p, Vector2(2, top.size.y))
			elif d.x > 0: e = Rect2(p + Vector2(TILE - 2, 0), Vector2(2, top.size.y))
			else: e = Rect2(p, Vector2(TILE, 2))
			draw_rect(e, Color(AfTheme.GOLD_DARK.r, AfTheme.GOLD_DARK.g, AfTheme.GOLD_DARK.b, 0.35))

func _sprite(t: Texture2D, foot: Vector2, h: float, mod := Color.WHITE) -> void:
	if t == null: return
	var sc := h / float(t.get_height())
	var w := float(t.get_width()) * sc
	draw_texture_rect(t, Rect2(foot.x - w / 2.0, foot.y - h, w, h), false, mod)

func _shadow(p: Vector2, w: float, a: float = 0.45) -> void:
	for i in 3:
		var k := 1.0 - i * 0.25
		_ellipse(p, w * 0.5 * k, w * 0.16 * k, Color(0, 0, 0, a * 0.4))

func _ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * float(i) / 20.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)

func _draw_cell(c: Vector2i, ch: String, o: Dictionary) -> void:
	var foot := cell_center(c) + Vector2(0, TILE * 0.32)
	match ch:
		"#": _draw_wall(c)
		"b":
			_shadow(foot, 34)
			_sprite(tex.get("brazier"), foot, 66)
			_flame(foot + Vector2(0, -58), 0.42)
		"p":
			_shadow(foot, 34)
			_sprite(tex.get("pillar"), foot, 86, Color(0.85, 0.8, 0.78))
		"s":
			_shadow(foot, 36)
			_sprite(tex.get("knight_statue"), foot, 80, Color(0.75, 0.72, 0.78))
		"C":
			var opened: bool = (o.chests as Array).has("%d,%d" % [c.y, c.x])
			_shadow(foot, 44)
			_sprite(tex.get("chest"), foot + Vector2(0, 2), 44, Color(0.55, 0.5, 0.48) if opened else Color.WHITE)
			if not opened and not reduced_motion:
				var gl: float = 0.5 + 0.5 * sin(t_now * 3.0)
				_ellipse(foot + Vector2(0, -18), 26.0 + gl * 4.0, 18.0, Color(1.0, 0.75, 0.35, 0.06 + 0.05 * gl))
		"L":
			var down: bool = bool(o.G)
			var base := foot + Vector2(0, -6)
			_shadow(foot, 26)
			draw_rect(Rect2(base + Vector2(-14, -10), Vector2(28, 12)), Color(0.22, 0.19, 0.17))
			draw_rect(Rect2(base + Vector2(-14, -10), Vector2(28, 3)), Color(0.45, 0.38, 0.3))
			var tip := base + Vector2(-16, -30) if not down else base + Vector2(18, -18)
			draw_line(base + Vector2(0, -6), tip, Color(0.55, 0.47, 0.38), 4.0)
			draw_circle(tip, 5.0, AfTheme.EMBER if not down else Color(0.5, 0.42, 0.34))
		"G":
			if bool(o.G):
				var p0 := Vector2(c) * TILE
				draw_rect(Rect2(p0 + Vector2(0, 0), Vector2(TILE, 6)), Color(0.3, 0.27, 0.24))
				for k in 5: draw_line(p0 + Vector2(5 + k * 9.5, 0), p0 + Vector2(5 + k * 9.5, 8), Color(0.42, 0.38, 0.34), 3.0)
			else:
				var p1 := Vector2(c) * TILE
				for k in 5: draw_line(p1 + Vector2(5 + k * 9.5, -WALL_H), p1 + Vector2(5 + k * 9.5, TILE - 4), Color(0.38, 0.35, 0.32), 3.5)
				for k in 3: draw_line(p1 + Vector2(0, 4 + k * 14), p1 + Vector2(TILE, 4 + k * 14), Color(0.3, 0.27, 0.25), 3.0)
		"D":
			var p2 := Vector2(c) * TILE
			if bool(o.D):
				draw_rect(Rect2(p2 + Vector2(-4, -WALL_H), Vector2(8, TILE + WALL_H - 6)), Color(0.3, 0.2, 0.13))
			else:
				var dr := Rect2(p2 + Vector2(3, -WALL_H), Vector2(TILE - 6, TILE + WALL_H - 6))
				draw_rect(dr, Color(0.33, 0.21, 0.12))
				for k in 4: draw_line(dr.position + Vector2(4 + k * 10, 2), dr.position + Vector2(4 + k * 10, dr.size.y - 2), Color(0.22, 0.13, 0.08), 2.0)
				for yy in [10.0, dr.size.y - 14.0]: draw_rect(Rect2(dr.position + Vector2(0, yy), Vector2(dr.size.x, 5)), Color(0.42, 0.4, 0.38))
				var kc := dr.get_center() + Vector2(0, 6)
				draw_circle(kc, 6.0, Color(0.05, 0.03, 0.02))
				_flame(kc + Vector2(0, 2), 0.16)
		"P":
			_shadow(foot, 40)
			_sprite(tex.get("shrine"), foot, 72, Color(0.85, 0.9, 1.0))
			_flame(foot + Vector2(0, -60), 0.5, Color(0.6, 0.9, 1.0))
			if not reduced_motion:
				var gl2: float = 0.5 + 0.5 * sin(t_now * 2.2)
				draw_arc(foot + Vector2(0, -4), 30.0 + gl2 * 4.0, 0, TAU, 32, Color(0.6, 0.9, 1.0, 0.25 + 0.2 * gl2), 2.0)
		"B": _draw_boss_door(c)
		"K":
			if not bool(o.K):
				var gt: Texture2D = tex.get("foe_" + str(fdef.get("guardian_art", "")))
				_shadow(foot, 46, 0.55)
				var bob: float = 0.0 if reduced_motion else sin(t_now * 2.0) * 1.5
				if gt != null: _sprite(gt, foot + Vector2(0, bob), 92, Color(0.95, 0.9, 0.95))
				var col := Color(BossDefs.get_def(str(fdef.guardian)).get("color", "#ffffff"))
				if not reduced_motion: draw_arc(foot + Vector2(0, -2), 30.0 + sin(t_now * 3.0) * 3.0, 0, TAU, 32, Color(col.r, col.g, col.b, 0.35), 2.0)
		"d":
			var pd := Vector2(c) * TILE
			if bool(o.get("d", false)):
				draw_rect(Rect2(pd + Vector2(-3, -WALL_H), Vector2(6, TILE + WALL_H - 6)), Color(0.25, 0.22, 0.2))
			else:
				var dd := Rect2(pd + Vector2(6, -WALL_H + 4), Vector2(TILE - 12, TILE + WALL_H - 10))
				draw_rect(dd, Color(0.2, 0.19, 0.2))
				draw_rect(dd.grow(-3), Color(0.27, 0.26, 0.28))
				draw_circle(dd.get_center(), 5.0, Color(0.7, 0.95, 0.9, 0.5 + 0.3 * sin(t_now * 2.4)))
		">", "<", "S":
			var p3 := Vector2(c) * TILE
			var st: Texture2D = tex.get("stairs")
			if st != null:
				draw_texture_rect(st, Rect2(p3 + Vector2(2, 2), Vector2(TILE - 4, TILE - 4)), false, Color(0.75, 0.7, 0.66) if ch != ">" else Color(0.55, 0.5, 0.48))
			var lab := "DOWN" if ch == ">" else ("UP" if ch == "<" else "EXIT")
			var f: Font = AfTheme.get_theme().default_font
			if f != null:
				draw_string(f, p3 + Vector2(0, -4), lab, HORIZONTAL_ALIGNMENT_CENTER, TILE, 11, Color(AfTheme.GOLD.r, AfTheme.GOLD.g, AfTheme.GOLD.b, 0.8))

func _draw_boss_door(c: Vector2i) -> void:
	var cells: Array = DungeonMaps.find_all(floor_i, "B")
	if cells.is_empty() or c != cells[0]: return
	var p := Vector2(cells[0]) * TILE
	var w := TILE * float(cells.size())
	var r := Rect2(p + Vector2(0, -TILE * 0.9), Vector2(w, TILE * 1.85))
	if cleared:
		# open: a warm portal home
		draw_rect(r, Color(0.06, 0.04, 0.03))
		var gl: float = 0.5 + 0.5 * sin(t_now * 2.0)
		for i in 5:
			_ellipse(r.get_center(), w * (0.42 - i * 0.07), r.size.y * (0.42 - i * 0.07), Color(1.0, 0.75, 0.4, 0.12 + 0.04 * gl))
		return
	draw_rect(r, Color(0.14, 0.07, 0.05))
	var half := Rect2(r.position + Vector2(4, 4), Vector2(w / 2.0 - 6, r.size.y - 4))
	for k in 2:
		var hr := Rect2(half.position + Vector2(k * (w / 2.0 - 2), 0), half.size)
		draw_rect(hr, Color(0.28, 0.13, 0.08))
		for yy in [14.0, hr.size.y * 0.5, hr.size.y - 16.0]:
			draw_rect(Rect2(hr.position + Vector2(0, yy), Vector2(hr.size.x, 5)), Color(0.5, 0.36, 0.22))
	var sc := r.get_center() + Vector2(0, -6)
	var pulse: float = 0.5 + 0.5 * sin(t_now * 2.6)
	draw_arc(sc, 16.0, 0, TAU, 32, Color(1.0, 0.5, 0.25, 0.6 + 0.4 * pulse), 2.5)
	_flame(sc + Vector2(0, 10), 0.3)
	draw_rect(Rect2(r.position, Vector2(w, 3)), Color(1.0, 0.55, 0.3, 0.6))

func _flame(p: Vector2, s: float, mod := Color.WHITE) -> void:
	var ft: Texture2D = tex.get("flame")
	if ft == null: return
	var n := 7
	var fr: int = 0 if reduced_motion else int(t_now * 12.0 + p.x) % n
	var fw := 128.0
	draw_texture_rect_region(ft, Rect2(p.x - fw * s / 2.0, p.y - fw * s * 0.82, fw * s, fw * s), Rect2(fr * fw, 0, fw, 128), mod)

func _draw_hero() -> void:
	var t: Texture2D = tex.get("hero")
	var bob := 0.0
	if walking and not reduced_motion: bob = absf(sin(t_now * 11.0)) * 4.0
	elif not reduced_motion: bob = sin(t_now * 2.2) * 0.8
	_shadow(pos, 40.0 - bob * 2.0, 0.55)
	if t == null:
		draw_circle(pos + Vector2(0, -30), 16, AfTheme.EMBER); return
	var h := 74.0
	var sc := h / float(t.get_height())
	var w := float(t.get_width()) * sc
	var dst := Rect2(pos.x - w / 2.0, pos.y - h - bob + 6.0, w, h)
	if facing < 0: dst = Rect2(pos.x + w / 2.0, dst.position.y, -w, h)
	draw_texture_rect(t, dst, false)

# ---------------------------------------------------------------- UI (Airron's Fall theme)
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	ui = Control.new()
	ui.theme = AfTheme.get_theme()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	# vignette
	vignette = TextureRect.new()
	var vg := GradientTexture2D.new()
	vg.fill = GradientTexture2D.FILL_RADIAL
	vg.fill_from = Vector2(0.5, 0.5); vg.fill_to = Vector2(1.05, 0.5)
	var gr := Gradient.new()
	gr.set_color(0, Color(0, 0, 0, 0)); gr.set_color(1, Color(0, 0, 0, 0.72))
	gr.add_point(0.6, Color(0, 0, 0, 0.12))
	vg.gradient = gr
	vignette.texture = vg
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(vignette)
	# location card: floor, HP, gold, danger meter
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.position = Vector2(12, 12)
	ui.add_child(card)
	var lc := VBoxContainer.new()
	lc.add_theme_constant_override("separation", 3)
	card.add_child(lc)
	loc_name = Label.new(); loc_name.theme_type_variation = "HeaderLabel"; loc_name.add_theme_font_size_override("font_size", 17)
	lc.add_child(loc_name)
	loc_sub = Label.new(); loc_sub.theme_type_variation = "MutedLabel"; loc_sub.add_theme_font_size_override("font_size", 12)
	lc.add_child(loc_sub)
	var hr := HBoxContainer.new(); lc.add_child(hr)
	var hl := Label.new(); hl.text = "HP"; hl.theme_type_variation = "MutedLabel"; hr.add_child(hl)
	hp_bar = ProgressBar.new(); hp_bar.show_percentage = false; hp_bar.custom_minimum_size = Vector2(100, 14)
	hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL; hp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hr.add_child(hp_bar)
	gold_label = Label.new(); gold_label.add_theme_color_override("font_color", AfTheme.GOLD); hr.add_child(gold_label)
	var dr := HBoxContainer.new(); lc.add_child(dr)
	var dl := Label.new(); dl.text = "Danger"; dl.theme_type_variation = "MutedLabel"; dr.add_child(dl)
	danger_bar = ProgressBar.new(); danger_bar.theme_type_variation = "DangerBar"; danger_bar.show_percentage = false
	danger_bar.custom_minimum_size = Vector2(110, 14); danger_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	danger_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dr.add_child(danger_bar)
	menu_btn = _button("Menu", func(): AfTheme.pop_in(menu, reduced_motion))
	menu_btn.custom_minimum_size = Vector2(84, 44)
	ui.add_child(menu_btn)
	use_btn = _button("Use", func(): use(near), true)
	use_btn.add_theme_font_size_override("font_size", 22)
	use_btn.custom_minimum_size = Vector2(118, 64)
	use_btn.disabled = true
	ui.add_child(use_btn)
	hint = _panel("ToastPanel"); hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_label = Label.new(); hint.add_child(hint_label); hint.visible = false
	ui.add_child(hint)
	toast = _panel("ToastPanel"); toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_label = Label.new(); toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; toast.add_child(toast_label); toast.visible = false
	ui.add_child(toast)
	# floor banner
	banner = VBoxContainer.new(); banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_title = Label.new(); banner_title.theme_type_variation = "HeaderLabel"; banner_title.add_theme_font_size_override("font_size", 30)
	banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_sub = Label.new(); banner_sub.theme_type_variation = "FlavorLabel"; banner_sub.add_theme_font_size_override("font_size", 16)
	banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_child(banner_title); banner.add_child(banner_sub)
	ui.add_child(banner)
	# dialog
	dialog = _panel("FramedPanel")
	var dv := VBoxContainer.new(); dv.add_theme_constant_override("separation", 6); dialog.add_child(dv)
	dlg_name = Label.new(); dlg_name.theme_type_variation = "HeaderLabel"; dlg_name.add_theme_font_size_override("font_size", 18); dv.add_child(dlg_name)
	dlg_text = Label.new(); dlg_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; dlg_text.custom_minimum_size = Vector2(280, 0); dv.add_child(dlg_text)
	dlg_buttons = HBoxContainer.new(); dlg_buttons.alignment = BoxContainer.ALIGNMENT_END; dlg_buttons.add_theme_constant_override("separation", 8); dv.add_child(dlg_buttons)
	dialog.visible = false
	ui.add_child(dialog)
	# menu
	menu = _panel("FramedPanel")
	var mv := VBoxContainer.new(); mv.add_theme_constant_override("separation", 8); menu.add_child(mv)
	var mt := Label.new(); mt.text = "The Sunken Bastion"; mt.theme_type_variation = "HeaderLabel"; mv.add_child(mt)
	mv.add_child(_button("Resume", func(): AfTheme.pop_out(menu, reduced_motion), true))
	mv.add_child(_button("Leave the Bastion", func(): save_game(); DungeonGate.leave(get_tree())))
	menu.visible = false
	ui.add_child(menu)
	# end card (after the final boss)
	end_card = _panel("FramedPanel")
	var ev := VBoxContainer.new(); ev.add_theme_constant_override("separation", 8); end_card.add_child(ev)
	var et := Label.new(); et.text = "The Bastion Is Quiet"; et.theme_type_variation = "HeaderLabel"; et.add_theme_font_size_override("font_size", 26)
	et.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; ev.add_child(et)
	var es := Label.new(); es.theme_type_variation = "FlavorLabel"; es.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; es.custom_minimum_size = Vector2(300, 0)
	es.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	es.text = "The Ash Sovereign has fallen. Carry the Heart-Coal home: Emberhold's throne is going cold."
	ev.add_child(es)
	ev.add_child(_button("Return to Emberhold", func(): DungeonGate.leave(get_tree()), true))
	ev.add_child(_button("Stay a while", func(): AfTheme.pop_out(end_card, reduced_motion)))
	end_card.visible = false
	ui.add_child(end_card)
	fade = ColorRect.new(); fade.color = Color(0, 0, 0, 0); fade.set_anchors_preset(Control.PRESET_FULL_RECT); fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(fade)
	get_viewport().size_changed.connect(_layout)
	_layout()

func _panel(variation: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = variation
	return p

func _button(text: String, cb: Callable, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	if primary: b.theme_type_variation = "PrimaryButton"
	b.custom_minimum_size = Vector2(0, 44)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	AfTheme.add_press_juice(b, func(): return reduced_motion)
	return b

func _layout() -> void:
	var vs := get_viewport().get_visible_rect().size
	var port: bool = vs.y > vs.x
	var m := 12.0
	menu_btn.position = Vector2(vs.x - menu_btn.size.x - m, m)
	use_btn.position = Vector2(vs.x - use_btn.custom_minimum_size.x - m - 6.0, vs.y - use_btn.custom_minimum_size.y - m - (24.0 if port else 6.0))
	hint.position = Vector2(vs.x / 2.0 - 120.0, vs.y - (150.0 if port else 70.0))
	toast.custom_minimum_size = Vector2(minf(vs.x - 40.0, 420.0), 0)
	toast.position = Vector2((vs.x - toast.custom_minimum_size.x) / 2.0, vs.y * (0.62 if port else 0.66))
	banner.position = Vector2(0, vs.y * (0.24 if port else 0.2)); banner.size = Vector2(vs.x, 80)
	var dw: float = minf(vs.x - 24.0, 560.0)
	dialog.custom_minimum_size = Vector2(dw, 0)
	dialog.size = Vector2(dw, 0)
	dialog.position = Vector2((vs.x - dw) / 2.0, vs.y - (300.0 if port else 210.0))
	menu.position = Vector2(vs.x / 2.0 - 140.0, vs.y * 0.3); menu.custom_minimum_size = Vector2(280, 0)
	end_card.custom_minimum_size = Vector2(minf(vs.x - 24.0, 460.0), 0)
	end_card.position = Vector2((vs.x - end_card.custom_minimum_size.x) / 2.0, vs.y * 0.28)
	if embers != null: embers.emission_rect_extents = vs * 0.6
	if cam != null:
		var z: float = clampf(minf(vs.x, vs.y) / 560.0, 0.85, 1.45)
		cam.zoom = Vector2(z, z)

func _update_ui() -> void:
	loc_name.text = str(fdef.name)
	loc_sub.text = str(fdef.sub)
	hp_bar.max_value = hp_max; hp_bar.value = hp
	gold_label.text = "%d g" % gold

func _show_banner(t: String, s: String) -> void:
	banner_title.text = t; banner_sub.text = s
	banner_t = 0.0; banner.modulate.a = 0.0

func toast_msg(s: String, secs: float = 2.6) -> void:
	toast_label.text = s
	AfTheme.pop_in(toast, reduced_motion)
	toast_t = secs

func say(name: String, text: String, choices: Array = [], done: Callable = Callable()) -> void:
	say_seq([[name, text]], choices, done)

## A short dialog sequence: lines = [[speaker, text], ...]; choices on the last line: [[label, callable], ...].
func say_seq(lines: Array, choices: Array = [], done: Callable = Callable()) -> void:
	dlg_queue = lines.duplicate()
	dlg_done = done
	_dlg_choices = choices
	_dialog_next()
	_update_ui()

var _dlg_choices: Array = []
func _dialog_next() -> void:
	if dlg_queue.is_empty():
		AfTheme.pop_out(dialog, reduced_motion)
		if dlg_done.is_valid(): dlg_done.call()
		return
	var ln: Array = dlg_queue.pop_front()
	dlg_name.text = str(ln[0]); dlg_text.text = str(ln[1])
	for c in dlg_buttons.get_children(): c.queue_free()
	if dlg_queue.is_empty() and not _dlg_choices.is_empty():
		for ch in _dlg_choices:
			var cb: Callable = ch[1]
			dlg_buttons.add_child(_button(str(ch[0]), func(): AfTheme.pop_out(dialog, reduced_motion); dlg_queue = []; cb.call(), ch == _dlg_choices[0]))
	else:
		dlg_buttons.add_child(_button("Next" if not dlg_queue.is_empty() else "OK", func(): _dialog_advance(), true))
	if not dialog.visible: AfTheme.pop_in(dialog, reduced_motion)
	hint.visible = false

func _dialog_advance() -> void:
	if dlg_queue.is_empty() and not _dlg_choices.is_empty() and dlg_buttons.get_child_count() > 1: return
	_dialog_next()

func _show_end_card() -> void:
	AfTheme.pop_in(end_card, reduced_motion)

func _fade(to: float) -> void:
	if shots_mode or reduced_motion:
		fade.color.a = to; return
	var tw := create_tween()
	tw.tween_property(fade, "color:a", to, 0.35)
	await tw.finished
