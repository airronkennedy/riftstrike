extends SceneTree
## Main story checks (docs/STORY.md):
##  1. data: every dialog / speaker / portrait / action / fight / foe / backdrop / item referenced exists
##  2. every story NPC and spot is reachable with the real kingdom collision
##  3. a full walk of the story flags from the guard's "!" to the epilogue, twice (choice path A and path B),
##     with story fights stubbed, checking the party gate, objectives, loyalty, heirlooms and the ending
##  4. one real story fight (fight_grieve) through QuestFlow + main.tscn and back to the same kingdom spot
## Run with private user data:  XDG_DATA_HOME=$(mktemp -d) godot --headless --path . --script res://tools/test_story.gd
const SD = preload("res://scripts/story/story_data.gd")
const DL = preload("res://scripts/story/story_dialog.gd")
var fails := 0
var st
var k
var policy := {}

func ok(c: bool, m: String) -> void:
	print(("ok   " if c else "FAIL ") + m)
	if not c: fails += 1

func wait(ms: float) -> void:
	await create_timer(ms / 1000.0).timeout

func _init() -> void:
	preload("res://tools/test_save.gd").fresh()
	_run.call_deferred()

func _run() -> void:
	st = root.get_node("Story")
	check_data()
	await check_reach()
	await walk("A", {"king_audience": 0, "grieve_after": 0, "corvin_meet": 1, "ilsabet_after": 0, "regnant_after": 0, "sovereign_after": 1, "drosk_offer": 0})
	await walk("B", {"king_audience": 1, "grieve_after": 1, "corvin_meet": 0, "ilsabet_after": 1, "regnant_after": 1, "sovereign_after": 0, "drosk_offer": 1})
	await real_fight()
	print("STORY ", "PASS" if fails == 0 else "FAIL %d" % fails)
	quit(1 if fails > 0 else 0)

# ------------------------------------------------------------------ 1. data
func check_data() -> void:
	var D: Dictionary = DL.D
	var bad: Array = []
	var refs: Array = []
	for m in SD.NPCS:
		for n in SD.NPCS[m]:
			for r in n.talk: refs.append(str(r[1]))
			if not ResourceLoader.exists("res://assets/af/heroes/%s.png" % n.art): bad.append("art " + str(n.art))
	for h in SD.BASE:
		if SD.BASE[h] is Array: for r in SD.BASE[h]: refs.append(str(r[1]))
	for s in SD.SPOT_TALK: for r in SD.SPOT_TALK[s]: refs.append(str(r[1]))
	for m in SD.SPOTS: for s in SD.SPOTS[m]: for r in s.talk: refs.append(str(r[1]))
	for b in SD.BATTLES:
		var bt: Dictionary = SD.BATTLES[b]
		refs.append(str(bt.win)); refs.append(str(bt.lose))
		if not ResourceLoader.exists("res://assets/af/areas/area-%s-backdrop.png" % bt.area): bad.append("area " + str(bt.area))
		for f in bt.get("foe_ids", []): if str(f) != "" and not preload("res://scripts/af_roster.gd").FOES.has(str(f)): bad.append("foe " + str(f))
		for tr in bt.tiers: if not preload("res://scripts/quest_rpg.gd").FOE_TIER.has(str(tr)): bad.append("tier " + str(tr))
		ok(bt.kinds.size() == bt.tiers.size(), "fight %s: kinds and tiers line up" % b)
	var acts := ["set", "clear", "recruit", "loyal", "battle", "gold", "item", "heal", "hurt", "act", "tip", "toast", "dungeon", "exit_dungeon", "ending", "boss", "sparks", "crates", "calm"]
	var items: Dictionary = SD.ITEMS.duplicate()
	for i in ["warden_mail", "brook_pendant"]: items[i] = true
	for id in D:
		var node: Dictionary = D[id]
		if node.has("next") and str(node.next) != "": refs.append(str(node.next))
		for l in node.get("lines", []):
			if not SD.CAST.has(str(l[0])): bad.append("speaker %s in %s" % [l[0], id])
		var all_do: Array = node.get("do", []).duplicate()
		for c in node.get("choices", []):
			all_do.append_array(c.get("do", []))
			if str(c.get("next", "")) != "": refs.append(str(c.next))
		for a0 in all_do:
			var a := str(a0).get_slice("?", 0)
			var op := str(a).get_slice(":", 0)
			if not acts.has(op): bad.append("action %s in %s" % [a, id])
			if op == "battle" and not SD.BATTLES.has(str(a).get_slice(":", 1)): bad.append("battle " + str(a))
			if op == "item" and not items.has(str(a).get_slice(":", 1)): bad.append("item " + str(a))
			if op == "act" and not SD.ACTS.has(str(a).get_slice(":", 1)): bad.append("act " + str(a))
	for id in ["f1_enter", "f1_skip", "f2_enter", "f2_bind", "final_confront", "sovereign_intro"]: refs.append(id)
	for r in refs: if not D.has(r): bad.append("dialog " + r)
	for c in SD.CAST:
		var art: String = str(SD.CAST[c].art)
		if art == "": continue
		var path := ("res://assets/af/foes/foe-%s.png" % art.substr(4)) if art.begins_with("foe:") else ("res://assets/af/heroes/%s.png" % art)
		if not ResourceLoader.exists(path): bad.append("portrait " + path)
	ok(bad.is_empty(), "story data references all resolve %s" % [bad])
	var steps := 0
	for s in SD.STEPS: steps += 1
	ok(steps >= 12, "%d main story steps" % steps)

