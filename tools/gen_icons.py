#!/usr/bin/env python3
"""Fabrique les pictogrammes de l'interface (blancs, fond transparent) dans icons/.
Ils sont colorés ensuite par le jeu. Usage : python3 tools/gen_icons.py"""
import math, os
from PIL import Image, ImageDraw

S = 512          # taille de dessin (suréchantillonnée)
OUT = 96         # taille finale
DIR = os.path.join(os.path.dirname(__file__), "..", "icons")


def canvas():
    img = Image.new("L", (S, S), 0)
    return img, ImageDraw.Draw(img)


def P(v):  # coordonnées en 0..100 → pixels
    return v * S / 100.0


def box(d, x0, y0, x1, y1, r=0, fill=255):
    d.rounded_rectangle([P(x0), P(y0), P(x1), P(y1)], radius=P(r), fill=fill)


def disc(d, x, y, r, fill=255):
    d.ellipse([P(x - r), P(y - r), P(x + r), P(y + r)], fill=fill)


def oval(d, x0, y0, x1, y1, fill=255):
    d.ellipse([P(x0), P(y0), P(x1), P(y1)], fill=fill)


def poly(d, pts, fill=255):
    d.polygon([(P(x), P(y)) for x, y in pts], fill=fill)


def line(d, pts, w, fill=255):
    d.line([(P(x), P(y)) for x, y in pts], fill=fill, width=int(P(w)), joint="curve")
    for x, y in pts:
        disc(d, x, y, w / 2.0, fill)


def arc(d, x, y, r, a0, a1, w, fill=255):
    d.arc([P(x - r), P(y - r), P(x + r), P(y + r)], a0, a1, fill=fill, width=int(P(w)))


def star(d, x, y, r, r2=None, n=5, rot=-90, fill=255):
    r2 = r2 or r * 0.45
    pts = []
    for i in range(n * 2):
        a = math.radians(rot + i * 180.0 / n)
        rr = r if i % 2 == 0 else r2
        pts.append((x + math.cos(a) * rr, y + math.sin(a) * rr))
    poly(d, pts, fill)


def heart(d, x, y, s, fill=255):
    disc(d, x - s * 0.5, y - s * 0.3, s * 0.56, fill)
    disc(d, x + s * 0.5, y - s * 0.3, s * 0.56, fill)
    poly(d, [(x - s * 1.02, y - 0.02 * s), (x + s * 1.02, y - 0.02 * s), (x, y + s * 1.1)], fill)


ICONS = {}


def icon(f):
    ICONS[f.__name__] = f
    return f


@icon
def faim(d):  # pomme
    disc(d, 38, 58, 27); disc(d, 62, 58, 27)
    disc(d, 50, 34, 9, 0)
    line(d, [(50, 38), (54, 20)], 6)
    poly(d, [(56, 24), (72, 12), (80, 22), (66, 30)])


@icon
def sommeil(d):  # lune et étoile
    disc(d, 46, 54, 36); disc(d, 62, 42, 31, 0)
    star(d, 72, 30, 13)


@icon
def toilettes(d):  # rouleau de papier
    box(d, 16, 22, 70, 62, 20)
    oval(d, 24, 30, 42, 54, 0)
    box(d, 52, 42, 86, 86, 5)
    line(d, [(58, 64), (80, 64)], 4, 0)
    line(d, [(58, 74), (80, 74)], 4, 0)


@icon
def hygiene(d):  # goutte d'eau
    disc(d, 50, 62, 27)
    poly(d, [(50, 8), (26, 50), (74, 50)])
    arc(d, 50, 62, 17, 100, 170, 6, 0)


@icon
def social(d):  # deux bulles
    box(d, 8, 14, 66, 56, 16)
    poly(d, [(20, 50), (20, 72), (40, 54)])
    box(d, 40, 44, 92, 80, 14, 0)
    box(d, 44, 48, 92, 80, 13)
    poly(d, [(80, 76), (82, 94), (64, 78)])
    for x in (22, 37, 52):
        disc(d, x, 35, 5, 0) if x < 44 else None


@icon
def piece(d):
    disc(d, 50, 50, 40); disc(d, 50, 50, 31, 0); disc(d, 50, 50, 25)
    star(d, 50, 51, 15, fill=0)


@icon
def etoile(d):
    star(d, 50, 54, 44, 19)


@icon
def horloge(d):
    disc(d, 50, 50, 40); disc(d, 50, 50, 31, 0)
    line(d, [(50, 50), (50, 30)], 7); line(d, [(50, 50), (64, 58)], 7)


@icon
def chrono(d):
    disc(d, 50, 56, 36); disc(d, 50, 56, 27, 0)
    box(d, 42, 6, 58, 18, 3); box(d, 46, 14, 54, 24)
    line(d, [(74, 26), (80, 32)], 7)
    line(d, [(50, 56), (50, 38)], 7)


@icon
def physique(d):  # haltère
    box(d, 22, 44, 78, 56, 3)
    box(d, 8, 26, 22, 74, 6); box(d, 24, 18, 38, 82, 6)
    box(d, 62, 18, 76, 82, 6); box(d, 78, 26, 92, 74, 6)


@icon
def creativite(d):  # palette
    oval(d, 8, 18, 92, 84)
    disc(d, 66, 66, 10, 0)
    for x, y in ((30, 44), (46, 32), (66, 36), (30, 64)):
        disc(d, x, y, 7, 0)


@icon
def charisme(d):  # micro
    box(d, 36, 8, 64, 58, 14)
    arc(d, 50, 44, 26, 0, 180, 7)
    box(d, 46, 68, 54, 84); box(d, 32, 82, 68, 90, 4)


