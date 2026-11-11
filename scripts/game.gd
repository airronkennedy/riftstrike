extends Node2D
## RIFTSTRIKE — turn-based 6vN brawl. Godot port of the canvas game (game.js), kept 1:1.
## Art: Tiny Swords by Pixel Frog (CC0). Boss: Necromancer by CreativeKind.
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
	"dead": "units/Dead.png", "dynamite": "fx/Dynamite.png", "arrow": "fx/Arrow.png",
	"explosion": "fx/Explosions.png", "fire": "fx/Fire.png",
	"flat": "terrain/Tilemap_Flat.png", "foam": "terrain/Foam.png",
	"rocks1": "terrain/Rocks_01.png", "rocks3": "terrain/Rocks_03.png", "tree": "terrain/Tree.png",
	"tower": "terrain/Tower_Blue.png", "ghouse": "terrain/Goblin_House.png", "sheep": "terrain/HappySheep_Idle.png",
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
	for d in ["01", "02", "03", "04", "05", "07", "08", "09", "10", "11", "12", "13", "14"]:
		SRC["deco" + d] = "deco/" + d + ".png"
	for k in SRC:
		IMG[k] = load("res://assets/" + SRC[k])
	for k in ["warrior", "archer", "pawn", "torch", "tnt", "barrel", "necro"]:
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

var ROSTER_BLUE := [["warrior", "Airron", 360, 265], ["warrior", "Christian", 360, 395],
	["pawn", "Lanning", 315, 185], ["pawn", "Rico", 315, 470],
	["archer", "Weston", 205, 265], ["archer", "Wiesen", 205, 395]]
var GOB_NAMES := ["Rusk", "Kael", "Sable", "Drenn", "Voss", "Iven"]
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
}
var CLASS_IDS := ["Knight", "Warrior", "Ranger", "Marksman", "Guardian", "Warden"]
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
var CHAR := {
	"Airron": {"cls": "Knight", "sub": "Riftblade"},
	"Christian": {"cls": "Warrior", "sub": "Vanguard"},
	"Weston": {"cls": "Ranger", "sub": "Scout"},
	"Wiesen": {"cls": "Marksman", "sub": "Sharpshot"},
	"Lanning": {"cls": "Guardian", "sub": "Ironhide"},
	"Rico": {"cls": "Warrior", "sub": "Raider"},
}
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
	var d: Dictionary = HERO_BASE[name].duplicate()
	pack_add(d, CLASS_DEFS[cls])
	pack_add(d, SUB_DEFS[sub])
	return {
		"hp": clamp_range(d.hp, 140, 620),
		"atk": clamp_stat(d.atk),
		"def": clamp_stat(d.def),
		"armor": clamp_range(d.armor, 0, 40),
		"crit": clamp_range(d.crit, 1, 50),
		"mana": clamp_range(d.mana, 0, 25),
		"speed": clamp_range(d.speed, 1, 40),
		"cls": cls, "sub": sub, "kind": CLASS_DEFS[cls].kind,
		"blurb": CLASS_DEFS[cls].blurb, "sub_blurb": SUB_DEFS[sub].blurb, "scale": 1.0,
	}

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
	if n == 0: n = int(params.get("enemies", "0"))
	if n == 0: n = last_raid
	if n != 1 and n != 2 and n != 3: n = 3
	last_raid = n
	var red := build_red_roster(n)
	for team in ["blue", "red"]:
		var roster: Array = ROSTER_BLUE if team == "blue" else red
		for i in roster.size():
			var r: Array = roster[i]
			var p := mp(r[2], r[3])
			var st := char_stats(r[1], r[0], team, n)
			var kind: String = st.get("kind", r[0])
			if not KINDS.has(kind): kind = r[0]
			var u := Unit.new()
			u.id = team + str(i); u.team = team; u.kind = kind; u.K = KINDS[kind]; u.name = r[1]
			u.x = p.x; u.y = p.y; u.hx = p.x; u.hy = p.y
			u.hp = st.hp; u.maxhp = st.hp; u.shown_hp = st.hp; u.atk = st.atk; u.def = st.def
			u.armor = st.get("armor", 0); u.crit = st.get("crit", 10)
			u.mana_regen = st.get("mana", 0); u.speed = st.get("speed", 12)
			u.cls = st.cls; u.sub = st.sub; u.scale = st.scale
			u.gauge = rand(0, 30); u.facing = 1 if team == "blue" else -1; u.at = rand(0, 1000)
			units.append(u)
	G = Battle.new()
	G.units = units
	G.n_red = n
	fx = []; projectiles = []; texts = []; banner = null

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
	var special: bool = u.gauge >= 100
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
	a.d = list[mini(a.swing, list.size() - 1)] if (u.kind == "warrior" or u.kind == "pawn") else list[0]
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
			if u.kind == "warrior" and a.swing == 0:
				a.swing = 1; begin_swing(u); return
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
			apply_hit(h.u, t, h.mult, h.special, false, h.color)

