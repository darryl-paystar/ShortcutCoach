import AppKit
import ApplicationServices

enum AX {
    /// Short timeout so a hung app can never stall input for long (our tap is synchronous).
    static let systemWide: AXUIElement = {
        let e = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(e, 0.15)
        return e
    }()

    static var isTrusted: Bool { AXIsProcessTrusted() }

    static func requestTrust() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    /// Hit-tests inside one app only. Never call this for our own pid: Accessibility queries about our
    /// own windows are answered in-process on the calling thread, and SwiftUI requires the main thread.
    static func element(at p: CGPoint, pid: pid_t) -> AXUIElement? {
        guard pid != Apps.ownPID, pid > 0 else { return nil }
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.15)
        var el: AXUIElement?
        guard AXUIElementCopyElementAtPosition(app, Float(p.x), Float(p.y), &el) == .success else { return nil }
        return el
    }

    static func focusedElement(pid: pid_t) -> AXUIElement? {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.15)
        return app.element(kAXFocusedUIElementAttribute)
    }

    static let textRoles: Set<String> = [kAXTextFieldRole, kAXTextAreaRole, kAXComboBoxRole]

    /// True when keyboard focus in `pid` is an editable text element.
    static func isTextFocused(pid: pid_t) -> Bool {
        guard let el = focusedElement(pid: pid), let role = el.role else { return false }
        if textRoles.contains(role) { return true }
        return role != kAXStaticTextRole && el.value("AXSelectedTextRange") != nil
    }
}

extension AXUIElement {
    func value(_ attr: String) -> CFTypeRef? {
        var v: CFTypeRef?
        guard AXUIElementCopyAttributeValue(self, attr as CFString, &v) == .success else { return nil }
        return v
    }

    func string(_ attr: String) -> String? {
        guard let s = value(attr) as? String, !s.isEmpty else { return nil }
        return s
    }

    func int(_ attr: String) -> Int? { (value(attr) as? NSNumber)?.intValue }
    func bool(_ attr: String) -> Bool? { (value(attr) as? NSNumber)?.boolValue }

    func element(_ attr: String) -> AXUIElement? {
        guard let v = value(attr), CFGetTypeID(v) == AXUIElementGetTypeID() else { return nil }
        return (v as! AXUIElement)
    }

    func elements(_ attr: String) -> [AXUIElement] {
        (value(attr) as? [AXUIElement]) ?? []
    }

    /// Fetches several attributes in one IPC round trip; missing ones come back as nil.
    func values(_ attrs: [String]) -> [String: Any] {
        var out: CFArray?
        guard AXUIElementCopyMultipleAttributeValues(self, attrs as CFArray, AXCopyMultipleAttributeOptions(rawValue: 0), &out) == .success,
              let arr = out as? [Any] else { return [:] }
        var dict: [String: Any] = [:]
        for (name, v) in zip(attrs, arr) {
            // Missing attributes are returned as AXValue-wrapped errors.
            if CFGetTypeID(v as CFTypeRef) == AXValueGetTypeID() { continue }
            dict[name] = v
        }
        return dict
    }

    var role: String? { string(kAXRoleAttribute) }
    var subrole: String? { string(kAXSubroleAttribute) }
    var title: String? { string(kAXTitleAttribute) }
    var axDescription: String? { string(kAXDescriptionAttribute) }
    var identifier: String? { string("AXIdentifier") }
    var placeholder: String? { string("AXPlaceholderValue") }
    var stringValue: String? { string(kAXValueAttribute) }
    var parent: AXUIElement? { element(kAXParentAttribute) }
    var children: [AXUIElement] { elements(kAXChildrenAttribute) }
    var isEnabled: Bool { bool(kAXEnabledAttribute) ?? true }

    var pid: pid_t {
        var p: pid_t = 0
        AXUIElementGetPid(self, &p)
        return p
    }

    /// Human label for buttons: title, else accessibility description.
    var label: String? { title ?? axDescription }

    /// Self or the nearest ancestor within `maxDepth` hops that satisfies `match`.
    func ancestor(maxDepth: Int, where match: (AXUIElement) -> Bool) -> AXUIElement? {
        var cur: AXUIElement? = self
        var depth = 0
        while let c = cur, depth <= maxDepth {
            if match(c) { return c }
            cur = c.parent
            depth += 1
        }
        return nil
    }

    func ancestor(role: String, maxDepth: Int) -> AXUIElement? {
        ancestor(maxDepth: maxDepth) { $0.role == role }
    }
}
