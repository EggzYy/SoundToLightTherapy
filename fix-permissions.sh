#!/bin/bash

# Script to fix Info.plist permissions and install the app

set -e

echo "Building app with xtool..."
xtool dev build

echo "Updating Info.plist with privacy permissions..."
INFO_PLIST="xtool/SoundToLightTherapy.app/Info.plist"

# Add NSMicrophoneUsageDescription if not present
if ! grep -q "NSMicrophoneUsageDescription" "$INFO_PLIST"; then
    # Create temporary file with updated plist
    python3 -c "
import plistlib
import sys

with open('$INFO_PLIST', 'rb') as f:
    plist = plistlib.load(f)

plist['NSMicrophoneUsageDescription'] = 'This app uses the microphone to detect sound frequencies and provide synchronized light therapy based on real-time audio analysis.'
plist['NSCameraUsageDescription'] = 'This app uses the camera to access the flashlight for providing synchronized light therapy based on sound frequency detection.'

with open('$INFO_PLIST', 'wb') as f:
    plistlib.dump(plist, f)
"
    echo "Added privacy usage descriptions to Info.plist"
else
    echo "Privacy descriptions already present"
fi

echo "Creating IPA..."
xtool dev build --ipa

echo "Extracting IPA to update Info.plist..."
cd xtool
rm -rf temp_ipa_extract
unzip -q SoundToLightTherapy.ipa -d temp_ipa_extract

echo "Updating Info.plist in extracted IPA..."
INFO_PLIST_IPA="temp_ipa_extract/Payload/SoundToLightTherapy.app/Info.plist"

python3 -c "
import plistlib
import sys

with open('$INFO_PLIST_IPA', 'rb') as f:
    plist = plistlib.load(f)

plist['NSMicrophoneUsageDescription'] = 'This app uses the microphone to detect sound frequencies and provide synchronized light therapy based on real-time audio analysis.'
plist['NSCameraUsageDescription'] = 'This app uses the camera to access the flashlight for providing synchronized light therapy based on sound frequency detection.'

with open('$INFO_PLIST_IPA', 'wb') as f:
    plistlib.dump(plist, f)
"

echo "Repackaging IPA with updated Info.plist..."
cd temp_ipa_extract
zip -r ../SoundToLightTherapy-fixed.ipa Payload/
cd ..

echo "Installing updated app to device..."
if [ -f "SoundToLightTherapy-fixed.ipa" ]; then
    xtool install SoundToLightTherapy-fixed.ipa
else
    echo "Error: Fixed IPA file not found"
    exit 1
fi

cd ..

echo "App installation complete!"
