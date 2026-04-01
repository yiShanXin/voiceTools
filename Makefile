APP_NAME := VoiceHub
BUILD_DIR := build
APP_BUNDLE := $(BUILD_DIR)/$(APP_NAME).app
EXECUTABLE := .build/release/$(APP_NAME)

-include Makefile.local

CODE_SIGN_IDENTITY ?=
ALLOW_ADHOC ?= 0

.PHONY: build run install clean

build:
	swift build -c release
	mkdir -p $(APP_BUNDLE)/Contents/MacOS
	mkdir -p $(APP_BUNDLE)/Contents/Resources
	cp $(EXECUTABLE) $(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)
	cp Info.plist $(APP_BUNDLE)/Contents/Info.plist
	@if [ -n "$(CODE_SIGN_IDENTITY)" ]; then \
		echo "Signing with identity: $(CODE_SIGN_IDENTITY)"; \
		codesign --force --deep --sign "$(CODE_SIGN_IDENTITY)" "$(APP_BUNDLE)"; \
	elif [ "$(ALLOW_ADHOC)" = "1" ]; then \
		echo "Warning: using ad-hoc signing (permissions may need re-authorization after reinstall)."; \
		codesign --force --deep --sign - "$(APP_BUNDLE)"; \
	else \
		echo "Error: no CODE_SIGN_IDENTITY set."; \
		echo "Set CODE_SIGN_IDENTITY to a stable signing identity (recommended), or run with ALLOW_ADHOC=1."; \
		exit 1; \
	fi

run: build
	open $(APP_BUNDLE)

install: build
	mkdir -p $$HOME/Applications
	rm -rf $$HOME/Applications/$(APP_NAME).app
	cp -R $(APP_BUNDLE) $$HOME/Applications/$(APP_NAME).app

clean:
	rm -rf .build $(BUILD_DIR)
