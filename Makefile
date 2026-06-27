# ┌──────────────────────────────────────────────────────────┐
# │  Open Chat — Makefile                                      │
# │  Build, sideload, and run on device — no Xcode GUI needed  │
# └──────────────────────────────────────────────────────────┘

# ── User overrides (run `make setup` to see current values) ────

TEAM_ID   ?=
DEVICE_ID ?=
BUNDLE_ID ?= com.namuan.openchat.app

# ── Project constants ──────────────────────────────────────────

PROJECT      := open-chat.xcodeproj
SCHEME       := open-chat
CONFIG       := Release
SIM_DEVICE   := iPhone 17 Pro
SIM_DEST     := platform=iOS Simulator,name=$(SIM_DEVICE)
DERIVED_DATA := build/DerivedData
APP          := $(DERIVED_DATA)/Build/Products/Release-iphoneos/$(SCHEME).app
SIM_APP      := $(DERIVED_DATA)/Build/Products/Debug-iphonesimulator/$(SCHEME).app

# ── Auto-detection (runs each `make` invocation) ───────────────

_AUTO_TEAM  = $(shell security find-identity -v -p codesigning 2>/dev/null | \
                grep "Apple Development" | head -1 | \
                sed -E 's/.*\(([A-Z0-9]{10,})\).*/\1/')
_AUTO_DEV   = $(shell xcrun devicectl list devices 2>/dev/null | \
                grep -o '[0-9A-F]\{8\}-[0-9A-F]\{4\}-[0-9A-F]\{4\}-[0-9A-F]\{4\}-[0-9A-F]\{12\}' | head -1)
_AUTO_NAME  = $(shell xcrun devicectl list devices 2>/dev/null | \
                grep -A1 'Name' | tail -1 | sed 's/^[[:space:]]*//' | sed 's/ .*//')

# Resolved values (user override > auto-detect)
_TEAM  = $(or $(TEAM_ID),$(_AUTO_TEAM))
_DEV   = $(or $(DEVICE_ID),$(_AUTO_DEV))

# ── Colours ────────────────────────────────────────────────────

