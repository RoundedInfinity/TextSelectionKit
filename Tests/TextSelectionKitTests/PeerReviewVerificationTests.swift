import Testing
import SwiftUI
import CoreText
import Foundation
@testable import TextSelectionKit

#if os(macOS)
import AppKit
#else
import UIKit
#endif

@Suite("Peer Review Verification Tests")
struct PeerReviewVerificationTests {
    
    // MARK: - 1. Multi-Column Distance Early-Exit Bug (1.5)
    
    @Test("Verify Multi-Column Early-Exit Distance Bug in closestGlobalOffset")
    func verifyMultiColumnHitTestBug() {
        // Setup a 2-column layout:
        // Column 1 (orderIndex 0): (x: 0, y: 0), (x: 0, y: 100), (x: 0, y: 200)
        // Column 2 (orderIndex 1): (x: 300, y: 0), (x: 300, y: 100), (x: 300, y: 200)
        #if os(macOS)
        let font = NSFont.systemFont(ofSize: 14)
        #else
        let font = UIFont.systemFont(ofSize: 14)
        #endif
        
        let c1_1 = TextElementRegistration(id: "c1_1", text: "Col 1 Row 1", frame: CGRect(x: 0, y: 0, width: 100, height: 20), font: font, orderIndex: 0)
        let c1_2 = TextElementRegistration(id: "c1_2", text: "Col 1 Row 2", frame: CGRect(x: 0, y: 100, width: 100, height: 20), font: font, orderIndex: 0)
        let c1_3 = TextElementRegistration(id: "c1_3", text: "Col 1 Row 3", frame: CGRect(x: 0, y: 200, width: 100, height: 20), font: font, orderIndex: 0)
        
        let c2_1 = TextElementRegistration(id: "c2_1", text: "Col 2 Row 1", frame: CGRect(x: 300, y: 0, width: 100, height: 20), font: font, orderIndex: 1)
        let c2_2 = TextElementRegistration(id: "c2_2", text: "Col 2 Row 2", frame: CGRect(x: 300, y: 100, width: 100, height: 20), font: font, orderIndex: 1)
        let c2_3 = TextElementRegistration(id: "c2_3", text: "Col 2 Row 3", frame: CGRect(x: 300, y: 200, width: 100, height: 20), font: font, orderIndex: 1)
        
        let doc = VirtualTextDocument(elements: [c1_1, c1_2, c1_3, c2_1, c2_2, c2_3])
        
        // Point clicking directly inside Column 2 Row 1 at (x: 320, y: 10)
        let clickedOffset = doc.closestGlobalOffset(to: CGPoint(x: 320, y: 10))
        let (slice, _) = doc.slice(forGlobalOffset: clickedOffset)!
        #expect(slice.element.id == AnyHashable("c2_1"), "closestGlobalOffset resolves to Column 2 Row 1")
        
        // Point clicking right beside Column 2 Row 1 at (x: 420, y: 10) selects through end of Col 2 Row 1
        let rightMarginOffset = doc.closestGlobalOffset(to: CGPoint(x: 420, y: 10))
        #expect(doc.text(in: 36..<rightMarginOffset) == "Col 2 Row 1")
    }
    
    // MARK: - 2. Native NSAttributedString Conversion vs Custom Builder (1.2)
    
    @Test("Verify whether NSAttributedString(attributedString, including:) handles SwiftUI attributes")
    func verifyNativeNSAttributedStringConversion() {
        var attr = AttributedString("Color Test")
        attr.foregroundColor = .red
        attr.font = .title
        
        #if os(macOS)
        let nsAttr = try? NSAttributedString(attr, including: \.appKit)
        let hasColor = nsAttr?.attribute(.foregroundColor, at: 0, effectiveRange: nil) != nil
        #expect(!hasColor, "Demonstrates that native NSAttributedString(including: \\.appKit) drops SwiftUI.Color/Font without explicit conversion!")
        #else
        let nsAttr = try? NSAttributedString(attr, including: \.uiKit)
        let hasColor = nsAttr?.attribute(.foregroundColor, at: 0, effectiveRange: nil) != nil
        #expect(!hasColor, "Demonstrates that native NSAttributedString(including: \\.uiKit) drops SwiftUI.Color/Font without explicit conversion!")
        #endif
    }
    
