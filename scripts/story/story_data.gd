extends RefCounted
## Airron's Quest main story data (see docs/STORY.md): cast, objective steps, NPC and spot placements per kingdom map,
## story fights and heirloom items. The dialog text lives in story_dialog.gd. The engine is story.gd (autoload "Story").
##
## Conditions (cond / talk rules) are strings: flags joined by "&", "!" negates, plus a few counters:
##   "s_king&!got_grieve"   "sparks>=4"   "loyal>=3"   "gold>=50"   "party>=2"   "" (always)
## Talk rules: [cond, dialog id, marker] checked top-down, first match wins. Marker: "!" story beat, "?" objective
## target, "s" side quest offer / turn-in (pale blue), "" none.

const RECRUITS := ["grieve", "halvard", "corvin", "ilsabet"]
const HERO := "bramwell"

## Who speaks. art: hero sprite id (assets/af/heroes) or "foe:<id>" (assets/af/foes). "" = no portrait (narration).
const CAST := {
	"narr": {"name": "", "art": ""},
	"bramwell": {"name": "Bramwell", "art": "bramwell", "title": "Knight of the Barrow Watch"},
	"vellin": {"name": "Vellin", "art": "vellin", "title": "Gate-serjeant"},
	"orlan": {"name": "King Orlan", "art": "orlan", "title": "Ninth of the Ember Crown"},
	"selka": {"name": "Selka", "art": "selka", "title": "Royal armillary-scribe"},
	"taren": {"name": "Taren Unlit", "art": "taren", "title": "Royal Lamplighter"},
	"caldric": {"name": "Ser Caldric", "art": "caldric", "title": "Knight of the Cinder Gate"},
	"maera": {"name": "Aunt Maera", "art": "maera", "title": "Hearth-tender"},
	"pell": {"name": "Pell", "art": "pell", "title": "Firewright"},
	"wenna": {"name": "Sister Wenna", "art": "wenna", "title": "Mendicant of the Quiet Bell"},
	"joryn": {"name": "Joryn", "art": "joryn", "title": "Stall-keeper"},
	"drosk": {"name": "Drosk", "art": "drosk", "title": "Coinwright"},
	"grieve": {"name": "Grieve", "art": "grieve", "title": "Warden of Roots"},
	"halvard": {"name": "Halvard", "art": "halvard", "title": "Warden of the Forge"},
	"corvin": {"name": "Corvin", "art": "corvin", "title": "Warden of the Star"},
	"ilsabet": {"name": "Ilsabet", "art": "ilsabet", "title": "Warden of the Tide"},
	"matron": {"name": "Matron of Cinders", "art": "foe:matron"},
	"cardinal": {"name": "The Drowned Cardinal", "art": "foe:cardinal"},
	"regnant": {"name": "The Unlit Regnant", "art": "foe:regent"},
	"sovereign": {"name": "The Ash Sovereign", "art": "foe:sovereign"},
	"leaper": {"name": "Charnel Leaper", "art": "foe:leaper"},
	"engine": {"name": "Reliquary Engine", "art": "foe:engine"},
	"knell": {"name": "Knellbearer", "art": "foe:knell"},
}

const ACTS := {
	"P": "Prologue",
	"I": "Act I  ·  The Summons",
	"II": "Act II  ·  The Wardfires",
	"III": "Act III  ·  Kindling Night",
	"IV": "Act IV  ·  The Sunken Bastion",
	"E": "Epilogue",
}

