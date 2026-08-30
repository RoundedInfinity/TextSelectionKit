import Testing
import Foundation
import CoreGraphics
import SwiftUI
@testable import TextSelectionKit

#if os(macOS)
import AppKit
#else
import UIKit
#endif

@Suite("VirtualTextDocument Core Tests")
struct VirtualTextDocumentTests {
    
    private func makeRegistration(
        id: UUID = UUID(),
        text: String,
        frame: CGRect = CGRect(x: 0, y: 0, width: 200, height: 20),
        orderIndex: Int = 0,
        delimiter: String = "\n",
        alignment: TextAlignment = .leading
    ) -> TextElementRegistration {
        #if os(macOS)
        let font = NSFont.systemFont(ofSize: 14)
        #else
        let font = UIFont.systemFont(ofSize: 14)
        #endif
        return TextElementRegistration(
            id: id,
            text: text,
            frame: frame,
            font: font,
            orderIndex: orderIndex,
            delimiter: delimiter,
            alignment: alignment
        )
    }
    
    // MARK: - Empty & Minimal Document Edge Cases
    
    @Test("Empty document has zero length and returns empty results")
    func testEmptyDocument() {
        let doc = VirtualTextDocument(elements: [])
        
        #expect(doc.isEmpty)
        #expect(doc.totalLength == 0)
        #expect(doc.fullText == "")
        #expect(doc.elements.isEmpty)
        #expect(doc.slices.isEmpty)
        
        #expect(doc.slice(forGlobalOffset: 0) == nil)
        #expect(doc.slice(forGlobalOffset: 10) == nil)
        #expect(doc.text(in: 0..<5) == "")
        #expect(doc.wordRange(atGlobalOffset: 0) == nil)
        #expect(doc.paragraphRange(atGlobalOffset: 0) == nil)
        #expect(doc.characterRect(atGlobalOffset: 0) == .zero)
        #expect(doc.caretRect(atGlobalOffset: 0) == .zero)
        #expect(doc.lineSelectionRects(for: 0..<5).isEmpty)
        #expect(doc.closestGlobalOffset(to: CGPoint(x: 100, y: 100)) == 0)
    }
    
    @Test("Single element with empty string")
    func testSingleEmptyElement() {
        let elem = makeRegistration(text: "")
        let doc = VirtualTextDocument(elements: [elem])
        
        #expect(doc.totalLength == 0)
        #expect(doc.fullText == "")
        #expect(doc.text(in: 0..<1) == "")
    }
    
    @Test("Single character element")
    func testSingleCharacterElement() {
        let elem = makeRegistration(text: "A")
        let doc = VirtualTextDocument(elements: [elem])
        
        #expect(doc.totalLength == 1)
        #expect(doc.fullText == "A")
        #expect(doc.text(in: 0..<1) == "A")
        
        let sliceLookup = doc.slice(forGlobalOffset: 0)
        #expect(sliceLookup?.slice.element.text == "A")
        #expect(sliceLookup?.localOffset == 0)
    }
    
    @Test("Unicode and emoji elements")
    func testUnicodeAndEmoji() {
        let elem = makeRegistration(text: "Swift 🚀✨ text")
        let doc = VirtualTextDocument(elements: [elem])
        
        #expect(doc.fullText == "Swift 🚀✨ text")
        #expect(doc.text(in: 0..<5) == "Swift")
        #expect(doc.totalLength == elem.text.utf16.count)
    }
    
    // MARK: - Spatial & Index Ordering
    
    @Test("Vertical layout orders by Y coordinate")
    func testVerticalOrdering() {
        let e1 = makeRegistration(text: "Line 1", frame: CGRect(x: 0, y: 0, width: 100, height: 20))
        let e2 = makeRegistration(text: "Line 2", frame: CGRect(x: 0, y: 30, width: 100, height: 20))
        let e3 = makeRegistration(text: "Line 3", frame: CGRect(x: 0, y: 60, width: 100, height: 20))
        
        // Pass in shuffled order
        let doc = VirtualTextDocument(elements: [e3, e1, e2])
        
        #expect(doc.elements.map { $0.text } == ["Line 1", "Line 2", "Line 3"])
        #expect(doc.fullText == "Line 1\nLine 2\nLine 3")
    }
    
