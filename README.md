# Cutline (Flutter)

## Build
Requires the Flutter SDK (stable), Java 17, Android Studio, and Xcode for iOS.

    tools/bootstrap.sh
    cd build_app
    flutter analyze
    flutter run --release

Or push to GitHub and the `build` workflow runs analyze plus Android and iOS builds.

## Test by hand (Phase 1)
1. Add two videos from different sources. Confirm both preview.
2. Trim one, split the other mid-clip, reorder, set one clip to 2x and one muted.
3. Close and reopen the app. The project should be restored.
4. Undo and redo a few edits.
5. Export, then open the saved video in your gallery and check trims, order, speed, audio and orientation.

Report anything that fails with the exact error text or logcat / Xcode console output.
See FEATURES.md for status.

## Test by hand (Phase 2: text)
1. Make a project of two clips, one set to 2x. Add two text layers with different start/end times and positions.
2. In preview, confirm each text appears and disappears at its own times. Drag one and confirm it moves.
3. Close and reopen: the text layers should still be there. Undo/redo should add and remove them.
4. Export and open the video. Check that each text appears and disappears at the same moment as in the preview,
   in the same position and a similar size. Pay attention to times after the 2x clip.
Known risks: font and vertical placement can differ slightly between preview and export; timing after sped-up
clips on Android is the least certain part, because it depends on how Media3 timestamps composition-level overlays.
