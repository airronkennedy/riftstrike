extends Node2D
## RIFTSTRIKE — turn-based 6vN brawl. Godot port of the canvas game (game.js), kept 1:1.
## Art: Tiny Swords by Pixel Frog (original release, free for commercial use; see docs/ASSET_LICENSES.md). Boss: Necromancer by CreativeKind.
## Everything is drawn immediate-mode in _draw(), mirroring the canvas renderer.

# ---------------------------------------------------------------- world / orientation
const LW := 1024.0
const LH := 576.0
var W := LW
var H := LH
var PORT := false
var ISL := {}
var VIEW := {}

func mp(x: float, y: float) -> Vector2:
	return Vector2(y, LW - x) if PORT else Vector2(x, y)

func set_orientation(port: bool) -> void:
	PORT = port
	W = LH if port else LW
	H = LW if port else LH
	ISL = {"c0": 1, "c1": 7, "r0": 1, "r1": 14} if port else {"c0": 1, "c1": 14, "r0": 1, "r1": 7}
	VIEW = {"x": 40.0, "y": 40.0, "w": 496.0, "h": 950.0} if port else {"x": 40.0, "y": 40.0, "w": 944.0, "h": 500.0}

# ---------------------------------------------------------------- assets
var SRC := {
	"warrior": "units/Warrior_Blue.png", "archer": "units/Archer_Blue.png", "pawn": "units/Pawn_Blue.png",
	"torch": "units/Torch_Red.png", "tnt": "units/TNT_Red.png", "barrel": "units/Barrel_Red.png",
	"necro": "necromancer/Necromancer.png",
	"paladin": "heroes/christian-paladin.png",
	"dead": "units/Dead.png", "dynamite": "fx/Dynamite.png", "arrow": "fx/Arrow.png",
	"explosion": "fx/Explosions.png", "fire": "fx/Fire.png",
	"flat": "terrain/Tilemap_Flat.png", "foam": "terrain/Foam.png",
	"rocks1": "terrain/Rocks_01.png", "rocks3": "terrain/Rocks_03.png", "tree": "terrain/Tree.png",
	"tower": "terrain/Tower_Blue.png", "ghouse": "terrain/Goblin_House.png", "sheep": "terrain/HappySheep_Idle.png",
	# Overworld buildings and terrain for Acts II-V (Tiny Swords, original release; see docs/ASSET_LICENSES.md).
	"tower_red": "buildings/Tower_Red.png", "tower_yellow": "buildings/Tower_Yellow.png", "tower_purple": "buildings/Tower_Purple.png",
	"tower_ruin": "buildings/Tower_Destroyed.png", "ghouse_ruin": "buildings/Goblin_House_Destroyed.png",
	"house_blue": "buildings/House_Blue.png", "house_red": "buildings/House_Red.png", "house_yellow": "buildings/House_Yellow.png",
	"house_purple": "buildings/House_Purple.png", "house_ruin": "buildings/House_Destroyed.png",
	"castle_blue": "buildings/Castle_Blue.png", "castle_red": "buildings/Castle_Red.png", "castle_yellow": "buildings/Castle_Yellow.png",
	"castle_purple": "buildings/Castle_Purple.png", "castle_ruin": "buildings/Castle_Destroyed.png",
	"wtower": "buildings/Wood_Tower_Red.png", "goldmine": "buildings/GoldMine_Active.png",
	"elev": "terrain/Tilemap_Elevation.png", "bridge": "terrain/Bridge_All.png",
	"rocks2": "terrain/Rocks_02.png", "rocks4": "terrain/Rocks_04.png",
	"ribbonBlue": "ui/Ribbon_Blue_3Slides.png", "ribbonRed": "ui/Ribbon_Red_3Slides.png", "ribbonYellow": "ui/Ribbon_Yellow_3Slides.png",
	"btnBlue": "ui/Button_Blue_3Slides.png", "btnBlueP": "ui/Button_Blue_3Slides_Pressed.png",
	"btnRed": "ui/Button_Red_3Slides.png", "btnRedP": "ui/Button_Red_3Slides_Pressed.png",
	"sq": "ui/Button_Blue.png", "sqP": "ui/Button_Blue_Pressed.png", "carved": "ui/Carved_9Slides.png", "sound": "ui/Regular_03.png",
}
var IMG := {}
var WHITE := {}
var CYAN := {}
var FONT: FontFile

const URL_TINY := "https://pixelfrog-assets.itch.io/tiny-swords"
const URL_NECRO := "https://creativekind.itch.io/necromancer-free"

