"""
Extract frames from login animation video with improved black background removal.
Uses luminance-based keying with better edge preservation.
"""
import cv2
import numpy as np
from PIL import Image
import os

VIDEO = r'C:\Users\PC\Desktop\WLM Project\Login animation\Generated Video April 07, 2026 - 5_55PM.mp4'
OUT_DIR = r'C:\Users\PC\Desktop\WLM Project\assets\images\extracted\login_anim'
os.makedirs(OUT_DIR, exist_ok=True)

cap = cv2.VideoCapture(VIDEO)
fps = cap.get(cv2.CAP_PROP_FPS)
total = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
w = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
h = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
print(f'Video: {w}x{h}, {fps} fps, {total} frames, duration={total/fps:.2f}s')

target_frames = 36
step = max(1, total // target_frames)

frames = []
idx = 0
saved = 0
while True:
    ret, frame = cap.read()
    if not ret:
        break
    if idx % step == 0 and saved < target_frames:
        rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)

        # Use max channel value for alpha (preserves colored pixels better)
        max_channel = np.max(rgb, axis=2).astype(np.float32)

        # Very low threshold - only truly black pixels become transparent
        threshold = 15

        # Create alpha: pixels brighter than threshold are opaque
        # Smooth transition for anti-aliasing
        alpha = np.clip((max_channel - threshold) / (60 - threshold) * 255, 0, 255).astype(np.uint8)

        # For pixels that are clearly part of the figure (bright), ensure full opacity
        bright_mask = max_channel > 80
        alpha[bright_mask] = 255

        # Create RGBA image
        rgba = np.dstack((rgb, alpha))

        img = Image.fromarray(rgba)

        # Crop to the content area (the buddy is centered in a 1280x720 frame)
        # Find bounding box of non-transparent content
        bbox = img.getbbox()
        if bbox:
            # Add a small margin
            margin = 10
            x1 = max(0, bbox[0] - margin)
            y1 = max(0, bbox[1] - margin)
            x2 = min(img.width, bbox[2] + margin)
            y2 = min(img.height, bbox[3] + margin)

            # Make it square (using the larger dimension)
            cw, ch = x2 - x1, y2 - y1
            size = max(cw, ch)
            cx, cy = (x1 + x2) // 2, (y1 + y2) // 2
            x1 = max(0, cx - size // 2)
            y1 = max(0, cy - size // 2)
            x2 = x1 + size
            y2 = y1 + size

            # Clamp
            if x2 > img.width:
                x2 = img.width
                x1 = max(0, x2 - size)
            if y2 > img.height:
                y2 = img.height
                y1 = max(0, y2 - size)

            img = img.crop((x1, y1, x2, y2))

        # Resize to 200x200 for app use
        img = img.resize((200, 200), Image.LANCZOS)

        outpath = os.path.join(OUT_DIR, f'frame_{saved:03d}.png')
        img.save(outpath, optimize=True)
        saved += 1
        frames.append(outpath)
    idx += 1

cap.release()
print(f'Extracted {saved} frames to {OUT_DIR}')

# Create sprite sheet
if frames:
    first = Image.open(frames[0])
    sw, sh = first.size
    sheet = Image.new('RGBA', (sw * len(frames), sh), (0, 0, 0, 0))
    for i, fp in enumerate(frames):
        f = Image.open(fp)
        sheet.paste(f, (i * sw, 0))
    sprite_path = os.path.join(OUT_DIR, 'sprite_sheet.png')
    sheet.save(sprite_path, optimize=True)
    print(f'Sprite sheet: {sheet.size[0]}x{sheet.size[1]} saved to {sprite_path}')