## Main story steps in order. A step is done when its flag is set; the objective is the first visible step not done.
## target: {map, x, y} in tiles (kingdom maps) or {npc: id} (looked up in NPCS). rec: recommended party level.
const STEPS := [
	{"id": "s_prologue", "act": "P", "title": "A Summons at the Gate", "text": "Vellin the gate-serjeant is waving you down.", "hint": "Walk up to him and tap him (or press E) to talk.", "target": {"npc": "vellin"}},
	{"id": "s_king", "act": "I", "title": "The King's Summons", "text": "Go north through town to Castle Emberhold and speak with King Orlan.", "hint": "The castle gate is at the top of the main road.", "target": {"npc": "orlan"}},
	{"id": "s_maera", "act": "I", "title": "Aunt Maera", "text": "Visit Aunt Maera at your house before you set out.", "hint": "Bramwell's House is on the west side of town.", "target": {"npc": "maera"}},
	{"id": "got_grieve", "act": "II", "title": "The Wardfire of Roots", "text": "Find the Warden at Gloamwood Heart, in the western forest.", "hint": "Leave town by the south road, then head west.", "rec": 2, "target": {"npc": "grieve"}},
	{"id": "got_halvard", "act": "II", "title": "The Wardfire of the Forge", "text": "Find the Warden at Coalvein Cave, in the north of the isle.", "hint": "Follow the King's Road north from the town gate.", "rec": 3, "target": {"npc": "halvard"}},
	{"id": "got_corvin", "act": "II", "title": "The Wardfire of the Star", "text": "Find the Warden at Cliff Overlook, on the eastern heights.", "hint": "Cross the Ashen Heights through the pass in the ridge.", "rec": 5, "target": {"npc": "corvin"}},
	{"id": "got_ilsabet", "act": "II", "title": "The Wardfire of the Tide", "text": "Find the Warden at the Drowned Steps, on the south shore.", "hint": "Follow the road south from the town gate to the sea.", "rec": 6, "target": {"npc": "ilsabet"}},
	{"id": "s_return", "act": "III", "title": "Four Sparks", "text": "Bring the four sparks home to King Orlan.", "hint": "He's on the Ember Throne in Castle Emberhold.", "rec": 7, "target": {"npc": "orlan"}},
	{"id": "s_kindling", "act": "III", "title": "Kindling Night", "text": "Join the king at the plaza in front of the castle gate.", "hint": "The whole town is there. Talk to the king to begin.", "rec": 7, "target": {"npc": "orlan_plaza"}},
	{"id": "s_bastion", "act": "IV", "title": "The Sunken Bastion", "text": "Follow Taren into the Sunken Bastion, the ruin east of Emberhold.", "hint": "Take the road east from the town gate to the ruin.", "rec": 8, "target": {"map": "overworld", "x": 32.0, "y": 21.4}},
	{"id": "bastion_f1", "act": "IV", "title": "The Drowned Gate", "text": "Get past the guardian of the first floor.", "hint": "", "rec": 8, "target": {"map": "overworld", "x": 32.0, "y": 21.4}},
	{"id": "bastion_f2", "act": "IV", "title": "The Reliquary Halls", "text": "Get past the guardian of the second floor.", "hint": "", "rec": 9, "target": {"map": "overworld", "x": 32.0, "y": 21.4}},
	{"id": "boss2_won", "act": "IV", "title": "The Unlit Throne", "text": "Face Taren at the bottom of the Bastion.", "hint": "Heal up first. This is the end of the road.", "rec": 10, "target": {"map": "overworld", "x": 32.0, "y": 21.4}},
	{"id": "s_ending", "act": "E", "title": "The Heart-Coal", "text": "Decide the fate of the Heart-Coal.", "hint": "", "target": {}},
]

## Side quests: shown in the journal while on (flag `on`) and checked off when `done` is set.
const SIDE := [
	{"id": "fire", "on": "sq_fire_on", "done": "sq_fire_done", "title": "Pell's Lost Fireworks", "giver": "pell",
		"text": "Find Pell's three firework crates on Cinderreach: the north meadow, the east shore and the south-west strand.", "count": ["crate_1", "crate_2", "crate_3"],
		"back": "Bring the crates back to Pell in town."},
	{"id": "bell", "on": "sq_bell_on", "done": "sq_bell_done", "title": "The Quiet Bell", "giver": "wenna", "rec": 4,
		"text": "Ring the bell at the Votive Shrine (west of the King's Road) and quiet whatever answers.", "count": ["bell_rung"],
		"back": "Tell Sister Wenna the bell is quiet."},
	{"id": "book", "on": "sq_book_bet", "done": "sq_book_paid", "title": "Drosk's Book", "giver": "drosk",
		"text": "You bet 50 gold on yourself to become Hearth-Champion. Collect after Kindling Night.", "count": ["s_kindling"],
		"back": "Collect your winnings from Drosk at the plaza."},
	{"id": "reliquary", "on": "c2_keep", "done": "reliquary_given", "title": "The Black Reliquary", "giver": "grieve",
		"text": "Carry the cultists' reliquary to Selka in the castle before you bring the sparks home.", "count": [],
		"back": ""},
]

