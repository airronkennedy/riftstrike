#!/usr/bin/env python3
"""Build Airron's Quest art from Airron's Fall (Airron Kennedy's own game art).

Copies the Airron's Fall sprites, area art, icons, title art, fonts and music into assets/af/,
and generates the atlases the engine draws (terrain, props, buildings, VFX, UI frames) from
that art or procedurally, keeping the old atlas layouts so the drawing code stays the same.
Usage: python3 tools/build_af_assets.py [path/to/arena-survival-game]
"""
import math, os, random, shutil, sys
from PIL import Image, ImageDraw, ImageFilter, ImageEnhance, ImageChops

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AF = sys.argv[1] if len(sys.argv) > 1 else "/workspace/arena-survival-game"
PUB = os.path.join(AF, "artifacts/emberfall-arena/public")
SRC = os.path.join(AF, "artifacts/emberfall-arena/src/assets")
OUT = os.path.join(ROOT, "assets/af")
random.seed(7)

def out(*p):
    path = os.path.join(OUT, *p)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    return path

def rgba(path):
    return Image.open(path).convert("RGBA")

# ------------------------------------------------------------------ straight copies
def copy_tree(src, dst, exts=(".png",)):
    for f in sorted(os.listdir(src)):
        if f.lower().endswith(exts):
            shutil.copy(os.path.join(src, f), out(dst, f))

copy_tree(f"{PUB}/assets/heroes", "heroes")
copy_tree(f"{PUB}/assets/foes", "foes")
copy_tree(f"{PUB}/assets/areas", "areas")
copy_tree(f"{PUB}/assets/icons", "icons")
for webp, name in [("ashling.webp", "foe-ashling.png"), ("ash-brute.webp", "foe-brute.png"), ("ash-elite.webp", "foe-elite.png")]:
    rgba(f"{PUB}/assets/{webp}").save(out("foes", name))
shutil.copy(f"{PUB}/assets/final-boss.png", out("foes", "foe-sovereign.png"))
shutil.copy(f"{PUB}/assets/ember-chest.png", out("props", "ember-chest.png"))
shutil.copy(f"{PUB}/icon-192.png", out("ui", "icon-192.png"))
shutil.copy(f"{PUB}/icon-512.png", out("ui", "icon-512.png"))
for f in ["title-keyart-wide.jpg", "title-keyart-tall.jpg"]:
    shutil.copy(f"{SRC}/title/{f}", out("ui", f))
for f in ["death-backdrop.jpg", "victory-backdrop.jpg"]:
    shutil.copy(f"{SRC}/screens/{f}", out("ui", f))
shutil.copy(f"{PUB}/assets/run-theme.mp3", out("audio", "run-theme.mp3"))
shutil.copy(f"{PUB}/favicon.svg", out("ui", "favicon.svg"))
# Every Airron's Fall font goes into fonts/ (the game draws with Cinzel 700 and Rajdhani 600/700).
for f in sorted(os.listdir(f"{SRC}/fonts")):
    if f.endswith(".woff2"):
        shutil.copy(f"{SRC}/fonts/{f}", os.path.join(ROOT, "fonts", f))

# ------------------------------------------------------------------ silhouettes (selection outline + hit flash)
def silhouettes(src_png, key):
    im = rgba(src_png)
    a = im.getchannel("A")
    for name, col in [("white", (255, 255, 255)), ("cyan", (110, 238, 255))]:
        s = Image.new("RGBA", im.size, col + (0,))
        s.putalpha(a)
        s.save(out("sil", f"{key}_{name}.png"))

for f in sorted(x for x in os.listdir(OUT + "/heroes") if x.endswith(".png")):
    silhouettes(f"{OUT}/heroes/{f}", "h_" + f[:-4])
for f in sorted(x for x in os.listdir(OUT + "/foes") if x.endswith(".png")):
    silhouettes(f"{OUT}/foes/{f}", "f_" + f[4:-4])

# ------------------------------------------------------------------ helpers
PROPS = rgba(f"{PUB}/assets/areas/area-props.png")  # 3 x 10 grid of 40px props
def prop(col, row):
    return PROPS.crop((col * 40, row * 40, col * 40 + 40, row * 40 + 40))

def fit(im, w, h, scale=1.0, anchor="bottom"):
    c = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    s = min(w / im.width, h / im.height) * scale
    r = im.resize((max(1, int(im.width * s)), max(1, int(im.height * s))), Image.NEAREST)
    x = (w - r.width) // 2
    y = h - r.height - int(h * 0.06) if anchor == "bottom" else (h - r.height) // 2
    c.alpha_composite(r, (x, y))
    return c

