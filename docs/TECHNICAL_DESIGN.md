# PandaPlay 功能完善 — 技术设计文档

> 基于 qemby (Qt/C++ Emby 桌面客户端) 参考文档，为 PandaPlay 补齐缺失功能。
> 本文档仅描述设计，不包含实施代码。实施时按 Phase 顺序逐步执行。

---

## 目录

1. [Phase 1: 数据模型增强](#phase-1-数据模型增强)
2. [Phase 2: 新增 API 端点](#phase-2-新增-api-端点)
3. [Phase 3: 首页增强](#phase-3-首页增强)
4. [Phase 4: 详情页丰富](#phase-4-详情页丰富)
5. [Phase 5: 播放器改进](#phase-5-播放器改进)
6. [Phase 6: 设置与库浏览](#phase-6-设置与库浏览)
7. [新增文件清单](#新增文件清单)
8. [Xcode 项目配置](#xcode-项目配置)

---

## Phase 1: 数据模型增强

**目标**: 丰富 `MediaItem` 数据模型，使其能承载 Emby API 返回的完整字段，为后续所有功能提供数据基础。

**修改文件**: `PandaPlay/Services/EmbyClient.swift`（底部 `// MARK: - Models` 区域，567-758 行）

### 1.1 给 MediaItem 新增字段

在现有 `MediaItem` struct 中添加以下可选字段（全部设 `= nil` 默认值，避免破坏已有的 memberwise init 调用）:

```swift
struct MediaItem: Codable, Identifiable, Hashable {
    // === 现有字段（保持不变）===
    let id: String
    let name: String?
    let type: String?
    let overview: String?
    let imageTags: ImageTags?
    let imageBlurHashes: ImageBlurHashes?
    let productionYear: Int?
    let genres: [String]?
    let runTimeTicks: Int64?
    let playbackPositionTicks: Int64?
    let userData: UserData?
    let mediaType: String?
    let indexNumber: Int?
    let parentIndexNumber: Int?
    let seasonId: String?
    let seriesId: String?
    let seriesName: String?
    let communityRating: Double?

    // === 新增字段 ===
    let taglines: [String]?              // "Taglines" — 影片标语
    let officialRating: String?          // "OfficialRating" — 分级 PG-13/R
    let people: [MediaPersonInfo]?       // "People" — 演职人员
    let studios: [MediaStudioInfo]?      // "Studios" — 制片厂
    let externalUrls: [MediaExternalUrlInfo]?  // "ExternalUrls" — 外部链接
    let remoteTrailers: [RemoteTrailerInfo]?   // "RemoteTrailers" — 预告片
    let providerIds: [String: String]?   // "ProviderIds" — IMDb/TMDb ID
    let canDownload: Bool?               // "CanDownload"
    let criticRating: Int?               // "CriticRating"
    let childCount: Int?                 // "ChildCount" — 子项数量（季数等）
    let status: String?                  // "Status" — Continuing/Ended
    let collectionType: String?          // "CollectionType" — movies/tvshows 等
}
```

每个新字段的 CodingKeys 枚举也需要添加对应条目。

### 1.2 新增支持模型 Struct

添加以下 `Codable` struct:

```swift
struct MediaPersonInfo: Codable, Identifiable, Hashable {
    let id: String          // "Id"
    let name: String        // "Name"
    let role: String?       // "Role"
    let type: String?       // "Type" — Actor/Director/Writer 等
    let primaryImageTag: String?  // "PrimaryImageTag"
}

struct MediaStudioInfo: Codable, Hashable {
    let name: String        // "Name"
    let id: String?         // "Id"
}

struct MediaExternalUrlInfo: Codable {
    let name: String        // "Name"
    let url: String         // "Url"
}

struct RemoteTrailerInfo: Codable {
    let url: String         // "Url"
    let name: String?       // "Name"
}
```

### 1.3 修改 getItem() 请求参数

**文件**: `EmbyClient.swift` 第 242-256 行的 `getItem(itemId:userId:)` 方法

当前代码直接 GET 请求不传 Fields 参数，服务器只返回基础字段。需改为带 Fields 查询:

```
GET emby/Users/{userId}/Items/{itemId}?Fields=Overview,Genres,CommunityRating,ProductionYear,RunTimeTicks,People,Studios,ExternalUrls,ProviderIds,Taglines,RemoteTrailers,OfficialRating,CanDownload,CriticRating,ChildCount,Status
```

具体修改: 用 `URLComponents` 构造 URL 并添加 `Fields` queryItem。

### 1.4 修复剧集简介不显示 (已知 Bug)

**文件**: `EmbyClient.swift` 第 281-303 行的 `getEpisodes(seasonId:userId:)`

**根因**: 请求未包含 `Fields=Overview` 参数，返回的 episode 对象 overview 字段为 nil。

**修复**: 在请求 URL 中追加 `&Fields=Overview,RunTimeTicks` 参数。

同时，在 `MediaDetailView.swift` 的 `SeasonEpisodeSelector` 中（第 426 行），当用户点击 episode 时，除了设置 `selectedEpisode`，还应调用 `getItem()` 获取该 episode 的完整信息:

```
.onTapGesture {
    selectedEpisode = episode
    onEpisodeSelected(episode)
    // 新增: 获取完整 episode 详情以显示 overview
    Task { await loadEpisodeDetails(for: episode.id) }
}
```

新增 `loadEpisodeDetails(for:)` 方法调用 `EmbyClient.getItem()` 并更新 `selectedEpisode` 和 `onOverviewChanged`。

### 1.5 Preview 适配

`PlayerView.swift` 第 482-501 行和 `MediaDetailView.swift` 第 728-753 行的 `#Preview` 使用 memberwise init。由于所有新字段都有 `= nil` 默认值，Swift 不会要求在 init 中提供它们，但如果 Swift 版本不支持 struct 存储属性默认值 + memberwise init 的组合，需要改用带默认参数的自定义 init。

**验证**: 先编译一次，如果 memberwise init 报错，则为 MediaItem 添加自定义 init:
```swift
init(id: String, name: String? = nil, type: String? = nil, overview: String? = nil,
     imageTags: ImageTags? = nil, /* ...所有现有字段... */) {
    self.id = id; self.name = name; // ...
}
```

---

## Phase 2: 新增 API 端点

**目标**: 在 `EmbyClient` 中添加收藏、播放状态、推荐、下一集、媒体库浏览等 API 方法。

**修改文件**: `PandaPlay/Services/EmbyClient.swift`

### 2.1 通用请求辅助方法

新增 private helper 减少 POST/DELETE 重复代码:

```swift
private func sendEmptyRequest(endpoint: String, method: String) async throws {
    guard let url = URL(string: baseURL + endpoint) else {
        throw EmbyError.invalidURL
    }
    var request = URLRequest(url: url)
    request.httpMethod = method
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    if let token = accessToken {
        request.setValue(token, forHTTPHeaderField: "X-Emby-Token")
    }
    let (_, response) = try await session.data(for: request)
    if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
        throw EmbyError.invalidResponse
    }
}
```

### 2.2 收藏管理

**API 参考**: qemby 文档 02 第 7 节

```swift
// MARK: - Favorites
func setFavorite(itemId: String, userId: String, isFavorite: Bool) async throws {
    let endpoint = "emby/Users/\(userId)/FavoriteItems/\(itemId)"
    try await sendEmptyRequest(endpoint: endpoint, method: isFavorite ? "POST" : "DELETE")
}
```

### 2.3 播放状态

**API 参考**: qemby 文档 02 第 7 节

```swift
// MARK: - Played Status
func setPlayed(itemId: String, userId: String, isPlayed: Bool) async throws {
    let endpoint = "emby/Users/\(userId)/PlayedItems/\(itemId)"
    try await sendEmptyRequest(endpoint: endpoint, method: isPlayed ? "POST" : "DELETE")
}
```

### 2.4 相似推荐

**API 参考**: qemby 文档 02 第 9 节 — `GET /Items/{itemId}/Similar`

```swift
func getSimilarItems(itemId: String, userId: String, limit: Int = 12) async throws -> [MediaItem] {
    let endpoint = "emby/Items/\(itemId)/Similar?UserId=\(userId)&Limit=\(limit)&Fields=Overview,Genres,CommunityRating,ProductionYear"
    guard let url = URL(string: baseURL + endpoint) else {
        throw EmbyError.invalidURL
    }
    var request = URLRequest(url: url)
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    if let token = accessToken {
        request.setValue(token, forHTTPHeaderField: "X-Emby-Token")
    }
    let (data, _) = try await session.data(for: request)
    // API 返回 {"Items": [...]}
    struct SimilarResponse: Codable { let items: [MediaItem]?; enum CodingKeys: String, CodingKey { case items = "Items" } }
    return (try? JSONDecoder().decode(SimilarResponse.self, from: data).items) ?? []
}
```

### 2.5 下一集 (Next Up)

**API 参考**: qemby 文档 02 第 5 节 — `GET /Shows/NextUp`

```swift
func getNextUp(userId: String, limit: Int = 20) async throws -> [MediaItem] {
    let endpoint = "emby/Shows/NextUp?UserId=\(userId)&Limit=\(limit)&Fields=Overview,Genres,CommunityRating,ProductionYear"
    guard let url = URL(string: baseURL + endpoint) else {
        throw EmbyError.invalidURL
    }
    var request = URLRequest(url: url)
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    if let token = accessToken {
        request.setValue(token, forHTTPHeaderField: "X-Emby-Token")
    }
    let (data, _) = try await session.data(for: request)
    return (try? JSONDecoder().decode(MediaItemsResponse.self, from: data).items) ?? []
}
```

### 2.6 用户视图 (媒体库列表)

**API 参考**: qemby 文档 02 第 4 节 — `GET /Users/{userId}/Views`

```swift
func getUserViews(userId: String) async throws -> [MediaItem] {
    let endpoint = "emby/Users/\(userId)/Views"
    guard let url = URL(string: baseURL + endpoint) else {
        throw EmbyError.invalidURL
    }
    var request = URLRequest(url: url)
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    if let token = accessToken {
        request.setValue(token, forHTTPHeaderField: "X-Emby-Token")
    }
    let (data, _) = try await session.data(for: request)
    return (try? JSONDecoder().decode(MediaItemsResponse.self, from: data).items) ?? []
}
```

### 2.7 ServerInfo 扩展

**API 参考**: qemby 文档 02 第 11 节

给 `ServerInfo` model 添加字段以支持设置页展示:

```swift
struct ServerInfo: Codable {
    let productName: String?     // "ProductName"
    let version: String?         // "Version"
    let serverName: String?      // "ServerName"
    let id: String?              // "Id"
    let operatingSystem: String? // "OperatingSystem" — 新增
}
```

---

## Phase 3: 首页增强

**目标**: 在首页添加"下一集"、"最新添加"、"媒体库"三个新内容区块。

**修改文件**:
- `PandaPlay/ViewModels/HomeViewModel.swift`
- `PandaPlay/Views/Media/HomeView.swift`

**新建文件**:
- `PandaPlay/Views/Components/LibraryTile.swift`

### 3.1 HomeViewModel 扩展

新增 Published 属性:

```swift
@Published var nextUpItems: [MediaItem] = []
@Published var latestItems: [MediaItem] = []
@Published var libraries: [MediaItem] = []
```

修改 `hasContent` 计算属性:

```swift
var hasContent: Bool {
    !resumeItems.isEmpty || !movies.isEmpty || !tvShows.isEmpty
        || !nextUpItems.isEmpty || !latestItems.isEmpty || !libraries.isEmpty
}
```

在 `loadContent()` 中，与现有三个并行请求一起新增:

```swift
async let nextUp = embyClient?.getNextUp(userId: userId, limit: 12)
async let latest = embyClient?.getItems(userId: userId, filters: [
    "IncludeItemTypes": "Movie,Series",
    "SortBy": "DateCreated",
    "SortOrder": "Descending",
    "Limit": "20",
    "Recursive": "true",
    "Fields": "Overview,Genres,CommunityRating,ProductionYear"
])
async let libraries = embyClient?.getUserViews(userId: userId)
```

收集结果:
```swift
let results = try await [resume, movies, tvShows, nextUp, latest, libraries] as [[MediaItem]?]
self.nextUpItems = results[3] ?? []
self.latestItems = results[4] ?? []
self.libraries = results[5] ?? []
```

### 3.2 HomeView 内容行扩展

在 `contentRows` 视图构建器中（第 282-328 行），按以下顺序插入新行:

```
1. 继续观看 (已有)
2. 下一集 (Next Up) — 新增
3. 最新添加 (Latest) — 新增
4. 电影 (已有)
5. 电视剧 (已有)
6. 媒体库 (Libraries) — 新增，使用不同的卡片样式
```

**下一集行** — 使用 `.resume` displayMode，点击直接进入播放器:
```swift
if !viewModel.nextUpItems.isEmpty {
    MediaRow(
        title: "下一集",
        items: viewModel.nextUpItems,
        serverURL: serverManager.currentServer?.url ?? "",
        displayMode: .resume,
        onSelect: { item in selectedDestination = .player(item) }
    )
}
```

**最新添加行** — 标准海报模式:
```swift
if !viewModel.latestItems.isEmpty {
    MediaRow(
        title: "最新添加",
        items: viewModel.latestItems,
        serverURL: serverManager.currentServer?.url ?? "",
        onSelect: { item in selectedDestination = .detail(item) }
    )
}
```

**媒体库行** — 横向滚动图标卡片（非海报样式）:
```swift
if !viewModel.libraries.isEmpty {
    VStack(alignment: .leading, spacing: 12) {
        Text("媒体库")
            .font(DeviceType.current == .iPhone ? .headline : .title2)
            .bold()
            .padding(.horizontal, horizontalPadding)

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: itemSpacing) {
                ForEach(viewModel.libraries) { library in
                    LibraryTile(library: library, serverURL: serverManager.currentServer?.url ?? "")
                        .onTapGesture { selectedDestination = .library(library) }
                }
            }
            .padding(.horizontal, horizontalPadding)
        }
        #if !os(iOS)
        .focusSection()
        #endif
    }
}
```

### 3.3 LibraryTile 组件

**新建文件**: `PandaPlay/Views/Components/LibraryTile.swift`

根据 `collectionType` 显示不同图标和颜色的方块卡片:

```
collectionType: "movies"     → 🎬 icon → film
collectionType: "tvshows"    → 📺 icon → tv
collectionType: "music"      → 🎵 icon → music.note
collectionType: "books"      → 📚 icon → book
collectionType: "homevideos" → 📹 icon → video
collectionType: "photos"     → 🖼 icon → photo
collectionType: "playlists"  → 📋 icon → list.bullet
其他 / nil                   → 📁 icon → folder
```

卡片布局:
```
┌─────────────────┐
│                  │
│   [SF Symbol]    │  ← 60pt (iPhone) / 80pt (iPad) / 100pt (tvOS)
│                  │
│   Library Name   │  ← 1行截断
└─────────────────┘
```

尺寸: iPhone 120x100, iPad 160x130, tvOS 200x160。背景色根据 collectionType 变化（蓝色系为主）。

### 3.4 导航目标扩展

**文件**: `HomeView.swift` 第 519-531 行

扩展 `HomeNavigationDestination` 枚举:

```swift
enum HomeNavigationDestination: Identifiable, Hashable {
    case detail(MediaItem)
    case player(MediaItem)
    case library(MediaItem)    // 新增
}
```

在 `navigationDestination` 处理中添加:
```swift
case .library(let library):
    LibraryBrowseView(library: library)
```

### 3.5 HomeMediaSection 扩展

**文件**: `HomeView.swift` 第 533-550 行

```swift
enum HomeMediaSection: String, Identifiable, CaseIterable {
    case resume
    case nextUp       // 新增
    case latest       // 新增
    case movies
    case tvShows

    var title: String {
        switch self {
        case .resume:  return "继续观看"
        case .nextUp:  return "下一集"
        case .latest:  return "最新添加"
        case .movies:  return "电影"
        case .tvShows: return "电视剧"
        }
    }
}
```

---

## Phase 4: 详情页丰富

**目标**: 在详情页添加收藏/已看按钮、相似推荐、演员、tagline、分级徽章，并修复剧集简介。

**修改文件**: `PandaPlay/Views/Media/MediaDetailView.swift`

**新建文件**: `PandaPlay/Views/Components/PersonCard.swift`

### 4.1 新增状态属性

```swift
@State private var isFavorite: Bool = false
@State private var isPlayed: Bool = false
@State private var similarItems: [MediaItem] = []
```

### 4.2 初始化收藏/已看状态

在 `loadFullItemDetails()` 中，获取到 `fullItem` 后:
```swift
isFavorite = item.userData?.isFavorite ?? false
isPlayed = item.userData?.played ?? false
```

同时并行获取相似推荐:
```swift
async let similar = client.getSimilarItems(itemId: mediaItem.id, userId: userId, limit: 12)
// ... 在 do 块中:
self.similarItems = (try? await similar) ?? []
```

### 4.3 操作按钮区域

在现有播放按钮旁（第 184-194 行）添加按钮组:

```
┌────────────────────────────────────────────────┐
│  [▶ 播放]  [♡ 收藏]  [✓ 已看]                    │
└────────────────────────────────────────────────┘
```

iPhone 水平排列，按钮更小; iPad/tvOS 间距更大。

收藏按钮:
```swift
Button { await toggleFavorite() } label: {
    Label(isFavorite ? "已收藏" : "收藏",
          systemImage: isFavorite ? "heart.fill" : "heart")
}
.tint(isFavorite ? .pink : .blue)
.buttonStyle(.bordered)
```

已看按钮:
```swift
Button { await togglePlayed() } label: {
    Label(isPlayed ? "已看" : "标记已看",
          systemImage: isPlayed ? "checkmark.circle.fill" : "checkmark.circle")
}
.tint(isPlayed ? .green : .blue)
.buttonStyle(.bordered)
```

toggleFavorite/togglePlayed 方法:
```swift
func toggleFavorite() async {
    guard let client = createEmbyClient() else { return }
    let newValue = !isFavorite
    do {
        try await client.setFavorite(itemId: displayItem.id, userId: userId, isFavorite: newValue)
        isFavorite = newValue
    } catch {
        toastManager.show(.error("操作失败"))
    }
}
```

### 4.4 Tagline 显示

在标题下方（第 138 行之后），如果 taglines 不为空，显示第一条:

```swift
if let taglines = displayItem.taglines, let tagline = taglines.first, !tagline.isEmpty {
    Text(tagline)
        .italic()
        .foregroundColor(.white.opacity(0.7))
        .font(DeviceType.current == .iPhone ? .caption : .body)
}
```

### 4.5 官方分级徽章

在 metadata HStack 中（第 143-181 行），年份/类型/时长/评分之后添加:

```swift
if let rating = displayItem.officialRating {
    Text(rating)
        .font(DeviceType.current == .iPhone ? .caption2 : .caption)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.white.opacity(0.2))
        .cornerRadius(4)
        .foregroundColor(.white)
}
```

### 4.6 演职人员区域

在简介/选季选集下方添加水平滚动演员列表:

```
┌─────────────────────────────────────────────────┐
│  演职人员                                        │
│                                                  │
│  [👤] [👤] [👤] [👤] [👤] [👤] →               │
│  张三  李四  王五  赵六  钱     孙               │
│  主角  配角  导演                                  │
└─────────────────────────────────────────────────┘
```

```swift
if let people = displayItem.people, !people.isEmpty {
    VStack(alignment: .leading, spacing: 12) {
        Text("演职人员")
            .font(.headline)
            .padding(.horizontal, horizontalPadding)

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: itemSpacing) {
                ForEach(people) { person in
                    PersonCard(person: person, serverURL: serverManager.currentServer?.url ?? "")
                }
            }
            .padding(.horizontal, horizontalPadding)
        }
    }
}
```

过滤逻辑: 只显示 `type` 为 "Actor"、"Director"、"Writer" 的人，最多显示前 20 个。

### 4.7 PersonCard 组件

**新建文件**: `PandaPlay/Views/Components/PersonCard.swift`

```
┌──────────┐
│   [头像]   │  ← 圆形裁剪，60pt (iPhone) / 80pt (iPad) / 100pt (tvOS)
│           │
│  张三     │  ← 1行截断
│  饰 主角   │  ← 次要颜色，1行截断
└──────────┘
```

头像 URL: `{serverURL}/emby/Items/{person.id}/Images/Primary?maxWidth=200&quality=90`

若无图片: 显示人名首字符作为占位。

### 4.8 相似推荐区域

在页面底部添加:

```
┌─────────────────────────────────────────────────┐
│  相似推荐                          [更多 →]      │
│                                                  │
│  [海报] [海报] [海报] [海报] [海报] →            │
└─────────────────────────────────────────────────┘
```

复用现有 `MediaRow` 组件:
```swift
if !similarItems.isEmpty {
    MediaRow(
        title: "相似推荐",
        items: similarItems,
        serverURL: serverManager.currentServer?.url ?? "",
        onSelect: { item in
            // 导航到该 item 的详情页
            selectedDestination = .detail(item)
        }
    )
}
```

需要给 `MediaDetailView` 也添加 `selectedDestination` 状态和 `navigationDestination` modifier（当前详情页没有这个）。

### 4.9 页面整体布局顺序

```
1. 背景图 + 渐变遮罩
2. 标题 + Tagline
3. 类型标签 + 年份 + 分级徽章 + 时长 + 评分
4. 播放 / 收藏 / 已看 按钮组
5. 简介
6. 选季 / 选集（电视剧）
7. 演职人员
8. 相似推荐
```

---

## Phase 5: 播放器改进

**目标**: 添加音轨选择 UI，并根据画质设置选择直连或转码流。

**修改文件**:
- `PandaPlay/ViewModels/PlayerViewModel.swift`
- `PandaPlay/Views/Player/PlayerView.swift`

### 5.1 音轨数据模型

**文件**: `PlayerViewModel.swift`

在 `SubtitleTrack` 旁新增:

```swift
struct AudioTrack: Identifiable, Equatable {
    let id: Int
    let name: String
    let language: String?

    var displayName: String {
        if let lang = language, !lang.isEmpty { return lang }
        return "音轨 \(id + 1)"
    }
}
```

### 5.2 PlayerViewModel 音轨管理

新增 Published 属性:

```swift
@Published var audioTracks: [AudioTrack] = []
@Published var currentAudioIndex: Int = 0
```

新增方法:

```swift
private func loadAudioTracks() {
    guard let player = mediaPlayer else { return }
    let count = Int(player.numberOfAudioTracks)
    var tracks: [AudioTrack] = []
    for i in 0..<count {
        tracks.append(AudioTrack(id: i, name: "音轨 \(i + 1)", language: nil))
    }
    audioTracks = tracks
    if let first = tracks.first { currentAudioIndex = first.id }
}

func setAudioTrack(index: Int) {
    guard let player = mediaPlayer else { return }
    player.currentAudioTrackIndex = Int32(index)
    currentAudioIndex = index
}
```

在 `loadPlayer()` 的延迟加载块中（第 104 行），同时调用:
```swift
DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
    self.loadSubtitleTracks()
    self.loadAudioTracks()  // 新增
}
```

### 5.3 PlayerView 音轨选择 UI

**文件**: `PlayerView.swift`

新增状态: `@State private var showAudioMenu = false`

在控制栏的 HStack 中（第 351 行），字幕按钮（第 368 行）之前添加音轨按钮:

```swift
// Audio track button
Button(action: { showAudioMenu.toggle() }) {
    ZStack(alignment: .topLeading) {
        Image(systemName: "speaker.wave.2")
            .font(DeviceType.current == .iPhone ? .title2 : .system(size: 48))
            .foregroundColor(.white)
            .frame(width: DeviceType.current == .iPhone ? 44 : 80,
                   height: DeviceType.current == .iPhone ? 44 : 80)

        if viewModel.audioTracks.count > 1 {
            Circle()
                .fill(Color.orange)
                .frame(width: DeviceType.current == .iPhone ? 8 : 12,
                       height: DeviceType.current == .iPhone ? 8 : 12)
                .offset(x: DeviceType.current == .iPhone ? -8 : -12,
                        y: DeviceType.current == .iPhone ? -4 : -6)
        }
    }
}
.confirmationDialog("选择音轨", isPresented: $showAudioMenu, titleVisibility: .visible) {
    ForEach(viewModel.audioTracks) { track in
        Button(track.displayName == viewModel.audioTracks[safe: viewModel.currentAudioIndex]?.displayName ?? "" ? "\(track.displayName) ✓" : track.displayName) {
            viewModel.setAudioTrack(index: track.id)
        }
    }
}
```

### 5.4 画质设置联动

**文件**: `PlayerViewModel.swift` 第 58-78 行的 `loadPlayer()` 方法

当前代码总是使用 `getStreamURL(..., isStatic: true)` 进行直连播放。改为根据画质设置选择:

```swift
import Foundation // UserDefaultsManager 已在项目中

let quality = UserDefaultsManager.shared.videoQuality
let streamURL: URL?

switch quality {
case .auto, .max:
    // 直连播放，不转码
    streamURL = client?.getStreamURL(itemId: mediaItem.id, userId: userId, isStatic: true)
case .high, .medium, .low:
    // 使用 HLS 转码流
    streamURL = client?.getMasterM3U8URL(itemId: mediaItem.id, userId: userId)
}
```

**文件**: `EmbyClient.swift` 第 489-509 行的 `getMasterM3U8URL()`

修改为接受 `maxBitrate` 参数:

```swift
func getMasterM3U8URL(itemId: String, userId: String, maxBitrate: Int? = nil) -> URL? {
    // ...
    var queryItems = [/* 现有 items */]
    if let maxBitrate {
        queryItems.append(URLQueryItem(name: "MaxStreamingBitrate", value: String(maxBitrate)))
    }
    // ...
}
```

各画质对应码率:
| 画质 | MaxStreamingBitrate |
|------|-------------------|
| high | 12000000 |
| medium | 4000000 |
| low | 1500000 |

---

## Phase 6: 设置与库浏览

**修改文件**: `PandaPlay/Views/Settings/SettingsView.swift`

**新建文件**: `PandaPlay/Views/Media/LibraryBrowseView.swift`

### 6.1 SettingsView 扩展

**当前内容**: 只有"服务器管理"和"关于"两个 Section。

**新增 Section**:

#### 播放设置
```
┌────────────────────────────┐
│ 播放                        │
│                            │
│ 视频质量          [自动 ▾]  │
│                            │
│ 说明: 选择"自动"将优先直连   │
│ 播放，不转码                │
└────────────────────────────┘
```

```swift
Section {
    Picker("视频质量", selection: Binding(
        get: { UserDefaultsManager.shared.videoQuality },
        set: { UserDefaultsManager.shared.videoQuality = $0 }
    )) {
        ForEach(VideoQuality.allCases, id: \.rawValue) { quality in
            Text(quality.displayName).tag(quality)
        }
    }
} header: {
    Text("播放")
}
```

#### 关于（增强版）
```
┌────────────────────────────┐
│ 关于                        │
│                            │
│ PandaPlay           [Logo] │
│ 版本              1.0.0    │
│ ─────────────────────────  │
│ 服务器                       │
│ 服务器名称        MyEmby    │
│ 版本             4.8.0.0   │
│ 系统             Linux      │
│ ─────────────────────────  │
│ 当前用户                     │
│ 用户名           admin     │
└────────────────────────────┘
```

需要新增 `@State private var serverInfo: ServerInfo?` 和 `@State private var systemInfo: ServerInfo?`（认证后的系统信息）。

在 `.task` 中调用:
```swift
.task {
    if let serverURL = serverManager.currentServer?.url {
        let client = EmbyClient(serverURL: serverURL)
        serverInfo = (try? await client.getServerInfo())
    }
}
```

### 6.2 LibraryBrowseView

**新建文件**: `PandaPlay/Views/Media/LibraryBrowseView.swift`

按 ParentId 浏览媒体库目录结构，复用 `MoreMediaListViewModel` 的分页模式。

#### 数据模型

```swift
@MainActor
class LibraryBrowseViewModel: ObservableObject {
    @Published var items: [MediaItem] = []
    @Published var isLoadingInitial: Bool = false
    @Published var isLoadingMore: Bool = false
    @Published var errorMessage: String?
    @Published var currentLibrary: MediaItem?

    private let pageSize: Int = 30
    private var serverURL: String = ""
    private var userId: String = ""
    private var accessToken: String = ""
    private var currentParentId: String = ""
    private var currentStartIndex: Int = 0
    private var hasMore: Bool = true

    func load(library: MediaItem, serverURL: String, userId: String, accessToken: String) async { ... }
    func navigateInto(folder: MediaItem) async { ... }
    func loadMoreIfNeeded(currentItem: MediaItem) { ... }
    private func loadNextPage() async { ... }
}
```

#### 页面结构

```swift
struct LibraryBrowseView: View {
    let library: MediaItem
    @StateObject private var viewModel = LibraryBrowseViewModel()
    @State private var selectedItem: MediaItem?
    @EnvironmentObject var serverManager: ServerManager
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        ScrollView {
            LazyVGrid(columns: /* 复用 MoreMediaListView 的 columns */) {
                ForEach(viewModel.items) { item in
                    Button { handleItemTap(item) } label: {
                        if item.type == "CollectionFolder" || item.type == "Folder" {
                            // 显示文件夹样式卡片
                            FolderCard(item: item, serverURL: ...)
                        } else {
                            MediaPoster(item: item, serverURL: ...)
                        }
                    }
                    .onAppear { viewModel.loadMoreIfNeeded(currentItem: item) }
                }
            }
        }
        .navigationTitle(library.name ?? "媒体库")
        .navigationDestination(item: $selectedItem) { item in
            if item.type == "Movie" {
                PlayerView(mediaItem: item)
            } else {
                MediaDetailView(mediaItem: item)
            }
        }
        .task { await viewModel.load(...) }
    }
}
```

#### API 调用

核心请求:
```
GET emby/Users/{userId}/Items?ParentId={libraryId}&Recursive=false&Limit=30&StartIndex={startIndex}&Fields=Overview,Genres,CommunityRating,ProductionYear,RunTimeTicks,DateCreated&SortBy=SortName&SortOrder=Ascending
```

`Recursive=false` 保留文件夹结构，用户可以点击文件夹进入子目录。

点击文件夹时调用 `navigateInto(folder:)`，更新 `currentParentId` 并重新加载。

#### 导航层级支持

支持面包屑导航显示当前位置:
```
电影 → 科幻 → ...
```

用 `NavigationStack` 的自然导航栈实现，每次进入子文件夹 push 一个新的 `LibraryBrowseView`。

---

## 新增文件清单

| 文件路径 | 用途 |
|---------|------|
| `PandaPlay/Views/Components/LibraryTile.swift` | 首页媒体库图标卡片 |
| `PandaPlay/Views/Components/PersonCard.swift` | 演员卡片组件 |
| `PandaPlay/Views/Media/LibraryBrowseView.swift` | 媒体库浏览页面 |

## Xcode 项目配置

以上三个新文件需要添加到 Xcode 项目的 `PandaPlay` target 中（iOS 和 tvOS 两个 target 都要添加）。

**操作步骤**:
1. 在 Xcode 中右键 `Views/Components/` → Add Files to "PandaPlay"
2. 取消勾选 "Copy items if needed"（文件已在正确位置）
3. 确保 PandaPlay (iOS) 和 PandaPlay (tvOS) 两个 target 都勾选
4. 对 `Views/Media/LibraryBrowseView.swift` 重复以上步骤

---

## 实施顺序与依赖关系

```
Phase 1 (模型)
  ├── Phase 2 (API 端点) ← 依赖 Phase 1 的新模型字段
  │     ├── Phase 3 (首页) ← 依赖 Phase 2 的 getNextUp/getUserViews
  │     └── Phase 4 (详情页) ← 依赖 Phase 2 的 setFavorite/getSimilarItems
  ├── Phase 5 (播放器) ← 仅依赖 Phase 1 的模型，可并行
  └── Phase 6 (设置/库) ← 依赖 Phase 2 的 API
```

建议实施顺序: 1 → 2 → 3+4+5 并行 → 6

---

## 验证清单

- [ ] iOS target 编译通过
- [ ] tvOS target 编译通过
- [ ] 首页"下一集"行正确显示数据
- [ ] 首页"最新添加"行正确显示数据
- [ ] 首页"媒体库"行正确显示库列表
- [ ] 点击媒体库进入 LibraryBrowseView，可翻页
- [ ] LibraryBrowseView 中点击文件夹可进入子目录
- [ ] 详情页显示 tagline（如有）
- [ ] 详情页显示官方分级徽章（如有）
- [ ] 收藏按钮点击后状态切换，刷新后保持
- [ ] 已看按钮点击后状态切换
- [ ] 详情页显示演员列表（如有）
- [ ] 详情页显示相似推荐（如有）
- [ ] 剧集选择后简介正确显示
- [ ] 播放器音轨选择菜单正常弹出
- [ ] 切换音轨后播放正常
- [ ] 设置页视频质量选项可保存
- [ ] 画质设为"中"/"低"时播放使用转码流
- [ ] 画质设为"自动"/"最高"时播放使用直连
- [ ] 设置页"关于"显示服务器信息
