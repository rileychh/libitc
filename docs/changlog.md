# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Support for SM178B text-to-speech module
- Support for ST7735 TFT LCD module
- Support for TSL2561 light sensor (`tsl.vhd`)
- I2C interface (`i2c.vhd`)
- Edge detector `edge`
- Useful functions
  - `log(base, num)`
  - `reverse(vector)`
  - `reduce(vector, operation)`
  - `index_of(vector, element)`
  - `to_string(num, num_max, base, length)`
- Useful types
  - `nibble_t`
  - `nibble_be_t`
  - `nibbles_t`
  - `nibbles_be_t`
  - `byte_t`
  - `byte_be_t`
  - `bytes_t`
  - `bytes_be_t`

### Changed

- Complete rewrite
- Some port bit order
- Unified packages to one `itc` package
- `rst` port is now `rst_n`
- Auto compiling and deploying VSCode tasks

### Fixed

- `pwm` overflows when duty cycle is over 50%
- Range of `temp` and `hum` in `dht` is too small

## [0.3.0]

### Added

- Deploy and program script for VSCode
- DHT11 interface (`dht.vhd`)

### Removed

- Simulation files
- `clk_div` component

### Changed

- Changed some ports to simpler names
- Seven segment display now uses string type as data input
  - You can use `to_character()` function to convert integer or unsigned into hexadecimal format
- `seg.vhd` now reversed `seg_s` port bit order, you'll need to update pin assignment
- Changed `clk_sys`'s name to `clk`

### Fixed

- Fixed `clk` overflow, now timing will be correct

## [0.2.0]

### Added

- Add enable pins to `dot` and `seg` drivers
- Some new features for `dot`
  - `dot_zeros` and `dot_ones` constants which are just `dot_data_t` type with full of '0's and '1's
  - `dot_anim_t` type: array of `dot_data_t` dor creating animations

### Fixed

- Fixed `seg_data_t` type to `integer range 0 to seg_lut_len - 1`
- Fixed `clk_sys` component "divide by zero error"

## [0.1.0]

### Added

- More glyphs in the `seg_lut`
- Add new constants:
  - `seg_lut_len`: the length of `seg_lut`
  - `seg_dot`: add this number to any element of `seg_data` to turn on the dot
  - `seg_spc`: space
  - `seg_deg`: degree symbol
  - `seg_lb`, `seg_rb`: brackets

### Changed

- Increased `seg_data_t` range
