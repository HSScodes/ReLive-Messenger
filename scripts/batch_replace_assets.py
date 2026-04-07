"""
Batch asset replacement script for WLM Project UI overhaul.
Processes AI-generated assets from assets_to_replace/New Assets:
  - Crops to content bounding box
  - Resizes to match original dimensions
  - Preserves/ensures RGBA transparency
  - Backs up originals and replaces them
"""

import os
import shutil
import sys
from PIL import Image
import numpy as np

PROJECT = r"C:\Users\PC\Desktop\WLM Project"
NEW_DIR = os.path.join(PROJECT, "assets_to_replace", "New Assets")
ASSETS_DIR = os.path.join(PROJECT, "assets", "images", "extracted", "msgsres")

# Mapping: (new_filename, original_filename, target_width, target_height, description)
REPLACEMENTS = [
    # Status icons (42x42 circles)
    ("new_new_carved_png_9375216.png", "carved_png_9375216.png", 42, 42, "Online status (green)"),
    ("new_carved_png_9380960.png",     "carved_png_9380960.png", 42, 42, "Away status (yellow)"),
    ("new_carved_png_9387680.png",     "carved_png_9387680.png", 42, 42, "Busy status (red)"),
    ("new_carved_png_9394296.png",     "carved_png_9394296.png", 42, 42, "Offline status (grey)"),
    # Small icons
    ("new_carved_png_9432408.png",     "carved_png_9432408.png", 16, 16, "Nudge icon"),
    ("new_carved_png_9727920.png",     "carved_png_9727920.png", 16, 16, "Help icon"),
    # Back button
    ("new_carved_png_10983152.png",    "carved_png_10983152.png", 50, 51, "Win7 back button"),
    # Chrome bar (wide, thin)
    ("new_carved_png_433248.png",      "carved_png_433248.png",  600, 31, "Chrome bar light"),
    # Default avatar placeholder
    ("new_new_carved_png_9801032.png", "carved_png_9801032.png",  96, 96, "Default user silhouette"),
    # Avatar frame (already processed but let's include the final version)
    ("aeroframe_139.png",             "carved_png_9812096.png", 139, 139, "Avatar frame"),
]


def crop_to_content(img, margin=2, alpha_threshold=10):
    """Crop image to bounding box of non-transparent pixels, with margin."""
    arr = np.array(img)
    if arr.shape[2] < 4:
        # No alpha channel - return as-is
        return img
    alpha = arr[:, :, 3]
    rows = np.any(alpha > alpha_threshold, axis=1)
    cols = np.any(alpha > alpha_threshold, axis=0)
    if not rows.any():
        return img
    rmin, rmax = np.where(rows)[0][[0, -1]]
    cmin, cmax = np.where(cols)[0][[0, -1]]
    # Add margin
    rmin = max(0, rmin - margin)
    rmax = min(arr.shape[0] - 1, rmax + margin)
    cmin = max(0, cmin - margin)
    cmax = min(arr.shape[1] - 1, cmax + margin)
    return img.crop((cmin, rmin, cmax + 1, rmax + 1))


