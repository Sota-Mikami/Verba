#!/usr/bin/env python3
"""Generate macOS app icons for Verba with microphone + sound waves design."""

from PIL import Image, ImageDraw
import math
import os

OUTPUT_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "Verba", "Assets.xcassets", "AppIcon.appiconset"
)

# Brand colors
BG_TOP_LEFT = (0x15, 0x14, 0x1a)
BG_BOTTOM_RIGHT = (0x0c, 0x0b, 0x0f)
MIC_COLOR = (0xed, 0xe8, 0xe1)
WAVE_COLOR = (0x7c, 0x6c, 0xfc)
GLOW_COLOR = (0xf0, 0xa0, 0x60)

# Icon sizes: (filename_base, pixel_size)
ICON_SIZES = [
    ("icon_16x16", 16),
    ("icon_16x16@2x", 32),
    ("icon_32x32", 32),
    ("icon_32x32@2x", 64),
    ("icon_128x128", 128),
    ("icon_128x128@2x", 256),
    ("icon_256x256", 256),
    ("icon_256x256@2x", 512),
    ("icon_512x512", 512),
    ("icon_512x512@2x", 1024),
]


def lerp_color(c1, c2, t):
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3))


def draw_gradient_bg(img, size):
    """Draw diagonal gradient background."""
    pixels = img.load()
    for y in range(size):
        for x in range(size):
            # Diagonal gradient: top-left to bottom-right
            t = (x / size + y / size) / 2.0
            c = lerp_color(BG_TOP_LEFT, BG_BOTTOM_RIGHT, t)
            pixels[x, y] = c + (255,)


def make_superellipse_mask(size, radius_fraction=0.2237):
    """Create macOS-style superellipse (squircle) mask."""
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    r = int(size * radius_fraction)
    # Use rounded_rectangle for the mask
    draw.rounded_rectangle([0, 0, size - 1, size - 1], radius=r, fill=255)
    return mask


def draw_arc_wave(draw, cx, cy, radius, start_angle, end_angle, color_rgba, width):
    """Draw an arc (sound wave) as a series of line segments for antialiasing."""
    steps = max(40, int(radius * 0.8))
    points = []
    for i in range(steps + 1):
        t = i / steps
        angle = math.radians(start_angle + (end_angle - start_angle) * t)
        px = cx + radius * math.cos(angle)
        py = cy - radius * math.sin(angle)
        points.append((px, py))

    # Draw as connected line segments
    for i in range(len(points) - 1):
        draw.line([points[i], points[i + 1]], fill=color_rgba, width=width)