# ------------------------------------------------------------------ 2. reachability
func check_reach() -> void:
	k = load("res://scenes/kingdom.tscn").instantiate()
	root.add_child(k)
	await process_frame
	# Turn on every story flag group that places people, map by map.
	for f in ["s_prologue", "s_king"]: st.flags[f] = true
	for id in ["town", "castle", "house", "overworld"]:
		for f in ["sq_fire_on"]: st.flags[f] = true
		k.load_map(id)
		var reach := _reach()
		for m in [SD.NPCS.get(id, []), SD.SPOTS.get(id, [])]:
			for n in m:
				var p := Vector2(float(n.x), float(n.y)) * 64.0
				ok(_near(reach, p, 74.0), "%s: story %s reachable" % [id, n.id])
	# The plaza court for Kindling Night
	for r in SD.RECRUITS: st.flags["got_" + r] = true
	st.flags["s_return"] = true
	k.load_map("town")
	var reach2 := _reach()
	var u = _find("orlan_plaza")
	ok(u != null and _near(reach2, u.pos, 74.0), "town: king on the plaza reachable at Kindling Night")
	k.queue_free()
	await process_frame
	st.reset()
	preload("res://tools/test_save.gd").fresh()

func _reach() -> Array:
	var seen := {}
	var q: Array = [k.player_pos]
	seen[Vector2i(k.player_pos / 16.0)] = true
	var out: Array = []
	while not q.is_empty() and out.size() < 40000:
		var p: Vector2 = q.pop_back()
		out.append(p)
		for d in [Vector2(16, 0), Vector2(-16, 0), Vector2(0, 16), Vector2(0, -16)]:
			var n: Vector2 = p + d
			var key := Vector2i(n / 16.0)
			if seen.has(key) or k.blocked_at(n): continue
			seen[key] = true
			q.append(n)
	return out

func _near(reach: Array, t: Vector2, rad: float) -> bool:
	for p in reach: if (p as Vector2).distance_to(t) < rad: return true
	return false

func _find(sid: String):
	for u in k.usables:
		if str(u.get("sid", "")) == sid: return u
	return null

# ------------------------------------------------------------------ 3. the walk
func settle() -> void:
	var idle := 0
	for i in 4000:
		await process_frame
		var ui = st.ui
		if not ui.choices_box.get_children().is_empty():
			var root_id: String = st._dlg_id
			var pick: int = int(policy.get(root_id, 0))
			pick = mini(pick, ui.choices_box.get_child_count() - 1)
			ui._pick(pick)
			idle = 0
		elif ui.dlg.visible and ui.catcher.visible:
			ui.dlg_text.visible_ratio = 1.0
			ui.advance()
			idle = 0
		elif ui._blocking:
			ui._tap = true
			idle = 0
		elif st.pending_dialog != "":
			idle = 0
		else:
			idle += 1
			if idle > 6: return