def ground(name, size=64, dark=1.0):
    g = Image.open(f"{PUB}/assets/areas/area-{name}-ground.png").convert("RGBA")
    g = g.crop((16, 16, 16 + size, 16 + size)) if size <= 80 else g.resize((size, size), Image.NEAREST)
    if dark != 1.0:
        g = ImageEnhance.Brightness(g).enhance(dark)
    return g

def edge_shade(tile, ex, ey, rim=(20, 14, 10)):
    """Autotile edge: ex/ey 0=open on low side, 1=middle, 2=open on high side, 3=isolated."""
    t = tile.copy()
    d = ImageDraw.Draw(t)
    w, h = t.size
    mask = Image.new("L", (w, h), 255)
    md = ImageDraw.Draw(mask)
    left = ex in (0, 3); right = ex in (2, 3); top = ey in (0, 3); bot = ey in (2, 3)
    x0 = 6 if left else 0; x1 = w - 6 if right else w; y0 = 6 if top else 0; y1 = h - 6 if bot else h
    md.rectangle((0, 0, w, h), fill=0)
    md.rounded_rectangle((x0, y0, x1 - 1, y1 - 1), radius=10 if (left or right or top or bot) else 0, fill=255)
    t.putalpha(ImageChops.multiply(t.getchannel("A"), mask))
    # dark rim
    rimimg = Image.new("RGBA", (w, h), rim + (0,))
    rd = ImageDraw.Draw(rimimg)
    if left or right or top or bot:
        rd.rounded_rectangle((x0, y0, x1 - 1, y1 - 1), radius=10, outline=rim + (200,), width=3)
        rimimg.putalpha(ImageChops.multiply(rimimg.getchannel("A"), mask))
        t.alpha_composite(rimimg)
    return t

# ------------------------------------------------------------------ terrain: flat tilemap (640x256)
flat = Image.new("RGBA", (640, 256), (0, 0, 0, 0))
grass = ground("stillmoss-cloister")
sand = ground("tollstone-quarry")
for ey in range(4):
    for ex in range(4):
        flat.alpha_composite(edge_shade(grass, ex, ey), (ex * 64, ey * 64))
        flat.alpha_composite(edge_shade(sand, ex, ey, rim=(40, 26, 14)), (320 + ex * 64, ey * 64))
flat.save(out("gen", "tilemap_flat.png"))

# elevation: rows 0-2 plateau top (3x3 + col 3 single), row 3 cliff face
elev = Image.new("RGBA", (256, 512), (0, 0, 0, 0))
stone = ground("unlit-throne", dark=1.15)
for ey in range(3):
    for ex in range(4):
        elev.alpha_composite(edge_shade(stone, ex, ey if ey < 3 else 3), (ex * 64, ey * 64))
cliff = ImageEnhance.Brightness(ground("coalvein-deeps")).enhance(0.55)
for ex in range(4):
    c = cliff.copy(); d = ImageDraw.Draw(c)
    for k in range(4):
        d.line((0, 14 + k * 14, 64, 14 + k * 14), fill=(10, 8, 8, 140), width=2)
    elev.alpha_composite(edge_shade(c, ex, 1), (ex * 64, 192))
elev.save(out("gen", "tilemap_elevation.png"))

# coast glow ring (8 frames of 192, tile in the middle)
foam = Image.new("RGBA", (1536, 192), (0, 0, 0, 0))
for f in range(8):
    fr = Image.new("RGBA", (192, 192), (0, 0, 0, 0)); d = ImageDraw.Draw(fr)
    grow = 4 + 3 * math.sin(f / 8 * math.tau)
    d.rounded_rectangle((64 - 10 - grow, 64 - 10 - grow, 128 + 10 + grow, 128 + 10 + grow), radius=22, fill=(150, 205, 190, 90))
    d.rounded_rectangle((64 - 4, 64 - 4, 128 + 4, 128 + 4), radius=14, fill=(210, 235, 220, 140))
    foam.alpha_composite(fr.filter(ImageFilter.GaussianBlur(2)), (f * 192, 0))
foam.save(out("gen", "coast_glow.png"))

# bridge planks (192x256): row 0 horizontal (3), col 0 rows 1-3 vertical
bridge = Image.new("RGBA", (192, 256), (0, 0, 0, 0)); d = ImageDraw.Draw(bridge)
def planks(x, y, vertical):
    for k in range(5):
        if vertical:
            d.rectangle((x + 6, y + k * 13, x + 58, y + k * 13 + 10), fill=(92, 62, 40, 255), outline=(40, 26, 16, 255))
        else:
            d.rectangle((x + k * 13, y + 6, x + k * 13 + 10, y + 58), fill=(92, 62, 40, 255), outline=(40, 26, 16, 255))
