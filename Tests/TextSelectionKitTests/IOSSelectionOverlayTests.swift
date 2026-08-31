import Testing
import Foundation
import CoreGraphics
import SwiftUI
@testable import TextSelectionKit

#if os(iOS) || os(visionOS) || os(tvOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@Suite("iOS Selection Handles & Loupe Magnifier Coordination Tests")
struct IOSSelectionOverlayTests {
    
    // MARK: - Helpers
    
    private func makeRegistration(
        id: UUID = UUID(),
        text: String,
        frame: CGRect = CGRect(x: 20, y: 30, width: 300, height: 40),
        alignment: TextAlignment = .leading,
        layoutDirection: LayoutDirection = .leftToRight
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
            alignment: alignment,
            layoutDirection: layoutDirection
        )
    }
    
    // MARK: - Cross-Platform Loupe Magnifier & Handle Geometry Tests
    
    @Test("Loupe caret rect tracking maintains vertical continuity across multi-line paragraphs")
    func testLoupeCaretContinuity() {
        let elem1 = makeRegistration(
            text: "First line of text for loupe",
            frame: CGRect(x: 10, y: 10, width: 250, height: 25)
        )
        let elem2 = makeRegistration(
            text: "Second line of text for loupe",
            frame: CGRect(x: 10, y: 45, width: 250, height: 25)
        )
        let doc = VirtualTextDocument(elements: [elem1, elem2])
        
        // Test caret rect at various offsets
        let caretStart = doc.caretRect(atGlobalOffset: 0)
        let caretMiddle = doc.caretRect(atGlobalOffset: 10)
        let caretElem2 = doc.caretRect(atGlobalOffset: elem1.text.utf16.count + 1) // First char of second element
        
        #expect(caretStart.width == 2)
        #expect(caretStart.height > 10)
        #expect(caretStart.minX >= 10)
        #expect(caretMiddle.minX > caretStart.minX)
        #expect(caretElem2.minY > caretStart.maxY)
        
        // Simulating vertical loupe drag down from middle of line 1 to line 2
        let dragPoint = CGPoint(x: caretMiddle.midX, y: caretMiddle.midY + 35)
        let newOffset = doc.closestGlobalOffset(to: dragPoint)
        let dragCaret = doc.caretRect(atGlobalOffset: newOffset)
        
        #expect(dragCaret.minY >= elem2.frame.minY - 5)
        #expect(dragCaret.minY <= elem2.frame.maxY + 5)
    }
    
    @Test("Selection handle touch expansion bounds cover 24pt hit target area around selection rects")
    func testHandleTouchExpansionTargetBounds() {
        let elem = makeRegistration(
            text: "SwiftUI Text Selection Kit",
            frame: CGRect(x: 50, y: 50, width: 200, height: 30)
        )
        let doc = VirtualTextDocument(elements: [elem])
        
        // Select "Text" (range 8..<12)
        let rects = doc.lineSelectionRects(for: 8..<12)
        #expect(!rects.isEmpty)
        let selRect = rects[0]
        
        // 24pt expansion area around selection rect
        let expanded = selRect.insetBy(dx: -24, dy: -24)
        
        // Point right on start handle (bottom-left of selection, offset by 10pt down and 10pt left)
        let startHandleTouch = CGPoint(x: selRect.minX - 10, y: selRect.maxY + 10)
        #expect(expanded.contains(startHandleTouch))
        
        // Point right on end handle (top-right of selection, offset by 10pt up and 10pt right)
        let endHandleTouch = CGPoint(x: selRect.maxX + 10, y: selRect.minY - 10)
        #expect(expanded.contains(endHandleTouch))
        
        // Point outside the 24pt handle radius (50pt away)
        let farTouch = CGPoint(x: selRect.maxX + 50, y: selRect.maxY + 50)
        #expect(!expanded.contains(farTouch))
    }
    
    @Test("RTL loupe caret tracking moves right-to-left across multi-line Arabic layouts")
    func testRTLLoupeCaretContinuityAndProgression() {
        let line1 = makeRegistration(
            text: "السطر الأول من النص العربي", // Line 1
            frame: CGRect(x: 10, y: 10, width: 280, height: 25),
            layoutDirection: .rightToLeft
        )
        let line2 = makeRegistration(
            text: "السطر الثاني من النص العربي", // Line 2
            frame: CGRect(x: 10, y: 45, width: 280, height: 25),
            layoutDirection: .rightToLeft
        )
        let doc = VirtualTextDocument(elements: [line1, line2])
        
        // Caret at offset 0 (start of line 1) is positioned on the right
        let caretStart = doc.caretRect(atGlobalOffset: 0)
        #expect(caretStart.minX > 200)
        
        // Dragging finger to the left along line 1 advances caret offset
        let midDragPoint = CGPoint(x: 150, y: caretStart.midY)
        let midOffset = doc.closestGlobalOffset(to: midDragPoint)
        let midCaret = doc.caretRect(atGlobalOffset: midOffset)
        
        #expect(midOffset > 0)
        #expect(midCaret.minX < caretStart.minX)
        
        // Dragging vertically down from mid of line 1 to line 2
        let downDragPoint = CGPoint(x: 150, y: caretStart.midY + 35)
        let line2Offset = doc.closestGlobalOffset(to: downDragPoint)
        let line2Caret = doc.caretRect(atGlobalOffset: line2Offset)
        
        #expect(line2Offset >= line1.text.utf16.count)
        #expect(line2Caret.minY >= line2.frame.minY - 5)
    }
    
    @Test("RTL selection handles touch targets cover right-aligned start handle and left-aligned end handle")
    func testRTLSelectionHandleTouchExpansionTargetBounds() {
        let elem = makeRegistration(
            text: "مرحبا بالعالم العربي الجميل",
            frame: CGRect(x: 0, y: 0, width: 300, height: 30),
            layoutDirection: .rightToLeft
        )
        let doc = VirtualTextDocument(elements: [elem])
        
        // Select "مرحبا" (0..<5)
        let rects = doc.lineSelectionRects(for: 0..<5)
        #expect(!rects.isEmpty)
        
        let selRect = rects[0]
        let expanded = selRect.insetBy(dx: -24, dy: -24)
        
        // Start handle on the top-right in RTL (offset 10pt right and 10pt up)
        let startHandleTouch = CGPoint(x: selRect.maxX + 10, y: selRect.minY - 10)
        #expect(expanded.contains(startHandleTouch))
        
        // End handle on the bottom-left in RTL (offset 10pt left and 10pt down)
        let endHandleTouch = CGPoint(x: selRect.minX - 10, y: selRect.maxY + 10)
        #expect(expanded.contains(endHandleTouch))
        
        // Far away touch (80pt away from selection)
        let farTouch = CGPoint(x: 20, y: 150)
        #expect(!expanded.contains(farTouch))
    }
    
    // MARK: - iOS UIKit & UITextInput Conformance Tests
    
    #if os(iOS) || os(visionOS) || os(tvOS)
    
    @Test("CustomTextSelectionRect properties and flags")
    func testCustomTextSelectionRect() {
        let rect = CGRect(x: 10, y: 20, width: 100, height: 25)
        let selRect = CustomTextSelectionRect(
            rect: rect,
            writingDirection: .leftToRight,
            containsStart: true,
            containsEnd: false,
            isVertical: false
        )
        
        #expect(selRect.rect == rect)
        #expect(selRect.writingDirection == .leftToRight)
        #expect(selRect.containsStart == true)
        #expect(selRect.containsEnd == false)
        #expect(selRect.isVertical == false)
    }
    
    @Test("iOS NativeSelectionTrackingUIView selectionRects returns accurate start/end flags for handles")
    @MainActor
    func testIOSTextInputSelectionRects() {
        let manager = SelectionManager()
        let elem1 = makeRegistration(
            text: "Line One",
            frame: CGRect(x: 10, y: 10, width: 200, height: 25)
        )
        let elem2 = makeRegistration(
            text: "Line Two",
            frame: CGRect(x: 10, y: 40, width: 200, height: 25)
        )
        let elem3 = makeRegistration(
            text: "Line Three",
            frame: CGRect(x: 10, y: 70, width: 200, height: 25)
        )
        manager.updateRegisteredElements([elem1, elem2, elem3])
        
        let trackingView = NativeSelectionTrackingUIView(frame: CGRect(x: 0, y: 0, width: 300, height: 120))
        trackingView.manager = manager
        
        // Select spanning all 3 elements
        let total = manager.totalLength
        let range = VirtualTextRange(range: 0..<total)
        let selRects = trackingView.selectionRects(for: range)
        
        #expect(selRects.count == 3)
        #expect(selRects[0].containsStart == true)
        #expect(selRects[0].containsEnd == false)
        #expect(selRects[1].containsStart == false)
        #expect(selRects[1].containsEnd == false)
        #expect(selRects[2].containsStart == false)
        #expect(selRects[2].containsEnd == true)
        #expect(selRects[0].writingDirection == .leftToRight)
    }
    
    @Test("iOS NativeSelectionTrackingUIView handles RTL writing direction in selectionRects")
    @MainActor
    func testIOSRTLSelectionRects() {
        let manager = SelectionManager()
        let rtlElem = makeRegistration(
            text: "مرحبا بالعالم",
            frame: CGRect(x: 10, y: 10, width: 200, height: 25),
            layoutDirection: .rightToLeft
        )
        manager.updateRegisteredElements([rtlElem])
        
        let trackingView = NativeSelectionTrackingUIView(frame: CGRect(x: 0, y: 0, width: 300, height: 50))
        trackingView.manager = manager
        
        let range = VirtualTextRange(range: 0..<rtlElem.text.utf16.count)
        let selRects = trackingView.selectionRects(for: range)
        
        #expect(!selRects.isEmpty)
        #expect(selRects[0].writingDirection == .rightToLeft)
        #expect(selRects.first?.containsStart == true)
        #expect(selRects.last?.containsEnd == true)
    }
    
    @Test("iOS UITextInput loupe position and navigation methods")
    @MainActor
    func testIOSTextInputNavigationAndLoupe() {
        let manager = SelectionManager()
        let elem1 = makeRegistration(
            text: "Hello World",
            frame: CGRect(x: 10, y: 10, width: 100, height: 25)
        )
        let elem2 = makeRegistration(
            text: "SwiftUI Selection",
            frame: CGRect(x: 10, y: 40, width: 150, height: 25)
        )
        manager.updateRegisteredElements([elem1, elem2])
        
        let trackingView = NativeSelectionTrackingUIView(frame: CGRect(x: 0, y: 0, width: 300, height: 100))
        trackingView.manager = manager
        
        // 1. caretRect(for:)
        let startPos = VirtualTextPosition(offset: 0)
        let caret = trackingView.caretRect(for: startPos)
        #expect(caret.width == 2)
        #expect(caret.minX >= 10)
        
        // 2. firstRect(for:)
        let range = VirtualTextRange(range: 0..<5)
        let first = trackingView.firstRect(for: range)
        #expect(first.width > 0)
        #expect(first.height > 0)
        
        // 3. closestPosition(to:)
        let pos1 = trackingView.closestPosition(to: CGPoint(x: 15, y: 15)) as? VirtualTextPosition
        #expect(pos1 != nil)
        #expect(pos1?.offset == 0 || pos1?.offset == 1)
        
        // 4. closestPosition(to:within:)
        let posClamped = trackingView.closestPosition(to: CGPoint(x: 500, y: 500), within: VirtualTextRange(range: 0..<5)) as? VirtualTextPosition
        #expect(posClamped?.offset == 5)
        
        // 5. position(from:in:offset:) vertical loupe movement
        let downPos = trackingView.position(from: startPos, in: .down, offset: 1) as? VirtualTextPosition
        #expect(downPos != nil)
        #expect(downPos!.offset >= elem1.text.utf16.count) // Moved to second element
        
        let upPos = trackingView.position(from: downPos!, in: .up, offset: 1) as? VirtualTextPosition
        #expect(upPos != nil)
        #expect(upPos!.offset <= elem1.text.utf16.count) // Moved back to first element
        
        // 6. characterRange(at:) word selection
        let wordRange = trackingView.characterRange(at: CGPoint(x: 20, y: 20)) as? VirtualTextRange
        #expect(wordRange?.range == 0..<5) // "Hello"
        
        // 7. characterRange(byExtending:in:)
        let extRight = trackingView.characterRange(byExtending: startPos, in: .right) as? VirtualTextRange
        #expect(extRight?.range == 0..<1)
        
        // 8. compare and offset
        let posB = VirtualTextPosition(offset: 6)
        #expect(trackingView.compare(startPos, to: posB) == .orderedAscending)
        #expect(trackingView.offset(from: startPos, to: posB) == 6)
        
        // 9. text(in:)
        let text = trackingView.text(in: VirtualTextRange(range: 0..<5))
        #expect(text == "Hello")
    }
    
    @Test("iOS NativeSelectionTrackingUIView hit-testing captures handles within 24pt margin")
    @MainActor
    func testIOSHitTestingWithActiveSelectionHandles() {
        let manager = SelectionManager()
        let elem = makeRegistration(
            text: "Selectable text item",
            frame: CGRect(x: 50, y: 50, width: 200, height: 30)
        )
        manager.updateRegisteredElements([elem])
        
        let trackingView = NativeSelectionTrackingUIView(frame: CGRect(x: 0, y: 0, width: 400, height: 400))
        trackingView.manager = manager
        trackingView.hitTestPolicy = .textOnly(padding: 8)
        
        // 1. Without active selection: touch outside text padding (x: 10, y: 10) passes through (returns nil)
        #expect(trackingView.hitTest(CGPoint(x: 10, y: 10), with: nil) == nil)
        
        // Touch on text element (x: 60, y: 60) hits tracking view
        #expect(trackingView.hitTest(CGPoint(x: 60, y: 60), with: nil) === trackingView)
        
        // 2. With active selection: select "Selectable" (range 0..<10)
        manager.select(0..<10)
        #expect(manager.hasSelection == true)
        
        let selRect = manager.document.lineSelectionRects(for: 0..<10)[0]
        
        // Touch 15pt below selection rect (inside 24pt handle touch target) captures view for dragging
        let handleTouch = CGPoint(x: selRect.midX, y: selRect.maxY + 15)
        #expect(trackingView.hitTest(handleTouch, with: nil) === trackingView)
        
        // Touch 80pt away from selection and text returns nil (passes to scroll view)
        let farTouch = CGPoint(x: 350, y: 350)
        #expect(trackingView.hitTest(farTouch, with: nil) == nil)
    }
    
    @Test("iOS selectedTextRange getter/setter coordinates with SelectionManager")
    @MainActor
    func testIOSSelectedTextRangeSynchronization() {
        let manager = SelectionManager()
        let elem = makeRegistration(
            text: "Hello World",
            frame: CGRect(x: 0, y: 0, width: 200, height: 30)
        )
        manager.updateRegisteredElements([elem])
        
        let trackingView = NativeSelectionTrackingUIView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
        trackingView.manager = manager
        
        // Initially no selection
        #expect(trackingView.selectedTextRange == nil)
        
        // Setting selectedTextRange updates manager
        trackingView.selectedTextRange = VirtualTextRange(range: 0..<5)
        #expect(manager.hasSelection == true)
        #expect(manager.globalSelectedRange == 0..<5)
        #expect((trackingView.selectedTextRange as? VirtualTextRange)?.range == 0..<5)
        
        // Clearing via selectedTextRange = nil
        trackingView.selectedTextRange = nil
        #expect(manager.hasSelection == false)
        #expect(trackingView.selectedTextRange == nil)
    }
    
    @Test("iOS edit menu interaction coordinates custom context menu items")
    @MainActor
    func testIOSEditMenuInteractionCustomProvider() {
        let manager = SelectionManager()
        let elem = makeRegistration(
            text: "Selected text content",
            frame: CGRect(x: 0, y: 0, width: 200, height: 30)
        )
        manager.updateRegisteredElements([elem])
        manager.select(0..<8) // "Selected"
        
        let trackingView = NativeSelectionTrackingUIView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
        trackingView.manager = manager
        
        var actionExecuted = false
        let provider = SelectionContextMenuProvider(placement: .replace) { context in
            SelectionButton("Custom iOS Action", systemImage: "sparkles") {
                actionExecuted = true
            }.makeParsedMenuItems()
        }
        trackingView.contextMenuProvider = provider
        
        let editInteraction = UIEditMenuInteraction(delegate: trackingView)
        let config = UIEditMenuConfiguration(identifier: "testConfig", sourcePoint: CGPoint(x: 50, y: 20))
        let suggestedAction = UIAction(title: "Suggested") { _ in }
        
        let menu = trackingView.editMenuInteraction(editInteraction, menuFor: config, suggestedActions: [suggestedAction])
        #expect(menu != nil)
        #expect(menu?.children.count == 1)
        
        if let customAction = menu?.children.first as? UIAction {
            #expect(customAction.title == "Custom iOS Action")
        }
    }
    
    @Test("iOS RTL selection handles accurately position touch targets and report rightToLeft writing direction")
    @MainActor
    func testIOSRTLSelectionHandlesAndTouchTargets() {
        let manager = SelectionManager()
        let rtlElem = makeRegistration(
            text: "مرحبا بالعالم الجميل", // "Hello beautiful world" in Arabic
            frame: CGRect(x: 0, y: 0, width: 300, height: 35),
            alignment: .leading,
            layoutDirection: .rightToLeft
        )
        manager.updateRegisteredElements([rtlElem])
        
        let trackingView = NativeSelectionTrackingUIView(frame: CGRect(x: 0, y: 0, width: 400, height: 100))
        trackingView.manager = manager
        trackingView.hitTestPolicy = .textOnly(padding: 8)
        
        // Select first word "مرحبا" (0..<5)
        manager.select(0..<5)
        let range = VirtualTextRange(range: 0..<5)
        let selRects = trackingView.selectionRects(for: range)
        
        #expect(!selRects.isEmpty)
        #expect(selRects[0].writingDirection == .rightToLeft)
        #expect(selRects[0].containsStart == true)
        #expect(selRects[selRects.count - 1].containsEnd == true)
        
        let firstRect = selRects[0].rect
        let lastRect = selRects[selRects.count - 1].rect
        
        // In leading RTL, start handle is on the right side of the selection
        let startHandlePoint = CGPoint(x: firstRect.maxX + 12, y: firstRect.minY - 10)
        #expect(trackingView.hitTest(startHandlePoint, with: nil) === trackingView)
        
        // End handle is on the left side of the selection
        let endHandlePoint = CGPoint(x: lastRect.minX - 12, y: lastRect.maxY + 10)
        #expect(trackingView.hitTest(endHandlePoint, with: nil) === trackingView)
        
        // Far away on the unselected bottom area passes through
        let unselectedFarPoint = CGPoint(x: 20, y: 70)
        #expect(trackingView.hitTest(unselectedFarPoint, with: nil) == nil)
    }
    
    @Test("iOS RTL loupe magnifier tracking and base writing direction")
    @MainActor
    func testIOSRTLLoupeTrackingProgressionAndNavigation() {
        let manager = SelectionManager()
        let line1 = makeRegistration(
            text: "السطر الأول من النص العربي", // Line 1
            frame: CGRect(x: 0, y: 0, width: 300, height: 30),
            layoutDirection: .rightToLeft
        )
        let line2 = makeRegistration(
            text: "السطر الثاني من النص العربي", // Line 2
            frame: CGRect(x: 0, y: 40, width: 300, height: 30),
            layoutDirection: .rightToLeft
        )
        manager.updateRegisteredElements([line1, line2])
        
        let trackingView = NativeSelectionTrackingUIView(frame: CGRect(x: 0, y: 0, width: 350, height: 100))
        trackingView.manager = manager
        
        // 1. baseWritingDirection for Arabic
        let startPos = VirtualTextPosition(offset: 0)
        #expect(trackingView.baseWritingDirection(for: startPos, in: .forward) == .rightToLeft)
        
        // 2. Caret rect in RTL: offset 0 is on the right
        let caretStart = trackingView.caretRect(for: startPos)
        let caretMidLine1 = trackingView.caretRect(for: VirtualTextPosition(offset: 10))
        #expect(caretStart.minX > caretMidLine1.minX)
        
        // 3. Loupe horizontal drag across RTL text:
        // Dragging finger to the far right produces offset near 0
        let rightPos = trackingView.closestPosition(to: CGPoint(x: 290, y: 15)) as? VirtualTextPosition
        #expect(rightPos != nil)
        #expect(rightPos!.offset <= 5)
        
        // Dragging finger towards the left produces higher offset
        let leftPos = trackingView.closestPosition(to: CGPoint(x: 20, y: 15)) as? VirtualTextPosition
        #expect(leftPos != nil)
        #expect(leftPos!.offset > rightPos!.offset)
        
        // 4. Vertical loupe navigation across RTL lines
        let downPos = trackingView.position(from: startPos, in: .down, offset: 1) as? VirtualTextPosition
        #expect(downPos != nil)
        #expect(downPos!.offset >= line1.text.utf16.count)
        
        let upPos = trackingView.position(from: downPos!, in: .up, offset: 1) as? VirtualTextPosition
        #expect(upPos != nil)
        #expect(upPos!.offset <= line1.text.utf16.count)
    }
    
    @Test("iOS BiDi mixed text selectionRects assign appropriate writing directions")
    @MainActor
    func testIOSBiDiSelectionRectsAndHandleWritingDirections() {
        let manager = SelectionManager()
        let bidiElem = makeRegistration(
            text: "مرحبا Hello بالعالم",
            frame: CGRect(x: 0, y: 0, width: 300, height: 30),
            layoutDirection: .rightToLeft
        )
        manager.updateRegisteredElements([bidiElem])
        
        let trackingView = NativeSelectionTrackingUIView(frame: CGRect(x: 0, y: 0, width: 300, height: 50))
        trackingView.manager = manager
        
        let total = manager.totalLength
        let range = VirtualTextRange(range: 0..<total)
        let selRects = trackingView.selectionRects(for: range)
        
        #expect(!selRects.isEmpty)
        #expect(selRects.first?.containsStart == true)
        #expect(selRects.last?.containsEnd == true)
        
        // Base writing direction for document starting with Arabic is RTL
        #expect(selRects.first?.writingDirection == .rightToLeft)
    }
    
    #endif
}
