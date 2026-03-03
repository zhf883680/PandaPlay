# 服务器切换和管理功能设计

**日期：** 2026-03-03
**状态：** 已批准

## 概述

为 PandaPlay 应用添加完善的服务器切换和管理功能，支持多 Emby/Jellyfin 服务器配置，提供流畅的用户体验。

## 需求

1. **启动流程优化**
   - 应用启动时自动连接上次使用的服务器
   - 无服务器时引导用户添加
   - 自动使用保存的凭证登录

2. **全局服务器切换器**
   - 左上角显示，支持快速切换
   - iOS 使用 Menu，tvOS 使用焦点导航
   - 显示当前服务器名称

3. **设置页面改进**
   - 完善服务器管理功能（添加、编辑、删除）
   - 提供快捷入口和完整管理界面

## 架构设计

### 组件结构

```
PandaPlayApp
  └── RootView
        └── ContentView
              ├── ServerSetupView (无服务器时)
              ├── LoginView (未认证时)
              └── HomeView (已认证)
                    ├── .toolbar { ServerSwitcher }
                    ├── MediaDetailView
                    │     └── .toolbar { ServerSwitcher }
                    └── SettingsView
                          └── .toolbar { ServerSwitcher }
```

### 新增组件

1. **`ServerSwitcher`** - 服务器切换器组件
2. **`ServerListMenu`** - 服务器列表菜单（iOS）
3. **`ServerListView`** - 服务器列表视图（tvOS）

### 数据流

```
用户点击切换器
    ↓
显示服务器列表
    ↓
用户选择服务器
    ↓
ServerManager.switchServer(serverId)
    ↓
AuthManager.switchToServer(server)
    ↓
┌──────────────────┐
│ Keychain 有凭证?  │
└──────────────────┘
    ↓ 是              ↓ 否
自动登录成功      显示 LoginView
    ↓
更新 UI → HomeView
```

## 实现要点

### 1. ServerManager 扩展

**新增属性：**
- `currentServerId: String?` - 持久化当前选中的服务器ID

**新增方法：**
- `switchServer(_ server: EmbyServer) async throws` - 完整的服务器切换流程
- `loadServers()` 改进 - 恢复上次选中的服务器

### 2. AuthManager 扩展

**新增方法：**
- `switchToServer(server: EmbyServer) async throws` - 切换服务器并认证
- `hasValidCredentials(for serverId: String) -> Bool` - 检查凭证有效性

### 3. UI 组件

**ServerSwitcher：**
- iOS: `.toolbar` + `Menu`
- tvOS: `.toolbar` + 自定义焦点列表
- 显示当前服务器名称 + 下拉箭头

**ServerManagerView 改进：**
- Sheet 方式添加服务器
- 删除确认对话框
- 编辑服务器名称功能

### 4. UserDefaults 键值

- `saved_servers`: 服务器列表数组（已有）
- `selected_server_id`: 当前选中的服务器 ID（新增）

## 错误处理

| 场景 | 处理方式 |
|------|----------|
| 服务器列表为空 | 显示 ServerSetupView |
| 切换到已删除的服务器 | 自动切换到第一个服务器 |
| 服务器连接失败 | Toast 提示，保留当前状态 |
| 认证失败 | 显示 LoginView，清除无效凭证 |
| Keychain 凭证缺失 | 显示 LoginView |

## 平台差异

### iOS (iPhone/iPad)
- 使用 SwiftUI Menu 组件
- 轻点展开下拉菜单
- Sheet 弹出服务器设置

### tvOS
- 自定义焦点列表视图
- 方向键导航
- 全屏服务器列表
- 确保所有元素可聚焦

## 测试要点

1. ✅ 首次启动显示 ServerSetupView
2. ✅ 添加服务器后自动登录
3. ✅ 切换服务器自动使用保存的凭证
4. ✅ 删除最后一个服务器返回设置页
5. ✅ iOS 和 tvOS 焦点导航正常
6. ✅ 网络错误提示友好
