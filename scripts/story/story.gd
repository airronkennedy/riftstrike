extends Node
## Autoload "Story": the Airron's Quest main story engine (docs/STORY.md).
## Holds the story flags, runs dialogs (portraits, typewriter, choices) through StoryUI, places story NPCs and quest
## markers in the Emberhold kingdom, keeps the objective / journal, and starts story fights through QuestFlow.
## Data: scripts/story/story_data.gd (cast, steps, NPCs, fights) and story_dialog.gd (text).
## Public API (also used by the dungeon / boss scenes): see "API for other scenes" in docs/STORY.md.

const StoryData = preload("res://scripts/story/story_data.gd")
const StoryDialog = preload("res://scripts/story/story_dialog.gd")
const StoryUI = preload("res://scripts/story/story_ui.gd")
const StoryWorld = preload("res://scripts/story/story_world.gd")
const QuestRPG = preload("res://scripts/quest_rpg.gd")
const AfRoster = preload("res://scripts/af_roster.gd")

const SAVE := "user://kingdom.cfg"
const BAG_PATH := "user://airrons_quest.cfg"
const KINGDOM_SCENE := "res://scenes/kingdom.tscn"
const MAIN_SCENE := "res://main.tscn"
## The dungeon worker's scene (Act IV). Until it exists, enter_dungeon() plays the floors straight from the ruin.
const DUNGEON_SCENE := "res://scenes/dungeon.tscn"
## Where base kingdom NPCs stand (for objective targets): id -> [map, tile pos].
const BASE_POS := {"orlan": ["castle", Vector2(10.0, 3.0)], "selka": ["castle", Vector2(8.0, 12.0)],
	"pell": ["town", Vector2(9.5, 9.6)], "wenna": ["town", Vector2(14.0, 13.6)], "joryn": ["town", Vector2(15.2, 9.7)]}
## Where the epilogue leaves the hero: the plaza.
const END_POS := Vector2(12.0, 9.4)

signal flag_changed(name: String, value: bool)
signal battle_finished(id: String, won: bool)
signal boss_defeated(id: String)
signal objective_changed()
signal dialog_closed(id: String)

var flags: Dictionary = {}
var vars: Dictionary = {}
var _recruited: Array = []
var started := false
var ui: StoryUI
var kingdom: Node = null          # the live kingdom scene (set by on_map_loaded)
var world: Node2D = null          # StoryWorld markers + actors inside the kingdom
var current_battle := ""          # story fight in progress (between start_battle and on_battle_done)
var return_scene := ""            # scene a story fight returns to
var pending_dialog := ""          # dialog to play once the next non-battle scene is ready
var _pending_wait := 0.0
var _added: Array = []            # usables this script added to the current kingdom map
var _dlg_id := ""
var _dlg_root := ""
var _dlg_done: Callable = Callable()
var _deferred: Array = []
var _last_obj := ""
var _loaded := false
var hud_wanted := false
## Tests: battle_stub = resolve story fights instantly (result stub_win) instead of loading main.tscn.
var battle_stub := false
var stub_win := true           # another scene (the dungeon) can ask for the tracker / Quests button


func _ready() -> void:
	ui = StoryUI.new()
	ui.story = self
	add_child(ui)
	load_state()


func _process(delta: float) -> void:
	var cs := get_tree().current_scene
	var in_battle := cs != null and cs.scene_file_path == MAIN_SCENE
	ui.set_hud_visible(not in_battle and (is_instance_valid(kingdom) or hud_wanted) and started)
	if pending_dialog != "" and not in_battle and not ui_open():
		_pending_wait += delta
		if _pending_wait > 0.7:
			var d := pending_dialog
			pending_dialog = ""
			_pending_wait = 0.0
			start_dialog(d)
	var obj: Dictionary = objective()
	var key: String = str(obj.get("id", "")) + "|" + str(obj.get("text", ""))
	if key != _last_obj:
		var first := _last_obj == ""
		_last_obj = key
		ui.refresh_tracker(not first)
		objective_changed.emit()


# ================================================================ state
func load_state() -> void:
	flags = {}; vars = {}; _recruited = []; started = false
	var cf := ConfigFile.new()
	if cf.load(SAVE) == OK and cf.has_section("story"):
		started = true
		for f in str(cf.get_value("story", "flags", "")).split(",", false): flags[f] = true
		var v = JSON.parse_string(str(cf.get_value("story", "vars", "{}")))
		if v is Dictionary: vars = v
		_recruited = Array(str(cf.get_value("story", "recruited", StoryData.HERO)).split(",", false))
	_loaded = true
	_last_obj = ""


