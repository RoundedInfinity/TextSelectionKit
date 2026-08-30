import Testing
import Foundation
import CoreGraphics
@testable import TextSelectionKit

#if os(macOS)
import AppKit
#else
import UIKit
#endif

@Suite("VirtualText Binary Search & Slice Tests")
struct VirtualTextSliceSearchTests {
    
    private func makeRegistration(
        id: UUID = UUID(),
        text: String,
        frame: CGRect = CGRect(x: 0, y: 0, width: 200, height: 20),
        orderIndex: Int = 0
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
            orderIndex: orderIndex
        )
    }
    
    @Test("Binary search slice lookup at start, middle, and boundaries")
    func testBinarySearchSlices() {
        let e1 = makeRegistration(text: "First", frame: CGRect(x: 0, y: 0, width: 100, height: 20))    // length 5 (0..4), delim at 5
        let e2 = makeRegistration(text: "Second", frame: CGRect(x: 0, y: 30, width: 100, height: 20)) // length 6 (6..11), delim at 12
        let e3 = makeRegistration(text: "Third", frame: CGRect(x: 0, y: 60, width: 100, height: 20))  // length 5 (13..17)
        
        let doc = VirtualTextDocument(elements: [e1, e2, e3])
        #expect(doc.totalLength == 18) // 5 + 1 + 6 + 1 + 5
        
        // Exact start (0)
        let lookup0 = doc.slice(forGlobalOffset: 0)
        #expect(lookup0?.slice.element.text == "First")
        #expect(lookup0?.localOffset == 0)
        
        // Inside First (3)
        let lookup3 = doc.slice(forGlobalOffset: 3)
        #expect(lookup3?.slice.element.text == "First")
        #expect(lookup3?.localOffset == 3)
        
        // Delimiter between First and Second (5)
        let lookup5 = doc.slice(forGlobalOffset: 5)
        #expect(lookup5?.slice.element.text == "Second")
        #expect(lookup5?.localOffset == 0)
        
        // Inside Second (8)
        let lookup8 = doc.slice(forGlobalOffset: 8)
        #expect(lookup8?.slice.element.text == "Second")
        #expect(lookup8?.localOffset == 2) // 8 - 6
        
        // Inside Third (14)
        let lookup14 = doc.slice(forGlobalOffset: 14)
        #expect(lookup14?.slice.element.text == "Third")
        #expect(lookup14?.localOffset == 1) // 14 - 13
        
        // At exact end of document (18)
        let lookup18 = doc.slice(forGlobalOffset: 18)
        #expect(lookup18?.slice.element.text == "Third")
        #expect(lookup18?.localOffset == 5)
        
        // Past end of document (100) -> clamped
        let lookup100 = doc.slice(forGlobalOffset: 100)
        #expect(lookup100?.slice.element.text == "Third")
        #expect(lookup100?.localOffset == 5)
        
        // Negative offset (-10) -> clamped to start
        let lookupNeg = doc.slice(forGlobalOffset: -10)
        #expect(lookupNeg?.slice.element.text == "First")
        #expect(lookupNeg?.localOffset == 0)
    }
    
    @Test("Overlapping slice iteration across 5 elements")
    func testOverlappingSliceIteration() {
        let elements = (1...5).map { i in
            makeRegistration(text: "Element\(i)", frame: CGRect(x: 0, y: CGFloat(i * 30), width: 100, height: 20))
        }
        let doc = VirtualTextDocument(elements: elements)
        
        var visitedElements: [String] = []
        var visitedRanges: [Range<Int>] = []
        
        // Select from middle of Element 2 through middle of Element 4
        // E1: 0..<8, delim: 8
        // E2: 9..<17, delim: 17
        // E3: 18..<26, delim: 26
        // E4: 27..<35, delim: 35
        // E5: 36..<44
        
        doc.forEachOverlappingSlice(in: 12..<30) { slice, localRange in
            visitedElements.append(slice.element.text)
            visitedRanges.append(localRange)
        }
        
        #expect(visitedElements == ["Element2", "Element3", "Element4"])
        #expect(visitedRanges[0] == 3..<8) // 12-9..<17-9
        #expect(visitedRanges[1] == 0..<8) // full Element3
        #expect(visitedRanges[2] == 0..<3) // 27-27..<30-27
    }
}
