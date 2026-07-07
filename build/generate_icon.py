#!/usr/bin/env python3
"""Generate the ILL WILL Windows icon (assets/ui/illwill.ico).

Identity: a party game about inheritance and betrayal. The mark is a "sealed
will" — a chunky gold SPADE (the estate's grudge currency) on aged dark-plum
parchment, wearing the LuckiestGuy logotype. Large layers carry the wordmark;
small layers drop to a spade-only seal so the silhouette stays legible at 16px.

Pure-Python (Pillow): draws the spade as a dilated union mask, so it needs no
system spade glyph and scales crisply. Run from the repo root:
    python build/generate_icon.py
Outputs assets/ui/illwill.ico plus per-size PNG proofs under build/icon_layers/.
"""
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_ICO = os.path.join(ROOT, "assets", "ui", "illwill.ico")
LAYER_DIR = os.path.join(ROOT, "build", "icon_layers")
LOGO_FONT = os.path.join(ROOT, "assets", "fonts", "LuckiestGuy-Regular.ttf")

GOLD = (255, 205, 51, 255)          # logo gold  (1.0, 0.85, 0.2)
GOLD_HI = (255, 232, 140, 255)      # sheen highlight
DARK = (38, 22, 10, 255)            # logo outline (0.2, 0.12, 0.05)
PLUM = (26, 18, 34, 255)            # dark plum parchment center
PLUM_EDGE = (12, 8, 17, 255)        # vignette edge
BORDER = (196, 150, 40, 255)        # aged-gold rim

SS = 8  # supersample factor for the master render


def _lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(len(a)))


def rounded_mask(size, radius):
    m = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(m)
    d.rounded_rectangle([0, 0, size - 1, size - 1], radius=radius, fill=255)
    return m


