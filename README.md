# 🤖 AIUsageTracker

**Track your AI API usage & balance — right from the macOS menu bar**

[//]: # (magic comment: divider)

**在 macOS 菜单栏实时监控你的 AI API 用量和余额**

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14.0%2B-blue?logo=apple" alt="macOS 14.0+" />
  <img src="https://img.shields.io/badge/Swift-5.9-orange?logo=swift" alt="Swift 5.9" />
  <img src="https://img.shields.io/badge/license-MIT-green" alt="MIT License" />
</p>

---

## ✨ Features / 功能

| English | 中文 |
|---------|------|
| 🖥️ Native macOS menu bar app — lightweight, always on hand | 🖥️ 原生 macOS 菜单栏应用，轻量不占 Dock |
| 📊 Real-time API balance & usage refresh | 📊 实时刷新 API 余额与用量 |
| 🔑 API keys stored securely in system Keychain | 🔑 API Key 安全存入系统 Keychain |
| ⏱️ Configurable auto-refresh interval | ⏱️ 可配置自动刷新间隔 |
| 📈 30-day usage history charts (Swift Charts) | 📈 30 天用量历史图表（Swift Charts） |
| 🔌 Extensible provider architecture | 🔌 可扩展的多平台架构 |
| 🌙 Menu bar only — no Dock icon clutter | 🌙 纯菜单栏运行，无 Dock 图标 |
| 🪟 Always-on-top floating widget | 🪟 永远置顶悬浮窗显示余额 |
| 📍 Show balance in the menu bar / notch area | 📍 在菜单栏/刘海区域显示余额 |

---

## 🚀 Quick Start / 快速开始

### 1. Download / 下载

> **⏳ Coming soon — prebuilt binary**
> For now, build from source (instructions below).
>
> **⏳ 预编译版本即将发布**
> 目前请自行从源码构建。

### 2. Build from source / 从源码构建

```bash
# macOS 14.0+ required / 需要 macOS 14.0+
xcodegen generate   # Generate Xcode project / 生成 Xcode 项目
xcodebuild -scheme AIUsageTracker -configuration Release build
```

Or open `AIUsageTracker.xcodeproj` in Xcode and hit **Cmd+R**.

或者在 Xcode 中打开 `AIUsageTracker.xcodeproj`，按 **Cmd+R** 运行。

### 3. Set up your API key / 配置 API Key

1. Click the pie chart icon 🥧 in the menu bar
2. Go to **Settings** → **API Keys**
3. Enter your API key → **Save** → **Test Connection**

> **Where to get API keys / 获取 API Key:**
> - **DeepSeek**: [platform.deepseek.com](https://platform.deepseek.com)
> - **OpenAI**: [platform.openai.com](https://platform.openai.com)
> - **Anthropic**: [console.anthropic.com](https://console.anthropic.com)

---

## 🔧 Supported Providers / 支持的服务商

| Provider | Balance | Usage History | Notes |
|----------|---------|---------------|-------|
| **DeepSeek** | ✅ `/user/balance` | ❌ API unavailable | Balance works; usage tracked locally (planned) |
| **OpenAI** | ✅ `/dashboard/billing/subscription` | ✅ `/dashboard/billing/usage` | Full support |
| **Anthropic** | ❌ No API | ❌ No API | Connection verification only |

| 服务商 | 余额查询 | 用量历史 | 说明 |
|--------|---------|---------|------|
| **DeepSeek** | ✅ 支持 | ❌ 无 API | 余额可用，用量本地记录（规划中） |
| **OpenAI** | ✅ 支持 | ✅ 支持 | 全功能支持 |
| **Anthropic** | ❌ 不支持 | ❌ 不支持 | 仅可验证连接 |

### 🔌 Adding a new provider / 添加新服务商

Implement the `UsageServiceProtocol` and add it to `UsageServiceFactory` — that's it.

实现 `UsageServiceProtocol`，添加到 `UsageServiceFactory` 即可。

```swift
protocol UsageServiceProtocol {
    var provider: AIProvider { get }
    var config: ProviderConfig { get }
    func fetchBalance() async throws -> BalanceRecord
    func fetchUsage(startDate: Date, endDate: Date) async throws -> [UsageRecord]
    func verifyConnection() async throws
}
```

---

## 📁 Project Structure / 项目结构

```
AIUsageTracker/
├── AIUsageTrackerApp.swift      # @main — MenuBarExtra entry
├── Views/                       # SwiftUI UI
│   ├── MenuBarPopover.swift     # Menu bar dropdown
│   ├── ProviderRowView.swift    # Per-provider card
│   ├── UsageChartView.swift     # Swift Charts
│   └── SettingsView.swift       # API keys & preferences
├── ViewModels/                  # State management
│   ├── DashboardViewModel.swift # Data aggregation & refresh
│   └── SettingsViewModel.swift  # Settings state
├── Models/                      # Data models
│   ├── ProviderConfig.swift     # Provider enum + config
│   ├── UsageRecord.swift        # Usage data
│   └── BalanceRecord.swift      # Balance + API response types
├── Services/                    # API layer
│   ├── UsageServiceProtocol.swift
│   ├── DeepSeekService.swift
│   ├── OpenAIService.swift
│   ├── AnthropicService.swift
│   ├── UsageServiceFactory.swift
│   └── RefreshScheduler.swift
├── Storage/                     # Persistence
│   ├── KeychainStorage.swift    # Keychain wrapper
│   └── LocalCache.swift         # Disk cache
└── Utils/                       # Helpers
    ├── Constants.swift
    ├── DateFormatters.swift
    └── APIError.swift
```

---

## 🏗️ Tech Stack / 技术栈

- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI (macOS 14+ `MenuBarExtra`)
- **Charts**: Swift Charts (built-in)
- **Keychain**: Security framework (built-in)
- **Networking**: URLSession async/await
- **Project Generation**: XcodeGen (`project.yml`)

---

## 📝 Requirements / 系统要求

- macOS 14.0+ (Sonoma or later)
- Xcode 16.0+ (for building from source)
- An API key from your AI provider

---

## 🤝 Contributing / 贡献

PRs welcome! If you'd like to add a new provider or improve the app, feel free to open an issue or pull request.

欢迎提交 PR！如果你想添加新服务商或改进功能，欢迎提 Issue 或 PR。

---

## 📄 License / 许可

MIT
