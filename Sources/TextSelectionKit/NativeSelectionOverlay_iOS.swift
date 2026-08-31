#if os(iOS) || os(visionOS) || os(tvOS)
import UIKit
import SwiftUI

// MARK: - Custom Text Selection Rect Subclass

final class CustomTextSelectionRect: UITextSelectionRect {
    private let _rect: CGRect
    private let _writingDirection: NSWritingDirection
    private let _containsStart: Bool
    private let _containsEnd: Bool
    private let _isVertical: Bool
    
    init(
        rect: CGRect,
        writingDirection: NSWritingDirection = .leftToRight,
        containsStart: Bool = false,
        containsEnd: Bool = false,
        isVertical: Bool = false
    ) {
        self._rect = rect
        self._writingDirection = writingDirection
        self._containsStart = containsStart
        self._containsEnd = containsEnd
        self._isVertical = isVertical
        super.init()
    }
    
    override var rect: CGRect { _rect }
    override var writingDirection: NSWritingDirection { _writingDirection }
    override var containsStart: Bool { _containsStart }
    override var containsEnd: Bool { _containsEnd }
    override var isVertical: Bool { _isVertical }
}

// MARK: - Native Selection Tracking View (UITextInput + UITextInteraction)

final class NativeSelectionTrackingUIView: UIView, UITextInput, SelectionObserver {
    weak var manager: SelectionManager? {
        didSet {
            guard oldValue !== manager else { return }
            oldValue?.removeObserver(self)
            manager?.addObserver(self)
        }
    }
    
    var hitTestPolicy: SelectionHitTestPolicy = .textOnly
    
    func selectionDidChange(in manager: SelectionManager) {
        setNeedsDisplay()
        if manager.hasSelection {
            if !isFirstResponder {
                _ = becomeFirstResponder()
            }
        }
        inputDelegate?.selectionDidChange(self)
    }
    
    deinit {
        if let manager = manager {
            MainActor.assumeIsolated {
                manager.removeObserver(self)
            }
        }
    }
    
    override var canBecomeFirstResponder: Bool { true }
    
    override func becomeFirstResponder() -> Bool {
        if let manager = manager {
            SelectionFocusCoordinator.shared.registerActive(manager)
        }
        return super.becomeFirstResponder()
    }
    
    // MARK: - UITextInput Properties
    
    weak var inputDelegate: UITextInputDelegate?
    lazy var tokenizer: UITextInputTokenizer = UITextInputStringTokenizer(textInput: self)
    
    var selectedTextRange: UITextRange? {
        get {
            guard let manager = manager, manager.hasSelection else {
                return nil
            }
            return VirtualTextRange(range: manager.globalSelectedRange)
        }
        set {
            guard let manager = manager else { return }
            if let newRange = (newValue as? VirtualTextRange)?.range, !newRange.isEmpty {
                if !isFirstResponder {
                    _ = becomeFirstResponder()
                }
                manager.select(newRange)
            } else {
                manager.deselectAll()
            }
        }
    }
    
    var markedTextRange: UITextRange? { nil }
    var markedTextStyle: [NSAttributedString.Key : Any]? {
        get { nil }
        set {}
    }
    
    var beginningOfDocument: UITextPosition {
        VirtualTextPosition(offset: 0)
    }
    
    var endOfDocument: UITextPosition {
        VirtualTextPosition(offset: manager?.document.totalLength ?? 0)
    }
    
    var hasText: Bool {
        !(manager?.document.isEmpty ?? true)
    }
    
    private var textInteraction: UITextInteraction?
    private var editMenuInteraction: UIEditMenuInteraction?
    var contextMenuProvider: SelectionContextMenuProvider?
    
    // Cached selection rects for hit-testing and UITextInput selection rects
    private var cachedSelectionRange: Range<Int>?
    private var cachedDocumentTotalLength: Int = -1
    private var cachedSelectionLineRects: [CGRect] = []
    
    private func cachedLineSelectionRects(for range: Range<Int>) -> [CGRect] {
        guard let manager = manager else { return [] }
        if cachedSelectionRange == range && cachedDocumentTotalLength == manager.totalLength {
            return cachedSelectionLineRects
        }
        let rects = manager.document.lineSelectionRects(for: range)
        cachedSelectionRange = range
        cachedDocumentTotalLength = manager.totalLength
        cachedSelectionLineRects = rects
        return rects
    }
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        backgroundColor = .clear
        isOpaque = false
        
        let interaction = UITextInteraction(for: .nonEditable)
        interaction.textInput = self
        addInteraction(interaction)
        self.textInteraction = interaction
        
