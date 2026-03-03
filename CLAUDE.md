# PandaPlay - Claude Development Guide

This file contains project-specific context for Claude Code to help with development tasks.

## Project Overview

PandaPlay is a multi-platform media player for Emby/Jellyfin servers, supporting both iOS (iPhone/iPad) and tvOS.

**Tech Stack:**
- Language: Swift
- UI Framework: SwiftUI
- Dependency Management: CocoaPods
- Media Player: MobileVLCKit (VLC-based)
- Minimum iOS/tvOS: 15.0

## Key Dependencies

### MobileVLCKit (~> 3.3.0)
- **What it does:** Provides media playback capabilities using VLC's FFmpeg-based engine
- **Why we use it:** Wide format support (MKV, MP4, AVI, etc.), hardware acceleration, built-in subtitle/audio track handling
- **License:** LGPL v2.1+
- **Important:** The project uses `.xcworkspace` (not `.xcodeproj`) because of CocoaPods

## Project Structure

```
PandaPlay/
├── App/                    # Application entry point
├── Views/                  # SwiftUI views
│   ├── Onboarding/        # Server setup and login
│   ├── Media/             # Media browsing (Home, Detail)
│   ├── Player/            # Video player with controls
│   ├── Settings/          # Settings management
│   └── Components/        # Reusable UI components
├── ViewModels/            # Business logic layer
├── Models/                # Data models
├── Services/              # Network and storage services
├── Utils/                 # Utilities (DeviceType for responsive design)
└── Assets.xcassets       # Images and resources
```

## Platform-Specific Development

### Device Detection
Use `DeviceType.current` from `Utils/DeviceType.swift` to detect the current platform:
- `.iPhone` - Compact size, touch controls
- `.iPad` - Regular size, touch controls
- `.tvOS` - Large screen, focus-based navigation

### Conditional Compilation
For tvOS-only APIs, use:
```swift
#if os(tvOS)
// tvOS-specific code (focusable, focusSection, @FocusState)
#else
// iOS-specific code
#endif
```

### Responsive Layout
Use the helper utilities in `DeviceType.swift`:
- `PlatformPadding.horizontal/vertical/sectionSpacing/itemSpacing`
- `PlatformSize.posterWidth/Height, backdropHeight, etc.`
- View modifiers: `.ifPhone {}`, `.ifTV {}`, `.ifIPad {}`

## Key Features Implementation

### Video Player (PlayerView.swift)
- Uses `MobileVLCKit.VLCMediaPlayer` for playback
- Implements custom player controls overlay
- Auto-hides controls after 4 seconds of inactivity
- Subtitle track selection with on/off toggle
- Supports multiple audio tracks

### Authentication (EmbyClient.swift)
- Connects to Emby/Jellyfin servers via REST API
- Uses Keychain for secure credential storage
- Manages access tokens and user sessions

### Image Loading (ImageLoader.swift)
- Async image loading from server URLs
- Implements blur hash placeholders for smooth UX

## Development Guidelines

### Building the Project
1. Always use `.xcworkspace`, not `.xcodeproj`
2. Run `pod install` if dependencies are missing
3. Select the appropriate target destination (iOS/tvOS)

### Adding New Features
1. Consider platform differences (iOS touch vs tvOS focus)
2. Use `DeviceType.current` for responsive layouts
3. Test on both iOS Simulator and tvOS Simulator
4. Use conditional compilation for platform-specific APIs

### UI Development
- **Focus Engine (tvOS):** Use `.focusable()`, `focusSection()`, `@FocusState`
- **Touch (iOS):** Use buttons, gestures, sheet presentations
- **Spacing:** Use `PlatformPadding` constants for consistency
- **Sizes:** Use `PlatformSize` constants for responsive elements

### Common Tasks

**Add a new view:**
1. Create in appropriate `Views/` subdirectory
2. Use `DeviceType.current` for platform-specific layout
3. Test on both iOS and tvOS simulators

**Update player controls:**
1. Edit `Views/Player/PlayerView.swift`
2. Ensure controls work on both touch and focus-based interfaces
3. Consider tvOS's simplified control paradigm

**API integration:**
1. Add methods to `Services/EmbyClient.swift`
2. Handle errors with `Models/AppError.swift`
3. Update ViewModels to call new API methods

## Known Issues

- Episode overview not displaying when selecting an episode (needs getItem API call)

## Testing

When making changes:
1. Test on iPhone Simulator (compact size)
2. Test on iPad Simulator (regular size)
3. Test on tvOS Simulator (focus navigation)
4. Verify player controls work correctly on all platforms
5. Test subtitle and audio track switching

## License Considerations

This project uses MobileVLCKit (LGPL v2.1+). Any modifications must comply with the LGPL terms, particularly regarding:
- Linking to the library
- Providing mechanism to relink with modified versions
- Distributing source code of any modifications to MobileVLCKit itself
