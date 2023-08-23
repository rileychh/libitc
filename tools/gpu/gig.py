# GPU Instruction Generator (GIG)

import argparse
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


def load_config(graphics_yaml_path: str):
    if not path.isfile(graphics_yaml_path):
        raise FileNotFoundError(f"{default_filename} not found in {args.project}.")

    with open(graphics_yaml_path, "r") as graphics_yaml:
        graphics = yaml.load(graphics_yaml, Loader=yaml.Loader)

    constants = graphics["constants"]
    images = [
        Image(name, properties) for name, properties in graphics["images"].items()
    ]
    return (constants, images)

args = load_args()
graphics_yaml_path = path.join(args.project, default_filename)
constants, images = load_config(graphics_yaml_path)

print(constants, *images, sep="\n")
