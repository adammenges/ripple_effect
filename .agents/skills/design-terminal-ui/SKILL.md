---
name: design-terminal-ui
description: Design, implement, or refine the static HTML/CSS/JavaScript interface for this macOS Tauri app using its centered, responsive, terminal-inspired visual language. Use for screens, components, interaction polish, responsive layouts, accessibility, ASCII art, keyboard shortcuts, focus behavior, or visual QA in `ui/`.
---

# Design Terminal UI

Create a legible macOS interface with a restrained hacker aesthetic, not a literal terminal emulator.

## Design Rules

- Center the primary workspace and make it fluid from the configured 420 px minimum window width upward.
- Use semantic HTML and progressive enhancement so `ui/index.html` remains useful as a browser preview.
- Establish hierarchy through spacing, type weight, restrained color, borders, and status cues before adding decoration.
- Use monospace deliberately for commands, labels, counters, and ASCII art; keep longer prose comfortably readable.
- Keep ASCII art decorative with accessible text alternatives and hide it when it stops fitting cleanly.
- Prefer local assets and system fonts. The current CSP does not permit arbitrary remote fonts, scripts, or images.
- Use consistent SF Symbol exports from `assets/symbols/` when a symbol improves recognition; provide an accessible label.

## Interaction Rules

1. Make every primary action reachable by keyboard and pointer.
2. Show visible `:focus-visible` treatment and use native controls whenever practical.
3. Announce changing status text with appropriate live-region semantics without making routine updates noisy.
4. Keep hit targets comfortable, labels explicit, and destructive actions visually distinct.
5. Respect reduced-motion preferences and never make motion necessary to understand state.
6. Test modal focus, escape/close behavior, disabled states, error states, and narrow-window wrapping.

## Implementation Loop

1. Inspect existing CSS variables and component patterns before adding new ones.
2. Edit `ui/index.html`, `ui/style.css`, and `ui/main.js` without introducing a frontend toolchain.
3. Check `ui/index.html` directly for the visual-only fallback.
4. Run the app for Tauri-specific states when needed, then inspect at narrow and normal widths.
5. Run `$verify-tauri-change` before handing off.
