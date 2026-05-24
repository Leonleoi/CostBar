# Fix Package Publish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix all currently identified app bugs, verify the macOS build, clean stale generated files, publish the updated installer to GitHub, and update the GitHub Pages website plus README.

**Architecture:** Keep provider-specific behavior inside service classes, keep refresh orchestration in `DashboardViewModel`, and keep presentation-only formatting in SwiftUI views. The packaging workflow should build in `/tmp` to avoid FileProvider/FinderInfo signing pollution, then publish a clean zip named `CostBar-kx-macOS.zip` that matches the website download link.

**Tech Stack:** Swift 5, SwiftUI, Xcode macOS target, XCTest, GitHub CLI, GitHub Pages static `docs/index.html`, GitHub Releases.

---

## File Structure

- Modify `Services/AnthropicService.swift`: remove the invalid `/v1/usage` network call and report unsupported usage explicitly.
- Modify `Services/OpenAIService.swift`: treat missing billing and usage fields as errors instead of converting missing values to zero.
- Modify `ViewModels/DashboardViewModel.swift`: support provider-specific refresh behavior, preserve old good data on transient failures, load saved refresh interval on startup, and expose currency conversion helpers for all providers.
- Modify `Storage/LocalCache.swift`: persist `isEnabled` and `displayOrder` while stripping API keys.
- Modify `Views/ProviderRowView.swift`: show accurate currency labels and converted values for any provider.
- Modify `Views/MenuBarPopover.swift`: show monthly cost in the selected display currency after conversion.
- Modify `Views/UsageChartView.swift`: chart selected display currency consistently.
- Modify `kxTests/OpenAIServiceTests.swift`: add regression tests for missing required OpenAI fields.
- Modify `kxTests/LocalCacheTests.swift`: add regression test for provider config metadata preservation.
- Create `kxTests/DashboardViewModelTests.swift` only if dependency injection is added for refresh behavior. If avoiding extra injection keeps the change smaller, skip this file and verify through service/view-model unit boundaries already covered.
- Modify `docs/index.html`: update release date/version text and ensure the download href points to `https://github.com/Leonleoi/CostBar/releases/latest/download/CostBar-kx-macOS.zip`.
- Modify `README.md`: update tested status, download artifact name, and provider support notes.
- Clean generated files: remove `dist/Release`, `dist/CostBar-kx.zip`, and project-root `CostBar-kx.app` if they are stale build artifacts. Keep the final `dist/CostBar-kx-macOS.zip`.

---

### Task 1: Fix Anthropic unsupported usage behavior

**Files:**
- Modify: `Services/AnthropicService.swift:30-58`

- [ ] **Step 1: Replace invalid usage API call**

Replace `fetchUsage(startDate:endDate:)` with:

```swift
func fetchUsage(startDate: Date, endDate: Date) async throws -> [UsageRecord] {
    throw UsageError.usageNotSupported
}
```

- [ ] **Step 2: Verify no invalid endpoint remains**

Run:

```bash
rg -n "/v1/usage|usageEndpoint" Services Utils README.md docs/index.html
```

Expected: no `Services/AnthropicService.swift` network request to `/v1/usage`. README may still say Anthropic usage is unsupported.

- [ ] **Step 3: Commit**

```bash
git add Services/AnthropicService.swift
git commit -m "fix: mark anthropic usage as unsupported"
```

---

### Task 2: Prevent OpenAI missing-field zero balances

**Files:**
- Modify: `Services/OpenAIService.swift:25-58`
- Test: `kxTests/OpenAIServiceTests.swift`

- [ ] **Step 1: Add failing tests for missing OpenAI billing and usage fields**

Add these tests to `OpenAIServiceTests`:

```swift
func testFetchBalanceThrowsWhenHardLimitIsMissing() async {
    let service = makeService { request in
        let path = request.url?.path ?? ""
        if path.hasSuffix("/dashboard/billing/subscription") {
            return Self.response("{}")
        }

        return Self.response("""
        {
          "total_usage": 3450
        }
        """)
    }

    await XCTAssertThrowsErrorAsync(try await service.fetchBalance())
}

func testFetchBalanceThrowsWhenTotalUsageIsMissing() async {
    let service = makeService { request in
        let path = request.url?.path ?? ""
        if path.hasSuffix("/dashboard/billing/subscription") {
            return Self.response("""
            {
              "hard_limit_usd": 120.0
            }
            """)
        }

        return Self.response("{}")
    }

    await XCTAssertThrowsErrorAsync(try await service.fetchBalance())
}
```

If `XCTAssertThrowsErrorAsync` is not already available in the file, add:

