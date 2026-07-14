import AppKit
import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case green
    case pink

    var id: String { rawValue }

    func displayName(language: AppLanguage) -> String {
        switch (self, language) {
        case (.green, .chinese): return "薄荷绿"
        case (.green, .english): return "Mint Green"
        case (.pink, .chinese): return "樱花粉"
        case (.pink, .english): return "Sakura Pink"
        }
    }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case chinese
    case english

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chinese: return "中文"
        case .english: return "English"
        }
    }
}

@MainActor
final class AppSettings: ObservableObject {
    @Published var theme: AppTheme {
        didSet {
            UserDefaults.standard.set(theme.rawValue, forKey: Keys.theme)
            onChange?()
        }
    }

    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: Keys.language)
            onChange?()
        }
    }

    @Published var customAppName: String {
        didSet {
            UserDefaults.standard.set(customAppName, forKey: Keys.customAppName)
            onChange?()
        }
    }

    @Published private(set) var logoRevision = UUID()

    var onChange: (() -> Void)?

    private enum Keys {
        static let theme = "appTheme"
        static let language = "appLanguage"
        static let customAppName = "customAppName"
    }

    init() {
        let storedTheme = UserDefaults.standard.string(forKey: Keys.theme)
        theme = storedTheme.flatMap(AppTheme.init(rawValue:)) ?? .green

        let storedLanguage = UserDefaults.standard.string(forKey: Keys.language)
        language = storedLanguage.flatMap(AppLanguage.init(rawValue:)) ?? .chinese

        customAppName = UserDefaults.standard.string(forKey: Keys.customAppName) ?? ""
    }

    var displayName: String {
        let normalized = customAppName.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? AppStrings.defaultAppName(language) : normalized
    }

    var hasCustomLogo: Bool {
        FileManager.default.fileExists(atPath: AppPaths.customLogoURL.path)
    }

    func updateLogo(from sourceURL: URL) throws {
        guard let image = NSImage(contentsOf: sourceURL),
              let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileReadCorruptFile)
        }

        try FileManager.default.createDirectory(at: AppPaths.supportDirectory, withIntermediateDirectories: true)
        try pngData.write(to: AppPaths.customLogoURL, options: .atomic)
        logoRevision = UUID()
        onChange?()
    }

    func resetLogo() throws {
        let url = AppPaths.customLogoURL
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        logoRevision = UUID()
        onChange?()
    }
}

enum AppStrings {
    static func settings(_ language: AppLanguage) -> String {
        language == .chinese ? "设置" : "Settings"
    }

    static func restoreXiaoQ(_ language: AppLanguage) -> String {
        language == .chinese ? "显示小Q" : "Show Q"
    }

    static func hide(_ language: AppLanguage) -> String {
        language == .chinese ? "隐身" : "Hide"
    }

    static func quit(_ language: AppLanguage) -> String {
        language == .chinese ? "退出" : "Quit"
    }

    static func close(_ language: AppLanguage) -> String {
        language == .chinese ? "关闭" : "Close"
    }

    static func theme(_ language: AppLanguage) -> String {
        language == .chinese ? "主题色" : "Theme"
    }

    static func language(_ language: AppLanguage) -> String {
        language == .chinese ? "语言" : "Language"
    }

    static func panelLanguage(_ language: AppLanguage) -> String {
        language == .chinese ? "面板显示语言" : "Panel language"
    }

    static func displayName(_ language: AppLanguage) -> String {
        language == .chinese ? "显示名称" : "Display name"
    }

    static func displayNamePlaceholder(_ language: AppLanguage) -> String {
        defaultAppName(language)
    }

    static func logoImage(_ language: AppLanguage) -> String {
        language == .chinese ? "头像图片" : "Logo image"
    }

    static func chooseLogo(_ language: AppLanguage) -> String {
        language == .chinese ? "选择图片" : "Choose"
    }

    static func resetLogo(_ language: AppLanguage) -> String {
        language == .chinese ? "恢复默认" : "Reset"
    }

    static func logoUpdateFailed(_ language: AppLanguage) -> String {
        language == .chinese ? "头像图片更新失败" : "Logo update failed"
    }

