---
name: create-macos-app-icon
description: Design, generate, replace, validate, and install the macOS application icon for this Tauri project, including AI-assisted raster concepts, the Swift fallback renderer, the 1024 px source PNG, Tauri platform icon generation, small-size review, and packaged `.icns` verification. Use whenever creating app branding, changing `assets/icons/AppIcon-1024.png`, regenerating `src-tauri/icons/`, or diagnosing an incorrect icon in a macOS bundle.
---

# Create macOS App Icon

Produce one strong source asset and carry it through the repository's complete icon pipeline.

## Workflow

1. Read `references/icon-review-checklist.md` before finalizing a direction.
2. Identify the app's purpose, personality, distinctive motif, and required palette from the product request and existing UI.
3. Choose a simple silhouette with one focal idea. Avoid tiny details, paragraphs, screenshots, photo-realistic mockups, and unlicensed brand marks.
4. Create or edit the artwork:
   - Prefer an image-generation or image-editing tool for an original raster concept when available. Ask for a straight-on icon asset on a square canvas, not a device mockup or marketing scene.
   - Use `scripts/generate_default_icon.swift` as the deterministic local fallback. Customize its palette and SF Symbol or vector drawing, then render it with `swift scripts/generate_default_icon.swift assets/icons/AppIcon-1024.png`.
   - Preserve the user's supplied source when the task is only to install or regenerate it.
5. Inspect the source image visually. Crop deliberately to a square and export exactly 1024 x 1024 PNG; do not stretch a non-square image or upscale a weak low-resolution source.
6. Run `.agents/skills/create-macos-app-icon/scripts/validate_icon.sh` from the repository root.
7. Install the source at `assets/icons/AppIcon-1024.png`, then run `make icons` to regenerate every committed platform output under `src-tauri/icons/`.
8. Inspect at least the 32 px, 128 px, and full-size outputs. Simplify the art if the mark muddies, vanishes, or resembles another app at small sizes.
9. Use `$package-macos-app` when the request includes a production bundle; confirm the `.app` contains `Contents/Resources/icon.icns`.

## Guardrails

- Keep `assets/icons/AppIcon-1024.png` as the single source of truth.
- Do not hand-edit generated files in `src-tauri/icons/`.
- Commit the full generated icon set after changing the source.
- Keep meaningful content away from the extreme canvas edge and evaluate the generated macOS result rather than assuming a mask.
- Verify current Apple distribution requirements before changing this template from its flattened PNG/ICNS pipeline to a newer layered format.

## Resources

- Run `scripts/validate_icon.sh [path]` to verify the source dimensions and PNG format.
- Read `references/icon-review-checklist.md` for visual, technical, and packaging acceptance criteria.
