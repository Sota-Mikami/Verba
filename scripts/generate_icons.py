#!/usr/bin/env python3
"""Generate macOS app icons for Verba - clean, minimal Linear/Raycast style."""

from PIL import Image, ImageDraw
import os

# --- Config ---
RENDER_SIZE = 1024 * 4  # 4x supersampling
CORNER_RATIO = 0.2237   # macOS superellipse

THEMES = {
    "release": {
        "bg": "#0c0b0f",
        "mic": "#ede8e1",
        "wave": "#7c6cfc",
    },
    "dev": {
        "bg": "#4a4a4a",
        "mic": "#e0e0e0",
        "wave": "#b0b0b0",
    },
}

SIZES = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]

BASE = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "Verba", "Assets.xcassets",
)
DIRS = {
    "release": os.path.join(BASE, "AppIcon.appiconset"),
    "dev": os.path.join(BASE, "AppIconDev.appiconset"),
}


def hex_to_rgba(h, alpha=255):
    h = h.lstrip("#")
    r, g, b = (int(h[i:i+2], 16) for i in (0, 2, 4))
    return (r, g, b, alpha)


def render_icon(theme):
    """Render icon at RENDER_SIZE, return the full-res image."""
    S = RENDER_SIZE
    colors = THEMES[theme]
    bg = hex_to_rgba(colors["bg"])
    mic = hex_to_rgba(colors["mic"])
    wave_rgb = hex_to_rgba(colors["wave"])

    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img, "RGBA")

    # Background with superellipse corners
    corner_r = int(S * CORNER_RATIO)
    draw.rounded_rectangle([0, 0, S - 1, S - 1], radius=corner_r, fill=bg)

    cx = S // 2
    cy = S // 2

    # --- Microphone head (capsule/pill) ---
    head_w = int(S * 0.22)
    head_h = int(S * 0.30)
    head_radius = head_w // 2  # fully rounded ends for pill shape
    head_cy = cy - int(S * 0.04)  # slightly above center

    head_bbox = [
        cx - head_w // 2,
        head_cy - head_h // 2,
        cx + head_w // 2,
        head_cy + head_h // 2,
    ]
    draw.rounded_rectangle(head_bbox, radius=head_radius, fill=mic)

    # --- U-shaped cradle ---
    stroke = int(S * 0.028)
    cradle_w = int(head_w * 1.45)
    cradle_radius = cradle_w // 2
    cradle_cy = head_cy + int(head_h * 0.12)

    # Semicircle arc (bottom half)
    cradle_bbox = [
        cx - cradle_radius,
        cradle_cy - cradle_radius,
        cx + cradle_radius,
        cradle_cy + cradle_radius,
    ]
    draw.arc(cradle_bbox, start=0, end=180, fill=mic, width=stroke)

    # Vertical arms extending upward from the arc endpoints
    arm_top = head_cy - int(head_h * 0.05)
    arm_bottom = cradle_cy
    # Left arm
    draw.line(
        [(cx - cradle_radius, arm_top), (cx - cradle_radius, arm_bottom)],
        fill=mic, width=stroke,
    )
    # Right arm
    draw.line(
        [(cx + cradle_radius, arm_top), (cx + cradle_radius, arm_bottom)],
        fill=mic, width=stroke,
    )

    # --- Vertical stem ---
    stem_top = cradle_cy + cradle_radius
    stem_bottom = stem_top + int(S * 0.10)
    draw.line(
        [(cx, stem_top), (cx, stem_bottom)],
        fill=mic, width=stroke,
    )

    # --- Sound wave arcs (2 on each side) ---
    wave_stroke = int(S * 0.025)
    wave_center_y = head_cy
    arc_span = 60  # degrees

    inner_gap = int(S * 0.08)
    inner_radius = head_w // 2 + inner_gap
    inner_color = hex_to_rgba(colors["wave"], int(255 * 0.85))

    outer_gap = int(S * 0.05)
    outer_radius = inner_radius + outer_gap + wave_stroke
    outer_color = hex_to_rgba(colors["wave"], int(255 * 0.50))

    # Right side: arcs centered at 0 degrees (3 o'clock)
    right_start = 360 - arc_span // 2  # 330
    right_end = arc_span // 2          # 30

    # Left side: arcs centered at 180 degrees
    left_start = 180 - arc_span // 2   # 150
    left_end = 180 + arc_span // 2     # 210

    for radius, color in [(inner_radius, inner_color), (outer_radius, outer_color)]:
        bbox = [
            cx - radius,
            wave_center_y - radius,
            cx + radius,
            wave_center_y + radius,
        ]
        draw.arc(bbox, start=right_start, end=right_end, fill=color, width=wave_stroke)
        draw.arc(bbox, start=left_start, end=left_end, fill=color, width=wave_stroke)

    # Apply superellipse mask for clean edges
    mask = Image.new("L", (S, S), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle([0, 0, S - 1, S - 1], radius=corner_r, fill=255)

    final = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    final.paste(img, mask=mask)

    return final


def main():
    for theme in ["release", "dev"]:
        out_dir = DIRS[theme]
        os.makedirs(out_dir, exist_ok=True)
        print(f"\n--- {theme.upper()} icons ---")

        # Render once at full size, then downscale for each target
        full = render_icon(theme)

        for px, filename in SIZES:
            if px == RENDER_SIZE:
                icon = full.copy()
            else:
                icon = full.resize((px, px), Image.LANCZOS)
            path = os.path.join(out_dir, filename)
            icon.save(path, "PNG")
            file_size = os.path.getsize(path)
            print(f"  {filename:30s} {px:4d}x{px:<4d}  {file_size:>8,} bytes")

    print("\nDone!")


if __name__ == "__main__":
    main()
