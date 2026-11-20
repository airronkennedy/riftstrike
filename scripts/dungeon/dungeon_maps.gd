class_name DungeonMaps
extends RefCounted
## The Vespergate Deeps: three floors under the Coalvein Cave (docs/DUNGEON.md). 48 px tiles.
## Legend:
##   #  wall          .  floor        ,  rubble floor   ~  lava (blocks, glows)   =  stone bridge over lava
##   S  entrance stairs (leave to the overworld)        <  stairs up       >  stairs down
##   C  chest   L  lever (opens every G)   G  portcullis   D  locked door (needs the floor's key)
##   P  ember shrine save point (heals, saves)          B  sealed boss door (final boss)
##   b  brazier (light)   p  pillar   s  keeper statue (all solid)

const TILE := 48.0

const FLOORS := [
	{"id": "deeps_1", "name": "Coalvein Shafts", "sub": "The Vespergate Deeps  ·  Floor 1", "ground": "coalvein-deeps",
		"tint": Color(0.5, 0.42, 0.38), "ambient": Color(0.42, 0.36, 0.36), "light": Color(1.0, 0.62, 0.32),
		"rate": 30.0, "chests": {"3,15": {"gold": 80, "text": "80 gold, warm from the seam."},
			"13,10": {"gold": 0, "text": "An Ember Tonic: the party's wounds close a little.", "heal": 0.35}},
		"lever_text": "The lever groans. Far off, a portcullis rattles open.",
		"rows": [
		"##########################",
		"#####...~~~~....####>#####",
		"####....~~~~.....##.G.####",
		"###..b...~~....C.##...####",
		"###......~~...........####",
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
	{"id": "deeps_2", "name": "Cinder Vault", "sub": "The Vespergate Deeps  ·  Floor 2", "ground": "unlit-throne",
		"tint": Color(0.6, 0.58, 0.66), "ambient": Color(0.4, 0.39, 0.46), "light": Color(1.0, 0.66, 0.4),
		"rate": 26.0, "key": "Vault Key", "chests": {"14,5": {"gold": 0, "key": true, "text": "The Vault Key, cold as river stone."},
			"11,20": {"gold": 140, "text": "140 gold in a tithe box."}},
		"door_text": "Locked. A heavy keyhole shaped like a flame.",
		"rows": [
		"##########################",
		"##<......#########...>..##",
		"##.......#########......##",
		"##..s.s..#########..s...##",
		"##.......#.......#......##",
		"###.....##...b...##.D.####",
		"####...###.......###.#####",
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
	{"id": "deeps_3", "name": "Vespergate Sanctum", "sub": "The Vespergate Deeps  ·  Floor 3", "ground": "vespergate-sanctum",
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

## Can the hero stand here? open: ids of opened gates / doors on this floor ("G", "D").
static func walkable(i: int, c: Vector2i, open: Dictionary) -> bool:
	var ch := at(i, c)
	match ch:
		"#", "~", "b", "p", "s", "C", "L", "P": return false
		"G": return bool(open.get("G", false))
		"D": return bool(open.get("D", false))
		"B": return false
	return true
