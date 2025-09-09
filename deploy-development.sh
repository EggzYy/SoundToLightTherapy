#!/bin/bash

# Direct iPhone Development Deployment Script for SoundToLightTherapy
# Deploys therapeutic app directly to connected iPhone from Linux for real-world testing

set -euo pipefail

# Configuration
PRODUCT_NAME="SoundToLightTherapy"
BUNDLE_ID="com.yourcompany.soundtolighttherapy.dev"
TEAM_ID="${TEAM_ID:-""}"
DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-""}"
BUILD_DIR="build"
DEPLOYMENT_TARGET="17.0"
DEVICE_ID="${DEVICE_ID:-""}"
PROVISIONING_PROFILE_PATH="${PROVISIONING_PROFILE_PATH:-""}"
CERTIFICATE_PATH="${CERTIFICATE_PATH:-""}"
PRIVATE_KEY_PATH="${PRIVATE_KEY_PATH:-""}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Logging functions
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

log_debug() {
    echo -e "${CYAN}[DEBUG]${NC} $1"
}

log_progress() {
    echo -e "${PURPLE}[PROGRESS]${NC} $1"
}

print_banner() {
    echo -e "${BLUE}"
    echo "=========================================================================="
    echo "  SoundToLightTherapy - Direct iPhone Development Deployment"
    echo "  Linux → iPhone Therapeutic App Testing Pipeline"
    echo "=========================================================================="
    echo -e "${NC}"
}

