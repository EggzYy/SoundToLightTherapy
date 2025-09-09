# iPhone Connection and Pairing Troubleshooting Guide

Comprehensive troubleshooting for connecting and pairing iPhones with Linux development systems for SoundToLightTherapy deployment.

## 🚨 Quick Diagnosis

Run this command to get an instant diagnosis of your connection issues:

```bash
./deploy-development.sh diagnostics
```

## 🔍 Common Connection Issues

### Issue 1: "No iOS devices detected"

#### Symptoms
```bash
$ idevice_id -l
# No output or command hangs
```

#### Solutions

**Step 1: Check Physical Connection**
```bash
# Verify iPhone appears as USB device
lsusb | grep Apple
# Expected output: Bus 001 Device 005: ID 05ac:12a8 Apple, Inc. iPhone

# If no Apple device shown:
# - Try different USB cable (use original Apple cable)
# - Try different USB port (USB 3.0 preferred)
# - Ensure iPhone is unlocked and on home screen
```

**Step 2: Restart USB Services**
```bash
# Stop usbmuxd daemon
sudo systemctl stop usbmuxd

# Kill any existing processes
sudo pkill -f usbmuxd

# Start in foreground with verbose logging
sudo usbmuxd -f -v
# Look for connection messages, then Ctrl+C and restart service

# Restart usbmuxd service
sudo systemctl start usbmuxd
sudo systemctl enable usbmuxd
```

**Step 3: Fix Permissions**
```bash
# Add user to plugdev group
sudo usermod -a -G plugdev $USER

# Create/update udev rules
sudo tee /etc/udev/rules.d/39-usbmuxd.rules > /dev/null <<'EOF'
# iOS devices udev rules
SUBSYSTEM=="usb", ATTR{idVendor}=="05ac", ATTR{idProduct}=="12[9a-f][0-9a-f]", GROUP="plugdev", MODE="0664"
SUBSYSTEM=="usb", ATTR{idVendor}=="05ac", ATTR{idProduct}=="129[0-9a-f]", GROUP="plugdev", MODE="0664"
EOF

# Reload udev rules
sudo udevadm control --reload-rules
sudo udevadm trigger

# Log out and back in for group changes to take effect
```

**Step 4: Install/Reinstall libimobiledevice**
```bash
# Ubuntu/Debian - remove and reinstall
sudo apt remove libimobiledevice6 libimobiledevice-utils
sudo apt autoremove
sudo apt update
sudo apt install libimobiledevice6 libimobiledevice-utils usbmuxd

# Fedora - reinstall
sudo dnf reinstall libimobiledevice libimobiledevice-utils usbmuxd

# Arch Linux - reinstall
sudo pacman -S libimobiledevice usbmuxd --overwrite '*'
```

### Issue 2: "Device detected but pairing fails"

#### Symptoms
```bash
$ idevice_id -l
00008030-001234567890123A

$ idevicepair pair
ERROR: Pairing failed!
```

#### Solutions

**Step 1: Trust Computer on iPhone**
```bash
# Ensure iPhone shows "Trust This Computer?" dialog
# If not shown:
# 1. Disconnect and reconnect iPhone
# 2. Ensure iPhone is unlocked
# 3. Look for notification on lock screen
# 4. Go to Settings > General > Reset > Reset Location & Privacy
```

**Step 2: Clear Existing Pairing Data**
```bash
# Remove existing pairing records
rm -rf ~/.local/share/libimobiledevice/
mkdir -p ~/.local/share/libimobiledevice/

# Clear system-wide pairing data (if exists)
sudo rm -rf /var/lib/lockdown/

# Unpair and re-pair
idevicepair unpair
sleep 2
idevicepair pair
```

**Step 3: Check iOS Version Compatibility**
```bash
# Get iOS version
ideviceinfo -k ProductVersion
# Expected: 17.0 or higher for optimal compatibility

# If iOS is too new, update libimobiledevice:
# Ubuntu - try PPA with newer version
sudo add-apt-repository ppa:pmcenery/ppa
sudo apt update
sudo apt upgrade libimobiledevice6

# Or build from source (latest version)
git clone https://github.com/libimobiledevice/libimobiledevice.git
cd libimobiledevice
./autogen.sh
make
sudo make install
```

