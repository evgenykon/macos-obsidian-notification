APP_NAME = ObsidianTodoBar
BUILD_DIR = .build
RELEASE_DIR = $(BUILD_DIR)/release

.PHONY: all build run release clean install uninstall

all: build

build:
	swift build

run:
	swift run

release:
	swift build -c release

clean:
	swift package clean
	rm -rf $(BUILD_DIR)

install: release
	cp -R $(RELEASE_DIR)/$(APP_NAME) /Applications/$(APP_NAME).app

uninstall:
	rm -rf /Applications/$(APP_NAME).app
