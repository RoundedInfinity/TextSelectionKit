import Testing
import SwiftUI
@testable import TextSelectionKit

@Suite("SelectableText Initializer & Modifier Tests")
struct SelectableTextTests {
    
    @Test("Plain text and markdown initializer parsing")
    @MainActor
    func testInitializers() {
        let plain = SelectableText("Plain Text")
        _ = plain
        
        let markdown = SelectableText("**Bold** and *Italic*")
        _ = markdown
        
        let verbatim = SelectableText(verbatim: "**Verbatim**")
        _ = verbatim
        
        let explicitMarkdown = SelectableText(markdown: "`code block`")
        _ = explicitMarkdown
        
        let attr = SelectableText(AttributedString("Direct Attributed"))
        _ = attr
    }
    
    @Test("Direct styling modifiers chaining")
    @MainActor
    func testStylingModifiers() {
        let text = SelectableText("Base Text")
            .bold()
            .italic()
            .monospaced()
            .underline(true, color: .red)
            .strikethrough(true, color: .blue)
            .tracking(2.0)
            .kerning(1.0)
            .baselineOffset(3.0)
            .foregroundStyle(.green)
            .foregroundColor(.yellow)
        
        _ = text
    }
    
    @Test("Concatenation operator (+) creates compound SelectableText")
    @MainActor
    func testConcatenationOperator() {
        let part1 = SelectableText("First Part ").bold()
        let part2 = SelectableText("Second Part").italic()
        let combined = part1 + part2
        
        _ = combined
    }
    
    @Test("LocalizedStringKey and LocalizationValue resolution")
    @MainActor
    func testLocalizedKeyResolution() {
        let key: LocalizedStringKey = "Hello **World**"
        let selectableFromKey = SelectableText(key)
        _ = selectableFromKey
        
        let localizedValue = SelectableText(localized: "Hello **World**")
        _ = localizedValue
    }
    
    @Test("View.selectionContainer() modifier wraps view in SelectionContainer")
    @MainActor
    func testSelectionContainerModifier() {
        let view = Text("Hello").selectionContainer()
        _ = view
    }
    
    @Test("selectableTextDisabled modifier disables selection on child views")
    @MainActor
    func testSelectableTextDisabled() {
        let text = SelectableText("Disabled Text")
            .selectableTextDisabled()
        _ = text
        
        let container = SelectionContainer {
            VStack {
                SelectableText("Enabled Text")
                
                VStack {
                    SelectableText("Disabled Child 1")
                    SelectableText("Disabled Child 2")
                }
                .selectableTextDisabled()
            }
        }
        _ = container
    }
    
    @Test("disabledSelection modifier alias disables selection on child views")
    @MainActor
    func testDisabledSelectionAlias() {
        let text = SelectableText("Disabled Text")
            .disabledSelection()
        _ = text
        
        let hierarchy = VStack {
            SelectableText("Item 1")
            SelectableText("Item 2")
        }
        .disabledSelection(true)
        _ = hierarchy
    }
    
    @Test("selectionDelimiter modifier sets delimiter for child views")
    @MainActor
    func testSelectionDelimiterModifier() {
        let text = SelectableText("John")
            .selectionDelimiter(" ")
        _ = text
        
        let stack = HStack {
            SelectableText("John")
            SelectableText("Doe")
        }
        .selectionDelimiter(" ")
        _ = stack
    }
    
    @Test("Custom element ID in SelectableText initializers")
    @MainActor
    func testCustomElementIDs() {
        let stringID = SelectableText("Plain Text", id: "header-1")
        _ = stringID
        
        let intID = SelectableText(markdown: "**Markdown**", id: 42)
        _ = intID
        
        let uuid = UUID()
        let uuidID = SelectableText(verbatim: "Verbatim", id: uuid)
        _ = uuidID
        
        let attrID = SelectableText(AttributedString("Rich"), id: "rich-block")
        let modified = attrID.bold().italic().underline(true)
        _ = modified
        
        let part1 = SelectableText("First ", id: "compound-id")
        let part2 = SelectableText("Second")
        let combined = part1 + part2
        _ = combined
    }
}