    @Test("Horizontal layout on same line orders by X coordinate")
    func testHorizontalOrdering() {
        let left = makeRegistration(text: "Left", frame: CGRect(x: 0, y: 10, width: 50, height: 20))
        let right = makeRegistration(text: "Right", frame: CGRect(x: 60, y: 11, width: 50, height: 20))
        
        let doc = VirtualTextDocument(elements: [right, left])
        
        #expect(doc.elements.map { $0.text } == ["Left", "Right"])
        #expect(doc.fullText == "Left\nRight")
    }
    
    @Test("Differing heights and baseline offsets on same line order by X coordinate")
    func testMixedHeightSameLineOrdering() {
        let mainText = makeRegistration(text: "Title", frame: CGRect(x: 0, y: 10, width: 80, height: 24))
        let inlineBadge = makeRegistration(text: "NEW", frame: CGRect(x: 90, y: 11, width: 30, height: 14))
        
        let doc = VirtualTextDocument(elements: [inlineBadge, mainText])
        
        #expect(doc.elements.map { $0.text } == ["Title", "NEW"])
        #expect(doc.fullText == "Title\nNEW")
    }
    
    @Test("Explicit orderIndex overrides spatial coordinates")
    func testExplicitOrderIndex() {
        let e1 = makeRegistration(text: "First in order", frame: CGRect(x: 0, y: 100, width: 100, height: 20), orderIndex: -5)
        let e2 = makeRegistration(text: "Second in order", frame: CGRect(x: 0, y: 0, width: 100, height: 20), orderIndex: 0)
        let e3 = makeRegistration(text: "Third in order", frame: CGRect(x: 0, y: 50, width: 100, height: 20), orderIndex: 2)
        
        let doc = VirtualTextDocument(elements: [e3, e2, e1])
        
        #expect(doc.elements.map { $0.text } == ["First in order", "Second in order", "Third in order"])
    }
    
    // MARK: - Delimiter & Range Mathematics
    
    @Test("Virtual delimiter range calculations")
    func testVirtualDelimiterRanges() {
        let id1 = UUID()
        let id2 = UUID()
        let e1 = makeRegistration(id: id1, text: "ABC", frame: CGRect(x: 0, y: 0, width: 100, height: 20))
        let e2 = makeRegistration(id: id2, text: "DEF", frame: CGRect(x: 0, y: 30, width: 100, height: 20))
        
        let doc = VirtualTextDocument(elements: [e1, e2])
        #expect(doc.totalLength == 7)
        
        // Selecting ONLY the delimiter (range 3..<4)
        let delimiterSelections = doc.perElementSelections(from: 3..<4)
        #expect(delimiterSelections.isEmpty)
        #expect(doc.text(in: 3..<4) == "\n")
        
        // Selecting spanning across the delimiter (range 2..<5) -> "C\nD"
        let spanningSelections = doc.perElementSelections(from: 2..<5)
        #expect(spanningSelections[id1] == 2..<3) // "C"
        #expect(spanningSelections[id2] == 0..<1) // "D"
        #expect(doc.text(in: 2..<5) == "C\nD")
        
        let attr = doc.attributedString(in: 2..<5)
        #expect(String(attr.characters) == "C\nD")
    }
    
    @Test("Out of bounds text range clamping")
    func testOutOfBoundsRangeClamping() {
        let e1 = makeRegistration(text: "Hello", frame: CGRect(x: 0, y: 0, width: 100, height: 20))
        let doc = VirtualTextDocument(elements: [e1])
        
        // Negative range lower bound
        #expect(doc.text(in: -5..<3) == "Hel")
        
        // Overflowing upper bound
        #expect(doc.text(in: 2..<50) == "llo")
        
        // Empty ranges
        #expect(doc.text(in: 3..<3) == "")
        #expect(doc.text(in: 0..<0) == "")
    }
    
    // MARK: - Word & Paragraph Boundaries
    
