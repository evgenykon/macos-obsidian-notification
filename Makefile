APP_NAME = ObsidianTodoBar
BUILD_DIR = .build

.PHONY: all build run release clean launch install uninstall

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

launch:
	./Scripts/launch.sh

launch-release:
	./Scripts/launch.sh release

install: launch-release
	cp -R /tmp/$(APP_NAME).app /Applications/$(APP_NAME).app

uninstall:
	rm -rf /Applications/$(APP_NAME).app
