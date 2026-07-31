#!/bin/bash
set -e

cd "$(dirname "$0")"
source scripts/assemble_app.sh

APP_NAME="Bitnote"
APP_BUNDLE="${APP_NAME}.app"
DMG_NAME="${APP_NAME}.dmg"
DMG_TEMP="dmg_temp"
VOLUME_NAME="${APP_NAME}"

assemble_app release "com.bitnote.app" "${APP_NAME}" "${APP_BUNDLE}"

# Create DMG staging directory
echo "Creating DMG..."
rm -rf "${DMG_TEMP}"
mkdir -p "${DMG_TEMP}"
cp -R "${APP_BUNDLE}" "${DMG_TEMP}/"
ln -s /Applications "${DMG_TEMP}/Applications"

# Create the DMG
rm -f "${DMG_NAME}"
hdiutil create -volname "${VOLUME_NAME}" \
  -srcfolder "${DMG_TEMP}" \
  -ov -format UDZO \
  "${DMG_NAME}"

# Cleanup
rm -rf "${DMG_TEMP}"

echo ""
echo "Done! ${DMG_NAME} created ($(du -h "${DMG_NAME}" | cut -f1) )."
echo "Open it and drag Bitnote to Applications to install."
