APP_NAME = Revolution 2
APP_BUNDLE = $(APP_NAME).app
CACHE_DIR = ./cache
BIN_DIR = ./bin
SRC_DIR = ./src
RES_DIR = $(SRC_DIR)/Resources

SWIFTC = swiftc
SWIFTC_FLAGS = -module-cache-path $(CACHE_DIR) -parse-as-library -O

SOURCES = $(SRC_DIR)/Models.swift \
          $(SRC_DIR)/Storage.swift \
          $(SRC_DIR)/UIState.swift \
          $(SRC_DIR)/IPCServer.swift \
          $(SRC_DIR)/Views.swift \
          $(SRC_DIR)/AppDelegate.swift \
          $(SRC_DIR)/Main.swift

.PHONY: all app sign dmg run install clean

all: app

app:
	@mkdir -p $(CACHE_DIR) "$(APP_BUNDLE)/Contents/MacOS" "$(APP_BUNDLE)/Contents/Resources"
	@echo "Compiling $(APP_NAME)..."
	$(SWIFTC) $(SWIFTC_FLAGS) $(SOURCES) -o "$(APP_BUNDLE)/Contents/MacOS/Revolution2"
	@cp -f $(RES_DIR)/Info.plist "$(APP_BUNDLE)/Contents/Info.plist"
	@cp -f $(RES_DIR)/AppIcon.icns "$(APP_BUNDLE)/Contents/Resources/AppIcon.icns"
	@cp -f $(RES_DIR)/AppIcon.png "$(APP_BUNDLE)/Contents/Resources/AppIcon.png"
	@chmod +x "$(APP_BUNDLE)/Contents/MacOS/Revolution2"
	@chmod +x $(BIN_DIR)/revolution $(BIN_DIR)/revolution-mcp
	@xattr -cr "$(APP_BUNDLE)"
	@codesign --force --deep --sign - "$(APP_BUNDLE)"
	@echo "✓ Built and ad-hoc signed $(APP_BUNDLE)"

sign:
	@xattr -cr "$(APP_BUNDLE)"
	@codesign --force --deep --sign - "$(APP_BUNDLE)"
	@codesign --verify --verbose "$(APP_BUNDLE)"

dmg: app
	@rm -rf dmg_staging ./Revolution-2.dmg
	@mkdir -p dmg_staging
	@cp -R "$(APP_BUNDLE)" dmg_staging/
	@ln -s /Applications dmg_staging/Applications
	@diskutil image create from --volumeName "$(APP_NAME)" --format UDZO ./dmg_staging ./Revolution-2.dmg
	@rm -rf dmg_staging
	@echo "✓ Created signed Revolution-2.dmg"

run: app
	open "$(APP_BUNDLE)"

install: app
	@rm -rf "/Applications/$(APP_BUNDLE)"
	@cp -R "$(APP_BUNDLE)" "/Applications/$(APP_BUNDLE)"
	@echo "✓ Installed to /Applications/$(APP_BUNDLE)"

clean:
	@rm -rf $(CACHE_DIR) "$(APP_BUNDLE)"
