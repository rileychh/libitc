from typing import Tuple


def rgb565(pixel: int) -> int:
    r, g, b = pixel >> 16, (pixel >> 8) & 0xff, pixel & 0xff
    return (b >> 3) << 11 | (r >> 2) << 5 | (g >> 3)


colors = []

while True:
    try:
        colors.append(rgb565(int(input(), 16)))
    except EOFError:
        print('x"' + '", x"'.join('{:04x}'.format(c) for c in colors) + '"')
        break
