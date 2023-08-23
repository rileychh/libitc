#!/usr/bin/env python

from argparse import ArgumentParser, FileType
from enum import Enum
from io import BufferedIOBase, TextIOBase
from typing import Union

from PIL import Image
from PIL.ImageColor import getrgb


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


def format_pixel(depth: int, pixel: Union[tuple[int, int, int], int]) -> str:
    if depth == 1:
        return "1" if pixel else "0"
    elif depth == 3:
        r, g, b = pixel
        return "{:x}".format((r >> 7) << 2 | (g >> 7) << 1 | b >> 7)
    elif depth == 8:
        r, g, b = pixel
        return "{:x}".format((r >> 5) << 5 | (g >> 5) << 2 | (b >> 6))
    else:
        r, g, b = pixel
        return "{:x}".format(r << 16 | g << 8 | b)


class CropMode(Enum):
    NONE = 0
    FILL = 1
    FIT = 2

    def __str__(self):
        if self == CropMode.NONE:
            return "in"
        elif self == CropMode.FILL:
            return "fills"
        elif self == CropMode.FIT:
            return "fits"

    def from_str(mode: str):
        if mode == "none":
            return CropMode.NONE
        elif mode == "fill":
            return CropMode.FILL
        elif mode == "fit":
            return CropMode.FIT
        else:
            raise ValueError(f"Invalid mode: {mode}")


def generate(
    size: tuple[int, int],
    depth: int,
    crop: CropMode,
    background: tuple[int, int, int],
    image: BufferedIOBase,
    mif: TextIOBase,
):
    im = Image.open(image).convert("RGB")

    if crop == CropMode.FIT:
        im = fit(im, size, background)
    elif crop == CropMode.FILL:
        im = fill(im, size)

    if depth == 1:
        im = im.convert("1")

    pixels = list(im.getdata())

    mif_header = f"""\
WIDTH={str(depth)};
DEPTH={len(pixels)};

ADDRESS_RADIX=UNS;
DATA_RADIX=HEX;

CONTENT BEGIN
"""

    mif_footer = """\
END;
"""

    mif_data = "".join(
        f"\t{i}: {format_pixel(depth, p)};\n" for i, p in enumerate(pixels)
    )
    mif.write(mif_header + mif_data + mif_footer)


if __name__ == "__main__":
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
    elif args.background is None:
        args.background = "#000"

    generate(
        size=args.size,
        depth=args.depth,
        crop=CropMode.from_str(args.crop),
        background=getrgb(args.background),
        image=args.image,
        mif=args.mif,
    )
