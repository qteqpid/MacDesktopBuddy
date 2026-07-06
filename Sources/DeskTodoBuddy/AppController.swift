import AppKit
import SwiftUI

final class BuddyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private func makeLightHostingView<Content: View>(_ rootView: Content) -> NSHostingView<AnyView> {
    NSHostingView(rootView: AnyView(rootView.preferredColorScheme(.light)))
}

final class FloatingIconHostingView: NSHostingView<FloatingIconView> {
    private var dragIcon: (CGSize) -> Void = { _ in }
    private var finishIconDrag: (CGSize, Bool) -> Void = { _, _ in }
    private var showIconMenu: (NSPoint) -> Void = { _ in }
    private var mouseDownLocation: NSPoint?
    private var longPressWorkItem: DispatchWorkItem?
    private var shouldIgnoreMouseUp = false
    private var didDragIcon = false

    override var isOpaque: Bool { false }

    required init(rootView: FloatingIconView) {
        super.init(rootView: rootView)
        configureTransparency()
    }

    init(
        rootView: FloatingIconView,
        dragIcon: @escaping (CGSize) -> Void,
        finishIconDrag: @escaping (CGSize, Bool) -> Void,
        showIconMenu: @escaping (NSPoint) -> Void
    ) {
        self.dragIcon = dragIcon
        self.finishIconDrag = finishIconDrag
        self.showIconMenu = showIconMenu
        super.init(rootView: rootView)
        configureTransparency()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.isOpaque = false
        window?.backgroundColor = .clear
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownLocation = NSEvent.mouseLocation
        shouldIgnoreMouseUp = false
        didDragIcon = false
        if event.type == .rightMouseDown || event.modifierFlags.contains(.control) {
            mouseDownLocation = nil
            shouldIgnoreMouseUp = true
            didDragIcon = false
            showContextMenu()
            return
        }

        let workItem = DispatchWorkItem { [weak self] in
            self?.showContextMenu()
        }
        longPressWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7, execute: workItem)
    }

    override func mouseDragged(with event: NSEvent) {
        longPressWorkItem?.cancel()
        guard let mouseDownLocation else { return }
        let current = NSEvent.mouseLocation
        let translation = CGSize(
            width: current.x - mouseDownLocation.x,
            height: current.y - mouseDownLocation.y
        )
        if hypot(translation.width, translation.height) > 3 {
            didDragIcon = true
        }
        dragIcon(translation)
    }

    override func mouseUp(with event: NSEvent) {
        longPressWorkItem?.cancel()
        guard !shouldIgnoreMouseUp else {
            shouldIgnoreMouseUp = false
            mouseDownLocation = nil
            didDragIcon = false
            return
        }
        guard let mouseDownLocation else {
            finishIconDrag(.zero, didDragIcon)
            return
        }

        let current = NSEvent.mouseLocation
        let didDragIcon = self.didDragIcon
        self.mouseDownLocation = nil
        self.didDragIcon = false
        finishIconDrag(CGSize(
            width: current.x - mouseDownLocation.x,
            height: current.y - mouseDownLocation.y
        ), didDragIcon)
    }

    override func rightMouseDown(with event: NSEvent) {
        mouseDownLocation = nil
        shouldIgnoreMouseUp = true
        didDragIcon = false
        showContextMenu()
    }

    private func configureTransparency() {
        wantsLayer = true
        layer?.isOpaque = false
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    private func showContextMenu() {
        longPressWorkItem?.cancel()
        mouseDownLocation = nil
        shouldIgnoreMouseUp = true
        didDragIcon = false
        showIconMenu(NSEvent.mouseLocation)
    }
}

@MainActor
final class AppController: NSObject, NSApplicationDelegate {
    private let store = TodoStore()
    private let settings = AppSettings()
    private let notificationScheduler = NotificationScheduler()
    private lazy var reminders = ReminderCoordinator(store: store)

    private var iconWindow: NSWindow?
    private var todoPanel: BuddyPanel?
    private var settingsPanel: BuddyPanel?
    private var reminderBubblePanel: NSPanel?
    private var reminderBubbleDismissTask: Task<Void, Never>?
    private var statusItem: NSStatusItem?
    private var iconDragStartOrigin: NSPoint?
    private var isIconHidden = AppPreferences.isIconHidden
    private var lastIconClickAt: Date?
    private var lastPanelOpenedAt: Date?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        settings.onChange = { [weak self] in
            self?.refreshMenus()
        }
        createStatusItem()

