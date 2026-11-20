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


def label(d):
    """8-connected labels of a boolean mask (plain numpy + a stack flood fill). Returns (labels, count)."""
    lab = np.zeros(d.shape, np.int32)
    h, w = d.shape
    cur = 0
    for sy, sx in zip(*np.where(d)):
        if lab[sy, sx]:
            continue
        cur += 1
        stack = [(sy, sx)]; lab[sy, sx] = cur
        while stack:
            y, x = stack.pop()
            for yy in (y - 1, y, y + 1):
                for xx in (x - 1, x, x + 1):
                    if 0 <= yy < h and 0 <= xx < w and d[yy, xx] and not lab[yy, xx]:
                        lab[yy, xx] = cur; stack.append((yy, xx))
    return lab, cur


def own_mask(win, m, inner, px, min_frac=0.004):
    """Keep the blobs that belong to this cell: label the key mask at 1/px scale (grown a little so a sprite's
    loose parts join up), then keep every blob whose centre lies inside the cell proper (`inner` = y0, y1, x0, x1
    in window coords). Parts that spill past the cell line are kept whole; neighbours' slivers are dropped.
    `min_frac`: smallest kept blob relative to the biggest (details like pebbles / flowers keep their loose bits;
    props and buildings drop stray specks and the odd extra object the generator put in the cell)."""
    h, w = m.shape
    hs, ws = h // px, w // px
    small = m[:hs * px, :ws * px].reshape(hs, px, ws, px).any(axis=(1, 3))
    g = small.copy()
    for _ in range(2):
        e = g.copy()
        e[1:] |= g[:-1]; e[:-1] |= g[1:]; e[:, 1:] |= g[:, :-1]; e[:, :-1] |= g[:, 1:]
        g = e
    lab, n = label(g)
    keep = np.zeros_like(g)
    sizes = [(lab == i).sum() for i in range(1, n + 1)]
    big = max(sizes) if sizes else 0
    iy0, iy1, ix0, ix1 = [v / px for v in inner]
    for i in range(1, n + 1):
        ys, xs = np.where(lab == i)
        cy, cx = ys.mean(), xs.mean()
        if iy0 <= cy < iy1 and ix0 <= cx < ix1 and sizes[i - 1] >= big * min_frac:
            keep |= lab == i
    full = np.zeros_like(m)
    full[:hs * px, :ws * px] = np.repeat(np.repeat(keep, px, 0), px, 1)
    return m & full


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
            # Window = the cell plus a 14% margin so sprites that overflow their cell are not cropped;
            # own_mask() then drops whatever belongs to the neighbouring cells.
            mx, my = int(cw * 0.14), int(ch * 0.14)
            X0, Y0 = max(0, int(cx * cw) - mx), max(0, int(cy * ch) - my)
            X1, Y1 = min(w, int((cx + 1) * cw) + mx), min(h, int((cy + 1) * ch) + my)
            cell = im[Y0:Y1, X0:X1]
            m = key_mask(cell, bg)
            frac = 0.5 if name == "log" else (0.004 if fn == "sheet-details.jpg" else 0.2)
            m = own_mask(cell, m, (int(cy * ch) - Y0, int((cy + 1) * ch) - Y0, int(cx * cw) - X0, int((cx + 1) * cw) - X0), px, frac)
            ys, xs = np.where(m)
            if len(xs) == 0:
                print("empty", name); continue
            y1, y2, x1, x2 = ys.min(), ys.max(), xs.min(), xs.max()
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
