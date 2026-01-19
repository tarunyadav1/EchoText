# EchoText - Claude Code Context

## Project Overview

EchoText is a macOS app for voice-to-text transcription using WhisperKit (on-device ML). It features:
- Real-time dictation with auto-insert into any app
- File transcription (audio/video files)
- Menu bar integration with global hotkey
- Multiple Whisper model sizes (tiny to large)

## Tech Stack

- **Language**: Swift 5.0
- **UI Framework**: SwiftUI with native Liquid Glass (macOS 26+)
- **Min macOS**: 26.0 (Tahoe)
- **Design System**: Apple Liquid Glass
- **Dependencies**:
  - WhisperKit (v0.6.0+) - On-device speech recognition
  - KeyboardShortcuts (v2.0.0+) - Global hotkey handling

## Color Palette

EchoText uses a warm, vibrant color palette:

| Color | Hex | Name | Usage |
|-------|-----|------|-------|
| ![#0C0A3E](https://via.placeholder.com/15/0C0A3E/0C0A3E.png) | `#0C0A3E` | Russian Violet | Dark backgrounds, text |
| ![#7B1E7A](https://via.placeholder.com/15/7B1E7A/7B1E7A.png) | `#7B1E7A` | Patriarch | Secondary accent, gradients |
| ![#B33F62](https://via.placeholder.com/15/B33F62/B33F62.png) | `#B33F62` | Irresistible | Voice/audio primary accent |
| ![#F9564F](https://via.placeholder.com/15/F9564F/F9564F.png) | `#F9564F` | Tart Orange | **Primary accent**, buttons, highlights |
| ![#F3C677](https://via.placeholder.com/15/F3C677/F3C677.png) | `#F3C677` | Gold Crayola | Secondary voice, success states |

### Color Roles in DesignSystem.swift
- `accent` = Tart Orange (`#F9564F`) - Primary brand color
- `voicePrimary` = Irresistible (`#B33F62`) - Voice/recording UI
- `voiceSecondary` = Gold Crayola (`#F3C677`) - Secondary voice elements
- `spectralPurple` = Patriarch (`#7B1E7A`) - Gradient accents
- Gradients use combinations of the palette colors

## Liquid Glass Design

The app uses Apple's native Liquid Glass design language introduced in macOS 26. Key APIs:

- `.glassEffect(.regular)` - Standard translucent glass
- `.glassEffect(.regular.tint(color))` - Tinted glass
- `.glassEffect(.regular.interactive())` - Interactive glass with press effects
- `.glassEffect(.clear)` - High transparency glass
- `GlassEffectContainer` - Groups glass elements with morphing

Glass should be used for navigation/controls floating over content, not for content itself.

## Project Structure

```
EchoText/
├── App/                 # App entry, delegate, state
├── Models/              # Data models (WhisperModel, RecordingState, etc.)
├── Services/            # Core services
│   ├── AudioRecordingService.swift
│   ├── WhisperService.swift
│   ├── TextInsertionService.swift  # Accessibility-dependent
│   ├── PermissionService.swift
│   └── HotkeyService.swift
├── ViewModels/          # MVVM view models
├── Views/
│   ├── Main/            # Main window tabs
│   ├── Floating/        # Recording overlay window
│   ├── MenuBar/         # Menu bar popover
│   ├── Settings/        # Settings tabs
│   ├── Onboarding/      # First-run setup
│   └── Components/      # Reusable UI components
├── Utilities/           # Constants, DesignSystem, Extensions
└── Resources/           # Info.plist, Assets, Entitlements
```

## Development Commands

Use the Makefile for all build operations:

```bash
# Standard builds
make run         # Build and run the app
make restart     # Kill running instance and relaunch
make build       # Incremental build (fast, may use cache)

# Guaranteed fresh builds (use if changes don't appear)
make fresh          # Touch all files + build (forces recompile)
make run-fresh      # Fresh build + run
make restart-fresh  # Kill + fresh build + run
make fresh-clean    # Nuclear: delete all caches + rebuild

# Utilities
make verify      # Check when app binary was last built
make run-only    # Run without rebuilding
make clean       # Remove build artifacts
make rebuild     # Clean + build

# Permissions
make open-settings  # Open Accessibility settings

# Other
make xcode       # Open project in Xcode
make help        # Show all commands
```

**If your code changes don't appear in the app**, use `make restart-fresh`.

## Build Configuration

- **Debug builds**: Ad-hoc signed (`-`), hardened runtime disabled
- **Release builds**: Automatic signing, hardened runtime enabled
- **Build output**: `build-output/` directory
- **Bundle ID**: `com.echotext.app`

## Permissions Required

1. **Microphone** - For voice recording (prompted automatically)
2. **Accessibility** - For auto-inserting text into other apps

### Accessibility Permission Setup

The app uses ad-hoc signing for Debug builds so permissions persist across rebuilds. To grant accessibility:

1. Run `make open-settings` to open System Settings
2. Go to Privacy & Security > Accessibility
3. Click + and add: `build-output/Build/Products/Debug/EchoText.app`

## Key Files for Common Tasks

| Task | Files |
|------|-------|
| Recording logic | `AppState.swift`, `AudioRecordingService.swift` |
| Transcription | `WhisperService.swift` |
| Text insertion | `TextInsertionService.swift` |
| Permissions | `PermissionService.swift` |
| Global hotkey | `HotkeyService.swift` |
| UI styling | `DesignSystem.swift` |
| App settings | `AppSettings.swift`, `SettingsView.swift` |

## Testing Changes

After making code changes:
```bash
make restart  # Fastest way to test changes
```

## Common Issues

### "Accessibility permission required" after rebuild
This shouldn't happen with the current setup. If it does:
1. Run `make open-settings`
2. Remove and re-add the app in Accessibility settings

### Build fails with signing errors
The Makefile uses ad-hoc signing which doesn't require a dev team. If building from Xcode directly, ensure Debug scheme is selected.

### WhisperKit model download issues
Models are downloaded to `~/Library/Application Support/EchoText/Models/`. Delete this folder to force re-download.
