extends RefCounted
## Class divination at the Ember Inn (docs/CLASSES.md), after Dragon Quest IX's Alltrades Abbey.
## Adeyo the Star-Reader changes a keeper's CLASS or SUBCLASS. Every class and every subclass keeps its own level and
## EXP per keeper (game.gd CLASS_XP / SUB_XP), so switching back resumes where you left off.
##   A class (or subclass) a keeper has never had starts at HALF their best level, rounded up ("the stars remember").
##   Advanced callings unlock with the story: Warlock after Kindling Night, Bard after the Quiet Bell (or Act III).
##   Picking the current subclass as the class swaps the two (and the other way round), as in Build.
##   A hand-set Attack Order keeps its order; its per-keeper delays are re-tuned for the new class's hit timing.
const QuestRPG = preload("res://scripts/quest_rpg.gd")
const Combo = preload("res://scripts/combo.gd")
const Signatures = preload("res://scripts/classes/signatures.gd")

const FLAVOR := {
	"Warrior": "The stars see a broad back and a short temper. Hit first; apologise never.",
	"Guardian": "A shield-shaped constellation. Everyone stands behind you, which is flattering and also the point.",
	"Knight": "The Lancer rises. Armor, oaths, and a fondness for charging at things larger than you.",
	"Rogue": "Seven quick stars and one that's hiding. Fast hands, sharp knives, opinions about locks.",
	"Monk": "A still star in a moving sky. Fists like rain, and a calm that annoys your enemies.",
	"Ranger": "The Archer's arc. Patience, distance, and marks that make big things fall over.",
	"Mage": "A burning wheel of light. Fire over every foe, and very little between you and their teeth.",
	"Warlock": "A star that went out and kept shining anyway. Curses first, then the ash.",
	"Cleric": "The Hearth-star. Mend the line, steady the party, outlast the dark.",
	"Bard": "A star that hums. Songs that sharpen blades and lift tired feet.",
}

const ADVANCED := {
	"Warlock": {"flags": ["s_kindling"], "hint": "Opens after Kindling Night: the Matron's ash teaches it."},
	"Bard": {"flags": ["sq_bell_done", "s_return"], "hint": "Opens when the Quiet Bell is answered (Sister Wenna's quest) or the four sparks come home."},
}

static func story(tree: SceneTree) -> Node:
	return tree.root.get_node_or_null("Story") if tree != null else null

## Is this calling open yet? Outside story play (no Story autoload or no story started) everything is open.
static func unlocked(tree: SceneTree, cls: String) -> bool:
	if not ADVANCED.has(cls): return true
	var st := story(tree)
	if st == null or not bool(st.get("started")): return true
	for f in ADVANCED[cls].flags:
		if st.get_flag(str(f)): return true
	return false

static func unlock_hint(cls: String) -> String:
	return str(ADVANCED.get(cls, {}).get("hint", ""))

static func best_level(g: Object, name: String) -> int:
	var b := 1
	for c in QuestRPG.CLASS_ORDER: b = maxi(b, g.class_level(name, c))
	return b

## Has this keeper ever had this class (mode "class") or subclass (mode "sub")?
static func known(g: Object, name: String, cls: String, mode: String) -> bool:
	var d: Dictionary = (g.CLASS_XP if mode == "class" else g.SUB_XP).get(name, {})
	return int(d.get(cls, 0)) > 0 or (mode == "class" and str(g.CHAR[name].cls) == cls) or (mode == "sub" and str(g.CHAR[name].sub) == cls)

static func start_level(g: Object, name: String) -> int:
	return maxi(1, int(ceil(float(best_level(g, name)) / 2.0)))

## The level this keeper would have in that class / subclass right after divining it.
static func level_after(g: Object, name: String, cls: String, mode: String) -> int:
	if known(g, name, cls, mode): return g.class_level(name, cls) if mode == "class" else g.sub_level(name, cls)
	return start_level(g, name)

