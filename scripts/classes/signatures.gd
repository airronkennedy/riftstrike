extends RefCounted
## Signature abilities (docs/CLASSES.md): one per keeper, tied to the CHARACTER, not to the class, so who you bring
## matters beyond looks. Same row format as quest_rpg.gd class abilities, plus one light twist:
##   "classes": [..]  -> cast while that keeper is one of these classes it is EMPOWERED (the "+" row)
##   "combo": n       -> cast right after a turn where the party sparked n+ times it is EMPOWERED
##   "finisher": true -> cast from the LAST slot of the Attack Order (they land after everyone) it is EMPOWERED
## Empowered casts use a separate ability id "<id>_x" (its own params), so nothing in combat needs to know.
## Keepers without a row here use their Airron's Fall weapon signature (game.gd SIG_AB) and have no twist.

## Signatures wake at this keeper level (their equipped class level) and fire at most once per battle (tactics.gd).
const SIG_LEVEL := 3

const ROWS := {
	"Bramwell": {"id": "sig_barrow_watch", "name": "Barrow Watch", "kind": "damage_single", "cond": "boss",
		"blurb": "Plants the old Watch banner and swings: a heavy blow, and the party digs in (Defense up).",
		"params": {"mult": 2.4, "party_buff": [["def", 10]], "pturns": 2},
		"twist": "Knight or Guardian: the banner holds (bigger hit, Defense + Armor up).", "classes": ["Knight", "Guardian"],
		"x": {"mult": 3.0, "party_buff": [["def", 16], ["armor", 6]], "pturns": 2}},
	"Grieve": {"id": "sig_second_burial", "name": "Second Burial", "kind": "damage_single", "cond": "foe_low",
		"blurb": "Puts something back in the ground. One foe, very hard, and its Defense cracks.",
		"params": {"mult": 3.0, "debuff": [["def", -8]], "dturns": 2},
		"twist": "Combo finisher: from the last Attack Order slot it lands after everyone (x3.8).", "finisher": true,
		"x": {"mult": 3.8, "debuff": [["def", -12]], "dturns": 2}},
	"Halvard": {"id": "sig_anvil_oath", "name": "Anvil Oath", "kind": "damage_all_enemies", "cond": "foes_2",
		"blurb": "Drops the anvil. The ground answers under every foe, and he braces (self Defense up).",
		"params": {"mult": 1.25, "self_buff": [["def", 14]], "sturns": 2},
		"twist": "Guardian or Warrior: the old baron remembers his mines (x1.6, Armor too).", "classes": ["Guardian", "Warrior"],
		"x": {"mult": 1.6, "self_buff": [["def", 20], ["armor", 8]], "sturns": 2}},
	"Corvin": {"id": "sig_called_shot", "name": "Called Shot", "kind": "damage_single", "cond": "boss",
		"blurb": "Names the odds, then beats them: one brass round at one foe.",
		"params": {"mult": 2.5, "self_buff": [["crit", 8]], "sturns": 2},
		"twist": "Spark streak: after a turn with 3+ sparks the odds are 'excellent' (x3.4).", "combo": 3,
		"x": {"mult": 3.4, "self_buff": [["crit", 14]], "sturns": 2}},
	"Ilsabet": {"id": "sig_tidal_decree", "name": "Tidal Decree", "kind": "heal_party", "cond": "ally_hurt",
		"blurb": "A queen's decree, and the tide obeys: the party is healed and its ATK rises.",
		"params": {"pct": 0.17, "party_buff": [["atk", 6]], "pturns": 2},
		"twist": "Cleric or Bard: the court sings with her (bigger heal, more ATK).", "classes": ["Cleric", "Bard"],
		"x": {"pct": 0.24, "party_buff": [["atk", 10]], "pturns": 2}},
}

## Register every signature (and its empowered twin) in game.gd ABILITY_DEFS. Called at the end of build_rpg().
static func register(g: Object) -> void:
	for nm in ROWS:
		var r: Dictionary = ROWS[nm]
		g.ABILITY_DEFS[r.id] = {"id": r.id, "name": r.name, "blurb": r.blurb, "kind": r.kind, "params": r.params,
			"lv": SIG_LEVEL, "cond": r.cond, "src": "sig", "owner": nm, "mp": g.AB_MP, "tier": 3, "twist": r.twist}
		g.ABILITY_DEFS[r.id + "_x"] = {"id": r.id + "_x", "name": r.name + "+", "blurb": r.blurb, "kind": r.kind, "params": r.x,
			"lv": SIG_LEVEL, "cond": r.cond, "src": "sig", "owner": nm, "mp": g.AB_MP, "tier": 3, "twist": r.twist, "empowered": true}

## The keeper's signature ability id ("" if none).
static func id_for(g: Object, name: String) -> String:
	if ROWS.has(name): return str(ROWS[name].id)
	var s: String = str(g.SIG_AB.get(name, ""))
	return s if g.ABILITY_DEFS.has(s) else ""

static func row(name: String) -> Dictionary:
	return ROWS.get(name, {})

static func twist(name: String) -> String:
	return str(ROWS.get(name, {}).get("twist", ""))

## True when this cast should use the empowered twin (class match, spark streak or finisher slot).
static func empowered(g: Object, u) -> bool:
	var r: Dictionary = ROWS.get(str(u.name), {})
	if r.is_empty(): return false
	if r.has("classes") and (r.classes as Array).has(str(g.CHAR[u.name].cls)): return true
	if r.has("combo") and g.G != null and int(g.G.summary.get("sparks", 0)) >= int(r.combo): return true
	if bool(r.get("finisher", false)):
		var order: Array = g.attack_order()
		var alive_names: Array = []
		for nm in order:
			for a in g.alive("blue"):
				if a.name == nm: alive_names.append(nm); break
		if alive_names.size() >= 2 and alive_names[-1] == u.name: return true
	return false

## Would this keeper's signature be empowered in their CURRENT class? (screens; "finisher"/"combo" are battle-time)
static func class_match(name: String, cls: String) -> bool:
	var r: Dictionary = ROWS.get(name, {})
	return r.has("classes") and (r.classes as Array).has(cls)