## Story people per kingdom map. `cond` = when they stand there. `talk` = rules. Existing kingdom NPCs (base) are
## taken over by id through BASE (same rule format); `hide` removes a base NPC.
const NPCS := {
	"town": [
		{"id": "vellin", "art": "vellin", "x": 13.7, "y": 14.7, "cond": "", "talk": [
			["!s_prologue", "prologue", "!"], ["s_kindling", "vellin_after", ""], ["", "vellin_idle", ""]]},
		{"id": "drosk", "art": "drosk", "x": 9.8, "y": 10.5, "cond": "s_prologue", "talk": [
			["sq_book_bet&s_kindling&!sq_book_paid", "drosk_payout", "s"], ["s_king&!sq_book_bet&!s_kindling&gold>=50", "drosk_offer", "s"],
			["s_king&!sq_book_bet&!s_kindling", "drosk_offer", ""], ["", "drosk_idle", ""]]},
		# Kindling Night: the court gathers on the plaza before the castle gate.
		{"id": "orlan_plaza", "art": "orlan", "name": "King Orlan", "x": 11.1, "y": 7.2, "cond": "s_return&!s_kindling", "talk": [
			["", "kindling", "?"]]},
		{"id": "taren_plaza", "art": "taren", "name": "Taren Unlit", "x": 13.2, "y": 7.2, "cond": "s_return&!s_kindling", "talk": [["", "taren_plaza", ""]]},
		{"id": "selka_plaza", "art": "selka", "name": "Selka", "x": 9.4, "y": 7.6, "cond": "s_return&!s_kindling", "talk": [["", "selka_plaza", ""]]},
		{"id": "caldric_plaza", "art": "caldric", "name": "Ser Caldric", "x": 14.9, "y": 7.6, "cond": "s_return&!s_kindling", "talk": [["", "caldric_plaza", ""]]},
		# After the ending the court celebrates on the plaza.
		{"id": "caldric_end", "art": "caldric", "name": "Ser Caldric", "x": 14.9, "y": 7.6, "cond": "s_ending", "talk": [["", "caldric_end", ""]]},
	],
	"castle": [
		{"id": "taren", "art": "taren", "x": 12.4, "y": 3.5, "cond": "s_prologue&!s_return", "talk": [["", "taren_idle", ""]]},
		{"id": "caldric", "art": "caldric", "x": 12.2, "y": 12.3, "cond": "s_king&!s_return", "talk": [["", "caldric_castle", ""]]},
		{"id": "caldric_gate", "art": "caldric", "name": "Ser Caldric", "x": 10.0, "y": 19.6, "cond": "s_kindling&!s_ending", "talk": [["", "caldric_gate", ""]]},
	],
	"house": [
		{"id": "maera", "art": "maera", "x": 5.0, "y": 3.0, "cond": "", "talk": [
			["s_king&!s_maera", "maera_intro", "!"], ["s_ending", "maera_end", ""], ["s_kindling", "maera_late", ""], ["s_maera", "maera_idle", ""], ["", "maera_early", ""]]},
	],
	"overworld": [
		{"id": "grieve", "art": "grieve", "x": 10.6, "y": 14.6, "cond": "s_king&!got_grieve", "talk": [
			["r_grieve", "grieve_retry", "?"], ["", "grieve_meet", "?"]]},
		{"id": "halvard", "art": "halvard", "x": 33.6, "y": 7.3, "cond": "s_king&!got_halvard", "talk": [
			["r_halvard", "halvard_retry", "?"], ["", "halvard_meet", "?"]]},
		{"id": "corvin", "art": "corvin", "x": 35.6, "y": 12.6, "cond": "s_king&!got_corvin", "talk": [
			["c3_hunt", "corvin_retry", "?"], ["", "corvin_meet", "?"]]},
		{"id": "ilsabet", "art": "ilsabet", "x": 19.6, "y": 28.2, "cond": "s_king&!got_ilsabet", "talk": [
			["r_ilsabet", "ilsabet_retry", "?"], ["", "ilsabet_meet", "?"]]},
		{"id": "caldric_shore", "art": "caldric", "name": "Ser Caldric", "x": 23.7, "y": 25.4, "cond": "sparks>=2&!s_return", "talk": [["", "caldric_shore", ""]]},
	],
}

