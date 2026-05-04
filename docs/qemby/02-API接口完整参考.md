# API 接口完整参考

## 1. 认证头格式

所有认证请求都需要携带 `X-Emby-Authorization` 头:

```
X-Emby-Authorization: MediaBrowser Client="qEmby", Device="Desktop", DeviceId="<uuid>", Version="0.1", Token="<accessToken>"
```

- `DeviceId`: UUID 格式，首次登录时生成并持久化
- `Token`: 登录成功后从 `/Users/AuthenticateByName` 获取的 `AccessToken`

## 2. 服务器类型

项目同时支持 **Emby** 和 **Jellyfin**，通过 `/System/Info/Public` 的 `ProductName` 自动检测。

| 差异项 | Emby | Jellyfin |
|--------|------|----------|
| WebSocket 路径 | `/embywebsocket` | `/socket` |
| 虚拟文件夹查询 | `/Library/VirtualFolders/Query` | `/Library/VirtualFolders` |
| 删除虚拟文件夹 | `POST /Library/VirtualFolders/Delete` | `DELETE /Library/VirtualFolders` |
| 删除媒体路径 | `POST /Library/VirtualFolders/Paths/Delete` | `DELETE /Library/VirtualFolders/Paths` |
| 修改密码 | `POST` 表单格式 | `POST` JSON 格式 |

## 3. 认证接口

### 3.1 获取服务器公开信息 (无需认证)
```
GET /System/Info/Public
```
**调用时机**: 登录第一步，检测服务器类型 (Emby vs Jellyfin)
**返回**: `{ ProductName, ... }`

### 3.2 用户认证
```
POST /Users/AuthenticateByName
Content-Type: application/json

Body: { "Username": "xxx", "Pw": "xxx" }
```
**调用时机**: 用户输入用户名密码后点击登录
**返回**:
```json
{
  "AccessToken": "xxx",
  "User": {
    "Id": "xxx",
    "Name": "xxx",
    "Policy": {
      "IsAdministrator": true,
      "EnableMediaPlayback": true,
      "EnableContentDownloading": true
    }
  },
  "ServerId": "xxx"
}
```
**后续操作**: 提取 `AccessToken`、`User.Id`、`User.Name`、`User.Policy.IsAdministrator`，尝试获取服务器图标

### 3.3 获取系统信息 (需认证)
```
GET /System/Info
```
**调用时机**: 恢复会话时验证服务器可达性
**返回**: `SystemInfo` 结构

### 3.4 获取用户详情
```
GET /Users/{userId}
```
**调用时机**: 恢复会话时刷新用户策略 (管理员状态、下载权限)
**返回**: 用户信息含 `Policy`

## 4. 媒体浏览接口

### 4.1 获取用户媒体库视图
```
GET /Users/{userId}/Views
```
**调用时机**: 进入首页加载侧边栏媒体库列表
**参数**: 无
**返回**: `{ Items: [MediaItem, ...], TotalRecordCount }`
**映射**: `MediaService::getUserViews()`

### 4.2 获取媒体库项目 (分页)
```
GET /Users/{userId}/Items?ParentId={parentId}&SortBy={sortBy}&SortOrder={sortOrder}&Filters={filters}&IncludeItemTypes={types}&StartIndex={startIndex}&Limit={limit}&Recursive={recursive}&IncludeChildCount={includeChildCount}
```
**调用时机**: 浏览媒体库内容、搜索、按人物/分类过滤
**映射**: `MediaService::getLibraryItemsPage()`
**返回**: `{ Items: [MediaItem, ...], TotalRecordCount, StartIndex }`

### 4.3 获取继续观看
```
GET /Users/{userId}/Items/Resume?Limit={limit}&SortBy={sortBy}&SortOrder={sortOrder}
```
**调用时机**: 加载首页 "继续观看" 区域
**映射**: `MediaService::getResumeItems()`
**返回**: `[MediaItem, ...]`

### 4.4 获取最新添加
```
GET /Users/{userId}/Items?IncludeItemTypes=Movie,Series&SortBy=DateCreated&SortOrder=Descending&Limit={limit}
```
**调用时机**: 加载首页 "最新添加" 区域
**映射**: `MediaService::getLatestItems()`
**返回**: `[MediaItem, ...]`

