extends Node
## Autoload "Encounters" (project.godot). The one hook the kingdom overworld calls when the danger meter fills.
##
## Connect the battle scene to it, e.g. in the battle owner's _ready():
##     Encounters.random_battle_requested.connect(_on_random_battle)   # func _on_random_battle(region_id: String)
## and call Encounters.finish_random_battle(won) when the fight is over so the overworld resumes.
## With nothing connected, start_random_battle() is a harmless stub: the overworld shows a toast and keeps going.
##
## Also: open the kingdom from the web preview with ?kingdom=1 (or `-- --kingdom=1` on the command line).

signal random_battle_requested(region_id: String)
signal random_battle_finished(won: bool)

const KINGDOM_SCENE := "res://scenes/kingdom.tscn"

var enabled := true          # set false to switch random battles off (debug / cutscenes)
var battles_started := 0     # counters for tests and debugging
var last_region := ""
var _redirect_done := false


## Called by scripts/kingdom/kingdom.gd when the overworld danger meter fills. region_id is one of
## "meadow", "forest", "highlands", "shore", "road" (see KingdomMaps.REGIONS).
func start_random_battle(region_id: String) -> void:
	if not enabled:
		return
	battles_started += 1
	last_region = region_id
	random_battle_requested.emit(region_id)


## True when something (the battle scene) listens; the overworld then waits for finish_random_battle().
func has_battle_listener() -> bool:
	return random_battle_requested.get_connections().size() > 0


func finish_random_battle(won: bool = true) -> void:
	random_battle_finished.emit(won)


func _ready() -> void:
	if _wants_kingdom():
		_redirect_done = true
		_open_kingdom.call_deferred()


func _open_kingdom() -> void:
	var cur := get_tree().current_scene
	if cur == null or cur.scene_file_path != KINGDOM_SCENE:
		get_tree().change_scene_to_file(KINGDOM_SCENE)


func _wants_kingdom() -> bool:
	if _redirect_done:
		return false
	for a in OS.get_cmdline_user_args():
		if a == "--kingdom=1" or a == "--kingdom":
			return true
	if OS.has_feature("web"):
		var q = JavaScriptBridge.eval("location.search", true)
		if q is String and (q as String).contains("kingdom"):
			return true
	return false