func load_all() -> void:
	for d in ["01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "13", "14", "15", "16", "17", "18"]:
		SRC["deco" + d] = "deco/" + d + ".png"
	for k in SRC:
		IMG[k] = load("res://assets/" + SRC[k])
	for k in ["warrior", "archer", "pawn", "torch", "tnt", "barrel", "necro", "paladin"]:
		WHITE[k] = load("res://assets/sil/%s_white.png" % k)
		CYAN[k] = load("res://assets/sil/%s_cyan.png" % k)
	FONT = load("res://fonts/LilitaOne-Regular.ttf")

# ---------------------------------------------------------------- rng helpers
func rand(a: float, b: float) -> float: return a + randf() * (b - a)
func pick(a: Array): return a[randi() % a.size()]
func shuffled(a: Array) -> Array:
	var b := a.duplicate()
	b.shuffle()
	return b

# ---------------------------------------------------------------- unit kinds
func A(r: int, n: int, fps: float, hit: int, hold: float) -> Dictionary:
	return {"r": r, "n": n, "fps": fps, "hit": hit, "hold": hold}

var KINDS := {}
func build_kinds() -> void:
	var S192 := {"fw": 192.0, "fh": 192.0, "ax": 96.0, "ay": 134.0, "s": 1.0}
	KINDS = {
		"warrior": {"img": "warrior", "f": S192, "head": 84.0, "label": "Warrior", "range": 52.0, "ranged": "",
			"idle": {"r": 0, "n": 6, "fps": 10.0}, "run": {"r": 1, "n": 6, "fps": 12.0},
			"atk": [A(2, 6, 10, 3, 160), A(3, 6, 10, 3, 180)],
			"atkDown": [A(4, 6, 10, 3, 160), A(5, 6, 10, 3, 180)], "atkUp": [A(6, 6, 10, 3, 160), A(7, 6, 10, 3, 180)],
			"special": "Rift Cleave"},
		# Christian's Paladin sheet: 256px frames, right-facing. atkUp/atkDown reuse the side slash for now.
		"paladin": {"img": "paladin", "f": {"fw": 256.0, "fh": 256.0, "ax": 128.0, "ay": 242.0, "s": 0.58}, "head": 200.0, "label": "Paladin", "range": 52.0, "ranged": "",
			"idle": {"r": 0, "n": 6, "fps": 10.0}, "run": {"r": 1, "n": 6, "fps": 12.0},
			"atk": [A(2, 6, 10, 3, 160), A(3, 6, 10, 3, 180)],
			"atkDown": [A(4, 6, 10, 3, 160), A(5, 6, 10, 3, 180)], "atkUp": [A(6, 6, 10, 3, 160), A(7, 6, 10, 3, 180)],
			"special": "Holy Strike"},
		"archer": {"img": "archer", "f": S192, "head": 72.0, "label": "Archer", "range": 340.0, "ranged": "arrow",
			"idle": {"r": 0, "n": 6, "fps": 10.0}, "run": {"r": 1, "n": 6, "fps": 12.0},
			"atk": [A(4, 8, 11, 5, 160)], "atkUp": [A(3, 8, 11, 5, 160)], "atkDown": [A(5, 8, 11, 5, 160)],
			"special": "Piercing Volley"},
		"pawn": {"img": "pawn", "f": S192, "head": 64.0, "label": "Pawn", "range": 46.0, "ranged": "",
			"idle": {"r": 0, "n": 6, "fps": 10.0}, "run": {"r": 1, "n": 6, "fps": 12.0},
			"atk": [A(3, 6, 10, 3, 180), A(2, 6, 10, 3, 200)], "special": "Hearth Hammer"},
		"torch": {"img": "torch", "f": S192, "head": 76.0, "label": "Torch", "range": 52.0, "ranged": "",
			"idle": {"r": 0, "n": 7, "fps": 10.0}, "run": {"r": 1, "n": 6, "fps": 12.0},
			"atk": [A(2, 6, 10, 3, 170)], "atkDown": [A(3, 6, 10, 3, 170)], "atkUp": [A(4, 6, 10, 3, 170)],
			"special": "Cinder Sweep"},
		"tnt": {"img": "tnt", "f": S192, "head": 66.0, "label": "TNT", "range": 290.0, "ranged": "dynamite",
			"idle": {"r": 0, "n": 6, "fps": 10.0}, "run": {"r": 1, "n": 6, "fps": 12.0},
			"atk": [A(2, 7, 10, 3, 160)], "special": "Big Bang"},
		"barrel": {"img": "barrel", "f": {"fw": 128.0, "fh": 128.0, "ax": 64.0, "ay": 101.0, "s": 1.0}, "head": 70.0, "label": "Barrel", "range": 48.0, "ranged": "",
			"idle": {"r": 4, "n": 3, "fps": 5.0}, "run": {"r": 3, "n": 6, "fps": 12.0},
			"atk": [A(1, 6, 10, 2, 180)], "special": "Powder Keg"},
		# 6v1 boss only: CreativeKind Necromancer (160x128 frames, faces right). Casts a soul bolt.
		"necro": {"img": "necro", "f": {"fw": 160.0, "fh": 128.0, "ax": 82.0, "ay": 114.0, "s": 1.7}, "head": 86.0, "label": "Necromancer", "range": 360.0, "ranged": "bolt",
			"idle": {"r": 0, "n": 8, "fps": 10.0}, "run": {"r": 1, "n": 8, "fps": 12.0},
			"atk": [A(2, 13, 14, 8, 200)], "death": {"r": 6, "n": 9}, "special": "Soul Rend"},
	}

# Paladin uses the warrior combat kit (double swing, melee contact).
func is_warrior_kit(kind: String) -> bool:
	return kind == "warrior" or kind == "paladin"

var ROSTER_BLUE := [["warrior", "Airron", 360, 265], ["warrior", "Christian", 360, 395],
	["pawn", "Lanning", 315, 185], ["pawn", "Rico", 315, 470],
	["archer", "Weston", 205, 265], ["archer", "Wiesen", 205, 395]]
var GOB_NAMES := ["Rusk", "Kael", "Sable", "Drenn", "Voss", "Iven"]
# Active Play squad. The character catalog can grow past this squad later.
var HERO_NAMES := ["Airron", "Christian", "Weston", "Wiesen", "Lanning", "Rico"]
# Personal cores — class and subclass bonuses stack on top.
var HERO_BASE := {
	"Airron": {"hp": 220, "atk": 64, "def": 26, "armor": 8, "crit": 8, "mana": 6, "speed": 14},
	"Christian": {"hp": 260, "atk": 50, "def": 36, "armor": 10, "crit": 6, "mana": 5, "speed": 12},
	"Weston": {"hp": 210, "atk": 58, "def": 18, "armor": 4, "crit": 10, "mana": 6, "speed": 18},
	"Wiesen": {"hp": 200, "atk": 68, "def": 16, "armor": 3, "crit": 12, "mana": 5, "speed": 16},
	"Lanning": {"hp": 300, "atk": 38, "def": 40, "armor": 12, "crit": 4, "mana": 8, "speed": 8},
	"Rico": {"hp": 240, "atk": 48, "def": 24, "armor": 8, "crit": 8, "mana": 6, "speed": 16},
}
# Classes: big, focused packages + a combat kit. Subclasses: smaller mix-and-match bonuses.
# Target is 10 classes; add new ones to CLASS_DEFS and CLASS_IDS when they are ready.
# Do not ship placeholder or TBD playable classes.
var CLASS_DEFS := {
	"Knight": {"kind": "warrior", "blurb": "Heavy blows and thick armor",
		"hp": 40, "atk": 22, "def": 8, "armor": 14, "crit": 0, "mana": 2, "speed": 0},
	"Warrior": {"kind": "warrior", "blurb": "Aggressive melee pressure",
		"hp": 16, "atk": 20, "def": 4, "armor": 6, "crit": 8, "mana": 2, "speed": 12},
	"Ranger": {"kind": "archer", "blurb": "Fast shots and sharp crits",
		"hp": 16, "atk": 14, "def": 0, "armor": 2, "crit": 16, "mana": 2, "speed": 16},
	"Marksman": {"kind": "archer", "blurb": "Precision damage from the back line",
		"hp": 8, "atk": 20, "def": 2, "armor": 4, "crit": 12, "mana": 4, "speed": 8},
	"Guardian": {"kind": "pawn", "blurb": "Stands firm and soaks hits",
		"hp": 80, "atk": 0, "def": 22, "armor": 16, "crit": 0, "mana": 4, "speed": 0},
	"Warden": {"kind": "pawn", "blurb": "Steady defense and mana",
		"hp": 50, "atk": 4, "def": 16, "armor": 8, "crit": 0, "mana": 14, "speed": 2},
	# Upcoming classes for the new character models. Real definitions (shown in the Compendium),
	# NOT in CLASS_IDS and NOT assigned in CHAR yet. Their 10-ability kits live in
	# scripts/upcoming_classes.gd; when the art lands, move the kit into AB_CLASS_ROWS[hero],
	# set CHAR[hero].cls, drop "upcoming", and add the class to CLASS_IDS.
	"Spell Breaker": {"kind": "warrior", "blurb": "Breaks guards, wards and spells", "upcoming": true, "hero": "Airron",
		"hp": 28, "atk": 18, "def": 8, "armor": 8, "crit": 6, "mana": 8, "speed": 8},
	"Paladin": {"kind": "paladin", "blurb": "Holy armor that heals the line", "hero": "Christian",
		"hp": 44, "atk": 12, "def": 12, "armor": 12, "crit": 0, "mana": 8, "speed": 2},
	"Warlock": {"kind": "archer", "blurb": "Dark bolts and draining curses", "upcoming": true, "hero": "Wiesen",
		"hp": 8, "atk": 24, "def": 2, "armor": 2, "crit": 10, "mana": 12, "speed": 6},
}
var CLASS_IDS := ["Knight", "Warrior", "Ranger", "Marksman", "Guardian", "Warden", "Paladin"]
var SUB_DEFS := {
	"Riftblade": {"blurb": "A little extra cut", "atk": 8, "crit": 6},
	"Vanguard": {"blurb": "Front-line bulk", "hp": 24, "def": 4, "armor": 6},
	"Scout": {"blurb": "Gets there first", "speed": 8, "crit": 4},
	"Sharpshot": {"blurb": "Keener eyes", "atk": 6, "crit": 6},
	"Ironhide": {"blurb": "Harder to break", "armor": 8, "def": 4, "hp": 16},
	"Raider": {"blurb": "Hits and moves", "atk": 6, "speed": 6},
	"Sage": {"blurb": "Mana between turns", "mana": 8, "def": 3},
	"Duelist": {"blurb": "Pick your opening", "crit": 6, "atk": 4, "speed": 3},
}
var SUB_IDS := ["Riftblade", "Vanguard", "Scout", "Sharpshot", "Ironhide", "Raider", "Sage", "Duelist"]
# ---------------------------------------------------------------- abilities (data-driven)
# Every ability is one data row. Class abilities belong to ONE character (unique kit);
# subclass abilities are shared by anyone running that subclass.
# Using any ability needs a FULL MP bar (gauge 100) and spends the whole bar.
const AB_MP := 100.0
const CLASS_UNLOCKS := [1, 11, 21, 31, 41, 51, 61, 71, 81, 99]
const SUB_UNLOCKS := [1, 20, 40, 60, 80]
var ABILITY_DEFS: Dictionary = {}
var AB_CLASS_LIST: Dictionary = {} # hero name -> [ids in unlock order]
var AB_SUB_LIST: Dictionary = {} # subclass -> [ids in unlock order]
var AB_EQUIP: Dictionary = {} # hero name -> {"cls": id, "sub": id}
var AB_AUTO: Dictionary = {} # hero name -> ability id auto-battle fires on a full MP bar ("" = basic attacks only; missing = class ability)
var HERO_MP: Dictionary = {} # hero name -> MP carried between fights (saved)
# Rows: [id, name, blurb, kind, params]. Unlock level comes from the row position.
var AB_CLASS_ROWS := {
	"Airron": [
		["rift_cut", "Rift Cut", "A sharp opening strike that tears a seam in the air.", "damage_single", {"mult": 2.4}],
		["seam_ward", "Seam Ward", "Folds the rift around himself to blunt incoming blows.", "buff_self", {"buffs": [["def", 20], ["armor", 6]], "turns": 2}],
		["riftbrand_slash", "Riftbrand Slash", "A heavy cut that also strips the target's armor.", "damage_single", {"mult": 3.2, "debuff": [["armor", -6]], "dturns": 2}],
		["rending_arc", "Rending Arc", "A wide rift arc that catches every enemy.", "damage_all_enemies", {"mult": 1.6}],
		["knights_oath", "Knight's Oath", "Swears to the squad. The whole party gains Defense.", "buff_party", {"buffs": [["def", 15]], "turns": 2}],
		["rift_lunge", "Rift Lunge", "Steps through the rift for a crushing single blow.", "damage_single", {"mult": 4.2}],
		["sundering_wave", "Sundering Wave", "A wave of torn space hits all foes and cracks their guard.", "damage_all_enemies", {"mult": 2.2, "debuff": [["def", -15]], "dturns": 2}],
		["bulwark_rally", "Bulwark Rally", "Rallies the line: party gains Armor and ATK.", "buff_party", {"buffs": [["armor", 8], ["atk", 10]], "turns": 2}],
		["fault_line", "Fault Line", "Splits the ground under every enemy.", "damage_all_enemies", {"mult": 2.8}],
		["worldsplitter", "Worldsplitter", "Capstone. Cleaves the rift itself — a massive hit on every foe.", "damage_all_enemies", {"mult": 3.4, "self_buff": [["atk", 15]], "sturns": 2}],
	],
	"Christian": [
		["holy_strike", "Holy Strike", "A consecrated swing that lands in a flash of holy light.", "damage_single", {"mult": 2.4}],
		["lay_on_hands", "Lay on Hands", "Lays a healing hand on one ally, mending a large amount of damage.", "heal_single", {"pct": 0.40}],
		["aegis_of_light", "Aegis of Light", "Raises a shield of light: Defense and Armor up.", "buff_self", {"buffs": [["def", 20], ["armor", 8]], "turns": 2}],
		["consecrate", "Consecrate", "Blesses the ground and burns every enemy on it.", "damage_all_enemies", {"mult": 1.6}],
		["devotion_aura", "Devotion Aura", "Faith steadies the whole line: party Defense up.", "buff_party", {"buffs": [["def", 15]], "turns": 2}],
		["judgment", "Judgment", "Judges one foe: a heavy hit that lowers its ATK.", "damage_single", {"mult": 4.0, "debuff": [["atk", -15]], "dturns": 2}],
		["healing_light", "Healing Light", "Light washes over the squad, healing everyone.", "heal_party", {"pct": 0.25}],
		["crusader_charge", "Crusader Charge", "Charges the enemy line and rallies the party (ATK up).", "damage_all_enemies", {"mult": 2.4, "party_buff": [["atk", 10]], "pturns": 2}],
		["divine_shield", "Divine Shield", "Shields the whole party: big Defense and Armor for three turns.", "buff_party", {"buffs": [["def", 25], ["armor", 10]], "turns": 3}],
		["radiant_dawn", "Radiant Dawn", "Capstone. A holy dawn floods the party with a large heal and makes it hard to break.", "heal_party", {"pct": 0.50, "party_buff": [["def", 15], ["armor", 8]], "pturns": 3}],
	],
	"Weston": [
		["quick_mark", "Quick Mark", "Finds the opening first: hits and marks the target (DEF down).", "damage_single", {"mult": 2.0, "debuff": [["def", -15]], "dturns": 2}],
		["fleet_foot", "Fleet Foot", "Light on his feet: Speed and Crit up.", "buff_self", {"buffs": [["speed", 12], ["crit", 10]], "turns": 2}],
		["twin_shot", "Twin Shot", "Two arrows nocked as one — a strong single shot.", "damage_single", {"mult": 3.0}],
		["volley", "Volley", "Arrows over the whole enemy line.", "damage_all_enemies", {"mult": 1.6}],
		["hunters_call", "Hunter's Call", "Calls the hunt: party Crit up.", "buff_party", {"buffs": [["crit", 10]], "turns": 2}],
		["pinning_shot", "Pinning Shot", "Pins one foe hard and slows it.", "damage_single", {"mult": 3.8, "debuff": [["speed", -15]], "dturns": 2}],
		["arrow_rain", "Arrow Rain", "A heavy rain of arrows on every enemy.", "damage_all_enemies", {"mult": 2.2}],
		["trailwise", "Trailwise", "Leads the party: Speed and ATK up.", "buff_party", {"buffs": [["speed", 12], ["atk", 8]], "turns": 2}],
		["storm_of_arrows", "Storm of Arrows", "A storm of shafts batters all foes.", "damage_all_enemies", {"mult": 2.8}],
		["skyfall_volley", "Skyfall Volley", "Capstone. The sky falls on every enemy and opens their guard.", "damage_all_enemies", {"mult": 3.4, "debuff": [["def", -15]], "dturns": 2}],
	],
	"Wiesen": [
		["piercing_shot", "Piercing Shot", "A precise, punching arrow that pierces armor.", "damage_single", {"mult": 2.6, "debuff": [["armor", -6]], "dturns": 2}],
		["steady_aim", "Steady Aim", "Breathes out and lines up: ATK and Crit up.", "buff_self", {"buffs": [["atk", 15], ["crit", 10]], "turns": 2}],
		["headshot", "Headshot", "A clean shot at one target's weak spot.", "damage_single", {"mult": 3.4}],
		["ricochet", "Ricochet", "One arrow skips off every enemy.", "damage_all_enemies", {"mult": 1.6}],
		["spotters_eye", "Spotter's Eye", "Calls out openings: party Crit up.", "buff_party", {"buffs": [["crit", 12]], "turns": 2}],
		["armor_piercer", "Armor Piercer", "A heavy bolt that shreds armor for three turns.", "damage_single", {"mult": 4.0, "debuff": [["armor", -12]], "dturns": 3}],
		["suppressing_fire", "Suppressing Fire", "Pins down all enemies and weakens their ATK.", "damage_all_enemies", {"mult": 2.0, "debuff": [["atk", -12]], "dturns": 2}],
		["deadeye_focus", "Deadeye Focus", "Total focus: huge ATK and Crit.", "buff_self", {"buffs": [["atk", 30], ["crit", 15]], "turns": 2}],
		["longshot", "Longshot", "A shot from impossible range at one foe.", "damage_single", {"mult": 5.2}],
		["one_clean_shot", "One Clean Shot", "Capstone. The perfect shot — enormous single-target damage.", "damage_single", {"mult": 7.0}],
	],
	"Lanning": [
		["iron_wall", "Iron Wall", "Braces and soaks the hit: big Defense and Armor.", "buff_self", {"buffs": [["def", 25], ["armor", 8]], "turns": 2}],
		["shield_bash", "Shield Bash", "Bashes one foe and dulls its ATK.", "damage_single", {"mult": 2.2, "debuff": [["atk", -12]], "dturns": 2}],
		["bastion", "Bastion", "Becomes a wall for everyone: party Armor up.", "buff_party", {"buffs": [["armor", 6]], "turns": 2}],
		["rallying_stand", "Rallying Stand", "Steadies the line, healing the whole party a little.", "heal_party", {"pct": 0.12}],
		["stone_skin", "Stone Skin", "Skin like stone: Armor and Defense for three turns.", "buff_self", {"buffs": [["armor", 16], ["def", 20]], "turns": 3}],
		["ground_slam", "Ground Slam", "Slams the ground, hitting all foes and slowing them.", "damage_all_enemies", {"mult": 1.8, "debuff": [["speed", -12]], "dturns": 2}],
		["aegis_line", "Aegis Line", "Raises a shield line: party Defense and Armor up.", "buff_party", {"buffs": [["def", 20], ["armor", 6]], "turns": 2}],
		["second_wind", "Second Wind", "Pulls the weakest ally back up with a large heal.", "heal_single", {"pct": 0.45}],
		["fortress", "Fortress", "The party becomes a fortress for three turns.", "buff_party", {"buffs": [["def", 25], ["armor", 10]], "turns": 3}],
		["unbreakable", "Unbreakable", "Capstone. Heals the party and makes it nearly unbreakable.", "heal_party", {"pct": 0.30, "party_buff": [["armor", 12], ["def", 20]], "pturns": 3}],
	],
	"Rico": [
		["raid_step", "Raid Step", "Hits and shifts off the line, gaining Speed.", "damage_single", {"mult": 2.4, "self_buff": [["speed", 10]], "sturns": 2}],
		["hit_and_run", "Hit and Run", "Strikes and slips away, guarding himself.", "damage_single", {"mult": 2.8, "self_buff": [["def", 12]], "sturns": 1}],
		["plunder_strike", "Plunder Strike", "Steals the fight from one foe, lowering its ATK.", "damage_single", {"mult": 3.2, "debuff": [["atk", -10]], "dturns": 2}],
		["whirling_raid", "Whirling Raid", "Spins through the whole enemy line.", "damage_all_enemies", {"mult": 1.8}],
		["war_drums", "War Drums", "Beats the drums: party Speed up.", "buff_party", {"buffs": [["speed", 12]], "turns": 2}],
		["flank_rush", "Flank Rush", "Rushes the flank for a big hit, then Speed and Crit up.", "damage_single", {"mult": 4.2, "self_buff": [["speed", 12], ["crit", 10]], "sturns": 2}],
		["reavers_sweep", "Reaver's Sweep", "A reckless sweep across every enemy.", "damage_all_enemies", {"mult": 2.4}],
		["bloodrush", "Bloodrush", "All-in aggression: huge ATK and Speed.", "buff_self", {"buffs": [["atk", 30], ["speed", 15]], "turns": 2}],
		["raiders_storm", "Raider's Storm", "Storms all foes and keeps the momentum (ATK up).", "damage_all_enemies", {"mult": 3.0, "self_buff": [["atk", 15]], "sturns": 2}],
		["warpath", "Warpath", "Capstone. Tears through every foe and drives the party forward.", "damage_all_enemies", {"mult": 3.6, "party_buff": [["speed", 12], ["atk", 10]], "pturns": 2}],
	],
}
var AB_SUB_ROWS := {
	"Riftblade": [
		["rift_edge", "Rift Edge", "A quick rift-edged cut on one foe.", "damage_single", {"mult": 2.2}],
		["seam_burst", "Seam Burst", "Bursts a seam under every enemy.", "damage_all_enemies", {"mult": 1.4}],
		["blade_focus", "Blade Focus", "Hones the edge: ATK and Crit up.", "buff_self", {"buffs": [["atk", 20], ["crit", 10]], "turns": 2}],
		["rift_rend", "Rift Rend", "Rends one foe and its armor.", "damage_single", {"mult": 4.0, "debuff": [["armor", -10]], "dturns": 2}],
		["riftstorm", "Riftstorm", "A storm of rift blades hits all foes hard.", "damage_all_enemies", {"mult": 2.8}],
	],
	"Vanguard": [
		["hold_the_line", "Hold the Line", "Digs in: Defense up.", "buff_self", {"buffs": [["def", 20]], "turns": 2}],
		["shoulder_charge", "Shoulder Charge", "Charges one foe and slows it.", "damage_single", {"mult": 2.4, "debuff": [["speed", -10]], "dturns": 2}],
		["front_guard", "Front Guard", "Guards the whole party: Defense up.", "buff_party", {"buffs": [["def", 15]], "turns": 2}],
		["rally_point", "Rally Point", "Heals the party a little and adds Armor.", "heal_party", {"pct": 0.15, "party_buff": [["armor", 5]], "pturns": 2}],
		["vanguards_wall", "Vanguard's Wall", "A full wall: big party Defense and Armor.", "buff_party", {"buffs": [["def", 25], ["armor", 10]], "turns": 3}],
	],
	"Scout": [
		["swift_strike", "Swift Strike", "A fast strike, then Speed up.", "damage_single", {"mult": 2.0, "self_buff": [["speed", 10]], "sturns": 2}],
		["scout_ahead", "Scout Ahead", "Finds the path: party Speed up.", "buff_party", {"buffs": [["speed", 10]], "turns": 2}],
		["expose", "Expose", "Exposes one foe: hit and big Defense down.", "damage_single", {"mult": 2.4, "debuff": [["def", -20]], "dturns": 2}],
		["smoke_screen", "Smoke Screen", "Covers the party: Defense and Speed up.", "buff_party", {"buffs": [["def", 18], ["speed", 8]], "turns": 2}],
		["ambush", "Ambush", "Springs an ambush on every enemy.", "damage_all_enemies", {"mult": 2.6}],
	],
	"Sharpshot": [
		["aimed_shot", "Aimed Shot", "A careful shot at one foe.", "damage_single", {"mult": 2.4}],
		["weak_point", "Weak Point", "Hits a weak point and lowers Armor.", "damage_single", {"mult": 2.2, "debuff": [["armor", -10]], "dturns": 2}],
		["keen_eyes", "Keen Eyes", "Sharpens the squad: party Crit up.", "buff_party", {"buffs": [["crit", 12]], "turns": 2}],
		["scatter_shot", "Scatter Shot", "Scatters shots across all foes.", "damage_all_enemies", {"mult": 2.0}],
		["killshot", "Killshot", "A lethal single shot.", "damage_single", {"mult": 5.0}],
	],
	"Ironhide": [
		["harden", "Harden", "Hardens up: Armor up.", "buff_self", {"buffs": [["armor", 10]], "turns": 2}],
		["iron_hide", "Iron Hide", "Iron skin: big Defense and Armor.", "buff_self", {"buffs": [["def", 25], ["armor", 12]], "turns": 2}],
		["shrug_off", "Shrug Off", "Shrugs off the damage, healing himself a lot.", "heal_single", {"pct": 0.40, "self": true}],
		["iron_bond", "Iron Bond", "Shares the iron: party Armor up.", "buff_party", {"buffs": [["armor", 8]], "turns": 2}],
		["living_fortress", "Living Fortress", "Party Armor and Defense way up for three turns.", "buff_party", {"buffs": [["armor", 12], ["def", 20]], "turns": 3}],
	],
	"Raider": [
		["raid_strike", "Raid Strike", "A raider's opening hit on one foe.", "damage_single", {"mult": 2.2}],
		["loot_run", "Loot Run", "Hits one foe and runs off faster.", "damage_single", {"mult": 2.6, "self_buff": [["speed", 12]], "sturns": 2}],
		["pillage", "Pillage", "Pillages the line: hits all and lowers Armor.", "damage_all_enemies", {"mult": 1.6, "debuff": [["armor", -6]], "dturns": 2}],
		["warband_rush", "Warband Rush", "The warband surges: party ATK and Speed up.", "buff_party", {"buffs": [["atk", 12], ["speed", 8]], "turns": 2}],
		["sack_the_line", "Sack the Line", "Sacks every foe and breaks their Defense.", "damage_all_enemies", {"mult": 2.8, "debuff": [["def", -15]], "dturns": 2}],
	],
	"Sage": [
		["mend", "Mend", "Heals one ally for a large amount (lowest HP first).", "heal_single", {"pct": 0.50}],
		["mana_ward", "Mana Ward", "Wards the party: Defense and Armor up.", "buff_party", {"buffs": [["def", 12], ["armor", 4]], "turns": 2}],
		["soothing_rain", "Soothing Rain", "Heals the whole party for a medium amount.", "heal_party", {"pct": 0.25}],
		["renewal", "Renewal", "Heals the whole party and adds Defense.", "heal_party", {"pct": 0.30, "party_buff": [["def", 12]], "pturns": 2}],
		["grand_restoration", "Grand Restoration", "Heals the whole party for a large amount.", "heal_party", {"pct": 0.50}],
	],
	"Duelist": [
		["riposte", "Riposte", "Strikes one foe and guards the counter.", "damage_single", {"mult": 2.2, "self_buff": [["def", 12]], "sturns": 1}],
		["feint", "Feint", "A feint that opens the guard (big Defense down).", "damage_single", {"mult": 2.0, "debuff": [["def", -18]], "dturns": 2}],
		["en_garde", "En Garde", "Ready stance: Crit and Speed up.", "buff_self", {"buffs": [["crit", 15], ["speed", 10]], "turns": 2}],
		["perfect_lunge", "Perfect Lunge", "One perfect lunge — heavy single-target damage.", "damage_single", {"mult": 4.2}],
		["duels_end", "Duel's End", "Ends the duel: huge hit, then Crit up.", "damage_single", {"mult": 5.2, "self_buff": [["crit", 15]], "sturns": 2}],
	],
}

func build_abilities() -> void:
	ABILITY_DEFS = {}
	AB_CLASS_LIST = {}
	AB_SUB_LIST = {}
	for hero in AB_CLASS_ROWS:
		var rows: Array = AB_CLASS_ROWS[hero]
		var ids: Array = []
		for i in rows.size():
			var r: Array = rows[i]
			var lv: int = int(CLASS_UNLOCKS[mini(i, CLASS_UNLOCKS.size() - 1)])
			ABILITY_DEFS[r[0]] = {"id": r[0], "name": r[1], "blurb": r[2], "kind": r[3], "params": r[4],
				"lv": lv, "src": "class", "owner": hero, "mp": AB_MP, "tier": i + 1}
			ids.append(r[0])
		AB_CLASS_LIST[hero] = ids
	for sub in AB_SUB_ROWS:
		var rows2: Array = AB_SUB_ROWS[sub]
		var ids2: Array = []
		for i in rows2.size():
			var r2: Array = rows2[i]
			var lv2: int = int(SUB_UNLOCKS[mini(i, SUB_UNLOCKS.size() - 1)])
			ABILITY_DEFS[r2[0]] = {"id": r2[0], "name": r2[1], "blurb": r2[2], "kind": r2[3], "params": r2[4],
				"lv": lv2, "src": "sub", "owner": sub, "mp": AB_MP, "tier": i + 1}
			ids2.append(r2[0])
		AB_SUB_LIST[sub] = ids2

const STAT_SHORT := {"atk": "ATK", "def": "DEF", "armor": "ARM", "speed": "SPD", "crit": "CRIT"}

func mods_text(mods: Array) -> String:
	var parts: Array = []
	for m in mods:
		var stat: String = str(m[0])
		var amt: int = int(m[1])
		parts.append("%s %+d" % [str(STAT_SHORT.get(stat, stat.to_upper())), amt])
	return ", ".join(parts)

## Short, phone-readable effect line generated from the data row.
func ab_effect_line(id: String) -> String:
	if not ABILITY_DEFS.has(id):
		return ""
	var ab: Dictionary = ABILITY_DEFS[id]
	var p: Dictionary = ab.params
	var kind: String = str(ab.kind)
	var out: String = ""
	if kind == "damage_single":
		out = "Hits one foe x%.1f" % float(p.get("mult", 1.0))
	elif kind == "damage_all_enemies":
		out = "Hits all foes x%.1f" % float(p.get("mult", 1.0))
	elif kind == "heal_single":
		var size_s: String = "large" if float(p.get("pct", 0.0)) >= 0.4 else "medium"
		out = ("Heals self (%s)" % size_s) if bool(p.get("self", false)) else ("Heals one ally (%s)" % size_s)
	elif kind == "heal_party":
		var pct: float = float(p.get("pct", 0.0))
		var size_p: String = "large" if pct >= 0.45 else ("medium" if pct >= 0.2 else "small")
		out = "Heals party (%s)" % size_p
	elif kind == "buff_self":
		out = "Self " + mods_text(p.get("buffs", [])) + " %dT" % int(p.get("turns", 1))
	elif kind == "buff_party":
		out = "Party " + mods_text(p.get("buffs", [])) + " %dT" % int(p.get("turns", 1))
	if p.has("debuff"):
		out += " · Foe " + mods_text(p.debuff)
	if p.has("self_buff"):
		out += " · Self " + mods_text(p.self_buff)
	if p.has("party_buff"):
		out += " · Party " + mods_text(p.party_buff)
	return out

func ab_color(id: String) -> Color:
	if not ABILITY_DEFS.has(id):
		return Color("#c9a0ff")
	var kind: String = str(ABILITY_DEFS[id].kind)
	if kind == "heal_single" or kind == "heal_party":
		return Color("#5dff8a")
	if kind == "buff_self" or kind == "buff_party":
		return Color("#7fd8ff")
	return Color("#c98bff")

func class_ability_ids(name: String) -> Array:
	return AB_CLASS_LIST.get(name, [])

func sub_ability_ids(sub: String) -> Array:
	return AB_SUB_LIST.get(sub, [])

func ab_unlocked(name: String, id: String) -> bool:
	if not ABILITY_DEFS.has(id):
		return false
	return hero_level(name) >= int(ABILITY_DEFS[id].lv)

func unlocked_class_ids(name: String) -> Array:
	var out: Array = []
	for id in class_ability_ids(name):
		if ab_unlocked(name, id):
			out.append(id)
	return out

func unlocked_sub_ids(name: String) -> Array:
	var out: Array = []
	var sub: String = str(CHAR[name].sub)
	for id in sub_ability_ids(sub):
		if ab_unlocked(name, id):
			out.append(id)
	return out

## Keeps a hero's two equipped abilities valid: one owned class ability, one owned
## ability from the CURRENT subclass. Invalid picks fall back to the first unlocked.
func validate_ab_equip(name: String) -> void:
	if not AB_EQUIP.has(name):
		AB_EQUIP[name] = {"cls": "", "sub": ""}
	var e: Dictionary = AB_EQUIP[name]
	var cids: Array = unlocked_class_ids(name)
	var cur_c: String = str(e.get("cls", ""))
	if cids.find(cur_c) < 0:
		e["cls"] = str(cids[0]) if cids.size() > 0 else ""
	var sids: Array = unlocked_sub_ids(name)
	var cur_s: String = str(e.get("sub", ""))
	if sids.find(cur_s) < 0:
		e["sub"] = str(sids[0]) if sids.size() > 0 else ""
	# The auto pick must stay one of the two equipped abilities; otherwise auto just basic-attacks.
	if AB_AUTO.has(name):
		var aid: String = str(AB_AUTO[name])
		if aid != "" and aid != str(e["cls"]) and aid != str(e["sub"]):
			AB_AUTO[name] = ""

## Which equipped ability auto-battle uses for this hero ("" = none).
func auto_ab(name: String) -> String:
	validate_ab_equip(name)
	if not AB_AUTO.has(name):
		return str(AB_EQUIP[name].cls)
	return str(AB_AUTO[name])

## Mark (or unmark) one of the two equipped abilities for auto-battle.
func set_auto_ab(name: String, id: String) -> void:
	validate_ab_equip(name)
	if id != str(AB_EQUIP[name].cls) and id != str(AB_EQUIP[name].sub):
		return
	AB_AUTO[name] = "" if auto_ab(name) == id else id
	save_cfg()
	sfx.tone(988 if AB_AUTO[name] != "" else 440, 0.05, "triangle", 0.03)

func equipped_class_ab(name: String) -> String:
	validate_ab_equip(name)
	return str(AB_EQUIP[name].cls)

func equipped_sub_ab(name: String) -> String:
	validate_ab_equip(name)
	return str(AB_EQUIP[name].sub)

func equip_ability(name: String, id: String) -> bool:
	if not ABILITY_DEFS.has(id) or not ab_unlocked(name, id):
		return false
	validate_ab_equip(name)
	var ab: Dictionary = ABILITY_DEFS[id]
	var was_auto: String = auto_ab(name)
	var slot_key: String = "cls" if str(ab.src) == "class" else "sub"
	if str(ab.src) == "class":
		if str(ab.owner) != name:
			return false
	else:
		if str(ab.owner) != str(CHAR[name].sub):
			return false
	var old_id: String = str(AB_EQUIP[name][slot_key])
	AB_EQUIP[name][slot_key] = id
	# Swapping out the auto ability clears the auto pick (auto then basic-attacks until one is marked).
	if AB_AUTO.has(name) and was_auto != "" and was_auto == old_id and old_id != id:
		AB_AUTO[name] = ""
	save_cfg()
	return true

# Class is locked to the character. Only subclass is swappable in the Characters page.
var CHAR := {
	"Airron": {"cls": "Knight", "sub": "Riftblade", "ability": "rift_cut"},
	"Christian": {"cls": "Paladin", "sub": "Vanguard", "ability": "holy_strike"},
	"Weston": {"cls": "Ranger", "sub": "Scout", "ability": "quick_mark"},
	"Wiesen": {"cls": "Marksman", "sub": "Sharpshot", "ability": "piercing_shot"},
	"Lanning": {"cls": "Guardian", "sub": "Ironhide", "ability": "iron_wall"},
	"Rico": {"cls": "Warrior", "sub": "Raider", "ability": "raid_step"},
}
# Per-hero level / XP. Cap 99. Growth is computed from current level + current subclass
# (changing subclass retargets the focused bonus; it is not locked at the time you leveled).
const LEVEL_CAP := 99
var SUB_FOCUS := {
	"Riftblade": "atk",
	"Vanguard": "hp",
	"Scout": "speed",
	"Sharpshot": "crit",
	"Ironhide": "armor",
	"Raider": "atk",
	"Sage": "mana",
	"Duelist": "crit",
}
var FOCUS_LABELS := {
	"hp": "HP", "atk": "ATK", "def": "Defense", "armor": "Armor",
	"crit": "Crit", "mana": "Mana", "speed": "Speed",
}
var HERO_PROG := {}
# First 5 fight; the rest sit on the bench. Index 0 is the lead (overworld model).
const PARTY_SIZE := 5
var SQUAD := ["Airron", "Christian", "Weston", "Wiesen", "Lanning", "Rico"]
# Shared bag + per-hero equipment. Slot keys match ITEM_DEFS.slot.
const SLOT_IDS := ["weapon", "armor", "gloves", "amulet"]
const SLOT_LABELS := {"weapon": "Weapon", "armor": "Armor", "gloves": "Gloves", "amulet": "Amulet"}
var ITEM_DEFS := {
	"riftbrand": {"name": "Riftbrand", "slot": "weapon", "blurb": "A keen rift-forged blade", "atk": 6, "crit": 2},
	"hollow_bow": {"name": "Hollow Bow", "slot": "weapon", "blurb": "Quiet and precise", "atk": 5, "crit": 4},
	"oak_maul": {"name": "Oak Maul", "slot": "weapon", "blurb": "Heavy wooden heft", "atk": 3, "hp": 12},
	"iron_plate": {"name": "Iron Plate", "slot": "armor", "blurb": "Solid, weighty cover", "armor": 4, "def": 4, "hp": 16},
	"trail_vest": {"name": "Trail Vest", "slot": "armor", "blurb": "Light travel padding", "def": 3, "speed": 2, "hp": 8},
	"warden_mail": {"name": "Warden Mail", "slot": "armor", "blurb": "Steady protective rings", "armor": 3, "def": 6, "hp": 12},
	"grip_wraps": {"name": "Grip Wraps", "slot": "gloves", "blurb": "A firmer hold on the strike", "atk": 3, "crit": 2},
	"swift_cuffs": {"name": "Swift Cuffs", "slot": "gloves", "blurb": "Light on the hands", "speed": 3, "crit": 2},
	"stone_fists": {"name": "Stone Fists", "slot": "gloves", "blurb": "Knuckles like cobble", "armor": 2, "atk": 2},
	"sage_hands": {"name": "Sage Hands", "slot": "gloves", "blurb": "Steady for channeling", "mana": 3, "def": 1},
	"ember_charm": {"name": "Ember Charm", "slot": "amulet", "blurb": "A warm spark at the throat", "atk": 2, "crit": 3},
	"brook_pendant": {"name": "Brook Pendant", "slot": "amulet", "blurb": "A calm, lingering ward", "hp": 20, "mana": 2},
	"veil_talisman": {"name": "Veil Talisman", "slot": "amulet", "blurb": "A thin extra guard", "def": 3, "armor": 2},
	"wind_seal": {"name": "Wind Seal", "slot": "amulet", "blurb": "A push at the heels", "speed": 4, "crit": 1},
}
const STARTER_BAG := ["riftbrand", "oak_maul", "trail_vest", "grip_wraps", "swift_cuffs", "ember_charm", "brook_pendant", "sage_hands"]
var INV: Array = []
var EQUIP := {}
# Menu / overworld UI state
var inv_slot_sel := ""
var party_sel := 0
var ow_x := 0.0
var ow_y := 0.0
var ow_tx := 0.0
var ow_ty := 0.0
var ow_facing := 1
var ow_anim := "idle"
var ow_at := 0.0
var ow_camx := 0.0
var ow_camy := 0.0
var ow_scale := 1.0
var ow_moving := false
var ow_ready := false
# Overworld campaign: data-driven world, region map, stats screen, wild encounters.
const WorldScript = preload("res://scripts/world.gd")
const WorldMapUI = preload("res://scripts/world_map_ui.gd")
const StatsUI = preload("res://scripts/stats_ui.gd")
const CompendiumUI = preload("res://scripts/compendium.gd")
var COMP = null
var WORLD = null
var WMAP = null
var STATS = null
var ow_menu_open := false
var menu_return := "" # "overworld" when a menu screen was opened from the overworld
var encounter: Dictionary = {} # non-empty while a wild battle is running
var drag_on := false
var drag_moved := false
var drag_from := Vector2.ZERO
var drag_last := Vector2.ZERO
# Rivenbrook — original starter hamlet (not a Nintendo map).
const TOWN_NAME := "Rivenbrook"
const OW_C0 := 1
const OW_C1 := 16
const OW_R0 := 1
const OW_R1 := 12
var OW_BLOCK := [] # Rect2 in world space
var OW_PROPS := []
var OW_DECO := []
var OW_SHEEP := []
# 5-fighter landscape slots: three front, two back.
var BLUE_SLOTS_5 := [[360, 210], [375, 330], [360, 450], [215, 250], [215, 410]]
var GOB_CLASS := {
	"torch": {"cls": "Skirmisher", "sub": "Emberblade", "atk": 72, "def": 36, "armor": 8, "crit": 8, "mana": 6, "speed": 14},
	"tnt": {"cls": "Bomber", "sub": "Demolitionist", "atk": 84, "def": 22, "armor": 4, "crit": 10, "mana": 4, "speed": 12},
	"barrel": {"cls": "Bruiser", "sub": "Powderguard", "atk": 58, "def": 52, "armor": 14, "crit": 6, "mana": 5, "speed": 8},
	"necro": {"cls": "Boss", "sub": "Necromancer", "atk": 72, "def": 40, "armor": 12, "crit": 8, "mana": 10, "speed": 10},
}
var GOB_FLAVOR := {
	"Rusk": {"atk": 0.98, "def": 1.08}, "Kael": {"atk": 1.10, "def": 0.88}, "Sable": {"atk": 0.92, "def": 1.18},
	"Drenn": {"atk": 1.14, "def": 0.82}, "Voss": {"atk": 1.00, "def": 1.05}, "Iven": {"atk": 0.96, "def": 1.10},
}
func hp_from_atk(atk: float) -> int: return int(roundf((108.0 - atk) * 6.5 + 120.0))
func clamp_stat(n: float) -> int: return int(maxf(1, minf(100, roundf(n))))
func clamp_range(n: float, lo: float, hi: float) -> int: return int(maxf(lo, minf(hi, roundf(n))))

func pack_add(d: Dictionary, pack: Dictionary) -> void:
	for k in ["hp", "atk", "def", "armor", "crit", "mana", "speed"]:
		d[k] = int(d.get(k, 0)) + int(pack.get(k, 0))

func compute_hero_stats(name: String) -> Dictionary:
	var loadout: Dictionary = CHAR[name]
	var cls: String = loadout.cls
	var sub: String = loadout.sub
	if not CLASS_DEFS.has(cls): cls = "Knight"
	if not SUB_DEFS.has(sub): sub = "Riftblade"
	var ability_id: String = str(loadout.get("ability", ""))
	var ab: Dictionary = ABILITY_DEFS[ability_id] if ABILITY_DEFS.has(ability_id) else {"name": ability_id, "blurb": ""}
	var d: Dictionary = HERO_BASE[name].duplicate()
	pack_add(d, CLASS_DEFS[cls])
	pack_add(d, SUB_DEFS[sub])
	var lv: int = hero_level(name)
	pack_add(d, level_bonus(lv, sub))
	var eq: Dictionary = EQUIP[name] if EQUIP.has(name) else {}
	for slot in SLOT_IDS:
		var iid: String = str(eq.get(slot, ""))
		if iid != "" and ITEM_DEFS.has(iid):
			pack_add(d, ITEM_DEFS[iid])
	var xp: int = hero_xp(name)
	var focus: String = sub_focus_stat(sub)
	return {
		"hp": clamp_range(d.hp, 140, 1200),
		"atk": clamp_range(d.atk, 1, 180),
		"def": clamp_range(d.def, 1, 180),
		"armor": clamp_range(d.armor, 0, 60),
		"crit": clamp_range(d.crit, 1, 70),
		"mana": clamp_range(d.mana, 0, 50),
		"speed": clamp_range(d.speed, 1, 70),
		"cls": cls, "sub": sub, "kind": CLASS_DEFS[cls].kind,
		"blurb": CLASS_DEFS[cls].blurb, "sub_blurb": SUB_DEFS[sub].blurb, "scale": 1.0,
		"ability": ability_id, "ability_name": ab.name, "ability_blurb": ab.blurb,
		"level": lv, "xp": xp, "xp_next": xp_to_next(lv),
		"focus": focus, "focus_name": FOCUS_LABELS.get(focus, "ATK"),
	}

func hero_level(name: String) -> int:
	if not HERO_PROG.has(name):
		return 1
	return int(HERO_PROG[name].level)

func hero_xp(name: String) -> int:
	if not HERO_PROG.has(name):
		return 0
	return int(HERO_PROG[name].xp)

func xp_to_next(level: int) -> int:
	if level >= LEVEL_CAP:
		return 0
	# Early levels come in a fight or two; the curve steepens so 99 stays a long-term cap.
	return 50 + 8 * level + int(level * level * 2 / 5)

func sub_focus_stat(sub: String) -> String:
	if SUB_FOCUS.has(sub):
		return str(SUB_FOCUS[sub])
	return "atk"

func level_bonus(level: int, sub: String = "Riftblade") -> Dictionary:
	# General bump on every stat, plus a larger extra bump on the current subclass focus.
	# Recalculated from level + current subclass (not historic).
	var lv: int = maxi(0, level - 1)
	var d := {
		"hp": 2 * lv,
		"atk": int(roundf(0.25 * lv)),
		"def": int(roundf(0.25 * lv)),
		"armor": int(roundf(0.10 * lv)),
		"crit": int(roundf(0.15 * lv)),
		"mana": int(roundf(0.10 * lv)),
		"speed": int(roundf(0.15 * lv)),
	}
	var focus := sub_focus_stat(sub)
	var extra := {"hp": 4.0, "atk": 0.60, "def": 0.50, "armor": 0.25, "crit": 0.35, "mana": 0.30, "speed": 0.40}
	var add := int(roundf(float(extra.get(focus, 0.6)) * lv))
	d[focus] = int(d[focus]) + add
	return d

func ensure_hero_data() -> void:
	for name in HERO_NAMES:
		if not HERO_PROG.has(name):
			HERO_PROG[name] = {"level": 1, "xp": 0}
		if not EQUIP.has(name):
			EQUIP[name] = {"weapon": "", "armor": "", "gloves": "", "amulet": ""}
		else:
			for slot in SLOT_IDS:
				if not EQUIP[name].has(slot):
					EQUIP[name][slot] = ""
	if SQUAD.size() != HERO_NAMES.size():
		SQUAD = HERO_NAMES.duplicate()
	# Keep a unique, complete order; unknown names dropped.
	var seen := {}
	var cleaned: Array = []
	for name in SQUAD:
		if HERO_NAMES.find(name) >= 0 and not seen.has(name):
			cleaned.append(name)
			seen[name] = true
	for name in HERO_NAMES:
		if not seen.has(name):
			cleaned.append(name)
	SQUAD = cleaned

func party_names() -> Array:
	return SQUAD.slice(0, mini(PARTY_SIZE, SQUAD.size()))

func bench_names() -> Array:
	return SQUAD.slice(mini(PARTY_SIZE, SQUAD.size()))

func lead_name() -> String:
	var p := party_names()
	return p[0] if p.size() > 0 else HERO_NAMES[0]

func raid_xp_award(n_red: int, win: bool) -> int:
	var base := 80 if n_red == 3 else (110 if n_red == 2 else 150)
	return base if win else int(roundf(float(base) * 0.25))

func grant_hero_xp(name: String, amount: int) -> int:
	ensure_hero_data()
	if amount <= 0 or not HERO_PROG.has(name):
		return 0
	var p: Dictionary = HERO_PROG[name]
	if int(p.level) >= LEVEL_CAP:
		p.xp = 0
		return 0
	p.xp = int(p.xp) + amount
	var gained := 0
	while int(p.level) < LEVEL_CAP and int(p.xp) >= xp_to_next(int(p.level)):
		p.xp = int(p.xp) - xp_to_next(int(p.level))
		p.level = int(p.level) + 1
		gained += 1
	if int(p.level) >= LEVEL_CAP:
		p.xp = 0
	return gained

func item_bonus_text(iid: String) -> String:
	if not ITEM_DEFS.has(iid):
		return ""
	var it: Dictionary = ITEM_DEFS[iid]
	var parts: Array = []
	var labels := {"hp": "HP", "atk": "ATK", "def": "DEF", "armor": "ARM", "crit": "CRIT", "mana": "MANA", "speed": "SPD"}
	for k in ["hp", "atk", "def", "armor", "crit", "mana", "speed"]:
		var v := int(it.get(k, 0))
		if v != 0:
			parts.append("%+d %s" % [v, labels[k]])
	return "  ".join(parts)

func equip_item(name: String, iid: String) -> bool:
	ensure_hero_data()
	if not ITEM_DEFS.has(iid):
		return false
	var slot: String = ITEM_DEFS[iid].slot
	var bag_i := INV.find(iid)
	if bag_i < 0:
		return false
	INV.remove_at(bag_i)
	var cur: String = str(EQUIP[name].get(slot, ""))
	if cur != "" and ITEM_DEFS.has(cur):
		INV.append(cur)
	EQUIP[name][slot] = iid
	save_cfg()
	apply_loadout_preview(name)
	return true

func unequip_slot(name: String, slot: String) -> bool:
	ensure_hero_data()
	if SLOT_IDS.find(slot) < 0:
		return false
	var cur: String = str(EQUIP[name].get(slot, ""))
	if cur == "":
		return false
	EQUIP[name][slot] = ""
	if ITEM_DEFS.has(cur):
		INV.append(cur)
	save_cfg()
	apply_loadout_preview(name)
	return true

func swap_party_with_bench(party_i: int, bench_i: int) -> void:
	ensure_hero_data()
	var p := party_names()
	var b := bench_names()
	if party_i < 0 or party_i >= p.size() or bench_i < 0 or bench_i >= b.size():
		return
	var pi := party_i
	var bi := PARTY_SIZE + bench_i
	var tmp = SQUAD[pi]
	SQUAD[pi] = SQUAD[bi]
	SQUAD[bi] = tmp
	save_cfg()
	sfx.tone(660, 0.05, "square", 0.03)

func move_party_slot(i: int, dir: int) -> void:
	ensure_hero_data()
	var j := i + dir
	if i < 0 or i >= PARTY_SIZE or j < 0 or j >= PARTY_SIZE or i >= SQUAD.size() or j >= SQUAD.size():
		return
	var tmp = SQUAD[i]
	SQUAD[i] = SQUAD[j]
	SQUAD[j] = tmp
	party_sel = j
	save_cfg()
	sfx.tone(523, 0.045, "triangle", 0.025)

func build_blue_roster() -> Array:
	var active: Array = party_names()
	var melee: Array = []
	var ranged: Array = []
	for name in active:
		var st := compute_hero_stats(name)
		var kind: String = st.kind
		if not KINDS.has(kind):
			kind = "warrior"
		if str(KINDS[kind].get("ranged", "")) != "":
			ranged.append([kind, name])
		else:
			melee.append([kind, name])
	var front: Array = melee.slice(0, mini(3, melee.size()))
	var back: Array = ranged.slice(0, mini(2, ranged.size()))
	var extra_m: Array = melee.slice(front.size())
	var extra_r: Array = ranged.slice(back.size())
	while front.size() < 3 and extra_r.size() > 0:
		front.append(extra_r[0]); extra_r.remove_at(0)
	while back.size() < 2 and extra_m.size() > 0:
		back.append(extra_m[0]); extra_m.remove_at(0)
	var order: Array = front + back + extra_m + extra_r
	var out := []
	for i in order.size():
		if i >= BLUE_SLOTS_5.size():
			break
		out.append([order[i][0], order[i][1], BLUE_SLOTS_5[i][0], BLUE_SLOTS_5[i][1]])
	return out

func char_stats(name: String, kind: String, team: String, n_red: int) -> Dictionary:
	if team == "blue":
		return compute_hero_stats(name)
	var g: Dictionary = GOB_CLASS[kind]
	var f: Dictionary = GOB_FLAVOR.get(name, {"atk": 1.0, "def": 1.0})
	var hpM := 4.2 if n_red == 1 else (2.2 if n_red == 2 else 1.25)
	var atkM := 1.35 if n_red == 1 else (1.15 if n_red == 2 else 1.0)
	var defM := 1.25 if n_red == 1 else (1.1 if n_red == 2 else 1.0)
	return {
		"hp": int(roundf(hp_from_atk(g.atk) * hpM)),
		"atk": clamp_stat(g.atk * f.atk * atkM), "def": clamp_stat(g.def * f.def * defM),
		"armor": clamp_range(g.get("armor", 8) * defM, 0, 40),
		"crit": clamp_range(g.get("crit", 8), 1, 50),
		"mana": clamp_range(g.get("mana", 6), 0, 25),
		"speed": clamp_range(g.get("speed", 12), 1, 40),
		"cls": "Boss" if n_red == 1 else ("Elite" if n_red == 2 else g.cls),
		"sub": (g.sub if kind == "necro" else "Rift Tyrant") if n_red == 1 else g.sub,
		"kind": kind,
		"scale": 1.4 if n_red == 1 else (1.12 if n_red == 2 else 1.0),
	}
func def_mit(d: float) -> float: return 100.0 / (100.0 + maxf(0.0, d))
func uS(u) -> float: return US * (u.scale if u else 1.0)
# landscape design coords, front (melee) slots first. Slot 1 = single boss (missing in game.js).
var RED_SLOTS := {
	1: [[740, 330]],
	2: [[680, 280], [760, 395]],
	3: [[670, 260], [670, 400], [800, 330]],
}
var USE_NECRO := true
func build_red_roster(n: int) -> Array:
	var names := shuffled(GOB_NAMES)
	if n == 1 and USE_NECRO:
		return [["necro", names[0], RED_SLOTS[1][0][0], RED_SLOTS[1][0][1]]]
	var kinds := shuffled(["torch", "torch", "barrel", "barrel", "tnt", "tnt"]).slice(0, n)
	var all_tnt := true
	for k in kinds:
		if k != "tnt": all_tnt = false
	if all_tnt: kinds[0] = pick(["torch", "barrel"])
	var nt := kinds.filter(func(k): return k != "tnt")
	var tt := kinds.filter(func(k): return k == "tnt")
	kinds = nt + tt
	var slots: Array = RED_SLOTS[n]
	var out := []
	for i in kinds.size():
		out.append([kinds[i], names[i], slots[i][0], slots[i][1]])
	return out
const US := 0.8

# ---------------------------------------------------------------- data classes
class Plan:
	var target = null
	var combo = null # Array of Unit or null
	var combo_done := false
	var contact_done := false

class Act:
	var target = null
	var special := false
	var stage := "go"
	var t := 0.0
	var swing := 0
	var ready := false
	var ready_t := 0.0
	var d := {}
	var hit_done := false
	var hold_t := 0.0
	var doubled := false
	var ability := ""

class Unit:
	var id := ""
	var team := ""
	var kind := ""
	var K := {}
	var name := ""
	var x := 0.0
	var y := 0.0
	var hx := 0.0
	var hy := 0.0
	var hp := 0
	var maxhp := 0
	var shown_hp := 0.0
	var atk := 0
	var def := 0
	var armor := 0
	var crit := 10
	var mana_regen := 0
	var speed := 12
	var cls := ""
	var sub := ""
	var scale := 1.0
	var gauge := 0.0
	var facing := 1
	var anim := "idle"
	var at := 0.0
	var act = null
	var flash := 0.0
	var shake := 0.0
	var kx := 0.0
	var dead := false
	var death_t := 0.0
	var gone := false
	var dmg := 0
	var kos := 0
	var pop := 0.0
	var burn = null
	var plan = null
	var buffs := []
	var ab_class := ""
	var ab_sub := ""
	var ab_queued := ""

class Proj:
	var kind := ""
	var owner = null
	var act = null
	var last := true
	var target = null
	var x := 0.0
	var y := 0.0
	var sx := 0.0
	var sy := 0.0
	var t := 0.0
	var dur := 0.0
	var tx := 0.0
	var ty := 0.0
	var special := false
	var pierce := false
	var mult := 1.0
	var speed := 900.0
	var delay := 0.0
	var rot := 0.0
	var ang := 0.0
	var ability := ""

class Battle:
	var units := []
	var n_red := 3
	var t := 0.0
	var turn := 0
	var side := "blue"
	var mode := "select"
	var queue := []
	var qi := 0
	var gap := 0.0
	var cur = null
	var end_t := 0.0
	var result := ""
	var ab_focus = null

# ---------------------------------------------------------------- state
var G: Battle = null
var phase := "loading" # loading | title | battle | ending | results
var screen := "" # "title" | "results" | "" (battle HUD)
var paused := false
var speed := 1
var muted := false
var AUTO := false
var last_raid := 3
var fx := []
var projectiles := []
var texts := []
var shake_t := 0.0
var shake_mag := 0.0
var banner = null
var now := 0.0
var hitstop := 0.0
var sync_pending := []
var params := {}
var sfx
var results_t := 0.0
var res := {}
var char_sel := 0
var char_prev := {}
var char_bar := {}
var char_delta_t := 0.0

func new_battle(n: int = 0) -> void:
	if G != null:
		for ou in G.units:
			ou.plan = null; ou.act = null; ou.burn = null
		G.queue = []; G.cur = null
	sync_pending = []
	var units := []
	var enc_on: bool = not encounter.is_empty()
	if n == 0: n = int(params.get("enemies", "0"))
	if n == 0: n = last_raid
	if n != 1 and n != 2 and n != 3: n = 3
	var red: Array = []
	var emult: Dictionary = {}
	if enc_on:
		red = build_encounter_roster()
		n = red.size()
		emult = WORLD.enemy_mult(int(encounter.get("level", 1)))
	else:
		last_raid = n
		red = build_red_roster(n)
	for team in ["blue", "red"]:
		var roster: Array = build_blue_roster() if team == "blue" else red
		for i in roster.size():
			var r: Array = roster[i]
			var p := mp(r[2], r[3])
			var st: Dictionary = char_stats(r[1], r[0], team, 3 if enc_on else n)
			if enc_on and team == "red":
				st.hp = maxi(40, int(roundf(float(st.hp) * float(emult.hp))))
				st.atk = maxi(1, int(roundf(float(st.atk) * float(emult.atk))))
				st.def = maxi(1, int(roundf(float(st.def) * float(emult.def))))
			var kind: String = st.get("kind", r[0])
			if not KINDS.has(kind): kind = r[0]
			var u := Unit.new()
			u.id = team + str(i); u.team = team; u.kind = kind; u.K = KINDS[kind]; u.name = r[1]
			u.x = p.x; u.y = p.y; u.hx = p.x; u.hy = p.y
			u.hp = st.hp; u.maxhp = st.hp; u.shown_hp = st.hp; u.atk = st.atk; u.def = st.def
			u.armor = st.get("armor", 0); u.crit = st.get("crit", 10)
			u.mana_regen = st.get("mana", 0); u.speed = st.get("speed", 12)
			u.cls = st.cls; u.sub = st.sub; u.scale = st.scale
			if team == "blue" and CHAR.has(u.name):
				u.ab_class = equipped_class_ab(u.name); u.ab_sub = equipped_sub_ab(u.name)
			u.gauge = clampf(float(HERO_MP.get(u.name, 0.0)), 0.0, AB_MP) if team == "blue" else rand(0, 30)
			u.facing = 1 if team == "blue" else -1; u.at = rand(0, 1000)
			units.append(u)
	G = Battle.new()
	G.units = units
	G.n_red = n
	fx = []; projectiles = []; texts = []; banner = null; cast_banner = null; screen_flash = null

# ---------------------------------------------------------------- simulation
func alive(team: String) -> Array:
	return G.units.filter(func(u): return u.team == team and not u.dead)
func enemy_of(u) -> String: return "red" if u.team == "blue" else "blue"
func surge_mult() -> float: return 1.0 + (G.turn - 3) * 0.35 if G.turn > 3 else 1.0
func home_facing(u) -> int: return 1 if u.team == "blue" else -1

func pick_atk(u, tgt) -> Array:
	var K: Dictionary = u.K
	var dx: float = tgt.x - u.x
	var dy: float = tgt.y - u.y
	var list: Array = K.atk
	if absf(dy) > absf(dx) * 1.1:
		if dy < 0 and K.has("atkUp"): list = K.atkUp
		elif dy > 0 and K.has("atkDown"): list = K.atkDown
	elif K.ranged != "" and absf(dy) > absf(dx) * 0.45:
		if dy < 0 and K.has("atkUp"): list = K.atkUp
		elif dy > 0 and K.has("atkDown"): list = K.atkDown
	return list

func set_anim(u, a: String) -> void:
	if u.anim != a:
		u.anim = a; u.at = 0.0

func plan_actions(queue: Array) -> void:
	for u in queue: u.plan = null
	for u in queue:
		if u.dead: continue
		var foes := alive(enemy_of(u))
		if foes.is_empty(): continue
		var p := Plan.new()
		p.target = foes[0] if params.get("focus", "") == "1" else pick(foes)
		u.plan = p

func start_action(u) -> bool:
	var foes := alive(enemy_of(u))
	if foes.is_empty(): return false
	var t = u.plan.target if (u.plan != null and u.plan.target != null and not u.plan.target.dead) else pick(foes)
	if u.plan != null: u.plan.target = t
	if u.team == "blue" and u.ab_queued != "" and ABILITY_DEFS.has(u.ab_queued) and u.gauge >= AB_MP:
		return start_ability(u, u.ab_queued)
	u.ab_queued = ""
	# Heroes HOLD a full MP bar for an ability; only enemies auto-fire their kit special.
	var special: bool = u.gauge >= 100 and u.team != "blue"
	var a := Act.new()
	a.target = t; a.special = special; a.stage = "atk" if u.K.ranged != "" else "go"
	u.act = a
	if u.K.ranged != "": begin_swing(u)
	if special:
		u.gauge = 0.0
		add_text(u.x, u.y - u.K.head * uS(u) - 30, u.K.special + "!", "#9fe3ff" if u.team == "blue" else "#ffb27a", 17, 1000, true)
		fx.append({"type": "ring", "x": u.x, "y": u.y - 20, "t": 0.0, "life": 380.0, "color": Color("#7fd8ff") if u.team == "blue" else Color("#ff9a4a")})
		sfx.special()
	else:
		u.gauge = minf(100, u.gauge + 22)
	return true

func begin_swing(u) -> void:
	var a = u.act
	var list := pick_atk(u, a.target)
	a.d = list[mini(a.swing, list.size() - 1)] if (is_warrior_kit(u.kind) or u.kind == "pawn") else list[0]
	a.stage = "atk"; a.t = 0.0; a.hit_done = false; a.hold_t = 0.0
	u.facing = 1 if a.target.x >= u.x else -1

func update_unit(u, dt: float) -> void:
	if u.flash > 0: u.flash -= dt
	if u.shake > 0: u.shake -= dt
	u.kx *= pow(0.0001, dt / 1000.0)
	u.shown_hp += (u.hp - u.shown_hp) * minf(1.0, dt / 220.0)
	if u.dead:
		u.death_t += dt
		if u.death_t > 1700: u.gone = true
		return
	u.at += dt
	if u.burn != null and u.burn.t > 0:
		u.burn.t -= dt
		if u.burn.t <= 0:
			var b: Dictionary = u.burn
			u.burn = null
			hit(b.owner, u, b.mult, false, true, "#ff9a3d")
			fx.append({"type": "sprite", "img": "fire", "fw": 128.0, "fh": 128.0, "n": 7, "fps": 16.0, "x": u.x, "y": u.y + 6, "ax": 64.0, "ay": 105.0, "s": 0.5, "t": 0.0, "loops": 1})
	var a = u.act
	if a == null:
		set_anim(u, "idle"); return
	if a.ready: a.ready_t += dt
	var t = a.target
	if a.stage == "go":
		if t.dead:
			var foes := alive(enemy_of(u))
			if not foes.is_empty():
				t = pick(foes); a.target = t
				if u.plan != null:
					u.plan.target = t; u.plan.combo = null
			else:
				a.stage = "back"; a.ready = true; return
		var side := -1.0 if u.hx < t.x else 1.0
		var gx: float = t.x + side * (u.K.range + 4)
		var gy: float = t.y + 2
		if move_to(u, gx, gy, 720, dt): begin_swing(u)
		return
	if a.stage == "atk":
		a.t += dt
		var d: Dictionary = a.d
		var fr := int(floorf(a.t * d.fps / 1000.0))
		if not a.hit_done and fr >= d.hit:
			a.hit_done = true; resolve_hit(u, a)
		if fr >= d.n:
			a.hold_t += dt
			if a.hold_t < d.get("hold", 150): return
			if a.ability != "":
				if a.stage == "atk" and (a.target == u or str(ABILITY_DEFS[a.ability].kind) != "damage_single" or u.K.ranged != ""):
					a.stage = "wait"
				else:
					a.stage = "back"; a.ready = true
				return
			if is_warrior_kit(u.kind) and a.swing == 0:
				a.swing = 1; begin_swing(u); return
			# Follow-up strike if still in range. Warriors already swing twice as their kit.
			if u.kind != "warrior" and not a.doubled and a.target != null and not a.target.dead:
				var dx: float = a.target.x - u.x
				var dy: float = a.target.y - u.y
				if sqrt(dx * dx + dy * dy) <= float(u.K.range) + 12.0:
					a.doubled = true
					a.swing = 0
					begin_swing(u)
					return
			if u.K.ranged != "": a.stage = "wait"
			else:
				a.stage = "back"; a.ready = true
		return
	if a.stage == "wait":
		set_anim(u, "idle")
		if a.ready and a.ready_t > 0:
			u.act = null; u.facing = home_facing(u)
		return
	if a.stage == "back":
		if move_to(u, u.hx, u.hy, 760, dt):
			u.act = null; u.facing = home_facing(u); set_anim(u, "idle")

func move_to(u, gx: float, gy: float, sp: float, dt: float) -> bool:
	var dx: float = gx - u.x
	var dy: float = gy - u.y
	var d := sqrt(dx * dx + dy * dy)
	var st := sp * (0.88 + float(u.speed) / 140.0) * dt / 1000.0
	if d <= st + 0.5:
		u.x = gx; u.y = gy; return true
	u.x += dx / d * st; u.y += dy / d * st
	if absf(dx) > 1: u.facing = 1 if dx > 0 else -1
	set_anim(u, "run")
	return false

const SYNC_WINDOW := 90.0 # ms — only count as a combo if strikes land in this same moment

func contact_eta(t) -> float:
	var best := 1e9
	if t == null or t.dead:
		return best
	for u in G.units:
		if u.dead or u.act == null: continue
		var a = u.act
		if a.target != t: continue
		if a.stage == "atk" and not a.hit_done and u.K.ranged == "" and a.d:
			var eta: float = a.d.hit * 1000.0 / maxf(1.0, a.d.fps) - a.t
			best = minf(best, maxf(0.0, eta))
	for p in projectiles:
		if p.target != t: continue
		if p.kind == "dyn":
			best = minf(best, maxf(0.0, p.dur - p.t))
			continue
		if p.kind == "arrow" or p.kind == "bolt":
			var dx: float = t.x - p.x
			var dy: float = (t.y - 30) - p.y
			var d := sqrt(dx * dx + dy * dy)
			var eta: float = p.delay + d / maxf(1.0, p.speed) * 1000.0
			best = minf(best, maxf(0.0, eta))
	return best

func flush_sync(dt: float) -> void:
	if sync_pending.is_empty():
		return
	for h in sync_pending:
		h.age += dt
	var by_t := {}
	for h in sync_pending:
		if h.t == null: continue
		var id: String = h.t.id
		if not by_t.has(id): by_t[id] = []
		by_t[id].append(h)
	var keep := []
	for id in by_t:
		var group: Array = by_t[id]
		var t = group[0].t
		var first_age := 0.0
		for h in group:
			if h.age > first_age: first_age = h.age
		var remain: float = SYNC_WINDOW - first_age
		var eta: float = contact_eta(t) if (t != null and not t.dead) else 1e9
		if remain > 0.0 and eta <= remain:
			keep.append_array(group)
			continue
		resolve_sync_group(group)
	sync_pending = keep

func resolve_sync_group(group: Array) -> void:
	var t = group[0].t
	if t == null or t.dead:
		return
	var units := []
	for h in group:
		if h.u != null and not h.u.dead and units.find(h.u) < 0:
			units.append(h.u)
	if units.size() >= 2:
		var sum := 0
		for u in units:
			sum += u.atk
		var dmg := mitigate_raw(sum * 3.0 * surge_mult(), t)
		deal_damage(group[group.size() - 1].u, t, dmg, {"combo": true, "members": units, "n": units.size()})
	else:
		for h in group:
			if t.dead: return
			apply_hit(h.u, t, h.mult, h.special, false, h.color, bool(h.get("ab", false)))

func resolve_hit(u, a) -> void:
	if a.ability != "":
		resolve_ability(u, a)
		return
	var t = a.target
	var K: Dictionary = u.K
	var sp: bool = a.special
	if K.ranged == "arrow" or K.ranged == "bolt":
		sfx.shoot()
		if K.ranged == "bolt": sfx.tone(180, 0.2, "sawtooth", 0.035, 2.0)
		var n := 3 if sp else 1
		for i in n:
			var p := Proj.new()
			p.kind = K.ranged; p.owner = u; p.act = a; p.last = i == n - 1; p.target = t
			if K.ranged == "bolt":
				p.x = u.x + u.facing * 34; p.y = u.y - 120 + (i - 1) * 10
			else:
				p.x = u.x + u.facing * 20; p.y = u.y - 34 + (i - 1) * 7
			p.special = sp; p.pierce = sp and i == 0; p.mult = 2.5 / 3.0 if sp else 1.0
			p.speed = (700 if K.ranged == "bolt" else 900) + i * 60; p.delay = i * 70
			projectiles.append(p)
		return
	if K.ranged == "dynamite":
		var p := Proj.new()
		p.kind = "dyn"; p.owner = u; p.act = a; p.last = true; p.target = t
		p.sx = u.x + u.facing * 18; p.sy = u.y - 40; p.x = u.x; p.y = u.y; p.dur = 480; p.tx = t.x; p.ty = t.y; p.special = sp
		projectiles.append(p)
		sfx.tone(500, 0.06, "triangle", 0.02, 1.6)
		return
	if t == null or t.dead:
		add_text(u.x + u.facing * 30, u.y - 50, "miss", "#dddddd", 12, 500); return
	var final: bool = not (is_warrior_kit(u.kind) and a.swing == 0)
	var base := 0.6 if is_warrior_kit(u.kind) else (0.8 if u.kind == "torch" else 1.0)
	hit(u, t, base * (2.5 if sp else 1.0), sp and final)
	if u.kind == "pawn": t.kx = u.facing * 16
	if u.kind == "torch" and not t.dead: t.burn = {"t": 380.0, "owner": u, "mult": 0.3 * (2 if sp else 1)}
	if u.kind == "barrel" and not sp:
		explode(t.x, t.y, 0.55); splash(u, t.x, t.y, 70, 0.12, t)
	if sp and final:
		if is_warrior_kit(u.kind):
			splash(u, t.x, t.y, 85, 0.4, t); fx.append({"type": "slash", "x": t.x, "y": t.y - 30, "t": 0.0, "life": 260.0, "dir": u.facing}); shake(6, 200)
		if u.kind == "pawn":
			add_text(t.x, t.y - t.K.head * uS(t) - 30, "SHOCK", "#fff27a", 13, 700); splash(u, t.x, t.y, 70, 0.3, t); shake(5, 160)
		if u.kind == "torch":
			fx.append({"type": "sprite", "img": "fire", "fw": 128.0, "fh": 128.0, "n": 7, "fps": 14.0, "x": t.x, "y": t.y + 8, "ax": 64.0, "ay": 105.0, "s": 0.8, "t": 0.0, "loops": 2}); splash(u, t.x, t.y, 70, 0.35, t); shake(5, 160)
		if u.kind == "barrel":
			explode(t.x, t.y, 1.1); splash(u, t.x, t.y, 90, 0.4, t)

func explode(x: float, y: float, s: float = 1.0) -> void:
	fx.append({"type": "sprite", "img": "explosion", "fw": 192.0, "fh": 192.0, "n": 9, "fps": 20.0, "x": x, "y": y + 10, "ax": 96.0, "ay": 120.0, "s": 0.75 * s, "t": 0.0, "loops": 1})
	sfx.boom(); shake(4 + 5 * s, 240)

func splash(u, x: float, y: float, r: float, mult: float, except) -> void:
	for e in G.units:
		if e.dead or e.team == u.team or e == except: continue
		var dx: float = e.x - x
		var dy: float = (e.y - y) * 1.4
		if dx * dx + dy * dy <= r * r: hit(u, e, 2.5 * mult, true, true)

func hit(u, t, mult: float, special: bool, is_splash: bool = false, color: String = "") -> void:
	if t == null or t.dead: return
	if is_splash:
		apply_hit(u, t, mult, special, true, color)
		return
	sync_pending.append({"u": u, "t": t, "mult": mult, "special": special, "color": color, "age": 0.0})

func mitigate_raw(raw: float, t) -> int:
	var cut: float = raw * def_mit(t.def) - float(t.armor)
	return maxi(1, int(roundf(cut)))

func apply_hit(u, t, mult: float, special: bool, is_splash: bool = false, color: String = "", ab: bool = false) -> void:
	if t == null or t.dead: return
	var crit_p: float = clampf(float(u.crit) / 100.0, 0.0, 0.6)
	var crit := not special and not is_splash and randf() < crit_p
	# Melee damage is fixed (crits and combos are the only swings); ranged keeps a small roll.
	var roll: float = rand(0.85, 1.15) if str(u.K.ranged) != "" else 1.0
	var raw: float = u.atk * roll * mult * (1.5 if crit else 1.0) * surge_mult()
	deal_damage(u, t, mitigate_raw(raw, t), {"special": special, "isSplash": is_splash, "crit": crit, "color": color, "ab": ab})

func deal_damage(u, t, dmg: int, opt: Dictionary) -> void:
	if t.dead: return
	var combo: bool = opt.get("combo", false)
	t.hp = maxi(0, t.hp - dmg)
	if combo:
		var members: Array = opt.members
		var sum := 0
		for m in members: sum += m.atk
		var credited := 0
		for m in members:
			var c := int(roundf(dmg * (float(m.atk) / sum)))
			m.dmg += c; credited += c
		u.dmg += dmg - credited
	else:
		u.dmg += dmg
	t.gauge = minf(100, t.gauge + (16 if combo else 9))
	t.flash = 180.0 if combo else 110.0
	t.shake = 240.0 if combo else 160.0
	t.kx = (1.0 if t.x >= u.x else -1.0) * (14 if combo else (9 if opt.get("special", false) else 5))
	var big: bool = combo or bool(opt.get("ab", false)) or (opt.get("special", false) and not opt.get("isSplash", false))
	var crit: bool = opt.get("crit", false)
	var label := ("COMBO x%d  %d" % [opt.n, dmg]) if combo else str(dmg)
	var col: String = opt.get("color", "")
	if col == "": col = "#ffd23f" if (combo or big) else ("#ff8a3d" if crit else "#ffffff")
	add_text(t.x + rand(-10, 10), t.y - t.K.head * uS(t) - 6, label, col, 28 if combo else (26 if big else (21 if crit else 17)), 1100 if combo else 760, big or crit)
	fx.append({"type": "spark", "x": t.x - t.kx * 2, "y": t.y - 32, "t": 0.0, "life": 280.0 if big else 170.0, "big": big or crit, "rot": randf() * 6})
	if combo:
		fx.append({"type": "ring", "x": t.x, "y": t.y - 20, "t": 0.0, "life": 420.0, "color": Color("#ffd23f")})
		add_text(t.x, t.y - t.K.head * uS(t) - 36, "x3", "#fff27a", 18, 800, true)
		hitstop = maxf(hitstop, 90)
		sfx.special()
	elif big:
		hitstop = maxf(hitstop, 60)
	sfx.hit()
	if t.hp <= 0:
		t.dead = true; t.death_t = 0.0; t.act = null; t.burn = null; u.kos += 1
		add_text(t.x, t.y - t.K.head * uS(t) - 28, "KO!", "#ff5a5a", 20, 800, true)
		sfx.ko(); shake(7 if combo else 4, 200 if combo else 140)
		var qi := G.queue.find(t)
		if qi >= 0 and qi >= G.qi: G.queue.remove_at(qi)

func shake(m: float, d: float) -> void:
	if m >= shake_mag or shake_t <= 0:
		shake_mag = m; shake_t = d

func add_text(x: float, y: float, s: String, color: String, size: float, life: float = 700, pop: bool = false) -> void:
	texts.append({"x": x, "y": y, "s": s, "color": Color(color), "size": size, "t": 0.0, "life": life, "pop": pop})

func landed(p) -> void:
	if p.last and p.act != null: p.act.ready = true

func update_projectiles(dt: float) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var p = projectiles[i]
		var t = p.target
		if p.kind == "arrow" or p.kind == "bolt":
			if p.delay > 0:
				p.delay -= dt; continue
			var tx: float = t.x
			var ty: float = t.y - 30
			var dx: float = tx - p.x
			var dy: float = ty - p.y
			var d := sqrt(dx * dx + dy * dy)
			var st: float = p.speed * dt / 1000.0
			p.ang = atan2(dy, dx)
			if d <= st + 6 or t.dead:
				if p.ability != "":
					ability_impact(p.owner, p.ability, t)
				elif not t.dead:
					hit(p.owner, t, p.mult, p.special)
				if p.pierce:
					splash(p.owner, tx, ty + 30, 75, 0.4, t)
					fx.append({"type": "ring", "x": tx, "y": ty + 26, "t": 0.0, "life": 300.0, "color": Color("#ff5a7a") if p.kind == "bolt" else Color("#9fe3ff")})
				if p.kind == "arrow" and (not t.dead or d < 60): fx.append({"type": "stuck", "x": tx, "y": ty, "ang": p.ang, "t": 0.0, "life": 260.0})
				if p.kind == "bolt": fx.append({"type": "ring", "x": tx, "y": ty + 10, "t": 0.0, "life": 240.0, "color": Color("#c23050")})
				landed(p); projectiles.remove_at(i); continue
			p.x += dx / d * st; p.y += dy / d * st
		else:
			p.t += dt
			if not t.dead:
				p.tx += (t.x - p.tx) * minf(1.0, dt / 120.0); p.ty += (t.y - p.ty) * minf(1.0, dt / 120.0)
			var k := minf(1.0, p.t / p.dur)
			p.x = p.sx + (p.tx - p.sx) * k
			p.y = p.sy + (p.ty - 10 - p.sy) * k - sin(k * PI) * 110
			p.rot += dt * 0.02
			if k >= 1:
				explode(p.tx, p.ty, 1.25 if p.special else 0.7)
				if not t.dead:
					hit(p.owner, t, 2.5 if p.special else 1.0, p.special)
				if p.special: splash(p.owner, p.tx, p.ty, 95, 0.4, t)
				landed(p); projectiles.remove_at(i)

# ---------------------------------------------------------------- turn controller
func busy() -> bool:
	if projectiles.size() > 0: return true
	if sync_pending.size() > 0: return true
	for u in G.units:
		if u.act != null: return true
	return false

func apply_mana_regen(team: String) -> void:
	for u in alive(team):
		if u.mana_regen <= 0: continue
		u.gauge = minf(100.0, u.gauge + u.mana_regen)

func begin_player_turn() -> void:
	G.side = "blue"; G.mode = "select"; G.queue = []; G.qi = 0; G.turn += 1; G.ab_focus = null
	for bu in G.units: bu.ab_queued = ""
	tick_mods("blue")
	apply_mana_regen("blue")
	banner = {"text": "YOUR TURN", "sub": "Tap knights to set the attack order" if G.turn == 1 else "Turn %d" % G.turn, "t": 0.0, "life": 1000.0, "color": "blue"}
	if G.turn == 4: banner.sub = "RIFT SURGE — damage rising!"
	sfx.tone(523, 0.08, "square", 0.04)

const LAUNCH_STAGGER := 200.0
const LAUNCH_FIRST := 80.0

func execute_orders() -> void:
	if G == null or G.mode != "select" or G.queue.is_empty() or phase != "battle": return
	G.mode = "resolve"; G.side = "blue"; G.qi = 0; G.gap = LAUNCH_FIRST; G.cur = null
	plan_actions(G.queue)
	sfx.fight()

func begin_enemy_turn() -> void:
	G.side = "red"; G.mode = "enemyIntro"; G.gap = 520; G.qi = 0; G.cur = null
	G.queue = shuffled(alive("red"))
	tick_mods("red")
	apply_mana_regen("red")
	plan_actions(G.queue)
	banner = {"text": "ENEMY TURN", "sub": "", "t": 0.0, "life": 850.0, "color": "red"}
	sfx.tone(220, 0.15, "sawtooth", 0.04, 0.8)

func attack_resolved(u) -> bool:
	if u == null or u.dead or u.act == null: return true
	var a = u.act
	if a.stage == "go" or a.stage == "atk": return false
	for p in projectiles:
		if p.owner == u: return false
	if a.stage == "wait" and not a.ready: return false
	return a.ready_t >= 180

func controller(dt: float) -> void:
	if G.mode == "select": return
	if G.mode == "enemyIntro":
		G.gap -= dt
		if G.gap <= 0:
			G.mode = "resolve"; G.gap = 0
		return
	if G.mode == "resolve":
		G.gap -= dt
		if G.gap > 0: return
		if alive("red" if G.side == "blue" else "blue").is_empty():
			G.mode = "finish"; return
		while G.qi < G.queue.size() and G.queue[G.qi].dead: G.qi += 1
		if G.qi < G.queue.size():
			var u = G.queue[G.qi]
			G.qi += 1
			G.cur = u
			start_action(u)
			G.gap = LAUNCH_STAGGER
			return
		if busy(): return
		G.mode = "finish"
	if G.mode == "finish":
		if busy(): return
		G.queue = []; G.cur = null
		if alive("red").is_empty() or alive("blue").is_empty(): return
		if G.side == "blue": begin_enemy_turn()
		else: begin_player_turn()

func toggle_queue(u) -> void:
	if G == null or G.mode != "select" or u.dead or u.team != "blue" or phase != "battle": return
	var i := G.queue.find(u)
	if i >= 0:
		G.queue.remove_at(i); u.ab_queued = ""
		if G.ab_focus == u: G.ab_focus = G.queue[G.queue.size() - 1] if G.queue.size() > 0 else null
	else:
		G.queue.append(u); G.ab_focus = u
	u.pop = 160.0
	sfx.tone(440 if i >= 0 else 660 + G.queue.size() * 40, 0.05, "square", 0.03)

## AUTO: queue every living hero; a full MP bar fires that hero's marked auto ability, otherwise a normal attack.
func auto_queue_turn() -> void:
	G.queue = []
	for u in alive("blue"):
		G.queue.append(u)
		u.ab_queued = ""
		if u.gauge >= AB_MP:
			var aid: String = auto_ab(u.name) if CHAR.has(u.name) else ""
			if aid != "" and ABILITY_DEFS.has(aid) and (aid == u.ab_class or aid == u.ab_sub):
				u.ab_queued = aid
	execute_orders()

func toggle_auto() -> void:
	AUTO = not AUTO
	save_cfg()
	sfx.tone(784 if AUTO else 523, 0.06, "square", 0.03)

## Keep each hero's MP bar for the next fight (win, lose, or Run).
func stash_party_mp() -> void:
	if G == null:
		return
	for u in G.units:
		if u.team == "blue" and CHAR.has(u.name):
			HERO_MP[u.name] = clampf(float(u.gauge), 0.0, AB_MP)

func queue_all() -> void:
	if G == null or G.mode != "select" or phase != "battle": return
	for u in alive("blue"):
		if G.queue.find(u) < 0: G.queue.append(u)
	sfx.tone(880, 0.06, "square", 0.03)

func clear_queue() -> void:
	if G == null or G.mode != "select" or phase != "battle": return
	G.queue = []; G.ab_focus = null
	for u in G.units: u.ab_queued = ""
	sfx.tone(330, 0.05, "square", 0.03)

func step(dt: float) -> void:
	now += dt
	if phase == "battle" or phase == "ending":
		if hitstop > 0:
			hitstop -= dt; dt *= 0.15
		G.t += dt
		if phase == "battle" and AUTO and G.mode == "select" and not paused:
			auto_queue_turn()
		var order := shuffled(G.units)
		for u in order: update_unit(u, dt)
		update_projectiles(dt)
		flush_sync(dt)
		if phase == "battle":
			controller(dt)
			var b := alive("blue").size()
			var r := alive("red").size()
			if (b == 0 or r == 0) and not busy():
				phase = "ending"; G.end_t = 0; G.result = "win" if b > 0 else ("lose" if r > 0 else "draw"); G.mode = "over"
				banner = {"text": "VICTORY!" if G.result == "win" else ("DEFEAT" if G.result == "lose" else "DOUBLE KO"), "sub": "", "t": 0.0, "life": 1400.0,
					"color": "blue" if G.result == "win" else ("red" if G.result == "lose" else "yellow")}
				if G.result == "win": sfx.win()
				else: sfx.lose()
		else:
			G.end_t += dt
			if G.end_t > 1450: show_results()
	elif G != null:
		for u in G.units:
			u.at += dt; u.shown_hp = u.hp
	if G != null:
		for u in G.units:
			if u.pop > 0: u.pop -= dt
	for f in range(fx.size() - 1, -1, -1):
		var e: Dictionary = fx[f]
		e.t += dt
		var life: float = e.life if e.has("life") else (e.n / e.fps * 1000.0 * e.get("loops", 1))
		if e.t >= life: fx.remove_at(f)
	for q in range(texts.size() - 1, -1, -1):
		texts[q].t += dt
		if texts[q].t >= texts[q].life: texts.remove_at(q)
	if shake_t > 0: shake_t -= dt
	if banner != null:
		banner.t += dt
		if banner.t > banner.life: banner = null
	if cast_banner != null:
		cast_banner.t += dt
		if cast_banner.t > cast_banner.life: cast_banner = null
	if screen_flash != null:
		screen_flash.t += dt
		if screen_flash.t > screen_flash.life: screen_flash = null

# ---------------------------------------------------------------- ability combat
var cast_banner = null # {"text", "sub", "t", "life", "color"}
var screen_flash = null # {"color", "t", "life"}

func stat_floor(stat: String) -> int:
	if stat == "armor" or stat == "crit":
		return 0
	return 1

## Adds a timed stat change. The same stat + direction from a newer cast replaces the
## older one instead of stacking. turns counts the unit's own side turns.
func add_mod(u, stat: String, amt: int, turns: int) -> void:
	if u == null or u.dead or amt == 0:
		return
	for i in range(u.buffs.size() - 1, -1, -1):
		var b: Dictionary = u.buffs[i]
		if str(b.stat) == stat and (int(b.req) > 0) == (amt > 0):
			u.set(stat, int(u.get(stat)) - int(b.d))
			u.buffs.remove_at(i)
	var cur: int = int(u.get(stat))
	var nv: int = maxi(stat_floor(stat), cur + amt)
	var d: int = nv - cur
	u.set(stat, nv)
	u.buffs.append({"stat": stat, "d": d, "req": amt, "turns": turns})

func tick_mods(team: String) -> void:
	for u in G.units:
		if u.team != team:
			continue
		for i in range(u.buffs.size() - 1, -1, -1):
			var b: Dictionary = u.buffs[i]
			b.turns = int(b.turns) - 1
			if int(b.turns) <= 0:
				u.set(str(b.stat), int(u.get(str(b.stat))) - int(b.d))
				u.buffs.remove_at(i)

func apply_mod_list(u, mods: Array, turns: int, show: bool) -> void:
	for m in mods:
		add_mod(u, str(m[0]), int(m[1]), maxi(1, turns))
	if show and not mods.is_empty() and u != null and not u.dead:
		var good: bool = int(mods[0][1]) > 0
		add_text(u.x, u.y - u.K.head * uS(u) - 50, mods_text(mods), "#7fd8ff" if good else "#ff9a4a", 13, 1100, true)
		fx.append({"type": "aura", "unit": u, "t": 0.0, "life": 900.0, "color": Color("#7fd8ff") if good else Color("#ff8a4a")})

func lowest_ally(u):
	var best = null
	var br := 9.0
	for a in alive(u.team):
		var r: float = float(a.hp) / maxf(1.0, float(a.maxhp))
		if r < br:
			br = r; best = a
	return best

func heal_unit(t, pct: float) -> void:
	if t == null or t.dead:
		return
	var amt: int = maxi(1, int(roundf(float(t.maxhp) * pct)))
	var before: int = t.hp
	t.hp = mini(t.maxhp, t.hp + amt)
	var got: int = t.hp - before
	add_text(t.x + rand(-6, 6), t.y - t.K.head * uS(t) - 6, "+" + str(got), "#5dff8a", 24, 1000, true)
	fx.append({"type": "pulse", "x": t.x, "y": t.y - 4, "t": 0.0, "life": 650.0, "r": 46.0, "color": Color("#5dff8a")})
	fx.append({"type": "aura", "unit": t, "t": 0.0, "life": 800.0, "color": Color("#5dff8a")})

func queue_ability(u, id: String) -> void:
	if G == null or G.mode != "select" or phase != "battle" or u == null or u.dead:
		return
	if u.ab_queued == id:
		u.ab_queued = ""
		sfx.tone(392, 0.05, "square", 0.03)
		return
	if u.gauge < AB_MP or not ABILITY_DEFS.has(id):
		sfx.tone(196, 0.05, "square", 0.02)
		return
	u.ab_queued = id
	if G.queue.find(u) < 0:
		G.queue.append(u)
	u.pop = 160.0
	sfx.tone(988, 0.07, "triangle", 0.035)

## Replaces the unit's normal attack for this turn. Spends the full MP bar.
func start_ability(u, id: String) -> bool:
	var ab: Dictionary = ABILITY_DEFS[id]
	var kind: String = str(ab.kind)
	var p: Dictionary = ab.params
	u.gauge = 0.0
	u.ab_queued = ""
	var col: Color = ab_color(id)
	var t = null
	if kind == "damage_single" or kind == "damage_all_enemies":
		var foes := alive(enemy_of(u))
		if foes.is_empty():
			return false
		t = u.plan.target if (u.plan != null and u.plan.target != null and not u.plan.target.dead) else pick(foes)
		if u.plan != null: u.plan.target = t
	elif kind == "heal_single":
		t = u if bool(p.get("self", false)) else lowest_ally(u)
	else:
		t = u
	if t == null:
		t = u
	var a := Act.new()
	a.target = t
	a.special = false
	a.ability = id
	u.act = a
	var melee_go: bool = kind == "damage_single" and str(u.K.ranged) == ""
	if melee_go:
		a.stage = "go"
	else:
		begin_swing(u)
		if t == u:
			u.facing = home_facing(u)
	# Loud, readable tell: name popup, caster burst, screen flash, top banner.
	add_text(u.x, u.y - u.K.head * uS(u) - 34, str(ab.name), "#" + col.to_html(false), 22, 1300, true)
	fx.append({"type": "ring", "x": u.x, "y": u.y - 10, "t": 0.0, "life": 520.0, "color": col})
	fx.append({"type": "pulse", "x": u.x, "y": u.y - 4, "t": 0.0, "life": 520.0, "r": 40.0, "color": col})
	fx.append({"type": "aura", "unit": u, "t": 0.0, "life": 900.0, "color": col})
	screen_flash = {"color": col, "t": 0.0, "life": 260.0}
	cast_banner = {"text": str(ab.name), "sub": u.name + " · " + ab_effect_line(id), "t": 0.0, "life": 1500.0, "color": col}
	hitstop = maxf(hitstop, 70)
	sfx.special()
	return true

## Fires at the ability's hit frame.
func resolve_ability(u, a) -> void:
	var id: String = a.ability
	var ab: Dictionary = ABILITY_DEFS[id]
	var kind: String = str(ab.kind)
	if kind == "damage_single" and (u.K.ranged == "arrow" or u.K.ranged == "bolt"):
		var t = a.target
		if t == null or t.dead:
			var foes := alive(enemy_of(u))
			if foes.is_empty():
				a.ready = true
				return
			t = pick(foes); a.target = t
		sfx.shoot()
		var pr := Proj.new()
		pr.kind = u.K.ranged; pr.owner = u; pr.act = a; pr.last = true; pr.target = t
		pr.x = u.x + u.facing * 20; pr.y = u.y - 34
		pr.special = true; pr.pierce = false; pr.mult = 1.0; pr.speed = 1100; pr.delay = 0
		pr.ability = id
		projectiles.append(pr)
		return
	ability_impact(u, id, a.target)
	a.ready = true

func ability_impact(u, id: String, t) -> void:
	var ab: Dictionary = ABILITY_DEFS[id]
	var kind: String = str(ab.kind)
	var p: Dictionary = ab.params
	var col: Color = ab_color(id)
	var mult: float = float(p.get("mult", 1.0))
	if kind == "damage_single":
		if t == null or t.dead or t.team == u.team:
			var foes := alive(enemy_of(u))
			if foes.is_empty(): return
			t = pick(foes)
		explode(t.x, t.y, 0.9)
		fx.append({"type": "pulse", "x": t.x, "y": t.y - 4, "t": 0.0, "life": 520.0, "r": 60.0, "color": col})
		fx.append({"type": "slash", "x": t.x, "y": t.y - 30, "t": 0.0, "life": 320.0, "dir": u.facing})
		shake(7, 220)
		sync_pending.append({"u": u, "t": t, "mult": mult, "special": false, "color": "", "age": 0.0, "ab": true})
		if p.has("debuff"):
			apply_mod_list(t, p.debuff, int(p.get("dturns", 2)), true)
	elif kind == "damage_all_enemies":
		var foes2 := alive(enemy_of(u))
		var cx := 0.0
		var cy := 0.0
		for e in foes2:
			cx += e.x; cy += e.y
		if foes2.size() > 0:
			cx /= foes2.size(); cy /= foes2.size()
			fx.append({"type": "pulse", "x": cx, "y": cy, "t": 0.0, "life": 700.0, "r": 150.0, "color": col})
		shake(9, 280)
		for e in foes2:
			explode(e.x, e.y, 0.75)
			apply_hit(u, e, mult, true, false, "#e2b8ff", true)
		if p.has("debuff"):
			for e2 in alive(enemy_of(u)):
				apply_mod_list(e2, p.debuff, int(p.get("dturns", 2)), true)
	elif kind == "heal_single":
		if t == null or t.dead or t.team != u.team:
			t = lowest_ally(u)
		heal_unit(t, float(p.get("pct", 0.3)))
		sfx.tone(784, 0.12, "triangle", 0.04, 1.5)
	elif kind == "heal_party":
		var al := alive(u.team)
		var cx2 := 0.0
		var cy2 := 0.0
		for m in al:
			cx2 += m.x; cy2 += m.y
		if al.size() > 0:
			cx2 /= al.size(); cy2 /= al.size()
			fx.append({"type": "pulse", "x": cx2, "y": cy2, "t": 0.0, "life": 900.0, "r": 190.0, "color": Color("#5dff8a")})
		for m2 in al:
			heal_unit(m2, float(p.get("pct", 0.2)))
		sfx.tone(659, 0.18, "triangle", 0.045, 1.5)
	elif kind == "buff_self":
		apply_mod_list(u, p.get("buffs", []), int(p.get("turns", 2)), true)
		sfx.tone(880, 0.1, "triangle", 0.035, 1.3)
	elif kind == "buff_party":
		var al2 := alive(u.team)
		var cx3 := 0.0
		var cy3 := 0.0
		for m3 in al2:
			cx3 += m3.x; cy3 += m3.y
		if al2.size() > 0:
			fx.append({"type": "pulse", "x": cx3 / al2.size(), "y": cy3 / al2.size(), "t": 0.0, "life": 800.0, "r": 180.0, "color": Color("#7fd8ff")})
		for m4 in al2:
			apply_mod_list(m4, p.get("buffs", []), int(p.get("turns", 2)), true)
		sfx.tone(880, 0.12, "triangle", 0.04, 1.3)
	if p.has("self_buff"):
		apply_mod_list(u, p.self_buff, int(p.get("sturns", 2)), true)
	if p.has("party_buff"):
		for m5 in alive(u.team):
			apply_mod_list(m5, p.party_buff, int(p.get("pturns", 2)), true)

# ---------------------------------------------------------------- terrain
var props := []
var DECO := [["13", 150, 120], ["10", 330, 110], ["01", 420, 140], ["02", 600, 120], ["11", 690, 112], ["04", 860, 120],
	["08", 90, 300], ["14", 330, 470], ["03", 470, 480], ["05", 590, 470], ["12", 700, 482], ["07", 930, 300], ["10", 900, 440],
	["13", 120, 450], ["01", 560, 320], ["14", 470, 215], ["02", 300, 330], ["10", 720, 330], ["09", 845, 495], ["07", 175, 500]]
var ROCKS := [["rocks1", 30, 120], ["rocks3", 990, 200], ["rocks1", 990, 470], ["rocks3", 40, 360], ["rocks1", 470, 30], ["rocks3", 700, 556], ["rocks1", 300, 556]]

func build_terrain() -> void:
	props = [
		{"img": "tree", "fw": 192.0, "fh": 192.0, "n": 4, "ax": 96.0, "ay": 178.0, "x": 90, "y": 112, "s": 0.7, "ph": 0},
		{"img": "tree", "fw": 192.0, "fh": 192.0, "n": 4, "ax": 96.0, "ay": 178.0, "x": 250, "y": 92, "s": 0.62, "ph": 2},
		{"img": "tree", "fw": 192.0, "fh": 192.0, "n": 4, "ax": 96.0, "ay": 178.0, "x": 520, "y": 86, "s": 0.58, "ph": 1},
		{"img": "tree", "fw": 192.0, "fh": 192.0, "n": 4, "ax": 96.0, "ay": 178.0, "x": 790, "y": 92, "s": 0.62, "ph": 3},
		{"img": "tree", "fw": 192.0, "fh": 192.0, "n": 4, "ax": 96.0, "ay": 178.0, "x": 950, "y": 520, "s": 0.66, "ph": 1},
		{"img": "tree", "fw": 192.0, "fh": 192.0, "n": 4, "ax": 96.0, "ay": 178.0, "x": 76, "y": 525, "s": 0.66, "ph": 2},
		{"img": "tower", "fw": 128.0, "fh": 256.0, "n": 1, "ax": 64.0, "ay": 235.0, "x": 168, "y": 128, "s": 0.55, "ph": 0},
		{"img": "ghouse", "fw": 128.0, "fh": 192.0, "n": 1, "ax": 64.0, "ay": 171.0, "x": 880, "y": 128, "s": 0.62, "ph": 0},
		{"img": "sheep", "fw": 128.0, "fh": 128.0, "n": 8, "ax": 64.0, "ay": 86.0, "x": 400, "y": 104, "s": 0.6, "ph": 0, "fps": 8.0},
		{"img": "sheep", "fw": 128.0, "fh": 128.0, "n": 8, "ax": 64.0, "ay": 86.0, "x": 650, "y": 108, "s": 0.6, "ph": 3, "fps": 8.0, "flip": true},
	]
	for p in props:
		var q := mp(p.x, p.y)
		p.x = q.x; p.y = q.y

func draw_terrain() -> void:
	var ff := int(floorf(now / 110.0)) % 8
	for r in range(ISL.r0, ISL.r1 + 1):
		for c in range(ISL.c0, ISL.c1 + 1):
			if r == ISL.r0 or r == ISL.r1 or c == ISL.c0 or c == ISL.c1:
				img(IMG.foam, ((ff + c + r) % 8) * 192, 0, 192, 192, c * 64 - 64, r * 64 - 64, 192, 192)
	for i in ROCKS.size():
		var k: Array = ROCKS[i]
		var f := (int(floorf(now / 140.0)) + i * 3) % 8
		var q := mp(k[1], k[2])
		img(IMG[k[0]], f * 128, 0, 128, 128, q.x - 64, q.y - 72, 128, 128)
	for r in range(ISL.r0, ISL.r1 + 1):
		for c in range(ISL.c0, ISL.c1 + 1):
			var sx := 0 if c == ISL.c0 else (2 if c == ISL.c1 else 1)
			var sy := 0 if r == ISL.r0 else (2 if r == ISL.r1 else 1)
			img(IMG.flat, sx * 64, sy * 64, 64, 64, c * 64, r * 64, 64, 64)
	for d in DECO:
		var im: Texture2D = IMG["deco" + d[0]]
		var q := mp(d[1], d[2])
		img(im, 0, 0, 64, 64, roundf(q.x - 32), roundf(q.y - 64 + 10), 64, 64)

# ---------------------------------------------------------------- canvas-like drawing helpers
var _xf := Transform2D.IDENTITY
var _stack := []
var _alpha := 1.0

func save() -> void: _stack.push_back([_xf, _alpha])
func restore() -> void:
	var s: Array = _stack.pop_back()
	_xf = s[0]; _alpha = s[1]
	draw_set_transform_matrix(_xf)
func set_xf(t: Transform2D) -> void:
	_xf = t; draw_set_transform_matrix(_xf)
func tr_(x: float, y: float) -> void: set_xf(_xf * Transform2D(0.0, Vector2(x, y)))
func scale_by(sx: float, sy: float) -> void: set_xf(_xf * Transform2D(Vector2(sx, 0), Vector2(0, sy), Vector2.ZERO))
func rotate_by(a: float) -> void: set_xf(_xf * Transform2D(a, Vector2.ZERO))
func ca(c: Color) -> Color: return Color(c.r, c.g, c.b, c.a * _alpha)

func img(tex: Texture2D, sx: float, sy: float, sw: float, sh: float, dx: float, dy: float, dw: float, dh: float, mod := Color.WHITE) -> void:
	draw_texture_rect_region(tex, Rect2(dx, dy, dw, dh), Rect2(sx, sy, sw, sh), ca(mod))

func draw_frame(tex: Texture2D, fw: float, fh: float, col: int, row: int, x: float, y: float, ax: float, ay: float, s: float, flip: bool, alpha := 1.0, mod := Color.WHITE) -> void:
	save(); tr_(roundf(x), roundf(y))
	if flip: scale_by(-1, 1)
	_alpha *= alpha
	img(tex, col * fw, row * fh, fw, fh, -ax * s, -ay * s, fw * s, fh * s, mod)
	restore()

func ellipse_pts(cx: float, cy: float, rx: float, ry: float, seg := 32) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in seg + 1:
		var a := TAU * i / seg
		pts.append(Vector2(cx + cos(a) * rx, cy + sin(a) * ry))
	return pts
func fill_ellipse(cx: float, cy: float, rx: float, ry: float, col: Color) -> void:
	var pts := ellipse_pts(cx, cy, rx, ry)
	pts.remove_at(pts.size() - 1)
	draw_colored_polygon(pts, ca(col))
func stroke_ellipse(cx: float, cy: float, rx: float, ry: float, col: Color, w: float) -> void:
	draw_polyline(ellipse_pts(cx, cy, rx, ry), ca(col), w, true)

func text_w(s: String, size: float) -> float:
	return FONT.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, int(roundf(size))).x
