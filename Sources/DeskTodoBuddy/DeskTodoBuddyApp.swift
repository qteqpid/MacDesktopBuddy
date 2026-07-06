import AppKit

@main
struct DeskTodoBuddyApp {
    @MainActor private static var controller: AppController?

    @MainActor
    static func main() {
        let app = NSApplication.shared
        app.appearance = NSAppearance(named: .aqua)
        let controller = AppController()
        Self.controller = controller
        app.delegate = controller
        app.run()
    }
}
