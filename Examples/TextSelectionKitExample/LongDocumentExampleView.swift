import SwiftUI
import TextSelectionKit

/// A comprehensive, multi-section technical document demonstrating high-performance text selection
/// across deep hierarchies, diverse typography, multi-line paragraphs, inline code blocks,
/// callouts, tables, and right-to-left scripts.
public struct LongDocumentExampleView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectionManager = SelectionManager()

    public init() {}

    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }

    private var contentHorizontalPadding: CGFloat {
        isCompact ? 16 : 28
    }

    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - Sticky Selection Inspector Header
            selectionHUDHeader
                .background(.bar)

            Divider()

            ScrollView {
                SelectionContainer(manager: selectionManager, hitTestPolicy: .container) {
                    VStack(alignment: .leading, spacing: isCompact ? 22 : 28) {
                        
                        // MARK: - Document Header
                        documentHeaderSection

                        Divider()

                        // MARK: - Chapter 1: Introduction & State of Text Selection
                        chapter1Section

                        Divider()

                        // MARK: - Chapter 2: Virtual Document Synthesis & Coordinate Spaces
                        chapter2Section

                        Divider()

                        // MARK: - Chapter 3: Zero-Allocation CoreText Layout Engine
                        chapter3Section

                        Divider()

                        // MARK: - Chapter 4: Cross-Platform Native Tracking Overlays
                        chapter4Section

                        Divider()

                        // MARK: - Chapter 5: Bi-Directional & Multi-Script (RTL) Layouts
                        chapter5Section

                        Divider()

                        // MARK: - Chapter 6: Selection Physics, Word Snapping & Drag Hit-Testing
                        chapter6Section

                        Divider()

                        // MARK: - Chapter 7: Hit-Testing Policies & Interaction Safety
                        chapter7Section

                        Divider()

                        // MARK: - Chapter 8: Context Menus, Keyboard Shortcuts & Clipboard
                        chapter8Section

                        Divider()

                        // MARK: - Chapter 9: 120Hz ProMotion Benchmarks & Memory Profiling
                        chapter9Section

                        Divider()

                        // MARK: - Chapter 10: Complete Code Architecture & Integration
                        chapter10Section

                        Divider()

                        // MARK: - Footnotes & Bibliography
                        footnotesSection
                    }
                    .padding(.horizontal, contentHorizontalPadding)
                    .padding(.vertical, isCompact ? 20 : 28)
                }
                .selectionContextMenu(placement: .append) { context in
                    SelectionButton(
                        "Highlight Selection",
                        systemImage: "highlighter",
                        shortcut: SelectionKeyboardShortcut("h", modifiers: [.command, .shift])
                    ) {
                        print("Highlighted from LongDocument: \(context.selectedText)")
                    }

                    SelectionButton("Quote in Discussion", systemImage: "quote.opening") {
                        print("Quoting: \(context.selectedText)")
                    }

                    SelectionDivider()

                    SelectionMenu("Share Selection", systemImage: "square.and.arrow.up") {
                        SelectionButton("To Notes", systemImage: "note.text") { }
                        SelectionButton("To Messages", systemImage: "message") { }
                    }
                }
            }
        }
    }

    // MARK: - Selection HUD Header

    private var selectionHUDHeader: some View {
        Group {
            if isCompact {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        statusIndicatorView
                        Spacer()
                        hudActionButtons(iconOnly: true)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            } else {
                HStack(spacing: 16) {
                    statusIndicatorView
                    Spacer()
                    hudActionButtons(iconOnly: false)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
        }
    }

    private var statusIndicatorView: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Circle()
                    .fill(selectionManager.hasSelection ? Color.green : Color.secondary.opacity(0.4))
                    .frame(width: 8, height: 8)

                Text(selectionManager.hasSelection ? "Active Selection" : "Document Reader Mode")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(selectionManager.hasSelection ? .primary : .secondary)
            }

            if selectionManager.hasSelection {
                let chars = selectionManager.selectedText.count
                let words = selectionManager.selectedText.split(whereSeparator: \.isWhitespace).count
                Text("\(chars) chars • \(words) words • \(selectionManager.selectedIDs.count) element(s)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text(isCompact ? "Drag to select across elements" : "Drag mouse or finger from any margin to select across elements")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func hudActionButtons(iconOnly: Bool) -> some View {
        HStack(spacing: 6) {
            Button {
                selectionManager.selectAll()
            } label: {
                if iconOnly {
                    Image(systemName: "selection.pin.in.out")
                        .accessibilityLabel("Select All")
                } else {
                    Label("Select All", systemImage: "selection.pin.in.out")
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button {
                selectionManager.copySelection()
            } label: {
                if iconOnly {
                    Image(systemName: "doc.on.doc")
                        .accessibilityLabel("Copy")
                } else {
                    Label("Copy", systemImage: "doc.on.doc")
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(!selectionManager.hasSelection)

            Button {
                selectionManager.deselectAll()
            } label: {
                if iconOnly {
                    Image(systemName: "xmark.circle")
                        .accessibilityLabel("Clear")
                } else {
                    Label("Clear", systemImage: "xmark.circle")
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(!selectionManager.hasSelection)
        }
    }

    // MARK: - Document Header Section

    private var documentHeaderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                SelectableText("ARCHITECTURE WHITE PAPER", id: "meta-badge")
                    .font(.caption2.bold())
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1), in: .rect(cornerRadius: 6))

                SelectableText("SWIFTUI & CORETEXT", id: "meta-tag")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.1), in: .rect(cornerRadius: 6))
            }

            SelectableText("Deep Dive: Native Multi-Element Text Selection Architecture in Modern SwiftUI", id: "doc-title")
                .font(isCompact ? .title.bold() : .largeTitle.bold())

            SelectableText("A comprehensive exploration of virtual layout documents, CoreText line geometry caching, bi-directional script slicing, and cross-platform responder coordination.", id: "doc-subtitle")
                .font(isCompact ? .subheadline : .title3)
                .foregroundStyle(.secondary)
                .lineSpacing(3)

            WrapHStack(spacing: 8) {
                SelectableText("By **Alex Rivera** & **Team**", id: "author")
                    .font(.caption)

                SelectableText("•")
                    .foregroundStyle(.secondary)

                SelectableText("August 31, 2026", id: "date")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                SelectableText("•")
                    .foregroundStyle(.secondary)

                SelectableText("24 min read", id: "read-time")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Chapter 1

    private var chapter1Section: some View {
        VStack(alignment: .leading, spacing: 14) {
            SelectableText("1. The State of SwiftUI Text Selection", id: "ch1-title")
                .font(.title2.bold())

            SelectableText("Standard SwiftUI provides the `.textSelection(.enabled)` modifier, which allows users to highlight and copy text within a view hierarchy. However, under SwiftUI's default architecture, each individual `Text` view functions as an isolated island. Users cannot drag their cursor or finger to highlight text continuously across multiple paragraphs, across titles and body blocks, or through visual dividers and spacers.", id: "ch1-p1")
                .font(.body)
                .lineSpacing(4)

            SelectableText("In modern document readers, rich note applications, web browsers, and chat clients, seamless multi-paragraph selection is a foundational user expectation. When text selection fails to span multiple blocks, users encounter friction and interface rigidity.", id: "ch1-p2")
                .font(.body)
                .lineSpacing(4)

            // Quote Callout Block
            HStack(alignment: .top, spacing: 12) {
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: 4)

                VStack(alignment: .leading, spacing: 4) {
                    SelectableText("\"A great text selection experience is completely invisible to the user until it fails. True native feel demands sub-pixel caret accuracy, natural word snapping, and zero dropped frames during drag gestures.\"", id: "ch1-quote")
                        .font(.callout.italic())
                        .foregroundColor(.primary)

                    SelectableText("— Apple Human Interface Guidelines for Text Interaction", id: "ch1-quote-author")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(Color.blue.opacity(0.05), in: .rect(cornerRadius: 8))

            SelectableText("Replicating this continuous behavior without abandoning SwiftUI's declarative view hierarchy requires bridging declarative layout tree preferences with native low-level text engine subsystems.", id: "ch1-p3")
                .font(.body)
                .lineSpacing(4)
        }
    }

    // MARK: - Chapter 2

    private var chapter2Section: some View {
        VStack(alignment: .leading, spacing: 14) {
            SelectableText("2. Virtual Document Synthesis & Coordinate Spaces", id: "ch2-title")
                .font(.title2.bold())

            SelectableText("To coordinate multiple disjoint SwiftUI views, TextSelectionKit introduces the concept of a `VirtualTextDocument`. As each `SelectableText` view renders, it publishes its local bounding frame, resolved font, text alignment, line spacing, truncation mode, and attributed content up the view hierarchy.", id: "ch2-p1")
                .font(.body)
                .lineSpacing(4)

            SelectableText("On iOS 18+ and macOS 15+, this registration is powered by `.onGeometryChange(for:action:)`, providing zero-overhead frame tracking directly into the selection controller. On iOS 17 and macOS 14, the framework falls back gracefully to a custom `PreferenceKey` reducing pipeline.", id: "ch2-p2")
                .font(.body)
                .lineSpacing(4)

            // Diagram Box (Scrollable horizontally on narrow screens)
            VStack(alignment: .leading, spacing: 8) {
                SelectableText("VIRTUAL DOCUMENT COORDINATE MAPPING", id: "ch2-diagram-title")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    SelectableText("┌─────────────────────────────────────────────────────────────┐\n│ SelectionContainer (.coordinateSpace: \"SelectionContainer\")  │\n│                                                             │\n│  [Element 0: Heading]      Offset: 0..<32    (Frame: Y:0)   │\n│  ────────────── Delimiter: \\n (Offset: 32..<33) ─────────── │\n│  [Element 1: Paragraph 1]  Offset: 33..<185  (Frame: Y:48)  │\n│  ────────────── Delimiter: \\n (Offset: 185..<186) ───────── │\n│  [Element 2: Paragraph 2]  Offset: 186..<410 (Frame: Y:120) │\n│                                                             │\n│  1D Continuous Offset Space: 0 ........................ 410 │\n└─────────────────────────────────────────────────────────────┘", id: "ch2-diagram")
                        .font(.system(size: isCompact ? 11 : 12, design: .monospaced))
                        .foregroundStyle(.primary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.04), in: .rect(cornerRadius: 8))

            SelectableText("The enclosing `SelectionContainer` collects these registrations and synthesizes a continuous one-dimensional string index space mapped over the two-dimensional visual layout. Delimiters (such as newlines) are automatically accounted for between discrete visual blocks.", id: "ch2-p3")
                .font(.body)
                .lineSpacing(4)

            // Pro Tip Box
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.orange)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 4) {
                    SelectableText("Pro Tip: Explicit Traversal Ordering", id: "ch2-tip-title")
                        .font(.subheadline.bold())
                    SelectableText("When building complex multi-column grids or side-by-side cards, apply `.selectionOrder(index)` to explicitly control whether selection flows column-first or row-first. Lower indices are always sequenced before higher indices regardless of visual position.", id: "ch2-tip-body")
                        .font(.caption)
                }
            }
            .padding()
            .background(Color.orange.opacity(0.08), in: .rect(cornerRadius: 10))
        }
    }

    // MARK: - Chapter 3

    private var chapter3Section: some View {
        VStack(alignment: .leading, spacing: 14) {
            SelectableText("3. Zero-Allocation CoreText Layout Engine", id: "ch3-title")
                .font(.title2.bold())

            SelectableText("During high-frequency mouse drag events or touch gesture updates (running at 60Hz to 120Hz ProMotion refresh rates), calculating character bounding rects and hit-tests from scratch on every frame would trigger immense memory allocation pressure and visible frame stutter.", id: "ch3-p1")
                .font(.body)
                .lineSpacing(4)

            SelectableText("To solve this, TextSelectionKit employs a high-performance `CachedElementLayout` layer backed by CoreText `CTFramesetter`, `CTFrame`, and `CTLine` caches. Key architectural optimizations include:", id: "ch3-p2")
                .font(.body)
                .lineSpacing(4)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 8) {
                    SelectableText("•", id: "ch3-bullet1-dot").bold()
                    SelectableText("**Logarithmic Binary Search**: Global character offsets are located in $O(\\log N)$ time across element slices rather than linear $O(N)$ iteration.", id: "ch3-bullet1")
                        .font(.body)
                }

                HStack(alignment: .top, spacing: 8) {
                    SelectableText("•", id: "ch3-bullet2-dot").bold()
                    SelectableText("**Thread-Safe LRU Font Cache**: Dynamic type scaling and symbolic trait mutations are cached in a thread-safe `BoundedFontCache` protected by `OSAllocatedUnfairLock`.", id: "ch3-bullet2")
                        .font(.body)
                }

                HStack(alignment: .top, spacing: 8) {
                    SelectableText("•", id: "ch3-bullet3-dot").bold()
                    SelectableText("**Selective Invalidation**: Layout caches are preserved across view refreshes and only invalidated when frame dimensions deviate by $\\ge 0.5\\text{ pt}$ or text content mutations occur.", id: "ch3-bullet3")
                        .font(.body)
                }

                HStack(alignment: .top, spacing: 8) {
                    SelectableText("•", id: "ch3-bullet4-dot").bold()
                    SelectableText("**Accurate Typographic Line Pitch**: Accurately computes typographic ascents, descents, and line gaps to ensure selection highlights match exact baseline geometry without clipped glyphs.", id: "ch3-bullet4")
                        .font(.body)
                }
            }
            .padding(.leading, 6)
        }
    }

    // MARK: - Chapter 4

    private var chapter4Section: some View {
        VStack(alignment: .leading, spacing: 14) {
            SelectableText("4. Cross-Platform Native Tracking Overlays", id: "ch4-title")
                .font(.title2.bold())

            SelectableText("Rather than drawing synthetic selection rectangles with custom gesture recognizers, TextSelectionKit bridges directly into the native text selection subsystems of Apple platforms:", id: "ch4-p1")
                .font(.body)
                .lineSpacing(4)

            VStack(alignment: .leading, spacing: 12) {
                // macOS Box
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "macbook")
                            .foregroundStyle(.blue)
                        SelectableText("macOS AppKit Tracking Subsystem", id: "ch4-mac-title")
                            .font(.headline)
                    }

                    SelectableText("Uses `MacOSSelectionTrackingView` and `MacOSSelectionHighlightView`. Conforms to `acceptsFirstResponder`, listens for window key status notifications to alternate between `selectedTextBackgroundColor` and `unemphasizedSelectedTextBackgroundColor`, supports Shift-click range extensions, double-click word selection, triple-click paragraph selection, and standard AppKit dictionary lookups via `quickLook(with:)`.", id: "ch4-mac-body")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.blue.opacity(0.06), in: .rect(cornerRadius: 10))

                // iOS Box
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "iphone")
                            .foregroundStyle(.green)
                        SelectableText("iOS & iPadOS UIKit UITextInput Architecture", id: "ch4-ios-title")
                            .font(.headline)
                    }

                    SelectableText("Uses `NativeSelectionTrackingUIView` conforming fully to the `UITextInput` protocol with `UITextInteraction(for: .nonEditable)`. Generates `CustomTextSelectionRect` instances with accurate start/end flags for native selection grab handles, magnifying loupe tracking, and `UIEditMenuInteraction` integration.", id: "ch4-ios-body")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.green.opacity(0.06), in: .rect(cornerRadius: 10))
            }
        }
    }

    // MARK: - Chapter 5

    private var chapter5Section: some View {
        VStack(alignment: .leading, spacing: 14) {
            SelectableText("5. Bi-Directional & Right-to-Left (RTL) Layouts", id: "ch5-title")
                .font(.title2.bold())

            SelectableText("Supporting multi-element text selection in international software requires comprehensive handling of Right-to-Left (RTL) scripts, such as Arabic and Hebrew, alongside Left-to-Right (LTR) Latin text.", id: "ch5-p1")
                .font(.body)
                .lineSpacing(4)

            SelectableText("When text contains mixed scripts, CoreText decomposes lines into separate directional glyph runs (`CTRun`). TextSelectionKit inspects each run's string range to calculate non-overlapping, contiguous visual highlights across mixed-direction sentences:", id: "ch5-p2")
                .font(.body)
                .lineSpacing(4)

            // Mixed Arabic Sample Box
            VStack(alignment: .leading, spacing: 10) {
                SelectableText("SAMPLE BI-DIRECTIONAL TEXT BLOCK", id: "ch5-box-title")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                SelectableText("مرحباً بكم في نظام TextSelectionKit لتحديد النصوص المتعددة. يدعم هذا النظام تحديد النصوص باللغتين العربية والإنجليزية بسلاسة ودقة متناهية.", id: "ch5-arabic-text")
                    .font(.system(size: isCompact ? 15 : 16))
                    .lineSpacing(6)

                Divider()

                SelectableText("שלום עולם! זוהי דוגמה לבחירת טקסט רב-אלמנטים בעברית ובאנגלית בו-זמנית.", id: "ch5-hebrew-text")
                    .font(.system(size: isCompact ? 14 : 15))
                    .lineSpacing(4)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.purple.opacity(0.06), in: .rect(cornerRadius: 10))
        }
    }

    // MARK: - Chapter 6

    private var chapter6Section: some View {
        VStack(alignment: .leading, spacing: 14) {
            SelectableText("6. Selection Physics, Word Snapping & Drag Hit-Testing", id: "ch6-title")
                .font(.title2.bold())

            SelectableText("Hit-testing in a multi-element virtual document is fundamentally more complex than in a single text view. Points may fall between views, inside empty line margins, or on surrounding buttons. TextSelectionKit executes a multi-stage geometric evaluation:", id: "ch6-p1")
                .font(.body)
                .lineSpacing(4)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    SelectableText("1.", id: "ch6-num1").bold()
                    SelectableText("**Direct Bounding Frame Hit-Test**: If the pointer is directly over a text element's padded bounds, computes character index via `CTLineGetStringIndexForPosition`.", id: "ch6-step1")
                        .font(.body)
                }

                HStack(alignment: .top, spacing: 8) {
                    SelectableText("2.", id: "ch6-num2").bold()
                    SelectableText("**Document Bounds Clamping**: If the pointer is above or below the document bounding hull, clamps to index `0` or `totalLength`.", id: "ch6-step2")
                        .font(.body)
                }

                HStack(alignment: .top, spacing: 8) {
                    SelectableText("3.", id: "ch6-num3").bold()
                    SelectableText("**Horizontal Row Containment Priority**: When hit-testing in margins, elements on the same horizontal row are prioritized over vertically distant elements using a weighted distance metric: $D = (100 \\times dy^2) + dx^2$.", id: "ch6-step3")
                        .font(.body)
                }

                HStack(alignment: .top, spacing: 8) {
                    SelectableText("4.", id: "ch6-num4").bold()
                    SelectableText("**Word & Paragraph Snapping**: Double-clicking invokes `enumerateSubstrings(options: .byWords)` to snap selection bounds to full words. Triple-clicking expands to full paragraph boundaries.", id: "ch6-step4")
                        .font(.body)
                }
            }
            .padding(.leading, 6)
        }
    }

    // MARK: - Chapter 7

    private var chapter7Section: some View {
        VStack(alignment: .leading, spacing: 14) {
            SelectableText("7. Hit-Testing Policies & Non-Interfering Controls", id: "ch7-title")
                .font(.title2.bold())

            SelectableText("Real-world application screens contain interactive buttons, sliders, links, and toggles embedded directly alongside selectable text. If the selection overlay captured all pointer events, buttons would become unclickable.", id: "ch7-p1")
                .font(.body)
                .lineSpacing(4)

            SelectableText("To solve this, `SelectionContainer` provides two distinct hit-testing policies configured via `SelectionHitTestPolicy`:", id: "ch7-p2")
                .font(.body)
                .lineSpacing(4)

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "hand.tap")
                        .foregroundColor(.blue)
                        .font(.title3)

                    VStack(alignment: .leading, spacing: 4) {
                        SelectableText("SelectionHitTestPolicy.textOnly (Default)", id: "ch7-policy-text-title")
                            .font(.headline)
                        SelectableText("Captures selection events strictly on and within 4pt of selectable text elements. Taps on buttons, links, or toggles pass through seamlessly to SwiftUI controls.", id: "ch7-policy-text-body")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.blue.opacity(0.06), in: .rect(cornerRadius: 10))

                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "doc.text")
                        .foregroundColor(.indigo)
                        .font(.title3)

                    VStack(alignment: .leading, spacing: 4) {
                        SelectableText("SelectionHitTestPolicy.container", id: "ch7-policy-container-title")
                            .font(.headline)
                        SelectableText("Captures selection anywhere across the entire container bounding frame. Ideal for article readers, book viewers, and document viewers where users expect dragging to start from empty margins.", id: "ch7-policy-container-body")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.indigo.opacity(0.06), in: .rect(cornerRadius: 10))
            }
        }
    }

    // MARK: - Chapter 8

    private var chapter8Section: some View {
        VStack(alignment: .leading, spacing: 14) {
            SelectableText("8. Context Menus, Keyboard Shortcuts & Clipboard", id: "ch8-title")
                .font(.title2.bold())

            SelectableText("Selecting text is only half the experience—users also expect full clipboard integration, contextual actions, and keyboard shortcuts.", id: "ch8-p1")
                .font(.body)
                .lineSpacing(4)

            SelectableText("TextSelectionKit provides a dedicated context menu DSL using `SelectionButton`, `SelectionMenu`, and `SelectionDivider` attached via `.selectionContextMenu(placement:content:)`:", id: "ch8-p2")
                .font(.body)
                .lineSpacing(4)

            // Code Snippet Box with horizontal scroll for narrow screens
            VStack(alignment: .leading, spacing: 6) {
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 4) {
                        SelectableText("SelectionContainer {", id: "ch8-code1")
                            .font(.system(size: isCompact ? 12 : 13, design: .monospaced))
                        SelectableText("    ArticleView()", id: "ch8-code2")
                            .font(.system(size: isCompact ? 12 : 13, design: .monospaced))
                        SelectableText("}", id: "ch8-code3")
                            .font(.system(size: isCompact ? 12 : 13, design: .monospaced))
                        SelectableText(".selectionContextMenu(placement: .append) { context in", id: "ch8-code4")
                            .font(.system(size: isCompact ? 12 : 13, design: .monospaced))
                        SelectableText("    SelectionButton(\"Highlight\", systemImage: \"highlighter\", shortcut: SelectionKeyboardShortcut(\"h\")) {", id: "ch8-code5")
                            .font(.system(size: isCompact ? 12 : 13, design: .monospaced))
                        SelectableText("        highlightText(context.selectedText)", id: "ch8-code6")
                            .font(.system(size: isCompact ? 12 : 13, design: .monospaced))
                        SelectableText("    }", id: "ch8-code7")
                            .font(.system(size: isCompact ? 12 : 13, design: .monospaced))
                        SelectableText("    SelectionDivider()", id: "ch8-code8")
                            .font(.system(size: isCompact ? 12 : 13, design: .monospaced))
                        SelectableText("    SelectionMenu(\"Share\", systemImage: \"square.and.arrow.up\") {", id: "ch8-code9")
                            .font(.system(size: isCompact ? 12 : 13, design: .monospaced))
                        SelectableText("        SelectionButton(\"To Notes\", systemImage: \"note.text\") { }", id: "ch8-code10")
                            .font(.system(size: isCompact ? 12 : 13, design: .monospaced))
                        SelectableText("    }", id: "ch8-code11")
                            .font(.system(size: isCompact ? 12 : 13, design: .monospaced))
                        SelectableText("}", id: "ch8-code12")
                            .font(.system(size: isCompact ? 12 : 13, design: .monospaced))
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.12), in: .rect(cornerRadius: 8))

            SelectableText("When copied, text is serialized to the system pasteboard as both plain text (`String`) and rich formatted text (`RTF` on macOS and `AttributedString` on iOS).", id: "ch8-p3")
                .font(.body)
                .lineSpacing(4)
        }
    }

    // MARK: - Chapter 9

    private var chapter9Section: some View {
        VStack(alignment: .leading, spacing: 14) {
            SelectableText("9. 120Hz ProMotion Benchmarks & Memory Profiling", id: "ch9-title")
                .font(.title2.bold())

            SelectableText("Performance testing across long multi-page documents (over 10,000 words and 200+ elements) confirms sustained 120 FPS drag gesture performance with zero frame drops on Apple Silicon Macs and ProMotion iPad/iPhone devices.", id: "ch9-p1")
                .font(.body)
                .lineSpacing(4)

            // Benchmark Table (Adaptive Grid layout for iOS and macOS)
            VStack(alignment: .leading, spacing: 10) {
                SelectableText("BENCHMARK METRICS (APPLE M-SERIES / A-SERIES)", id: "ch9-table-title")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                if isCompact {
                    // Card style on compact iOS screens
                    VStack(spacing: 8) {
                        metricRowCard(operation: "Slice Binary Lookup", time: "< 0.002 ms", complexity: "O(log N)", id: "b1")
                        metricRowCard(operation: "Closest Global Offset", time: "< 0.015 ms", complexity: "O(N) coarse", id: "b2")
                        metricRowCard(operation: "Line Selection Rects", time: "< 0.020 ms", complexity: "O(Lines)", id: "b3")
                        metricRowCard(operation: "Memory Alloc In Drag", time: "0.0 KB (Zero)", complexity: "O(1)", id: "b4")
                    }
                } else {
                    // Multi-column table on regular / desktop screens
                    VStack(spacing: 6) {
                        HStack {
                            SelectableText("Operation", id: "th-op").font(.subheadline.bold()).frame(maxWidth: .infinity, alignment: .leading)
                            SelectableText("Time / Cost", id: "th-time").font(.subheadline.bold()).frame(width: 120, alignment: .leading)
                            SelectableText("Complexity", id: "th-comp").font(.subheadline.bold()).frame(width: 100, alignment: .leading)
                        }

                        Divider()

                        HStack {
                            SelectableText("Slice Binary Lookup", id: "tr1-op").font(.caption).frame(maxWidth: .infinity, alignment: .leading)
                            SelectableText("< 0.002 ms", id: "tr1-time").font(.caption).frame(width: 120, alignment: .leading)
                            SelectableText("O(log N)", id: "tr1-comp").font(.caption.monospaced()).frame(width: 100, alignment: .leading)
                        }

                        HStack {
                            SelectableText("Closest Global Offset", id: "tr2-op").font(.caption).frame(maxWidth: .infinity, alignment: .leading)
                            SelectableText("< 0.015 ms", id: "tr2-time").font(.caption).frame(width: 120, alignment: .leading)
                            SelectableText("O(N) coarse + O(1)", id: "tr2-comp").font(.caption.monospaced()).frame(width: 100, alignment: .leading)
                        }

                        HStack {
                            SelectableText("Line Selection Rects", id: "tr3-op").font(.caption).frame(maxWidth: .infinity, alignment: .leading)
                            SelectableText("< 0.020 ms", id: "tr3-time").font(.caption).frame(width: 120, alignment: .leading)
                            SelectableText("O(Lines)", id: "tr3-comp").font(.caption.monospaced()).frame(width: 100, alignment: .leading)
                        }

                        HStack {
                            SelectableText("Memory Alloc During Drag", id: "tr4-op").font(.caption).frame(maxWidth: .infinity, alignment: .leading)
                            SelectableText("0.0 KB (Zero)", id: "tr4-time").font(.caption).frame(width: 120, alignment: .leading)
                            SelectableText("O(1)", id: "tr4-comp").font(.caption.monospaced()).frame(width: 100, alignment: .leading)
                        }
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.gray.opacity(0.06), in: .rect(cornerRadius: 10))
        }
    }

    private func metricRowCard(operation: String, time: String, complexity: String, id: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                SelectableText(operation, id: "\(id)-op")
                    .font(.subheadline.weight(.medium))
                SelectableText(complexity, id: "\(id)-comp")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            SelectableText(time, id: "\(id)-time")
                .font(.caption.bold())
                .foregroundStyle(.blue)
        }
        .padding(8)
        .background(Color.primary.opacity(0.03), in: .rect(cornerRadius: 6))
    }

    // MARK: - Chapter 10

    private var chapter10Section: some View {
        VStack(alignment: .leading, spacing: 14) {
            SelectableText("10. Complete Code Architecture & Integration", id: "ch10-title")
                .font(.title2.bold())

            SelectableText("Adopting TextSelectionKit in your existing application requires no disruptive changes to your SwiftUI state model or layout hierarchies. The API matches SwiftUI's standard `Text` conventions seamlessly:", id: "ch10-p1")
                .font(.body)
                .lineSpacing(4)

            VStack(alignment: .leading, spacing: 6) {
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 4) {
                        SelectableText("// 1. Wrap your root view in a SelectionContainer", id: "ch10-step1")
                            .font(.system(size: isCompact ? 12 : 13, design: .monospaced))
                            .foregroundStyle(.secondary)
                        SelectableText("SelectionContainer {", id: "ch10-step2")
                            .font(.system(size: isCompact ? 12 : 13, design: .monospaced))
                        SelectableText("    VStack(alignment: .leading, spacing: 12) {", id: "ch10-step3")
                            .font(.system(size: isCompact ? 12 : 13, design: .monospaced))
                        SelectableText("        SelectableText(\"Headline\").font(.headline)", id: "ch10-step4")
                            .font(.system(size: isCompact ? 12 : 13, design: .monospaced))
                        SelectableText("        Divider()", id: "ch10-step5")
                            .font(.system(size: isCompact ? 12 : 13, design: .monospaced))
                        SelectableText("        SelectableText(\"Rich body with **bold** and *italics*.\")", id: "ch10-step6")
                            .font(.system(size: isCompact ? 12 : 13, design: .monospaced))
                        SelectableText("    }", id: "ch10-step7")
                            .font(.system(size: isCompact ? 12 : 13, design: .monospaced))
                        SelectableText("}", id: "ch10-step8")
                            .font(.system(size: isCompact ? 12 : 13, design: .monospaced))
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.12), in: .rect(cornerRadius: 8))

            SelectableText("By synthesizing a unified virtual document while letting platform-native text engines render selection physics, TextSelectionKit delivers the missing native text selection experience in modern SwiftUI.", id: "ch10-p2")
                .font(.body)
                .lineSpacing(4)
        }
    }

    // MARK: - Footnotes Section

    private var footnotesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SelectableText("References & Bibliography:", id: "fn-header")
                .font(.caption.bold())
                .foregroundColor(.secondary)

            SelectableText("1. Apple Developer Documentation: CoreText CTFrame, CTLine, and CTRun Typographic Slicing.", id: "fn-1")
                .font(.caption2)
                .foregroundColor(.secondary)

            SelectableText("2. Apple UIKit Framework Reference: Implementing Custom UITextInput and UIEditMenuInteraction protocols.", id: "fn-2")
                .font(.caption2)
                .foregroundColor(.secondary)

            SelectableText("3. Apple AppKit Framework Reference: NSView First Responder Chain, Key Status, and Cursor Rect Management.", id: "fn-3")
                .font(.caption2)
                .foregroundColor(.secondary)

            SelectableText("4. Unicode Consortium: Standard Annex #9 — The Bidirectional Algorithm (UBA).", id: "fn-4")
                .font(.caption2)
                .foregroundColor(.secondary)

            SelectableText("5. Swift Evolution: Approaching Concurrency Safety and Sendability in Swift 6.0.", id: "fn-5")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.top, 12)
    }
}

// MARK: - Helper Views

private struct WrapHStack<Content: View>: View {
    var spacing: CGFloat = 8
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(spacing: spacing) {
            content()
        }
    }
}

#Preview("iOS iPhone Portrait") {
    LongDocumentExampleView()
}

#Preview("Mac / iPad") {
    LongDocumentExampleView()
        .frame(minWidth: 720, minHeight: 600)
}
