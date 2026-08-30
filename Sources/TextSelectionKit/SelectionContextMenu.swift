import SwiftUI

#if os(macOS)
import AppKit
#elseif os(iOS) || os(visionOS) || os(tvOS)
import UIKit
#endif

// MARK: - Selection Menu Context

/// Contextual information provided to custom selection menu builders.
public struct SelectionMenuContext: @unchecked Sendable {
    /// The plain text content currently selected.
    public let selectedText: String
    
    /// The formatted rich text content currently selected.
    public let selectedAttributedString: AttributedString
    
    /// The continuous character range of the active selection in the virtual document.
    public let globalSelectedRange: Range<Int>
    
    /// The identifiers of all elements containing active selection, in document layout order.
    public let selectedIDs: [AnyHashable]
    
    /// A Boolean value indicating whether there is an active, non-empty selection.
    public var hasSelection: Bool {
        !selectedText.isEmpty && !globalSelectedRange.isEmpty
    }
    
    public init(
        selectedText: String,
        selectedAttributedString: AttributedString = AttributedString(),
        globalSelectedRange: Range<Int> = 0..<0,
        selectedIDs: [AnyHashable] = []
    ) {
        self.selectedText = selectedText
        self.selectedAttributedString = selectedAttributedString
        self.globalSelectedRange = globalSelectedRange
        self.selectedIDs = selectedIDs
    }
}

// MARK: - Selection Menu Placement

/// Defines the position of custom context menu items relative to default system menu items.
public enum SelectionMenuPlacement: Sendable, Equatable {
    /// Custom items appear after default system items (Copy, Select All, etc.).
    case append
    
    /// Custom items appear before default system items.
    case prepend
    
    /// Custom items completely replace default system items.
    case replace
}

// MARK: - Keyboard Shortcut

/// Represents a cross-platform keyboard shortcut for a selection menu item.
public struct SelectionKeyboardShortcut: Sendable, Equatable {
    public let key: KeyEquivalent
    public let modifiers: EventModifiers
    
    public init(_ key: KeyEquivalent, modifiers: EventModifiers = .command) {
        self.key = key
        self.modifiers = modifiers
    }
    
    public static func == (lhs: SelectionKeyboardShortcut, rhs: SelectionKeyboardShortcut) -> Bool {
        lhs.key == rhs.key && lhs.modifiers.rawValue == rhs.modifiers.rawValue
    }
}

// MARK: - Selection Menu Item Protocol

/// A type that can be converted into selection context menu items.
public protocol SelectionMenuItemConvertible: Sendable {
    @MainActor
    func makeParsedMenuItems() -> [ParsedMenuItem]
}

// MARK: - Localization Helpers

internal enum MenuLocalizationHelper {
    static func resolve(_ key: LocalizedStringKey) -> String {
        let desc = String(describing: key)
        var rawKey = desc
        if let startRange = desc.range(of: "key: \""),
           let endRange = desc.range(of: "\"", range: startRange.upperBound..<desc.endIndex) {
            rawKey = String(desc[startRange.upperBound..<endRange.lowerBound])
        }
        return Bundle.main.localizedString(forKey: rawKey, value: rawKey, table: nil)
    }
    
    static func resolve(_ resource: LocalizedStringResource) -> String {
        String(localized: resource)
    }
    
    static func resolve(
        localized key: String.LocalizationValue,
        table: String? = nil,
        bundle: Bundle? = nil,
        locale: Locale = .current
    ) -> String {
        String(localized: key, table: table, bundle: bundle, locale: locale)
    }
}

// MARK: - Dedicated Menu Item Structs

/// A button menu item in a selection context menu with first-class localization support.
public struct SelectionButton: SelectionMenuItemConvertible, @unchecked Sendable {
    public let title: String
    public let systemImage: String?
    public let role: ButtonRole?
    public let isEnabled: Bool
    public let displayedShortcut: SelectionKeyboardShortcut?
    public let action: @MainActor () -> Void
    
    /// Creates a selection button from a localized string key (including string literals).
    public init(
        _ titleKey: LocalizedStringKey,
        systemImage: String? = nil,
        role: ButtonRole? = nil,
        isEnabled: Bool = true,
        displayedShortcut: SelectionKeyboardShortcut? = nil,
        action: @escaping @MainActor () -> Void
    ) {
        self.title = MenuLocalizationHelper.resolve(titleKey)
        self.systemImage = systemImage
        self.role = role
        self.isEnabled = isEnabled
        self.displayedShortcut = displayedShortcut
        self.action = action
    }
    
