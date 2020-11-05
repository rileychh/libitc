#!/usr/bin/env python

def add_p():
    result = ''
    while True:
        try:
            a_to_g = int(input(), base=16)
            a_to_p = a_to_g << 1
            result += 'x"' + hex(a_to_p)[2:] + '", '
        except EOFError:
            print(result)
            break


def reverse_bit_order():
    result = []
    while True:
        try:
            n = int(input(), base=16)
            result.append(
                'x"' + '{:02x}'.format(int('{:08b}'.format(n)[::-1], 2)) + '", ')
        except EOFError:
            print(*result, sep='')
            break


if __name__ == '__main__':
    reverse_bit_order()