func save_state() -> void:
	var cf := ConfigFile.new()
	cf.load(SAVE)
	cf.set_value("story", "flags", ",".join(flags.keys()))
	cf.set_value("story", "vars", JSON.stringify(vars))
	cf.set_value("story", "recruited", ",".join(_recruited))
	cf.save(SAVE)


## New Game: forget everything (QuestFlow.new_game deletes kingdom.cfg first).
func reset() -> void:
	flags = {}; vars = {}; _recruited = []; started = false
	pending_dialog = ""; current_battle = ""
	ui.close_all()


func _begin() -> void:
	started = true
	_recruited = [StoryData.HERO]
	flags = {}; vars = {"chronicle": []}
	save_state()


func get_flag(name: String) -> bool:
	if name.begins_with("r_"):
		return _recruited.has(name.substr(2))
	return flags.has(name)


func set_flag(name: String, value: bool = true) -> void:
	if value == flags.has(name):
		return
	if value: flags[name] = true
	else: flags.erase(name)
	save_state()
	flag_changed.emit(name, value)
	if not ui_open(): refresh_map() # mid-dialog changes re-place NPCs when the dialog closes


func recruited() -> Array:
	return _recruited.duplicate()


## Party gate for scripts/game.gd build_af_roster(): before the story starts every keeper is in.
func allows_keeper(id: String) -> bool:
	if not started: return true
	return _recruited.has(id)


func loyal_count() -> int:
	var n := 0
	for r in StoryData.RECRUITS:
		if flags.has("loyal_" + r): n += 1
	return n


func sparks() -> int:
	var n := 0
	for r in StoryData.RECRUITS:
		if flags.has("got_" + r): n += 1
	return n


## Wild fights grow with the party: alone 1 foe, two keepers up to 2, three or more the usual 2-3.
func max_foes() -> int:
	if not started: return 3
	return clampi(_recruited.size(), 1, 3)


func ui_open() -> bool:
	return ui != null and ui.is_open()


# ================================================================ conditions
func check(c: String) -> bool:
	if c.strip_edges() == "": return true
	for part in c.split("&", false):
		if not _atom(part.strip_edges()): return false
	return true


func _atom(a: String) -> bool:
	for op in [">=", "<=", ">", "<"]:
		if a.contains(op):
			var kv := a.split(op)
			var l := _num(kv[0].strip_edges())
			var r := int(kv[1])
			match op:
				">=": return l >= r
				"<=": return l <= r
				">": return l > r
				"<": return l < r
	if a.begins_with("!"): return not get_flag(a.substr(1))
	return get_flag(a)


func _num(n: String) -> int:
	match n:
		"sparks": return sparks()
		"loyal": return loyal_count()
		"gold": return gold()
		"party": return _recruited.size()
		"crates":
			var c := 0
			for k in ["crate_1", "crate_2", "crate_3"]: if flags.has(k): c += 1
			return c
	return int(vars.get(n, 0))


func fill(t: String) -> String:
	return t.replace("{sparks}", str(sparks())).replace("{loyal}", str(loyal_count())).replace("{gold}", str(gold()))


func pick_rule(rules: Array) -> Array:
	for r in rules:
		if check(str(r[0])): return r
	return []


# ================================================================ objective + journal data
func objective() -> Dictionary:
	if not started: return {}
	for s in StoryData.STEPS:
		if flags.has(s.id): continue
		if s.id == "s_ending" and not flags.has("boss2_won"): continue
		var o: Dictionary = s.duplicate(true)
		o["target_pos"] = target_of(s.get("target", {}))
		# Act II: point at the nearest unfinished Wardfire in the suggested order (any order works).
		return o
	return {"id": "done", "act": "E", "title": "The End", "text": "Emberhold is safe. Thank you for playing Airron's Quest!", "hint": "Explore, finish side quests, or start a New Game to make other choices.", "target_pos": []}


## Target -> [map, Vector2 tile pos] or [] if it isn't on a kingdom map.
func target_of(t: Dictionary) -> Array:
	if t.has("map"): return [str(t.map), Vector2(float(t.x), float(t.y))]
	if t.has("npc"):
		var id := str(t.npc)
		for m in StoryData.NPCS:
			for n in StoryData.NPCS[m]:
				if str(n.id) == id: return [m, Vector2(float(n.x), float(n.y))]
		if BASE_POS.has(id): return BASE_POS[id]
	return []


