# SF Symbols Assets

Use this folder for SF Symbol exports used inside the app UI.

Recommended workflow:

1. Open Apple's SF Symbols app.
2. Export symbols as SVG.
3. Save them in this directory with stable names.
4. Reference them from `ui/` as local SVG assets.

Keep icon style consistent:

- Use a consistent optical weight within each screen.
- Provide an accessible text label or `aria-label` for interactive symbols.
- Prefer monochrome or a restrained palette so symbols inherit UI state cleanly.

Review Apple's SF Symbols license before distributing exported assets outside an Apple-platform app.
