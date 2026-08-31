import Testing
import SwiftUI
@testable import TextSelectionKit

@Suite("SelectableText Initializer & Modifier Tests")
struct SelectableTextTests {
    
    @Test("Plain text and markdown initializer parsing")
    @MainActor
    func testInitializers() {
        let plain = SelectableText(verbatim: "Plain Text")
        #expect(plain.rawText == "Plain Text")
        
        let markdown = SelectableText("**Bold** and *Italic*")
        #expect(markdown.rawText == "Bold and Italic")
        
        let verbatim = SelectableText(verbatim: "**Verbatim**")
        #expect(verbatim.rawText == "**Verbatim**")
        
        let explicitMarkdown = SelectableText(markdown: "`code block`")
        #expect(explicitMarkdown.rawText == "code block")
        
        let attr = SelectableText(AttributedString("Direct Attributed"))
        #expect(attr.rawText == "Direct Attributed")
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
            .foregroundColor(.yellow)
            .font(.title)
        
        #expect(text.rawText == "Base Text")
        #expect(text.attributedText.runs.first?.font == .title)
    }
    
    @Test("Concatenation operator (+) creates compound SelectableText with distinct fonts")
    @MainActor
    func testConcatenationOperator() {
        let part1 = SelectableText("First Part ").bold().font(.headline)
        let part2 = SelectableText("Second Part").italic().font(.subheadline)
        let combined = part1 + part2
        
        #expect(combined.rawText == "First Part Second Part")
        let runs = Array(combined.attributedText.runs)
        #expect(runs.count == 2)
        #expect(runs[0].font == .headline)
        #expect(runs[1].font == .subheadline)
    }
    
    @Test("LocalizedStringKey and LocalizationValue resolution")
    @MainActor
    func testLocalizedKeyResolution() {
        let key: LocalizedStringKey = "Hello **World**"
        let selectableFromKey = SelectableText(localizedKey: key)
        #expect(selectableFromKey.rawText == "Hello World")
        
        let localizedValue = SelectableText(localized: "Hello **World**")
        #expect(localizedValue.rawText == "Hello World")
    }
    
    @Test("String literal with interpolation and localization resolution")
    @MainActor
    func testStringLiteralLocalization() {
        let count = 42
        let textWithInterpolation = SelectableText("Items count: \(count)")
        #expect(textWithInterpolation.rawText == "Items count: 42")
    }
    
    @Test("Runtime String variables do not get markdown parsed and preserve verbatim content")
    @MainActor
    func testRuntimeStringDoesNotParseMarkdown() {
        let snakeCase = "snake_case_user_id"
        let text1 = SelectableText(snakeCase)
        #expect(text1.rawText == "snake_case_user_id")
        
        let math = "2 * 3 = 6"
        let text2 = SelectableText(math)
        #expect(text2.rawText == "2 * 3 = 6")
        
        let citation = "[1] Reference Title"
        let text3 = SelectableText(citation)
        #expect(text3.rawText == "[1] Reference Title")
        
        let tilde = "approx ~ 50%"
        let text4 = SelectableText(tilde)
        #expect(text4.rawText == "approx ~ 50%")
    }
    
    @Test("Explicit markdown initializer parses inline markdown formatting")
    @MainActor
    func testExplicitMarkdownParsing() {
        let md = SelectableText(markdown: "**Bold** and *Italic* and `code`")
        #expect(md.rawText == "Bold and Italic and code")
        
        // Assert attributes are present
        let boldRun = md.attributedText.runs.first { run in
            String(md.attributedText[run.range].characters) == "Bold"
        }
        #expect(boldRun?.inlinePresentationIntent?.contains(.stronglyEmphasized) == true)
        
        let italicRun = md.attributedText.runs.first { run in
            String(md.attributedText[run.range].characters) == "Italic"
        }
        #expect(italicRun?.inlinePresentationIntent?.contains(.emphasized) == true)
    }
    
    @Test("Verbatim initializer preserves all markdown tokens intact")
    @MainActor
    func testVerbatimPreservesAllTokens() {
        let verbatim = SelectableText(verbatim: "**Bold** and *Italic* and `code` and [link](url)")
        #expect(verbatim.rawText == "**Bold** and *Italic* and `code` and [link](url)")
        #expect(String(verbatim.attributedText.characters) == "**Bold** and *Italic* and `code` and [link](url)")
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
