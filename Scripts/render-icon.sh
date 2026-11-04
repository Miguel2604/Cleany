#!/bin/sh
# Renders docs/icon.png from App/AppIcon.icon with Icon Composer's renderer. The icon itself ships as
# the .icon (layered SVGs that macOS renders in Liquid Glass); Xcode compiles it.
set -e
cd "$(dirname "$0")/.."
ICTOOL="$(xcode-select -p)/../Applications/Icon Composer.app/Contents/Executables/ictool"
"$ICTOOL" App/AppIcon.icon --export-image --output-file docs/icon.png \
  --platform macOS --rendition Default --width 512 --height 512 --scale 1 >/dev/null
