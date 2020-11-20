#!/usr/bin/env python

from argparse import ArgumentParser, FileType
from io import BytesIO
from sys import stdin, stdout
from typing import Union
from PIL import Image
from PIL.ImageColor import getrgb

frame_size = (128, 160)


def fill(im: Image.Image, size: tuple[int, int]) -> Image.Image:
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


def fit(im: Image.Image, size: tuple[int, int], fill_color: tuple[int, int, int]) -> Image.Image:
    resized = im.copy()
    resized.thumbnail(size)
    res = Image.new('RGB', size, fill_color)
    res.paste(resized, ((size[0] - resized.width) //
                        2, (size[1] - resized.height) // 2))
    return res


parser = ArgumentParser()
parser.add_argument('input_file', nargs='?', default='-')
parser.add_argument('output_file', nargs='?',
                    type=FileType('w'), default=stdout)
mode_group = parser.add_mutually_exclusive_group()
mode_group.add_argument('-i', '--icon', action='store_true')
mode_group.add_argument('-f', '--fit', metavar='COLOR', default='', type=str)
parser.add_argument('-b', '--bicolor', action='store_true', default=False)
args = parser.parse_args()

buffer = BytesIO()
if args.input_file == '-':
    buffer.write(stdin.buffer.read())
else:
    buffer.write(open(args.input_file, 'rb').read())
im = Image.open(buffer).convert('RGB')

if args.fit:
    im = fit(im, frame_size, getrgb(args.fit))
elif not args.icon:
    im = fill(im, frame_size)

if args.bicolor:
    im = im.convert('1')

pixels = list(im.getdata())


def format_pixel(pixel: Union[tuple[int, int, int], int]) -> str:
    if args.bicolor:
        return '0' if pixel else '1'
    else:
        r, g, b = pixel
        return '{:x}'.format(r << 16 | g << 8 | b)


mif_header = f'''\
WIDTH={'1' if args.bicolor else '24'};
DEPTH={len(pixels)};

ADDRESS_RADIX=UNS;
DATA_RADIX=HEX;

CONTENT BEGIN
'''

mif_footer = '''\
END;
'''

mif_data = ''.join(
    f'\t{i}: {format_pixel(p)};\n' for i, p in enumerate(pixels))

args.output_file.write(mif_header + mif_data + mif_footer)
