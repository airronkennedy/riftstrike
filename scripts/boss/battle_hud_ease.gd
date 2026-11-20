class_name BattleHUDEase
extends RefCounted
## Small drawing helpers for the boss HUD (kept out of battle_hud.gd).
static func out(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return 1.0 - pow(1.0 - x, 3.0)

static func closed(p: PackedVector2Array) -> PackedVector2Array:
	var q := p.duplicate(); q.append(p[0]); return q