func side_quests() -> Array:
	var out: Array = []
	for q in StoryData.SIDE:
		if not flags.has(str(q.on)): continue
		var cnt: Array = q.count
		var got := 0
		for f in cnt: if flags.has(f): got += 1
		var done: bool = flags.has(str(q.done))
		var text: String = q.text
		if not done and cnt.size() > 0 and got >= cnt.size() and str(q.back) != "": text = q.back
		out.append({"title": q.title, "text": text, "done": done, "progress": "%d / %d" % [got, cnt.size()] if cnt.size() > 1 else ""})
	return out


func chronicle() -> Array:
	return vars.get("chronicle", [])


# ================================================================ kingdom integration
## Called by scripts/kingdom/kingdom.gd at the end of load_map(). Takes over base NPCs and spots, adds story NPCs.
func on_map_loaded(k: Node) -> void:
	if kingdom != k:
		kingdom = k
		load_state()
		if not started: _begin()
	_added.clear()
	if world == null or not is_instance_valid(world) or world.get_parent() != k:
		world = StoryWorld.new()
		world.story = self
		world.k = k
		k.add_child(world)
	world.on_map_loaded()
	var mid: String = str(k.map.get("id", ""))
	# Base NPCs: talk through the story, or hide.
	for u in k.usables.duplicate():
		if str(u.get("kind", "")) == "npc" and u.has("node"):
			var hero: String = str(u.node.hero)
			if StoryData.BASE.has(hero):
				var rule = StoryData.BASE[hero]
				if rule is String and rule == "hide":
					k.usables.erase(u)
					u.node.queue_free()
				else:
					u["action"] = "story"; u["rules"] = rule; u["sid"] = hero
					u["name"] = str(StoryData.CAST.get(hero, {}).get("name", u.name))
		elif str(u.get("kind", "")) == "spot" and StoryData.SPOT_TALK.has(str(u.get("id", ""))):
			u["action"] = "story"; u["rules"] = StoryData.SPOT_TALK[str(u.id)]; u["sid"] = str(u.id)
	_add_story_people(k, mid)
	if pending_dialog == "" and mid == "town" and not flags.has("s_prologue"):
		pending_dialog = "" # the guard's "!" invites the player; nothing auto-plays
	ui.refresh_tracker(false)


func _add_story_people(k: Node, mid: String) -> void:
	for n in StoryData.NPCS.get(mid, []):
		if not check(str(n.get("cond", ""))): continue
		var a = world.make_actor(str(n.art), Vector2(float(n.x), float(n.y)) * k.TILE)
		var nm: String = str(n.get("name", StoryData.CAST.get(str(n.art), {}).get("name", n.id)))
		var u := {"kind": "npc", "pos": a.position, "name": nm, "prompt": "Talk", "action": "story", "rules": n.talk, "sid": str(n.id), "node": a, "story": true}
		k.usables.append(u)
		_added.append(u)
	for s in StoryData.SPOTS.get(mid, []):
		if not check(str(s.get("cond", ""))): continue
		var u2 := {"kind": "spot", "id": str(s.id), "pos": Vector2(float(s.x), float(s.y)) * k.TILE, "name": str(s.name), "prompt": str(s.prompt),
			"action": "story", "rules": s.talk, "sid": str(s.id), "story": true}
		k.usables.append(u2)
		_added.append(u2)


## Re-place story NPCs after flags change (a recruit joins and leaves their spot, the court gathers on the plaza...).
func refresh_map() -> void:
	if not is_instance_valid(kingdom) or kingdom.map.is_empty(): return
	for u in _added:
		kingdom.usables.erase(u)
		if u.has("node") and is_instance_valid(u.node): u.node.queue_free()
	_added.clear()
	_add_story_people(kingdom, str(kingdom.map.get("id", "")))
	if world and is_instance_valid(world): world.queue_redraw()


## kingdom.gd use() for action "story".
func use(k: Node, u: Dictionary) -> void:
	kingdom = k
	var r := pick_rule(u.get("rules", []))
	if r.is_empty(): return
	var face: Variant = u.get("node", null)
	if face != null and is_instance_valid(face) and "facing" in face:
		face.facing = -1.0 if k.player_pos.x < face.position.x else 1.0
	start_dialog(str(r[1]))


func marker_for(u: Dictionary) -> String:
	var r := pick_rule(u.get("rules", []))
	return str(r[2]) if r.size() > 2 else ""


