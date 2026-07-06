# MacDesktopBuddy

一个常驻 macOS 桌面的可爱待办小工具。MacDesktopBuddy 会把“小Q”放在桌面边角：点击打开待办面板，拖动移动位置，到点时在图标旁弹出提醒气泡并播放提示音。

[中文](#中文) · [English](#english)

![MacDesktopBuddy icon](Resources/BuddyIcon.png)

## 中文

### 功能

- 常驻桌面图标：可拖动到桌面任意位置，点击打开待办面板。
- 待办列表：添加、完成、恢复、删除待办；完成任务会自动清除它的提醒。
- 任务提醒：支持 15 分钟、30 分钟、1 小时和自定义时间。
- 提醒气泡：到点后在图标旁显示提醒气泡，并播放提示音；气泡可手动关闭。
- 休息提醒：按固定间隔弹出温馨提醒，帮助你从长时间工作里停一下。
- 语音输入：使用 macOS 语音识别把中英文夹杂的口述内容转成待办。
- 隐身模式：右键或长按小Q选择隐身，之后可从菜单栏入口恢复。
- 设置：支持淡绿色/淡粉色主题，以及中文/英文面板语言。
- 本地保存：待办数据保存在本机，不依赖后端服务。

### 安装

从本仓库构建出的 DMG 在：

```text
dist/MacDesktopBuddy.dmg
```

打开 DMG 后，把 `MacDesktopBuddy.app` 拖到 `Applications`。首次启动后，小Q会常驻桌面；如果使用语音输入，macOS 会请求麦克风和语音识别权限。

### 权限与隐私

MacDesktopBuddy 使用以下系统能力：

| 权限 | 用途 |
| --- | --- |
| 麦克风 | 录制语音输入 |
| 语音识别 | 将语音转为待办文本 |
| 通知 | 为待办提醒注册系统通知 |

待办数据保存在本机 Application Support 目录下：

```text
~/Library/Application Support/DeskTodoBuddy/todos.json
```

设置项保存在 `UserDefaults`。当前项目没有后端服务，也没有上传待办内容的代码路径。

### 开发

要求：

- macOS 13 或更高版本
- Xcode command line tools
- Swift 5.9 或兼容工具链

运行测试：

```bash
swift test
```

构建 `.app`：

```bash
Scripts/build-app.sh
```

生成本地测试用 DMG，不签名、不公证：

```bash
SKIP_SIGNING=1 Scripts/package-dmg.sh
```

生成可分发 DMG：

```bash
NOTARY_PROFILE=btt-notary Scripts/package-dmg.sh
```

如果本机有多个 `Developer ID Application` 证书，可以显式指定：

```bash
DEVELOPER_ID="Developer ID Application: Your Name (TEAMID)" \
NOTARY_PROFILE=btt-notary \
Scripts/package-dmg.sh
```

打包脚本会执行 release build、创建 `.app`、签名、生成 DMG、提交 Apple notarization，并在通过后执行 stapler。

### 项目结构

```text
Sources/DeskTodoBuddy/
  AppController.swift          # AppKit 窗口、菜单栏、桌面图标、提醒气泡
  Views.swift                  # SwiftUI 面板、待办列表、设置和休息提醒 UI
  TodoStore.swift              # 本地待办存储
  ReminderCoordinator.swift    # 任务提醒和休息提醒调度
  SpeechInputController.swift  # 语音输入
  AppSettings.swift            # 主题、语言和界面字符串
  NotificationScheduler.swift  # macOS 通知调度

Resources/                     # 图标和提醒音效
Packaging/                     # Info.plist、App 图标、签名 entitlements
Scripts/                       # app 构建和 DMG 打包脚本
Tests/                         # ReminderTiming、TodoStore、ReminderCoordinator 测试
```

### 测试覆盖

当前测试覆盖：

- 自定义提醒时间计算，包括秒数归零和当前/过去分钟兜底。
- 任务提醒只在到期后 2 分钟窗口内触发。
- 完成任务清除提醒，重新设置提醒会解除已提醒标记。
- 本地 JSON 持久化读写。

### 说明

- 外部产品名是 `MacDesktopBuddy`，内部 SwiftPM target 仍为 `DeskTodoBuddy`。
- 仓库当前没有声明开源许可证；分发或开源前请补充 `LICENSE`。

## English

MacDesktopBuddy is a small macOS desktop companion for todos, task reminders, and gentle break reminders. It keeps a draggable “Q” icon on your desktop, opens a compact todo panel on click, and shows timed reminder bubbles with sound.

### Features

- Floating desktop icon: drag it anywhere on the desktop and click to open the panel.
- Todo list: add, complete, restore, and delete tasks.
- Task reminders: choose 15 minutes, 30 minutes, 1 hour, or a custom date/time.
- Reminder bubbles: timed reminders appear near the desktop icon and play a sound.
- Break reminders: warm rest prompts at a configurable interval.
- Voice input: macOS Speech recognition for Chinese-first dictation with mixed English terms.
- Hide mode: hide Q from the desktop via right-click or long-press, then restore it from the menu bar.
- Settings: Soft Green / Soft Pink themes and Chinese / English panel language.
- Local-first storage: todos are stored locally with no backend service.

### Install

The generated DMG lives at:

```text
dist/MacDesktopBuddy.dmg
```

Open the DMG and drag `MacDesktopBuddy.app` into `Applications`. On first voice input, macOS will ask for microphone and speech recognition permissions.

### Permissions And Privacy

MacDesktopBuddy uses these macOS capabilities:

| Permission | Purpose |
| --- | --- |
| Microphone | Capture voice input |
| Speech Recognition | Convert speech to todo text |
| Notifications | Schedule task reminder notifications |

Todo data is stored locally at:

```text
~/Library/Application Support/DeskTodoBuddy/todos.json
```

Settings are stored in `UserDefaults`. The app has no backend service and no code path that uploads todo content.

### Development

Requirements:

- macOS 13 or later
- Xcode command line tools
- Swift 5.9 or a compatible toolchain

Run tests:

```bash
swift test
```

Build the `.app` bundle:

```bash
Scripts/build-app.sh
```

Create an unsigned local-testing DMG:

```bash
SKIP_SIGNING=1 Scripts/package-dmg.sh
```

Create a signed and notarized distribution DMG:

```bash
NOTARY_PROFILE=btt-notary Scripts/package-dmg.sh
```

If multiple `Developer ID Application` certificates are available, specify one explicitly:

```bash
DEVELOPER_ID="Developer ID Application: Your Name (TEAMID)" \
NOTARY_PROFILE=btt-notary \
Scripts/package-dmg.sh
```

The packaging script builds the release app, signs it, creates the DMG, submits it to Apple notarization, and staples the accepted ticket.

### Project Layout

```text
Sources/DeskTodoBuddy/
  AppController.swift          # AppKit windows, menu bar, desktop icon, reminder bubbles
  Views.swift                  # SwiftUI panel, todo list, settings, and break reminder UI
  TodoStore.swift              # Local todo storage
  ReminderCoordinator.swift    # Task and break reminder scheduling
  SpeechInputController.swift  # Voice input
  AppSettings.swift            # Theme, language, and UI strings
  NotificationScheduler.swift  # macOS notification scheduling

Resources/                     # Icons and reminder sound
Packaging/                     # Info.plist, app icon, signing entitlements
Scripts/                       # App build and DMG packaging scripts
Tests/                         # ReminderTiming, TodoStore, ReminderCoordinator tests
```

### Tests

The test suite covers:

- Custom reminder time calculation, including second stripping and current/past-minute fallback.
- Task reminder delivery within the 2-minute freshness window.
- Reminder cleanup when tasks are completed or rescheduled.
- Local JSON persistence round trips.

### Notes

- The external product name is `MacDesktopBuddy`; the internal SwiftPM target is still `DeskTodoBuddy`.
- No open-source license is declared in this repository yet. Add a `LICENSE` before public distribution as open source.