func resolve_hit(u, a) -> void:
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
	var final: bool = not (u.kind == "warrior" and a.swing == 0)
	var base := 0.6 if u.kind == "warrior" else (0.8 if u.kind == "torch" else 1.0)
	hit(u, t, base * (2.5 if sp else 1.0), sp and final)
	if u.kind == "pawn": t.kx = u.facing * 16
	if u.kind == "torch" and not t.dead: t.burn = {"t": 380.0, "owner": u, "mult": 0.3 * (2 if sp else 1)}
	if u.kind == "barrel" and not sp:
		explode(t.x, t.y, 0.55); splash(u, t.x, t.y, 70, 0.12, t)
	if sp and final:
		if u.kind == "warrior":
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

func apply_hit(u, t, mult: float, special: bool, is_splash: bool = false, color: String = "") -> void:
	if t == null or t.dead: return
	var crit_p: float = clampf(float(u.crit) / 100.0, 0.0, 0.6)
	var crit := not special and not is_splash and randf() < crit_p
	var raw: float = u.atk * rand(0.85, 1.15) * mult * (1.5 if crit else 1.0) * surge_mult()
	deal_damage(u, t, mitigate_raw(raw, t), {"special": special, "isSplash": is_splash, "crit": crit, "color": color})

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
	var big: bool = combo or (opt.get("special", false) and not opt.get("isSplash", false))
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
				if not t.dead:
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
	G.side = "blue"; G.mode = "select"; G.queue = []; G.qi = 0; G.turn += 1
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
	if i >= 0: G.queue.remove_at(i)
	else: G.queue.append(u)
	u.pop = 160.0
	sfx.tone(440 if i >= 0 else 660 + G.queue.size() * 40, 0.05, "square", 0.03)

func queue_all() -> void:
	if G == null or G.mode != "select" or phase != "battle": return
	for u in alive("blue"):
		if G.queue.find(u) < 0: G.queue.append(u)
	sfx.tone(880, 0.06, "square", 0.03)

func clear_queue() -> void:
	if G == null or G.mode != "select" or phase != "battle": return
	G.queue = []
	sfx.tone(330, 0.05, "square", 0.03)

func step(dt: float) -> void:
	now += dt
	if phase == "battle" or phase == "ending":
		if hitstop > 0:
			hitstop -= dt; dt *= 0.15
		G.t += dt
		if phase == "battle" and AUTO and G.mode == "select":
			for u in shuffled(alive("blue")): G.queue.append(u)
			execute_orders()
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

