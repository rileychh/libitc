#!/usr/bin/env python

import argparse
from PIL import Image
from pathlib import Path


def bmp(img_path: Path, new_width=128, new_height=160) -> Path:
    img = Image.open(img_path).convert('RGB') # open imaage as 24-bit color format
    aspect = img.width / img.height
    new_aspect = new_width / new_height

    if aspect > new_aspect:
        # Then crop the left and right edges:
        target_width = int(new_aspect * img.height)
        offset = (img.width - target_width) / 2
        new_box = (offset, 0, img.width - offset, img.height)
    else:
        # ... crop the top and bottom:
        target_height = int(img.width / new_aspect)
        offset = (img.height - target_height) / 2
        new_box = (0, offset, img.width, img.height - offset)

    new_img = img.crop(new_box).resize((new_width, new_height))

    new_img_path = img_path.parent / 'preview.bmp'
    new_img.save(new_img_path, format='bmp')
    return new_img_path

def mif(bmp_path: Path, mif_path: Path):
    header = '''\
WIDTH=16;
DEPTH=20480;

ADDRESS_RADIX=UNS;
DATA_RADIX=HEX;

CONTENT BEGIN
'''

    footer = '''\
END;
'''

    # get 24-bit pixels without header
    bitmap = bmp_path.read_bytes()[54:]
    # convert content into list of pixels
    pixels = [bitmap[i:i+3] for i in range(0, len(bitmap), 3)]
    # convert 24-bit color to 16-bit color
    pixels = [((p[0] & 0b11111000) << 8 | (p[1] & 0b11111100) << 3 | (p[2] & 0b11111000)).to_bytes(2, 'big') for p in pixels]
    # add syntax
    data = ''.join(f'\t{i}: {p.hex()};\n' for i, p in enumerate(pixels))
    mif_path.write_text(header + data + footer)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('input_path', type=Path)
    parser.add_argument('output_path', type=Path)
    args = parser.parse_args()

    mif(bmp(args.input_path), args.output_path)
