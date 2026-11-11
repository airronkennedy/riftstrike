#!/usr/bin/env python3
"""Layout 3 generator: keeps the hand-tuned Act I (layout 2) verbatim, finishes Ironbridge Fort,
and builds Acts II-V on a wider/taller canvas.  Safe to re-run: it always starts from the pinned
Act I sources in tools/act1_layout2_map.txt + tools/act1_layout2_tiles.json.

  python3 tools/build_world_acts.py          # writes data/world_map.txt, data/world_tiles.json

Charset: ~ water  . grass  : road/sand  " wild grass (encounters)  T tree  R rock  b bush
         X gate   = bridge  , stone floor  ; rubble floor (encounters)  # wall  L lava  _ ice
Act I tiles (cols 0-223, rows 0-91) are never touched except inside the Ironbridge Fort stub and the
water channels the fort's two new exits cross.  New areas use only Tiny Swords art already in assets/.
"""
import json, math, os, random

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
W, H = 448, 208
A1W, A1H = 224, 92

src = open(os.path.join(ROOT, "tools/act1_layout2_map.txt")).read().rstrip("\n").split("\n")
G = [list(r.ljust(W, "~")) for r in src] + [["~"] * W for _ in range(H - len(src))]
tiles1 = json.load(open(os.path.join(ROOT, "tools/act1_layout2_tiles.json")))

# Act I cells we may edit: the fort stub and the water its exits cross.
EDIT_OK = set()
for y in range(40, 70):
    for x in range(202, 222):
        EDIT_OK.add((x, y))
for y in range(50, 58):
    for x in range(222, 224):
        EDIT_OK.add((x, y))
for y in range(70, 92):
    for x in range(206, 218):
        EDIT_OK.add((x, y))


def can(x, y):
    if x < 0 or y < 0 or x >= W or y >= H:
        return False
    if x < A1W and y < A1H:
        return (x, y) in EDIT_OK
    return True


def put(x, y, ch):
    if can(x, y):
        G[y][x] = ch


def get(x, y):
    if x < 0 or y < 0 or x >= W or y >= H:
        return "~"
    return G[y][x]


def rect(x0, y0, x1, y1, ch):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            put(x, y, ch)


def ellipse(cx, cy, rx, ry, ch, rng=None, jag=0.0, only=None):
    for y in range(int(cy - ry - 2), int(cy + ry + 3)):
        for x in range(int(cx - rx - 2), int(cx + rx + 3)):
            d = ((x - cx) / max(0.5, rx)) ** 2 + ((y - cy) / max(0.5, ry)) ** 2
            j = (rng.random() - 0.5) * jag if rng else 0.0
            if d <= 1.0 + j and (only is None or get(x, y) in only):
                put(x, y, ch)


def line(pts, w, ch, over=None, bridge_over_water=True):
    """Thick polyline. Road over water becomes a bridge."""
    for (ax, ay), (bx, by) in zip(pts, pts[1:]):
        n = int(max(abs(bx - ax), abs(by - ay))) * 2 + 1
        for i in range(n + 1):
            t = i / n
            x = ax + (bx - ax) * t
            y = ay + (by - ay) * t
            for oy in range(w):
                for ox in range(w):
                    cx, cy = int(round(x)) + ox - w // 2, int(round(y)) + oy - w // 2
                    cur = get(cx, cy)
                    if over is not None and cur not in over:
                        continue
                    if ch == ":" and bridge_over_water and cur in "~=":
                        put(cx, cy, "=")
                    elif ch == ":" and cur in "XL#":
                        if cur == "L":
                            put(cx, cy, "=")
                        continue
                    else:
                        put(cx, cy, ch)


def river(pts, w, rng, wobble=1.5):
    out = [pts[0]]
    for (ax, ay), (bx, by) in zip(pts, pts[1:]):
        steps = int(max(abs(bx - ax), abs(by - ay)) / 4) + 1
        for i in range(1, steps + 1):
            t = i / steps
            out.append((ax + (bx - ax) * t + (rng.random() - 0.5) * wobble * 2, ay + (by - ay) * t + (rng.random() - 0.5) * wobble * 2))
    line(out, w, "~", over=set('.":TbR,;_'))


def border(x0, y0, x1, y1, ch, rng, th=2, extra=2, alt=None):
    """Ring of blocking tiles (trees / rock) with a ragged inner edge."""
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            d = min(x - x0, x1 - x, y - y0, y1 - y)
            lim = th + (rng.randint(0, extra) if extra else 0)
            if d < lim:
                c = ch
                if alt and rng.random() < 0.3:
                    c = alt
                put(x, y, c)


def blobs(x0, y0, x1, y1, n, rmin, rmax, ch, rng, only=".", jag=0.5):
    for _ in range(n):
        cx = rng.uniform(x0 + rmax, x1 - rmax)
        cy = rng.uniform(y0 + rmax, y1 - rmax)
        ellipse(cx, cy, rng.uniform(rmin, rmax), rng.uniform(rmin, rmax) * 0.8, ch, rng, jag, only=set(only))