func draw_frame(tex: Texture2D, fw: float, fh: float, col: int, row: int, x: float, y: float, ax: float, ay: float, s: float, flip: bool, alpha := 1.0) -> void:
	save(); tr_(roundf(x), roundf(y))
	if flip: scale_by(-1, 1)
	_alpha *= alpha
	img(tex, col * fw, row * fh, fw, fh, -ax * s, -ay * s, fw * s, fh * s)
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
	draw_circle(Vector2(x, y), r + 2.5, ca(Color("#0d3d4a")))
	draw_circle(Vector2(x, y), r, ca(Color("#38f2ff")))
	text(str(n), x, y + 1, roundf(r * 1.35), Color("#062830"))

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
	var nfs := roundf(10 * TS)
	# canvas uses alphabetic baseline at y-4; convert to middle
	var ny := y - 4 - nfs * 0.35
	text(u.name, u.x, ny, nfs, Color("#d6f1ff") if u.team == "blue" else Color("#ffd9cf"), "center", 3, Color(0, 0, 0, 0.75))
	if u.sub != "":
		var rfs := roundf(7.5 * TS)
		text(u.cls + " · " + u.sub, u.x, y - 4 - 11 * TS - rfs * 0.35, rfs, Color("#9fd4e8") if u.team == "blue" else Color("#f0b6a8"), "center", 2.5, Color(0, 0, 0, 0.75))

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

func save_cfg() -> void:
	var cf := ConfigFile.new()
	cf.set_value("rs", "muted", muted)
	for name in HERO_NAMES:
		cf.set_value("loadout", name, "%s|%s" % [CHAR[name].cls, CHAR[name].sub])
	cf.save("user://riftstrike.cfg")

func load_cfg() -> void:
	var cf := ConfigFile.new()
	if cf.load("user://riftstrike.cfg") != OK:
		return
	muted = bool(cf.get_value("rs", "muted", muted))
	for name in HERO_NAMES:
		var raw = cf.get_value("loadout", name, "")
		if typeof(raw) != TYPE_STRING or raw == "":
			continue
		var parts: PackedStringArray = raw.split("|")
		if parts.size() < 2:
			continue
		if CLASS_DEFS.has(parts[0]):
			CHAR[name].cls = parts[0]
		if SUB_DEFS.has(parts[1]):
			CHAR[name].sub = parts[1]

func open_chars() -> void:
	char_sel = 0
	char_prev = {}
	char_bar = {}
	char_delta_t = 0.0
	screen = "chars"
	sfx.tone(660, 0.06, "square", 0.035)

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
		u.anim = "idle"
		return

func select_hero(i: int) -> void:
	char_sel = clampi(i, 0, HERO_NAMES.size() - 1)
	char_prev = {}
	char_bar = {}
	char_delta_t = 0.0
	sfx.tone(523, 0.05, "square", 0.03)

func cycle_class(dir: int) -> void:
	var name := selected_hero()
	char_prev = compute_hero_stats(name)
	var i := CLASS_IDS.find(CHAR[name].cls)
	if i < 0:
		i = 0
	CHAR[name].cls = CLASS_IDS[(i + dir + CLASS_IDS.size()) % CLASS_IDS.size()]
	char_delta_t = 900.0
	save_cfg()
	apply_loadout_preview(name)
	sfx.tone(784 if dir > 0 else 659, 0.05, "square", 0.03)

func cycle_sub(dir: int) -> void:
	var name := selected_hero()
	char_prev = compute_hero_stats(name)
	var i := SUB_IDS.find(CHAR[name].sub)
	if i < 0:
		i = 0
	CHAR[name].sub = SUB_IDS[(i + dir + SUB_IDS.size()) % SUB_IDS.size()]
	char_delta_t = 900.0
	save_cfg()
	apply_loadout_preview(name)
	sfx.tone(880 if dir > 0 else 698, 0.045, "triangle", 0.025)

