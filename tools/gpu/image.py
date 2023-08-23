from enum import Enum

from genmif import CropMode


# represent images in graphics.yml
class Image:
    def __init__(self, name: str, properties: dict):
        def with_fallback(properties: dict, key, fallback):
            return properties[key] if key in properties else fallback

        self.name = name
        self.path = properties["path"]
        self.crop = CropMode.from_str(with_fallback(properties, "mode", "fill"))
        self.width = with_fallback(properties, "width", 128)
        self.height = with_fallback(properties, "height", 160)

    def __str__(self):
        return f"{self.name}: {self.path} {self.crop} {self.width}x{self.height}"
