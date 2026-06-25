.PHONY: build clean

APP_NAME = Dashee
MAIN_SCRIPT = main.py

build:
	@echo "Building native macOS application bundle..."
	python3 -m PyInstaller \
		--noconfirm \
		--windowed \
		--name "$(APP_NAME)" \
		--hidden-import=requests \
		--hidden-import=dotenv \
		$(MAIN_SCRIPT)
	@echo "Build complete. App bundle located in dist/$(APP_NAME).app"

clean:
	rm -rf build/ dist/ $(APP_NAME).spec
	find . -type d -name __pycache__ -exec rm -r {} +
