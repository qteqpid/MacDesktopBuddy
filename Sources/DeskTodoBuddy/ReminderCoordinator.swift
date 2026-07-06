import AppKit
import Foundation

@MainActor
final class ReminderCoordinator: ObservableObject {
    @Published var currentMessage = BuddyMessage(text: "小Q在这里，今天也一点点推进就好。")
    @Published var breakRemindersEnabled: Bool {
        didSet {
            UserDefaults.standard.set(breakRemindersEnabled, forKey: Keys.breakRemindersEnabled)
            resetBreakTimer()
        }
    }
    @Published private(set) var breakIntervalMinutes: Int
    var onTimedReminder: ((String) -> Void)?

    private enum Keys {
        static let breakRemindersEnabled = "breakRemindersEnabled"
        static let breakIntervalMinutes = "breakIntervalMinutes"
    }

    private static let tickInterval: TimeInterval = 5
    private let store: TodoStore
    private var timer: Timer?
    private var nextBreakAt: Date
    private var remindedTodoIDs: Set<UUID>
    private var messageIndex = 0

    private let breakMessages = [
        "小Q提醒你：眼睛眨一眨，肩膀放一放，世界不会趁这十秒跑掉。",
        "先喝一口水吧，脑袋也喜欢被温柔照顾。",
        "工作暂停一下，给自己按个小小的“保存进度”。",
        "站起来走两步，像给身体重新开机。",
        "你已经专注很久啦，小Q批准你发呆一分钟。",
        "手腕转一转，脖子慢慢动一动，别让努力变成僵硬。",
        "深呼吸三次，把刚才的紧绷慢慢吐出去。",
        "休息不是偷懒，是给下一段认真充电。",
        "喝点水，看看远处，顺便夸一下今天还在坚持的自己。",
        "小Q探头：该把眉头松开啦。",
        "离开屏幕一下，让眼睛去窗外散个步。",
        "你不用一直绷着，慢一点也还是在往前走。",
        "如果脑子开始打结，就先给自己一分钟空白。",
        "起来活动一下吧，身体已经默默陪你工作很久了。",
        "今天的你已经很努力了，现在轮到你照顾一下自己。",
        "先别急着继续，喝水、伸展、呼吸，一件一件来。",
        "小Q给你递一杯想象中的热茶：休息一下再出发。",
        "把屏幕放远一点，把注意力收回来一点。",
        "现在适合做一个小暂停，让心情也缓一缓。",
        "你不是机器，是需要休息也值得被照顾的人。",
        "小Q戳戳你：再不眨眼，屏幕要以为你爱上它了。",
        "休息时间到，请把自己从椅子上轻轻拔起来。",
        "小Q检测到：你的肩膀正在偷偷申请假期。",
        "喝口水吧，你的脑细胞刚刚发来了缺水工单。",
        "眼睛放风一分钟，不然它们要开始罢工啦。",
        "站起来转一圈，证明你不是桌面插件。",
        "小Q提示：当前任务可暂停，当前人类需保养。",
        "伸个懒腰吧，顺便重启一下你的可爱能量。",
        "别卷了别卷了，先给身体发点工资。",
        "你的脖子说它有话要讲：咔咔不是正常沟通方式。",
        "小Q命令你：放下手头的事，先把水喝了。",
        "眼睛离开屏幕一分钟，这是命令，不是建议。",
        "你可以努力，但不准把自己耗坏，听见了吗？",
        "站起来，肩膀放松，别让我说第二遍。",
        "小Q批准你休息三分钟，回来继续漂亮地解决问题。",
        "先呼吸，再继续。真正厉害的人懂得掌控节奏。",
        "你的身体不是工具，是本女王重点保护对象。",
        "别硬撑。能长期稳定输出，才叫真正的强。",
        "现在去走两步，回来把这件事拿下。",
        "休息一下，调整状态。你不是来被任务支配的。"
    ]

