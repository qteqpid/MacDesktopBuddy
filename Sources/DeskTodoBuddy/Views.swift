import AppKit
import SwiftUI

enum BuddyIconImageProvider {
    static func loadImage() -> NSImage? {
        for path in candidatePaths() {
            if let image = NSImage(contentsOfFile: NSString(string: path).expandingTildeInPath) {
                return image
            }
        }

        return nil
    }

    private static func candidatePaths() -> [String] {
        var paths: [String] = []

        if let path = ProcessInfo.processInfo.environment["DESK_TODO_BUDDY_ICON"],
           !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            paths.append(path)
        }

        let currentDirectory = FileManager.default.currentDirectoryPath
        paths.append("\(currentDirectory)/Resources/BuddyIcon.png")

        if let resourcePath = Bundle.main.resourcePath {
            paths.append("\(resourcePath)/BuddyIcon.png")
            paths.append("\(resourcePath)/Resources/BuddyIcon.png")
        }

        if let executablePath = Bundle.main.executablePath {
            let executableURL = URL(fileURLWithPath: executablePath)
            let nearbyResources = executableURL
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Resources/BuddyIcon.png")
            paths.append(nearbyResources.path)
        }

        return paths
    }
}

enum PanelIconImageProvider {
    static func loadImage() -> NSImage? {
        for path in candidatePaths() {
            if let image = NSImage(contentsOfFile: NSString(string: path).expandingTildeInPath) {
                return image
            }
        }
        return nil
    }

    private static func candidatePaths() -> [String] {
        var paths: [String] = []
        let currentDirectory = FileManager.default.currentDirectoryPath
        paths.append("\(currentDirectory)/Resources/PanelIcon.jpg")

        if let resourcePath = Bundle.main.resourcePath {
            paths.append("\(resourcePath)/PanelIcon.jpg")
            paths.append("\(resourcePath)/Resources/PanelIcon.jpg")
        }

        paths.append("~/Downloads/qteqpid_avatar.jpg")
        return paths
    }
}

struct FloatingIconView: View {
    @ObservedObject var store: TodoStore
    @ObservedObject var reminders: ReminderCoordinator

    @State private var isHovering = false
    @State private var isBobbing = false
    private let iconImage = BuddyIconImageProvider.loadImage()

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ZStack {
                if let iconImage {
                    Image(nsImage: iconImage)
                        .resizable()
                        .scaledToFit()
                } else {
                    BuiltInBuddyIcon()
                }
            }
            .frame(width: 86, height: 86)
            .scaleEffect(isHovering ? 1.05 : 1.0)
            .offset(y: isBobbing ? -5 : 3)
        }
        .frame(width: 104, height: 104)
        .contentShape(Rectangle())
        .background(Color.clear)
        .help("拖动移动，点击打开 DeskTodoBuddy")
        .onHover { isHovering = $0 }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                isBobbing = true
            }
        }
    }
}

struct BuiltInBuddyIcon: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.09, green: 0.09, blue: 0.10),
                            Color(red: 0.22, green: 0.22, blue: 0.24)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            Circle()
                .fill(.white.opacity(0.95))
                .frame(width: 28, height: 28)
                .offset(x: -12, y: -12)
            Circle()
                .fill(.white.opacity(0.95))
                .frame(width: 28, height: 28)
                .offset(x: 12, y: -12)
            Circle()
                .fill(.black)
                .frame(width: 8, height: 8)
                .offset(x: -8, y: -10)
            Circle()
                .fill(.black)
                .frame(width: 8, height: 8)
                .offset(x: 8, y: -10)
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(Color(red: 1.0, green: 0.79, blue: 0.12))
                .offset(y: 22)
        }
    }
}

enum PanelSection: String, CaseIterable, Identifiable {
    case tasks = "任务"
    case focus = "休息"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .tasks: return "checklist"
        case .focus: return "cup.and.saucer.fill"
        }
    }
}

