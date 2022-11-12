#!/usr/bin/env python

import pyperclip
from textwrap import *

txt_type = 'u8_arr_t'
txt_signal_name = 'tts_data'
txt_len_signal_name = 'tts_len'

cnt = int(input())
name = []
text = []

for i in range(cnt):
    name.append(input())
    text.append(input())

encoded_text = [s.encode('big5') for s in text]  # encode all inputs
# lengths (in bytes) of encoded texts
byte_len = [len(s) for s in encoded_text]

result = f'constant max_len : integer := {max(byte_len)};\n\n'

for i in range(cnt):
    array_elements = '", x"'.join(f'{c:02x}' for c in encoded_text[i])

    result += fill(f'-- "{text[i]}", {byte_len[i]}', width=60, subsequent_indent='-- ') + '\n' + \
        f'-- {txt_signal_name}(0 to {byte_len[i] - 1}) <= {name[i]};\n' + \
        f'-- {txt_len_signal_name} <= {byte_len[i]};\n' + \
        f'constant {name[i]} : {txt_type}(0 to {byte_len[i] - 1}) := (\n' + \
        indent(fill(f'x"{array_elements}"', width=111), '\t') + '\n' + \
        ');\n\n'

print(result)
pyperclip.copy(result)

# test input
"""
2
song
的是時間/我不想在未來的日子裡/獨自哭著無法往前
what
聽講，露西時常做運動，身體健康精神好，露西！哩洗那欸加你搞，身體健康精神好，規律運動不可少，沒事常做健康操，全身運動功效好，喂，同學，歸勒百欸穩懂安抓來安白，杯題阿哇的有擘吼哩哉，咖嘛北鼻當賊來，麼地有135，麼地有246，西哉金裡嗨，搭給當賊來。
"""
