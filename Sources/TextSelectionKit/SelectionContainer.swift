import SwiftUI

// MARK: - Selection Hit-Test Policy

/// Defines how pointer and touch hit-testing is performed within a ``SelectionContainer``.
public enum SelectionHitTestPolicy: Sendable, Equatable {
    /// Captures selection gestures strictly on and immediately near selectable text elements.
    ///
    /// This is the default policy. It ensures that non-text interactive controls like `Button`, `Toggle`,
    /// or `TextField` inside the container can receive clicks and taps without gesture conflicts.
    ///
    /// - Parameter padding: The hit-test expansion margin around text elements, in points. Defaults to 4.
    case textOnly(padding: CGFloat = 4)
    
    /// Captures selection gestures anywhere across the entire container bounds.
    ///
    /// Suitable for text document readers, articles, notes, or markdown viewers where drag selection
    /// can be initiated smoothly from empty margins or padding.
    case container
    
    /// A text-only hit-testing policy with the default 4-point padding.
    public static let textOnly: SelectionHitTestPolicy = .textOnly(padding: 4)
}

// MARK: - Selection Container

/// A view container that coordinates continuous, multi-element text selection across child ``SelectableText`` views.
///
/// Standard SwiftUI text selection isolates each `Text` view into an independent selection region.
/// Wrapping a view hierarchy in a `SelectionContainer` synthesizes a unified document model, allowing
/// users to drag across headings, paragraphs, dividers, and columns.
///
/// ```swift
/// SelectionContainer {
///     VStack(alignment: .leading, spacing: 12) {
///         SelectableText("Heading")
///             .font(.headline)
///         Divider()
///         SelectableText("Body paragraph selectable together with the heading.")
///     }
/// }
/// ```
public struct SelectionContainer<Content: View>: View {
    private let content: Content
    private let externalManager: SelectionManager?
    private let hitTestPolicy: SelectionHitTestPolicy
    @State private var internalManager = SelectionManager()
    
    private var effectiveManager: SelectionManager {
        externalManager ?? internalManager
    }
    
    /// Creates a selection container with an optional external manager and hit-test policy.
    ///
    /// - Parameters:
    ///   - manager: An optional external ``SelectionManager`` to programmatically observe or control selection.
    ///     When `nil`, an internal manager is created and maintained automatically.
    ///   - hitTestPolicy: The policy governing pointer and touch event capture. Defaults to ``SelectionHitTestPolicy/textOnly``.
    ///   - content: A view builder producing the view hierarchy containing ``SelectableText`` elements.
    public init(
        manager: SelectionManager? = nil,
        hitTestPolicy: SelectionHitTestPolicy = .textOnly,
        @ViewBuilder content: () -> Content
    ) {
        self.externalManager = manager
        self.hitTestPolicy = hitTestPolicy
        self.content = content()
    }
    
    public var body: some View {
        let manager = effectiveManager
        content
            .environment(manager)
            .coordinateSpace(.named("SelectionContainerCoordinateSpace"))
            .onPreferenceChange(ElementRegistrationKey.self) { elements in
                manager.updateRegisteredElements(elements)
            }
            .overlay(OverlayContainer(manager: manager, hitTestPolicy: hitTestPolicy))
    }
    
    private struct OverlayContainer: View {
        let manager: SelectionManager
        let hitTestPolicy: SelectionHitTestPolicy
        @Environment(\.selectionContextMenuProvider) private var contextMenuProvider
        
        var body: some View {
            #if os(macOS)
            MacOSSelectionOverlay(manager: manager, hitTestPolicy: hitTestPolicy, contextMenuProvider: contextMenuProvider)
            #else
            IOSSelectionOverlay(manager: manager, hitTestPolicy: hitTestPolicy, contextMenuProvider: contextMenuProvider)
            #endif
        }
    }
}

// MARK: - View Extension

extension View {
    /// Wraps the view in a ``SelectionContainer`` to coordinate multi-element text selection across child ``SelectableText`` views.
    ///
    /// - Parameters:
    ///   - manager: An optional external ``SelectionManager`` to programmatically observe or control selection.
    ///   - hitTestPolicy: The policy governing pointer and touch event capture. Defaults to ``SelectionHitTestPolicy/textOnly``.
    public func selectionContainer(
        manager: SelectionManager? = nil,
        hitTestPolicy: SelectionHitTestPolicy = .textOnly
    ) -> some View {
        SelectionContainer(manager: manager, hitTestPolicy: hitTestPolicy) {
            self
        }
    }
}
