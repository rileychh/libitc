
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
			result.append('x"' + '{:02x}'.format(int('{:08b}'.format(n)[::-1], 2)) + '", ')
		except EOFError:
			print(*result, sep='')
			break

if __name__ == '__main__':
	reverse_bit_order()

# Test input
"""
00
86
22
7E
6D
D2
46
20
29
0B
21
70
10
40
80
52
3F
06
5B
4F
66
6D
7D
07
7F
6F
09
0D
61
48
43
D3
5F
77
7C
39
5E
79
71
3D
76
30
1E
75
38
15
37
3F
73
6B
33
6D
78
3E
3E
2A
76
6E
5B
39
64
0F
23
08
02
5F
7C
58
5E
7B
71
6F
74
10
0C
75
30
14
54
5C
73
67
50
6D
78
1C
1C
14
76
6E
5B
46
30
70
01
00
"""
