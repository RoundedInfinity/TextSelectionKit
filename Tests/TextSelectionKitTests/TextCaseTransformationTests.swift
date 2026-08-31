import Testing
import SwiftUI
@testable import TextSelectionKit

@Suite("Text Case Transformation Tests")
struct TextCaseTransformationTests {
    
    @Test("Uppercase transformation preserves foreground color, font, and markdown intents")
    @MainActor
    func testUppercasePreservesFormatting() {
        var attr = AttributedString("Hello World")
        attr.foregroundColor = .red
        attr.underlineStyle = .single
        
        let selectable = SelectableText(attr)
        
        // Transform with uppercase
        let transformed = selectable.applyingTextCase(.uppercase)
        
        #expect(String(transformed.characters) == "HELLO WORLD")
        
        let firstRun = transformed.runs.first
        #expect(firstRun?.foregroundColor == .red, "Foreground color must be preserved across uppercase transformation")
        #expect(firstRun?.underlineStyle == .single, "Underline style must be preserved across uppercase transformation")
    }
    
    @Test("Lowercase transformation preserves multi-run styles across distinct segments")
    @MainActor
    func testLowercasePreservesMultipleRuns() {
        var part1 = AttributedString("BOLD ")
        part1.inlinePresentationIntent = .stronglyEmphasized
        part1.foregroundColor = .blue
        
        var part2 = AttributedString("AND ")
        part2.foregroundColor = .primary
        
        var part3 = AttributedString("ITALIC")
        part3.inlinePresentationIntent = .emphasized
        part3.foregroundColor = .green
        
        var combined = part1
        combined.append(part2)
        combined.append(part3)
        
        let selectable = SelectableText(combined)
        let transformed = selectable.applyingTextCase(.lowercase)
        
        #expect(String(transformed.characters) == "bold and italic")
        
        let runs = Array(transformed.runs)
        #expect(runs.count == 3, "All 3 distinct attribute runs must be preserved")
        
        #expect(String(transformed[runs[0].range].characters) == "bold ")
        #expect(runs[0].inlinePresentationIntent?.contains(.stronglyEmphasized) == true)
        #expect(runs[0].foregroundColor == .blue)
        
        #expect(String(transformed[runs[1].range].characters) == "and ")
        #expect(runs[1].foregroundColor == .primary)
        
        #expect(String(transformed[runs[2].range].characters) == "italic")
        #expect(runs[2].inlinePresentationIntent?.contains(.emphasized) == true)
        #expect(runs[2].foregroundColor == .green)
    }
    
    @Test("Uppercase transformation handles expanding character sets (e.g. German eszett 'ß' to 'SS')")
    @MainActor
    func testExpandingCharacterLengths() {
        var attr = AttributedString("große Straße")
        attr.foregroundColor = .orange
        
        let selectable = SelectableText(attr)
        let transformed = selectable.applyingTextCase(.uppercase)
        
        #expect(String(transformed.characters) == "GROSSE STRASSE")
        
        let firstRun = transformed.runs.first
        #expect(firstRun?.foregroundColor == .orange, "Color must be preserved on length-expanded strings")
    }
    
    @Test("Nil textCase leaves attributed string unchanged")
    @MainActor
    func testNilTextCasePreservesOriginal() {
        var attr = AttributedString("Original Case Text")
        attr.foregroundColor = .purple
        
        let selectable = SelectableText(attr)
        let transformed = selectable.applyingTextCase(nil)
        
        #expect(String(transformed.characters) == "Original Case Text")
        #expect(transformed.runs.first?.foregroundColor == .purple)
    }
}
