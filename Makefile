.PHONY: help project install dmg

help:
	@printf "Targets:\n"
	@printf "  make install  Generate the Xcode project and install the app + CLI locally\n"
	@printf "  make project  Regenerate PromptTimer.xcodeproj from project.yml\n"
	@printf "  make dmg      Build a distributable DMG via scripts/build-dmg.sh\n"

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
