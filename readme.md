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

## 開發環境

本專案為 Visual Studio Code 設定，包含程式碼片段、工作等。

### 工作 (tasks)

請使用 `bash` 或 `zsh` 等 POSIX 殼層來執行工作。要執行 `Build`（編譯）或 `Deploy`（部屬）工作前，請先將 `quartus_sh` 指令加入環境變數。

### Python 環境設定

大部分的工具都是用 Python 寫的。我們用 [Poetry](https://python-poetry.org/) 管理相依套件和工作環境。

在安裝完 Python、pip 和 Poetry 後，需要執行 `poetry install` 才能使用工具。成功執行後，試著執行任一工具來檢查環境是否正確。

### VHDL 語言伺服器

使用 [VHDL Tool](https://www.vhdltool.com/) 可以擁有自動完成、跳至定義等實用功能，加快開發速度。安裝完成後請到 [IEEE](https://standards.ieee.org/downloads/) 下載 VHDL 標準函式庫 (IEEE 1076™) 的定義，放在 `vhdltool-config.yaml` 指定的路徑。
