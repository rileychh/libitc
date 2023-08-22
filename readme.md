# libitc

VHDL library for 108th, 109th and 110th ITC hardware.

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

### Python 環境設定

大部分的工具都是用 Python 寫的。我們用 [Poetry](https://python-poetry.org/) 管理相依套件和工作環境。

在安裝完 Python、pip 和 Poetry 後，需要一些設定才能使用工具。

```sh
poetry config virtualenvs.in-project true
poetry install
poetry shell
```

三項指令都成功執行後，試著執行任一工具來檢查環境是否正確。