func tick_char_ui(dt: float) -> void:
	if screen != "chars":
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
	text(label, x, y + 8, 11, Color("#5b3b20"), "left")
	var bx := x + 82
	var bw: float = maxf(64.0, w - 82 - 72)
	draw_rect(Rect2(bx, y + 3, bw, h), Color("#2a1a10"))
	var fill := clampf(value / maxf(1.0, vmax), 0.0, 1.0)
	draw_rect(Rect2(bx, y + 3, bw * fill, h), col)
	text(shown, bx + bw + 8, y + 9, 13, Color("#2a1a10"), "left")
	if delta != 0:
		var ds := "%+d" % delta
		if shown.ends_with("%"):
			ds += "%"
		var dc := Color("#1a7a32") if delta > 0 else Color("#a4321a")
		dc.a = clampf(char_delta_t / 400.0, 0.0, 1.0)
		text(ds, bx + bw + 8 + text_w(shown, 13) + 6, y + 9, 13, dc, "left")

func draw_cycle_row(id: String, x: float, y: float, w: float, tag: String, value: String, hint: String, on_prev: Callable, on_next: Callable) -> float:
	var ah := 42.0
	var aw := 46.0
	text(tag, x, y + 2, 11, Color("#5b3b20"), "left")
	var row_y := y + 10
	ui_button(id + "_l", Rect2(x, row_y, aw, ah), "<", true, 20, 20, on_prev)
	ui_button(id + "_r", Rect2(x + w - aw, row_y, aw, ah), ">", true, 20, 20, on_next)
	var mid := Rect2(x + aw + 6, row_y, w - aw * 2 - 12, ah)
	var fsz := clampf3(14, mid.size.x / maxf(7.0, float(value.length()) * 0.62), 20)
	ui_button(id + "_n", mid, value, false, fsz, 26, on_next)
	var h := 10 + ah
	if hint != "":
		text(hint, x + w / 2, row_y + ah + 12, 11, Color("#7a5a32"))
		h += 16
	return h + 6

func draw_hero_sprite(kind: String, x: float, y: float, scl: float) -> void:
	var K: Dictionary = KINDS[kind]
	var idle: Dictionary = K.idle
	var fr := int(floorf(now * idle.fps / 1000.0)) % int(idle.n)
	draw_frame(IMG[K.img], K.f.fw, K.f.fh, fr, idle.r, x, y, K.f.ax, K.f.ay, float(K.f.s) * scl, false)

