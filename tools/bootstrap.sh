#!/usr/bin/env bash
# Generates a full Flutter project in ./build_app (or $1) from these sources.
set -euo pipefail
SRC="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$SRC/build_app}"

flutter create --org com.example --project-name cutline --platforms android,ios "$OUT"
cd "$OUT"

# Add common packages first. Allow failures to be retried/handled below.
flutter pub add video_player image_picker path_provider path || true

# Try to add `gal` from pub.dev. If that fails (network or package not found),
# fall back to writing a reasonable dependency into pubspec.yaml and run pub get.
if ! flutter pub add gal; then
  echo "Warning: flutter pub add gal failed; falling back to adding a pinned dependency to pubspec.yaml"
  # Only append the dependency block if it doesn't already exist.
  if ! grep -q "^  gal:" pubspec.yaml 2>/dev/null; then
    cat >> pubspec.yaml <<'YAML'

# Added by tools/bootstrap.sh fallback
dependencies:
  gal: ^2.3.3
YAML
  fi
  flutter pub get
fi

# Copy app sources into the generated project
cp "$SRC/lib/main.dart" lib/main.dart
mkdir -p android/app/src/main/kotlin/com/example/cutline
cp "$SRC/android/MainActivity.kt" android/app/src/main/kotlin/com/example/cutline/MainActivity.kt
cp "$SRC/ios/AppDelegate.swift" ios/Runner/AppDelegate.swift
python3 "$SRC/tools/patch_native.py" .

echo "Project ready in $OUT"