## Text with canvas semantics: textBaseline=middle, align left/center/right, optional stroke (lineWidth = lw).
func text(s: String, x: float, y: float, size: float, col: Color, align := "center", lw := 0.0, stroke := Color("#1a0f08")) -> void:
	var fs := int(roundf(size))
	if fs < 1: return
	var w := text_w(s, fs)
	var ox := x - w / 2.0 if align == "center" else (x - w if align == "right" else x)
	var by := y + (FONT.get_ascent(fs) - FONT.get_descent(fs)) / 2.0
	if lw > 0: draw_string_outline(FONT, Vector2(ox, by), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(roundf(lw)), ca(stroke))
	draw_string(FONT, Vector2(ox, by), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ca(col))
func outlined(s: String, x: float, y: float, size: float, col: Color, align := "center") -> void:
	text(s, x, y, size, col, align, maxf(3.0, size / 5.0))
func shadow_text(s: String, x: float, y: float, size: float, col: Color, off := 2.0, sh := Color(0, 0, 0, 0.45), align := "center") -> void:
	text(s, x + off, y + off, size, sh, align)
	text(s, x, y, size, col, align)

## game.js draw3: caps scale with height.
func draw3(tex: Texture2D, x: float, y: float, w: float, h: float, mod := Color.WHITE) -> void:
	var e := 64.0 * h / 64.0
	img(tex, 0, 0, 64, 64, x, y, e, h, mod)
	img(tex, 64, 0, 64, 64, x + e, y, maxf(0, w - 2 * e), h, mod)
	img(tex, 128, 0, 64, 64, x + w - e, y, e, h, mod)
