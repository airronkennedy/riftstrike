extends RefCounted
## Auto-cast tactics (docs/CLASSES.md): a Gambit-style rule list per keeper, set up out of battle; combat stays AUTO.
## Rules live in game.gd AB_SEQ[name] = [[ability id, condition id], ...], checked top-down whenever the keeper's
## Brave gauge is full. Signatures fire at most ONCE per battle. The first rule whose ability is unlocked + switched on and whose condition passes fires.
## Special rule id "hold" ("Save Brave Burst"): when its condition passes, the keeper attacks normally and KEEPS the
## full gauge (e.g. hold if no boss is here). AB_OFF[name] = [ability ids switched off]: they never auto-cast.
## Add a condition: one entry in CONDITIONS (label), its place in COND_ORDER, and a branch in check().

const HOLD := "hold"
const CONDITIONS := {
	"always": "always",
	"turn_1": "at battle start",
	"boss": "on a boss or elite",
	"no_boss": "no boss or elite here",
	"ally_hurt": "an ally < 75% HP",
	"ally_low": "an ally < 50% HP",
	"ally_40": "an ally < 40% HP",
	"self_low": "self < 50% HP",
	"foes_2": "2+ foes left",
	"foes_3": "3+ foes left",
	"foe_low": "a foe < 30% HP",
	"combo_3": "last turn sparked 3+",
}
const COND_ORDER := ["always", "turn_1", "boss", "no_boss", "ally_hurt", "ally_low", "ally_40", "self_low", "foes_2", "foes_3", "foe_low", "combo_3"]

## Conditions this module adds on top of game.gd seq_condition_ok (which knows the original ones).
static func handles(cond: String) -> bool:
	return cond in ["ally_40", "no_boss", "combo_3"]

static func check(g: Object, u, cond: String) -> bool:
	match cond:
		"ally_40":
			for a in g.alive(u.team):
				if float(a.hp) / maxf(1.0, float(a.maxhp)) < 0.4: return true
			return false
		"no_boss": return not g.seq_condition_ok(u, "boss")
		"combo_3":
			return g.G != null and int(g.G.summary.get("sparks", 0)) >= 3
	return false

static func label(cond: String) -> String:
	return str(CONDITIONS.get(cond, cond))

static func is_off(g: Object, name: String, id: String) -> bool:
	return (g.AB_OFF.get(name, []) as Array).has(id)

static func set_off(g: Object, name: String, id: String, off: bool) -> void:
	var a: Array = (g.AB_OFF.get(name, []) as Array).duplicate()
	if off and not a.has(id): a.append(id)
	if not off: a.erase(id)
	g.AB_OFF[name] = a

static func save(g: Object, cf: ConfigFile) -> void:
	for nm in g.AB_OFF: cf.set_value("ab_off", str(nm), ",".join(g.AB_OFF[nm]))
	cf.set_value("rs", "sig_seen", ",".join(g.SIG_SEEN.keys()))

static func load_from(g: Object, cf: ConfigFile) -> void:
	g.AB_OFF = {}
	g.SIG_SEEN = {}
	for nm in str(cf.get_value("rs", "sig_seen", "")).split(",", false): g.SIG_SEEN[nm] = true
	if not cf.has_section("ab_off"): return
	for nm in cf.get_section_keys("ab_off"):
		g.AB_OFF[nm] = Array(str(cf.get_value("ab_off", nm, "")).split(",", false))

## Old saves: put the signature rule on top of a saved plan once (SIG_SEEN remembers it, so removing it sticks).
static func migrate(g: Object, name: String) -> void:
	var sg: String = g._sig_list(name)[0] if not g._sig_list(name).is_empty() else ""
	if sg == "" or g.SIG_SEEN.has(name): return
	var rules: Array = g.AB_SEQ.get(name, [])
	if not rules.any(func(rr): return str(rr[0]) == sg):
		rules.push_front([sg, str(g.ABILITY_DEFS[sg].get("cond", "always"))])
	g.AB_SEQ[name] = rules
	g.SIG_SEEN[name] = true

## The ability a full gauge fires (replaces game.gd seq_pick's loop): "" = basic attack, gauge kept.
static func pick(g: Object, u) -> String:
	var name: String = str(u.name)
	var lo: Array = g.loadout_of(name) + g._sig_list(name) # class 2 + subclass 2, plus the keeper's signature
	for rr in g.seq_of(name):
		var id: String = str(rr[0])
		var cond: String = str(rr[1])
		if id == HOLD:
			if g.seq_condition_ok(u, cond): return ""
			continue
		if lo.find(id) < 0 or not g.ab_unlocked(name, id) or is_off(g, name, id): continue
		var sig: bool = str(g.ABILITY_DEFS[id].get("src", "")) == "sig"
		if sig and u.has_meta("sig_used"): continue # a signature is a once-per-battle move
		if g.seq_condition_ok(u, cond) and g.auto_wants(u, id):
			if sig:
				u.set_meta("sig_used", true)
				if g.ABILITY_DEFS.has(id + "_x") and Signatures.empowered(g, u): return id + "_x"
			return id
	return ""

const Signatures = preload("res://scripts/classes/signatures.gd")
