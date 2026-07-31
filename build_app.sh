#!/bin/bash
set -e

cd "$(dirname "$0")"
source scripts/assemble_app.sh

APP_BUNDLE="Bitnote-dev.app"

assemble_app debug "com.bitnote.app.dev" "Bitnote-dev" "${APP_BUNDLE}"

echo "Done. Launching ${APP_BUNDLE}..."
open "${APP_BUNDLE}"