for i in range(3): planks(i * 64, 0, False)
for i in range(1, 4): planks(0, i * 64, True)
bridge.save(out("gen", "bridge.png"))

# ------------------------------------------------------------------ props from the Airron's Fall prop sheet
# deco ids keep the old meaning (10/11 grass tufts, 07-09 bushes, 04/06/15 rubble, 16-18 big props)
DECO = {
    "01": (0, 6), "02": (1, 3), "03": (0, 3), "04": (0, 2), "05": (2, 4), "06": (2, 2), "07": (2, 6),
    "08": (1, 4), "09": (2, 3), "10": (1, 1), "11": (2, 6), "12": (0, 8), "13": (1, 7), "14": (2, 7),
    "15": (1, 9), "16": (0, 9), "17": (0, 4), "18": (1, 6),
}
SIZES = {"16": (64, 128), "17": (128, 128), "18": (192, 192)}
for k, (c, r) in DECO.items():
    w, h = SIZES.get(k, (64, 64))
    fit(prop(c, r), w, h, 0.9).save(out("gen", f"deco_{k}.png"))

# animated 128px strips (8 frames): rocks / shoals
for i, (c, r) in enumerate([(0, 2), (2, 1), (0, 5), (0, 9)], start=1):
    strip = Image.new("RGBA", (1024, 128), (0, 0, 0, 0))
    base = fit(prop(c, r), 128, 128, 0.62, anchor="center")
    for f in range(8):
        strip.alpha_composite(base, (f * 128, int(2 * math.sin(f / 8 * math.tau))))
    strip.save(out("gen", f"rocks_{i}.png"))

# trees: 4 cols x 3 rows of 192 (sway frames), from the dead-tree prop
tree = Image.new("RGBA", (768, 576), (0, 0, 0, 0))
tbase = fit(prop(0, 4), 192, 192, 1.0)
for row in range(3):
    for f in range(4):
        sk = (f - 1.5) * 0.015
        t = tbase.transform(tbase.size, Image.AFFINE, (1, sk, -sk * 180, 0, 1, 0), Image.NEAREST)
        tree.alpha_composite(t, (f * 192, row * 192))
tree.save(out("gen", "tree.png"))

# wandering ember mote (8 frames of 128) in place of the old sheep
mote = rgba(f"{PUB}/assets/foes/foe-mote.png")
motes = Image.new("RGBA", (1024, 128), (0, 0, 0, 0))
for f in range(8):
    motes.alpha_composite(fit(mote, 128, 128, 0.5), (f * 128, int(-4 * abs(math.sin(f / 8 * math.pi)))))
motes.save(out("gen", "mote_idle.png"))

# ------------------------------------------------------------------ buildings (drawn here in the Airron's Fall palette)
def building(w, h, kind, accent, ruined=False):
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    stone = (78, 70, 66, 255); dark = (34, 28, 26, 255); roof = (52, 38, 44, 255)
    glow = accent + (255,)
    if kind == "house":
        d.rectangle((14, h * 0.45, w - 14, h - 10), fill=stone, outline=dark, width=3)
        d.polygon([(6, h * 0.47), (w / 2, h * 0.12), (w - 6, h * 0.47)], fill=roof, outline=dark)
        d.rectangle((w / 2 - 12, h - 44, w / 2 + 12, h - 10), fill=dark)
        for x in (28, w - 44):
            d.rectangle((x, h * 0.55, x + 16, h * 0.55 + 18), fill=glow, outline=dark, width=2)
    elif kind == "tower":
        d.rectangle((26, h * 0.2, w - 26, h - 10), fill=stone, outline=dark, width=3)
        d.polygon([(18, h * 0.22), (w / 2, h * 0.02), (w - 18, h * 0.22)], fill=roof, outline=dark)
        for y in (0.32, 0.5, 0.68):
            d.rectangle((w / 2 - 8, h * y, w / 2 + 8, h * y + 18), fill=glow, outline=dark, width=2)
    elif kind == "castle":
        d.rectangle((40, h * 0.35, w - 40, h - 10), fill=stone, outline=dark, width=3)
        for x in (12, w - 72):
            d.rectangle((x, h * 0.18, x + 60, h - 10), fill=stone, outline=dark, width=3)
            d.polygon([(x - 6, h * 0.2), (x + 30, h * 0.02), (x + 66, h * 0.2)], fill=roof, outline=dark)
            d.rectangle((x + 22, h * 0.32, x + 38, h * 0.32 + 20), fill=glow, outline=dark, width=2)
        d.rounded_rectangle((w / 2 - 26, h - 74, w / 2 + 26, h - 10), radius=24, fill=dark)
        for x in range(48, w - 48, 22):
            d.rectangle((x, h * 0.35 - 12, x + 12, h * 0.35), fill=stone, outline=dark, width=2)
    elif kind == "mine":
        d.polygon([(10, h - 10), (w * 0.3, h * 0.25), (w * 0.7, h * 0.2), (w - 10, h - 10)], fill=stone, outline=dark)
        d.rounded_rectangle((w / 2 - 26, h - 60, w / 2 + 26, h - 10), radius=22, fill=dark)
        d.ellipse((w / 2 - 10, h - 46, w / 2 + 10, h - 26), fill=glow)
    if ruined:
        im = im.rotate(0)
        d = ImageDraw.Draw(im)
        for k in range(6):
            x = random.randint(0, w); y = random.randint(0, int(h * 0.5))
            d.polygon([(x, y), (x + 40, y + 10), (x + 20, y + 60)], fill=(0, 0, 0, 0))
        d.rectangle((0, h - 22, w, h - 6), fill=(60, 52, 48, 255))
    return im

