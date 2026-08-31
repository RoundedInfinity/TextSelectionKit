import SwiftUI
import Observation

#if os(macOS)
import AppKit
#elseif os(iOS) || os(visionOS) || os(tvOS)
import UIKit
#endif

// MARK: - Global Selection Focus Coordinator

/// Coordinates active selection focus across multiple ``SelectionManager`` instances.
///
/// Ensures mutual exclusivity so that only one ``SelectionContainer`` maintains an active text selection
/// at any given time, matching platform-native behavior on macOS and iOS.
@MainActor
public final class SelectionFocusCoordinator {
    /// The shared focus coordinator instance.
    public static let shared = SelectionFocusCoordinator()
    
    /// The currently active selection manager, or `nil` if no selection is active.
    public private(set) weak var activeManager: SelectionManager?
    
    private init() {}
    
    /// Registers the given manager as the active selection controller, clearing any previously focused manager.
    ///
    /// - Parameter manager: The ``SelectionManager`` that gained focus.
    public func registerActive(_ manager: SelectionManager) {
        if let current = activeManager, current !== manager {
            current.deselectAll()
        }
        activeManager = manager
    }
    
    /// Clears the active selection manager reference if it matches the specified manager.
    ///
    /// - Parameter manager: The ``SelectionManager`` to unregister.
    public func clearIfActive(_ manager: SelectionManager) {
        if activeManager === manager {
            activeManager = nil
        }
    }
}

// MARK: - Internal Selection Observer Protocol

@MainActor
protocol SelectionObserver: AnyObject {
    func selectionDidChange(in manager: SelectionManager)
}

private struct WeakSelectionObserver {
    weak var value: (any SelectionObserver)?
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
    private var observers: [WeakSelectionObserver] = []
    
    /// Registers a weak observer invoked when selection changes.
    internal func addObserver(_ observer: any SelectionObserver) {
        observers.removeAll { $0.value == nil || $0.value === observer }
        observers.append(WeakSelectionObserver(value: observer))
    }
    
    /// Returns the number of registered active selection observers, pruning deallocated weak references.
    internal var observerCount: Int {
        observers.removeAll { $0.value == nil }
        return observers.count
    }
    
    /// Unregisters a selection observer.
    internal func removeObserver(_ observer: any SelectionObserver) {
        observers.removeAll { $0.value == nil || $0.value === observer }
    }
    
    /// Creates a new selection manager.
    public init() {}
    
    private func notifySelectionChanged() {
        observers.removeAll { $0.value == nil }
        for wrapper in observers {
            wrapper.value?.selectionDidChange(in: self)
        }
        onSelectionChanged?()
    }
    
    /// The total length in UTF-16 code units across all registered elements and delimiters in the virtual document.
    public private(set) var totalLength: Int = 0
    
    /// The concatenated full text across all registered elements in the virtual document.
    public private(set) var fullText: String = ""
    
    // MARK: - Direct Element Registration (iOS 18+ / macOS 15+)
    
    private var registeredElementsMap: [AnyHashable: TextElementRegistration] = [:]
    
    /// Registers or updates a single text element in the virtual document.
    func registerElement(_ element: TextElementRegistration) {
        if let existing = registeredElementsMap[element.id], existing == element {
            return
        }
        registeredElementsMap[element.id] = element
        updateRegisteredElementsInternal(Array(registeredElementsMap.values))
    }
    
    /// Unregisters a text element by its identifier when removed or scrolled out of view.
    func unregisterElement(id: AnyHashable) {
        guard registeredElementsMap.removeValue(forKey: id) != nil else { return }
        updateRegisteredElementsInternal(Array(registeredElementsMap.values))
    }
    
    /// Updates all registered elements in batch (used by PreferenceKey fallback or bulk injection).
    func updateRegisteredElements(_ elements: [TextElementRegistration]) {
        var newMap: [AnyHashable: TextElementRegistration] = [:]
        for elem in elements {
            newMap[elem.id] = elem
        }
        self.registeredElementsMap = newMap
        updateRegisteredElementsInternal(elements)
    }
    