## CSS border-image 3-slice with a fixed cap width.
func css3(tex: Texture2D, x: float, y: float, w: float, h: float, cap: float, mod := Color.WHITE) -> void:
	cap = minf(cap, w / 2.0)
	img(tex, 0, 0, 64, 64, x, y, cap, h, mod)
	img(tex, 64, 0, 64, 64, x + cap, y, maxf(0, w - 2 * cap), h, mod)
	img(tex, 128, 0, 64, 64, x + w - cap, y, cap, h, mod)
func css9(tex: Texture2D, x: float, y: float, w: float, h: float, b: float) -> void:
	var xs := [x, x + b, x + w - b]
	var ws := [b, w - 2 * b, b]
	var ys := [y, y + b, y + h - b]
	var hs := [b, h - 2 * b, b]
	for r in 3:
		for c in 3:
			img(tex, c * 64, r * 64, 64, 64, xs[c], ys[r], ws[c], hs[r])

# ---------------------------------------------------------------- unit drawing
func unit_frame(u) -> Vector2i:
	var K: Dictionary = u.K
	if u.act != null and u.act.stage == "atk":
		var d: Dictionary = u.act.d
		return Vector2i(mini(d.n - 1, int(floorf(u.act.t * d.fps / 1000.0))), d.r)
	var a: Dictionary = K.get(u.anim, K.idle)
	return Vector2i(int(floorf(u.at * a.fps / 1000.0)) % a.n, a.r)

func draw_unit(u) -> void:
	var K: Dictionary = u.K
	var f: Dictionary = K.f
	var fsc: float = f.s
	if u.dead:
		if u.death_t < 140:
			var fr0 := unit_frame(u)
			draw_frame(WHITE[K.img], f.fw, f.fh, fr0.x, fr0.y, u.x, u.y, f.ax, f.ay, uS(u) * fsc * (1 + u.death_t / 900.0), u.facing < 0, 1 - u.death_t / 200.0)
		var dt: float = u.death_t - 60
		if dt < 0: return
		var al := maxf(0.0, 1 - (u.death_t - 1300) / 400.0) if u.death_t > 1300 else 1.0
		if K.has("death"):
			var dd: Dictionary = K.death
			var di := mini(dd.n - 1, int(floorf(dt / 95.0)))
			draw_frame(IMG[K.img], f.fw, f.fh, di, dd.r, u.x, u.y, f.ax, f.ay, uS(u) * fsc, u.facing < 0, al)
			return
		var idx := mini(13, int(floorf(dt / 85.0)))
		draw_frame(IMG.dead, 128, 128, idx % 7, 0 if idx < 7 else 1, u.x, u.y, 64, 96, uS(u) * 0.95, u.facing < 0, al)
		return
	var fr := unit_frame(u)
	var sx: float = (randf() - 0.5) * 5 * (u.shake / 160.0) if u.shake > 0 else 0.0
	var x: float = u.x + u.kx + sx
	var y: float = u.y
	var sq: float = 1 + 0.08 * (u.flash / 110.0) if u.flash > 0 else 1.0
	if u.gauge >= 100 and phase == "battle":
		var p := 0.5 + 0.5 * sin(now / 90.0)
		save(); _alpha = 0.35 + 0.25 * p
		fill_ellipse(x, y - 4, 26 + p * 4, 9 + p * 2, Color("#8fe6ff") if u.team == "blue" else Color("#ffb35a"))
		restore()
	if u.buffs.size() > 0 and phase == "battle":
		var good := false
		var bad := false
		for b in u.buffs:
			if int(b.req) > 0: good = true
			else: bad = true
		save(); _alpha = 0.45 + 0.2 * sin(now / 260.0)
		if good: stroke_ellipse(x, y - 3, 30, 10, Color("#7fd8ff"), 2.5)
		if bad: stroke_ellipse(x, y - 1, 34, 12, Color("#ff8a4a"), 2.5)
		restore()
	var qn := queued_num(u)
	if qn == 0 and G != null and G.mode == "select" and u.team == "blue" and phase == "battle":
		save(); _alpha = 0.25 + 0.15 * sin(now / 200.0)
		stroke_ellipse(x, y - 2, 24, 8, Color.WHITE, 2)
		restore()
	save(); tr_(roundf(x), roundf(y)); scale_by((-1.0 if u.facing < 0 else 1.0) / sq, sq)
	var sc := uS(u) * fsc
	var sw: float = f.fw * sc
	var sh: float = f.fh * sc
	var ox0: float = -f.ax * sc
	var oy0: float = -f.ay * sc
	var src := Rect2(fr.x * f.fw, fr.y * f.fh, f.fw, f.fh)
	if qn > 0:
		var o := 2.6
		var c: Texture2D = CYAN[K.img]
		var mod := ca(Color(1, 1, 1, 0.95))
		for d in [Vector2(o, 0), Vector2(-o, 0), Vector2(0, o), Vector2(0, -o), Vector2(o * 0.7, o * 0.7), Vector2(-o * 0.7, o * 0.7), Vector2(o * 0.7, -o * 0.7), Vector2(-o * 0.7, -o * 0.7)]:
			draw_texture_rect_region(c, Rect2(ox0 + d.x, oy0 + d.y, sw, sh), src, mod)
	draw_texture_rect_region(IMG[K.img], Rect2(ox0, oy0, sw, sh), src, ca(Color.WHITE))
	if u.flash > 0:
		draw_texture_rect_region(WHITE[K.img], Rect2(ox0, oy0, sw, sh), src, ca(Color(1, 1, 1, minf(1.0, u.flash / 80.0))))
	restore()

func queued_num(u) -> int:
	if G == null or G.side != "blue" or u.team != "blue" or u.dead: return 0
	if G.mode != "select" and G.mode != "resolve": return 0
	var i := G.queue.find(u)
	if i < 0: return 0
	if G.mode == "resolve" and i < G.qi - 1: return 0
	return i + 1

func draw_badge(u) -> void:
	var n := queued_num(u)
	if n == 0: return
	var r: float = 11 * TS * (1 + u.pop / 400.0 if u.pop > 0 else 1.0)
	var x: float = u.x
	var y: float = u.y - u.K.head * uS(u) - 24 - 14 * TS
	var abq: bool = u.ab_queued != ""
	draw_circle(Vector2(x, y), r + 2.5, ca(Color("#3a1450") if abq else Color("#0d3d4a")))
	draw_circle(Vector2(x, y), r, ca(Color("#c98bff") if abq else Color("#38f2ff")))
	text(str(n), x, y + 1, roundf(r * 1.35), Color("#062830"))
	if abq and ABILITY_DEFS.has(u.ab_queued):
		var an: String = str(ABILITY_DEFS[u.ab_queued].name)
		text(an, x, y - r - 9 * TS, roundf(10 * TS), Color("#f0d8ff"), "center", 3, Color(0, 0, 0, 0.85))

func draw_bars(u) -> void:
	if u.dead: return
	var w := 46 * TS
	var bh := 5 * TS
	var gh := 3 * TS
	var x: float = u.x - w / 2
	var y: float = u.y - u.K.head * uS(u) - 10 - 6 * TS
	draw_rect(Rect2(x - 2, y - 2, w + 4, bh + gh + 5), ca(Color(20 / 255.0, 14 / 255.0, 10 / 255.0, 0.85)))
	draw_rect(Rect2(x, y, w, bh), ca(Color("#5a1f1f")))
	draw_rect(Rect2(x, y, w * maxf(0, u.shown_hp) / u.maxhp, bh), ca(Color.WHITE))
	var pc: float = float(u.hp) / u.maxhp
	var hc := (Color("#4fd36b") if pc > 0.35 else Color("#ffcf3a")) if u.team == "blue" else (Color("#ff5b4a") if pc > 0.35 else Color("#ffcf3a"))
	draw_rect(Rect2(x, y, w * pc, bh), ca(hc))
	var gp := minf(1.0, u.gauge / 100.0)
	draw_rect(Rect2(x, y + bh + 1, w, gh), ca(Color("#2a2a3a")))
	var gc := (Color("#fff6a0") if int(now / 120) % 2 == 1 else Color("#ffc928")) if gp >= 1 else Color("#ffc928")
	draw_rect(Rect2(x, y + bh + 1, w * gp, gh), ca(gc))
	if u.team == "blue" and gp >= 1 and phase == "battle":
		text("MP FULL", x + w + 4, y + bh, roundf(8 * TS), Color("#fff27a"), "left", 2.5, Color(0, 0, 0, 0.8))
	if u.buffs.size() > 0:
		var tags: Array = []
		for b in u.buffs:
			tags.append(str(STAT_SHORT.get(str(b.stat), str(b.stat))) + ("+" if int(b.req) > 0 else "-"))
		text(" ".join(tags), u.x, y + bh + gh + 9 * TS, roundf(8 * TS), Color("#bfeeff"), "center", 2.5, Color(0, 0, 0, 0.8))
	var nfs := roundf(10 * TS)
	# canvas uses alphabetic baseline at y-4; convert to middle
	var ny := y - 4 - nfs * 0.35
	text(u.name, u.x, ny, nfs, Color("#d6f1ff") if u.team == "blue" else Color("#ffd9cf"), "center", 3, Color(0, 0, 0, 0.75))
	if u.sub != "":
		var rfs := roundf(7.5 * TS)
		var role: String = u.cls + " · " + u.sub
		if u.team == "blue":
			role = "Lv." + str(hero_level(u.name)) + "  " + role
		text(role, u.x, y - 4 - 11 * TS - rfs * 0.35, rfs, Color("#9fd4e8") if u.team == "blue" else Color("#f0b6a8"), "center", 2.5, Color(0, 0, 0, 0.75))

func draw_fx(e: Dictionary) -> void:
	match e.type:
		"sprite":
			var fr := int(floorf(e.t * e.fps / 1000.0)) % int(e.n)
			draw_frame(IMG[e.img], e.fw, e.fh, fr, 0, e.x, e.y, e.ax, e.ay, e.s, false)
		"spark":
			var k: float = e.t / e.life
			var r: float = (26.0 if e.big else 16.0) * (0.4 + k)
			save(); tr_(e.x, e.y); rotate_by(e.rot); _alpha *= 1 - k
			var c := Color("#ffe066") if e.big else Color.WHITE
			for i in 6:
				var a := i * PI / 3
				draw_line(Vector2(cos(a), sin(a)) * r * 0.35, Vector2(cos(a), sin(a)) * r, ca(c), 4.0 if e.big else 3.0)
			draw_circle(Vector2.ZERO, maxf(0.01, (9.0 if e.big else 6.0) * (1 - k)), ca(Color.WHITE))
			restore()
		"ring":
			var kk: float = e.t / e.life
			save(); _alpha *= 1 - kk
			stroke_ellipse(e.x, e.y, 20 + kk * 50, 10 + kk * 25, e.color, 5 * (1 - kk) + 1)
			restore()
		"slash":
			var ks: float = e.t / e.life
			save(); tr_(e.x, e.y); scale_by(e.dir, 1); _alpha *= 1 - ks
			draw_arc(Vector2(-10, 0), 40 + ks * 18, -1.2, 1.2, 20, ca(Color("#e8fbff")), 7 * (1 - ks) + 2, true)
			restore()
		"pulse":
			var kp: float = e.t / e.life
			var pr: float = float(e.r) * (0.25 + 0.95 * kp)
			var pc: Color = e.color
			save(); _alpha *= (1.0 - kp)
			fill_ellipse(e.x, e.y, pr, pr * 0.42, Color(pc.r, pc.g, pc.b, 0.28))
			stroke_ellipse(e.x, e.y, pr, pr * 0.42, pc, 6.0 * (1.0 - kp) + 2.0)
			stroke_ellipse(e.x, e.y, pr * 0.7, pr * 0.3, Color(1, 1, 1, 0.7), 3.0 * (1.0 - kp) + 1.0)
			restore()
		"aura":
			var ua = e.unit
			if ua == null or ua.dead: return
			var ka: float = e.t / e.life
			var ac: Color = e.color
			save(); _alpha *= (1.0 - ka)
			fill_ellipse(ua.x, ua.y - 4, 30, 11, Color(ac.r, ac.g, ac.b, 0.35))
			for ri in 3:
				var rk: float = fmod(ka * 1.6 + ri * 0.33, 1.0)
				var ry: float = ua.y - 6 - rk * 70.0
				stroke_ellipse(ua.x, ry, 26 - rk * 8, 9 - rk * 3, Color(ac.r, ac.g, ac.b, 1.0 - rk), 3.0)
			restore()
		"stuck":
			save(); _alpha *= 1 - e.t / e.life; tr_(e.x, e.y); rotate_by(e.ang)
			img(IMG.arrow, 0, 64, 64, 64, -40, -35 * 0.7, 64 * 0.7, 64 * 0.7)
			restore()

func draw_projectile(p) -> void:
	if p.kind == "arrow":
		if p.delay > 0: return
		save(); tr_(p.x, p.y); rotate_by(p.ang)
		var s := 0.85 if p.special else 0.7
		if p.special:
			draw_rect(Rect2(-60, -3, 50, 6), ca(Color(0x9f / 255.0, 0xe3 / 255.0, 1, 0.5)))
		img(IMG.arrow, 0, 0, 64, 64, -48 * s, -35 * s, 64 * s, 64 * s)
		restore()
	elif p.kind == "bolt":
		if p.delay > 0: return
		save(); tr_(p.x, p.y); rotate_by(p.ang)
		var s2 := 1.3 if p.special else 1.0
		var fl := 0.8 + 0.2 * sin(now / 40.0)
		draw_rect(Rect2(-46 * s2, -3 * s2, 38 * s2, 6 * s2), ca(Color(0.9, 0.15, 0.3, 0.45)))
		draw_circle(Vector2.ZERO, 11 * s2 * fl, ca(Color(0.85, 0.1, 0.25, 0.45)))
		draw_circle(Vector2.ZERO, 7 * s2, ca(Color("#ff3355")))
		draw_circle(Vector2.ZERO, 3.5 * s2, ca(Color("#ffd0d8")))
		restore()
	else:
		var k := minf(1.0, p.t / p.dur)
		fill_ellipse(p.sx + (p.tx - p.sx) * k, p.sy + 40 + (p.ty - p.sy - 40) * k, 9, 4, Color(0, 0, 0, 0.25))
		var fr := int(floorf(now / 70.0)) % 6
		var s3 := 0.95 if p.special else 0.7
		save(); tr_(p.x, p.y); rotate_by(p.rot)
		img(IMG.dynamite, fr * 64, 0, 64, 64, -32 * s3, -32 * s3, 64 * s3, 64 * s3)
		restore()

func draw_text_fx(t: Dictionary) -> void:
	var k: float = t.t / t.life
	var y: float = t.y - 34 * (1 - pow(1 - k, 2))
	var sc: float
	if t.pop: sc = 1.7 - k / 0.12 * 0.7 if k < 0.12 else 1.0
	else: sc = 1.3 - k / 0.08 * 0.3 if k < 0.08 else 1.0
	save(); _alpha *= 1 - (k - 0.7) / 0.3 if k > 0.7 else 1.0
	tr_(t.x, y); scale_by(sc, sc)
	var fsz := roundf(t.size * TS)
	text(t.s, 0, 0, fsz, t.color, "center", maxf(3, fsz / 4.5))
	restore()

func draw_hud() -> void:
	if G == null or phase == "title" or phase == "loading": return
	var w := minf(300, (VWc - 96) / 2)
	var h := roundf(minf(44, maxf(34, w / 6.5)))
	var fs := roundf(h * 0.38)
	var pad := roundf(h * 1.05)
	var top := 6 + SAFE_T
	for team in ["blue", "red"]:
		var us: Array = G.units.filter(func(u): return u.team == team)
		var al := us.filter(func(u): return not u.dead).size()
		var hp := 0.0
		var mx := 0.0
		for u in us:
			hp += maxf(0, u.shown_hp); mx += u.maxhp
		var isB: bool = team == "blue"
		var x := 6.0 if isB else VWc - 6 - w
		draw3(IMG.ribbonBlue if isB else IMG.ribbonRed, x, top, w, h)
		var team_name: String
		if isB: team_name = "SQUAD" if w > 190 else "BLUE"
		elif not encounter.is_empty(): team_name = "WILD"
		elif G.n_red == 1: team_name = "BOSS"
		elif G.n_red == 2: team_name = "ELITES" if w > 190 else "RED"
		else: team_name = "GOBLINS" if w > 190 else "RED"
		outlined(team_name, x + (pad if isB else w - pad), top + h * 0.42, fs, Color.WHITE, "left" if isB else "right")
		outlined("%d/%d" % [al, us.size()], x + (w - pad if isB else pad), top + h * 0.42, fs, Color.WHITE, "right" if isB else "left")
		var bx := x + h * 0.6
		var bw := w - h * 1.2
		var by := top + h + 2
		draw_rect(Rect2(bx - 2, by - 2, bw + 4, 10), Color(20 / 255.0, 14 / 255.0, 10 / 255.0, 0.85))
		var fw := bw * hp / mx
		draw_rect(Rect2(bx if isB else bx + bw - fw, by, fw, 6), Color("#4fd36b") if isB else Color("#ff5b4a"))
	var mine := G.side == "blue" and G.mode != "over"
	var label := "" if G.mode == "over" else ("YOUR TURN" if mine else "ENEMY TURN")
	var cw := maxf(70, VWc - 2 * w - 24)
	outlined("Turn %d" % maxi(1, G.turn), VWc / 2, top + h * 0.28, roundf(fs * 0.85), Color.WHITE)
	if label != "":
		outlined(label, VWc / 2, top + h * 0.28 + fs * 1.15, roundf(minf(fs * 1.35, cw / (label.length() * 0.62))), Color("#7ff3ff") if mine else Color("#ff8a7a"))
	if surge_mult() > 1:
		outlined("SURGE x%.2f" % surge_mult(), VWc / 2, top + h + 14, 11, Color("#ffd23f"))

