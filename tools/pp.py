#!/usr/bin/env python

from argparse import ArgumentParser
from pathlib import Path
from sys import stdout
import re


enable = False
minify_mode = set()


def preprocessor_enable(vhd: list[str], ln: int, macro_args: str) -> list[str]:  # pp
    global enable
    if macro_args == 'on':
        enable = True
    elif macro_args == 'off':
        enable = False
    return vhd


def define(vhd: list[str], ln: int, macro_args: str) -> list[str]:  # def
    token, value = macro_args.split(maxsplit=1)
    return [line.replace(token, value) for line in vhd]


def include(vhd: list[str], ln: int, macro_args: str) -> list[str]:  # inc
    files = list(args.input_file.parent.glob(macro_args))
    if args.input_file in files:
        files.remove(args.input_file)
    new_vhd = vhd
    new_vhd[ln:ln] = [l for f in files for l in open(
        f, 'r', encoding='utf-8').readlines()]
    return new_vhd


def minify(vhd: list[str], ln: int, macro_args: str) -> list[str]:  # min
    global minify_mode
    minify_mode = set(macro_args)
    if 'f' in minify_mode:
        minify_mode.update(set('cte'))

    return vhd


def evaluate(vhd: list[str], ln: int, macro_args: str) -> list[str]:  # eval
    new_vhd = vhd
    new_vhd.insert(ln, eval(macro_args))
    return new_vhd


cmd_kw = '--!'  # preprocessor keyword
# available macros
macros = {'pp': preprocessor_enable,
          'def': define,
          'inc': include,
          'min': minify,
          'eval': evaluate}

parser = ArgumentParser()
parser.add_argument('input_file', type=Path)
parser.add_argument('output_file', nargs='?', type=Path)
parser.add_argument('-i', '--in-place', action='store_true')
args = parser.parse_args()

vhd = open(args.input_file, 'r', encoding='utf-8').readlines()

macro_pattern = re.compile(rf'{cmd_kw}({"|".join(macros)}) (.*)')


# find all functions and their parameters
for ln, line in enumerate(vhd):
    if match := macro_pattern.search(line):
        if enable or match[1] == 'pp':
            vhd[ln] = line.replace(match[0], '')  # remove the marco
            vhd = macros[match[1]](vhd, ln, match[2])  # execute the macro

# execute minify

comment_pattern = re.compile(r'--.*$')
tab_pattern = re.compile(r' {2,}|\t')

if 'c' in minify_mode:
    vhd = [comment_pattern.sub('', l) for l in vhd]
if 't' in minify_mode:
    vhd = [tab_pattern.sub('', l) for l in vhd]
if 'e' in minify_mode:
    vhd = [l for l in vhd if l.strip()]
if 'f' in minify_mode:
    vhd = [l.strip() + ' ' for l in vhd]

result = ''.join(vhd)

if enable:
    if args.in_place:
        with open(args.input_file, 'w', encoding='utf-8') as f:
            f.write(result)
    elif args.output_file:
        with open(args.output_file, 'w', encoding='utf-8') as f:
            f.write(result)
    else:
        stdout.write(result)
