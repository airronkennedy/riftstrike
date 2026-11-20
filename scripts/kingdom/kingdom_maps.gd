class_name KingdomMaps
extends RefCounted
## Data for the starting kingdom: Emberhold town, its castle and the small island overworld (Cinderreach).
## Ground is ASCII (one char per 64 px tile). Props are Airron's Fall sprites from assets/af/gen; x/y are the
## sprite's foot (bottom centre) in tile units. Spots are things you can use with the interact button; warps fire
## when you step on them.
##   . grass   , cobble/road   ~ water   : sand   f forest floor   ^ highland grass   # wall/cliff   T tree
##   c carpet (castle)   P pillar (castle)

const TILE := 64.0

# Random encounters: tiles walked to fill the danger meter, per overworld region (lower = more dangerous).
const REGIONS := {
	"meadow": {"name": "Hearthmeadow", "tiles": 26.0},
	"forest": {"name": "Gloamwood", "tiles": 15.0},
	"highlands": {"name": "Ashen Heights", "tiles": 19.0},
	"shore": {"name": "Saltglass Shore", "tiles": 34.0},
	"road": {"name": "King's Road", "tiles": 60.0},
}

const TOWN := [
	"TTTTTTTTTTTTTTTTTTTTTTTT",
	"T..........,,..........T",
	"T..........,,..........T",
	"T..........,,..........T",
	"T..........,,..........T",
	"T...,,,,,,,,,,,,,,,,...T",
	"T...,......,,......,...T",
	"T...,......,,......,...T",
	"T...,......,,......,...T",
	"T...,,,,,,,,,,,,,,,,...T",
	"T~~.,......,,......,...T",
	"T~~.,......,,......,...T",
	"T...,......,,......,...T",
	"T...,,,,,,,,,,,,,,,,...T",
	"T..........,,..........T",
	"T..........,,..........T",
	"T..........,,..........T",
	"TTTTTTTTTTT,,TTTTTTTTTTT",
]

const CASTLE := [
	"####################",
	"####,,,,,,,,,,,,####",
	"####,,,,,,,,,,,,####",
	"####,P,,,cc,,,P,####",
	"####,,,,,cc,,,,,####",
	"####,P,,,cc,,,P,####",
	"####,,,,,cc,,,,,####",
	"####,P,,,cc,,,P,####",
	"####,,,,,cc,,,,,####",
	"#########cc#########",
	"#,,,,,,,,cc,,,,,,,,#",
	"#,P,,,,,,cc,,,,,,P,#",
	"#,,,,,,,,cc,,,,,,,,#",
	"#,,,,,,,,cc,,,,,,,,#",
	"#,,,####,cc,####,,,#",
	"#,,,####,cc,####,,,#",
	"#,,,####,cc,####,,,#",
	"#,,,####,cc,####,,,#",
	"#,,,####,cc,####,,,#",
	"########,cc,########",
	"########,cc,########",
	"#########cc#########",
]

static var _overworld: Array = []


## The island is generated (deterministic) so it stays small and always closed by water.
static func overworld_rows() -> Array:
	if not _overworld.is_empty():
		return _overworld
	var w := 44
	var h := 32
	var rows: Array = []
	for r in h:
		var line := ""
		for c in w:
			var dx := (float(c) - 22.0) / 18.5
			var dy := (float(r) - 16.0) / 12.5
			var ang := atan2(dy, dx)
			var wob := 0.08 * sin(ang * 3.0 + 0.7) + 0.05 * sin(ang * 7.0 + 2.1) + 0.03 * sin(ang * 13.0)
			var d := sqrt(dx * dx + dy * dy) - wob
			var ch := "~"
			if d < 0.9:
				ch = "."
				if c < 17 and r > 6 and r < 26:
					ch = "f"
				if c > 24 and r < 15:
					ch = "^"
			elif d < 1.0:
				ch = ":"
			line += ch
		rows.append(line)
	# Gloamwood: scattered blocking trees inside the forest floor, leaving a winding clear path.
	for r in h:
		var row: String = rows[r]
		for c in w:
			if row[c] == "f" and ((c * 7 + r * 13) % 5 == 0) and absi(r - (13 + int(3.0 * sin(c * 0.5)))) > 1:
				row[c] = "T"
		rows[r] = row
	# Ashen Heights cliffs: a ridge of rock with the overlook ledge at its east end.
	for c in range(26, 37):
		var rr := 9 + int(round(1.5 * sin(c * 0.6)))
		_put(rows, c, rr, "#")
	_put(rows, 31, 9 + int(round(1.5 * sin(31 * 0.6))), "^") # pass through the ridge
	# King's Road: town gate south to the shore, plus branches to each landmark.
	_road(rows, Vector2i(22, 20), Vector2i(22, 26))
	_road(rows, Vector2i(22, 20), Vector2i(13, 20))
	_road(rows, Vector2i(22, 20), Vector2i(31, 20))
	_road(rows, Vector2i(22, 20), Vector2i(22, 12))
	_road(rows, Vector2i(22, 12), Vector2i(31, 12))
	_overworld = rows
	return rows