        store.onItemsChanged = { [weak self] items in
            Task { @MainActor in
                self?.notificationScheduler.schedule(items: items)
            }
        }

        notificationScheduler.requestAuthorization()
        notificationScheduler.schedule(items: store.items)
        observeWorkspaceSessionChanges()

        createIconWindow()
        createTodoPanel()
        applyIconVisibility()

        reminders.onTimedReminder = { [weak self] text in
            self?.showReminderBubble(text)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        speechCleanup()
    }

    private func observeWorkspaceSessionChanges() {
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(
            self,
            selector: #selector(resetBreakTimerAfterSessionResume),
            name: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(resetBreakTimerAfterSessionResume),
            name: NSWorkspace.screensDidWakeNotification,
            object: nil
        )
    }

    @objc private func resetBreakTimerAfterSessionResume() {
        reminders.resetBreakTimer()
    }

    func toggleTodoPanel() {
        guard let todoPanel else { return }

        if todoPanel.isVisible {
            if let lastPanelOpenedAt, Date().timeIntervalSince(lastPanelOpenedAt) < 0.8 {
                return
            }
            todoPanel.orderOut(nil)
            return
        }

        positionTodoPanel()
        todoPanel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        lastPanelOpenedAt = Date()
    }

    func closeTodoPanel() {
        todoPanel?.orderOut(nil)
    }

    private func createIconWindow() {
        let size = NSSize(width: 112, height: 112)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.appearance = NSAppearance(named: .aqua)
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.ignoresMouseEvents = false

        let view = FloatingIconView(
            store: store,
            reminders: reminders
        )
        window.contentView = FloatingIconHostingView(
            rootView: view,
            dragIcon: { [weak self] translation in
                self?.dragIcon(translation: translation)
            },
            finishIconDrag: { [weak self] translation, didDrag in
                self?.finishIconDrag(translation: translation, didDrag: didDrag)
            },
            showIconMenu: { [weak self] point in
                self?.showIconContextMenu(at: point)
            }
        )
        iconWindow = window

        positionIconWindow()
        window.orderFrontRegardless()
    }

    private func createStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = makeStatusBarIcon()
        item.button?.imagePosition = .imageOnly
        item.button?.toolTip = "小Q"

