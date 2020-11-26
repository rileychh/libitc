#!/bin/bash

for f in tests/itc109_2/res/*.jpg
do
    tools/genmif.py $f $f.mif -bi
done