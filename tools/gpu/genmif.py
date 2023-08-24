#!/usr/bin/env python

from argparse import ArgumentParser, FileType
from enum import Enum
from io import BufferedIOBase, TextIOBase
from os import path
from typing import Optional

from mako.template import Template
from PIL import Image
from PIL.ImageColor import getrgb


class CropMode(Enum):
    NONE = "none"
    FILL = "fill"
    FIT = "fit"


class ColorDepth(Enum):
    BINARY = 1
    BASIC = 3  # 1 bit of R, G, and B
    COMPACT = 8  # 3 bits of R and G, 2 bits of B
    TRUE_COLOR = 24  # 8 bits of R, G, and B


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
    im: Image.Image, size: tuple[int, int], background: tuple[int, int, int] = None
) -> Image.Image:
    resized = im.copy()
    resized.thumbnail(size)
    res = Image.new("RGB", size, background if background is not None else (0, 0, 0))
    res.paste(
        resized, ((size[0] - resized.width) // 2, (size[1] - resized.height) // 2)
    )
    return res


def generate(
    size: tuple[int, int],
    depth: ColorDepth,
    crop: CropMode,
    image: BufferedIOBase,
    mif: TextIOBase,
    fit_background: Optional[tuple[int, int, int]] = None,
):
    im = Image.open(image).convert("RGB")

    if crop == CropMode.FIT:
        im = fit(im, size, fit_background)
    elif crop == CropMode.FILL:
        im = fill(im, size)

    if depth == ColorDepth.BINARY:
        im = im.convert("1")

    pixels = list(im.getdata())

    script_path = path.dirname(__file__)
    template = Template(filename=path.join(script_path, "templates/image.template.mif"))
    mif.write(
        template.render(
            width=depth.value,
            depth=len(pixels),
            pixels=pixels,
        )
    )


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

    generate(
        size=args.size,
        depth=ColorDepth(args.depth),
        crop=CropMode(args.crop),
        image=args.image,
        mif=args.mif,
        fit_background=getrgb(args.background) if args.background is not None else None,
    )
