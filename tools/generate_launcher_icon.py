#!/usr/bin/env python3
"""Generates Oneiro's launcher icon source assets.

Original artwork (night-indigo field, amber crescent moon + four-point star,
matching lib/src/core/theme/app_theme.dart) drawn programmatically with
Pillow at 4x and downscaled for smooth edges.

Outputs:
  assets/icon/app_icon.png             1024x1024, the night field with the
                                       motif rendered exactly like Android's
                                       adaptive icon (used for the legacy
                                       launcher icon, the GitHub README logo
                                       and the fastlane store icon — so all
                                       three match the on-device look)
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

# How the launcher actually renders the adaptive icon: the foreground layer
# is drawn inset by 16% (mipmap-anydpi-v26/ic_launcher.xml), then the
# launcher zooms the composition ~1.74x and center-crops it into the icon
# shape. Net effect — verified against on-device screenshots on One UI — is
# the foreground canvas scaled to ~1.18x of the visible icon.
FOREGROUND_SCALE = 1.18

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "icon"


def compose(mono: bool = False) -> Image.Image:
    """The padded, transparent motif (adaptive-icon foreground layer)."""
    moon_color = (255, 255, 255, 255) if mono else MOON
    star_color = (255, 255, 255, 255) if mono else STAR
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    pad = 1.18  # adaptive icons get masked + scaled by the launcher

    moon_r = S * 0.30 / pad
    moon_cx = S * 0.46
    moon_cy = S * 0.54

    # Crescent moon: a full disc with the bite punched out of the alpha so
    # the field color shows through.
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

    # Sparkle star resting in the crescent's opening.
    star_r = S * 0.075 / pad
    draw_star_colored(draw, S * 0.62, S * 0.36, star_r, star_color)
    # A tiny companion star, upper left of the moon.
    draw_star_colored(draw, S * 0.30, S * 0.33, star_r * 0.45, star_color)

    return img.resize((SIZE, SIZE), Image.LANCZOS)


def adaptive_render(foreground: Image.Image) -> Image.Image:
    """Bakes what the launcher actually shows: the foreground motif on the
    night field, scaled and cropped the way launchers zoom adaptive icons
    (see FOREGROUND_SCALE). Used anywhere a non-adaptive icon is needed
    (legacy launcher densities, GitHub README, fastlane store icon) so every
    surface shows the same icon.
    """
    inner = int(SIZE * FOREGROUND_SCALE)
    motif = foreground.resize((inner, inner), Image.LANCZOS)
    canvas = Image.new("RGBA", (SIZE, SIZE), NIGHT)
    offset = (SIZE - inner) // 2
    canvas.alpha_composite(motif, (offset, offset))
    return canvas


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
    foreground = compose()
    foreground.save(OUT / "app_icon_foreground.png")
    compose(mono=True).save(OUT / "app_icon_monochrome.png")
    adaptive_render(foreground).save(OUT / "app_icon.png")
    print(f"wrote {OUT / 'app_icon.png'}")
    print(f"wrote {OUT / 'app_icon_foreground.png'}")
    print(f"wrote {OUT / 'app_icon_monochrome.png'}")


if __name__ == "__main__":
    main()
