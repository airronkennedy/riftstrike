class_name BossDefs
extends RefCounted
## Boss data for Airron's Quest (docs/BOSSES.md). Pure data + the stat hook; the fight runs in boss_fight.gd.
##
## Each boss has:
##   art / kind / area   Airron's Fall foe sprite (assets/af/foes/foe-<art>.png), battle kind (torch melee,
##                       barrel bruiser, tnt ranged) and backdrop (assets/af/areas/area-<area>-*.png)
##   tier                "miniboss" | "boss"  -> QuestRPG.FOE_TIER (balance worker); see stat_scale()
##   phases              entered at HP share <= at. Each phase has its own hit frames (timing data, same format as
##                       Combo.FOE_FRAMES), hits per turn ("acts"), a spark window, a ward, and signature attacks
##   signature           name, telegraph ms, frames, target ("all" | "single" | "back"), mult, every N boss turns
##   lines               intro / phase / victory (the boss falls) / defeat (the party falls). Placeholder lines until
##                       docs/STORY.md lands; replace them there or via set_lines().
##
## Mechanics that make Attack Order matter (Brave Frontier style):
##   ward         non-spark hits deal only ward x damage; sparked hits ignore it
##   break_need   sparks on the boss to fill the Break gauge: a Broken boss takes +10% damage and its next turn is
##                one weak plain act (no signature, no second act)
##   spark_window ms; later phases tighten it, so only a well-timed order keeps sparking

const BOSSES := {
	"unlit_regnant": {
		"name": "The Unlit Regnant", "title": "Usurper of the Cold Throne", "art": "regent", "kind": "barrel",
		"area": "unlit-throne", "tier": "miniboss", "level_add": 0, "scale": 1.0, "color": "#9a7cff",
		"adds": [["torch", "ashling"]],
		"ward": 0.95, "break_need": 22,
		"phases": [
			{"at": 1.0, "name": "Cold Court", "acts": 1, "spark_window": 60.0,
				"frames": {"style": "melee", "windup": 320.0, "hits": 3, "interval": 150.0, "travel": 0.0, "mult": 1.0},
				"sig": ["candle_toll"], "sig_every": 3},
			{"at": 0.5, "name": "Snuffed Crown", "acts": 2, "spark_window": 55.0,
				"frames": {"style": "melee", "windup": 220.0, "hits": 4, "interval": 95.0, "travel": 0.0, "mult": 0.85},
				"sig": ["wick_rend", "candle_toll"], "sig_every": 2},
		],
	},
	"ash_sovereign": {
		"name": "The Ash Sovereign", "title": "Last Flame of the Vespergate", "art": "sovereign", "kind": "barrel",
		"area": "vespergate-sanctum", "tier": "boss", "level_add": 0, "scale": 1.0, "color": "#ff8a3d",
		"adds": [["tnt", "chanter"]],
		"ward": 0.97, "break_need": 26,
		"phases": [
			{"at": 1.0, "name": "Ember Regalia", "acts": 1, "spark_window": 60.0,
				"frames": {"style": "melee", "windup": 340.0, "hits": 3, "interval": 140.0, "travel": 0.0, "mult": 1.05},
				"sig": ["ash_comet"], "sig_every": 3},
			{"at": 0.66, "name": "Cinder Tyrant", "acts": 2, "spark_window": 52.0,
				"frames": {"style": "ranged", "windup": 260.0, "hits": 5, "interval": 80.0, "travel": 240.0, "mult": 0.8},
				"sig": ["sovereign_brand", "ash_comet"], "sig_every": 2},
			{"at": 0.33, "name": "Dying Star", "acts": 2, "spark_window": 45.0,
				"frames": {"style": "melee", "windup": 180.0, "hits": 6, "interval": 70.0, "travel": 0.0, "mult": 0.9},
				"sig": ["last_light", "sovereign_brand"], "sig_every": 2},
		],
	},
}

