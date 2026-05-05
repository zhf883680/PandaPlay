# PandaPlay tvOS 整体改造计划

> 创建日期: 2026-05-05
> 完成日期: 2026-05-05
> 基于 qemby 参考文档，全面改造 tvOS 端体验

## 进度总览

| Phase | 描述 | 状态 |
|-------|------|------|
| Phase 1 | 设置基础设施扩展 | DONE |
| Phase 2 | tvOS TabView 导航 | DONE |
| Phase 3 | 首页 Hero 区域 | DONE |
| Phase 4 | 详情页增强 (tvOS) | DONE |
| Phase 5 | 弹幕系统 | DONE |
| Phase 6 | 播放器改进 (tvOS) | DONE |
| Phase 7 | 多服务器改进 (tvOS) | DONE |

---

## Phase 1: 设置基础设施扩展 — DONE

**修改文件**:
- `PandaPlay/Services/UserDefaultsManager.swift` — 新增 14 个设置项 (seekStep + 弹幕设置)
- `PandaPlay/Views/Settings/SettingsView.swift` — 重构为多 Section 布局 (播放/弹幕/服务器/关于)，tvOS 独立布局

## Phase 2: tvOS TabView 导航 — DONE

**新建文件**:
- `PandaPlay/Views/TV/TVMainTabView.swift` — 4 Tab (首页/媒体库/搜索/设置) + TVLibrariesView

**修改文件**:
- `PandaPlay/App/ContentView.swift` — `#if os(tvOS)` 显示 TVMainTabView
- `PandaPlay/Views/Media/HomeView.swift` — tvOS 去掉 NavigationStack，toolbar 仅 iOS

## Phase 3: 首页 Hero 区域 — DONE

**新建文件**:
- `PandaPlay/Views/TV/TVHeroSection.swift` — 全宽 Backdrop 轮播 + 标题/Tagline/元数据/播放按钮

**修改文件**:
- `PandaPlay/Views/Media/HomeView.swift` — tvOS contentRows 顶部插入 TVHeroSection

## Phase 4: 详情页增强 (tvOS) — DONE

**修改文件**: `PandaPlay/Views/Media/MediaDetailView.swift`
- 背景图高度 450→550pt (tvOS)
- 添加"媒体信息"区域：制片厂、标签、外部链接 (tvOS)

## Phase 5: 弹幕系统 — DONE

**弹幕 API**: `https://danmu.940120.xyz:120`

**新建文件**:
- `PandaPlay/Services/DandanPlayClient.swift` — API 客户端 (match/search/fetchComments)
- `PandaPlay/ViewModels/DanmakuService.swift` — 匹配/缓存/手动匹配逻辑
- `PandaPlay/Views/Player/DanmakuOverlayView.swift` — Canvas 弹幕渲染 (滚动/顶部/底部)
- `PandaPlay/Views/Player/DanmakuMatchView.swift` — 手动匹配弹窗

**修改文件**:
- `PlayerView.swift` — 叠加 DanmakuOverlayView，弹幕开关按钮
- `SettingsView.swift` — 弹幕设置 Section

## Phase 6: 播放器改进 (tvOS) — DONE

**修改文件**:
- `PlayerView.swift` — 进度条 `.onMoveCommand` 拖动、倍速按钮(0.5x-2x)、弹幕开关、快进步长设置
- `PlayerViewModel.swift` — playbackRate 属性、setRate() 方法

## Phase 7: 多服务器改进 (tvOS) — DONE

**修改文件**:
- `ServerManagerView.swift` — tvOS 显式编辑/删除按钮
- `ServerSwitcher.swift` — tvOS ServerListView 添加编辑/删除按钮

---

## 新建文件清单

| 文件 | Phase |
|------|-------|
| `Views/TV/TVMainTabView.swift` | 2 |
| `Views/TV/TVHeroSection.swift` | 3 |
| `Services/DandanPlayClient.swift` | 5 |
| `ViewModels/DanmakuService.swift` | 5 |
| `Views/Player/DanmakuOverlayView.swift` | 5 |
| `Views/Player/DanmakuMatchView.swift` | 5 |

## 修改文件清单

| 文件 | Phases |
|------|--------|
| `Services/UserDefaultsManager.swift` | 1 |
| `Views/Settings/SettingsView.swift` | 1, 5 |
| `App/ContentView.swift` | 2 |
| `Views/Media/HomeView.swift` | 2, 3 |
| `Views/Media/MediaDetailView.swift` | 4 |
| `Views/Player/PlayerView.swift` | 5, 6 |
| `ViewModels/PlayerViewModel.swift` | 6 |
| `Views/Settings/ServerManagerView.swift` | 7 |
| `Views/Components/ServerSwitcher.swift` | 7 |

## 验证方式

- tvOS Simulator 编译运行
- 确认 iOS target 不受影响
- 弹幕需连接 `https://danmu.940120.xyz:120` 测试
