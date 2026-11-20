class_name DungeonMaps
extends RefCounted
## The Sunken Bastion (docs/STORY.md Act IV, docs/DUNGEON.md): three floors under the ruin east of Emberhold.
## 48 px tiles. Legend:
##   #  wall          .  floor        ,  rubble floor   ~  black water / lava (blocks; floor "liquid")   =  bridge
##   K  floor guardian (blocks until beaten or cleared by the story)     d  side door (opens with the Reliquary Key)
##   S  entrance stairs (leave to the overworld)        <  stairs up       >  stairs down
##   C  chest   L  lever (opens every G)   G  portcullis   D  locked door (needs the floor's key)
##   P  ember shrine save point (heals, saves)          B  sealed boss door (final boss)
##   b  brazier (light)   p  pillar   s  keeper statue (all solid)

const TILE := 48.0

const FLOORS := [
	{"id": "bastion_1", "name": "The Drowned Gate", "sub": "The Sunken Bastion  ·  Floor 1", "ground": "riven-choir",
		"tint": Color(0.46, 0.5, 0.52), "ambient": Color(0.38, 0.42, 0.46), "light": Color(1.0, 0.66, 0.4), "liquid": "water",
		"guardian": "guardian_f1", "guardian_art": "tithe", "guardian_flag": "bastion_f1", "side_flag": "c2_keep",
		"rate": 30.0, "chests": {"3,15": {"gold": 80, "text": "80 gold in a drowned purse."},
			"13,10": {"gold": 0, "text": "An Ember Tonic: the party's wounds close a little.", "heal": 0.35}},
		"lever_text": "The lever groans. Beyond the black water, the portcullis rattles open.",
		"rows": [
		"##########################",
		"#####...~~~~....####>d.###",
		"####....~~~~.....###G#.###",
		"###..b...~~....C.##.K..###",
		"###......~~............###",
		"##....,...~~..........L###",
		"##..........~~..p.....####",
		"###...p.....==........####",
		"####.........~~~...,..####",
		"#####...,......~~.....####",
		"######..........~~...#####",
		"######....b.......~~.#####",
		"#######...........~~######",
		"########..C......~~#######",
		"#########...S.....########",
		"##########################",
	]},
	{"id": "bastion_2", "name": "The Reliquary Halls", "sub": "The Sunken Bastion  ·  Floor 2", "ground": "vespergate-sanctum",
		"guardian": "guardian_f2", "guardian_art": "knell", "guardian_flag": "bastion_f2", "bind_flag": "c4_bind",
		"tint": Color(0.6, 0.58, 0.66), "ambient": Color(0.4, 0.39, 0.46), "light": Color(1.0, 0.66, 0.4),
		"rate": 26.0, "key": "Bell Key", "chests": {"14,5": {"gold": 0, "key": true, "text": "The Bell Key, cold as river stone."},
			"11,20": {"gold": 140, "text": "140 gold in a tithe box."}},
		"door_text": "Locked. A heavy keyhole shaped like a bell.",
		"rows": [
		"##########################",
		"##<......#########...>..##",
		"##.......#########......##",
		"##..s.s..#########..s...##",
		"##.......#.......#......##",
		"###.....##...b...##.D.####",
		"####...###.......###K#####",
		"####...........,.....#####",
		"####...###.......###.#####",
		"###..,..##...p...##...####",
		"##.......#.......#.....###",
		"##.......##.....##..C..###",
		"##.......###...###.....###",
		"###.....#####.#####...####",
		"####.C.######.######.#####",
		"##########################",
	]},
	{"id": "bastion_3", "name": "The Unlit Throne", "sub": "The Sunken Bastion  ·  Floor 3", "ground": "unlit-throne",
		"tint": Color(0.52, 0.47, 0.6), "ambient": Color(0.4, 0.35, 0.42), "light": Color(1.0, 0.58, 0.3),
		"rate": 34.0, "safe_rows": 7, "chests": {},
		"rows": [
		"##########################",
		"###########.BBB.##########",
		"##########.......#########",
		"#########...s.s...########",
		"#########.........########",
		"##########...P...#########",
		"###########.....##########",
		"####b.....##...##.....b###",
		"###.........,.........####",
		"###..p...........p....####",
		"####.....b.....b.....#####",
		"#####...............######",
		"######.............#######",
		"########.....<...#########",
		"##########################",
	]},
]

static func floor_def(i: int) -> Dictionary:
	return FLOORS[clampi(i, 0, FLOORS.size() - 1)]

static func rows(i: int) -> Array:
	return floor_def(i).rows

static func size(i: int) -> Vector2i:
	var r: Array = rows(i)
	return Vector2i(str(r[0]).length(), r.size())

static func at(i: int, c: Vector2i) -> String:
	var r: Array = rows(i)
	if c.y < 0 or c.y >= r.size(): return "#"
	var s: String = r[c.y]
	if c.x < 0 or c.x >= s.length(): return "#"
	return s[c.x]

## First cell holding ch on floor i (or (-1,-1)).
static func find(i: int, ch: String) -> Vector2i:
	var r: Array = rows(i)
	for y in r.size():
		var x: int = str(r[y]).find(ch)
		if x >= 0: return Vector2i(x, y)
	return Vector2i(-1, -1)

static func find_all(i: int, ch: String) -> Array:
	var out: Array = []
	var r: Array = rows(i)
	for y in r.size():
		var s: String = r[y]
		for x in s.length():
			if s[x] == ch: out.append(Vector2i(x, y))
	return out

## Can the hero stand here? open: what is open on this floor ("G" gate, "D" door, "d" side door, "K" guardian gone).
static func walkable(i: int, c: Vector2i, open: Dictionary) -> bool:
	var ch := at(i, c)
	match ch:
		"#", "~", "b", "p", "s", "C", "L", "P": return false
		"K": return bool(open.get("K", false))
		"d": return bool(open.get("d", false))
		"G": return bool(open.get("G", false))
		"D": return bool(open.get("D", false))
		"B": return false
	return true
