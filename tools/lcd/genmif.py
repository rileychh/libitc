import argparse
from PIL import Image
from pathlib import Path
from binascii import hexlify


def convert(img_path: Path, new_width=128, new_height=160) -> Path:
    img = Image.open(img_path)
    aspect = img.width / img.height
    new_aspect = new_width / new_height

    if aspect > new_aspect:
        # Then crop the left and right edges:
        target_width = int(new_aspect * img.height)
        offset = (img.width - target_width) / 2
        new_box = (offset, 0, img.width - offset, img.height)
    else:
        # ... crop the top and bottom:
        target_height = int(img.width / new_aspect)
        offset = (img.height - target_height) / 2
        new_box = (0, offset, img.width, img.height - offset)

    new_img = img.crop(new_box).resize((new_width, new_height))

    new_img_path = img_path.with_suffix('.bmp')
    new_img.save(new_img_path, format='bmp')
    return new_img_path

def bmp_to_mif(bmp_path: Path, mif_path: Path):
    header = '''\
WIDTH=12;
DEPTH=20480;

ADDRESS_RADIX=UNS;
DATA_RADIX=HEX;

CONTENT BEGIN
'''

    footer = '''\
END;
'''

    # get 24-bit pixels without header and EOF
    content = str(hexlify(bmp_path.read_bytes()))[54 * 2 + 2:-1].upper()
    print(len(content))
    # convert content into 12-bit pixels
    pixels = ''.join(content[i] for i in range(0, len(content), 2))
    print(len(pixels))
    # add syntax
    data = ''.join(
        f'\t{i}: {pixels[i * 3:i * 3 + 3]};\n' for i in range(int(len(pixels) / 3)))
    mif_path.write_text(header + data + footer)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('input_path', type=Path)
    parser.add_argument('output_path', type=Path)
    args = parser.parse_args()

    file_dir = Path(__file__).parent
    input_path = args.input_path
    output_path = args.output_path
    bmp_to_mif(convert(input_path), output_path)