func talk(map: String, sid: String) -> void:
	if str(k.map.get("id", "")) != map:
		k.load_map(map)
		await process_frame
	var u = _find(sid)
	ok(u != null, "  %s: '%s' is there" % [map, sid])
	if u == null: return
	k.player_pos = (u.pos as Vector2) + Vector2(0, 40)
	k.busy = false
	k.use(u)
	await settle()

func obj() -> String:
	return str(st.objective().get("id", ""))

func walk(tag: String, pol: Dictionary) -> void:
	print("--- walk ", tag)
	policy = pol
	preload("res://tools/test_save.gd").fresh()
	st.reset()
	st.battle_stub = true
	st.use_dungeon_scene = false # the overworld fallback; the dungeon scene has its own test (tools/test_dungeon.gd)
	st.ui.fast = true
	k = load("res://scenes/kingdom.tscn").instantiate()
	root.add_child(k)
	await wait(200)
	ok(st.started and st.recruited() == ["bramwell"], "%s: New Game starts the story, hero alone" % tag)
	ok(obj() == "s_prologue", "%s: first objective is the guard" % tag)
	var g_u = _find("vellin")
	ok(g_u != null and st.marker_for(g_u) == "!", "%s: guard has a ! marker" % tag)
	ok(st.max_foes() == 1, "%s: alone = 1 wild foe" % tag)
	await talk("town", "vellin")
	ok(st.get_flag("s_prologue") and obj() == "s_king", "%s: guard -> go see the king" % tag)
	await talk("castle", "orlan")
	ok(st.get_flag("s_king"), "%s: king audience done" % tag)
	ok(st.get_flag("c1_oath") if tag == "A" else st.get_flag("c1_price"), "%s: choice 1 saved" % tag)
	if tag == "A": ok(k.bag.has("warden_mail"), "A: Oath gives Warden Mail")
	await talk("house", "maera")
	ok(obj() == "got_grieve", "%s: Act II objective is Grieve" % tag)
	await talk("town", "drosk")
	ok(st.get_flag("sq_book_bet") == (tag == "A"), "%s: Drosk bet as chosen" % tag)
	await talk("town", "pell")
	ok(st.get_flag("sq_fire_on"), "%s: Pell's side quest on" % tag)
	await talk("overworld", "grieve")
	ok(st.get_flag("got_grieve") and st.recruited().has("grieve"), "%s: Grieve recruited, spark 1" % tag)
	ok(st.max_foes() == 2, "%s: two keepers = up to 2 wild foes" % tag)
	ok(st.get_flag("loyal_grieve") == (tag == "A"), "%s: Grieve loyalty follows choice 2" % tag)
	if tag == "B": await talk("castle", "selka")
	for c in ["crate_1", "crate_2", "crate_3"]: await talk("overworld", c)
	await talk("town", "pell")
	ok(st.get_flag("sq_fire_done"), "%s: fireworks side quest done" % tag)
	await talk("overworld", "halvard")
	ok(st.get_flag("got_halvard") and st.get_flag("loyal_halvard") == (tag == "B"), "%s: Halvard recruited, loyal only if paid" % tag)
	await talk("town", "wenna")
	ok(st.get_flag("sq_bell_on"), "%s: Wenna's side quest on" % tag)
	await talk("overworld", "shrine")
	await talk("town", "wenna")
	ok(st.get_flag("sq_bell_done"), "%s: bell side quest done" % tag)
	await talk("overworld", "corvin")
	ok(st.get_flag("got_corvin") and st.get_flag("loyal_corvin") == (tag == "A"), "%s: Corvin (hunt = loyal)" % tag)
	await talk("overworld", "ilsabet")
	ok(st.get_flag("got_ilsabet") and st.sparks() == 4, "%s: four sparks" % tag)
	ok(st.recruited().size() == 5, "%s: party of five" % tag)
	ok(obj() == "s_return", "%s: objective: bring the sparks home" % tag)
	await talk("castle", "orlan")
	ok(obj() == "s_kindling", "%s: objective: Kindling Night" % tag)
	await talk("town", "orlan_plaza")
	ok(st.get_flag("s_kindling"), "%s: mini-boss won" % tag)
	var enc: Dictionary = st.encounter_for("miniboss_matron", 1)
	ok(enc.tiers[0] == "miniboss" and enc.foe_ids[0] == "matron" and enc.boss, "%s: mini-boss encounter (miniboss tier, Matron art)" % tag)
	if tag == "B": ok(int(enc.level) == 6, "B: Selka's warning lowers the Matron a level (%d)" % int(enc.level))
	if tag == "A":
		await talk("town", "drosk")
		ok(st.get_flag("sq_book_paid"), "A: Drosk pays out")
	ok(obj() == "s_bastion", "%s: objective: the Sunken Bastion" % tag)
	for i in 4:
		if st.get_flag("boss2_won"): break
		await talk("overworld", "ruin")
	ok(st.get_flag("bastion_f1") and st.get_flag("bastion_f2"), "%s: both Bastion floors cleared" % tag)
	ok(st.get_flag("boss1_won") and st.get_flag("boss2_won"), "%s: final boss, both phases" % tag)
	ok(st.get_flag("c5_spare") == (tag == "A"), "%s: Taren's fate saved" % tag)
	ok(st.get_flag("s_ending"), "%s: ending reached" % tag)
	ok(st.get_flag("end_hearth") == (tag == "A"), "%s: ending choice saved" % tag)
	ok(obj() == "done", "%s: story complete" % tag)
	ok(st.loyal_count() == (3 if tag == "A" else 1), "%s: loyal Wardens = %d" % [tag, st.loyal_count()])
	ok(st.chronicle().size() >= 6, "%s: chronicle has %d choices" % [tag, st.chronicle().size()])
	# Saved and loaded back
	st.load_state()
	ok(st.get_flag("s_ending") and st.recruited().size() == 5, "%s: story flags survive save / load" % tag)
	k.queue_free()
	await wait(100)