const SIGNATURES := {
	"candle_toll": {"name": "Candle Toll", "telegraph": 1100.0, "target": "all", "mult": 1.15,
		"frames": {"style": "cast", "windup": 420.0, "hits": 3, "interval": 220.0, "travel": 200.0, "mult": 1.15},
		"warn": "The bells drown the light: everyone is hit"},
	"wick_rend": {"name": "Wick Rend", "telegraph": 900.0, "target": "single", "mult": 2.1,
		"frames": {"style": "melee", "windup": 300.0, "hits": 6, "interval": 70.0, "travel": 0.0, "mult": 2.1},
		"warn": "A cold blade marks one keeper"},
	"ash_comet": {"name": "Ash Comet", "telegraph": 1200.0, "target": "all", "mult": 1.25,
		"frames": {"style": "cast", "windup": 500.0, "hits": 4, "interval": 160.0, "travel": 260.0, "mult": 1.25},
		"warn": "Ash falls from the vault: everyone is hit"},
	"sovereign_brand": {"name": "Sovereign's Brand", "telegraph": 1000.0, "target": "back", "mult": 2.3,
		"frames": {"style": "ranged", "windup": 280.0, "hits": 7, "interval": 60.0, "travel": 220.0, "mult": 2.3},
		"warn": "A brand seeks the last in line"},
	"last_light": {"name": "Last Light", "telegraph": 1400.0, "target": "all", "mult": 1.6,
		"frames": {"style": "cast", "windup": 600.0, "hits": 6, "interval": 110.0, "travel": 240.0, "mult": 1.6},
		"warn": "The Sovereign gathers every ember left"},
}

## Placeholder lines (swap for docs/STORY.md's once it lands: set_lines() or edit here).
static var LINES := {
	"unlit_regnant": {
		"intro": "Kneel, keeper. This throne has not felt warmth in a hundred winters, and it will not start with you.",
		"phase": ["You think a spark frightens the dark? Let me snuff your little lights."],
		"victory": "The candles... gutter... Take your festival, then. The cold keeps better company.",
		"defeat": "Sleep. The throne stays cold."},
	"ash_sovereign": {
		"intro": "So the hearth sent its last embers. Come, then. Burn bright, and burn out.",
		"phase": ["You strike in time, like a heartbeat. Then let us see how long the heart lasts.",
			"Enough! If I am to go dark, I take the sky with me!"],
		"victory": "Warm... I had forgotten. Carry it home, keeper. Carry it... home.",
		"defeat": "Ash to ash. The Vespergate closes."},
}

## Stat hook. new_battle() already applies the balance worker's tiers (QuestRPG.FOE_TIER["miniboss"|"boss"],
## FOE_SIZE, TIER_XP) through encounter.tiers / foe_ids. TUNE is an extra per-boss multiplier on top, for the boss
## mechanics here (ward, Break, phases, signatures): 1.0 = the plain tier numbers. Tuned with tools/sim_bosses.gd.
static var TUNE := {
	"unlit_regnant": {"hp": 1.6, "atk": 0.74, "def": 1.0},
	"ash_sovereign": {"hp": 1.6, "atk": 0.78, "def": 1.0},
}

static func has(id: String) -> bool:
	return BOSSES.has(id)

static func get_def(id: String) -> Dictionary:
	return BOSSES.get(id, {})

static func lines(id: String) -> Dictionary:
	return LINES.get(id, {"intro": "", "phase": [], "victory": "", "defeat": ""})

static func set_lines(id: String, d: Dictionary) -> void:
	var cur: Dictionary = lines(id).duplicate()
	for k in d: cur[k] = d[k]
	LINES[id] = cur

static func tune(id: String, stat: String) -> float:
	return float(TUNE.get(id, {}).get(stat, 1.0))

## The encounter dictionary game.gd new_battle() understands (balance worker's tiers / foe_ids hook).
static func encounter(id: String, level: int) -> Dictionary:
	var d: Dictionary = get_def(id)
	var kinds: Array = [str(d.kind)]
	var tiers: Array = [str(d.tier)]
	var ids: Array = [str(d.art)]
	for a in d.get("adds", []):
		kinds.append(str(a[0])); tiers.append("regular"); ids.append(str(a[1]))
	return {"area": str(d.area), "kinds": kinds, "tiers": tiers, "foe_ids": ids, "level": maxi(1, level + int(d.get("level_add", 0))),
		"foes": {}, "region": "boss", "elite": false, "auto": true, "boss": id}

static func phase_index(id: String, hp_frac: float) -> int:
	var ph: Array = get_def(id).get("phases", [])
	var best := 0
	for i in ph.size():
		if hp_frac <= float(ph[i].at) + 0.0001: best = i
	return best