enum PanelPalette {
    static let ink = Color(nsColor: .labelColor)
    static let secondaryInk = Color(nsColor: .secondaryLabelColor)
    static let panelStroke = Color(nsColor: .separatorColor).opacity(0.48)
    static let panelFill = Color(nsColor: .windowBackgroundColor).opacity(0.72)
    static let surface = Color(nsColor: .controlBackgroundColor).opacity(0.72)
    static let row = Color(nsColor: .textBackgroundColor).opacity(0.82)
    static let amber = Color(red: 0.95, green: 0.62, blue: 0.18)
    static let coral = Color(red: 0.94, green: 0.34, blue: 0.28)
    static let mint = Color(red: 0.29, green: 0.64, blue: 0.54)
    static let softGreenBackground = Color(red: 0.94, green: 0.98, blue: 0.95)
    static let softGreenHighlight = Color(red: 0.82, green: 0.94, blue: 0.87)
    static let violet = Color(red: 0.48, green: 0.43, blue: 0.88)

    static func themeAccent(_ theme: AppTheme) -> Color {
        switch theme {
        case .green: return mint
        case .pink: return Color(red: 0.86, green: 0.38, blue: 0.55)
        }
    }

    static func themeBackground(_ theme: AppTheme) -> Color {
        switch theme {
        case .green: return softGreenBackground
        case .pink: return Color(red: 0.99, green: 0.90, blue: 0.93)
        }
    }

    static func themeHighlight(_ theme: AppTheme) -> Color {
        switch theme {
        case .green: return softGreenHighlight
        case .pink: return Color(red: 0.96, green: 0.72, blue: 0.80)
        }
    }
}

struct TodoPanelView: View {
    @ObservedObject var store: TodoStore
    @ObservedObject var settings: AppSettings
    @ObservedObject var reminders: ReminderCoordinator
    @StateObject private var speech = SpeechInputController()

    @State private var draft = ""
    @FocusState private var isDraftFocused: Bool

    let showSettings: () -> Void
    let refocusPanel: () -> Void
    let closePanel: () -> Void

    private var nextReminder: Date? {
        store.activeItems.compactMap(\.reminderDate).filter { $0 > Date() }.min()
    }

    var body: some View {
        VStack(spacing: 0) {
            PanelHeaderView(
                activeCount: store.activeItems.count,
                completedCount: store.completedItems.count,
                nextReminder: nextReminder,
                breakRemindersEnabled: reminders.breakRemindersEnabled,
                settings: settings,
                showSettings: showSettings,
                closePanel: closePanel
            )

            tasksSection
            .padding(.horizontal, 18)
            .padding(.bottom, 16)
        }
        .frame(width: 472, height: 640)
        .background(panelBackground)
    }

    private var tasksSection: some View {
        VStack(spacing: 14) {
            TodoComposerView(
                draft: $draft,
                isDraftFocused: $isDraftFocused,
                speech: speech,
                settings: settings,
                refocusPanel: refocusPanel,
                addTodo: addTodo
            )

            TodoListView(store: store, settings: settings, showSettings: showSettings)

            PanelBottomBar(store: store, settings: settings)
        }
    }

    private var panelBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.regularMaterial)

            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            PanelPalette.themeBackground(settings.theme).opacity(0.94),
                            PanelPalette.themeBackground(settings.theme).opacity(0.84),
                            PanelPalette.themeHighlight(settings.theme).opacity(0.34)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 0) {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                PanelPalette.themeHighlight(settings.theme).opacity(0.36),
                                PanelPalette.themeAccent(settings.theme).opacity(0.16),
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 150)
                Spacer()
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(PanelPalette.panelStroke, lineWidth: 1)
        }
    }

    private func addTodo() {
        let normalized = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        speech.stop()
        guard !normalized.isEmpty else { return }

        store.add(title: normalized, reminderDate: nil)
        reminders.show(AppStrings.todoAdded(settings.language))
        draft = ""
        isDraftFocused = true
    }
}

