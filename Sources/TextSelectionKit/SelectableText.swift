import SwiftUI
import os

#if DEBUG
private let selectionLogger = Logger(subsystem: "SelectionTesting", category: "SelectableText")
#endif

// MARK: - Preference Keys & Environment Keys

struct ElementRegistrationKey: PreferenceKey {
    static let defaultValue: [TextElementRegistration] = []
    static func reduce(value: inout [TextElementRegistration], nextValue: () -> [TextElementRegistration]) {
        value.append(contentsOf: nextValue())
    }
}

extension EnvironmentValues {
    /// The explicit ordering index used to determine selection traversal sequence in a ``SelectionContainer``.
    ///
    /// When elements have identical `selectionOrderIndex` values (default is `0`), the container
    /// orders text elements by their natural 2D layout geometry (top-to-bottom, then left-to-right).
    /// Elements with lower indices are always sequenced before elements with higher indices.
    @Entry public var selectionOrderIndex: Int = 0
    
    /// A Boolean value indicating whether text selection is disabled for child ``SelectableText`` views.
    ///
    /// Defaults to `false`. When `true`, child ``SelectableText`` views do not participate in multi-element
    /// selection coordination and render as standard static text.
    @Entry public var isSelectableTextDisabled: Bool = false
    
    /// The delimiter string inserted after child ``SelectableText`` views when copying or synthesizing continuous text in a ``SelectionContainer``.
    ///
    /// Defaults to `"\n"` (newline). In horizontal layouts or inline tokens, set this to `" "` (space),
    /// `", "` (comma + space), or `""` (empty string) using the ``View/selectionDelimiter(_:)`` view modifier.
    @Entry public var selectionDelimiter: String = "\n"
}

extension View {
    /// Sets the explicit selection traversal order for child ``SelectableText`` views within a ``SelectionContainer``.
    ///
    /// ![Annotated layout diagram showing selection order arrows proceeding down the entire first column before moving to the top of the second column.](multicolumn-order)
    ///
    /// By default, a ``SelectionContainer`` traverses selectable text in visual row-by-row reading order:
    /// from top to bottom (Y-axis), and left to right (X-axis). While this works well for standard vertical
    /// flows, it can cause unintuitive jumping in multi-column grids or side-by-side card layouts where a user
    /// expects to select all content in the left column before moving to the right column.
    ///
    /// Applying `selectionOrder(_:)` assigns an integer priority that overrides visual layout coordinates.
    /// Elements with lower indices are always selected before elements with higher indices.
    ///
    /// ### Multi-Column Reading Example
    ///
    /// ```swift
    /// SelectionContainer {
    ///     HStack(alignment: .top, spacing: 20) {
    ///         // Left column - should be fully selected first
    ///         VStack(alignment: .leading) {
    ///             SelectableText("Column 1: Header")
    ///             SelectableText("Column 1: Paragraph 1")
    ///             SelectableText("Column 1: Paragraph 2")
    ///         }
    ///         .selectionOrder(0)
    ///
    ///         // Right column - should be selected after the entire left column
    ///         VStack(alignment: .leading) {
    ///             SelectableText("Column 2: Header")
    ///             SelectableText("Column 2: Paragraph 1")
    ///             SelectableText("Column 2: Paragraph 2")
    ///         }
    ///         .selectionOrder(1)
    ///     }
    /// }
    /// ```
    ///
    /// - Parameter index: An integer specifying the sort priority. Defaults to `0`. Lower values are sequenced first.
    public func selectionOrder(_ index: Int) -> some View {
        environment(\.selectionOrderIndex, index)
    }
    
    /// Disables text selection for child ``SelectableText`` views within this view hierarchy.
    ///
    /// When applied, descendant ``SelectableText`` views will not participate in multi-element
    /// drag selection, will be excluded from the surrounding ``SelectionContainer``'s virtual layout,
    /// and will render as standard non-selectable text.
    ///
    /// ```swift
    /// VStack {
    ///     SelectableText("This text is selectable.")
    ///
    ///     VStack {
    ///         SelectableText("Excluded text 1")
    ///         SelectableText("Excluded text 2")
    ///     }
    ///     .selectableTextDisabled()
    /// }
    /// ```
    ///
    /// - Parameter disabled: A Boolean value indicating whether text selection is disabled. Defaults to `true`.
    public func selectableTextDisabled(_ disabled: Bool = true) -> some View {
        environment(\.isSelectableTextDisabled, disabled)
    }
    
