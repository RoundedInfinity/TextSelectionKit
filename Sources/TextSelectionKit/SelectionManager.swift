import SwiftUI
import Observation

#if os(macOS)
import AppKit
#elseif os(iOS) || os(visionOS) || os(tvOS)
import UIKit
#endif

// MARK: - Global Selection Focus Coordinator

@MainActor
public final class SelectionFocusCoordinator {
    public static let shared = SelectionFocusCoordinator()
    
    public private(set) weak var activeManager: SelectionManager?
    
    private init() {}
    
    public func registerActive(_ manager: SelectionManager) {
        if let current = activeManager, current !== manager {
            current.clearSelection()
        }
        activeManager = manager
    }
    
    public func clearIfActive(_ manager: SelectionManager) {
        if activeManager === manager {
            activeManager = nil
        }
    }
}

// MARK: - High-Performance Selection Manager (@Observable)

/// An observable controller that coordinates selection state across a ``SelectionContainer``.
///
/// Use `SelectionManager` when you need programmatic access to the active selection range,
/// custom clipboard handling, or to drive UI controls like external "Select All" and "Copy" buttons.
///
/// Mutating methods and observable properties are bound to `@MainActor`.
@MainActor
@Observable
public final class SelectionManager: Identifiable {
    /// The unique identifier of this selection manager.
    public let id = UUID()
    
    /// The active selection ranges in UTF-16 code-unit offsets, keyed by text element identifier.
    public private(set) var selections: [AnyHashable: Range<Int>] = [:]
    
    /// The continuous global range of the active selection in the virtual document, in UTF-16 code-unit offsets.
    public private(set) var globalSelectedRange: Range<Int> = 0..<0
    
    /// A Boolean value indicating whether a selection drag or interaction is currently active.
    public private(set) var isSelecting: Bool = false
    
    @ObservationIgnored
    private(set) var document = VirtualTextDocument()
    
    /// A closure invoked whenever the active selection range changes.
    @ObservationIgnored
    public var onSelectionChanged: (() -> Void)?
    
    @ObservationIgnored
    private var internalSelectionListeners: [UUID: () -> Void] = [:]
    
    /// Registers an internal listener invoked when selection changes, returning a token to unregister.
    @discardableResult
    internal func addInternalSelectionListener(_ listener: @escaping () -> Void) -> UUID {
        let token = UUID()
        internalSelectionListeners[token] = listener
        return token
    }
    
    /// Unregisters an internal listener by token.
    internal func removeInternalSelectionListener(token: UUID) {
        internalSelectionListeners.removeValue(forKey: token)
    }
    
    /// An internal callback invoked when selection changes, used by platform overlays without interfering with `onSelectionChanged`.
    @ObservationIgnored
    internal var onInternalSelectionChanged: (() -> Void)? {
        get { internalSelectionListeners.values.first }
        set {
            let fixedKey = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
            if let newValue = newValue {
                internalSelectionListeners[fixedKey] = newValue
            } else {
                internalSelectionListeners.removeValue(forKey: fixedKey)
            }
        }
    }
    
    /// Creates a new selection manager.
    public init() {}
    
    private func notifySelectionChanged() {
        for listener in internalSelectionListeners.values {
            listener()
        }
        onSelectionChanged?()
    }
    
    /// The total length in UTF-16 code units across all registered elements and delimiters in the virtual document.
    public private(set) var totalLength: Int = 0
    
    /// The concatenated full text across all registered elements in the virtual document.
    public private(set) var fullText: String = ""
    
    func updateRegisteredElements(_ elements: [TextElementRegistration]) {
        self.document.update(elements: elements)
        
        let newTotalLength = document.totalLength
        if self.totalLength != newTotalLength {
            self.totalLength = newTotalLength
        }
        
        let newFullText = document.fullText
        if self.fullText != newFullText {
            self.fullText = newFullText
        }
        
        // Refresh per-element selections if global selection was set
        if !globalSelectedRange.isEmpty {
            let maxLen = newTotalLength
            let lower = max(0, min(globalSelectedRange.lowerBound, maxLen))
            let upper = max(lower, min(globalSelectedRange.upperBound, maxLen))
            let clampedRange = lower..<upper
            let newSelections = document.perElementSelections(from: clampedRange)
            let newIsSelecting = !clampedRange.isEmpty
            
            if self.globalSelectedRange != clampedRange || self.selections != newSelections || self.isSelecting != newIsSelecting {
                self.globalSelectedRange = clampedRange
                self.selections = newSelections
                self.isSelecting = newIsSelecting
                notifySelectionChanged()
            }
        }
    }
    
    // MARK: - Selection Updates
    
    /// Programmatically sets the active global selection range.
    ///
    /// Offsets are specified in UTF-16 code units and are automatically clamped to valid document bounds `0..<totalLength`.
    ///
    /// - Parameter range: The continuous range in UTF-16 code-unit offsets to select within the virtual document.
    public func setGlobalSelection(_ range: Range<Int>) {
        let lower = max(0, min(range.lowerBound, document.totalLength))
        let upper = max(lower, min(range.upperBound, document.totalLength))
        let clampedRange = lower..<upper
        
        if self.globalSelectedRange == clampedRange && self.isSelecting == (!clampedRange.isEmpty) {
            return
        }
        
        if !clampedRange.isEmpty {
            SelectionFocusCoordinator.shared.registerActive(self)
        }
        
        let newSelections = document.perElementSelections(from: clampedRange)
        self.globalSelectedRange = clampedRange
        self.selections = newSelections
        self.isSelecting = !clampedRange.isEmpty
        self.notifySelectionChanged()
    }
    
