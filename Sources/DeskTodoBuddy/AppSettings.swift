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

    var onChange: (() -> Void)?

    private enum Keys {
        static let theme = "appTheme"
        static let language = "appLanguage"
    }

    init() {
        let storedTheme = UserDefaults.standard.string(forKey: Keys.theme)
        theme = storedTheme.flatMap(AppTheme.init(rawValue:)) ?? .green

        let storedLanguage = UserDefaults.standard.string(forKey: Keys.language)
        language = storedLanguage.flatMap(AppLanguage.init(rawValue:)) ?? .chinese
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

    static func appearanceSubtitle(_ language: AppLanguage) -> String {
        language == .chinese ? "选择小Q面板和提醒气泡的颜色" : "Choose the panel and reminder bubble color"
    }

    static func appName(_ language: AppLanguage) -> String {
        language == .chinese ? "小Q" : "Hi, Q"
    }

    static func reminderTitle(_ language: AppLanguage) -> String {
        language == .chinese ? "小Q提醒" : "Q Reminder"
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
        if activeCount == 0 {
            return language == .chinese ? "今天先放一件小事进去" : "Start with one small thing today"
        }
        return language == .chinese ? "当前还有 \(activeCount) 件事待推进" : "\(activeCount) item\(activeCount == 1 ? "" : "s") in progress"
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
