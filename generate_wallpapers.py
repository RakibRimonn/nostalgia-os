import os
from PIL import Image, ImageDraw

OUTPUT_DIR = "wallpapers"
WIDTH, HEIGHT = 3840, 2160
os.makedirs(OUTPUT_DIR, exist_ok=True)

THEMES = [
    ("deep-night", (10, 12, 18), (28, 35, 51)),
    ("retro-neon", (15, 5, 29), (72, 12, 79)),
    ("cyber-horizon", (3, 18, 33), (12, 84, 110)),
    ("monolith-black", (5, 5, 5), (25, 25, 28)),
]

for idx in range(10):
    theme = THEMES[idx % len(THEMES)]
    c1, c2 = theme[1], theme[2]
    img = Image.new("RGB", (WIDTH, HEIGHT), c1)
    draw = ImageDraw.Draw(img)
    for y in range(HEIGHT):
        ratio = y / HEIGHT
        r = int(c1[0] * (1 - ratio) + c2[0] * ratio)
        g = int(c1[1] * (1 - ratio) + c2[1] * ratio)
        b = int(c1[2] * (1 - ratio) + c2[2] * ratio)
        draw.line([(0, y), (WIDTH, y)], fill=(r, g, b))
    img.save(os.path.join(OUTPUT_DIR, f"nostalgia-{idx+1:02d}.png"), "PNG")
print("Wallpapers generated successfully.")
