# SoundToLightTherapy - Direct iPhone Development Deployment Guide

Complete guide for deploying the therapeutic app directly to iPhone from Linux development environment for real-world testing.

## 🎯 Quick Start

```bash
# 1. Set up your Apple Developer credentials
export TEAM_ID="ABCDEF1234"  # Your Apple Developer Team ID
export PROVISIONING_PROFILE_PATH="./SoundToLightTherapy_Development.mobileprovision"

# 2. Install iOS tools and deploy
./deploy-development.sh setup
./deploy-development.sh deploy
```

## 📋 Prerequisites

### Linux System Requirements
- **OS**: Ubuntu 20.04+ / Fedora 35+ / Arch Linux / openSUSE
- **Architecture**: x86_64 (ARM64 support experimental)
- **USB**: USB 3.0+ port for reliable iPhone connection
- **Storage**: 2GB free space for build artifacts

### Apple Developer Account Requirements
- **Active Apple Developer Program membership** ($99/year)
- **Development certificate** for iOS App Development
- **Provisioning profile** including your test devices
- **Team ID** from Apple Developer Portal

### Hardware Requirements
- **iPhone**: iOS 17.0+ (for therapeutic app compatibility)
- **USB Cable**: Original Lightning/USB-C cable (third-party may cause issues)
- **Mac Access**: Optional but recommended for certificate generation

## 🛠 Installation Guide

### Step 1: Install Linux iOS Tools

#### Ubuntu/Debian
```bash
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

# Install build dependencies
sudo apt install -y \
    build-essential \
    git \
    libimobiledevice-dev \
    libplist-dev \
    libusbmuxd-dev \
    libssl-dev
```

#### Fedora/RHEL
```bash
sudo dnf install -y \
    libimobiledevice \
    libimobiledevice-utils \
    ideviceinstaller \
    ifuse \
    usbmuxd \
    libplist \
    openssl-devel \
    git \
    gcc \
    make
```

#### Arch Linux
```bash
sudo pacman -S \
    libimobiledevice \
    ideviceinstaller \
    ifuse \
    usbmuxd \
    git \
    base-devel
```

### Step 2: Install ios-deploy
```bash
# Clone and build ios-deploy
git clone https://github.com/ios-control/ios-deploy.git
cd ios-deploy
make
sudo make install
cd ..
rm -rf ios-deploy

# Verify installation
ios-deploy --version
```

### Step 3: Setup USB Permissions
```bash
# Add user to plugdev group
sudo usermod -a -G plugdev $USER

# Create udev rules for iOS devices
sudo tee /etc/udev/rules.d/39-usbmuxd.rules > /dev/null <<EOF
# iOS devices
SUBSYSTEM=="usb", ATTR{idVendor}=="05ac", ATTR{idProduct}=="12[9a-f][0-9a-f]", GROUP="plugdev"
EOF

# Reload udev rules
sudo udevadm control --reload-rules
sudo udevadm trigger

# Log out and log back in for group changes
```

## 🍎 Apple Developer Setup

### Step 1: Apple Developer Account
1. **Join Apple Developer Program**: https://developer.apple.com/programs/
2. **Verify membership status** in Apple Developer Portal
3. **Note your Team ID** (found in Membership section)

### Step 2: Development Certificate

#### Method A: Using Xcode (Recommended)
1. **Open Xcode** on a Mac
2. **Preferences → Accounts → Add Apple ID**
3. **Select team → Manage Certificates**
4. **Create "Apple Development" certificate**
5. **Export certificate** (.p12 file with private key)

#### Method B: Manual Certificate Creation
1. **Generate Certificate Signing Request (CSR)**:
   ```bash
   # On Linux/Mac, create private key
   openssl genrsa -out ios_development.key 2048
   
   # Create certificate request
   openssl req -new -key ios_development.key -out ios_development.csr
   # Enter your Apple ID email and developer info
   ```

2. **Upload CSR to Apple Developer Portal**:
   - Go to Certificates, Identifiers & Profiles
   - Certificates → iOS App Development
   - Upload your CSR file

