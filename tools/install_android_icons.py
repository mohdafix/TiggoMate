import os
from PIL import Image

SRC_ICON = r"C:\Project\TiggoMate\j5-ev-dashboard\web\icon-1024.png"
RES_DIR = r"C:\Project\TiggoMate\app\android\app\src\main\res"

SIZES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192
}

def install():
    img = Image.open(SRC_ICON).convert("RGBA")
    for folder, size in SIZES.items():
        dst_folder = os.path.join(RES_DIR, folder)
        os.makedirs(dst_folder, exist_ok=True)
        dst_path = os.path.join(dst_folder, "ic_launcher.png")
        resized = img.resize((size, size), Image.Resampling.LANCZOS)
        resized.save(dst_path, "PNG")
        print(f"Saved {size}x{size} launcher icon to {dst_path}")

if __name__ == "__main__":
    install()
