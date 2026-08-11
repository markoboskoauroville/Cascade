#!/usr/bin/env python3
"""Regenerate assets/icon_1024.png: cascading panes on a near-black plate."""
from PIL import Image, ImageDraw
import pathlib

S, SS = 1024, 4
W = S * SS
ORANGE = (210, 105, 30, 255)
DIM = (150, 74, 21, 255)
BG_TOP, BG_BOT = (24, 24, 27), (9, 9, 11)

img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
margin = W * 0.085
corner = (W - margin * 2) * 0.225

plate = Image.new("RGBA", (W, W), (0, 0, 0, 0))
pd = ImageDraw.Draw(plate)
for y in range(int(margin), int(W - margin)):
    t = (y - margin) / (W - 2 * margin)
    pd.line([(0, y), (W, y)],
            fill=tuple(int(BG_TOP[i] + (BG_BOT[i] - BG_TOP[i]) * t) for i in range(3)) + (255,))
mask = Image.new("L", (W, W), 0)
ImageDraw.Draw(mask).rounded_rectangle([margin, margin, W - margin, W - margin],
                                       radius=corner, fill=255)
img.paste(plate, (0, 0), mask)
d = ImageDraw.Draw(img)

# Two columns of three cascading panes: the layout the app produces.
pane_w, pane_h = W * 0.300, W * 0.300
step = W * 0.050
r = W * 0.028
for col, base_x in enumerate((W * 0.180, W * 0.520)):
    base_y = W * 0.235
    for i in range(3):
        x = base_x + i * step
        y = base_y + i * step
        fill = ORANGE if i == 2 else DIM
        d.rounded_rectangle([x, y, x + pane_w, y + pane_h], radius=r, fill=fill)
        # title bar strip, the thing the cascade keeps reachable
        d.rounded_rectangle([x, y, x + pane_w, y + W * 0.030], radius=r * 0.5,
                            fill=(255, 255, 255, 70))

out = pathlib.Path(__file__).resolve().parent.parent / "assets" / "icon_1024.png"
out.parent.mkdir(exist_ok=True)
img.resize((S, S), Image.LANCZOS).save(out)
print("wrote", out)