    /// Creates a selection button from a localized string resource.
    public init(
        resource: LocalizedStringResource,
        systemImage: String? = nil,
        role: ButtonRole? = nil,
        isEnabled: Bool = true,
        displayedShortcut: SelectionKeyboardShortcut? = nil,
        action: @escaping @MainActor () -> Void
    ) {
        self.title = MenuLocalizationHelper.resolve(resource)
        self.systemImage = systemImage
        self.role = role
        self.isEnabled = isEnabled
        self.displayedShortcut = displayedShortcut
        self.action = action
    }
    
    /// Creates a selection button from a localized key with optional table, bundle, and locale overrides.
    public init(
        localized key: String.LocalizationValue,
        table: String? = nil,
        bundle: Bundle? = nil,
        locale: Locale = .current,
        systemImage: String? = nil,
        role: ButtonRole? = nil,
        isEnabled: Bool = true,
        displayedShortcut: SelectionKeyboardShortcut? = nil,
        action: @escaping @MainActor () -> Void
    ) {
        self.title = MenuLocalizationHelper.resolve(localized: key, table: table, bundle: bundle, locale: locale)
        self.systemImage = systemImage
        self.role = role
        self.isEnabled = isEnabled
        self.displayedShortcut = displayedShortcut
        self.action = action
    }
    
    /// Creates a selection button that displays the given string verbatim without localization lookup.
    public init(
        verbatim title: String,
        systemImage: String? = nil,
        role: ButtonRole? = nil,
        isEnabled: Bool = true,
        displayedShortcut: SelectionKeyboardShortcut? = nil,
        action: @escaping @MainActor () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.role = role
        self.isEnabled = isEnabled
        self.displayedShortcut = displayedShortcut
        self.action = action
    }
    
    /// Attaches a purely visual keyboard shortcut display to the menu button.
    public func displayedShortcut(_ key: KeyEquivalent, modifiers: EventModifiers = .command) -> SelectionButton {
        SelectionButton(
            verbatim: title,
            systemImage: systemImage,
            role: role,
            isEnabled: isEnabled,
            displayedShortcut: SelectionKeyboardShortcut(key, modifiers: modifiers),
            action: action
        )
    }
    
    /// Attaches a purely visual keyboard shortcut display to the menu button.
    public func displayedShortcut(_ shortcut: SelectionKeyboardShortcut?) -> SelectionButton {
        SelectionButton(
            verbatim: title,
            systemImage: systemImage,
            role: role,
            isEnabled: isEnabled,
            displayedShortcut: shortcut,
            action: action
        )
    }
    
    /// Modifies the enabled state of the menu button.
    public func disabled(_ disabled: Bool) -> SelectionButton {
        SelectionButton(
            verbatim: title,
            systemImage: systemImage,
            role: role,
            isEnabled: !disabled,
            displayedShortcut: displayedShortcut,
            action: action
        )
    }
    
    @MainActor
    public func makeParsedMenuItems() -> [ParsedMenuItem] {
        [.action(
            title: title,
            systemImage: systemImage,
            role: role,
            isEnabled: isEnabled,
            displayedShortcut: displayedShortcut,
            action: action
        )]
    }
}

/// A submenu container in a selection context menu with localization support.
public struct SelectionMenu: SelectionMenuItemConvertible, @unchecked Sendable {
    public let title: String
    public let systemImage: String?
    public let items: [any SelectionMenuItemConvertible]
    
    /// Creates a submenu with a localized string key (including string literals).
    public init(
        _ titleKey: LocalizedStringKey,
        systemImage: String? = nil,
        @SelectionMenuBuilder content: () -> [any SelectionMenuItemConvertible]
    ) {
        self.title = MenuLocalizationHelper.resolve(titleKey)
        self.systemImage = systemImage
        self.items = content()
    }
    
    /// Creates a submenu with a localized string resource.
    public init(
        resource: LocalizedStringResource,
        systemImage: String? = nil,
        @SelectionMenuBuilder content: () -> [any SelectionMenuItemConvertible]
    ) {
        self.title = MenuLocalizationHelper.resolve(resource)
        self.systemImage = systemImage
        self.items = content()
    }
    
