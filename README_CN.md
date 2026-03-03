# PandaPlay - Emby/Jellyfin 播放器

一款专为 Emby/Jellyfin 媒体服务器设计的高级播放器，支持多平台。

## 功能特性

- **多平台支持**
  - iOS（iPhone 和 iPad）原生触摸界面
  - tvOS 支持 Siri 遥控器
  - 针对不同设备类型优化的响应式设计

- **服务器连接**
  - Emby/Jellyfin 服务器认证
  - 多服务器管理，安全存储（钥匙串）

- **媒体库浏览**
  - 浏览电影和电视剧
  - 查看最近添加和继续播放项目
  - 季和剧集导航

- **视频播放**
  - **广泛格式支持**（通过 MobileVLCKit，支持 MKV、MP4、AVI 等）
  - 直接串流（无需服务器转码）
  - 硬件加速解码
  - **字幕轨道选择，支持开关切换**
  - 多音轨支持
  - **完整的播放器控制**（播放/暂停、快进、进度条）
  - 4 秒无操作后自动隐藏控制界面

- **用户体验**
  - 原生 iOS/tvOS 界面
  - tvOS 基于焦点的导航
  - 平滑的图片加载，带模糊占位符
  - 使用 SecureField 的安全密码输入

## 系统要求

- macOS 14.0+
- Xcode 15.0+
- iOS 15.0+ / tvOS 15.0+
- CocoaPods

## 安装

### 从源码构建

1. 克隆仓库
2. 安装 CocoaPods 依赖：
   ```bash
   cd PandaPlay
   pod install
   ```
3. 在 Xcode 中打开 `PandaPlay.xcworkspace`（使用 .xcworkspace，不是 .xcodeproj）
4. 在项目设置中选择开发团队
5. 在 iOS 模拟器、tvOS 模拟器或真机上构建运行

### 依赖项

项目使用 CocoaPods 管理依赖：

- **MobileVLCKit** (~> 3.3.0) - 基于 VLC FFmpeg 解码引擎的媒体播放器
  - 支持 MKV、MP4、AVI、MOV 等多种格式
  - iOS/tvOS 硬件加速解码
  - 内置字幕和音轨支持

运行 `pod install` 时会自动解析这些依赖。

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
│   ├── Player/                # 集成 MobileVLCKit 的视频播放器
│   ├── Settings/              # 设置管理
│   └── Components/            # 可复用 UI 组件
├── ViewModels/                 # 视图模型
│   ├── ServerManager.swift    # 服务器配置
│   ├── AuthManager.swift      # 认证状态
│   ├── HomeViewModel.swift    # 媒体库逻辑
│   └── PlayerViewModel.swift  # 播放器逻辑（含字幕/轨道管理）
├── Models/                     # 数据模型
│   └── AppError.swift         # 错误类型
├── Services/                   # 服务层
│   ├── EmbyClient.swift       # Emby/Jellyfin API 客户端
│   ├── ImageLoader.swift      # 异步图片加载
│   ├── KeychainManager.swift  # 安全存储
│   ├── PlaybackProgressManager.swift
│   └── UserDefaultsManager.swift
├── Utils/                      # 工具函数
│   └── DeviceType.swift       # 设备检测和响应式布局辅助
└── Assets.xcassets            # 图片和资源
```

## 平台特定功能

### iOS（iPhone/iPad）
- 触摸控制
- 滑动手势导航
- 支持紧凑和常规尺寸类
- 带自动隐藏的屏幕播放器控制

### tvOS
- Siri 遥控器集成
- 基于焦点的导航
- 为遥控器优化的简化控制方案

## 已知问题

- 选择剧集时不显示剧集概览（需要调用 getItem API）

## 许可证

本项目使用 MobileVLCKit，采用 LGPL v2.1（或更高版本）许可证。如果您 fork 或修改本项目，请确保遵守 MobileVLCKit 的许可条款。

## 贡献

欢迎贡献！欢迎提交问题和拉取请求。
