# 3D Screenshot Generator

Render app screenshots onto Apple iPhone/iPad USDZ assets and export a flat PNG.


## Dependencies

Download the following Apple USDZ assets and place them in `Assets/`:
https://store.storevideos.cdn-apple.com/v1/store.apple.com/st/1757022617174/iphone17pro-cosmicorange-ar-202509_GEO_US.usdz
https://store.storevideos.cdn-apple.com/v1/store.apple.com/st/1758636365686/ipad-pro-m5-13in-spaceblack-mgk-black-pencil-pro-ios26.usdz


## Build

```sh
swift build
```

## Usage

```sh
swift run 3dsg render \
  --device iphone-17-pro \
  --color deep-blue \
  --screen /path/to/screenshot.png \
  --output outputs/render.png \
  --size 1200x900
```

The original files in `Assets/` are loaded read-only and are not modified.
The device orientation is inferred from the `--screen` image dimensions: portrait images render portrait, and landscape images render landscape. For assets with a different native orientation, the screenshot is rotated internally before it is placed on the screen.
Renders are produced internally at a size derived from `--size`, trimmed to the non-transparent pixels, and then scaled so the final PNG fits within the max dimensions provided by `--size`.

Supported devices:

- `iphone-17-pro`
- `iphone-17-pro-max`
- `ipad-pro-13-inch`

Useful options:

- `--rotation X,Y,Z` applies extra 3D rotation in degrees after default framing.