struct PanelHeaderView: View {
    let activeCount: Int
    let completedCount: Int
    let nextReminder: Date?
    let breakRemindersEnabled: Bool
    @ObservedObject var settings: AppSettings
    let showSettings: () -> Void
    let closePanel: () -> Void
    private let panelIcon = PanelIconImageProvider.loadImage()
    @State private var taskSubtitle = ""

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                PanelHeaderIconView(image: panelIcon)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 9) {
                        Text(AppStrings.appName(settings.language))
                            .font(.system(size: 21, weight: .semibold))
                            .foregroundStyle(PanelPalette.ink)

                        Button(action: showSettings) {
                            HStack(spacing: 5) {
                                CoffeeReminderIcon(steaming: breakRemindersEnabled)
                                Text(AppStrings.rest(settings.language))
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundStyle(PanelPalette.ink)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(PanelPalette.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(PanelPalette.panelStroke, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .help(AppStrings.settings(settings.language))
                    }

                    Text(headerSubtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(PanelPalette.secondaryInk)
                        .lineLimit(1)
                }

                Spacer()

                Button(action: showSettings) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(PanelPalette.secondaryInk)
                        .frame(width: 28, height: 28)
                        .background(PanelPalette.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .help(AppStrings.settings(settings.language))

                Button(action: closePanel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(PanelPalette.secondaryInk)
                        .frame(width: 28, height: 28)
                        .background(PanelPalette.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .help(AppStrings.close(settings.language))
            }

            HStack(spacing: 10) {
                HeaderMetricView(title: AppStrings.active(settings.language), value: "\(activeCount)", tint: PanelPalette.themeAccent(settings.theme), iconName: "circle.dotted")
                HeaderMetricView(title: AppStrings.completed(settings.language), value: "\(completedCount)", tint: PanelPalette.violet, iconName: "checkmark")
                HeaderMetricView(title: AppStrings.nextReminder(settings.language), value: nextReminderText, tint: PanelPalette.coral, iconName: "bell.fill")
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 14)
        .onAppear {
            refreshTaskSubtitleIfNeeded()
        }
        .onChange(of: settings.language) { _ in
            refreshTaskSubtitle()
        }
    }

    private var headerSubtitle: String {
        if !taskSubtitle.isEmpty {
            return taskSubtitle
        }
        return AppStrings.headerSubtitle(activeCount: activeCount, section: .tasks, language: settings.language)
    }

    private func refreshTaskSubtitleIfNeeded() {
        guard taskSubtitle.isEmpty else { return }
        refreshTaskSubtitle()
    }

    private func refreshTaskSubtitle() {
        taskSubtitle = AppStrings.randomTaskHeaderSubtitle(language: settings.language, excluding: taskSubtitle)
    }

    private var nextReminderText: String {
        guard let nextReminder else { return AppStrings.none(settings.language) }
        return nextReminder.formatted(date: .omitted, time: .shortened)
    }
}

struct PanelHeaderIconView: View {
    let image: NSImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(PanelPalette.ink.opacity(0.92))

            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(PanelPalette.amber)
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct SettingsPanelView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var reminders: ReminderCoordinator
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 12) {
                Text(AppStrings.settings(settings.language))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(PanelPalette.ink)

                Spacer()

                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(PanelPalette.secondaryInk)
                        .frame(width: 28, height: 28)
                        .background(PanelPalette.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .help(AppStrings.close(settings.language))
            }

            VStack(alignment: .leading, spacing: 12) {
                SettingsSection {
                    RestReminderSettingsCard(reminders: reminders, settings: settings)
                }

                SettingsSection {
                    VStack(alignment: .leading, spacing: 14) {
                        SettingsRow(title: AppStrings.theme(settings.language), systemImage: "paintpalette.fill", theme: settings.theme) {
                            Picker("", selection: $settings.theme) {
                                ForEach(AppTheme.allCases) { theme in
                                    Text(theme.displayName(language: settings.language)).tag(theme)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 240)
                        }

                        Divider()

                        SettingsRow(title: AppStrings.panelLanguage(settings.language), systemImage: "character.bubble.fill", theme: settings.theme) {
                            Picker("", selection: $settings.language) {
                                ForEach(AppLanguage.allCases) { language in
                                    Text(language.displayName).tag(language)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 240)
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(width: 520, height: 500)
        .background(settingsBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(PanelPalette.panelStroke, lineWidth: 1)
        )
    }

    private var settingsBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.regularMaterial)
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            PanelPalette.themeBackground(settings.theme).opacity(0.94),
                            PanelPalette.themeHighlight(settings.theme).opacity(0.28)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
}

struct SettingsSection<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(14)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(PanelPalette.panelStroke, lineWidth: 1)
            )
    }
}

struct SettingsRow<Content: View>: View {
    let title: String
    let systemImage: String
    let theme: AppTheme
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(PanelPalette.themeAccent(theme))
                .frame(width: 28, height: 28)
                .background(PanelPalette.themeAccent(theme).opacity(0.13))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(PanelPalette.ink)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            Spacer(minLength: 24)

            content()
                .frame(width: 240, alignment: .trailing)
        }
    }
}

struct CoffeeReminderIcon: View {
    let steaming: Bool

    @State private var isBreathing = false

    var body: some View {
        ZStack {
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 11, weight: .semibold))
                .offset(y: steaming ? 3 : 1)

            if steaming {
                HStack(spacing: 2) {
                    steamLine(delay: 0)
                    steamLine(delay: 0.12)
                    steamLine(delay: 0.24)
                }
                .offset(y: isBreathing ? -5 : -3)
                .opacity(isBreathing ? 0.72 : 0.38)
            }
        }
        .frame(width: 17, height: 14)
        .onAppear {
            guard steaming else { return }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                isBreathing = true
            }
        }
        .onChange(of: steaming) { enabled in
            if enabled {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    isBreathing = true
                }
            } else {
                isBreathing = false
            }
        }
    }

    private func steamLine(delay: Double) -> some View {
        Capsule()
            .fill(PanelPalette.ink.opacity(0.74))
            .frame(width: 1.4, height: 5)
            .offset(y: isBreathing ? -1 - delay * 2 : 0)
    }
}