func draw_banner() -> void:
	if banner == null: return
	var k: float = banner.t / banner.life
	var sc := 2.2 - k / 0.12 * 1.2 if k < 0.12 else 1.0
	var al := 1 - (k - 0.8) / 0.2 if k > 0.8 else 1.0
	var bs := minf(1.0, (VWc - 20) / 400.0)
	save(); _alpha *= al; tr_(VWc / 2, VHc / 2 - 30); scale_by(sc * bs, sc * bs)
	var tex: Texture2D = IMG.ribbonBlue if banner.color == "blue" else (IMG.ribbonRed if banner.color == "red" else IMG.ribbonYellow)
	draw3(tex, -190, -40, 380, 80)
	outlined(banner.text, 0, -6, 40, Color.WHITE)
	if banner.get("sub", "") != "": outlined(banner.sub, 0, 50, 16, Color("#ffe27a"))
	restore()

# ---------------------------------------------------------------- layout
var vscale := 1.0
var dpr := 1.0
var OX := 0.0
var OY := 0.0
var VWc := 1024.0
var VHc := 576.0
var TS := 1.0
var SAFE_T := 0.0
var _last_vp := Vector2.ZERO
var terrain_built := false

func _rm(o, kx: String, ky: String, to_port: bool) -> void:
	var x: float = o[kx] if o is Dictionary else o.get(kx)
	var y: float = o[ky] if o is Dictionary else o.get(ky)
	var nx := y if to_port else LW - y
	var ny := LW - x if to_port else x
	if o is Dictionary:
		o[kx] = nx; o[ky] = ny
	else:
		o.set(kx, nx); o.set(ky, ny)

func remap_units(to_port: bool) -> void:
	if G != null:
		for u in G.units:
			_rm(u, "x", "y", to_port); _rm(u, "hx", "hy", to_port)
	for p in projectiles:
		_rm(p, "x", "y", to_port); _rm(p, "sx", "sy", to_port); _rm(p, "tx", "ty", to_port)
	for e in fx: _rm(e, "x", "y", to_port)
	for t in texts: _rm(t, "x", "y", to_port)

func compute_dpr(vp: Vector2) -> float:
	if OS.has_feature("web"):
		var iw = JavaScriptBridge.eval("window.innerWidth", true)
		if iw != null and float(iw) > 0: return maxf(0.5, vp.x / float(iw))
	return maxf(1.0, DisplayServer.screen_get_scale())

func layout() -> void:
	var vp := get_viewport_rect().size
	if vp == _last_vp: return
	_last_vp = vp
	dpr = compute_dpr(vp)
	if params.has("dpr"): dpr = float(params.dpr)
	var vw := vp.x / dpr
	var vh := vp.y / dpr
	var port := vh > vw * 1.05
	if port != PORT:
		set_orientation(port)
		if terrain_built:
			remap_units(port); build_terrain()
	VWc = vw; VHc = vh
	var topR := 52.0 + SAFE_T if PORT else (30.0 if vh < 520 else 0.0)
	var botR := 96.0 if PORT else (58.0 if vh < 520 else 66.0)
	vscale = minf(vw / VIEW.w, (vh - topR - botR) / VIEW.h)
	OX = (vw - VIEW.w * vscale) / 2 - VIEW.x * vscale
	OY = topR + (vh - topR - botR - VIEW.h * vscale) / 2 - VIEW.y * vscale
	TS = maxf(1.0, minf(1.7, 0.9 / vscale))

# ---------------------------------------------------------------- UI (HTML overlay equivalents)
var buttons := [] # {id, rect, cb}
var pressed_id := ""

func add_btn(id: String, r: Rect2, cb: Callable) -> void:
	buttons.append({"id": id, "rect": r, "cb": cb})

func clampf3(lo: float, v: float, hi: float) -> float: return maxf(lo, minf(v, hi))

## A Tiny Swords 3-slice button like .btn: border caps, text raised by padding-bottom.
func ui_button(id: String, r: Rect2, label: String, red: bool, fsz: float, cap: float, cb: Callable, off := false, locked := false, pulse := false) -> void:
	var down := pressed_id == id and not locked
	var tex: Texture2D
	if red: tex = IMG.btnRedP if down else IMG.btnRed
	else: tex = IMG.btnBlueP if down else IMG.btnBlue
	save()
	var c := r.get_center()
	var s := 0.95 if down else 1.0
	tr_(c.x, c.y); scale_by(s, s); tr_(-c.x, -c.y)
	if locked: _alpha *= 0.45
	var mod := Color.WHITE
	if off:
		mod = Color(0.62, 0.62, 0.66, 0.7)
	elif pulse:
		var b := 1.0 + 0.09 * (1 - cos(now / 1100.0 * TAU))
		mod = Color(b, b, b, 1)
	css3(tex, r.position.x, r.position.y, r.size.x, r.size.y, cap, mod)
	var pb := 2.0 if down else 10.0
	shadow_text(label, c.x, r.position.y + (r.size.y - pb) / 2.0, fsz, Color(1, 1, 1, 0.75) if off else Color.WHITE, 2.0, Color(0, 0, 0, 0.5))
	restore()
	if not locked: add_btn(id, r, cb)

func ribbon(tex: Texture2D, cx: float, y: float, label: String, fsz: float, h: float, minw := 0.0, cap := 40.0, line_h := -1.0) -> void:
	var w := maxf(minw, text_w(label, fsz) + cap * 2)
	css3(tex, cx - w / 2, y, w, h, cap)
	var lh := line_h if line_h > 0 else h - 8
	shadow_text(label, cx, y + lh / 2.0, fsz, Color.WHITE, 2.0)

func wrap_words(s: String, size: float, maxw: float) -> Array:
	var lines := []
	var cur := ""
	for wd in s.split(" "):
		var t: String = wd if cur == "" else cur + " " + wd
		if text_w(t, size) > maxw and cur != "":
			lines.append(cur); cur = wd
		else:
			cur = t
	if cur != "": lines.append(cur)
	return lines

func link_text(prefix: String, link: String, suffix: String, url: String, cx: float, y: float, size: float, col: Color, lcol: Color, shadow: bool, id: String) -> void:
	var w1 := text_w(prefix, size)
	var w2 := text_w(link, size)
	var w3 := text_w(suffix, size)
	var x := cx - (w1 + w2 + w3) / 2
	for part in [[prefix, col, w1], [link, lcol, w2], [suffix, col, w3]]:
		if part[0] == "": continue
		if shadow:
			text(part[0], x, y, size, part[1], "left", 3, Color(0, 0, 0, 0.8))
		else:
			text(part[0], x, y, size, part[1], "left")
		x += part[2]
	add_btn(id, Rect2(cx - (w1 + w2 + w3) / 2 + w1 - 4, y - size, w2 + 8, size * 2), func(): OS.shell_open(url))

# ---------------------------------------------------------------- soft menu chrome
# One rounded, bubbly look for every menu: a cream sheet, white cards, teal pills, gold = selected / equipped.
var UI_INK := Color("#1d3b41")
var UI_MUTED := Color("#5e7b7f")
var UI_SHEET := Color("#f5f0e3")
var UI_CARD := Color("#ffffff")
var UI_LINE := Color("#ddd5c2")
var UI_TEAL := Color("#2a9d97")
var UI_TEAL_D := Color("#1d7470")
var UI_TEAL_L := Color("#d3eeeb")
var UI_GOLD := Color("#f0b03a")
var UI_GOLD_D := Color("#c4861b")
var UI_GOLD_L := Color("#fff0c4")
var UI_CORAL := Color("#e2685b")
var UI_CORAL_D := Color("#b54b40")
var UI_GOOD := Color("#23874d")
var UI_GOOD_L := Color("#d3f1dd")
var UI_BAD := Color("#c8443a")
var UI_BAD_L := Color("#fbdcd8")
var UI_LOCK := Color("#a39d90")

## Rounded rectangle (StyleBoxFlat) honoring the current transform and alpha.
func rbox(r: Rect2, rad: float, fill: Color, border: Color = Color(0, 0, 0, 0), bw: float = 0.0, shadow: float = 0.0) -> void:
	if r.size.x <= 0.5 or r.size.y <= 0.5:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = ca(fill)
	sb.set_corner_radius_all(int(roundf(clampf(rad, 0.0, minf(r.size.x, r.size.y) / 2.0))))
	sb.corner_detail = 12
	sb.anti_aliasing = true
	if bw > 0.0:
		sb.border_color = ca(border)
		sb.set_border_width_all(int(roundf(bw)))
	if shadow > 0.0:
		sb.shadow_color = ca(Color(0.03, 0.1, 0.11, 0.22))
		sb.shadow_size = int(roundf(shadow))
		sb.shadow_offset = Vector2(0, roundf(shadow * 0.4))
	draw_style_box(sb, r)

func pill_colors(kind: String) -> Array:
	if kind == "soft": return [UI_CARD, UI_LINE, UI_INK]
	if kind == "danger": return [UI_CORAL, UI_CORAL_D, Color.WHITE]
	if kind == "gold": return [UI_GOLD, UI_GOLD_D, Color("#3d2706")]
	if kind == "tealsoft": return [UI_TEAL_L, Color("#a9d6d1"), UI_TEAL_D]
	return [UI_TEAL, UI_TEAL_D, Color.WHITE]

## Soft pill button. kind: primary (teal) | soft (white) | danger (coral) | gold | tealsoft.
func pill(id: String, r: Rect2, label: String, kind: String, fsz: float, cb: Callable, off: bool = false, locked: bool = false, pulse: bool = false, sub: String = "", icon: String = "") -> void:
	var down: bool = pressed_id == id and not locked
	var pc: Array = pill_colors(kind)
	var fill: Color = pc[0]
	var lip: Color = pc[1]
	var fg: Color = pc[2]
	if off:
		fill = fill.lerp(UI_SHEET, 0.55)
		lip = lip.lerp(UI_SHEET, 0.55)
		fg = fg.lerp(UI_MUTED, 0.5)
	save()
	if locked: _alpha *= 0.4
	var rad: float = minf(r.size.y / 2.0, 26.0)
	var dy: float = 3.0 if down else 0.0
	if pulse:
		var pk: float = 0.5 - 0.5 * cos(now / 1100.0 * TAU)
		rbox(r.grow(2.0 + 3.0 * pk), rad + 4.0, Color(UI_GOLD.r, UI_GOLD.g, UI_GOLD.b, 0.4 * pk))
	rbox(Rect2(r.position.x, r.position.y + 4.0, r.size.x, r.size.y - 4.0), rad, lip)
	var face := Rect2(r.position.x, r.position.y + dy, r.size.x, r.size.y - 4.0)
	rbox(face, rad, fill)
	if kind != "soft" and not off:
		rbox(Rect2(face.position.x + rad * 0.7, face.position.y + 3.0, face.size.x - rad * 1.4, face.size.y * 0.24), face.size.y * 0.12, Color(1, 1, 1, 0.11))
	var cx: float = face.get_center().x
	var cy: float = face.get_center().y
	var iw: float = fsz * 0.8 if icon == "back" else 0.0
	var fs2: float = fit_size(label, fsz, face.size.x - rad - iw, 9.0)
	var lw: float = text_w(label, fs2)
	var lx: float = cx + iw / 2.0
	if icon == "back":
		var ax: float = lx - lw / 2.0 - fsz * 0.55
		var ah: float = fsz * 0.3
		draw_polyline(PackedVector2Array([Vector2(ax + ah * 0.7, cy - ah), Vector2(ax - ah * 0.3, cy), Vector2(ax + ah * 0.7, cy + ah)]), ca(fg), 3.0, true)
	if icon == "up" or icon == "down" or icon == "left" or icon == "right":
		var k: float = minf(face.size.x, face.size.y) * 0.2
		var pts := PackedVector2Array()
		if icon == "up": pts = PackedVector2Array([Vector2(cx - k, cy + k * 0.5), Vector2(cx, cy - k * 0.5), Vector2(cx + k, cy + k * 0.5)])
		elif icon == "down": pts = PackedVector2Array([Vector2(cx - k, cy - k * 0.5), Vector2(cx, cy + k * 0.5), Vector2(cx + k, cy - k * 0.5)])
		elif icon == "left": pts = PackedVector2Array([Vector2(cx + k * 0.5, cy - k), Vector2(cx - k * 0.5, cy), Vector2(cx + k * 0.5, cy + k)])
		else: pts = PackedVector2Array([Vector2(cx - k * 0.5, cy - k), Vector2(cx + k * 0.5, cy), Vector2(cx - k * 0.5, cy + k)])
		draw_polyline(pts, ca(fg), 3.5, true)
	elif sub != "":
		text(label, lx, cy - fs2 * 0.42, fs2, fg)
		var sfs: float = fit_size(sub, maxf(10.0, fsz * 0.62), face.size.x - rad, 8.0)
		text(sub, lx, cy + fs2 * 0.62, sfs, Color(fg.r, fg.g, fg.b, 0.72))
	else:
		text(label, lx, cy, fs2, fg)
	restore()
	if not locked: add_btn(id, r, cb)

## Segmented pill tabs; cb receives the tab index.
func seg_tabs(id: String, r: Rect2, labels: Array, cur: int, fsz: float, cb: Callable) -> void:
	rbox(r, r.size.y / 2.0, Color(UI_INK.r, UI_INK.g, UI_INK.b, 0.09))
	var n: int = labels.size()
	var w: float = (r.size.x - 8.0) / float(maxi(1, n))
	for i in n:
		var tr2 := Rect2(r.position.x + 4.0 + w * i, r.position.y + 4.0, w, r.size.y - 8.0)
		var on: bool = i == cur
		if on:
			rbox(tr2, tr2.size.y / 2.0, UI_TEAL, Color(0, 0, 0, 0), 0.0, 4.0)
		var lab: String = str(labels[i])
		text(lab, tr2.get_center().x, tr2.get_center().y, fit_size(lab, fsz, tr2.size.x - 14.0, 9.0), Color.WHITE if on else UI_MUTED)
		var k: int = i
		add_btn(id + str(i), tr2, func(): cb.call(k))

## Small rounded badge. Returns its width.
func chip(s: String, x: float, cy: float, fsz: float, bg: Color, fg: Color, align: String = "left") -> float:
	var w: float = text_w(s, fsz) + fsz * 1.2
	var h: float = fsz + 9.0
	var x0: float = x
	if align == "center": x0 = x - w / 2.0
	elif align == "right": x0 = x - w
	rbox(Rect2(x0, cy - h / 2.0, w, h), h / 2.0, bg)
	text(s, x0 + w / 2.0, cy, fsz, fg)
	return w

func section_label(s: String, x: float, y: float, short: bool) -> void:
	text(s, x + 4.0, y, 11.0 if short else 12.0, UI_MUTED, "left")

## Every menu screen: dim the scene, one rounded sheet, a Back pill, a title with one helper line,
## and optional tabs (right of the title, or under it on narrow screens). Returns the content rect.
func menu_sheet(back_id: String, title: String, helper: String, back_cb: Callable, tabs: Array = [], tab_cur: int = 0, tab_cb: Callable = Callable(), tab_id: String = "") -> Rect2:
	var short: bool = VHc <= 430
	draw_rect(Rect2(0, 0, VWc, VHc), Color(0.03, 0.1, 0.11, 0.6))
	var m: float = 8.0 if short else 14.0
	var panel := Rect2(m, m, VWc - m * 2.0, VHc - m * 2.0)
	rbox(panel, 22.0 if short else 28.0, UI_SHEET, Color(1, 1, 1, 0.55), 2.0, 12.0)
	var ip: float = 12.0 if short else 18.0
	var inner := panel.grow(-ip)
	var bh: float = 38.0 if short else 44.0
	var bw: float = 96.0 if short else 110.0
	pill(back_id, Rect2(inner.position.x, inner.position.y, bw, bh), "Back", "soft", 15.0 if short else 17.0, back_cb, false, false, false, "", "back")
	var tx: float = inner.position.x + bw + 16.0
	var narrow: bool = inner.size.x < 640.0
	var tabs_w: float = 0.0
	if tabs.size() > 0:
		tabs_w = minf(320.0, maxf(220.0, float(tabs.size()) * 130.0))
	var tabs_in_header: bool = tabs.size() > 0 and not narrow
	var right: float = inner.end.x - (tabs_w + 14.0 if tabs_in_header else 0.0)
	var tfs: float = fit_size(title, 22.0 if short else 27.0, right - tx, 14.0)
	var wrap_lines: Array = []
	if helper != "" and text_w(helper, 11.0) > right - tx:
		wrap_lines = wrap_words(helper, 12.0, inner.size.x - 8.0)
		helper = ""
	if helper != "":
		text(title, tx, inner.position.y + bh * 0.3, tfs, UI_INK, "left")
		var hfs: float = fit_size(helper, 11.0 if short else 13.0, right - tx, 9.0)
		text(helper, tx, inner.position.y + bh * 0.3 + tfs * 0.5 + hfs * 0.85, hfs, UI_MUTED, "left")
	else:
		text(title, tx, inner.position.y + bh * 0.5, tfs, UI_INK, "left")
	var top: float = inner.position.y + bh + (8.0 if short else 14.0)
	for wl in wrap_lines:
		text(str(wl), inner.position.x + 4.0, top + 6.0, 12.0, UI_MUTED, "left")
		top += 16.0
	if wrap_lines.size() > 0:
		top += 4.0
	if tabs.size() > 0:
		var th: float = 36.0 if short else 42.0
		if tabs_in_header:
			seg_tabs(tab_id, Rect2(inner.end.x - tabs_w, inner.position.y + (bh - th) / 2.0, tabs_w, th), tabs, tab_cur, 14.0 if short else 16.0, tab_cb)
		else:
			seg_tabs(tab_id, Rect2(inner.position.x, top, inner.size.x, th), tabs, tab_cur, 14.0 if short else 16.0, tab_cb)
			top += th + 8.0
	return Rect2(inner.position.x, top, inner.size.x, inner.end.y - top)

## Hero picker shared by Characters and Inventory: rounded cards on the left, or a pill grid on narrow screens.
## Returns the rect left for the detail pane.
func hero_picker(prefix: String, area: Rect2, short: bool, sub_fn: Callable) -> Rect2:
	if area.size.x < 560.0:
		var cols: int = 3
		var gap: float = 6.0
		var chh: float = 36.0
		var cw: float = (area.size.x - gap * float(cols - 1)) / float(cols)
		for i in HERO_NAMES.size():
			var r := Rect2(area.position.x + float(i % cols) * (cw + gap), area.position.y + float(i / cols) * (chh + gap), cw, chh)
			var sel: bool = i == char_sel
			rbox(r, chh / 2.0, UI_GOLD_L if sel else UI_CARD, UI_GOLD if sel else UI_LINE, 2.5 if sel else 1.5)
			text(str(HERO_NAMES[i]), r.get_center().x, r.get_center().y, 15.0, UI_INK)
			var idx: int = i
			add_btn(prefix + str(i), r, func(): select_hero(idx))
		var used: float = 2.0 * (chh + gap) + 6.0
		return Rect2(area.position.x, area.position.y + used, area.size.x, area.size.y - used)
	var lw: float = clampf3(168.0, area.size.x * 0.25, 220.0)
	var gap2: float = 5.0 if short else 7.0
	var rh: float = (area.size.y - gap2 * 5.0) / 6.0
	for i in HERO_NAMES.size():
		var hn: String = HERO_NAMES[i]
		var hs := compute_hero_stats(hn)
		var r := Rect2(area.position.x, area.position.y + float(i) * (rh + gap2), lw, rh)
		var sel: bool = i == char_sel
		rbox(r, minf(18.0, rh / 2.0), UI_GOLD_L if sel else UI_CARD, UI_GOLD if sel else UI_LINE, 2.5 if sel else 1.5, 3.0 if sel else 0.0)
		draw_hero_sprite(hs.kind, r.position.x + 28.0, r.end.y - 3.0, 0.34 if short else 0.42)
		var tx: float = r.position.x + 56.0
		var line: String = str(sub_fn.call(hn, hs))
		text(hn, tx, r.get_center().y - (7.0 if short else 9.0), 15.0 if short else 17.0, UI_INK, "left")
		text(line, tx, r.get_center().y + (9.0 if short else 11.0), fit_size(line, 11.0 if short else 12.0, r.end.x - tx - 8.0, 9.0), UI_MUTED, "left")
		var idx2: int = i
		add_btn(prefix + str(i), r, func(): select_hero(idx2))
	return Rect2(area.position.x + lw + 16.0, area.position.y, area.size.x - lw - 16.0, area.size.y)

## Detail header: sprite, big name, and soft chips (level, class …).
func hero_head(name: String, st: Dictionary, x: float, y: float, w: float, short: bool, chips: Array) -> float:
	var hh: float = 48.0 if short else 66.0
	draw_hero_sprite(st.kind, x + 30.0, y + hh - 2.0, 0.56 if short else 0.78)
	text(name, x + 74.0, y + hh * 0.32, 22.0 if short else 28.0, UI_INK, "left")
	var cx: float = x + 74.0
	var cfs: float = 11.0 if short else 12.0
	for c in chips:
		var cs: String = str(c[0])
		if cx + text_w(cs, cfs) + cfs * 1.2 > x + w:
			break
		cx += chip(cs, cx, y + hh * 0.76, cfs, c[1], c[2]) + 6.0
	return hh

func stat_rows() -> Array:
	return [
		["hp", "HP", 1200.0, Color("#4fc46b"), ""],
		["atk", "Attack", 180.0, Color("#e8664a"), ""],
		["def", "Defense", 180.0, Color("#3d8adf"), ""],
		["armor", "Armor", 60.0, Color("#8a8f9a"), ""],
		["crit", "Crit", 70.0, Color("#e6b422"), "%"],
		["mana", "MP Regen", 50.0, Color("#9b6bdb"), ""],
		["speed", "Speed", 70.0, Color("#3ec0c0"), ""],
	]

## Two-column rounded stat bars inside a soft card. Returns the height used.
func draw_stat_block(name: String, st: Dictionary, r: Rect2, short: bool) -> void:
	rbox(r, 18.0, Color(1, 1, 1, 0.65), UI_LINE, 1.0)
	var rows: Array = stat_rows()
	var two: bool = r.size.x > 380.0
	var pad: float = 12.0
	var cw: float = (r.size.x - pad * 2.0 - 16.0) / 2.0 if two else r.size.x - pad * 2.0
	var nrow: int = 4 if two else 7
	var rh: float = minf(24.0, (r.size.y - 12.0) / float(nrow))
	for ri in rows.size():
		var row: Array = rows[ri]
		var key: String = row[0]
		var cur: int = int(st[key])
		var shown: String = str(cur) + str(row[4])
		if key == "mana":
			shown = "+" + str(cur)
		var vx: float = r.position.x + pad + ((cw + 16.0) * float(ri % 2) if two else 0.0)
		var vy: float = r.position.y + 6.0 + rh * float(int(ri / 2) if two else ri)
		var bar_v := float(char_bar[key]) if char_bar.has(key) else float(cur)
		draw_stat_bar(vx, vy, cw, rh, row[1], bar_v, row[2], shown, stat_delta(key, cur), row[3])

func save_cfg() -> void:
	ensure_hero_data()
	var cf := ConfigFile.new()
	cf.set_value("rs", "muted", muted)
	for name in HERO_NAMES:
		# Class is stored for readability only; load always keeps the locked class.
		cf.set_value("loadout", name, "%s|%s" % [CHAR[name].cls, CHAR[name].sub])
		cf.set_value("progress", name, "%d|%d" % [hero_level(name), hero_xp(name)])
		var eq: Dictionary = EQUIP[name]
		var ev := []
		for slot in SLOT_IDS:
			ev.append(str(eq.get(slot, "")))
		cf.set_value("equip", name, "|".join(ev))
		validate_ab_equip(name)
		cf.set_value("abilities", name, "%s|%s" % [str(AB_EQUIP[name].cls), str(AB_EQUIP[name].sub)])
		if AB_AUTO.has(name):
			cf.set_value("auto_ab", name, "-" if str(AB_AUTO[name]) == "" else str(AB_AUTO[name]))
		cf.set_value("mp", name, int(roundf(float(HERO_MP.get(name, 0.0)))))
	cf.set_value("rs", "auto", AUTO)
	cf.set_value("party", "squad", ",".join(SQUAD))
	cf.set_value("inv", "bag", ",".join(INV))
	if WORLD != null:
		var fl: Array = WORLD.flags.keys()
		cf.set_value("world", "flags", ",".join(fl))
		if ow_ready:
			cf.set_value("world", "pos", "%d|%d" % [int(ow_x), int(ow_y)])
			cf.set_value("world", "layout", int(WORLD.data.get("tile_layout", 1)))
	cf.save("user://riftstrike.cfg")

func load_cfg() -> void:
	ensure_hero_data()
	var cf := ConfigFile.new()
	var loaded: bool = cf.load("user://riftstrike.cfg") == OK
	if not loaded:
		INV = STARTER_BAG.duplicate()
		return
	muted = bool(cf.get_value("rs", "muted", muted))
	AUTO = bool(cf.get_value("rs", "auto", false))
	for name in HERO_NAMES:
		var raw = cf.get_value("loadout", name, "")
		if typeof(raw) == TYPE_STRING and raw != "":
			var parts: PackedStringArray = raw.split("|")
			# Class is locked to the character; ignore any class saved by older builds.
			var sub := parts[1] if parts.size() >= 2 else (parts[0] if parts.size() == 1 else "")
			if SUB_DEFS.has(sub):
				CHAR[name].sub = sub
		var prog = cf.get_value("progress", name, "")
		if typeof(prog) == TYPE_STRING and prog != "":
			var pp: PackedStringArray = prog.split("|")
			var lv := int(pp[0]) if pp.size() >= 1 else 1
			var xp := int(pp[1]) if pp.size() >= 2 else 0
			HERO_PROG[name] = {"level": clampi(lv, 1, LEVEL_CAP), "xp": maxi(0, xp)}
			if hero_level(name) >= LEVEL_CAP:
				HERO_PROG[name].xp = 0
		var eqr = cf.get_value("equip", name, "")
		if typeof(eqr) == TYPE_STRING and eqr != "":
			var ep: PackedStringArray = eqr.split("|")
			for si in SLOT_IDS.size():
				var iid := ep[si] if si < ep.size() else ""
				if iid != "" and ITEM_DEFS.has(iid) and ITEM_DEFS[iid].slot == SLOT_IDS[si]:
					EQUIP[name][SLOT_IDS[si]] = iid
				else:
					EQUIP[name][SLOT_IDS[si]] = ""
		var abr = cf.get_value("abilities", name, "")
		AB_EQUIP[name] = {"cls": "", "sub": ""}
		if typeof(abr) == TYPE_STRING and abr != "":
			var ap: PackedStringArray = abr.split("|")
			AB_EQUIP[name]["cls"] = ap[0] if ap.size() >= 1 else ""
			AB_EQUIP[name]["sub"] = ap[1] if ap.size() >= 2 else ""
		var aar = cf.get_value("auto_ab", name, "")
		if typeof(aar) == TYPE_STRING and aar != "":
			AB_AUTO[name] = "" if aar == "-" else str(aar)
		HERO_MP[name] = clampf(float(cf.get_value("mp", name, 0)), 0.0, AB_MP)
		validate_ab_equip(name)
	if cf.has_section_key("party", "squad"):
		var sq = cf.get_value("party", "squad", "")
		if typeof(sq) == TYPE_STRING and sq != "":
			SQUAD = Array(sq.split(",", false))
	if cf.has_section_key("inv", "bag"):
		var bag = cf.get_value("inv", "bag", "")
		INV = []
		if typeof(bag) == TYPE_STRING and bag != "":
			for iid in bag.split(",", false):
				if ITEM_DEFS.has(iid):
					INV.append(iid)
	else:
		# Old saves have no inventory yet — seed the starter bag once.
		INV = STARTER_BAG.duplicate()
	ensure_hero_data()
	if WORLD != null:
		var wf = cf.get_value("world", "flags", "")
		if typeof(wf) == TYPE_STRING and wf != "":
			for f in wf.split(",", false):
				WORLD.set_flag(str(f))
		var wp = cf.get_value("world", "pos", "")
		if typeof(wp) == TYPE_STRING and wp != "":
			var pp2: PackedStringArray = wp.split("|")
			if pp2.size() == 2:
				ow_x = float(pp2[0])
				ow_y = float(pp2[1])
				ow_ready = true
				# Saves from an older tile layout: scale the position, or fall back to the start.
				var saved_layout: int = int(cf.get_value("world", "layout", 1))
				var cur_layout: int = int(WORLD.data.get("tile_layout", 1))
				if saved_layout != cur_layout:
					var sc_tbl: Dictionary = WORLD.data.get("tile_layout_scale", {})
					if sc_tbl.has(str(saved_layout)):
						var k: float = float(sc_tbl[str(saved_layout)])
						ow_x *= k
						ow_y *= k
					else:
						ow_ready = false
	# Drop equipment ids that somehow also sit in the bag, and vice versa, is fine
	# (bag and equipment are separate). Rebuild if an equipped id is invalid already handled.

func open_chars() -> void:
	char_sel = 0
	char_prev = {}
	char_bar = {}
	char_delta_t = 0.0
	screen = "chars"
	sfx.tone(660, 0.06, "square", 0.035)

func open_inv() -> void:
	char_sel = 0
	inv_slot_sel = ""
	char_prev = {}
	char_bar = {}
	char_delta_t = 0.0
	screen = "inv"
	sfx.tone(660, 0.06, "square", 0.035)

func open_compendium() -> void:
	COMP.open()
	screen = "compendium"
	sfx.tone(660, 0.06, "square", 0.035)

func open_party() -> void:
	party_sel = 0
	char_sel = 0
	screen = "party"
	sfx.tone(660, 0.06, "square", 0.035)

func open_overworld() -> void:
	build_overworld()
	phase = "overworld"
	paused = false
	screen = "overworld"
	ow_menu_open = false
	menu_return = ""
	WORLD.cur_area = ""
	WORLD.reset_grace()
	sfx.tone(523, 0.08, "square", 0.035)


# Back to the overworld without rebuilding (after a menu, the map, or a wild battle).
func resume_overworld() -> void:
	if OW_PROPS.is_empty():
		build_overworld()
	phase = "overworld"
	paused = false
	screen = "overworld"
	menu_return = ""
	ow_tx = ow_x
	ow_ty = ow_y
	ow_moving = false
	ow_anim = "idle"
	WORLD.last_x = ow_x
	WORLD.last_y = ow_y


func menu_back() -> void:
	if menu_return == "overworld":
		resume_overworld()
	else:
		to_title()


func ow_open_menu_screen(which: String) -> void:
	ow_menu_open = false
	if which == "map":
		WMAP.open()
		screen = "map"
		menu_return = "overworld"
	elif which == "stats":
		var li: int = maxi(0, SQUAD.find(lead_name()))
		STATS.open(li)
		screen = "stats"
		menu_return = "overworld"
	elif which == "party":
		new_battle()
		phase = "title"
		open_party()
		menu_return = "overworld"
	elif which == "inv":
		new_battle()
		phase = "title"
		open_inv()
		menu_return = "overworld"
	elif which == "chars":
		new_battle()
		phase = "title"
		open_chars()
		menu_return = "overworld"
	sfx.tone(660, 0.06, "square", 0.035)


