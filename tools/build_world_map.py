#!/usr/bin/env python3
"""Generates data/world_map.txt + data/world_tiles.json for the Act I build.
Legend: ~ water  . grass  : sand/road  " wild grass  T tree  R rock  b bush  X gate (blocks while locked)
After the first pass you can edit world_map.txt directly (one char per 64px tile)."""
import json, os, random
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
W, H = 112, 46
rnd = random.Random(7)
g = [["~"] * W for _ in range(H)]

def fill(c0, r0, c1, r1, ch):
    for r in range(max(0, r0), min(H, r1 + 1)):
        for c in range(max(0, c0), min(W, c1 + 1)):
            g[r][c] = ch

def blob(cx, cy, rx, ry, ch, jitter=0.25):
    for r in range(cy - ry - 1, cy + ry + 2):
        for c in range(cx - rx - 1, cx + rx + 2):
            if 0 <= r < H and 0 <= c < W:
                d = ((c - cx) / max(1, rx)) ** 2 + ((r - cy) / max(1, ry)) ** 2
                if d <= 1 + rnd.uniform(-jitter, jitter):
                    g[r][c] = ch

def path(points, ch=":", w=1):
    for (a, b) in zip(points, points[1:]):
        (c0, r0), (c1, r1) = a, b
        n = max(abs(c1 - c0), abs(r1 - r0), 1)
        for i in range(n + 1):
            c = round(c0 + (c1 - c0) * i / n); r = round(r0 + (r1 - r0) * i / n)
            fill(c - (w // 2), r - (w // 2), c + (w - 1 - w // 2), r + (w - 1 - w // 2), ch)

def border_trees(c0, r0, c1, r1, gaps):
    for c in range(c0, c1 + 1):
        for r in (r0, r1):
            if not any(gc0 <= c <= gc1 and gr0 <= r <= gr1 for (gc0, gr0, gc1, gr1) in gaps) and g[r][c] != "~":
                g[r][c] = "T"
    for r in range(r0, r1 + 1):
        for c in (c0, c1):
            if not any(gc0 <= c <= gc1 and gr0 <= r <= gr1 for (gc0, gr0, gc1, gr1) in gaps) and g[r][c] != "~":
                g[r][c] = "T"

def scatter(c0, r0, c1, r1, ch, p, on="."):
    for r in range(r0, r1 + 1):
        for c in range(c0, c1 + 1):
            if g[r][c] == on and rnd.random() < p:
                g[r][c] = ch

# --- landmass: Act I
fill(1, 1, 16, 12, ".")            # Rivenbrook (matches the original town island)
fill(17, 1, 38, 14, ".")           # Brookside Meadow
fill(2, 13, 31, 30, ".")           # Whisperreed Marsh
fill(39, 3, 62, 13, ".")           # Old Mill Road
fill(63, 1, 80, 15, ".")           # Thornwick
fill(81, 1, 110, 19, ".")          # Hollowpine Wood
fill(56, 16, 100, 33, ".")         # Saltmere Shore
fill(101, 18, 110, 34, ".")        # Ironbridge Fort forecourt
fill(58, 34, 63, 43, ".")          # Gullcliff spit
# coves / ponds
blob(12, 24, 4, 2, "~"); blob(22, 20, 3, 2, "~"); blob(25, 27, 3, 2, "~")
blob(50, 11, 3, 1, "~")
for r in range(28, 34):
    for c in range(64, 100):
        if r >= 31 - (c % 5 == 0): g[r][c] = "~"
fill(56, 16, 57, 22, "~")

# --- Rivenbrook: border trees with exits east (rows 7-9) and south (cols 8-10)
border_trees(1, 1, 16, 12, [(16, 7, 16, 9), (8, 12, 10, 12)])
# --- Brookside Meadow: wild patches, road east
fill(17, 7, 38, 8, ":")
blob(23, 4, 4, 2, '"'); blob(32, 4, 4, 2, '"'); blob(22, 11, 4, 2, '"'); blob(33, 11, 4, 2, '"')
for c in range(17, 39):
    if g[1][c] != "~": g[1][c] = "T"
scatter(17, 2, 38, 13, "b", 0.03)
fill(28, 13, 30, 14, ":")            # south link to the marsh
# --- Whisperreed Marsh
path([(9, 12), (9, 18), (17, 22), (29, 15)], ":", 1)
blob(7, 18, 4, 3, '"'); blob(18, 26, 5, 3, '"'); blob(28, 22, 3, 4, '"'); blob(6, 27, 3, 2, '"')
scatter(2, 13, 31, 30, "T", 0.06)
scatter(2, 13, 31, 30, "R", 0.01)
for c in range(2, 32):
    if g[30][c] in '."b': g[30][c] = "T"
# --- Old Mill Road
path([(39, 8), (45, 8), (49, 6), (56, 6), (62, 8)], ":", 2)
blob(43, 11, 3, 1, '"'); blob(58, 11, 3, 1, '"'); blob(52, 4, 2, 1, '"')
for c in range(39, 63):
    if g[3][c] != "~": g[3][c] = "T"
    if g[13][c] not in "~": g[13][c] = "T"
scatter(39, 4, 62, 12, "b", 0.03)
# --- Thornwick: town plaza with exits west, north-east, south
fill(63, 7, 80, 8, ":"); fill(70, 2, 71, 15, ":")
border_trees(63, 1, 80, 15, [(63, 6, 63, 9), (80, 2, 80, 5), (69, 15, 72, 15)])
fill(80, 3, 81, 4, ":")
# --- Hollowpine Wood: dense forest with wild-grass glades and a trail to the fort
scatter(81, 1, 110, 19, "T", 0.42)
path([(81, 3), (88, 4), (92, 9), (98, 8), (104, 13), (105, 18)], ":", 2)
blob(88, 9, 3, 2, '"'); blob(97, 4, 4, 2, '"'); blob(100, 14, 3, 2, '"'); blob(108, 6, 2, 3, '"')
for c in range(81, 111):
    g[1][c] = "T"
for r in range(1, 20):
    g[r][110] = "T"
# --- Saltmere Shore: beach and dunes
for r in range(16, 31):
    for c in range(58, 101):
        if g[r][c] == "." and r >= 25: g[r][c] = ":"
path([(70, 15), (70, 19), (78, 23), (90, 22), (100, 25)], ":", 2)
blob(64, 20, 4, 3, '"'); blob(84, 18, 4, 2, '"'); blob(94, 28, 4, 2, '"'); blob(76, 27, 3, 1, '"')
scatter(58, 16, 100, 24, "T", 0.05)
scatter(58, 16, 100, 30, "R", 0.012)
path([(61, 26), (61, 41)], ":", 2)
# --- Fort forecourt (built stub) and gates
fill(101, 18, 110, 34, ":")
for r in range(18, 35): g[r][110] = "R"
for c in range(101, 111): g[34][c] = "R"
fill(101, 20, 102, 20, "R"); fill(101, 21, 101, 33, "R")
fill(103, 20, 109, 20, "X")   # north gate (from forest)
fill(101, 23, 101, 27, "X")   # south/sea gate (from shore)
fill(58, 42, 63, 42, "X")     # lighthouse door
# clean up: anything at map edge is water
for r in range(H):
    g[r][0] = "~"; g[r][W - 1] = "~"
for c in range(W):
    g[0][c] = "~"; g[H - 1][c] = "~"
txt = "\n".join("".join(row) for row in g) + "\n"
open(os.path.join(ROOT, "data", "world_map.txt"), "w").write(txt)

tiles = {
 "_readme": "Tile rects are [col0,row0,col1,row1] inclusive (64px tiles). First matching rect wins. 'start' is the new-game tile. Gate rects tie X tiles to world.json gates.",
 "tile": 64,
 "start": [10, 8],
 "areas": [
  {"id": "rivenbrook", "rects": [[1, 1, 16, 12]]},
  {"id": "brookside_meadow", "rects": [[17, 1, 38, 14]]},
  {"id": "whisperreed_marsh", "rects": [[2, 13, 31, 30]]},
  {"id": "old_mill_road", "rects": [[39, 3, 62, 13]]},
  {"id": "thornwick", "rects": [[63, 1, 80, 15]]},
  {"id": "hollowpine_wood", "rects": [[81, 1, 110, 19]]},
  {"id": "ironbridge_fort", "rects": [[101, 20, 110, 34]]},
  {"id": "gullcliff_lighthouse", "rects": [[58, 34, 63, 43]]},
  {"id": "saltmere_shore", "rects": [[56, 16, 100, 33]]},
 ],
 "gates": [
  {"id": "g_fort_north", "rects": [[103, 20, 109, 20]]},
  {"id": "g_fort_south", "rects": [[101, 23, 101, 27]]},
  {"id": "g_lighthouse_door", "rects": [[58, 42, 63, 42]]},
 ],
 "props": [
  {"img": "tower", "x": 50, "y": 5, "s": 0.62, "note": "the old mill"},
  {"img": "ghouse", "x": 46, "y": 10, "s": 0.8},
  {"img": "ghouse", "x": 66, "y": 4, "s": 0.84},
  {"img": "ghouse", "x": 75, "y": 4, "s": 0.84, "flip": True},
  {"img": "ghouse", "x": 66, "y": 12, "s": 0.86},
  {"img": "ghouse", "x": 76, "y": 12, "s": 0.82, "flip": True},
  {"img": "tower", "x": 78, "y": 8, "s": 0.7},
  {"img": "tower", "x": 104, "y": 28, "s": 0.8, "note": "fort keep (sealed)"},
  {"img": "tower", "x": 108, "y": 26, "s": 0.7},
  {"img": "tower", "x": 61, "y": 43, "s": 0.8, "note": "lighthouse"},
 ],
}
json.dump(tiles, open(os.path.join(ROOT, "data", "world_tiles.json"), "w"), indent=1)
print(txt)