const BASE := {
	"orlan": [["s_prologue&!s_king", "king_audience", "!"], ["sparks>=4&!s_return", "king_return", "?"], ["s_ending", "king_final", ""],
		["s_kindling", "king_after", ""], ["s_king", "king_idle", ""], ["", "king_early", ""]],
	"selka": [["c2_keep&!reliquary_given&!s_return", "selka_reliquary", "s"], ["s_ending", "selka_end", ""], ["s_kindling", "selka_after", ""],
		["s_king", "selka_idle", ""], ["", "selka_early", ""]],
	"pell": [["sq_fire_on&crate_1&crate_2&crate_3&!sq_fire_done", "pell_turnin", "s"], ["s_king&!sq_fire_on", "pell_offer", "s"],
		["sq_fire_on&!sq_fire_done", "pell_wait", ""], ["s_kindling", "pell_after", ""], ["", "pell_idle", ""]],
	"wenna": [["bell_rung&!sq_bell_done", "wenna_turnin", "s"], ["sparks>=1&!sq_bell_on", "wenna_offer", "s"],
		["sq_bell_done", "wenna_heal", ""], ["sq_bell_on", "wenna_wait", ""], ["", "wenna_idle", ""]],
	"joryn": [["s_ending", "joryn_end", ""], ["s_kindling", "joryn_after", ""], ["s_king", "joryn_hunt", ""], ["", "joryn_idle", ""]],
	"bramwell": "hide",
}

## Story spots: existing spots taken over by id (SPOT_TALK) and new ones (SPOTS) with a cond.
const SPOT_TALK := {
	"ruin": [["s_kindling&!s_ending", "bastion_enter", "?"], ["s_ending", "ruin_after", ""], ["", "ruin_sealed", ""]],
	"shrine": [["sq_bell_on&!bell_rung", "shrine_bell", "s"], ["", "shrine_pray", ""]],
	"forest": [["got_grieve", "forest_after", ""], ["", "forest_look", ""]],
	"cave": [["got_halvard", "cave_after", ""], ["", "cave_look", ""]],
	"overlook": [["got_corvin", "overlook_after", ""], ["", "overlook_look", ""]],
}
const SPOTS := {
	"overworld": [
		{"id": "steps", "x": 17.6, "y": 27.4, "name": "Drowned Steps", "prompt": "Look", "cond": "", "talk": [["got_ilsabet", "steps_after", ""], ["", "steps_look", ""]]},
		{"id": "crate_1", "x": 14.5, "y": 6.4, "name": "Firework Crate", "prompt": "Pick up", "cond": "sq_fire_on&!crate_1", "talk": [["", "crate_1", "s"]]},
		{"id": "crate_2", "x": 39.4, "y": 17.5, "name": "Firework Crate", "prompt": "Pick up", "cond": "sq_fire_on&!crate_2", "talk": [["", "crate_2", "s"]]},
		{"id": "crate_3", "x": 8.5, "y": 25.0, "name": "Firework Crate", "prompt": "Pick up", "cond": "sq_fire_on&!crate_3", "talk": [["", "crate_3", "s"]]},
	],
}

## Where each map's exits lead (tile positions), so the objective arrow can point at the right door.
const LINKS := {
	"town": {"castle": Vector2(12.0, 5.3), "overworld": Vector2(12.0, 17.0), "house": Vector2(7.5, 13.3)},
	"castle": {"town": Vector2(10.0, 21.0)},
	"house": {"town": Vector2(4.0, 6.4)},
	"overworld": {"town": Vector2(22.0, 20.3)},
}