    @Test("Word boundaries lookup")
    func testWordBoundaries() {
        let e1 = makeRegistration(text: "Hello World Swift", frame: CGRect(x: 0, y: 0, width: 200, height: 20))
        let doc = VirtualTextDocument(elements: [e1])
        
        // At index 0 ('H') -> "Hello" (0..<5)
        #expect(doc.wordRange(atGlobalOffset: 0) == 0..<5)
        // At index 3 ('l') -> "Hello" (0..<5)
        #expect(doc.wordRange(atGlobalOffset: 3) == 0..<5)
        // At index 6 ('W') -> "World" (6..<11)
        #expect(doc.wordRange(atGlobalOffset: 6) == 6..<11)
        // At index 14 ('w') -> "Swift" (12..<17)
        #expect(doc.wordRange(atGlobalOffset: 14) == 12..<17)
    }
    
    @Test("Paragraph boundaries lookup across elements")
    func testParagraphBoundaries() {
        let e1 = makeRegistration(text: "Paragraph 1", frame: CGRect(x: 0, y: 0, width: 200, height: 20))
        let e2 = makeRegistration(text: "Paragraph 2", frame: CGRect(x: 0, y: 30, width: 200, height: 20))
        let doc = VirtualTextDocument(elements: [e1, e2])
        
        // Paragraph 1: 0..<11
        #expect(doc.paragraphRange(atGlobalOffset: 4) == 0..<11)
        
        // Paragraph 2: starts at 12, length 11 -> 12..<23
        #expect(doc.paragraphRange(atGlobalOffset: 15) == 12..<23)
    }
    
    // MARK: - Custom Selection Delimiter Tests
    
    @Test("Custom space delimiter separates elements with a space")
    func testCustomSpaceDelimiter() {
        let e1 = makeRegistration(text: "John", frame: CGRect(x: 0, y: 0, width: 50, height: 20), delimiter: " ")
        let e2 = makeRegistration(text: "Doe", frame: CGRect(x: 60, y: 0, width: 50, height: 20), delimiter: " ")
        
        let doc = VirtualTextDocument(elements: [e1, e2])
        
        #expect(doc.totalLength == 8) // 4 + 1 + 3
        #expect(doc.fullText == "John Doe")
        #expect(doc.text(in: 0..<8) == "John Doe")
        #expect(doc.text(in: 2..<7) == "hn Do")
        
        let attr = doc.attributedString(in: 0..<8)
        #expect(String(attr.characters) == "John Doe")
    }
    
    @Test("Custom comma delimiter separates elements with comma and space")
    func testCustomCommaDelimiter() {
        let e1 = makeRegistration(text: "Apple", frame: CGRect(x: 0, y: 0, width: 50, height: 20), delimiter: ", ")
        let e2 = makeRegistration(text: "Banana", frame: CGRect(x: 60, y: 0, width: 50, height: 20), delimiter: ", ")
        let e3 = makeRegistration(text: "Cherry", frame: CGRect(x: 120, y: 0, width: 50, height: 20), delimiter: ", ")
        
        let doc = VirtualTextDocument(elements: [e1, e2, e3])
        
        #expect(doc.totalLength == 21) // 5 + 2 + 6 + 2 + 6 = 21
        #expect(doc.fullText == "Apple, Banana, Cherry")
        #expect(doc.text(in: 0..<21) == "Apple, Banana, Cherry")
        
        let attr = doc.attributedString(in: 0..<21)
        #expect(String(attr.characters) == "Apple, Banana, Cherry")
    }
    
    @Test("Empty delimiter concatenates elements directly without spacing")
    func testEmptyDelimiter() {
        let e1 = makeRegistration(text: "Hello", frame: CGRect(x: 0, y: 0, width: 50, height: 20), delimiter: "")
        let e2 = makeRegistration(text: "World", frame: CGRect(x: 60, y: 0, width: 50, height: 20), delimiter: "")
        
        let doc = VirtualTextDocument(elements: [e1, e2])
        
        #expect(doc.totalLength == 10) // 5 + 0 + 5
        #expect(doc.fullText == "HelloWorld")
        #expect(doc.text(in: 0..<10) == "HelloWorld")
        
        let attr = doc.attributedString(in: 0..<10)
        #expect(String(attr.characters) == "HelloWorld")
    }
    
