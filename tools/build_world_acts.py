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


def snoise(t, seed, f0=0.09):
    """Smooth 1D noise in 0..1 (three octaves of sines with seeded phases)."""
    r = random.Random(seed)
    v = 0.0
    for k, amp in enumerate((0.55, 0.3, 0.15)):
        f = f0 * (2.1 ** k) * r.uniform(0.8, 1.25)
        v += amp * (0.5 + 0.5 * math.sin(t * f + r.uniform(0, math.tau)))
    return v


def border(x0, y0, x1, y1, ch, rng, th=2, extra=2, alt=None, coast=0, corner=6):
    """Organic edge: blocking tiles (trees / rock) whose depth wanders with smooth noise, rounded corners, clumps
    spilling inward, and optionally a water coast/channel on the very outside."""
    seed = rng.randint(0, 1 << 30)
    depth = th + extra
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            dl, dr, dt, db = x - x0, x1 - x, y - y0, y1 - y
            d = min(dl, dr, dt, db)
            if d > depth + 3 + coast:
                continue
            # rounded corners
            cx = min(dl, dr); cy = min(dt, db)
            if cx < corner and cy < corner:
                d = min(d, corner - math.hypot(corner - cx, corner - cy))
            if d == dl or d == dr:
                sv = snoise(y, seed + (0 if d == dl else 1))
            else:
                sv = snoise(x, seed + (2 if d == dt else 3))
            lim = th + extra * sv * 1.6
            wlim = coast * (0.35 + 0.9 * snoise(x + y, seed + 7, 0.05)) if coast else 0
            if d < wlim:
                put(x, y, "~")
            elif d < wlim + lim:
                c = ch
                if alt and rng.random() < 0.3:
                    c = alt
                put(x, y, c)
            elif d < wlim + lim + 2.5 and rng.random() < 0.22 and get(x, y) == ".":
                put(x, y, ch if rng.random() < 0.7 else (alt or ch))


def roughen(x0, y0, x1, y1, rng, p_out=0.18, p_in=0.08, floor=";"):
    """Break straight dungeon walls: nibble wall tiles that face a room, push a few wall knobs into rooms."""
    keep = lambda xx, yy: any(get(xx + dx, yy + dy) in "X=" for dx in range(-2, 3) for dy in range(-2, 3))
    cells = [(x, y) for y in range(y0 + 1, y1) for x in range(x0 + 1, x1)]
    snap = {(x, y): get(x, y) for (x, y) in cells}
    for (x, y) in cells:
        c = snap[(x, y)]
        if keep(x, y):
            continue
        n = [snap.get((x + dx, y + dy), "#") for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))]
        if c == "#" and sum(1 for v in n if v in ",;") == 1 and rng.random() < p_out:
            # only nibble if the wall stays at least 2 thick behind it
            put(x, y, floor if rng.random() < 0.6 else ",")
        elif c in ",;" and sum(1 for v in n if v == "#") == 1 and rng.random() < p_in:
            if all(snap.get((x + dx, y + dy), "#") in ",;" for dx, dy in ((1, 1), (-1, 1), (1, -1), (-1, -1)) if snap.get((x + dx, y + dy), "#") != "#") :
                put(x, y, "#")


def pillars(x0, y0, x1, y1, step=4, ch="#"):
    for y in range(y0, y1 + 1, step):
        for x in range(x0, x1 + 1, step):
            if get(x, y) in ",;":
                put(x, y, ch)


DECO_SETS = {
    "green": ["01", "02", "03", "07", "08", "09", "10", "11", "12", "13", "14"],
    "fen": ["01", "02", "03", "10", "11", "15", "08"],
    "ember": ["04", "05", "06", "10", "15", "09"],
    "snow": ["04", "05", "06", "09"],
    "rift": ["04", "05", "06", "15", "16"],
    "dungeon": ["04", "05", "06", "15"],
    "redcap": ["01", "02", "03", "01", "02", "10", "11", "08"],
}


def decorate(x0, y0, x1, y1, rng, kind="green", dens=0.035, mod=None, floor_dens=0.0, torches=0.0):
    """Non-blocking ground dressing (Tiny Swords deco) and wall torches; avoids roads, water, props."""
    taken = {(round(p["x"]), round(p["y"])) for p in PROPS}
    pal = DECO_SETS[kind]
    for y in range(y0 + 1, y1):
        for x in range(x0 + 1, x1):
            c = get(x, y)
            if (x, y) in taken:
                continue
            near_road = any(get(x + dx, y + dy) in ":=X" for dx in (-1, 0, 1) for dy in (-1, 0, 1))
            if c in '."' and not near_road and rng.random() < dens:
                d = rng.choice(pal)
                prop("deco" + d, x + rng.uniform(-0.3, 0.3), y + rng.uniform(-0.3, 0.2), rng.uniform(0.75, 1.0), rng.random() < 0.5, mod=mod, walk=True)
            elif c in ",;" and floor_dens and rng.random() < floor_dens:
                prop("deco" + rng.choice(DECO_SETS["dungeon"]), x + rng.uniform(-0.3, 0.3), y, rng.uniform(0.6, 0.85), walk=True)
            elif c in ",;" and torches and get(x, y - 1) == "#" and rng.random() < torches and not near_road:
                prop("fire", x, y - 0.35, 0.36, note="wall torch")


def street_houses(pts, rng, kinds, spacing=5.0, off=2.6, s=0.8, mod=None, note=None, both=True):
    """Line a street with houses on both sides where the ground is free (real streets, not scattered huts)."""
    placed = []
    for (ax, ay), (bx, by) in zip(pts, pts[1:]):
        L = math.hypot(bx - ax, by - ay)
        if L < 1:
            continue
        nx, ny = -(by - ay) / L, (bx - ax) / L
        k = spacing * 0.6
        while k < L:
            px, py = ax + (bx - ax) * k / L, ay + (by - ay) * k / L
            for side in ((1, -1) if both else (1,)):
                hx, hy = round(px + nx * off * side), round(py + ny * off * side + (0.6 if ny * side > 0 else 0))
                ok = all(get(xx, yy) in '.,"b' for yy in range(hy - 1, hy + 1) for xx in range(hx - 1, hx + 2))
                ok = ok and all(math.hypot(hx - p["x"], hy - p["y"]) > 2.6 for p in PROPS if p["img"].startswith(("house", "castle", "tower", "ghouse", "goldmine", "wtower")))
                if ok:
                    prop(rng.choice(kinds), hx, hy, s + rng.uniform(-0.04, 0.04), rng.random() < 0.5, mod=mod, note=note)
                    placed.append((hx, hy))
            k += spacing
    return placed


def wiggle(pts, rng, amp=1.2, step=5):
    """Subdivide a polyline and bend it a little so roads don't run ruler-straight."""
    out = [pts[0]]
    for (ax, ay), (bx, by) in zip(pts, pts[1:]):
        L = math.hypot(bx - ax, by - ay)
        n = max(1, int(L / step))
        nx, ny = (-(by - ay) / L, (bx - ax) / L) if L else (0, 0)
        for i in range(1, n + 1):
            t = i / n
            o = 0 if i == n else math.sin(t * math.pi) * rng.uniform(-amp, amp)
            out.append((ax + (bx - ax) * t + nx * o, ay + (by - ay) * t + ny * o))
    return out


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