```swift
private func XCTAssertThrowsErrorAsync(
    _ expression: @autoclosure () async throws -> some Any,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("Expected error to be thrown", file: file, line: line)
    } catch {
        // Expected.
    }
}
```

- [ ] **Step 2: Run tests and confirm failure before implementation**

Run:

```bash
xcodebuild test -project CostBar-kx.xcodeproj -scheme CostBar-kx -destination 'platform=macOS' -only-testing:CostBar-kxTests/OpenAIServiceTests
```

Expected before implementation: the two new tests fail because missing fields currently become zero.

- [ ] **Step 3: Implement strict OpenAI parsing**

In `OpenAIService.fetchBalance()`, replace:

```swift
let hardLimit = subscription.hardLimitUsd ?? 0
```

with:

```swift
guard let hardLimit = subscription.hardLimitUsd else {
    throw APIError(statusCode: 0, message: "OpenAI subscription response missing hard_limit_usd")
}
```

Replace:

```swift
let totalUsed = (usage.totalUsage ?? 0) / 100.0
```

with:

```swift
guard let totalUsage = usage.totalUsage else {
    throw APIError(statusCode: 0, message: "OpenAI usage response missing total_usage")
}
let totalUsed = totalUsage / 100.0
```

- [ ] **Step 4: Run OpenAI service tests**

Run:

```bash
xcodebuild test -project CostBar-kx.xcodeproj -scheme CostBar-kx -destination 'platform=macOS' -only-testing:CostBar-kxTests/OpenAIServiceTests
```

Expected: all OpenAI service tests pass.

- [ ] **Step 5: Commit**

```bash
git add Services/OpenAIService.swift kxTests/OpenAIServiceTests.swift
git commit -m "fix: reject incomplete openai billing responses"
```

---

### Task 3: Fix refresh behavior for providers without balance APIs

**Files:**
- Modify: `ViewModels/DashboardViewModel.swift:155-226`

- [ ] **Step 1: Add provider-specific fallback behavior**

In the `catch` after `service.fetchBalance()`, distinguish unsupported balance from real errors:

```swift
do {
    balance = try await service.fetchBalance()
} catch UsageError.balanceNotSupported {
    do {
        try await service.verifyConnection()
    } catch {
        errorMsg = error.localizedDescription
    }
} catch {
    errorMsg = error.localizedDescription
}
```

- [ ] **Step 2: Allow usage fetch after unsupported balance only if connection verified**

Add a `connectionVerified` flag inside each provider task:

```swift
var connectionVerified = false
```

Set it after a successful balance or verify call:

```swift
balance = try await service.fetchBalance()
connectionVerified = true
```

and:

```swift
try await service.verifyConnection()
connectionVerified = true
```

Then change:

```swift
if balance != nil {
```

to:

```swift
if connectionVerified {
```

- [ ] **Step 3: Preserve benign unsupported usage state**

Keep this branch:

```swift
} catch is UsageError {
    // Expected: provider doesn't support usage history
}
```

This prevents DeepSeek and Anthropic unsupported usage from appearing as failed connections.

- [ ] **Step 4: Run tests**

Run:

```bash
xcodebuild test -project CostBar-kx.xcodeproj -scheme CostBar-kx -destination 'platform=macOS'
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add ViewModels/DashboardViewModel.swift
git commit -m "fix: verify providers without balance APIs"
```

---

### Task 4: Apply currency conversion consistently

**Files:**
- Modify: `ViewModels/DashboardViewModel.swift:54-86`
- Modify: `Views/ProviderRowView.swift:42-90`
- Modify: `Views/MenuBarPopover.swift:31-73`
- Modify: `Views/UsageChartView.swift`

- [ ] **Step 1: Add generic display amount helper**

Add to `DashboardViewModel`:

```swift
func displayAmount(_ amount: Double, currency: String) -> (amount: Double, currency: CurrencyType) {
    let actualCurrency = currency.uppercased()
    if preferredCurrency == .usd, actualCurrency == "CNY", let rate = exchangeRate {
        return (amount / rate, .usd)
    }
    if preferredCurrency == .cny, actualCurrency == "USD", let rate = exchangeRate {
        return (amount * rate, .cny)
    }
    return (amount, CurrencyType(rawValue: actualCurrency) ?? preferredCurrency)
}

func displayBalance(for record: BalanceRecord) -> (amount: Double, currency: CurrencyType) {
    displayAmount(record.totalBalance, currency: record.currency)
}

func displayCost(_ amount: Double, currency: String) -> (amount: Double, currency: CurrencyType) {
    displayAmount(amount, currency: currency)
}
```