    /// Sets the delimiter inserted between child ``SelectableText`` views when copying or synthesizing continuous text in a ``SelectionContainer``.
    ///
    /// By default, a newline character (`"\n"`) is inserted between discrete text elements.
    /// Use this modifier on horizontal stacks (`HStack`), inline tokens, or comma-separated lists where elements
    /// should be separated by a space (`" "`), comma (`", "`), or no delimiter (`""`).
    ///
    /// ```swift
    /// HStack {
    ///     SelectableText("John")
    ///     SelectableText("Doe")
    /// }
    /// .selectionDelimiter(" ")
    /// // Copies as: "John Doe"
    /// ```
    ///
    /// - Parameter delimiter: The string delimiter to insert between selectable text elements. Defaults to `"\n"`.
    public func selectionDelimiter(_ delimiter: String) -> some View {
        environment(\.selectionDelimiter, delimiter)
    }
}

// MARK: - High-Performance Selectable Text View

/// A view that displays selectable text coordinated by an enclosing ``SelectionContainer``.
///
/// Use `SelectableText` in place of SwiftUI's `Text` when you want text to participate in multi-element
/// drag selection across view boundaries.
///
/// If rendered outside of a ``SelectionContainer``, `SelectableText` falls back to individual
/// `.textSelection(.enabled)` behavior and logs a diagnostic warning in debug builds.
public struct SelectableText: View {
    let rawText: String
    let attributedText: AttributedString
    let customId: AnyHashable?
    
    // Stable persistent element identity if customId is not provided
    @State private var fallbackId = UUID()
    
    private var effectiveId: AnyHashable {
        customId ?? AnyHashable(fallbackId)
    }
    
