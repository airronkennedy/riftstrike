class_name BossDefs
extends RefCounted
## Boss data for Airron's Quest (docs/BOSSES.md). Pure data + the stat hook; the fight runs in boss_fight.gd.
##
## Each boss has:
##   art / kind / area   Airron's Fall foe sprite (assets/af/foes/foe-<art>.png), battle kind (torch melee,
##                       barrel bruiser, tnt ranged) and backdrop (assets/af/areas/area-<area>-*.png)
##   tier                "elite" | "miniboss" | "boss"  -> QuestRPG.FOE_TIER (balance worker)
##   tag                 HUD label: MINI-BOSS, GUARDIAN, FINAL BOSS I / II (the final battle is two story fights)
##   phases              entered at HP share <= at. Each phase has its own hit frames (timing data, same format as
##                       Combo.FOE_FRAMES), hits per turn ("acts"), a spark window, a ward, and signature attacks
##   signature           name, telegraph ms, frames, target ("all" | "single" | "back"), mult, every N boss turns
##   lines               intro / phase / victory (the boss falls) / defeat (the party falls); set_lines() overrides
##
## Mechanics that make Attack Order matter (Brave Frontier style):
##   ward         non-spark hits deal only ward x damage; sparked hits ignore it
##   break_need   sparks on the boss to fill the Break gauge: a Broken boss takes +10% damage and its next turn is
##                one weak plain act (no signature, no second act)
##   spark_window ms; later phases tighten it, so only a well-timed order keeps sparking