ACC = {"blue": (102, 230, 255), "red": (255, 122, 58), "yellow": (240, 196, 106), "purple": (183, 131, 255), "ruin": (90, 60, 40)}
for col, acc in ACC.items():
    ruin = col == "ruin"
    building(128, 192, "house", acc, ruin).save(out("gen", f"house_{col}.png"))
    building(128, 256, "tower", acc, ruin).save(out("gen", f"tower_{col}.png"))
    building(320, 256, "castle", acc, ruin).save(out("gen", f"castle_{col}.png"))
building(128, 192, "house", ACC["red"]).save(out("gen", "hut.png"))
building(128, 192, "house", ACC["ruin"], True).save(out("gen", "hut_ruin.png"))
building(192, 128, "mine", ACC["red"]).save(out("gen", "mine.png"))
wt = Image.new("RGBA", (1024, 192), (0, 0, 0, 0))  # 4 frames of 256 (old watchtower layout)
tw = building(128, 192, "tower", ACC["red"])
for f in range(4):
    wt.alpha_composite(tw, (f * 256 + 64, 0))
wt.save(out("gen", "watchtower.png"))

# ------------------------------------------------------------------ VFX sheets (procedural ember style)
def radial(size, inner, outer, r_in, r_out):
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    c = size / 2
    for i in range(int(r_out), 0, -1):
        t = i / r_out
        col = tuple(int(inner[k] * (1 - t) + outer[k] * t) for k in range(4))
        d.ellipse((c - i, c - i, c + i, c + i), fill=col)
    return im

ex = Image.new("RGBA", (1728, 192), (0, 0, 0, 0))
for f in range(9):
    k = f / 8
    r = 20 + 70 * k
    a = int(255 * (1 - k) ** 0.8)
    fr = radial(192, (255, 240, 190, a), (234, 110, 40, 0), 0, r)
    d = ImageDraw.Draw(fr)
    d.ellipse((96 - r, 96 - r, 96 + r, 96 + r), outline=(255, 180, 90, int(a * 0.8)), width=4)
    ex.alpha_composite(fr, (f * 192, 0))
ex.save(out("gen", "fx_burst.png"))

fire = Image.new("RGBA", (896, 128), (0, 0, 0, 0))
for f in range(7):
    fr = Image.new("RGBA", (128, 128), (0, 0, 0, 0)); d = ImageDraw.Draw(fr)
    for j in range(5):
        h = 30 + 18 * math.sin((f + j * 1.7) / 7 * math.tau)
        x = 44 + j * 10
        d.polygon([(x - 10, 110), (x, 110 - h - 20), (x + 10, 110)], fill=(255, 140 + j * 15, 50, 210))
    d.ellipse((40, 96, 88, 116), fill=(255, 220, 140, 200))
    fire.alpha_composite(fr.filter(ImageFilter.GaussianBlur(1.2)), (f * 128, 0))
fire.save(out("gen", "fx_flame.png"))

