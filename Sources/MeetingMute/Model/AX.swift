import AppKit
import ApplicationServices

/// The CGWindowID behind an AX window. Private but long-stable API (used by yabai, Rectangle
/// and AltTab); without it, windows are matched by frame instead.
@_silgen_name("_AXUIElementGetWindow")
private func _AXUIElementGetWindow(_ element: AXUIElement, _ id: UnsafeMutablePointer<CGWindowID>) -> AXError

/// Small typed wrappers over the Accessibility C API.
enum AX {
    /// Every AX call is a message to another process; a hung app must not hang MeetingMute.
    static func setGlobalTimeout(_ seconds: Float) {
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), seconds)
    }

    static func app(_ pid: pid_t) -> AXUIElement { AXUIElementCreateApplication(pid) }

    static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    static func bool(_ element: AXUIElement, _ attribute: String) -> Bool? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return (value as? NSNumber)?.boolValue
    }

    static func element(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    static func children(_ element: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success else { return [] }
        return value as? [AXUIElement] ?? []
    }

    static func windows(of pid: pid_t) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app(pid), kAXWindowsAttribute as CFString, &value) == .success else {
            return []
        }
        return value as? [AXUIElement] ?? []
    }

    static func position(_ element: AXUIElement) -> CGPoint? {
        var value: CFTypeRef?
        var point = CGPoint.zero
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXValueGetTypeID(),
              AXValueGetValue(value as! AXValue, .cgPoint, &point) else { return nil }
        return point
    }

    static func size(_ element: AXUIElement) -> CGSize? {
        var value: CFTypeRef?
        var size = CGSize.zero
        guard AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXValueGetTypeID(),
              AXValueGetValue(value as! AXValue, .cgSize, &size) else { return nil }
        return size
    }

    @discardableResult
    static func setPosition(_ element: AXUIElement, _ point: CGPoint) -> AXError {
        var point = point
        guard let value = AXValueCreate(.cgPoint, &point) else { return .failure }
        return AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, value)
    }

    static func press(_ element: AXUIElement) -> Bool {
        AXUIElementPerformAction(element, kAXPressAction as CFString) == .success
    }

    static func actionNames(_ element: AXUIElement) -> [String] {
        var names: CFArray?
        guard AXUIElementCopyActionNames(element, &names) == .success else { return [] }
        return names as? [String] ?? []
    }

    static func perform(_ element: AXUIElement, _ action: String) -> Bool {
        AXUIElementPerformAction(element, action as CFString) == .success
    }

    static func windowID(_ window: AXUIElement) -> CGWindowID? {
        var id = CGWindowID(0)
        return _AXUIElementGetWindow(window, &id) == .success && id != 0 ? id : nil
    }

    /// Electron apps only expose their web content to Accessibility when asked.
    static func setManualAccessibility(_ pid: pid_t, _ on: Bool) {
        AXUIElementSetAttributeValue(app(pid), "AXManualAccessibility" as CFString, on ? kCFBooleanTrue : kCFBooleanFalse)
    }

    /// Depth-first walk with a node budget. `visit` returns true to skip that element's children.
    static func walk(_ root: AXUIElement, maxNodes: Int = 300, maxDepth: Int = 20,
                     visit: (AXUIElement, Int) -> Bool) {
        var budget = maxNodes
        func step(_ element: AXUIElement, _ depth: Int) {
            guard budget > 0, depth <= maxDepth else { return }
            budget -= 1
            if visit(element, depth) { return }
            for child in children(element) { step(child, depth + 1) }
        }
        step(root, 0)
    }

    /// The text a person sees on an element: title, value, description.
    static func visibleTexts(_ element: AXUIElement) -> [String] {
        [kAXTitleAttribute, kAXValueAttribute, kAXDescriptionAttribute]
            .compactMap { string(element, $0)?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
