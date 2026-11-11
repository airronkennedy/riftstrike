#!/usr/bin/env python3
"""One-shot generator for the starting world data. After this first pass,
edit data/*.json and data/world_map.txt by hand; re-running overwrites them."""
import json, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
D = os.path.join(ROOT, "data")

# id, name, kind, act, rec, rec_max, hours, optional, map x, map y, built, blurb
A = [
 # Act I — The Riverlands
 ("rivenbrook","Rivenbrook","town",1,1,1,0.5,False,6,74,"walkable","Starter hamlet on the river. Home base."),
 ("brookside_meadow","Brookside Meadow","wild",1,2,4,1.0,False,17,64,"walkable","Tall-grass fields east of town. First wild encounters."),
 ("whisperreed_marsh","Whisperreed Marsh","wild",1,4,6,1.0,True,12,88,"walkable","Reedy ponds south of Rivenbrook. Optional loot and grinding."),
 ("old_mill_road","Old Mill Road","route",1,4,7,1.0,False,28,74,"walkable","Sandy road past the old mill toward Thornwick."),
 ("thornwick","Thornwick","town",1,7,7,0.5,False,39,74,"walkable","Crossroads town. First real fork in the road."),
 ("hollowpine_wood","Hollowpine Wood","wild",1,8,11,1.5,False,48,62,"walkable","Dense pine forest. North way to the fort."),
 ("saltmere_shore","Saltmere Shore","wild",1,8,11,1.5,False,48,86,"walkable","Dunes and tide pools. South way to the fort."),
 ("gullcliff_lighthouse","Gullcliff Lighthouse","dungeon",1,12,13,1.0,True,60,95,"stub","Sealed lighthouse on a sea spit. Optional climb."),
 ("ironbridge_fort","Ironbridge Fort","dungeon",1,13,14,1.5,False,58,74,"stub","Garrison over the gorge. Both forest and shore paths meet here."),
 # Act II — The Ember Highlands
 ("emberfall","Emberfall","town",2,15,15,0.5,False,68,66,"planned","Mining town on the highland rim."),
 ("kindlegrass_steppe","Kindlegrass Steppe","wild",2,16,19,1.5,False,74,55,"planned","Windy red-grass plains. Splits west and east."),
 ("redcap_hills","Redcap Hills","wild",2,24,27,1.0,True,84,68,"planned","Mushroom hills with tougher wild packs."),
 ("glasswind_canyon","Glasswind Canyon","route",2,19,22,1.5,False,64,45,"planned","West branch: crystal canyon toward the abbey."),
 ("sunken_abbey","Sunken Abbey","dungeon",2,23,25,2.0,False,56,35,"planned","Flooded abbey. Warden of Bells waits below."),
 ("mirefen_deep","Mirefen Deep","wild",2,20,23,1.5,False,84,47,"planned","East branch: bog wilds toward Foxglove."),
 ("foxglove_hamlet","Foxglove Hamlet","town",2,21,21,0.5,False,94,57,"planned","Hidden village in the fen."),
 ("lanternkeep","Lanternkeep","dungeon",2,25,27,2.0,False,94,38,"planned","Keep of hanging lanterns. Warden of Lanterns."),
 ("underroot_catacomb","Underroot Catacomb","dungeon",2,27,30,2.0,False,83,31,"planned","Root-choked tombs under the keep."),
 ("smokewater_caldera","Smokewater Caldera","dungeon",2,31,34,1.5,True,95,20,"planned","Optional volcanic lake below the catacomb."),
 # Act III — Frostveil
 ("frostveil_bridge","Frostveil Bridge","route",3,30,32,0.5,False,71,24,"planned","Long frozen bridge. Sealed until the abbey and catacomb fall."),
 ("frostveil","Frostveil","town",3,32,32,0.5,False,61,15,"planned","Snowbound city of spires."),
 ("moonlit_terraces","Moonlit Terraces","wild",3,33,36,1.5,False,49,10,"planned","Terraced gardens. Splits to the spire or the vault."),
 ("seers_spire","Seer's Spire","dungeon",3,37,40,2.0,False,37,4,"planned","West branch: tower of the Warden of Moons."),
 ("deepvault_prison","Deepvault Prison","dungeon",3,37,40,1.5,False,48,25,"planned","East branch: prison under the terraces."),
 ("molten_capital","Molten Capital","dungeon",3,41,44,2.0,False,38,33,"planned","Fallen city past the prison. Warden of the Forge."),
 ("hoarfrost_pass","Hoarfrost Pass","wild",3,42,45,1.0,True,28,20,"planned","Icy pass west of Frostveil. Back way to the crown lands."),
 # Act IV — The Crownlands
 ("kingshold_approach","Kingshold Approach","route",4,45,47,1.0,False,31,48,"planned","Royal road behind the fort, sealed by the royal ward."),
 ("kingshold_citadel","Kingshold Citadel","dungeon",4,48,51,2.0,False,20,55,"planned","The king's citadel."),
 ("withered_garden","Withered Royal Garden","wild",4,47,50,1.0,True,8,46,"planned","Optional overgrown palace garden."),
 ("drakespire_peak","Drakespire Peak","dungeon",4,55,58,1.5,True,6,31,"planned","Optional summit. Needs the drake sigil."),
 ("starfall_archive","Starfall Archive","dungeon",4,54,57,2.0,False,18,37,"planned","Library of falling stars. Last stop before the heart."),
 ("rift_heart","The Rift Heart","final",4,60,60,1.0,False,17,19,"planned","Where the rift began. Needs all four warden seals."),
 # Post-game
 ("hushed_hollow","Hushed Hollow","secret",5,65,68,1.0,True,23,92,"planned","Post-game secret behind Rivenbrook."),
 ("shattered_expanse","Shattered Expanse","postgame",5,75,85,2.0,True,8,8,"planned","Post-game rift fields."),
 ("riftsea_depths","Riftsea Depths","postgame",5,88,99,2.0,True,25,4,"planned","Post-game abyss. Level 99 content."),
]
ACTS = {1: "Act I · The Riverlands", 2: "Act II · The Ember Highlands", 3: "Act III · Frostveil", 4: "Act IV · The Crownlands", 5: "Post-game"}