func close_world_map() -> void:
	resume_overworld()


func close_stats() -> void:
	resume_overworld()


# ---------------------------------------------------------------- wild encounters
func start_encounter(e: Dictionary) -> void:
	encounter = e
	ow_moving = false
	ow_tx = ow_x
	ow_ty = ow_y
	save_cfg()
	new_battle(3)
	phase = "battle"
	paused = false
	screen = ""
	begin_player_turn()
	banner.text = "WILD ENCOUNTER"
	banner.sub = WORLD.area_name(str(e.get("area", ""))) + "  ·  Lv." + str(int(e.get("level", 1)))
	banner.color = "yellow"
	banner.life = 1400.0
	sfx.tone(392, 0.09, "square", 0.04)


func build_encounter_roster() -> Array:
	var names := shuffled(GOB_NAMES)
	var kinds: Array = encounter.get("kinds", ["torch"])
	var n: int = clampi(kinds.size(), 1, 3)
	var ks: Array = kinds.slice(0, n)
	var nt: Array = ks.filter(func(k): return k != "tnt")
	var tt: Array = ks.filter(func(k): return k == "tnt")
	ks = nt + tt
	var slots: Array = RED_SLOTS[n]
	var out: Array = []
	for i in ks.size():
		out.append([str(ks[i]), names[i], slots[i][0], slots[i][1]])
	return out


func end_encounter_return() -> void:
	encounter = {}
	fx = []; projectiles = []; texts = []; banner = null; cast_banner = null; screen_flash = null
	WORLD.reset_grace()
	resume_overworld()


# RUN: leave any battle right away. Wild battles go back to the overworld spot, raids to the title. No XP.
func run_battle() -> void:
	if phase != "battle" and phase != "ending":
		return
	sfx.tone(330, 0.06, "square", 0.03)
	stash_party_mp()
	save_cfg()
	if not encounter.is_empty():
		end_encounter_return()
	else:
		to_title()


func results_primary() -> void:
	if not encounter.is_empty():
		end_encounter_return()
	else:
		start_fight(last_raid)


func results_title() -> void:
	encounter = {}
	to_title()

func selected_hero() -> String:
	return HERO_NAMES[clampi(char_sel, 0, HERO_NAMES.size() - 1)]

func apply_loadout_preview(name: String) -> void:
	if G == null:
		return
	var st := compute_hero_stats(name)
	for u in G.units:
		if u.team != "blue" or u.name != name:
			continue
		var kind: String = st.kind
		u.kind = kind
		u.K = KINDS[kind]
		u.hp = st.hp
		u.maxhp = st.hp
		u.shown_hp = st.hp
		u.atk = st.atk
		u.def = st.def
		u.armor = st.armor
		u.crit = st.crit
		u.mana_regen = st.mana
		u.speed = st.speed
		u.cls = st.cls
		u.sub = st.sub
		u.buffs = []
		u.ab_queued = ""
		u.ab_class = equipped_class_ab(name)
		u.ab_sub = equipped_sub_ab(name)
		u.anim = "idle"
		return

func select_hero(i: int) -> void:
	char_sel = clampi(i, 0, HERO_NAMES.size() - 1)
	char_prev = {}
	char_bar = {}
	char_delta_t = 0.0
	sfx.tone(523, 0.05, "square", 0.03)

func cycle_sub(dir: int) -> void:
	var name := selected_hero()
	char_prev = compute_hero_stats(name)
	var i := SUB_IDS.find(CHAR[name].sub)
	if i < 0:
		i = 0
	CHAR[name].sub = SUB_IDS[(i + dir + SUB_IDS.size()) % SUB_IDS.size()]
	validate_ab_equip(name)
	char_delta_t = 900.0
	save_cfg()
	apply_loadout_preview(name)
	sfx.tone(880 if dir > 0 else 698, 0.045, "triangle", 0.025)

func tick_char_ui(dt: float) -> void:
	if screen != "chars" and screen != "inv":
		return
	if char_delta_t > 0:
		char_delta_t = maxf(0.0, char_delta_t - dt)
	var st := compute_hero_stats(selected_hero())
	var k := minf(1.0, dt / 90.0)
	for key in ["hp", "atk", "def", "armor", "crit", "mana", "speed"]:
		var target := float(st[key])
		if not char_bar.has(key):
			char_bar[key] = target
		else:
			char_bar[key] = float(char_bar[key]) + (target - float(char_bar[key])) * k

func stat_delta(key: String, cur: int) -> int:
	if char_delta_t <= 0 or char_prev.is_empty() or not char_prev.has(key):
		return 0
	return cur - int(char_prev[key])

func draw_stat_bar(x: float, y: float, w: float, h: float, label: String, value: float, vmax: float, shown: String, delta: int, col: Color) -> void:
	var cy: float = y + h * 0.5
	var lab_w: float = 74.0
	text(label, x, cy, 12.0, UI_MUTED, "left")
	var bx: float = x + lab_w
	var bw: float = maxf(50.0, w - lab_w - 64.0)
	var th: float = minf(10.0, h - 6.0)
	rbox(Rect2(bx, cy - th / 2.0, bw, th), th / 2.0, Color(UI_INK.r, UI_INK.g, UI_INK.b, 0.1))
	var fill := clampf(value / maxf(1.0, vmax), 0.0, 1.0)
	if fill > 0.0:
		rbox(Rect2(bx, cy - th / 2.0, maxf(th, bw * fill), th), th / 2.0, col)
	text(shown, bx + bw + 10.0, cy, 14.0, UI_INK, "left")
	if delta != 0:
		var ds := "%+d" % delta
		if shown.ends_with("%"):
			ds += "%"
		var dc: Color = UI_GOOD if delta > 0 else UI_BAD
		dc.a = clampf(char_delta_t / 400.0, 0.0, 1.0)
		text(ds, bx + bw + 10.0 + text_w(shown, 14.0) + 5.0, cy, 13.0, dc, "left")

func draw_hero_sprite(kind: String, x: float, y: float, scl: float) -> void:
	var K: Dictionary = KINDS[kind]
	var idle: Dictionary = K.idle
	var fr := int(floorf(now * idle.fps / 1000.0)) % int(idle.n)
	draw_frame(IMG[K.img], K.f.fw, K.f.fh, fr, idle.r, x, y, K.f.ax, K.f.ay, float(K.f.s) * scl, false)

func draw_chars() -> void:
	var short: bool = VHc <= 430
	var area: Rect2 = menu_sheet("chars_back", "Characters", "Pick a hero, then swap their subclass. Class stays locked.", func(): menu_back())
	var d: Rect2 = hero_picker("hero_", area, short, func(hn, hs): return "Lv." + str(int(hs.level)) + "  " + str(hs.cls) + " · " + str(hs.sub))
	var name := selected_hero()
	var st := compute_hero_stats(name)
	var dx: float = d.position.x
	var dw: float = d.size.x
	var y: float = d.position.y
	y += hero_head(name, st, dx, y, dw, short, [["Lv." + str(int(st.level)), UI_TEAL_L, UI_TEAL_D], ["Focus " + str(st.focus_name), UI_GOLD_L, Color("#7a5208")]]) + (6.0 if short else 10.0)
	# Class (locked) + Subclass (swap) cards
	var card_h: float = 50.0 if short else 74.0
	var gap: float = 10.0
	var stack: bool = dw < 420.0
	var half: float = dw if stack else (dw - gap) / 2.0
	var cr := Rect2(dx, y, half, card_h)
	rbox(cr, 18.0, Color(1, 1, 1, 0.65), UI_LINE, 1.5)
	text("CLASS", cr.position.x + 16.0, cr.position.y + (12.0 if short else 15.0), 11.0, UI_MUTED, "left")
	chip("Locked", cr.end.x - 10.0, cr.position.y + (13.0 if short else 16.0), 10.0, Color(UI_LOCK.r, UI_LOCK.g, UI_LOCK.b, 0.22), UI_MUTED, "right")
	text(str(st.cls), cr.position.x + 16.0, cr.position.y + (33.0 if short else 38.0), 18.0 if short else 22.0, UI_INK, "left")
	if not short:
		var cb: String = str(st.blurb)
		text(cb, cr.position.x + 16.0, cr.position.y + 60.0, fit_size(cb, 11.0, cr.size.x - 28.0, 8.0), UI_MUTED, "left")
	var sr := Rect2(dx + (0.0 if stack else half + gap), y + (card_h + gap if stack else 0.0), half, card_h)
	rbox(sr, 18.0, UI_GOLD_L, UI_GOLD, 2.0)
	var ab: float = 34.0 if short else 40.0
	var aby: float = sr.position.y + (card_h - ab) / 2.0
	pill("sub_l", Rect2(sr.position.x + 8.0, aby, ab, ab), "", "primary", 18.0, func(): cycle_sub(-1), false, false, false, "", "left")
	pill("sub_r", Rect2(sr.end.x - 8.0 - ab, aby, ab, ab), "", "primary", 18.0, func(): cycle_sub(1), false, false, false, "", "right")
	var mid_x: float = sr.get_center().x
	var mid_w: float = sr.size.x - ab * 2.0 - 32.0
	text("SUBCLASS · tap to swap", mid_x, sr.position.y + (12.0 if short else 15.0), 11.0, Color("#8a5f12"))
	text(str(st.sub), mid_x, sr.position.y + (33.0 if short else 38.0), fit_size(str(st.sub), 18.0 if short else 22.0, mid_w, 12.0), UI_INK)
	if not short:
		var sb2: String = str(st.sub_blurb)
		text(sb2, mid_x, sr.position.y + 60.0, fit_size(sb2, 11.0, mid_w, 8.0), Color("#7a5a22"))
	add_btn("sub_n", Rect2(sr.position.x + ab + 12.0, sr.position.y, sr.size.x - ab * 2.0 - 24.0, sr.size.y), func(): cycle_sub(1))
	y += (card_h * 2.0 + gap if stack else card_h) + gap
	# Abilities in battle
	var ar := Rect2(dx, y, dw, 40.0 if short else 50.0)
	rbox(ar, ar.size.y / 2.0, Color(1, 1, 1, 0.65), UI_LINE, 1.5)
	var cn: String = str(ABILITY_DEFS[equipped_class_ab(name)].name) if ABILITY_DEFS.has(equipped_class_ab(name)) else "—"
	var sn: String = str(ABILITY_DEFS[equipped_sub_ab(name)].name) if ABILITY_DEFS.has(equipped_sub_ab(name)) else "—"
	text("IN BATTLE", ar.position.x + 18.0, ar.get_center().y, 11.0, UI_MUTED, "left")
	var cwid: float = chip("Change in Inventory", ar.end.x - 10.0, ar.get_center().y, 11.0, UI_TEAL_L, UI_TEAL_D, "right")
	var ab_line: String = cn + "  +  " + sn
	text(ab_line, ar.position.x + 96.0, ar.get_center().y, fit_size(ab_line, 15.0 if short else 17.0, ar.size.x - 120.0 - cwid, 10.0), UI_INK, "left")
	y += ar.size.y + gap
	# Stats
	var foot: float = 0.0 if short else 18.0
	var sh_h: float = minf(d.end.y - y - foot, (4.0 if dw > 380.0 else 7.0) * (20.0 if short else 24.0) + 12.0)
	draw_stat_block(name, st, Rect2(dx, y, dw, sh_h), short)
	if not short:
		var fl: String = "Defense cuts a % of each hit  ·  Armor blocks a flat amount  ·  MP Regen refills MP each turn"
		text(fl, dx + dw / 2.0, d.end.y - 6.0, fit_size(fl, 11.0, dw, 7.0), UI_MUTED)

func draw_inv() -> void:
	var short: bool = VHc <= 430
	var helper: String = "Tap gear to put it on or take it off." if inv_tab != "abilities" else "Pick 1 class + 1 subclass ability. Mark one for AUTO."
	var area: Rect2 = menu_sheet("inv_back", "Inventory", helper, func(): menu_back(), ["Gear", "Abilities"], 1 if inv_tab == "abilities" else 0, func(i): _set_inv_tab("abilities" if i == 1 else "gear"), "invtab_")
	var d: Rect2 = hero_picker("invhero_", area, short, func(hn, hs): return "Lv." + str(int(hs.level)) + "  " + str(hs.cls))
	var name := selected_hero()
	var st := compute_hero_stats(name)
	var dx: float = d.position.x
	var dw: float = d.size.x
	var y: float = d.position.y
	var xp_txt: String = "MAX level" if int(st.level) >= LEVEL_CAP else ("%d / %d XP" % [int(st.xp), int(st.xp_next)])
	y += hero_head(name, st, dx, y, dw, short, [["Lv." + str(int(st.level)), UI_TEAL_L, UI_TEAL_D], [str(st.cls), Color(UI_INK.r, UI_INK.g, UI_INK.b, 0.08), UI_INK], [xp_txt, Color(UI_INK.r, UI_INK.g, UI_INK.b, 0.08), UI_MUTED]]) + (6.0 if short else 10.0)
	if inv_tab == "abilities":
		draw_inv_abilities(name, dx, y, dw, d.end.y, short)
		return
	# Equipped slots
	var eq: Dictionary = EQUIP[name] if EQUIP.has(name) else {}
	section_label("EQUIPPED  ·  tap to take off", dx, y + 6.0, short)
	y += 16.0 if short else 20.0
	var four: bool = dw >= 470.0
	var gap: float = 8.0
	var sw: float = (dw - gap * 3.0) / 4.0 if four else (dw - gap) / 2.0
	var sh: float = 44.0 if short else 60.0
	for si in SLOT_IDS.size():
		var slot: String = SLOT_IDS[si]
		var iid: String = str(eq.get(slot, ""))
		var filled: bool = iid != "" and ITEM_DEFS.has(iid)
		var col_i: int = si if four else si % 2
		var row_i: int = 0 if four else int(si / 2)
		var rr := Rect2(dx + float(col_i) * (sw + gap), y + float(row_i) * (sh + gap), sw, sh)
		var active: bool = inv_slot_sel == slot
		var down: bool = pressed_id == "slot_" + slot
		if active:
			rbox(rr, 18.0, UI_GOLD_L, UI_GOLD, 2.5)
		elif filled:
			rbox(rr, 18.0, UI_CARD, UI_TEAL if down else Color("#9fd3ce"), 2.0)
		else:
			rbox(rr, 18.0, Color(1, 1, 1, 0.35), UI_LINE, 1.5)
		text(str(SLOT_LABELS[slot]).to_upper(), rr.position.x + 14.0, rr.position.y + (11.0 if short else 14.0), 10.0 if short else 11.0, UI_MUTED, "left")
		var shown: String = str(ITEM_DEFS[iid].name) if filled else "Empty"
		text(shown, rr.position.x + 14.0, rr.position.y + (28.0 if short else 33.0), fit_size(shown, 14.0 if short else 16.0, rr.size.x - 24.0, 10.0), UI_INK if filled else UI_LOCK, "left")
		if not short:
			var bl: String = item_bonus_text(iid) if filled else "Pick from the bag"
			text(bl, rr.position.x + 14.0, rr.position.y + 49.0, fit_size(bl, 11.0, rr.size.x - 24.0, 8.0), UI_TEAL_D if filled else UI_LOCK, "left")
		var slot_id: String = slot
		add_btn("slot_" + slot, rr, func(): _inv_tap_slot(slot_id))
	y += (sh if four else sh * 2.0 + gap) + (8.0 if short else 12.0)
	# Stats block at the bottom
	var stat_h: float = 4.0 * (16.0 if short else 21.0) + 12.0 if dw > 380.0 else 7.0 * 18.0 + 12.0
	var stat_y: float = d.end.y - stat_h
	# Bag
	var bag_lab: String = "BAG  ·  tap to equip"
	if inv_slot_sel != "":
		bag_lab = "BAG  ·  " + str(SLOT_LABELS[inv_slot_sel]) + " items are highlighted"
	section_label(bag_lab, dx, y + 6.0, short)
	y += 16.0 if short else 20.0
	var bag_bottom: float = stat_y - 8.0
	var cols: int = 3 if dw >= 520.0 else 2
	var bw: float = (dw - gap * float(cols - 1)) / float(cols)
	var ih: float = 30.0 if short else 42.0
	if INV.is_empty():
		text("Your bag is empty. Take gear off to put it back here.", dx + dw / 2.0, y + 16.0, 12.0, UI_MUTED)
	else:
		var shown_n := 0
		for bi in INV.size():
			var iid2: String = INV[bi]
			if not ITEM_DEFS.has(iid2):
				continue
			var it: Dictionary = ITEM_DEFS[iid2]
			var cx: float = dx + float(shown_n % cols) * (bw + gap)
			var cy: float = y + float(int(shown_n / cols)) * (ih + 6.0)
			if cy + ih > bag_bottom + 2.0:
				break
			shown_n += 1
			var br := Rect2(cx, cy, bw, ih)
			var match_slot: bool = inv_slot_sel == "" or str(it.slot) == inv_slot_sel
			var hl: bool = inv_slot_sel != "" and match_slot
			save()
			if not match_slot: _alpha *= 0.45
			rbox(br, ih / 2.0, UI_CARD, UI_GOLD if hl else UI_LINE, 2.0 if hl else 1.5)
			var bonus: String = item_bonus_text(iid2)
			if short:
				text(str(it.name), br.position.x + 14.0, br.get_center().y, fit_size(str(it.name), 13.0, br.size.x * 0.5, 9.0), UI_INK, "left")
				text(bonus, br.end.x - 12.0, br.get_center().y, fit_size(bonus, 10.0, br.size.x * 0.45, 7.0), UI_TEAL_D, "right")
			else:
				text(str(it.name), br.position.x + 16.0, br.position.y + 14.0, fit_size(str(it.name), 14.0, br.size.x - 28.0, 9.0), UI_INK, "left")
				var l2: String = str(SLOT_LABELS[str(it.slot)]) + "  ·  " + bonus
				text(l2, br.position.x + 16.0, br.position.y + 30.0, fit_size(l2, 11.0, br.size.x - 28.0, 8.0), UI_TEAL_D, "left")
			restore()
			var bag_index: int = bi
			add_btn("bag_%d" % bi, br, func(): _inv_tap_bag(bag_index))
	draw_stat_block(name, st, Rect2(dx, stat_y, dw, stat_h), short)

func _set_inv_tab(t: String) -> void:
	inv_tab = t
	inv_ab_view = ""
	sfx.tone(587, 0.04, "square", 0.025)

func _inv_tap_slot(slot: String) -> void:
	var name := selected_hero()
	ensure_hero_data()
	var cur: String = str(EQUIP[name].get(slot, ""))
	if cur != "":
		char_prev = compute_hero_stats(name)
		if unequip_slot(name, slot):
			char_delta_t = 900.0
			inv_slot_sel = slot
			sfx.tone(698, 0.045, "triangle", 0.025)
			return
	inv_slot_sel = "" if inv_slot_sel == slot else slot
	sfx.tone(523, 0.04, "square", 0.025)


func _inv_tap_bag(index: int) -> void:
	if index < 0 or index >= INV.size():
		return
	var iid: String = INV[index]
	if not ITEM_DEFS.has(iid):
		return
	var name := selected_hero()
	char_prev = compute_hero_stats(name)
	if equip_item(name, iid):
		inv_slot_sel = str(ITEM_DEFS[iid].slot)
		char_delta_t = 900.0
		sfx.tone(880, 0.045, "triangle", 0.025)
	else:
		sfx.tone(220, 0.05, "square", 0.02)


func draw_party() -> void:
	var short: bool = VHc <= 430
	var area: Rect2 = menu_sheet("party_back", "Party", "Tap a fighter, then a bench hero to swap. Arrows set the order.", func(): menu_back())
	var pnames := party_names()
	var bnames := bench_names()
	var narrow: bool = area.size.x < 560.0
	var col_gap: float = 16.0
	var left_w: float = area.size.x if narrow else (area.size.x - col_gap) * 0.64
	var right_x: float = area.position.x if narrow else area.position.x + left_w + col_gap
	var right_w: float = area.size.x if narrow else area.end.x - right_x
	var lab_h: float = 16.0 if short else 20.0
	section_label("FIGHTING FIVE  ·  #1 leads in the overworld", area.position.x, area.position.y + 6.0, short)
	var list_top: float = area.position.y + lab_h
	var list_bot: float = area.end.y
	var bench_top: float = list_top
	if narrow:
		list_bot = area.position.y + (area.size.y - lab_h) * 0.72
		bench_top = list_bot + lab_h + 6.0
		section_label("BENCH", right_x, list_bot + 12.0, short)
	else:
		section_label("BENCH  ·  sits out, gets half XP on a win", right_x, area.position.y + 6.0, short)
	var rg: float = 5.0 if short else 8.0
	var prow: float = (list_bot - list_top - rg * 4.0) / 5.0
	for i in pnames.size():
		var hn: String = pnames[i]
		var hs := compute_hero_stats(hn)
		var rr := Rect2(area.position.x, list_top + float(i) * (prow + rg), left_w, prow)
		var sel: bool = party_sel == i
		rbox(rr, minf(20.0, prow / 2.0), UI_GOLD_L if sel else UI_CARD, UI_GOLD if sel else UI_LINE, 2.5 if sel else 1.5, 3.0 if sel else 0.0)
		var idx: int = i
		add_btn("pact_%d" % i, rr, func(): _party_tap_active(idx))
		var bcy: float = rr.get_center().y
		if i == 0:
			chip("LEAD", rr.position.x + 10.0, bcy, 10.0 if short else 11.0, UI_GOLD, Color("#3d2706"))
		else:
			draw_circle(Vector2(rr.position.x + 26.0, bcy), 12.0, ca(UI_TEAL_L))
			text(str(i + 1), rr.position.x + 26.0, bcy, 13.0, UI_TEAL_D)
		draw_hero_sprite(hs.kind, rr.position.x + 80.0, rr.end.y - 3.0, 0.34 if short else 0.44)
		var tx: float = rr.position.x + 108.0
		text(hn, tx, bcy - (7.0 if short else 9.0), 15.0 if short else 18.0, UI_INK, "left")
		var line: String = "Lv." + str(int(hs.level)) + "  " + str(hs.cls) + " · " + str(hs.sub)
		var aw: float = minf(prow - 8.0, 38.0)
		text(line, tx, bcy + (9.0 if short else 11.0), fit_size(line, 11.0 if short else 12.0, rr.end.x - tx - aw * 2.0 - 24.0, 8.0), UI_MUTED, "left")
		var ay: float = bcy - aw / 2.0
		pill("pup_%d" % i, Rect2(rr.end.x - aw * 2.0 - 14.0, ay, aw, aw), "", "tealsoft", 15.0, func(): move_party_slot(idx, -1), false, i == 0, false, "", "up")
		pill("pdn_%d" % i, Rect2(rr.end.x - aw - 8.0, ay, aw, aw), "", "tealsoft", 15.0, func(): move_party_slot(idx, 1), false, i >= PARTY_SIZE - 1, false, "", "down")
	var bench_bot: float = area.end.y
	if bnames.is_empty():
		var er := Rect2(right_x, bench_top, right_w, minf(prow, 60.0))
		rbox(er, 18.0, Color(1, 1, 1, 0.35), UI_LINE, 1.5)
		text("No one on the bench.", er.get_center().x, er.get_center().y, 13.0, UI_MUTED)
	else:
		var brow: float = minf(prow, (bench_bot - bench_top - rg * float(bnames.size() - 1)) / float(bnames.size()))
		for j in bnames.size():
			var hn2: String = bnames[j]
			var hs2 := compute_hero_stats(hn2)
			var rr2 := Rect2(right_x, bench_top + float(j) * (brow + rg), right_w, brow)
			var sel2: bool = party_sel == PARTY_SIZE + j
			var swap_hint: bool = party_sel >= 0 and party_sel < PARTY_SIZE
			rbox(rr2, minf(20.0, brow / 2.0), UI_GOLD_L if sel2 else Color(1, 1, 1, 0.7), UI_GOLD if sel2 else (UI_TEAL if swap_hint else UI_LINE), 2.5 if sel2 or swap_hint else 1.5)
			var jdx: int = j
			add_btn("pben_%d" % j, rr2, func(): _party_tap_bench(jdx))
			draw_hero_sprite(hs2.kind, rr2.position.x + 30.0, rr2.end.y - 3.0, 0.34 if short else 0.44)
			var tx2: float = rr2.position.x + 60.0
			text(hn2, tx2, rr2.get_center().y - (7.0 if short else 9.0), 15.0 if short else 18.0, UI_INK, "left")
			var l2: String = "Lv." + str(int(hs2.level)) + "  " + str(hs2.cls)
			text(l2, tx2, rr2.get_center().y + (9.0 if short else 11.0), 11.0 if short else 12.0, UI_MUTED, "left")
			if swap_hint and rr2.size.x > 220.0:
				chip("Tap to swap in", rr2.end.x - 10.0, rr2.get_center().y, 10.0, UI_TEAL_L, UI_TEAL_D, "right")

func _party_tap_active(i: int) -> void:
	ensure_hero_data()
	if party_sel >= PARTY_SIZE:
		var bi := party_sel - PARTY_SIZE
		swap_party_with_bench(i, bi)
		party_sel = i
		return
	party_sel = i
	sfx.tone(523, 0.04, "square", 0.025)


func _party_tap_bench(j: int) -> void:
	ensure_hero_data()
	if party_sel >= 0 and party_sel < PARTY_SIZE:
		swap_party_with_bench(party_sel, j)
		return
	party_sel = PARTY_SIZE + j
	sfx.tone(523, 0.04, "square", 0.025)


func ow_walk_rect() -> Rect2:
	if WORLD != null and WORLD.ok:
		return WORLD.world_rect().grow(-22.0)
	var x0 := float(OW_C0) * 64.0 + 22.0
	var y0 := float(OW_R0) * 64.0 + 22.0
	var x1 := float(OW_C1 + 1) * 64.0 - 22.0
	var y1 := float(OW_R1 + 1) * 64.0 - 22.0
	return Rect2(x0, y0, x1 - x0, y1 - y0)


func ow_blocked_at(x: float, y: float) -> bool:
	var wr := ow_walk_rect()
	if x < wr.position.x or y < wr.position.y or x > wr.position.x + wr.size.x or y > wr.position.y + wr.size.y:
		return true
	if WORLD != null and WORLD.ok and WORLD.blocked_at(x, y):
		return true
	var r := Rect2(x - 10, y - 8, 20, 16)
	for b in OW_BLOCK:
		if r.intersects(b):
			return true
	return false


func ow_add_block(cx: float, cy: float, w: float, h: float) -> void:
	OW_BLOCK.append(Rect2(cx - w / 2.0, cy - h * 0.65, w, h))


func ow_add_tree(x: float, y: float, scl: float, ph: int) -> void:
	OW_PROPS.append({"kind": "tree", "x": x, "y": y, "s": scl, "ph": ph, "fw": 192.0, "fh": 192.0, "n": 4, "ax": 96.0, "ay": 178.0, "img": "tree", "fps": 6.0})
	ow_add_block(x, y, 22 * scl / 0.6, 16 * scl / 0.6)


var ow_warp := "" # area id from ?warp= (debug / preview), consumed by build_overworld
var OW_K := 1.0 # town decor spacing scale (world.json town_scale) for the larger tile layout

func ow_add_house(x0: float, y0: float, scl: float, flip := false) -> void:
	var x: float = x0 * OW_K
	var y: float = y0 * OW_K
	OW_PROPS.append({"kind": "house", "x": x, "y": y, "s": scl, "ph": 0, "fw": 128.0, "fh": 192.0, "n": 1, "ax": 64.0, "ay": 171.0, "img": "ghouse", "flip": flip, "fps": 1.0})
	ow_add_block(x, y + 2, 70 * scl, 36 * scl)


func ow_add_tower(x0: float, y0: float, scl: float) -> void:
	var x: float = x0 * OW_K
	var y: float = y0 * OW_K
	OW_PROPS.append({"kind": "tower", "x": x, "y": y, "s": scl, "ph": 0, "fw": 128.0, "fh": 256.0, "n": 1, "ax": 64.0, "ay": 235.0, "img": "tower", "fps": 1.0})
	ow_add_block(x, y + 2, 48 * scl / 0.7, 30 * scl / 0.7)


func ow_add_rock(x0: float, y0: float, which: String, block := true) -> void:
	var x: float = x0 * OW_K
	var y: float = y0 * OW_K
	OW_PROPS.append({"kind": "rock", "x": x, "y": y, "s": 1.0, "ph": 0, "fw": 128.0, "fh": 128.0, "n": 8, "ax": 64.0, "ay": 72.0, "img": which, "fps": 7.0})
	if block:
		ow_add_block(x, y, 36, 22)


func ow_add_deco(id: String, x0: float, y0: float, block := false) -> void:
	var x: float = x0 * OW_K
	var y: float = y0 * OW_K
	OW_DECO.append([id, x, y])
	if block:
		ow_add_block(x, y, 22, 16)


func build_overworld() -> void:
	OW_K = float(WORLD.data.get("town_scale", 1.0)) if WORLD != null and WORLD.ok else 1.0
	OW_BLOCK = []
	OW_PROPS = []
	OW_DECO = []
	OW_SHEEP = []
	# Houses and the lookout — a small hamlet, not a Nintendo layout.
	ow_add_house(300, 280, 0.88)
	ow_add_house(540, 250, 0.84, true)
	ow_add_house(270, 470, 0.9)
	ow_add_tower(900, 270, 0.72)
	if OW_K > 1.0:
		# The bigger Rivenbrook gets a few more cottages so the town isn't an empty field.
		for hp in [[720, 420, 0.86, false], [880, 600, 0.82, true], [500, 700, 0.88, false], [150, 330, 0.84, true], [980, 740, 0.8, false], [660, 170, 0.8, true], [160, 640, 0.86, false]]:
			ow_add_house(float(hp[0]), float(hp[1]), float(hp[2]), bool(hp[3]))
		for dd in [["01", 740, 470], ["13", 900, 650], ["02", 520, 750], ["10", 180, 380], ["12", 1000, 790], ["11", 690, 220], ["03", 190, 690]]:
			ow_add_deco(str(dd[0]), float(dd[1]), float(dd[2]), false)
	# Yard "fences" of stones in front of cottages and a small sheep pasture.
	for t in [[340, 330], [372, 332], [404, 330], [500, 300], [532, 302], [564, 300], [250, 520], [282, 522], [314, 520], [250, 552], [314, 552], [220, 700], [252, 702], [284, 700], [316, 702], [348, 700], [220, 760], [348, 760], [220, 728], [348, 728]]:
		ow_add_deco("04" if int(t[0] + t[1]) % 2 == 0 else "05", t[0], t[1], true)
	# Trees, roads, wild grass and the wider region come from res://data/world_map.txt (world.gd).
	# East road out: keep a 2-tile corridor around y=500-560, x=900-1040 clear of trees (already omitted). Line it with bushes.
	for bx in [860, 900, 940, 980, 1020]:
		ow_add_deco("08", bx, 470, false)
		ow_add_deco("07", bx + 16, 590, false)
	# Gardens and path dressings
	for d in [["01", 360, 360], ["02", 390, 350], ["03", 580, 330], ["10", 450, 400], ["11", 470, 620], ["12", 320, 560], ["13", 360, 580], ["09", 620, 700], ["08", 200, 600], ["14", 780, 360], ["02", 820, 400], ["01", 760, 240], ["11", 640, 360], ["10", 480, 520]]:
		ow_add_deco(d[0], float(d[1]), float(d[2]), false)
	# A couple of rock piles near the shore road and the north grove
	ow_add_rock(820, 640, "rocks1", true)
	ow_add_rock(200, 240, "rocks3", true)
	ow_add_rock(980, 500, "rocks1", false)
	OW_SHEEP = [
		{"x": 270 * OW_K, "y": 730 * OW_K, "ph": 0, "flip": false},
		{"x": 320 * OW_K, "y": 748 * OW_K, "ph": 3, "flip": true},
	]
	# Start in the central plaza if new, otherwise keep a still-valid spot.
	var start: Vector2 = WORLD.start_pos() if WORLD != null and WORLD.ok else Vector2(640, 520)
	if not ow_ready or ow_blocked_at(ow_x, ow_y):
		ow_x = start.x
		ow_y = start.y
	if ow_warp != "" and WORLD != null and WORLD.ok:
		var wp: Vector2 = WORLD.spawn_pos(ow_warp)
		ow_x = wp.x
		ow_y = wp.y
		ow_warp = ""
	ow_tx = ow_x
	ow_ty = ow_y
	ow_anim = "idle"
	ow_at = 0.0
	ow_camx = ow_x
	ow_camy = ow_y
	ow_moving = false
	ow_ready = true


