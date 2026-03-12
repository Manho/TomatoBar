import SwiftUI
import LaunchAtLogin

extension NSImage.Name {
    static let idle = Self("BarIconIdle")
    static let work = Self("BarIconWork")
    static let shortRest = Self("BarIconShortRest")
    static let longRest = Self("BarIconLongRest")
}

private let digitFont = NSFont.monospacedDigitSystemFont(ofSize: 0, weight: .regular)

@main
struct TBApp: App {
    @NSApplicationDelegateAdaptor(TBStatusItem.self) var appDelegate

    init() {
        TBStatusItem.shared = appDelegate
        LaunchAtLogin.migrateIfNeeded()
        logger.append(event: TBLogEventAppStart())
    }

    var body: some Scene {
        Settings {}
    }
}

class TBClockWindowController: NSObject, ObservableObject, NSWindowDelegate {
    @Published private(set) var isVisible = false
    @Published var isPinned: Bool {
        didSet {
            UserDefaults.standard.set(isPinned, forKey: Self.pinPreferenceKey)
            applyPinning()
        }
    }

    private static let pinPreferenceKey = "clockWindowPinned"
    private static let widthPreferenceKey = "clockWindowWidth"
    private static let heightPreferenceKey = "clockWindowHeight"
    private static let defaultContentSize = NSSize(width: 360, height: 500)
    private static let minimumContentSize = NSSize(width: 148, height: 150)
    private let timer: TBTimer
    private var window: NSWindow?

    init(timer: TBTimer) {
        self.timer = timer
        isPinned = UserDefaults.standard.bool(forKey: Self.pinPreferenceKey)
        super.init()
    }

    func toggle() {
        isVisible ? hide() : show()
    }

    func show() {
        let window = getWindow()
        applyPinning()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        isVisible = true
    }

    func hide() {
        window?.orderOut(nil)
        isVisible = false
    }

    func windowWillClose(_: Notification) {
        isVisible = false
    }

    func windowDidResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window == self.window else {
            return
        }

        saveWindowContentSize(window.contentRect(forFrameRect: window.frame).size)
    }

    private func getWindow() -> NSWindow {
        if let window {
            return window
        }

        let hostingController = NSHostingController(
            rootView: TBClockWindowView(timer: timer, controller: self)
        )
        let window = NSWindow(contentViewController: hostingController)
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.title = "TomatoBar Clock"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.isMovableByWindowBackground = true
        window.minSize = Self.minimumContentSize
        window.setContentSize(restoredContentSize())
        window.center()

        self.window = window
        applyPinning()
        return window
    }

    private func restoredContentSize() -> NSSize {
        let defaults = UserDefaults.standard
        let savedWidth = defaults.object(forKey: Self.widthPreferenceKey) as? Double
        let savedHeight = defaults.object(forKey: Self.heightPreferenceKey) as? Double

        guard let savedWidth, let savedHeight else {
            return Self.defaultContentSize
        }

        return NSSize(
            width: max(savedWidth, Self.minimumContentSize.width),
            height: max(savedHeight, Self.minimumContentSize.height)
        )
    }

    private func saveWindowContentSize(_ size: NSSize) {
        UserDefaults.standard.set(size.width, forKey: Self.widthPreferenceKey)
        UserDefaults.standard.set(size.height, forKey: Self.heightPreferenceKey)
    }

    private func applyPinning() {
        guard let window else {
            return
        }

        if isPinned {
            window.level = .floating
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        } else {
            window.level = .normal
            window.collectionBehavior = [.moveToActiveSpace]
        }
    }
}

class TBStatusItem: NSObject, NSApplicationDelegate {
    private var popover = NSPopover()
    private var statusBarItem: NSStatusItem?
    let timer = TBTimer.shared
    lazy var clockWindowController = TBClockWindowController(timer: timer)
    static var shared: TBStatusItem?

    func applicationDidFinishLaunching(_: Notification) {
        let view = TBPopoverView(timer: timer, clockWindowController: clockWindowController)

        popover.behavior = .transient
        popover.contentViewController = NSViewController()
        popover.contentViewController?.view = NSHostingView(rootView: view)
        if let contentViewController = popover.contentViewController {
            popover.contentSize.height = contentViewController.view.intrinsicContentSize.height
            popover.contentSize.width = 360
        }

        statusBarItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.variableLength
        )
        statusBarItem?.button?.imagePosition = .imageLeft
        setIcon(name: .idle)
        statusBarItem?.button?.action = #selector(TBStatusItem.togglePopover(_:))
    }

    func setTitle(title: String?) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = 0.9
        paragraphStyle.alignment = NSTextAlignment.center

        let attributedTitle = NSAttributedString(
            string: title != nil ? " \(title!)" : "",
            attributes: [
                NSAttributedString.Key.font: digitFont,
                NSAttributedString.Key.paragraphStyle: paragraphStyle
            ]
        )
        statusBarItem?.button?.attributedTitle = attributedTitle
    }

    func setIcon(name: NSImage.Name) {
        statusBarItem?.button?.image = NSImage(named: name)
    }

    func showPopover(_: AnyObject?) {
        if let button = statusBarItem?.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    func closePopover(_ sender: AnyObject?) {
        popover.performClose(sender)
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            closePopover(sender)
        } else {
            showPopover(sender)
        }
    }
}