3. **Download and convert certificate**:
   ```bash
   # Download ios_development.cer from Apple
   # Convert to PEM format
   openssl x509 -inform DER -outform PEM -in ios_development.cer -out ios_development.pem
   
   # Create P12 bundle
   openssl pkcs12 -export -out ios_development.p12 \
       -inkey ios_development.key \
       -in ios_development.pem
   ```

### Step 3: App ID Registration
1. **Navigate to Identifiers** in Apple Developer Portal
2. **Create new App ID**:
   - **Description**: SoundToLightTherapy Development
   - **Bundle ID**: `com.yourcompany.soundtolighttherapy.dev`
   - **Capabilities**: Enable:
     - ✅ Audio & AirPlay
     - ✅ Camera
     - ✅ HealthKit (optional)
     - ✅ Push Notifications (optional)

### Step 4: Device Registration
1. **Connect iPhone** to Mac/PC
2. **Get device UDID**:
   ```bash
   # On Linux with iPhone connected
   idevice_id -l
   
   # Or use iTunes/Finder on Mac
   # Or Settings → General → About → Copy UDID (iOS 16+)
   ```
3. **Register device** in Apple Developer Portal:
   - Devices → iOS → Add Device
   - Enter UDID and device name

### Step 5: Provisioning Profile
1. **Create Development Provisioning Profile**:
   - Profiles → iOS App Development
   - Select your App ID
   - Select development certificate
   - Select test devices
   - Name: "SoundToLightTherapy Development"

2. **Download profile** (`.mobileprovision` file)
3. **Install profile**:
   ```bash
   # Copy to project directory
   cp ~/Downloads/SoundToLightTherapy_Development.mobileprovision ./
   export PROVISIONING_PROFILE_PATH="./SoundToLightTherapy_Development.mobileprovision"
   ```

## 📱 Device Setup

### Step 1: iPhone Preparation
1. **Update iOS** to 17.0+ for optimal compatibility
2. **Enable Developer Mode** (iOS 16+):
   - Settings → Privacy & Security → Developer Mode → ON
   - Restart iPhone when prompted
3. **Trust this Computer**:
   - Connect iPhone to Linux PC
   - Unlock iPhone and tap "Trust" when prompted

### Step 2: Device Connection Test
```bash
# Start deployment script diagnostics
./deploy-development.sh devices

# Expected output:
# Connected devices:
#   📱 Your iPhone (iPhone15,2)
#      ID: 00008030-001234567890123A
#      iOS: 17.1

# Test device pairing
./deploy-development.sh pair
```

### Troubleshooting Device Connection
```bash
# If no devices detected:
sudo usbmuxd -f -v

# Check USB connection
lsusb | grep Apple

# Restart usbmuxd daemon
sudo systemctl restart usbmuxd

# Check device trust status
idevicepair -u DEVICE_ID validate
```

## 🚀 Development Deployment

### Step 1: Configure Environment
```bash
# Set required environment variables
export TEAM_ID="ABCDEF1234"                                    # Your Apple Developer Team ID
export DEVICE_ID="00008030-001234567890123A"                   # Target iPhone UDID (optional - auto-detected)
export PROVISIONING_PROFILE_PATH="./SoundToLightTherapy_Development.mobileprovision"
export CERTIFICATE_PATH="./ios_development.p12"                # Optional - for advanced signing

# For recurring deployments, add to ~/.bashrc:
echo 'export TEAM_ID="ABCDEF1234"' >> ~/.bashrc
echo 'export PROVISIONING_PROFILE_PATH="$HOME/ios-dev/SoundToLightTherapy_Development.mobileprovision"' >> ~/.bashrc
```

### Step 2: Deploy to iPhone
```bash
# Full deployment pipeline
./deploy-development.sh deploy

# Step-by-step process:
# ✅ Install iOS tools (libimobiledevice, ios-deploy)
# ✅ Detect connected iPhone
# ✅ Pair with device (trust establishment)
# ✅ Validate development certificates
# ✅ Generate development Info.plist with therapeutic permissions
# ✅ Build Swift app for iOS (arm64)
# ✅ Create signed development IPA
# ✅ Install app on iPhone via ios-deploy
# ✅ Launch app for testing
```

### Step 3: Verify Installation
```bash
# Check installed apps
ideviceinstaller -u $DEVICE_ID -l | grep SoundToLight

# Launch app with debugging
./deploy-development.sh launch

# Monitor device logs
ios-deploy --id $DEVICE_ID --debug
```

