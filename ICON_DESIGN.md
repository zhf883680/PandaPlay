# PandaPlay 应用图标设计指南

## 设计理念

PandaPlay 的图标融合了以下元素：
- **熊猫形象**：代表应用的名称和品牌标识
- **播放按钮**：底部三角形状象征媒体播放功能
- **现代简约风格**：扁平化设计，符合 iOS/tvOS 设计规范
- **友好亲切**：熊猫的表情传达出轻松愉快的观看体验

## 颜色方案

- **背景**：深蓝灰渐变 (#2C3E50 → #1A252F)
  - 提供专业、沉稳的视觉基础
  - 与白色熊猫形成良好对比

- **熊猫主体**：白色渐变 (#FFFFFF → #E8E8E8)
  - 简洁、纯净的视觉效果

- **熊猫特征**：深灰色/黑色 (#1A1A1A)
  - 耳朵、眼圈、眼睛和鼻子

- **播放按钮**：蓝色 (#3498DB)
  - 强调媒体播放功能
  - 与背景形成对比

## 图标尺寸

### iOS 所需尺寸
- 1024x1024 - App Store（必须提供）
- 180x180 - iPhone (@3x)
- 167x167 - iPad Pro (@2x)
- 152x152 - iPad (@2x)
- 120x120 - iPhone (@2x)
- 87x87 - iPhone (@3x) 设置
- 80x80 - iPhone (@2x) 设置
- 76x76 - iPad (@1x)
- 60x60 - iPhone (@2x) 通知
- 58x58 - iPhone (@3x) 设置
- 40x40 - iPhone (@2x) Spotlight
- 29x29 - iPhone (@2x) 设置
- 20x20 - iPhone (@2x) 通知

### tvOS 所需尺寸
- 1280x768 - App Store（必须提供）
- 400x240 - Top Shelf
- 232x232 - 创建横幅图标（小）
- 464x464 - 创建横幅图标（大）

## 如何生成图标

### 方法 1：使用在线工具
1. 访问 [AppIconGenerator](https://appicon.co)
2. 上传 `AppIcon.svg` 文件
3. 选择 "iOS" 和 "tvOS"
4. 下载生成的图标包
5. 将图标拖入 Xcode 的 AppIcon 资源目录

### 方法 2：使用命令行工具
```bash
# 安装 ImageMagick（如果尚未安装）
brew install imagemagick

# 从 SVG 生成 PNG 文件
convert -background none -resize 1024x1024 AppIcon.svg AppIcon-1024.png

# 生成其他所需尺寸
for size in 180 167 152 120 87 80 76 60 58 40 29 20; do
  convert -background none -resize ${size}x${size} AppIcon.svg AppIcon-${size}.png
done
```

### 方法 3：使用 Sketch/Figma
1. 将 `AppIcon.svg` 导入 Sketch 或 Figma
2. 创建多个画板，尺寸为所需图标尺寸
3. 将图标复制到每个画板
4. 导出为 PNG

## 在 Xcode 中添加图标

### iOS
1. 在 Xcode 中，打开 `Assets.xcassets`
2. 选择 `AppIcon`
3. 将生成的 PNG 图标拖入对应的尺寸槽位
4. 确保 "iOS" 目标被选中

### tvOS
1. 在 Xcode 中，打开 tvOS 目标的 `Assets.xcassets`
2. 选择 `AppIcon`
3. 将生成的 tvOS 图标拖入对应的尺寸槽位
4. 确保 "tvOS" 目标被选中

## 设计变体

### 深色模式
当前设计已考虑深色模式，使用深色背景确保在所有环境下都清晰可见。

### 无障碍
- 高对比度设计符合 WCAG 标准
- 清晰的形状和颜色便于识别
- 适合视力障碍用户

## 品牌应用

### 小尺寸建议
在小于 40x40 的尺寸下：
- 简化细节（去除渐变）
- 增强对比度
- 考虑只使用熊猫头部 + 播放按钮

### 单色版本
用于需要单色的场景（如通知、打印材料）：
- 保留基本轮廓
- 使用单一颜色（黑色或白色）

## 更新记录

- **v1.0** (2026-03-03): 初始图标设计
  - 熊猫形象
  - 播放按钮元素
  - 适配 iOS/tvOS

## 许可

此图标设计遵循项目整体许可证。可以自由修改和重新设计以适应品牌需求。