Change `displayDeepseekBalance` to call `displayBalance(for:)`:

```swift
var displayDeepseekBalance: (amount: Double?, currency: CurrencyType) {
    guard let record = balances[.deepseek] else { return (nil, preferredCurrency) }
    let display = displayBalance(for: record)
    return (display.amount, display.currency)
}
```

- [ ] **Step 2: Update provider rows to use real display currency**

Replace provider-specific balance formatting in `ProviderRowView` with:

```swift
let display = dashboardVM.displayBalance(for: balance)
Text("Balance: \(String(format: "%.2f", display.amount)) \(display.currency.rawValue)")
```

For the trailing value, use:

```swift
let display = dashboardVM.displayBalance(for: balance)
Text("\(String(format: "%.2f", display.amount))")
Text(display.currency.rawValue)
```

- [ ] **Step 3: Update menu summary monthly cost**

In `MenuBarPopover`, calculate:

```swift
private var monthlyCostDisplay: (amount: Double, currency: DashboardViewModel.CurrencyType) {
    dashboardVM.usageSummaries.values.reduce((0, dashboardVM.preferredCurrency)) { partial, summary in
        let converted = dashboardVM.displayCost(summary.totalCostThisMonth, currency: summary.currency)
        return (partial.0 + converted.amount, converted.currency)
    }
}
```

Use:

```swift
let monthly = monthlyCostDisplay
SummaryItem(label: "Monthly Cost", value: formatCurrency(monthly.amount, symbol: monthly.currency.symbol))
```

- [ ] **Step 4: Update chart inputs**

Either keep chart values in their source currency and label by source, or convert records before charting. For the current all-provider chart, convert costs in `UsageChartView.groupedByDay()` by adding a conversion closure:

```swift
let displayCost: (UsageRecord) -> Double
```

and use `displayCost(record)` instead of `record.cost`.

- [ ] **Step 5: Run tests and build**

Run:

```bash
xcodebuild test -project CostBar-kx.xcodeproj -scheme CostBar-kx -destination 'platform=macOS'
xcodebuild build -project CostBar-kx.xcodeproj -scheme CostBar-kx -configuration Debug -destination 'platform=macOS'
```

Expected: both commands succeed.

- [ ] **Step 6: Commit**

```bash
git add ViewModels/DashboardViewModel.swift Views/ProviderRowView.swift Views/MenuBarPopover.swift Views/UsageChartView.swift
git commit -m "fix: display converted currencies consistently"
```

---

### Task 5: Restore saved refresh interval on launch

**Files:**
- Modify: `ViewModels/DashboardViewModel.swift:92-100`

- [ ] **Step 1: Add saved interval helper**

Add:

```swift
private var savedRefreshInterval: TimeInterval {
    let saved = UserDefaults.standard.double(forKey: "refreshInterval")
    return saved > 0 ? saved : AppConstants.defaultRefreshInterval
}
```

- [ ] **Step 2: Use saved interval at startup**

Replace:

```swift
startAutoRefresh()
```

with:

```swift
startAutoRefresh(interval: savedRefreshInterval)
```

- [ ] **Step 3: Run build**

Run:

```bash
xcodebuild build -project CostBar-kx.xcodeproj -scheme CostBar-kx -configuration Debug -destination 'platform=macOS'
```

Expected: build succeeds.

- [ ] **Step 4: Commit**

```bash
git add ViewModels/DashboardViewModel.swift
git commit -m "fix: restore saved refresh interval on launch"
```

---

### Task 6: Preserve provider config metadata

**Files:**
- Modify: `Storage/LocalCache.swift:33-42`
- Test: `kxTests/LocalCacheTests.swift`

- [ ] **Step 1: Add failing metadata preservation test**

Add to `LocalCacheTests`:

```swift
func testSaveAndLoadConfigPreservesNonSecretFields() throws {
    let cache = LocalCache()
    var config = ProviderConfig(provider: .openai, apiKey: "secret", baseURL: "https://example.com")
    config.isEnabled = false
    config.displayOrder = 42

    try cache.saveConfig([config])
    let loaded = try cache.loadConfig()

    XCTAssertEqual(loaded.count, 1)
    XCTAssertEqual(loaded[0].provider, .openai)
    XCTAssertEqual(loaded[0].apiKey, "")
    XCTAssertEqual(loaded[0].baseURL, "https://example.com")
    XCTAssertFalse(loaded[0].isEnabled)
    XCTAssertEqual(loaded[0].displayOrder, 42)
}
```

- [ ] **Step 2: Run test and confirm failure before implementation**

Run:

