"""Pack generated Alchemist Prince / Colossus animation cells into the game's 128px strips.

Only chroma extraction, cell cutting, size/anchor normalization and packing.
All poses come from the generated source images, never shifted copies of a pose.
Run from the repository: python tools/pack_alchemist_sprites.py
"""
from pathlib import Path
import json
import hashlib
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'artifacts' / 'alchemist_prince'
ATLAS_PRINCE = SOURCE / 'alchemist_prince_action_atlas.png'
ATLAS_COLOSSUS = SOURCE / 'alchemist_colossus_action_atlas.png'
DEST_PRINCE = ROOT / 'assets' / 'sprites' / 'boss' / 'alchemist_prince'
DEST_COLOSSUS = ROOT / 'assets' / 'sprites' / 'boss' / 'alchemist_colossus'


def key_green(image):
    data = np.array(image.convert('RGBA'), dtype=np.uint8)
    rgb = data[:, :, :3].astype(np.int16)
    # Green-screen only: dark-gold robe, bronze plates and the amber potion glow are retained.
    green = (rgb[:, :, 1] > rgb[:, :, 0] + 25) & (rgb[:, :, 1] > rgb[:, :, 2] + 25)
    data[green] = 0
    return Image.fromarray(data)

def row_edges(image, count):
    alpha = np.array(image.getchannel('A'))
    occupied = (alpha > 32).sum(axis=1)
    step = image.height / count
    edges = [0]
    for row in range(1, count):
        center = round(row * step)
        radius = round(step * 0.09)
        start, end = center - radius, center + radius
        minimum = occupied[start:end].min()
        candidates = np.flatnonzero(occupied[start:end] == minimum) + start
        edges.append(int(min(candidates, key=lambda value: abs(value - center))))
    return edges + [image.height]

def cells(image, columns, rows):
    edges = row_edges(image, rows)
    result = []
    for row in range(rows):
        row_cells = []
        for col in range(columns):
            frame = image.crop((round(col * image.width / columns), edges[row], round((col + 1) * image.width / columns), edges[row + 1]))
            data = np.array(frame)
            counts = (data[:, :, 3] > 32).sum(axis=1)
            occupied = np.flatnonzero(counts)
            # Remove only tiny neighbouring-row fragments at the crop boundary.
            # Keep interior particles and every character pose untouched.
            if len(occupied):
                groups = np.split(occupied, np.flatnonzero(np.diff(occupied) > 1) + 1)
                total = counts.sum()
                for group in groups:
                    near_edge = group[-1] < frame.height * 0.12 or group[0] > frame.height * 0.88
                    if near_edge and counts[group].sum() < total * 0.012:
                        data[group, :, :] = 0
            row_cells.append(Image.fromarray(data))
        result.append(row_cells)
    return result

def pack(frames, name, dest, scale=None):
    boxes = [frame.getchannel('A').getbbox() for frame in frames]
    if any(box is None for box in boxes):
        raise ValueError('Empty animation cell: ' + name)
    if scale is None:
        max_height = max(b[3] - b[1] for b in boxes)
        max_width = max(b[2] - b[0] for b in boxes)
        scale = min(108 / max_height, 116 / max_width)
    strip = Image.new('RGBA', (128 * 6, 128))
    packed = []
    for index, (frame, box) in enumerate(zip(frames, boxes)):
        body = frame.crop(box)
        body = body.resize((max(1, round(body.width * scale)), max(1, round(body.height * scale))), Image.Resampling.NEAREST)
        # Baseline normalization prevents generated cell spacing from becoming jitter.
        cell = Image.new('RGBA', (128, 128))
        center_shift = (box[0] + box[2] - frame.width) * 0.5 * scale
        x = round((128 - body.width) * 0.5 + center_shift)
        x = max(3, min(x, 125 - body.width))
        y = 119 - body.height
        if y < 1 or body.width > 122:
            raise ValueError('Sprite exceeds safe cell: ' + name)
        cell.alpha_composite(body, (x, y))
        strip.alpha_composite(cell, (index * 128, 0))
        packed.append(cell)
    output = dest / (name + '.png')
    strip.save(output)
    return packed, scale

def pack_atlas(source_path, dest, actions, keyed_name, sheet_name, manifest_name):
    dest.mkdir(parents=True, exist_ok=True)
    keyed = key_green(Image.open(source_path))
    keyed.save(SOURCE / keyed_name)
    atlas_rows = cells(keyed, 6, 5)
    all_frames = {}
    base_scale = None
    for row, name in enumerate(actions):
        frames, scale = pack(atlas_rows[row], name, dest, base_scale if name == 'death' else None)
        if name == 'idle':
            base_scale = scale
        all_frames[name] = frames
    preview = Image.new('RGB', (960, len(all_frames) * 144 + 32), '#12151d')
    draw = ImageDraw.Draw(preview)
    for row, (name, frames) in enumerate(all_frames.items()):
        draw.text((12, 44 + row * 144), name, fill='#ddd5bf')
        for i, frame in enumerate(frames):
            preview.paste(frame, (184 + i * 128, 32 + row * 144), frame)
    preview.save(SOURCE / sheet_name)
    manifest = {'source_sha256': hashlib.sha256(source_path.read_bytes()).hexdigest(), 'cell_size': 128, 'frames_per_action': 6, 'actions': {name: {'path': str((dest / (name + '.png')).relative_to(ROOT)).replace('\\', '/'), 'unique_frames': len({frame.tobytes() for frame in frames})} for name, frames in all_frames.items()}}
    (SOURCE / manifest_name).write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
    return manifest

def main():
    manifest_prince = pack_atlas(
        ATLAS_PRINCE, DEST_PRINCE,
        ['idle', 'move', 'cast', 'solo_shift', 'death'],
        'alchemist_prince_action_atlas_keyed.png',
        'alchemist_prince_contact_sheet.png',
        'asset_manifest_prince.json',
    )
    manifest_colossus = pack_atlas(
        ATLAS_COLOSSUS, DEST_COLOSSUS,
        ['idle', 'move', 'slam', 'enrage', 'death'],
        'alchemist_colossus_action_atlas_keyed.png',
        'alchemist_colossus_contact_sheet.png',
        'asset_manifest_colossus.json',
    )
    print(json.dumps({'alchemist_prince': manifest_prince, 'alchemist_colossus': manifest_colossus}, ensure_ascii=False, indent=2))

if __name__ == '__main__':
    main()
