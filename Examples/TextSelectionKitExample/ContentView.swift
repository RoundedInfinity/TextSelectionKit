import SwiftUI
import TextSelectionKit

public enum ExampleTab: String, CaseIterable, Identifiable {
    case showcase = "Showcase"
    case complexLayout = "Complex & RTL"
    case longDocument = "Long Document"

    public var id: String { rawValue }
}

public struct ContentView: View {
    @State private var selectedTab: ExampleTab = .showcase

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            Picker("Example Mode", selection: $selectedTab) {
                ForEach(ExampleTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.bar)

            Divider()

            switch selectedTab {
            case .showcase:
                FeatureShowcaseView()
            case .complexLayout:
                ComplexLayoutRTLExampleView()
            case .longDocument:
                LongDocumentExampleView()
            }
        }
        #if os(macOS)
        .frame(minWidth: 640, minHeight: 520)
        #endif
    }
}

public struct FeatureShowcaseView: View {
    @State private var changeText = false
    @State private var firstContainerManager = SelectionManager()

    public init() {}

    private var customAttributedSample: AttributedString {
        var str = AttributedString("Rich AttributedString: ")
        str.font = .system(size: 14, weight: .bold)
        
        var colored = AttributedString("emerald color")
        colored.foregroundColor = .green
        colored.font = .system(size: 14, weight: .semibold)
        str.append(colored)
        
        let middle = AttributedString(", ")
        str.append(middle)
        
        var struck = AttributedString("strikethrough text")
        struck.strikethroughStyle = .single
        str.append(struck)
        
        let and = AttributedString(", and ")
        str.append(and)
        
        var underlined = AttributedString("underlined text")
        underlined.underlineStyle = .single
        str.append(underlined)
        
        let end = AttributedString(" in the same selectable block!")
        str.append(end)
        
        return str
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Multi-Element Text Selection Demo")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Drag mouse or finger across elements below to select across view boundaries.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // External SelectionManager Programmatic Controls
                HStack(spacing: 10) {
                    Button {
                        firstContainerManager.selectAll()
                    } label: {
                        Label("Select All", systemImage: "selection.pin.in.out")
                    }
                    .buttonStyle(.bordered)
                    
                    Button {
                        firstContainerManager.copySelection()
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                    .disabled(!firstContainerManager.hasSelection)
                    
                    Button {
                        firstContainerManager.clearSelection()


                    } label: {
                        Label("Clear", systemImage: "xmark.circle")
                    }
                    .buttonStyle(.bordered)
                    .disabled(!firstContainerManager.hasSelection)
                    
                    Spacer()
                    
                    if firstContainerManager.hasSelection {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(firstContainerManager.getSelectedText().count) chars selected")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            let ids = firstContainerManager.selectedIDs(String.self)
                            if !ids.isEmpty {
                                Text("IDs: \(ids.joined(separator: ", "))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)

                SelectionContainer(manager: firstContainerManager) {
                    VStack(alignment: .leading, spacing: 16) {
                        SelectableText("Hello, this is the first selectable block of text.", id: "heading")
                            .font(.headline)

                        Divider()
                        
                        SelectableText(
                            "World! You can smoothly select from the headline above, through this divider, and into this longer paragraph. Standard SwiftUI text selection isolates each Text element, but SelectionContainer coordinates selection across the entire view hierarchy.",
                            id: "body-paragraph"
                        )
                        .font(.body)

                        Divider()

                        Button("Some useless Button") {
                            print("This button got clicked")
                        }

                        Divider()

                        Text("Normal text that is not selectable")

                        Divider()

                        SelectableText("Third selectable element with custom font sizing and weights.", id: "third-block")
                            .font(.system(size: 14, weight: .medium))

                        HStack {
                            SelectableText("John", id: "first-name")
                            SelectableText("Doe", id: "last-name")
                        }
                        .padding(6)
                        .background(Color.blue.opacity(0.08), in: .rect(cornerRadius: 6))
                        .selectionDelimiter(" ")

                        Divider()

                        VStack(alignment: .leading, spacing: 6) {
                            SelectableText("Disabled Selection Sub-Hierarchy Demo")
                                .font(.caption.bold())
                            SelectableText("This entire box has .selectableTextDisabled() applied, so selection skips it.")
                                .font(.caption)
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.08), in: .rect(cornerRadius: 8))
                        .selectableTextDisabled()
                    }
                    .padding()
                    .background(Color.gray.opacity(0.08), in: .rect(cornerRadius: 12))
                }
                .selectionContextMenu(placement: .append) { context in
                    SelectionButton("Highlight Selection", systemImage: "highlighter") {
                        print("Highlighted: \(context.selectedText)")
                    }
                    .displayedShortcut("h", modifiers: [.command, .shift])

                    SelectionButton("Quote in Reply", systemImage: "quote.opening") {
                        print("Quoting: \(context.selectedText)")
                    }


                    SelectionDivider()
                    
                    SelectionMenu("Share Selection", systemImage: "square.and.arrow.up") {
                        SelectionButton("To Notes", systemImage: "note.text") { }
                        SelectionButton("To Messages", systemImage: "message") { }
                    }
                }

                Divider()

                SelectionContainer {
                    VStack(alignment: .leading, spacing: 16)  {
                        SelectableText("This is even more selectable text but in another container. This should not be selectable when selecting from the different container.")

                        HStack {
                            Image(systemName: "star")

                            Spacer()

                            SelectableText("This is an indented text with **bold** text, *italic* accents, and `inline code`.")
                        }

                        SelectableText(customAttributedSample)

                        SelectableText("✨🚀 →")

                        let sampleKey: LocalizedStringKey = "Localized string key with **markdown** formatting"
                        SelectableText(sampleKey)

                        SelectableText(verbatim: "Verbatim raw text: no *markdown* parsing here")

                        // Direct text styling modifiers demo
                        (SelectableText("Chained: ").bold() + SelectableText("Bold & ").underline(true, color: .orange) + SelectableText("Strikethrough").strikethrough(true, color: .red))
                            .font(.system(size: 13))

                        // Text with tracking & baselineOffset
                        SelectableText("Wide tracked text with baseline offset")
                            .tracking(3)
                            .baselineOffset(2)
                            .font(.caption)

                        // Environment-driven centered & spaced text
                        SelectableText("This text is center-aligned.")
                            .multilineTextAlignment(.center)
                            .lineSpacing(6)
                            .font(.subheadline)

                        // Environment textCase
                        SelectableText("This text is capitalized via .textCase(.uppercase)")
                            .textCase(.uppercase)
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Toggle("Change text", isOn: $changeText)

                        SelectableText(changeText ? "This text is bold 12" : "This text is **bold** 13")
                            .contentTransition(.numericText())
                            .animation(.default, value: changeText)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.08), in: .rect(cornerRadius: 12))

                Divider()
                
                Text("Standalone SelectableText (Outside SelectionContainer)")
                    .font(.headline)
                
                SelectableText("This SelectableText is placed directly in the view hierarchy without a SelectionContainer. It seamlessly falls back to individual native text selection (.textSelection(.enabled)) and logs a diagnostic warning in the console.")
                    .font(.body)
                    .padding()
                    .background(Color.orange.opacity(0.1), in: .rect(cornerRadius: 12))
                    .contextMenu {
                        Button("Quote in Reply", systemImage: "quote.opening") {
                        }
                        .keyboardShortcut("b",modifiers: [.shift,.command])
                    }
            }
            .padding(24)
        }
    }
}

#Preview("Main Content View") {
    ContentView()
}

#Preview("Container hitTestPolicy") {
    SelectionContainer(hitTestPolicy: .container) {
        VStack(alignment: .leading) {
            SelectableText("Hello world")
                .font(.title)

            SelectableText("This is a selectable text")

            Divider()
            

            SelectableText("This is another selectable text")

            VStack {
                SelectableText("These texts are not selectable")
                SelectableText("They are not!")
            }
            .selectableTextDisabled()

            HStack {
                SelectableText("Swift")
                SelectableText("SwiftUI")
                SelectableText("CoreText")
            }
            .selectionDelimiter(", ")
      
        }
        .padding(32)



    }
    .keyboardShortcut("a",)
    .background(.blue.opacity(0.1))
    .padding()
}
