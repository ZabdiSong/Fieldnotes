import AppKit
import SwiftUI
import Combine

@MainActor
final class TodayWidgetController: NSObject, NSWindowDelegate {
    private var panel: NSPanel?
    private var visibility: AnyCancellable?
    private weak var store: PlannerStore?
    private var openPlanner: ((Date) -> Void)?
    func attach(store: PlannerStore, openPlanner: @escaping (Date) -> Void) {
        self.openPlanner = openPlanner
        guard self.store !== store else { return }
        self.store = store
        visibility = store.$desktopVisible.removeDuplicates().sink { [weak self] visible in
            DispatchQueue.main.async { self?.setVisible(visible) }
        }
    }
    func stop() { visibility?.cancel(); panel?.orderOut(nil); panel = nil }
    private func setVisible(_ visible: Bool) {
        guard visible, let store else { panel?.orderOut(nil); return }
        if panel == nil {
            let savedSize = UserDefaults.standard.array(forKey: "todayCalendarSize") as? [Double]
            let size = NSSize(width: min(640, max(260, savedSize?.first ?? 344)),
                              height: min(600, max(150, savedSize?.last ?? 200)))
            let window = DesktopCalendarPanel(contentRect: NSRect(origin: .zero, size: size),
                styleMask: [.borderless, .nonactivatingPanel, .resizable], backing: .buffered, defer: false)
            window.title = "Fieldnotes · Today"
            window.minSize = NSSize(width: 260, height: 150)
            window.maxSize = NSSize(width: 640, height: 600)
            window.identifier = NSUserInterfaceItemIdentifier("fieldnotes-today-widget")
            window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            window.hidesOnDeactivate = false
            window.canHide = false
            window.isReleasedWhenClosed = false
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = true
            window.delegate = self
            window.contentView = DesktopCalendarHost(rootView: TodayCalendarWidget(store: store) { [weak self] day in
                self?.openPlanner?(day)
            }.frame(maxWidth: .infinity, maxHeight: .infinity))
            let screens = NSScreen.screens
            let screen = NSScreen.main ?? screens[0]
            let saved = UserDefaults.standard.array(forKey: "todayCalendarPosition") as? [Double]
            var origin = NSPoint(x: screen.visibleFrame.maxX - size.width - 20, y: screen.visibleFrame.minY + 24)
            if let saved, saved.count == 2, saved.allSatisfy(\.isFinite) {
                let previousSize = UserDefaults.standard.array(forKey: "todayCalendarSize") as? [Double]
                let previousHeight = previousSize?.last ?? 270
                let candidate = NSPoint(x: saved[0], y: saved[1] + previousHeight - size.height)
                if let target = screens.first(where: { $0.visibleFrame.contains(candidate) }) {
                    let x = candidate.x < target.visibleFrame.minX + 60 ? target.visibleFrame.minX + 16 : candidate.x
                    origin = NSPoint(x: min(max(target.visibleFrame.minX, x), target.visibleFrame.maxX - size.width),
                                     y: min(max(target.visibleFrame.minY, candidate.y), target.visibleFrame.maxY - size.height))
                }
            }
            window.setFrameOrigin(origin)
            UserDefaults.standard.set([origin.x, origin.y], forKey: "todayCalendarPosition")
            UserDefaults.standard.set([size.width, size.height], forKey: "todayCalendarSize")
            panel = window
        }
        panel?.orderFrontRegardless()
    }
    func windowDidResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        UserDefaults.standard.set([window.frame.width, window.frame.height], forKey: "todayCalendarSize")
    }
    func windowDidMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window.isVisible else { return }
        UserDefaults.standard.set([window.frame.origin.x, window.frame.origin.y], forKey: "todayCalendarPosition")
    }
}

private final class DesktopCalendarPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
private final class DesktopCalendarHost<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

