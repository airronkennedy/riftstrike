extends Node
## Autoload "Bosses" (project.godot): the story-facing boss interface (docs/BOSSES.md).
##
##   Bosses.start_boss("unlit_regnant")              # mini-boss: fight, then back to the scene that called it
##   Bosses.start_boss("ash_sovereign", DUNGEON)     # or name the scene to return to
##   Bosses.boss_defeated.connect(func(id): ...)     # story beat / flags after a win (emitted once back in that scene)
##   Bosses.boss_failed.connect(func(id): ...)       # the party fell (HP left at 1; the boss can be retried)
##   Bosses.is_defeated(id) -> bool                  # saved in user://bosses.cfg
##
## The battle itself runs in main.tscn on the normal auto battle + combo + camera systems (scripts/boss/boss_fight.gd).

signal boss_started(id: String)
signal boss_defeated(id: String)
signal boss_failed(id: String)

const SAVE := "user://bosses.cfg"
const MAIN_SCENE := "res://main.tscn"

var pending := ""          # boss id the battle scene should start
var return_scene := ""     # where to go after the fight
var last_result := {}      # {"id", "won"} of the most recent fight (cleared when the signal is emitted)
var _emit_after_load := {}

## Preview helpers: ?dungeon=1 opens the Vespergate Deeps, ?bossfight=<id> starts that boss fight
## (desktop: -- --dungeon=1 / -- --bossfight=ash_sovereign).
func _ready() -> void:
	var q := ""
	if OS.has_feature("web"):
		var v = JavaScriptBridge.eval("location.search", true)
		if v is String: q = v
	for a in OS.get_cmdline_user_args(): q += "&" + a.trim_prefix("--")
	for kv in q.trim_prefix("?").split("&", false):
		var parts: PackedStringArray = kv.split("=")
		if parts[0] == "dungeon" and (parts.size() < 2 or parts[1] == "1"):
			DungeonGate.enter.call_deferred(get_tree())
		elif parts[0] == "bossfight" and parts.size() > 1 and BossDefs.has(parts[1]):
			start_boss.call_deferred(parts[1], "res://main.tscn")

func start_boss(id: String, return_to: String = "") -> void:
	if not BossDefs.has(id):
		push_warning("Bosses.start_boss: unknown boss " + id)
		return
	pending = id
	var cur := get_tree().current_scene
	return_scene = return_to if return_to != "" else (cur.scene_file_path if cur != null and cur.scene_file_path != "" else "res://scenes/kingdom.tscn")
	boss_started.emit(id)
	get_tree().change_scene_to_file.call_deferred(MAIN_SCENE)

func is_defeated(id: String) -> bool:
	var cf := ConfigFile.new()
	if cf.load(SAVE) != OK: return false
	return bool(cf.get_value("defeated", id, false))

func defeated_list() -> Array:
	var cf := ConfigFile.new()
	if cf.load(SAVE) != OK or not cf.has_section("defeated"): return []
	return Array(cf.get_section_keys("defeated")).filter(func(k): return bool(cf.get_value("defeated", k, false)))

func reset() -> void:
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

## Called by the battle scene when a boss fight ends. Records the result, writes party HP back to the kingdom save,
## then changes to return_scene and emits boss_defeated / boss_failed there.
func finish(id: String, won: bool, frac_left: float) -> void:
	if won:
		var cf := ConfigFile.new()
		cf.load(SAVE)
		cf.set_value("defeated", id, true)
		cf.save(SAVE)
	_write_party_hp(won, frac_left)
	last_result = {"id": id, "won": won}
	pending = ""
	var to := return_scene if return_scene != "" else "res://scenes/kingdom.tscn"
	return_scene = ""
	var qf := get_node_or_null("/root/QuestFlow")
	if qf != null:
		qf.pending_region = ""; qf.in_kingdom_battle = false
	_emit_after_load = last_result
	get_tree().change_scene_to_file.call_deferred(to)
	_emit_deferred.call_deferred()

func _emit_deferred() -> void:
	# one frame after the scene swap so the returning scene's _ready() can connect first
	await get_tree().process_frame
	await get_tree().process_frame
	var r := _emit_after_load
	_emit_after_load = {}
	if r.is_empty(): return
	if bool(r.won): boss_defeated.emit(str(r.id))
	else: boss_failed.emit(str(r.id))

func _write_party_hp(won: bool, frac_left: float) -> void:
	var path := "user://kingdom.cfg"
	var cf := ConfigFile.new()
	cf.load(path)
	var mx := int(cf.get_value("kingdom", "hp_max", 80))
	var qr = load("res://scripts/quest_rpg.gd")
	var hp := maxi(1, int(roundf(float(qr.hp_after_battle(won, frac_left)) * mx)))
	cf.set_value("kingdom", "hp", mini(hp, mx))
	cf.save(path)