def parchment(size):
    """Dark-plum rounded tile with a soft radial vignette and gold rim."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()
    cx = cy = size / 2.0
    maxd = (size / 2.0) * 1.18
    for y in range(size):
        for x in range(size):
            d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
            t = min(1.0, d / maxd)
            px[x, y] = _lerp(PLUM, PLUM_EDGE, t * t)
    radius = int(size * 0.22)
    img.putalpha(rounded_mask(size, radius))
    # aged-gold rim
    d = ImageDraw.Draw(img)
    inset = max(1, int(size * 0.012))
    d.rounded_rectangle(
        [inset, inset, size - 1 - inset, size - 1 - inset],
        radius=radius - inset, outline=BORDER, width=max(1, int(size * 0.02)))
    return img


def spade_mask(size, w, h, cx, cy):
    """Union mask (L) of a spade sized w x h, centered at (cx, cy)."""
    m = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(m)
    top = cy - h / 2.0
    bottom = cy + h / 2.0
    # lobes: two circles at the body's widest point form the rounded shoulders
    lobe_r = w * 0.30
    lobe_cy = cy + h * 0.04
    lx = cx - w * 0.5 + lobe_r
    rx = cx + w * 0.5 - lobe_r
    d.ellipse([lx - lobe_r, lobe_cy - lobe_r, lx + lobe_r, lobe_cy + lobe_r], fill=255)
    d.ellipse([rx - lobe_r, lobe_cy - lobe_r, rx + lobe_r, lobe_cy + lobe_r], fill=255)
    # point: triangle from the sharp apex down to the lobes' widest points, so the
    # sides meet the shoulders cleanly (classic spade, no pinched waist)
    d.polygon([(cx, top), (lx - lobe_r, lobe_cy), (rx + lobe_r, lobe_cy)], fill=255)
    # fill the notch between the two lobes below their centre line
    d.polygon([(lx, lobe_cy), (rx, lobe_cy), (cx, lobe_cy + lobe_r)], fill=255)
    # stem: flared pedestal under the body
    stem_top = lobe_cy + lobe_r * 0.55
    d.polygon([(cx - w * 0.055, stem_top - h * 0.02), (cx + w * 0.055, stem_top - h * 0.02),
               (cx + w * 0.21, bottom), (cx - w * 0.21, bottom)], fill=255)
    return m


def outlined_spade(size, w, h, cx, cy, ss=SS):
    """A gold spade with a dark outline + top sheen, on a transparent canvas."""
    S = size * ss
    m = spade_mask(S, w * ss, h * ss, cx * ss, cy * ss)
    ow = max(2, int(round(size * 0.045)) * ss)  # outline thickness
    outline_m = m.filter(ImageFilter.MaxFilter(ow | 1))
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    dark_fill = Image.new("RGBA", (S, S), DARK)
    layer = Image.composite(dark_fill, layer, outline_m)
    # gold body with a vertical sheen (brighter up top)
    body = Image.new("RGBA", (S, S), GOLD)
    bpx = body.load()
    top_y = (cy - h / 2.0) * ss
    bot_y = (cy + h / 2.0) * ss
    for yy in range(int(top_y), int(bot_y) + 1):
        if yy < 0 or yy >= S:
            continue
        t = (yy - top_y) / max(1.0, (bot_y - top_y))
        col = _lerp(GOLD_HI, GOLD, min(1.0, t * 1.3))
        for xx in range(S):
            bpx[xx, yy] = col
    layer = Image.composite(body, layer, m)
    return layer.resize((size, size), Image.LANCZOS)


def fit_font(path, text, target_w, start=10):
    size = start
    f = ImageFont.truetype(path, size)
    while True:
        nf = ImageFont.truetype(path, size + 4)
        if nf.getbbox(text)[2] > target_w:
            break
        size += 4
        f = nf
    return f


def draw_wordmark(img, text, cx, y_center, target_w):
    d = ImageDraw.Draw(img)
    f = fit_font(LOGO_FONT, text, target_w)
    bbox = d.textbbox((0, 0), text, font=f)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    x = cx - tw / 2 - bbox[0]
    y = y_center - th / 2 - bbox[1]
    ow = max(2, int(img.size[0] * 0.02))
    for dx in range(-ow, ow + 1):
        for dy in range(-ow, ow + 1):
            if dx * dx + dy * dy <= ow * ow:
                d.text((x + dx, y + dy), text, font=f, fill=DARK)
    d.text((x, y), text, font=f, fill=GOLD)


def compose(size, with_wordmark):
    img = parchment(size)
    if with_wordmark:
        # spade sits in the upper 60%, wordmark stacked at the bottom
        sp = outlined_spade(size, w=size * 0.46, h=size * 0.50,
                             cx=size * 0.5, cy=size * 0.40)
        img.alpha_composite(sp)
        draw_wordmark(img, "ILL", size * 0.5, size * 0.72, size * 0.42)
        draw_wordmark(img, "WILL", size * 0.5, size * 0.88, size * 0.52)
    else:
        # spade-only seal — fills the tile for legibility at tiny sizes
        sp = outlined_spade(size, w=size * 0.62, h=size * 0.68,
                            cx=size * 0.5, cy=size * 0.5)
        img.alpha_composite(sp)
    return img


def main():
    os.makedirs(LAYER_DIR, exist_ok=True)
    # Distinct art per size: wordmark on the big layers, spade-only when small.
    plan = [(256, True), (128, True), (64, True), (48, False), (32, False), (16, False)]
    layers = []
    for sz, word in plan:
        im = compose(sz, word)
        p = os.path.join(LAYER_DIR, f"icon_{sz}.png")
        im.save(p)
        layers.append(im)
        print(f"  layer {sz}px  wordmark={word}  -> {p}")
    # Pillow writes a multi-resolution .ico from the largest image + sizes list,
    # but that reuses one source. To keep the distinct small-size art, append the
    # individual frames explicitly.
    base = layers[0]
    base.save(OUT_ICO, format="ICO",
              sizes=[(s, s) for s, _ in plan],
              append_images=layers[1:])
    print(f"wrote {OUT_ICO}")


if __name__ == "__main__":
    main()
