#!/usr/bin/env python3
"""Génère les textures du jeu (bois, carrelage, tissu, herbe, tapis, tableaux...).

Tout est fabriqué par calcul : aucune image externe, donc aucune licence à gérer.
Lancer :  python3 tools/gen_textures.py   (depuis la racine du projet)
"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "textures")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)


def tile_noise(size, cells, seed=0):
    """Bruit lisse qui se répète sans raccord (valeurs entre 0 et 1)."""
    r = np.random.default_rng(seed)
    grid = r.random((cells, cells))
    xs = np.linspace(0, cells, size, endpoint=False)
    x0 = np.floor(xs).astype(int)
    t = xs - x0
    t = t * t * (3 - 2 * t)
    x1 = (x0 + 1) % cells
    a = grid[np.ix_(x0, x0)]
    b = grid[np.ix_(x0, x1)]
    c = grid[np.ix_(x1, x0)]
    d = grid[np.ix_(x1, x1)]
    tx = t[None, :]
    ty = t[:, None]
    return (a * (1 - tx) + b * tx) * (1 - ty) + (c * (1 - tx) + d * tx) * ty


def fbm(size, base=4, octaves=5, seed=0):
    total = np.zeros((size, size))
    amp = 1.0
    norm = 0.0
    for o in range(octaves):
        total += amp * tile_noise(size, base * 2 ** o, seed + o * 13)
        norm += amp
        amp *= 0.5
    return total / norm


def save_rgb(name, arr):
    arr = np.clip(arr, 0, 1)
    Image.fromarray((arr * 255).astype(np.uint8), "RGB").save(os.path.join(OUT, name), optimize=True)


def save_rgba(name, arr):
    arr = np.clip(arr, 0, 1)
    Image.fromarray((arr * 255).astype(np.uint8), "RGBA").save(os.path.join(OUT, name), optimize=True)


def normal_from_height(height, strength=2.0):
    dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * strength
    dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * strength
    nz = np.ones_like(height)
    length = np.sqrt(dx * dx + dy * dy + nz * nz)
    n = np.stack([-dx / length, -dy / length, nz / length], axis=-1)
    return n * 0.5 + 0.5


def lerp_color(a, b, t):
    a = np.array(a)[None, None, :]
    b = np.array(b)[None, None, :]
    return a + (b - a) * t[..., None]


# --- Parquet ---------------------------------------------------------------------------
def wood_floor(size=1024):
    planks = 8  # lames sur la largeur de la texture
    pw = size // planks
    albedo = np.zeros((size, size, 3))
    height = np.zeros((size, size))
    grain = fbm(size, 4, 5, 1)
    stretched = np.repeat(fbm(size, 8, 4, 2)[:, :: 8], 8, axis=1)[:, :size]  # fibres allongées
    stretched = np.asarray(Image.fromarray((stretched * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2))) / 255.0
    for i in range(planks):
        x0 = i * pw
        offset = int(rng.integers(0, size))
        tone = 0.86 + 0.2 * rng.random()
        warm = rng.random() * 0.05
        yy = (np.arange(size) + offset) % size
        seg_len = size // 2
        seg = (yy // seg_len)
        local = np.roll(stretched, offset, axis=0)[:, x0:x0 + pw].T  # fibres dans le sens de la lame
        local = np.roll(stretched, offset * 3, axis=1)[x0:x0 + pw, :].T
        g = 0.5 * local + 0.5 * np.roll(grain, offset, axis=0)[:, x0:x0 + pw]
        base = np.array([0.80 + warm, 0.60, 0.40]) * tone
        dark = base * 0.80
        col = dark[None, None, :] + (base - dark)[None, None, :] * g[..., None]
        seg_tone = np.where(seg % 2 == 0, 1.0, 0.94)[:, None, None]
        albedo[:, x0:x0 + pw, :] = col * seg_tone
        h = np.ones((size, pw))
        h[:, :2] = 0.0
        h[:, -2:] = 0.0
        joint = (yy % seg_len) < 3
        h[joint, :] = 0.0
        height[:, x0:x0 + pw] = h
        albedo[:, x0:x0 + 2, :] *= 0.62
        albedo[:, x0 + pw - 2:x0 + pw, :] *= 0.62
        albedo[joint, x0:x0 + pw, :] *= 0.62
    height = np.asarray(Image.fromarray((height * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.5))) / 255.0
    height = height + (grain - 0.5) * 0.08
    save_rgb("parquet.png", albedo)
    save_rgb("parquet_n.png", normal_from_height(height, 3.0))


# --- Bois des meubles -----------------------------------------------------------------
def wood(size=512):
    n = fbm(size, 3, 5, 5)
    yy, xx = np.mgrid[0:size, 0:size] / size
    rings = np.sin((xx * 6.0 + n * 2.2) * 2 * np.pi * 2.0) * 0.5 + 0.5
    fibres = np.repeat(fbm(size, 16, 3, 9)[:, ::16], 16, axis=1)[:, :size]
    fibres = np.asarray(Image.fromarray((fibres * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.0))) / 255.0
    t = 0.55 * rings + 0.45 * fibres.T
    col = lerp_color([0.86, 0.86, 0.86], [1.0, 1.0, 1.0], t)  # nuances de gris : teinté par la couleur du matériau
    save_rgb("bois.png", col)
    save_rgb("bois_n.png", normal_from_height(t * 0.5, 1.2))


# --- Carrelage --------------------------------------------------------------------------
def tiles(size=512, count=4):
    cell = size // count
    yy, xx = np.mgrid[0:size, 0:size]
    gx = np.minimum(xx % cell, cell - 1 - xx % cell)
    gy = np.minimum(yy % cell, cell - 1 - yy % cell)
    edge = np.minimum(gx, gy)
    grout = np.clip(edge / 5.0, 0, 1)
    tone = np.zeros((size, size))
    for i in range(count):
        for j in range(count):
            tone[i * cell:(i + 1) * cell, j * cell:(j + 1) * cell] = 0.93 + 0.07 * rng.random()
    n = fbm(size, 8, 4, 21)
    base = (tone + (n - 0.5) * 0.04)[..., None] * np.ones(3)[None, None, :]
    groutcol = np.array([0.74, 0.76, 0.78])[None, None, :]
    col = groutcol + (base - groutcol) * grout[..., None]
    save_rgb("carrelage.png", col)
    save_rgb("carrelage_n.png", normal_from_height(np.clip(edge / 7.0, 0, 1), 2.5))


# --- Mur (crépi fin) et tissu : cartes de relief seulement --------------------------------
def plaster(size=512):
    n = fbm(size, 16, 5, 31)
    save_rgb("crepi_n.png", normal_from_height(n, 1.6))
    col = (0.94 + (n - 0.5) * 0.1)[..., None] * np.ones(3)[None, None, :]
    save_rgb("crepi.png", col)


def fabric(size=256):
    yy, xx = np.mgrid[0:size, 0:size]
    weave = (np.sin(xx * 2 * np.pi / 8) * np.sin(yy * 2 * np.pi / 8)) * 0.5 + 0.5
    n = fbm(size, 16, 3, 41)
    h = 0.7 * weave + 0.3 * n
    save_rgb("tissu_n.png", normal_from_height(h, 1.4))
    col = (0.9 + (h - 0.5) * 0.18)[..., None] * np.ones(3)[None, None, :]
    save_rgb("tissu.png", col)


# --- Herbe ---------------------------------------------------------------------------------
def grass(size=512):
    n1 = fbm(size, 4, 5, 51)
    n2 = fbm(size, 32, 3, 57)
    t = np.clip(0.6 * n1 + 0.4 * n2, 0, 1)
    col = lerp_color([0.36, 0.60, 0.30], [0.56, 0.78, 0.40], t)
    blades = (fbm(size, 64, 2, 61) > 0.62)[..., None]
    col = np.where(blades, col * 1.1, col)
    save_rgb("herbe.png", col)


# --- Tapis rond (motif), fond transparent -------------------------------------------------
def rug(size=512):
    s = size * 2
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = s // 2
    rings = [(1.00, (236, 201, 178)), (0.93, (250, 236, 220)), (0.86, (222, 150, 130)), (0.80, (250, 236, 220)),
             (0.56, (240, 212, 190)), (0.50, (120, 160, 190)), (0.46, (250, 236, 220)), (0.20, (222, 150, 130)), (0.14, (250, 236, 220))]
    for r, colr in rings:
        rr = int(c * r)
        d.ellipse([c - rr, c - rr, c + rr, c + rr], fill=colr + (255,))
    for k in range(16):  # pétales
        a = k * 2 * np.pi / 16
        px, py = c + np.cos(a) * c * 0.68, c + np.sin(a) * c * 0.68
        rr = int(c * 0.055)
        d.ellipse([px - rr, py - rr, px + rr, py + rr], fill=(120, 160, 190, 255))
    for k in range(8):
        a = k * 2 * np.pi / 8 + np.pi / 8
        px, py = c + np.cos(a) * c * 0.33, c + np.sin(a) * c * 0.33
        rr = int(c * 0.045)
        d.ellipse([px - rr, py - rr, px + rr, py + rr], fill=(222, 150, 130, 255))
    img = img.resize((size, size), Image.LANCZOS)
    arr = np.asarray(img).astype(float) / 255.0
    weave = fbm(size, 64, 2, 71)
    arr[..., :3] *= (0.92 + 0.12 * weave)[..., None]
    save_rgba("tapis.png", arr)


# --- Tableaux -----------------------------------------------------------------------------
def painting(name, palette, seed, size=256):
    r = np.random.default_rng(seed)
    s = size * 2
    img = Image.new("RGB", (s, s), palette[0])
    d = ImageDraw.Draw(img)
    for _ in range(9):
        colr = palette[int(r.integers(1, len(palette)))]
        x, y = r.integers(0, s, 2)
        rad = int(r.integers(s // 10, s // 3))
        d.ellipse([x - rad, y - rad, x + rad, y + rad], fill=colr)
    for _ in range(5):
        colr = palette[int(r.integers(1, len(palette)))]
        x0, y0, x1, y1 = r.integers(0, s, 4)
        d.line([x0, y0, x1, y1], fill=colr, width=int(r.integers(8, 28)))
    img = img.filter(ImageFilter.GaussianBlur(2)).resize((size, size), Image.LANCZOS)
    img.save(os.path.join(OUT, name), optimize=True)


def landscape(size=256):
    s = size * 2
    img = Image.new("RGB", (s, s), (170, 215, 240))
    d = ImageDraw.Draw(img)
    d.ellipse([s * 0.62, s * 0.12, s * 0.82, s * 0.32], fill=(255, 236, 170))
    d.polygon([(0, s * 0.62), (s * 0.3, s * 0.34), (s * 0.62, s * 0.66)], fill=(150, 170, 200))
    d.polygon([(s * 0.35, s * 0.68), (s * 0.7, s * 0.4), (s, s * 0.66)], fill=(128, 150, 186))
    d.ellipse([-s * 0.3, s * 0.55, s * 0.7, s * 1.5], fill=(130, 190, 120))
    d.ellipse([s * 0.3, s * 0.62, s * 1.4, s * 1.6], fill=(108, 172, 108))
    for x, y in [(0.2, 0.7), (0.3, 0.76), (0.75, 0.78), (0.86, 0.72)]:
        d.rectangle([s * x - 4, s * y, s * x + 4, s * y + 30], fill=(120, 86, 60))
        d.ellipse([s * x - 26, s * y - 44, s * x + 26, s * y + 8], fill=(70, 140, 84))
    img.resize((size, size), Image.LANCZOS).save(os.path.join(OUT, "tableau_paysage.png"), optimize=True)


# --- Nuage et ombre douce (fond transparent) ----------------------------------------------
def cloud(size=256):
    yy, xx = np.mgrid[0:size, 0:size] / size
    a = np.zeros((size, size))
    for cx, cy, r in [(0.3, 0.58, 0.2), (0.5, 0.45, 0.26), (0.7, 0.56, 0.21), (0.42, 0.62, 0.2), (0.6, 0.63, 0.19)]:
        dist = np.sqrt((xx - cx) ** 2 + ((yy - cy) * 1.5) ** 2)
        a = np.maximum(a, np.clip(1.0 - dist / r, 0, 1))
    a = np.clip(a * 2.2, 0, 1) ** 0.9
    arr = np.ones((size, size, 4))
    arr[..., 3] = a
    arr[..., :3] = (0.92 + 0.08 * (1 - yy))[..., None]
    save_rgba("nuage.png", arr)


def blob(size=128):
    yy, xx = np.mgrid[0:size, 0:size] / (size - 1) * 2 - 1
    dist = np.sqrt(xx ** 2 + yy ** 2)
    arr = np.zeros((size, size, 4))
    arr[..., 3] = np.clip(1 - dist, 0, 1) ** 1.6
    save_rgba("ombre.png", arr)
    arr2 = np.ones((size, size, 4))
    arr2[..., 3] = np.clip(1 - dist, 0, 1) ** 2.2
    save_rgba("lueur.png", arr2)


def bedspread(size=256):
    yy, xx = np.mgrid[0:size, 0:size]
    base = np.ones((size, size, 3)) * np.array([0.93, 0.95, 1.0])
    stripe = ((yy // 32) % 2 == 0)
    base[stripe] = np.array([0.80, 0.86, 0.97])
    dots = (((xx % 64) - 32) ** 2 + ((yy % 64) - 16) ** 2) < 36
    base[dots] = np.array([1.0, 0.86, 0.6])
    n = fbm(size, 32, 2, 81)
    base *= (0.95 + 0.08 * n)[..., None]
    save_rgb("couette.png", base)


def wallpaper(size=256):
    """Papier peint très discret : petits losanges ton sur ton."""
    yy, xx = np.mgrid[0:size, 0:size]
    base = np.ones((size, size, 3))
    cell = 64
    dx = np.abs((xx % cell) - cell / 2)
    dy = np.abs((yy % cell) - cell / 2)
    diamond = (dx + dy) < 9
    dx2 = np.abs(((xx + cell // 2) % cell) - cell / 2)
    dy2 = np.abs(((yy + cell // 2) % cell) - cell / 2)
    dot = (dx2 ** 2 + dy2 ** 2) < 9
    base[diamond] = 0.93
    base[dot] = 0.95
    n = fbm(size, 16, 3, 91)
    base *= (0.97 + 0.05 * n)[..., None]
    save_rgb("papier_peint.png", base)


if __name__ == "__main__":
    wood_floor()
    wood()
    tiles()
    plaster()
    fabric()
    grass()
    rug()
    painting("tableau_abstrait.png", [(250, 240, 225), (240, 150, 120), (110, 160, 200), (250, 205, 110), (120, 180, 140)], 3)
    painting("toile_chevalet.png", [(252, 250, 244), (236, 120, 110), (90, 150, 220), (250, 200, 90), (110, 190, 140)], 11)
    landscape()
    cloud()
    blob()
    bedspread()
    wallpaper()
    print("Textures générées dans", OUT)
