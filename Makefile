.DEFAULT_GOAL := help

.PHONY: help setup doctor dev check icons build-app clean

help:
	@echo "Rust + Tauri macOS template"
	@echo ""
	@echo "  make setup      Install pinned tools and fetch dependencies"
	@echo "  make doctor     Check the local development environment"
	@echo "  make dev        Launch the app with hot reload"
	@echo "  make check      Run syntax checks, formatting, Clippy, and tests"
	@echo "  make icons      Regenerate platform icons from the source PNG"
	@echo "  make build-app  Build and verify an ARM64 release .app in dist/"
	@echo "  make clean      Remove generated build output"

setup:
	./scripts/setup.sh

doctor:
	./scripts/doctor.sh

dev:
	./scripts/dev.sh

check:
	./scripts/check.sh

icons:
	cargo tauri icon assets/icons/AppIcon-1024.png

build-app:
	./scripts/build_macos_app.sh

clean:
	cargo clean
	rm -rf dist
