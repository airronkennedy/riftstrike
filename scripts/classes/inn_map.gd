extends RefCounted
## The Ember Inn, inside (kingdom map "inn", docs/CLASSES.md). The counter rests the party (the old inn panel),
## and Adeyo the Star-Reader keeps the candle-lit corner where keepers change their calling (a Story NPC).
static func map() -> Dictionary:
	return {
		"id": "inn", "name": "The Ember Inn", "sub": "Warm beds, cold ale, one diviner", "indoor": true, "rows": [
			"############",
			"#,,,,,,,,,,#",
			"#,,,,,,,,,,#",
			"#,,,,,,,,,,#",
			"#,,,,,,,,,,#",
			"#,,,,,,,,,,#",
			"#,,,,,,,,,,#",
			"#####,,#####",
		],
		"particles": "dust", "encounters": false,
		"start": Vector2(6.0, 6.4),
		"props": [
			{"img": "fire", "x": 2.0, "y": 1.8, "s": 0.5, "light": true},
			{"img": "bookshelf", "x": 4.0, "y": 1.3, "s": 1.3}, {"img": "barrels", "x": 10.4, "y": 1.6, "s": 1.3},
			{"img": "banquet_table", "x": 4.0, "y": 4.4, "s": 1.3}, {"img": "banquet_table", "x": 4.0, "y": 6.0, "s": 1.1},
			{"img": "sconce", "x": 6.0, "y": 1.0, "s": 1.2}, {"img": "sconce", "x": 8.4, "y": 1.0, "s": 1.2},
			{"img": "candelabra", "x": 8.2, "y": 4.0, "s": 1.2}, {"img": "candelabra", "x": 10.6, "y": 4.0, "s": 1.2},
			{"img": "urn_plant", "x": 1.4, "y": 6.3, "s": 1.0}, {"img": "urn_plant", "x": 10.6, "y": 6.3, "s": 1.0},
			{"img": "chest", "x": 7.4, "y": 1.7, "s": 0.42},
		],
		"decals": [{"img": "rug_round", "x": 9.4, "y": 3.6, "s": 1.5}],
		"fg": [{"img": "chandelier", "x": 5.0, "y": 4.2, "s": 1.6, "dark": 1.0, "par": 0.3}],
		"npcs": [],
		"spots": [
			{"id": "inn_counter", "x": 7.2, "y": 2.2, "name": "The Counter", "prompt": "Rest", "action": "inn"},
		],
		"warps": [{"rect": Rect2(5, 7, 2, 1), "to": "town", "at": Vector2(16.5, 9.9), "name": "Emberhold"}],
	}
