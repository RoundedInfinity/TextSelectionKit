import Testing
import SwiftUI
import CoreGraphics
@testable import TextSelectionKit

#if os(macOS)
import AppKit
#else
import UIKit
#endif

@Suite("Multi-Column Layout Hit-Testing Tests")
struct MultiColumnHitTestTests {
    
    private func makeFont() -> PlatformFont {
        #if os(macOS)
        return NSFont.systemFont(ofSize: 14)
        #else
        return UIFont.systemFont(ofSize: 14)
        #endif
    }
    
    @Test("Two-column layout hit-testing resolves accurately to Column 2")
    func testTwoColumnHitTesting() {
        let font = makeFont()
        
        // Column 1 (Left column, orderIndex: 0)
        let col1_row1 = TextElementRegistration(id: "col1_1", text: "Col 1 Row 1", frame: CGRect(x: 0, y: 0, width: 150, height: 20), font: font, orderIndex: 0)
        let col1_row2 = TextElementRegistration(id: "col1_2", text: "Col 1 Row 2", frame: CGRect(x: 0, y: 50, width: 150, height: 20), font: font, orderIndex: 0)
        let col1_row3 = TextElementRegistration(id: "col1_3", text: "Col 1 Row 3", frame: CGRect(x: 0, y: 100, width: 150, height: 20), font: font, orderIndex: 0)
        let col1_row4 = TextElementRegistration(id: "col1_4", text: "Col 1 Row 4", frame: CGRect(x: 0, y: 150, width: 150, height: 20), font: font, orderIndex: 0)
        
        // Column 2 (Right column, orderIndex: 1)
        let col2_row1 = TextElementRegistration(id: "col2_1", text: "Col 2 Row 1", frame: CGRect(x: 200, y: 0, width: 150, height: 20), font: font, orderIndex: 1)
        let col2_row2 = TextElementRegistration(id: "col2_2", text: "Col 2 Row 2", frame: CGRect(x: 200, y: 50, width: 150, height: 20), font: font, orderIndex: 1)
        let col2_row3 = TextElementRegistration(id: "col2_3", text: "Col 2 Row 3", frame: CGRect(x: 200, y: 100, width: 150, height: 20), font: font, orderIndex: 1)
        
        let doc = VirtualTextDocument(elements: [col1_row1, col1_row2, col1_row3, col1_row4, col2_row1, col2_row2, col2_row3])
        
        // 1. Click directly inside Col 2 Row 1
        let offsetDirect = doc.closestGlobalOffset(to: CGPoint(x: 220, y: 10))
        let (sliceDirect, _) = doc.slice(forGlobalOffset: offsetDirect)!
        #expect(sliceDirect.element.id == AnyHashable("col2_1"))
        
        // 2. Click in the margin immediately to the right of Col 2 Row 1 (x: 370, y: 10)
        let offsetRightMargin = doc.closestGlobalOffset(to: CGPoint(x: 370, y: 10))
        // Selecting from start of col2_1 (offset 48) to offsetRightMargin should select "Col 2 Row 1"
        #expect(doc.text(in: 48..<offsetRightMargin) == "Col 2 Row 1")
        #expect(doc.perElementSelections(from: 48..<offsetRightMargin) == [AnyHashable("col2_1"): 0..<11])
        
        // 3. Click inside Col 2 Row 2
        let offsetCol2Row2 = doc.closestGlobalOffset(to: CGPoint(x: 220, y: 60))
        let (sliceCol2Row2, _) = doc.slice(forGlobalOffset: offsetCol2Row2)!
        #expect(sliceCol2Row2.element.id == AnyHashable("col2_2"))
    }
    
    @Test("Three-column grid hit-testing resolves across all columns")
    func testThreeColumnGridHitTesting() {
        let font = makeFont()
        
        var elements: [TextElementRegistration] = []
        for col in 0..<3 {
            for row in 0..<4 {
                let elem = TextElementRegistration(
                    id: "c\(col)_r\(row)",
                    text: "Column \(col) Row \(row)",
                    frame: CGRect(x: CGFloat(col * 200), y: CGFloat(row * 40), width: 180, height: 25),
                    font: font,
                    orderIndex: col
                )
                elements.append(elem)
            }
        }
        
        let doc = VirtualTextDocument(elements: elements)
        
        // Click directly inside Column 2 (third column, x: 420) Row 0 (y: 10)
        let offsetCol2 = doc.closestGlobalOffset(to: CGPoint(x: 420, y: 10))
        let (sliceCol2, _) = doc.slice(forGlobalOffset: offsetCol2)!
        #expect(sliceCol2.element.id == AnyHashable("c2_r0"), "Expected Column 2 Row 0, but got \(sliceCol2.element.id)")
        
        // Click directly inside Column 1 (second column, x: 220) Row 3 (y: 130)
        let offsetCol1Row3 = doc.closestGlobalOffset(to: CGPoint(x: 220, y: 130))
        let (sliceCol1Row3, _) = doc.slice(forGlobalOffset: offsetCol1Row3)!
        #expect(sliceCol1Row3.element.id == AnyHashable("c1_r3"), "Expected Column 1 Row 3, but got \(sliceCol1Row3.element.id)")
    }
    
    @Test("Unequal column heights hit-testing resolves correctly")
    func testUnequalColumnHeights() {
        let font = makeFont()
        
        // Left Column (Long: 5 items, y: 0...200)
        let leftItems = (0..<5).map { i in
            TextElementRegistration(
                id: "left_\(i)",
                text: "Left paragraph \(i)",
                frame: CGRect(x: 0, y: CGFloat(i * 50), width: 150, height: 25),
                font: font,
                orderIndex: 0
            )
        }
        
        // Right Column (Short: 2 items, y: 0...50)
        let rightItems = (0..<2).map { i in
            TextElementRegistration(
                id: "right_\(i)",
                text: "Right short \(i)",
                frame: CGRect(x: 200, y: CGFloat(i * 50), width: 150, height: 25),
                font: font,
                orderIndex: 1
            )
        }
        
        let doc = VirtualTextDocument(elements: leftItems + rightItems)
        
        // Click inside right column row 0 at (x: 220, y: 12)
        let offsetRight0 = doc.closestGlobalOffset(to: CGPoint(x: 220, y: 12))
        let (sliceRight0, _) = doc.slice(forGlobalOffset: offsetRight0)!
        #expect(sliceRight0.element.id == AnyHashable("right_0"))
        
        // Click inside left column row 4 at (x: 20, y: 210)
        let offsetLeft4 = doc.closestGlobalOffset(to: CGPoint(x: 20, y: 210))
        let (sliceLeft4, _) = doc.slice(forGlobalOffset: offsetLeft4)!
        #expect(sliceLeft4.element.id == AnyHashable("left_4"))
    }
}
