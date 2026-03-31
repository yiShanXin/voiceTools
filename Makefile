APP_NAME := VoiceTools
BUILD_DIR := build
APP_BUNDLE := $(BUILD_DIR)/$(APP_NAME).app
EXECUTABLE := .build/release/$(APP_NAME)

.PHONY: build run install clean

build:
	swift build -c release
	mkdir -p $(APP_BUNDLE)/Contents/MacOS
	mkdir -p $(APP_BUNDLE)/Contents/Resources
	cp $(EXECUTABLE) $(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)
	cp Info.plist $(APP_BUNDLE)/Contents/Info.plist
	codesign --force --deep --sign - $(APP_BUNDLE)

run: build
	open $(APP_BUNDLE)

install: build
	mkdir -p $$HOME/Applications
	rm -rf $$HOME/Applications/$(APP_NAME).app
	cp -R $(APP_BUNDLE) $$HOME/Applications/$(APP_NAME).app

clean:
	rm -rf .build $(BUILD_DIR)