## Do it. Returns {ok, name, mode, cls, old, level, fresh, swapped, sub, timing: {before, after, auto}}.
static func divine(g: Object, name: String, cls: String, mode: String = "class") -> Dictionary:
	if not g.CHAR.has(name) or not QuestRPG.CLASSES.has(cls): return {"ok": false}
	var old_c: String = str(g.CHAR[name].cls)
	var old_s: String = str(g.CHAR[name].sub)
	if (mode == "class" and cls == old_c) or (mode == "sub" and cls == old_s): return {"ok": false}
	var before := spark_rate(g)
	var fresh := not known(g, name, cls, mode)
	var lv := start_level(g, name)
	var xp_book: Dictionary = g.CLASS_XP if mode == "class" else g.SUB_XP
	if not xp_book.has(name): xp_book[name] = {}
	if fresh: xp_book[name][cls] = maxi(int(xp_book[name].get(cls, 0)), QuestRPG.xp_floor(lv))
	var swapped := false
	if mode == "class":
		swapped = cls == old_s
		if swapped and not known(g, name, old_c, "sub"): # the old class becomes the subclass: seed its sub level too
			if not g.SUB_XP.has(name): g.SUB_XP[name] = {}
			g.SUB_XP[name][old_c] = QuestRPG.xp_floor(start_level(g, name))
		g.set_class(name, cls)
	else:
		if cls == old_c: # swap: the old subclass becomes the class
			swapped = true
			if not known(g, name, old_s, "class"): g.CLASS_XP[name][old_s] = QuestRPG.xp_floor(start_level(g, name))
			g.set_class(name, old_s)
		g.set_sub(name, cls)
	var timing := retune(g)
	timing["before"] = before
	g.save_cfg()
	return {"ok": true, "name": name, "mode": mode, "cls": cls, "old": old_c if mode == "class" else old_s, "fresh": fresh,
		"level": g.class_level(name, cls) if mode == "class" else g.sub_level(name, cls), "swapped": swapped,
		"class": str(g.CHAR[name].cls), "sub": str(g.CHAR[name].sub), "timing": timing,
		"sig_plus": Signatures.class_match(name, str(g.CHAR[name].cls))}

## Expected spark rate of the party's current Attack Order (Combo.spark_rate on each keeper's class hit frames).
static func spark_rate(g: Object) -> float:
	var order: Array = g.attack_order()
	if order.size() < 2: return 0.0
	var fr: Array = []
	var dl: Array = []
	var hd: Dictionary = g.attack_delays()
	for nm in order:
		fr.append(Combo.frames(str(g.CHAR[nm].cls))); dl.append(float(hd.get(nm, 0.0)))
	return Combo.spark_rate(fr, dl, 40)

## Class timing changed: the suggested order (untouched Build) follows by itself (game.gd auto_plan is keyed by class).
## A hand-set order keeps its order; the per-keeper delays are re-tuned one slot at a time like Suggest order does.
static func retune(g: Object) -> Dictionary:
	if g.auto_order(): return {"auto": true, "after": spark_rate(g)}
	var order: Array = g.attack_order()
	var fr: Array = []
	for nm in order: fr.append(Combo.frames(str(g.CHAR[nm].cls)))
	var d: Array = []
	for i in order.size(): d.append(0.0)
	var cur := Combo.spark_rate(fr, d, 24)
	for _pass in 2:
		for s in range(1, order.size()):
			var keep: float = d[s]
			var step := 0.0
			while step <= Combo.DELAY_MAX:
				d[s] = step
				var r := Combo.spark_rate(fr, d, 24)
				if r > cur + 0.004: cur = r; keep = step
				step += Combo.DELAY_STEP
			d[s] = keep
	for i in order.size(): g.HERO_DELAY[order[i]] = float(d[i])
	return {"auto": false, "after": spark_rate(g)}

## From the kingdom (Adeyo's dialog): save, then open the divination screen in main.tscn; Back returns to the inn.
static func open_from_kingdom(tree: SceneTree, kingdom: Node) -> void:
	if kingdom != null and is_instance_valid(kingdom) and kingdom.has_method("save_game"): kingdom.save_game()
	var st := story(tree)
	if st != null:
		st.save_state()
		if st.get("ui") != null: st.ui.close_all()
	var qf := tree.root.get_node_or_null("QuestFlow")
	if qf == null: return
	qf.pending_screen = "diviner"
	tree.change_scene_to_file.call_deferred("res://main.tscn")
