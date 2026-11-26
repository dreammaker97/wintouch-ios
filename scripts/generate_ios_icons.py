import json
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC_ICON = os.path.join(ROOT, "web", "icons", "logo-source.png")
ASSETS_DIR = os.path.join(ROOT, "ios", "WinTouch", "Resources", "Assets.xcassets")
APPICON_DIR = os.path.join(ASSETS_DIR, "AppIcon.appiconset")

ICON_SPECS = [
    ("Icon-40.png", 40, "20x20", "2x", "iphone"),
    ("Icon-60.png", 60, "20x20", "3x", "iphone"),
    ("Icon-58.png", 58, "29x29", "2x", "iphone"),
    ("Icon-87.png", 87, "29x29", "3x", "iphone"),
    ("Icon-80.png", 80, "40x40", "2x", "iphone"),
    ("Icon-120.png", 120, "40x40", "3x", "iphone"),
    ("Icon-120-app.png", 120, "60x60", "2x", "iphone"),
    ("Icon-180.png", 180, "60x60", "3x", "iphone"),
    ("Icon-152.png", 152, "76x76", "2x", "ipad"),
    ("Icon-167.png", 167, "83.5x83.5", "2x", "ipad"),
    ("Icon-1024.png", 1024, "1024x1024", "1x", "ios-marketing"),
]


def main():
    os.makedirs(APPICON_DIR, exist_ok=True)

    with open(os.path.join(ASSETS_DIR, "Contents.json"), "w", encoding="utf-8") as f:
        json.dump({"info": {"author": "xcode", "version": 1}}, f, indent=2)

    base = Image.open(SRC_ICON).convert("RGBA")
    w, h = base.size
    side = min(w, h)
    base = base.crop(((w - side) // 2, (h - side) // 2, (w + side) // 2, (h + side) // 2))

    images_json = []
    for filename, px, size_pt, scale, idiom in ICON_SPECS:
        resized = base.resize((px, px), Image.Resampling.LANCZOS)
        bg = Image.new("RGBA", (px, px), (7, 10, 18, 255))
        bg.paste(resized, (0, 0), resized)
        bg.convert("RGB").save(os.path.join(APPICON_DIR, filename), "PNG", optimize=True)

        images_json.append({
            "filename": filename,
            "idiom": idiom,
            "scale": scale,
            "size": size_pt,
        })

    with open(os.path.join(APPICON_DIR, "Contents.json"), "w", encoding="utf-8") as f:
        json.dump({
            "images": images_json,
            "info": {"author": "xcode", "version": 1},
        }, f, indent=2)

    print("Generated iOS AppIcon.appiconset at:", APPICON_DIR)


if __name__ == "__main__":
    main()