    /// Clears the active selection.
    public func clearSelection() {
        guard !globalSelectedRange.isEmpty || !selections.isEmpty || isSelecting else { return }
        self.globalSelectedRange = 0..<0
        self.selections.removeAll()
        self.isSelecting = false
        self.notifySelectionChanged()
    }
    
    /// Selects all text across all registered elements in the container.
    public func selectAll() {
        setGlobalSelection(0..<document.totalLength)
    }
    
    /// Copies the currently selected plain and rich text to the system pasteboard.
    public func copySelection() {
        let copiedText = getSelectedText()
        guard !copiedText.isEmpty else { return }
        
        #if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(copiedText, forType: .string)
        
        let attrString = getSelectedAttributedString()
        let nsAttr = PlatformAttributedStringBuilder.build(from: attrString, defaultFont: NSFont.systemFont(ofSize: NSFont.systemFontSize))
        if let rtfData = try? nsAttr.data(from: NSRange(location: 0, length: nsAttr.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]) {
            pasteboard.setData(rtfData, forType: .rtf)
        }
        #elseif os(iOS) || os(visionOS) || os(tvOS)
        UIPasteboard.general.string = copiedText
        #endif
    }
    
    /// Returns the plain text content of the active selection.
    public func getSelectedText() -> String {
        document.text(in: globalSelectedRange)
    }
    
    /// Returns the formatted rich text content of the active selection as an `AttributedString`.
    public func getSelectedAttributedString() -> AttributedString {
        document.attributedString(in: globalSelectedRange)
    }
    
    /// A Boolean value indicating whether there is an active, non-empty selection.
    public var hasSelection: Bool {
        !globalSelectedRange.isEmpty && !getSelectedText().isEmpty
    }
    
    // MARK: - Element Identification & Queries
    
    /// Returns the local selection range in UTF-16 code-unit offsets for the specified element identifier, or `nil` if not selected.
    ///
    /// - Parameter id: The identifier of the element to query.
    /// - Returns: The local `Range<Int>` in UTF-16 code-unit offsets within the element's text if currently selected, otherwise `nil`.
    public func selection<ID: Hashable>(for id: ID) -> Range<Int>? {
        selections[AnyHashable(id)]
    }
    
    /// Returns a Boolean value indicating whether the element with the specified identifier is currently selected.
    ///
    /// - Parameter id: The identifier of the element to query.
    /// - Returns: `true` if the element has an active non-empty selection range, otherwise `false`.
    public func isSelected<ID: Hashable>(_ id: ID) -> Bool {
        guard let range = selections[AnyHashable(id)] else { return false }
        return !range.isEmpty
    }
    
    /// Returns the plain text selected within the element with the specified identifier, or `nil` if not selected.
    ///
    /// - Parameter id: The identifier of the element to query.
    /// - Returns: The selected substring, or `nil` if the element is not currently selected.
    public func selectedText<ID: Hashable>(for id: ID) -> String? {
        guard let range = selections[AnyHashable(id)], !range.isEmpty else { return nil }
        guard let slice = document.slices.first(where: { $0.element.id == AnyHashable(id) }) else { return nil }
        let text = slice.element.text
        let utf16 = text.utf16
        let clampedStart = max(0, min(range.lowerBound, utf16.count))
        let clampedEnd = max(clampedStart, min(range.upperBound, utf16.count))
        guard clampedStart < clampedEnd else { return "" }
        let startIdx = utf16.index(utf16.startIndex, offsetBy: clampedStart, limitedBy: utf16.endIndex) ?? utf16.startIndex
        let endIdx = utf16.index(utf16.startIndex, offsetBy: clampedEnd, limitedBy: utf16.endIndex) ?? utf16.endIndex
        return String(utf16[startIdx..<endIdx])
    }
    
    /// Returns the formatted rich text selected within the element with the specified identifier, or `nil` if not selected.
    ///
    /// - Parameter id: The identifier of the element to query.
    /// - Returns: The selected `AttributedString` slice, or `nil` if the element is not currently selected.
    public func selectedAttributedString<ID: Hashable>(for id: ID) -> AttributedString? {
        guard let range = selections[AnyHashable(id)], !range.isEmpty else { return nil }
        guard let slice = document.slices.first(where: { $0.element.id == AnyHashable(id) }) else { return nil }
        let baseAttr = slice.element.attributedString ?? AttributedString(slice.element.text)
        let text = slice.element.text
        let nsRange = NSRange(location: range.lowerBound, length: range.count)
        if let strRange = Range(nsRange, in: text),
           let attrStart = AttributedString.Index(strRange.lowerBound, within: baseAttr),
           let attrEnd = AttributedString.Index(strRange.upperBound, within: baseAttr) {
            return AttributedString(baseAttr[attrStart..<attrEnd])
        }
        return nil
    }
    
    /// Returns the identifiers of all elements that currently contain a non-empty selection, cast to the given type.
    ///
    /// The identifiers are returned in visual reading/document layout order.
    ///
    /// - Parameter type: The concrete identifier type to extract.
    /// - Returns: An array of matching identifiers for currently selected elements.
    public func selectedIDs<ID: Hashable>(_ type: ID.Type = ID.self) -> [ID] {
        document.slices.compactMap { slice in
            guard let range = selections[slice.element.id], !range.isEmpty else { return nil }
            return slice.element.id.base as? ID
        }
    }
    
    /// Returns the identifiers of all elements that currently contain a non-empty selection.
    ///
    /// The identifiers are returned in visual reading/document layout order.
    public var selectedIDs: [AnyHashable] {
        document.slices.compactMap { slice in
            guard let range = selections[slice.element.id], !range.isEmpty else { return nil }
            return slice.element.id
        }
    }
}