static func _put(rows: Array, c: int, r: int, ch: String) -> void:
	var row: String = rows[r]
	if row[c] != "~":
		row[c] = ch
		rows[r] = row


static func _road(rows: Array, a: Vector2i, b: Vector2i) -> void:
	var p := a
	while true:
		_put(rows, p.x, p.y, ",")
		if p == b:
			break
		if p.x != b.x:
			p.x += signi(b.x - p.x)
		else:
			p.y += signi(b.y - p.y)


## One map: name, ground rows, look (tint / particles / light), props, spots and warps.
static func get_map(id: String) -> Dictionary:
	match id:
		"town":
			return {
				"id": "town", "name": "Emberhold", "sub": "The Kingdom of Emberhold", "rows": TOWN,
				"tint": Color(1.0, 0.93, 0.84), "particles": "embers", "encounters": false, "torch": 0.55,
				"start": Vector2(12.0, 15.5),
				"props": [
					{"img": "castle_blue", "x": 12.0, "y": 5.0, "s": 1.0},
					{"img": "house_yellow", "x": 7.5, "y": 9.0, "s": 0.95, "label": "General Store"},
					{"img": "house_red", "x": 16.5, "y": 9.0, "s": 0.95, "label": "The Ember Inn"},
					{"img": "house_blue", "x": 7.5, "y": 13.0, "s": 0.95, "label": "Bramwell's House"},
					{"img": "house_purple", "x": 16.5, "y": 13.0, "s": 0.95},
					{"img": "house_red", "x": 2.5, "y": 5.0, "s": 0.85},
					{"img": "tower_yellow", "x": 21.0, "y": 5.0, "s": 0.75},
					{"img": "house_purple", "x": 5.5, "y": 17.0, "s": 0.85},
					{"img": "hut", "x": 18.5, "y": 17.0, "s": 0.85},
					{"img": "house_yellow", "x": 21.0, "y": 12.0, "s": 0.8},
					{"img": "fire", "x": 12.0, "y": 11.4, "s": 0.6, "light": true},
				],
				"npcs": [
					{"hero": "pell", "x": 9.5, "y": 9.6, "text": "Pell: The store buys anything you can carry. Mostly."},
					{"hero": "wenna", "x": 14.0, "y": 13.6, "text": "Wenna: Danger stirs once you leave the walls. Watch the ember meter."},
				],
				"spots": [
					{"id": "store", "x": 7.5, "y": 9.3, "name": "General Store", "prompt": "Shop", "action": "shop"},
					{"id": "inn", "x": 16.5, "y": 9.3, "name": "The Ember Inn", "prompt": "Rest", "action": "inn"},
					{"id": "gate", "x": 12.0, "y": 5.3, "name": "Castle Gate", "prompt": "Enter", "action": "warp", "to": "castle", "at": Vector2(10.0, 20.5)},
					{"id": "house", "x": 7.5, "y": 13.3, "name": "Bramwell's House", "prompt": "Enter", "action": "warp", "to": "house", "at": Vector2(4.0, 6.5)},
				],
				"warps": [{"rect": Rect2(11, 17, 2, 1), "to": "overworld", "at": Vector2(22.0, 21.5), "name": "Town Exit"}],
			}
		"castle":
			return {
				"id": "castle", "name": "Castle Emberhold", "sub": "Seat of the Ember Crown", "rows": CASTLE,
				"tint": Color(0.62, 0.55, 0.52), "particles": "dust", "encounters": false, "torch": 0.9,
				"start": Vector2(10.0, 20.5),
				"props": [
					{"img": "throne", "x": 10.0, "y": 2.2, "s": 1.0},
					{"img": "fire", "x": 5.5, "y": 2.4, "s": 0.55, "light": true}, {"img": "fire", "x": 14.5, "y": 2.4, "s": 0.55, "light": true},
					{"img": "fire", "x": 5.5, "y": 8.4, "s": 0.5, "light": true}, {"img": "fire", "x": 14.5, "y": 8.4, "s": 0.5, "light": true},
					{"img": "fire", "x": 1.5, "y": 10.6, "s": 0.5, "light": true}, {"img": "fire", "x": 18.5, "y": 10.6, "s": 0.5, "light": true},
					{"img": "statue:halvard", "x": 2.0, "y": 15.6, "s": 0.42}, {"img": "statue:aurel", "x": 2.0, "y": 17.8, "s": 0.42},
					{"img": "statue:idra", "x": 18.0, "y": 15.6, "s": 0.42}, {"img": "statue:caldric", "x": 18.0, "y": 17.8, "s": 0.42},
					{"img": "chest", "x": 3.0, "y": 13.8, "s": 0.5},
				],
				"npcs": [
					{"hero": "orlan", "x": 10.0, "y": 2.6, "text": "King Orlan: Keeper, the ember fades beyond our walls. Ruins, caves, a shrine... find what wakes there."},
					{"hero": "selka", "x": 8.0, "y": 12.0, "text": "Selka: The Great Hall. West is the Hall of Keepers, east the Gallery of Banners."},
				],
				"spots": [
					{"id": "throne", "x": 10.0, "y": 3.4, "name": "The Ember Throne", "prompt": "Look", "action": "text", "text": "The Ember Throne. Its coals have burned for nine kings."},
					{"id": "keepers", "x": 2.0, "y": 16.7, "name": "Hall of Keepers", "prompt": "Look", "action": "text", "text": "Stone keepers stand watch. One plinth is still empty."},
					{"id": "banners", "x": 18.0, "y": 16.7, "name": "Gallery of Banners", "prompt": "Look", "action": "text", "text": "Banners of every house that swore to the Ember Crown."},
				],
				"warps": [{"rect": Rect2(9, 21, 2, 1), "to": "town", "at": Vector2(12.0, 6.2), "name": "Castle Gate"}],
				"zones": [
					{"rect": Rect2(4, 1, 12, 8), "name": "Throne Room"}, {"rect": Rect2(1, 10, 18, 4), "name": "Great Hall"},
					{"rect": Rect2(1, 14, 3, 5), "name": "Hall of Keepers"}, {"rect": Rect2(16, 14, 3, 5), "name": "Gallery of Banners"},
					{"rect": Rect2(8, 14, 4, 8), "name": "Entrance Hall"},
				],
			}
		"house":
			return {
				"id": "house", "name": "Bramwell's House", "sub": "A placeholder interior", "rows": [
					"########",
					"#,,,,,,#",
					"#,,,,,,#",
					"#,,,,,,#",
					"#,,,,,,#",
					"#,,,,,,#",
					"###,,###",
				],
				"tint": Color(0.75, 0.66, 0.58), "particles": "dust", "encounters": false, "torch": 0.8,
				"start": Vector2(4.0, 5.5),
				"props": [{"img": "fire", "x": 2.0, "y": 1.8, "s": 0.45, "light": true}, {"img": "chest", "x": 6.0, "y": 2.0, "s": 0.45}],
				"npcs": [{"hero": "bramwell", "x": 5.0, "y": 3.0, "text": "Bramwell: Make yourself at home. The rest of the house is still being built."}],
				"spots": [],
				"warps": [{"rect": Rect2(3, 6, 2, 1), "to": "town", "at": Vector2(7.5, 13.9), "name": "Emberhold"}],
			}
		"overworld":
			return {
				"id": "overworld", "name": "Cinderreach", "sub": "The isle around Emberhold", "rows": overworld_rows(),
				"tint": Color(0.92, 0.9, 0.95), "particles": "motes", "encounters": true, "torch": 0.35,
				"start": Vector2(22.0, 21.5),
				"props": [
					{"img": "castle_blue", "x": 22.0, "y": 20.0, "s": 0.55}, {"img": "house_red", "x": 20.4, "y": 20.0, "s": 0.4}, {"img": "house_yellow", "x": 23.6, "y": 20.0, "s": 0.4},
					{"img": "castle_ruin", "x": 32.0, "y": 21.0, "s": 0.6}, {"img": "tower_ruin", "x": 34.5, "y": 22.0, "s": 0.5},
					{"img": "deco18", "x": 9.0, "y": 13.0, "s": 0.9},
					{"img": "goldmine", "x": 32.0, "y": 6.2, "s": 0.7},
					{"img": "shrine", "x": 12.5, "y": 20.0, "s": 1.0, "light": true},
					{"img": "wtower", "x": 37.0, "y": 11.5, "s": 0.45},
				],
				"npcs": [],
				"spots": [
					{"id": "town", "x": 22.0, "y": 20.3, "name": "Emberhold", "prompt": "Enter", "action": "warp", "to": "town", "at": Vector2(12.0, 16.2)},
					{"id": "ruin", "x": 32.0, "y": 21.4, "name": "Sunken Bastion", "prompt": "Look", "action": "text", "text": "Sunken Bastion: a fallen keep. Ash drifts up from the cellars (dungeon coming soon)."},
					{"id": "forest", "x": 9.0, "y": 13.5, "name": "Gloamwood Heart", "prompt": "Look", "action": "text", "text": "Gloamwood Heart: the oldest tree on the isle hums with a low ember light."},
					{"id": "cave", "x": 32.0, "y": 6.6, "name": "Coalvein Cave", "prompt": "Look", "action": "text", "text": "Coalvein Cave: warm air breathes out of the dark (cave coming soon)."},
					{"id": "shrine", "x": 12.5, "y": 20.4, "name": "Votive Shrine", "prompt": "Pray", "action": "text", "text": "Votive Shrine: you feel the danger in the air settle.", "calm": true},
					{"id": "overlook", "x": 37.0, "y": 11.9, "name": "Cliff Overlook", "prompt": "Look", "action": "text", "text": "Cliff Overlook: the whole of Cinderreach below, and nothing but sea beyond."},
				],
				"warps": [],
			}
	return {}