func draw_chars() -> void:
	draw_rect(Rect2(0, 0, VWc, VHc), Color(8 / 255.0, 18 / 255.0, 22 / 255.0, 0.72))
	var short := VHc <= 430
	var pad := 8.0 if short else 12.0
	var panel := Rect2(pad, pad, VWc - pad * 2, VHc - pad * 2)
	css9(IMG.carved, panel.position.x, panel.position.y, panel.size.x, panel.size.y, 24.0 if short else 32.0)
	var inner := Rect2(panel.position.x + (16 if short else 22), panel.position.y + (12 if short else 16), panel.size.x - (32 if short else 44), panel.size.y - (24 if short else 32))
	var name := selected_hero()
	var st := compute_hero_stats(name)
	var back_w := 110.0 if short else 130.0
	var bh := 40.0 if short else 48.0
	ui_button("chars_back", Rect2(inner.position.x, inner.position.y, back_w, bh), "BACK", true, 16, 28, func(): to_title())
	ribbon(IMG.ribbonYellow, inner.get_center().x, inner.position.y, "Characters", 20.0 if short else 26.0, bh, minf(280, inner.size.x * 0.46), 40, bh - 10)
	text("Saved for Play", inner.position.x + inner.size.x, inner.position.y + bh * 0.55, 11, Color("#5b3b20"), "right")
	var top: float = inner.position.y + bh + (4.0 if short else 8.0)
	var body_h: float = inner.position.y + inner.size.y - top
	var left_w := clampf3(148.0, inner.size.x * 0.28, 220.0)
	var row_h: float = body_h / 6.0
	for i in HERO_NAMES.size():
		var hn: String = HERO_NAMES[i]
		var hs := compute_hero_stats(hn)
		var ry: float = top + i * row_h
		var rr := Rect2(inner.position.x, ry, left_w - 8, row_h - 3)
		var sel := i == char_sel
		if sel:
			draw_rect(rr, Color("#c8a05a"))
			draw_rect(Rect2(rr.position.x + 2, rr.position.y + 2, rr.size.x - 4, rr.size.y - 4), Color("#3a2412"))
		var idx := i
		add_btn("hero_%d" % i, rr, func(): select_hero(idx))
		var sy: float = rr.position.y + rr.size.y - 2
		draw_hero_sprite(hs.kind, rr.position.x + 26, sy, 0.40 if short else 0.48)
		var tx: float = rr.position.x + 50
		text(hn, tx, ry + (13 if short else 15), 14.0 if short else 16.0, Color("#ffe27a") if sel else Color("#2a1a10"), "left")
		text(hs.cls + " · " + hs.sub, tx, ry + (26 if short else 30), 10.0 if short else 11.0, Color("#c8a06a") if sel else Color("#7a5a32"), "left")
	var dx: float = inner.position.x + left_w + 4
	var dw: float = inner.position.x + inner.size.x - dx
	var y: float = top
	var spr_h: float = 88.0 if short else 120.0
	draw_hero_sprite(st.kind, dx + 44, y + spr_h - 4, 0.82 if short else 1.05)
	text(name, dx + 88, y + 18, 24.0 if short else 30.0, Color("#2a1a10"), "left")
	text(st.cls + "  ·  " + st.sub, dx + 88, y + (40 if short else 48), 13.0 if short else 15.0, Color("#7a5a32"), "left")
	y += spr_h + (2 if short else 6)
	y += draw_cycle_row("cls", dx, y, dw, "CLASS", st.cls, st.blurb, func(): cycle_class(-1), func(): cycle_class(1))
	var sub_hint := "" if short else String(st.sub_blurb)
	y += draw_cycle_row("sub", dx, y, dw, "SUBCLASS", st.sub, sub_hint, func(): cycle_sub(-1), func(): cycle_sub(1))
	var rows := [
		["hp", "HP", 620.0, Color("#4fd36b"), ""],
		["atk", "ATK", 100.0, Color("#e85a3a"), ""],
		["def", "Defense", 100.0, Color("#3d8adf"), ""],
		["armor", "Armor", 40.0, Color("#8a8f9a"), ""],
		["crit", "Crit", 50.0, Color("#e6b422"), "%"],
		["mana", "Mana Regen", 25.0, Color("#9b6bdb"), ""],
		["speed", "Speed", 40.0, Color("#3ec8c8"), ""],
	]
	var two_col := dw > 360
	var col_w: float = (dw - 12) / 2.0 if two_col else dw
	var sh: float = 16.0 if short else 18.0
	var gap: float = 2.0 if short else 3.0
	for ri in rows.size():
		var row: Array = rows[ri]
		var key: String = row[0]
		var cur: int = int(st[key])
		var shown: String = str(cur) + str(row[4])
		if key == "mana":
			shown = "+" + str(cur)
		var vx: float = dx
		var vy: float = y
		if two_col:
			vx = dx + (col_w + 12) * (ri % 2)
			vy = y + int(ri / 2) * (sh + gap)
		else:
			vy = y + ri * (sh + gap)
		var bar_v := float(char_bar[key]) if char_bar.has(key) else float(cur)
		draw_stat_bar(vx, vy, col_w, sh, row[1], bar_v, row[2], shown, stat_delta(key, cur), row[3])
	var footer_y: float = inner.position.y + inner.size.y - 6
	if not short:
		text("Defense cuts a percent of a hit. Armor subtracts a flat amount. Mana returns each turn.", dx + dw / 2, footer_y, 10, Color("#7a5a32"))
		text("Tap the arrows — or the name — to swap and watch the stats move.", dx + dw / 2, footer_y - 14, 10, Color("#7a5a32"))


