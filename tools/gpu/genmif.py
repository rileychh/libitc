#!/usr/bin/env python

from argparse import ArgumentParser, FileType
from typing import Union

from PIL import Image
from PIL.ImageColor import getrgb


def load_args():
    parser = ArgumentParser()

    parser.add_argument(
        "-s",
        "--size",
        type=int,
        nargs=2,
        metavar=("WIDTH", "HEIGHT"),
        default=(128, 160),
        help="size of the MIF file, default is 128x160",
    )
    parser.add_argument(
        "-d",
        "--depth",
        type=int,
        choices=[1, 3, 8, 24],
        default=24,
        help="color depth, default is 24",
    )
    parser.add_argument(
        "-c",
        "--crop",
        choices=["none", "fill", "fit"],
        default="fill",
        help="crop mode, default is fill",
    )
    parser.add_argument(
        "-b",
        "--background",
        metavar="COLOR",
        help='background color when crop mode is "fit", default is black ("#000")',
    )
    parser.add_argument("image", type=FileType("rb"), help="input path to image file")
    parser.add_argument("mif", type=FileType("w"), help="output path to MIF file")
    args = parser.parse_args()

    if args.crop != "fit" and args.background is not None:
        parser.error("background color is only used when crop mode is fit")
    elif args.crop == "fit" and args.background is None:
        args.background = "#000"
    return args


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


def fit(
    im: Image.Image, size: tuple[int, int], fill_color: tuple[int, int, int]
) -> Image.Image:
    resized = im.copy()
    resized.thumbnail(size)
    res = Image.new("RGB", size, fill_color)
    res.paste(
        resized, ((size[0] - resized.width) // 2, (size[1] - resized.height) // 2)
    )
    return res


def format_pixel(pixel: Union[tuple[int, int, int], int]) -> str:
    if args.depth == 1:
        return "1" if pixel else "0"
    elif args.depth == 3:
        r, g, b = pixel
        return "{:x}".format((r >> 7) << 2 | (g >> 7) << 1 | b >> 7)
    elif args.depth == 8:
        r, g, b = pixel
        return "{:x}".format((r >> 5) << 5 | (g >> 5) << 2 | (b >> 6))
    else:
        r, g, b = pixel
        return "{:x}".format(r << 16 | g << 8 | b)


args = load_args()
im = Image.open(args.image).convert("RGB")

if args.crop == "fit":
    im = fit(im, args.size, getrgb(args.background))
elif args.crop == "fill":
    im = fill(im, args.size)

if args.depth == 1:
    im = im.convert("1")

pixels = list(im.getdata())

mif_header = f"""\
WIDTH={str(args.depth)};
DEPTH={len(pixels)};

ADDRESS_RADIX=UNS;
DATA_RADIX=HEX;

CONTENT BEGIN
"""

mif_footer = """\
END;
"""

mif_data = "".join(f"\t{i}: {format_pixel(p)};\n" for i, p in enumerate(pixels))
args.mif.write(mif_header + mif_data + mif_footer)
