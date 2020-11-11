from math import sqrt

a = [int(sqrt(x) * 0x10) for x in range(0x100)]

print('x"' + '", x"'.join(arr := ['{:02x}'.format(x) for x in a]) + '"')
print(len(arr))