    /// Creates a submenu with a localized key and optional table/bundle/locale.
    public init(
        localized key: String.LocalizationValue,
        table: String? = nil,
        bundle: Bundle? = nil,
        locale: Locale = .current,
        systemImage: String? = nil,
        @SelectionMenuBuilder content: () -> [any SelectionMenuItemConvertible]
    ) {
        self.title = MenuLocalizationHelper.resolve(localized: key, table: table, bundle: bundle, locale: locale)
        self.systemImage = systemImage
        self.items = content()
    }
    
    /// Creates a submenu with a verbatim string title without localization lookup.
    public init(
        verbatim title: String,
        systemImage: String? = nil,
        @SelectionMenuBuilder content: () -> [any SelectionMenuItemConvertible]
    ) {
        self.title = title
        self.systemImage = systemImage
        self.items = content()
    }
    
    @MainActor
    public func makeParsedMenuItems() -> [ParsedMenuItem] {
        let childParsed = items.flatMap { $0.makeParsedMenuItems() }
        return [.submenu(title: title, systemImage: systemImage, items: childParsed)]
    }
}

/// A visual separator in a selection context menu.
public struct SelectionDivider: SelectionMenuItemConvertible, Sendable {
    public init() {}
    
    @MainActor
    public func makeParsedMenuItems() -> [ParsedMenuItem] {
        [.separator]
    }
}

/// Dynamic menu item factory helpers.
public struct SelectionMenuItem: SelectionMenuItemConvertible, @unchecked Sendable {
    private let generator: @MainActor () -> [ParsedMenuItem]
    
    public init(_ item: any SelectionMenuItemConvertible) {
        self.generator = { item.makeParsedMenuItems() }
    }
    
    public static func button(
        _ titleKey: LocalizedStringKey,
        systemImage: String? = nil,
        role: ButtonRole? = nil,
        isEnabled: Bool = true,
        displayedShortcut: SelectionKeyboardShortcut? = nil,
        action: @escaping @MainActor () -> Void
    ) -> SelectionMenuItem {
        SelectionMenuItem(SelectionButton(
            titleKey,
            systemImage: systemImage,
            role: role,
            isEnabled: isEnabled,
            displayedShortcut: displayedShortcut,
            action: action
        ))
    }
    
    public static func button(
        resource: LocalizedStringResource,
        systemImage: String? = nil,
        role: ButtonRole? = nil,
        isEnabled: Bool = true,
        displayedShortcut: SelectionKeyboardShortcut? = nil,
        action: @escaping @MainActor () -> Void
    ) -> SelectionMenuItem {
        SelectionMenuItem(SelectionButton(
            resource: resource,
            systemImage: systemImage,
            role: role,
            isEnabled: isEnabled,
            displayedShortcut: displayedShortcut,
            action: action
        ))
    }
    
    public static func button(
        verbatim title: String,
        systemImage: String? = nil,
        role: ButtonRole? = nil,
        isEnabled: Bool = true,
        displayedShortcut: SelectionKeyboardShortcut? = nil,
        action: @escaping @MainActor () -> Void
    ) -> SelectionMenuItem {
        SelectionMenuItem(SelectionButton(
            verbatim: title,
            systemImage: systemImage,
            role: role,
            isEnabled: isEnabled,
            displayedShortcut: displayedShortcut,
            action: action
        ))
    }
    
    public static func divider() -> SelectionMenuItem {
        SelectionMenuItem(SelectionDivider())
    }
    
    public static func menu(
        _ titleKey: LocalizedStringKey,
        systemImage: String? = nil,
        @SelectionMenuBuilder content: () -> [any SelectionMenuItemConvertible]
    ) -> SelectionMenuItem {
        SelectionMenuItem(SelectionMenu(titleKey, systemImage: systemImage, content: content))
    }
    
    public static func menu(
        resource: LocalizedStringResource,
        systemImage: String? = nil,
        @SelectionMenuBuilder content: () -> [any SelectionMenuItemConvertible]
    ) -> SelectionMenuItem {
        SelectionMenuItem(SelectionMenu(resource: resource, systemImage: systemImage, content: content))
    }
    
