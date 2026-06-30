APP_NAME = ObsidianTodoBar
BUILD_DIR = .build
BUNDLE_DIR = $(HOME)/Applications/$(APP_NAME).app

.PHONY: all build run release clean launch launch-release install uninstall

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
	rm -rf $(BUNDLE_DIR)

launch:
	./Scripts/launch.sh

launch-release:
	./Scripts/launch.sh release
