# libitc

VHDL library for 108th and 109th ITC hardware.

## Supported hardwares

Under `/src`, every hardware have its own `.vhd` file, consists of one package, which can have one or more constants and components.

| Name  |                         For                          |  Status   |
| :---: | :--------------------------------------------------: | :-------: |
|  clk  |                System clock dividers                 | v1 stable |
|  seg  |  2 x 4 digit seven segment display decoder/scanner   |  v2 beta  |
|  dot  | 8 x 8 bicolor (red/green) dot matrix display scanner | v1 stable |
|  key  |                 4 x 4 keypad scanner                 | v1 stable |

## Utilities

Under `src/util`, there are optional utilities for converting types, generating waves, etc.

| Name  |                                       For                                       |  Status   |
| :---: | :-----------------------------------------------------------------------------: | :-------: |
|  bcd  | Converting unsigned integer into BCD vectors (commonly used with `seg` package) | v1 stable |
|  pwm  |                        Single phase PWM signal generator                        | v1 stable |

## Tests

There are no actual complete VHDL testbench, but there some .vhd files located under `tests/` you can `Set as top level entity` in Quartus to test some of the packages.

## My last words

Contribution is always welcome!
