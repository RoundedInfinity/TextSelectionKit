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
}