    public static func menu(
        verbatim title: String,
        systemImage: String? = nil,
        @SelectionMenuBuilder content: () -> [any SelectionMenuItemConvertible]
    ) -> SelectionMenuItem {
        SelectionMenuItem(SelectionMenu(verbatim: title, systemImage: systemImage, content: content))
    }
    
    @MainActor
    public func makeParsedMenuItems() -> [ParsedMenuItem] {
        generator()
    }
}

// MARK: - Internal Parsed Menu Item

public enum ParsedMenuItem: @unchecked Sendable {
    case action(
        title: String,
        systemImage: String?,
        role: ButtonRole?,
        isEnabled: Bool,
        displayedShortcut: SelectionKeyboardShortcut?,
        action: @MainActor () -> Void
    )
    case separator
    case submenu(
        title: String,
        systemImage: String?,
        items: [ParsedMenuItem]
    )
}

// MARK: - Selection Menu Result Builder

@resultBuilder
public struct SelectionMenuBuilder {
    public static func buildBlock(_ components: [any SelectionMenuItemConvertible]...) -> [any SelectionMenuItemConvertible] {
        components.flatMap { $0 }
    }
    
    public static func buildExpression(_ item: any SelectionMenuItemConvertible) -> [any SelectionMenuItemConvertible] {
        [item]
    }
    
    public static func buildExpression(_ items: [any SelectionMenuItemConvertible]) -> [any SelectionMenuItemConvertible] {
        items
    }
    
    public static func buildOptional(_ component: [any SelectionMenuItemConvertible]?) -> [any SelectionMenuItemConvertible] {
        component ?? []
    }
    
    public static func buildEither(first component: [any SelectionMenuItemConvertible]) -> [any SelectionMenuItemConvertible] {
        component
    }
    
    public static func buildEither(second component: [any SelectionMenuItemConvertible]) -> [any SelectionMenuItemConvertible] {
        component
    }
    
    public static func buildArray(_ components: [[any SelectionMenuItemConvertible]]) -> [any SelectionMenuItemConvertible] {
        components.flatMap { $0 }
    }
}

// MARK: - Selection Context Menu Provider (Environment)

public struct SelectionContextMenuProvider: @unchecked Sendable {
    public let placement: SelectionMenuPlacement
    public let builder: @MainActor (SelectionMenuContext) -> [ParsedMenuItem]
    
    public init(
        placement: SelectionMenuPlacement = .append,
        builder: @escaping @MainActor (SelectionMenuContext) -> [ParsedMenuItem]
    ) {
        self.placement = placement
        self.builder = builder
    }
}

extension EnvironmentValues {
    @Entry public var selectionContextMenuProvider: SelectionContextMenuProvider? = nil
}

// MARK: - View Extension

extension View {
    /// Configures custom context menu items for selected text using dedicated menu types (`SelectionButton`, `SelectionMenu`, `SelectionDivider`).
    ///
    /// ```swift
    /// SelectionContainer {
    ///     ArticleContentView()
    /// }
    /// .selectionContextMenu(placement: .append) { context in
    ///     SelectionButton("Highlight Selection", systemImage: "highlighter") {
    ///         print("Highlighting: \(context.selectedText)")
    ///     }
    ///     .keyboardShortcut("h", modifiers: [.command, .shift])
    ///
    ///     SelectionButton("Quote in Reply", systemImage: "quote.opening") {
    ///         replyComposer.insert(context.selectedText)
    ///     }
    ///
    ///     SelectionDivider()
    ///
    ///     SelectionMenu("Share Selection", systemImage: "square.and.arrow.up") {
    ///         SelectionButton("To Notes", systemImage: "note.text") { ... }
    ///         SelectionButton("To Messages", systemImage: "message") { ... }
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - placement: The placement of custom menu items relative to default system items (Copy, Select All, etc.). Defaults to `.append`.
    ///   - content: A menu builder producing custom menu items for the given ``SelectionMenuContext``.
    public func selectionContextMenu(
        placement: SelectionMenuPlacement = .append,
        @SelectionMenuBuilder content: @escaping (SelectionMenuContext) -> [any SelectionMenuItemConvertible]
    ) -> some View {
        let provider = SelectionContextMenuProvider(placement: placement) { context in
            let convertibles = content(context)
            return convertibles.flatMap { $0.makeParsedMenuItems() }
        }
        return environment(\.selectionContextMenuProvider, provider)
    }
}
