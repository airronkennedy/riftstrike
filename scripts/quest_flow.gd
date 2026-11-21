extends Node
const QuestRPG = preload("res://scripts/quest_rpg.gd")
## Autoload "QuestFlow": the main Airron's Quest loop between the Emberhold kingdom and the side-view battle.
##   title (main.tscn) -> New Game / Continue -> kingdom (scenes/kingdom.tscn)
##   kingdom danger meter fills -> Encounters.random_battle_requested(region) -> main.tscn runs that region's fight
##   fight ends -> party_hp written to user://kingdom.cfg -> Encounters.finish_random_battle(won) -> back to the kingdom spot

const KINGDOM_SCENE := "res://scenes/kingdom.tscn"
const MAIN_SCENE := "res://main.tscn"
const KINGDOM_SAVE := "user://kingdom.cfg"

## Region battles: Airron's Fall backdrop, elite chance, foe art per archetype, archetype mix.
## Foe levels follow the party (QuestRPG.foe_level: party level ± 1), so regions differ by foe pool and elites (docs/BALANCE.md).
const REGION_BATTLES := {
	"meadow": {"area": "stillmoss-cloister", "elite": 0.0, "kinds": ["torch", "torch", "tnt"],
		"foes": {"torch": ["ashling", "gnat"], "barrel": ["pilgrim"], "tnt": ["moth"]}},
	"forest": {"area": "gallowbough-orchard", "elite": 0.08, "kinds": ["torch", "barrel", "tnt"],
		"foes": {"torch": ["mote", "gnat"], "barrel": ["brute"], "tnt": ["moth", "chanter"]}},
	"highlands": {"area": "tollstone-quarry", "elite": 0.25, "kinds": ["barrel", "torch", "tnt"],
		"foes": {"torch": ["lancer"], "barrel": ["brute", "pilgrim"], "tnt": ["chanter"]}},
	"shore": {"area": "starwreck-strand", "elite": 0.15, "kinds": ["torch", "tnt", "torch"],
		"foes": {"torch": ["mote", "ashling"], "barrel": ["pilgrim"], "tnt": ["moth"]}},
	"road": {"area": "riven-choir", "elite": 0.0, "kinds": ["torch", "barrel", "torch"],
		"foes": {"torch": ["lancer", "ashling"], "barrel": ["brute"], "tnt": ["chanter"]}},
}

var pending_region := "" # set while a kingdom battle is starting or running
var return_scene := "" # scene to go back to after the fight (the dungeon sets this; default: the kingdom)
var in_kingdom_battle := false
var pending_screen := "" # "build": main.tscn opens Build (Attack Order) and Back returns to the kingdom (Story journal)

func _ready() -> void:
	var e := get_node_or_null("/root/Encounters")
	if e != null:
		e.random_battle_requested.connect(_on_battle_requested)

func _on_battle_requested(region_id: String) -> void:
	pending_region = region_id if (REGION_BATTLES.has(region_id) or DungeonGate.BATTLES.has(region_id)) else "meadow"
	in_kingdom_battle = true
	get_tree().change_scene_to_file.call_deferred(MAIN_SCENE)

## Encounter dictionary for game.gd start_encounter().
## Regions pick the art, the foe pool and the elite chance only. The level comes from the party (auto-levelling,
## QuestRPG.foe_level / foe_scale, docs/BALANCE.md); pass it in, or -1 to use the saved party's level.
func encounter_for(region_id: String, level: int = -1) -> Dictionary:
	var story := get_node_or_null("/root/Story")
	if region_id.begins_with("story:") and story != null: # story fights: scripts/story/story_data.gd BATTLES
		return story.encounter_for(region_id.substr(6), level)
	var r: Dictionary = REGION_BATTLES.get(region_id, DungeonGate.BATTLES.get(region_id, REGION_BATTLES.meadow))
	var n := randi_range(2, 3)
	if story != null: n = mini(n, story.max_foes()) # the hero starts alone; fights grow with the party
	var kinds: Array = (r.kinds as Array).slice(0, n)
	if level < 1: level = QuestRPG.foe_level(1.0)
	var elite: bool = randf() < float(r.get("elite", 0.0))
	# foe_mult: the story's small-party scaling times QuestRPG.WILD_FOE (wild fights only, docs/BALANCE.md)
	var fm: Dictionary = story.party_mult() if story != null else {}
	fm = {"hp": float(fm.get("hp", 1.0)) * float(QuestRPG.WILD_FOE.hp), "atk": float(fm.get("atk", 1.0)) * float(QuestRPG.WILD_FOE.atk)}
	return {"area": str(r.area), "kinds": kinds, "level": level, "foes": r.foes, "region": region_id, "elite": elite,
		"auto": true, "foe_mult": fm}

func has_save() -> bool:
	return FileAccess.file_exists(KINGDOM_SAVE)

func party_hp_frac() -> float:
	var cf := ConfigFile.new()
	if cf.load(KINGDOM_SAVE) != OK: return 1.0
	var mx := maxf(1.0, float(cf.get_value("kingdom", "hp_max", 80)))
	return clampf(float(cf.get_value("kingdom", "hp", mx)) / mx, 0.05, 1.0)

func new_game() -> void:
	return_scene = ""
	if FileAccess.file_exists(KINGDOM_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(KINGDOM_SAVE))
	var story := get_node_or_null("/root/Story")
	if story != null: story.reset()
	DungeonGate.reset() # dungeon floor, doors, chests and keys start over too
	var bs := get_node_or_null("/root/Bosses")
	if bs != null: bs.reset()
	open_kingdom()

func open_kingdom() -> void:
	pending_region = ""; in_kingdom_battle = false
	var to := return_scene if return_scene != "" else KINGDOM_SCENE
	return_scene = ""
	get_tree().change_scene_to_file.call_deferred(to)

## frac_left: the party's share of HP left after the fight (0..1). A loss leaves 1 HP: rest at the inn.
func finish_battle(won: bool, frac_left: float) -> void:
	var cf := ConfigFile.new()
	cf.load(KINGDOM_SAVE)
	var mx := int(cf.get_value("kingdom", "hp_max", 80))
	var hp := int(roundf(QuestRPG.hp_after_battle(won, frac_left) * mx))
	hp = maxi(1, hp)
	cf.set_value("kingdom", "hp", mini(hp, mx))
	cf.save(KINGDOM_SAVE)
	var story := get_node_or_null("/root/Story")
	if story != null and pending_region.begins_with("story:"):
		# Story fight: record the result (win / lose dialog plays back in the scene it came from).
		story.on_battle_done(pending_region.substr(6), won)
		var back: String = story.take_return_scene()
		pending_region = ""; in_kingdom_battle = false
		get_tree().change_scene_to_file.call_deferred(back)
		return
	var e := get_node_or_null("/root/Encounters")
	if e != null: e.finish_random_battle(won)
	open_kingdom()