def cave(x0, y0, x1, y1, pts, rng, chambers=()):
    """Cave interior: solid rock wall with winding rubble tunnels between pts and a few stone chambers."""
    rect(x0, y0, x1, y1, "#")
    for (ax, ay), (bx, by) in zip(pts, pts[1:]):
        x, y = float(ax), float(ay)
        while abs(x - bx) > 0.6 or abs(y - by) > 0.6:
            dx, dy = bx - x, by - y
            d = max(1e-6, math.hypot(dx, dy))
            x += dx / d + (rng.random() - 0.5) * 0.9
            y += dy / d + (rng.random() - 0.5) * 0.9
            x = min(max(x, x0 + 1), x1 - 1); y = min(max(y, y0 + 1), y1 - 1)
            w = 2 if rng.random() < 0.7 else 3
            rect(int(x) - w // 2, int(y) - w // 2, int(x) - w // 2 + w - 1, int(y) - w // 2 + w - 1, ";")
        rect(int(bx) - 1, int(by) - 1, int(bx), int(by), ";")
    for (cx, cy, rx, ry) in chambers:
        ellipse(cx, cy, rx, ry, ",", rng, 0.3, only=set("#;"))


def rooms(rs, edges, rng, cw=2, corr=",", amp=1.0):
    """Hand-feel dungeon: irregular rooms (ellipse 'o' or ragged rect 'r') joined by bent corridors.
    rs: list of (cx, cy, rx, ry, shape, ch)."""
    for (cx, cy, rx, ry, shp, ch) in rs:
        if shp == "o":
            ellipse(cx, cy, rx, ry, ch, rng, 0.35)
        else:
            for y in range(int(cy - ry), int(cy + ry) + 1):
                jl = rng.choice((0, 0, 0, 1)); jr = rng.choice((0, 0, 0, 1))
                rect(int(cx - rx) + jl, y, int(cx + rx) - jr, y, ch)
    for (i, j) in edges:
        a, b = rs[i], rs[j]
        mid = ((a[0] + b[0]) / 2 + (rng.random() - 0.5) * 4, (a[1] + b[1]) / 2 + (rng.random() - 0.5) * 4)
        line(wiggle([(a[0], a[1]), mid, (b[0], b[1])], rng, amp, 4), cw, corr, over=set("#R"))


def shelves(x0, y0, x1, y1, rng, vertical=True, gap=3):
    """Short book-stack rows inside a room (only on floor), broken so they never seal the room."""
    if vertical:
        for x in range(x0, x1 + 1, gap):
            ya, yb = y0 + rng.randint(0, 1), y1 - rng.randint(0, 1)
            for y in range(ya, yb + 1):
                if get(x, y) == "," and (y - ya) % 6 != 5:
                    put(x, y, "#")
    else:
        for y in range(y0, y1 + 1, gap):
            xa, xb = x0 + rng.randint(0, 1), x1 - rng.randint(0, 1)
            for x in range(xa, xb + 1):
                if get(x, y) == "," and (x - xa) % 7 != 6:
                    put(x, y, "#")


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
    border(x0, y0, x1, y1, "R", rng, th=2, extra=2, alt="T", coast=3)
    # mining rim: a ragged basalt ridge along the north, three mine mouths cut into it, spoil heaps below
    for x in range(x0 + 2, x1 - 1):
        h = 3 + int(round(2.5 * snoise(x, 33, 0.18)))
        rect(x, y0 + 2, x, y0 + 2 + h, "#")
    for mx in (240, 254, 266):
        rect(mx - 1, y0 + 2, mx + 1, y0 + 8, ";")             # adits into the ridge (patrolled)
        rect(mx - 2, y0 + 8, mx + 2, y0 + 9, ":")
    # streets: the bridge road becomes the high street, a crooked lane to each mine, a south lane to the springs
    main = wiggle([(x0, 53.5), (246, 54), (259, 53), (x1, 53.5)], rng, 0.6)
    line(main, 2, ":")
    ellipse(252.5, 54, 5.5, 3.6, ",", rng, 0.0)               # market square
    lanes = [wiggle([(252.5, 50), (252, 46), (254, y0 + 9)], rng, 0.8), wiggle([(244, 53), (241, 47), (240, y0 + 9)], rng, 0.8),
             wiggle([(261, 53), (265, 47), (266, y0 + 9)], rng, 0.8), wiggle([(252.5, 58), (250, 64), (256, 69), (262, y1)], rng, 0.8),
             wiggle([(238, 54), (237, 62), (241, 69)], rng, 0.8)]
    for ln in lanes:
        line(ln, 2, ":")
    line([(246, 43), (246, y0 - 1)], 2, ":", bridge_over_water=False)        # north pass to Redcap Hills
    rect(245, y0, 247, y0 + 9, ":")
    ellipse(241, 68, 4.5, 3, "~", rng, 0.3)                  # hot springs
    ellipse(268, 66, 3, 2.5, "~", rng, 0.3)
    scatter(x0 + 3, y0 + 10, x1 - 3, y1 - 3, "R", 0.015, rng)
    for mx in (240, 254, 266):
        prop("goldmine", mx, y0 + 8, 0.62, note="mine mouth")
        npc("pawn", mx + 2.4, y0 + 10, rng.random() < 0.5)
        prop("rocks4", mx - 3, y0 + 10, 0.9, note="spoil heap", mod=EMBER + [1.0])
    hk = ["house_red", "house_yellow", "house_red"]
    street_houses(main, rng, hk, spacing=4.2, off=2.6, s=0.8)
    for ln in lanes:
        street_houses(ln, rng, hk, spacing=4.5, off=2.6, s=0.78)
    prop("tower_red", 272, 50, 0.6, note="east watch")
    prop("wtower", 235, 70, 0.48, note="ore hoist")
    prop("wtower", 270, 42, 0.46)
    for (x, y) in [(249, 52), (256, 52), (249, 56), (256, 56)]:
        prop("fire", x, y, 0.45, note="forge")
    prop("deco17", 252, 57, 0.6, note="signpost: Redcap / steppe / fort")
    for (x, y, f) in [(251, 54, False), (254, 55, True), (244, 53, False), (259, 54, True), (240, 64, True), (265, 48, False),
                      (248, 47, True), (233, 53, False), (241, 66, False), (268, 64, True), (255, 66, False)]:
        npc("pawn", x, y, f)
    npc("warrior", 274, 52, True)
    npc("warrior", 274, 55, True)
    npc("warrior", 234, 52, False)
    area("emberfall", [[x0, y0, x1, y1]], "ember", [252, 54],
         zones=[{"name": "Emberfall Mines", "rects": [[x0 + 2, y0 + 2, x1 - 2, y0 + 8]]}])


def build_redcap():
    rng = random.Random(202)
    x0, y0, x1, y1 = 232, 2, 345, 33
    rect(x0, y0, x1, y1, ".")
    border(x0, y0, x1, y1, "T", rng, th=2, extra=3, alt="R", coast=3)
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
    # Redcap Burrows: a goblin warren dug into the north-east hills, the road runs into its mouth
    cave(326, 3, 343, 22, [(334, 23), (336, 16), (340, 10), (338, 5), (330, 6), (328, 13)], rng, chambers=[(338, 6, 3, 1.6), (329, 13, 2, 2)])
    line([(326, 24), (334, 24), (334, 21)], 2, ":")
    prop("fire", 334, 19, 0.45, note="burrow torch")
    prop("fire", 339, 7, 0.45)
    prop("deco16", 330, 12, 0.6)
    prop("ghouse_ruin", 312, 28, 0.8, note="goblin camp")
    prop("ghouse", 318, 29, 0.8, True)
    prop("deco16", 315, 30, 0.7)
    prop("fire", 315, 28, 0.5)
    prop("house_yellow", 272, 26, 0.78, clear=(3, 2), note="shepherd hut")
    for (x, y) in [(268, 28), (275, 29), (278, 27)]:
        npc("sheep", x, y, x % 2 == 0)
    npc("pawn", 270, 27)
    area("redcap_hills", [[x0, y0, x1, y1]], "redcap", [246, 30],
         zones=[{"name": "Redcap Burrows", "rects": [[326, 3, 343, 22]], "style": "cave"}])


def build_steppe():
    rng = random.Random(203)
    x0, y0, x1, y1 = 276, 36, 345, 80
    rect(x0, y0, x1, y1, ".")
    border(x0, y0, x1, y1, "R", rng, th=2, extra=2, coast=3)
    blobs(x0 + 3, y0 + 3, x1 - 3, 64, 30, 3, 7, '"', rng)          # red kindlegrass
    scatter(x0 + 3, y0 + 3, x1 - 3, 64, "R", 0.015, rng, only='."')
    scatter(x0 + 3, y0 + 3, x1 - 3, 64, "b", 0.015, rng, only='."')
    # Glasswind Canyon: a crystal gorge along the south with cliff walls and a wind-cut stream
    cy0 = 66
    for x in range(x0 + 2, x1 - 1):                     # ragged canyon rim
        top = cy0 - 1 + int(round(3 * snoise(x, 61, 0.15)))
        rect(x, top, x, y1 - 2, "#")
    gorge = wiggle([(x0 + 3, 72), (290, 70), (300, 73), (312, 75), (322, 71), (332, 72), (x1 - 3, 74)], rng, 1.5, 3)
    for i, (gx, gy) in enumerate(gorge):
        w = 2 + int(round(2.5 * snoise(i, 62, 0.5)))
        rect(int(gx) - 1, int(gy) - w // 2 - 1, int(gx) + 1, int(gy) + w // 2 + 1, ";")
    for (cx, cy, rx, ry) in [(288, 75, 3, 1.6), (318, 69, 2.5, 1.5), (336, 76, 3, 1.5), (300, 77, 2, 1.2)]:
        ellipse(cx, cy, rx, ry, ";", rng, 0.4, only=set("#"))     # wind-cut side pockets
    river(wiggle([(x0 + 6, 76), (296, 75), (308, 77), (322, 75), (x1 - 6, 76)], rng, 0.8, 4), 1, rng, 0.3)
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
    # nomad camp in the red grass
    rect(326, 52, 334, 57, ".")
    for (x, y, f) in [(327, 53, False), (333, 53, True), (330, 57, False)]:
        prop("ghouse", x, y, 0.62, f, note="nomad tent")
    prop("fire", 330, 55, 0.45)
    npc("pawn", 329, 55)
    for (x, y) in [(337, 56), (339, 54), (336, 52)]:
        npc("sheep", x, y, x % 2 == 0)
    area("kindlegrass_steppe", [[x0, y0, x1, y1]], "steppe", [280, 53],
         zones=[{"name": "Glasswind Canyon", "rects": [[x0, cy0, x1, y1]], "style": "canyon"}])


def build_abbey():
    rng = random.Random(204)
    x0, y0, x1, y1 = 290, 81, 335, 105
    rect(x0, y0, x1, y1, "#")
    # a drowned abbey: the nave and cloister under black water, broken walks and boardwalks between
    # the chapter house, the side chapels, the drowned cloister garth and the bell crypt
    for (cx, cy, rx, ry) in [(312, 92, 20, 9), (300, 96, 8, 6), (325, 88, 8, 5)]:
        ellipse(cx, cy, rx, ry, "~", rng, 0.25)
    R = [(301.5, 84, 3, 2, "r", ","),     # 0 canyon stair landing
         (301.5, 89, 6, 2, "r", ","),     # 1 nave crossing
         (293, 88, 2.5, 3, "o", ";"),     # 2 west chapel
         (312, 86, 3.5, 2.5, "o", ";"),   # 3 chapter house
         (326, 86, 4, 2.5, "r", ";"),     # 4 north-east chapel
         (318, 96, 4, 3, "o", "."),       # 5 drowned cloister garth (island)
         (329, 97, 3, 3, "r", ";"),       # 6 sacristy
         (301.5, 100, 5.5, 2.5, "r", ";")]  # 7 bell crypt (Warden of Bells)
    for (cx, cy, rx, ry, shp, ch) in R:
        if shp == "o":
            ellipse(cx, cy, rx, ry, ch, rng, 0.3)
        else:
            rect(int(cx - rx), int(cy - ry), int(cx + rx), int(cy + ry), ch)
    rect(300, y0, 303, 84, ",")
    line([(301.5, 84), (301.5, 100)], 3, ",", over=set("#~"))         # the nave walk
    for (a, b) in [(1, 2), (1, 3), (3, 4), (3, 5), (5, 6), (4, 6), (7, 5)]:
        A, B = R[a], R[b]
        line(wiggle([(A[0], A[1]), (B[0], B[1])], rng, 0.8, 3), 2, "=", over=set("~#"))   # boardwalks
    rect(303, 102, 306, y1, ",")
    gate("g_frostveil_seal", 303, 104, 306, 105)
    roughen(x0, y0, x1, y1, rng, p_out=0.10, p_in=0.03, floor=",")
    prop("castle_ruin", 312, 85, 0.5, note="sunken chapter house")
    prop("tower_ruin", 293, 86.5, 0.5)
    prop("tower_ruin", 326, 85, 0.5)
    prop("house_ruin", 329, 96.5, 0.6, note="sacristy")
    prop("tower", 299, 100, 0.5, note="bell tower: Warden of Bells", mod=[0.75, 0.85, 0.9])
    for (x, y) in [(318, 96), (298, 89), (305, 89), (293, 90), (312, 87)]:
        prop("deco16", x, y, 0.55)
    prop("fire", 297, 100, 0.45)
    prop("fire", 306, 100, 0.45)
    area("sunken_abbey", [[x0, y0, x1, y1]], "abbey", [301, 82])


def build_mirefen():
    rng = random.Random(205)
    x0, y0, x1, y1 = 346, 2, 405, 60
    rect(x0, y0, x1, y1, ".")
    border(x0, y0, x1, y1, "T", rng, th=2, extra=3, coast=3)
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
    # upper keep: gatehouse, a cruciform lantern hall, side halls, lamp-wright's workshop, the warden's throne
    R = [(375.5, 65, 3.5, 2.5, "r", ","),   # 0 gatehouse
         (375.5, 74, 10, 4.5, "r", ","),    # 1 lantern hall
         (357, 72, 5, 3.5, "o", ","),       # 2 west hall
         (394, 72, 5, 3.5, "o", ","),       # 3 east hall
         (356, 80, 3.5, 1.8, "r", ";"),     # 4 workshop
         (395, 80, 3.5, 1.8, "r", ";"),     # 5 store
         (375.5, 81, 3, 1.5, "r", ",")]     # 6 stair down
    rooms(R, [(0, 1), (1, 2), (1, 3), (2, 4), (3, 5), (1, 6)], rng, cw=2)
    rect(372, y0, 379, 64, ",")
    pillars(367, 71, 384, 77, step=4)
    # Underroot Catacomb: a root-choked warren under the keep, ossuary niches, a sunken root lake
    cave(348, 83, 403, 103, [(375, 84), (368, 90), (356, 87), (352, 96), (362, 100), (369, 102), (372, 96), (384, 92), (393, 87),
                            (398, 94), (402, 98), (390, 100), (380, 99)], rng,
         chambers=[(356, 87, 3, 2), (362, 100, 3, 1.6), (393, 87, 3, 2), (384, 92, 2.5, 2), (390, 100, 2.5, 1.5)])
    ellipse(380, 88, 3, 1.6, "~", rng, 0.3, only=set("#"))
    scatter(348, 84, 403, 102, "T", 0.03, rng, only=";", keep_off=",=X")
    # Caldera bridge: east out of the catacombs (dropped by the lever) over the lava chasm
    rect(398, 98, 405, 99, ",")
    gate("g_caldera_bridge", 404, 98, 405, 99)
    # Frost seal: south stair down to the frozen lake
    rect(366, 101, 371, y1, ",")
    gate("g_frostveil_seal", 366, 104, 371, 105)
    for (x, y) in [(367, 71), (384, 71), (367, 77), (384, 77), (357, 70), (394, 70), (373, 64), (378, 64)]:
        prop("fire", x, y, 0.5, note="hanging lantern")
    prop("castle_yellow", 375.5, 73.5, 0.7, note="Warden of Lanterns")
    prop("tower_yellow", 357, 71.5, 0.55)
    prop("tower_yellow", 394, 71.5, 0.55)
    prop("wtower", 356, 79.5, 0.4, note="lamp-wright's crane")
    for (x, y) in [(353, 96), (385, 99), (393, 88), (366, 90), (398, 94)]:
        prop("deco16", x, y, 0.6, note="ossuary niche")
    prop("castle_ruin", 362, 99.5, 0.45, note="ossuary")
    npc("pawn", 395, 80, True, note="lamplighter")
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
    # the city: walled, spired, snowbound. A ring road around the palace hill, an avenue from the bridge gate
    # south to the pass, the market road east to the terraces, a frozen canal, parks and lived-in streets.
    rect(x0, 120, x1, y1, ".")
    border(x0, 120, x1, y1, "T", rng, th=2, extra=2, alt="R", coast=2)
    for x in range(x0 + 5, x1 - 4):                        # north curtain wall, wavy
        t = int(round(1.2 * snoise(x, 91)))
        rect(x, 121 + t, x, 123 + t, "#")
    rect(327, 120, 333, 125, ",")                            # bridge gate
    river([(x0 + 3, 151), (310, 150), (330, 152), (352, 150), (x1 - 3, 151)], 2, rng, 0.5)   # frozen canal
    ring = [(332 + 30 * math.cos(a) , 139 + 11 * math.sin(a)) for a in [k / 24 * math.tau for k in range(25)]]
    line(ring, 2, ":")
    line(wiggle([(330, 124), (330, 134), (331, 146), (330, y1)], rng, 0.8), 3, ":")
    line(wiggle([(x0 + 4, 141), (302, 140), (362, 140), (x1, 140)], rng, 0.8), 2, ":")
    line(wiggle([(304, 128), (306, 155)], rng, 1.0), 2, ":")
    line(wiggle([(357, 128), (356, 155)], rng, 1.0), 2, ":")
    ellipse(331, 141, 6, 3.6, ",", rng, 0.0)                # frost plaza
    ellipse(331, 141, 2.2, 1.4, "~", rng, 0.0)
    put(331, 141, "_")
    ellipse(332, 130, 7, 3.5, ",", rng, 0.0)                # palace terrace
    for (cx, cy) in [(316, 132), (348, 147), (318, 154)]:     # parks
        ellipse(cx, cy, 3.5, 2.2, "T", rng, 0.4, only=set("."))
    prop("castle_blue", 332, 130, 0.9, note="Frostveil palace", mod=[0.9, 0.97, 1.0])
    for (x, y) in [(302, 126), (362, 126), (301, 156), (362, 156), (323, 144), (339, 144), (325, 129), (339, 129)]:
        prop("tower", x, y, 0.6, mod=[0.9, 0.97, 1.0], note="spire")
    hk = ["house_blue", "house_blue", "house_purple", "house_yellow"]
    street_houses(ring, rng, hk, spacing=4.5, off=2.8, s=0.78, mod=[0.92, 0.97, 1.0])
    street_houses([(296, 141), (360, 141)], rng, hk, spacing=4.5, off=2.6, s=0.76, mod=[0.92, 0.97, 1.0])
    street_houses([(330, 146), (330, 157)], rng, hk, spacing=4.0, off=2.8, s=0.76, mod=[0.92, 0.97, 1.0])
    street_houses([(304, 128), (306, 155)], rng, hk, spacing=4.5, off=2.6, s=0.76, mod=[0.92, 0.97, 1.0])
    street_houses([(357, 128), (356, 155)], rng, hk, spacing=4.5, off=2.6, s=0.76, mod=[0.92, 0.97, 1.0])
    for (x, y) in [(327, 139), (335, 139), (327, 143), (335, 143), (329, 126), (332, 126)]:
        prop("fire", x, y, 0.42, note="hearth brazier")
    for (x, y) in [(325, 141), (337, 141)]:
        prop("deco17", x, y, 0.55, note="market stall sign")
    for (x, y, f) in [(326, 141, False), (336, 142, True), (329, 144, False), (333, 138, True), (309, 140, False), (352, 140, True),
                      (316, 141, False), (345, 141, True), (304, 135, False), (357, 148, True), (306, 150, False), (330, 153, True),
                      (318, 137, False), (346, 137, True), (312, 146, True), (350, 133, False)]:
        npc("pawn", x, y, f)
    for (x, y, f) in [(327, 124, False), (333, 124, True), (373, 139, True), (330, 157, False), (328, 133, False), (336, 133, True)]:
        npc("warrior", x, y, f)
    npc("archer", 302, 127)
    npc("archer", 362, 127, True)
    area("frostveil", [[x0, y0, x1, y1]], "snow", [330, 136],
         zones=[{"name": "Frostveil Bridge", "rects": [[x0, y0, x1, 119]], "style": "frostlake"}])


def build_terraces():
    rng = random.Random(302)
    x0, y0, x1, y1 = 378, 106, 445, 150
    rect(x0, y0, x1, y1, ".")
    border(x0, y0, x1, y1, "T", rng, th=2, extra=2, coast=3)
    # terraced gardens: stepped stone retaining walls with stairs, moon pools, hedges
    for k, ty in enumerate([114, 122, 130, 138]):        # curving retaining walls, stairs cut through
        for x in range(x0 + 3, x1 - 2):
            put(x, ty + int(round(1.4 * snoise(x, 150 + k, 0.08))), "#")
        for sx in ([388, 412, 432] if k % 2 == 0 else [398, 422, 440]):
            for x in range(sx, sx + 3):
                for y in range(ty - 3, ty + 4):
                    if get(x, y) == "#":
                        put(x, y, ",")
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
    # a round tower climbed as four ring galleries, each door on the opposite side of the last, sanctum at the core
    cx, cy = 428.5, 179
    for i in range(4):
        rx, ry = 15.5 - 3.6 * i, 25.5 - 5.2 * i
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                d = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
                di = ((x - cx) / (rx - 2)) ** 2 + ((y - cy) / (ry - 2)) ** 2
                if d <= 1.0 and di > 1.0:
                    put(x, y, ";" if i % 2 == 0 else ",")
        if i < 3:
            ddy = ry - 2.6 if i % 2 == 0 else -(ry - 2.6)
            rect(int(cx) - 1, int(cy + ddy) - 1, int(cx) + 1, int(cy + ddy) + 1, ",")
    ellipse(cx, cy, 3.5, 7, ",", rng, 0.0)
    rect(427, 152, 429, 156, ",")                     # entrance from the terraces (north)
    for (px, py) in [(cx - 11, cy - 12), (cx + 11, cy - 12), (cx - 11, cy + 12), (cx + 11, cy + 12)]:
        prop("deco17", px, py, 0.55, note="seeing-glass lamp")
    prop("tower_purple", cx, cy + 1, 0.8, note="Seer's Spire sanctum (Warden of Sights)")
    for (x, y) in [(cx, cy - 6), (cx, cy + 6), (416, 179), (441, 179), (420, 162), (437, 196)]:
        prop("fire", x, y, 0.45, note="scrying flame", mod=[0.8, 0.7, 1.0])
    area("seers_spire", [[x0, y0, x1, y1]], "spire", [428, 155])

def build_deepvault():
    rng = random.Random(304)
    x0, y0, x1, y1 = 378, 152, 409, 205
    rect(x0, y0, x1, y1, "#")
    # Deepvault Prison: gatehouse, guard hall, a crooked cell row, the oubliette, the warden's office and
    # the long stair down into the Molten Capital
    gate("g_deepvault_door", 392, 152, 396, 153)
    R = [(394, 157, 3, 2.5, "r", ","),     # 0 gatehouse
         (387, 162, 5, 2.5, "r", ","),     # 1 guard hall
         (402, 163, 4, 3, "o", ";"),       # 2 oubliette
         (384, 169, 4, 2, "r", ";"),       # 3 west cell row
         (397, 170, 6, 2, "r", ","),       # 4 east gallery
         (404, 174, 2.5, 2, "r", ","),     # 5 warden's office
         (391, 175, 2, 2, "o", ",")]       # 6 stair head
    rooms(R, [(0, 1), (0, 2), (1, 3), (1, 4), (2, 4), (4, 5), (3, 6), (4, 6)], rng, cw=2)
    rect(392, y0 + 2, 396, 155, ",")
    for x in range(381, 389, 2):                     # cell bars along the west row
        put(x, 167, "#"); put(x, 171, "#")
    for x in range(393, 403, 3):
        put(x, 172, "#")
    # Molten Capital: a fallen city in a lava cavern, broken streets on islands and stone causeways
    for x in range(x0 + 1, x1):
        top = 178 + int(round(1.5 * snoise(x, 71, 0.2)))
        for y in range(top, y1 - 1):
            put(x, y, "L")
    for (cx, cy, rx, ry) in [(388, 187, 5, 3.5), (402, 186, 4, 3), (392, 197, 6, 3.5), (382, 198, 3, 2.5), (404, 199, 3, 2.5)]:
        ellipse(cx, cy, rx, ry, ";", rng, 0.4)
    line([(391, 175), (391, 181), (388, 187)], 2, ",", over=set("#L;"))
    line([(388, 187), (402, 186)], 2, ",", over=set("L;"))
    line([(388, 187), (392, 197)], 2, ",", over=set("L;"))
    line([(402, 186), (404, 199), (392, 197)], 2, ",", over=set("L;"))
    line([(392, 197), (382, 198)], 2, ",", over=set("L;"))
    rect(391, 200, 396, 202, ",")                     # Warden of Embers' throne dais
    prop("castle_ruin", 388, 186, 0.5, note="fallen manor")
    prop("house_ruin", 402, 185, 0.7)
    prop("house_ruin", 382, 197, 0.6)
    prop("tower_ruin", 404, 198, 0.55)
    prop("castle_red", 393.5, 201, 0.55, note="Warden of Embers")
    for (x, y) in [(394, 157), (387, 162), (404, 174), (391, 175), (388, 190), (402, 189), (390, 199), (397, 199)]:
        prop("fire", x, y, 0.45)
    for (x, y) in [(383, 169), (402, 163), (399, 170), (386, 161)]:
        prop("deco16", x, y, 0.55, note="chains / bones")
    npc("warrior", 392, 158, False, note="gaoler")
    area("deepvault", [[x0, y0, x1, y1]], "prison", [394, 155],
         zones=[{"name": "Molten Capital", "rects": [[x0, 177, x1, y1]], "style": "molten"}])

def build_hoarfrost():
    rng = random.Random(305)
    x0, y0, x1, y1 = 290, 160, 375, 205
    rect(x0, y0, x1, y1, ".")
    border(x0, y0, x1, y1, "R", rng, th=3, extra=3, alt="T", coast=2)
    # icy pass: switchbacks between rock spurs, a glacier lake, snowfields with wild drifts
    for k, (a, b, c, d) in enumerate([(300, 166, 340, 168), (320, 176, 368, 178), (296, 186, 336, 188), (330, 194, 346, 196)]):
        for x in range(a + rng.randint(0, 3), c - rng.randint(0, 3)):
            yy = b + int(round(2.2 * snoise(x, 130 + k, 0.12)))
            t = 1 + (1 if snoise(x, 140 + k, 0.3) > 0.1 else 0)
            rect(x, yy, x, yy + t, "R")
        blobs(a, b - 2, c, d + 2, 4, 1, 2, "R", rng)          # boulders off the spurs
    ellipse(352, 168, 8, 4, "~", rng, 0.3)
    ellipse(352, 168, 5, 2.5, "_", rng, 0.2)
    blobs(x0 + 4, y0 + 4, x1 - 4, y1 - 4, 22, 2, 4.5, '"', rng)
    scatter(x0 + 4, y0 + 4, x1 - 4, y1 - 4, "T", 0.03, rng)
    line([(330, y0 - 1), (330, 164), (346, 172), (370, 172), (372, 182), (340, 182), (314, 182), (296, 180), (294, 192), (316, 192), (340, 200), (300, 200), (x0, 200)], 2, ":")
    gate("g_royal_ward_north", 288, 199, 291, 201)
    # Rime Cave: an ice cave under the pass with a frozen pool at the back
    cave(348, 185, 373, 199, [(360, 183), (362, 189), (354, 193), (366, 196), (370, 190)], rng, chambers=[(366, 196, 3, 1.5), (354, 193, 2.5, 1.5)])
    ellipse(366, 196, 1.5, 0.8, "_", rng, 0.0)
    prop("tower_ruin", 354, 192, 0.45, mod=[0.85, 0.95, 1.0], note="frozen shrine")
    prop("house_blue", 343, 171, 0.76, mod=[0.92, 0.97, 1.0], note="pass hut", clear=(3, 2))
    prop("fire", 346, 174, 0.45)
    npc("pawn", 341, 174, True, note="pass warden")
    prop("tower_ruin", 300, 190, 0.6, mod=[0.92, 0.97, 1.0])
    prop("deco17", 332, 165, 0.6, note="signpost")
    area("hoarfrost_pass", [[x0, y0, x1, y1]], "snow", [330, 162],
         zones=[{"name": "Rime Cave", "rects": [[348, 185, 373, 199]], "style": "icecave"}])


# =========================================================== Act IV: the Crownlands
def build_kingshold():
    rng = random.Random(401)
    x0, y0, x1, y1 = 150, 94, 288, 205
    rect(x0, y0, x1, y1, ".")
    border(x0, y0, x1, y1, "T", rng, th=2, extra=3, coast=4)
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
    # Crownfield: farming village and a millpond west of the royal road
    ellipse(170, 122, 7, 3.5, "~", rng, 0.3, only=set('."b'))
    line([(186, 110), (186, 104)], 2, ":")
    rect(178, 98, 196, 100, ":")
    for (x, y) in [(172, 97), (178, 97), (184, 97), (198, 102), (172, 108), (178, 108)]:
        prop(rng.choice(["house_yellow", "house_red"]), x, y, 0.78, rng.random() < 0.5, clear=(3, 2), note="Crownfield")
    prop("wtower", 162, 117, 0.5, note="millpond mill")
    for (x, y, f) in [(176, 101, False), (182, 102, True), (190, 100, False), (170, 112, True)]:
        npc("pawn", x, y, f)
    for (x, y) in [(158, 100), (162, 102), (166, 99)]:
        prop("deco18", x, y, 0.5, note="field scarecrow")
    # --- Kingshold Citadel (south-east): an oval curtain wall with bastions, a processional way to the inner
    # keep, barracks and chapel halls, bailey quarters along curved streets, fountains and a parade ground
    cx0, cy0, cx1, cy1 = 196, 132, 278, 196
    ccx, ccy, crx, cry = 237, 165, 39.5, 31
    rect(cx0, cy0, cx1, cy1, ".")
    for y in range(cy0, cy1 + 1):
        for x in range(cx0, cx1 + 1):
            d = ((x - ccx) / crx) ** 2 + ((y - ccy) / cry) ** 2
            if 0.88 <= d <= 1.0:
                put(x, y, "#")
    for (bx, by) in [(ccx - crx * 0.71, ccy - cry * 0.71), (ccx + crx * 0.71, ccy - cry * 0.71), (ccx - crx * 0.71, ccy + cry * 0.71),
                     (ccx + crx * 0.71, ccy + cry * 0.71), (ccx - crx, ccy), (ccx + crx, ccy)]:
        ellipse(bx, by, 2.6, 2.6, "#", rng, 0.0)               # bastions
        prop("tower", bx, by - 0.5, 0.7, note="citadel bastion", force=True)
    line([(220, 128), (221, 136), (229, 142), (237, 147)], 3, ",", over=set("#."))   # north gatehouse passage
    proc = wiggle([(237, 147), (237, 158), (237, 170)], rng, 0.4)
    line(proc, 3, ":")
    ellipse(237, 158, 6, 3.5, ",", rng, 0.0)                    # parade ground
    ellipse(237, 158, 1.6, 1.0, "~", rng, 0.0)
    inner = wiggle([(205, 165), (212, 152), (225, 143), (249, 143), (262, 152), (269, 165), (262, 178), (249, 188), (225, 188), (212, 178), (205, 165)], rng, 0.5)
    line(inner, 2, ":")                                          # bailey ring street
    line([(ccx - crx + 2, 171), (205, 167)], 2, ",", over=set("#."))   # west door into the garden
    rect(cx0, 170, cx0 + 3, 172, ",")
    line([(cx1, 183), (271, 181), (262, 178)], 2, ",", over=set("#."))  # east postern to the royal road
    # inner keep
    for y in range(170, 196):
        for x in range(222, 253):
            d = ((x - 237) / 13.5) ** 2 + ((y - 182) / 10) ** 2
            if d <= 1.0:
                put(x, y, "#" if d > 0.78 else ",")
    rect(235, 170, 239, 174, ",")
    # halls in the bailey: barracks (rubble, patrolled), chapel, armoury, granary
    R = [(213, 158, 4.5, 3, "r", ";"), (261, 158, 4.5, 3, "r", ";"), (216, 179, 4, 2.5, "r", ";"), (258, 179, 4, 2.5, "r", ","), (237, 150, 3, 1.5, "r", ",")]
    for (hx, hy, rx, ry, _, ch) in R:
        rect(int(hx - rx) - 1, int(hy - ry) - 1, int(hx + rx) + 1, int(hy + ry) + 1, "#")
        rect(int(hx - rx), int(hy - ry), int(hx + rx), int(hy + ry), ch)
        rect(int(hx) - 1, int(hy + ry) + 1, int(hx), int(hy + ry) + 1, ",")
        rect(int(hx) - 1, int(hy - ry) - 1, int(hx), int(hy - ry) - 1, ",")
    roughen(cx0, cy0, cx1, cy1, rng, p_out=0.05, p_in=0.02, floor=";")
    scatter(cx0 + 2, cy0 + 2, cx1 - 2, cy1 - 2, "b", 0.02, rng)
    for (fx, fy) in [(212, 168), (262, 168)]:
        ellipse(fx, fy, 2.2, 1.5, "~", rng, 0.0, only=set(".b"))
    prop("castle_blue", 237, 186, 1.0, note="the king's citadel (boss_kingshold)")
    for (x, y) in [(229, 181), (245, 181), (232, 176), (242, 176)]:
        prop("fire", x, y, 0.5, note="throne-hall brazier")
    for (x, y) in [(227, 186), (247, 186)]:
        prop("deco16", x, y, 0.6, note="royal banners")
    prop("tower", 228, 177, 0.55, note="keep tower")
    prop("tower", 246, 177, 0.55)
    prop("house_blue", 258, 178.5, 0.8, note="chapel", clear=(3, 2))
    prop("deco16", 237, 151, 0.6, note="drake sigil shrine")
    street_houses(inner, rng, ["house_blue", "house_yellow", "house_blue"], spacing=6.5, off=2.6, s=0.76, note="bailey quarters")
    for (x, y) in [(233, 156), (241, 156), (233, 160), (241, 160), (236, 168), (238, 168), (213, 156), (261, 156), (216, 179)]:
        prop("fire", x, y, 0.45)
    for (x, y, f) in [(220, 133, False), (223, 135, True), (235, 147, False), (239, 147, True), (236, 172, False), (239, 172, True)]:
        npc("warrior", x, y, f)
    for (x, y, f) in [(212, 168, False), (262, 174, True), (230, 143, False), (244, 143, True), (275, 182, True), (199, 171, False)]:
        npc("archer", x, y, f)
    for (x, y, f) in [(234, 158, False), (240, 158, True), (225, 188, False), (250, 188, True)]:
        npc("pawn", x, y, f)
    # --- Withered Royal Garden (south-west): dead hedges, dry fountains, the drake altar to the west
    gx0, gy0, gx1, gy1 = x0 + 2, 130, 194, y1 - 2
    rect(gx0, gy0, gx1, gy1, ".")
    blobs(gx0 + 2, gy0 + 2, gx1 - 2, gy1 - 2, 18, 2, 4, '"', rng)
    for k in range(6):                                   # overgrown hedge walks, bent and gapped
        hy = gy0 + 6 + k * 12
        for x in range(gx0 + 4, gx1 - 5):
            if snoise(x, 110 + k, 0.2) > 0.6:
                continue
            put(x, hy + int(round(1.6 * snoise(x, 120 + k, 0.1))), "b")
    for (hx, hy) in [(172, 150), (168, 176)]:            # dead hedge mazes around the old fountains
        for r in (5, 3.5):
            for y in range(int(hy - r) - 1, int(hy + r) + 2):
                for x in range(int(hx - r * 1.4) - 1, int(hx + r * 1.4) + 2):
                    d = ((x - hx) / (r * 1.4)) ** 2 + ((y - hy) / r) ** 2
                    if 0.8 <= d <= 1.0 and not (abs(x - hx) < 1.5 and (y > hy) == (r > 4)):
                        if get(x, y) in '."':
                            put(x, y, "b")
    for (cx, cy) in [(162, 150), (182, 174), (166, 192)]:
        ellipse(cx, cy, 2.5, 1.8, "~", rng, 0.2, only=set('."b'))
    scatter(gx0 + 2, gy0 + 2, gx1 - 2, gy1 - 2, "T", 0.025, rng, only='.')
    line([(cx0, 171), (180, 171), (172, 180), (x0 - 1, 180)], 2, ":")
    gate("g_drake_altar", x0 - 2, 179, x0 + 1, 181)
    line([(211.5, 128), (211.5, 130), (180, 130), (170, 140), (180, 160), (180, 171)], 2, ":")
    # Royal Crypt: catacombs under the garden, entered from the altar road
    cave(152, 186, 176, 202, [(168, 182), (166, 190), (158, 196), (170, 199), (174, 192)], rng, chambers=[(158, 196, 3, 2), (170, 199, 2.5, 1.5)])
    prop("castle_ruin", 159, 196, 0.4, note="royal tombs")
    prop("fire", 166, 189, 0.45)
    for (x, y) in [(172, 144), (186, 164)]:
        prop("tower_ruin", x, y, 0.55, note="dead gazebo")
    prop("castle_ruin", 160, 166, 0.55, note="old summer palace")
    # archive doors on the west road
    gate("g_archive_doors", x0 - 2, 103, x0 + 1, 105)
    area("kingshold", [[x0, y0, x1, y1]], "royal", [211, 96],
         zones=[{"name": "Kingshold Citadel", "rects": [[cx0, cy0, cx1, cy1]], "style": "citadel"},
                {"name": "Royal Crypt", "rects": [[152, 186, 176, 202]], "style": "catacomb"},
                {"name": "Withered Royal Garden", "rects": [[x0, 129, 195, y1]], "style": "withered"},
                {"name": "Kingshold Approach", "rects": [[x0, y0, x1, 131]]}])


def build_drakespire():
    rng = random.Random(402)
    x0, y0, x1, y1 = 96, 150, 148, 205
    rect(x0, y0, x1, y1, "R")
    rect(x0 + 2, y0 + 2, x1 - 2, y1 - 2, ".")
    border(x0 + 2, y0 + 2, x1 - 2, y1 - 2, "R", rng, th=1, extra=3, coast=0, corner=0)
    # a scorched mountain: ragged rock bands with switchback gaps, scree, lava seeps, the drake nest on top
    for k, by in enumerate([194, 184, 174, 164]):
        xa, xb = (x0 + 3, x1 - 12) if k % 2 == 0 else (x0 + 12, x1 - 2)
        for x in range(xa + rng.randint(0, 3), xb - rng.randint(0, 3)):
            if snoise(x, 70 + k, 0.25) > 0.75:
                continue                                  # scree gaps
            yy = by + int(round(3.0 * snoise(x, 80 + k, 0.12)))
            rect(x, yy, x, yy + 1 + (1 if snoise(x, 90 + k, 0.3) > 0.3 else 0), "#")
    blobs(x0 + 4, y0 + 4, x1 - 4, y1 - 4, 18, 1.5, 3, ";", rng)
    blobs(x0 + 4, y0 + 4, x1 - 4, y1 - 4, 7, 1.2, 2.4, "L", rng)
    scatter(x0 + 3, y0 + 3, x1 - 3, y1 - 3, "R", 0.035, rng)
    trail = wiggle([(x1 + 1, 180), (140, 180), (138, 190), (104, 189), (103, 179), (138, 178), (139, 169), (106, 168), (104, 158), (122, 156)], rng, 1.0, 4)
    line(trail, 2, ":")
    ellipse(122, 156, 5, 3, ",", rng, 0.3)
    ellipse(110, 199, 3, 2, ";", rng, 0.3)               # bone hollow
    prop("tower_ruin", 122, 155, 0.8, note="drake nest summit")
    prop("fire", 118, 157, 0.55)
    prop("fire", 126, 157, 0.55)
    prop("rocks4", 110, 199, 0.9, note="drake bones", mod=EMBER + [1.0])
    for (x, y) in [(132, 189), (110, 172), (136, 168), (116, 186), (128, 160)]:
        prop("deco16", x, y, 0.6)
    prop("deco17", 144, 181, 0.55, note="altar signpost")
    area("drakespire_peak", [[x0, y0, x1, y1]], "drake", [145, 180])

def build_archive():
    rng = random.Random(403)
    x0, y0, x1, y1 = 70, 94, 148, 148
    rect(x0, y0, x1, y1, "#")
    # Starfall Archive: an east vestibule, a domed reading hall, stack rooms of differing shapes, map and
    # orrery rooms, a scriptorium, a sunken star court open to the sky, and the west door to the Rift
    R = [(142, 104, 4, 2.5, "r", ","),     # 0 vestibule
         (124, 108, 8, 6, "o", ","),       # 1 domed reading hall
         (100, 104, 10, 5, "r", ","),      # 2 north stacks
         (80, 104, 6, 5, "o", ","),        # 3 map room
         (108, 132, 11, 8, "o", "."),      # 4 star court (open sky)
         (134, 128, 7, 5, "r", ","),       # 5 east stacks
         (136, 142, 6, 2.5, "r", ";"),     # 6 collapsed annex
         (84, 124, 6, 6, "r", ","),        # 7 scriptorium
         (82, 140, 7, 3.5, "o", ";"),      # 8 fallen-star crater
         (76, 122, 2.5, 2, "r", ","),      # 9 west door hall
         (106, 117, 3, 2, "o", ",")]       # 10 stair landing
    rooms(R, [(0, 1), (1, 2), (2, 3), (1, 10), (10, 4), (1, 5), (5, 6), (4, 5), (4, 8), (3, 7), (7, 9), (7, 4), (8, 7), (2, 10)], rng, cw=2)
    rect(x1 - 3, 103, x1, 105, ",")
    rect(x0, 121, x0 + 6, 123, ",")
    gate("g_rift_heart", x0 - 2, 121, x0 + 1, 123)
    shelves(92, 100, 108, 108, rng, vertical=True, gap=3)
    shelves(129, 124, 139, 132, rng, vertical=False, gap=3)
    shelves(80, 120, 88, 128, rng, vertical=True, gap=4)
    ellipse(108, 133, 3.5, 2.2, "~", rng, 0.0)
    blobs(98, 126, 118, 139, 5, 1, 2, '"', rng)
    ellipse(82, 140, 2, 1.2, "R", rng, 0.0, only=set(";"))
    roughen(x0, y0, x1, y1, rng, p_out=0.12, p_in=0.04, floor=",")
    for (x, y) in [(118, 103), (130, 103), (118, 113), (130, 113)]:
        prop("tower_purple", x, y, 0.45, note="reading-dome pillar")
    prop("castle_purple", 108, 128, 0.62, note="observatory (archive boss)")
    prop("wtower", 80, 103, 0.42, mod=[0.8, 0.8, 1.0], note="orrery")
    prop("rocks4", 82, 140, 0.9, mod=[0.75, 0.8, 1.0], note="fallen star")
    for (x, y) in [(124, 106), (100, 106), (84, 124), (134, 128), (108, 124), (142, 104), (76, 122)]:
        prop("fire", x, y, 0.42, note="star lamp", mod=[0.7, 0.8, 1.0])
    for (x, y) in [(96, 110), (126, 111), (88, 128), (138, 141)]:
        prop("deco16", x, y, 0.5, note="book pile")
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
    "cave": {"floor": [0.6, 0.5, 0.44], "wall": [0.62, 0.52, 0.46], "map": [0.4, 0.32, 0.28]},
    "icecave": {"floor": [0.78, 0.88, 0.96], "wall": [0.82, 0.92, 1.0], "snow": False, "map": [0.75, 0.85, 0.95]},
    "royal": {"grass": [0.96, 1.0, 0.86], "road": [1.0, 0.97, 0.9], "tree": [0.9, 1.0, 0.86], "map": [0.7, 0.7, 0.4]},
    "citadel": {"floor": [0.88, 0.87, 0.82], "wall": [0.92, 0.9, 0.86], "map": [0.8, 0.8, 0.7]},
    "withered": {"grass": [0.76, 0.7, 0.55], "overlay": [0.3, 0.24, 0.14, 0.28], "tree": [0.7, 0.6, 0.45], "wild": [0.8, 0.7, 0.5], "water": [0.32, 0.42, 0.38, 1.0], "map": [0.5, 0.45, 0.3]},
    "drake": {"grass": [0.7, 0.6, 0.55], "overlay": [0.2, 0.1, 0.08, 0.35], "rock": [0.85, 0.65, 0.55], "wall": [0.8, 0.6, 0.5], "floor": [0.7, 0.58, 0.52], "embers": True, "map": [0.45, 0.3, 0.25]},
    "archive": {"floor": [0.62, 0.64, 0.86], "wall": [0.64, 0.66, 0.9], "grass": [0.62, 0.66, 0.9], "overlay": [0.1, 0.1, 0.35, 0.28], "water": [0.2, 0.25, 0.5, 1.0], "map": [0.35, 0.35, 0.6]},
    "rift": {"grass": [0.76, 0.52, 0.9], "overlay": [0.35, 0.05, 0.4, 0.32], "floor": [0.72, 0.52, 0.86], "wall": [0.66, 0.46, 0.86], "water": [0.3, 0.12, 0.42, 1.0], "tree": [0.7, 0.5, 0.9], "wild": [0.86, 0.5, 1.0], "road": [0.85, 0.7, 0.95], "map": [0.5, 0.2, 0.55]},
    "riftsea": {"grass": [0.66, 0.5, 0.86], "overlay": [0.25, 0.05, 0.35, 0.35], "floor": [0.62, 0.48, 0.8], "water": [0.16, 0.06, 0.3, 1.0], "wild": [0.8, 0.5, 1.0], "road": [0.8, 0.66, 0.92], "map": [0.3, 0.1, 0.4]},
}


DETAIL = [
    # rect, outdoor deco set, deco density, tint, dungeon? (roughen + floor dressing + torches)
    ([204, 42, 219, 67], None, 0, None, (0.0, 0.005, 0.0)),
    ([232, 36, 275, 75], "ember", 0.03, None, None),
    ([232, 2, 345, 33], "redcap", 0.05, None, None),
    ([326, 3, 343, 22], None, 0, None, (0.15, 0.027, 0.06)),
    ([276, 36, 345, 65], "ember", 0.03, [1.0, 0.8, 0.6], None),
    ([276, 66, 345, 80], None, 0, None, (0.2, 0.017, 0.0)),
    ([290, 81, 335, 105], None, 0, None, (0.15, 0.02, 0.05)),
    ([346, 2, 405, 60], "fen", 0.045, [0.75, 0.85, 0.7], None),
    ([346, 62, 405, 105], None, 0, None, (0.14, 0.023, 0.08)),
    ([406, 30, 445, 105], "ember", 0.03, [0.8, 0.6, 0.5], None),
    ([290, 120, 375, 158], "snow", 0.02, [0.92, 0.97, 1.0], None),
    ([378, 106, 445, 150], "green", 0.05, [0.75, 0.75, 1.0], None),
    ([412, 152, 445, 205], None, 0, None, (0.08, 0.02, 0.05)),
    ([378, 152, 409, 205], None, 0, None, (0.12, 0.02, 0.05)),
    ([290, 160, 375, 205], "snow", 0.025, [0.9, 0.96, 1.0], None),
    ([348, 185, 373, 199], None, 0, None, (0.15, 0.017, 0.04)),
    ([150, 94, 288, 131], "green", 0.04, None, None),
    ([150, 129, 195, 205], "fen", 0.04, [0.8, 0.7, 0.55], None),
    ([196, 132, 278, 196], "green", 0.02, None, (0.1, 0.017, 0.05)),
    ([152, 186, 176, 202], None, 0, None, (0.15, 0.027, 0.06)),
    ([96, 150, 148, 205], "ember", 0.03, [0.85, 0.65, 0.55], None),
    ([70, 94, 148, 148], None, 0, None, (0.1, 0.017, 0.06)),
    ([4, 94, 68, 148], "rift", 0.05, [0.9, 0.7, 1.0], None),
    ([4, 150, 94, 205], "rift", 0.05, [0.85, 0.65, 1.0], None),
]


def detail_pass():
    rng = random.Random(777)
    for (q, deco, dens, mod, dun) in DETAIL:
        x0, y0, x1, y1 = q
        if dun:
            rough, fd, tor = dun
            if rough:
                roughen(x0, y0, x1, y1, rng, p_out=rough, p_in=rough * 0.4)
            decorate(x0, y0, x1, y1, rng, "green", 0.0, None, floor_dens=fd, torches=tor)
        if deco:
            decorate(x0, y0, x1, y1, rng, deco, dens, mod)


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


def area_at(x, y):
    for aid, a in AREAS.items():
        for (a0, b0, a1, b1) in a["rects"]:
            if a0 <= x <= a1 and b0 <= y <= b1:
                return aid
    return None


def connect_islands():
    """Every walkable pocket must be reachable (gates open): tunnel/bridge the nearest way to the main walk."""
    from collections import deque
    BL = set("~TR#L")
    small = set()
    for _ in range(60):
        st = tuple(tiles1["start"])
        seen = {st}; dq = deque([st])
        while dq:
            x, y = dq.popleft()
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = (x + dx, y + dy)
                if n not in seen and 0 <= n[0] < W and 0 <= n[1] < H and get(*n) not in BL:
                    seen.add(n); dq.append(n)
        orphan = None
        for y in range(H):
            for x in range(W):
                if (x < A1W and y < A1H) or get(x, y) in BL or (x, y) in seen or (x, y) in small:
                    continue
                comp = {(x, y)}; q = deque([(x, y)])
                while q:
                    cx, cy = q.popleft()
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        n = (cx + dx, cy + dy)
                        if n not in comp and 0 <= n[0] < W and 0 <= n[1] < H and get(*n) not in BL:
                            comp.add(n); q.append(n)
                if len(comp) < 12:
                    small |= comp; continue
                orphan = (x, y); break
            if orphan: break
        if not orphan:
            return
        ox, oy = orphan
        if _ > 50: print("orphan", orphan, get(ox, oy))
        oa = area_at(ox, oy)
        best = min((t for t in seen if (not (t[0] < A1W and t[1] < A1H) or (t in EDIT_OK)) and area_at(*t) == oa), key=lambda t: abs(t[0] - ox) + abs(t[1] - oy))
        bx, by = best
        inside = get(ox, oy) in ",;" or get(bx, by) in ",;"
        x, y = ox, oy
        path = []
        while x != bx:
            x += 1 if bx > x else -1; path.append((x, y))
        while y != by:
            y += 1 if by > y else -1; path.append((x, y))
        for (px, py) in path:
            for (qx, qy) in ((px, py), (px + 1, py), (px, py + 1)):
                c = get(qx, qy)
                if c in "~L":
                    put(qx, qy, "=")
                elif c in "#TR":
                    put(qx, qy, ";" if inside else ":")
    raise SystemExit("connect_islands did not converge")


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
    detail_pass()
    connect_islands()
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