# ================================================================ dialog engine
func start_dialog(id: String, on_done: Callable = Callable()) -> void:
	if not StoryDialog.D.has(id):
		push_warning("Story: no dialog '%s'" % id)
		if on_done.is_valid(): on_done.call()
		return
	if not started: _begin()
	_dlg_root = id
	_dlg_done = on_done
	_deferred.clear()
	if is_instance_valid(kingdom):
		kingdom.tap_target = null
	_run_node(id)


func _run_node(id: String) -> void:
	_dlg_id = id
	var node: Dictionary = StoryDialog.D.get(id, {})
	var lines: Array = []
	for l in node.get("lines", []):
		if l.size() > 2 and not check(str(l[2])): continue
		lines.append([str(l[0]), fill(str(l[1]))])
	if lines.is_empty():
		_after_lines(id)
	else:
		ui.show_lines(lines, func(): _after_lines(id))


func _after_lines(id: String) -> void:
	var node: Dictionary = StoryDialog.D.get(id, {})
	var ch: Array = []
	for c in node.get("choices", []):
		if check(str(c.get("cond", ""))): ch.append(c)
	if not ch.is_empty():
		var texts: Array = []
		for c in ch: texts.append(fill(str(c.t)))
		ui.show_choices(texts, func(i: int): _choose(id, ch[i]))
		return
	_do(node.get("do", []))
	var nx: String = str(node.get("next", ""))
	if nx != "": _run_node(nx)
	else: _finish()


func _choose(id: String, c: Dictionary) -> void:
	var ch: Array = vars.get("chronicle", [])
	var sets: Array = []
	for a in c.get("do", []): if str(a).begins_with("set:c") or str(a).begins_with("set:end_"): sets.append(str(a).substr(4))
	if not sets.is_empty():
		ch.append({"act": _act_now(), "text": fill(str(c.t)), "flag": sets[0]})
		vars["chronicle"] = ch
	_do(c.get("do", []))
	var nx: String = str(c.get("next", ""))
	if nx != "": _run_node(nx)
	else: _finish()


func _act_now() -> String:
	var o := objective()
	return str(StoryData.ACTS.get(str(o.get("act", "")), ""))


func _finish() -> void:
	var root := _dlg_root
	ui.close_dialog()
	save_state()
	refresh_map()
	var cb := _dlg_done
	_dlg_done = Callable()
	await _flush_deferred()
	dialog_closed.emit(root)
	if cb.is_valid(): cb.call()


func _flush_deferred() -> void:
	var q := _deferred.duplicate()
	_deferred.clear()
	for d in q:
		match str(d[0]):
			"fanfare": await ui.fanfare(str(d[1]))
			"sparks": await ui.spark_card()
			"act": await ui.act_card(str(StoryData.ACTS.get(str(d[1]), d[1])))
			"tip": ui.tip(str(d[1]))
			"battle": start_battle(str(d[1])); return
			"dungeon": enter_dungeon(); return
			"exit_dungeon": exit_dungeon(); return
			"ending": await _ending(); return


func _do(actions: Array) -> void:
	for a0 in actions:
		var a := str(a0)
		if a.contains("?"): # "action?cond": only when the condition holds
			if not check(a.get_slice("?", 1)): continue
			a = a.get_slice("?", 0)
		var arg := a.get_slice(":", 1) if a.contains(":") else ""
		match a.get_slice(":", 0):
			"set": set_flag(arg)
			"clear": set_flag(arg, false)
			"recruit": _recruit(arg)
			"loyal": flags["loyal_" + arg] = true
			"gold": add_gold(int(arg))
			"item": give_item(arg)
			"heal": heal(1.0)
			"hurt": hurt(float(arg))
			"calm":
				if is_instance_valid(kingdom) and "meter" in kingdom:
					kingdom.meter = 0.0
					kingdom._refresh_hud()
			"toast": ui.toast(a.substr(6))
			"boss": boss_defeated.emit(arg)
			"act": _deferred.append(["act", arg])
			"tip": _deferred.append(["tip", arg])
			"sparks": _deferred.append(["sparks", ""])
			"crates": ui.toast("Pell's fireworks: %d / 3 crates" % _num("crates"))
			"battle": _deferred.append(["battle", arg])
			"dungeon": _deferred.append(["dungeon", ""])
			"exit_dungeon": _deferred.append(["exit_dungeon", ""])
			"ending": _deferred.append(["ending", ""])
	save_state()


func _recruit(id: String) -> void:
	if _recruited.has(id): return
	_recruited.append(id)
	_catch_up(id)
	save_state()
	_deferred.append(["fanfare", id])


