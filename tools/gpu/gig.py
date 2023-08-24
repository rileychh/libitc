# GPU Instruction Generator (GIG)

import argparse
import re
from os import path

import yaml
from image import Image

default_filename = "graphics.yml"


def load_args():
    def dir_path(string):
        if path.isdir(string):
            return string
        else:
            raise NotADirectoryError(string)

    parser = argparse.ArgumentParser()
    parser.add_argument(
        "project", type=dir_path, help=f"directory containing {default_filename}"
    )
    parser.add_argument(
        "-o", "--overwrite", action="store_true", help="allow overwrite existing files"
    )
    return parser.parse_args()


def load_config(graphics_yaml_path: str) -> tuple[dict[str, str], list[Image]]:
    if not path.isfile(graphics_yaml_path):
        raise FileNotFoundError(f"{default_filename} not found in {args.project}.")

    with open(graphics_yaml_path, "r") as graphics_yaml:
        graphics = yaml.load(graphics_yaml, Loader=yaml.Loader)

    constants = graphics["constants"]

    def resolve(value: str):
        if type(value) is not str:
            return value

        pattern = r"\$(\w*)"  # words starting with $
        def replace(match: re.Match):
            return constants[match.group(1)]

        return re.sub(pattern, replace, value)

    images = []
    for name, properties in graphics["images"].items():
        resolved_properties = {k: resolve(v) for k, v in properties.items()}
        images.append(Image(name, resolved_properties))

    return (constants, images)


args = load_args()
graphics_yaml_path = path.join(args.project, default_filename)
constants, images = load_config(graphics_yaml_path)

print(constants, *images, sep="\n")

for image in images:
    image.generate(path.join(args.project, f"{image.name}.mif"))