**Step 4: Developer Mode Issues (iOS 16+)**
```bash
# Enable Developer Mode on iPhone:
# Settings > Privacy & Security > Developer Mode > ON
# Restart iPhone when prompted

# Verify Developer Mode is enabled
ideviceinfo -k DeveloperModeStatus
# Should return: true
```

### Issue 3: "Pairing successful but device communication fails"

#### Symptoms
```bash
$ idevicepair validate
SUCCESS: Paired with device 00008030-001234567890123A

$ ideviceinstaller -l
ERROR: Could not connect to device
```

#### Solutions

**Step 1: Check Device Lock Status**
```bash
# Device must be unlocked for most operations
ideviceinfo -k PasswordProtected
# If "true", unlock iPhone and try again

# Keep iPhone unlocked during deployment
# Consider increasing auto-lock time:
# iPhone Settings > Display & Brightness > Auto-Lock > Never (temporarily)
```

**Step 2: Test Individual Services**
```bash
# Test device info service
ideviceinfo -k DeviceName

# Test installation service
ideviceinstaller -l | head -5

# Test file system service
ifuse /mnt/iphone  # May require additional setup

# If specific services fail, check iOS restrictions:
# Settings > General > Profiles & Device Management
```

**Step 3: Network and Firewall Issues**
```bash
# libimobiledevice uses network-like communication over USB
# Check if firewall is blocking:
sudo iptables -L | grep usbmux
sudo ufw status

# Temporarily disable firewall for testing
sudo ufw disable
# Test connection, then re-enable:
sudo ufw enable
```

### Issue 4: "Connection works but deployment fails"

#### Symptoms
```bash
$ ios-deploy --detect
Found device 00008030-001234567890123A

$ ios-deploy --bundle app.ipa
Error: AMDeviceInstallApplication failed
```

#### Solutions

**Step 1: Check App Signing**
```bash
# Verify app is properly signed
codesign -dv --verbose=4 SoundToLightTherapy.app/
# Should show valid certificate and no errors

# Check provisioning profile
security cms -D -i SoundToLightTherapy_Development.mobileprovision | grep -A 10 ProvisionedDevices
# Ensure your device UDID is in the list
```

**Step 2: Free Storage Space**
```bash
# Check device storage
ideviceinfo -k TotalDiskCapacity
ideviceinfo -k TotalSystemAvailable

# If low storage, clean up iPhone:
# Settings > General > iPhone Storage
# Delete unused apps and media
```

**Step 3: Check iOS Deployment Target**
```bash
# Verify app deployment target matches iOS version
otool -l SoundToLightTherapy.app/SoundToLightTherapy | grep -A 5 LC_VERSION_MIN_IPHONEOS
# Should be <= iPhone iOS version

# If mismatch, rebuild with correct target:
export IPHONEOS_DEPLOYMENT_TARGET=17.0
./deploy-development.sh build
```

## 🔧 Advanced Troubleshooting

### Debug Mode Connection Testing

```bash
# Enable debug mode for detailed logging
export LIBIMOBILEDEVICE_DEBUG=1

# Test connection with full debugging
idevice_id -l -d

# Check usbmuxd logs
journalctl -u usbmuxd -f
```

### Network-over-USB Issues

```bash
# Test network-over-USB connectivity
# Create test connection
iproxy 2222 22 &  # Forward SSH if available
ssh -p 2222 mobile@localhost  # iOS has SSH in developer mode

# Kill proxy when done
pkill iproxy
```

### Hardware-Specific Issues

#### USB-C vs Lightning
```bash
# Different iPhone models use different connectors:
# Lightning: iPhone 5-14 series
# USB-C: iPhone 15+ series

# Ensure proper cable:
# - Lightning: Use MFi certified cable
# - USB-C: Use USB 3.0+ cable with data support (not charging-only)

# Test cable with data transfer
# Lightning: Should sync with iTunes/Finder
# USB-C: Should mount as storage device when configured
```

#### Linux Distribution-Specific Issues

**Ubuntu/Pop!_OS Issues**
```bash
# Snap packages can interfere with USB access
snap list | grep libimobiledevice
# If found, prefer apt version:
sudo snap remove libimobiledevice
sudo apt install libimobiledevice-utils
```