    @Test("text(in:) and attributedString(in:) agree on partial delimiter selections")
    func testPartialDelimiterSynchronization() {
        // "Apple" (0..<5), ", " (5..<7), "Banana" (7..<13)
        let e1 = makeRegistration(text: "Apple", frame: CGRect(x: 0, y: 0, width: 50, height: 20), delimiter: ", ")
        let e2 = makeRegistration(text: "Banana", frame: CGRect(x: 60, y: 0, width: 50, height: 20), delimiter: ", ")
        let doc = VirtualTextDocument(elements: [e1, e2])
        
        // 4..<8: "e, B"
        #expect(doc.text(in: 4..<8) == "e, B")
        #expect(String(doc.attributedString(in: 4..<8).characters) == "e, B")
        
        // 5..<8: ", B" (starts at delimiter start)
        #expect(doc.text(in: 5..<8) == ", B")
        #expect(String(doc.attributedString(in: 5..<8).characters) == ", B")
        
        // 6..<8: " B" (starts inside delimiter)
        #expect(doc.text(in: 6..<8) == " B")
        #expect(String(doc.attributedString(in: 6..<8).characters) == " B")
        
        // 5..<7: ", " (delimiter only)
        #expect(doc.text(in: 5..<7) == ", ")
        #expect(String(doc.attributedString(in: 5..<7).characters) == ", ")
        
        // 4..<6: "e," (element end + partial delimiter)
        #expect(doc.text(in: 4..<6) == "e,")
        #expect(String(doc.attributedString(in: 4..<6).characters) == "e,")
        
        // 4..<7: "e, " (element end + full delimiter)
        #expect(doc.text(in: 4..<7) == "e, ")
        #expect(String(doc.attributedString(in: 4..<7).characters) == "e, ")
    }
    
    @Test("Exhaustive text(in:) and attributedString(in:) round-trip property across multi-element documents")
    func testExhaustiveTextAndAttributedStringRoundTrip() {
        let e1 = makeRegistration(text: "Swift", frame: CGRect(x: 0, y: 0, width: 50, height: 20), delimiter: " -- ")
        let e2 = makeRegistration(text: "UI", frame: CGRect(x: 60, y: 0, width: 50, height: 20), delimiter: "\n\n")
        let e3 = makeRegistration(text: "Kit", frame: CGRect(x: 120, y: 0, width: 50, height: 20), delimiter: "")
        let doc = VirtualTextDocument(elements: [e1, e2, e3])
        
        for lower in 0...doc.totalLength {
            for upper in lower...doc.totalLength {
                let range = lower..<upper
                let plain = doc.text(in: range)
                let attr = doc.attributedString(in: range)
                #expect(String(attr.characters) == plain, "Mismatch at range \(range): plain=\(plain), attr=\(String(attr.characters))")
            }
        }
    }
    
    @Test("Early return hits when tree order differs from visual spatial order")
    func testEarlyReturnWhenTreeOrderDiffersFromVisualOrder() {
        let e1 = makeRegistration(text: "Top", frame: CGRect(x: 0, y: 0, width: 100, height: 20))
        let e2 = makeRegistration(text: "Middle", frame: CGRect(x: 0, y: 50, width: 100, height: 20))
        let e3 = makeRegistration(text: "Bottom", frame: CGRect(x: 0, y: 100, width: 100, height: 20))
        
        // Tree order is reversed from visual Y order: [Bottom, Middle, Top]
        let treeOrder = [e3, e2, e1]
        var doc = VirtualTextDocument(elements: treeOrder)
        
        // Visual sorted elements should be [Top, Middle, Bottom]
        #expect(doc.elements.map(\.id) == [e1.id, e2.id, e3.id])
        #expect(doc.slices.map(\.element.id) == [e1.id, e2.id, e3.id])
        #expect(doc.fullText == "Top\nMiddle\nBottom")
        
        // Stored rawElements should match tree order
        #expect(doc.rawElements == treeOrder)
        
        // Calling update again with identical tree order should hit early-return
        doc.update(elements: treeOrder)
        #expect(doc.elements.map(\.id) == [e1.id, e2.id, e3.id])
        #expect(doc.slices.map(\.element.id) == [e1.id, e2.id, e3.id])
        #expect(doc.fullText == "Top\nMiddle\nBottom")
    }
}