    @Environment(\.font) private var environmentFont
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.multilineTextAlignment) private var multilineTextAlignment
    @Environment(\.lineSpacing) private var lineSpacing
    @Environment(\.lineLimit) private var lineLimit
    @Environment(\.truncationMode) private var truncationMode
    @Environment(\.textCase) private var textCase
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(SelectionManager.self) private var selectionManager: SelectionManager?
    @Environment(\.selectionOrderIndex) private var orderIndex
    @Environment(\.isSelectableTextDisabled) private var isSelectableTextDisabled
    @Environment(\.selectionDelimiter) private var selectionDelimiter
    
    /// Creates a selectable text view from a localized string resource.
    ///
    /// String literals and string interpolations passed to `SelectableText("...")` use this initializer,
    /// participating in full Foundation localization and inline Markdown rendering.
    ///
    /// - Parameters:
    ///   - resource: The localized string resource to look up.
    ///   - id: An optional custom identifier for element-level selection queries. Defaults to `nil`.
    public init(_ resource: LocalizedStringResource, id: AnyHashable? = nil) {
        let attr = AttributedString(localized: resource)
        self.attributedText = attr
        self.rawText = String(attr.characters)
        self.customId = id
    }
    
    /// Creates a selectable text view from a localized key with optional table, bundle, and locale overrides.
    ///
    /// Automatically parses inline Markdown syntax within the resolved localized string.
    ///
    /// - Parameters:
    ///   - key: The key for the localized string in the strings table.
    ///   - table: The name of the strings table to search.
    ///   - bundle: The bundle containing the strings table.
    ///   - locale: The locale for string localization.
    ///   - id: An optional custom identifier for element-level selection queries. Defaults to `nil`.
    public init(localized key: String.LocalizationValue, table: String? = nil, bundle: Bundle? = nil, locale: Locale = .current, id: AnyHashable? = nil) {
        let raw = String(localized: key, table: table, bundle: bundle, locale: locale)
        if let attr = try? AttributedString(markdown: raw, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            self.attributedText = attr
            self.rawText = String(attr.characters)
        } else {
            self.attributedText = AttributedString(raw)
            self.rawText = raw
        }
        self.customId = id
    }
    
    /// Creates a selectable text view from a localized string key.
    ///
    /// - Parameters:
    ///   - key: The key for the localized string.
    ///   - id: An optional custom identifier for element-level selection queries. Defaults to `nil`.
    public init(localizedKey key: LocalizedStringKey, id: AnyHashable? = nil) {
        let desc = String(describing: key)
        var rawKey = desc
        if let startRange = desc.range(of: "key: \""),
           let endRange = desc.range(of: "\"", range: startRange.upperBound..<desc.endIndex) {
            rawKey = String(desc[startRange.upperBound..<endRange.lowerBound])
        }
        let localized = Bundle.main.localizedString(forKey: rawKey, value: rawKey, table: nil)
        if let attr = try? AttributedString(markdown: localized, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            self.attributedText = attr
            self.rawText = String(attr.characters)
        } else {
            self.attributedText = AttributedString(localized)
            self.rawText = localized
        }
        self.customId = id
    }
    
    /// Creates a selectable text view from a runtime string without localization or Markdown parsing.
    ///
    /// This matches SwiftUI `Text(someString)` behavior: dynamic string variables are displayed verbatim.
    /// To parse inline Markdown from a dynamic string, use ``init(markdown:id:)``.
    ///
    /// - Parameters:
    ///   - content: The dynamic string to display verbatim.
    ///   - id: An optional custom identifier for element-level selection queries. Defaults to `nil`.
    @_disfavoredOverload
    public init<S: StringProtocol>(_ content: S, id: AnyHashable? = nil) {
        let str = String(content)
        self.attributedText = AttributedString(str)
        self.rawText = str
        self.customId = id
    }
    
    /// Creates a selectable text view that displays the given string verbatim without Markdown parsing.
    ///
    /// - Parameters:
    ///   - text: The exact string to display.
    ///   - id: An optional custom identifier for element-level selection queries. Defaults to `nil`.
    public init(verbatim text: String, id: AnyHashable? = nil) {
        self.attributedText = AttributedString(text)
        self.rawText = text
        self.customId = id
    }
    
    /// Creates a selectable text view by parsing inline Markdown formatting.
    ///
    /// - Parameters:
    ///   - markdown: A string containing inline Markdown syntax.
    ///   - id: An optional custom identifier for element-level selection queries. Defaults to `nil`.
    public init(markdown: String, id: AnyHashable? = nil) {
        if let attr = try? AttributedString(markdown: markdown, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            self.attributedText = attr
            self.rawText = String(attr.characters)
        } else {
            self.attributedText = AttributedString(markdown)
            self.rawText = markdown
        }
        self.customId = id
    }
    
    /// Creates a selectable text view from an attributed string.
    ///
    /// Preserves custom typography, colors, underlines, strikethroughs, and presentation intents.
    ///
    /// - Parameters:
    ///   - attributedString: The attributed string to display.
    ///   - id: An optional custom identifier for element-level selection queries. Defaults to `nil`.
    @_disfavoredOverload
    public init(_ attributedString: AttributedString, id: AnyHashable? = nil) {
        self.attributedText = attributedString
        self.rawText = String(attributedString.characters)
        self.customId = id
    }
    
    func applyingTextCase(_ textCase: Text.Case?) -> AttributedString {
        guard let textCase = textCase else { return attributedText }
        var result = AttributedString()
        for run in attributedText.runs {
            let runChars = attributedText[run.range].characters
            let transformedString: String
            switch textCase {
            case .uppercase:
                transformedString = String(runChars).uppercased()
            case .lowercase:
                transformedString = String(runChars).lowercased()
            @unknown default:
                transformedString = String(runChars)
            }
            
            var transformedRun = AttributedString(transformedString)
            transformedRun.setAttributes(run.attributes)
            result.append(transformedRun)
        }
        return result
    }
    
    private var effectiveAttributedText: AttributedString {
        applyingTextCase(textCase)
    }
    
    public var body: some View {
        let effectiveAttributed = effectiveAttributedText
        let effectiveRaw = String(effectiveAttributed.characters)
        
        if isSelectableTextDisabled {
            // Disabled selection: Render as plain static SwiftUI Text without registering preference or fallback
            Text(effectiveAttributed)
        } else if let manager = selectionManager {
            let platformFont = PlatformFontResolver.resolve(from: environmentFont, dynamicTypeSize: dynamicTypeSize)
            
            renderedSelectableText(
                manager: manager,
                effectiveAttributed: effectiveAttributed,
                effectiveRaw: effectiveRaw,
                platformFont: platformFont
            )
        } else {
            // Standalone Fallback: Standard SwiftUI text with selection enabled
            Text(effectiveAttributed)
                .textSelection(.enabled)
                .onAppear {
                    #if DEBUG
                    let snippet = effectiveRaw.count > 40 ? "\(effectiveRaw.prefix(37))..." : effectiveRaw
                    selectionLogger.warning("SelectableText(\"\(snippet, privacy: .public)\") is rendered outside of a SelectionContainer. Falling back to individual textSelection(.enabled). Wrap your view hierarchy in a SelectionContainer { ... } for multi-element selection coordination.")
                    #endif
                }
        }
    }
    
    @ViewBuilder
    private func renderedSelectableText(
        manager: SelectionManager,
        effectiveAttributed: AttributedString,
        effectiveRaw: String,
        platformFont: PlatformFont
    ) -> some View {
        let makeRegistration: (CGRect) -> TextElementRegistration = { frame in
            TextElementRegistration(
                id: effectiveId,
                text: effectiveRaw,
                attributedString: effectiveAttributed,
                frame: frame,
                font: platformFont,
                orderIndex: orderIndex,
                delimiter: selectionDelimiter,
                alignment: multilineTextAlignment,
                lineSpacing: lineSpacing,
                lineLimit: lineLimit,
                truncationMode: truncationMode,
                layoutDirection: layoutDirection
            )
        }
        
        if #available(iOS 18.0, macOS 15.0, visionOS 2.0, tvOS 18.0, watchOS 11.0, *) {
            Text(effectiveAttributed)
                .onGeometryChange(for: CGRect.self) { proxy in
                    proxy.frame(in: .named("SelectionContainerCoordinateSpace"))
                } action: { newFrame in
                    manager.registerElement(makeRegistration(newFrame))
                }
                .onDisappear {
                    manager.unregisterElement(id: effectiveId)
                }
        } else {
            Text(effectiveAttributed)
                .background(
                    GeometryReader { geometry in
                        Color.clear.preference(
                            key: ElementRegistrationKey.self,
                            value: [
                                makeRegistration(geometry.frame(in: .named("SelectionContainerCoordinateSpace")))
                            ]
                        )
                    }
                )
        }
    }
}

