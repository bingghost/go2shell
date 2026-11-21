# Go2Term — build, sign and install via Swift Package Manager.
# See docs/02-TECH-DESIGN.md §4.

APP_NAME      := Go2Term
BUNDLE_ID     := com.bingghost.Go2Term
BUILD_DIR     := .build
APP_BUNDLE    := $(BUILD_DIR)/$(APP_NAME).app
INSTALL_PATH  := /Applications/$(APP_NAME).app
ENTITLEMENTS  := Resources/$(APP_NAME).entitlements

# UNIVERSAL=1 builds arm64 + x86_64; default is the host architecture.
ifeq ($(UNIVERSAL),1)
SWIFT_ARCH_FLAGS := --arch arm64 --arch x86_64
else
SWIFT_ARCH_FLAGS :=
endif
SWIFT_BUILD := swift build -c release $(SWIFT_ARCH_FLAGS)

# Signing identity: first "Apple Development" certificate in the keychain (by SHA-1),
# override with `make SIGN_ID=...`. Falls back to ad-hoc ("-") when none is found.
SIGN_ID ?= $(shell security find-identity -v -p codesigning 2>/dev/null | awk '/"Apple Development/ { print $$2; exit }')

.PHONY: all build bundle sign test run install uninstall reset-tcc clean help

all: build

help:
	@echo "make build      Build, bundle and sign $(APP_BUNDLE) (UNIVERSAL=1 for arm64+x86_64)"
	@echo "make test       Run unit tests"
	@echo "make run        Build and open the app"
	@echo "make install    Build and copy to $(INSTALL_PATH)"
	@echo "make uninstall  Remove $(INSTALL_PATH)"
	@echo "make reset-tcc  Reset Automation (Apple Events) permissions for $(BUNDLE_ID)"
	@echo "make clean      Remove build products"

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

install: build
	@if [ -d "$(INSTALL_PATH)" ]; then echo "Replacing existing $(INSTALL_PATH)"; rm -rf "$(INSTALL_PATH)"; fi
	ditto "$(APP_BUNDLE)" "$(INSTALL_PATH)"
	@echo "✅ Installed $(INSTALL_PATH)"

uninstall:
	@if [ -d "$(INSTALL_PATH)" ]; then rm -rf "$(INSTALL_PATH)"; echo "Removed $(INSTALL_PATH)"; \
	else echo "$(INSTALL_PATH) not installed"; fi
	@echo "Settings remain; remove with: defaults delete $(BUNDLE_ID)"

reset-tcc:
	tccutil reset AppleEvents $(BUNDLE_ID)

clean:
	rm -rf "$(BUILD_DIR)" .swiftpm