        let editMenu = UIEditMenuInteraction(delegate: self)
        addInteraction(editMenu)
        self.editMenuInteraction = editMenu
    }
    
    // MARK: - Hit Testing & Gesture Routing
    
    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let manager = manager, !manager.document.isEmpty else { return nil }
        
        // If selection is currently active, capture touches near the selection rects/handles
        if manager.hasSelection {
            // Fast coarse check: only test elements overlapping the active selection
            var isNearSelectedElement = false
            manager.document.forEachOverlappingSlice(in: manager.globalSelectedRange) { slice, _ in
                if slice.element.frame.insetBy(dx: -24, dy: -24).contains(point) {
                    isNearSelectedElement = true
                }
            }
            
            if isNearSelectedElement {
                let selectionRects = cachedLineSelectionRects(for: manager.globalSelectedRange)
                if selectionRects.contains(where: { $0.insetBy(dx: -24, dy: -24).contains(point) }) {
                    return self
                }
            }
        }
        
        switch hitTestPolicy {
        case .container:
            return bounds.contains(point) ? self : nil
        case .textOnly(let padding):
            // Check if touch is on or near any selectable text element
            for elem in manager.document.elements {
                let paddedFrame = elem.frame.insetBy(dx: -padding, dy: -padding)
                if paddedFrame.contains(point) {
                    return self
                }
            }
            // Let touch pass through to underlying buttons, controls, or scrollviews
            return nil
        }
    }
    
    // MARK: - UITextInput Methods
    
    public func text(in range: UITextRange) -> String? {
        guard let manager = manager, let vRange = range as? VirtualTextRange else { return nil }
        return manager.document.text(in: vRange.range)
    }
    
    public func replace(_ range: UITextRange, withText text: String) {
        // Read-only selectable text
    }
    
    public func setMarkedText(_ markedText: String?, selectedRange: NSRange) {
        // Read-only selectable text
    }
    
    public func unmarkText() {
        // Read-only selectable text
    }
    
    public func insertText(_ text: String) {
        // Read-only selectable text
    }
    
    public func deleteBackward() {
        // Read-only selectable text
    }
    
    public func textRange(from fromPosition: UITextPosition, to toPosition: UITextPosition) -> UITextRange? {
        guard let from = fromPosition as? VirtualTextPosition,
              let to = toPosition as? VirtualTextPosition else { return nil }
        let start = min(from.offset, to.offset)
        let end = max(from.offset, to.offset)
        return VirtualTextRange(range: start..<end)
    }
    
    public func position(from position: UITextPosition, offset: Int) -> UITextPosition? {
        guard let manager = manager, let pos = position as? VirtualTextPosition else { return nil }
        let total = manager.document.totalLength
        let newOffset = max(0, min(pos.offset + offset, total))
        return VirtualTextPosition(offset: newOffset)
    }
    
    public func position(from position: UITextPosition, in direction: UITextLayoutDirection, offset: Int) -> UITextPosition? {
        guard let manager = manager, let pos = position as? VirtualTextPosition else { return nil }
        switch direction {
        case .right:
            return self.position(from: position, offset: offset)
        case .left:
            return self.position(from: position, offset: -offset)
        case .up, .down:
            let currentCaret = manager.document.caretRect(atGlobalOffset: pos.offset)
            let step = max(16.0, currentCaret.height + 4.0)
            let dy = (direction == .down ? step : -step) * CGFloat(offset)
            let targetPoint = CGPoint(x: currentCaret.midX, y: currentCaret.midY + dy)
            let newOffset = manager.document.closestGlobalOffset(to: targetPoint)
            return VirtualTextPosition(offset: newOffset)
        @unknown default:
            return self.position(from: position, offset: offset)
        }
    }
    
    public func compare(_ position: UITextPosition, to other: UITextPosition) -> ComparisonResult {
        guard let p1 = position as? VirtualTextPosition,
              let p2 = other as? VirtualTextPosition else { return .orderedSame }
        if p1.offset < p2.offset { return .orderedAscending }
        if p1.offset > p2.offset { return .orderedDescending }
        return .orderedSame
    }
    
    public func offset(from: UITextPosition, to: UITextPosition) -> Int {
        guard let f = from as? VirtualTextPosition,
              let t = to as? VirtualTextPosition else { return 0 }
        return t.offset - f.offset
    }
    
    public func position(within range: UITextRange, farthestIn direction: UITextLayoutDirection) -> UITextPosition? {
        guard let r = range as? VirtualTextRange else { return nil }
        switch direction {
        case .left, .up:
            return VirtualTextPosition(offset: r.range.lowerBound)
        case .right, .down:
            return VirtualTextPosition(offset: r.range.upperBound)
        @unknown default:
            return VirtualTextPosition(offset: r.range.lowerBound)
        }
    }
    
    public func characterRange(byExtending position: UITextPosition, in direction: UITextLayoutDirection) -> UITextRange? {
        guard let manager = manager, let pos = position as? VirtualTextPosition else { return nil }
        switch direction {
        case .right, .down:
            let end = min(pos.offset + 1, manager.document.totalLength)
            return VirtualTextRange(range: pos.offset..<end)
        case .left, .up:
            let start = max(0, pos.offset - 1)
            return VirtualTextRange(range: start..<pos.offset)
        @unknown default:
            return nil
        }
    }
    
    private func isRTLCharacter(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x0590...0x05FF, // Hebrew
             0x0600...0x06FF, // Arabic
             0x0700...0x074F, // Syriac
             0x0750...0x077F, // Arabic Supplement
             0x0780...0x07BF, // Thaana
             0x07C0...0x07FF, // NKo
             0x0800...0x083F, // Samaritan
             0x0840...0x085F, // Mandaic
             0x08A0...0x08FF, // Arabic Extended-A
             0xFB1D...0xFB4F, // Hebrew Presentation Forms
             0xFB50...0xFDFF, // Arabic Presentation Forms-A
             0xFE70...0xFEFF: // Arabic Presentation Forms-B
            return true
        default:
            return false
        }
    }
    
    func baseWritingDirection(for position: UITextPosition, in direction: UITextStorageDirection) -> NSWritingDirection {
        guard let manager = manager, let pos = position as? VirtualTextPosition else { return .natural }
        if let (slice, _) = manager.document.slice(forGlobalOffset: pos.offset) {
            if slice.element.layoutDirection == .rightToLeft {
                return .rightToLeft
            }
            let text = slice.element.text
            let utf16 = text.utf16
            let localOffset = min(pos.offset - slice.globalRange.lowerBound, max(0, utf16.count - 1))
            if let idx = utf16.index(utf16.startIndex, offsetBy: max(0, localOffset), limitedBy: utf16.endIndex), idx < text.endIndex {
                if let scalar = text[idx].unicodeScalars.first, isRTLCharacter(scalar) {
                    return .rightToLeft
                }
            }
        }
        return .leftToRight
    }
    
    func setBaseWritingDirection(_ baseWritingDirection: NSWritingDirection, for range: UITextRange) {
        // Read-only text
    }
    
    // MARK: - Geometry & Selection Rects
    
    func firstRect(for range: UITextRange) -> CGRect {
        guard let manager = manager, let vRange = range as? VirtualTextRange, !vRange.range.isEmpty else {
            if let manager = manager, let vRange = range as? VirtualTextRange {
                return manager.document.caretRect(atGlobalOffset: vRange.range.lowerBound)
            }
            return .zero
        }
        let rects = cachedLineSelectionRects(for: vRange.range)
        return rects.first ?? manager.document.characterRect(atGlobalOffset: vRange.range.lowerBound)
    }
    
    func caretRect(for position: UITextPosition) -> CGRect {
        guard let manager = manager, let pos = position as? VirtualTextPosition else { return .zero }
        return manager.document.caretRect(atGlobalOffset: pos.offset)
    }
    
    func selectionRects(for range: UITextRange) -> [UITextSelectionRect] {
        guard let manager = manager, let vRange = range as? VirtualTextRange, !vRange.range.isEmpty else {
            return []
        }
        
        let isRTL: Bool = {
            if let (slice, _) = manager.document.slice(forGlobalOffset: vRange.range.lowerBound) {
                if slice.element.layoutDirection == .rightToLeft { return true }
                let text = slice.element.text
                if let scalar = text.unicodeScalars.first, isRTLCharacter(scalar) {
                    return true
                }
            }
            return false
        }()
        
        let lineRects = cachedLineSelectionRects(for: vRange.range)
        guard !lineRects.isEmpty else { return [] }
        let dir: NSWritingDirection = isRTL ? .rightToLeft : .leftToRight
        
        return lineRects.enumerated().map { index, rect in
            let isFirst = index == 0
            let isLast = index == lineRects.count - 1
            return CustomTextSelectionRect(
                rect: rect,
                writingDirection: dir,
                containsStart: isFirst,
                containsEnd: isLast,
                isVertical: false
            )
        }
    }
    
    public func closestPosition(to point: CGPoint) -> UITextPosition? {
        guard let manager = manager else { return nil }
        let offset = manager.document.closestGlobalOffset(to: point)
        return VirtualTextPosition(offset: offset)
    }
    
    public func closestPosition(to point: CGPoint, within range: UITextRange) -> UITextPosition? {
        guard let manager = manager, let vRange = range as? VirtualTextRange else {
            return closestPosition(to: point)
        }
        let offset = manager.document.closestGlobalOffset(to: point)
        let clamped = max(vRange.range.lowerBound, min(offset, vRange.range.upperBound))
        return VirtualTextPosition(offset: clamped)
    }
    
    public func characterRange(at point: CGPoint) -> UITextRange? {
        guard let manager = manager else { return nil }
        let offset = manager.document.closestGlobalOffset(to: point)
        if let word = manager.document.wordRange(atGlobalOffset: offset) {
            return VirtualTextRange(range: word)
        }
        let end = min(offset + 1, manager.document.totalLength)
        return VirtualTextRange(range: offset..<end)
    }
    
    // MARK: - Standard Edit Actions (Copy, Select All)
    
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(copy(_:)) {
            return manager?.hasSelection ?? false
        }
        if action == #selector(selectAll(_:)) {
            return !(manager?.document.isEmpty ?? true)
        }
        return super.canPerformAction(action, withSender: sender)
    }
    
    @objc override func copy(_ sender: Any?) {
        manager?.copySelection()
    }
    
    @objc override func selectAll(_ sender: Any?) {
        manager?.selectAll()
        inputDelegate?.selectionDidChange(self)
    }
    
    override func buildMenu(with builder: UIMenuBuilder) {
        super.buildMenu(with: builder)
        guard builder.system == .context else { return }
        guard let manager = manager, manager.hasSelection else { return }
        guard let provider = contextMenuProvider else { return }
        
        let selectedText = manager.selectedText
        let context = SelectionMenuContext(
            selectedText: selectedText,
            selectedAttributedString: manager.selectedAttributedString,
            globalSelectedRange: manager.globalSelectedRange,
            selectedIDs: manager.selectedIDs
        )
        
        let parsedCustom = provider.builder(context)
        let customElements = convertParsedItemsToUIElements(parsedCustom)
        guard !customElements.isEmpty else { return }
        
        let customMenu = UIMenu(options: .displayInline, children: customElements)
        
        switch provider.placement {
        case .append:
            builder.insertSibling(customMenu, afterMenu: .standardEdit)
        case .prepend:
            builder.insertSibling(customMenu, beforeMenu: .standardEdit)
        case .replace:
            builder.remove(menu: .standardEdit)
            builder.remove(menu: .lookup)
            builder.remove(menu: .share)
            builder.insertChild(customMenu, atEndOfMenu: .root)
        }
    }
}