struct HeaderMetricView: View {
    let title: String
    let value: String
    let tint: Color
    let iconName: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 20, height: 20)
                .background(tint.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PanelPalette.ink)
                    .lineLimit(1)
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(PanelPalette.secondaryInk)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(PanelPalette.panelStroke, lineWidth: 1)
        )
    }
}

struct AssistantNoteView: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: "sparkles")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(PanelPalette.amber)
                .frame(width: 28, height: 28)
                .background(PanelPalette.amber.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(PanelPalette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(PanelPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(PanelPalette.panelStroke, lineWidth: 1)
        )
    }
}

struct ReminderBubbleView: View {
    let message: String
    @ObservedObject var settings: AppSettings
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            HStack(alignment: .top, spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(PanelPalette.amber.opacity(0.18))
                    Image(systemName: "bell.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(PanelPalette.amber)
                }
                .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 5) {
                    Text(AppStrings.reminderTitle(settings.language))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(PanelPalette.secondaryInk)
                    Text(message)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(PanelPalette.ink)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(.trailing, 28)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(PanelPalette.secondaryInk)
                    .frame(width: 24, height: 24)
                    .background(.white.opacity(0.56))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(AppStrings.close(settings.language))
            .padding(.top, 6)
            .padding(.trailing, 6)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(width: 318, height: 92)
        .background(
            ZStack {
                Rectangle()
                    .fill(.regularMaterial)
                LinearGradient(
                    colors: [
                        PanelPalette.themeBackground(settings.theme).opacity(0.78),
                        PanelPalette.themeHighlight(settings.theme).opacity(0.28)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(PanelPalette.panelStroke, lineWidth: 1)
        )
    }
}

struct TodoComposerView: View {
    @Binding var draft: String
    var isDraftFocused: FocusState<Bool>.Binding

    @ObservedObject var speech: SpeechInputController
    @ObservedObject var settings: AppSettings
    @State private var recordingPulse = false

    let refocusPanel: () -> Void
    let addTodo: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PanelPalette.themeAccent(settings.theme))

                TextField(AppStrings.todoPlaceholder(settings.language), text: $draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(PanelPalette.ink)
                    .focused(isDraftFocused)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .onSubmit(addTodo)

                Button {
                    Task {
                        await speech.toggle { text in
                            guard speech.isRecording else { return }
                            draft = text
                            isDraftFocused.wrappedValue = true
                        }
                        refocusPanel()
                        isDraftFocused.wrappedValue = true
                    }
                } label: {
                    ZStack {
                        if speech.isRecording {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(PanelPalette.coral.opacity(recordingPulse ? 0.26 : 0.08))
                                .frame(width: recordingPulse ? 40 : 30, height: recordingPulse ? 40 : 30)
                        }

                        Image(systemName: speech.isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(speech.isRecording ? .white : PanelPalette.ink)
                            .frame(width: 30, height: 30)
                            .background(speech.isRecording ? PanelPalette.coral : Color(nsColor: .textBackgroundColor).opacity(0.75))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .scaleEffect(speech.isRecording && recordingPulse ? 1.05 : 1.0)
                    }
                    .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)
                .help(speech.isRecording ? AppStrings.stopVoiceInput(settings.language) : AppStrings.voiceInput(settings.language))
                .onChange(of: speech.isRecording) { isRecording in
                    if isRecording {
                        withAnimation(.easeInOut(duration: 0.95).repeatForever(autoreverses: true)) {
                            recordingPulse = true
                        }
                    } else {
                        withAnimation(.easeOut(duration: 0.18)) {
                            recordingPulse = false
                        }
                    }
                }

                Button(action: addTodo) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 30)
                        .background(canAdd ? PanelPalette.themeAccent(settings.theme) : PanelPalette.secondaryInk.opacity(0.35))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .help(AppStrings.addTodo(settings.language))
                .disabled(!canAdd)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(nsColor: .textBackgroundColor).opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isDraftFocused.wrappedValue ? PanelPalette.themeAccent(settings.theme).opacity(0.75) : PanelPalette.panelStroke, lineWidth: 1)
            )
        }
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(PanelPalette.panelStroke, lineWidth: 1)
        )
    }

    private var canAdd: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct TodoListView: View {
    @ObservedObject var store: TodoStore
    @ObservedObject var settings: AppSettings
    let showSettings: () -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                if store.activeItems.isEmpty && store.completedItems.isEmpty {
                    EmptyTodoView(settings: settings)
                        .padding(.vertical, 46)
                } else {
                    ForEach(store.activeItems) { item in
                        TodoRow(item: item, store: store, settings: settings, showSettings: showSettings)
                            .id("active-\(item.id.uuidString)")
                    }

                    if !store.completedItems.isEmpty {
                        SectionDividerView(title: AppStrings.completed(settings.language))
                            .padding(.top, 4)

                        ForEach(store.completedItems) { item in
                            TodoRow(item: item, store: store, settings: settings, showSettings: showSettings, displayAsCompleted: true)
                                .id("completed-\(item.id.uuidString)")
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .frame(maxHeight: .infinity)
    }
}

struct SectionDividerView: View {
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(PanelPalette.secondaryInk)
            Rectangle()
                .fill(PanelPalette.panelStroke)
                .frame(height: 1)
        }
    }
}

