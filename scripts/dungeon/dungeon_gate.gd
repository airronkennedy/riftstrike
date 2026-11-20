class_name DungeonGate
extends RefCounted
## The Vespergate Deeps: the story-facing interface of the dungeon (docs/DUNGEON.md).
##
##   DungeonGate.is_open()          the entrance flag: the overworld cave lets the hero in (story sets it)
##   DungeonGate.set_open(true)     story: unlock the dungeon (saved in user://dungeon.cfg [gate] open)
##   DungeonGate.enter(tree)        go to the dungeon (floor 1 entrance, or the saved spot)
##   DungeonGate.leave(tree)        back to the overworld at the cave mouth
##   DungeonGate.cleared()          true once the final boss in the last room is beaten
##
## If a story autoload named "Story" exists and has has_flag(name), its DUNGEON_FLAG decides (or set_open(true));
## without one the gate is open so the dungeon is playable before the story lands.
## The overworld entrance is the Coalvein Cave spot in the kingdom overworld (kingdom maps: spot id "cave").

const SCENE := "res://scenes/dungeon.tscn"
const SAVE := "user://dungeon.cfg"
const KINGDOM_SAVE := "user://kingdom.cfg"
const DUNGEON_FLAG := "dungeon_open"
const FINAL_BOSS := "ash_sovereign"
## Where the overworld puts the hero back (tile coords, just below the Coalvein Cave mouth).
const OVERWORLD_RETURN := Vector2(32.0, 7.6)

## Random battles per floor (QuestFlow REGION_BATTLES format; levels follow the party like every wild fight).
const BATTLES := {
	"deeps_1": {"area": "coalvein-deeps", "elite": 0.1, "kinds": ["torch", "barrel", "tnt"],
		"foes": {"torch": ["mote", "gnat"], "barrel": ["brute"], "tnt": ["moth"]}},
	"deeps_2": {"area": "coalvein-deeps", "elite": 0.2, "kinds": ["barrel", "torch", "tnt"],
		"foes": {"torch": ["lancer", "ashling"], "barrel": ["pilgrim", "brute"], "tnt": ["chanter"]}},
	"deeps_3": {"area": "vespergate-sanctum", "elite": 0.3, "kinds": ["torch", "tnt", "barrel"],
		"foes": {"torch": ["lancer", "ashling"], "barrel": ["pilgrim"], "tnt": ["chanter", "moth"]}},
}

static func is_open() -> bool:
	var cf := ConfigFile.new()
	if cf.load(SAVE) == OK and bool(cf.get_value("gate", "open", false)): return true
	var ml := Engine.get_main_loop()
	if ml is SceneTree:
		var st: Node = (ml as SceneTree).root.get_node_or_null("Story")
		if st != null and st.has_method("has_flag"): return bool(st.has_flag(DUNGEON_FLAG))
	# No story framework yet: the cave is open so the dungeon stays playable. Once a "Story" autoload with
	# has_flag() exists, its DUNGEON_FLAG decides.
	return true

static func set_open(v: bool = true) -> void:
	var cf := ConfigFile.new()
	cf.load(SAVE)
	cf.set_value("gate", "open", v)
	cf.save(SAVE)

static func cleared() -> bool:
	var cf := ConfigFile.new()
	return cf.load(SAVE) == OK and bool(cf.get_value("progress", "cleared", false))

static func enter(tree: SceneTree) -> void:
	tree.change_scene_to_file.call_deferred(SCENE)

## Back to the overworld, standing at the cave mouth.
static func leave(tree: SceneTree) -> void:
	var cf := ConfigFile.new()
	cf.load(KINGDOM_SAVE)
	cf.set_value("kingdom", "map", "overworld")
	cf.set_value("kingdom", "pos", OVERWORLD_RETURN)
	cf.save(KINGDOM_SAVE)
	tree.change_scene_to_file.call_deferred("res://scenes/kingdom.tscn")

static func reset() -> void:
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
