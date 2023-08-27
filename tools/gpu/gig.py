# GPU Instruction Generator (GIG)

import argparse
import re
from os import getcwd, path
from typing import Optional

import yaml
from image import Image

default_filename = "graphics.yaml"

Constants = dict[str, str]
Images = list[Image]


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
    parser.add_argument(
        "-v", "--verbose", action="store_true", help="print additional information"
    )
    return parser.parse_args()


def load_config(
    project_path: str,
) -> tuple[Optional[Constants], Optional[Images]]:
    graphics_yaml_path = path.join(project_path, default_filename)

    if not path.isfile(graphics_yaml_path):
        raise FileNotFoundError(f"{default_filename} not found in {project_path}.")

    with open(graphics_yaml_path, "r") as graphics_yaml:
        graphics = yaml.load(graphics_yaml, Loader=yaml.Loader)

    constants = graphics["constants"] if "constants" in graphics else None

    def resolve(value: str):
        if type(value) is not str:
            return value

        pattern = r"\$(\w*)"  # words starting with $

        def replace(match: re.Match):
            return constants[match.group(1)]

        return re.sub(pattern, replace, value)

    images = None
    if "images" in graphics:
        images = []
        for name, properties in graphics["images"].items():
            resolved_properties = {k: resolve(v) for k, v in properties.items()}
            images.append(Image(name, resolved_properties, project_path))

    return (constants, images)


args = load_args()
constants, images = load_config(args.project)

if args.verbose:
    print(constants)
    print(*images, sep="\n")

for image in images:
    here = path.dirname(__file__)
    working_dir = getcwd()
    image.generate_mif()
    image.generate_qip()
    image.generate_vhd()
