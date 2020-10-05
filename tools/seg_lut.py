result = ''

def add_p():
	while True:
		try:
			a_to_g = int(input(), base=16)
			a_to_p = a_to_g << 1
			result += 'x"' + hex(a_to_p)[2:] + '", '
		except EOFError:
			print(result)
			break

if __name__ == '__main__':
	add_p()