def generate_icon(size):
    """Generate a single icon at the given pixel size."""
    # Use 4x supersampling for antialiasing
    ss = 4
    s = size * ss

    # Create RGBA image
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    draw_gradient_bg(img, s)
    draw = ImageDraw.Draw(img, "RGBA")

    cx = s / 2
    cy = s / 2

    # --- Subtle warm glow behind mic ---
    glow_radius = s * 0.18
    for r_step in range(int(glow_radius), 0, -1):
        frac = r_step / glow_radius
        alpha = int(22 * (1 - frac ** 1.5))  # ~8-9% max, soft falloff
        glow_c = GLOW_COLOR + (alpha,)
        bbox = [cx - r_step, cy - r_step * 0.85, cx + r_step, cy + r_step * 0.85]
        draw.ellipse(bbox, fill=glow_c)

    # --- Microphone dimensions (relative to icon size) ---
    mic_head_w = s * 0.14  # half-width of capsule
    mic_head_h = s * 0.18  # half-height of capsule
    mic_head_cy = cy - s * 0.06  # center of head, slightly above center

    # Mic line width
    lw = max(1, int(s * 0.025))
    arm_lw = max(1, int(s * 0.02))

    # --- Draw microphone head (capsule / rounded rectangle) ---
    head_bbox = [
        cx - mic_head_w, mic_head_cy - mic_head_h,
        cx + mic_head_w, mic_head_cy + mic_head_h,
    ]
    head_corner = min(int(mic_head_w * 0.95), int(mic_head_w - lw))
    head_corner = max(1, head_corner)
    draw.rounded_rectangle(head_bbox, radius=head_corner, outline=MIC_COLOR + (255,), width=lw)

    # Fill the head with slight transparency to add body
    fill_alpha = 40
    draw.rounded_rectangle(head_bbox, radius=head_corner, fill=MIC_COLOR + (fill_alpha,))

    # --- Mic grill lines inside the head ---
    grill_count = 4
    grill_top = mic_head_cy - mic_head_h * 0.5
    grill_bot = mic_head_cy + mic_head_h * 0.5
    grill_lw = max(1, int(s * 0.008))
    for i in range(grill_count):
        t = (i + 1) / (grill_count + 1)
        gy = grill_top + (grill_bot - grill_top) * t
        # Calculate width at this y position (elliptical)
        dy = (gy - mic_head_cy) / mic_head_h
        grill_half_w = mic_head_w * 0.7 * math.sqrt(max(0, 1 - dy * dy))
        draw.line(
            [(cx - grill_half_w, gy), (cx + grill_half_w, gy)],
            fill=MIC_COLOR + (60,), width=grill_lw
        )

    # --- Curved arms (U-shape below mic head) ---
    arm_radius_x = mic_head_w * 1.4
    arm_radius_y = s * 0.10
    arm_cy = mic_head_cy + mic_head_h + arm_radius_y * 0.15

    # Draw the U-shaped arm as an arc
    arm_steps = 50
    arm_points = []
    for i in range(arm_steps + 1):
        t = i / arm_steps
        angle = math.pi * t  # 0 to pi (half circle, opening upward)
        px = cx + arm_radius_x * math.cos(angle)
        py = arm_cy + arm_radius_y * math.sin(angle)
        arm_points.append((px, py))

    for i in range(len(arm_points) - 1):
        draw.line([arm_points[i], arm_points[i + 1]], fill=MIC_COLOR + (255,), width=arm_lw)

    # --- Vertical stem ---
    stem_top = arm_cy + arm_radius_y
    stem_bot = stem_top + s * 0.08
    draw.line([(cx, stem_top), (cx, stem_bot)], fill=MIC_COLOR + (255,), width=arm_lw)

    # --- Horizontal base ---
    base_half = mic_head_w * 0.9
    draw.line(
        [(cx - base_half, stem_bot), (cx + base_half, stem_bot)],
        fill=MIC_COLOR + (255,), width=arm_lw
    )

    # --- Sound wave arcs ---
    # Determine how many waves based on target size
    if size <= 32:
        num_waves = 1
    elif size <= 64:
        num_waves = 2
    else:
        num_waves = 3

    wave_base_radius = mic_head_w * 1.8
    wave_spacing = s * 0.065

    for i in range(num_waves):
        radius = wave_base_radius + wave_spacing * (i + 1)
        # Opacity decreases for outer waves
        alpha = int(255 * (1.0 - i * 0.3))
        wave_lw = max(1, int(s * 0.02 * (1.0 - i * 0.15)))
        color = WAVE_COLOR + (alpha,)

        # Right side arcs (roughly -50 to 50 degrees from horizontal right)
        draw_arc_wave(draw, cx, mic_head_cy, radius, -45, 45, color, wave_lw)
        # Left side arcs
        draw_arc_wave(draw, cx, mic_head_cy, radius, 135, 225, color, wave_lw)

    # --- Apply superellipse mask ---
    mask = make_superellipse_mask(s)
    img.putalpha(mask)

    # --- Downsample with high-quality resampling ---
    img = img.resize((size, size), Image.LANCZOS)

    return img


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    for name, px_size in ICON_SIZES:
        filename = f"{name}.png"
        filepath = os.path.join(OUTPUT_DIR, filename)
        print(f"Generating {filename} ({px_size}x{px_size})...")
        icon = generate_icon(px_size)
        icon.save(filepath, "PNG")
        print(f"  Saved: {filepath}")

    print("\nAll icons generated successfully!")


if __name__ == "__main__":
    main()