### 4.5 获取推荐
```
GET /Users/{userId}/Items?IncludeItemTypes=Movie,Series&SortBy=Random&SortOrder=Ascending&Limit={limit}
```
**调用时机**: 加载首页 "推荐" 区域
**映射**: `MediaService::getRecommendedMovies()`
**返回**: `[MediaItem, ...]`
**缓存**: 内存+磁盘缓存，可配置缓存时长

### 4.6 搜索媒体
```
GET /Users/{userId}/Items?SearchTerm={searchTerm}&IncludeItemTypes={types}&Limit={limit}
```
**调用时机**: 用户在搜索框输入搜索
**映射**: `MediaService::searchMedia()`
**返回**: `[MediaItem, ...]`

### 4.7 获取媒体详情
```
GET /Users/{userId}/Items/{itemId}?Fields=Overview,BroadcastDate,Genres,Tags,People,Studios,ExternalUrls,MediaSources,ProviderIds,Taglines,RemoteTrailers
```
**调用时机**: 点击媒体卡片进入详情页
**映射**: `MediaService::getItemDetail()`
**返回**: `MediaItem` 完整信息

## 5. 电视剧相关接口

### 5.1 获取季列表
```
GET /Shows/{seriesId}/Seasons
```
**调用时机**: 进入剧集详情页加载季列表
**映射**: `MediaService::getSeasons()`
**返回**: `[MediaItem, ...]` (每项为一个季)

### 5.2 获取集列表
```
GET /Shows/{seriesId}/Episodes?SeasonId={seasonId}&SortBy={sortBy}&SortOrder={sortOrder}
```
**调用时机**: 在详情页切换季或进入季详情页
**映射**: `MediaService::getEpisodes()`
**返回**: `[MediaItem, ...]` (每项为一集)

### 5.3 获取 "下一集"
```
GET /Shows/NextUp?SeriesId={seriesId}
```
**调用时机**: 剧集详情页显示 "下一集"
**映射**: `MediaService::getNextUp()`
**返回**: `[MediaItem, ...]`

## 6. 播放接口

### 6.1 获取播放信息
```
GET /Items/{itemId}/PlaybackInfo
```
**调用时机**: 点击播放按钮，获取媒体源信息 (视频/音频/字幕流)
**映射**: `MediaService::getPlaybackInfo()`
**返回**: `PlaybackInfo { playSessionId, mediaSources: [MediaSourceInfo] }`

### 6.2 获取流媒体 URL (非 API 调用，直接构造)
```
{baseUrl}/Videos/{itemId}/stream?static=true&mediaSourceId={sourceId}&api_key={token}
```
**构造逻辑**: `MediaService::getStreamUrl()`
**特殊处理**: 支持 STRM 文件直接播放 (返回 STRM 文件中的 URL)

### 6.3 报告播放开始
```
POST /Sessions/Playing
Body: { ItemId, MediaSourceId, PositionTicks, CanSeek: true }
```
**调用时机**: 开始播放视频
**映射**: `MediaService::reportPlaybackStart()`
**返回**: `playSessionId`

### 6.4 报告播放进度
```
POST /Sessions/Playing/Progress
Body: { ItemId, MediaSourceId, PositionTicks, IsPaused, PlaySessionId }
```
**调用时机**: 播放中定时 (每10秒) 上报
**映射**: `MediaService::reportPlaybackProgress()`

### 6.5 报告播放停止
```
POST /Sessions/Playing/Stopped
Body: { ItemId, MediaSourceId, PositionTicks, PlaySessionId }
```
**调用时机**: 停止播放、关闭播放器、切换到下一集
**映射**: `MediaService::reportPlaybackStopped()`

## 7. 用户操作接口

### 7.1 切换收藏
```
POST   /Users/{userId}/FavoriteItems/{itemId}   # 添加收藏
DELETE /Users/{userId}/FavoriteItems/{itemId}   # 取消收藏
```
**映射**: `MediaService::toggleFavorite()`
**逻辑**: 根据 `userData.isFavorite` 状态决定调用 POST 还是 DELETE

### 7.2 标记已播放/未播放
```
POST   /Users/{userId}/PlayedItems/{itemId}     # 标记已播放
DELETE /Users/{userId}/PlayedItems/{itemId}      # 标记未播放
```
**映射**: `MediaService::markAsPlayed()`, `markAsUnplayed()`

### 7.3 从继续观看移除
```
POST /Users/{userId}/Items/{itemId}/HideFromResume?Hide=true
```
**映射**: `MediaService::removeFromResume()`

## 8. 收藏接口

