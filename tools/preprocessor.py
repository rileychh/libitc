#!/usr/bin/env python

from argparse import ArgumentParser, FileType
from pathlib import Path
from sys import stdout
import re


def define(vhd: list[str], ln: int, macro_args: str) -> list[str]:  # def
    token, value = macro_args.split(maxsplit=1)
    return [line.replace(token, value) for line in vhd]


def include(vhd: list[str], ln: int, macro_args: str) -> list[str]:  # inc
    vhd_path = Path(args.input_file.name)
    files = list(vhd_path.parent.glob(macro_args))
    if vhd_path in files:
        files.remove(vhd_path)
    new_vhd = vhd
    new_vhd[ln:ln] = [l for f in files for l in open(f, 'r').readlines()]
    return new_vhd


minify_mode = set()


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
macros = {'def': define,
          'inc': include,
          'min': minify,
          'eval': evaluate}

parser = ArgumentParser()
parser.add_argument('input_file', type=FileType('r'))
parser.add_argument('output_file', nargs='?',
                    type=FileType('w'), default=stdout)
args = parser.parse_args()

vhd = args.input_file.readlines()

macro_pattern = re.compile(rf'{cmd_kw}({"|".join(macros)}) (.*)')


# find all functions and their parameters
for ln, line in enumerate(vhd):
    if match := macro_pattern.search(line):
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

args.output_file.write(''.join(vhd))