bolt = Image.new("RGBA", (64, 128), (0, 0, 0, 0))  # row 0 flying bolt, row 1 stuck shard
b = radial(64, (255, 245, 210, 255), (240, 120, 40, 0), 0, 18)
bolt.alpha_composite(b, (0, 0))
d = ImageDraw.Draw(bolt)
d.polygon([(10, 32), (50, 28), (56, 32), (50, 36)], fill=(255, 200, 120, 230))
d.polygon([(14, 96), (50, 92), (56, 96), (50, 100)], fill=(200, 120, 60, 255))
bolt.save(out("gen", "fx_bolt.png"))

bomb = Image.new("RGBA", (384, 64), (0, 0, 0, 0))  # 6 spinning ember-flask frames
for f in range(6):
    fr = radial(64, (255, 210, 120, 255), (180, 60, 30, 0), 0, 16)
    d = ImageDraw.Draw(fr)
    a = f / 6 * math.tau
    d.line((32, 32, 32 + 14 * math.cos(a), 32 + 14 * math.sin(a)), fill=(255, 250, 220, 255), width=3)
    bomb.alpha_composite(fr, (f * 64, 0))
bomb.save(out("gen", "fx_flask.png"))

# ------------------------------------------------------------------ UI frames in the Airron's Fall palette
BG = (36, 31, 25); CARD = (47, 40, 32); BORDER = (82, 68, 52); GOLD = (234, 210, 102)
EMBER = (232, 118, 58); EMBER_D = (150, 66, 28); TEAL = (85, 134, 120); RED = (200, 70, 60); RED_D = (120, 36, 30)

def three_slice(fill, edge, pressed=False, ribbon=False):
    im = Image.new("RGBA", (192, 64), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    top = 10 if not pressed else 14
    if ribbon:
        d.polygon([(0, 14), (24, 14), (24, 58), (12, 50), (0, 58)], fill=tuple(int(v * 0.6) for v in fill) + (255,))
        d.polygon([(192, 14), (168, 14), (168, 58), (180, 50), (192, 58)], fill=tuple(int(v * 0.6) for v in fill) + (255,))
        d.rectangle((16, 8, 176, 52), fill=fill + (255,), outline=GOLD + (255,), width=3)
        return im
    if not pressed:
        d.rounded_rectangle((4, 14, 188, 60), radius=10, fill=tuple(int(v * 0.45) for v in fill) + (255,))
    d.rounded_rectangle((4, top, 188, top + 44), radius=10, fill=fill + (255,), outline=edge + (255,), width=3)
    d.line((14, top + 6, 178, top + 6), fill=tuple(min(255, v + 50) for v in fill) + (160,), width=2)
    return im

three_slice(EMBER, GOLD).save(out("gen", "ui_btn_ember.png"))
three_slice(EMBER, GOLD, True).save(out("gen", "ui_btn_ember_p.png"))
three_slice(RED, (255, 190, 160)).save(out("gen", "ui_btn_red.png"))
three_slice(RED, (255, 190, 160), True).save(out("gen", "ui_btn_red_p.png"))
three_slice(TEAL, GOLD, ribbon=True).save(out("gen", "ui_ribbon_teal.png"))
three_slice(RED_D, GOLD, ribbon=True).save(out("gen", "ui_ribbon_red.png"))
three_slice((150, 120, 40), GOLD, ribbon=True).save(out("gen", "ui_ribbon_gold.png"))
for name, pressed in [("ui_sq", False), ("ui_sq_p", True)]:
    im = Image.new("RGBA", (64, 64), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    top = 8 if pressed else 4
    if not pressed: d.rounded_rectangle((4, 8, 60, 62), radius=10, fill=(20, 16, 12, 255))
    d.rounded_rectangle((4, top, 60, top + 52), radius=10, fill=CARD + (255,), outline=GOLD + (255,), width=3)
    im.save(out("gen", name + ".png"))
panel = Image.new("RGBA", (192, 192), (0, 0, 0, 0)); d = ImageDraw.Draw(panel)
d.rounded_rectangle((4, 4, 188, 188), radius=18, fill=BG + (245,), outline=BORDER + (255,), width=4)
d.rounded_rectangle((12, 12, 180, 180), radius=12, outline=GOLD + (120,), width=2)
panel.save(out("gen", "ui_panel_9.png"))
spk = Image.new("RGBA", (64, 64), (0, 0, 0, 0)); d = ImageDraw.Draw(spk)
d.polygon([(14, 26), (24, 26), (36, 14), (36, 50), (24, 38), (14, 38)], fill=(236, 227, 207, 255))
d.arc((30, 18, 52, 46), -50, 50, fill=(236, 227, 207, 255), width=3)
spk.save(out("gen", "ui_sound.png"))
print("built", OUT)