### 8.1 获取收藏的电影
```
GET /Users/{userId}/Items?Filters=IsFavorite&IncludeItemTypes=Movie&Limit={limit}
```
**映射**: `MediaService::getFavoriteMovies()`

### 8.2 获取收藏的剧集
```
GET /Users/{userId}/Items?Filters=IsFavorite&IncludeItemTypes=Series
```
**映射**: `MediaService::getFavoriteSeries()`

### 8.3 获取收藏的合集/播放列表/文件夹/人物
```
GET /Users/{userId}/Items?Filters=IsFavorite&IncludeItemTypes=BoxSet|Playlist|CollectionFolder|Person
```
**映射**: `MediaService::getFavoriteCollections/Playlists/Folders/People()`

## 9. 关联内容接口

### 9.1 获取相似推荐
```
GET /Items/{itemId}/Similar?Limit={limit}
```
**映射**: `MediaService::getSimilarItems()`

### 9.2 获取附加部分
```
GET /Videos/{itemId}/AdditionalParts
```
**映射**: `MediaService::getAdditionalParts()`

### 9.3 获取所在合集
```
GET /Users/{userId}/Items?IncludeItemTypes=BoxSet&PersonIds={itemId}
```
**映射**: `MediaService::getItemCollections()`

### 9.4 获取合集内容
```
GET /Users/{userId}/Items?ParentId={collectionId}
```
**映射**: `MediaService::getCollectionItems()`

### 9.5 按人物获取作品
```
GET /Users/{userId}/Items?PersonIds={personId}
```
**映射**: `MediaService::getItemsByPerson()`

### 9.6 按分类过滤
```
GET /Users/{userId}/Items?Genres={genre}|Tags={tag}|Studios={studio}
```
**映射**: `MediaService::getItemsByFilter()`

### 9.7 获取项目集合
```
GET /Users/{userId}/Items?IncludeItemTypes=Playlist,BoxSet&ListItemIds={itemId}
```
**映射**: `MediaService::getItemCollections()`

## 10. 图片接口

图片 URL 直接构造，不走 API 调用:
```
{baseUrl}/Items/{itemId}/Images/{imageType}?maxWidth={maxWidth}&tag={imageTag}&quality={quality}
```

**imageType**: `Primary` (海报), `Backdrop` (背景), `Thumb` (缩略图), `Logo` (标志)
**图片获取逻辑** (MediaService):
1. 先检查内存缓存 (`QPixmapCache`)
2. 再检查磁盘缓存 (`QNetworkDiskCache`, 500MB)
3. 最后网络请求，并存入缓存
4. 支持 `invalidateImageCache()` 使缓存失效
5. 支持配置图片质量 (`ConfigKeys::ImageQuality`)

## 11. 管理员接口

### 11.1 系统管理

| 方法 | 端点 | 说明 |
|------|------|------|
| GET | `/System/Info` | 获取系统信息 |
| POST | `/System/Restart` | 重启服务器 |
| POST | `/System/Shutdown` | 关闭服务器 |
| GET | `/System/Logs` | 列出日志文件 |
| GET | `/System/Logs/{logName}` | 获取日志内容 (文本) |
| GET | `/System/ActivityLog/Entries?Limit={limit}` | 获取活动日志 |

### 11.2 会话管理

| 方法 | 端点 | 说明 |
|------|------|------|
| GET | `/Sessions` | 获取活跃会话列表 |

### 11.3 用户管理

| 方法 | 端点 | 说明 |
|------|------|------|
| GET | `/Users` | 列出所有用户 |
| GET | `/Users/{userId}` | 获取用户详情 |
| POST | `/Users/New` | 创建用户 |
| POST | `/Users/{userId}` | 更新用户 |
| DELETE | `/Users/{userId}` | 删除用户 |
| POST | `/Users/{userId}/Policy` | 更新用户策略 |
| POST | `/Users/{userId}/Configuration` | 更新用户配置 |
| POST | `/Users/{userId}/Password` | 更新密码 |
| POST | `/Users/{userId}/EasyPassword` | 更新简易密码 |

### 11.4 媒体库管理