func ow_tap(p: Vector2) -> void:
	var world := Vector2((p.x - VWc / 2.0) / ow_scale + ow_camx, (p.y - VHc / 2.0) / ow_scale + ow_camy)
	# If the exact spot is blocked, walk as close as we can on the way there.
	ow_tx = world.x
	ow_ty = world.y
	# Clamp destination to the walkable island, even if it's inside a building (movement will slide/stop).
	var wr := ow_walk_rect()
	ow_tx = clampf(ow_tx, wr.position.x, wr.position.x + wr.size.x)
	ow_ty = clampf(ow_ty, wr.position.y, wr.position.y + wr.size.y)
	sfx.tone(440, 0.03, "square", 0.015)


func tick_overworld(dt: float) -> void:
	if screen != "overworld":
		return
	ow_at += dt
	if ow_menu_open:
		ow_tx = ow_x
		ow_ty = ow_y
	var sp := 200.0 * dt / 1000.0
	var dx: float = ow_tx - ow_x
	var dy: float = ow_ty - ow_y
	var dist := sqrt(dx * dx + dy * dy)
	if dist <= sp + 0.6:
		ow_x = ow_tx
		ow_y = ow_ty
		ow_moving = false
		ow_anim = "idle"
	else:
		var nx: float = ow_x + dx / dist * sp
		var ny: float = ow_y + dy / dist * sp
		var moved := false
		if not ow_blocked_at(nx, ny):
			ow_x = nx
			ow_y = ny
			moved = true
		elif absf(nx - ow_x) > 0.05 and not ow_blocked_at(nx, ow_y):
			ow_x = nx
			moved = true
			# sliding: cancel the blocked axis of the destination so we don't jitter
			if ow_blocked_at(ow_x, ow_y + (1 if dy > 0 else -1) * 2):
				ow_ty = ow_y
		elif absf(ny - ow_y) > 0.05 and not ow_blocked_at(ow_x, ny):
			ow_y = ny
			moved = true
			if ow_blocked_at(ow_x + (1 if dx > 0 else -1) * 2, ow_y):
				ow_tx = ow_x
		else:
			var gid: String = WORLD.blocking_gate_near(ow_x, ow_y, ow_tx, ow_ty)
			if gid != "":
				var gd: Dictionary = WORLD.gates.get(gid, {})
				WORLD.show_toast(str(gd.get("locked_text", "The way is blocked.")))
			ow_tx = ow_x
			ow_ty = ow_y
			moved = false
		ow_moving = moved
		ow_anim = "run" if moved else "idle"
		if absf(dx) > 1:
			ow_facing = 1 if dx > 0 else -1
	# Smooth camera, clamped to the town plus a little water.
	var wantx := ow_x
	var wanty := ow_y
	ow_camx += (wantx - ow_camx) * minf(1.0, dt / 110.0)
	ow_camy += (wanty - ow_camy) * minf(1.0, dt / 110.0)
	var vis_w: float = VWc / maxf(0.2, ow_scale)
	var vis_h: float = VHc / maxf(0.2, ow_scale)
	var map_x0 := 0.0
	var map_y0 := 0.0
	var map_x1 := float(OW_C1 + 2) * 64.0
	var map_y1 := float(OW_R1 + 2) * 64.0
	if WORLD != null and WORLD.ok:
		map_x1 = float(WORLD.W) * 64.0
		map_y1 = float(WORLD.H) * 64.0
	var wev: Dictionary = WORLD.tick(ow_x, ow_y, dt, ow_moving)
	if wev.has("encounter"):
		start_encounter(wev.encounter)
		return
	var min_cx := map_x0 + vis_w / 2.0
	var max_cx := map_x1 - vis_w / 2.0
	var min_cy := map_y0 + vis_h / 2.0
	var max_cy := map_y1 - vis_h / 2.0
	if min_cx > max_cx:
		ow_camx = (map_x0 + map_x1) / 2.0
	else:
		ow_camx = clampf(ow_camx, min_cx, max_cx)
	if min_cy > max_cy:
		ow_camy = (map_y0 + map_y1) / 2.0
	else:
		ow_camy = clampf(ow_camy, min_cy, max_cy)


func draw_overworld() -> void:
	# Water backdrop and a grass island with foam, houses, and a road out to the east.
	draw_rect(Rect2(0, 0, VWc, VHc), Color("#47aba9"))
	var short := VHc <= 430
	# Fit a readable chunk of town; keep the lead easy to see on a short landscape screen.
	# Zoomed out vs the first town build (was 460/560 tall, 0.7–1.35) so more of the region shows.
	var show_h := 600.0 if short else 720.0
	var show_w := show_h * (VWc / maxf(1.0, VHc))
	ow_scale = minf(VWc / show_w, VHc / show_h)
	ow_scale = clampf(ow_scale, 0.55, 1.1)
	var base := Transform2D(Vector2(dpr, 0), Vector2(0, dpr), Vector2.ZERO)
	var cam := Transform2D(Vector2(ow_scale, 0), Vector2(0, ow_scale), Vector2(VWc / 2.0 - ow_camx * ow_scale, VHc / 2.0 - ow_camy * ow_scale))
	set_xf(base * cam)
	var vis_w2: float = VWc / ow_scale
	var vis_h2: float = VHc / ow_scale
	var view := Rect2(ow_camx - vis_w2 / 2.0, ow_camy - vis_h2 / 2.0, vis_w2, vis_h2)
	WORLD.draw_ground(self, view, now)
	# Ground decorations (mushrooms, bushes, stones) under characters
	for d in OW_DECO:
		var im: Texture2D = IMG["deco" + str(d[0])]
		img(im, 0, 0, 64, 64, float(d[1]) - 32, float(d[2]) - 54, 64, 64)
	# Destination marker
	if ow_moving or absf(ow_tx - ow_x) + absf(ow_ty - ow_y) > 2:
		save(); _alpha *= 0.45 + 0.2 * sin(now / 160.0)
		stroke_ellipse(ow_tx, ow_ty - 2, 12, 6, Color("#ffe27a"), 2)
		restore()
	# Y-sort props, sheep, and the lead
	var list := []
	for p in OW_PROPS:
		list.append([float(p.y), 0, p])
	for wp in WORLD.visible_props(view):
		list.append([float(wp.y), 0, wp])
	for sh in OW_SHEEP:
		list.append([float(sh.y), 1, sh])
	list.append([ow_y, 2, {}])
	list.sort_custom(func(a, b): return a[0] < b[0])
	for o in list:
		if o[1] == 0:
			var p: Dictionary = o[2]
			var fr: int = 0
			if int(p.n) > 1:
				fr = (int(floorf(now / (1000.0 / float(p.get("fps", 6.0))))) + int(p.ph)) % int(p.n)
			draw_frame(IMG[p.img], p.fw, p.fh, fr, 0, p.x, p.y, p.ax, p.ay, p.s, p.get("flip", false), 1.0, p.get("mod", Color.WHITE))
		elif o[1] == 1:
			var sh: Dictionary = o[2]
			var sfr := (int(floorf(now / 125.0)) + int(sh.ph)) % 8
			draw_frame(IMG.sheep, 128, 128, sfr, 0, sh.x, sh.y, 64, 86, 0.62, sh.flip)
		else:
			_draw_ow_lead()
			WORLD.draw_grass_over(self, ow_x, ow_y, now)
	set_xf(base)
	if screen != "overworld":
		return
	# UI
	var bh := 42.0 if short else 48.0
	var mw := 118.0 if short else 130.0
	pill("ow_menu", Rect2(10, 8, mw, bh), "Menu", "primary", 17, func(): ow_menu_open = not ow_menu_open)
	pill("ow_map", Rect2(10, 8 + bh + 8, mw, bh), "Map", "soft", 17, func(): ow_open_menu_screen("map"))
	var here: String = WORLD.area_name(WORLD.cur_area) if WORLD.cur_area != "" else TOWN_NAME
	var hfs: float = 17.0 if short else 20.0
	var hw: float = minf(VWc * 0.46, maxf(180.0, text_w(here, hfs) + 48.0))
	var hh: float = bh - 6.0
	rbox(Rect2(VWc / 2 - hw / 2, 8, hw, hh), hh / 2.0, Color(UI_SHEET.r, UI_SHEET.g, UI_SHEET.b, 0.94), Color(1, 1, 1, 0.6), 2.0, 6.0)
	text(here, VWc / 2, 8 + hh / 2.0, fit_size(here, hfs, hw - 28.0, 11.0), UI_INK)
	if WORLD.cur_area != "":
		chip(("%s  ·  " % WORLD.cur_zone if WORLD.cur_zone != "" else "") + "Recommended " + WORLD.rec_text(WORLD.cur_area), VWc / 2, 8 + hh + 16, 11.0 if short else 12.0, Color(0.06, 0.14, 0.15, 0.72), Color("#ffe6a8"), "center")
	var lead := lead_name()
	var st := compute_hero_stats(lead)
	chip(lead + "  ·  Lv." + str(int(st.level)) + "  " + st.cls, VWc - 10, 8 + hh / 2.0, 12.0 if short else 13.0, Color(0.06, 0.14, 0.15, 0.72), Color.WHITE, "right")
	var wild_now: bool = WORLD.in_wild(ow_x, ow_y)
	var hint := "Tap the ground to walk" if short else "Tap a spot to walk there  ·  your lead hero explores"
	if wild_now:
		hint = "Wild grass  ·  monsters may jump out"
	chip(hint, VWc / 2, VHc - (16 if short else 22), 12.0 if short else 13.0, Color(0.06, 0.14, 0.15, 0.72), Color("#c8ffb0") if wild_now else Color.WHITE, "center")
	WORLD.draw_hud(self, VWc, VHc)
	if ow_menu_open:
		_draw_ow_menu(short)


func _draw_ow_menu(short: bool) -> void:
	draw_rect(Rect2(0, 0, VWc, VHc), Color(0.02, 0.08, 0.09, 0.5))
	var items := [
		["owm_map", "Map", "Where to go next", "map"], ["owm_party", "Party", "Pick your five", "party"],
		["owm_inv", "Inventory", "Gear and abilities", "inv"], ["owm_stats", "Stats", "Compare heroes", "stats"],
		["owm_chars", "Characters", "Swap subclasses", "chars"], ["owm_title", "Title", "Main screen", "title"],
	]
	var cols: int = 2 if VWc < 700 else 3
	var gap: float = 10.0 if short else 14.0
	var bw: float = minf(220.0, (VWc - 70.0 - gap * float(cols - 1)) / float(cols))
	var bh: float = 54.0 if short else 66.0
	var rows: int = int(ceil(float(items.size()) / float(cols)))
	var pad: float = 18.0 if short else 24.0
	var head: float = 40.0 if short else 52.0
	var pw: float = float(cols) * bw + float(cols - 1) * gap + pad * 2.0
	var ph: float = head + float(rows) * bh + float(rows - 1) * gap + pad * 2.0
	var px: float = VWc / 2.0 - pw / 2.0
	var py: float = VHc / 2.0 - ph / 2.0
	add_btn("owm_bg", Rect2(0, 0, VWc, VHc), func(): ow_menu_open = false)
	rbox(Rect2(px, py, pw, ph), 30.0, UI_SHEET, Color(1, 1, 1, 0.6), 2.0, 14.0)
	add_btn("owm_panel", Rect2(px, py, pw, ph), func(): pass)
	text("Menu", px + pad + 2.0, py + pad + head * 0.32, 22.0 if short else 27.0, UI_INK, "left")
	var cs: float = 34.0 if short else 38.0
	pill("owm_close", Rect2(px + pw - pad - cs, py + pad + head * 0.32 - cs / 2.0, cs, cs), "×", "soft", 20.0, func(): ow_menu_open = false)
	var y0: float = py + pad + head
	for i in items.size():
		var it: Array = items[i]
		var cx: float = px + pad + float(i % cols) * (bw + gap)
		var cy: float = y0 + float(i / cols) * (bh + gap)
		var which: String = it[3]
		if which == "title":
			pill(it[0], Rect2(cx, cy, bw, bh), it[1], "danger", 17.0 if short else 19.0, func(): to_title(), false, false, false, it[2])
		else:
			pill(it[0], Rect2(cx, cy, bw, bh), it[1], "primary" if which == "map" else "soft", 17.0 if short else 19.0, func(): ow_open_menu_screen(which), false, false, false, it[2])

func _draw_ow_lead() -> void:
	var name := lead_name()
	var st := compute_hero_stats(name)
	var kind: String = st.kind
	if not KINDS.has(kind):
		kind = "warrior"
	var K: Dictionary = KINDS[kind]
	var anim: Dictionary = K.run if ow_anim == "run" else K.idle
	var fr := int(floorf(ow_at * float(anim.fps) / 1000.0)) % int(anim.n)
	var scl: float = float(K.f.s) * 0.95
	draw_frame(IMG[K.img], K.f.fw, K.f.fh, fr, anim.r, ow_x, ow_y, K.f.ax, K.f.ay, scl, ow_facing < 0)
	# Soft name tag so the lead stays readable
	text(name, ow_x, ow_y - K.head * scl - 8, 11, Color("#d6f1ff"), "center", 3, Color(0, 0, 0, 0.75))


func draw_title() -> void:
	draw_rect(Rect2(0, 0, VWc, VHc), Color(10 / 255.0, 25 / 255.0, 28 / 255.0, 0.5))
	var short := VHc <= 430
	var vw := VWc
	var L := clampf3(32, VHc * 0.09, 64) if short else clampf3(46, vw * 0.135, 108)
	var pad: float = 14.0 if short else 20.0
	var sw: float = minf(680.0, vw - 24.0)
	var mbh: float = 46.0 if short else 58.0
	var rbh: float = 50.0 if short else 62.0
	var gap: float = 10.0
	var lab_h: float = 18.0 if short else 24.0
	var menu_one_row: bool = sw >= 5.0 * 112.0 + 4.0 * gap + pad * 2.0
	var menu_rows: int = 1 if menu_one_row else 2
	var raid_one_row: bool = sw >= 3.0 * 130.0 + 2.0 * gap + pad * 2.0
	var raid_rows: int = 1 if raid_one_row else 2
	var sheet_h: float = pad * 2.0 + lab_h * 2.0 + float(menu_rows) * (mbh + gap) + float(raid_rows) * (rbh + gap) + 2.0
	var tag_h: float = 0.0 if short else 40.0
	var hint_fs: float = clampf3(12, vw * 0.03, 15)
	var hint_h: float = 0.0 if short else hint_fs * 2.2
	var total: float = L + 10.0 + tag_h + sheet_h + hint_h
	var y: float = maxf(8.0, (VHc - total) / 2.0 - (14.0 if USE_NECRO else 6.0))
	var cx := VWc / 2
	# logo with layered text-shadow and bob
	var bob := -3.0 + 3.0 * cos(now / 2400.0 * TAU)
	var ly := y + L / 2 + bob
	var logo := "RIFTSTRIKE"
	text(logo, cx, ly + L * 0.12 + L * 0.06, L, Color(0, 0, 0, 0.45))
	text(logo, cx, ly + L * 0.09, L, Color("#4a2a14"), "center", L * 0.06, Color("#4a2a14"))
	text(logo, cx, ly + L * 0.05, L, Color("#b5641f"), "center", L * 0.06, Color("#2b1a10"))
	text(logo, cx, ly, L, Color("#ffe27a"), "center", L * 0.06, Color("#2b1a10"))
	y += L + 10.0
	if not short:
		chip("Turn-based rift brawl", cx, y + 14.0, 15.0, Color(1, 1, 1, 0.88), UI_INK, "center")
		y += tag_h
	# One soft sheet holding the menus and the quick raids
	var sr := Rect2(cx - sw / 2.0, y, sw, sheet_h)
	rbox(sr, 28.0, Color(UI_SHEET.r, UI_SHEET.g, UI_SHEET.b, 0.95), Color(1, 1, 1, 0.6), 2.0, 12.0)
	var iy: float = sr.position.y + pad
	var ix: float = sr.position.x + pad
	var iw: float = sw - pad * 2.0
	section_label("AIRRON'S SQUAD", ix, iy + lab_h * 0.4, short)
	iy += lab_h
	var menus := [
		["chars", "Characters", "soft", func(): open_chars()],
		["inv", "Inventory", "soft", func(): open_inv()],
		["party", "Party", "soft", func(): open_party()],
		["cmp", "Compendium", "soft", func(): open_compendium()],
		["ow", "Overworld", "primary", func(): open_overworld()],
	]
	var mfs: float = 15.0 if short else 18.0
	var row_counts: Array = [menus.size()] if menu_one_row else [3, menus.size() - 3]
	var mi: int = 0
	for ri in row_counts.size():
		var per: int = int(row_counts[ri])
		var mw: float = (iw - gap * float(per - 1)) / float(per)
		for ci in per:
			var m: Array = menus[mi]
			pill(m[0], Rect2(ix + float(ci) * (mw + gap), iy + float(ri) * (mbh + gap), mw, mbh), m[1], m[2], mfs, m[3])
			mi += 1
	iy += float(menu_rows) * (mbh + gap)
	section_label("QUICK RAID  ·  pick a fight", ix, iy + lab_h * 0.4, short)
	iy += lab_h
	var specs := [["raid3", "6v3 Raid", "tealsoft", 3], ["raid2", "6v2 Elite", "primary", 2], ["raid1", "6v1 Boss", "danger", 1]]
	var bfs: float = 16.0 if short else 20.0
	if raid_one_row:
		var rw: float = (iw - gap * 2.0) / 3.0
		for i in specs.size():
			var sp: Array = specs[i]
			var n: int = sp[3]
			pill(sp[0], Rect2(ix + float(i) * (rw + gap), iy, rw, rbh), sp[1], sp[2], bfs, func(): start_fight(n), false, false, sp[0] == "raid1")
	else:
		var rw2: float = (iw - gap) / 2.0
		for i in specs.size():
			var sp2: Array = specs[i]
			var n2: int = sp2[3]
			var r2: Rect2 = Rect2(ix + float(i % 2) * (rw2 + gap), iy + float(int(i / 2)) * (rbh + gap), rw2, rbh)
			if i == 2: r2 = Rect2(ix, iy + rbh + gap, iw, rbh)
			pill(sp2[0], r2, sp2[1], sp2[2], bfs, func(): start_fight(n2), false, false, sp2[0] == "raid1")
	y = sr.end.y + 10.0
	if not short:
		var hint: String = "Overworld explores Act I  ·  Raids are quick fights  ·  Hits that land together COMBO"
		text(hint, cx, y + hint_fs * 0.6, fit_size(hint, hint_fs, vw - 24.0, 10.0), Color("#e9fff9"), "center", 3, Color(0, 0, 0, 0.7))
	var cfs := 12.0 if short else 14.0
	var cy := VHc - (4.0 if short else 10.0) - cfs
	if USE_NECRO:
		link_text("Art: ", "Tiny Swords by Pixel Frog", "", URL_TINY, cx, cy - cfs * 1.6, cfs, Color.WHITE, Color("#ffe27a"), true, "cr1")
		link_text("Boss: ", "Necromancer by CreativeKind", "", URL_NECRO, cx, cy, cfs, Color.WHITE, Color("#ffe27a"), true, "cr2")
	else:
		link_text("Art: ", "Tiny Swords by Pixel Frog", "", URL_TINY, cx, cy, cfs, Color.WHITE, Color("#ffe27a"), true, "cr1")

