#!/usr/bin/env python3
"""Tile-level connectivity check for data/world_map.txt + world_tiles.json (props ignored; see test_world.gd for props)."""
import json, os, sys
from collections import deque
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
rows = open(os.path.join(ROOT, "data/world_map.txt")).read().rstrip("\n").split("\n")
t = json.load(open(os.path.join(ROOT, "data/world_tiles.json")))
H, W = len(rows), max(len(r) for r in rows)
def ch(x, y): return rows[y][x] if 0 <= y < H and 0 <= x < len(rows[y]) else "~"
amap = {}
for a in t["areas"]:
    for q in a["rects"]:
        for y in range(q[1], q[3] + 1):
            for x in range(q[0], q[2] + 1):
                amap.setdefault((x, y), a["id"])
gmap = {}
for g in t["gates"]:
    for q in g["rects"]:
        for y in range(q[1], q[3] + 1):
            for x in range(q[0], q[2] + 1):
                gmap[(x, y)] = g["id"]
BLOCK = set("~TR#L")
def bfs(open_gates):
    s = tuple(t["start"]); seen = {s}; dq = deque([s]); hit = {}
    while dq:
        x, y = dq.popleft()
        a = amap.get((x, y), "")
        hit[a] = hit.get(a, 0) + 1
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (x + dx, y + dy); c = ch(*n)
            if n in seen or c in BLOCK: continue
            if c == "X" and gmap.get(n) not in open_gates: continue
            seen.add(n); dq.append(n)
    return hit, seen
allg = {g["id"] for g in t["gates"]}
hit, seen = bfs(allg)
ids = [a["id"] for a in t["areas"]]
print("reachable with all gates open:", len([i for i in ids if i in hit]), "/", len(ids))
print("missing:", [i for i in ids if i not in hit])
print("walkable tiles outside any area:", hit.get("", 0))
h2, _ = bfs(set())
print("gates closed:", sorted(k for k in h2 if k))
# per-area walkable tiles not reachable (islands)
tot = {}
for (x, y), a in amap.items():
    if ch(x, y) not in BLOCK: tot[a] = tot.get(a, 0) + 1
for a in ids:
    print(f"  {a:20s} reach {hit.get(a,0):6d} / walk {tot.get(a,0):6d}")
# stray gate tiles without a rect
for y in range(H):
    for x in range(W):
        if ch(x, y) == "X" and (x, y) not in gmap: print("X without gate rect", x, y)
# components (gates open)
comp = {}; cid = 0
for (x0, y0), a in amap.items():
    if (x0, y0) in comp or ch(x0, y0) in BLOCK: continue
    cid += 1; dq = deque([(x0, y0)]); comp[(x0, y0)] = cid
    while dq:
        x, y = dq.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (x + dx, y + dy)
            if n in comp or ch(*n) in BLOCK: continue
            comp[n] = cid; dq.append(n)
big = {}
for k, c in comp.items():
    a = amap.get(k, "")
    big.setdefault(c, {}).setdefault(a, 0); big[c][a] += 1
for c, d in sorted(big.items(), key=lambda kv: -sum(kv[1].values())):
    if sum(d.values()) >= 30 and ("-v" in sys.argv or len(d) > 0):
        print("component", c, {k: v for k, v in d.items()})
if "-where" in sys.argv:
    out = [k for k, c in comp.items() if amap.get(k, "") == ""]
    print("outside:", sorted(out)[:40])
    for c, d in big.items():
        ks = [k for k, cc in comp.items() if cc == c]
        if 30 <= len(ks) < 2000:
            xs = [k[0] for k in ks]; ys = [k[1] for k in ks]
            print("comp", c, d, "bbox", min(xs), min(ys), max(xs), max(ys))
# area adjacency vs world.json links
wj = json.load(open(os.path.join(ROOT, "data/world.json")))
pairs = {}
for (x, y), a in amap.items():
    if ch(x, y) in BLOCK: continue
    for dx, dy in ((1, 0), (0, 1)):
        n = (x + dx, y + dy); b = amap.get(n)
        if b and b != a and ch(*n) not in BLOCK:
            k = tuple(sorted((a, b)))
            g = gmap.get((x, y)) or gmap.get(n) or ""
            pairs.setdefault(k, set()).add(g)
want = {tuple(sorted((l["from"], l["to"]))): l["gate"] for l in wj["links"]}
for k, gs in sorted(pairs.items()):
    tag = "OK " if k in want else "EXTRA"
    print(tag, k, sorted(gs), "want gate:", want.get(k))
for k in want:
    if k not in pairs: print("MISSING link", k, want[k])