func draw_title() -> void:
	draw_rect(Rect2(0, 0, VWc, VHc), Color(10 / 255.0, 25 / 255.0, 28 / 255.0, 0.5))
	var short := VHc <= 430
	var vw := VWc
	var L := clampf3(40, VHc * 0.11, 80) if short else clampf3(46, vw * 0.135, 108)
	var rib_h := 38.0 if short else 44.0
	var tag_fs := clampf3(15, vw * 0.044, 22)
	var side_fs := clampf3(14, vw * 0.038, 19)
	var mtop := 8.0 if short else clampf3(10, VHc * 0.03, 22)
	var mbot := 8.0 if short else clampf3(10, VHc * 0.03, 20)
	var bh := 56.0 if short else 70.0
	var bfs := 16.0 if short else clampf3(16, vw * 0.044, 22)
	var row_w := minf(560, vw * 0.94)
	var specs := [["raid3", "6v3 RAID", false, minf(160, vw * 0.44), 3], ["raid2", "6v2 ELITE", false, minf(160, vw * 0.44), 2], ["raid1", "6v1 BOSS", true, minf(200, vw * 0.7), 1]]
	var rows := []
	var cur := []
	var cw := 0.0
	for sp in specs:
		var bw := maxf(sp[3], text_w(sp[1], bfs) + 80 + 4)
		if cur.size() > 0 and cw + 10 + bw > row_w:
			rows.append([cur, cw]); cur = []; cw = 0.0
		cw += (10.0 if cur.size() > 0 else 0.0) + bw
		cur.append([sp, bw])
	rows.append([cur, cw])
	var hint_fs := clampf3(13, vw * 0.036, 16)
	var hint_lines := []
	if not short:
		for para in ["Open Characters to swap class and subclass, then pick a raid. Hits that land together COMBO."]:
			hint_lines += wrap_words(para, hint_fs, vw - 24)
	var ch_w := minf(280.0, vw * 0.62)
	var total := L + 10 + rib_h + mtop + rib_h + mbot + bh + 10 + rows.size() * bh + (rows.size() - 1) * 10 + 2
	if hint_lines.size() > 0: total += 12 + hint_lines.size() * hint_fs * 1.2
	var y := maxf(12, (VHc - total) / 2 - (10.0 if USE_NECRO else 0.0))
	var cx := VWc / 2
	# logo with layered text-shadow and bob
	var bob := -3.0 + 3.0 * cos(now / 2400.0 * TAU)
	var ly := y + L / 2 + bob
	var logo := "RIFTSTRIKE"
	text(logo, cx, ly + L * 0.12 + L * 0.06, L, Color(0, 0, 0, 0.45))
	text(logo, cx, ly + L * 0.09, L, Color("#4a2a14"), "center", L * 0.06, Color("#4a2a14"))
	text(logo, cx, ly + L * 0.05, L, Color("#b5641f"), "center", L * 0.06, Color("#2b1a10"))
	text(logo, cx, ly, L, Color("#ffe27a"), "center", L * 0.06, Color("#2b1a10"))
	y += L + 10
	ribbon(IMG.ribbonYellow, cx, y, "Turn-based rift brawl", tag_fs, rib_h, minf(340, vw * 0.8), 40, rib_h - 8)
	y += rib_h + mtop
	var vs_fs := clampf3(22, vw * 0.06, 34)
	var lw := text_w("Airron's Squad", side_fs) + 80
	var rw := text_w("Pick a raid", side_fs) + 80
	var vsw := text_w("VS", vs_fs)
	var x0 := cx - (lw + rw + vsw + 20) / 2
	ribbon(IMG.ribbonBlue, x0 + lw / 2, y, "Airron's Squad", side_fs, rib_h, 0, 40, rib_h - 8)
	text("VS", x0 + lw + 10 + vsw / 2, y + rib_h / 2 + 3, vs_fs, Color.BLACK, "center", 4, Color.BLACK)
	text("VS", x0 + lw + 10 + vsw / 2, y + rib_h / 2, vs_fs, Color.WHITE, "center", 4, Color.BLACK)
	ribbon(IMG.ribbonRed, x0 + lw + 20 + vsw + rw / 2, y, "Pick a raid", side_fs, rib_h, 0, 40, rib_h - 8)
	y += rib_h + mbot + 2
	ui_button("chars", Rect2(cx - ch_w / 2, y, ch_w, bh), "CHARACTERS", false, bfs, 40, func(): open_chars())
	y += bh + 10
	for row in rows:
		var bx: float = cx - row[1] / 2
		for it in row[0]:
			var sp: Array = it[0]
			var n: int = sp[4]
			ui_button(sp[0], Rect2(bx, y, it[1], bh), sp[1], sp[2], bfs, 40, func(): start_fight(n), false, false, sp[0] == "raid1")
			bx += it[1] + 10
		y += bh + 10
	y += 2
	for ln in hint_lines:
		text(ln, cx + 1, y + hint_fs * 0.6 + 2, hint_fs, Color.BLACK)
		text(ln, cx, y + hint_fs * 0.6, hint_fs, Color("#e9fff9"))
		y += hint_fs * 1.2
	var cfs := 12.0 if short else 14.0
	var cy := VHc - (4.0 if short else 10.0) - cfs
	if USE_NECRO:
		link_text("Art: ", "Tiny Swords by Pixel Frog", " (CC0)", URL_TINY, cx, cy - cfs * 1.6, cfs, Color.WHITE, Color("#ffe27a"), true, "cr1")
		link_text("Boss: ", "Necromancer by CreativeKind", "", URL_NECRO, cx, cy, cfs, Color.WHITE, Color("#ffe27a"), true, "cr2")
	else:
		link_text("Art: ", "Tiny Swords by Pixel Frog", " (CC0)", URL_TINY, cx, cy, cfs, Color.WHITE, Color("#ffe27a"), true, "cr1")

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
	var btn_h := 64.0
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
	css9(IMG.carved, cx - pw / 2, top, pw, ph, b)
	var y := top + b + 8
	var rt: Texture2D = IMG.ribbonBlue if res.result == "win" else (IMG.ribbonRed if res.result == "lose" else IMG.ribbonYellow)
	ribbon(rt, cx, y, res.title, title_fs, title_h, minf(300, vw * 0.7), 56, title_h - 10)
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
		ui_button("retry", Rect2(bx, y, rw, btn_h), "RETRY", false, 22, 40, func(): start_fight(last_raid))
		ui_button("menu", Rect2(bx + rw + 10, y, tw, btn_h), "TITLE", true, 22, 40, func(): to_title())
		y += btn_h
	else:
		ui_button("retry", Rect2(cx - rw / 2, y, rw, btn_h), "RETRY", false, 22, 40, func(): start_fight(last_raid))
		y += btn_h + 10
		ui_button("menu", Rect2(cx - tw / 2, y, tw, btn_h), "TITLE", true, 22, 40, func(): to_title())
		y += btn_h
	y += (4 if short else 10) + 8
	link_text("Art: ", "Tiny Swords by Pixel Frog", " (CC0)", URL_TINY, cx, y, 12, Color("#5b3b20"), Color("#2a5d9f"), false, "cr1")
	if cred_lines == 2:
		link_text("Boss: ", "Necromancer by CreativeKind", "", URL_NECRO, cx, y + 16, 12, Color("#5b3b20"), Color("#2a5d9f"), false, "cr2")
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
	if G != null and phase == "battle":
		if sel: hint = "Tap again to remove · order = attack order" if n > 0 else "Tap your knights in attack order"
		else: hint = "Your knights are attacking…" if G.side == "blue" else "Goblins are attacking…"
	if hint != "":
		var hfs := 12.0 if short_land else 14.0
		var hy := by - 2 - 9
		if short_land: text(hint, VWc - 8, hy, hfs, Color.WHITE, "right", 3, Color(0, 0, 0, 0.85))
		else: text(hint, VWc / 2, hy, hfs, Color.WHITE, "center", 3, Color(0, 0, 0, 0.85))
	if paused:
		var pfs := clampf3(36, VWc * 0.1, 56)
		text("PAUSED", VWc / 2 + 3, VHc * 0.42 + pfs / 2 + 4, pfs, Color.BLACK, "center", 4, Color.BLACK)
		text("PAUSED", VWc / 2, VHc * 0.42 + pfs / 2, pfs, Color.WHITE, "center", 4, Color.BLACK)

