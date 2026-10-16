import AppKit
import CoreGraphics

/// A session-wide CGEvent tap running on its own thread, so a busy main thread never delays system input.
/// The tap is "active" (not listen-only) because menu hit-testing must happen before the click reaches
/// the app and the menu closes. Events are always passed through unmodified.
final class EventMonitor {
    typealias Handler = (CGEventType, CGEvent) -> Void

    private let handler: Handler
    private var tap: CFMachPort?
    private var thread: Thread?
    private var runLoop: CFRunLoop?

    init(handler: @escaping Handler) {
        self.handler = handler
    }

    var isRunning: Bool {
        guard let tap else { return false }
        return CGEvent.tapIsEnabled(tap: tap)
    }

    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return isRunning }
        let types: [CGEventType] = [.leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp, .keyDown, .flagsChanged]
        let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << CGEventMask($1.rawValue)) }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                if let refcon {
                    let monitor = Unmanaged<EventMonitor>.fromOpaque(refcon).takeUnretainedValue()
                    monitor.dispatch(type, event)
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            Log.info("Event tap could not be created (Accessibility permission missing?)")
            return false
        }
        self.tap = tap

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        let thread = Thread { [weak self] in
            self?.runLoop = CFRunLoopGetCurrent()
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            CFRunLoopRun()
        }
        thread.name = "ShortcutCoach.EventTap"
        thread.qualityOfService = .userInteractive
        thread.start()
        self.thread = thread
        Log.info("Event tap started")
        return true
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let runLoop { CFRunLoopStop(runLoop) }
        tap = nil
        runLoop = nil
        thread = nil
    }

    private func dispatch(_ type: CGEventType, _ event: CGEvent) {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            Log.info("Event tap re-enabled after \(type == .tapDisabledByTimeout ? "timeout" : "user input")")
        default:
            handler(type, event)
        }
    }
}

/// On-screen window lookup via CGWindowList — cheap, and needs no Accessibility calls.
enum WindowList {
    struct Info {
        let pid: pid_t
        let layer: Int
        let bounds: CGRect
    }

    /// Frontmost window containing `point` (global, top-left origin — same space as CGEvent locations).
    static func window(at point: CGPoint) -> Info? {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return nil }
        for w in list {
            guard let dict = w[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: dict),
                  bounds.contains(point) else { continue }
            let alpha = w[kCGWindowAlpha as String] as? Double ?? 1
            let layer = w[kCGWindowLayer as String] as? Int ?? 0
            guard alpha > 0.01, layer < 1000 else { continue }
            let pid = (w[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value ?? 0
            return Info(pid: pid, layer: layer, bounds: bounds)
        }
        return nil
    }
}
