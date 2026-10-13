#!/usr/bin/env bash
# Generates a full Flutter project in ./build_app (or $1) from these sources.
set -euo pipefail

SRC="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$SRC/build_app}"

flutter create --org com.example --project-name cutline --platforms android,ios "$OUT"
cd "$OUT"

flutter pub add video_player image_picker path_provider path
if ! flutter pub add gal; then
  echo "Adding gal dependency through pubspec.yaml fallback"
  python3 - <<'PY2'
from pathlib import Path
import re

p = Path("pubspec.yaml")
s = p.read_text()
if not re.search(r"(?m)^  gal:", s):
    s = re.sub(
        r"(?m)^dependencies:\s*$",
        "dependencies:\n  gal: ^2.3.3",
        s,
        count=1
    )
    p.write_text(s)
PY2
  flutter pub get
fi

cp "$SRC/lib/main.dart" lib/main.dart
mkdir -p android/app/src/main/kotlin/com/example/cutline
cp "$SRC/android/MainActivity.kt" android/app/src/main/kotlin/com/example/cutline/MainActivity.kt
cp "$SRC/ios/AppDelegate.swift" ios/Runner/AppDelegate.swift
python3 "$SRC/tools/patch_native.py" .
echo "Project ready in $OUT"
