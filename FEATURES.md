# Feature checklist

Status key: **Written** = code exists, never compiled or run. **Verified** = confirmed on a device or CI (nothing yet).
**Planned** = not started. **Blocked** = needs an external model, service or credential.

## Phase 1: core workflow (current)
| Feature | Status |
|---|---|
| Import video from gallery (copied into app storage) | Written |
| Sequential preview of trimmed clips | Written |
| Trim (range slider), split at playhead, delete, reorder | Written |
| Per-clip speed (0.5x to 4x) and mute | Written |
| Undo / redo (50 steps) | Written |
| Autosave and restore after relaunch (single project) | Written |
| Export H.264/AAC MP4, save to gallery (Media3 on Android, AVFoundation on iOS) | Written |
| CI build (analyze, Android debug APK, iOS no-codesign) | Written, never run |

## Phase 2: text overlays (written this round, never compiled or run)
| Feature | Status |
|---|---|
| Text layers: add, edit text, color, size, start/end on project timeline, delete | Written |
| Drag text in preview to reposition, tap to edit | Written |
| Text saved with project, included in undo/redo | Written |
| Text burned into export on Android (Media3 OverlayEffect) | Written |
| Text burned into export on iOS (CATextLayer + AVVideoCompositionCoreAnimationTool) | Written |

Behavior change to check: export now always uses a fixed canvas (1280x720, or 720x1280 if the first clip is portrait)
with letterboxing, on both platforms.

Phase 2 gaps: font choice, stroke/background, rotation, animation presets, multi-line text, text timing is edited with a slider only.

## Known gaps in Phase 1
Export progress and cancel, multiple projects, 4:5 and custom ratios, photo and audio import,
frame-accurate seeking, low-storage checks, cleanup of unused imported media.

## Later phases (all Planned)
2. Multi-track timeline, overlays, picture-in-picture, snapping
3. Text layers, stickers, captions
4. Transitions, filters, color correction
5. Keyframes, speed curves, reverse, freeze frame
6. Audio tracks, waveforms, fades, ducking, voiceover
7. AI features. Each needs a model or service and has costs or limits:
   - Speech to text: on-device Whisper (model size and speed vary by device) or a paid API
   - Translation: external API, paid
   - Background removal: ML Kit / Vision (free, on-device) or a segmentation model
   - Beat detection: on-device audio analysis (no external cost)
   - Text to speech: platform voices (free, limited) or a paid API
   - Script-to-video and editing suggestions: LLM API with credentials and per-use cost
