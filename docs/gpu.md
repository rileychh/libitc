# GPU

## GIG 指令編譯器

讀取資料夾中的 `graphics.yaml` 並產生：

- VHDL 檔案，包含一個帶有常數的 `package`
- `graphics.mif` 指令 ROM MIF
- 每張圖片的 MIF，使用 `genmif` 產生

## 指令 ROM 格式

指令代碼 4 位 + 參數 60 位共 64 位

## 指令集

### fill xs ys xe ye color

- 指令代碼： 0x1
- 15 位開始位址
- 15 位結束位址
- 24 位顏色

### text x y color "string"

- 指令代碼： 0x2
- 15 位位址
- 24 位顏色
- 接下來每行 8 個字元，每個佔 8 位，直到 NUL (0x0) 出現。

### image x y image

- 指令代碼： 0x3
- 15 位開始位址
- 15 位結束位址
- 4 位圖片 ROM 代碼
  - ???

### rotate xs ys xe ye orientation

- 15 位開始位址
- 15 位結束位址
- 2 位圖片方向，代表順時針旋轉 90 度的次數

### mirror xs ys xe ye orientation

- 15 位開始位址
- 15 位結束位址
- 2 位圖片方向，代表順時針旋轉 90 度的次數

### replace color color

- 指令代碼： 0x4
- 24 位顏色
- 24 位顏色
