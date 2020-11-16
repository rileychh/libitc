#!/usr/bin/env python

from argparse import ArgumentParser
from pathlib import Path
from typing import Tuple
from PIL import Image

frame_size = (128, 160)
mode = 'fill'
bg_color = (0, 0, 0)


def fill(im: Image.Image, size: Tuple[int, int]) -> Image.Image:
    aspect = im.width / im.height
    new_aspect = size[0] / size[1]

    if aspect > new_aspect:
        # Then crop the left and right edges:
        target_width = int(new_aspect * im.height)
        offset = (im.width - target_width) / 2
        new_box = (offset, 0, im.width - offset, im.height)
    else:
        # ... crop the top and bottom:
        target_height = int(im.width / new_aspect)
        offset = (im.height - target_height) / 2
        new_box = (0, offset, im.width, im.height - offset)

    return im.crop(new_box).resize(size)


def fit(im: Image.Image, size: Tuple[int, int], fill_color: Tuple[int, int, int]) -> Image.Image:
    resized = im.copy()
    resized.thumbnail(size)
    res = Image.new('RGB', size, fill_color)
    res.paste(resized, (int((size[0] - resized.width) / 2),
                        int((size[1] - resized.height) / 2)))
    return res


def pack(pixel: Tuple[int, int, int]) -> int:
    r, g, b = pixel
    return r << 16 | g << 8 | b


parser = ArgumentParser()
parser.add_argument('input_path', type=Path)
parser.add_argument('output_path', type=Path)
args = parser.parse_args()

im = Image.open(args.input_path).convert('RGB')

if mode == 'fill':
    im = fill(im, frame_size)
elif mode == 'fit':
    im = fit(im, frame_size, bg_color)

pixels = list(im.getdata())

mif_header = '''\
WIDTH=24;
DEPTH=20480;

ADDRESS_RADIX=UNS;
DATA_RADIX=HEX;

CONTENT BEGIN
'''

mif_footer = '''\
END;
'''

mif_data = ''.join(
    f'\t{i}: {"{:x}".format(pack(p))};\n' for i, p in enumerate(pixels))

args.output_path.write_text(mif_header + mif_data + mif_footer)
