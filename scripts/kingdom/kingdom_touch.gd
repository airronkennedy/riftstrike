class_name KingdomTouch
extends RefCounted
## Multitouch router for the kingdom / overworld (no mouse emulation).
##
## Matches Airron's Fall's floating joystick: a finger that lands on the play area spawns the stick
## base under it, the knob follows (clamped to 31% of the base size), a 10% dead zone is cut out and
## rescaled so speed is analog. Other fingers stay free: one can hold the stick while another presses
## Use / Menu (UI hits are routed by rect, per finger index) or taps a person or door.
##
## Feed it InputEventScreenTouch / InputEventScreenDrag via handle(); it returns a list of actions:
##   {type="ui_down", name}, {type="ui_up", name, inside}, {type="tap", pos},
##   {type="stick_start", pos}, {type="stick_end"}
## Pure logic (no nodes), so tools/test_kingdom.gd can drive it.

const TAP_TIME := 0.25   # s: a release sooner than this ...
const TAP_SLOP := 14.0   # ... that moved less than this (px * scale) is a tap, not a stick drag
const DEADZONE := 0.10

var size := 118.0        # stick base diameter in screen px (kingdom sets 118 * ui scale)
var scale := 1.0         # ui scale, for the tap slop
var stick_finger := -1
var origin := Vector2.ZERO
var knob := Vector2.ZERO # knob offset from origin, screen px (clamped)
var vec := Vector2.ZERO  # analog direction, length 0..1 after the dead zone
var fingers := {}        # index -> {start: Vector2, t: float, ui: String, pos: Vector2, moved: float}
## (Vector2 screen pos) -> String: name of the UI button under that point, or "" for the play area.
var hit_ui: Callable = func(_p: Vector2) -> String: return ""


func radius() -> float:
	return size * 0.31


func active() -> bool:
	return stick_finger >= 0


func handle(e: InputEvent, now: float) -> Array:
	var out: Array = []
	if e is InputEventScreenTouch:
		var t := e as InputEventScreenTouch
		if t.pressed:
			_down(t.index, t.position, now, out)
		else:
			_up(t.index, t.position, now, out)
	elif e is InputEventScreenDrag:
		var d := e as InputEventScreenDrag
		_drag(d.index, d.position)
	return out


func _down(i: int, p: Vector2, now: float, out: Array) -> void:
	if fingers.has(i): # iOS can drop a touchend; treat a repeat press as a fresh finger
		_up(i, p, now, out)
	var ui := str(hit_ui.call(p))
	fingers[i] = {"start": p, "t": now, "ui": ui, "pos": p, "moved": 0.0}
	if ui != "":
		out.append({"type": "ui_down", "name": ui})
		return
	if stick_finger < 0:
		stick_finger = i
		origin = p
		knob = Vector2.ZERO
		vec = Vector2.ZERO
		out.append({"type": "stick_start", "pos": p})


func _drag(i: int, p: Vector2) -> void:
	if not fingers.has(i):
		return
	var f: Dictionary = fingers[i]
	f.pos = p
	f.moved = maxf(float(f.moved), p.distance_to(f.start))
	if i == stick_finger:
		_aim(p)


func _aim(p: Vector2) -> void:
	var r := radius()
	var off := p - origin
	knob = off.limit_length(r)
	var raw := off.length() / r
	if raw <= DEADZONE:
		vec = Vector2.ZERO
	else:
		vec = off.normalized() * minf(1.0, (raw - DEADZONE) / (1.0 - DEADZONE))


func _up(i: int, p: Vector2, now: float, out: Array) -> void:
	if not fingers.has(i):
		return
	var f: Dictionary = fingers[i]
	fingers.erase(i)
	var ui := str(f.ui)
	if ui != "":
		out.append({"type": "ui_up", "name": ui, "inside": str(hit_ui.call(p)) == ui})
		return
	var quick: bool = now - float(f.t) < TAP_TIME and maxf(float(f.moved), p.distance_to(f.start)) < TAP_SLOP * scale
	if i == stick_finger:
		stick_finger = -1
		knob = Vector2.ZERO
		vec = Vector2.ZERO
		out.append({"type": "stick_end"})
	if quick:
		out.append({"type": "tap", "pos": f.start})


## Drop every finger (scene change, modal opened, app lost focus).
func reset() -> Array:
	var out: Array = []
	if stick_finger >= 0:
		out.append({"type": "stick_end"})
	stick_finger = -1
	knob = Vector2.ZERO
	vec = Vector2.ZERO
	fingers.clear()
	return out