## A Warden joins at about the hero's level: their starting class gets 90% of the hero's best class EXP
## (written to the kingdom save that scripts/game.gd load_class_xp() reads).
func _catch_up(id: String) -> void:
	var cf := ConfigFile.new()
	cf.load(SAVE)
	var best := 0
	for kv in str(cf.get_value("class_xp", "Bramwell", "")).split(",", false):
		best = maxi(best, int(kv.get_slice(":", 1)))
	var short := id.capitalize()
	var cls := ""
	for h in AfRoster.HEROES:
		if str(h.id) == id:
			short = str(h.short)
			cls = str(QuestRPG.FROM_KIT_CLASS.get(str(h.cls), h.cls))
	if cls == "" or best <= 0: return
	var cur := {}
	for kv in str(cf.get_value("class_xp", short, "")).split(",", false):
		cur[kv.get_slice(":", 0)] = int(kv.get_slice(":", 1))
	var want := int(best * 0.9)
	if int(cur.get(cls, 0)) >= want: return
	cur[cls] = want
	var parts: Array = []
	for c in cur: parts.append("%s:%d" % [c, int(cur[c])])
	cf.set_value("class_xp", short, ",".join(parts))
	cf.save(SAVE)


# ================================================================ gold / items / HP
func gold() -> int:
	if is_instance_valid(kingdom): return int(kingdom.gold)
	var cf := ConfigFile.new()
	cf.load(SAVE)
	return int(cf.get_value("kingdom", "gold", 120))


func add_gold(n: int) -> void:
	if is_instance_valid(kingdom):
		kingdom.gold = maxi(0, int(kingdom.gold) + n)
		kingdom._refresh_hud()
		kingdom.save_game()
		return
	var cf := ConfigFile.new()
	cf.load(SAVE)
	cf.set_value("kingdom", "gold", maxi(0, int(cf.get_value("kingdom", "gold", 120)) + n))
	cf.save(SAVE)


func give_item(iid: String) -> void:
	if is_instance_valid(kingdom):
		kingdom.bag.append(iid)
		if not kingdom.item_defs.has(iid) and StoryData.ITEMS.has(iid): kingdom.item_defs[iid] = StoryData.ITEMS[iid]
		kingdom.save_game()
		return
	var bf := ConfigFile.new()
	bf.load(BAG_PATH)
	var bag: Array = Array(str(bf.get_value("inv", "bag", "")).split(",", false))
	bag.append(iid)
	bf.set_value("inv", "bag", ",".join(bag))
	bf.save(BAG_PATH)


## frac of max HP to set (heal(1.0) = full).
func heal(frac: float) -> void:
	if is_instance_valid(kingdom):
		kingdom.party_hp = int(roundf(kingdom.party_hp_max * frac))
		kingdom._refresh_hud()
		kingdom.save_game()
		return
	var cf := ConfigFile.new()
	cf.load(SAVE)
	var mx := int(cf.get_value("kingdom", "hp_max", 80))
	cf.set_value("kingdom", "hp", int(roundf(mx * frac)))
	cf.save(SAVE)


## Lose a share of the CURRENT HP (the burn from pulling Taren out).
func hurt(share: float) -> void:
	if is_instance_valid(kingdom):
		kingdom.party_hp = maxi(1, int(roundf(kingdom.party_hp * (1.0 - share))))
		kingdom._refresh_hud()
		kingdom.save_game()
		return
	var cf := ConfigFile.new()
	cf.load(SAVE)
	var mx := int(cf.get_value("kingdom", "hp_max", 80))
	cf.set_value("kingdom", "hp", maxi(1, int(roundf(int(cf.get_value("kingdom", "hp", mx)) * (1.0 - share)))))
	cf.save(SAVE)


## scripts/game.gd _ready(): heirloom items become real gear.
func extend_items(defs: Dictionary) -> void:
	for k in StoryData.ITEMS:
		if not defs.has(k): defs[k] = StoryData.ITEMS[k].duplicate()


