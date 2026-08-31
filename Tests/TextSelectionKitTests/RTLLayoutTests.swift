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

@Suite("RTL (Right-to-Left) Layout & Bidirectional Geometry Tests")
struct RTLLayoutTests {
    
    private func makeRTLRegistration(
        id: UUID = UUID(),
        text: String,
        frame: CGRect = CGRect(x: 10, y: 10, width: 300, height: 35),
        alignment: TextAlignment = .leading,
        layoutDirection: LayoutDirection = .rightToLeft,
        delimiter: String = "\n",
        lineLimit: Int? = nil,
        truncationMode: Text.TruncationMode = .tail
    ) -> TextElementRegistration {
        #if os(macOS)
        let font = NSFont.systemFont(ofSize: 16)
        #else
        let font = UIFont.systemFont(ofSize: 16)
        #endif
        return TextElementRegistration(
            id: id,
            text: text,
            frame: frame,
            font: font,
            orderIndex: 0,
            delimiter: delimiter,
            alignment: alignment,
            lineLimit: lineLimit,
            truncationMode: truncationMode,
            layoutDirection: layoutDirection
        )
    }
    
    // MARK: - Single-Line & Multi-Line RTL Geometry
    
    @Test("Arabic single-line caret progression moves from right to left")
    func testArabicCaretProgression() {
        let text = "مرحبا بالعالم" // "Hello World" in Arabic (13 utf16 code units)
        let elem = makeRTLRegistration(text: text, frame: CGRect(x: 0, y: 0, width: 300, height: 30))
        let doc = VirtualTextDocument(elements: [elem])
        
        let startCaret = doc.caretRect(atGlobalOffset: 0)
        let middleCaret = doc.caretRect(atGlobalOffset: 6)
        let endCaret = doc.caretRect(atGlobalOffset: text.utf16.count)
        
        // In leading-aligned RTL text, offset 0 is on the right side of the container
        #expect(startCaret.minX > 200)
        
        // Progressing through the string moves caret leftward
        #expect(middleCaret.minX < startCaret.minX)
        #expect(endCaret.minX < middleCaret.minX)
        #expect(endCaret.minX >= 0)
    }
    
    @Test("Hebrew single-line text layout and word boundary selection")
    func testHebrewLayoutAndWordBoundaries() {
        let text = "שלום עולם שלום" // "Hello world hello" in Hebrew
        let elem = makeRTLRegistration(text: text, frame: CGRect(x: 10, y: 10, width: 300, height: 30))
        let doc = VirtualTextDocument(elements: [elem])
        
        // Word range at start (index 0)
        let wordRange = doc.wordRange(atGlobalOffset: 0)
        #expect(wordRange == 0..<4) // "שלום"
        #expect(doc.text(in: wordRange!) == "שלום")
        
        // Selection rect for the first word should be positioned on the right
        let rects = doc.lineSelectionRects(for: 0..<4)
        #expect(!rects.isEmpty)
        #expect(rects[0].maxX > 200)
        #expect(rects[0].width > 20)
    }
    
    @Test("Multi-line Arabic text wraps correctly and hit-tests each line right-to-left")
    func testMultiLineArabicHitTesting() {
        let longArabicText = "هذا النص هو مثال لنص عربي طويل يمتد على عدة أسطر لاختبار دقة التحديد والتفاعل في اتجاه اليمين إلى اليسار."
        let elem = makeRTLRegistration(
            text: longArabicText,
            frame: CGRect(x: 0, y: 0, width: 180, height: 100)
        )
        let doc = VirtualTextDocument(elements: [elem])
        
        // Whole document selection rects should span across multiple vertical lines
        let allRects = doc.lineSelectionRects(for: 0..<longArabicText.utf16.count)
        #expect(!allRects.isEmpty)
        
        let minY = allRects.map(\.minY).min() ?? 0
        let maxY = allRects.map(\.maxY).max() ?? 0
        #expect(maxY > minY + 30) // Spans multiple lines vertically
        
        // First line rects vs last line rects are on different vertical rows
        let firstLineRect = allRects.first!
        let lastLineRect = allRects.last!
        #expect(lastLineRect.minY > firstLineRect.minY)
        
        // Clicking at the top-right (start of line 0, x: 175, y: 10) maps to offset near 0
        let topHit = doc.closestGlobalOffset(to: CGPoint(x: 175, y: 10))
        #expect(topHit <= 5)
        
        // Clicking at line 1 (y: 35, x: 175) maps to an offset corresponding to line 1 start
        let midHit = doc.closestGlobalOffset(to: CGPoint(x: 175, y: 35))
        #expect(midHit > 10)
    }
    
