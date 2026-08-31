import SwiftUI
import TextSelectionKit

public struct FontModifiersExampleView: View {
    @State private var selectionManager = SelectionManager()
    @State private var containerFontScale: CGFloat = 16
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header & Selection Inspector
                VStack(alignment: .leading, spacing: 8) {
                    Text("Font & Typography Modifiers Showcase")
                        .font(.title2.bold())
                    
                    Text("Select and drag across any of the text blocks below to verify that all font weights, designs, styles, line properties, and concatenation combinations render correctly with native text selection.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    // Live Selection HUD
                    HStack(spacing: 12) {
                        Label(
                            selectionManager.hasSelection
                                ? "\(selectionManager.selectedText.count) characters selected"
                                : "No active selection (drag to select)",
                            systemImage: selectionManager.hasSelection ? "checkmark.circle.fill" : "cursorarrow.rays"
                        )
                        .font(.caption.weight(.medium))
                        .foregroundStyle(selectionManager.hasSelection ? .primary : .secondary)
                        .padding(.vertical,8)

                        Spacer()

                        if selectionManager.hasSelection {
                            Button("Copy") {
                                selectionManager.copySelection()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            Button("Clear") {
                                selectionManager.deselectAll()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.accentColor.opacity(0.08), in: .rect(cornerRadius: 8))
                }
                
                SelectionContainer(manager: selectionManager) {
                    VStack(alignment: .leading, spacing: 28) {
                        
                        // MARK: - Section 1: Standard SwiftUI Text Styles
                        VStack(alignment: .leading, spacing: 10) {
                            Text("1. Standard SwiftUI Text Styles (.font)")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                SelectableText("Large Title Typography (.font(.largeTitle))")
                                    .font(.largeTitle)
                                
                                SelectableText("Title Style (.font(.title))")
                                    .font(.title)
                                
                                SelectableText("Title 2 Style (.font(.title2))")
                                    .font(.title2)
                                
                                SelectableText("Title 3 Style (.font(.title3))")
                                    .font(.title3)
                                
                                SelectableText("Headline Style (.font(.headline))")
                                    .font(.headline)
                                
                                SelectableText("Subheadline Style (.font(.subheadline))")
                                    .font(.subheadline)
                                
                                SelectableText("Body Regular Style (.font(.body))")
                                    .font(.body)
                                
                                SelectableText("Callout Style (.font(.callout))")
                                    .font(.callout)
                                
                                SelectableText("Footnote Style (.font(.footnote))")
                                    .font(.footnote)
                                
                                SelectableText("Caption Style (.font(.caption))")
                                    .font(.caption)
                                
                                SelectableText("Caption 2 Style (.font(.caption2))")
                                    .font(.caption2)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gray.opacity(0.06), in: .rect(cornerRadius: 10))
                        }
                        
                        // MARK: - Section 2: Font Weights Spectrum
                        VStack(alignment: .leading, spacing: 10) {
                            Text("2. System Font Weights (UltraLight to Black)")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                SelectableText("UltraLight: The quick brown fox jumps over the lazy dog")
                                    .font(.system(size: 15, weight: .ultraLight))
                                
                                SelectableText("Thin: The quick brown fox jumps over the lazy dog")
                                    .font(.system(size: 15, weight: .thin))
                                
                                SelectableText("Light: The quick brown fox jumps over the lazy dog")
                                    .font(.system(size: 15, weight: .light))
                                
                                SelectableText("Regular: The quick brown fox jumps over the lazy dog")
                                    .font(.system(size: 15, weight: .regular))
                                
                                SelectableText("Medium: The quick brown fox jumps over the lazy dog")
                                    .font(.system(size: 15, weight: .medium))
                                
                                SelectableText("Semibold: The quick brown fox jumps over the lazy dog")
                                    .font(.system(size: 15, weight: .semibold))
                                
                                SelectableText("Bold: The quick brown fox jumps over the lazy dog")
                                    .font(.system(size: 15, weight: .bold))
                                
                                SelectableText("Heavy: The quick brown fox jumps over the lazy dog")
                                    .font(.system(size: 15, weight: .heavy))
                                
                                SelectableText("Black: The quick brown fox jumps over the lazy dog")
                                    .font(.system(size: 15, weight: .black))
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gray.opacity(0.06), in: .rect(cornerRadius: 10))
                        }
                        
                        // MARK: - Section 3: Font Design Families
                        VStack(alignment: .leading, spacing: 10) {
                            Text("3. Font Design Families (Serif, Rounded, Monospaced)")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            
                            VStack(alignment: .leading, spacing: 10) {
                                SelectableText("Default Design: Clean and neutral system typography for standard interfaces.")
                                    .font(.system(size: 15, weight: .regular, design: .default))
                                
                                SelectableText("Serif Design: Editorial typography with classical serifs and elegant letterforms.")
                                    .font(.system(size: 15, weight: .regular, design: .serif))
                                
                                SelectableText("Rounded Design: Friendly and modern letterforms with smooth rounded stroke terminals.")
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                
                                SelectableText("Monospaced Design: Fixed-pitch glyphs for code blocks, logs, and tabular data alignment.")
                                    .font(.system(size: 14, weight: .regular, design: .monospaced))
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gray.opacity(0.06), in: .rect(cornerRadius: 10))
                        }
                        
                        // MARK: - Section 4: Direct Styling Modifiers & Decorations
                        VStack(alignment: .leading, spacing: 10) {
                            Text("4. Direct Text Styling Modifiers")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            
                            VStack(alignment: .leading, spacing: 10) {
                                SelectableText("Bold modifier applied directly via .bold()")
                                    .bold()


                                SelectableText("Italic modifier applied directly via .italic()")
                                    .italic()
                                
                                SelectableText("Monospaced code styling applied via .monospaced()")
                                    .monospaced()
                                
                                SelectableText("Solid blue underline applied via .underline(true, color: .blue)")
                                    .underline(true, pattern: .solid, color: .blue)
                                
                                SelectableText("Dashed orange underline applied via .underline(true, pattern: .dash, color: .orange)")
                                    .underline(true, pattern: .dash, color: .orange)
                                
                                SelectableText("Red strikethrough applied via .strikethrough(true, color: .red)")
                                    .strikethrough(true, pattern: .solid, color: .red)
                                
                                SelectableText("Dotted purple strikethrough applied via .strikethrough(true, pattern: .dot, color: .purple)")
                                    .strikethrough(true, pattern: .dot, color: .purple)
                                
                                SelectableText("Positive Baseline Offset (+4pt elevation)")
                                    .baselineOffset(4)
                                    .foregroundColor(.teal)
                                
                                SelectableText("Negative Baseline Offset (-4pt depression)")
                                    .baselineOffset(-4)
                                    .foregroundColor(.indigo)
                                
                                SelectableText("Letter Tracking & Kerning (Expanded Spacing)")
                                    .tracking(4.0)
                                    .kerning(1.5)
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gray.opacity(0.06), in: .rect(cornerRadius: 10))
                        }
                        
                        // MARK: - Section 5: Inline Concatenation (+) with Distinct Fonts
                        VStack(alignment: .leading, spacing: 10) {
                            Text("5. In-line Font Concatenation (+) Operator")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                let part1: SelectableText = SelectableText("Headline Part: ").font(.headline).foregroundColor(.primary)
                                let part2: SelectableText = SelectableText("Subheadline ").font(.subheadline).foregroundColor(.secondary)
                                let part3: SelectableText = SelectableText("with bold ").bold().font(.body).foregroundColor(.blue)
                                let part4: SelectableText = SelectableText("and red serif emphasis.").font(.system(size: 15, design: .serif)).italic().foregroundColor(.red)
                                (part1 + part2 + part3 + part4)
                                
                                Divider()
                                
                                let code1: SelectableText = SelectableText("func ").monospaced().font(.system(size: 13, weight: .semibold)).foregroundColor(.purple)
                                let code2: SelectableText = SelectableText("evaluateFontLayout").monospaced().font(.system(size: 13)).foregroundColor(.blue)
                                let code3: SelectableText = SelectableText("() -> ").monospaced().font(.system(size: 13)).foregroundColor(.secondary)
                                let code4: SelectableText = SelectableText("SelectableText").monospaced().font(.system(size: 13, weight: .bold)).foregroundColor(.orange)
                                (code1 + code2 + code3 + code4)
                                    .padding(10)
                                    .background(Color.primary.opacity(0.04), in: .rect(cornerRadius: 6))
                                
                                Divider()
                                
                                let mixed1: SelectableText = SelectableText("Mixed Sizing: ").font(.caption).foregroundColor(.secondary)
                                let mixed2: SelectableText = SelectableText("BIG TITLE ").font(.title.bold()).foregroundColor(.green)
                                let mixed3: SelectableText = SelectableText("small caption ").font(.caption2).foregroundColor(.gray)
                                let mixed4: SelectableText = SelectableText("medium text.").font(.body)
                                (mixed1 + mixed2 + mixed3 + mixed4)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gray.opacity(0.06), in: .rect(cornerRadius: 10))
                        }
                    }
                }
            }
            .padding(24)
        }
    }
}

#Preview("Font Modifiers Example") {
    FontModifiersExampleView()
}
