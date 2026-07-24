# macOS bundle resources

Place additional files that should ship inside the macOS application bundle here, then declare them in `bundle.resources` in `src-tauri/tauri.conf.json`.

Tauri generates `Info.plist` and embeds the icon during packaging. The build wrapper supplies optional name, identifier, and version overrides through a temporary Tauri configuration and verifies the finished bundle metadata.
