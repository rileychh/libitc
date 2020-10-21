# libitc

VHDL library for 108th and 109th ITC hardware. Current version is v3 (under development).

## Supported hardwares

Under `src/`, every hardware have its own `.vhd` file, consists of one package, which can have one or more constants and components.

| Name  |                         For                          | Status  |
| :---: | :--------------------------------------------------: | :-----: |
|  seg  |   2x4 digit seven segment display decoder/scanner    | stable  |
|  key  |                  4x4 keypad scanner                  | stable  |
|  mot  |      L293D H-Bridge for 2 DC motors' interface       |   N/A   |
|  dot  | 8 x 8 bicolor (red/green) dot matrix display scanner | stable  |
|  lcd  |        ST7735 128x160 RGB TFT LCD's interface        |   N/A   |
|  dht  |  DHT11 humidity and temperature sensor's interface   |   N/A   |
|  tsl  |        TSL2561 luminosity sensor's interface         | testing |
|  tts  |          SD178B Big5 TTS module's interface          |   N/A   |

## Utilities

Under `src/util`, there are shared dependency used by multiple files for converting types, generating waves, etc.

| Name  |                           For                            | Status  |
| :---: | :------------------------------------------------------: | :-----: |
|  clk  |                  System clock dividers                   | stable  |
|  pwm  |            Single phase PWM signal generator             | stable  |
|  bcd  | Converting unsigned integer into BCD vectors (for `seg`) | stable  |
|  i2c  |                I2C (IIC) master interface                | testing |

## Tests

There are no actual complete VHDL testbench, but there some .vhd files located under `tests/` you can `Set as top level entity` in Quartus to test some of the packages.

## Tools

Under `tools/` there are scripts that help with the writing of the code.
