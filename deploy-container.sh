#!/bin/bash

# Swift Container Plugin iOS Deployment (2025 Method)
# Uses Apple's new containerization framework for cross-compilation

set -euo pipefail

# Configuration
PRODUCT_NAME="SoundToLightTherapy"
BUNDLE_ID="com.yourcompany.soundtolighttherapy"
CONTAINER_IMAGE="soundtolighttherapy-ios"
BUILD_DIR="container-build"

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
    echo "  Swift Container Plugin iOS Deployment (2025)"
    echo "  Using Apple's Containerization Framework"
    echo "=================================================================="
    echo -e "${NC}"
}

check_swift_container_support() {
    log_info "Checking Swift Container Plugin support..."

    # Check Swift version (6.0+ required)
    local swift_version=$(swift --version | grep -o 'Swift version [0-9]\+\.[0-9]\+' | grep -o '[0-9]\+\.[0-9]\+' || echo "0.0")
    local major_version=$(echo $swift_version | cut -d. -f1)
    local minor_version=$(echo $swift_version | cut -d. -f2)

    if [ "$major_version" -lt 6 ]; then
        log_error "Swift 6.0+ required for Container Plugin. Current: $swift_version"
        log_info "Update Swift toolchain or use alternative deployment method"
        return 1
    fi

    # Check if running on macOS (for Apple Container)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        local macos_version=$(sw_vers -productVersion | cut -d. -f1)
        if [ "$macos_version" -lt 26 ]; then
            log_warning "macOS 26+ recommended for Apple Container. Current: $(sw_vers -productVersion)"
            log_info "Falling back to Docker-based approach..."
            return 2
        fi
        log_success "Apple Container support available"
        return 0
    else
        log_info "Linux environment detected. Using Docker-based cross-compilation..."
        return 2
    fi
}