def scatter(x0, y0, x1, y1, ch, dens, rng, only=".", keep_off=":=X"):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if get(x, y) in only and rng.random() < dens:
                if any(get(x + dx, y + dy) in keep_off for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
                    continue
                put(x, y, ch)


def clear_ring(x0, y0, x1, y1, ch=":"):
    rect(x0, y0, x1, y1, ch)


AREAS = {}   # id -> {"rects": [...], "zones": [...], "style": s, "spawn": [x,y]}
GATES = []   # {"id", "rects"}
PROPS = []   # {"img","x","y","s",...}


def area(aid, rects, style=None, spawn=None, zones=None):
    AREAS[aid] = {"id": aid, "rects": rects}
    if style:
        AREAS[aid]["style"] = style
    if spawn:
        AREAS[aid]["spawn"] = spawn
    if zones:
        AREAS[aid]["zones"] = zones


def gate(gid, x0, y0, x1, y1):
    rect(x0, y0, x1, y1, "X")
    for g in GATES:
        if g["id"] == gid:
            g["rects"].append([x0, y0, x1, y1])
            return
    GATES.append({"id": gid, "rects": [[x0, y0, x1, y1]]})


def free_for_prop(x, y, w=1, h=1):
    for yy in range(int(y) - h + 1, int(y) + 1):
        for xx in range(int(x) - w // 2, int(x) + (w + 1) // 2):
            if get(xx, yy) not in '.,"b':
                return False
    return True


def prop(img, x, y, s=0.8, flip=False, note=None, mod=None, walk=False, force=False, clear=None):
    """Place a prop. clear=(w,h) stamps grass under it first so nothing overlaps."""
    if clear:
        cw, ch_ = clear
        for yy in range(int(y) - ch_ + 1, int(y) + 1):
            for xx in range(int(x) - cw // 2, int(x) + (cw + 1) // 2):
                if get(xx, yy) in 'TRb"':
                    put(xx, yy, ".")
    p = {"img": img, "x": x, "y": y, "s": s}
    if flip:
        p["flip"] = True
    if note:
        p["note"] = note
    if mod:
        p["mod"] = mod
    if walk:
        p["walk"] = True
    PROPS.append(p)
    return p


def npc(img, x, y, flip=False, note=None):
    return prop(img, x, y, 0.42 if img != "sheep" else 0.62, flip, note)


def town_block(houses, rng, kinds=("house_red",), s=0.84):
    for (x, y) in houses:
        prop(rng.choice(kinds), x, y, s + rng.uniform(-0.04, 0.04), rng.random() < 0.4, clear=(3, 2))


# =========================================================== Act I: finish Ironbridge Fort
def build_fort():
    rng = random.Random(15)
    # Interior courtyard: stone floor, rubble training yards (fort patrols fight here).
    rect(204, 42, 219, 67, ",")
    rect(207, 60, 216, 66, ";")
    rect(205, 56, 206, 60, ";")
    rect(217, 44, 218, 50, ";")
    # Inner keep: walled compound around the commander's hall, door on its south side.
    rect(208, 43, 216, 50, "#")
    rect(209, 44, 215, 49, ",")
    rect(211, 50, 213, 50, ",")
    # Paths stay clear from every gate to the keep door and the two new exits.
    rect(206, 42, 219, 42, ",")
    rect(204, 51, 219, 55, ",")
    rect(210, 51, 213, 67, ",")
    # East wall: the raised iron span over the gorge (opens when the commander falls).
    gate("g_ironbridge_span", 220, 53, 221, 54)
    rect(222, 53, 231, 54, "=")
    # South wall: the royal ward over the causeway to Kingshold.
    gate("g_royal_ward", 210, 68, 213, 69)
    rect(211, 70, 212, 93, "=")
    prop("castle_red", 212, 48, 0.62, note="commander's hall (boss_ironbridge)")
    for (x, y) in [(205, 44), (218, 66), (205, 66)]:
        prop("tower_red", x, y, 0.6)
    prop("house_red", 217, 58, 0.78, note="barracks")
    prop("house_red", 206, 64, 0.76, True, note="armory")
    prop("fire", 209, 52, 0.5)
    prop("fire", 215, 52, 0.5)
    prop("deco18", 214, 62, 0.55, note="training dummy")
    prop("deco18", 209, 62, 0.55, True, note="training dummy")
    npc("warrior", 207, 45)
    npc("warrior", 219, 47, True)
    npc("archer", 212, 66)
    npc("warrior", 219, 53, True, note="span guard")


# =========================================================== Act II: the Ember Highlands
EMBER = [1.0, 0.74, 0.5]


def build_emberfall():
    rng = random.Random(201)
    x0, y0, x1, y1 = 232, 36, 275, 75
    rect(x0, y0, x1, y1, ".")
    border(x0, y0, x1, y1, "R", rng, th=2, extra=2, alt="T")
    # mining rim: a cliff ridge along the north with three mine mouths
    rect(x0 + 2, y0 + 2, x1 - 2, y0 + 5, "#")
    for mx in (240, 254, 266):
        rect(mx - 1, y0 + 6, mx + 1, y0 + 7, ":")
    # main street from the iron bridge across town to the steppe, plaza in the middle
    line([(x0, 53.5), (x1, 53.5)], 2, ":")
    rect(248, 50, 257, 57, ",")                                # stone market square
    line([(252.5, 50), (252.5, y0 + 7)], 2, ":")          # mine road
    line([(240, 44), (266, 44)], 2, ":")
    line([(252.5, 58), (252.5, y1 - 6), (262, y1 - 6), (262, y1)], 2, ":")   # south lane to the hot spring
    line([(246, 38), (246, y0 - 1)], 2, ":", bridge_over_water=False)        # north pass to Redcap Hills
    rect(245, y0, 247, y0 + 5, ":")
    ellipse(240, 67, 4.5, 3, "~", rng, 0.3)                  # hot spring pool
    ellipse(269, 66, 3, 2.5, "~", rng, 0.3)
    scatter(x0 + 3, y0 + 8, x1 - 3, y1 - 3, "R", 0.025, rng)
    scatter(x0 + 3, y0 + 8, x1 - 3, y1 - 3, "b", 0.02, rng)
    # buildings
    for mx in (240, 254, 266):
        prop("goldmine", mx, y0 + 6, 0.7, note="mine mouth")
        npc("pawn", mx + 2.2, y0 + 8, rng.random() < 0.5)
    town_block([(236, 49), (242, 48), (236, 58), (243, 59), (261, 48), (268, 48), (262, 59), (269, 59), (238, 63), (249, 64), (257, 64), (270, 70)], rng, ("house_red", "house_yellow", "house_red"))
    prop("tower_red", 272, 51, 0.62, note="east watch")
    prop("wtower", 235, 70, 0.5, note="ore hoist")
    prop("wtower", 270, 40, 0.48)
    prop("fire", 249, 51, 0.55, note="forge")
    prop("fire", 256, 51, 0.55, note="forge")
    prop("deco17", 250, 58, 0.7, note="signpost")
    for (x, y, f) in [(250, 55, False), (255, 54, True), (244, 53, False), (259, 56, True), (240, 64, True), (265, 47, False), (248, 46, True), (233, 53, False)]:
        npc("pawn", x, y, f)
    npc("warrior", 274, 52, True)
    npc("warrior", 274, 55, True)
    # yards, ore piles and market dressing so the streets read as lived-in
    for (x, y) in [(234, 51), (238, 51), (240, 61), (244, 61), (264, 51), (266, 61), (271, 61), (247, 66), (259, 66)]:
        prop("deco0%d" % rng.choice([4, 5]), x, y, 0.9)
    for (x, y) in [(241, 42), (256, 42), (263, 42), (237, 45)]:
        prop("rocks4", x, y, 0.9, note="ore pile", mod=EMBER + [1.0])
    for (x, y) in [(250, 52), (255, 56), (250, 56)]:
        prop("deco17", x, y, 0.55, note="market stall sign")
    for (x, y) in [(238, 67), (243, 68), (268, 65)]:
        npc("pawn", x, y, x % 2 == 0)
    area("emberfall", [[x0, y0, x1, y1]], "ember", [252, 54])


def build_redcap():
    rng = random.Random(202)
    x0, y0, x1, y1 = 232, 2, 345, 33
    rect(x0, y0, x1, y1, ".")
    border(x0, y0, x1, y1, "T", rng, th=2, extra=3, alt="R")
    # rolling hills: rock outcrops and tree knots; two creeks feeding a tarn
    river([(262, y0 + 2), (270, 14), (286, 19), (300, 16)], 2, rng)
    river([(330, y0 + 2), (316, 10), (300, 16)], 2, rng)
    ellipse(300, 17, 7, 4.5, "~", rng, 0.35)
    blobs(x0 + 4, y0 + 4, x1 - 4, y1 - 4, 26, 2.5, 5.5, '"', rng)
    blobs(x0 + 4, y0 + 4, x1 - 4, y1 - 4, 10, 1.5, 3, "T", rng)
    scatter(x0 + 3, y0 + 3, x1 - 3, y1 - 3, "R", 0.02, rng, only='."')
    line([(246, y1 + 1), (246, 26), (262, 22), (284, 25), (296, 23), (318, 24), (334, 18), (340, 10)], 2, ":")
    line([(296, 23), (292, 12), (280, 8), (262, 8)], 2, ":")       # north loop over the creeks
    rect(245, y1 - 3, 247, y1 + 1, ":")
    # mushroom rings (Redcap!) and a ruined goblin camp, a shepherd's hut
    for (x, y) in [(255, 9), (288, 9), (323, 28), (338, 13)]:
        for k in range(6):
            a = k / 6 * math.tau
            prop("deco0%d" % (1 + k % 3), x + math.cos(a) * 1.4, y + math.sin(a) * 1.0, 0.8)
    prop("ghouse_ruin", 312, 28, 0.8, note="goblin camp")
    prop("ghouse", 318, 29, 0.8, True)
    prop("deco16", 315, 30, 0.7)
    prop("fire", 315, 28, 0.5)
    prop("house_yellow", 272, 26, 0.78, clear=(3, 2), note="shepherd hut")
    for (x, y) in [(268, 28), (275, 29), (278, 27)]:
        npc("sheep", x, y, x % 2 == 0)
    npc("pawn", 270, 27)
    area("redcap_hills", [[x0, y0, x1, y1]], "redcap", [246, 30])


def build_steppe():
    rng = random.Random(203)
    x0, y0, x1, y1 = 276, 36, 345, 80
    rect(x0, y0, x1, y1, ".")
    border(x0, y0, x1, y1, "R", rng, th=2, extra=2)
    blobs(x0 + 3, y0 + 3, x1 - 3, 64, 30, 3, 7, '"', rng)          # red kindlegrass
    scatter(x0 + 3, y0 + 3, x1 - 3, 64, "R", 0.015, rng, only='."')
    scatter(x0 + 3, y0 + 3, x1 - 3, 64, "b", 0.015, rng, only='."')
    # Glasswind Canyon: a crystal gorge along the south with cliff walls and a wind-cut stream
    cy0 = 66
    rect(x0 + 2, cy0, x1 - 2, y1 - 2, "#")
    line([(x0 + 4, 72), (296, 70), (312, 74), (330, 71), (x1 - 4, 73)], 4, ";")
    river([(x0 + 6, 76), (300, 77), (322, 76), (x1 - 6, 77)], 1, rng, 0.6)
    for (x, y) in [(290, 71), (305, 73), (320, 70), (336, 74), (298, 75), (328, 76)]:
        prop("rocks2", x, y, 1.0, mod=[0.7, 0.95, 1.1])
    # roads: Emberfall (west) -> east to Mirefen; south through the canyon to the abbey
    line([(x0, 53.5), (300, 52), (318, 47), (x1, 45.5)], 2, ":")
    line([(304, 52), (304, 60), (300, 66), (300, 72)], 2, ":")
    rect(299, 66, 302, 72, ";")
    line([(300, 72), (302, 78), (302, y1)], 2, ":")
    rect(301, 76, 304, y1, ";")
    # wind shrines (stone towers) and a waystation
    prop("tower_yellow", 318, 44, 0.55, note="wind shrine")
    prop("tower_ruin", 289, 40, 0.7)
    prop("house_yellow", 309, 56, 0.76, clear=(3, 2), note="waystation")
    prop("fire", 312, 57, 0.45)
    npc("pawn", 307, 57)
    prop("deco17", 303, 50, 0.7, note="signpost: abbey / fen")
    area("kindlegrass_steppe", [[x0, y0, x1, y1]], "steppe", [280, 53],
         zones=[{"name": "Glasswind Canyon", "rects": [[x0, cy0, x1, y1]], "style": "canyon"}])


def build_abbey():
    rng = random.Random(204)
    x0, y0, x1, y1 = 290, 81, 335, 105
    rect(x0, y0, x1, y1, "#")
    # flooded nave: water channels between stone walks, chapels off the sides, the bell crypt at the bottom
    rect(x0 + 2, y0 + 2, x1 - 2, y1 - 2, "~")
    rect(299, y0, 304, y1 - 2, ",")                   # central walk from the canyon stair
    rect(x0 + 3, 87, x1 - 3, 89, ",")                 # transept
    for (a, b) in [(292, 83), (311, 83), (322, 83), (292, 96), (312, 95), (323, 96)]:
        rect(a, b, a + 5, b + 3, ";")
    rect(x0 + 3, 93, x1 - 3, 94, "=")                 # flooded aisle boardwalk
    rect(294, 89, 295, 96, "=")
    rect(316, 89, 317, 95, "=")
    rect(327, 89, 328, 96, "=")
    rect(296, 98, 307, 102, ";")                      # bell crypt (Warden of Bells)
    rect(303, 102, 306, y1, ",")
    gate("g_frostveil_seal", 303, 104, 306, 105)
    prop("castle_ruin", 301.5, 86, 0.6, note="sunken chapel")
    prop("tower_ruin", 294, 85, 0.55)
    prop("tower_ruin", 326, 85, 0.55)
    prop("tower", 301.5, 100, 0.55, note="bell tower: Warden of Bells", mod=[0.75, 0.85, 0.9])
    for (x, y) in [(298, 92), (305, 92), (293, 90), (330, 90)]:
        prop("deco16", x, y, 0.6)
    prop("fire", 299, 98, 0.45)
    prop("fire", 306, 98, 0.45)
    area("sunken_abbey", [[x0, y0, x1, y1]], "abbey", [301, 82])


def build_mirefen():
    rng = random.Random(205)
    x0, y0, x1, y1 = 346, 2, 405, 60
    rect(x0, y0, x1, y1, ".")
    border(x0, y0, x1, y1, "T", rng, th=2, extra=3)
    # bog: lots of pools, reeds (wild), dead trees; boardwalks connect it
    blobs(x0 + 4, y0 + 4, x1 - 4, y1 - 4, 34, 1.5, 4.5, "~", rng, only=".", jag=0.6)
    blobs(x0 + 3, y0 + 3, x1 - 3, y1 - 3, 30, 2, 5, '"', rng)
    scatter(x0 + 3, y0 + 3, x1 - 3, y1 - 3, "T", 0.05, rng, only='.')
    scatter(x0 + 3, y0 + 3, x1 - 3, y1 - 3, "b", 0.03, rng, only='."')
    # Mirefen Deep: the darker north-east lobe
    ellipse(392, 14, 9, 8, "~", rng, 0.5, only=set('."Tb'))
    for k in range(4):
        ellipse(386 + k * 4, 10 + (k % 2) * 7, 2, 1.5, '"', rng, 0.3, only=set("~"))
    # Foxglove Hamlet: a hidden clearing village in the south-west
    rect(350, 40, 370, 56, ".")
    border(348, 38, 372, 58, "T", rng, th=1, extra=1)
    rect(355, 44, 365, 52, ":")
    # boardwalk roads: steppe (south-west) -> hamlet -> north -> Lanternkeep (south)
    line([(x0, 45.5), (355, 47.5)], 2, ":")
    rect(x0 - 1, 45, x0 + 2, 46, ":")
    line([(365, 48), (378, 48), (378, 30), (390, 24), (392, 14)], 2, ":")
    line([(378, 48), (376, 56), (376, y1 + 1)], 2, ":")
    town_block([(357, 43), (364, 43), (352, 51), (368, 51), (358, 55), (366, 55)], rng, ("house_purple", "house_blue", "house_purple"), 0.76)
    prop("deco18", 361, 50, 0.55, note="foxglove scarecrow")
    for (x, y, f) in [(358, 47, False), (362, 49, True), (360, 52, False)]:
        npc("pawn", x, y, f)
    npc("sheep", 353, 47)
    prop("ghouse", 389, 27, 0.78, note="bog witch hut")
    prop("fire", 392, 28, 0.4)
    prop("tower_ruin", 392, 13, 0.7, note="drowned watchtower")
    area("mirefen", [[x0, y0, x1, y1]], "fen", [350, 46],
         zones=[{"name": "Foxglove Hamlet", "rects": [[348, 38, 372, 58]], "style": "foxglove"},
                {"name": "Mirefen Deep", "rects": [[380, 3, 404, 26]]}])


def build_lanternkeep():
    rng = random.Random(206)
    x0, y0, x1, y1 = 346, 62, 405, 105
    rect(x0, y0, x1, y1, "#")
    # upper keep: lantern-lit halls
    rect(372, y0, 379, 68, ",")                       # gatehouse from Mirefen
    rect(352, 68, 399, 80, ",")                       # great hall
    rect(356, 70, 362, 78, ";")
    rect(390, 70, 396, 78, ";")
    rect(373, 80, 378, 84, ",")
    # Underroot Catacomb: root-choked lower levels (rubble corridors, a sunken ossuary)
    rect(350, 84, 401, 102, ";")
    for (a, b, c, d) in [(355, 87, 364, 89), (368, 90, 371, 101), (380, 86, 383, 96), (388, 92, 398, 94), (352, 95, 362, 97)]:
        rect(a, b, c, d, "#")
    scatter(350, 84, 401, 102, "T", 0.04, rng, only=";", keep_off=",=X")
    rect(373, 84, 378, 102, ",")
    # Caldera bridge: east out of the catacombs (dropped by the lever) over the lava chasm
    rect(398, 98, 405, 99, ",")
    gate("g_caldera_bridge", 404, 98, 405, 99)
    # Frost seal: south stair down to the frozen lake
    rect(366, 102, 371, y1, ",")
    gate("g_frostveil_seal", 366, 104, 371, 105)
    for (x, y) in [(354, 70), (366, 70), (386, 70), (398, 70), (360, 79), (392, 79), (373, 66), (378, 66)]:
        prop("fire", x, y, 0.5, note="hanging lantern")
    prop("castle_yellow", 375.5, 75, 0.7, note="Warden of Lanterns")
    prop("tower_yellow", 353, 73, 0.6)
    prop("tower_yellow", 398, 73, 0.6)
    for (x, y) in [(353, 90), (385, 99), (395, 88), (366, 86)]:
        prop("deco16", x, y, 0.6)
    prop("castle_ruin", 357, 100, 0.55, note="ossuary")
    area("lanternkeep", [[x0, y0, x1, y1]], "lantern", [375, 64],
         zones=[{"name": "Underroot Catacomb", "rects": [[x0, 83, x1, y1]], "style": "catacomb"}])


def build_caldera():
    rng = random.Random(207)
    x0, y0, x1, y1 = 406, 30, 445, 105
    rect(x0, y0, x1, y1, "R")
    rect(x0 + 2, y0 + 2, x1 - 2, y1 - 2, ".")
    border(x0 + 2, y0 + 2, x1 - 2, y1 - 2, "R", rng, th=1, extra=2)
    # the smoking lake: a boiling water lake ringed by lava, ash flats, steam vents
    ellipse(426, 62, 13, 18, "L", rng, 0.25, only=set(".R"))
    ellipse(426, 62, 9, 13, "~", rng, 0.25)
    blobs(x0 + 3, y0 + 3, x1 - 3, y1 - 3, 10, 2, 4, ";", rng, only=".")
    scatter(x0 + 3, y0 + 3, x1 - 3, y1 - 3, "R", 0.03, rng)
    # rope bridge landing from Lanternkeep, a basalt causeway around and over the lake
    rect(406, 98, 410, 99, "=")
    line([(410, 98.5), (420, 94), (432, 86), (440, 70), (438, 50), (426, 38), (414, 46), (412, 62), (418, 76), (426, 62)], 2, ":")
    for (x, y) in [(434, 90), (440, 60), (414, 40), (412, 70)]:
        prop("fire", x, y, 0.55, note="steam vent")
    prop("castle_ruin", 426, 62, 0.55, note="drowned forge island")
    prop("tower_ruin", 438, 42, 0.6)
    area("smokewater_caldera", [[x0, y0, x1, y1]], "caldera", [412, 97])


# =========================================================== Act III: Frostveil
def build_frostveil():
    rng = random.Random(301)
    x0, y0, x1, y1 = 290, 106, 375, 158
    # Frostveil Bridge: the frozen lake below the abbey and Lanternkeep, crossed on the long bridge
    rect(x0, y0, x1, 119, "~")
    rect(303, y0, 306, 108, "_")
    rect(366, y0, 371, 108, "_")
    line([(304.5, 108), (304.5, 112), (330, 114), (368.5, 112), (368.5, 108)], 3, "=", over=set("~"))
    rect(328, 112, 332, 120, "=")
    blobs(x0 + 2, y0 + 3, x1 - 2, 118, 9, 1.5, 3, "_", rng, only="~")
    # the city: walled, spired, snowbound
    rect(x0, 120, x1, y1, ".")
    border(x0, 120, x1, y1, "T", rng, th=2, extra=2, alt="R")
    rect(x0 + 6, 122, x1 - 6, 124, "#")               # north curtain wall
    rect(328, 122, 332, 124, ",")                       # city gate
    line([(330, 124), (330, y1)], 3, ":")               # spire avenue south to Hoarfrost Pass
    line([(x0 + 4, 140), (x1, 140)], 3, ":")            # market road east to the terraces
    rect(322, 134, 338, 146, ",")                       # frost plaza
    ellipse(330, 140, 2.5, 2, "~", rng, 0.0)            # frozen fountain
    rect(329, 139, 331, 141, "_")
    rect(x1 - 1, 139, x1, 141, ":")
    for (a, b) in [(300, 128), (300, 148), (352, 128), (352, 148)]:
        rect(a, b, a + 12, b + 5, ",")                   # district squares
    scatter(x0 + 3, 125, x1 - 3, y1 - 3, "b", 0.02, rng)
    # buildings: spires everywhere (blue towers), the palace castle, many houses
    prop("castle_blue", 330, 131, 0.85, note="Frostveil palace", mod=[0.9, 0.97, 1.0])
    for (x, y) in [(302, 127), (318, 127), (342, 127), (358, 127), (302, 153), (358, 153), (324, 145), (336, 145)]:
        prop("tower", x, y, 0.62, mod=[0.9, 0.97, 1.0], note="spire")
    houses = [(296, 133), (304, 133), (312, 133), (348, 133), (356, 133), (364, 133), (296, 146), (304, 146), (312, 146),
              (348, 146), (356, 146), (364, 146), (306, 153), (314, 153), (346, 153), (354, 153), (318, 138), (344, 138)]
    for (x, y) in houses:
        prop(rng.choice(["house_blue", "house_blue", "house_purple"]), x, y, 0.8, rng.random() < 0.5, mod=[0.92, 0.97, 1.0], clear=(3, 2))
    for (x, y) in [(326, 137), (334, 137), (306, 130), (354, 130), (306, 150), (354, 150)]:
        prop("fire", x, y, 0.45, note="hearth brazier")
    for (x, y, f) in [(325, 141, False), (335, 142, True), (328, 144, False), (332, 136, True), (308, 140, False), (350, 140, True), (316, 141, False), (344, 141, True), (303, 130, False), (357, 150, True), (310, 150, False), (330, 152, True)]:
        npc("pawn", x, y, f)
    for (x, y, f) in [(327, 125, False), (333, 125, True), (373, 139, True), (330, 157, False)]:
        npc("warrior", x, y, f)
    npc("archer", 302, 128)
    npc("archer", 358, 128, True)
    area("frostveil", [[x0, y0, x1, y1]], "snow", [330, 136],
         zones=[{"name": "Frostveil Bridge", "rects": [[x0, y0, x1, 119]], "style": "frostlake"}])


def build_terraces():
    rng = random.Random(302)
    x0, y0, x1, y1 = 378, 106, 445, 150
    rect(x0, y0, x1, y1, ".")
    border(x0, y0, x1, y1, "T", rng, th=2, extra=2)
    # terraced gardens: stepped stone retaining walls with stairs, moon pools, hedges
    for k, ty in enumerate([114, 122, 130, 138]):
        rect(x0 + 3, ty, x1 - 3, ty, "#")
        for sx in ([388, 412, 432] if k % 2 == 0 else [398, 422, 440]):
            rect(sx, ty, sx + 2, ty, ",")
    blobs(x0 + 3, y0 + 3, x1 - 3, y1 - 3, 18, 2, 4, '"', rng)
    for (cx, cy) in [(392, 118), (420, 126), (404, 134), (434, 118), (430, 144)]:
        ellipse(cx, cy, 2.5, 1.6, "~", rng, 0.2, only=set('."'))
    scatter(x0 + 3, y0 + 3, x1 - 3, y1 - 3, "b", 0.04, rng, only='.')
    line([(x0 - 1, 140), (388, 140), (398, 138.5), (398, 130.5), (412, 130.5), (412, 122.5), (422, 122.5), (422, 114.5), (432, 114.5), (432, 110)], 2, ":")
    line([(398, 140), (394, 146), (394, y1 + 1)], 2, ":")          # to Deepvault
    line([(412, 130.5), (430, 136), (430, 146), (428, y1 + 1)], 2, ":")   # to Seer's Spire
    prop("house_purple", 432, 109, 0.8, note="jailer's lodge (vault_key)", clear=(3, 2))
    prop("tower_purple", 440, 110, 0.6)
    for (x, y) in [(392, 116), (420, 124), (404, 132), (430, 142)]:
        prop("deco17", x + 3, y, 0.6, note="moon lamp")
    for (x, y) in [(386, 126), (410, 118), (426, 134)]:
        prop("deco18", x, y, 0.5, note="garden scarecrow")
    npc("pawn", 434, 112, True, note="gardener")
    area("moonlit_terraces", [[x0, y0, x1, y1]], "terraces", [381, 140])


def build_spire():
    rng = random.Random(303)
    x0, y0, x1, y1 = 412, 152, 445, 205
    rect(x0, y0, x1, y1, "#")
    # spiral climb: four concentric galleries joined by doors on alternating sides, the sanctum inside
    for i in range(4):
        a, b, c, d = 414 + 4 * i, 154 + 4 * i, 443 - 4 * i, 203 - 4 * i
        for y in range(b, d + 1):
            for x in range(a, c + 1):
                if min(x - a, c - x, y - b, d - y) < 2:
                    put(x, y, ";" if i % 2 == 0 else ",")
        if i < 3:
            mx = (a + c) // 2
            if i % 2 == 0:
                rect(mx - 1, d - 3, mx, d - 2, ",")
            else:
                rect(mx - 1, b + 2, mx, b + 3, ",")
    rect(428, 170, 429, 187, ",")
    rect(426, 172, 431, 185, ",")
    rect(427, 152, 429, 154, ",")                     # entrance from the terraces (north)
    prop("tower_purple", 428.5, 180, 0.8, note="Seer's Spire (Warden of Sights)")
    for (x, y) in [(427, 174), (430, 184), (416, 160), (441, 200), (420, 190), (437, 166)]:
        prop("fire", x, y, 0.45, note="scrying flame")
    area("seers_spire", [[x0, y0, x1, y1]], "spire", [428, 155])


def build_deepvault():
    rng = random.Random(304)
    x0, y0, x1, y1 = 378, 152, 409, 205
    rect(x0, y0, x1, y1, "#")
    # Deepvault Prison: cell blocks along a central hall
    rect(392, y0, 396, 176, ",")
    gate("g_deepvault_door", 392, 152, 396, 153)
    for cy in range(156, 175, 5):
        rect(381, cy, 389, cy + 3, ";")
        rect(399, cy, 406, cy + 3, ";")
        rect(390, cy + 1, 391, cy + 2, ",")
        rect(397, cy + 1, 398, cy + 2, ",")
    # Molten Capital: a fallen city sunk in a lava lake, causeways between ruined blocks
    rect(380, 178, 407, 203, "L")
    line([(394, 176), (394, 184), (386, 188), (386, 196), (394, 200), (402, 194), (402, 186), (394, 184)], 2, ",")
    for (a, b) in [(381, 186), (399, 184), (390, 195), (381, 197)]:
        rect(a, b, a + 5, b + 3, ";")
    line([(386, 196), (384, 199)], 2, ",")
    rect(392, 200, 397, 202, ";")                     # Warden of Embers' throne
    prop("castle_ruin", 384, 188, 0.5, note="fallen manor")
    prop("castle_ruin", 402, 186, 0.5)
    prop("tower_ruin", 392, 197, 0.6)
    prop("castle_red", 394.5, 202, 0.55, note="Warden of Embers")
    for (x, y) in [(393, 160), (395, 170), (388, 190), (400, 192)]:
        prop("fire", x, y, 0.5)
    for (x, y) in [(383, 157), (402, 162), (385, 167), (404, 172)]:
        prop("deco16", x, y, 0.55)
    area("deepvault", [[x0, y0, x1, y1]], "prison", [394, 155],
         zones=[{"name": "Molten Capital", "rects": [[x0, 177, x1, y1]], "style": "molten"}])


def build_hoarfrost():
    rng = random.Random(305)
    x0, y0, x1, y1 = 290, 160, 375, 205
    rect(x0, y0, x1, y1, ".")
    border(x0, y0, x1, y1, "R", rng, th=3, extra=3, alt="T")
    # icy pass: switchbacks between rock spurs, a glacier lake, snowfields with wild drifts
    for (a, b, c, d) in [(300, 166, 340, 168), (320, 176, 368, 178), (296, 186, 336, 188), (330, 194, 370, 196)]:
        rect(a, b, c, d, "R")
    ellipse(352, 168, 8, 4, "~", rng, 0.3)
    ellipse(352, 168, 5, 2.5, "_", rng, 0.2)
    blobs(x0 + 4, y0 + 4, x1 - 4, y1 - 4, 22, 2, 4.5, '"', rng)
    scatter(x0 + 4, y0 + 4, x1 - 4, y1 - 4, "T", 0.03, rng)
    line([(330, y0 - 1), (330, 164), (346, 172), (370, 172), (372, 182), (340, 182), (314, 182), (296, 180), (294, 192), (316, 192), (340, 200), (300, 200), (x0, 200)], 2, ":")
    gate("g_royal_ward_north", 288, 199, 291, 201)
    prop("house_blue", 343, 171, 0.76, mod=[0.92, 0.97, 1.0], note="pass hut", clear=(3, 2))
    prop("fire", 346, 174, 0.45)
    npc("pawn", 341, 174, True, note="pass warden")
    prop("tower_ruin", 300, 190, 0.6, mod=[0.92, 0.97, 1.0])
    prop("deco17", 332, 165, 0.6, note="signpost")
    area("hoarfrost_pass", [[x0, y0, x1, y1]], "snow", [330, 162])


# =========================================================== Act IV: the Crownlands
def build_kingshold():
    rng = random.Random(401)
    x0, y0, x1, y1 = 150, 94, 288, 205
    rect(x0, y0, x1, y1, ".")
    border(x0, y0, x1, y1, "T", rng, th=2, extra=2)
    # --- Kingshold Approach (north): the royal road from the fort causeway, farms, a river and a town
    rect(208, y0, 215, y0 + 2, ":")
    river([(x0 + 2, 116), (176, 112), (200, 118), (230, 114), (262, 120), (x1 - 2, 116)], 3, rng)
    blobs(x0 + 4, y0 + 4, x1 - 4, 128, 22, 2.5, 5.5, '"', rng)
    scatter(x0 + 3, y0 + 3, x1 - 3, 128, "b", 0.02, rng)
    line([(211.5, y0), (211.5, 108), (220, 118), (220, 130)], 3, ":")
    line([(220, 124), (250, 124), (270, 130), (283, 140), (283, 200), (x1, 200)], 2, ":")   # east road to Hoarfrost
    line([(220, 110), (186, 110), (164, 104), (x0, 104)], 2, ":")                          # west road to the archive
    line([(222, 102.5), (250, 102.5)], 2, ":")                                           # crown market town
    line([(236.5, 97), (236.5, 110)], 2, ":")
    rect(232, 100, 241, 105, ",")
    for (x, y) in [(228, 98), (234, 98), (240, 98), (246, 98), (228, 106), (234, 106), (242, 106), (248, 103)]:
        prop(rng.choice(["house_yellow", "house_blue", "house_red"]), x, y, 0.8, rng.random() < 0.5, clear=(3, 2))
    prop("tower_yellow", 222, 101, 0.6, note="toll tower")
    for (x, y, f) in [(230, 102, False), (238, 103, True), (244, 101, False), (236, 105, True), (213, 100, True)]:
        npc("pawn", x, y, f)
    for (x, y) in [(256, 100), (259, 101), (262, 99), (190, 100), (193, 101)]:
        npc("sheep", x, y, x % 2 == 1)
    prop("house_yellow", 194, 98, 0.78, note="royal farm", clear=(3, 2))
    prop("wtower", 266, 108, 0.5, note="mill")
    # --- Kingshold Citadel (south-east): walled keep with towers, inner bailey of rubble halls
    cx0, cy0, cx1, cy1 = 196, 132, 278, 196
    rect(cx0, cy0, cx1, cy1, "#")
    rect(cx0 + 3, cy0 + 3, cx1 - 3, cy1 - 3, ".")                # outer bailey lawns
    line([(219.5, cy0), (219.5, cy0 + 8), (236.5, cy0 + 8), (236.5, cy1 - 4)], 3, ":")
    line([(cx0 + 3, 171), (cx1 - 3, 171)], 2, ":")
    line([(cx0 + 3, cy0 + 8), (cx1 - 3, cy0 + 8)], 2, ":")
    line([(cx1 - 3, 183), (250, 183)], 2, ":")
    scatter(cx0 + 4, cy0 + 4, cx1 - 4, cy1 - 4, "b", 0.03, rng)
    for (cx, cy) in [(208, 160), (266, 160)]:
        ellipse(cx, cy, 3, 2, "~", rng, 0.0)                      # bailey fountains
    rect(216, cy0, 223, cy0 + 3, ",")                      # citadel north gate
    rect(cx0 + 10, cy0 + 12, cx1 - 10, cy0 + 14, "#")
    rect(232, cy0 + 12, 240, cy0 + 14, ",")
    for (a, b) in [(cx0 + 5, cy0 + 18), (cx0 + 26, cy0 + 18), (cx0 + 50, cy0 + 18), (cx0 + 5, cy0 + 40), (cx0 + 50, cy0 + 40)]:
        rect(a, b, a + 16, b + 12, ";")
    rect(cx0 + 26, cy0 + 38, cx0 + 46, cy1 - 4, "#")              # inner keep
    rect(cx0 + 28, cy0 + 40, cx0 + 44, cy1 - 6, ",")
    rect(235, cy0 + 38, 238, cy0 + 40, ",")
    for (a, b) in [(cx0 + 5, cy0 + 18), (cx0 + 26, cy0 + 18), (cx0 + 50, cy0 + 18), (cx0 + 5, cy0 + 40), (cx0 + 50, cy0 + 40)]:
        rect(a - 1, b - 1, a + 17, b + 13, "#")                    # walled halls with doors
        rect(a, b, a + 16, b + 12, ";")
        rect(a + 7, b - 1, a + 9, b - 1, ",")
        rect(a + 7, b + 13, a + 9, b + 13, ",")
    rect(cx1 - 3, 182, cx1, 184, ",")                      # east postern to the royal road
    rect(cx0, 170, cx0 + 3, 172, ",")                      # west door into the garden
    prop("castle_blue", 236.5, 186, 1.0, note="the king's citadel (boss_kingshold)")
    for (x, y) in [(cx0 + 2, cy0 + 2), (cx1 - 2, cy0 + 2), (cx0 + 2, cy1 - 2), (cx1 - 2, cy1 - 2), (214, cy0 + 1), (225, cy0 + 1)]:
        prop("tower", x, y, 0.7, note="citadel tower")
    for (x, y) in [(220, 140), (252, 140), (210, 160), (262, 160), (230, 176), (244, 176)]:
        prop("fire", x, y, 0.5)
    for (x, y, f) in [(217, 131, False), (222, 131, True), (236, 147, False), (240, 147, True)]:
        npc("warrior", x, y, f)
    prop("deco16", 233, 170, 0.6, note="drake sigil shrine")
    for (x, y) in [(204, 150), (270, 150), (204, 190), (270, 190), (228, 140), (246, 140)]:
        prop(rng.choice(["house_blue", "house_yellow"]), x, y, 0.78, rng.random() < 0.5, clear=(3, 2), note="bailey quarters")
    for (x, y, f) in [(212, 168, False), (262, 174, True), (230, 141, False), (244, 141, True)]:
        npc("archer", x, y, f)
    # --- Withered Royal Garden (south-west): dead hedges, dry fountains, the drake altar to the west
    gx0, gy0, gx1, gy1 = x0 + 2, 130, 194, y1 - 2
    rect(gx0, gy0, gx1, gy1, ".")
    blobs(gx0 + 2, gy0 + 2, gx1 - 2, gy1 - 2, 18, 2, 4, '"', rng)
    for k in range(6):
        rect(gx0 + 4, gy0 + 6 + k * 12, gx1 - 6, gy0 + 6 + k * 12, "b")
        rect(gx0 + 18 + (k % 2) * 12, gy0 + 6 + k * 12, gx0 + 21 + (k % 2) * 12, gy0 + 6 + k * 12, ".")
    for (cx, cy) in [(162, 150), (182, 174), (166, 192)]:
        ellipse(cx, cy, 2.5, 1.8, "~", rng, 0.2, only=set('."b'))
    scatter(gx0 + 2, gy0 + 2, gx1 - 2, gy1 - 2, "T", 0.025, rng, only='.')
    line([(cx0, 171), (180, 171), (172, 180), (x0 - 1, 180)], 2, ":")
    gate("g_drake_altar", x0 - 2, 179, x0 + 1, 181)
    line([(211.5, 128), (211.5, 130), (180, 130), (170, 140), (180, 160), (180, 171)], 2, ":")
    for (x, y) in [(172, 144), (186, 164), (160, 186)]:
        prop("tower_ruin", x, y, 0.55, note="dead gazebo")
    prop("castle_ruin", 160, 166, 0.55, note="old summer palace")
    # archive doors on the west road
    gate("g_archive_doors", x0 - 2, 103, x0 + 1, 105)
    area("kingshold", [[x0, y0, x1, y1]], "royal", [211, 96],
         zones=[{"name": "Kingshold Citadel", "rects": [[cx0, cy0, cx1, cy1]], "style": "citadel"},
                {"name": "Withered Royal Garden", "rects": [[x0, 129, 195, y1]], "style": "withered"},
                {"name": "Kingshold Approach", "rects": [[x0, y0, x1, 131]]}])


def build_drakespire():
    rng = random.Random(402)
    x0, y0, x1, y1 = 96, 150, 148, 205
    rect(x0, y0, x1, y1, "R")
    rect(x0 + 2, y0 + 2, x1 - 2, y1 - 2, ".")
    border(x0 + 2, y0 + 2, x1 - 2, y1 - 2, "R", rng, th=1, extra=2)
    # a scorched mountain: switchback trail up through rock bands to the summit nest, lava seeps
    for (a, b, c, d) in [(100, 194, 136, 195), (110, 184, 146, 185), (100, 174, 136, 175), (110, 164, 146, 165)]:
        rect(a, b, c, d, "#")
    blobs(x0 + 4, y0 + 4, x1 - 4, y1 - 4, 14, 1.5, 3, ";", rng)
    blobs(x0 + 4, y0 + 4, x1 - 4, y1 - 4, 6, 1.2, 2.2, "L", rng)
    scatter(x0 + 3, y0 + 3, x1 - 3, y1 - 3, "R", 0.03, rng)
    line([(x1 + 1, 180), (140, 180), (140, 190), (104, 190), (104, 179), (140, 179), (140, 169), (104, 169), (104, 158), (122, 156)], 2, ":")
    ellipse(122, 156, 4, 2.5, ",", rng, 0.0)
    prop("tower_ruin", 122, 155, 0.8, note="drake nest summit")
    prop("fire", 118, 157, 0.55)
    prop("fire", 126, 157, 0.55)
    for (x, y) in [(132, 189), (110, 172), (136, 168)]:
        prop("deco16", x, y, 0.6)
    area("drakespire_peak", [[x0, y0, x1, y1]], "drake", [145, 180])


def build_archive():
    rng = random.Random(403)
    x0, y0, x1, y1 = 70, 94, 148, 148
    rect(x0, y0, x1, y1, "#")
    # library of falling stars: stack aisles, reading domes, an observatory court open to the sky
    rect(x0 + 3, y0 + 3, x1 - 3, y1 - 3, ",")
    for k in range(8):
        ax = x0 + 8 + k * 8
        rect(ax, y0 + 6, ax + 1, y0 + 20, "#")
        rect(ax, y0 + 30, ax + 1, y1 - 8, "#")
    rect(x0 + 3, y0 + 22, x1 - 3, y0 + 28, ";")
    ellipse(108, 132, 10, 6, ".", rng, 0.0)
    ellipse(108, 132, 3, 2, "~", rng, 0.0)
    rect(x1 - 3, 103, x1, 105, ",")
    rect(x0 + 3, 120, x0 + 6, 124, ";")
    rect(x0, 121, x0 + 3, 123, ",")
    gate("g_rift_heart", x0 - 2, 121, x0 + 1, 123)
    for (x, y) in [(84, 100), (108, 100), (132, 100), (84, 142), (132, 142)]:
        prop("tower_purple", x, y, 0.6, note="star tower")
    prop("castle_purple", 108, 126, 0.65, note="observatory (archive boss)")
    for (x, y) in [(96, 118), (120, 118), (90, 132), (126, 132)]:
        prop("fire", x, y, 0.45, note="star lamp", mod=[0.7, 0.8, 1.0])
    area("starfall_archive", [[x0, y0, x1, y1]], "archive", [145, 104])


def build_rift_heart():
    rng = random.Random(404)
    x0, y0, x1, y1 = 4, 94, 68, 148
    rect(x0, y0, x1, y1, "~")
    # shattered islands floating in the rift sea, joined by broken bridges, the heart at the centre
    isl = [(60, 122, 6, 5), (46, 112, 6, 4), (46, 134, 6, 4), (30, 122, 9, 8), (14, 106, 5, 4), (14, 138, 5, 4)]
    for (cx, cy, rx, ry) in isl:
        ellipse(cx, cy, rx, ry, ".", rng, 0.3)
        ellipse(cx, cy, rx * 0.6, ry * 0.6, ";", rng, 0.3)
    line([(x1 + 1, 122), (60, 122), (46, 112), (30, 122), (46, 134), (60, 122)], 2, ":")
    line([(30, 122), (14, 106)], 2, ":")
    line([(30, 122), (14, 138), (14, y1 + 1)], 2, ":")
    ellipse(30, 122, 3, 2.4, ",", rng, 0.0)
    gate("g_postgame", 13, 147, 16, 149)
    prop("castle_purple", 30, 121, 0.7, note="the Rift Heart", mod=[1.0, 0.7, 1.0])
    for (x, y) in [(46, 111), (46, 133), (14, 105)]:
        prop("tower_ruin", x, y, 0.55, mod=[0.95, 0.75, 1.0])
    area("rift_heart", [[x0, y0, x1, y1]], "rift", [66, 122])


def build_riftsea():
    rng = random.Random(501)
    x0, y0, x1, y1 = 4, 150, 94, 205
    rect(x0, y0, x1, y1, "~")
    # post-game: rift fields of drifting land joined by broken bridges, the abyss (Riftsea Depths) south-east
    isl = []
    for _ in range(24):
        cx, cy = rng.uniform(10, 88), rng.uniform(155, 200)
        rx, ry = rng.uniform(2.5, 6), rng.uniform(2, 4)
        ellipse(cx, cy, rx, ry, ".", rng, 0.4)
        isl.append((cx, cy))
    blobs(x0 + 4, y0 + 2, x1 - 4, y1 - 4, 16, 2, 4, '"', rng, only=".")
    ellipse(72, 192, 7, 5, ";", rng, 0.3, only=set('.~"'))
    ellipse(72, 192, 2.5, 1.8, "~", rng, 0.0)
    isl.append((72, 189))
    # nearest-neighbour tour from the rift gate so every island is on the walk
    cur = (14.5, 151); tour = [cur]; left = isl[:]
    while left:
        nx = min(left, key=lambda p: (p[0] - cur[0]) ** 2 + (p[1] - cur[1]) ** 2)
        left.remove(nx); tour.append(nx); cur = nx
    line(tour, 2, ":")
    for (x, y) in [isl[3], isl[8], isl[13], isl[18]]:
        prop("tower_ruin", round(x), round(y), 0.55, mod=[0.9, 0.7, 1.0])
    prop("castle_ruin", 72, 188, 0.6, note="Riftsea Depths")
    area("riftsea_expanse", [[x0, y0, x1, y1]], "riftsea", [14, 152],
         zones=[{"name": "Riftsea Depths", "rects": [[56, 182, x1, y1]]}, {"name": "Shattered Expanse", "rects": [[x0, y0, x1, y1]]}])


STYLES = {
    "fort": {"floor": [0.78, 0.74, 0.7], "wall": [0.85, 0.8, 0.76], "map": [0.6, 0.55, 0.5]},
    "ember": {"grass": [1.0, 0.8, 0.6], "overlay": [0.35, 0.16, 0.08, 0.22], "tree": [1.0, 0.72, 0.5], "wild": [1.0, 0.72, 0.45], "road": [1.0, 0.9, 0.8], "wall": [0.85, 0.6, 0.5], "rock": [1.0, 0.8, 0.7], "embers": True, "map": [0.75, 0.45, 0.3]},
    "steppe": {"grass": [1.05, 0.86, 0.55], "overlay": [0.75, 0.3, 0.1, 0.16], "wild": [1.0, 0.55, 0.35], "tree": [1.0, 0.8, 0.55], "map": [0.8, 0.4, 0.25]},
    "canyon": {"grass": [0.85, 0.9, 1.0], "overlay": [0.55, 0.8, 1.0, 0.22], "rock": [0.7, 0.95, 1.0], "wall": [0.75, 0.9, 1.0], "floor": [0.75, 0.85, 0.95], "wild": [0.7, 0.95, 1.0], "map": [0.5, 0.8, 0.9]},
    "redcap": {"grass": [0.96, 0.84, 0.8], "overlay": [0.5, 0.1, 0.15, 0.12], "wild": [1.0, 0.62, 0.6], "tree": [0.95, 0.62, 0.55], "map": [0.7, 0.3, 0.35]},
    "fen": {"grass": [0.66, 0.76, 0.5], "overlay": [0.12, 0.18, 0.05, 0.3], "water": [0.24, 0.42, 0.32, 1.0], "tree": [0.6, 0.74, 0.55], "wild": [0.7, 0.8, 0.45], "map": [0.3, 0.45, 0.25]},
    "foxglove": {"grass": [0.86, 0.92, 0.78], "overlay": [0.5, 0.2, 0.6, 0.08], "water": [0.24, 0.42, 0.32, 1.0], "tree": [0.8, 0.86, 0.72], "map": [0.55, 0.45, 0.6]},
    "abbey": {"floor": [0.7, 0.76, 0.8], "wall": [0.72, 0.82, 0.86], "water": [0.2, 0.45, 0.5, 1.0], "map": [0.45, 0.55, 0.6]},
    "lantern": {"floor": [0.88, 0.76, 0.55], "wall": [0.9, 0.78, 0.6], "map": [0.75, 0.6, 0.3]},
    "catacomb": {"floor": [0.56, 0.5, 0.45], "wall": [0.58, 0.52, 0.46], "tree": [0.5, 0.56, 0.4], "map": [0.4, 0.35, 0.3]},
    "caldera": {"grass": [0.62, 0.46, 0.4], "overlay": [0.15, 0.05, 0.03, 0.42], "floor": [0.56, 0.42, 0.38], "wall": [0.75, 0.45, 0.35], "rock": [0.9, 0.55, 0.45], "tree": [0.6, 0.4, 0.3], "water": [0.5, 0.32, 0.22, 1.0], "road": [0.7, 0.55, 0.5], "embers": True, "map": [0.5, 0.2, 0.1]},
    "snow": {"overlay": [0.94, 0.97, 1.0, 0.8], "tree": [0.82, 0.92, 1.0], "wild": [0.86, 0.95, 1.0], "rock": [0.86, 0.93, 1.0], "road": [0.92, 0.95, 1.0], "water": [0.5, 0.72, 0.82, 1.0], "wall": [0.92, 0.96, 1.0], "floor": [0.86, 0.9, 0.96], "snow": True, "map": [0.93, 0.96, 1.0]},
    "frostlake": {"overlay": [0.94, 0.97, 1.0, 0.8], "water": [0.55, 0.78, 0.88, 1.0], "snow": True, "map": [0.8, 0.9, 1.0]},
    "terraces": {"grass": [0.72, 0.76, 0.95], "overlay": [0.2, 0.15, 0.45, 0.22], "tree": [0.66, 0.7, 0.95], "wild": [0.76, 0.7, 1.0], "water": [0.26, 0.36, 0.6, 1.0], "wall": [0.75, 0.75, 0.95], "floor": [0.8, 0.8, 0.95], "map": [0.4, 0.4, 0.7]},
    "spire": {"floor": [0.76, 0.7, 0.95], "wall": [0.76, 0.7, 0.96], "map": [0.55, 0.45, 0.8]},
    "prison": {"floor": [0.56, 0.56, 0.62], "wall": [0.58, 0.6, 0.68], "map": [0.35, 0.35, 0.4]},
    "molten": {"floor": [0.62, 0.46, 0.4], "wall": [0.72, 0.42, 0.35], "embers": True, "map": [0.6, 0.25, 0.15]},
    "royal": {"grass": [0.96, 1.0, 0.86], "road": [1.0, 0.97, 0.9], "tree": [0.9, 1.0, 0.86], "map": [0.7, 0.7, 0.4]},
    "citadel": {"floor": [0.88, 0.87, 0.82], "wall": [0.92, 0.9, 0.86], "map": [0.8, 0.8, 0.7]},
    "withered": {"grass": [0.76, 0.7, 0.55], "overlay": [0.3, 0.24, 0.14, 0.28], "tree": [0.7, 0.6, 0.45], "wild": [0.8, 0.7, 0.5], "water": [0.32, 0.42, 0.38, 1.0], "map": [0.5, 0.45, 0.3]},
    "drake": {"grass": [0.7, 0.6, 0.55], "overlay": [0.2, 0.1, 0.08, 0.35], "rock": [0.85, 0.65, 0.55], "wall": [0.8, 0.6, 0.5], "floor": [0.7, 0.58, 0.52], "embers": True, "map": [0.45, 0.3, 0.25]},
    "archive": {"floor": [0.62, 0.64, 0.86], "wall": [0.64, 0.66, 0.9], "grass": [0.62, 0.66, 0.9], "overlay": [0.1, 0.1, 0.35, 0.28], "water": [0.2, 0.25, 0.5, 1.0], "map": [0.35, 0.35, 0.6]},
    "rift": {"grass": [0.76, 0.52, 0.9], "overlay": [0.35, 0.05, 0.4, 0.32], "floor": [0.72, 0.52, 0.86], "wall": [0.66, 0.46, 0.86], "water": [0.3, 0.12, 0.42, 1.0], "tree": [0.7, 0.5, 0.9], "wild": [0.86, 0.5, 1.0], "road": [0.85, 0.7, 0.95], "map": [0.5, 0.2, 0.55]},
    "riftsea": {"grass": [0.66, 0.5, 0.86], "overlay": [0.25, 0.05, 0.35, 0.35], "floor": [0.62, 0.48, 0.8], "water": [0.16, 0.06, 0.3, 1.0], "wild": [0.8, 0.5, 1.0], "road": [0.8, 0.66, 0.92], "map": [0.3, 0.1, 0.4]},
}


def check_overlaps():
    OLD = {a["id"] for a in tiles1["areas"]}
    boxes = [("ironbridge_fort", q) for q in [[202, 40, 221, 69], [222, 50, 231, 57], [206, 70, 217, 93]]]
    boxes += [(a["id"], q) for a in tiles1["areas"] if a["id"] != "ironbridge_fort" for q in a["rects"]]
    boxes += [(aid, q) for aid, a in AREAS.items() for q in a["rects"]]
    for i, (ia, qa) in enumerate(boxes):
        for ib, qb in boxes[i + 1:]:
            if ia in OLD and ib in OLD:
                continue  # Act I's own hand-tuned rects (first match wins there)
            if ia != ib and qa[0] <= qb[2] and qb[0] <= qa[2] and qa[1] <= qb[3] and qb[1] <= qa[3]:
                raise SystemExit("area rects overlap: %s %s / %s %s" % (ia, qa, ib, qb))


def claim_gaps():
    """Walkable tiles between two area rects (doorways, bridge ends) join the neighbouring area."""
    owner = {}
    for aid, a in list(AREAS.items()) + [("ironbridge_fort", {"rects": [[202, 40, 221, 69], [222, 50, 231, 57], [206, 70, 217, 93]]})]:
        for q in a["rects"]:
            for y in range(q[1], q[3] + 1):
                for x in range(q[0], q[2] + 1):
                    owner.setdefault((x, y), aid)
    for y in range(H):
        for x in range(W):
            if x < A1W and y < A1H:
                continue
            if G[y][x] in "~TR#L" or (x, y) in owner:
                continue
            for dx, dy in ((-1, 0), (0, -1), (1, 0), (0, 1), (-2, 0), (0, -2), (2, 0), (0, 2)):
                n = owner.get((x + dx, y + dy))
                if n and n in AREAS:
                    AREAS[n]["rects"].append([x, y, x, y])
                    owner[(x, y)] = n
                    break


def main():
    build_fort()
    build_redcap(); build_emberfall(); build_steppe(); build_abbey(); build_mirefen(); build_lanternkeep(); build_caldera()
    build_frostveil(); build_terraces(); build_spire(); build_deepvault(); build_hoarfrost()
    build_kingshold(); build_drakespire(); build_archive(); build_rift_heart(); build_riftsea()
    check_overlaps()
    claim_gaps()
    rows = ["".join(r) for r in G]
    for y in range(A1H):
        for x in range(A1W):
            if (x, y) not in EDIT_OK:
                assert rows[y][x] == src[y][x], ("Act I tile changed", x, y)
    open(os.path.join(ROOT, "data/world_map.txt"), "w").write("\n".join(rows) + "\n")
    # tiles json: keep Act I areas/zones/gates/props, finish the fort, append the new acts
    t = json.loads(json.dumps(tiles1))
    t["_readme"] = ("Tile rects are [col0,row0,col1,row1] inclusive (64px tiles). First matching rect wins. 'start' is the new-game tile. "
                    "Gate rects tie X tiles to world.json gates. Layout 3 (tools/build_world_acts.py): Act I is the hand-tuned layout 2 verbatim "
                    "(cols 0-223, rows 0-91), the canvas grows east and south to 448x208 for Acts II-V; Act I coordinates did not move. "
                    "'style' names a look in 'styles' (code tints only, no extra art). 'spawn' is the ?warp= tile. Props: img keys from world.gd PROP_DEFS.")
    for a in t["areas"]:
        if a["id"] == "ironbridge_fort":
            a["rects"] = [[202, 40, 221, 69], [222, 50, 231, 57], [206, 70, 217, 93]]
            a["style"] = "fort"
            a["spawn"] = [212, 52]
    t["props"] = [p for p in t["props"] if not (202 <= p["x"] <= 222 and 40 <= p["y"] <= 70)]
    t["props"] += PROPS
    t["areas"] += list(AREAS.values())
    t["gates"] += GATES
    t["styles"] = STYLES
    json.dump(t, open(os.path.join(ROOT, "data/world_tiles.json"), "w"), indent=1)
    print("map", W, "x", H, "areas", len(t["areas"]), "gates", len(t["gates"]), "props", len(t["props"]))


if __name__ == "__main__":
    main()