func fmt_n(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out

func ease_out_back(k: float) -> float:
	var c1 := 1.70158 * 1.4
	var c3 := c1 + 1
	return 1 + c3 * pow(k - 1, 3) + c1 * pow(k - 1, 2)

func draw_results() -> void:
	draw_rect(Rect2(0, 0, VWc, VHc), Color(8 / 255.0, 20 / 255.0, 22 / 255.0, 0.5))
	var short := VHc <= 430
	var vw := VWc
	var pw := minf(560, vw * 0.94)
	var b := 24.0 if short else 32.0
	var inner := pw - 2 * b - 24
	var title_h := 48.0 if short else 60.0
	var title_fs := clampf3(26, vw * 0.08, 34)
	var sub_fs := clampf3(14, vw * 0.04, 17)
	var st_fs := clampf3(13, vw * 0.037, 16)
	var lh := st_fs * (1.35 if short else 1.55)
	var lines := []
	for seglist in res.lines:
		var words := []
		for seg in seglist:
			var parts: PackedStringArray = seg[0].split(" ")
			for i in parts.size():
				words.append([parts[i] + (" " if i < parts.size() - 1 else ""), seg[1]])
		var cur := []
		var cw := 0.0
		for wd in words:
			var ww := text_w(wd[0], st_fs)
			if cw + ww > inner and cur.size() > 0:
				lines.append([cur, cw]); cur = []; cw = 0.0
			cur.append([wd[0], wd[1], ww]); cw += ww
		lines.append([cur, cw])
	var btn_h := 56.0
	var rw := minf(220, vw * 0.6)
	var tw := minf(170, vw * 0.38)
	var btn_rows := 1 if rw + tw + 10 <= inner + 24 else 2
	var cred_lines := 2 if (USE_NECRO and res.n_red == 1) else 1
	var ch := 8 + title_h + (2 if short else 6) + sub_fs * 1.25 + (4 if short else 8) + lines.size() * lh + (8 if short else 14) + btn_rows * btn_h + (btn_rows - 1) * 10 + (4 if short else 10) + cred_lines * 16 + 10
	var ph := ch + 2 * b
	var k := minf(1.0, results_t / 280.0)
	var s := 0.6 + 0.4 * ease_out_back(k)
	var cx := VWc / 2
	var top := (VHc - ph) / 2
	save(); _alpha *= minf(1.0, k * 1.6)
	tr_(cx, VHc / 2); scale_by(s, s); tr_(-cx, -VHc / 2)
	rbox(Rect2(cx - pw / 2, top, pw, ph), 30.0, UI_SHEET, Color(1, 1, 1, 0.6), 2.0, 14.0)
	var y := top + b + 8
	var tcol: Color = UI_TEAL if res.result == "win" else (UI_CORAL if res.result == "lose" else UI_GOLD)
	var tw2: float = maxf(minf(300, vw * 0.6), text_w(res.title, title_fs) + 60.0)
	rbox(Rect2(cx - tw2 / 2.0, y, tw2, title_h - 6), (title_h - 6) / 2.0, tcol, Color(0, 0, 0, 0), 0.0, 4.0)
	text(res.title, cx, y + (title_h - 6) / 2.0, title_fs, Color.WHITE)
	y += title_h + (2 if short else 6)
	text(res.sub, cx, y + sub_fs * 0.62, sub_fs, Color("#4a2d16"))
	y += sub_fs * 1.25 + (4 if short else 8)
	for ln in lines:
		var x: float = cx - ln[1] / 2
		for wd in ln[0]:
			text(wd[0], x, y + lh / 2, st_fs, wd[1], "left")
			x += wd[2]
		y += lh
	y += 8 if short else 14
	if btn_rows == 1:
		var bx := cx - (rw + tw + 10) / 2
		pill("retry", Rect2(bx, y, rw, btn_h), "Continue" if not encounter.is_empty() else "Retry", "primary", 22, func(): results_primary())
		pill("menu", Rect2(bx + rw + 10, y, tw, btn_h), "Title", "soft", 22, func(): results_title())
		y += btn_h
	else:
		pill("retry", Rect2(cx - rw / 2, y, rw, btn_h), "Continue" if not encounter.is_empty() else "Retry", "primary", 22, func(): results_primary())
		y += btn_h + 10
		pill("menu", Rect2(cx - tw / 2, y, tw, btn_h), "Title", "soft", 22, func(): results_title())
		y += btn_h
	y += (4 if short else 10) + 8
	link_text("Art: ", "Tiny Swords by Pixel Frog", "", URL_TINY, cx, y, 12, UI_MUTED, UI_TEAL_D, false, "cr1")
	if cred_lines == 2:
		link_text("Boss: ", "Necromancer by CreativeKind", "", URL_NECRO, cx, y + 16, 12, UI_MUTED, UI_TEAL_D, false, "cr2")
	restore()

func sq_button(id: String, r: Rect2, label: String, cb: Callable, icon := false, off := false, paused_icon := false) -> void:
	var down := pressed_id == id
	img(IMG.sqP if down else IMG.sq, 0, 0, 64, 64, r.position.x, r.position.y, r.size.x, r.size.y)
	var c := r.get_center() + Vector2(0, 0 if down else -3)
	if icon:
		save(); _alpha *= 0.35 if off else 1.0
		img(IMG.sound, 0, 0, 64, 64, c.x - 17, c.y - 17, 34, 34, Color(2.2, 2.2, 2.2, 1))
		restore()
	elif paused_icon:
		var pts := PackedVector2Array([c + Vector2(-6, -8), c + Vector2(8, 0), c + Vector2(-6, 8)])
		draw_colored_polygon(PackedVector2Array([pts[0] + Vector2(1, 1), pts[1] + Vector2(1, 1), pts[2] + Vector2(1, 1)]), Color.BLACK)
		draw_colored_polygon(pts, Color.WHITE)
	else:
		shadow_text(label, c.x, c.y, 18, Color.WHITE, 1.0, Color.BLACK)
	add_btn(id, r, cb)

func draw_battle_ui() -> void:
	var short_land := VHc <= 520 and VWc > VHc
	var s := 46.0
	var pos := []
	if short_land:
		for i in 3: pos.append(Vector2(8 + i * (s + 6), VHc - 6 - s))
	else:
		for i in 3: pos.append(Vector2(VWc - 6 - s, 64 + SAFE_T + i * (s + 6)))
	sq_button("speed", Rect2(pos[0], Vector2(s, s)), "%dx" % speed, toggle_speed)
	sq_button("pause", Rect2(pos[1], Vector2(s, s)), "II", toggle_pause, false, false, paused)
	sq_button("mute", Rect2(pos[2], Vector2(s, s)), "", toggle_mute, true, muted)
	# RUN — always available during a fight (wild: back to the overworld spot; raid: back to title).
	var run_w := 108.0 if short_land else 124.0
	var run_h := 42.0 if short_land else 48.0
	var hud_w := minf(300, (VWc - 96) / 2)
	var hud_h := roundf(minf(44, maxf(34, hud_w / 6.5)))
	var run_y := 6 + SAFE_T + hud_h + 22
	var auto_w := 116.0 if short_land else 132.0
	var pair_w: float = run_w + 10.0 + auto_w
	var run_x: float = VWc / 2 - pair_w / 2
	pill("run", Rect2(run_x, run_y, run_w, run_h), "RUN", "danger", 17.0 if short_land else 19.0, func(): run_battle())
	pill("auto", Rect2(run_x + run_w + 10.0, run_y, auto_w, run_h), "AUTO ON" if AUTO else "AUTO", "gold" if AUTO else "soft", 16.0 if short_land else 18.0, func(): toggle_auto(), false, false, AUTO)
	var sel := G != null and phase == "battle" and G.mode == "select"
	var n := G.queue.size() if sel else 0
	var liv := alive("blue").size() if G != null else 0
	var narrow := VWc <= 400
	var bh := 50.0 if short_land else 60.0
	var cw := 96.0 if short_land else minf(120, VWc * 0.24)
	var ew := 200.0 if short_land else minf(250, VWc * 0.46)
	var cfs := 15.0 if short_land else (14.0 if narrow else 17.0)
	var efs := 18.0 if short_land else (17.0 if narrow else 21.0)
	var ccap := 18.0 if narrow else 22.0
	var ecap := 24.0 if narrow else 30.0
	var row_w := cw * 2 + ew + 16
	var by := VHc - (4.0 if short_land else 6.0) - bh
	var bx := VWc - 8 - row_w if short_land else (VWc - row_w) / 2
	var locked := not sel
	ui_button("clear", Rect2(bx, by, cw, bh), "CLEAR", true, cfs, ccap, clear_queue, n == 0, locked)
	ui_button("exec", Rect2(bx + cw + 8, by, ew, bh), ("EXECUTE %d" % n) if n > 0 else "EXECUTE", false, efs, ecap, execute_orders, n == 0, locked)
	ui_button("all", Rect2(bx + cw + ew + 16, by, cw, bh), "ALL", false, cfs, ccap, queue_all, not sel or n == liv, locked)
	var hint := ""
	var hint_base: float = by
	if sel and n > 0 and not AUTO:
		hint_base = draw_ability_panel(short_land, by) - 4
	if G != null and phase == "battle":
		if AUTO: hint = "Auto-battle on · tap AUTO to take control"
		elif sel: hint = "Tap again to remove · full MP bar = ability" if n > 0 else "Tap your knights in attack order · or tap AUTO"
		else: hint = "Your knights are attacking…" if G.side == "blue" else "Goblins are attacking…"
	if hint != "":
		var hfs := 12.0 if short_land else 14.0
		var hy := hint_base - 2 - 9
		if short_land: text(hint, VWc - 8, hy, hfs, Color.WHITE, "right", 3, Color(0, 0, 0, 0.85))
		else: text(hint, VWc / 2, hy, hfs, Color.WHITE, "center", 3, Color(0, 0, 0, 0.85))
	if paused:
		var pfs := clampf3(36, VWc * 0.1, 56)
		text("PAUSED", VWc / 2 + 3, VHc * 0.42 + pfs / 2 + 4, pfs, Color.BLACK, "center", 4, Color.BLACK)
		text("PAUSED", VWc / 2, VHc * 0.42 + pfs / 2, pfs, Color.WHITE, "center", 4, Color.BLACK)

# ---------------------------------------------------------------- ability UI
var inv_tab := "gear" # gear | abilities
var inv_ab_view := ""

func draw_cast_banner() -> void:
	if cast_banner == null or phase == "title":
		return
	var k: float = cast_banner.t / cast_banner.life
	var al: float = 1.0 - (k - 0.8) / 0.2 if k > 0.8 else 1.0
	var sc: float = 1.35 - k / 0.1 * 0.35 if k < 0.1 else 1.0
	var col: Color = cast_banner.color
	var fs := 22.0
	var sfs := 12.0
	var w: float = minf(VWc - 20, maxf(text_w(str(cast_banner.text), fs) + 120, text_w(str(cast_banner.sub), sfs) + 60))
	var h := 58.0
	var cy: float = (64.0 + SAFE_T) if PORT else (VHc * 0.2)
	save(); _alpha *= al
	tr_(VWc / 2, cy); scale_by(sc, sc)
	draw_rect(Rect2(-w / 2, -h / 2, w, h), ca(Color(0.05, 0.03, 0.08, 0.82)))
	draw_rect(Rect2(-w / 2, -h / 2, w, 3), ca(col))
	draw_rect(Rect2(-w / 2, h / 2 - 3, w, 3), ca(col))
	text(str(cast_banner.text), 0, -8, fs, col, "center", 4, Color(0, 0, 0, 0.9))
	text(str(cast_banner.sub), 0, 15, sfs, Color("#f4ecff"), "center", 3, Color(0, 0, 0, 0.9))
	restore()

func fit_size(s: String, base: float, maxw: float, lo: float) -> float:
	var f := base
	while f > lo and text_w(s, f) > maxw:
		f -= 1.0
	return f

func ab_button(id_btn: String, r: Rect2, tag: String, ab_id: String, on: bool, locked: bool, cb: Callable, note: String = "") -> void:
	var col: Color = ab_color(ab_id)
	var down: bool = pressed_id == id_btn and not locked
	save()
	if locked: _alpha *= 0.55
	rbox(r, 16.0, Color(0.06, 0.1, 0.12, 0.9), col if on else Color(col.r, col.g, col.b, 0.55), 3.0 if on else 1.5)
	if on:
		rbox(r.grow(-3.0), 13.0, Color(col.r, col.g, col.b, 0.26))
	if down:
		rbox(r, 16.0, Color(1, 1, 1, 0.12))
	var nm: String = str(ABILITY_DEFS[ab_id].name) if ABILITY_DEFS.has(ab_id) else "—"
	var pad := 12.0
	var tw: float = r.size.x - pad * 2
	var tag_s: String = tag + ("  · READY" if on else "")
	text(tag_s, r.position.x + pad, r.position.y + 10, 10, Color("#fff27a") if on else Color("#b8d4d6"), "left")
	var nfs: float = fit_size(nm, 16, tw, 10)
	text(nm, r.position.x + pad, r.position.y + r.size.y * 0.5 + 1, nfs, Color.WHITE, "left")
	var line: String = ab_effect_line(ab_id) if note == "" else note
	var efs: float = fit_size(line, 11, tw, 8)
	text(line, r.position.x + pad, r.position.y + r.size.y - 10, efs, Color(col.r * 0.45 + 0.55, col.g * 0.45 + 0.55, col.b * 0.45 + 0.55), "left")
	restore()
	if not locked: add_btn(id_btn, r, cb)

func ab_panel_focus():
	if G == null or G.queue.is_empty():
		return null
	if G.ab_focus != null and G.queue.find(G.ab_focus) >= 0 and not G.ab_focus.dead:
		return G.ab_focus
	return G.queue[G.queue.size() - 1]

func draw_ability_panel(short_land: bool, by: float) -> float:
	var u = ab_panel_focus()
	if u == null:
		return by
	var pw: float = minf(VWc - 16, 470.0)
	var px: float = (VWc - 8 - pw) if (short_land and VWc > 640) else (VWc - pw) / 2
	var bh2 := 48.0 if short_land else 54.0
	var chip_h := 26.0
	var top: float = by - 22 - bh2 - chip_h - 6
	var cx: float = px
	for q in G.queue:
		if q.dead: continue
		var lab: String = q.name + (" *" if q.ab_queued != "" else "")
		var cw: float = text_w(lab, 12) + 20
		if cx + cw > px + pw: break
		var rr := Rect2(cx, top, cw, chip_h - 4)
		var full: bool = q.gauge >= AB_MP
		rbox(rr, rr.size.y / 2.0, Color(0.06, 0.12, 0.13, 0.86), Color("#38f2ff") if q == u else Color(1, 1, 1, 0.15), 2.0 if q == u else 1.0)
		text(lab, rr.get_center().x, rr.get_center().y, 12, Color("#fff27a") if full else Color("#d6eef0"))
		var qq = q
		add_btn("abchip_" + str(q.id), rr, func(): _set_ab_focus(qq))
		cx += cw + 4
	var full2: bool = u.gauge >= AB_MP
	var status: String = (u.name + ": MP full — pick one or save it") if full2 else (u.name + ": MP %d/100 — fills over turns" % int(u.gauge))
	var sfs: float = fit_size(status, 12, pw - (cx - px) - 6, 8)
	if cx - px + text_w(status, sfs) + 6 > pw:
		status = ("MP FULL" if full2 else "MP %d/100" % int(u.gauge))
		sfs = 12
	text(status, px + pw, top + chip_h / 2 - 2, sfs, Color("#fff27a") if full2 else Color.WHITE, "right", 3, Color(0, 0, 0, 0.85))
	var by2: float = top + chip_h
	var bw: float = (pw - 6) / 2
	var uu = u
	var cid: String = u.ab_class
	var sid: String = u.ab_sub
	var aid: String = auto_ab(u.name) if CHAR.has(u.name) else ""
	if cid != "":
		ab_button("abq_c", Rect2(px, by2, bw, bh2), "CLASS" + ("  · AUTO" if aid == cid else ""), cid, u.ab_queued == cid, not full2, func(): queue_ability(uu, cid))
	if sid != "":
		ab_button("abq_s", Rect2(px + bw + 6, by2, bw, bh2), "SUB" + ("  · AUTO" if aid == sid else ""), sid, u.ab_queued == sid, not full2, func(): queue_ability(uu, sid))
	return top

func draw_inv_abilities(name: String, dx: float, y: float, dw: float, bottom: float, short: bool) -> void:
	validate_ab_equip(name)
	var lv: int = hero_level(name)
	var cls_ids: Array = class_ability_ids(name)
	var sub: String = str(CHAR[name].sub)
	var sub_ids: Array = sub_ability_ids(sub)
	var cid: String = str(AB_EQUIP[name].cls)
	var sid: String = str(AB_EQUIP[name].sub)
	var aid: String = auto_ab(name)
	section_label("IN BATTLE  ·  use with a full MP bar", dx, y + 6.0, short)
	y += 16.0 if short else 20.0
	var gap: float = 10.0
	var stack: bool = dw < 480.0
	var lh: float = 50.0 if short else 66.0
	var lw: float = dw if stack else (dw - gap) / 2.0
	var slots: Array = [["CLASS ABILITY", cid, "c"], ["SUBCLASS · " + sub.to_upper(), sid, "s"]]
	for i in 2:
		var sl: Array = slots[i]
		var r := Rect2(dx + (0.0 if stack else (lw + gap) * float(i)), y + (float(i) * (lh + 6.0) if stack else 0.0), lw, lh)
		var abid: String = str(sl[1])
		var col: Color = ab_color(abid)
		rbox(r, 20.0, UI_CARD, col, 2.5, 4.0)
		var dot := Vector2(r.position.x + 20.0, r.get_center().y)
		draw_circle(dot, 8.0, ca(col))
		var tx: float = r.position.x + 38.0
		var is_auto: bool = aid != "" and aid == abid
		var aw: float = 76.0 if short else 92.0
		var ah: float = 30.0 if short else 36.0
		var tw: float = r.size.x - 38.0 - aw - 18.0
		text(str(sl[0]), tx, r.position.y + (11.0 if short else 15.0), 10.0 if short else 11.0, UI_MUTED, "left")
		var nm: String = str(ABILITY_DEFS[abid].name) if ABILITY_DEFS.has(abid) else "—"
		text(nm, tx, r.position.y + (28.0 if short else 35.0), fit_size(nm, 16.0 if short else 19.0, tw, 11.0), UI_INK, "left")
		if ABILITY_DEFS.has(abid):
			var el: String = ab_effect_line(abid)
			text(el, tx, r.position.y + (42.0 if short else 54.0), fit_size(el, 11.0 if short else 12.0, tw, 8.0), UI_TEAL_D, "left")
		var aid2: String = abid
		pill("invauto_" + str(sl[2]), Rect2(r.end.x - aw - 10.0, r.get_center().y - ah / 2.0, aw, ah), "AUTO ON" if is_auto else "Set AUTO", "gold" if is_auto else "soft", 12.0 if short else 13.0, func(): set_auto_ab(name, aid2))
	y += (lh * 2.0 + 6.0 if stack else lh) + (8.0 if short else 12.0)
	# Ability lists
	var show_detail: bool = not short and bottom - y > 250.0
	var det_h: float = 40.0 if show_detail else 0.0
	var list_bot: float = bottom - (det_h + 8.0 if show_detail else 0.0)
	var c_w: float = dw if stack else (dw - gap) * 0.64
	var s_w: float = dw if stack else dw - gap - c_w
	var s_x: float = dx if stack else dx + c_w + gap
	section_label("CLASS  ·  %d/10 owned" % unlocked_class_ids(name).size(), dx, y + 6.0, short)
	if not stack:
		section_label("SUBCLASS %s  ·  %d/5 owned" % [sub.to_upper(), unlocked_sub_ids(name).size()], s_x, y + 6.0, short)
	y += 16.0 if short else 20.0
	var rows_h: float = list_bot - y
	if stack:
		rows_h = (list_bot - y - 22.0) * 0.5
	var rg: float = 4.0 if short else 6.0
	var rh: float = minf(44.0, (rows_h - rg * 4.0) / 5.0)
	var ccw: float = (c_w - rg) / 2.0
	for i in cls_ids.size():
		var c_id: String = cls_ids[i]
		var col_i: int = int(i / 5)
		var row_i: int = i % 5
		_inv_ab_row("invab_c%d" % i, Rect2(dx + float(col_i) * (ccw + rg), y + float(row_i) * (rh + rg), ccw, rh), c_id, name, lv, cid == c_id, aid == c_id)
	var sy: float = y
	if stack:
		sy = y + 5.0 * (rh + rg) + 4.0
		section_label("SUBCLASS %s  ·  %d/5 owned" % [sub.to_upper(), unlocked_sub_ids(name).size()], s_x, sy + 6.0, short)
		sy += 18.0
	for j in sub_ids.size():
		var s_id: String = sub_ids[j]
		_inv_ab_row("invab_s%d" % j, Rect2(s_x, sy + float(j) * (rh + rg), s_w, rh), s_id, name, lv, sid == s_id, aid == s_id)
	if show_detail:
		var view: String = inv_ab_view
		if not ABILITY_DEFS.has(view):
			view = cid
		if ABILITY_DEFS.has(view):
			var ab: Dictionary = ABILITY_DEFS[view]
			var dr := Rect2(dx, bottom - det_h, dw, det_h)
			rbox(dr, det_h / 2.0, UI_TEAL_L)
			var owned: bool = lv >= int(ab.lv)
			var body: String = str(ab.name) + ":  " + str(ab.blurb) + ("" if owned else "  (Unlocks at Lv %d)" % int(ab.lv))
			text(body, dr.position.x + 18.0, dr.get_center().y, fit_size(body, 13.0, dr.size.x - 36.0, 9.0), UI_TEAL_D, "left")

func _inv_ab_row(id_btn: String, r: Rect2, ab_id: String, name: String, lv: int, on: bool, is_auto: bool = false) -> void:
	var ab: Dictionary = ABILITY_DEFS[ab_id]
	var owned: bool = lv >= int(ab.lv)
	var col: Color = ab_color(ab_id)
	var rad: float = minf(16.0, r.size.y / 2.0)
	var viewing: bool = inv_ab_view == ab_id
	if on:
		rbox(r, rad, UI_GOLD_L, UI_GOLD, 2.5)
	elif owned:
		rbox(r, rad, UI_CARD, UI_TEAL if viewing else UI_LINE, 2.0 if viewing else 1.5)
	else:
		rbox(r, rad, Color(1, 1, 1, 0.25), UI_TEAL if viewing else Color(UI_LINE.r, UI_LINE.g, UI_LINE.b, 0.7), 1.5)
	var x: float = r.position.x + 12.0
	if owned:
		draw_circle(Vector2(x + 4.0, r.get_center().y), 5.0, ca(col))
	else:
		draw_circle(Vector2(x + 4.0, r.get_center().y), 5.0, ca(Color(UI_LOCK.r, UI_LOCK.g, UI_LOCK.b, 0.5)))
	x += 16.0
	var right: float = r.end.x - 8.0
	var bfs: float = 10.0
	if on:
		right -= chip("ON", right, r.get_center().y, bfs, UI_GOLD, Color("#3d2706"), "right") + 4.0
		if is_auto:
			right -= chip("AUTO", right, r.get_center().y, bfs, UI_TEAL, Color.WHITE, "right") + 4.0
	elif not owned:
		right -= chip("Lv %d" % int(ab.lv), right, r.get_center().y, bfs, Color(UI_LOCK.r, UI_LOCK.g, UI_LOCK.b, 0.22), UI_MUTED, "right") + 4.0
	var nw: float = right - x - 4.0
	var nm: String = str(ab.name)
	var tc: Color = UI_INK if owned else UI_LOCK
	if r.size.y >= 34.0:
		text(nm, x, r.get_center().y - 7.0, fit_size(nm, 13.0, nw, 9.0), tc, "left")
		var el: String = ab_effect_line(ab_id) if owned else "Locked"
		text(el, x, r.get_center().y + 8.0, fit_size(el, 10.0, nw, 7.0), UI_TEAL_D if owned else UI_LOCK, "left")
	else:
		text(nm, x, r.get_center().y, fit_size(nm, 12.0, nw, 8.0), tc, "left")
	var aid: String = ab_id
	add_btn(id_btn, r, func(): _inv_tap_ability(name, aid))

func _inv_tap_ability(name: String, id: String) -> void:
	inv_ab_view = id
	if equip_ability(name, id):
		sfx.tone(880, 0.05, "triangle", 0.03)
	else:
		sfx.tone(330, 0.05, "square", 0.02)

func _set_ab_focus(q) -> void:
	if G == null: return
	G.ab_focus = q
	sfx.tone(587, 0.04, "square", 0.025)

# ---------------------------------------------------------------- render
func _draw() -> void:
	buttons.clear()
	var base := Transform2D(Vector2(dpr, 0), Vector2(0, dpr), Vector2.ZERO)
	_stack.clear(); _alpha = 1.0
	set_xf(base)
	if screen == "overworld":
		draw_overworld()
		return
	if screen == "map":
		draw_overworld()
		WMAP.draw(self, VWc, VHc, now, ow_x, ow_y)
		return
	if screen == "stats":
		draw_overworld()
		STATS.draw(self, VWc, VHc)
		return
	draw_rect(Rect2(0, 0, VWc, VHc), Color("#47aba9"))
	set_xf(base * Transform2D(Vector2(vscale, 0), Vector2(0, vscale), Vector2(OX, OY)))
	save()
	if shake_t > 0:
		tr_((randf() - 0.5) * shake_mag * 2 * (shake_t / 240.0), (randf() - 0.5) * shake_mag * 2 * (shake_t / 240.0))
	draw_terrain()
	var list := []
	for p in props: list.append([p.y, 0, p])
	if G != null:
		for u in G.units:
			if not u.gone: list.append([u.y - 1000 if u.dead else u.y, 1, u])
	for e in fx:
		if e.type == "sprite": list.append([e.y + 1, 2, e])
	list.sort_custom(func(a, b): return a[0] < b[0])
	for o in list:
		if o[1] == 0:
			var p: Dictionary = o[2]
			var fr: int = (int(floorf(now / (1000.0 / p.get("fps", 6.0)))) + p.ph) % p.n if p.n > 1 else 0
			draw_frame(IMG[p.img], p.fw, p.fh, fr, 0, p.x, p.y, p.ax, p.ay, p.s, p.get("flip", false))
		elif o[1] == 1: draw_unit(o[2])
		else: draw_fx(o[2])
	for e in fx:
		if e.type != "sprite": draw_fx(e)
	for p in projectiles: draw_projectile(p)
	if G != null and phase != "title":
		for u in G.units: draw_bars(u)
		for u in G.units: draw_badge(u)
	for t in texts: draw_text_fx(t)
	restore()
	set_xf(base)
	if screen_flash != null:
		var fk: float = screen_flash.t / screen_flash.life
		var fcol: Color = screen_flash.color
		draw_rect(Rect2(0, 0, VWc, VHc), Color(fcol.r, fcol.g, fcol.b, 0.32 * (1.0 - fk)))
	draw_hud(); draw_banner(); draw_cast_banner()
	if screen == "title": draw_title()
	elif screen == "chars": draw_chars()
	elif screen == "inv": draw_inv()
	elif screen == "party": draw_party()
	elif screen == "compendium": COMP.draw(self, VWc, VHc)
	elif screen == "results": draw_results()
	elif phase == "battle" or phase == "ending": draw_battle_ui()

# ---------------------------------------------------------------- screens
func to_title() -> void:
	encounter = {}
	ow_menu_open = false
	menu_return = ""
	new_battle(); phase = "title"; paused = false; screen = "title"

func start_fight(n: int) -> void:
	new_battle(n); phase = "battle"; paused = false; screen = ""
	begin_player_turn()
	if G.n_red == 1:
		banner.text = "BOSS RIFT!"; banner.sub = "6v1 — one necromancer" if USE_NECRO else "6v1 — one tyrant"
	elif G.n_red == 2:
		banner.text = "ELITE RAID"; banner.sub = "6v2 — two elites"
	else:
		banner.text = "GOBLIN RAID"; banner.sub = "6v3 — a short raid"
	banner.color = "red" if G.n_red == 1 else "yellow"; banner.life = 1400.0

func show_results() -> void:
	if phase == "results": return
	phase = "results"
	var r := G.result
	var raid_name := "6v1 Boss" if G.n_red == 1 else ("6v2 Elite" if G.n_red == 2 else "6v3 Raid")
	var blue: Array = G.units.filter(func(u): return u.team == "blue")
	var red: Array = G.units.filter(func(u): return u.team == "red")
	var b_alive := blue.filter(func(u): return not u.dead).size()
	var r_alive := red.filter(func(u): return not u.dead).size()
	var mvp = G.units[0]
	for u in G.units:
		if u.dmg > mvp.dmg: mvp = u
	var bd := 0
	var rd := 0
	for u in blue: bd += u.dmg
	for u in red: rd += u.dmg
	var role: String = (mvp.cls + " / " + mvp.sub) if mvp.cls != "" else mvp.K.label
	var N := Color("#3a2412")
	var B := Color("#1c4f8a")
	var RR := Color("#9e2c2c")
	var win: bool = r == "win"
	var xp_full := raid_xp_award(G.n_red, win) if r != "draw" else raid_xp_award(G.n_red, false)
	if not encounter.is_empty():
		var exp_e: int = WORLD.encounter_xp(encounter)
		xp_full = exp_e if win else int(roundf(float(exp_e) * 0.25))
		raid_name = "Wild Lv." + str(int(encounter.get("level", 1)))
	if r == "draw" and encounter.is_empty():
		xp_full = raid_xp_award(G.n_red, false)
	stash_party_mp()
	var ups: Array = []
	# Fighters get full XP; bench gets half on a win, none on a loss or draw.
	for name in party_names():
		var g := grant_hero_xp(name, xp_full)
		if g > 0:
			ups.append(name + " Lv." + str(hero_level(name)))
	if win:
		for name in bench_names():
			var half := int(roundf(float(xp_full) * 0.5))
			var g2 := grant_hero_xp(name, half)
			if g2 > 0:
				ups.append(name + " Lv." + str(hero_level(name)))
	save_cfg()
	var xp_line := [["XP: ", N], ["+%d" % xp_full, B], [" each fighter", N]]
	if win and bench_names().size() > 0:
		xp_line += [[" · bench +%d" % int(roundf(float(xp_full) * 0.5)), N]]
	var up_line := []
	if ups.size() > 0:
		up_line = [["Level up: ", N], [", ".join(ups), B]]
	else:
		up_line = [["No level ups this fight.", N]]
	var lines_out := [
		[["Turns: ", N], [str(G.turn), B], [" · Mode: ", N], [raid_name, RR]],
		[["Standing: ", N], ["%d/%d" % [b_alive, party_names().size()], B], [" · ", N], ["%d/%d" % [r_alive, G.n_red], RR]],
		[["Damage: ", N], [fmt_n(bd), B], [" vs ", N], [fmt_n(rd), RR]],
		[["MVP: ", N], [mvp.name, RR if mvp.team == "red" else B], [" the " + role + " — " + fmt_n(mvp.dmg) + " dmg, " + str(mvp.kos) + " KO" + ("" if mvp.kos == 1 else "s"), N]],
		xp_line,
		up_line,
	]
	res = {
		"result": r, "n_red": G.n_red,
		"title": "VICTORY" if r == "win" else ("DEFEAT" if r == "lose" else "DRAW"),
		"sub": "The squad holds the rift!" if r == "win" else ("The rift was overrun…" if r == "lose" else "Nobody left standing!"),
		"lines": lines_out,
	}
	results_t = 0.0
	screen = "results"

func toggle_pause() -> void:
	if phase != "battle" and phase != "ending": return
	paused = not paused
func toggle_mute() -> void:
	muted = not muted
	sfx.muted = muted
	save_cfg()
func toggle_speed() -> void:
	speed = 2 if speed == 1 else 1

# ---------------------------------------------------------------- input
var last_touch := -10000
var touch_idx := -1
var last_fire := {}

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		last_touch = Time.get_ticks_msec()
		if event.pressed:
			touch_idx = event.index
			on_press(event.position / dpr)
		else:
			if event.index != touch_idx: return
			touch_idx = -1
			on_release(event.position / dpr)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if Time.get_ticks_msec() - last_touch < 600: return
		if event.pressed: on_press(event.position / dpr)
		else: on_release(event.position / dpr)
	elif event is InputEventKey and event.pressed and not event.echo:
		on_key(event.physical_keycode)
	elif (event is InputEventScreenDrag or event is InputEventMouseMotion) and drag_on:
		var mp2: Vector2 = event.position / dpr
		if mp2.distance_to(drag_from) > 8.0:
			drag_moved = true
		if drag_moved:
			WMAP.drag(mp2 - drag_last)
		drag_last = mp2

func btn_at(p: Vector2) -> Dictionary:
	for i in range(buttons.size() - 1, -1, -1):
		var r: Rect2 = buttons[i].rect
		if r.has_point(p): return buttons[i]
	return {}

func on_press(p: Vector2) -> void:
	var b := btn_at(p)
	if not b.is_empty():
		pressed_id = b.id
		return
	pressed_id = ""
	if screen == "map":
		drag_on = true
		drag_moved = false
		drag_from = p
		drag_last = p
		return
	if screen == "stats":
		return
	if screen == "overworld":
		if ow_menu_open:
			ow_menu_open = false
			return
		ow_tap(p)
		return
	canvas_tap(p.x, p.y)

func on_release(p: Vector2) -> void:
	if drag_on:
		drag_on = false
		if not drag_moved and screen == "map":
			WMAP.tap(p)
	var id := pressed_id
	pressed_id = ""
	if id == "": return
	var b := btn_at(p)
	if b.is_empty() or b.id != id: return
	var t := Time.get_ticks_msec()
	if t - int(last_fire.get(id, -1000)) < 350: return
	last_fire[id] = t
	b.cb.call()

func canvas_tap(cx: float, cy: float) -> void:
	if G == null or phase != "battle" or G.mode != "select" or paused: return
	var wx := (cx - OX) / vscale
	var wy := (cy - OY) / vscale
	var best = null
	var bd := 1e9
	var rad := maxf(38, 24 / vscale)
	for u in alive("blue"):
		var dx: float = wx - u.x
		var dy: float = wy - (u.y - 26)
		var d := sqrt(dx * dx + dy * dy * 0.7)
		if d < rad and d < bd:
			bd = d; best = u
	if best != null: toggle_queue(best)

func on_key(k: int) -> void:
	if screen == "map" or screen == "stats":
		if k == KEY_ESCAPE or k == KEY_P or k == KEY_M:
			resume_overworld()
		return
	if screen == "overworld":
		if k == KEY_ESCAPE or k == KEY_P:
			ow_menu_open = not ow_menu_open
		elif k == KEY_M:
			ow_open_menu_screen("map")
		return
	if screen == "compendium":
		COMP.key(self, k)
		return
	if screen == "chars" or screen == "inv" or screen == "party" or screen == "overworld":
		if k == KEY_ESCAPE or k == KEY_P:
			menu_back()
			return
		if screen == "overworld":
			return
		if k == KEY_LEFT and screen == "chars":
			cycle_sub(-1)
		elif k == KEY_RIGHT and screen == "chars":
			cycle_sub(1)
		elif k == KEY_UP:
			if screen == "party":
				party_sel = (party_sel - 1 + SQUAD.size()) % SQUAD.size()
			else:
				select_hero((char_sel - 1 + HERO_NAMES.size()) % HERO_NAMES.size())
		elif k == KEY_DOWN:
			if screen == "party":
				party_sel = (party_sel + 1) % SQUAD.size()
			else:
				select_hero((char_sel + 1) % HERO_NAMES.size())
		elif k >= KEY_1 and k <= KEY_6:
			if screen == "party":
				party_sel = k - KEY_1
			else:
				select_hero(k - KEY_1)
		# Space / Enter must not start a fight from these menus.
		return
	if k == KEY_SPACE or k == KEY_ENTER or k == KEY_KP_ENTER:
		if phase == "title" or phase == "results": start_fight(last_raid)
		else: execute_orders()
	elif k >= KEY_1 and k <= KEY_6 and G != null and phase == "battle":
		var bl: Array = G.units.filter(func(u): return u.team == "blue")
		var i := k - KEY_1
		if i < bl.size(): toggle_queue(bl[i])
	elif k == KEY_R: run_battle()
	elif k == KEY_A: queue_all()
	elif k == KEY_C: clear_queue()
	elif k == KEY_P or k == KEY_ESCAPE: toggle_pause()
	elif k == KEY_M: toggle_mute()
	elif k == KEY_S: toggle_speed()

# ---------------------------------------------------------------- loop
func _ready() -> void:
	randomize()
	build_abilities()
	sfx = preload("res://scripts/sfx.gd").new()
	add_child(sfx)
	WORLD = WorldScript.new()
	WORLD.load_all()
	WMAP = WorldMapUI.new()
	WMAP.setup(WORLD)
	STATS = StatsUI.new()
	COMP = CompendiumUI.new()
	load_cfg()
	sfx.muted = muted
	if OS.has_feature("web"):
		var q = JavaScriptBridge.eval("location.search", true)
		if q is String:
			for kv in q.trim_prefix("?").split("&", false):
				var parts: PackedStringArray = kv.split("=")
				params[parts[0]] = parts[1] if parts.size() > 1 else ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			var kv2 := a.substr(2).split("=")
			params[kv2[0]] = kv2[1]
	if params.get("boss", "") == "goblin": USE_NECRO = false
	if params.has("enc"): WORLD.enc_mult = maxf(0.0, float(params.enc))
	if params.get("gates", "") == "off": WORLD.gates_enabled = false
	if params.has("warp"): ow_warp = str(params.warp) # preview helper: ?warp=frostveil starts the overworld in that area
	build_kinds()
	load_all()
	set_orientation(false)
	layout()
	build_terrain(); terrain_built = true
	to_title()
	if params.get("auto", "") == "1":
		AUTO = true; start_fight(int(params.get("enemies", str(last_raid))))
	if params.has("shot") and not OS.has_feature("web"): _autotest()

func _process(delta: float) -> void:
	layout()
	var dt := minf(50.0, delta * 1000.0)
	if not paused and phase != "loading":
		var total := dt * speed
		while total > 0:
			var s := minf(total, 17.0)
			step(s); total -= s
	if screen == "results": results_t += dt
	if screen == "chars" or screen == "inv": tick_char_ui(dt)
	if screen == "overworld": tick_overworld(dt)
	queue_redraw()

# ---------------------------------------------------------------- headless test hooks (desktop only)
func _sim(n: int) -> Dictionary:
	var out := {"win": 0, "lose": 0, "draw": 0, "turns": 0, "byN": {}}
	AUTO = true
	var m: bool = sfx.muted
	sfx.muted = true
	for k in n:
		new_battle((k % 3) + 1); phase = "battle"; begin_player_turn()
		var guard := 0
		while phase == "battle" and guard < 60000:
			step(17); guard += 1
		out[G.result] += 1
		out.turns += G.turn
		var key := str(G.n_red)
		if not out.byN.has(key): out.byN[key] = {"w": 0, "l": 0}
		if G.result == "win": out.byN[key].w += 1
		else: out.byN[key].l += 1
		phase = "title"
	AUTO = false
	sfx.muted = m
	return out

func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)

func _wait_ms(ms: float) -> void:
	await get_tree().create_timer(ms / 1000.0).timeout

## Headless check: force-cast every ability once and confirm it spends the full bar.
func _abtest() -> void:
	var m: bool = sfx.muted
	sfx.muted = true
	var ok := 0
	var bad: Array = []
	for id in ABILITY_DEFS:
		new_battle(3); phase = "battle"; begin_player_turn()
		var blues: Array = G.units.filter(func(x): return x.team == "blue")
		var u = blues[0]
		for x in blues:
			if str(ABILITY_DEFS[id].src) == "class" and x.name == str(ABILITY_DEFS[id].owner): u = x
		var hp0 := 0
		for x in G.units: hp0 += x.hp
		for x in blues: x.hp = maxi(1, int(x.maxhp / 2))
		var bhp := 0
		for x in blues: bhp += x.hp
		var rhp := 0
		for x in alive("red"): rhp += x.hp
		u.gauge = 100.0
		G.queue = [u]
		queue_ability(u, id)
		var queued: bool = u.ab_queued == id
		execute_orders()
		var guard := 0
		while phase == "battle" and G.side == "blue" and guard < 4000:
			step(17); guard += 1
		var bhp2 := 0
		for x in G.units.filter(func(x2): return x2.team == "blue"): bhp2 += x.hp
		var rhp2 := 0
		for x in G.units.filter(func(x2): return x2.team == "red"): rhp2 += x.hp
		var buffs := 0
		for x in G.units: buffs += x.buffs.size()
		var kind: String = str(ABILITY_DEFS[id].kind)
		var effect := false
		if kind.begins_with("damage"): effect = rhp2 < rhp
		elif kind.begins_with("heal"): effect = bhp2 > bhp
		else: effect = buffs > 0
		if queued and effect and u.gauge < 100.0 and guard < 4000: ok += 1
		else: bad.append("%s q=%s eff=%s g=%d guard=%d" % [id, str(queued), str(effect), int(u.gauge), guard])
		phase = "title"
	sfx.muted = m
	print("ABTEST ok=", ok, " total=", ABILITY_DEFS.size(), " bad=", bad)

func _autotest() -> void:
	var dir: String = params.shot
	if params.has("abtest"):
		_abtest()
		get_tree().quit()
		return
	if params.has("sim"):
		print("SIM ", JSON.stringify(_sim(int(params.sim))))
		to_title()
	await _wait_ms(400)
	await _shot(dir + "/01_title.png")
	open_inv(); inv_tab = "abilities"
	await _wait_ms(300)
	await _shot(dir + "/01b_inv_abilities.png")
	select_hero(4); inv_tab = "abilities"
	await _wait_ms(200)
	await _shot(dir + "/01c_inv_lanning.png")
	inv_tab = "gear"
	await _wait_ms(200)
	await _shot(dir + "/01d_inv_gear.png")
	open_chars()
	await _wait_ms(300)
	await _shot(dir + "/01e_chars.png")
	to_title()
	start_fight(int(params.get("mode", "1")))
	await _wait_ms(1600)
	for u in G.units.filter(func(u): return u.team == "blue").slice(0, 4): toggle_queue(u)
	await _wait_ms(200)
	await _shot(dir + "/02_queued.png")
	var qb: Array = G.queue.duplicate()
	for qu in qb: qu.gauge = 100.0
	if qb.size() >= 2:
		queue_ability(qb[0], qb[0].ab_class)
		queue_ability(qb[1], qb[1].ab_sub)
		G.ab_focus = qb[1]
	await _wait_ms(300)
	await _shot(dir + "/02b_abilities.png")
	execute_orders()
	await _wait_ms(500)
	await _shot(dir + "/03a_cast.png")
	await _wait_ms(400)
	await _shot(dir + "/03_attack.png")
	speed = 2
	while phase == "battle" and G.side == "blue": await _wait_ms(100)
	await _wait_ms(700)
	await _shot(dir + "/04_enemy.png")
	AUTO = true
	while phase != "results": await _wait_ms(200)
	await _wait_ms(600)
	await _shot(dir + "/05_results.png")
	print("RESULT ", G.result, " turns ", G.turn)
	get_tree().quit()
