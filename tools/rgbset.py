lut = []

# red
for i in range(0b100000):
    lut.append(i << 1 | i >> 4)

# green
for i in range(0b1000000):
    lut.append(i)

# blue
for i in range(0b100000):
    lut.append(i << 1 | i >> 4)

print('x"' + '", x"'.join("{:02x}".format(o) for o in lut) + '"')