    static func appearanceSubtitle(_ language: AppLanguage) -> String {
        language == .chinese ? "选择小Q面板和提醒气泡的颜色" : "Choose the panel and reminder bubble color"
    }

    static func defaultAppName(_ language: AppLanguage) -> String {
        language == .chinese ? "小Q" : "Hi, Q"
    }

    static func restoreBuddy(_ name: String, language: AppLanguage) -> String {
        language == .chinese ? "显示\(name)" : "Show \(name)"
    }

    static func reminderTitle(_ name: String, language: AppLanguage) -> String {
        language == .chinese ? "\(name)提醒" : "\(name) Reminder"
    }

    static func tasks(_ language: AppLanguage) -> String {
        language == .chinese ? "任务" : "Tasks"
    }

    static func rest(_ language: AppLanguage) -> String {
        language == .chinese ? "休息" : "Rest"
    }

    static func openRest(_ language: AppLanguage) -> String {
        language == .chinese ? "打开休息提醒" : "Open rest reminders"
    }

    static func backToTasks(_ language: AppLanguage) -> String {
        language == .chinese ? "回到任务" : "Back to tasks"
    }

    static func active(_ language: AppLanguage) -> String {
        language == .chinese ? "进行中" : "Active"
    }

    static func completed(_ language: AppLanguage) -> String {
        language == .chinese ? "已完成" : "Done"
    }

    static func nextReminder(_ language: AppLanguage) -> String {
        language == .chinese ? "下个提醒" : "Next"
    }

    static func none(_ language: AppLanguage) -> String {
        language == .chinese ? "无" : "None"
    }

    static func headerSubtitle(activeCount: Int, section: PanelSection, language: AppLanguage) -> String {
        if section == .focus {
            return language == .chinese ? "让小Q提醒你及时放松" : "Let Q remind you to pause"
        }
        return randomTaskHeaderSubtitle(language: language)
    }

    static func randomTaskHeaderSubtitle(language: AppLanguage, excluding current: String? = nil) -> String {
        let subtitles = taskHeaderSubtitles(language)
        let candidates = subtitles.filter { $0 != current }
        return (candidates.randomElement() ?? subtitles.randomElement()) ?? ""
    }

    private static func taskHeaderSubtitles(_ language: AppLanguage) -> [String] {
        switch language {
        case .chinese:
            return [
                "今天向前一步，光就近一点。",
                "把热爱落在行动里。",
                "心里有光，脚下有路。",
                "去做吧，答案在路上。",
                "让今天比昨天更有回响。",
                "带着好心情，把小事做好。",
                "每一次开始，都在靠近更好的自己。",
                "先动起来，风也会来帮你。",
                "把普通一天过出亮光。",
                "今天的努力，会成为明天的底气。",
                "眼里有方向，手上有行动。",
                "向阳而行，步履不停。",
                "认真做事的人，自带光芒。",
                "把计划写下，把行动交给现在。",
                "今日份进步，从这一件事开始。",
                "追光的人，也会成为光。",
                "不负清晨，也不负此刻。",
                "让心情放晴，让事情推进。",
                "小小一步，也有新的可能。",
                "今天适合发光，也适合完成。",
                "保持热爱，稳稳向前。",
                "把期待变成行动。",
                "趁阳光正好，做点漂亮的事。",
                "一点点认真，会把日子照亮。",
                "你只管向前，路会慢慢清晰。",
                "让今天有开始，也有收获。",
                "心向远方，先做好眼前。",
                "好状态，从完成一件小事开始。",
                "每个当下，都是新的起点。",
                "今天也要闪闪发光地前进。"
            ]
        case .english:
            return [
                "Put what you love into action.",
                "Begin now; the answer is on the way.",
                "Start moving, and the wind will meet you.",
                "Give an ordinary day a little shine.",
                "Those who chase light can become light.",
                "Honor the morning, and honor this moment.",
                "Today is good for shining and finishing.",
                "Keep the love, keep moving steadily.",
                "Stay hungry, stay foolish.",
                "Turn expectation into action.",
                "A little care can light up the day.",
                "Every moment is a fresh starting point.",
                "Move forward with a little sparkle today."
            ]
        }
    }