## 🧪 Therapeutic App Testing

### Core Functionality Tests

#### 1. Audio Frequency Detection
```bash
# Test frequency detection on iPhone:
# 📱 Launch "Sound to Light Therapy (Dev)"
# 🎤 Grant microphone permission
# 🔊 Play test frequencies:
```

**Test Frequencies (therapeutic range):**
- **Alpha waves**: 8-13 Hz (relaxation)
- **Beta waves**: 14-30 Hz (focus)
- **Gamma waves**: 31-100 Hz (cognitive enhancement)
- **Music therapy**: 440 Hz (A4 note)
- **Ultrasonic**: 20 kHz (range limit test)

#### 2. Flashlight Synchronization
```bash
# Real-world sync tests:
# 💡 Verify flashlight responds to audio within 50ms
# ⚡ Test different intensity patterns
# 🔋 Monitor battery usage during therapy sessions
# 📊 Validate frequency accuracy vs. light timing
```

#### 3. Therapeutic Effectiveness Validation
1. **Session Duration Tests**:
   - 5-minute focused sessions
   - 30-minute extended therapy
   - Battery life impact assessment

2. **Environmental Tests**:
   - Quiet room (background < 30dB)
   - Normal environment (30-60dB)
   - Noisy environment (> 60dB)

3. **Device Performance**:
   - Memory usage monitoring
   - CPU load during processing
   - Temperature during extended use

### Accessibility Testing

#### VoiceOver Compatibility
```bash
# Enable on iPhone: Settings → Accessibility → VoiceOver
# Test navigation and therapy control announcements
```

#### Dynamic Type Support
```bash
# Test: Settings → Accessibility → Display & Text Size
# Verify UI scales properly for vision accessibility
```

#### High Contrast Mode
```bash
# Test: Settings → Accessibility → Display & Text Size → Increase Contrast
# Ensure therapy controls remain visible
```

## 🔧 Advanced Configuration

### Custom Signing with OpenSSL
```bash
# Create development certificate bundle
cat ios_development.pem > dev_bundle.pem
cat AppleWWDRCA.pem >> dev_bundle.pem

# Sign app manually
codesign --force --sign "iPhone Developer" \
         --entitlements Resources/iOS/Development/Entitlements.plist \
         build/development/SoundToLightTherapy.app
```

### Build Optimization
```bash
# Enable Swift optimization for therapeutic performance
swift build -c release \
    -Xswiftc -O \
    -Xswiftc -whole-module-optimization \
    --arch arm64

# Optimize for real-time audio processing
export SWIFT_COMPILATION_MODE=wholemodule
export SWIFT_OPTIMIZATION_LEVEL=speed
```

### Debugging and Profiling
```bash
# Launch with Xcode debugging (if available)
ios-deploy --id $DEVICE_ID --debug --bundle build/development/SoundToLightTherapy.app

# Profile memory and CPU usage
instruments -t "Time Profiler" -D profile.trace \
    -w $DEVICE_ID com.yourcompany.soundtolighttherapy.dev

# Monitor therapeutic performance metrics
ios-deploy --id $DEVICE_ID --debug | grep "frequency\|flashlight\|therapy"
```

## 🚨 Troubleshooting

### Common Issues

#### "No provisioning profile matches"
```bash
# Solutions:
1. Verify bundle ID matches provisioning profile
2. Check device UDID is in provisioning profile
3. Ensure certificate is valid and not expired
4. Re-download provisioning profile from Apple Developer Portal

# Check profile details:
security cms -D -i SoundToLightTherapy_Development.mobileprovision
```

#### "Could not find Developer Disk Image"
```bash
# Update iOS support files:
# Option 1: Use Xcode on Mac to update iOS support
# Option 2: Download disk images manually:
wget https://github.com/filsv/iOSDeviceSupport/raw/master/17.0/DeveloperDiskImage.dmg
mkdir -p ~/Library/Developer/Xcode/iOS\ DeviceSupport/17.0/
cp DeveloperDiskImage.dmg ~/Library/Developer/Xcode/iOS\ DeviceSupport/17.0/
```