**Fedora/CentOS Issues**
```bash
# SELinux can block USB device access
sudo setsebool -P use_nfs_home_dirs 1
sudo setsebool -P allow_execstack 1

# Check SELinux denials
sudo ausearch -m AVC -ts recent | grep usbmux
```

**Arch Linux Issues**
```bash
# Ensure AUR packages are up to date
yay -S libimobiledevice-git usbmuxd-git

# Check systemd service
sudo systemctl status usbmuxd
sudo systemctl daemon-reload
```

## 📱 iPhone-Specific Troubleshooting

### iOS Restrictions and Profiles

```bash
# Check for configuration profiles that might block development
ideviceinfo -k ConfigurationProfiles
# If enterprise profiles exist, they might restrict development

# Check if iPhone is supervised (enterprise/education)
ideviceinfo -k IsSupervised
# If "true", contact IT administrator
```

### iPhone Model Compatibility

```bash
# Get exact iPhone model
ideviceinfo -k ProductType
# Cross-reference with supported models:

# Fully supported (iOS 17+):
# - iPhone15,2 (iPhone 14 Pro)
# - iPhone15,3 (iPhone 14 Pro Max)  
# - iPhone16,1 (iPhone 15)
# - iPhone16,2 (iPhone 15 Plus)

# Limited support (iOS 15-16):
# - iPhone13,x series (iPhone 12)
# - iPhone14,x series (iPhone 13)
```

### Therapeutic App Specific Requirements

```bash
# Verify microphone access
ideviceinfo -k MicrophoneRestriction
# Should be: none

# Check camera/flashlight availability
ideviceinfo -k CameraRestriction
ideviceinfo -k TorchCapability
# Both should allow access

# Ensure sufficient processing power for real-time audio
ideviceinfo -k CPUArchitecture
# arm64 required for optimal performance
```

## 🛠 Recovery Procedures

### Complete Reset and Reconnect

```bash
#!/bin/bash
# Complete connection reset script

echo "🔄 Resetting iPhone connection..."

# 1. Stop all related services
sudo systemctl stop usbmuxd
pkill -f idevice
pkill -f ios-deploy

# 2. Clean pairing data
rm -rf ~/.local/share/libimobiledevice/
sudo rm -rf /var/lib/lockdown/

# 3. Reset USB subsystem
sudo modprobe -r apple_mfi_fastcharge
sudo modprobe -r ipheth
sleep 2
sudo modprobe ipheth
sudo modprobe apple_mfi_fastcharge

# 4. Restart services
sudo systemctl start usbmuxd
sleep 3

# 5. Reconnect device
echo "🔌 Disconnect and reconnect your iPhone now"
read -p "Press Enter when iPhone is reconnected..."

# 6. Test connection
echo "🧪 Testing connection..."
idevice_id -l
if [ $? -eq 0 ]; then
    echo "✅ Connection successful!"
    ./deploy-development.sh pair
else
    echo "❌ Connection failed - manual intervention required"
fi
```

### Emergency Deployment via Alternative Methods

If direct deployment continues to fail, use these alternatives:

#### Method 1: GitHub Actions Remote Build
```bash
# Push code and trigger remote iOS build
git add .
git commit -m "Deploy to iPhone via GitHub Actions"
git push origin main

# Trigger iOS workflow
gh workflow run ios-development-build.yml \
    --field team_id="$TEAM_ID" \
    --field device_udid="$DEVICE_ID"

# Download and install built IPA
gh run download
```

#### Method 2: Mac-based Build with Remote iPhone
```bash
# If you have Mac access but iPhone is on Linux system:
# 1. Build on Mac
# 2. Transfer IPA to Linux
# 3. Install via Linux tools

scp user@mac-system:~/SoundToLightTherapy.ipa ./
./deploy-development.sh install
```

#### Method 3: TestFlight Distribution
```bash
# Upload to TestFlight for testing
# Requires App Store Connect access
# Install TestFlight app on iPhone
# Distribute via Apple's infrastructure
```

## 📊 Connection Health Monitoring

### Automated Connection Testing

