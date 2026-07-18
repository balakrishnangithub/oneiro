#!/usr/bin/env python3
"""Generates Oneiro's launcher icon source assets.

Original artwork (night-indigo field, amber crescent moon + four-point star,
matching lib/src/core/theme/app_theme.dart) drawn programmatically with
Pillow at 4x and downscaled for smooth edges.

Outputs:
  assets/icon/app_icon.png             1024x1024, full-bleed night field
  assets/icon/app_icon_foreground.png  1024x1024, transparent, padded motif
                                       (adaptive-icon foreground layer)
  assets/icon/app_icon_monochrome.png  1024x1024, white motif on transparent
                                       (Android 13+ themed-icon layer)

Run from the repo root:  python tools/generate_launcher_icon.py
"""

from pathlib import Path

from PIL import Image, ImageDraw

SIZE = 1024
SS = 4  # supersampling factor
S = SIZE * SS

# Palette from AppTheme: dark night surfaces + the lucid amber accent.
NIGHT = (15, 17, 32, 255)        # #0F1120 scaffold dark
NIGHT_HIGH = (34, 38, 62, 255)   # #22263E surfaceContainerHigh
MOON = (245, 197, 66, 255)       # #F5C542 lucidAccent
STAR = (255, 226, 138, 255)      # lighter amber for the star

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "icon"


def draw_moon(draw: ImageDraw.ImageDraw, cx: float, cy: float, r: float) -> None:
    """Crescent moon: a full disc with an offset bite in the field color."""
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=MOON)
    # The bite: offset up-right, drawn in the NIGHT color for the opaque
    # version. For the transparent foreground we punch it out instead.
    bite_r = r * 0.86
    bx = cx + r * 0.52
    by = cy - r * 0.46
    draw.ellipse([bx - bite_r, by - bite_r, bx + bite_r, by + bite_r], fill=NIGHT)


def draw_star_colored(draw: ImageDraw.ImageDraw, cx: float, cy: float,
                      r: float, color) -> None:
    """Four-point sparkle star (two overlapping slim diamonds)."""


def compose(transparent: bool, mono: bool = False) -> Image.Image:
    moon_color = (255, 255, 255, 255) if mono else MOON
    star_color = (255, 255, 255, 255) if mono else STAR
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0) if transparent else NIGHT)
    draw = ImageDraw.Draw(img)

    pad = 1.18 if transparent else 1.0  # adaptive icons get masked + scaled
    if not transparent:
        # Quiet halo behind the moon so the field is not perfectly flat.
        halo_r = S * 0.46
        draw.ellipse(
            [S / 2 - halo_r, S / 2 - halo_r, S / 2 + halo_r, S / 2 + halo_r],
            fill=NIGHT_HIGH,
        )

    moon_r = S * 0.30 / pad
    moon_cx = S * 0.46
    moon_cy = S * 0.54
    if transparent:
        # Punch the bite out of the alpha so the field color shows through.
        moon = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        md = ImageDraw.Draw(moon)
        md.ellipse(
            [moon_cx - moon_r, moon_cy - moon_r,
             moon_cx + moon_r, moon_cy + moon_r],
            fill=moon_color,
        )
        bite_r = moon_r * 0.86
        bx = moon_cx + moon_r * 0.52
        by = moon_cy - moon_r * 0.46
        md.ellipse([bx - bite_r, by - bite_r, bx + bite_r, by + bite_r],
                   fill=(0, 0, 0, 0))
        img.alpha_composite(moon)
    else:
        draw_moon(draw, moon_cx, moon_cy, moon_r)

    # Sparkle star resting in the crescent's opening.
    star_r = S * 0.075 / pad
    draw_star_colored(draw, S * 0.62, S * 0.36, star_r, star_color)
    # A tiny companion star, lower left of the moon.
    draw_star_colored(draw, S * 0.30, S * 0.33, star_r * 0.45, star_color)

    return img.resize((SIZE, SIZE), Image.LANCZOS)


def draw_star_colored(draw: ImageDraw.ImageDraw, cx: float, cy: float,
                      r: float, color) -> None:
    """Four-point sparkle star (two overlapping slim diamonds)."""
    w = r * 0.22
    draw.polygon(
        [(cx, cy - r), (cx + w, cy - w), (cx + r, cy), (cx + w, cy + w),
         (cx, cy + r), (cx - w, cy + w), (cx - r, cy), (cx - w, cy - w)],
        fill=color,
    )


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    compose(transparent=False).save(OUT / "app_icon.png")
    compose(transparent=True).save(OUT / "app_icon_foreground.png")
    compose(transparent=True, mono=True).save(OUT / "app_icon_monochrome.png")
    print(f"wrote {OUT / 'app_icon.png'}")
    print(f"wrote {OUT / 'app_icon_foreground.png'}")
    print(f"wrote {OUT / 'app_icon_monochrome.png'}")


if __name__ == "__main__":
    main()
