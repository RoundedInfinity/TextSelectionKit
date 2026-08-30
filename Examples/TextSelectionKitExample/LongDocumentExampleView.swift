import SwiftUI
import TextSelectionKit

public struct LongDocumentExampleView: View {
    public init() {}

    public var body: some View {
        ScrollView {
            SelectionContainer(hitTestPolicy: .container) {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // MARK: - Document Header
                    VStack(alignment: .leading, spacing: 8) {
                        SelectableText("Deep Dive: Native Multi-Element Text Selection Architecture")
                            .font(.largeTitle.bold())
                        
                        SelectableText("A comprehensive exploration of virtual layout documents, CoreText line geometry, and cross-platform responder coordination in modern SwiftUI.")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 12) {
                            SelectableText("By **Alex Rivera**")
                                .font(.subheadline)
                            
                            SelectableText("•")
                                .foregroundStyle(.secondary)
                            
                            SelectableText("October 24, 2026")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            SelectableText("•")
                                .foregroundStyle(.secondary)
                            
                            SelectableText("12 min read")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 4)
                    }

                    Divider()

                    // MARK: - Section 1: Introduction
                    VStack(alignment: .leading, spacing: 12) {
                        SelectableText("1. The State of SwiftUI Text Selection")
                            .font(.title2.bold())

                        SelectableText("Standard SwiftUI provides the `.textSelection(.enabled)` modifier, which allows users to select and copy text. However, in standard SwiftUI, each individual `Text` view functions as an isolated island. Users cannot drag their cursor or finger to highlight text across multiple paragraphs, headings, or through dividers and spacers.")
                            .font(.body)
                            .lineSpacing(4)

                        SelectableText("In modern document readers, web browsers, and chat applications, seamless multi-paragraph selection is a foundational expectation. Replicating this behavior without abandoning SwiftUI's declarative view hierarchy requires bridging declarative layout tree preferences with native low-level text engine subsystems.")
                            .font(.body)
                            .lineSpacing(4)

                        // Highlight Quote Block
                        HStack(alignment: .top, spacing: 14) {
                            Rectangle()
                                .fill(Color.blue)
                                .frame(width: 4)
                            
                            SelectableText("\"A great text selection experience is completely invisible to the user until it fails. True native feel demands sub-pixel caret accuracy, natural word snapping, and zero dropped frames during drag gestures.\"")
                                .font(.callout.italic())
                                .foregroundColor(.primary)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.blue.opacity(0.05), in: .rect(cornerRadius: 6))
                    }

                    Divider()

                    // MARK: - Section 2: Virtual Document Synthesis
                    VStack(alignment: .leading, spacing: 12) {
                        SelectableText("2. The Virtual Document Coordinate Space")
                            .font(.title2.bold())

                        SelectableText("To coordinate multiple disjoint SwiftUI views, `TextSelectionKit` introduces the concept of a `VirtualTextDocument`. As each `SelectableText` renders, it publishes its local bounding frame, resolved font, text alignment, and attributed content up the view hierarchy using SwiftUI's `PreferenceKey` mechanism.")
                            .font(.body)
                            .lineSpacing(4)

                        SelectableText("The enclosing `SelectionContainer` collects these registrations and synthesizes a 1D continuous string index space mapped over the 2D visual layout. Delimiters (such as newlines) are automatically accounted for between discrete visual blocks.")
                            .font(.body)
                            .lineSpacing(4)

                        // Tip Callout Box
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.orange)
                                .font(.title3)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                SelectableText("Pro Tip: Explicit Ordering")
                                    .font(.subheadline.bold())
                                SelectableText("When building complex multi-column grids or side-by-side cards, apply `.selectionOrder(index)` to explicitly control whether selection flows column-first or row-first.")
                                    .font(.caption)
                            }
                        }
                        .padding()
                        .background(Color.orange.opacity(0.08), in: .rect(cornerRadius: 10))
                    }

                    Divider()

                    // MARK: - Section 3: High-Performance CoreText Layout
                    VStack(alignment: .leading, spacing: 12) {
                        SelectableText("3. Zero-Allocation CoreText Caching")
                            .font(.title2.bold())

                        SelectableText("During high-frequency mouse drag events or gesture updates (60 to 120 FPS), calculating character rects and hit-tests from scratch would trigger memory pressure and frame stutter. `TextSelectionKit` employs a high-performance `CachedElementLayout` layer backed by CoreText `CTFrame` and `CTLine` caches.")
                            .font(.body)
                            .lineSpacing(4)

                        SelectableText("Key architectural optimizations include:")
                            .font(.body)

                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top, spacing: 8) {
                                SelectableText("•").bold()
                                SelectableText("**Logarithmic Binary Search**: Global character offsets are located in $O(\\log N)$ time across element slices rather than linear iteration.")
                                    .font(.body)
                            }
                            
                            HStack(alignment: .top, spacing: 8) {
                                SelectableText("•").bold()
                                SelectableText("**Thread-Safe Platform Font Resolvers**: Thread-safe `NSLock` protected caching for dynamic font transformations and traits.")
                                    .font(.body)
                            }

                            HStack(alignment: .top, spacing: 8) {
                                SelectableText("•").bold()
                                SelectableText("**Fast Invalidation**: Caches are only recomputed when frame widths deviate by $\\ge 0.5\\text{ pt}$ or text content changes.")
                                    .font(.body)
                            }
                        }
                        .padding(.leading, 8)
                    }

                    Divider()

                    // MARK: - Section 4: Code Integration Example
                    VStack(alignment: .leading, spacing: 12) {
                        SelectableText("4. Developer API & Integration")
                            .font(.title2.bold())

                        SelectableText("Integrating `TextSelectionKit` into existing SwiftUI codebases requires minimal refactoring. Wrap your view tree in a `SelectionContainer` and replace `Text` views with `SelectableText`:")
                            .font(.body)

                        // Code Block Simulation
                        VStack(alignment: .leading, spacing: 6) {
                            SelectableText("import SwiftUI")
                                .font(.system(size: 13, design: .monospaced))
                            SelectableText("import TextSelectionKit")
                                .font(.system(size: 13, design: .monospaced))
                            SelectableText("")
                                .font(.system(size: 13, design: .monospaced))
                            SelectableText("struct ArticleView: View {")
                                .font(.system(size: 13, design: .monospaced))
                            SelectableText("    var body: some View {")
                                .font(.system(size: 13, design: .monospaced))
                            SelectableText("        SelectionContainer {")
                                .font(.system(size: 13, design: .monospaced))
                            SelectableText("            VStack(alignment: .leading, spacing: 12) {")
                                .font(.system(size: 13, design: .monospaced))
                            SelectableText("                SelectableText(\"Heading\").font(.headline)")
                                .font(.system(size: 13, design: .monospaced))
                            SelectableText("                SelectableText(\"Body paragraph with **markdown**.\")")
                                .font(.system(size: 13, design: .monospaced))
                            SelectableText("            }")
                                .font(.system(size: 13, design: .monospaced))
                            SelectableText("        }")
                                .font(.system(size: 13, design: .monospaced))
                            SelectableText("    }")
                                .font(.system(size: 13, design: .monospaced))
                            SelectableText("}")
                                .font(.system(size: 13, design: .monospaced))
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.12), in: .rect(cornerRadius: 8))
                    }

                    Divider()

                    // MARK: - Section 5: Conclusion & Footnotes
                    VStack(alignment: .leading, spacing: 12) {
                        SelectableText("5. Summary & Next Steps")
                            .font(.title2.bold())

                        SelectableText("By combining SwiftUI's declarative component model with custom native platform tracking overlays on macOS (AppKit) and iOS (UIKit `UITextInput`), `TextSelectionKit` achieves the ideal balance of developer ergonomic simplicity and fluid, platform-native user interaction.")
                            .font(.body)
                            .lineSpacing(4)

                        // Footnote Block
                        VStack(alignment: .leading, spacing: 4) {
                            SelectableText("References & Platform Notes:")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                            SelectableText("1. Apple Developer Documentation: CoreText CTFrame and CTLine Geometry.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            SelectableText("2. Apple UIKit Documentation: Implementing Custom UITextInput Protocols.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            SelectableText("3. Apple AppKit Documentation: NSView First Responder and Cursor Invalidation.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(28)
            }
        }
    }
}

#Preview("Long Document Article") {
    LongDocumentExampleView()
}
