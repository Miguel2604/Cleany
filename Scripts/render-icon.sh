#!/bin/sh
# Renders App/Assets.xcassets/AppIcon.appiconset PNGs (and a mood sheet, path $1) from the vector raccoon.
set -e
cd "$(dirname "$0")/.."
mkdir -p build
swiftc -O -parse-as-library -o build/render-icon Scripts/RenderIcon.swift App/Views/Raccoon.swift 2>&1 | grep -v warning || true
build/render-icon App/Assets.xcassets/AppIcon.appiconset "${1:-build/raccoon-moods.png}"