private struct TodayCalendarWidget: View {
    @ObservedObject var store: PlannerStore
    let open: (Date) -> Void
    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let today = PlanLogic.calendar.startOfDay(for: context.date)
            let entries = PlanLogic.entries(in: PlanLogic.dayInterval(today), data: store.data)
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    ZStack(alignment: .leading) {
                        HStack(spacing: 7) {
                            Circle().fill(paper).frame(width: 7, height: 7)
                            Text("TODAY").font(.system(size: 10, weight: .bold)).foregroundStyle(blue)
                            Text(PlanLogic.label(today, format: "EEE, MMM d")).font(.system(size: 12, weight: .semibold))
                        }
                        WidgetDragArea()
                    }.frame(maxWidth: .infinity, alignment: .leading).frame(height: 22)
                    Button { open(today) } label: { Image(systemName: "arrow.up.right") }.help("Open today's calendar")
                    Button { store.desktopVisible = false } label: { Image(systemName: "xmark") }.help("Hide desktop widget")
                }.buttonStyle(.plain).font(.system(size: 10))
                Divider()
                ScrollViewReader { reader in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            if entries.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("A little room in your day.").font(.system(size: 13, weight: .semibold))
                                    Text("Open the planner to add an arrangement.").font(.system(size: 10)).foregroundStyle(.secondary)
                                }.padding(.vertical, 8)
                            }
                            ForEach(entries) { entry in
                                Button { open(today); store.edit(entry) } label: {
                                    HStack(alignment: .top, spacing: 9) {
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(PlanLogic.label(entry.start, format: "HH:mm")).font(.system(size: 11, weight: .semibold, design: .monospaced))
                                            Text(PlanLogic.label(entry.end, format: "HH:mm")).font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary)
                                        }.frame(width: 42, alignment: .leading)
                                        RoundedRectangle(cornerRadius: 2).fill(entry.kind == .task ? blue : paper).frame(width: 3, height: 28)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(entry.title).font(.system(size: 11, weight: .medium)).lineLimit(1).strikethrough(entry.crossedOut || entry.done)
                                            Text(entry.badge).font(.system(size: 9)).foregroundStyle(.secondary)
                                        }.frame(maxWidth: .infinity, alignment: .leading)
                                    }.opacity(entry.crossedOut ? 0.5 : 1).contentShape(Rectangle())
                                }.buttonStyle(.plain).id(entry.id)
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }.onAppear { scrollToCurrent(reader, entries: entries, now: context.date) }
                        .onChange(of: today) { _, _ in scrollToCurrent(reader, entries: entries, now: context.date) }
                }
                let due = store.pending.filter { $0.due.map { PlanLogic.calendar.isDate($0, inSameDayAs: today) } == true }.count
                HStack {
                    Text("\(due) due · Beijing time").foregroundStyle(.secondary)
                    Spacer()
                    Button("Open planner →") { open(today) }.buttonStyle(.plain).foregroundStyle(blue)
                }.font(.system(size: 9))
            }.padding(12).padding(.bottom, 5).background(canvas, in: RoundedRectangle(cornerRadius: 18))
                .overlay(alignment: .bottomTrailing) {
                    WidgetResizeArea().frame(width: 18, height: 18).padding(3)
                }
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(outline))
        }.foregroundStyle(ink).tint(blue).preferredColorScheme(.light).fontDesign(.rounded)
    }
    private func scrollToCurrent(_ reader: ScrollViewProxy, entries: [CalendarEntry], now: Date) {
        if let entry = entries.first(where: { !$0.crossedOut && $0.end > now }) ?? entries.last {
            reader.scrollTo(entry.id, anchor: .top)
        }
    }
}
private struct WidgetDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> WidgetDragView { WidgetDragView() }
    func updateNSView(_ nsView: WidgetDragView, context: Context) {}
}
private final class WidgetDragView: NSView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .openHand) }
    override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
}

private struct WidgetResizeArea: NSViewRepresentable {
    func makeNSView(context: Context) -> WidgetResizeView { WidgetResizeView() }
    func updateNSView(_ view: WidgetResizeView, context: Context) {}
}
private final class WidgetResizeView: NSView {
    private var initialFrame = NSRect.zero
    private var initialMouse = NSPoint.zero
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.systemBlue.withAlphaComponent(0.65).setStroke()
        for offset in [4.0, 9.0] {
            let path = NSBezierPath()
            path.move(to: NSPoint(x: bounds.maxX - offset - 3, y: 3))
            path.line(to: NSPoint(x: bounds.maxX - 3, y: offset + 3))
            path.lineWidth = 1.5; path.stroke()
        }
    }
    override func mouseDown(with event: NSEvent) {
        initialFrame = window?.frame ?? .zero; initialMouse = NSEvent.mouseLocation
    }
    override func mouseDragged(with event: NSEvent) {
        guard let window else { return }
        let mouse = NSEvent.mouseLocation
        let screen = window.screen?.visibleFrame ?? initialFrame
        let width = min(window.maxSize.width, screen.maxX - initialFrame.minX,
                        max(window.minSize.width, initialFrame.width + mouse.x - initialMouse.x))
        let height = min(window.maxSize.height, initialFrame.maxY - screen.minY,
                         max(window.minSize.height, initialFrame.height - mouse.y + initialMouse.y))
        window.setFrame(NSRect(x: initialFrame.minX, y: initialFrame.maxY - height, width: width, height: height), display: true)
    }
}