## Ids are docs/STORY.md's story fight ids (Story.start_battle / StoryData.BATTLES), so every story boss fight gets
## this presentation automatically (game.gd keys off encounter.story_id). art / tier / area / adds mirror
## StoryData.BATTLES and are only used when a fight starts outside the story (tools, ?bossfight=, Bosses.start_boss
## without a Story autoload).
const BOSSES := {
	"miniboss_matron": {
		"name": "Matron of Cinders", "title": "Mother of the Grey Brood", "art": "matron", "kind": "barrel",
		"area": "vespergate-sanctum", "tier": "miniboss", "tag": "MINI-BOSS", "level": 7, "scale": 1.0, "color": "#c9a2ff",
		"adds": [["torch", "ashling"]],
		"ward": 0.95, "break_need": 22,
		"phases": [
			{"at": 1.0, "name": "Lullaby", "acts": 1, "spark_window": 60.0,
				"frames": {"style": "melee", "windup": 320.0, "hits": 3, "interval": 150.0, "travel": 0.0, "mult": 1.0},
				"sig": ["cinder_lullaby"], "sig_every": 3},
			{"at": 0.5, "name": "Cross Mother", "acts": 2, "spark_window": 55.0,
				"frames": {"style": "melee", "windup": 220.0, "hits": 4, "interval": 95.0, "travel": 0.0, "mult": 0.85},
				"sig": ["smother", "cinder_lullaby"], "sig_every": 2},
		],
	},
	"guardian_f1": {
		"name": "Tithe Collector", "title": "Guardian of the Drowned Gate", "art": "tithe", "kind": "barrel",
		"area": "riven-choir", "tier": "elite", "tag": "GUARDIAN", "level": 8, "scale": 1.0, "color": "#7fd4c8",
		"adds": [["torch", "lancer"], ["torch", "lancer"]],
		"ward": 0.97, "break_need": 18,
		"phases": [
			{"at": 1.0, "name": "Ledger Open", "acts": 1, "spark_window": 60.0,
				"frames": {"style": "melee", "windup": 300.0, "hits": 3, "interval": 140.0, "travel": 0.0, "mult": 1.0},
				"sig": ["final_tally"], "sig_every": 3},
		],
	},
	"guardian_f2": {
		"name": "Knellbearer", "title": "Guardian of the Reliquary Halls", "art": "knell", "kind": "barrel",
		"area": "vespergate-sanctum", "tier": "elite", "tag": "GUARDIAN", "level": 9, "scale": 1.0, "color": "#e0c27a",
		"adds": [["tnt", "chanter"], ["tnt", "chanter"]],
		"ward": 0.97, "break_need": 18,
		"phases": [
			{"at": 1.0, "name": "First Bell", "acts": 1, "spark_window": 60.0,
				"frames": {"style": "melee", "windup": 320.0, "hits": 3, "interval": 150.0, "travel": 0.0, "mult": 1.0},
				"sig": ["death_knell"], "sig_every": 3},
		],
	},
	"boss_regnant": {
		"name": "The Unlit Regnant", "title": "Patron of the Black Glass Throne", "art": "regent", "kind": "barrel",
		"area": "unlit-throne", "tier": "boss", "tag": "FINAL BOSS I", "level": 9, "scale": 1.0, "color": "#9a7cff",
		"adds": [["tnt", "chanter"]],
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
	"boss_sovereign": {
		"name": "The Ash Sovereign", "title": "The Thing Beneath the Throne", "art": "sovereign", "kind": "barrel",
		"area": "unlit-throne", "tier": "boss", "tag": "FINAL BOSS II", "level": 10, "scale": 1.0, "color": "#ff8a3d",
		"adds": [["torch", "ashling"]],
		"ward": 0.97, "break_need": 26,
		"phases": [
			{"at": 1.0, "name": "Grey Crown", "acts": 1, "spark_window": 60.0,
				"frames": {"style": "melee", "windup": 340.0, "hits": 3, "interval": 140.0, "travel": 0.0, "mult": 1.05},
				"sig": ["ash_comet"], "sig_every": 3},
			{"at": 0.66, "name": "Nine Kings' Ash", "acts": 2, "spark_window": 52.0,
				"frames": {"style": "ranged", "windup": 260.0, "hits": 5, "interval": 80.0, "travel": 240.0, "mult": 0.8},
				"sig": ["sovereign_brand", "ash_comet"], "sig_every": 2},
			{"at": 0.33, "name": "Every Fire Gone Out", "acts": 2, "spark_window": 45.0,
				"frames": {"style": "melee", "windup": 180.0, "hits": 6, "interval": 70.0, "travel": 0.0, "mult": 0.9},
				"sig": ["last_light", "sovereign_brand"], "sig_every": 2},
		],
	},
}

const SIGNATURES := {
	"cinder_lullaby": {"name": "Cinder Lullaby", "telegraph": 1100.0, "target": "all", "mult": 1.15,
		"frames": {"style": "cast", "windup": 420.0, "hits": 3, "interval": 220.0, "travel": 200.0, "mult": 1.15},
		"warn": "Hush now: hot ash rains on everyone"},
	"smother": {"name": "Smother", "telegraph": 900.0, "target": "single", "mult": 2.1,
		"frames": {"style": "melee", "windup": 300.0, "hits": 6, "interval": 70.0, "travel": 0.0, "mult": 2.1},
		"warn": "Mother pulls one keeper close"},
	"final_tally": {"name": "Final Tally", "telegraph": 900.0, "target": "back", "mult": 1.9,
		"frames": {"style": "melee", "windup": 300.0, "hits": 5, "interval": 75.0, "travel": 0.0, "mult": 1.9},
		"warn": "The ledger names the last in line"},
	"death_knell": {"name": "Death Knell", "telegraph": 1000.0, "target": "all", "mult": 1.1,
		"frames": {"style": "cast", "windup": 420.0, "hits": 3, "interval": 200.0, "travel": 200.0, "mult": 1.1},
		"warn": "The great bell swings: everyone is hit"},
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

## Short in-battle lines (the long pre- and post-fight scenes are the story's dialogs, scripts/story/story_dialog.gd).
## Voices match docs/STORY.md: the Matron coos, the Regnant and the Sovereign speak in capitals.
static var LINES := {
	"miniboss_matron": {
		"intro": "Hush now, little embers. Mother is here.",
		"phase": ["Mother is cross now. Into the ash with you, all of you."],
		"victory": "Hush... hush... the braziers are... so bright...",
		"defeat": "There. Sleep, little embers. Mother will keep you warm."},
	"guardian_f1": {
		"intro": "Every soul that passes the Drowned Gate owes a tithe. Yours is overdue.",
		"phase": [],
		"victory": "The ledger... does not balance...",
		"defeat": "Paid in full."},
	"guardian_f2": {
		"intro": "Every bell in these halls rang for someone. This one rings for you.",
		"phase": [],
		"victory": "The last bell... stops...",
		"defeat": "Ring, ring, and be still."},
	"boss_regnant": {
		"intro": "LITTLE LAMPLIGHTER. YOU BROUGHT ME GUESTS.",
		"phase": ["YOU STRIKE TOGETHER, LIKE A HEARTBEAT. LET ME STOP IT."],
		"victory": "THE GLASS... BREAKS... BENEATH ME, HE WAKES...",
		"defeat": "DOWN THE STAIRS, ALWAYS DOWN. AND NEVER UP AGAIN."},
	"boss_sovereign": {
		"intro": "NINE KINGS. ONE LID. AND NOW... A BARROW-KNIGHT.",
		"phase": ["A HUNDRED YEARS UNDER A CHAIR. DO YOU KNOW HOW COLD THAT IS?",
			"THEN BURN, ALL OF YOU. IF I GO OUT, I TAKE EVERY FIRE WITH ME."],
		"victory": "Warm... I had forgotten warm...",
		"defeat": "ASH TO ASH. THE THRONE GOES COLD."},
}

## Stat hook. new_battle() already applies the balance worker's tiers (QuestRPG.FOE_TIER["miniboss"|"boss"],
## FOE_SIZE, TIER_XP) through encounter.tiers / foe_ids. TUNE is an extra per-boss multiplier on top, for the boss
## mechanics here (ward, Break, phases, signatures): 1.0 = the plain tier numbers. Tuned with tools/sim_bosses.gd.
static var TUNE := {
	"miniboss_matron": {"hp": 1.6, "atk": 0.74, "def": 1.0},
	"guardian_f1": {"hp": 1.0, "atk": 1.0, "def": 1.0},
	"guardian_f2": {"hp": 1.0, "atk": 1.0, "def": 1.0},
	"boss_regnant": {"hp": 1.05, "atk": 0.84, "def": 1.0},
	"boss_sovereign": {"hp": 1.2, "atk": 0.64, "def": 1.0},
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

## The boss id for an encounter dictionary: encounter.boss when it is a boss id (Bosses.start_boss / tools), else
## encounter.story_id when that story fight has a boss here. "" = a normal fight.
static func id_for(enc: Dictionary) -> String:
	var b = enc.get("boss", "")
	if b is String and has(b): return b
	var sid := str(enc.get("story_id", ""))
	return sid if has(sid) else ""

## The encounter dictionary game.gd new_battle() understands (balance worker's tiers / foe_ids hook). Uses the
## story's own encounter (Story.encounter_for) when the Story autoload is there, so tools fight the real thing.
static func encounter(id: String, level: int) -> Dictionary:
	var ml := Engine.get_main_loop()
	var st: Node = (ml as SceneTree).root.get_node_or_null("Story") if ml is SceneTree else null
	if st != null and st.has_method("encounter_for"):
		var se: Dictionary = st.encounter_for(id, level)
		if not se.is_empty():
			se["boss"] = id
			return se
	var d: Dictionary = get_def(id)
	var kinds: Array = [str(d.kind)]
	var tiers: Array = [str(d.tier)]
	var ids: Array = [str(d.art)]
	for a in d.get("adds", []):
		kinds.append(str(a[0])); tiers.append("regular"); ids.append(str(a[1]))
	return {"area": str(d.area), "kinds": kinds, "tiers": tiers, "foe_ids": ids, "level": maxi(1, level),
		"foes": {}, "region": "boss", "elite": false, "auto": true, "boss": id, "story_id": id}

static func phase_index(id: String, hp_frac: float) -> int:
	var ph: Array = get_def(id).get("phases", [])
	var best := 0
	for i in ph.size():
		if hp_frac <= float(ph[i].at) + 0.0001: best = i
	return best
