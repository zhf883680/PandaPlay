# PandaPlay - Emby/Jellyfin Apple TV Player

An advanced tvOS media player for Emby/Jellyfin servers with MKV support.

[中文文档](README_CN.md)

## Features

- **Server Connection**
  - Emby/Jellyfin server authentication
  - Multiple server management with secure storage (Keychain)

- **Media Library**
  - Browse movies and TV shows
  - View recently added and resume items
  - Season and episode navigation

- **Video Playback**
  - **MKV format support** via KSPlayer
  - Direct streaming (no server transcoding)
  - Hardware-accelerated decoding
  - Subtitle and audio track support

- **User Experience**
  - Native tvOS interface with Siri Remote support
  - Focus-based navigation
  - Smooth image loading with blur hash placeholders

## Requirements

- macOS 14.0+
- Xcode 15.0+
- tvOS 15.0+
- Apple TV HD (4th gen) or Apple TV 4K

## Installation

### Building from Source

1. Clone the repository
2. Open `PandaPlay.xcodeproj` in Xcode
3. Select your development team in project settings
4. Build and run on tvOS Simulator or Apple TV

### Dependencies

The project uses Swift Package Manager for dependencies:

- **KSPlayer** - Media player with FFmpeg support for MKV and other formats
- **FFmpegKit** - Required by KSPlayer for media decoding

These are automatically resolved when building the project.

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
│   ├── Player/                # Video player with KSPlayer
│   ├── Settings/              # Settings management
│   └── Components/            # Reusable UI components
├── ViewModels/                 # View models
│   ├── ServerManager.swift    # Server configuration
│   ├── AuthManager.swift      # Authentication state
│   ├── HomeViewModel.swift    # Media library logic
│   └── PlayerViewModel.swift  # Player logic
├── Models/                     # Data models
│   └── AppError.swift         # Error types
├── Services/                   # Service layer
│   ├── EmbyClient.swift       # Emby/Jellyfin API client
│   ├── ImageLoader.swift      # Async image loading
│   ├── KeychainManager.swift  # Secure storage
│   ├── PlaybackProgressManager.swift
│   └── UserDefaultsManager.swift
└── Assets.xcassets            # Images and resources
```

## Known Issues

- Episode overview not displaying when selecting an episode (needs getItem API call)

## License

This project uses KSPlayer which is licensed under GPL. Please ensure compliance with KSPlayer's license terms if you fork or modify this project.

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.
