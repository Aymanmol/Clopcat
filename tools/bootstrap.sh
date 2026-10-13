#!/usr/bin/env bash
# Generates a full Flutter project in ./build_app (or $1) from these sources.
set -euo pipefail
SRC="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$SRC/build_app}"
flutter create --org com.example --project-name cutline --platforms android,ios "$OUT"
cd "$OUT"
flutter pub add video_player image_picker path_provider path gal
cp "$SRC/lib/main.dart" lib/main.dart
mkdir -p android/app/src/main/kotlin/com/example/cutline
cp "$SRC/android/MainActivity.kt" android/app/src/main/kotlin/com/example/cutline/MainActivity.kt
cp "$SRC/ios/AppDelegate.swift" ios/Runner/AppDelegate.swift
python3 "$SRC/tools/patch_native.py" .
echo "Project ready in $OUT"
