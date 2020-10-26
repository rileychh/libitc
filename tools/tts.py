cnt = int(input())
name = []
text = []
length = []
byte_len = []
max_len = 0

for i in range(cnt):
    name.append(input())
    text.append(input())
    byte_len.append(curr_len := len(text[i].encode('big5')))

    max_len = curr_len if curr_len > max_len else max_len

for i in range(cnt):
    print(
        '-- "' + text[i] + '", ' + str(byte_len[i]) + '\n'
        'constant ' + name[i] + ' : txt_t(0 to ' + str(max_len - 1) + ') := (\n' +
        'x"' + '", x"'.join(['{:02x}'.format(c) for c in text[i].encode('big5')]) + '"' +
        '\n);')