```bash
xcodebuild test -project CostBar-kx.xcodeproj -scheme CostBar-kx -destination 'platform=macOS' -only-testing:CostBar-kxTests/LocalCacheTests/testSaveAndLoadConfigPreservesNonSecretFields
```

Expected before implementation: failure because `isEnabled` and `displayOrder` are reset.

- [ ] **Step 3: Preserve fields while stripping API key**

Replace the safe config map with:

```swift
let safeConfigs = configs.map { c in
    var safe = c
    safe.apiKey = ""
    return safe
}
```

- [ ] **Step 4: Run LocalCache tests**

Run:

```bash
xcodebuild test -project CostBar-kx.xcodeproj -scheme CostBar-kx -destination 'platform=macOS' -only-testing:CostBar-kxTests/LocalCacheTests
```

Expected: LocalCache tests pass.

- [ ] **Step 5: Commit**

```bash
git add Storage/LocalCache.swift kxTests/LocalCacheTests.swift
git commit -m "fix: preserve provider config metadata"
```

---

### Task 7: Clean stale generated artifacts

**Files:**
- Delete if present: `dist/Release`
- Delete if present: `dist/CostBar-kx.zip`
- Delete if present: `CostBar-kx.app`

- [ ] **Step 1: Inspect generated artifacts**

Run:

```bash
find dist -maxdepth 3 -print 2>/dev/null
ls -ld CostBar-kx.app 2>/dev/null || true
```

Expected: old build products are visible before cleanup.

- [ ] **Step 2: Remove stale artifacts**

Run:

```bash
rm -rf dist/Release dist/CostBar-kx.zip CostBar-kx.app
```

- [ ] **Step 3: Keep final package name only after packaging**

After Task 9, `dist/` should contain:

```text
dist/CostBar-kx-macOS.zip
```

- [ ] **Step 4: Commit cleanup if tracked files changed**

Run:

```bash
git status --short
```

If `CostBar-kx.app` was tracked and deleted:

```bash
git add -A CostBar-kx.app dist
git commit -m "chore: remove stale build artifacts"
```

If only untracked generated files were removed, do not create a cleanup commit.

---

### Task 8: Full verification after fixes

**Files:**
- No source edits.

- [ ] **Step 1: Run full test suite**

Run:

```bash
xcodebuild test -project CostBar-kx.xcodeproj -scheme CostBar-kx -destination 'platform=macOS'
```

Expected: all tests pass with 0 failures.

- [ ] **Step 2: Run Xcode Analyze**

Run:

```bash
xcodebuild analyze -project CostBar-kx.xcodeproj -scheme CostBar-kx -configuration Debug -destination 'platform=macOS'
```

Expected: `** ANALYZE SUCCEEDED **`.

- [ ] **Step 3: Run Release build in `/tmp`**

Run:

```bash
rm -rf /tmp/kx-package
mkdir -p /tmp/kx-package
xcodebuild build -project CostBar-kx.xcodeproj -scheme CostBar-kx -configuration Release -destination 'platform=macOS' -derivedDataPath /tmp/kx-package/DerivedData SYMROOT=/tmp/kx-package/dist
```

Expected: `** BUILD SUCCEEDED **`.

---

### Task 9: Package clean installer zip

**Files:**
- Create: `dist/CostBar-kx-macOS.zip`

- [ ] **Step 1: Clean package xattrs and re-sign**

Run:

```bash
xattr -cr /tmp/kx-package/dist/Release/CostBar-kx.app
codesign --force --sign - --options runtime --entitlements CostBar-kx.entitlements /tmp/kx-package/dist/Release/CostBar-kx.app
codesign --verify --deep --strict --verbose=2 /tmp/kx-package/dist/Release/CostBar-kx.app
```

Expected:

```text
/tmp/kx-package/dist/Release/CostBar-kx.app: valid on disk
/tmp/kx-package/dist/Release/CostBar-kx.app: satisfies its Designated Requirement
```

- [ ] **Step 2: Create zip with website-compatible name**

Run:

```bash
mkdir -p dist
rm -f dist/CostBar-kx-macOS.zip
COPYFILE_DISABLE=1 ditto -c -k --norsrc --keepParent /tmp/kx-package/dist/Release/CostBar-kx.app dist/CostBar-kx-macOS.zip
```

- [ ] **Step 3: Verify zip**

Run:

```bash
rm -rf /tmp/kx-package/verify-unzip
mkdir -p /tmp/kx-package/verify-unzip
unzip -q dist/CostBar-kx-macOS.zip -d /tmp/kx-package/verify-unzip
codesign --verify --deep --strict --verbose=2 /tmp/kx-package/verify-unzip/CostBar-kx.app
unzip -t dist/CostBar-kx-macOS.zip
if unzip -l dist/CostBar-kx-macOS.zip | rg '/\._|\._' >/dev/null; then echo 'AppleDouble metadata found'; exit 1; else echo 'No AppleDouble metadata found'; fi
shasum -a 256 dist/CostBar-kx-macOS.zip
```