# from, to, gate ("" = open)
C = [
 ("rivenbrook","brookside_meadow",""),("rivenbrook","whisperreed_marsh",""),("brookside_meadow","whisperreed_marsh",""),
 ("brookside_meadow","old_mill_road",""),("old_mill_road","thornwick",""),
 ("thornwick","hollowpine_wood",""),("thornwick","saltmere_shore",""),
 ("saltmere_shore","gullcliff_lighthouse","g_lighthouse_door"),
 ("hollowpine_wood","ironbridge_fort","g_fort_north"),("saltmere_shore","ironbridge_fort","g_fort_south"),
 ("ironbridge_fort","emberfall","g_ironbridge_span"),
 ("emberfall","kindlegrass_steppe",""),("emberfall","redcap_hills",""),
 ("kindlegrass_steppe","glasswind_canyon",""),("glasswind_canyon","sunken_abbey",""),
 ("kindlegrass_steppe","mirefen_deep",""),("mirefen_deep","foxglove_hamlet",""),("foxglove_hamlet","lanternkeep",""),
 ("lanternkeep","underroot_catacomb","g_catacomb_stair"),
 ("underroot_catacomb","smokewater_caldera","g_caldera_bridge"),
 ("sunken_abbey","frostveil_bridge",""),("underroot_catacomb","frostveil_bridge",""),
 ("frostveil_bridge","frostveil","g_frostveil_seal"),
 ("frostveil","moonlit_terraces",""),("moonlit_terraces","seers_spire",""),
 ("moonlit_terraces","deepvault_prison","g_deepvault_door"),("deepvault_prison","molten_capital",""),
 ("frostveil","hoarfrost_pass",""),
 ("ironbridge_fort","kingshold_approach","g_royal_ward"),("hoarfrost_pass","kingshold_approach","g_royal_ward_north"),
 ("kingshold_approach","kingshold_citadel",""),("kingshold_citadel","withered_garden",""),
 ("withered_garden","drakespire_peak","g_drake_altar"),
 ("kingshold_citadel","starfall_archive","g_archive_doors"),
 ("starfall_archive","rift_heart","g_rift_heart"),
 ("rivenbrook","hushed_hollow","g_hushed_hollow"),
 ("rift_heart","shattered_expanse","g_postgame"),("shattered_expanse","riftsea_depths",""),
]