def remove_solid_background(img, tolerance=30):
    """Remove white/light solid background via flood-fill from corners."""
    arr = np.array(img).copy()
    h, w = arr.shape[:2]

    # Sample corners to detect bg color
    corners = [(0, 0), (0, w-1), (h-1, 0), (h-1, w-1)]
    bg_colors = []
    for r, c in corners:
        bg_colors.append(arr[r, c, :3])

    # Use the most common corner color as bg
    from collections import Counter
    rounded = [tuple((v // 10) * 10 for v in c) for c in bg_colors]
    most_common = Counter(rounded).most_common(1)[0][0]

    # BFS flood fill from all 4 corners
    visited = np.zeros((h, w), dtype=bool)
    queue = []
    for r, c in corners:
        pix = arr[r, c, :3].astype(int)
        ref = np.array(most_common, dtype=int)
        if np.max(np.abs(pix - ref)) < tolerance:
            queue.append((r, c))

    cleared = 0
    while queue:
        batch = queue
        queue = []
        for r, c in batch:
            if r < 0 or r >= h or c < 0 or c >= w:
                continue
            if visited[r, c]:
                continue
            visited[r, c] = True
            pix = arr[r, c, :3].astype(int)
            ref = np.array(most_common, dtype=int)
            if np.max(np.abs(pix - ref)) < tolerance:
                arr[r, c, 3] = 0
                cleared += 1
                for dr, dc in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
                    nr, nc = r + dr, c + dc
                    if 0 <= nr < h and 0 <= nc < w and not visited[nr, nc]:
                        queue.append((nr, nc))

    print(f"    Flood-fill cleared {cleared} bg pixels")
    return Image.fromarray(arr)


def process_asset(new_name, orig_name, target_w, target_h, desc):
    """Process a single asset replacement."""
    new_path = os.path.join(NEW_DIR, new_name)
    orig_path = os.path.join(ASSETS_DIR, orig_name)

    if not os.path.exists(new_path):
        print(f"  SKIP {new_name}: file not found")
        return False

    print(f"\n  Processing: {desc}")
    print(f"    New: {new_name}")
    print(f"    Target: {orig_name} ({target_w}x{target_h})")

    # Load and ensure RGBA
    img = Image.open(new_path).convert("RGBA")
    print(f"    Source: {img.size[0]}x{img.size[1]}")

    # Check if background removal is needed (0% transparent = solid bg)
    arr = np.array(img)
    transparent_pct = (arr[:, :, 3] == 0).sum() / arr[:, :, 3].size * 100
    if transparent_pct < 5.0:
        print(f"    No transparency ({transparent_pct:.1f}%) - removing background...")
        img = remove_solid_background(img)

    # Crop to content
    cropped = crop_to_content(img)
    print(f"    After crop: {cropped.size[0]}x{cropped.size[1]}")

    # Make square if target is square and content is nearly square
    cw, ch = cropped.size
    if target_w == target_h and abs(cw - ch) < max(cw, ch) * 0.15:
        # Pad to square
        side = max(cw, ch)
        square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        square.paste(cropped, ((side - cw) // 2, (side - ch) // 2))
        cropped = square
        print(f"    Squared to: {side}x{side}")

    # Resize to target
    final = cropped.resize((target_w, target_h), Image.LANCZOS)
    print(f"    Resized to: {target_w}x{target_h}")

    # Verify
    final_arr = np.array(final)
    final_trans = (final_arr[:, :, 3] == 0).sum() / final_arr[:, :, 3].size * 100
    print(f"    Final transparency: {final_trans:.1f}%")

    # Backup original
    if os.path.exists(orig_path):
        bak_path = orig_path + ".bak"
        if not os.path.exists(bak_path):
            shutil.copy2(orig_path, bak_path)
            print(f"    Backed up original")

    # Save replacement
    final.save(orig_path, optimize=True)
    size_kb = os.path.getsize(orig_path) / 1024
    print(f"    Saved: {size_kb:.1f} KB")

    return True


def main():
    print("=" * 60)
    print("WLM Project - Batch Asset Replacement")
    print("=" * 60)

    success = 0
    skipped = 0
    failed = 0

    for new_name, orig_name, tw, th, desc in REPLACEMENTS:
        try:
            if process_asset(new_name, orig_name, tw, th, desc):
                success += 1
            else:
                skipped += 1
        except Exception as e:
            print(f"  FAILED {new_name}: {e}")
            import traceback
            traceback.print_exc()
            failed += 1

    print(f"\n{'=' * 60}")
    print(f"Results: {success} replaced, {skipped} skipped, {failed} failed")
    print(f"{'=' * 60}")


if __name__ == "__main__":
    main()
