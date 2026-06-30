APP_NAME = ObsidianTodoBar
BUILD_DIR = .build
LOCAL_APPS = $(HOME)/Applications

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
	rm -rf /tmp/$(APP_NAME).app
	rm -rf $(LOCAL_APPS)/$(APP_NAME).app

launch:
	./Scripts/launch.sh

launch-release:
	./Scripts/launch.sh release

install: build
	rm -rf $(LOCAL_APPS)/$(APP_NAME).app
	mkdir -p $(LOCAL_APPS)
	cp -R /tmp/$(APP_NAME).app $(LOCAL_APPS)/$(APP_NAME).app
	codesign -f -s - --deep $(LOCAL_APPS)/$(APP_NAME).app 2>/dev/null || true
	open $(LOCAL_APPS)/$(APP_NAME).app

uninstall:
	rm -rf $(LOCAL_APPS)/$(APP_NAME).app
