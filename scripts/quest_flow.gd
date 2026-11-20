extends Node
## Autoload "QuestFlow": the main Airron's Quest loop between the Emberhold kingdom and the side-view battle.
##   title (main.tscn) -> New Game / Continue -> kingdom (scenes/kingdom.tscn)
##   kingdom danger meter fills -> Encounters.random_battle_requested(region) -> main.tscn runs that region's fight
##   fight ends -> party_hp written to user://kingdom.cfg -> Encounters.finish_random_battle(won) -> back to the kingdom spot

const KINGDOM_SCENE := "res://scenes/kingdom.tscn"
const MAIN_SCENE := "res://main.tscn"
const KINGDOM_SAVE := "user://kingdom.cfg"

## Region battles: Airron's Fall backdrop, foe level range, elite chance, foe art per archetype, archetype mix.
## Levels follow the walk out of town: meadow 1-3, road 2-4, forest 3-6, shore 5-8, highlands 7-10 (docs/BALANCE.md).
const REGION_BATTLES := {
	"meadow": {"area": "stillmoss-cloister", "level": [1, 3], "elite": 0.0, "kinds": ["torch", "torch", "tnt"],
		"foes": {"torch": ["ashling", "gnat"], "barrel": ["pilgrim"], "tnt": ["moth"]}},
	"forest": {"area": "gallowbough-orchard", "level": [3, 6], "elite": 0.08, "kinds": ["torch", "barrel", "tnt"],
		"foes": {"torch": ["mote", "gnat"], "barrel": ["brute"], "tnt": ["moth", "chanter"]}},
	"highlands": {"area": "tollstone-quarry", "level": [7, 10], "elite": 0.25, "kinds": ["barrel", "torch", "tnt"],
		"foes": {"torch": ["lancer"], "barrel": ["brute", "pilgrim"], "tnt": ["chanter"]}},
	"shore": {"area": "starwreck-strand", "level": [5, 8], "elite": 0.15, "kinds": ["torch", "tnt", "torch"],
		"foes": {"torch": ["mote", "ashling"], "barrel": ["pilgrim"], "tnt": ["moth"]}},
	"road": {"area": "riven-choir", "level": [2, 4], "elite": 0.0, "kinds": ["torch", "barrel", "torch"],
		"foes": {"torch": ["lancer", "ashling"], "barrel": ["brute"], "tnt": ["chanter"]}},
}

var pending_region := "" # set while a kingdom battle is starting or running
var in_kingdom_battle := false

func _ready() -> void:
	var e := get_node_or_null("/root/Encounters")
	if e != null:
		e.random_battle_requested.connect(_on_battle_requested)

func _on_battle_requested(region_id: String) -> void:
	pending_region = region_id if REGION_BATTLES.has(region_id) else "meadow"
	in_kingdom_battle = true
	get_tree().change_scene_to_file.call_deferred(MAIN_SCENE)

## Encounter dictionary for game.gd start_encounter().
func encounter_for(region_id: String) -> Dictionary:
	var r: Dictionary = REGION_BATTLES.get(region_id, REGION_BATTLES.meadow)
	var n := randi_range(2, 3)
	var kinds: Array = (r.kinds as Array).slice(0, n)
	var lv: Array = r.level
	var level := randi_range(int(lv[0]), int(lv[1]))
	var elite: bool = randf() < float(r.get("elite", 0.0))
	return {"area": str(r.area), "kinds": kinds, "level": level, "foes": r.foes, "region": region_id, "elite": elite,
		"mult": foe_mult(level)}

## Foe stat multiplier by level (vs a level-1 regular foe). Keeps pace with class growth (docs/BALANCE.md).
static func foe_mult(level: int) -> Dictionary:
	var l := float(level - 1)
	return {"hp": 0.95 + 0.10 * l, "atk": 0.95 + 0.07 * l, "def": 0.95 + 0.045 * l}

func has_save() -> bool:
	return FileAccess.file_exists(KINGDOM_SAVE)

func party_hp_frac() -> float:
	var cf := ConfigFile.new()
	if cf.load(KINGDOM_SAVE) != OK: return 1.0
	var mx := maxf(1.0, float(cf.get_value("kingdom", "hp_max", 80)))
	return clampf(float(cf.get_value("kingdom", "hp", mx)) / mx, 0.05, 1.0)

func new_game() -> void:
	if FileAccess.file_exists(KINGDOM_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(KINGDOM_SAVE))
	open_kingdom()

func open_kingdom() -> void:
	pending_region = ""; in_kingdom_battle = false
	get_tree().change_scene_to_file.call_deferred(KINGDOM_SCENE)

## frac_left: the party's share of HP left after the fight (0..1). A loss leaves 1 HP: rest at the inn.
func finish_battle(won: bool, frac_left: float) -> void:
	var cf := ConfigFile.new()
	cf.load(KINGDOM_SAVE)
	var mx := int(cf.get_value("kingdom", "hp_max", 80))
	var hp := int(roundf(clampf(frac_left, 0.0, 1.0) * mx))
	hp = maxi(1, hp)
	if won: hp = maxi(hp, int(mx * 0.1))
	cf.set_value("kingdom", "hp", mini(hp, mx))
	cf.save(KINGDOM_SAVE)
	var e := get_node_or_null("/root/Encounters")
	if e != null: e.finish_random_battle(won)
	open_kingdom()
