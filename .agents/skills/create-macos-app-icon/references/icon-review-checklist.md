# macOS App Icon Review Checklist

Use this checklist after generating the source and again after `make icons`.

## Product fit

- Express one recognizable idea connected to the app's job.
- Match the interface palette and personality without copying the UI literally.
- Avoid text unless a single glyph is essential and remains legible at small sizes.
- Use only artwork, fonts, and marks the project can distribute.

## Composition

- Make the silhouette and focal mark recognizable at a glance.
- Keep important features away from the extreme edge.
- Use enough tonal contrast to survive light and dark desktop backgrounds.
- Avoid hairline strokes, dense texture, and subtle details that disappear below 128 px.
- Avoid presenting the icon inside a phone, laptop, app-store card, or other mockup.

## Source file

- Store the final source at `assets/icons/AppIcon-1024.png`.
- Export a true 1024 x 1024 PNG without stretching.
- Use transparency only when it is intentional and inspect the generated macOS result for unexpected edges.
- Run `scripts/validate_icon.sh` from this skill directory or pass the source path explicitly.

## Generated outputs

- Run `make icons` rather than resizing files by hand.
- Inspect `src-tauri/icons/32x32.png`, `128x128.png`, `128x128@2x.png`, `icon.png`, and `icon.icns`.
- Confirm no crop, halo, unexpected square background, muddy edge, or lost focal detail appears.
- Commit the regenerated platform set so clean checkouts can build without recreating assets.

## Bundle verification

- Build through `./scripts/build_macos_app.sh` when packaging is in scope.
- Confirm the bundle contains `Contents/Resources/icon.icns` and that Finder displays the intended icon.
- Check current Apple documentation before App Store submission if the platform's icon format or presentation requirements have changed.
