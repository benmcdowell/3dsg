# 3D Screenshot Generator

Render app screenshots onto Apple iPhone/iPad USDZ assets and export a flat PNG.


## Assets

The Apple USDZ assets are managed automatically. If the required asset is missing when the tool runs, it is downloaded from Apple and saved to:

`~/Library/Application Support/com.benmcdowell.3dsg/usdz`


## Build

```sh
swift build
```

## Usage

```sh
swift run 3dsg \
  --device iphone-17-pro \
  --color deep-blue \
  --screen /path/to/screenshot.png \
  --output outputs/render.png
```

The device orientation is inferred from the `--screen` image dimensions: portrait images render portrait, and landscape images render landscape. For assets with a different native orientation, the screenshot is rotated internally before it is placed on the screen.
Renders are produced internally at a size derived from the requested output size, trimmed to the non-transparent pixels, and then scaled so the final PNG fits within the max dimensions. Use `--size WIDTHxHEIGHT` to choose those max dimensions; when omitted, the screenshot dimensions are used.

Supported devices:

- `iphone-17-pro`
- `iphone-17-pro-max`
- `ipad-pro-13-inch`

Useful options:

- `--rotation X,Y,Z` applies extra 3D rotation in degrees after default framing.
- `--version` prints the installed `3dsg` version.
