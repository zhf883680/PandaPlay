#!/bin/bash

# PandaPlay Project Generator
# This script generates a basic Xcode tvOS project structure

PROJECT_DIR="/Users/zhoufeng/Documents/code/PandaPlay"
PROJECT_NAME="PandaPlay"
BUNDLE_ID="com.pandaplay.emby"

# Create Xcode project using xcodebuild
cd "$PROJECT_DIR"

# Create a tvOS app template
xcodebuild -project "${PROJECT_NAME}.xcodeproj" -scheme "${PROJECT_NAME}" -showBuildSettings > /dev/null 2>&1

# If project doesn't exist, provide manual instructions
if [ ! -d "${PROJECT_NAME}.xcodeproj/project.xcworkspace" ]; then
    echo "=================================="
    echo "PandaPlay Project Setup Instructions"
    echo "=================================="
    echo ""
    echo "由于自动创建 Xcode 项目的复杂性，请按照以下步骤在 Xcode 中创建项目："
    echo ""
    echo "1. 打开 Xcode"
    echo "2. 选择 File → New → Project"
    echo "3. 选择 tvOS → App"
    echo "4. 填写以下信息："
    echo "   - Product Name: PandaPlay"
    echo "   - Team: 选择您的开发者账号"
    echo "   - Organization Identifier: com.pandaplay"
    echo "   - Bundle Identifier: com.pandaplay.emby"
    echo "   - Interface: SwiftUI"
    echo "   - Language: Swift"
    echo "   - 保存位置: $PROJECT_DIR"
    echo "5. 点击 Create"
    echo ""
    echo "6. 项目创建后，请执行以下操作："
    echo "   a. 删除 Xcode 自动生成的文件（ContentView.swift, PandaPlayApp.swift）"
    echo "   b. 将 PandaPlay/ 文件夹中的所有文件拖入 Xcode 项目"
    echo "   c. 确保 Info.plist 位于正确的位置"
    echo "   d. 配置 Signing & Capabilities"
    echo ""
    echo "或者，您可以运行以下命令让 Xcode 生成项目："
    echo ""
    echo "   cd $PROJECT_DIR"
    echo "   # 使用 Swift Package Manager 初始化"
    echo "   swift package init --type executable --name PandaPlay"
    echo ""
    echo "=================================="
fi
