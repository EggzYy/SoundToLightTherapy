#!/bin/bash

# iOS Deployment Script for SoundToLightTherapy
# Alternative deployment methods for iOS when xtool has dependency conflicts

set -euo pipefail

# Configuration
PRODUCT_NAME="SoundToLightTherapy"
BUNDLE_ID="com.yourcompany.soundtolighttherapy"
SCHEME_NAME="SoundToLightTherapyApp"
BUILD_DIR="build"
DEPLOYMENT_TARGET="17.0"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_banner() {
    echo -e "${BLUE}"
    echo "=================================================================="
    echo "  SoundToLightTherapy iOS Deployment Script"
    echo "  Alternative Methods for Cross-Platform iOS Building"
    echo "=================================================================="
    echo -e "${NC}"
}

check_requirements() {
    log_info "Checking deployment requirements..."

    # Check if running on macOS (required for iOS building)
    if [[ "$OSTYPE" != "darwin"* ]]; then
        log_error "iOS building requires macOS. Current OS: $OSTYPE"
        log_info "Consider using GitHub Actions workflow instead:"
        log_info "  gh workflow run ios-build.yml"
        exit 1
    fi

    # Check Xcode
    if ! command -v xcodebuild &> /dev/null; then
        log_error "Xcode command line tools not found. Install with:"
        log_info "  xcode-select --install"
        exit 1
    fi

    # Check Swift
    if ! command -v swift &> /dev/null; then
        log_error "Swift not found. Install Xcode and command line tools."
        exit 1
    fi

    local xcode_version=$(xcodebuild -version | head -n 1)
    local swift_version=$(swift --version | head -n 1)

    log_success "Xcode: $xcode_version"
    log_success "Swift: $swift_version"
}

setup_directories() {
    log_info "Setting up build directories..."

    mkdir -p "$BUILD_DIR"
    mkdir -p "Resources/iOS"

    log_success "Directories created"
}

generate_ios_resources() {
    log_info "Generating iOS-specific resources..."

    # Generate Info.plist
    cat > "Resources/iOS/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>Sound to Light Therapy</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$(PRODUCT_NAME)</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSRequiresIPhoneOS</key>
    <true/>
    <key>UILaunchStoryboardName</key>
    <string>LaunchScreen</string>
    <key>UIRequiredDeviceCapabilities</key>
    <array>
        <string>armv7</string>
    </array>
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>
    <key>UISupportedInterfaceOrientations~ipad</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationPortraitUpsideDown</string>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>
    <key>NSMicrophoneUsageDescription</key>
    <string>This app uses the microphone to detect sound frequencies for therapeutic light synchronization.</string>
    <key>UIViewControllerBasedStatusBarAppearance</key>
    <false/>
    <key>ITSAppUsesNonExemptEncryption</key>
    <false/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.healthcare-fitness</string>
</dict>
</plist>
EOF

    # Generate PrivacyInfo.xcprivacy
    cat > "Resources/iOS/PrivacyInfo.xcprivacy" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyTracking</key>
    <false/>
    <key>NSPrivacyCollectedDataTypes</key>
    <array/>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryMicrophone</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>3B52.1</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
EOF

    log_success "iOS resources generated"
}

generate_xcode_project() {
    log_info "Generating Xcode project from SwiftPM..."

    # Generate Xcode project
    if swift package generate-xcodeproj --skip-extra-files; then
        log_success "Xcode project generated successfully"
    else
        log_error "Failed to generate Xcode project"
        log_info "Trying alternative method with xcodegen..."

        # Check if xcodegen is available
        if command -v xcodegen &> /dev/null; then
            # Create project.yml for xcodegen
            create_xcodegen_config
            xcodegen generate
            log_success "Xcode project generated with xcodegen"
        else
            log_error "xcodegen not found. Install with: brew install xcodegen"
            exit 1
        fi
    fi
}

create_xcodegen_config() {
    log_info "Creating XcodeGen configuration..."

    cat > "project.yml" << EOF
name: $PRODUCT_NAME
options:
  bundleIdPrefix: com.yourcompany
  deploymentTarget:
    iOS: "$DEPLOYMENT_TARGET"

targets:
  $SCHEME_NAME:
    type: application
    platform: iOS
    sources:
      - Sources/SoundToLightTherapy
    info:
      path: Resources/iOS/Info.plist
    settings:
      PRODUCT_BUNDLE_IDENTIFIER: $BUNDLE_ID
      INFOPLIST_FILE: Resources/iOS/Info.plist
      IPHONEOS_DEPLOYMENT_TARGET: $DEPLOYMENT_TARGET
      SWIFT_VERSION: 6.0
    dependencies:
      - package: swift-cross-ui
        product: SwiftCrossUI
      - package: swift-cross-ui
        product: DefaultBackend

packages:
  swift-cross-ui:
    url: https://github.com/stackotter/swift-cross-ui
    revision: a02da752cf9cd50c99b3ce43d573975b69225d58
EOF

    log_success "XcodeGen configuration created"
}

build_for_simulator() {
    log_info "Building for iOS Simulator..."

    xcodebuild build \
        -project "$PRODUCT_NAME.xcodeproj" \
        -scheme "$SCHEME_NAME" \
        -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=latest' \
        -configuration Debug \
        CODE_SIGNING_ALLOWED=NO \
        ONLY_ACTIVE_ARCH=NO \
        -derivedDataPath "$BUILD_DIR/DerivedData"

    log_success "Simulator build completed"
}

