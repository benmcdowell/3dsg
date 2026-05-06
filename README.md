# 3D Screenshot Generator

Render app screenshots onto Apple iPhone/iPad USDZ assets and export both a flat
PNG render and a generated USDZ scene.

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

The tool derives `outputs/render.usdz` from the PNG output path. The original
files in `Assets/` are loaded read-only and are not modified.

Supported devices:

- `iphone-17-pro`
- `iphone-17-pro-max`
- `ipad`

Useful options:

- `--rotation X,Y,Z` applies extra 3D rotation in degrees after default framing.
- `--screen-fit cover|contain|stretch` controls screenshot fitting.
- `--show-keyboard` and `--show-pencil` opt into iPad accessories.
