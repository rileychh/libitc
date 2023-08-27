from os import getcwd, path

from genmif import ColorDepth, CropMode
from genmif import generate as gen_mif
from mako.template import Template

here = path.dirname(__file__)
working_dir = getcwd()


# represent images in graphics.yaml
class Image:
    def __init__(self, name: str, properties: dict, project_path: str):
        def with_fallback(properties: dict, key, fallback):
            return properties[key] if key in properties else fallback

        self.project = project_path
        self.name = name
        self.path = path.normpath(path.join(self.project, properties["path"]))
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

    def generate_mif(self):
        mif_path = path.join(self.project, f"{self.name}.mif")
        with open(self.path, "rb") as image, open(mif_path, "w") as mif:
            gen_mif(
                size=(self.width, self.height),
                depth=self.color_depth,
                crop=self.crop,
                image=image,
                mif=mif,
                fit_background=self.fit_background,
            )

    def generate_qip(self):
        qip_path = path.join(self.project, f"{self.name}.qip")
        qip_template = Template(filename=path.join(here, "templates/rom.template.qip"))
        with open(qip_path, "w") as qip:
            qip.write(qip_template.render(name=self.name))

    def generate_vhd(self):
        vhd_path = path.join(self.project, f"{self.name}.vhd")
        mif_path = path.join(self.project, f"{self.name}.mif")
        vhd_template = Template(filename=path.join(here, "templates/rom.template.vhd"))
        with open(vhd_path, "w") as vhd:
            vhd.write(
                vhd_template.render(
                    name=self.name,
                    mif_path=path.relpath(mif_path, working_dir).replace("\\", "/"),
                    mif_depth=self.width * self.height,
                    mif_width=self.color_depth.value,
                )
            )