## Story fights. kinds = slot archetypes (torch melee / barrel heavy / tnt caster), tiers per slot, foe_ids = the
## Airron's Fall foe (AfRoster.FOES id) per slot ("" = pick from foes), foes = regular foe art per kind. rec = minimum foe level;
## the fight is levelled to the party but clamped to rec..rec+2. win / lose = dialog played back in the kingdom.
const BATTLES := {
	"fight_grieve": {"area": "gallowbough-orchard", "rec": 2, "kinds": ["barrel", "tnt"], "tiers": ["elite", "regular"],
		"foe_ids": ["leaper", ""], "foes": {"tnt": ["moth"]}, "banner": "THE WARDFIRE OF ROOTS", "win": "grieve_after", "lose": "lose_generic"},
	"fight_halvard": {"area": "coalvein-deeps", "rec": 3, "kinds": ["barrel", "torch", "torch"], "tiers": ["elite", "regular", "regular"],
		"foe_ids": ["elite", "", ""], "foes": {"torch": ["ashling"], "barrel": ["brute"]}, "banner": "THE DEEP FORGE", "win": "halvard_after", "lose": "lose_generic"},
	"fight_engine": {"area": "starwreck-strand", "rec": 5, "kinds": ["barrel", "torch", "torch"], "tiers": ["elite", "regular", "regular"],
		"foe_ids": ["engine", "", ""], "foes": {"torch": ["lancer", "mote"]}, "banner": "THE RELIQUARY ENGINE", "win": "corvin_hunt_after", "lose": "lose_generic"},
	"fight_cardinal": {"area": "saltglass-fen", "rec": 6, "kinds": ["barrel", "torch"], "tiers": ["miniboss", "regular"],
		"foe_ids": ["cardinal", ""], "foes": {"torch": ["mote"], "tnt": ["moth"]}, "boss": true,
		"banner": "THE DROWNED CARDINAL", "win": "ilsabet_after", "lose": "lose_generic"},
	"fight_bell": {"area": "stillmoss-cloister", "rec": 4, "kinds": ["barrel", "tnt"], "tiers": ["elite", "regular"],
		"foe_ids": ["knell", ""], "foes": {"tnt": ["chanter"]}, "banner": "THE QUIET BELL", "win": "bell_after", "lose": "lose_generic"},
	"miniboss_matron": {"area": "vespergate-sanctum", "rec": 7, "kinds": ["barrel", "torch"], "tiers": ["miniboss", "regular"],
		"foe_ids": ["matron", ""], "foes": {"torch": ["ashling"]}, "boss": true,
		"banner": "MATRON OF CINDERS", "win": "matron_after", "lose": "kindling_lose"},
	"guardian_f1": {"area": "riven-choir", "rec": 8, "kinds": ["barrel", "torch", "torch"], "tiers": ["elite", "regular", "regular"],
		"foe_ids": ["tithe", "", ""], "foes": {"torch": ["lancer"]}, "banner": "THE DROWNED GATE", "win": "f1_after", "lose": "lose_bastion", "flag": "bastion_f1"},
	"guardian_f2": {"area": "vespergate-sanctum", "rec": 9, "kinds": ["barrel", "tnt", "tnt"], "tiers": ["elite", "regular", "regular"],
		"foe_ids": ["knell", "", ""], "foes": {"tnt": ["chanter"]}, "banner": "THE RELIQUARY HALLS", "win": "f2_after", "lose": "lose_bastion", "flag": "bastion_f2"},
	"boss_regnant": {"area": "unlit-throne", "rec": 9, "kinds": ["barrel", "tnt"], "tiers": ["boss", "regular"],
		"foe_ids": ["regent", ""], "foes": {"tnt": ["chanter"]}, "boss": true, "banner": "THE UNLIT REGNANT", "banner_sub": "Final battle  ·  Phase 1",
		"win": "regnant_after", "lose": "lose_final", "flag": "boss1_won"},
	"boss_sovereign": {"area": "unlit-throne", "rec": 10, "kinds": ["barrel", "torch"], "tiers": ["boss", "regular"],
		"foe_ids": ["sovereign", ""], "foes": {"torch": ["ashling", "lancer"]}, "boss": true, "banner": "THE ASH SOVEREIGN", "banner_sub": "Final battle  ·  Phase 2",
		"win": "sovereign_after", "lose": "lose_final", "flag": "boss2_won"},
}

## Boss ids reported through Story.boss_defeated.
const BOSS_IDS := ["miniboss_matron", "guardian_f1", "guardian_f2", "boss_regnant", "boss_sovereign", "fight_cardinal"]

## Heirlooms a loyal Warden gives (added to scripts/game.gd ITEM_DEFS at startup by Story.extend_items).
const ITEMS := {
	"gravebell": {"name": "Gravebell", "slot": "amulet", "blurb": "Grieve's heirloom. It rang at both his funerals", "hp": 24, "def": 3, "crit": 2},
	"rust_pledge": {"name": "Rust Baron's Pledge", "slot": "weapon", "blurb": "Halvard's hammer. It has never struck a crown. Yet", "atk": 8, "hp": 12},
	"loaded_dice": {"name": "Loaded Dice", "slot": "gloves", "blurb": "Corvin's dice. Loaded, but only in your favor", "crit": 6, "speed": 3, "atk": 1},
	"tideglass": {"name": "Tideglass Shard", "slot": "amulet", "blurb": "A pearl from Ilsabet's drowned crown", "mana": 4, "hp": 18, "def": 2},
}
