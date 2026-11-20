class_name DungeonGate
extends RefCounted
## The Sunken Bastion: the dungeon's interface to the rest of the game (docs/DUNGEON.md, docs/STORY.md Act IV).
##
## With the Story autoload (normal play), the story owns the way in and out: the Sunken Bastion spot on the overworld
## plays "bastion_enter", which calls Story.enter_dungeon() -> this scene; leave() calls Story.exit_dungeon().
## The floors read the story flags (bastion_f1/f2, c2_keep, c4_bind, boss1_won/boss2_won) and start the story's
## fights and dialogs (Story.start_battle / start_dialog). Without a Story autoload (tools, previews) the dungeon runs
## on its own: local flags in user://dungeon.cfg and Bosses.start_boss for the guardians and bosses.
##
##   DungeonGate.is_open()          entrance flag: the Kindling (mini-boss) is won (Story "s_kindling"), or set_open()
##   DungeonGate.enter(tree)        go down (Story.enter_dungeon when there is a story)
##   DungeonGate.leave(tree)        back up to the overworld at the ruin (Story.exit_dungeon)
##   DungeonGate.cleared()          the final boss is beaten (Story "boss2_won", or the local flag)

const SCENE := "res://scenes/dungeon.tscn"
const SAVE := "user://dungeon.cfg"
const KINGDOM_SAVE := "user://kingdom.cfg"
const DUNGEON_FLAG := "s_kindling"
const FINAL_BOSS := "boss_sovereign"
const FIRST_BOSS := "boss_regnant"
## Where the overworld puts the hero back without a story (tile coords, the Sunken Bastion ruin; Story.exit_dungeon
## uses the same spot).
const OVERWORLD_RETURN := Vector2(32.0, 22.6)

## Random battles per floor (QuestFlow REGION_BATTLES format; levels follow the party like every wild fight).
const BATTLES := {
	"bastion_1": {"area": "riven-choir", "elite": 0.1, "kinds": ["torch", "barrel", "tnt"],
		"foes": {"torch": ["lancer", "gnat"], "barrel": ["pilgrim"], "tnt": ["moth"]}},
	"bastion_2": {"area": "vespergate-sanctum", "elite": 0.2, "kinds": ["barrel", "torch", "tnt"],
		"foes": {"torch": ["lancer", "ashling"], "barrel": ["pilgrim", "brute"], "tnt": ["chanter"]}},
	"bastion_3": {"area": "unlit-throne", "elite": 0.3, "kinds": ["torch", "tnt", "barrel"],
		"foes": {"torch": ["lancer", "ashling"], "barrel": ["pilgrim"], "tnt": ["chanter", "moth"]}},
}

static func story() -> Node:
	var ml := Engine.get_main_loop()
	return (ml as SceneTree).root.get_node_or_null("Story") if ml is SceneTree else null

## A story flag (Story.get_flag), or this dungeon's own copy in user://dungeon.cfg [flags] when there is no story.
static func flag(name: String) -> bool:
	var st := story()
	if st != null and st.has_method("get_flag"): return bool(st.get_flag(name))
	var cf := ConfigFile.new()
	return cf.load(SAVE) == OK and bool(cf.get_value("flags", name, false))

static func set_flag(name: String, v: bool = true) -> void:
	var st := story()
	if st != null and st.has_method("set_flag"):
		st.set_flag(name, v); return
	var cf := ConfigFile.new()
	cf.load(SAVE)
	cf.set_value("flags", name, v)
	cf.save(SAVE)

static func is_open() -> bool:
	var cf := ConfigFile.new()
	if cf.load(SAVE) == OK and bool(cf.get_value("gate", "open", false)): return true
	if story() == null: return true # no story: always open (tools, previews)
	return flag(DUNGEON_FLAG) or flag("s_bastion")

static func set_open(v: bool = true) -> void:
	var cf := ConfigFile.new()
	cf.load(SAVE)
	cf.set_value("gate", "open", v)
	cf.save(SAVE)

static func cleared() -> bool:
	return flag("boss2_won")

static func enter(tree: SceneTree) -> void:
	var st := story()
	if st != null and st.has_method("enter_dungeon"): st.enter_dungeon(); return
	tree.change_scene_to_file.call_deferred(SCENE)

## Back to the overworld, standing at the ruin.
static func leave(tree: SceneTree) -> void:
	var st := story()
	if st != null and st.has_method("exit_dungeon"): st.exit_dungeon(); return
	var cf := ConfigFile.new()
	cf.load(KINGDOM_SAVE)
	cf.set_value("kingdom", "map", "overworld")
	cf.set_value("kingdom", "pos", OVERWORLD_RETURN)
	cf.save(KINGDOM_SAVE)
	tree.change_scene_to_file.call_deferred("res://scenes/kingdom.tscn")

static func reset() -> void:
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
