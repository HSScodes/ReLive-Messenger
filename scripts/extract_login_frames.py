"""
Extract frames from the login animation video, remove black background,
and save as transparent PNGs for use as a sprite animation.
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

# We want ~24-30 frames for a smooth loop (keep it reasonable for app size)
# Sample evenly across the full video
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
        # Convert BGR to RGBA, make black pixels transparent
        rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)

        # Calculate brightness to determine alpha
        # Black background: low brightness = transparent
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)

        # Use a threshold approach: pixels darker than threshold become transparent
        # Use smooth alpha based on brightness for anti-aliased edges
        alpha = gray.copy().astype(np.float32)

        # Boost the alpha curve so the buddy figure stays solid
        # but black background fades out
        threshold = 30
        alpha = np.clip((alpha - threshold) * (255.0 / (255 - threshold)), 0, 255).astype(np.uint8)

        # Create RGBA image
        rgba = np.dstack((rgb, alpha))

        img = Image.fromarray(rgba)
        # Resize to 200x200 for app use
        img = img.resize((200, 200), Image.LANCZOS)

        outpath = os.path.join(OUT_DIR, f'frame_{saved:03d}.png')
        img.save(outpath, optimize=True)
        saved += 1
        frames.append(outpath)
    idx += 1

cap.release()
print(f'Extracted {saved} frames to {OUT_DIR}')

# Also create a quick sprite sheet (single row)
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
