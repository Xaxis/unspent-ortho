#!/usr/bin/env python3
"""The landing page's images, from the frames tours/site.tour shoots.

    tools/site/frames.py [SHOTS_DIR]       default shots/tour/site

Each page image is one shot, scaled from the tour's 3840x2160 to 2560 and 1280
wide WebP (the page's srcset), and the hero also as the 1200x630 JPEG a link
preview shows. FRAMES below says which shot is which image; the captions in
site/index.html are written for these moments, so change both together.

Needs Pillow (`uv pip install pillow`). The images are committed, so the deploy
never needs it.
"""
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "site/frames"
# page image -> the shot in tours/site.tour it is made from
FRAMES = {
    "hero": "08-town-night",
    "tether": "02-tether",
    "shore": "04-town-shoulder",
    "reaper": "05-reaper",
    "surf": "01-surf",
    "drowned": "06-drowned",
    "camp": "09-camp-night",
}
WIDTHS = (2560, 1280)


def main() -> int:
    shots = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "shots/tour/site"
    OUT.mkdir(parents=True, exist_ok=True)
    for name, shot in FRAMES.items():
        src = shots / (shot + ".png")
        if not src.exists():
            print("frames: no %s (run tours/site.tour)" % src)
            return 1
        im = Image.open(src).convert("RGB")
        for w in WIDTHS:
            im.resize((w, round(w * im.height / im.width)), Image.Resampling.LANCZOS).save(OUT / ("%s-%d.webp" % (name, w)), quality=84, method=6)
        if name == "hero":
            # 1200x630: the 1.9:1 a link preview crops to, cut from the 16:9 frame.
            h = round(im.width / 1.905)
            top = (im.height - h) // 2
            card = im.crop((0, top, im.width, top + h)).resize((1200, 630), Image.Resampling.LANCZOS)
            card.save(OUT / "card.jpg", quality=86, optimize=True, progressive=True)
        print("frames: %s <- %s" % (name, shot))
    return 0


if __name__ == "__main__":
    sys.exit(main())
