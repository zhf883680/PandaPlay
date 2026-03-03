# PandaPlay - Emby/Jellyfin Player

An advanced media player for Emby/Jellyfin servers with multi-platform support.

[中文文档](README_CN.md)

## Features

- **Multi-Platform Support**
  - iOS (iPhone & iPad) with native touch interface
  - tvOS with Siri Remote support
  - Responsive design optimized for each device type

- **Server Connection**
  - Emby/Jellyfin server authentication
  - Multiple server management with secure storage (Keychain)

- **Media Library**
  - Browse movies and TV shows
  - View recently added and resume items
  - Season and episode navigation

- **Video Playback**
  - **Wide format support** via MobileVLCKit (MKV, MP4, AVI, etc.)
  - Direct streaming (no server transcoding)
  - Hardware-accelerated decoding
  - **Subtitle track selection with on/off toggle**
  - Multiple audio track support
  - **Comprehensive player controls** (play/pause, seek, progress bar)
  - Auto-hide controls after 4 seconds of inactivity

- **User Experience**
  - Native iOS/tvOS interface
  - Focus-based navigation on tvOS
  - Smooth image loading with blur hash placeholders
  - Secure password input with SecureField

## Requirements

- macOS 14.0+
- Xcode 15.0+
- iOS 15.0+ / tvOS 15.0+
- CocoaPods

## Installation

### Building from Source

1. Clone the repository
2. Install CocoaPods dependencies:
   ```bash
   cd PandaPlay
   pod install
   ```
3. Open `PandaPlay.xcworkspace` in Xcode (use .xcworkspace, not .xcodeproj)
4. Select your development team in project settings
5. Build and run on iOS Simulator, tvOS Simulator, or physical device

### Dependencies

The project uses CocoaPods for dependency management:

- **MobileVLCKit** (~> 3.3.0) - Media player with VLC's FFmpeg-based decoding engine
  - Supports MKV, MP4, AVI, MOV, and many other formats
  - Hardware-accelerated decoding on iOS/tvOS
  - Built-in subtitle and audio track support

These are automatically resolved when running `pod install`.

## Configuration

On first launch, the app will guide you through:

1. **Server Setup**: Enter your Emby/Jellyfin server URL
2. **Authentication**: Login with your username and password
3. **Media Access**: Browse your media library

## Project Structure

```
PandaPlay/
├── App/                        # App entry point
│   ├── PandaPlayApp.swift
│   └── ContentView.swift
├── Views/                      # UI views
│   ├── Onboarding/            # Setup & login screens
│   ├── Media/                 # Media browsing (home, detail)
│   ├── Player/                # Video player with MobileVLCKit
│   ├── Settings/              # Settings management
│   └── Components/            # Reusable UI components
├── ViewModels/                 # View models
│   ├── ServerManager.swift    # Server configuration
│   ├── AuthManager.swift      # Authentication state
│   ├── HomeViewModel.swift    # Media library logic
│   └── PlayerViewModel.swift  # Player logic with subtitle/track management
├── Models/                     # Data models
│   └── AppError.swift         # Error types
├── Services/                   # Service layer
│   ├── EmbyClient.swift       # Emby/Jellyfin API client
│   ├── ImageLoader.swift      # Async image loading
│   ├── KeychainManager.swift  # Secure storage
│   ├── PlaybackProgressManager.swift
│   └── UserDefaultsManager.swift
├── Utils/                      # Utility functions
│   └── DeviceType.swift       # Device detection and responsive layout helpers
└── Assets.xcassets            # Images and resources
```

## Platform-Specific Features

### iOS (iPhone/iPad)
- Touch-based controls
- Swipe gestures for navigation
- Compact and regular size class support
- On-screen player controls with auto-hide

### tvOS
- Siri Remote integration
- Focus-based navigation
- Simplified control scheme optimized for remote

## Known Issues

- Episode overview not displaying when selecting an episode (needs getItem API call)

## License

This project uses MobileVLCKit which is licensed under LGPL v2.1 (or later). Please ensure compliance with MobileVLCKit's license terms if you fork or modify this project.

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.
