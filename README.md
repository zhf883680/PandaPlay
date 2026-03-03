# PandaPlay

PandaPlay is a SwiftUI client for Emby/Jellyfin on Apple platforms.

## Implemented Features

### Home
- Continue Watching section from server resume data.
- Resume cards use two-line text:
  - line 1: series name (or item name)
  - line 2: episode info + title when available
- Home rows show up to 10 preview items.
- `More` entry for non-resume sections.
- Removed `Recently Added` section from home.

### More List
- Dedicated list page for sections with paging.
- Infinite load when scrolling near the bottom.
- Sort options:
  - by date added
  - by media duration/time

### Search
- Added global search entry on home toolbar.
- Added `SearchView` with server-side keyword search.
- Supports searching Movie / Series / Episode.
- Episode results open player directly.

### Player and Playback Reporting
- Continue Watching item tap opens player directly.
- Fixed resume row item tap hit/mapping behavior.
- Improved player drawable binding lifecycle to reduce SwiftUI/VLC threading issues.
- Playback check-in/reporting improvements:
  - start/progress/stopped reporting path cleanup
  - retry path when initial start report fails
  - aligned client authorization header usage

## Main Updated Files

- `PandaPlay/Views/Media/HomeView.swift`
- `PandaPlay/Views/Media/MoreMediaListView.swift`
- `PandaPlay/Views/Media/SearchView.swift`
- `PandaPlay/Views/Player/PlayerView.swift`
- `PandaPlay/ViewModels/HomeViewModel.swift`
- `PandaPlay/ViewModels/PlayerViewModel.swift`
- `PandaPlay/Services/EmbyClient.swift`
- `PandaPlay/App/ContentView.swift`

## Build
- Build in Xcode or run project build from your current workspace scheme.

