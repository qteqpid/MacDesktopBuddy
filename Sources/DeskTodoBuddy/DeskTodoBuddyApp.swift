import AppKit

@main
struct DeskTodoBuddyApp {
    @MainActor private static var controller: AppController?

    @MainActor
    static func main() {
        let app = NSApplication.shared
        let controller = AppController()
        Self.controller = controller
        app.delegate = controller
        app.run()
    }
}