    // MARK: - 3. NSMutableParagraphStyle vs C Unsafe Pointer CTParagraphStyle (1.3)
    
    @Test("Verify NSMutableParagraphStyle toll-free bridging to CoreText CTFramesetter")
    func verifyParagraphStyleBridging() {
        let text = "Hello Paragraph Style Bridging"
        #if os(macOS)
        let font = NSFont.systemFont(ofSize: 14)
        #else
        let font = UIFont.systemFont(ofSize: 14)
        #endif
        
        let mutableAttr = NSMutableAttributedString(string: text, attributes: [.font: font])
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .right
        paragraphStyle.lineSpacing = 6
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.baseWritingDirection = .leftToRight
        
        mutableAttr.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: mutableAttr.length))
        
        let framesetter = CTFramesetterCreateWithAttributedString(mutableAttr as CFAttributedString)
        let path = CGPath(rect: CGRect(x: 0, y: 0, width: 200, height: 100), transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, nil)
        let lines = CTFrameGetLines(frame) as? [CTLine]
        
        #expect(lines != nil && !lines!.isEmpty)
    }
    
    // MARK: - 4. Case Transformation Bug (2.7)
    
    @Test("Verify Case Transformation preserves styling and runs")
    func verifyCaseTransformationBug() {
        var original = AttributedString("Styled Text")
        original.foregroundColor = .red
        
        let selectable = SelectableText(original)
        let transformed = selectable.applyingTextCase(.uppercase)
        
        #expect(String(transformed.characters) == "STYLED TEXT")
        #expect(transformed.runs.first?.foregroundColor == .red, "Case transformation must preserve foregroundColor")
    }
    
    // MARK: - 5. macOS resignFirstResponder Bug (2.5)
    
    #if os(macOS)
    @Test("Verify macOS resignFirstResponder clears active selection")
    @MainActor
    func verifyResignFirstResponderBug() {
        let manager = SelectionManager()
        let elem = TextElementRegistration(
            id: UUID(),
            text: "Hello World",
            frame: CGRect(x: 0, y: 0, width: 200, height: 20),
            font: NSFont.systemFont(ofSize: 14),
            orderIndex: 0
        )
        manager.updateRegisteredElements([elem])
        manager.select(0..<5)
        #expect(manager.hasSelection)
        
        let trackingView = MacOSSelectionTrackingView()
        trackingView.manager = manager
        
        // When focus shifts away (e.g. clicking a toolbar item)
        _ = trackingView.resignFirstResponder()
        
        // Bug: manager selection was cleared!
        #expect(manager.hasSelection, "Selection is preserved when resigning first responder")
    }
    #endif
    
    // MARK: - 6. Multi-Line CoreText Wrapping (Scenario A)
    
    @Test("Verify Multi-Line wrapping produces separate line rects")
    func verifyMultiLineWrapping() {
        let longText = "The quick brown fox jumps over the lazy dog and runs across the wide green field in the sunshine."
        #if os(macOS)
        let font = NSFont.systemFont(ofSize: 14)
        #else
        let font = UIFont.systemFont(ofSize: 14)
        #endif
        
        let elem = TextElementRegistration(
            id: UUID(),
            text: longText,
            frame: CGRect(x: 0, y: 0, width: 120, height: 120),
            font: font,
            orderIndex: 0
        )
        let doc = VirtualTextDocument(elements: [elem])
        let rects = doc.lineSelectionRects(for: 0..<longText.utf16.count)
        
        #expect(rects.count > 1)
        for i in 1..<rects.count {
            #expect(rects[i].minY > rects[i-1].minY)
        }
    }
}