```bash
#!/bin/bash
# iPhone connection health check script

echo "📱 iPhone Connection Health Check"
echo "================================"

# Test 1: Device Detection
echo -n "Device Detection: "
if idevice_id -l > /dev/null 2>&1; then
    echo "✅ PASS"
    DEVICE_ID=$(idevice_id -l | head -1)
    echo "   Device: $DEVICE_ID"
else
    echo "❌ FAIL - No devices detected"
    exit 1
fi

# Test 2: Pairing Status
echo -n "Device Pairing: "
if idevicepair validate > /dev/null 2>&1; then
    echo "✅ PASS"
else
    echo "❌ FAIL - Device not paired"
fi

# Test 3: Device Information
echo -n "Device Communication: "
DEVICE_NAME=$(ideviceinfo -k DeviceName 2>/dev/null)
if [ -n "$DEVICE_NAME" ]; then
    echo "✅ PASS"
    echo "   Name: $DEVICE_NAME"
    echo "   iOS: $(ideviceinfo -k ProductVersion)"
    echo "   Model: $(ideviceinfo -k ProductType)"
else
    echo "❌ FAIL - Cannot communicate with device"
fi

# Test 4: Installation Service
echo -n "App Installation Service: "
if ideviceinstaller -l > /dev/null 2>&1; then
    echo "✅ PASS"
    APP_COUNT=$(ideviceinstaller -l | wc -l)
    echo "   Installed apps: $APP_COUNT"
else
    echo "❌ FAIL - Cannot access installation service"
fi

# Test 5: Developer Mode (iOS 16+)
echo -n "Developer Mode: "
DEV_MODE=$(ideviceinfo -k DeveloperModeStatus 2>/dev/null)
if [ "$DEV_MODE" = "true" ]; then
    echo "✅ PASS"
elif [ "$DEV_MODE" = "false" ]; then
    echo "⚠️  WARNING - Developer Mode disabled"
    echo "   Enable: Settings > Privacy & Security > Developer Mode"
else
    echo "ℹ️  N/A - iOS version < 16"
fi

echo
echo "🏥 Therapeutic App Requirements:"
echo -n "Microphone Access: "
MIC_RESTRICTION=$(ideviceinfo -k MicrophoneRestriction 2>/dev/null)
if [ "$MIC_RESTRICTION" != "true" ]; then
    echo "✅ Available"
else
    echo "❌ Restricted"
fi

echo -n "Camera/Flashlight: "
CAM_RESTRICTION=$(ideviceinfo -k CameraRestriction 2>/dev/null)
if [ "$CAM_RESTRICTION" != "true" ]; then
    echo "✅ Available"
else
    echo "❌ Restricted"
fi

echo
echo "Connection health check complete!"
```

### Performance Monitoring

```bash
# Monitor deployment performance
time ./deploy-development.sh deploy

# Expected timings (optimal conditions):
# - Device detection: < 2s
# - Pairing validation: < 1s  
# - App build: 30-120s (depending on system)
# - Installation: 10-30s
# - Launch: < 5s

# If significantly slower, investigate:
# - USB connection quality
# - System resource availability
# - iPhone storage space
# - Background processes
```

## 🎯 Success Verification

After following troubleshooting steps, verify successful deployment:

```bash
# 1. Confirm app installation
ideviceinstaller -l | grep -i soundtolight

# 2. Launch therapeutic app
./deploy-development.sh launch

# 3. Verify permissions granted
# Check iPhone: Settings > Privacy & Security > Microphone/Camera
# SoundToLightTherapy should appear in allowed apps list

# 4. Test core functionality
# 🎤 Audio frequency detection
# 💡 Flashlight control
# 📊 Real-time synchronization

# 5. Monitor for crashes
idevicecrashreport -e | grep -i soundtolight
```

**Success Criteria:**
- ✅ iPhone connects and pairs reliably
- ✅ App installs without errors
- ✅ Microphone and camera permissions granted
- ✅ Real-time frequency detection works
- ✅ Flashlight synchronizes with audio
- ✅ No crashes during 5-minute therapy session

---

**Need more help?** Check the main [DEVELOPMENT_DEPLOYMENT_GUIDE.md](DEVELOPMENT_DEPLOYMENT_GUIDE.md) or open a GitHub issue with your specific error messages and system configuration.