# ================================================================ story fights
## Start a story fight (ids in StoryData.BATTLES). Returns to the current scene afterwards and plays the fight's
## win / lose dialog there. The kingdom saves its spot first; another scene must save its own state.
func start_battle(id: String) -> void:
	if not StoryData.BATTLES.has(id):
		push_warning("Story: no battle '%s'" % id)
		return
	current_battle = id
	if battle_stub:
		on_battle_done(id, stub_win)
		return
	var cs := get_tree().current_scene
	return_scene = cs.scene_file_path if cs != null and cs.scene_file_path != MAIN_SCENE else KINGDOM_SCENE
	if is_instance_valid(kingdom): kingdom.save_game()
	save_state()
	var qf := get_node_or_null("/root/QuestFlow")
	if qf == null: return
	qf.pending_region = "story:" + id
	qf.in_kingdom_battle = true
	await ui.battle_intro(StoryData.BATTLES[id])
	get_tree().change_scene_to_file.call_deferred(MAIN_SCENE)


## Encounter dictionary for game.gd (via QuestFlow.encounter_for("story:<id>", party foe level)).
func encounter_for(id: String, level: int = -1) -> Dictionary:
	var b: Dictionary = StoryData.BATTLES.get(id, {})
	if b.is_empty(): return {}
	var rec := int(b.get("rec", 1))
	if id == "miniboss_matron" and flags.has("reliquary_given"): rec -= 1 # Selka warned the guard (Choice 2)
	var lv := clampi(level if level > 0 else rec, rec, rec + 2)
	lv = clampi(lv, 1, QuestRPG.LEVEL_CAP)
	var region := "story"
	return {"area": str(b.area), "kinds": b.kinds.duplicate(), "tiers": b.tiers.duplicate(), "foe_ids": b.get("foe_ids", []).duplicate(),
		"foes": b.get("foes", {}).duplicate(true), "level": lv, "region": region, "elite": false, "auto": true,
		"story_id": id, "boss": bool(b.get("boss", false)), "banner": str(b.get("banner", "")),
		"banner_sub": str(b.get("banner_sub", "Lv.%d" % lv))}


## QuestFlow.finish_battle() calls this for story fights before it changes scene.
func on_battle_done(id: String, won: bool) -> void:
	current_battle = ""
	var b: Dictionary = StoryData.BATTLES.get(id, {})
	if won:
		if b.has("flag"): flags[str(b.flag)] = true
		save_state()
		if StoryData.BOSS_IDS.has(id): boss_defeated.emit(id)
	pending_dialog = str(b.get("win" if won else "lose", ""))
	_pending_wait = 0.0
	battle_finished.emit(id, won)


## The scene a story fight should return to (QuestFlow.finish_battle).
func take_return_scene() -> String:
	var s := return_scene if return_scene != "" else KINGDOM_SCENE
	return_scene = ""
	return s


# ================================================================ dungeon (Act IV)
func enter_dungeon() -> void:
	set_flag("s_bastion")
	if ResourceLoader.exists(DUNGEON_SCENE):
		if is_instance_valid(kingdom): kingdom.save_game()
		get_tree().change_scene_to_file.call_deferred(DUNGEON_SCENE)
		return
	# Fallback until the dungeon scene lands: each descent plays the next floor straight from the ruin.
	if not flags.has("bastion_f1"):
		if flags.has("reliquary_given"): start_dialog("f1_skip")
		else: start_dialog("f1_enter", func(): start_battle("guardian_f1"))
	elif not flags.has("bastion_f2"):
		if flags.has("c4_bind"): start_dialog("f2_bind")
		else: start_dialog("f2_enter", func(): start_battle("guardian_f2"))
	elif not flags.has("boss1_won"):
		start_dialog("final_confront")
	elif not flags.has("boss2_won"):
		start_dialog("sovereign_intro")


func exit_dungeon() -> void:
	var cf := ConfigFile.new()
	cf.load(SAVE)
	cf.set_value("kingdom", "map", "overworld")
	cf.set_value("kingdom", "pos", Vector2(32.0, 22.6))
	cf.save(SAVE)
	get_tree().change_scene_to_file.call_deferred(KINGDOM_SCENE)


# ================================================================ ending
func _ending() -> void:
	var cards: Array = []
	for e in StoryDialog.EPILOGUE:
		if check(str(e[0])): cards.append([str(e[1]), fill(str(e[2]))])
	flags["s_ending"] = true
	save_state()
	await ui.epilogue(cards)
	# Back to the plaza for the celebration (free roam after the end).
	if is_instance_valid(kingdom):
		kingdom.warp_to("town", END_POS)
	else:
		var cf := ConfigFile.new()
		cf.load(SAVE)
		cf.set_value("kingdom", "map", "town")
		cf.set_value("kingdom", "pos", END_POS)
		cf.save(SAVE)
		get_tree().change_scene_to_file.call_deferred(KINGDOM_SCENE)
	refresh_map()