# ---------------------------------------------------------------- render
func _draw() -> void:
	buttons.clear()
	var base := Transform2D(Vector2(dpr, 0), Vector2(0, dpr), Vector2.ZERO)
	_stack.clear(); _alpha = 1.0
	set_xf(base)
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
	draw_hud(); draw_banner()
	if screen == "title": draw_title()
	elif screen == "chars": draw_chars()
	elif screen == "results": draw_results()
	elif phase == "battle" or phase == "ending": draw_battle_ui()

# ---------------------------------------------------------------- screens
func to_title() -> void:
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
	res = {
		"result": r, "n_red": G.n_red,
		"title": "VICTORY" if r == "win" else ("DEFEAT" if r == "lose" else "DRAW"),
		"sub": "The squad holds the rift!" if r == "win" else ("The rift was overrun…" if r == "lose" else "Nobody left standing!"),
		"lines": [
			[["Turns: ", N], [str(G.turn), B], [" · Mode: ", N], [raid_name, RR]],
			[["Standing: ", N], ["%d/6" % b_alive, B], [" · ", N], ["%d/%d" % [r_alive, G.n_red], RR]],
			[["Damage: ", N], [fmt_n(bd), B], [" vs ", N], [fmt_n(rd), RR]],
			[["MVP: ", N], [mvp.name, RR if mvp.team == "red" else B], [" the " + role + " — " + fmt_n(mvp.dmg) + " dmg, " + str(mvp.kos) + " KO" + ("" if mvp.kos == 1 else "s"), N]],
		],
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
	canvas_tap(p.x, p.y)

func on_release(p: Vector2) -> void:
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
	if screen == "chars":
		if k == KEY_ESCAPE or k == KEY_P:
			to_title()
		elif k == KEY_LEFT:
			cycle_class(-1)
		elif k == KEY_RIGHT:
			cycle_class(1)
		elif k == KEY_UP:
			cycle_sub(-1)
		elif k == KEY_DOWN:
			cycle_sub(1)
		elif k >= KEY_1 and k <= KEY_6:
			select_hero(k - KEY_1)
		return
	if k == KEY_SPACE or k == KEY_ENTER or k == KEY_KP_ENTER:
		if phase == "title" or phase == "results": start_fight(last_raid)
		else: execute_orders()
	elif k >= KEY_1 and k <= KEY_6 and G != null and phase == "battle":
		var bl: Array = G.units.filter(func(u): return u.team == "blue")
		var i := k - KEY_1
		if i < bl.size(): toggle_queue(bl[i])
	elif k == KEY_A: queue_all()
	elif k == KEY_C: clear_queue()
	elif k == KEY_P or k == KEY_ESCAPE: toggle_pause()
	elif k == KEY_M: toggle_mute()
	elif k == KEY_S: toggle_speed()

# ---------------------------------------------------------------- loop
func _ready() -> void:
	randomize()
	sfx = preload("res://scripts/sfx.gd").new()
	add_child(sfx)
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
	if screen == "chars": tick_char_ui(dt)
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

func _autotest() -> void:
	var dir: String = params.shot
	if params.has("sim"):
		print("SIM ", JSON.stringify(_sim(int(params.sim))))
		to_title()
	await _wait_ms(400)
	await _shot(dir + "/01_title.png")
	start_fight(int(params.get("mode", "1")))
	await _wait_ms(1600)
	for u in G.units.filter(func(u): return u.team == "blue").slice(0, 4): toggle_queue(u)
	await _wait_ms(200)
	await _shot(dir + "/02_queued.png")
	execute_orders()
	await _wait_ms(900)
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
