#!/usr/bin/env python

from argparse import ArgumentParser, FileType
from io import BytesIO
from sys import stdin, stdout
from PIL import Image

frame_size = (128, 160)
mode = 'fill'  # fill or fit
bg_color = (255, 255, 255)
colored = True


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
    res.paste(resized, (int((size[0] - resized.width) / 2),
                        int((size[1] - resized.height) / 2)))
    return res


def pack(pixel: tuple[int, int, int]) -> int:
    r, g, b = pixel
    return r << 16 | g << 8 | b


parser = ArgumentParser()
parser.add_argument('input_file', nargs='?', default='-')
parser.add_argument('output_file', nargs='?',
                    type=FileType('w'), default=stdout)
parser.add_argument('-m', '--mode')
args = parser.parse_args()

buffer = BytesIO()
if args.input_file == '-':
    buffer.write(stdin.buffer.read())
else:
    buffer.write(open(args.input_file, 'rb').read())
im = Image.open(buffer).convert('RGB')

if mode == 'fill':
    im = fill(im, frame_size)
elif mode == 'fit':
    im = fit(im, frame_size, bg_color)


if colored:
    mif_header = '''\
    WIDTH=24;
    DEPTH=20480;

    ADDRESS_RADIX=UNS;
    DATA_RADIX=HEX;

    CONTENT BEGIN
    '''

    pixels = list(im.getdata())

    mif_data = ''.join(
        f'\t{i}: {"{:x}".format(pack(p))};\n' for i, p in enumerate(pixels))

else:
    mif_header = '''\
WIDTH=1;
DEPTH=20480;

ADDRESS_RADIX=UNS;
DATA_RADIX=HEX;

CONTENT BEGIN
'''

    im = im.convert('1')
    pixels = list(im.getdata())

    mif_data = ''.join(
        f'\t{i}: {"0" if p == 0 else "1"};\n' for i, p in enumerate(pixels))

mif_footer = '''\
END;
'''

args.output_file.write(mif_header + mif_data + mif_footer)