    init(store: TodoStore, autoStart: Bool = true) {
        self.store = store
        let storedInterval = UserDefaults.standard.integer(forKey: Keys.breakIntervalMinutes)
        let initialInterval = storedInterval == 0 ? 50 : ReminderTiming.normalizedBreakInterval(storedInterval)
        breakIntervalMinutes = initialInterval
        breakRemindersEnabled = UserDefaults.standard.object(forKey: Keys.breakRemindersEnabled) as? Bool ?? true
        nextBreakAt = Date().addingTimeInterval(TimeInterval(initialInterval * 60))
        remindedTodoIDs = AppPreferences.remindedTodoIDs
        if autoStart {
            start()
        }
    }

    deinit {
        timer?.invalidate()
    }

    func show(_ text: String, playSound: Bool = false) {
        currentMessage = BuddyMessage(text: text)
        if playSound {
            ReminderSoundPlayer.shared.play()
            onTimedReminder?(text)
        }
    }

    func setBreakIntervalMinutes(_ minutes: Int) {
        let normalized = ReminderTiming.normalizedBreakInterval(minutes)
        guard breakIntervalMinutes != normalized else { return }
        breakIntervalMinutes = normalized
        UserDefaults.standard.set(normalized, forKey: Keys.breakIntervalMinutes)
        resetBreakTimer()
    }

    func resetBreakTimer() {
        nextBreakAt = Date().addingTimeInterval(TimeInterval(breakIntervalMinutes * 60))
    }

    private func start() {
        let timer = Timer(timeInterval: Self.tickInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        timer.tolerance = 0.2
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        tick(now: Date())
    }

    func dueTaskReminder(now: Date = Date()) -> String? {
        remindedTodoIDs = AppPreferences.remindedTodoIDs

        for item in store.dueItems(now: now) where !remindedTodoIDs.contains(item.id) {
            guard let reminderDate = item.reminderDate,
                  ReminderTiming.shouldDeliverTaskReminder(now: now, reminderDate: reminderDate) else {
                continue
            }

            remindedTodoIDs.insert(item.id)
            AppPreferences.remindedTodoIDs = remindedTodoIDs
            return item.title
        }

        return nil
    }

    private func tick(now: Date) {
        if let taskReminder = dueTaskReminder(now: now) {
            show(taskReminder, playSound: true)
            return
        }

        guard breakRemindersEnabled, now >= nextBreakAt else { return }
        show(nextBreakMessage(), playSound: true)
        resetBreakTimer()
    }

    private func nextBreakMessage() -> String {
        let message = breakMessages[messageIndex % breakMessages.count]
        messageIndex += 1
        return message
    }
}

final class ReminderSoundPlayer {
    static let shared = ReminderSoundPlayer()

    private var sound: NSSound?

    private init() {
        sound = Self.loadSound()
    }

    func play() {
        guard let sound else {
            NSSound(named: "Glass")?.play()
            return
        }

        if sound.isPlaying {
            sound.stop()
        }
        sound.currentTime = 0
        sound.play()
    }

    func stop() {
        sound?.stop()
        sound?.currentTime = 0
    }

    private static func loadSound() -> NSSound? {
        for path in candidatePaths() {
            let expanded = NSString(string: path).expandingTildeInPath
            if let sound = NSSound(contentsOfFile: expanded, byReference: false) {
                sound.volume = 0.9
                return sound
            }
        }
        return nil
    }

    private static func candidatePaths() -> [String] {
        var paths: [String] = []
        let currentDirectory = FileManager.default.currentDirectoryPath
        paths.append("\(currentDirectory)/Resources/ReminderSound.wav")

        if let resourcePath = Bundle.main.resourcePath {
            paths.append("\(resourcePath)/ReminderSound.wav")
            paths.append("\(resourcePath)/Resources/ReminderSound.wav")
        }

        paths.append("~/Desktop/ios开发/class-table/class-table/pretty-soft-notification.wav")
        return paths
    }
}
