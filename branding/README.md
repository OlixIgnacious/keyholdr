# Brand assets

The app icon is the website's animated logo, frozen mid-sway: a grey balloon lifting a black
house key on two dashed cords, on a paper-coloured macOS tile. `generate.py` builds every asset
from one vector definition whose coordinates come straight from `key-balloon.gif`, so the icon
and the site logo stay in step. It needs Python 3, Pillow and Google Chrome (to rasterise the
SVG); `iconutil` (macOS) makes the `.icns`.

```bash
python3 branding/generate.py          # writes branding/export/
python3 branding/generate.py k        # alternate design (a key whose shaft is a K) → branding/export-k/
```

| File | Use |
|---|---|
| `export/AppIcon.icns`, `AppIcon-1024.png` | macOS app icon. Copied to `Sources/keyholdr/AppIcon.icns` (in use since 1.7.1); after re-running `generate.py`, copy it there again. The App Store icon comes from the build. |
| `export/keyholdr-icon.svg` | The coloured icon as a vector (README, docs). |
| `export/keyholdr-mark.svg` | The key alone, one colour (`currentColor`). |
| `export/MenuBarIcon*.png` | Black template glyph (the key), 18 pt at @1x/@2x/@3x; macOS tints it. Not wired in yet: the app still uses the `key.fill` SF Symbol. |

Tune the composition with `ART_SCALE` / `ART_TILT` in `generate.py`. Edit the drawing there and
re-run it rather than hand-editing the exported files.

## App Store screenshots

`appstore/slides.html` holds the five App Store slides; `appstore/render.sh` renders them with
headless Chrome (fonts load from Google Fonts, so it needs network access) at the 2880×1800 Mac
App Store Connect size, then downsizes each with `sips`.

```bash
branding/appstore/render.sh    # writes Keyholdr-appstore-screenshots/<size>/keyholdr-<n>.png
```

`Keyholdr-appstore-screenshots/` (2880×1800, 2560×1600, 1440×900, 1280×800) is the only tracked
copy, ready to upload. The intermediate masters in `appstore/export/` are gitignored.