@icon
def organisation(d):  # liste cochée
    for i, y in enumerate((24, 50, 76)):
        box(d, 10, y - 10, 30, y + 10, 4)
        box(d, 40, y - 5, 90, y + 5, 5)
        if i < 2:
            line(d, [(14, y), (19, y + 5), (27, y - 5)], 4, 0)
        else:
            box(d, 15, y - 5, 25, y + 5, 2, 0)


@icon
def travail(d):  # mallette
    box(d, 34, 14, 66, 40, 8); box(d, 41, 21, 59, 40, 3, 0)
    box(d, 8, 30, 92, 84, 10)
    box(d, 8, 52, 92, 57, 0, 0)
    box(d, 43, 46, 57, 64, 3); box(d, 47, 50, 53, 60, 1, 0)


@icon
def coeur(d):
    heart(d, 50, 44, 36)


@icon
def cible(d):
    disc(d, 50, 50, 42); disc(d, 50, 50, 33, 0); disc(d, 50, 50, 24); disc(d, 50, 50, 15, 0); disc(d, 50, 50, 8)


@icon
def livre(d):  # livre ouvert
    poly(d, [(8, 22), (46, 30), (46, 86), (8, 76)])
    poly(d, [(92, 22), (54, 30), (54, 86), (92, 76)])
    for y in (42, 54, 66):
        line(d, [(16, y - 4), (38, y)], 3, 0); line(d, [(84, y - 4), (62, y)], 3, 0)


@icon
def pause(d):
    box(d, 22, 16, 42, 84, 6); box(d, 58, 16, 78, 84, 6)


@icon
def son(d):
    poly(d, [(8, 38), (28, 38), (52, 16), (52, 84), (28, 62), (8, 62)])
    arc(d, 50, 50, 22, -45, 45, 7); arc(d, 50, 50, 38, -45, 45, 7)


@icon
def reglages(d):  # roue dentée
    for i in range(8):
        a = math.radians(i * 45)
        x, y = 50 + math.cos(a) * 34, 50 + math.sin(a) * 34
        disc(d, x, y, 10)
    disc(d, 50, 50, 31); disc(d, 50, 50, 13, 0)


@icon
def coche(d):
    line(d, [(16, 54), (40, 76), (84, 26)], 14)


@icon
def croix(d):
    line(d, [(22, 22), (78, 78)], 14); line(d, [(78, 22), (22, 78)], 14)


@icon
def fleche(d):
    line(d, [(14, 50), (76, 50)], 14)
    poly(d, [(56, 20), (92, 50), (56, 80)])


@icon
def souris(d):
    box(d, 26, 8, 74, 92, 24)
    box(d, 47, 8, 53, 42, 0, 0)
    box(d, 26, 40, 74, 45, 0, 0)
    box(d, 44, 18, 56, 36, 6)


@icon
def clavier(d):
    box(d, 4, 24, 96, 78, 10)
    for row, y in enumerate((36, 50)):
        for i in range(6):
            x = 12 + i * 13.5 + row * 3
            box(d, x, y - 4.5, x + 9, y + 4.5, 2, 0)
    box(d, 28, 61, 72, 69, 3, 0)


@icon
def soleil(d):
    disc(d, 50, 50, 21)
    for i in range(8):
        a = math.radians(i * 45)
        line(d, [(50 + math.cos(a) * 31, 50 + math.sin(a) * 31), (50 + math.cos(a) * 42, 50 + math.sin(a) * 42)], 8)


@icon
def de(d):  # dé (au hasard)
    box(d, 12, 12, 88, 88, 16)
    for x, y in ((30, 30), (70, 30), (50, 50), (30, 70), (70, 70)):
        disc(d, x, y, 7.5, 0)


@icon
def perso(d):  # silhouette
    disc(d, 50, 28, 20)
    box(d, 18, 54, 82, 120, 30)


@icon
def miroir(d):
    oval(d, 22, 6, 78, 76); oval(d, 30, 14, 70, 68, 0)
    box(d, 45, 74, 55, 88); box(d, 30, 86, 70, 94, 4)
    line(d, [(40, 34), (50, 24)], 4)


@icon
def cadenas(d):
    arc(d, 50, 38, 21, 180, 360, 9)
    box(d, 29, 36, 38, 50); box(d, 62, 36, 71, 50)
    box(d, 18, 46, 82, 90, 10)
    disc(d, 50, 66, 7, 0)


@icon
def drapeau(d):
    box(d, 18, 8, 26, 94, 3)
    poly(d, [(26, 12), (86, 26), (26, 52)])


@icon
def bulle(d):  # « i » d'information
    disc(d, 50, 50, 42)
    disc(d, 50, 28, 7, 0); box(d, 44, 42, 56, 76, 5, 0)


def main():
    os.makedirs(DIR, exist_ok=True)
    for name, f in ICONS.items():
        mask, d = canvas()
        f(d)
        mask = mask.resize((OUT, OUT), Image.LANCZOS)
        img = Image.new("RGBA", (OUT, OUT), (255, 255, 255, 0))
        img.putalpha(mask)
        img.save(os.path.join(DIR, name + ".png"))
    # Planche de contrôle
    names = list(ICONS)
    cols = 8
    sheet = Image.new("RGBA", (cols * 110, ((len(names) + cols - 1) // cols) * 110), (60, 90, 150, 255))
    for i, name in enumerate(names):
        im = Image.open(os.path.join(DIR, name + ".png"))
        sheet.alpha_composite(im, ((i % cols) * 110 + 7, (i // cols) * 110 + 7))
    sheet.save(os.environ.get("ICON_SHEET", "/tmp/icons_sheet.png"))
    print(len(names), "icônes")


if __name__ == "__main__":
    main()
