# EchoText Development Makefile
# Improves developer experience with quick commands

SCHEME = EchoText
PROJECT = EchoText.xcodeproj
BUILD_DIR = build-output
APP_PATH = $(BUILD_DIR)/Build/Products/Debug/EchoText.app
BUNDLE_ID = com.echotext.app

# Colors for output
GREEN = \033[0;32m
YELLOW = \033[0;33m
RED = \033[0;31m
CYAN = \033[0;36m
NC = \033[0m # No Color

.PHONY: all build run clean rebuild install-deps open-settings grant-accessibility help fresh verify

# Default target
all: build

# Build the app (incremental)
build:
	@echo "$(GREEN)Building EchoText...$(NC)"
	@xcodebuild -project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration Debug \
		-derivedDataPath $(BUILD_DIR) \
		-destination 'platform=macOS' \
		ONLY_ACTIVE_ARCH=YES \
		CODE_SIGN_IDENTITY="-" \
		CODE_SIGNING_REQUIRED=NO \
		CODE_SIGNING_ALLOWED=NO \
		2>&1 | grep -E "^(Build|Compiling|Linking|error:|warning:|\*\*)" || true
	@echo "$(GREEN)Build complete!$(NC)"
	@echo "$(CYAN)Built at: $$(date '+%H:%M:%S')$(NC)"

# Build with full output (for debugging build issues)
build-verbose:
	@echo "$(GREEN)Building EchoText (verbose)...$(NC)"
	xcodebuild -project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration Debug \
		-derivedDataPath $(BUILD_DIR) \
		-destination 'platform=macOS' \
		ONLY_ACTIVE_ARCH=YES \
		CODE_SIGN_IDENTITY="-" \
		CODE_SIGNING_REQUIRED=NO \
		CODE_SIGNING_ALLOWED=NO

# Force rebuild by touching all Swift files (invalidates cache)
fresh:
	@echo "$(YELLOW)Forcing fresh build (touching all Swift files)...$(NC)"
	@find EchoText -name "*.swift" -exec touch {} \;
	@$(MAKE) build
	@echo "$(GREEN)Fresh build complete!$(NC)"

# Nuclear option: clean DerivedData and rebuild
fresh-clean:
	@echo "$(RED)Nuclear rebuild: cleaning all caches...$(NC)"
	@rm -rf $(BUILD_DIR)
	@rm -rf ~/Library/Developer/Xcode/DerivedData/EchoText-*
	@$(MAKE) build
	@echo "$(GREEN)Fresh clean build complete!$(NC)"

# Build and run the app
run: build
	@echo "$(GREEN)Launching EchoText...$(NC)"
	@open "$(APP_PATH)"

# Force fresh build and run
run-fresh: fresh
	@echo "$(GREEN)Launching EchoText...$(NC)"
	@open "$(APP_PATH)"

# Run without rebuilding (use existing build)
run-only:
	@if [ -d "$(APP_PATH)" ]; then \
		echo "$(GREEN)Launching EchoText...$(NC)"; \
		open "$(APP_PATH)"; \
	else \
		echo "$(RED)App not found. Run 'make build' first.$(NC)"; \
		exit 1; \
	fi

# Verify when the app was built (check binary modification time)
verify:
	@echo "$(CYAN)Build verification:$(NC)"
	@if [ -d "$(APP_PATH)" ]; then \
		echo "  App path: $(APP_PATH)"; \
		echo "  Binary modified: $$(stat -f '%Sm' '$(APP_PATH)/Contents/MacOS/EchoText' 2>/dev/null || echo 'Not found')"; \
		echo "  Current time:    $$(date '+%b %d %H:%M:%S %Y')"; \
		echo ""; \
		echo "$(YELLOW)Recent source changes:$(NC)"; \
		find EchoText -name "*.swift" -mmin -5 -exec ls -la {} \; 2>/dev/null | head -5 || echo "  No changes in last 5 minutes"; \
	else \
		echo "$(RED)App not built yet. Run 'make build' first.$(NC)"; \
	fi

# Clean build artifacts
clean:
	@echo "$(YELLOW)Cleaning build artifacts...$(NC)"
	@rm -rf $(BUILD_DIR)
	@rm -f build_log*.txt
	@echo "$(GREEN)Clean complete!$(NC)"

# Full rebuild (clean + build)
rebuild: clean build

# Install Swift package dependencies
install-deps:
	@echo "$(GREEN)Resolving Swift Package dependencies...$(NC)"
	@xcodebuild -project $(PROJECT) -scheme $(SCHEME) -resolvePackageDependencies

# Open Accessibility settings directly
open-settings:
	@echo "$(YELLOW)Opening Accessibility Settings...$(NC)"
	@open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"

# Grant accessibility (shows instructions)
grant-accessibility:
	@echo "$(YELLOW)============================================$(NC)"
	@echo "$(YELLOW)  Granting Accessibility Permissions$(NC)"
	@echo "$(YELLOW)============================================$(NC)"
	@echo ""
	@echo "To preserve accessibility permissions across builds:"
	@echo ""
	@echo "1. Open System Settings > Privacy & Security > Accessibility"
	@echo "2. Click '+' and navigate to:"
	@echo "   $(APP_PATH)"
	@echo ""
	@echo "3. IMPORTANT: After adding, run this to lock the path:"
	@echo "   $(GREEN)sudo tccutil reset Accessibility $(BUNDLE_ID)$(NC)"
	@echo ""
	@echo "Tip: Using ad-hoc signing (make build) helps preserve permissions"
	@echo "     since the code signature stays consistent."
	@echo ""
	@open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"

# Kill running instance
kill:
	@echo "$(YELLOW)Stopping EchoText...$(NC)"
	@pkill -x EchoText 2>/dev/null || echo "EchoText not running"

# Restart the app (kill + run)
restart: kill run

# Restart with forced fresh build
restart-fresh: kill run-fresh

# Watch for changes and rebuild (requires fswatch: brew install fswatch)
watch:
	@echo "$(GREEN)Watching for changes... (Ctrl+C to stop)$(NC)"
	@fswatch -o EchoText/ | xargs -n1 -I{} make build

# Open project in Xcode
xcode:
	@open $(PROJECT)

# Create and publish a release
release:
	@echo "$(GREEN)Creating release...$(NC)"
	@./scripts/release.sh

# Show help
help:
	@echo "$(GREEN)EchoText Development Commands$(NC)"
	@echo ""
	@echo "  $(CYAN)Standard builds:$(NC)"
	@echo "  $(YELLOW)make build$(NC)         - Incremental build (fast, may use cache)"
	@echo "  $(YELLOW)make run$(NC)           - Build and run"
	@echo "  $(YELLOW)make restart$(NC)       - Kill and restart"
	@echo ""
	@echo "  $(CYAN)Guaranteed fresh builds (use if changes don't appear):$(NC)"
	@echo "  $(YELLOW)make fresh$(NC)         - Touch files + build (forces recompile)"
	@echo "  $(YELLOW)make run-fresh$(NC)     - Fresh build + run"
	@echo "  $(YELLOW)make restart-fresh$(NC) - Kill + fresh build + run"
	@echo "  $(YELLOW)make fresh-clean$(NC)   - Nuclear: delete all caches + rebuild"
	@echo ""
	@echo "  $(CYAN)Utilities:$(NC)"
	@echo "  $(YELLOW)make verify$(NC)        - Check when app was last built"
	@echo "  $(YELLOW)make clean$(NC)         - Remove build artifacts"
	@echo "  $(YELLOW)make rebuild$(NC)       - Clean + build"
	@echo "  $(YELLOW)make run-only$(NC)      - Run without rebuilding"
	@echo "  $(YELLOW)make kill$(NC)          - Stop running EchoText"
	@echo ""
	@echo "  $(CYAN)Permissions:$(NC)"
	@echo "  $(YELLOW)make open-settings$(NC) - Open Accessibility settings"
	@echo ""
	@echo "  $(CYAN)Release:$(NC)"
	@echo "  $(YELLOW)make release$(NC)       - Build, sign, and publish release"
	@echo ""
	@echo "  $(CYAN)Other:$(NC)"
	@echo "  $(YELLOW)make xcode$(NC)         - Open project in Xcode"
	@echo "  $(YELLOW)make watch$(NC)         - Auto-rebuild on file changes"
	@echo ""
	@echo "$(GREEN)Tip:$(NC) If your changes don't appear, use $(YELLOW)make restart-fresh$(NC)"