#### "libimobiledevice not detecting device"
```bash
# Fix USB connection issues:
sudo systemctl stop usbmuxd
sudo usbmuxd -f -v  # Run in foreground with verbose logging

# Check device permissions:
ls -la /dev/bus/usb/*/
sudo chmod 666 /dev/bus/usb/*/*  # Temporary fix

# Permanent fix:
sudo usermod -a -G plugdev $USER
# Log out and back in
```

#### "App installs but crashes on launch"
```bash
# Check crash logs:
idevicecrashreport -u $DEVICE_ID -e

# Common solutions:
1. Verify iOS deployment target (17.0+)
2. Check entitlements match app capabilities
3. Ensure proper code signing
4. Validate Swift runtime compatibility

# Debug launch:
ios-deploy --id $DEVICE_ID --debug --bundle build/development/SoundToLightTherapy.app
```

### Performance Issues

#### Slow Frequency Detection
```bash
# Optimize audio processing:
# 1. Check microphone permissions granted
# 2. Verify real-time audio processing priority
# 3. Monitor CPU usage during detection
# 4. Test with different sample rates

# Debug audio pipeline:
./deploy-development.sh launch | grep "AudioCaptureManager\|FrequencyDetector"
```

#### Flashlight Sync Delay
```bash
# Troubleshoot sync timing:
# 1. Measure actual delay using oscilloscope/light sensor
# 2. Profile AVCaptureDevice.setTorchMode performance
# 3. Check iOS camera permission granted
# 4. Test different torch intensity levels

# Expected performance:
# - Audio detection: < 20ms latency
# - Flashlight control: < 30ms response
# - End-to-end sync: < 50ms total
```

## 🔄 Continuous Development

### Automated Testing
```bash
# Create test script
cat > test-deployment.sh << 'EOF'
#!/bin/bash
set -e

# Deploy to multiple test devices
for device in $TEST_DEVICES; do
    DEVICE_ID=$device ./deploy-development.sh deploy
    sleep 5  # Allow installation to complete
    
    # Run basic functionality test
    DEVICE_ID=$device ./test-therapeutic-functions.sh
done
EOF

chmod +x test-deployment.sh
```

### Remote Build via GitHub Actions
```bash
# If local build fails, trigger remote build:
gh workflow run ios-development-build.yml \
    --field team_id="$TEAM_ID" \
    --field device_id="$DEVICE_ID" \
    --field bundle_id="com.yourcompany.soundtolighttherapy.dev"

# Monitor build progress:
gh run watch
```

### Version Management
```bash
# Tag development builds
git tag -a v1.0.0-dev.$(date +%Y%m%d) -m "Development build for therapeutic testing"

# Update version in build
export BUILD_NUMBER=$(date +%Y%m%d%H%M%S)
./deploy-development.sh build
```

## 📊 Therapeutic Effectiveness Metrics

### Data Collection Points
1. **Audio Processing**:
   - Frequency detection accuracy (±1 Hz)
   - Processing latency (< 20ms target)
   - Background noise handling

2. **Light Synchronization**:
   - Flashlight response time (< 30ms)
   - Intensity modulation range
   - Battery impact per hour

3. **User Experience**:
   - Session completion rates
   - Accessibility feature usage
   - Performance on different iPhone models

### Testing Protocol
```bash
# Structured testing session
./therapeutic-test-protocol.sh --duration 30min \
    --frequencies "8,13,440,1000" \
    --intensities "0.1,0.5,1.0" \
    --log-file therapy-session-$(date +%s).json
```

## 🎯 Next Steps

1. **Production Preparation**:
   - Implement TestFlight beta testing
   - Set up App Store distribution certificates
   - Prepare App Store metadata and screenshots

2. **Clinical Validation**:
   - Partner with therapeutic professionals
   - Conduct controlled efficacy studies
   - Document therapeutic outcomes

3. **Platform Expansion**:
   - Android development with Flutter/Kotlin
   - Web-based therapy sessions
   - Apple Watch companion app

---

## 📞 Support

- **GitHub Issues**: Report deployment problems
- **Apple Developer Forums**: Certificate/provisioning issues
- **Swift Forums**: Cross-platform development questions

**Successfully deployed?** 🎉 Your SoundToLightTherapy app is ready for real-world therapeutic testing on iPhone!