extends Node2D
## World-space story layer inside the kingdom: story NPC actors (Airron's Fall hero or foe sprites), the "!" / "?"
## quest markers over people and places, a beacon on the current objective, and the recruited Wardens following
## the hero in a line (breadcrumb trail).

var story
var k
var followers: Array = []
var trail: Array = []       # recent player positions, newest first
const TRAIL_STEP := 10.0
const FOLLOW_GAP := 5        # trail points between followers
var _font: Font


class StoryActor extends Node2D:
	var k
	var art := "bramwell"
	var facing := 1.0
	var walking := false
	var follower := false
	var _tex: Texture2D
	var foe := false
	func setup(a: String) -> void:
		art = a
		foe = a.begins_with("foe:")
		var path := ("res://assets/af/foes/foe-%s.png" % a.substr(4)) if foe else ("res://assets/af/heroes/%s.png" % a)
		_tex = load(path) if ResourceLoader.exists(path) else null
	func _process(_d: float) -> void:
		queue_redraw()
	func _draw() -> void:
		var rm: bool = k.reduced_motion
		var t: float = k.t_now
		var bob := 0.0
		if walking and not rm: bob = absf(sin(t * 11.0 + position.x * 0.01)) * 4.0
		elif not rm: bob = sin(t * 2.2 + position.x) * 0.8
		KingdomView.soft_shadow(self, Vector2.ZERO, (60.0 if foe else 44.0) - bob * 2.0, 0.5)
		if _tex == null:
			draw_circle(Vector2(0, -30), 18, AfTheme.EMBER)
			return
		var h := 96.0 if foe else 78.0
		var sc := h / float(_tex.get_height())
		var w := float(_tex.get_width()) * sc
		var dst := Rect2(-w / 2.0, -h - bob + 6.0, w, h)
		if facing < 0: dst = Rect2(w / 2.0, dst.position.y, -w, h)
		if foe and not rm:
			var g := 0.5 + 0.5 * sin(t * 3.0)
			draw_circle(Vector2(0, -h * 0.45), h * 0.55, Color(AfTheme.CORAL, 0.10 + 0.06 * g))
		draw_texture_rect(_tex, dst, false, Color(1, 1, 1, 0.94) if follower else Color.WHITE)
		if not follower and k.near.get("node") == self:
			var y := -h - 16.0 - (0.0 if rm else absf(sin(t * 4.0)) * 4.0)
			draw_colored_polygon(PackedVector2Array([Vector2(-7, y - 8), Vector2(7, y - 8), Vector2(0, y)]), AfTheme.GOLD)


func _ready() -> void:
	z_index = 40
	_font = load("res://fonts/cinzel-700.woff2")


func make_actor(art: String, pos: Vector2) -> StoryActor:
	var a := StoryActor.new()
	a.k = k
	a.setup(art)
	a.position = pos
	a.facing = -1.0 if pos.x > k.player_pos.x else 1.0
	k.ysort.add_child(a)
	return a


## The kingdom freed every y-sorted node on load_map: rebuild the followers at the hero's spot.
func on_map_loaded() -> void:
	followers.clear()
	trail.clear()
	for i in 40: trail.append(k.player_pos)
	for id in story.recruited():
		if id == "bramwell": continue
		var a := make_actor(str(id), k.player_pos)
		a.follower = true
		followers.append(a)


func _process(_d: float) -> void:
	if k == null or not is_instance_valid(k): return
	# Wardens who joined mid-map
	var want: Array = story.recruited().filter(func(x): return x != "bramwell")
	if want.size() != followers.size():
		for f in followers: if is_instance_valid(f): f.queue_free()
		on_map_loaded()
	var pp: Vector2 = k.player_pos
	if trail.is_empty() or pp.distance_to(trail[0]) >= TRAIL_STEP:
		trail.push_front(pp)
		if trail.size() > 60: trail.pop_back()
	for i in followers.size():
		var f = followers[i]
		if not is_instance_valid(f): continue
		var idx := mini((i + 1) * FOLLOW_GAP, trail.size() - 1)
		var target: Vector2 = trail[idx]
		var d: Vector2 = target - f.position
		f.walking = d.length() > 1.0
		if absf(d.x) > 0.5: f.facing = signf(d.x)
		f.position = f.position.lerp(target, 0.35)
	queue_redraw()


func _draw() -> void:
	if k == null: return
	var t: float = 0.0 if k.reduced_motion else k.t_now
	for u in k.usables:
		if str(u.get("action", "")) != "story": continue
		var m: String = story.marker_for(u)
		if m == "": continue
		var p: Vector2 = u.pos
		var top := -118.0 if str(u.get("kind", "")) == "npc" else -70.0
		if u.has("node") and is_instance_valid(u.node) and u.node is StoryActor and u.node.foe: top = -136.0
		_bubble(p + Vector2(0, top - absf(sin(t * 3.2 + p.x * 0.01)) * 6.0), m)
	# Objective beacon on this map
	var o: Dictionary = story.objective()
	var tp: Array = o.get("target_pos", [])
	if tp.size() == 2 and str(tp[0]) == str(k.map.get("id", "")):
		var c: Vector2 = (tp[1] as Vector2) * k.TILE
		var pulse := 0.5 + 0.5 * sin(t * 2.6)
		draw_arc(c, 34.0 + 10.0 * pulse, 0, TAU, 40, Color(AfTheme.GOLD, 0.55 - 0.3 * pulse), 3.0)
		draw_arc(c, 18.0 + 4.0 * pulse, 0, TAU, 28, Color(AfTheme.EMBER_LIGHT, 0.6), 2.0)
		for i in 3:
			var a := float(i) / 3.0 * TAU + t * 1.4
			draw_circle(c + Vector2(cos(a), sin(a) * 0.45) * 40.0, 3.0, Color(AfTheme.GOLD, 0.8))


## A "!" / "?" marker bubble: gold for the story, pale blue for side quests ("s").
func _bubble(at: Vector2, m: String) -> void:
	var side := m == "s"
	var glyph := "?" if m == "?" else "!"
	var col: Color = Color("#8fd3ff") if side else AfTheme.GOLD
	var r := 17.0
	draw_circle(at + Vector2(2, 3), r, Color(0, 0, 0, 0.35))
	draw_circle(at, r, Color(AfTheme.SHEET, 0.92))
	draw_arc(at, r, 0, TAU, 32, col, 3.0)
	draw_colored_polygon(PackedVector2Array([at + Vector2(-6, r - 2), at + Vector2(6, r - 2), at + Vector2(0, r + 9)]), col)
	var fs := 26
	var sz := _font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	draw_string(_font, at + Vector2(-sz.x / 2.0, fs * 0.36), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
