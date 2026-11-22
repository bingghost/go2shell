# Go2Shell — build, sign and install via Swift Package Manager.
# See docs/02-TECH-DESIGN.md §4.

APP_NAME      := Go2Shell
BUNDLE_ID     := com.bingghost.Go2Shell
BUILD_DIR     := .build
INSTALL_PATH  := /Applications/$(APP_NAME).app
ENTITLEMENTS  := Resources/$(APP_NAME).entitlements
# The legacy ZipZapMac Go2Shell installs to the same path; `deploy` moves a foreign app here
# instead of deleting it.
BACKUP_DIR    := $(HOME)/Library/Application Support/$(APP_NAME)/Replaced Apps

# UNIVERSAL=1 builds arm64 + x86_64; default is the host architecture.
ifeq ($(UNIVERSAL),1)
SWIFT_ARCH_FLAGS := --arch arm64 --arch x86_64
else
SWIFT_ARCH_FLAGS :=
endif

# CONFIG=debug builds an unoptimised bundle in .build/dev/ (used by start.sh);
# the default release bundle is .build/Go2Shell.app.
CONFIG ?= release
ifeq ($(CONFIG),debug)
APP_BUNDLE := $(BUILD_DIR)/dev/$(APP_NAME).app
else
APP_BUNDLE := $(BUILD_DIR)/$(APP_NAME).app
endif
SWIFT_BUILD := swift build -c $(CONFIG) $(SWIFT_ARCH_FLAGS)

# Signing identity: first "Apple Development" certificate in the keychain (by SHA-1),
# override with `make SIGN_ID=...`. Falls back to ad-hoc ("-") when none is found.
SIGN_ID ?= $(shell security find-identity -v -p codesigning 2>/dev/null | awk '/"Apple Development/ { print $$2; exit }')

.PHONY: all build bundle sign test run install deploy uninstall reset-tcc icon clean help

all: build

help:
	@echo "make build      Build, bundle and sign $(APP_BUNDLE) (UNIVERSAL=1 for arm64+x86_64, CONFIG=debug for a debug build)"
	@echo "make test       Run unit tests"
	@echo "make run        Build and open the app"
	@echo "make install    Build and copy to $(INSTALL_PATH)"
	@echo "make uninstall  Remove $(INSTALL_PATH)"
	@echo "make reset-tcc  Reset Automation (Apple Events) permissions for $(BUNDLE_ID)"
	@echo "make icon       Regenerate Resources/AppIcon.icns from Scripts/make-icon.swift"
	@echo "make deploy     Copy the already-built bundle to $(INSTALL_PATH) (no rebuild)"
	@echo "make clean      Remove build products (debug and release); fetched dependencies are kept"

build: bundle sign
	@echo "✅ Built $(APP_BUNDLE)"

bundle:
	$(SWIFT_BUILD)
	@BIN_DIR="$$($(SWIFT_BUILD) --show-bin-path)"; \
	rm -rf "$(APP_BUNDLE)"; \
	mkdir -p "$(APP_BUNDLE)/Contents/MacOS" "$(APP_BUNDLE)/Contents/Resources"; \
	cp "$$BIN_DIR/$(APP_NAME)" "$(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)"; \
	cp Resources/Info.plist "$(APP_BUNDLE)/Contents/Info.plist"; \
	if [ -f Resources/AppIcon.icns ]; then cp Resources/AppIcon.icns "$(APP_BUNDLE)/Contents/Resources/"; fi; \
	for lproj in Resources/*.lproj; do cp -R "$$lproj" "$(APP_BUNDLE)/Contents/Resources/"; done; \
	printf 'APPL????' > "$(APP_BUNDLE)/Contents/PkgInfo"

sign:
	@if [ -n "$(SIGN_ID)" ] && [ "$(SIGN_ID)" != "-" ]; then \
		echo "✍️  Signing with identity $(SIGN_ID)"; \
		codesign --force --options runtime --timestamp=none \
			--entitlements "$(ENTITLEMENTS)" --sign "$(SIGN_ID)" "$(APP_BUNDLE)"; \
	else \
		echo "⚠️  No 'Apple Development' certificate found — falling back to ad-hoc signing."; \
		echo "⚠️  Ad-hoc signatures change on every build, so Automation permission must be re-granted each time."; \
		codesign --force --options runtime \
			--entitlements "$(ENTITLEMENTS)" --sign - "$(APP_BUNDLE)"; \
	fi
	@codesign --verify --strict "$(APP_BUNDLE)"

test:
	swift test

run: build
	open "$(APP_BUNDLE)"

install: build deploy

# Copies the bundle built by `make build`; install.sh calls this after build.sh.
deploy:
	@if [ ! -d "$(APP_BUNDLE)" ]; then echo "$(APP_BUNDLE) not found — run make build first"; exit 1; fi
	@if [ -d "$(INSTALL_PATH)" ]; then \
		existing="$$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$(INSTALL_PATH)/Contents/Info.plist" 2>/dev/null || true)"; \
		if [ "$$existing" = "$(BUNDLE_ID)" ]; then \
			echo "Replacing existing $(INSTALL_PATH)"; rm -rf "$(INSTALL_PATH)"; \
		else \
			backup="$(BACKUP_DIR)/$(APP_NAME) ($${existing:-unknown}) $$(date +%Y%m%d-%H%M%S).app"; \
			mkdir -p "$(BACKUP_DIR)"; mv "$(INSTALL_PATH)" "$$backup"; \
			echo "⚠️  $(INSTALL_PATH) was a different app ($${existing:-unknown}); moved it to:"; \
			echo "    $$backup"; \
		fi; \
	fi
	ditto "$(APP_BUNDLE)" "$(INSTALL_PATH)"
	@echo "✅ Installed $(INSTALL_PATH)"

uninstall:
	@if [ ! -d "$(INSTALL_PATH)" ]; then echo "$(INSTALL_PATH) not installed"; \
	elif [ "$$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$(INSTALL_PATH)/Contents/Info.plist" 2>/dev/null)" != "$(BUNDLE_ID)" ]; then \
		echo "$(INSTALL_PATH) is a different app (not $(BUNDLE_ID)); leaving it alone"; exit 1; \
	else rm -rf "$(INSTALL_PATH)"; echo "Removed $(INSTALL_PATH)"; fi
	@echo "Settings remain; remove with: defaults delete $(BUNDLE_ID)"

reset-tcc:
	tccutil reset AppleEvents $(BUNDLE_ID)

# Redraws the app icon; the generated .icns is checked in, so this is only needed after
# changing Scripts/make-icon.swift.
icon:
	swift Scripts/make-icon.swift

# Removes compiled output only. SwiftPM's fetched dependencies (checkouts, repositories,
# artifacts and the workspace-state.json that tracks them) are kept.
clean:
	@if [ -d "$(BUILD_DIR)" ]; then \
		find "$(BUILD_DIR)" -mindepth 1 -maxdepth 1 \
			! -name checkouts ! -name repositories ! -name artifacts ! -name workspace-state.json \
			-exec rm -rf {} +; \
		rmdir "$(BUILD_DIR)" 2>/dev/null || true; \
	fi
	@echo "🧹 Removed build products"
