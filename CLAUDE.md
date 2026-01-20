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
  - Sparkle (v2.6.0+) - Auto-update framework

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

# Release
make release     # Build, sign, and publish a release

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
| Auto-updates | `UpdateService.swift`, `scripts/release.sh` |

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

---

## Auto-Update System (Sparkle)

EchoText uses Sparkle for automatic updates, hosted on Cloudflare.

### Infrastructure

| Component | URL/Value |
|-----------|-----------|
| **Appcast URL** | `https://echotext-updates.tarunyadav9761.workers.dev/appcast.xml` |
| **Worker URL** | `https://echotext-updates.tarunyadav9761.workers.dev` |
| **R2 Bucket** | `echotext-updates` |
| **KV Namespace ID** | `5b57a166e2a24287b2d3d4eae25b71ff` |

### Credentials

| Secret | Value |
|--------|-------|
| **Admin Secret** | `echotext-updates-admin-76f9a7be375bfaa6d07e3b7632960167` |
| **Cloudflare API Token** | `UZn5BlGUhkS6Zbyvl1Ua42luCleJG46YtUGsD2Vw` |
| **Cloudflare Account ID** | `9da0a3e2fbc6f382f556b4c4c622f6a3` |

### EdDSA Signing Key

- **Public Key** (in Info.plist): `Bo67frKqpavPc2nqKQk0xu+XThLl0SK8R/XIPfKGNa8=`
- **Private Key**: Stored in macOS Keychain (generated via Sparkle's `generate_keys`)

### How to Release an Update

1. **Bump version** in `Info.plist`:
   - `CFBundleShortVersionString` (e.g., "1.1")
   - `CFBundleVersion` (e.g., "2")

2. **Set environment variables**:
   ```bash
   export ECHOTEXT_ADMIN_SECRET="echotext-updates-admin-76f9a7be375bfaa6d07e3b7632960167"
   export CLOUDFLARE_API_TOKEN="UZn5BlGUhkS6Zbyvl1Ua42luCleJG46YtUGsD2Vw"
   ```

3. **Run the release script**:
   ```bash
   make release
   ```

This will:
- Build the app in Release configuration
- Create a signed DMG
- Upload to Cloudflare R2
- Update the appcast automatically

### Worker Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check |
| `/appcast.xml` | GET | Sparkle appcast feed |
| `/releases/:filename` | GET | Download update files |
| `/admin/release` | POST | Create/update release (requires auth) |
| `/admin/releases` | GET | List all releases (requires auth) |

### Files

| File | Purpose |
|------|---------|
| `cloudflare-updates-worker/` | Cloudflare Worker source |
| `scripts/release.sh` | Release automation script |
| `EchoText/Services/UpdateService.swift` | Sparkle wrapper service |

---

## Feedback System

EchoText includes an in-app feedback system that sends user feedback to a Cloudflare Worker backend.

### Infrastructure

| Component | URL/Value |
|-----------|-----------|
| **Feedback URL** | `https://echotext-feedback.tarunyadav9761.workers.dev` |
| **KV Namespace ID** | `eda9c0947d5e4a788eca99a3ef1e0e4a` |

### Credentials

| Secret | Value |
|--------|-------|
| **Admin Secret** | `echotext-feedback-admin-ed64161243d1f8a844b6b28b4c67ae60` |

### Worker Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check |
| `/submit` | POST | Submit feedback |
| `/admin/feedback` | GET | List all feedback (requires auth) |
| `/admin/feedback/:id` | GET | Get specific feedback (requires auth) |
| `/admin/feedback/:id` | DELETE | Delete feedback (requires auth) |

### Files

| File | Purpose |
|------|---------|
| `cloudflare-feedback-worker/` | Cloudflare Worker source |
| `EchoText/Services/FeedbackService.swift` | Feedback submission service |
| `EchoText/Views/Feedback/FeedbackView.swift` | Feedback UI |

### Optional: Discord/Slack Notifications

To receive notifications when users submit feedback:

```bash
cd cloudflare-feedback-worker
npx wrangler secret put NOTIFICATION_WEBHOOK
# Paste your Discord or Slack webhook URL
```

---

## Telemetry (TelemetryDeck)

EchoText uses TelemetryDeck for privacy-focused analytics. Users can opt out in Settings.

| Setting | Value |
|---------|-------|
| **App ID** | `F08DE9FB-4EDC-4F8D-8F43-442F290A80C4` |
| **Organization** | `com.tarunsaas` |
| **Dashboard** | https://dashboard.telemetrydeck.com |

Events tracked:
- `appLaunch` - App opened
- `recordingStarted` - User started recording
- `recordingCompleted` - Recording finished with transcription
- `transcriptionCompleted` - File/URL transcription completed
- `error` - Errors with context

---

## ⚠️ TODO: REMOVE BEFORE PRODUCTION ⚠️

### Credentials in This File

The credentials documented above (Admin Secret, API Token) are stored here for development convenience. Before making this repo public or sharing:

1. **Rotate the Cloudflare API Token** in Cloudflare dashboard
2. **Rotate the Admin Secret** with: `npx wrangler secret put ADMIN_SECRET`
3. **Move secrets to environment variables** or a secrets manager
4. **Remove or redact this section** from CLAUDE.md

### Dev Bypass Key for License Testing

A development bypass key exists for testing the app without a real license:

- **Key**: `ECHOTEXT-DEV-2024`
- **Location**: `EchoText/Services/LicenseService.swift` (lines 19-22 and 71-94)

**How to use**: Enter this key in the license activation field to bypass server validation.

**To remove for production**:
1. Delete lines 19-22 in `LicenseService.swift`:
   ```swift
   #if DEBUG
   private let devBypassKey = "ECHOTEXT-DEV-2024"
   #endif
   ```

2. Delete lines 71-94 in `LicenseService.swift` (the bypass check in `activate()` function)

**Note**: The `#if DEBUG` directive means this code is automatically excluded from Release builds. However, you should still remove it before publishing to ensure it's completely gone.
