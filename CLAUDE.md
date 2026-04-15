# CLAUDE.md

Guidance for Claude Code (and other AI assistants) working in this repository.

## Project Overview

**ClipKid** is a Flutter mobile app (Android-first) that helps kids edit short videos. It provides a guided, kid-friendly workflow for importing clips from the gallery, trimming them, reordering them on a timeline, stabilizing shaky footage, and exporting a final MP4.

- **Package name:** `clipkid`
- **Version:** `1.1.0+5` (see `pubspec.yaml`)
- **SDK:** Dart `^3.10.8`, Flutter with Material 3 (dark theme)
- **Platforms:** Android only (see `flutter_launcher_icons` — `ios: false`)
- **Deployment:** Uses [Shorebird](https://shorebird.dev) for code push (`shorebird.yaml` is in assets and git-ignored)

## Architecture

The app is a single-screen Flutter app rooted at `EditorScreen`, backed by plain `ChangeNotifier`/`setState` state (no Bloc/Riverpod/Provider).

```
lib/
├── main.dart                         # ClipKidApp entry — Material3 dark theme
├── models/
│   ├── choreography.dart             # Core data model: Choreography → Clip → ClipTrim / ClipEffects
│   └── duck_guide.dart               # DuckGuide ChangeNotifier: state machine for tutorial
├── screens/
│   ├── editor_screen.dart            # Main editor (timeline + preview + controls)
│   ├── trim_screen.dart              # Per-clip multi-segment trim editor
│   └── export_dialog.dart            # ExportQuality / ExportSettings + options dialog
├── services/
│   ├── project_service.dart          # File picking, duration probing, save/load projects
│   ├── video_processor.dart          # FFmpeg vidstab stabilization (2-pass)
│   └── export_service.dart           # FFmpeg concat/filter_complex export to MP4
└── widgets/
    ├── timeline_view.dart            # Drag-to-reorder clip timeline
    ├── video_preview.dart            # Sequential clip playback with seeking
    └── duck_guide_overlay.dart       # Chat-bubble tutorial overlay
```

### Core Data Model (`lib/models/choreography.dart`)

The **Choreography** is the authoritative document — a JSON-serializable list of ordered **Clip**s. It is the thing that gets saved to disk and rendered to MP4.

- `Choreography` — versioned (currently `version: 1`), contains `List<Clip>`, `createdAt`, `modifiedAt`. `totalDurationMs` is computed from `clips.map((c) => c.endMs).max`.
- `Clip` — has `id` (uuid), `path` (source), optional `processedPath` (e.g. stabilized output), `startMs` (timeline position), `sourceDurationMs`, `trim` (legacy single trim), `segments` (multi-segment trim — **takes precedence over `trim` when non-empty**), `name`, `effects`.
  - `playbackPath` returns `processedPath ?? path`.
  - `effectiveSegments` returns `segments` if non-empty, else `[trim]`.
  - `durationMs` is the sum of all effective segment durations divided by `effects.speed`.
  - `needsProcessing` is true when `effects.stabilize` is set but there's no `processedPath`.
- `ClipTrim` — `inPointMs`/`outPointMs` in the **source video's** timeline.
- `ClipEffects` — `stabilize` (bool), `stabilizeStrength` (0.0–1.0), `speed` (0.25–4.0, default 1.0).

**JSON convention:** `toJson()` omits default/empty values (e.g. no `segments` key when empty, no `speed` key when 1.0). `fromJson()` is tolerant of missing keys and accepts a legacy `duration` key as an alias for `sourceDuration`.

### Services

- **`ProjectService`** (`lib/services/project_service.dart`)
  - `pickVideos()` uses `file_picker` (chosen over `image_picker` for Shorebird compatibility).
  - `addVideosToChoreographyFast()` + `resolveDurations()` is the **preferred flow**: insert clips immediately with a 5000ms placeholder duration, then resolve actual durations in the background via `VideoPlayerController`. The synchronous `addVideosToChoreography` is legacy.
  - Videos are sorted by `lastModifiedSync()` as a proxy for recording time.
  - Projects are saved as JSON under `getApplicationDocumentsDirectory()/clipkid_projects/`.

- **`VideoProcessor`** (`lib/services/video_processor.dart`)
  - Uses `ffmpeg_kit_flutter_new` (community fork with Full-GPL / vidstab).
  - Two-pass stabilization: `vidstabdetect` → `.trf` transform file → `vidstabtransform` (with `zoom=5`, `crop=black`).
  - `strength` (0.0–1.0) maps to FFmpeg `smoothing` (1–30).
  - Output lands in `getTemporaryDirectory()` as `stabilized_<timestamp>.mp4`.
  - `processChoreography()` processes all clips where `needsProcessing == true` and returns a new Choreography with `processedPath` set.

- **`ExportService`** (`lib/services/export_service.dart`)
  - Builds a single FFmpeg command that trims and concatenates all segments from all clips using `-ss`/`-t` per input and `filter_complex` with `concat`.
  - Single-segment export uses a simpler command path.
  - Video is normalized to the chosen `ExportQuality` (480p/720p/1080p, CRF 28/23/20) with `scale` + `pad` + `setsar=1` + `yuv420p`, encoded with `libx264 -preset fast`.
  - Audio: `-c:a aac -b:a 128k -ac 2` or `-an`. In multi-segment exports, audio is mapped from the first input only (`-map 0:a?`) — this is a known simplification.
  - Output goes to `getTemporaryDirectory()/exports/<safeName>.mp4`.

### Duck Guide (Interactive Tutorial)

`DuckGuide` is a `ChangeNotifier` state machine that drives an optional chat-bubble tutorial (`DuckGuideOverlay`). It walks the kid through: welcome → addClips → reviewClips → pickVibe → starMoment → trimClips → orderClips → polish → export → completed. The state (`GuideState`) transitions: `notStarted → offered → active/dismissed → completed`. The `EditorScreen` subscribes via `addListener` and calls hooks like `onClipsAdded`, `onClipTrimmed`, `onClipsReordered` to advance the flow.

## Development Workflow

### Commands

```bash
flutter pub get                          # Install dependencies
flutter run                              # Run on connected Android device/emulator
flutter analyze                          # Static analysis (uses flutter_lints)
flutter test                             # Run tests (only widget_test.dart exists today)
flutter build apk                        # Build release APK
flutter pub run flutter_launcher_icons   # Regenerate launcher icons from assets/icon.png
```

### Shorebird (code push)

`shorebird.yaml` is listed as an asset in `pubspec.yaml` but git-ignored. The app is distributed via Shorebird, which is why `file_picker` is used instead of `image_picker` for the main picking flow (Shorebird compatibility). Preserve this choice unless you've verified the alternative works with Shorebird.

### Testing

There is only a placeholder `test/widget_test.dart`. Add tests next to the code they cover when modifying services or models (the models are pure Dart and easy to unit test — start there).

## Conventions

- **Linting:** `package:flutter_lints/flutter.yaml` via `analysis_options.yaml`. No custom rules; don't add lint ignores casually.
- **State:** Plain `setState` / `ChangeNotifier` + `addListener`. Do **not** introduce a state-management package without discussion.
- **Immutability:** Models are immutable; mutate by constructing new instances via `copyWith` (or recomputed constructors like `Choreography.addClip`). Preserve this pattern.
- **IDs:** Use `Uuid().v4()` for new clip IDs (see `ProjectService._uuid`).
- **Time units:** **Milliseconds everywhere** (`startMs`, `durationMs`, `inPointMs`, `outPointMs`). Only convert to seconds at FFmpeg command boundaries (divide by `1000.0`).
- **File paths:**
  - Processed/stabilized output → `getTemporaryDirectory()`
  - Exported MP4s → `getTemporaryDirectory()/exports/`
  - Project JSON → `getApplicationDocumentsDirectory()/clipkid_projects/`
- **FFmpeg commands:** Always quote paths with `"..."` because file paths can contain spaces. Always pass `-y` to overwrite. Log full command + logs on failure (see existing `print('=== EXPORT FAILED ===')` style — these are intentional debug logs).
- **Segments vs. trim:** When editing clip trimming logic, remember `segments` takes precedence over `trim` when non-empty. Always go through `effectiveSegments` rather than reading either field directly.
- **Placeholder duration:** The sentinel value `5000` is used to mark clips awaiting duration resolution in `resolveDurations`. Don't reuse this specific value elsewhere.
- **Dark theme:** The UI uses `Colors.grey[900]`/`[800]` surfaces, `Colors.blue` accents, white text. Follow this palette in new widgets.

## Git Workflow

- Default development branch for AI-driven changes: `claude/add-claude-documentation-KGXIH` (as instructed per session).
- Commit messages follow short imperative style (check `git log` for recent examples before committing).
- Do not push to `main`/`master` without explicit user request.
