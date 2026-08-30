import SwiftUI
import TextSelectionKit

public struct ComplexLayoutRTLExampleView: View {
    @State private var isRTL = false
    @State private var columnOrderMode = true

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header & Controls
                VStack(alignment: .leading, spacing: 8) {
                    Text("Complex Layout & RTL Selection")
                        .font(.title2.bold())
                    
                    Text("Test selection across multi-column grids, explicit selection ordering, nested cards, and Right-to-Left (Arabic & Hebrew) scripts.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 16) {
                        Toggle("Force RTL Layout", isOn: $isRTL)
                            .toggleStyle(.switch)
                        
                        Toggle("Column-First Selection Order", isOn: $columnOrderMode)
                            .toggleStyle(.switch)
                    }
                    .padding(.top, 4)
                }

                // MARK: - Section 1: Multi-Column Grid with Custom Selection Order
                VStack(alignment: .leading, spacing: 12) {
                    Text("1. Multi-Column Grid with selectionOrder(_:)")
                        .font(.headline)
                    
                    Text(columnOrderMode ? "Selection proceeds down Column A (1→2), then down Column B (3→4)." : "Selection proceeds horizontally across rows (1→3, then 2→4).")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    SelectionContainer {
                        HStack(alignment: .top, spacing: 16) {
                            // Column A
                            VStack(alignment: .leading, spacing: 12) {
                                VStack(alignment: .leading, spacing: 6) {
                                    SelectableText("Column A - Card 1 (Title)")
                                        .font(.headline)
                                        .selectionOrder(columnOrderMode ? 1 : 1)
                                    
                                    SelectableText("This is the description inside the first card of Column A.")
                                        .font(.body)
                                        .selectionOrder(columnOrderMode ? 2 : 2)
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.blue.opacity(0.08), in: .rect(cornerRadius: 10))

                                VStack(alignment: .leading, spacing: 6) {
                                    SelectableText("Column A - Card 2 (Bottom)")
                                        .font(.headline)
                                        .selectionOrder(columnOrderMode ? 3 : 5)
                                    
                                    SelectableText("Second card in Column A. Notice how ordering handles vertical flow.")
                                        .font(.body)
                                        .selectionOrder(columnOrderMode ? 4 : 6)
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.blue.opacity(0.08), in: .rect(cornerRadius: 10))
                            }
                            
                            // Column B
                            VStack(alignment: .leading, spacing: 12) {
                                VStack(alignment: .leading, spacing: 6) {
                                    SelectableText("Column B - Card 1 (Title)")
                                        .font(.headline)
                                        .selectionOrder(columnOrderMode ? 5 : 3)
                                    
                                    SelectableText("This is the description inside the first card of Column B.")
                                        .font(.body)
                                        .selectionOrder(columnOrderMode ? 6 : 4)
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.purple.opacity(0.08), in: .rect(cornerRadius: 10))

                                VStack(alignment: .leading, spacing: 6) {
                                    SelectableText("Column B - Card 2 (Bottom)")
                                        .font(.headline)
                                        .selectionOrder(columnOrderMode ? 7 : 7)
                                    
                                    SelectableText("Second card in Column B. Selecting across columns feels intuitive.")
                                        .font(.body)
                                        .selectionOrder(columnOrderMode ? 8 : 8)
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.purple.opacity(0.08), in: .rect(cornerRadius: 10))
                            }
                        }
                    }
                }

                Divider()

                // MARK: - Section 2: Bi-directional & RTL Script Rendering (Arabic / Hebrew / English)
                VStack(alignment: .leading, spacing: 12) {
                    Text("2. Bi-Directional & Right-to-Left (RTL) Rendering")
                        .font(.headline)
                    
                    Text("Arabic and Hebrew text rendered alongside Latin scripts with native selection highlighting.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    SelectionContainer {
                        VStack(alignment: .leading, spacing: 14) {
                            // English Heading
                            SelectableText("Arabic & English Mixed Document")
                                .font(.title3.bold())

                            // Arabic Paragraph
                            SelectableText("مرحباً بكم في حزمة TextSelectionKit لتحديد النصوص المتعددة في SwiftUI. يتيح هذا النظام تحديد النصوص بسلاسة عبر عناصر متعددة وبدقة عالية مع دعم كامل للاتجاهات من اليمين إلى اليسار.")
                                .font(.body)
                                .multilineTextAlignment(.leading)

                            Divider()

                            // Hebrew Heading & Paragraph
                            SelectableText("דוגמה לבחירת טקסט בעברית (Hebrew Example)")
                                .font(.headline)

                            SelectableText("שלום עולם! זוהי בדיקה לבחירת טקסט מרובה אלמנטים בשפת SwiftUI. ניתן לגרור את העכבר ולבחור מספר פסקאות בו-זמנית עם התאמה מלאה לכיוון הכתיבה.")
                                .font(.body)

                            Divider()

                            // Mixed inline tokens
                            HStack {
                                SelectableText("Status: **Active**")
                                    .font(.subheadline)
                                
                                Spacer()
                                
                                SelectableText("الحالة: **نشط** (Active)")
                                    .font(.subheadline)
                            }
                            .padding(8)
                            .background(Color.secondary.opacity(0.1), in: .rect(cornerRadius: 8))
                        }
                        .padding()
                        .background(Color.gray.opacity(0.08), in: .rect(cornerRadius: 12))
                    }
                }

                Divider()

                // MARK: - Section 3: Nested Card Layout with Badges and Pricing Table
                VStack(alignment: .leading, spacing: 12) {
                    Text("3. Nested Pricing & Feature Matrix")
                        .font(.headline)

                    SelectionContainer {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                SelectableText("Pro Plan")
                                    .font(.title3.bold())
                                
                                (SelectableText("$29").bold() + SelectableText(" / month").foregroundColor(.secondary))
                                    .font(.title3)
                            }

                            Divider()

                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    SelectableText("Multi-element native selection across containers")
                                        .font(.subheadline)
                                }
                                
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    SelectableText("Dynamic Type font scaling and dark mode support")
                                        .font(.subheadline)
                                }
                                
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    SelectableText("Right-to-Left script layout & CoreText bidirectional metrics")
                                        .font(.subheadline)
                                }
                            }
                            
                            SelectableText("Note: Subscriptions are billed annually. You can cancel at any time from your account settings.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.blue.opacity(0.06), in: .rect(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                        )
                    }
                }
            }
            .padding(24)
        }
        .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
    }
}

#Preview("Complex Layout & RTL") {
    ComplexLayoutRTLExampleView()
}
