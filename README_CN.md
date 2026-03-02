# PandaPlay - Emby/Jellyfin Apple TV 播放器

一款专为 Emby/Jellyfin 媒体服务器设计的高级 tvOS 播放器，支持 MKV 格式。

## 功能特性

- **服务器连接**
  - Emby/Jellyfin 服务器认证
  - 多服务器管理，安全存储（钥匙串）

- **媒体库浏览**
  - 浏览电影和电视剧
  - 查看最近添加和继续播放项目
  - 季和剧集导航

- **视频播放**
  - **MKV 格式支持**（通过 KSPlayer）
  - 直接串流（无需服务器转码）
  - 硬件加速解码
  - 字幕和音轨支持

- **用户体验**
  - 原生 tvOS 界面，支持 Siri 遥控器
  - 基于焦点的导航
  - 平滑的图片加载，带模糊占位符

## 系统要求

- macOS 14.0+
- Xcode 15.0+
- tvOS 15.0+
- Apple TV HD (第 4 代) 或 Apple TV 4K

## 安装

### 从源码构建

1. 克隆仓库
2. 在 Xcode 中打开 `PandaPlay.xcodeproj`
3. 在项目设置中选择开发团队
4. 在 tvOS 模拟器或 Apple TV 上构建运行

### 依赖项

项目使用 Swift Package Manager 管理依赖：

- **KSPlayer** - 支持 MKV 等格式的媒体播放器（基于 FFmpeg）
- **FFmpegKit** - KSPlayer 所需的媒体解码库

这些依赖会在构建时自动解析。

## 配置

首次启动时，应用会引导您完成：

1. **服务器设置**：输入您的 Emby/Jellyfin 服务器地址
2. **身份验证**：使用用户名和密码登录
3. **媒体访问**：浏览您的媒体库

## 项目结构

```
PandaPlay/
├── App/                        # 应用入口
│   ├── PandaPlayApp.swift
│   └── ContentView.swift
├── Views/                      # UI 视图
│   ├── Onboarding/            # 设置和登录页面
│   ├── Media/                 # 媒体浏览（主页、详情）
│   ├── Player/                # 集成 KSPlayer 的视频播放器
│   ├── Settings/              # 设置管理
│   └── Components/            # 可复用 UI 组件
├── ViewModels/                 # 视图模型
│   ├── ServerManager.swift    # 服务器配置
│   ├── AuthManager.swift      # 认证状态
│   ├── HomeViewModel.swift    # 媒体库逻辑
│   └── PlayerViewModel.swift  # 播放器逻辑
├── Models/                     # 数据模型
│   └── AppError.swift         # 错误类型
├── Services/                   # 服务层
│   ├── EmbyClient.swift       # Emby/Jellyfin API 客户端
│   ├── ImageLoader.swift      # 异步图片加载
│   ├── KeychainManager.swift  # 安全存储
│   ├── PlaybackProgressManager.swift
│   └── UserDefaultsManager.swift
└── Assets.xcassets            # 图片和资源
```

## 已知问题

- 选择剧集时不显示剧集概览（需要调用 getItem API）

## 许可证

本项目使用 KSPlayer，采用 GPL 许可证。如果您 fork 或修改本项目，请确保遵守 KSPlayer 的许可条款。

## 贡献

欢迎贡献！欢迎提交问题和拉取请求。