| 方法 | 端点 | 说明 |
|------|------|------|
| GET | `/Library/VirtualFolders` | 获取虚拟文件夹 (Jellyfin) |
| GET | `/Library/VirtualFolders/Query` | 获取虚拟文件夹 (Emby) |
| POST | `/Library/VirtualFolders` | 添加虚拟文件夹 |
| POST/DELETE | `/Library/VirtualFolders/Delete` 或 DELETE | 删除虚拟文件夹 |
| POST | `/Library/VirtualFolders/Name` | 重命名虚拟文件夹 |
| POST | `/Library/VirtualFolders/Paths` | 添加媒体路径 |
| POST/DELETE | `/Library/VirtualFolders/Paths/Delete` 或 DELETE | 删除媒体路径 |
| POST | `/Library/VirtualFolders/LibraryOptions` | 更新媒体库选项 |
| POST | `/Library/Refresh` | 刷新媒体库 |

### 11.5 播放列表 & 合集管理

| 方法 | 端点 | 说明 |
|------|------|------|
| POST | `/Playlists` | 创建播放列表 |
| GET | `/Playlists/{playlistId}/Items` | 获取播放列表内容 |
| POST | `/Playlists/{playlistId}/Items?Ids=...` | 添加到播放列表 |
| DELETE | `/Playlists/{playlistId}/Items?EntryIds=...` | 从播放列表移除 |
| POST | `/Collections?Name=...` | 创建合集 |
| POST | `/Collections/{id}/Items?Ids=...` | 添加到合集 |
| DELETE | `/Collections/{id}/Items?Ids=...` | 从合集移除 |

### 11.6 元数据/图片管理

| 方法 | 端点 | 说明 |
|------|------|------|
| POST | `/Items/RemoteSearch/{type}` | 搜索远程元数据 |
| POST | `/Items/RemoteSearch/Apply/{itemId}` | 应用远程搜索结果 |
| GET | `/Users/{userId}/Items/{itemId}` | 获取项目元数据 |
| POST | `/Items/{itemId}` | 更新项目元数据 |
| POST | `/Items/{itemId}/Refresh` | 刷新项目元数据 |
| GET | `/Items/{itemId}/Images` | 列出项目图片 |
| POST | `/Items/{itemId}/Images/{imageType}` | 上传图片 |
| DELETE | `/Items/{itemId}/Images/{imageType}` | 删除图片 |
| DELETE | `/Items/{itemId}` | 删除项目 |

### 11.7 转码配置

| 方法 | 端点 | 说明 |
|------|------|------|
| GET | `/System/Configuration/encoding` | 获取编码配置 |
| POST | `/System/Configuration/encoding` | 更新编码配置 |
| GET | `/Encoding/CodecInformation/Video` | 获取编解码器信息 |
| GET | `/Encoding/CodecConfiguration/Defaults` | 获取默认编解码配置 |
| GET | `/Encoding/CodecParameters` | 获取编解码参数 |
| POST | `/Encoding/CodecParameters` | 更新编解码参数 |

### 11.8 定时任务

| 方法 | 端点 | 说明 |
|------|------|------|
| GET | `/ScheduledTasks` | 列出所有定时任务 |
| GET | `/ScheduledTasks/{taskId}` | 获取任务详情 |
| POST | `/ScheduledTasks/Running/{taskId}` | 运行任务 |
| DELETE | `/ScheduledTasks/Running/{taskId}` | 停止任务 |
| POST | `/ScheduledTasks/{taskId}/Triggers` | 更新任务触发器 |

### 11.9 播放列表管理

| 方法 | 端点 | 说明 |
|------|------|------|
| POST | `/Playlists` | 创建播放列表 |
| GET | `/Playlists/{playlistId}/Items` | 获取播放列表内容 |
| POST | `/Playlists/{playlistId}/Items?Ids=...` | 添加到播放列表 |
| DELETE | `/Playlists/{playlistId}/Items?EntryIds=...` | 从播放列表移除 |

### 11.10 合集管理

| 方法 | 端点 | 说明 |
|------|------|------|
| GET | `/Users/{userId}/Items?IncludeItemTypes=BoxSet` | 列出合集 |
| POST | `/Collections?Name=...` | 创建合集 |
| POST | `/Collections/{id}/Items?Ids=...` | 添加到合集 |
| DELETE | `/Collections/{id}/Items?Ids=...` | 从合集移除 |

### 11.11 元数据/图片管理