// MARK: - UIEditMenuInteractionDelegate

extension NativeSelectionTrackingUIView: UIEditMenuInteractionDelegate {
    public func editMenuInteraction(
        _ interaction: UIEditMenuInteraction,
        menuFor configuration: UIEditMenuConfiguration,
        suggestedActions: [UIMenuElement]
    ) -> UIMenu? {
        guard let manager = manager else { return nil }
        
        let selectedText = manager.selectedText
        let context = SelectionMenuContext(
            selectedText: selectedText,
            selectedAttributedString: manager.selectedAttributedString,
            globalSelectedRange: manager.globalSelectedRange,
            selectedIDs: manager.selectedIDs
        )
        
        guard let provider = contextMenuProvider else {
            return UIMenu(children: suggestedActions)
        }
        
        let parsedCustom = provider.builder(context)
        let customElements = convertParsedItemsToUIElements(parsedCustom)
        
        switch provider.placement {
        case .replace:
            return UIMenu(children: customElements)
        case .prepend:
            return UIMenu(children: customElements + suggestedActions)
        case .append:
            return UIMenu(children: suggestedActions + customElements)
        }
    }
    
    private func convertParsedItemsToUIElements(_ items: [ParsedMenuItem]) -> [UIMenuElement] {
        var elements: [UIMenuElement] = []
        for item in items {
            switch item {
            case .action(let title, let systemImage, let role, let isEnabled, _, let action):
                let image = systemImage.flatMap { UIImage(systemName: $0) }
                var attributes: UIMenuElement.Attributes = []
                if !isEnabled { attributes.insert(.disabled) }
                if role == .destructive { attributes.insert(.destructive) }
                
                let act = UIAction(title: title, image: image, attributes: attributes) { _ in
                    action()
                }
                elements.append(act)
            case .separator:
                break
            case .submenu(let title, let systemImage, let subItems):
                let image = systemImage.flatMap { UIImage(systemName: $0) }
                let childElements = convertParsedItemsToUIElements(subItems)
                let submenu = UIMenu(title: title, image: image, children: childElements)
                elements.append(submenu)
            }
        }
        return elements
    }
}

// MARK: - iOS Selection Overlay Representable

struct IOSSelectionOverlay: UIViewRepresentable {
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
    
    func makeUIView(context: Context) -> NativeSelectionTrackingUIView {
        let view = NativeSelectionTrackingUIView()
        view.manager = manager
        view.hitTestPolicy = hitTestPolicy
        view.contextMenuProvider = contextMenuProvider
        return view
    }
    
    func updateUIView(_ uiView: NativeSelectionTrackingUIView, context: Context) {
        uiView.manager = manager
        uiView.hitTestPolicy = hitTestPolicy
        uiView.contextMenuProvider = contextMenuProvider
    }
}
#endif