    static func todoPlaceholder(_ language: AppLanguage) -> String {
        language == .chinese ? "写下一件要做的事" : "Write the next thing to do"
    }

    static func stopVoiceInput(_ language: AppLanguage) -> String {
        language == .chinese ? "停止语音输入" : "Stop voice input"
    }

    static func voiceInput(_ language: AppLanguage) -> String {
        language == .chinese ? "语音输入" : "Voice input"
    }

    static func addTodo(_ language: AppLanguage) -> String {
        language == .chinese ? "添加待办" : "Add todo"
    }

    static func todoAdded(_ language: AppLanguage) -> String {
        language == .chinese ? "记下来了。现在只要做下一小步。" : "Noted. Now just take the next small step."
    }

    static func markUndone(_ language: AppLanguage) -> String {
        language == .chinese ? "标记为未完成" : "Mark as not done"
    }

    static func markDone(_ language: AppLanguage) -> String {
        language == .chinese ? "标记完成" : "Mark done"
    }

    static func reminderIn15Minutes(_ language: AppLanguage) -> String {
        language == .chinese ? "15 分钟后" : "In 15 minutes"
    }

    static func reminderIn30Minutes(_ language: AppLanguage) -> String {
        language == .chinese ? "30 分钟后" : "In 30 minutes"
    }

    static func reminderIn1Hour(_ language: AppLanguage) -> String {
        language == .chinese ? "1 小时后" : "In 1 hour"
    }

    static func custom(_ language: AppLanguage) -> String {
        language == .chinese ? "自定义..." : "Custom..."
    }

    static func clearReminder(_ language: AppLanguage) -> String {
        language == .chinese ? "清除提醒" : "Clear reminder"
    }

    static func setReminder(_ language: AppLanguage) -> String {
        language == .chinese ? "设置提醒" : "Set reminder"
    }

    static func reminder(_ language: AppLanguage) -> String {
        language == .chinese ? "提醒" : "Reminder"
    }

    static func edit(_ language: AppLanguage) -> String {
        language == .chinese ? "编辑" : "Edit"
    }

    static func moreActions(_ language: AppLanguage) -> String {
        language == .chinese ? "更多操作" : "More actions"
    }

    static func delete(_ language: AppLanguage) -> String {
        language == .chinese ? "删除" : "Delete"
    }

    static func customReminder(_ language: AppLanguage) -> String {
        language == .chinese ? "自定义提醒" : "Custom Reminder"
    }

    static func reminderTime(_ language: AppLanguage) -> String {
        language == .chinese ? "提醒时间" : "Reminder time"
    }

    static func cancel(_ language: AppLanguage) -> String {
        language == .chinese ? "取消" : "Cancel"
    }

    static func save(_ language: AppLanguage) -> String {
        language == .chinese ? "保存" : "Save"
    }

    static func localSaved(_ language: AppLanguage) -> String {
        language == .chinese ? "本地保存" : "Saved locally"
    }

    static func restReminder(_ language: AppLanguage) -> String {
        language == .chinese ? "休息提醒" : "Rest Reminder"
    }

    static func breakStatus(enabled: Bool, minutes: Int, language: AppLanguage) -> String {
        if !enabled {
            return language == .chinese ? "已暂停" : "Paused"
        }
        return language == .chinese ? "每 \(minutes) 分钟提醒一次" : "Every \(minutes) minutes"
    }

    static func interval(_ language: AppLanguage) -> String {
        language == .chinese ? "间隔" : "Interval"
    }

    static func minutes(_ minutes: Int, language: AppLanguage) -> String {
        language == .chinese ? "\(minutes) 分钟" : "\(minutes) min"
    }

    static func emptyTitle(_ language: AppLanguage) -> String {
        language == .chinese ? "还没有待办" : "No todos yet"
    }

    static func emptySubtitle(_ language: AppLanguage) -> String {
        language == .chinese ? "先写一件最小的事。" : "Write down one small thing first."
    }
}
