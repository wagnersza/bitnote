#!/bin/bash
set -e

cd "$(dirname "$0")"
source scripts/assemble_app.sh

DEST="/Applications/Bitnote.app"
YES=0

for arg in "$@"; do
  case "$arg" in
    -y|--yes) YES=1 ;;
    --dest=*) DEST="${arg#--dest=}" ;;
    *) echo "Unknown argument: ${arg}" >&2; exit 1 ;;
  esac
done

if [ -e "${DEST}" ]; then
  echo "This will replace the existing app at ${DEST}."
else
  echo "This will install Bitnote to ${DEST}."
fi

if [ "${YES}" -ne 1 ]; then
  read -r -p "Proceed? [y/N] " reply
  case "$reply" in
    [yY]|[yY][eE][sS]) ;;
    *) echo "Aborted."; exit 1 ;;
  esac
fi

assemble_app release "com.bitnote.app" "Bitnote" "Bitnote.app"

echo "Installing to ${DEST}..."
rm -rf "${DEST}"
mkdir -p "$(dirname "${DEST}")"
cp -R "Bitnote.app" "${DEST}"
rm -rf "Bitnote.app"

echo "Done. Installed to ${DEST}."
