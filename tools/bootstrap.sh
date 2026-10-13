---
*** Begin Patch
*** Update File: tools/bootstrap.sh
@@
-flutter pub add video_player image_picker path_provider path gal
+# Add common packages first. Allow failures so we can attempt a safe fallback for `gal`.
+flutter pub add video_player image_picker path_provider path || true
+
+# Try to add `gal` from pub.dev. If that fails (network or package not found),
+# fall back to writing a reasonable dependency into pubspec.yaml and run pub get.
+if ! flutter pub add gal; then
+  echo "Warning: flutter pub add gal failed; falling back to adding a pinned dependency to pubspec.yaml"
+  # Only append the dependency block if it doesn't already exist.
+  if ! grep -q "^  gal:" pubspec.yaml 2>/dev/null; then
+    cat >> pubspec.yaml <<'YAML'
+
+# Added by tools/bootstrap.sh fallback
dependencies:
+  gal: ^2.3.3
+YAML
+  fi
+  flutter pub get
+fi
*** End Patch