# Gate requirement: all of `flags_all` set, at least one of `flags_any` (if listed),
# and at least `wardens_min` of the WARDEN flags. `enabled: false` turns the lock off.
G = {
 "g_lighthouse_door": dict(enabled=True, flags_all=["lighthouse_key"], text="The lighthouse door is rusted shut.",
   story="Placeholder: an old keeper in Whisperreed Marsh gives you the lighthouse key."),
 "g_fort_north": dict(enabled=True, flags_all=["thornwick_pass"], text="Fort sentries turn you back. You need a Thornwick pass.",
   story="Placeholder: earn the militia captain's pass in Thornwick (both fort paths check the same flag)."),
 "g_fort_south": dict(enabled=True, flags_all=["thornwick_pass"], text="The sea gate is barred. You need a Thornwick pass.",
   story="Placeholder: same pass as the north gate, so either branch works once you have it."),
 "g_ironbridge_span": dict(enabled=True, flags_all=["boss_ironbridge"], text="The bridge is raised.",
   story="Placeholder: defeat the fort's commander to lower the iron bridge."),
 "g_catacomb_stair": dict(enabled=True, flags_all=["warden_lanterns"], text="The stair is sealed by lantern light.",
   story="Placeholder: the seal fades when the Warden of Lanterns falls."),
 "g_caldera_bridge": dict(enabled=True, flags_all=["catacomb_bridge_dropped"], text="A rope bridge hangs out of reach.",
   story="Placeholder: cut the bridge mid-catacomb to drop down to the caldera."),
 "g_frostveil_seal": dict(enabled=True, flags_all=["warden_bells", "catacomb_cleared"], text="A frost seal blocks the bridge.",
   story="Placeholder: the abbey bell and the catacomb's cleared tombs together melt the seal."),
 "g_deepvault_door": dict(enabled=True, flags_all=["vault_key"], text="The prison door is locked.",
   story="Placeholder: a jailer's key is found in the Moonlit Terraces."),
 "g_royal_ward": dict(enabled=True, wardens_min=3, text="A royal ward holds the gate. Three warden seals will break it.",
   story="Placeholder: three of the four warden seals break the ward (either of two routes)."),
 "g_royal_ward_north": dict(enabled=True, wardens_min=3, text="The pass is warded. Three warden seals will break it.",
   story="Placeholder: same ward, reached from the frozen north."),
 "g_drake_altar": dict(enabled=True, flags_all=["drake_sigil"], text="An empty altar. Something belongs here.",
   story="Placeholder: the drake sigil is hidden in Kingshold Citadel."),
 "g_archive_doors": dict(enabled=True, flags_all=["boss_kingshold"], text="The archive doors are shut from inside.",
   story="Placeholder: beat the citadel's twin guardians to open the archive."),
 "g_rift_heart": dict(enabled=True, wardens_min=4, flags_all=["archive_cleared"], text="The rift will not open. All four warden seals are needed.",
   story="Placeholder: the final seal opens with all four wardens down and the archive cleared."),
 "g_hushed_hollow": dict(enabled=True, flags_all=["game_cleared"], text="A path you can't quite see.",
   story="Placeholder: post-game secret revealed after the ending."),
 "g_postgame": dict(enabled=True, flags_all=["game_cleared"], text="The rift is still collapsing.",
   story="Placeholder: post-game rift fields open after the ending."),
}

FLAGS = {
 "lighthouse_key": "Key from the marsh keeper.",
 "thornwick_pass": "Militia pass from Thornwick's captain.",
 "boss_ironbridge": "Fort commander defeated.",
 "warden_bells": "WARDEN: Warden of Bells (Sunken Abbey).",
 "warden_lanterns": "WARDEN: Warden of Lanterns (Lanternkeep).",
 "warden_moons": "WARDEN: Warden of Moons (Seer's Spire).",
 "warden_forge": "WARDEN: Warden of the Forge (Molten Capital).",
 "catacomb_bridge_dropped": "Caldera bridge cut in the catacomb.",
 "catacomb_cleared": "Underroot Catacomb boss defeated.",
 "vault_key": "Jailer's key from the terraces.",
 "drake_sigil": "Sigil found in the citadel.",
 "boss_kingshold": "Citadel guardians defeated.",
 "archive_cleared": "Starfall Archive boss defeated.",
 "game_cleared": "Ending reached.",
}
WARDENS = ["warden_bells", "warden_lanterns", "warden_moons", "warden_forge"]

areas = []
for (i, n, k, act, rec, rmax, hrs, opt, mx, my, built, blurb) in A:
    areas.append({"id": i, "name": n, "kind": k, "act": act, "rec": rec, "rec_max": rmax, "hours": hrs,
                  "optional": opt, "map": [mx, my], "built": built, "blurb": blurb})
gates = []
for gid, g in G.items():
    conn = [c for c in C if c[2] == gid][0]
    gates.append({"id": gid, "from": conn[0], "to": conn[1], "enabled": g["enabled"],
                  "flags_all": g.get("flags_all", []), "flags_any": g.get("flags_any", []),
                  "wardens_min": g.get("wardens_min", 0), "locked_text": g["text"], "story_beat": g["story"]})
world = {
 "_readme": "Riftstrike world graph. Edit freely: areas (name, rec level, map pos), links, gates (set enabled=false to unlock), flags. Tile layout lives in world_map.txt; area/gate tile rects in world_tiles.json.",
 "region": "The Riftmarch",
 "acts": {str(k): v for k, v in ACTS.items()},
 "gates_enabled": True,
 "start_area": "rivenbrook",
 "wardens": WARDENS,
 "flags": FLAGS,
 "start_flags": [],
 "areas": areas,
 "links": [{"from": a, "to": b, "gate": g} for (a, b, g) in C],
 "gates": gates,
}
json.dump(world, open(os.path.join(D, "world.json"), "w"), indent=1)
print("areas", len(areas), "links", len(C), "gates", len(gates), "hours", sum(a["hours"] for a in areas),
      "main hours", sum(a["hours"] for a in areas if not a["optional"]))
