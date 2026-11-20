class_name TargetSelect
extends RefCounted
## Target select before each party turn (side-view auto battle).
## Every party turn opens with a short window (game.gd SELECT_MS): tap a foe to focus the whole team on it, or let the
## countdown run out (AUTO skips the window) and the team auto-targets with the player's chosen setting below.
## The setting is picked outside combat (Emberhold menu -> "Auto target") and saved in user://targeting.cfg.
##
## Hook for the attack sequence: game.gd emits party_target_locked(focus) once the focus is final and then calls
## bf_run_party_turn(focus) (the combo worker's ComboTurn). Listen to that signal for any pre-strike effect.

const SAVE := "user://targeting.cfg"
const MODES := ["weakest", "threat", "elite", "backline"]
const LABELS := {"weakest": "Finish Off", "threat": "Biggest Threat", "elite": "Elites First", "backline": "Backline First"}
const HINTS := {
	"weakest": "The foe with the least HP left: fewer enemy hits per turn.",
	"threat": "The foe with the highest attack: cut the damage you take.",
	"elite": "Elites first (break the big one early), then the weakest.",
	"backline": "Archers and casters first, then the weakest.",
}

static var _mode := ""

static func mode() -> String:
	if _mode == "":
		var cf := ConfigFile.new()
		_mode = str(cf.get_value("target", "mode", "weakest")) if cf.load(SAVE) == OK else "weakest"
		if not MODES.has(_mode): _mode = "weakest"
	return _mode

static func set_mode(m: String) -> void:
	if not MODES.has(m): return
	_mode = m
	var cf := ConfigFile.new()
	cf.load(SAVE)
	cf.set_value("target", "mode", m)
	cf.save(SAVE)

## Next setting in MODES order (menu button); returns the new mode.
static func cycle() -> String:
	set_mode(MODES[(MODES.find(mode()) + 1) % MODES.size()])
	return _mode

static func label(m: String = "") -> String:
	return str(LABELS.get(m if m != "" else mode(), "Finish Off"))

## The foe the whole party focuses when the player did not tap one. foes: living red units.
static func pick(foes: Array, m: String = ""):
	if foes.is_empty(): return null
	if m == "": m = mode()
	var best = null
	var best_k := -INF
	for f in foes:
		var hp_frac := float(f.hp) / maxf(1.0, float(f.maxhp))
		var k := 0.0
		match m:
			"threat": k = float(f.atk) * 10.0 - hp_frac
			"elite": k = (1000.0 if str(f.tier) != "regular" else 0.0) - float(f.hp) * 0.01 # then the weakest
			"backline": k = (1000.0 if str(f.K.get("ranged", "")) != "" else 0.0) - float(f.hp) * 0.01
			_: k = -float(f.hp) - hp_frac # weakest: least HP left, ties to the more hurt one
		if best == null or k > best_k:
			best = f; best_k = k
	return best