// MARK: - Direct Text Styling Modifiers

extension SelectableText {
    /// Applies bold weight to the text.
    ///
    /// - Parameter isActive: A Boolean value indicating whether to apply bold styling. Defaults to `true`.
    public func bold(_ isActive: Bool = true) -> SelectableText {
        guard isActive else { return self }
        var copy = self.attributedText
        for run in copy.runs {
            var intent = run.inlinePresentationIntent ?? []
            intent.insert(.stronglyEmphasized)
            copy[run.range].inlinePresentationIntent = intent
        }
        return SelectableText(copy, id: self.customId)
    }
    
    /// Applies italic styling to the text.
    ///
    /// - Parameter isActive: A Boolean value indicating whether to apply italic styling. Defaults to `true`.
    public func italic(_ isActive: Bool = true) -> SelectableText {
        guard isActive else { return self }
        var copy = self.attributedText
        for run in copy.runs {
            var intent = run.inlinePresentationIntent ?? []
            intent.insert(.emphasized)
            copy[run.range].inlinePresentationIntent = intent
        }
        return SelectableText(copy, id: self.customId)
    }
    
    /// Applies a monospaced font design to the text.
    ///
    /// - Parameter isActive: A Boolean value indicating whether to apply monospaced styling. Defaults to `true`.
    public func monospaced(_ isActive: Bool = true) -> SelectableText {
        guard isActive else { return self }
        var copy = self.attributedText
        for run in copy.runs {
            var intent = run.inlinePresentationIntent ?? []
            intent.insert(.code)
            copy[run.range].inlinePresentationIntent = intent
        }
        return SelectableText(copy, id: self.customId)
    }
    