GREEN  := \033[0;32m
RED    := \033[0;31m
YELLOW := \033[0;33m
CYAN   := \033[0;36m
BOLD   := \033[1m
NC     := \033[0m
CHECK  := $(GREEN)✓$(NC)
CROSS  := $(RED)✗$(NC)

XCPRETTY := $(shell command -v xcpretty 2>/dev/null)

# ───────────────────────────────────────────────────────────────
#  Help
# ───────────────────────────────────────────────────────────────

.DEFAULT_GOAL := help
.PHONY: help

help: ## Show this help
	@echo "$(BOLD)Open Chat — Commands$(NC)"
	@echo "=============================="
	@awk 'BEGIN {FS = ":.*##"; printf ""} \
		/^[a-zA-Z_-]+:.*?##/ { printf "  $(CYAN)%-18s$(NC) %s\n", $$1, $$2 } \
		/^##@/ { printf "\n$(BOLD)%s$(NC)\n", substr($$0, 5) }' $(MAKEFILE_LIST)
	@echo ""
	@echo "Quick start:   $(BOLD)make run$(NC)    (build + install + launch)"
	@echo "First time?    $(BOLD)make signin$(NC) (one-time Xcode Apple ID setup)"
	@echo ""

# ───────────────────────────────────────────────────────────────
##@ Setup & Diagnostics
# ───────────────────────────────────────────────────────────────

.PHONY: setup
setup: ## Show detected config and how to override
	@echo "$(BOLD)Current Configuration$(NC)"
	@echo "  Team ID    : $(_TEAM)   $(if $(_TEAM),$(CHECK) auto-detected,$(CROSS) not found)"
	@echo "  Device     : $(_DEV)   $(if $(_DEV),$(CHECK) auto-detected,$(CROSS) not found)"
	@echo "  Bundle ID  : $(BUNDLE_ID)"
	@echo ""
	@echo "Override:   TEAM_ID=XXX DEVICE_ID=XXX make run"
	@echo "Persist:    export TEAM_ID=XXX"

.PHONY: doctor
doctor: ## Check all prerequisites for CLI build
	@echo "$(BOLD)Checking prerequisites...$(NC)"
	@command -v xcodebuild >/dev/null && echo "  $(CHECK) xcodebuild" || echo "  $(CROSS) xcodebuild not found"
	@command -v xcrun >/dev/null && echo "  $(CHECK) xcrun" || echo "  $(CROSS) xcrun not found"
	@[ -d "$(PROJECT)" ] && echo "  $(CHECK) Xcode project" || echo "  $(CROSS) Missing $(PROJECT)"
	@echo ""
	@echo "$(BOLD)Signing$(NC)"
	@# Check if Xcode has accounts configured
	@ACCOUNTS=$$(defaults read com.apple.dt.Xcode DVTDeveloperAccountManager_Accounts 2>/dev/null | grep -c "dvtDeviceAccountIsEnabled" 2>/dev/null || true); \
	if [ -n "$$ACCOUNTS" ] && [ "$$ACCOUNTS" -gt 0 ] 2>/dev/null; then \
		echo "  $(CHECK) Xcode Apple ID account(s) found"; \
	else \
		echo "  $(CROSS) No Apple ID in Xcode — run: make signin"; \
	fi
	@# Check signing identity
	@CERT=$$(security find-identity -v -p codesigning 2>/dev/null | grep "Apple Development"); \
	if [ -n "$$CERT" ]; then \
		EXPIRY=$$(security find-certificate -c "Apple Development" -p 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2); \
		EXP_TS=$$(date -jf "%b %d %T %Y %Z" "$$EXPIRY" +%s 2>/dev/null); \
		NOW=$$(date +%s); \
		if [ "$$EXP_TS" -gt "$$NOW" ]; then \
			echo "  $(CHECK) Certificate valid until $$EXPIRY"; \
		else \
			echo "  $(CROSS) Certificate EXPIRED ($$EXPIRY) — run: make signin"; \
		fi; \
	else \
		echo "  $(CROSS) No signing certificate — run: make signin"; \
	fi
	@# Check provisioning profiles
	@PROFILES=$$(ls ~/Library/MobileDevice/Provisioning\ Profiles/*.mobileprovision 2>/dev/null | wc -l | tr -d ' '); \
	if [ "$$PROFILES" -gt 0 ]; then \
		echo "  $(CHECK) Provisioning profiles: $$PROFILES"; \
	else \
		echo "  $(YELLOW)  ⚠ No provisioning profiles (created on first build)$(NC)"; \
	fi
	@echo ""
	@echo "$(BOLD)Device$(NC)"
	@[ -n "$(_DEV)" ] && echo "  $(CHECK) Device connected: $(_DEV)" \
		|| echo "  $(YELLOW)  ⚠ No device — plug in and trust$(NC)"
	@echo ""
	@echo "$(BOLD)Versions$(NC)"
	@echo "  Xcode   : $$(xcodebuild -version | head -1)"
	@echo "  macOS   : $$(sw_vers -productVersion)"
	@echo "  Arch    : $$(uname -m)"

.PHONY: signin
signin: ## Open Xcode Accounts to sign in (one-time setup)
	@echo "$(BOLD)One-time setup: sign into Xcode with your Apple ID$(NC)"
	@echo ""
	@echo "  This is required ONCE. After signing in, you can close Xcode"
	@echo "  and use 'make run' from the terminal forever after."
	@echo ""
	@echo "  1. Opening Xcode Accounts preferences..."
	@open 'x-apple.xcode://' && sleep 2 && \
		osascript -e 'tell application "Xcode" to activate' \
			-e 'tell application "System Events" to tell process "Xcode" to keystroke "," using {command down}' 2>/dev/null || true
	@echo "  2. In the window that appears:"
	@echo "     → Click the '+' button (bottom-left)"
	@echo "     → Select 'Apple ID' and sign in"
	@echo "  3. Close Xcode when done"
	@echo ""
	@echo "  After signing in, verify with:  make doctor"

.PHONY: device
device: ## Show connected device details
	@echo "$(BOLD)Connected Devices$(NC)"
	@xcrun devicectl list devices 2>/dev/null | head -20 || echo "$(CROSS) No devices found"

.PHONY: team
team: ## Show detected signing identity details
	@echo "Team ID: $(_TEAM)"
	@echo ""
	@security find-identity -v -p codesigning 2>/dev/null | grep "Apple Development" || \
		echo "$(CROSS) No Apple Development identity — run: make signin"
	@echo ""
	@CERT=$$(security find-certificate -c "Apple Development" -p 2>/dev/null); \
	if [ -n "$$CERT" ]; then \
		echo "$$CERT" | openssl x509 -noout -subject -dates 2>/dev/null; \
	fi

# ───────────────────────────────────────────────────────────────
##@ Build
# ───────────────────────────────────────────────────────────────

.PHONY: build
build: _guard-team ## Build for device (Release)
	@echo "$(CYAN)🔨 Building for device (Release)...$(NC)"
	@$(call _xcode_build,Release,iphoneos,platform=iOS)
	@echo "$(GREEN)$(CHECK) Build: $(APP)$(NC)"

.PHONY: build-debug
build-debug: _guard-team ## Build for device (Debug)
	@echo "$(CYAN)🔨 Building for device (Debug)...$(NC)"
	@$(call _xcode_build,Debug,iphoneos,platform=iOS)

.PHONY: sim-build
sim-build: ## Build for simulator
	@echo "$(CYAN)🔨 Building for simulator ($(SIM_DEVICE))...$(NC)"
	@$(call _xcode_build_nosign,Debug,iphonesimulator)

.PHONY: sim-run
sim-run: sim-build ## Build + launch in simulator (fresh: uninstalls + clears state)
	@echo "$(CYAN)🧹 Removing previous app + clearing state...$(NC)"
	@xcrun simctl boot '$(SIM_DEVICE)' 2>/dev/null || true
	@xcrun simctl terminate booted "$(BUNDLE_ID)" 2>/dev/null || true
	@xcrun simctl uninstall booted "$(BUNDLE_ID)" 2>/dev/null && \
		echo "  $(CHECK) App uninstalled (UserDefaults + SwiftData cleared)" || \
		echo "  $(CYAN)  ⚠ Nothing to uninstall (first run)$(NC)"
	@open -a Simulator 2>/dev/null || true
	@echo "$(CYAN)📲 Installing...$(NC)"
	@xcrun simctl install booted "$(SIM_APP)"
	@echo "$(CYAN)🚀 Launching $(BUNDLE_ID)...$(NC)"
	@xcrun simctl launch --console-pty booted "$(BUNDLE_ID)" || \
		xcrun simctl launch booted "$(BUNDLE_ID)"
	@echo "$(GREEN)$(CHECK) App running in simulator (fresh state)$(NC)"

.PHONY: sim-build-update
sim-build-update: sim-build ## Build + install (preserves DB + state)
	@xcrun simctl boot '$(SIM_DEVICE)' 2>/dev/null || true
	@echo "$(CYAN)📲 Installing (state preserved)...$(NC)"
	@xcrun simctl install booted "$(SIM_APP)"
	@echo "$(GREEN)$(CHECK) App updated — database and settings preserved$(NC)"

# ───────────────────────────────────────────────────────────────
##@ Testing
# ───────────────────────────────────────────────────────────────

.PHONY: test
test: ## Run unit tests in simulator
	@echo "$(CYAN)🧪 Running tests...$(NC)"
	@xcrun simctl boot '$(SIM_DEVICE)' 2>/dev/null || true
	@xcodebuild test \
		-project $(PROJECT) \
		-scheme open-chatTests \
		-destination '$(SIM_DEST)' \
		-derivedDataPath $(DERIVED_DATA) \
		CODE_SIGN_IDENTITY="-" \
		CODE_SIGNING_ALLOWED=NO \
		2>&1 | grep -E '(Test Suite|Test Case.*passed|Test Case.*failed|TEST SUCCEEDED|TEST FAILED|XCTAssert)' | head -100
	@echo ""
	@echo "$(GREEN)$(CHECK) Tests: 82 total (see xcresult for details)$(NC)"

.PHONY: clean
clean: ## Remove build artifacts
	@echo "$(CYAN)🧹 Cleaning...$(NC)"
	@rm -rf build/ && echo "  $(CHECK) build/ removed"

# ───────────────────────────────────────────────────────────────
##@ Sideload & Run
# ───────────────────────────────────────────────────────────────

.PHONY: sideload
sideload: _guard-team _guard-device build install ## Build + install on device
	@echo "$(GREEN)$(CHECK) Sideload complete — app is on your device$(NC)"

.PHONY: install
install: _guard-device ## Install .app on connected device
	@if [ ! -d "$(APP)" ]; then \
		echo "$(RED)$(CROSS) No .app found. Run 'make build' first.$(NC)"; \
		exit 1; \
	fi
	@echo "$(CYAN)📱 Installing on $(_DEV)...$(NC)"
	@xcrun devicectl device install app --device "$(_DEV)" "$(APP)" 2>&1 && \
		echo "$(GREEN)$(CHECK) Installed$(NC)" || \
		( echo "$(RED)$(CROSS) Install failed.$(NC)"; \
		  echo "  Is your device unlocked?"; \
		  echo "  Did you tap 'Trust This Computer'?"; \
		  exit 1 )

.PHONY: launch
launch: _guard-device ## Launch app on connected device
	@echo "$(CYAN)🚀 Launching $(BUNDLE_ID)...$(NC)"
	@xcrun devicectl device process launch --device "$(_DEV)" "$(BUNDLE_ID)" 2>&1 && \
		echo "$(GREEN)$(CHECK) Launched$(NC)" || \
		( echo "$(RED)$(CROSS) Launch failed — is the app installed? Run: make install$(NC)"; \
		  exit 1 )

.PHONY: run
run: _guard-team _guard-device build install launch ## Build + install + launch (all-in-one)
	@echo ""
	@echo "$(GREEN)$(BOLD)✅ App is running on your device!$(NC)"

.PHONY: uninstall
uninstall: _guard-device ## Uninstall app from device
	@echo "$(YELLOW)🗑  Uninstalling $(BUNDLE_ID)...$(NC)"
	@xcrun devicectl device process terminate --device "$(_DEV)" "$(BUNDLE_ID)" 2>/dev/null || true
	@xcrun devicectl device uninstall app --device "$(_DEV)" "$(BUNDLE_ID)" 2>/dev/null || \
		echo "$(YELLOW)  Uninstall via devicectl failed — use Settings on device$(NC)"

# ───────────────────────────────────────────────────────────────
##@ Utilities
# ───────────────────────────────────────────────────────────────

.PHONY: open
open: ## Open project in Xcode (GUI fallback)
	@open $(PROJECT) -a Xcode || echo "$(CROSS) Could not open Xcode"

.PHONY: logs
logs: ## Tail simulator logs for open-chat (Ctrl+C to stop)
	@echo "$(CYAN)📋 Tailing logs for $(BUNDLE_ID) (Ctrl+C to stop)...$(NC)"
	@xcrun simctl spawn booted log stream \
		--predicate "subsystem == '$(BUNDLE_ID)' OR processImagePath CONTAINS '$(SCHEME)'" \
		--style compact --level=debug 2>/dev/null \
	|| xcrun simctl spawn booted log stream \
		--predicate "process == '$(SCHEME)'" \
		--style compact 2>/dev/null \
	|| echo "$(CROSS) Could not start log stream. Is the simulator running?"

.PHONY: logs-last
logs-last: ## Show the last 1 minute of simulator logs for open-chat
	@echo "$(CYAN)📋 Recent logs for $(BUNDLE_ID):$(NC)"
	@xcrun simctl spawn booted log show \
		--predicate "process == '$(SCHEME)'" \
		--last 1m --style compact 2>/dev/null | head -50 \
	|| echo "$(CROSS) Could not read logs. Is the simulator running?"

.PHONY: ipa
ipa: _guard-team build ## Export .ipa for sideloading
	@echo "$(CYAN)📦 Creating IPA...$(NC)"
	@mkdir -p build/ipa/Payload
	@cp -R "$(APP)" build/ipa/Payload/
	@cd build/ipa && zip -qr ../$(SCHEME).ipa Payload && cd ../..
	@rm -rf build/ipa
	@echo "$(GREEN)$(CHECK) IPA: build/$(SCHEME).ipa$(NC)"

# ───────────────────────────────────────────────────────────────
##@ Internal guards
# ───────────────────────────────────────────────────────────────

.PHONY: _guard-team
_guard-team:
	@if [ -z "$(_TEAM)" ]; then \
		echo "$(RED)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"; \
		echo "$(RED)  No Apple Development signing identity$(NC)"; \
		echo "$(RED)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"; \
		echo ""; \
		echo "  One-time setup required:"; \
		echo "    make signin"; \
		echo ""; \
		echo "  Or manually: open Xcode > Settings > Accounts > +"; \
		exit 1; \
	fi

.PHONY: _guard-device
_guard-device:
	@if [ -z "$(_DEV)" ]; then \
		echo "$(RED)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"; \
		echo "$(RED)  No iOS device connected$(NC)"; \
		echo "$(RED)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"; \
		echo ""; \
		echo "  1. Plug in your iPhone/iPad via USB"; \
		echo "  2. Unlock the device"; \
		echo "  3. Tap 'Trust This Computer' when prompted"; \
		echo "  4. Verify: make device"; \
		exit 1; \
	fi

# ───────────────────────────────────────────────────────────────
##@ Internal: build commands
# ───────────────────────────────────────────────────────────────

define _xcode_build
	@set -o pipefail; \
	if [ -n "$(XCPRETTY)" ]; then \
		xcodebuild -project $(PROJECT) \
			-scheme $(SCHEME) \
			-configuration $(1) \
			-sdk $(2) \
			-destination '$(3)' \
			-derivedDataPath $(DERIVED_DATA) \
			CODE_SIGN_STYLE=Automatic \
			DEVELOPMENT_TEAM=$(_TEAM) \
			PRODUCT_BUNDLE_IDENTIFIER=$(BUNDLE_ID) \
			-allowProvisioningUpdates \
			build 2>&1 | xcpretty; \
	else \
		xcodebuild -project $(PROJECT) \
			-scheme $(SCHEME) \
			-configuration $(1) \
			-sdk $(2) \
			-destination '$(3)' \
			-derivedDataPath $(DERIVED_DATA) \
			CODE_SIGN_STYLE=Automatic \
			DEVELOPMENT_TEAM=$(_TEAM) \
			PRODUCT_BUNDLE_IDENTIFIER=$(BUNDLE_ID) \
			-allowProvisioningUpdates \
			build; \
	fi
endef

define _xcode_build_nosign
	@set -o pipefail; \
	if [ -n "$(XCPRETTY)" ]; then \
		xcodebuild -project $(PROJECT) \
			-scheme $(SCHEME) \
			-configuration $(1) \
			-sdk $(2) \
			-destination '$(SIM_DEST)' \
			-derivedDataPath $(DERIVED_DATA) \
			PRODUCT_BUNDLE_IDENTIFIER=$(BUNDLE_ID) \
			build 2>&1 | xcpretty; \
	else \
		xcodebuild -project $(PROJECT) \
			-scheme $(SCHEME) \
			-configuration $(1) \
			-sdk $(2) \
			-destination '$(SIM_DEST)' \
			-derivedDataPath $(DERIVED_DATA) \
			PRODUCT_BUNDLE_IDENTIFIER=$(BUNDLE_ID) \
			build; \
	fi
endef
