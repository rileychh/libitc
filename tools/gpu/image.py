from os import path

from genmif import ColorDepth, CropMode
from genmif import generate as gen_mif


# represent images in graphics.yml
class Image:
    def __init__(self, name: str, properties: dict, project_path: str):
        def with_fallback(properties: dict, key, fallback):
            return properties[key] if key in properties else fallback

        self.name = name
        self.path = path.normpath(path.join(project_path, properties["path"]))
        self.width = with_fallback(properties, "width", 128)
        self.height = with_fallback(properties, "height", 160)
        self.color_depth = ColorDepth(with_fallback(properties, "color_depth", 24))
        self.crop = CropMode(with_fallback(properties, "crop", "fill"))
        self.fit_background = with_fallback(properties, "fit_background", (0, 0, 0))

    def __str__(self):
        crop_verb = "in"
        if self.crop == CropMode.FILL:
            crop_verb = "fills"
        elif self.crop == CropMode.FIT:
            crop_verb = "fits"

        return f"{self.name}: {self.path} {crop_verb} {self.width}x{self.height} with {self.color_depth.value}-bit color"

    def generate(self, mif_path: str):
        with open(self.path, "rb") as image, open(mif_path, "w") as mif:
            gen_mif(
                size=(self.width, self.height),
                depth=self.color_depth,
                crop=self.crop,
                image=image,
                mif=mif,
                fit_background=self.fit_background,
            )