    /// Applies a strikethrough line style to the text.
    ///
    /// - Parameters:
    ///   - isActive: A Boolean value indicating whether the strikethrough is drawn. Defaults to `true`.
    ///   - pattern: The line pattern to draw. Defaults to `.solid`.
    ///   - color: The color of the strikethrough line. If `nil`, uses the text foreground color.
    public func strikethrough(_ isActive: Bool = true, pattern: Text.LineStyle.Pattern = .solid, color: Color? = nil) -> SelectableText {
        var copy = self.attributedText
        if isActive {
            copy.strikethroughStyle = Text.LineStyle(pattern: pattern, color: color)
        } else {
            copy.strikethroughStyle = nil
        }
        return SelectableText(copy, id: self.customId)
    }
    
    /// Applies an underline style to the text.
    ///
    /// - Parameters:
    ///   - isActive: A Boolean value indicating whether the underline is drawn. Defaults to `true`.
    ///   - pattern: The line pattern to draw. Defaults to `.solid`.
    ///   - color: The color of the underline. If `nil`, uses the text foreground color.
    public func underline(_ isActive: Bool = true, pattern: Text.LineStyle.Pattern = .solid, color: Color? = nil) -> SelectableText {
        var copy = self.attributedText
        if isActive {
            copy.underlineStyle = Text.LineStyle(pattern: pattern, color: color)
        } else {
            copy.underlineStyle = nil
        }
        return SelectableText(copy, id: self.customId)
    }
    
    /// Sets the vertical offset of the text relative to its baseline.
    ///
    /// - Parameter baselineOffset: The distance in points to shift the text vertically.
    public func baselineOffset(_ baselineOffset: CGFloat) -> SelectableText {
        var copy = self.attributedText
        copy.baselineOffset = baselineOffset
        return SelectableText(copy, id: self.customId)
    }
    
    /// Sets the tracking (letter spacing) for the text.
    ///
    /// - Parameter tracking: The amount of additional space in points between characters.
    public func tracking(_ tracking: CGFloat) -> SelectableText {
        var copy = self.attributedText
        copy.tracking = tracking
        return SelectableText(copy, id: self.customId)
    }
    
    /// Sets the kerning between characters.
    ///
    /// - Parameter kerning: The spacing in points between character glyphs.
    public func kerning(_ kerning: CGFloat) -> SelectableText {
        var copy = self.attributedText
        copy.kern = kerning
        return SelectableText(copy, id: self.customId)
    }
    
    /// Sets the foreground color of the text.
    ///
    /// - Parameter color: The color to apply to the text, or `nil` to clear explicit foreground coloring.
    public func foregroundColor(_ color: Color?) -> SelectableText {
        var copy = self.attributedText
        copy.foregroundColor = color
        return SelectableText(copy, id: self.customId)
    }
    
    /// Sets the font for the text.
    ///
    /// - Parameter font: The font to apply to the text, or `nil` to clear explicit font styling.
    public func font(_ font: Font?) -> SelectableText {
        var copy = self.attributedText
        copy.font = font
        return SelectableText(copy, id: self.customId)
    }
    
    /// Combines two selectable text views into a single composite selectable text block.
    public static func + (lhs: SelectableText, rhs: SelectableText) -> SelectableText {
        var merged = lhs.attributedText
        merged.append(rhs.attributedText)
        return SelectableText(merged, id: lhs.customId)
    }
}