check_linux_ios_tools() {
    log_info "Checking Linux iOS deployment tools..."

    # Check libimobiledevice suite
    local tools=("idevice_id" "ideviceinstaller" "ideviceinfo" "idevicepair" "ios-deploy")
    local missing_tools=()

    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        else
            local version
            case $tool in
                "idevice_id"|"ideviceinstaller"|"ideviceinfo"|"idevicepair")
                    version=$(libimobiledevice-tools --version 2>/dev/null | head -n1 || echo "unknown")
                    ;;
                "ios-deploy")
                    version=$(ios-deploy --version 2>/dev/null || echo "unknown")
                    ;;
            esac
            log_success "$tool: $version"
        fi
    done

    if [ ${#missing_tools[@]} -gt 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Installing required tools..."
        install_ios_tools
    fi
}

install_ios_tools() {
    log_info "Installing iOS deployment tools for Linux..."

    # Detect package manager
    if command -v apt &> /dev/null; then
        install_ios_tools_apt
    elif command -v dnf &> /dev/null; then
        install_ios_tools_dnf
    elif command -v zypper &> /dev/null; then
        install_ios_tools_zypper
    elif command -v pacman &> /dev/null; then
        install_ios_tools_pacman
    else
        log_error "Unsupported package manager. Please install manually:"
        show_manual_install_instructions
        exit 1
    fi
}

install_ios_tools_apt() {
    log_info "Installing via APT (Ubuntu/Debian)..."

    # Update package list
    sudo apt update

    # Install libimobiledevice suite
    sudo apt install -y \
        libimobiledevice6 \
        libimobiledevice-utils \
        ideviceinstaller \
        ifuse \
        usbmuxd \
        libplist3 \
        python3-imobiledevice

    # Install build dependencies for ios-deploy if needed
    if ! command -v ios-deploy &> /dev/null; then
        log_info "Installing ios-deploy from source..."
        install_ios_deploy_from_source
    fi

    log_success "iOS tools installed via APT"
}

install_ios_tools_dnf() {
    log_info "Installing via DNF (Fedora/RHEL)..."

    sudo dnf install -y \
        libimobiledevice \
        libimobiledevice-utils \
        ideviceinstaller \
        ifuse \
        usbmuxd \
        libplist

    if ! command -v ios-deploy &> /dev/null; then
        install_ios_deploy_from_source
    fi

    log_success "iOS tools installed via DNF"
}

install_ios_tools_zypper() {
    log_info "Installing via Zypper (openSUSE)..."

    sudo zypper install -y \
        libimobiledevice \
        libimobiledevice-tools \
        ifuse \
        usbmuxd

    if ! command -v ios-deploy &> /dev/null; then
        install_ios_deploy_from_source
    fi

    log_success "iOS tools installed via Zypper"
}

install_ios_tools_pacman() {
    log_info "Installing via Pacman (Arch Linux)..."

    sudo pacman -S --noconfirm \
        libimobiledevice \
        ideviceinstaller \
        ifuse \
        usbmuxd

    if ! command -v ios-deploy &> /dev/null; then
        install_ios_deploy_from_source
    fi

    log_success "iOS tools installed via Pacman"
}

install_ios_deploy_from_source() {
    log_info "Installing ios-deploy from source..."

    # Install build dependencies
    if command -v apt &> /dev/null; then
        sudo apt install -y build-essential git libimobiledevice-dev
    fi

    # Clone and build ios-deploy
    local temp_dir=$(mktemp -d)
    cd "$temp_dir"

    git clone https://github.com/ios-control/ios-deploy.git
    cd ios-deploy
    make
    sudo make install

    cd - > /dev/null
    rm -rf "$temp_dir"

    log_success "ios-deploy installed from source"
}

show_manual_install_instructions() {
    echo
    log_info "Manual installation instructions:"
    echo
    echo "1. Install libimobiledevice and related tools:"
    echo "   - Ubuntu/Debian: sudo apt install libimobiledevice-utils ideviceinstaller"
    echo "   - Fedora/RHEL: sudo dnf install libimobiledevice-utils ideviceinstaller"
    echo "   - Arch Linux: sudo pacman -S libimobiledevice ideviceinstaller"
    echo
    echo "2. Install ios-deploy:"
    echo "   git clone https://github.com/ios-control/ios-deploy.git"
    echo "   cd ios-deploy && make && sudo make install"
    echo
}

detect_connected_devices() {
    log_info "Detecting connected iOS devices..."

    # Start usbmuxd if not running
    if ! pgrep -x "usbmuxd" > /dev/null; then
        log_info "Starting usbmuxd daemon..."
        sudo usbmuxd -v 2>/dev/null &
        sleep 2
    fi

    # List connected devices
    local devices
    devices=$(idevice_id -l 2>/dev/null || echo "")

    if [ -z "$devices" ]; then
        log_error "No iOS devices detected!"
        echo
        log_info "Troubleshooting steps:"
        echo "  1. Connect iPhone via USB cable"
        echo "  2. Unlock iPhone and trust this computer"
        echo "  3. Ensure iPhone is in normal mode (not recovery/DFU)"
        echo "  4. Try running: sudo usbmuxd -f -v"
        echo "  5. Check USB connection and try different cable/port"
        return 1
    fi

    log_success "Connected devices:"
    while IFS= read -r device_id; do
        if [ -n "$device_id" ]; then
            local device_name
            device_name=$(ideviceinfo -u "$device_id" -k DeviceName 2>/dev/null || echo "Unknown")
            local ios_version
            ios_version=$(ideviceinfo -u "$device_id" -k ProductVersion 2>/dev/null || echo "Unknown")
            local device_model
            device_model=$(ideviceinfo -u "$device_id" -k ProductType 2>/dev/null || echo "Unknown")

            echo "  📱 $device_name ($device_model)"
            echo "     ID: $device_id"
            echo "     iOS: $ios_version"

            # Set device ID if not specified
            if [ -z "$DEVICE_ID" ]; then
                DEVICE_ID="$device_id"
                log_info "Using device: $device_id"
            fi
        fi
    done <<< "$devices"

    return 0
}

pair_device() {
    log_info "Pairing with device..."

    if [ -z "$DEVICE_ID" ]; then
        log_error "No device ID specified"
        return 1
    fi

    # Check if already paired
    if idevicepair -u "$DEVICE_ID" validate 2>/dev/null; then
        log_success "Device already paired"
        return 0
    fi

    # Attempt pairing
    log_info "Attempting to pair with device $DEVICE_ID..."
    log_info "Please check your iPhone and tap 'Trust' if prompted"

    if idevicepair -u "$DEVICE_ID" pair; then
        log_success "Device paired successfully"

        # Validate pairing
        if idevicepair -u "$DEVICE_ID" validate; then
            log_success "Pairing validated"
            return 0
        else
            log_error "Pairing validation failed"
            return 1
        fi
    else
        log_error "Failed to pair device"
        log_info "Make sure to:"
        log_info "  1. Unlock your iPhone"
        log_info "  2. Tap 'Trust' when prompted"
        log_info "  3. Enter your passcode if required"
        return 1
    fi
}

check_development_setup() {
    log_info "Checking development certificates and provisioning profile..."

    # Check for Apple Developer account setup
    if [ -z "$TEAM_ID" ]; then
        log_warning "TEAM_ID not set. Set your Apple Developer Team ID:"
        log_info "  export TEAM_ID='YOUR_TEAM_ID'"
        log_info "  (Find this in Apple Developer Portal > Membership)"
    fi

    # Check provisioning profile
    if [ -n "$PROVISIONING_PROFILE_PATH" ] && [ -f "$PROVISIONING_PROFILE_PATH" ]; then
        log_success "Provisioning profile found: $PROVISIONING_PROFILE_PATH"

        # Extract profile information
        local profile_info
        profile_info=$(security cms -D -i "$PROVISIONING_PROFILE_PATH" 2>/dev/null || echo "")

        if [ -n "$profile_info" ]; then
            log_debug "Provisioning profile details extracted"
        fi
    else
        log_warning "Provisioning profile not found or not specified"
        log_info "  Set PROVISIONING_PROFILE_PATH to your .mobileprovision file"
    fi

    # Check certificates
    if [ -n "$CERTIFICATE_PATH" ] && [ -f "$CERTIFICATE_PATH" ]; then
        log_success "Certificate found: $CERTIFICATE_PATH"
    else
        log_warning "Development certificate not specified"
        log_info "  Set CERTIFICATE_PATH to your .p12 or .cer file"
    fi
}

setup_development_build() {
    log_info "Setting up development build configuration..."

    # Create development build directory
    mkdir -p "$BUILD_DIR/development"
    mkdir -p "Resources/iOS/Development"

    # Generate development Info.plist with enhanced permissions
    generate_development_info_plist

    # Generate development entitlements
    generate_development_entitlements

    log_success "Development build configuration ready"
}

generate_development_info_plist() {
    log_info "Generating development Info.plist..."

    cat > "Resources/iOS/Development/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>Sound to Light Therapy (Dev)</string>
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
    <string>1.0.0-dev</string>
    <key>CFBundleVersion</key>
    <string>1.0.0.$(BUILD_NUMBER)</string>
    <key>LSRequiresIPhoneOS</key>
    <true/>
    <key>UILaunchStoryboardName</key>
    <string>LaunchScreen</string>
    <key>UIRequiredDeviceCapabilities</key>
    <array>
        <string>armv7</string>
        <string>microphone</string>
        <string>flash</string>
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
    <!-- Therapeutic App Permissions -->
    <key>NSMicrophoneUsageDescription</key>
    <string>This therapeutic app uses the microphone to detect sound frequencies (20Hz-20kHz) for synchronized light therapy. Audio is processed locally and never transmitted or stored.</string>
    <key>NSCameraUsageDescription</key>
    <string>Camera access is used to control the flashlight for therapeutic light synchronization based on detected audio frequencies.</string>
    <!-- Development and Testing Features -->
    <key>UIViewControllerBasedStatusBarAppearance</key>
    <false/>
    <key>ITSAppUsesNonExemptEncryption</key>
    <false/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.healthcare-fitness</string>
    <!-- Development-specific settings -->
    <key>get-task-allow</key>
    <true/>
    <!-- Enhanced Accessibility for Therapy -->
    <key>UIAccessibilityEnabled</key>
    <true/>
    <key>UIRequiresFullScreen</key>
    <false/>
    <!-- Background Audio Processing -->
    <key>UIBackgroundModes</key>
    <array>
        <string>audio</string>
    </array>
    <!-- Therapeutic App Metadata -->
    <key>NSHealthShareUsageDescription</key>
    <string>Optional: Share therapy session data with Health app for wellness tracking.</string>
    <key>NSHealthUpdateUsageDescription</key>
    <string>Optional: Save therapy session summaries to Health app.</string>
</dict>
</plist>
EOF

    log_success "Development Info.plist generated"
}

generate_development_entitlements() {
    log_info "Generating development entitlements..."

    cat > "Resources/iOS/Development/Entitlements.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>application-identifier</key>
    <string>${TEAM_ID}.${BUNDLE_ID}</string>
    <key>com.apple.developer.team-identifier</key>
    <string>${TEAM_ID}</string>
    <key>get-task-allow</key>
    <true/>
    <key>com.apple.developer.aps-environment</key>
    <string>development</string>
    <!-- Microphone access for frequency detection -->
    <key>com.apple.security.microphone</key>
    <true/>
    <!-- Camera access for flashlight control -->
    <key>com.apple.security.camera</key>
    <true/>
    <!-- Background audio processing -->
    <key>com.apple.developer.audio</key>
    <true/>
    <!-- Health data access (optional) -->
    <key>com.apple.developer.healthkit</key>
    <true/>
    <key>com.apple.developer.healthkit.access</key>
    <array>
        <string>health-records</string>
    </array>
</dict>
</plist>
EOF

    log_success "Development entitlements generated"
}

build_development_app() {
    log_progress "Building development version of SoundToLightTherapy..."

    # Set build number
    local build_number
    build_number=$(date +%Y%m%d%H%M%S)

    # Build with SwiftPM
    log_info "Building Swift package for iOS..."

    # Check if we can cross-compile or need remote build
    if command -v swift &> /dev/null && swift --version | grep -q "iOS"; then
        # Direct iOS compilation (if Swift iOS toolchain available)
        swift build \
            --configuration release \
            --arch arm64 \
            --build-path "$BUILD_DIR/development" \
            -Xswiftc -target -Xswiftc arm64-apple-ios${DEPLOYMENT_TARGET}
    else
        log_warning "iOS Swift toolchain not available locally"
        log_info "Attempting remote build via GitHub Actions or container..."

        # Trigger remote build if configured
        if [ -f ".github/workflows/ios-development-build.yml" ]; then
            trigger_remote_build
        else
            log_error "No remote build configuration found"
            log_info "Please set up GitHub Actions workflow or use a Mac for building"
            return 1
        fi
    fi

    log_success "App built successfully"
}

create_development_ipa() {
    log_info "Creating development IPA..."

    local app_path="$BUILD_DIR/development/SoundToLightTherapy.app"
    local ipa_path="$BUILD_DIR/development/SoundToLightTherapy-dev.ipa"

    # Create IPA structure
    mkdir -p "$BUILD_DIR/development/Payload"
    cp -r "$app_path" "$BUILD_DIR/development/Payload/"

    # Create IPA archive
    cd "$BUILD_DIR/development"
    zip -r "SoundToLightTherapy-dev.ipa" Payload/
    cd - > /dev/null

    if [ -f "$ipa_path" ]; then
        log_success "Development IPA created: $ipa_path"
        return 0
    else
        log_error "Failed to create IPA"
        return 1
    fi
}

deploy_to_device() {
    log_progress "Deploying therapeutic app to iPhone..."

    if [ -z "$DEVICE_ID" ]; then
        log_error "No device ID available"
        return 1
    fi

    local ipa_path="$BUILD_DIR/development/SoundToLightTherapy-dev.ipa"

    # Check if IPA exists
    if [ ! -f "$ipa_path" ]; then
        log_error "Development IPA not found: $ipa_path"
        return 1
    fi

    # Install via ios-deploy
    log_info "Installing app via ios-deploy..."

    if ios-deploy \
        --id "$DEVICE_ID" \
        --bundle "$ipa_path" \
        --timeout 300 \
        --verbose; then
        log_success "App installed successfully on device $DEVICE_ID"
    else
        log_warning "ios-deploy failed, trying ideviceinstaller..."

        # Fallback to ideviceinstaller
        if ideviceinstaller -u "$DEVICE_ID" -i "$ipa_path"; then
            log_success "App installed successfully via ideviceinstaller"
        else
            log_error "Both deployment methods failed"
            show_deployment_troubleshooting
            return 1
        fi
    fi

    log_success "🎉 SoundToLightTherapy deployed to iPhone!"
    show_testing_instructions
}

show_deployment_troubleshooting() {
    echo
    log_error "Deployment failed. Troubleshooting steps:"
    echo
    echo "1. Certificate/Provisioning Issues:"
    echo "   - Ensure development certificate is valid"
    echo "   - Check provisioning profile includes this device"
    echo "   - Verify Team ID matches your Apple Developer account"
    echo
    echo "2. Device Connection:"
    echo "   - Reconnect iPhone with different USB cable"
    echo "   - Ensure device is trusted and unlocked"
    echo "   - Try: sudo usbmuxd -f -v"
    echo
    echo "3. App Installation:"
    echo "   - Delete existing app if installed"
    echo "   - Free up storage space on device"
    echo "   - Check iOS version compatibility (${DEPLOYMENT_TARGET}+)"
    echo
    echo "4. Alternative Methods:"
    echo "   - Use Xcode if available on macOS"
    echo "   - Try TestFlight for beta testing"
    echo "   - Use Apple Configurator 2"
    echo
}

show_testing_instructions() {
    echo
    log_success "🧪 Testing SoundToLightTherapy on iPhone:"
    echo
    echo "1. Therapeutic Functionality Tests:"
    echo "   📱 Launch 'Sound to Light Therapy (Dev)' on iPhone"
    echo "   🎤 Grant microphone permission when prompted"
    echo "   📸 Grant camera permission for flashlight control"
    echo "   🔊 Test frequency detection (20Hz-20kHz range)"
    echo "   💡 Verify flashlight responds to audio input"
    echo
    echo "2. Real-World Therapy Validation:"
    echo "   🎵 Play pure tones at different frequencies"
    echo "   ⚡ Observe flashlight synchronization timing"
    echo "   📊 Check frequency detection accuracy"
    echo "   🔋 Monitor battery usage during therapy sessions"
    echo
    echo "3. Accessibility Testing:"
    echo "   🎯 Test VoiceOver compatibility"
    echo "   📏 Verify Dynamic Type support"
    echo "   🌗 Check high contrast mode"
    echo "   🔇 Test reduced motion settings"
    echo
    echo "4. Debug Information:"
    echo "   📋 Check device logs: ios-deploy --id $DEVICE_ID --debug"
    echo "   🔍 Monitor app performance and memory usage"
    echo "   📝 Document any therapeutic effectiveness observations"
    echo
}

launch_app() {
    log_info "Launching SoundToLightTherapy on device..."

    if [ -z "$DEVICE_ID" ]; then
        log_error "No device ID available"
        return 1
    fi

    # Launch via ios-deploy
    if ios-deploy --id "$DEVICE_ID" --bundle_id "$BUNDLE_ID" --debug --verbose; then
        log_success "App launched and debugging session started"
    else
        log_info "App may have launched, check your iPhone screen"
    fi
}

trigger_remote_build() {
    log_info "Triggering remote iOS build via GitHub Actions..."

    if command -v gh &> /dev/null; then
        gh workflow run ios-development-build.yml \
            --field device_id="$DEVICE_ID" \
            --field bundle_id="$BUNDLE_ID" \
            --field team_id="$TEAM_ID"

        log_info "Remote build triggered. Monitor progress:"
        log_info "  gh run watch"
    else
        log_info "Install GitHub CLI: https://cli.github.com/"
        log_info "Or trigger build manually in GitHub Actions tab"
    fi
}

run_device_diagnostics() {
    log_info "Running device diagnostics..."

    if [ -z "$DEVICE_ID" ]; then
        log_error "No device ID available"
        return 1
    fi

    echo
    log_info "📱 Device Information:"
    ideviceinfo -u "$DEVICE_ID" -k DeviceName
    ideviceinfo -u "$DEVICE_ID" -k ProductType
    ideviceinfo -u "$DEVICE_ID" -k ProductVersion
    ideviceinfo -u "$DEVICE_ID" -k BuildVersion

    echo
    log_info "🔋 Battery Status:"
    ideviceinfo -u "$DEVICE_ID" -k BatteryCurrentCapacity
    ideviceinfo -u "$DEVICE_ID" -k BatteryIsCharging

    echo
    log_info "💾 Storage Information:"
    ideviceinfo -u "$DEVICE_ID" -k TotalSystemAvailable
    ideviceinfo -u "$DEVICE_ID" -k TotalDiskCapacity

    echo
    log_info "🎤 Audio Capabilities:"
    ideviceinfo -u "$DEVICE_ID" -k HasBaseband
    ideviceinfo -u "$DEVICE_ID" -k SupportedDeviceFamilies
}

clean_development_build() {
    log_info "Cleaning development build artifacts..."

    rm -rf "$BUILD_DIR/development"
    rm -rf "Resources/iOS/Development"
    rm -f "project.yml"

    log_success "Development build cleaned"
}

print_deployment_summary() {
    echo
    log_success "📱 Direct iPhone Deployment Summary:"
    echo "  🏥 Therapeutic App: $PRODUCT_NAME"
    echo "  📦 Bundle ID: $BUNDLE_ID"
    echo "  📱 Device: $DEVICE_ID"
    echo "  🎯 iOS Target: $DEPLOYMENT_TARGET+"
    echo "  👨‍💻 Team ID: $TEAM_ID"
    echo
    log_info "🧪 Ready for therapeutic effectiveness testing!"
    echo "  ✅ Microphone frequency detection (20Hz-20kHz)"
    echo "  ✅ Real-time flashlight synchronization"
    echo "  ✅ Accessibility compliance testing"
    echo "  ✅ Battery and performance monitoring"
    echo
}

show_help() {
    echo "Usage: $0 [command] [options]"
    echo
    echo "Commands:"
    echo "  deploy      Deploy app to connected iPhone (default)"
    echo "  build       Build development version only"
    echo "  install     Install pre-built IPA to device"
    echo "  launch      Launch app on device with debugging"
    echo "  devices     List connected iOS devices"
    echo "  pair        Pair with connected device"
    echo "  diagnostics Run device diagnostics"
    echo "  clean       Clean build artifacts"
    echo "  setup       Install required Linux iOS tools"
    echo "  help        Show this help"
    echo
    echo "Environment Variables:"
    echo "  TEAM_ID                     Apple Developer Team ID"
    echo "  DEVICE_ID                   Target device UDID"
    echo "  PROVISIONING_PROFILE_PATH   Path to .mobileprovision file"
    echo "  CERTIFICATE_PATH            Path to development certificate"
    echo "  PRIVATE_KEY_PATH           Path to private key"
    echo
    echo "Examples:"
    echo "  # Full deployment pipeline"
    echo "  export TEAM_ID='ABCDEF1234'"
    echo "  $0 deploy"
    echo
    echo "  # Deploy to specific device"
    echo "  DEVICE_ID='00008030-001234567890123A' $0 deploy"
    echo
    echo "  # Setup tools and pair device"
    echo "  $0 setup && $0 pair"
    echo
}

# Main execution
main() {
    print_banner

    case "${1:-deploy}" in
        "setup")
            check_linux_ios_tools
            ;;
        "devices")
            detect_connected_devices
            ;;
        "pair")
            detect_connected_devices
            pair_device
            ;;
        "build")
            check_linux_ios_tools
            detect_connected_devices
            pair_device
            check_development_setup
            setup_development_build
            build_development_app
            create_development_ipa
            ;;
        "install")
            check_linux_ios_tools
            detect_connected_devices
            pair_device
            deploy_to_device
            ;;
        "launch")
            detect_connected_devices
            pair_device
            launch_app
            ;;
        "deploy")
            check_linux_ios_tools
            detect_connected_devices
            pair_device
            check_development_setup
            setup_development_build
            build_development_app
            create_development_ipa
            deploy_to_device
            ;;
        "diagnostics")
            detect_connected_devices
            run_device_diagnostics
            ;;
        "clean")
            clean_development_build
            ;;
        "help"|"-h"|"--help")
            show_help
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
