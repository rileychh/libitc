# libitc

VHDL library for 108th and 109th ITC hardware.

## Supported hardwares

Under `src/`, every hardware have its own `.vhd` file, consists of one package, which can have one or more constants and components.

| Name  |                           For                           | Status  |
| :---: | :-----------------------------------------------------: | :-----: |
|  seg  |       2x4 digit seven segment display controller        | working |
|  key  |                  4x4 keypad controller                  | working |
|  sw   |                  8 switches debouncer                   | working |
|  rgb  |                   RGB LED controller                    | working |
|  mot  |       L293D H-Bridge for 2 DC motors' controller        | working |
|  dot  | 8 x 8 bicolor (red/green) dot matrix display controller | working |
|  lcd  |         ST7735 128x160 RGB TFT LCD's controller         | working |
|  dht  |   DHT11 humidity and temperature sensor's controller    | working |
|  tsl  |         TSL2561 luminosity sensor's controller          | working |
|  tts  |           SD178B Big5 TTS module's controller           | working |

## Utilities

Under `src/util`, there are shared dependency used by multiple files for converting types, generating waves, etc.

|   Name   |                For                | Status  |
| :------: | :-------------------------------: | :-----: |
|   clk    |       System clock dividers       | working |
|   edge   |           Edge detector           | working |
| debounce |   Push button/switch debouncer    | working |
|   pwm    | Single phase PWM signal generator | working |
|   i2c    |       I²C master interface        | working |
|   spi    |   SPI simplex master interface    | working |
|   uart   |          UART interface           | working |

## Tests

There are no actual complete VHDL testbench, but there some .vhd files located under `tests/` you can `Set as top level entity` in Quartus to test some of the packages.

## Tools

Under `tools/` there are scripts that help with the writing of the code.
