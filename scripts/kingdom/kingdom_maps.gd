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


## Per-map look: post grading (tint / saturation / contrast / warmth), god rays, bloom, the CanvasModulate tint
## and the torch. "forest" is blended in on the overworld while you walk through Gloamwood.
const GRADES := {
	"town": {"tint": Color(1.02, 1.0, 0.96), "sat": 1.04, "con": 1.06, "warm": 0.08, "rays": 0.1, "bloom": 0.22, "mod": Color(0.9, 0.86, 0.82), "torch": 0.3},
	"overworld": {"tint": Color(1.0, 1.0, 1.02), "sat": 1.05, "con": 1.05, "warm": 0.04, "rays": 0.08, "bloom": 0.2, "mod": Color(0.96, 0.95, 1.0), "torch": 0.3},
	"forest": {"tint": Color(0.95, 1.02, 0.95), "sat": 1.02, "con": 1.08, "warm": -0.04, "rays": 0.16, "bloom": 0.3, "mod": Color(0.66, 0.74, 0.66), "torch": 0.7},
	"castle": {"tint": Color(1.02, 0.97, 0.92), "sat": 0.98, "con": 1.1, "warm": 0.1, "rays": 0.18, "bloom": 0.32, "mod": Color(0.42, 0.38, 0.42), "torch": 0.55},
	"inn": {"tint": Color(1.04, 0.96, 0.9), "sat": 1.0, "con": 1.06, "warm": 0.14, "rays": 0.06, "bloom": 0.34, "mod": Color(0.48, 0.42, 0.44), "torch": 0.6},
	"house": {"tint": Color(1.02, 0.97, 0.92), "sat": 1.0, "con": 1.06, "warm": 0.1, "rays": 0.08, "bloom": 0.3, "mod": Color(0.5, 0.45, 0.45), "torch": 0.55},
}