struct TodoRow: View {
    let item: TodoItem
    @ObservedObject var store: TodoStore
    @ObservedObject var settings: AppSettings
    let showSettings: () -> Void
    var displayAsCompleted = false

    @State private var isEditingTitle = false
    @State private var editedTitle = ""
    @FocusState private var isTitleEditorFocused: Bool

    private var isDue: Bool {
        guard let reminderDate = item.reminderDate else { return false }
        return reminderDate <= Date() && !item.isDone
    }

    private var isCompletedStyle: Bool {
        item.isDone || displayAsCompleted
    }

    var body: some View {
        HStack(alignment: .center, spacing: 11) {
            Button {
                store.toggle(item)
            } label: {
                Image(systemName: isCompletedStyle ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(isCompletedStyle ? PanelPalette.themeAccent(settings.theme) : PanelPalette.secondaryInk)
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .help(isCompletedStyle ? AppStrings.markUndone(settings.language) : AppStrings.markDone(settings.language))

            VStack(alignment: .leading, spacing: 6) {
                if isEditingTitle {
                    HStack(spacing: 6) {
                        TextField("", text: $editedTitle, axis: .vertical)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(PanelPalette.ink)
                            .focused($isTitleEditorFocused)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color(nsColor: .textBackgroundColor).opacity(0.95))
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .stroke(PanelPalette.themeAccent(settings.theme).opacity(0.75), lineWidth: 1)
                            )
                            .onSubmit(commitTitleEdit)
                            .onExitCommand(perform: cancelTitleEdit)
                            .onAppear {
                                isTitleEditorFocused = true
                            }

                        Button(action: commitTitleEdit) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 22, height: 22)
                                .background(canCommitTitleEdit ? PanelPalette.themeAccent(settings.theme) : PanelPalette.secondaryInk.opacity(0.35))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .disabled(!canCommitTitleEdit)
                        .help(AppStrings.save(settings.language))

                        Button(action: cancelTitleEdit) {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(PanelPalette.secondaryInk)
                                .frame(width: 22, height: 22)
                                .background(Color(nsColor: .textBackgroundColor).opacity(0.75))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help(AppStrings.cancel(settings.language))
                    }
                } else {
                    Text(item.title)
                        .font(.system(size: 13, weight: .semibold))
                        .strikethrough(isCompletedStyle)
                        .foregroundStyle(isCompletedStyle ? PanelPalette.secondaryInk : PanelPalette.ink)
                        .textSelection(.enabled)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let reminderDate = item.reminderDate, !isCompletedStyle {
                    ReminderBadgeView(date: reminderDate, isDue: isDue)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 8)

            TodoRowActions(
                item: item,
                store: store,
                settings: settings,
                showSettings: showSettings,
                edit: beginTitleEdit,
                isCompleted: isCompletedStyle,
                hasReminder: item.reminderDate != nil
            )
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .background(PanelPalette.row)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isDue && !isCompletedStyle ? PanelPalette.coral.opacity(0.58) : PanelPalette.panelStroke, lineWidth: 1)
        )
        .opacity(isCompletedStyle ? 0.58 : 1)
    }

    private func beginTitleEdit() {
        editedTitle = item.title
        isEditingTitle = true
    }

    private var canCommitTitleEdit: Bool {
        !editedTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func commitTitleEdit() {
        guard isEditingTitle else { return }
        guard canCommitTitleEdit else { return }
        store.updateTitle(for: item, title: editedTitle)
        isEditingTitle = false
    }

    private func cancelTitleEdit() {
        guard isEditingTitle else { return }
        editedTitle = item.title
        isEditingTitle = false
    }
}

struct ReminderBadgeView: View {
    let date: Date
    let isDue: Bool

    var body: some View {
        Label(date.formatted(date: .abbreviated, time: .shortened), systemImage: isDue ? "bell.badge.fill" : "bell.fill")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(isDue ? PanelPalette.coral : PanelPalette.amber)
            .lineLimit(1)
    }
}

struct TodoRowActions: View {
    let item: TodoItem
    @ObservedObject var store: TodoStore
    @ObservedObject var settings: AppSettings
    let showSettings: () -> Void
    let edit: () -> Void
    var isCompleted = false
    var hasReminder = false

    @State private var showingCustomReminder = false
    @State private var customReminderDate = Date().addingTimeInterval(30 * 60)

    var body: some View {
        HStack(spacing: 4) {
            if !isCompleted {
                Menu {
                    Button(role: .destructive) {
                        withAnimation(.easeOut(duration: 0.14)) {
                            store.delete(item)
                        }
                    } label: {
                        Label(AppStrings.delete(settings.language), systemImage: "trash")
                    }

                    Button {
                        edit()
                    } label: {
                        Label(AppStrings.edit(settings.language), systemImage: "pencil")
                    }

                    Menu {
                        Button(AppStrings.reminderIn15Minutes(settings.language)) {
                            store.updateReminder(for: item, reminderDate: Date().addingTimeInterval(15 * 60))
                        }
                        Button(AppStrings.reminderIn30Minutes(settings.language)) {
                            store.updateReminder(for: item, reminderDate: Date().addingTimeInterval(30 * 60))
                        }
                        Button(AppStrings.reminderIn1Hour(settings.language)) {
                            store.updateReminder(for: item, reminderDate: Date().addingTimeInterval(60 * 60))
                        }

                        Divider()

                        Button(AppStrings.custom(settings.language)) {
                            customReminderDate = item.reminderDate ?? Date().addingTimeInterval(30 * 60)
                            showingCustomReminder = true
                        }

                        if hasReminder {
                            Divider()
                            Button(AppStrings.clearReminder(settings.language)) {
                                store.updateReminder(for: item, reminderDate: nil)
                            }
                        }
                    } label: {
                        Label(AppStrings.reminder(settings.language), systemImage: hasReminder ? "bell.fill" : "bell.badge")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(PanelPalette.secondaryInk)
                        .frame(width: 28, height: 28)
                        .background(Color(nsColor: .textBackgroundColor).opacity(0.75))
                        .clipShape(Circle())
                }
                .menuStyle(.borderlessButton)
                .help(AppStrings.moreActions(settings.language))
                .popover(isPresented: $showingCustomReminder, arrowEdge: .trailing) {
                    CustomReminderPopoverView(
                        reminderDate: $customReminderDate,
                        settings: settings,
                        cancel: {
                            showingCustomReminder = false
                        },
                        save: {
                            store.updateReminder(for: item, reminderDate: ReminderTiming.customReminderDate(from: customReminderDate))
                            showingCustomReminder = false
                        }
                    )
                }
            } else {
                Button {
                    withAnimation(.easeOut(duration: 0.14)) {
                        store.delete(item)
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(PanelPalette.secondaryInk)
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .help(AppStrings.delete(settings.language))
            }
        }
    }
}

struct CustomReminderPopoverView: View {
    @Binding var reminderDate: Date
    @ObservedObject var settings: AppSettings

    let cancel: () -> Void
    let save: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PanelPalette.amber)
                Text(AppStrings.customReminder(settings.language))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PanelPalette.ink)
            }

            DatePicker(
                AppStrings.reminderTime(settings.language),
                selection: $reminderDate,
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.compact)
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                Button(AppStrings.cancel(settings.language), action: cancel)
                    .buttonStyle(.borderless)

                Spacer()

                Button(AppStrings.save(settings.language), action: save)
                    .buttonStyle(.borderedProminent)
                    .tint(PanelPalette.themeAccent(settings.theme))
            }
        }
        .padding(14)
        .frame(width: 340)
    }
}