    // MARK: - RTL Alignments (.leading, .trailing, .center)
    
    @Test("RTL text alignments correctly position starting caret")
    func testRTLAlignments() {
        let text = "نص تجريبي" // short Arabic text
        
        // 1. Leading alignment (right-aligned in RTL)
        let leadingElem = makeRTLRegistration(text: text, frame: CGRect(x: 0, y: 0, width: 300, height: 30), alignment: .leading)
        let docLeading = VirtualTextDocument(elements: [leadingElem])
        let leadingStart = docLeading.caretRect(atGlobalOffset: 0)
        #expect(leadingStart.minX > 200)
        
        // 2. Trailing alignment (left-aligned in RTL)
        let trailingElem = makeRTLRegistration(text: text, frame: CGRect(x: 0, y: 0, width: 300, height: 30), alignment: .trailing)
        let docTrailing = VirtualTextDocument(elements: [trailingElem])
        let trailingStart = docTrailing.caretRect(atGlobalOffset: 0)
        #expect(trailingStart.minX < 150)
        
        // 3. Center alignment (centered in RTL)
        let centerElem = makeRTLRegistration(text: text, frame: CGRect(x: 0, y: 0, width: 300, height: 30), alignment: .center)
        let docCenter = VirtualTextDocument(elements: [centerElem])
        let centerStart = docCenter.caretRect(atGlobalOffset: 0)
        #expect(centerStart.minX > trailingStart.minX)
        #expect(centerStart.minX < leadingStart.minX)
    }
    
    // MARK: - Mixed Bidirectional Text (LTR inside RTL)
    
    @Test("Bidirectional mixed script text accurately generates non-overlapping selection rects")
    func testBidirectionalRunsSelectionRects() {
        let bidiText = "السعر هو 150 USD فقط لا غير" // Arabic with English/numbers embedded
        let elem = makeRTLRegistration(text: bidiText, frame: CGRect(x: 0, y: 0, width: 350, height: 30))
        let doc = VirtualTextDocument(elements: [elem])
        
        // Full selection
        let rects = doc.lineSelectionRects(for: 0..<bidiText.utf16.count)
        #expect(!rects.isEmpty)
        for r in rects {
            #expect(r.width > 0)
            #expect(r.minX >= 0)
            #expect(r.maxX <= 360)
        }
        
        // Sub-selection of embedded English "150 USD"
        if let range = bidiText.range(of: "150 USD") {
            let utf16Start = bidiText.utf16.distance(from: bidiText.startIndex, to: range.lowerBound)
            let utf16End = bidiText.utf16.distance(from: bidiText.startIndex, to: range.upperBound)
            let subRects = doc.lineSelectionRects(for: utf16Start..<utf16End)
            #expect(!subRects.isEmpty)
            #expect(subRects[0].width > 0)
        }
    }
    
    // MARK: - Multi-Element Stacked RTL Container
    
