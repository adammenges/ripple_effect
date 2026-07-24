# App icon source

`AppIcon-1024.png` is the single source of truth for the application icon. Use a square 1024 × 1024 PNG with transparency where appropriate.

Regenerate Tauri's macOS, Windows, iOS, and Android icon set with:

```bash
make icons
```

`scripts/build_macos_app.sh` also regenerates icons when the source is newer than `src-tauri/icons/icon.icns`. If the source is missing on macOS, the build attempts to recreate the included default with `generate_default_icon.swift`.

Commit the generated files in `src-tauri/icons/` so a fresh checkout has a complete icon set.