build_for_device() {
    log_info "Building for iOS Device..."

    xcodebuild build \
        -project "$PRODUCT_NAME.xcodeproj" \
        -scheme "$SCHEME_NAME" \
        -destination 'generic/platform=iOS' \
        -configuration Release \
        CODE_SIGNING_ALLOWED=NO \
        ONLY_ACTIVE_ARCH=NO \
        -derivedDataPath "$BUILD_DIR/DerivedData"

    log_success "Device build completed"
}

archive_app() {
    log_info "Creating app archive..."

    xcodebuild archive \
        -project "$PRODUCT_NAME.xcodeproj" \
        -scheme "$SCHEME_NAME" \
        -destination 'generic/platform=iOS' \
        -configuration Release \
        -archivePath "$BUILD_DIR/$PRODUCT_NAME.xcarchive" \
        CODE_SIGNING_ALLOWED=NO \
        SKIP_INSTALL=NO \
        -derivedDataPath "$BUILD_DIR/DerivedData"

    log_success "App archived successfully"
}

export_ipa() {
    log_info "Exporting IPA..."

    # Create export options plist
    cat > "$BUILD_DIR/ExportOptions.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>development</string>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
    <key>compileBitcode</key>
    <false/>
</dict>
</plist>
EOF

    xcodebuild -exportArchive \
        -archivePath "$BUILD_DIR/$PRODUCT_NAME.xcarchive" \
        -exportPath "$BUILD_DIR" \
        -exportOptionsPlist "$BUILD_DIR/ExportOptions.plist"

    if [ -f "$BUILD_DIR/$PRODUCT_NAME.ipa" ]; then
        log_success "IPA exported successfully: $BUILD_DIR/$PRODUCT_NAME.ipa"
    else
        log_error "IPA export failed"
        exit 1
    fi
}

run_tests() {
    log_info "Running tests..."

    # SwiftPM tests first
    if swift test --parallel; then
        log_success "SwiftPM tests passed"
    else
        log_warning "SwiftPM tests failed or skipped"
    fi

    # iOS-specific tests if Xcode project exists
    if [ -f "$PRODUCT_NAME.xcodeproj/project.pbxproj" ]; then
        if xcodebuild test \
            -project "$PRODUCT_NAME.xcodeproj" \
            -scheme "$SCHEME_NAME" \
            -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=latest' \
            -configuration Debug; then
            log_success "iOS tests passed"
        else
            log_warning "iOS tests failed"
        fi
    fi
}

show_alternatives() {
    echo
    log_info "Alternative deployment methods:"
    echo
    echo "1. GitHub Actions (Recommended):"
    echo "   - Push code to GitHub"
    echo "   - Run: gh workflow run ios-build.yml"
    echo "   - Download artifacts from Actions tab"
    echo
    echo "2. xtool (when dependencies fixed):"
    echo "   - Resolve swift-windowsfoundation dependency conflict"
    echo "   - Run: xtool dev"
    echo
    echo "3. Apple Container (2025 method):"
    echo "   - Use Swift Container Plugin"
    echo "   - Cross-compile with static Linux SDK"
    echo "   - Build container with iOS support"
    echo
}

print_deployment_summary() {
    echo
    log_success "Deployment Summary:"
    echo "  📱 Product: $PRODUCT_NAME"
    echo "  📦 Bundle ID: $BUNDLE_ID"
    echo "  🎯 Deployment Target: iOS $DEPLOYMENT_TARGET+"
    echo "  📁 Build Directory: $BUILD_DIR/"
    echo
    if [ -f "$BUILD_DIR/$PRODUCT_NAME.ipa" ]; then
        echo "  ✅ IPA Ready: $BUILD_DIR/$PRODUCT_NAME.ipa"
        echo
        echo "Next steps:"
        echo "  1. Install on device: Use Xcode or third-party tools"
        echo "  2. TestFlight: Upload to App Store Connect"
        echo "  3. Enterprise: Use enterprise distribution profile"
    fi
    echo
}

# Main execution
main() {
    print_banner

    case "${1:-build}" in
        "build")
            check_requirements
            setup_directories
            generate_ios_resources
            generate_xcode_project
            build_for_simulator
            run_tests
            ;;
        "release")
            check_requirements
            setup_directories
            generate_ios_resources
            generate_xcode_project
            build_for_device
            archive_app
            export_ipa
            run_tests
            ;;
        "test")
            check_requirements
            generate_xcode_project
            run_tests
            ;;
        "clean")
            log_info "Cleaning build artifacts..."
            rm -rf "$BUILD_DIR"
            rm -rf ".build"
            rm -f "$PRODUCT_NAME.xcodeproj"
            rm -f "project.yml"
            rm -rf "Resources"
            log_success "Clean completed"
            ;;
        "help"|"-h"|"--help")
            echo "Usage: $0 [command]"
            echo
            echo "Commands:"
            echo "  build     Build for iOS Simulator (default)"
            echo "  release   Build and create IPA for device"
            echo "  test      Run tests only"
            echo "  clean     Clean build artifacts"
            echo "  help      Show this help"
            echo
            show_alternatives
            exit 0
            ;;
        *)
            log_error "Unknown command: $1"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac

    print_deployment_summary
}

# Run main function with all arguments
main "$@"
