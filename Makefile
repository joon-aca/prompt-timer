.PHONY: help project install dmg app-store

help:
	@printf "Targets:\n"
	@printf "  make install    Generate the Xcode project and install the personal app + CLI locally\n"
	@printf "  make project    Regenerate PromptTimer.xcodeproj from project.yml\n"
	@printf "  make dmg        Build a personal DMG via scripts/build-dmg.sh\n"
	@printf "  make app-store  Build the sandboxed App Store app target\n"

project:
	@command -v xcodegen >/dev/null 2>&1 || { \
		echo "xcodegen is required. Install it first, then rerun 'make project'."; \
		exit 1; \
	}
	xcodegen generate

install: project
	./scripts/install.sh

dmg: project
	./scripts/build-dmg.sh

app-store: project
	xcodebuild -project PromptTimer.xcodeproj -scheme PromptTimer -configuration Release -derivedDataPath build/DerivedData/AppStore clean build
