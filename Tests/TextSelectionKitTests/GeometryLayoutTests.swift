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

@Suite("Geometry & CoreText Layout Tests")
struct GeometryLayoutTests {
    
    private func makeRegistration(
        id: UUID = UUID(),
        text: String,
        frame: CGRect = CGRect(x: 10, y: 10, width: 200, height: 40),
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
            orderIndex: 0,
            alignment: alignment
        )
    }
    
    // MARK: - CachedElementLayout Tests
    
    @Test("Cached layout initialization and invalidation")
    func testCachedElementLayoutValidation() {
        let elem = makeRegistration(text: "Hello SwiftUI Text Selection")
        let layout = CachedElementLayout(element: elem)
        
        #expect(layout != nil)
        #expect(layout?.isValid(for: elem) == true)
        
        // Changing text invalidates cache
        var modifiedElem = elem
        modifiedElem.text = "Hello Different Text"
        #expect(layout?.isValid(for: modifiedElem) == false)
        
        // Changing width by >= 0.5 invalidates cache
        var widthModified = elem
        widthModified.frame.size.width += 2.0
        #expect(layout?.isValid(for: widthModified) == false)
        
        // Minor width change (< 0.5) keeps cache valid
        var minorWidthChange = elem
        minorWidthChange.frame.size.width += 0.2
        #expect(layout?.isValid(for: minorWidthChange) == true)
    }
    
    @Test("Cached layout returns nil for empty text")
    func testEmptyTextLayout() {
        let emptyElem = makeRegistration(text: "")
        let layout = CachedElementLayout(element: emptyElem)
        #expect(layout == nil)
    }
    
    // MARK: - Caret & Selection Rect Geometry
    
    @Test("Caret rect computation at start and end of string")
    func testCaretRects() {
        let elem = makeRegistration(text: "Quick brown fox", frame: CGRect(x: 20, y: 50, width: 300, height: 30))
        let doc = VirtualTextDocument(elements: [elem])
        
        let startCaret = doc.caretRect(atGlobalOffset: 0)
        let endCaret = doc.caretRect(atGlobalOffset: elem.text.utf16.count)
        
        #expect(startCaret.width == 2)
        #expect(startCaret.height > 10)
        #expect(startCaret.minX >= 20) // offset by element.frame.minX
        #expect(endCaret.minX > startCaret.minX)
    }
    
    @Test("Line selection rects across single element")
    func testLineSelectionRects() {
        let elem = makeRegistration(text: "Select this specific segment here", frame: CGRect(x: 0, y: 0, width: 400, height: 30))
        let doc = VirtualTextDocument(elements: [elem])
        
        let rects = doc.lineSelectionRects(for: 7..<11) // "this"
        #expect(!rects.isEmpty)
        #expect(rects[0].width > 0)
        #expect(rects[0].height > 0)
    }
    
    // MARK: - Hit-Testing & Closest Offset
    
    @Test("Closest offset hit-testing boundaries")
    func testClosestOffsetHitTesting() {
        let elem1 = makeRegistration(text: "Top Line", frame: CGRect(x: 10, y: 10, width: 200, height: 20))
        let elem2 = makeRegistration(text: "Bottom Line", frame: CGRect(x: 10, y: 50, width: 200, height: 20))
        let doc = VirtualTextDocument(elements: [elem1, elem2])
        
        // Point far above top element -> offset 0
        #expect(doc.closestGlobalOffset(to: CGPoint(x: 50, y: -100)) == 0)
        
        // Point far below bottom element -> totalLength
        #expect(doc.closestGlobalOffset(to: CGPoint(x: 50, y: 500)) == doc.totalLength)
        
        // Point inside first element
        let topOffset = doc.closestGlobalOffset(to: CGPoint(x: 15, y: 20))
        #expect(topOffset >= 0 && topOffset <= 8)
        
        // Point inside second element
        let bottomOffset = doc.closestGlobalOffset(to: CGPoint(x: 15, y: 60))
        #expect(bottomOffset >= 9 && bottomOffset <= doc.totalLength)
    }
    
    // MARK: - RTL & BiDi Geometry Tests
    
    @Test("RTL text caret and selection rects accurately map right-to-left coordinates")
    func testRTLSelectionRectsAndCaret() {
        #if os(macOS)
        let font = NSFont.systemFont(ofSize: 16)
        #else
        let font = UIFont.systemFont(ofSize: 16)
        #endif
        
        let rtlElem = TextElementRegistration(
            id: UUID(),
            text: "مرحبا بالعالم", // "Hello World" in Arabic (12 utf16 chars)
            frame: CGRect(x: 0, y: 0, width: 300, height: 30),
            font: font,
            orderIndex: 0,
            alignment: .leading,
            layoutDirection: .rightToLeft
        )
        let doc = VirtualTextDocument(elements: [rtlElem])
        
        // In right-aligned RTL text, offset 0 (start) should be on the right
        let startCaret = doc.caretRect(atGlobalOffset: 0)
        let endCaret = doc.caretRect(atGlobalOffset: rtlElem.text.utf16.count)
        
        #expect(startCaret.minX > endCaret.minX)
        
        // Selection rects for Arabic text must have positive width and valid coordinates
        let selectionRects = doc.lineSelectionRects(for: 0..<6)
        #expect(!selectionRects.isEmpty)
        for r in selectionRects {
            #expect(r.width > 0)
            #expect(r.height > 0)
            #expect(r.minX >= 0 && r.maxX <= 300)
        }
        
        // Character rect for an individual Arabic character
        let charRect = doc.characterRect(atGlobalOffset: 0)
        #expect(charRect.width > 0)
        #expect(charRect.minX >= 0)
        
        // Hit-test on the far right (where Arabic text begins) should return an offset near 0
        let rightOffset = doc.closestGlobalOffset(to: CGPoint(x: 290, y: 15))
        #expect(rightOffset <= 3)
    }
    
    @Test("Bi-directional mixed script selection generates accurate visual rects")
    func testBiDirectionalSelectionRects() {
        #if os(macOS)
        let font = NSFont.systemFont(ofSize: 14)
        #else
        let font = UIFont.systemFont(ofSize: 14)
        #endif
        
        let bidiElem = TextElementRegistration(
            id: UUID(),
            text: "Welcome مرحبا بكم to TextSelectionKit",
            frame: CGRect(x: 0, y: 0, width: 400, height: 30),
            font: font,
            orderIndex: 0,
            alignment: .leading,
            layoutDirection: .leftToRight
        )
        let doc = VirtualTextDocument(elements: [bidiElem])
        
        let rects = doc.lineSelectionRects(for: 0..<bidiElem.text.utf16.count)
        #expect(!rects.isEmpty)
        for r in rects {
            #expect(r.width > 0)
            #expect(r.height > 0)
        }
    }
    
    @Test("Closest offset hit-testing efficiently resolves across many stacked elements")
    func testClosestGlobalOffsetScalingAcrossManyElements() {
        var elements: [TextElementRegistration] = []
        for i in 0..<50 {
            let elem = makeRegistration(
                text: "Line item number \(i)",
                frame: CGRect(x: 10, y: CGFloat(i * 30), width: 300, height: 25)
            )
            elements.append(elem)
        }
        let doc = VirtualTextDocument(elements: elements)
        
        // Far above
        #expect(doc.closestGlobalOffset(to: CGPoint(x: 50, y: -500)) == 0)
        
        // Element 0
        let offset0 = doc.closestGlobalOffset(to: CGPoint(x: 15, y: 12))
        #expect(offset0 >= 0 && offset0 <= 20)
        
        // Element 25 (middle: y = 750)
        let offset25 = doc.closestGlobalOffset(to: CGPoint(x: 15, y: 760))
        let (slice25, _) = doc.slice(forGlobalOffset: offset25)!
        #expect(slice25.element.text.contains("25"))
        
        // Element 49 (bottom: y = 1470)
        let offset49 = doc.closestGlobalOffset(to: CGPoint(x: 15, y: 1480))
        let (slice49, _) = doc.slice(forGlobalOffset: offset49)!
        #expect(slice49.element.text.contains("49"))
        
        // Far below
        #expect(doc.closestGlobalOffset(to: CGPoint(x: 50, y: 2500)) == doc.totalLength)
    }
    
    @Test("Horizontal line containment prioritizes same row over vertically offset lines")
    func testHorizontalLineContainmentHitTesting() {
        let heading = makeRegistration(
            text: "Heading",
            frame: CGRect(x: 10, y: 10, width: 60, height: 20)
        )
        let paragraph = makeRegistration(
            text: "Longer paragraph text located on the line below.",
            frame: CGRect(x: 10, y: 40, width: 350, height: 20)
        )
        let doc = VirtualTextDocument(elements: [heading, paragraph])
        
        // Clicking far to the right of the heading on line 1 (x: 250, y: 15)
        let offset = doc.closestGlobalOffset(to: CGPoint(x: 250, y: 15))
        #expect(offset == heading.text.utf16.count)
        #expect(doc.text(in: 0..<offset) == "Heading")
    }
    
    // MARK: - Truncation & lineLimit Tests
    
    @Test("Single-line truncated text clamps caret rect and hit-testing within visible frame bounds")
    func testSingleLineTruncationBoundsProtection() {
        let longText = "The quick brown fox jumps over the lazy dog and runs across the wide green field."
        #if os(macOS)
        let font = NSFont.systemFont(ofSize: 14)
        #else
        let font = UIFont.systemFont(ofSize: 14)
        #endif
        
        let elem = TextElementRegistration(
            id: UUID(),
            text: longText,
            frame: CGRect(x: 10, y: 10, width: 120, height: 25),
            font: font,
            lineLimit: 1,
            truncationMode: .tail
        )
        let doc = VirtualTextDocument(elements: [elem])
        
        // 1. Caret at start (offset 0)
        let startCaret = doc.caretRect(atGlobalOffset: 0)
        #expect(startCaret.minX >= 10)
        #expect(startCaret.minX <= 20)
        
        // 2. Caret at end (offset = longText.utf16.count) must not collapse to 0, should be positioned at visible line end
        let endCaret = doc.caretRect(atGlobalOffset: longText.utf16.count)
        #expect(endCaret.minX > startCaret.minX)
        #expect(endCaret.maxX <= elem.frame.maxX + 10)
        
        // 3. Hit-test far to the right (x: 300, y: 20) should clamp to valid visible offset on the line
        let rightOffset = doc.closestGlobalOffset(to: CGPoint(x: 300, y: 20))
        #expect(rightOffset > 0)
        #expect(rightOffset <= longText.utf16.count)
        
        // 4. Line selection rects for the whole text must not have disjoint 0-width or overlapping artifacts
        let rects = doc.lineSelectionRects(for: 0..<longText.utf16.count)
        #expect(rects.count == 1)
        #expect(rects[0].minX >= 10)
        #expect(rects[0].maxX <= elem.frame.maxX + 10)
    }
    
    @Test("Multi-line text with lineLimit produces capped line count and safe caret rects")
    func testMultiLineLimitTruncationBoundsProtection() {
        let longText = "The quick brown fox jumps over the lazy dog and runs across the wide green field and into the deep dark woods on a sunny afternoon."
        #if os(macOS)
        let font = NSFont.systemFont(ofSize: 14)
        #else
        let font = UIFont.systemFont(ofSize: 14)
        #endif
        
        let elem = TextElementRegistration(
            id: UUID(),
            text: longText,
            frame: CGRect(x: 0, y: 0, width: 120, height: 50),
            font: font,
            lineLimit: 2,
            truncationMode: .tail
        )
        let doc = VirtualTextDocument(elements: [elem])
        
        // Selection rects for all text should produce exactly 2 line rects (capped by lineLimit = 2)
        let rects = doc.lineSelectionRects(for: 0..<longText.utf16.count)
        #expect(rects.count == 2)
        #expect(rects[1].minY > rects[0].minY)
        #expect(rects[0].maxX <= elem.frame.maxX + 10)
        #expect(rects[1].maxX <= elem.frame.maxX + 10)
        
        // Caret rect at end of string must be on line 2 (not line 1) and have positive width & height
        let endCaret = doc.caretRect(atGlobalOffset: longText.utf16.count)
        #expect(endCaret.minY >= rects[1].minY - 2)
        #expect(endCaret.minX > 0)
        #expect(endCaret.maxX <= elem.frame.maxX + 10)
        
        // Character rect at end of string must be on line 2
        let endCharRect = doc.characterRect(atGlobalOffset: longText.utf16.count - 1)
        #expect(endCharRect.minY >= rects[1].minY - 2)
        #expect(endCharRect.minX > 0)
        #expect(endCharRect.maxX <= elem.frame.maxX + 10)
    }
    
    @Test("Truncation modes (.head, .middle, .tail) handle character index and caret safely")
    func testVariousTruncationModesSafeHitTesting() {
        let text = "https://example.com/very/deep/nested/path/to/a/resource/that/is/extremely/long/and/detailed"
        #if os(macOS)
        let font = NSFont.systemFont(ofSize: 14)
        #else
        let font = UIFont.systemFont(ofSize: 14)
        #endif
        
        for mode in [Text.TruncationMode.head, Text.TruncationMode.middle, Text.TruncationMode.tail] {
            let elem = TextElementRegistration(
                id: UUID(),
                text: text,
                frame: CGRect(x: 0, y: 0, width: 150, height: 25),
                font: font,
                lineLimit: 1,
                truncationMode: mode
            )
            let doc = VirtualTextDocument(elements: [elem])
            
            let caret0 = doc.caretRect(atGlobalOffset: 0)
            let caretEnd = doc.caretRect(atGlobalOffset: text.utf16.count)
            #expect(caret0.width == 2)
            #expect(caretEnd.width == 2)
            #expect(caretEnd.minX >= 0)
            
            let hitRight = doc.closestGlobalOffset(to: CGPoint(x: 200, y: 10))
            #expect(hitRight >= 0 && hitRight <= text.utf16.count)
            
            let rects = doc.lineSelectionRects(for: 0..<text.utf16.count)
            #expect(rects.count == 1)
            #expect(rects[0].width > 0)
            #expect(rects[0].maxX <= 170)
        }
    }
}