struct PanelBottomBar: View {
    @ObservedObject var store: TodoStore
    @ObservedObject var settings: AppSettings

    var body: some View {
        UtilityBottomBar(error: store.lastError, settings: settings)
    }
}

struct UtilityBottomBar: View {
    let error: String?
    @ObservedObject var settings: AppSettings

    var body: some View {
        HStack(spacing: 8) {
            Spacer()

            if let error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(PanelPalette.coral)
                    .lineLimit(1)
            } else {
                Label(AppStrings.localSaved(settings.language), systemImage: "externaldrive.fill.badge.checkmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(PanelPalette.secondaryInk)
            }
        }
        .frame(height: 30)
    }
}

struct RestReminderSettingsCard: View {
    @ObservedObject var reminders: ReminderCoordinator
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "figure.mind.and.body")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(PanelPalette.themeAccent(settings.theme))
                    .frame(width: 38, height: 38)
                    .background(PanelPalette.themeAccent(settings.theme).opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(AppStrings.restReminder(settings.language))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(PanelPalette.ink)
                    Text(AppStrings.breakStatus(enabled: reminders.breakRemindersEnabled, minutes: reminders.breakIntervalMinutes, language: settings.language))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(PanelPalette.secondaryInk)
                }

                Spacer()

                Toggle("", isOn: $reminders.breakRemindersEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(AppStrings.interval(settings.language))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(PanelPalette.secondaryInk)
                    Spacer()
                    Text(AppStrings.minutes(reminders.breakIntervalMinutes, language: settings.language))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(PanelPalette.ink)
                }

                Slider(
                    value: Binding(
                        get: { Double(reminders.breakIntervalMinutes) },
                        set: { reminders.setBreakIntervalMinutes(Int(($0 / 5).rounded()) * 5) }
                    ),
                    in: 15...120,
                    step: 5
                )
                .disabled(!reminders.breakRemindersEnabled)
            }

            HStack(spacing: 8) {
                BreakPresetButton(title: "25", selected: reminders.breakIntervalMinutes == 25) {
                    reminders.setBreakIntervalMinutes(25)
                }
                BreakPresetButton(title: "50", selected: reminders.breakIntervalMinutes == 50) {
                    reminders.setBreakIntervalMinutes(50)
                }
                BreakPresetButton(title: "90", selected: reminders.breakIntervalMinutes == 90) {
                    reminders.setBreakIntervalMinutes(90)
                }
            }
            .disabled(!reminders.breakRemindersEnabled)
            .opacity(reminders.breakRemindersEnabled ? 1 : 0.48)
        }
    }
}

struct FocusPanelView: View {
    @ObservedObject var reminders: ReminderCoordinator
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(spacing: 14) {
            RestReminderSettingsCard(reminders: reminders, settings: settings)
            Spacer()

            UtilityBottomBar(error: nil, settings: settings)
        }
    }
}

struct BreakPresetButton: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(selected ? .white : PanelPalette.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(selected ? PanelPalette.ink : PanelPalette.row)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct EmptyTodoView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(PanelPalette.themeAccent(settings.theme).opacity(0.13))
                Image(systemName: "checklist")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(PanelPalette.themeAccent(settings.theme))
            }
            .frame(width: 54, height: 54)

            VStack(spacing: 4) {
                Text(AppStrings.emptyTitle(settings.language))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(PanelPalette.ink)
                Text(AppStrings.emptySubtitle(settings.language))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(PanelPalette.secondaryInk)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