    private func updateRegisteredElementsInternal(_ elements: [TextElementRegistration]) {
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
    public func select(_ range: Range<Int>) {
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
    
    /// Programmatically selects the full text of the element with the specified identifier.
    ///
    /// - Parameter id: The identifier of the element to select.
    /// - Returns: `true` if the element was found and selected, otherwise `false`.
    @discardableResult
    public func select<ID: Hashable>(id: ID) -> Bool {
        guard let slice = document.slices.first(where: { $0.element.id == AnyHashable(id) }) else { return false }
        select(slice.globalRange)
        return true
    }
    
    /// Programmatically selects a range within the element with the specified identifier.
    ///
    /// - Parameters:
    ///   - range: The local range in UTF-16 code units within the element to select.
    ///   - id: The identifier of the element.
    /// - Returns: `true` if the element was found and selected, otherwise `false`.
    @discardableResult
    public func select<ID: Hashable>(_ range: Range<Int>, in id: ID) -> Bool {
        guard let slice = document.slices.first(where: { $0.element.id == AnyHashable(id) }) else { return false }
        let elemLen = slice.element.text.utf16.count
        let localStart = max(0, min(range.lowerBound, elemLen))
        let localEnd = max(localStart, min(range.upperBound, elemLen))
        let globalRange = (slice.globalRange.lowerBound + localStart)..<(slice.globalRange.lowerBound + localEnd)
        select(globalRange)
        return true
    }
    
    /// Deselects all text across all registered elements in the container.
    public func deselectAll() {
        guard !globalSelectedRange.isEmpty || !selections.isEmpty || isSelecting else { return }
        self.globalSelectedRange = 0..<0
        self.selections.removeAll()
        self.isSelecting = false
        self.notifySelectionChanged()
    }
    
    /// Selects all text across all registered elements in the container.
    public func selectAll() {
        select(0..<document.totalLength)
    }
    
    /// Copies the currently selected plain and rich text to the system pasteboard.
    public func copySelection() {
        let copiedText = selectedText
        guard !copiedText.isEmpty else { return }
        
        #if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(copiedText, forType: .string)
        
        let attrString = selectedAttributedString
        let nsAttr = PlatformAttributedStringBuilder.build(from: attrString, defaultFont: NSFont.systemFont(ofSize: NSFont.systemFontSize))
        if let rtfData = try? nsAttr.data(from: NSRange(location: 0, length: nsAttr.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]) {
            pasteboard.setData(rtfData, forType: .rtf)
        }
        #elseif os(iOS) || os(visionOS) || os(tvOS)
        UIPasteboard.general.string = copiedText
        #endif
    }
    
    /// The plain text content of the active selection in the virtual document.
    public var selectedText: String {
        document.text(in: globalSelectedRange)
    }
    
    /// The formatted rich text content of the active selection as an `AttributedString`.
    public var selectedAttributedString: AttributedString {
        document.attributedString(in: globalSelectedRange)
    }
    
    /// A Boolean value indicating whether there is an active, non-empty selection.
    public var hasSelection: Bool {
        !globalSelectedRange.isEmpty && !selectedText.isEmpty
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
    
    /// Returns the identifiers of all elements that currently contain a non-empty selection, cast to the given type in visual reading order.
    ///
    /// - Parameter type: The concrete identifier type to extract. Defaults to `ID.self`.
    public func selectedIDs<ID: Hashable>(_ type: ID.Type = ID.self) -> [ID] {
        document.slices.compactMap { slice in
            guard let range = selections[slice.element.id], !range.isEmpty else { return nil }
            return slice.element.id.base as? ID
        }
    }
    
    /// The identifiers of all elements that currently contain a non-empty selection, in visual reading order.
    public var selectedIDs: [AnyHashable] {
        document.slices.compactMap { slice in
            guard let range = selections[slice.element.id], !range.isEmpty else { return nil }
            return slice.element.id
        }
    }
}