Expected: signature valid, zip test passes, no AppleDouble metadata.

---

### Task 10: Update website and README

**Files:**
- Modify: `docs/index.html`
- Modify: `README.md`

- [ ] **Step 1: Update website download link**

Ensure `docs/index.html` contains this href:

```html
https://github.com/Leonleoi/CostBar/releases/latest/download/CostBar-kx-macOS.zip
```

- [ ] **Step 2: Update website release copy**

In the download section, use:

```html
<p data-i18n="dl_desc">Download the latest verified build for macOS 14.0+ (Apple Silicon & Intel). Open source on GitHub.</p>
```

and Chinese:

```javascript
dl_desc: '下载最新已验证构建版本（macOS 14.0+，Apple Silicon 与 Intel）。开源在 GitHub。',
```

- [ ] **Step 3: Update README provider support**

Keep DeepSeek and OpenAI rows. Ensure Anthropic says connection verification only and no usage API:

```markdown
| **Anthropic** | ❌ No API | ❌ No API | Connection verification only |
```

- [ ] **Step 4: Update README download artifact name**

Add:

```markdown
Release artifact: `CostBar-kx-macOS.zip`
```

under the download section.

- [ ] **Step 5: Commit docs**

```bash
git add docs/index.html README.md
git commit -m "docs: update download and provider support notes"
```

---

### Task 11: Publish to GitHub

**Files:**
- Git commit history
- GitHub Release asset: `CostBar-kx-macOS.zip`
- GitHub Pages source: `docs/index.html`

- [ ] **Step 1: Confirm remote and branch**

Run:

```bash
git remote -v
git branch --show-current
git status --short
```

Expected: remote is `https://github.com/Leonleoi/CostBar.git`, branch is `main`.

- [ ] **Step 2: Commit remaining changes**

If changes remain:

```bash
git add -A
git commit -m "chore: prepare verified macOS release"
```

- [ ] **Step 3: Push branch**

Run:

```bash
git push origin main
```

Expected: push succeeds.

- [ ] **Step 4: Create or update GitHub Release**

Use a tag based on the app version and date:

```bash
TAG="v1.0.0-20260524"
gh release view "$TAG" >/dev/null 2>&1 || git tag "$TAG"
git push origin "$TAG"
gh release create "$TAG" dist/CostBar-kx-macOS.zip --title "CostBar-kx v1.0.0 verified build 2026-05-24" --notes "Verified macOS build. Fixes provider refresh handling, missing-field balance handling, currency display, saved refresh interval loading, and package cleanup." || gh release upload "$TAG" dist/CostBar-kx-macOS.zip --clobber
```

Expected: release exists with asset `CostBar-kx-macOS.zip`.

- [ ] **Step 5: Verify website download URL**

Run:

```bash
curl -I -L https://github.com/Leonleoi/CostBar/releases/latest/download/CostBar-kx-macOS.zip | sed -n '1,20p'
```

Expected: redirects to the release asset and returns a successful final response.

---

### Task 12: Final verification report

**Files:**
- No edits.

- [ ] **Step 1: Check clean publish state**

Run:

```bash
git status --short
git log --oneline -5
ls -lh dist/CostBar-kx-macOS.zip
shasum -a 256 dist/CostBar-kx-macOS.zip
```

- [ ] **Step 2: Report exact results**

Report:

```text
Tests: xcodebuild test ... => pass/fail with test count
Analyze: xcodebuild analyze ... => pass/fail
Release build: xcodebuild build Release in /tmp => pass/fail
Package: dist/CostBar-kx-macOS.zip size and SHA256
GitHub: pushed branch and release tag
Website: docs/index.html updated and pushed
README: updated and pushed
Residual risk: ad-hoc signed build is not notarized unless Developer ID signing is configured
```

---

## Self-Review

**Spec coverage:** The plan includes all requested items: fix all identified bugs, rerun checks, delete stale generated files, package the app, update website download link, update README, push to GitHub, and upload the installer to GitHub Releases.

**Placeholder scan:** No task uses TBD/TODO/fill-in placeholders. Commands and code snippets are concrete.

**Type consistency:** Code snippets use existing types: `UsageError`, `APIError`, `BalanceRecord`, `UsageRecord`, `DashboardViewModel.CurrencyType`, and existing service/view files.
