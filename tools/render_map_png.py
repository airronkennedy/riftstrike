#!/usr/bin/env python3
"""Quick top-down preview of data/world_map.txt (4px per tile) with area outlines and props."""
import json, os, sys
from PIL import Image, ImageDraw
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
rows = open(os.path.join(ROOT, "data/world_map.txt")).read().rstrip("\n").split("\n")
t = json.load(open(os.path.join(ROOT, "data/world_tiles.json")))
C = {"~": (47, 127, 140), ".": (127, 176, 74), '"': (63, 138, 46), ":": (230, 207, 134), "T": (44, 90, 42), "R": (125, 123, 120),
     "b": (100, 150, 60), "X": (210, 58, 42), "=": (154, 106, 58), ",": (169, 167, 162), ";": (140, 133, 122), "#": (74, 79, 88),
     "L": (224, 86, 28), "_": (223, 242, 251)}
S = int(sys.argv[2]) if len(sys.argv) > 2 else 4
H, W = len(rows), max(len(r) for r in rows)
im = Image.new("RGB", (W * S, H * S), C["~"])
d = ImageDraw.Draw(im)
for y, r in enumerate(rows):
    for x, ch in enumerate(r):
        d.rectangle([x * S, y * S, x * S + S - 1, y * S + S - 1], fill=C.get(ch, (255, 0, 255)))
for a in t["areas"]:
    for q in a["rects"]:
        d.rectangle([q[0] * S, q[1] * S, (q[2] + 1) * S - 1, (q[3] + 1) * S - 1], outline=(255, 255, 255))
    q = a["rects"][0]
    d.text((q[0] * S + 3, q[1] * S + 3), a["id"], fill=(255, 255, 0))
for p in t["props"]:
    d.ellipse([p["x"] * S - 2, p["y"] * S - 2, p["x"] * S + 2, p["y"] * S + 2], fill=(255, 40, 200))
im.save(sys.argv[1] if len(sys.argv) > 1 else "/tmp/map.png")