setup_container_plugin() {
    log_info "Setting up Swift Container Plugin..."

    # Add Container Plugin to Package.swift if not present
    if ! grep -q "swift-container-plugin" Package.swift 2>/dev/null; then
        log_info "Adding Swift Container Plugin dependency..."

        # Create a backup of Package.swift
        cp Package.swift Package.swift.backup

        # Add container plugin dependency
        local temp_package=$(mktemp)
        cat > "$temp_package" << 'EOF'
// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "SoundToLightTherapy",
    platforms: [
        .iOS(.v17),
        .macOS(.v12),
    ],
    products: [
        .library(
            name: "SoundToLightTherapy",
            targets: ["SoundToLightTherapy"]
        ),
        .executable(
            name: "SoundToLightTherapyApp",
            targets: ["SoundToLightTherapyApp"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/stackotter/swift-cross-ui",
            revision: "a02da752cf9cd50c99b3ce43d573975b69225d58"
        ),
        .package(
            url: "https://github.com/apple/swift-container-plugin",
            from: "1.0.0"
        ),
    ],
    targets: [
        .target(
            name: "SoundToLightTherapy",
            dependencies: [
                .product(name: "SwiftCrossUI", package: "swift-cross-ui")
            ],
            path: "Sources/SoundToLightTherapy",
            exclude: ["main.swift"],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .executableTarget(
            name: "SoundToLightTherapyApp",
            dependencies: [
                .target(name: "SoundToLightTherapy"),
                .product(name: "SwiftCrossUI", package: "swift-cross-ui"),
                .product(name: "DefaultBackend", package: "swift-cross-ui"),
            ],
            path: "Sources/SoundToLightTherapy",
            sources: ["main.swift"],
            plugins: [
                .plugin(name: "ContainerPlugin", package: "swift-container-plugin")
            ]
        ),
        .testTarget(
            name: "SoundToLightTherapyTests",
            dependencies: ["SoundToLightTherapy"],
            path: "Tests/SoundToLightTherapyTests"
        ),
    ]
)
EOF

        # Replace Package.swift
        mv "$temp_package" Package.swift
        log_success "Container plugin added to Package.swift"
    else
        log_info "Container plugin already present"
    fi
}

create_containerfile() {
    log_info "Creating Containerfile for iOS cross-compilation..."

    mkdir -p "$BUILD_DIR"

    cat > "$BUILD_DIR/Containerfile" << 'EOF'
# Use Swift base image with cross-compilation support
FROM swift:6.1-jammy

# Install iOS cross-compilation dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    clang \
    libc6-dev \
    libicu-dev \
    libssl-dev \
    libxml2-dev \
    libz-dev \
    pkg-config \
    curl \
    wget \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Set up iOS SDK for cross-compilation
WORKDIR /opt
RUN wget https://github.com/kabiroberai/swift-sdk-darwin/releases/latest/download/darwin-sdk.tar.gz \
    && tar -xzf darwin-sdk.tar.gz \
    && rm darwin-sdk.tar.gz

ENV PATH="/opt/darwin-sdk/bin:$PATH"
ENV DARWIN_SDK_PATH="/opt/darwin-sdk"

# Set working directory
WORKDIR /workspace

# Copy source code
COPY . .

# Build for iOS
RUN swift build --swift-sdk arm64-apple-ios17.0 -c release

# Create output directory
RUN mkdir -p /output && \
    cp .build/arm64-apple-ios17.0/release/SoundToLightTherapyApp /output/

# Runtime stage for packaging
FROM scratch as export
COPY --from=0 /output/ /
EOF

    log_success "Containerfile created"
}

build_with_apple_container() {
    log_info "Building with Apple Container..."

    # Use Apple's container tool
    if command -v container &> /dev/null; then
        container build \
            --tag "$CONTAINER_IMAGE:latest" \
            --target export \
            "$BUILD_DIR"

        # Extract built iOS binary
        container run \
            --rm \
            --volume "$(pwd)/$BUILD_DIR:/output" \
            "$CONTAINER_IMAGE:latest" \
            cp /SoundToLightTherapyApp /output/

        log_success "iOS binary built with Apple Container"
    else
        log_error "Apple Container tool not found. Install from Apple Developer Resources."
        return 1
    fi
}

build_with_docker() {
    log_info "Building with Docker (fallback method)..."

    # Check if Docker is available
    if ! command -v docker &> /dev/null; then
        log_error "Docker not found. Install Docker or use alternative method."
        return 1
    fi

    # Build with Docker
    docker build \
        --file "$BUILD_DIR/Containerfile" \
        --tag "$CONTAINER_IMAGE:latest" \
        --target export \
        .

    # Extract built iOS binary
    docker run \
        --rm \
        --volume "$(pwd)/$BUILD_DIR:/output" \
        "$CONTAINER_IMAGE:latest" \
        cp /SoundToLightTherapyApp /output/

    log_success "iOS binary built with Docker"
}

build_with_swift_sdk() {
    log_info "Building with Swift SDK cross-compilation..."

    # Check available Swift SDKs
    local available_sdks=$(swift sdk list 2>/dev/null || echo "")

    if echo "$available_sdks" | grep -q "arm64-apple-ios"; then
        log_info "iOS SDK available, building..."

        swift build \
            --swift-sdk arm64-apple-ios17.0 \
            --configuration release \
            --build-path "$BUILD_DIR"

        log_success "iOS binary built with Swift SDK"
    else
        log_warning "iOS SDK not installed. Available SDKs:"
        echo "$available_sdks"
        log_info "Install iOS SDK or use container-based approach"
        return 1
    fi
}

package_ios_app() {
    log_info "Packaging iOS application..."

    local app_dir="$BUILD_DIR/$PRODUCT_NAME.app"
    mkdir -p "$app_dir"

    # Copy binary
    if [ -f "$BUILD_DIR/SoundToLightTherapyApp" ]; then
        cp "$BUILD_DIR/SoundToLightTherapyApp" "$app_dir/"
        chmod +x "$app_dir/SoundToLightTherapyApp"
    else
        log_error "iOS binary not found at $BUILD_DIR/SoundToLightTherapyApp"
        return 1
    fi

    # Copy Info.plist if it exists
    if [ -f "Resources/iOS/Info.plist" ]; then
        cp "Resources/iOS/Info.plist" "$app_dir/"
    else
        log_warning "Info.plist not found. Creating minimal version..."
        cat > "$app_dir/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>SoundToLightTherapyApp</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>$PRODUCT_NAME</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
</dict>
</plist>
EOF
    fi

    # Copy privacy manifest if it exists
    if [ -f "Resources/iOS/PrivacyInfo.xcprivacy" ]; then
        cp "Resources/iOS/PrivacyInfo.xcprivacy" "$app_dir/"
    fi

    log_success "iOS app packaged at $app_dir"
}

validate_ios_binary() {
    log_info "Validating iOS binary..."

    local binary_path="$BUILD_DIR/SoundToLightTherapyApp"

    if [ -f "$binary_path" ]; then
        # Check file type
        local file_info=$(file "$binary_path")
        echo "Binary info: $file_info"

        # Check if it's an iOS binary
        if echo "$file_info" | grep -q "arm64"; then
            log_success "Valid ARM64 iOS binary detected"

            # Additional validation with otool if available (on macOS)
            if command -v otool &> /dev/null; then
                log_info "Binary details:"
                otool -l "$binary_path" | grep -A 5 LC_VERSION_MIN_IPHONEOS || \
                otool -l "$binary_path" | grep -A 5 LC_BUILD_VERSION
            fi
        else
            log_warning "Binary architecture may not be compatible with iOS"
        fi

        # Check binary size
        local size=$(stat -c%s "$binary_path" 2>/dev/null || stat -f%z "$binary_path" 2>/dev/null)
        log_info "Binary size: $(($size / 1024))KB"

    else
        log_error "iOS binary not found"
        return 1
    fi
}

show_deployment_options() {
    echo
    log_info "iOS deployment options for the built binary:"
    echo
    echo "1. Install via Xcode:"
    echo "   - Open Xcode → Window → Devices and Simulators"
    echo "   - Drag .app bundle to device"
    echo
    echo "2. Create IPA for distribution:"
    echo "   - Use ios-app-installer or similar tools"
    echo "   - Sign with valid provisioning profile"
    echo
    echo "3. TestFlight distribution:"
    echo "   - Upload to App Store Connect"
    echo "   - Requires Apple Developer account"
    echo
    echo "4. Enterprise distribution:"
    echo "   - Sign with enterprise certificate"
    echo "   - Distribute via MDM or direct download"
    echo
}

# Main execution
main() {
    print_banner

    case "${1:-build}" in
        "build")
            check_swift_container_support
            local container_result=$?

            setup_container_plugin
            create_containerfile

            # Choose build method based on environment
            case $container_result in
                0)
                    log_info "Using Apple Container (preferred method)"
                    build_with_apple_container || build_with_docker || build_with_swift_sdk
                    ;;
                2)
                    log_info "Using Docker-based cross-compilation"
                    build_with_docker || build_with_swift_sdk
                    ;;
                *)
                    log_info "Using Swift SDK cross-compilation"
                    build_with_swift_sdk || build_with_docker
                    ;;
            esac

            validate_ios_binary
            package_ios_app
            ;;
        "clean")
            log_info "Cleaning container build artifacts..."
            rm -rf "$BUILD_DIR"

            # Clean Docker images if they exist
            if command -v docker &> /dev/null; then
                docker rmi "$CONTAINER_IMAGE:latest" 2>/dev/null || true
            fi

            # Clean Apple Container images if they exist
            if command -v container &> /dev/null; then
                container rmi "$CONTAINER_IMAGE:latest" 2>/dev/null || true
            fi

            # Restore Package.swift backup if it exists
            if [ -f "Package.swift.backup" ]; then
                mv "Package.swift.backup" "Package.swift"
                log_info "Package.swift restored from backup"
            fi

            log_success "Clean completed"
            ;;
        "help"|"-h"|"--help")
            echo "Usage: $0 [command]"
            echo
            echo "Commands:"
            echo "  build     Build iOS app using container cross-compilation (default)"
            echo "  clean     Clean build artifacts and restore Package.swift"
            echo "  help      Show this help"
            echo
            show_deployment_options
            exit 0
            ;;
        *)
            log_error "Unknown command: $1"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac

    if [ -f "$BUILD_DIR/$PRODUCT_NAME.app/SoundToLightTherapyApp" ]; then
        log_success "Container-based iOS deployment completed!"
        echo "  📱 iOS App: $BUILD_DIR/$PRODUCT_NAME.app"
        echo "  🔧 Binary: $BUILD_DIR/SoundToLightTherapyApp"
        show_deployment_options
    fi
}

# Run main function with all arguments
main "$@"
