# PandaPlay

A SwiftUI media client for Emby/Jellyfin servers, supporting iPhone, iPad, and Apple TV.

## Requirements

- macOS 15.0+
- Xcode 16.0+
- [CocoaPods](https://cocoapods.org/) (`gem install cocoapods`)

## Getting Started

```bash
# 1. Install dependencies
pod install

# 2. Open the workspace (NOT .xcodeproj)
open PandaPlay.xcworkspace

# 3. Select a target scheme in Xcode and run
#    - PandaPlay-iOS  → iPhone / iPad
#    - PandaPlay       → Apple TV (tvOS)
```

## Features

- **Home** — Continue Watching row, library-based content rows with paging
- **Search** — Server-side keyword search across Movies, Series, and Episodes
- **Player** — VLC-based playback with subtitle/audio track switching, resume support
- **Multi-server** — Add and switch between multiple Emby/Jellyfin servers
- **Cross-platform** — Adaptive UI for iPhone, iPad, and Apple TV

## Tech Stack

| Component     | Technology                    |
|---------------|-------------------------------|
| Language      | Swift                         |
| UI Framework  | SwiftUI                       |
| Media Player  | MobileVLCKit / TVVLCKit       |
| Dependencies  | CocoaPods                     |
| Minimum OS    | iOS 18.0 / tvOS 18.0          |

## Project Structure

```
PandaPlay/
├── App/                    # Entry point & root view
├── Views/
│   ├── Onboarding/        # Server setup & login
│   ├── Media/             # Home, detail, search, library browsing
│   ├── Player/            # Video player & controls
│   ├── Settings/          # Server & app settings
│   └── Components/        # Reusable UI components
├── ViewModels/            # Business logic
├── Models/                # Data models
├── Services/              # Networking (EmbyClient) & storage
└── Utils/                 # Device detection & helpers
```

## License

MobileVLCKit and TVVLCKit are licensed under LGPL v2.1+.