        statusItem = item
        refreshMenus()
        updateStatusItemVisibility()
    }

    private func refreshMenus() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: AppStrings.restoreXiaoQ(settings.language), action: #selector(restoreIconFromMenu), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: AppStrings.settings(settings.language), action: #selector(showSettingsFromMenu), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: AppStrings.quit(settings.language), action: #selector(quitFromMenu), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        statusItem?.menu = menu
    }

    private func makeStatusBarIcon() -> NSImage? {
        guard let source = BuddyIconImageProvider.loadImage() else {
            return NSImage(systemSymbolName: "bird.fill", accessibilityDescription: "小Q")
        }

        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()
        source.draw(
            in: NSRect(origin: .zero, size: size),
            from: .zero,
            operation: .sourceOver,
            fraction: 1
        )
        image.unlockFocus()
        image.isTemplate = false
        image.accessibilityDescription = "小Q"
        return image
    }

    @objc private func restoreIconFromMenu() {
        restoreIcon()
    }

    @objc private func showSettingsFromMenu() {
        showSettingsPanel()
    }

    @objc private func quitFromMenu() {
        NSApp.terminate(nil)
    }

    private func createTodoPanel() {
        let size = NSSize(width: 472, height: 640)
        let panel = BuddyPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.appearance = NSAppearance(named: .aqua)
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false

        let view = TodoPanelView(
            store: store,
            settings: settings,
            reminders: reminders,
            showSettings: { [weak self] in
                self?.showSettingsPanel()
            },
            refocusPanel: { [weak self] in
                self?.refocusTodoPanelAfterSystemPrompt()
            },
            closePanel: { [weak self] in
                self?.closeTodoPanel()
            }
        )
        panel.contentView = makeLightHostingView(view)
        todoPanel = panel
        positionTodoPanel()
    }

    private func refocusTodoPanelAfterSystemPrompt() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self, let todoPanel else { return }
            positionTodoPanel()
            todoPanel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            lastPanelOpenedAt = Date()
        }
    }

    private func positionIconWindow() {
        guard let iconWindow else { return }
        let visibleFrame = NSScreen.main?.visibleFrame ?? NSScreen.screens.first?.visibleFrame ?? .zero
        let frame = iconWindow.frame
        let defaultOrigin = NSPoint(
            x: visibleFrame.maxX - frame.width - 24,
            y: visibleFrame.minY + 24
        )
        let origin = AppPreferences.iconWindowOrigin ?? defaultOrigin
        iconWindow.setFrameOrigin(clampedIconOrigin(origin))
    }

    private func positionTodoPanel() {
        guard let todoPanel else { return }
        let visibleFrame = screenForIcon()?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSScreen.screens.first?.visibleFrame ?? .zero
        let size = todoPanel.frame.size
        let iconFrame = iconWindow?.frame ?? .zero

        let preferredX = iconFrame.maxX - size.width
        let preferredAboveY = iconFrame.maxY + 8
        let preferredBelowY = iconFrame.minY - size.height - 8
        let y = preferredAboveY + size.height <= visibleFrame.maxY
            ? preferredAboveY
            : preferredBelowY

        todoPanel.setFrameOrigin(NSPoint(
            x: min(max(preferredX, visibleFrame.minX + 12), visibleFrame.maxX - size.width - 12),
            y: min(max(y, visibleFrame.minY + 12), visibleFrame.maxY - size.height - 12)
        ))
    }

    private func dragIcon(translation: CGSize) {
        guard let iconWindow else { return }
        if iconDragStartOrigin == nil {
            iconDragStartOrigin = iconWindow.frame.origin
        }

        guard let start = iconDragStartOrigin else { return }
        let proposed = NSPoint(
            x: start.x + translation.width,
            y: start.y + translation.height
        )
        iconWindow.setFrameOrigin(clampedIconOrigin(proposed))
        if todoPanel?.isVisible == true {
            positionTodoPanel()
        }
        if reminderBubblePanel?.isVisible == true {
            positionReminderBubble()
        }
    }

    private func finishIconDrag(translation: CGSize, didDrag: Bool) {
        defer { iconDragStartOrigin = nil }

        if !didDrag && hypot(translation.width, translation.height) < 5 {
            handleIconClick()
            return
        }

        if let origin = iconWindow?.frame.origin {
            AppPreferences.iconWindowOrigin = origin
        }
    }

    private func handleIconClick() {
        let now = Date()
        if let lastIconClickAt, now.timeIntervalSince(lastIconClickAt) < 0.5 {
            return
        }
        lastIconClickAt = now

        ReminderSoundPlayer.shared.stop()
        dismissReminderBubble()
        toggleTodoPanel()
    }

    private func showIconContextMenu(at point: NSPoint) {
        let menu = NSMenu()
        let settingsItem = NSMenuItem(title: AppStrings.settings(settings.language), action: #selector(showSettingsFromMenu), keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(NSMenuItem.separator())

        let hideItem = NSMenuItem(title: AppStrings.hide(settings.language), action: #selector(hideIconFromMenu), keyEquivalent: "")
        hideItem.target = self
        menu.addItem(hideItem)
        menu.popUp(positioning: hideItem, at: point, in: nil)
    }

    @objc private func hideIconFromMenu() {
        hideIcon()
    }

    private func hideIcon() {
        isIconHidden = true
        AppPreferences.isIconHidden = true
        applyIconVisibility()
    }

    private func restoreIcon() {
        isIconHidden = false
        AppPreferences.isIconHidden = false
        applyIconVisibility()
    }

    private func applyIconVisibility() {
        if isIconHidden {
            iconWindow?.orderOut(nil)
            todoPanel?.orderOut(nil)
            dismissReminderBubble()
            ReminderSoundPlayer.shared.stop()
        } else {
            positionIconWindow()
            iconWindow?.orderFrontRegardless()
        }
        updateStatusItemVisibility()
    }

    private func showSettingsPanel() {
        let size = NSSize(width: 520, height: 300)
        let panel = settingsPanel ?? BuddyPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.setContentSize(size)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.appearance = NSAppearance(named: .aqua)
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.contentView = makeLightHostingView(SettingsPanelView(settings: settings) { [weak self] in
            self?.settingsPanel?.orderOut(nil)
        })
        settingsPanel = panel
        positionSettingsPanel()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func positionSettingsPanel() {
        guard let settingsPanel else { return }
        let visibleFrame = screenForIcon()?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSScreen.screens.first?.visibleFrame ?? .zero
        let size = settingsPanel.frame.size
        let sourceFrame = todoPanel?.isVisible == true ? todoPanel?.frame ?? .zero : iconWindow?.frame ?? .zero
        let x = min(max(sourceFrame.maxX - size.width, visibleFrame.minX + 12), visibleFrame.maxX - size.width - 12)
        let preferredY = sourceFrame.maxY - size.height
        let y = min(max(preferredY, visibleFrame.minY + 12), visibleFrame.maxY - size.height - 12)
        settingsPanel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func dismissReminderBubble() {
        reminderBubbleDismissTask?.cancel()
        reminderBubbleDismissTask = nil
        reminderBubblePanel?.orderOut(nil)
    }

    private func updateStatusItemVisibility() {
        statusItem?.isVisible = isIconHidden
    }

    private func clampedIconOrigin(_ origin: NSPoint) -> NSPoint {
        guard let iconWindow else { return origin }
        let visibleFrame = screenForPoint(origin)?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        let size = iconWindow.frame.size
        return NSPoint(
            x: min(max(origin.x, visibleFrame.minX + 4), visibleFrame.maxX - size.width - 4),
            y: min(max(origin.y, visibleFrame.minY + 4), visibleFrame.maxY - size.height - 4)
        )
    }

    private func screenForIcon() -> NSScreen? {
        guard let iconFrame = iconWindow?.frame else { return NSScreen.main }
        return NSScreen.screens.first { $0.visibleFrame.intersects(iconFrame) } ?? NSScreen.main
    }

    private func screenForPoint(_ point: NSPoint) -> NSScreen? {
        NSScreen.screens.first { $0.visibleFrame.contains(point) } ?? NSScreen.main
    }

    private func showReminderBubble(_ text: String) {
        reminderBubbleDismissTask?.cancel()

        let size = NSSize(width: 318, height: 92)
        let panel = reminderBubblePanel ?? NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.setContentSize(size)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.appearance = NSAppearance(named: .aqua)
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isReleasedWhenClosed = false
        panel.ignoresMouseEvents = false
        panel.contentView = makeLightHostingView(ReminderBubbleView(message: text, settings: settings) { [weak self] in
            ReminderSoundPlayer.shared.stop()
            self?.dismissReminderBubble()
        })
        reminderBubblePanel = panel

        positionReminderBubble()
        panel.orderFrontRegardless()

        reminderBubbleDismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 20_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.reminderBubblePanel?.orderOut(nil)
            }
        }
    }

    private func positionReminderBubble() {
        guard let reminderBubblePanel else { return }

        if isIconHidden {
            let visibleFrame = NSScreen.main?.visibleFrame ?? NSScreen.screens.first?.visibleFrame ?? .zero
            let size = reminderBubblePanel.frame.size
            reminderBubblePanel.setFrameOrigin(NSPoint(
                x: visibleFrame.maxX - size.width - 18,
                y: visibleFrame.maxY - size.height - 18
            ))
            return
        }

        guard let iconWindow else { return }

        let visibleFrame = screenForIcon()?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        let iconFrame = iconWindow.frame
        let size = reminderBubblePanel.frame.size
        let gap: CGFloat = 10

        let shouldPlaceRight = iconFrame.midX < visibleFrame.midX
        let preferredX = shouldPlaceRight ? iconFrame.maxX + gap : iconFrame.minX - size.width - gap
        let preferredY = iconFrame.midY - size.height / 2

        reminderBubblePanel.setFrameOrigin(NSPoint(
            x: min(max(preferredX, visibleFrame.minX + 10), visibleFrame.maxX - size.width - 10),
            y: min(max(preferredY, visibleFrame.minY + 10), visibleFrame.maxY - size.height - 10)
        ))
    }

    private func speechCleanup() {
        // SpeechInputController instances live in SwiftUI. This hook is kept for future app-level teardown.
    }
}