| 方法 | 端点 | 说明 |
|------|------|------|
| POST | `/Items/RemoteSearch/{type}` | 搜索远程元数据 |
| POST | `/Items/RemoteSearch/Apply/{itemId}` | 应用远程搜索结果 |
| GET | `/Users/{userId}/Items/{itemId}` | 获取项目元数据 |
| POST | `/Items/{itemId}` | 更新项目元数据 |
| POST | `/Items/{itemId}/Refresh` | 刷新项目元数据 |
| GET | `/Items/{itemId}/Images` | 列出项目图片 |
| POST | `/Items/{itemId}/Images/{imageType}` | 上传图片 |
| DELETE | `/Items/{itemId}/Images/{imageType}` | 删除图片 |
| DELETE | `/Items/{itemId}` | 删除项目 |

### 11.12 环境与本地化

| 方法 | 端点 | 说明 |
|------|------|------|
| GET | `/Environment/Drives` | 获取服务器驱动器 |
| GET | `/Environment/DirectoryContents` | 获取目录内容 |
| GET | `/Localization/ParentalRatings` | 获取家长评级 |
| GET | `/Localization/cultures` | 获取文化列表 |
| GET | `/Localization/countries` | 获取国家列表 |
| GET | `/Channels` | 获取频道 |
| GET | `/Devices` | 获取设备 |
| GET | `/Auth/Providers` | 获取认证提供商 |
| GET | `/Features` | 获取功能列表 |

## 12. WebSocket 接口

### 连接地址
- Emby: `ws://{host}/embywebsocket?api_key={token}&deviceId={deviceId}`
- Jellyfin: `ws://{host}/socket?api_key={token}&deviceId={deviceId}`

### 心跳
每 30 秒发送: `{ "MessageType": "KeepAlive" }`

### 自动重连
- 指数退避策略
- 最大重试 10 次
- 最长等待 30 秒

### 处理的消息类型

| MessageType | 说明 |
|-------------|------|
| `KeepAlive` | 心跳响应 |
| `RefreshProgress` | 刷新进度 |
| `ScheduledTasksInfo` | 定时任务信息 |
| `ScheduledTasksInfoChanged` | 定时任务变更 |
| `ScheduledTaskEnded` | 定时任务完成 |
| `LibraryChanged` | 媒体库变更 |
| `Sessions` | 会话信息更新 |
| `UserDataChanged` | 用户数据变更 |

## 13. 弹幕 API (DandanPlay 外部服务)

| 方法 | 端点 | 说明 |
|------|------|------|
| POST | `/api/v2/match` | 按文件名匹配媒体 |
| GET | `/api/v2/search/episodes?keyword=...` | 搜索剧集 |
| GET | `/api/v2/search/anime?keyword=...` | 搜索动漫 (备选) |
| GET | `/api/v2/comment/{episodeId}` | 获取弹幕评论 |

## 14. 网络层架构

```
View / BaseView
    │
    ▼
QEmbyCore (门面)
    │
    ▼
Service (AuthService / MediaService / AdminService / DanmakuService)
    │
    ▼
ApiClient (添加认证头, 拼接 BaseURL)
    │
    ▼
NetworkManager (底层 HTTP: GET/POST/DELETE)
    │
    ▼
QNetworkAccessManager → HTTP/HTTPS
```

### NetworkManager 提供的方法

| 方法 | 返回类型 | 说明 |
|------|----------|------|
| `get(url, headers, options)` | `QCoro::Task<QJsonObject>` | JSON GET |
| `getText(url, headers, options)` | `QCoro::Task<QString>` | 文本 GET |
| `getBytes(url, headers, options)` | `QCoro::Task<QByteArray>` | 字节 GET |
| `post(url, headers, payload, options)` | `QCoro::Task<QJsonObject>` | JSON POST |
| `postArray(url, headers, payload, options)` | `QCoro::Task<QJsonObject>` | JSON数组 POST |
| `postBytes(url, headers, payload, contentType)` | `QCoro::Task<QJsonObject>` | 原始字节 POST |
| `postForm(url, headers, formData, options)` | `QCoro::Task<QJsonObject>` | 表单 POST |
| `deleteResource(url, headers, options)` | `QCoro::Task<QJsonObject>` | DELETE |

### 错误处理
- 传输层: 检查 `reply->error()`，失败时记录 HTTP 状态码、Qt 错误码、错误字符串、SSL 错误、前 500 字节响应体，抛出 `std::runtime_error`
- 字符编码: 优先 UTF-8，失败时尝试 GB18030/GBK 解码
- SSL: 支持忽略 SSL 错误 (自签名证书)，通过 `ServerProfile::ignoreSslVerification` 配置
