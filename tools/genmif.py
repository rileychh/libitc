#!/usr/bin/env python

from argparse import ArgumentParser
from pathlib import Path
from typing import Tuple
from PIL import Image


def fill(im: Image.Image, width: int, height: int) -> Image.Image:
    aspect = im.width / im.height
    new_aspect = width / height

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

    return im.crop(new_box).resize((width, height))


def rgb565(pixel: Tuple[int, int, int]) -> int:
    r, g, b = pixel
    return (b >> 3) << 11 | (r >> 2) << 5 | (g >> 3)
    # return (r >> 3) << 11 | (g >> 2) << 5 | (b >> 3)


parser = ArgumentParser()
parser.add_argument('input_path', type=Path)
parser.add_argument('output_path', type=Path)
args = parser.parse_args()

im = fill(Image.open(args.input_path), 128, 160).convert('RGB')
# im.show()
pixels = list(im.getdata())

mif_header = '''\
WIDTH=16;
DEPTH=20480;

ADDRESS_RADIX=UNS;
DATA_RADIX=HEX;

CONTENT BEGIN
'''

mif_footer = '''\
END;
'''

mif_data = ''.join(
    f'\t{i}: {"{:x}".format(rgb565(p))};\n' for i, p in enumerate(pixels))

args.output_path.write_text(mif_header + mif_data + mif_footer)