# ------------------------------------------------------------------ 4. a real story fight
func real_fight() -> void:
	print("--- real fight")
	preload("res://tools/test_save.gd").fresh()
	st.reset()
	st.battle_stub = false
	st.ui.fast = true
	change_scene_to_file("res://scenes/kingdom.tscn")
	await wait(500)
	k = current_scene
	for f in ["s_prologue", "s_king", "s_maera"]: st.flags[f] = true
	st.save_state()
	k.load_map("overworld")
	await wait(100)
	var u = _find("grieve")
	k.player_pos = (u.pos as Vector2) + Vector2(0, 40)
	for off in [Vector2(0, 40), Vector2(0, -40), Vector2(40, 0), Vector2(-40, 0), Vector2(30, 30), Vector2(-30, 30)]:
		if not k.blocked_at((u.pos as Vector2) + off):
			k.player_pos = (u.pos as Vector2) + off
			break
	var spot: Vector2 = k.player_pos
	k.use(u)
	for i in 600:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == "res://main.tscn": break
		if st.ui.dlg.visible: st.ui.dlg_text.visible_ratio = 1.0; st.ui.advance()
		if st.ui._blocking: st.ui._tap = true
	await wait(500)
	var g = current_scene
	ok(g.scene_file_path == "res://main.tscn" and g.phase == "battle", "story fight started in main.tscn")
	var names: Array = []
	for un in g.G.units: if un.team == "blue": names.append(un.name)
	ok(names.size() == 2 and names.has("Bramwell") and names.has("Grieve"), "party is Bramwell + Grieve (%s)" % [names])
	var foes: Array = []
	for un in g.G.units: if un.team == "red": foes.append([un.name, un.tier])
	ok(foes.size() == 2 and foes[0][1] == "elite" and str(foes[0][0]) == "Charnel Leaper", "foes: Charnel Leaper (elite) + moth (%s)" % [foes])
	ok(g.battle_area == "gallowbough-orchard", "Gallowbough backdrop")
	g.sfx.muted = true
	g.AUTO = true; g.speed = 3
	var guard := 0
	while g.phase != "results" and guard < 1600:
		await wait(50); guard += 1
	ok(g.phase == "results", "fight finished (%s)" % str(g.G.result))
	var won: bool = g.G.result == "win"
	g.results_primary()
	await wait(900)
	ok(current_scene.scene_file_path == "res://scenes/kingdom.tscn", "back in the kingdom")
	ok(current_scene.player_pos.distance_to(spot) < 40.0, "same spot (%.0f px off)" % current_scene.player_pos.distance_to(spot))
	for i in 400:
		await process_frame
		if st.ui.dlg.visible: break
	ok(st.ui.dlg.visible, "the %s dialog plays back" % ("win" if won else "lose"))