    @Test("Multiple stacked RTL elements maintain right-aligned continuous selection")
    func testMultipleStackedRTLElements() {
        let e1 = makeRTLRegistration(
            id: UUID(),
            text: "العنوان الرئيسي", // Main Heading
            frame: CGRect(x: 0, y: 0, width: 300, height: 30),
            delimiter: "\n"
        )
        let e2 = makeRTLRegistration(
            id: UUID(),
            text: "العنوان الفرعي للمقال", // Subtitle
            frame: CGRect(x: 0, y: 40, width: 300, height: 25),
            delimiter: "\n"
        )
        let e3 = makeRTLRegistration(
            id: UUID(),
            text: "الفقرة الأولى من النص العربي", // First paragraph
            frame: CGRect(x: 0, y: 75, width: 300, height: 25),
            delimiter: ""
        )
        let doc = VirtualTextDocument(elements: [e1, e2, e3])
        
        #expect(doc.elements.count == 3)
        #expect(doc.fullText == "العنوان الرئيسي\nالعنوان الفرعي للمقال\nالفقرة الأولى من النص العربي")
        
        // Select across element 1 and element 2
        let selSpan = doc.perElementSelections(from: 5..<25)
        #expect(selSpan[e1.id] != nil)
        #expect(selSpan[e2.id] != nil)
        
        let rects = doc.lineSelectionRects(for: 0..<doc.totalLength)
        #expect(!rects.isEmpty)
        
        // Ensure rects exist on all three element Y bands
        let e1Rects = rects.filter { $0.minY >= 0 && $0.minY < 35 }
        let e2Rects = rects.filter { $0.minY >= 35 && $0.minY < 70 }
        let e3Rects = rects.filter { $0.minY >= 70 }
        
        #expect(!e1Rects.isEmpty)
        #expect(!e2Rects.isEmpty)
        #expect(!e3Rects.isEmpty)
    }
    
    @Test("Custom Arabic comma delimiter preserves text roundtrip in RTL documents")
    func testArabicCommaDelimiter() {
        let e1 = makeRTLRegistration(text: "تفاح", frame: CGRect(x: 0, y: 0, width: 60, height: 20), delimiter: "، ")
        let e2 = makeRTLRegistration(text: "موز", frame: CGRect(x: 70, y: 0, width: 60, height: 20), delimiter: "، ")
        let e3 = makeRTLRegistration(text: "كرز", frame: CGRect(x: 140, y: 0, width: 60, height: 20), delimiter: "")
        let doc = VirtualTextDocument(elements: [e1, e2, e3])
        
        #expect(doc.fullText == "تفاح، موز، كرز")
        #expect(doc.text(in: 0..<doc.totalLength) == "تفاح، موز، كرز")
        #expect(String(doc.attributedString(in: 0..<doc.totalLength).characters) == "تفاح، موز، كرز")
    }
    
    // MARK: - RTL Truncation & lineLimit
    
    @Test("RTL text with lineLimit and truncation preserves valid caret and selection coordinates")
    func testRTLTruncationBounds() {
        let longArabicText = "هذا نص عربي طويل جداً لاختبار سلوك الاقتطاع عند تفعيل الحد الأقصى للأسطر في واجهة المستخدم."
        let elem = makeRTLRegistration(
            text: longArabicText,
            frame: CGRect(x: 0, y: 0, width: 120, height: 25),
            lineLimit: 1,
            truncationMode: .tail
        )
        let doc = VirtualTextDocument(elements: [elem])
        
        let caretStart = doc.caretRect(atGlobalOffset: 0)
        let caretEnd = doc.caretRect(atGlobalOffset: longArabicText.utf16.count)
        
        #expect(caretStart.width == 2)
        #expect(caretEnd.width == 2)
        #expect(caretStart.minX >= 0)
        #expect(caretEnd.minX >= 0)
        
        let rects = doc.lineSelectionRects(for: 0..<longArabicText.utf16.count)
        #expect(!rects.isEmpty)
        for r in rects {
            #expect(r.width > 0)
            #expect(r.maxX <= 130)
        }
    }
}
