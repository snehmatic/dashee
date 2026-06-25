APP_NAME = Dashee
BUNDLE_ID = com.snehmatic.dashee

all: build

build:
	@echo "Building SwiftUI App..."
	@mkdir -p dist/$(APP_NAME).app/Contents/MacOS
	@mkdir -p dist/$(APP_NAME).app/Contents/Resources
	
	@echo "Compiling Swift files..."
	swiftc Sources/Models.swift Sources/Views.swift \
		-o dist/$(APP_NAME).app/Contents/MacOS/$(APP_NAME) \
		-target arm64-apple-macosx11.0 \
		-framework SwiftUI -framework AppKit -framework Foundation
		
	@echo "Copying Info.plist..."
	cp Info.plist dist/$(APP_NAME).app/Contents/Info.plist
	
	@echo "Build complete: dist/$(APP_NAME).app"

clean:
	rm -rf dist/
