# 3D Screenshot Generator

Render app screenshots onto Apple iPhone/iPad USDZ assets and export a flat PNG.


## Dependencies

Download the following assets from Apple:
https://www.apple.com/105/media/us/iphone-17-pro/2025/704d4474-8e63-4ce7-9917-bb47b1ca4ba0/ar/iphone-17-pro-e-sim.usdz
https://www.apple.com/105/media/us/ipad-pro/2025/adee90db-c01e-430d-b726-fe64c0063f08/ar/ipad-pro-space-black.usdz


## Build

```sh
swift build
```

## Usage

```sh
swift run 3dsg render \
  --device iphone-17-pro \
  --color deep-blue \
  --orientation portrait \
  --screen /path/to/screenshot.png \
  --output outputs/render.png \
  --size 1200x900
```

The original files in `Assets/` are loaded read-only and are not modified.
Renders are produced internally at a size derived from `--size`, trimmed to the non-transparent pixels, and then scaled so the final PNG fits within the max dimensions provided by `--size`.

Supported devices:

- `iphone-17-pro`
- `iphone-17-pro-max`
- `ipad-pro-13-inch`

Useful options:

- `--rotation X,Y,Z` applies extra 3D rotation in degrees after default framing.
- `--screen-fit cover|contain|stretch` controls screenshot fitting.