## One map: name, ground rows, look, props, foreground occluders, spots and warps.
static func get_map(id: String) -> Dictionary:
	match id:
		"town":
			return {
				"id": "town", "name": "Emberhold", "sub": "The Kingdom of Emberhold", "rows": TOWN,
				"particles": "embers", "encounters": false, "birds": true,
				"start": Vector2(12.0, 15.5),
				"props": [
					{"img": "bld_gatehouse", "x": 12.0, "y": 5.0, "s": 3.0},
					{"img": "bld_store", "x": 7.5, "y": 9.0, "label": "General Store"},
					{"img": "bld_inn", "x": 16.5, "y": 9.0, "label": "The Ember Inn"},
					{"img": "bld_cottage", "x": 7.5, "y": 13.0, "label": "Bramwell's House"},
					{"img": "bld_chapel", "x": 16.5, "y": 13.0},
					{"img": "bld_townhouse", "x": 2.4, "y": 5.0, "s": 1.6},
					{"img": "bld_tower", "x": 21.2, "y": 5.0, "s": 1.7},
					{"img": "bld_smithy", "x": 21.4, "y": 12.6, "s": 1.5},
					{"img": "bld_farmhouse", "x": 2.4, "y": 16.6, "s": 1.5},
					{"img": "bld_cottage", "x": 21.0, "y": 16.6, "s": 1.5, "flip": true},
					{"img": "well", "x": 13.9, "y": 12.3, "s": 1.5},
					{"img": "market_stall", "x": 13.9, "y": 8.4, "s": 1.6},
					{"img": "brazier", "x": 10.2, "y": 5.5, "s": 1.6}, {"img": "brazier", "x": 13.8, "y": 5.5, "s": 1.6},
					{"img": "lamp_post", "x": 5.3, "y": 8.8, "s": 1.6}, {"img": "lamp_post", "x": 18.7, "y": 8.8, "s": 1.6},
					{"img": "lamp_post", "x": 5.3, "y": 12.8, "s": 1.6}, {"img": "lamp_post", "x": 18.7, "y": 12.8, "s": 1.6},
					{"img": "lamp_post", "x": 10.5, "y": 16.6, "s": 1.6},
					{"img": "fence", "x": 6.0, "y": 4.6, "s": 1.6}, {"img": "fence", "x": 8.1, "y": 4.6, "s": 1.6},
					{"img": "fence", "x": 15.9, "y": 4.6, "s": 1.6}, {"img": "fence", "x": 18.0, "y": 4.6, "s": 1.6},
					{"img": "barrels", "x": 10.3, "y": 12.6, "s": 1.4}, {"img": "barrels", "x": 20.4, "y": 8.4, "s": 1.4},
					{"img": "planter", "x": 5.7, "y": 10.4, "s": 1.2}, {"img": "planter", "x": 18.3, "y": 10.4, "s": 1.2},
					{"img": "hay_bale", "x": 4.2, "y": 16.7, "s": 1.4}, {"img": "signpost", "x": 13.5, "y": 16.4, "s": 1.6},
					{"img": "bush", "x": 1.6, "y": 8.6, "s": 1.6}, {"img": "bush", "x": 22.4, "y": 14.4, "s": 1.6}, {"img": "bush", "x": 9.0, "y": 2.4, "s": 1.6},
					{"img": "bush", "x": 15.0, "y": 2.6, "s": 1.6}, {"img": "boulder", "x": 4.6, "y": 2.2, "s": 1.4},
				],
				"fg": [
					{"img": "tree_oak", "x": 1.0, "y": 18.9, "s": 3.0}, {"img": "tree_pine", "x": 6.5, "y": 19.2, "s": 3.0},
					{"img": "tree_oak", "x": 17.8, "y": 19.1, "s": 3.0}, {"img": "tree_willow", "x": 23.0, "y": 18.8, "s": 3.0},
				],
				"npcs": [
					{"hero": "pell", "x": 9.5, "y": 9.6, "text": "Pell: The store buys anything you can carry. Mostly."},
					{"hero": "wenna", "x": 14.0, "y": 13.6, "text": "Wenna: Danger stirs once you leave the walls. Watch the ember meter."},
					{"hero": "joryn", "x": 15.2, "y": 9.7, "text": "Joryn: Fresh from the stall! Well, fresh-ish."},
				],
				"spots": [
					{"id": "store", "x": 7.5, "y": 9.3, "name": "General Store", "prompt": "Shop", "action": "shop"},
					{"id": "inn", "x": 16.5, "y": 9.3, "name": "The Ember Inn", "prompt": "Enter", "action": "warp", "to": "inn", "at": Vector2(6.0, 6.4)},
					{"id": "gate", "x": 12.0, "y": 5.3, "name": "Castle Gate", "prompt": "Enter", "action": "warp", "to": "castle", "at": Vector2(10.0, 20.5)},
					{"id": "house", "x": 7.5, "y": 13.3, "name": "Bramwell's House", "prompt": "Enter", "action": "warp", "to": "house", "at": Vector2(4.0, 6.5)},
				],
				"warps": [{"rect": Rect2(11, 17, 2, 1), "to": "overworld", "at": Vector2(22.0, 21.5), "name": "Town Exit"}],
			}
		"castle":
			return {
				"id": "castle", "name": "Castle Emberhold", "sub": "Seat of the Ember Crown", "rows": CASTLE,
				"particles": "dust", "encounters": false,
				"start": Vector2(10.0, 20.5),
				"props": [
					{"img": "throne", "x": 10.0, "y": 2.3, "s": 2.4},
					{"img": "window_stained", "x": 5.6, "y": 1.02, "s": 1.25}, {"img": "window_stained", "x": 8.0, "y": 1.02, "s": 1.25},
					{"img": "window_stained", "x": 12.0, "y": 1.02, "s": 1.25}, {"img": "window_stained", "x": 14.4, "y": 1.02, "s": 1.25},
					{"img": "banner", "x": 6.8, "y": 1.05, "s": 1.6}, {"img": "banner", "x": 13.2, "y": 1.05, "s": 1.6},
					{"img": "brazier", "x": 5.5, "y": 2.7, "s": 1.6}, {"img": "brazier", "x": 14.5, "y": 2.7, "s": 1.6},
					{"img": "brazier", "x": 5.5, "y": 8.6, "s": 1.6}, {"img": "brazier", "x": 14.5, "y": 8.6, "s": 1.6},
					{"img": "sconce", "x": 3.0, "y": 10.0, "s": 1.4}, {"img": "sconce", "x": 7.0, "y": 10.0, "s": 1.4},
					{"img": "sconce", "x": 13.0, "y": 10.0, "s": 1.4}, {"img": "sconce", "x": 17.0, "y": 10.0, "s": 1.4},
					{"img": "banquet_table", "x": 5.2, "y": 12.6, "s": 1.7}, {"img": "banquet_table", "x": 14.8, "y": 12.6, "s": 1.7},
					{"img": "candelabra", "x": 7.7, "y": 11.0, "s": 1.4}, {"img": "candelabra", "x": 12.3, "y": 11.0, "s": 1.4},
					{"img": "urn_plant", "x": 1.5, "y": 13.7, "s": 1.3}, {"img": "urn_plant", "x": 18.5, "y": 13.7, "s": 1.3},
					{"img": "statue:halvard", "x": 2.0, "y": 15.6, "s": 0.42}, {"img": "statue:aurel", "x": 2.0, "y": 17.8, "s": 0.42},
					{"img": "banner", "x": 16.4, "y": 15.1, "s": 1.5}, {"img": "banner", "x": 16.4, "y": 17.5, "s": 1.5},
					{"img": "weapon_rack", "x": 18.0, "y": 18.7, "s": 1.4}, {"img": "armor_stand", "x": 18.3, "y": 14.9, "s": 1.4},
					{"img": "armor_stand", "x": 8.4, "y": 16.0, "s": 1.4}, {"img": "armor_stand", "x": 11.6, "y": 16.0, "s": 1.4, "flip": true},
					{"img": "knight_statue", "x": 8.4, "y": 18.6, "s": 1.4}, {"img": "knight_statue", "x": 11.6, "y": 18.6, "s": 1.4, "flip": true},
					{"img": "chest", "x": 3.0, "y": 13.8, "s": 0.5},
				],
				"decals": [{"img": "rug_round", "x": 10.0, "y": 12.9, "s": 2.2}],
				"fg": [
					{"img": "chandelier", "x": 7.0, "y": 5.2, "s": 2.0, "dark": 1.0, "par": 0.3}, {"img": "chandelier", "x": 13.0, "y": 5.2, "s": 2.0, "dark": 1.0, "par": 0.3},
					{"img": "chandelier", "x": 6.0, "y": 12.2, "s": 2.0, "dark": 1.0, "par": 0.3}, {"img": "chandelier", "x": 14.0, "y": 12.2, "s": 2.0, "dark": 1.0, "par": 0.3},
				],
				"npcs": [
					{"hero": "orlan", "x": 10.0, "y": 3.0, "text": "King Orlan: Keeper, the ember fades beyond our walls. Ruins, caves, a shrine... find what wakes there."},
					{"hero": "selka", "x": 8.0, "y": 12.0, "text": "Selka: The Great Hall. West is the Hall of Keepers, east the Gallery of Banners."},
				],
				"spots": [
					{"id": "throne", "x": 10.0, "y": 3.6, "name": "The Ember Throne", "prompt": "Look", "action": "text", "text": "The Ember Throne. Its coals have burned for nine kings."},
					{"id": "keepers", "x": 2.0, "y": 16.7, "name": "Hall of Keepers", "prompt": "Look", "action": "text", "text": "Stone keepers stand watch. One plinth is still empty."},
					{"id": "banners", "x": 17.4, "y": 16.4, "name": "Gallery of Banners", "prompt": "Look", "action": "text", "text": "Banners of every house that swore to the Ember Crown."},
				],
				"warps": [{"rect": Rect2(9, 21, 2, 1), "to": "town", "at": Vector2(12.0, 6.2), "name": "Castle Gate"}],
				"zones": [
					{"rect": Rect2(4, 1, 12, 8), "name": "Throne Room"}, {"rect": Rect2(1, 10, 18, 4), "name": "Great Hall"},
					{"rect": Rect2(1, 14, 3, 5), "name": "Hall of Keepers"}, {"rect": Rect2(16, 14, 3, 5), "name": "Gallery of Banners"},
					{"rect": Rect2(8, 14, 4, 8), "name": "Entrance Hall"},
				],
			}
		"inn": # inside the Ember Inn: rest at the counter, Adeyo's divination corner (scripts/classes/inn_map.gd)
			return preload("res://scripts/classes/inn_map.gd").map()
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
				"particles": "dust", "encounters": false,
				"start": Vector2(4.0, 5.5),
				"props": [
					{"img": "fire", "x": 2.0, "y": 1.8, "s": 0.45, "light": true}, {"img": "chest", "x": 6.3, "y": 2.0, "s": 0.45},
					{"img": "bookshelf", "x": 4.6, "y": 1.3, "s": 1.3}, {"img": "urn_plant", "x": 6.4, "y": 5.4, "s": 1.1},
					{"img": "sconce", "x": 3.2, "y": 1.0, "s": 1.2},
				],
				"decals": [{"img": "rug_round", "x": 4.0, "y": 4.4, "s": 1.6}],
				"fg": [],
				"npcs": [{"hero": "bramwell", "x": 5.0, "y": 3.0, "text": "Bramwell: Make yourself at home. The rest of the house is still being built."}],
				"spots": [],
				"warps": [{"rect": Rect2(3, 6, 2, 1), "to": "town", "at": Vector2(7.5, 13.9), "name": "Emberhold"}],
			}
		"overworld":
			return {
				"id": "overworld", "name": "Cinderreach", "sub": "The isle around Emberhold", "rows": overworld_rows(),
				"particles": "motes", "encounters": true, "birds": true,
				"start": Vector2(22.0, 21.5),
				"props": [
					{"img": "bld_gatehouse", "x": 22.0, "y": 20.0, "s": 1.3}, {"img": "bld_cottage", "x": 20.2, "y": 20.0, "s": 0.9}, {"img": "bld_inn", "x": 23.9, "y": 20.0, "s": 0.9},
					{"img": "fence", "x": 19.0, "y": 21.4, "s": 1.4}, {"img": "fence", "x": 25.0, "y": 21.4, "s": 1.4}, {"img": "hay_bale", "x": 25.4, "y": 22.6, "s": 1.3},
					{"img": "signpost", "x": 22.9, "y": 23.6, "s": 1.6},
					{"img": "ruin", "x": 32.0, "y": 21.0, "s": 2.2}, {"img": "boulder", "x": 34.2, "y": 21.8, "s": 1.5}, {"img": "pillar", "x": 30.0, "y": 22.4, "s": 1.4},
					{"img": "tree_willow", "x": 9.0, "y": 13.0, "s": 2.8}, {"img": "brazier", "x": 10.3, "y": 13.6, "s": 1.3},
					{"img": "cave_mouth", "x": 32.0, "y": 6.2, "s": 2.2}, {"img": "boulder", "x": 30.2, "y": 6.6, "s": 1.4},
					{"img": "shrine", "x": 12.5, "y": 20.0, "s": 2.0}, {"img": "bush", "x": 11.2, "y": 20.4, "s": 1.4}, {"img": "bush", "x": 13.8, "y": 20.4, "s": 1.4},
					{"img": "cairn", "x": 37.0, "y": 11.5, "s": 1.8}, {"img": "signpost", "x": 35.9, "y": 12.3, "s": 1.5},
					{"img": "boulder", "x": 27.0, "y": 13.2, "s": 1.6}, {"img": "boulder", "x": 18.5, "y": 25.0, "s": 1.3}, {"img": "stump", "x": 16.6, "y": 17.4, "s": 1.4},
					{"img": "bush", "x": 26.4, "y": 24.4, "s": 1.6}, {"img": "bush", "x": 17.6, "y": 9.2, "s": 1.6}, {"img": "log", "x": 14.6, "y": 11.3, "s": 1.3},
				],
				"fg": [
					{"img": "tree_oak", "x": 5.5, "y": 10.8, "s": 3.2}, {"img": "tree_willow", "x": 11.5, "y": 17.4, "s": 3.2},
					{"img": "tree_pine", "x": 3.8, "y": 19.6, "s": 3.4}, {"img": "tree_oak", "x": 14.6, "y": 8.9, "s": 3.0},
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
