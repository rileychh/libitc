from math import sqrt

print('x"' + '", x"'.join('{:02x}'.format(y)
                          for y in (int(sqrt(x) * 0x10) for x in range(0x100))) + '"')
