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
| `export/AppIcon.icns`, `AppIcon-1024.png` | macOS app icon. Replace `Sources/keyholdr/AppIcon.icns` with it. The App Store icon comes from the build, so it ships with the next App Store version. |
| `export/keyholdr-icon.svg` | The coloured icon as a vector (README, docs). |
| `export/keyholdr-mark.svg` | The key alone, one colour (`currentColor`). |
| `export/MenuBarIcon*.png` | Black template glyph (the key), 18 pt at @1x/@2x/@3x; macOS tints it. Not wired in yet: the app still uses the `key.fill` SF Symbol. |

Tune the composition with `ART_SCALE` / `ART_TILT` in `generate.py`. Edit the drawing there and
re-run it rather than hand-editing the exported files.
