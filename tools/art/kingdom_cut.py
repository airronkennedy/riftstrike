#!/usr/bin/env python3
"""Cut the Grok-generated kingdom sheets (art-src/kingdom/raw/*.jpg) into game sprites in assets/kingdom/.

Each sheet is a clean grid on a flat magenta key. Per cell: chroma-key the magenta, despill the edges, crop to the
sprite, then downsample by the sheet's pixel size (median of each block) to a native pixel-art sprite that the game
draws at 2x nearest, the same density as the rest of the kingdom art. Run: python3 tools/art/kingdom_cut.py
Then re-attach provenance: tools/art/kingdom_c2pa.sh (parent = the raw sheet).
"""
import os
import numpy as np
from PIL import Image

RAW = "art-src/kingdom/raw"
OUT = "assets/kingdom"
SHEETS = {
    "sheet-props.jpg": (4, 4, 3, [
        "tree_oak", "tree_pine", "tree_willow", "bush",
        "shrine", "cave_mouth", "ruin", "cairn",
        "well", "market_stall", "fence", "throne",
        "pillar", "banner", "brazier", "barrels"]),
    "sheet-buildings.jpg": (3, 3, 3, [
        "bld_store", "bld_inn", "bld_cottage",
        "bld_townhouse", "bld_smithy", "bld_chapel",
        "bld_gatehouse", "bld_tower", "bld_farmhouse"]),
    "sheet-details.jpg": (4, 4, 3, [
        "tuft_tall", "tuft_short", "flowers_white", "flowers_blue",
        "flowers_red", "pebbles", "boulder", "mushrooms",
        "log", "stump", "reeds", "lilypad",
        "lamp_post", "signpost", "hay_bale", "planter"]),
    "sheet-castle.jpg": (4, 3, 3, [
        "window_stained", "sconce", "armor_stand", "candelabra",
        "banquet_table", "bookshelf", "knight_statue", "urn_plant",
        "rug_round", "stairs", "chandelier", "weapon_rack"]),
}


def key_mask(a, bg):
    d = np.sqrt(((a[..., :3].astype(np.float32) - bg) ** 2).sum(-1))
    r, g, b = a[..., 0].astype(int), a[..., 1].astype(int), a[..., 2].astype(int)
    magenta = (r - g > 55) & (b - g > 25)
    return (d > 90) & ~magenta


def biggest_blob(m, grow=4):
    """Mask of the largest 8-connected blob after growing the mask by `grow` px (plain numpy + a flood fill)."""
    d = m.copy()
    for _ in range(grow):
        e = d.copy()
        e[1:] |= d[:-1]; e[:-1] |= d[1:]; e[:, 1:] |= d[:, :-1]; e[:, :-1] |= d[:, 1:]
        d = e
    lab = np.zeros(d.shape, np.int32)
    h, w = d.shape
    best, best_n, cur = 0, 0, 0
    for sy, sx in zip(*np.where(d)):
        if lab[sy, sx]:
            continue
        cur += 1
        stack = [(sy, sx)]; lab[sy, sx] = cur; n = 0
        while stack:
            y, x = stack.pop(); n += 1
            for yy in (y - 1, y, y + 1):
                for xx in (x - 1, x, x + 1):
                    if 0 <= yy < h and 0 <= xx < w and d[yy, xx] and not lab[yy, xx]:
                        lab[yy, xx] = cur; stack.append((yy, xx))
        if n > best_n:
            best, best_n = cur, n
    return (lab == best) if best else None


def outline(a, col=(26, 18, 16)):
    """Clean the key edge: darken any leftover pink edge pixel, then add a 1 px dark outline (Airron's Fall style)."""
    op = a[..., 3] > 0
    r, g, b = a[..., 0].astype(int), a[..., 1].astype(int), a[..., 2].astype(int)
    pink = op & (r - g > 40) & (b - g > 15)
    edge = op & ~(np.roll(op, 1, 0) & np.roll(op, -1, 0) & np.roll(op, 1, 1) & np.roll(op, -1, 1))
    a[pink & edge, :3] = col
    grow = op | np.roll(op, 1, 0) | np.roll(op, -1, 0) | np.roll(op, 1, 1) | np.roll(op, -1, 1)
    ring = grow & ~op
    ring[0, :] = ring[-1, :] = False
    ring[:, 0] = ring[:, -1] = False
    a[ring, :3] = col
    a[ring, 3] = 255
    return a


def main():
    os.makedirs(OUT, exist_ok=True)
    for fn, (cols, rows, px, names) in SHEETS.items():
        im = np.array(Image.open(os.path.join(RAW, fn)).convert("RGB"))
        h, w = im.shape[:2]
        bg = np.median(np.concatenate([im[:6, :6].reshape(-1, 3), im[-6:, -6:].reshape(-1, 3)]), axis=0)
        cw, ch = w / cols, h / rows
        for i, name in enumerate(names):
            cx, cy = i % cols, i // cols
            x0, y0 = int(cx * cw) + 2, int(cy * ch) + 2
            cell = im[y0:int((cy + 1) * ch) - 2, x0:int((cx + 1) * cw) - 2]
            m = key_mask(cell, bg)
            # keep only reasonably large blobs' bounding box (ignores stray specks near cell edges)
            ys, xs = np.where(m)
            if len(xs) == 0:
                print("empty", name); continue
            y1, y2 = np.percentile(ys, [0.2, 99.8]).astype(int)
            x1, x2 = np.percentile(xs, [0.2, 99.8]).astype(int)
            y1, x1 = max(0, y1 - 2), max(0, x1 - 2)
            sub = cell[y1:y2 + 3, x1:x2 + 3]
            sm = m[y1:y2 + 3, x1:x2 + 3]
            # despill: pull magenta tint out of edge pixels
            s = sub.astype(np.float32)
            spill = np.clip((s[..., 0] + s[..., 2]) / 2 - s[..., 1] - 60, 0, None) * 0.5
            s[..., 0] -= spill; s[..., 2] -= spill
            sub = np.clip(s, 0, 255).astype(np.uint8)
            hh, ww = sub.shape[0] // px, sub.shape[1] // px
            out = np.zeros((hh + 2, ww + 2, 4), np.uint8)
            for yy in range(hh):
                for xx in range(ww):
                    blk = sub[yy * px:(yy + 1) * px, xx * px:(xx + 1) * px].reshape(-1, 3)
                    bm = sm[yy * px:(yy + 1) * px, xx * px:(xx + 1) * px].reshape(-1)
                    if bm.mean() >= 0.5:
                        out[yy + 1, xx + 1, :3] = np.median(blk[bm], axis=0)
                        out[yy + 1, xx + 1, 3] = 255
            out = outline(out)
            Image.fromarray(out, "RGBA").save(os.path.join(OUT, name + ".png"), optimize=True)
            print(name, out.shape[1], "x", out.shape[0])


if __name__ == "__main__":
    main()
