#!/bin/bash
# Shared assemble-and-sign step for build_app.sh, install.sh, create_dmg.sh.
# Must be sourced with CWD at the repo root, same convention as its callers.
#
# Usage: assemble_app <debug|release> <bundle_id> <app_name> <dest_path>

assemble_app() {
  local config="$1" bundle_id="$2" app_name="$3" dest="$4"
  local build_dir=".build/debug"
  local build_args=()
  if [ "$config" = "release" ]; then
    build_dir=".build/release"
    build_args=(-c release)
  fi

  echo "Building (${config})..."
  swift build "${build_args[@]}" 2>&1

  echo "Assembling ${dest}..."
  rm -rf "${dest}"
  mkdir -p "${dest}/Contents/MacOS"
  mkdir -p "${dest}/Contents/Resources"

  cp "${build_dir}/Bitnote" "${dest}/Contents/MacOS/Bitnote"
  cp "Sources/Bitnote/Info.plist" "${dest}/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier ${bundle_id}" "${dest}/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleName ${app_name}" "${dest}/Contents/Info.plist"

  echo "Signing..."
  codesign --force --deep --sign - \
    --entitlements "Bitnote.entitlements" \
    "${dest}"
}
