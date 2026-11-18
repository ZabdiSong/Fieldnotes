import AppKit
import SwiftUI

// Dominant pixels sampled from the user's Display P3 reference swatches.
let paper = Color(.displayP3, red: 248.0 / 255, green: 215.0 / 255, blue: 85.0 / 255)
let blue = Color(.displayP3, red: 39.0 / 255, green: 93.0 / 255, blue: 245.0 / 255)
let canvas = Color.white
let outline = Color(red: 0.88, green: 0.90, blue: 0.94)
let ink = Color(red: 0.06, green: 0.12, blue: 0.23)

@MainActor
final class PlannerLifecycle: NSObject, NSApplicationDelegate {
    let widget = TodayWidgetController()
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let url = Bundle.main.url(forResource: "Fieldnotes", withExtension: "icns"), let icon = NSImage(contentsOf: url) {
            NSApp.applicationIconImage = icon
        }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationWillTerminate(_ notification: Notification) { widget.stop() }
}

@main
struct FieldnotesApp: App {
    @StateObject private var store = PlannerStore()
    @NSApplicationDelegateAdaptor(PlannerLifecycle.self) private var lifecycle
    @Environment(\.openWindow) private var openWindow
    var body: some Scene {
        Window("Fieldnotes", id: "planner") {
            PlannerView(store: store)
                .preferredColorScheme(.light).fontDesign(.rounded)
                .environment(\.timeZone, PlanLogic.calendar.timeZone)
                .environment(\.calendar, PlanLogic.calendar)
                .onAppear { connect() }
        }
        .defaultSize(width: 1000, height: 720)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New task") { store.editor = .task(PlanTask()) }.keyboardShortcut("n")
            }
            CommandMenu("Planner") {
                Toggle("Today's desktop widget", isOn: $store.desktopVisible)
                Button("Import school assignments") { store.importSchool() }
            }
        }
        MenuBarExtra("Fieldnotes", systemImage: "calendar") {
            Button("Open planner") { openWindow(id: "planner"); NSApp.activate(ignoringOtherApps: true) }
            Toggle("Today's desktop widget", isOn: $store.desktopVisible)
            Button("Go to today") { store.jumpDate = Date(); openWindow(id: "planner"); NSApp.activate(ignoringOtherApps: true) }
            Divider()
            Button("Quit Fieldnotes") { NSApp.terminate(nil) }.keyboardShortcut("q")
        }
    }
    private func connect() {
        let open = openWindow
        lifecycle.widget.attach(store: store) { day in
            store.jumpDate = day
            open(id: "planner")
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

struct PlannerWindowSetup: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { NSView() }
    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator { weak var window: NSWindow? }
    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = view.window, context.coordinator.window !== window else { return }
            context.coordinator.window = window
            window.backgroundColor = .white
            window.titlebarAppearsTransparent = true
            window.aspectRatio = NSSize(width: 4, height: 3)
            window.minSize = NSSize(width: 880, height: 660)
            let frame = window.screen?.visibleFrame ?? NSScreen.main!.visibleFrame
            let width = min(1040, frame.width - 30, (frame.height - 30) * 4 / 3)
            let size = NSSize(width: width, height: width * 3 / 4)
            window.setFrame(NSRect(x: frame.midX - size.width / 2, y: frame.midY - size.height / 2,
                                   width: size.width, height: size.height), display: true)
        }
    }
}
