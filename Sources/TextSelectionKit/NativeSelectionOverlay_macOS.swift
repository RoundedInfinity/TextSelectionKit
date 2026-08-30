#if os(macOS)
import AppKit
import SwiftUI

// MARK: - macOS Selection Highlight Background View

final class MacOSSelectionHighlightView: NSView {
    weak var manager: SelectionManager? {
        didSet {
            setupManagerCallback()
        }
    }
    
    private var listenerToken: UUID?
    
    override var isFlipped: Bool { true }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
    }
    
    internal var onNeedsDisplay: (() -> Void)?
    
    private func setupManagerCallback() {
        if let token = listenerToken, let oldManager = manager {
            oldManager.removeInternalSelectionListener(token: token)
        }
        listenerToken = manager?.addInternalSelectionListener { [weak self] in
            self?.needsDisplay = true
            self?.onNeedsDisplay?()
        }
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        NotificationCenter.default.removeObserver(self, name: NSWindow.didBecomeKeyNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSWindow.didResignKeyNotification, object: nil)
        
        if let window = window {
            NotificationCenter.default.addObserver(self, selector: #selector(windowKeyStatusChanged), name: NSWindow.didBecomeKeyNotification, object: window)
            NotificationCenter.default.addObserver(self, selector: #selector(windowKeyStatusChanged), name: NSWindow.didResignKeyNotification, object: window)
        }
    }
    
    @objc private func windowKeyStatusChanged() {
        needsDisplay = true
    }
    
    func highlightColor(isKey: Bool) -> NSColor {
        isKey ? NSColor.selectedTextBackgroundColor : NSColor.unemphasizedSelectedTextBackgroundColor
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let manager = manager, manager.hasSelection else { return }
        
        let rects = manager.document.lineSelectionRects(for: manager.globalSelectedRange)
        guard !rects.isEmpty else { return }
        
        NSGraphicsContext.saveGraphicsState()
        let isKey = window?.isKeyWindow ?? true
        let color = highlightColor(isKey: isKey)
        color.setFill()
        
        for rect in rects {
            if dirtyRect.intersects(rect) {
                let path = NSBezierPath(rect: rect)
                path.fill()
            }
        }
        
        NSGraphicsContext.restoreGraphicsState()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - macOS Selection Highlight Representable

struct MacOSSelectionHighlightOverlay: NSViewRepresentable {
    var manager: SelectionManager
    
    func makeNSView(context: Context) -> MacOSSelectionHighlightView {
        let view = MacOSSelectionHighlightView()
        view.manager = manager
        return view
    }
    
    func updateNSView(_ nsView: MacOSSelectionHighlightView, context: Context) {
        nsView.manager = manager
    }
}

// MARK: - macOS Selection Tracking View

final class MacOSSelectionTrackingView: NSView {
    weak var manager: SelectionManager? {
        didSet {
            setupManagerCallback()
        }
    }
    
    var hitTestPolicy: SelectionHitTestPolicy = .textOnly
    var contextMenuProvider: SelectionContextMenuProvider?
    
    private var dragAnchorOffset: Int?
    private var activeOffset: Int?
    private var listenerToken: UUID?
    
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    
    private func setupManagerCallback() {
        if let token = listenerToken, let oldManager = manager {
            oldManager.removeInternalSelectionListener(token: token)
        }
        listenerToken = manager?.addInternalSelectionListener { [weak self] in
            self?.needsDisplay = true
        }
    }
    
    override func becomeFirstResponder() -> Bool {
        if let manager = manager {
            SelectionFocusCoordinator.shared.registerActive(manager)
        }
        needsDisplay = true
        return super.becomeFirstResponder()
    }
    
    override func resignFirstResponder() -> Bool {
        manager?.clearSelection()
        dragAnchorOffset = nil
        activeOffset = nil
        needsDisplay = true
        return super.resignFirstResponder()
    }
    
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
    
    // MARK: - Hit Testing & Event Passthrough
    
    public override func hitTest(_ point: NSPoint) -> NSView? {
        let localPoint = superview != nil ? convert(point, from: superview) : convert(point, from: nil)
        guard bounds.contains(localPoint) else { return nil }
        guard let manager = manager, !manager.document.isEmpty else { return nil }
        
        switch hitTestPolicy {
        case .container:
            return self
        case .textOnly(let padding):
            if manager.hasSelection {
                var isNearSelection = false
                manager.document.forEachOverlappingSlice(in: manager.globalSelectedRange) { slice, _ in
                    if slice.element.frame.insetBy(dx: -padding - 4, dy: -padding - 4).contains(localPoint) {
                        isNearSelection = true
                    }
                }
                if isNearSelection {
                    return self
                }
            }
            
            for elem in manager.document.elements {
                let paddedFrame = elem.frame.insetBy(dx: -padding, dy: -padding)
                if paddedFrame.contains(localPoint) {
                    return self
                }
            }
            return nil
        }
    }
    
    private func swiftUIPoint(from event: NSEvent) -> CGPoint {
        convert(event.locationInWindow, from: nil)
    }
    
    // MARK: - Mouse Events
    
    public override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        guard let manager = manager else { return }
        
        let point = swiftUIPoint(from: event)
        let clickedOffset = manager.document.closestGlobalOffset(to: point)
        
        if event.modifierFlags.contains(.shift) {
            let anchor = dragAnchorOffset ?? manager.globalSelectedRange.lowerBound
            dragAnchorOffset = anchor
            activeOffset = clickedOffset
            updateSelection(from: anchor, to: clickedOffset)
        } else {
            switch event.clickCount {
            case 2:
                if let wordRange = manager.document.wordRange(atGlobalOffset: clickedOffset) {
                    dragAnchorOffset = wordRange.lowerBound
                    activeOffset = wordRange.upperBound
                    manager.setGlobalSelection(wordRange)
                }
            case 3...:
                if let paraRange = manager.document.paragraphRange(atGlobalOffset: clickedOffset) {
                    dragAnchorOffset = paraRange.lowerBound
                    activeOffset = paraRange.upperBound
                    manager.setGlobalSelection(paraRange)
                }
            default:
                dragAnchorOffset = clickedOffset
                activeOffset = clickedOffset
                manager.clearSelection()
            }
        }
    }
    
    public override func mouseDragged(with event: NSEvent) {
        guard let manager = manager, let anchor = dragAnchorOffset else { return }
        
        let point = swiftUIPoint(from: event)
        let currentOffset = manager.document.closestGlobalOffset(to: point)
        activeOffset = currentOffset
        
        updateSelection(from: anchor, to: currentOffset)
        autoscroll(with: event)
    }
    
    public override func mouseUp(with event: NSEvent) {
        // Selection finalized
    }
    
    public override func rightMouseDown(with event: NSEvent) {
        guard let manager = manager else {
            super.rightMouseDown(with: event)
            return
        }
        
        let point = swiftUIPoint(from: event)
        let clickedOffset = manager.document.closestGlobalOffset(to: point)
        
        if !manager.hasSelection || !manager.globalSelectedRange.contains(clickedOffset) {
            if let wordRange = manager.document.wordRange(atGlobalOffset: clickedOffset) {
                manager.setGlobalSelection(wordRange)
                dragAnchorOffset = wordRange.lowerBound
                activeOffset = wordRange.upperBound
            }
        }
        
        super.rightMouseDown(with: event)
    }
    
    private func updateSelection(from anchor: Int, to current: Int) {
        guard let manager = manager else { return }
        let start = min(anchor, current)
        let end = max(anchor, current)
        manager.setGlobalSelection(start..<end)
    }
    
    // MARK: - Context Menu
    
    private func createMenuItem(title: String, action: Selector?, keyEquivalent: String = "", isEnabled: Bool = true) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        item.isEnabled = isEnabled
        return item
    }
    
    private final class CustomActionBox: NSObject {
        let action: @MainActor () -> Void
        init(action: @escaping @MainActor () -> Void) {
            self.action = action
        }
    }
    
    @objc private func customActionInvoked(_ sender: NSMenuItem) {
        if let box = sender.representedObject as? CustomActionBox {
            box.action()
        }
    }
    
    private func buildDefaultMenuItems(manager: SelectionManager, selectedText: String, hasSelection: Bool) -> [NSMenuItem] {
        var items: [NSMenuItem] = []
        items.append(createMenuItem(title: "Copy", action: #selector(copyAction(_:)), keyEquivalent: "c", isEnabled: hasSelection))
        items.append(createMenuItem(title: "Select All", action: #selector(selectAllAction(_:)), keyEquivalent: "a", isEnabled: !manager.document.isEmpty))
        items.append(.separator())
        
        if hasSelection {
            let snippet = selectedText.count > 25 ? "\(selectedText.prefix(22))..." : selectedText
            items.append(createMenuItem(title: "Look Up \"\(snippet)\"", action: #selector(lookUpAction(_:))))
            
            let shareMenu = NSMenu(title: "Share")
            for service in NSSharingService.sharingServices(forItems: [selectedText]) {
                let item = createMenuItem(title: service.title, action: #selector(shareServiceAction(_:)))
                item.image = service.image
                item.representedObject = service
                shareMenu.addItem(item)
            }
            let shareItem = createMenuItem(title: "Share", action: nil)
            shareItem.submenu = shareMenu
            items.append(shareItem)
            items.append(.separator())
        }
        
        items.append(createMenuItem(title: "Deselect", action: #selector(deselectAction(_:)), isEnabled: hasSelection))
        return items
    }
    
    private func mapModifiersToNSEventFlags(_ modifiers: EventModifiers) -> NSEvent.ModifierFlags {
        var flags = NSEvent.ModifierFlags()
        if modifiers.contains(.command) { flags.insert(.command) }
        if modifiers.contains(.shift) { flags.insert(.shift) }
        if modifiers.contains(.option) { flags.insert(.option) }
        if modifiers.contains(.control) { flags.insert(.control) }
        return flags
    }
    
    private func buildNativeMenuItems(from parsed: [ParsedMenuItem]) -> [NSMenuItem] {
        var result: [NSMenuItem] = []
        for item in parsed {
            switch item {
            case .action(let title, let systemImage, _, let isEnabled, let displayedShortcut, let action):
                let keyEq = displayedShortcut != nil ? String(displayedShortcut!.key.character).lowercased() : ""
                let menuItem = NSMenuItem(title: title, action: #selector(customActionInvoked(_:)), keyEquivalent: keyEq)
                if let displayedShortcut = displayedShortcut {
                    menuItem.keyEquivalentModifierMask = mapModifiersToNSEventFlags(displayedShortcut.modifiers)
                }
                menuItem.target = self
                menuItem.representedObject = CustomActionBox(action: action)
                menuItem.isEnabled = isEnabled
                if let systemImage = systemImage {
                    menuItem.image = NSImage(systemSymbolName: systemImage, accessibilityDescription: title)
                }
                result.append(menuItem)
            case .separator:
                result.append(.separator())
            case .submenu(let title, let systemImage, let subItems):
                let parentItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
                if let systemImage = systemImage {
                    parentItem.image = NSImage(systemSymbolName: systemImage, accessibilityDescription: title)
                }
                let subMenu = NSMenu(title: title)
                let subChildren = buildNativeMenuItems(from: subItems)
                for child in subChildren { subMenu.addItem(child) }
                parentItem.submenu = subMenu
                result.append(parentItem)
            }
        }
        return result
    }
    
    public override func menu(for event: NSEvent) -> NSMenu? {
        guard let manager = manager else { return nil }
        
        let selectedText = manager.getSelectedText()
        let hasSelection = manager.hasSelection && !selectedText.isEmpty
        let defaultItems = buildDefaultMenuItems(manager: manager, selectedText: selectedText, hasSelection: hasSelection)
        
        let menu = NSMenu(title: "Selection")
        
        guard let provider = contextMenuProvider else {
            for item in defaultItems { menu.addItem(item) }
            return menu
        }
        
        let context = SelectionMenuContext(
            selectedText: selectedText,
            selectedAttributedString: manager.getSelectedAttributedString(),
            globalSelectedRange: manager.globalSelectedRange,
            selectedIDs: manager.selectedIDs
        )
        
        let parsedCustom = provider.builder(context)
        let customItems = buildNativeMenuItems(from: parsedCustom)
        
        switch provider.placement {
        case .replace:
            for item in customItems { menu.addItem(item) }
        case .prepend:
            for item in customItems { menu.addItem(item) }
            if !customItems.isEmpty && !defaultItems.isEmpty { menu.addItem(.separator()) }
            for item in defaultItems { menu.addItem(item) }
        case .append:
            for item in defaultItems { menu.addItem(item) }
            if !defaultItems.isEmpty && !customItems.isEmpty { menu.addItem(.separator()) }
            for item in customItems { menu.addItem(item) }
        }
        
        return menu
    }
    
    @objc private func copyAction(_ sender: Any) {
        manager?.copySelection()
    }
    
    @objc private func selectAllAction(_ sender: Any) {
        manager?.selectAll()
    }
    
    @objc private func deselectAction(_ sender: Any) {
        manager?.clearSelection()
        dragAnchorOffset = nil
        activeOffset = nil
    }
    
    @objc private func lookUpAction(_ sender: Any) {
        guard let manager = manager, manager.hasSelection else { return }
        let selectedRange = manager.globalSelectedRange
        let rect = manager.document.characterRect(atGlobalOffset: selectedRange.lowerBound)
        let attrString = NSAttributedString(string: manager.getSelectedText())
        
        showDefinition(for: attrString, at: rect.origin)
    }
    
    @objc private func shareServiceAction(_ sender: NSMenuItem) {
        guard let service = sender.representedObject as? NSSharingService,
              let manager = manager else { return }
        service.perform(withItems: [manager.getSelectedText()])
    }
    
    // MARK: - Quick Look & Force Touch (Dictionary Look Up)
    
    public override func quickLook(with event: NSEvent) {
        guard let manager = manager else { return }
        let point = swiftUIPoint(from: event)
        let offset = manager.document.closestGlobalOffset(to: point)
        
        if let wordRange = manager.document.wordRange(atGlobalOffset: offset) {
            let text = manager.document.text(in: wordRange)
            let rect = manager.document.characterRect(atGlobalOffset: wordRange.lowerBound)
            showDefinition(for: NSAttributedString(string: text), at: rect.origin)
        }
    }
    
    // MARK: - Keyboard Navigation
    
    public override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard window?.firstResponder === self else {
            return super.performKeyEquivalent(with: event)
        }
        guard let manager = manager else { return false }
        
        let relevantModifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
        if relevantModifiers == .command {
            let chars = event.charactersIgnoringModifiers ?? ""
            if chars == "c" {
                if manager.hasSelection {
                    manager.copySelection()
                    return true
                }
            } else if chars == "a" {
                manager.selectAll()
                return true
            }
        }
        return super.performKeyEquivalent(with: event)
    }
    
    public override func keyDown(with event: NSEvent) {
        guard window?.firstResponder === self, let manager = manager else {
            super.keyDown(with: event)
            return
        }
        
        let isShift = event.modifierFlags.contains(.shift)
        let isOption = event.modifierFlags.contains(.option)
        let isCommand = event.modifierFlags.contains(.command)
        let total = manager.document.totalLength
        
        let currentPos = activeOffset ?? dragAnchorOffset ?? 0
        var nextPos = currentPos
        
        switch event.keyCode {
        case 53: // Escape
            manager.clearSelection()
            dragAnchorOffset = nil
            activeOffset = nil
            return
        case 123: // Left Arrow
            if isCommand {
                nextPos = 0
            } else if isOption {
                nextPos = max(0, currentPos - 1)
                if let w = manager.document.wordRange(atGlobalOffset: nextPos) {
                    nextPos = w.lowerBound
                }
            } else {
                nextPos = max(0, currentPos - 1)
            }
        case 124: // Right Arrow
            if isCommand {
                nextPos = total
            } else if isOption {
                nextPos = min(total, currentPos + 1)
                if let w = manager.document.wordRange(atGlobalOffset: nextPos) {
                    nextPos = w.upperBound
                }
            } else {
                nextPos = min(total, currentPos + 1)
            }
        case 125: // Down Arrow
            let caret = manager.document.caretRect(atGlobalOffset: currentPos)
            let step = max(16, caret.height + 4)
            let targetPoint = CGPoint(x: caret.midX, y: caret.midY + step)
            nextPos = manager.document.closestGlobalOffset(to: targetPoint)
        case 126: // Up Arrow
            let caret = manager.document.caretRect(atGlobalOffset: currentPos)
            let step = max(16, caret.height + 4)
            let targetPoint = CGPoint(x: caret.midX, y: caret.midY - step)
            nextPos = manager.document.closestGlobalOffset(to: targetPoint)
        default:
            super.keyDown(with: event)
            return
        }
        
        activeOffset = nextPos
        if isShift {
            if dragAnchorOffset == nil {
                dragAnchorOffset = currentPos
            }
            updateSelection(from: dragAnchorOffset ?? currentPos, to: nextPos)
        } else {
            dragAnchorOffset = nextPos
            manager.clearSelection()
        }
    }
    
    // MARK: - Cursor Rects
    
    public override func resetCursorRects() {
        guard let manager = manager, !manager.document.isEmpty else { return }
        // The I-Beam cursor is only displayed directly over text element boundaries,
        // even when container-wide hit-testing is active for drag selection.
        for elem in manager.document.elements {
            addCursorRect(elem.frame, cursor: .iBeam)
        }
    }
}

// MARK: - macOS Selection Overlay Representable

struct MacOSSelectionOverlay: NSViewRepresentable {
    var manager: SelectionManager
    var hitTestPolicy: SelectionHitTestPolicy
    var contextMenuProvider: SelectionContextMenuProvider?
    
    init(
        manager: SelectionManager,
        hitTestPolicy: SelectionHitTestPolicy = .textOnly,
        contextMenuProvider: SelectionContextMenuProvider? = nil
    ) {
        self.manager = manager
        self.hitTestPolicy = hitTestPolicy
        self.contextMenuProvider = contextMenuProvider
    }
    
    func makeNSView(context: Context) -> MacOSSelectionTrackingView {
        let view = MacOSSelectionTrackingView()
        view.manager = manager
        view.hitTestPolicy = hitTestPolicy
        view.contextMenuProvider = contextMenuProvider
        return view
    }
    
    func updateNSView(_ nsView: MacOSSelectionTrackingView, context: Context) {
        nsView.manager = manager
        nsView.hitTestPolicy = hitTestPolicy
        nsView.contextMenuProvider = contextMenuProvider
        nsView.window?.invalidateCursorRects(for: nsView)
    }
}
#endif
