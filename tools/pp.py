#!/usr/bin/env python

import re
from pathlib import Path
from sys import stdout

enable = False
minify_mode = set()


def preprocessor_enable(**kwargs) -> list[str]:  # pp
    vhd = kwargs["vhd"]
    macro_args = kwargs["macro_args"]

    global enable
    if macro_args == 'on':
        enable = True
    elif macro_args == 'off':
        enable = False
    return vhd


def define(**kwargs) -> list[str]:  # def
    vhd = kwargs["vhd"]
    macro_args = kwargs["macro_args"]

    token, value = macro_args.split(maxsplit=1)
    return [line.replace(token, value) for line in vhd]


def include(**kwargs) -> list[str]:  # inc
    vhd = kwargs["vhd"]
    ln = kwargs["ln"]
    macro_args = kwargs["macro_args"]
    input_file = kwargs["input_file"]

    files = list(input_file.parent.glob(macro_args))
    if input_file in files:
        files.remove(input_file)
    new_vhd = vhd
    new_vhd[ln:ln] = [l for f in files for l in open(
        f, 'r', encoding='utf-8').readlines()]
    return new_vhd


def minify(**kwargs) -> list[str]:  # min
    macro_args = kwargs["macro_args"]

    global minify_mode
    minify_mode = set(macro_args)
    if 'f' in minify_mode:
        minify_mode.update(set('cte'))

    return kwargs["vhd"]


def evaluate(**kwargs) -> list[str]:  # eval
    vhd = kwargs["vhd"]
    ln = kwargs["ln"]
    macro_args = kwargs["macro_args"]

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


def preprocess(input_file: Path, output_file: Path):
    vhd = open(input_file, 'r', encoding='utf-8').readlines()

    macro_pattern = re.compile(rf'{cmd_kw}({"|".join(macros)}) (.*)')

    # find all functions and their parameters
    for ln, line in enumerate(vhd):
        if match := macro_pattern.search(line):
            if enable or match[1] == 'pp':
                vhd[ln] = line.replace(match[0], '')  # remove the marco
                vhd = macros[match[1]](
                    vhd=vhd, ln=ln, macro_args=match[2], input_file=input_file)  # execute the macro

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
        if output_file:
            with open(output_file, 'w', encoding='utf-8') as f:
                f.write(result)
        else:
            stdout.write(result)


if __name__ == "__main__":
    from argparse import ArgumentParser
    parser = ArgumentParser()
    parser.add_argument('input_file', type=Path)
    parser.add_argument('output_file', nargs='?', type=Path)
    args = parser.parse_args()
    preprocess(args.input_file, args.output_file)
