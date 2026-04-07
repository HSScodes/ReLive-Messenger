"""
Remove white background from avatar frame PNG.
Flood-fills from corners (outside) and center (inside) to make
connected white/near-white regions transparent, preserving the
frame's own highlights and glossy edges.
"""
from PIL import Image
import numpy as np
from collections import deque
import sys
import os

def flood_fill_transparent(pixels, w, h, start_x, start_y, tolerance=45):
    """BFS flood fill: make connected white-ish pixels transparent."""
    sr, sg, sb, sa = pixels[start_y, start_x]
    # Only proceed if starting pixel is white-ish
    if sr < 200 or sg < 200 or sb < 200:
        print(f"  Skip ({start_x},{start_y}): pixel=({sr},{sg},{sb}) not white enough")
        return 0

    visited = np.zeros((h, w), dtype=bool)
    queue = deque([(start_x, start_y)])
    visited[start_y, start_x] = True
    count = 0

    while queue:
        x, y = queue.popleft()
        r, g, b, a = pixels[y, x]

        # Check if pixel is white-ish (all channels high, close to each other)
        if r >= 200 and g >= 200 and b >= 200 and a > 0:
            # Also check it's not too saturated (i.e. actually white, not colored)
            max_diff = int(max(r, g, b)) - int(min(r, g, b))
            if max_diff < tolerance:
                pixels[y, x] = (r, g, b, 0)  # Make transparent
                count += 1

                # Add neighbors
                for nx, ny in [(x+1, y), (x-1, y), (x, y+1), (x, y-1)]:
                    if 0 <= nx < w and 0 <= ny < h and not visited[ny, nx]:
                        visited[ny, nx] = True
                        queue.append((nx, ny))

    return count


def process(input_path, output_path):
    img = Image.open(input_path).convert('RGBA')
    w, h = img.size
    pixels = np.array(img)

    print(f"Image: {w}x{h}")

    # Flood fill from corners (outside white background)
    corners = [(0, 0), (w-1, 0), (0, h-1), (w-1, h-1)]
    for cx, cy in corners:
        n = flood_fill_transparent(pixels, w, h, cx, cy, tolerance=45)
        print(f"  Corner ({cx},{cy}): {n} pixels cleared")

    # Flood fill from center (inside the frame)
    cx, cy = w // 2, h // 2
    n = flood_fill_transparent(pixels, w, h, cx, cy, tolerance=45)
    print(f"  Center ({cx},{cy}): {n} pixels cleared")

    # Also try a few more interior points in case center lands on frame edge
    for dx, dy in [(-30, -30), (30, 30), (-30, 30), (30, -30), (0, -20), (0, 20)]:
        tx, ty = cx + dx, cy + dy
        if 0 <= tx < w and 0 <= ty < h:
            n = flood_fill_transparent(pixels, w, h, tx, ty, tolerance=45)
            if n > 0:
                print(f"  Interior ({tx},{ty}): {n} pixels cleared")

    result = Image.fromarray(pixels)
    result.save(output_path)
    print(f"Saved: {output_path} ({os.path.getsize(output_path)} bytes)")


if __name__ == '__main__':
    input_file = sys.argv[1] if len(sys.argv) > 1 else r"C:\Users\PC\Downloads\aeroframe.png"
    output_file = sys.argv[2] if len(sys.argv) > 2 else r"C:\Users\PC\Desktop\WLM Project\assets_to_replace\aeroframe_transparent.png"
    process(input_file, output_file)
