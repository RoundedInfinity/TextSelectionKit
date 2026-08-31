import Testing
import SwiftUI
import CoreGraphics
@testable import TextSelectionKit

#if os(macOS)
import AppKit
#else
import UIKit
#endif

@Suite("Paragraph Style & CoreText Layout Tests")
struct ParagraphStyleLayoutTests {
    
    private func makeFont() -> PlatformFont {
        #if os(macOS)
        return NSFont.systemFont(ofSize: 14)
        #else
        return UIFont.systemFont(ofSize: 14)
        #endif
    }
    
    @Test("CachedElementLayout creates lines with custom line spacing")
    func testLineSpacingIncreasesLineDistance() {
        let font = makeFont()
        let text = "Line 1 with enough words to wrap into multiple lines across the container width.\nLine 2 is here as well."
        
        let elemNoSpacing = TextElementRegistration(
            id: "no_spacing",
            text: text,
            frame: CGRect(x: 0, y: 0, width: 150, height: 100),
            font: font,
            alignment: .leading,
            lineSpacing: 0
        )
        
        let elemWithSpacing = TextElementRegistration(
            id: "with_spacing",
            text: text,
            frame: CGRect(x: 0, y: 0, width: 150, height: 100),
            font: font,
            alignment: .leading,
            lineSpacing: 20
        )
        
        let layoutNoSpacing = CachedElementLayout(element: elemNoSpacing)
        let layoutWithSpacing = CachedElementLayout(element: elemWithSpacing)
        
        #expect(layoutNoSpacing != nil)
        #expect(layoutWithSpacing != nil)
        
        guard let l1 = layoutNoSpacing, let l2 = layoutWithSpacing, l1.lines.count >= 2, l2.lines.count >= 2 else {
            Issue.record("Expected multiple lines for wrapped text")
            return
        }
        
        let distanceNoSpacing = abs(l1.lines[1].origin.y - l1.lines[0].origin.y)
        let distanceWithSpacing = abs(l2.lines[1].origin.y - l2.lines[0].origin.y)
        
        #expect(distanceWithSpacing > distanceNoSpacing, "Line spacing of 20pt must produce greater vertical distance between line origins than 0pt")
    }
    
    @Test("CachedElementLayout respects leading, center, and trailing alignments")
    func testTextAlignmentLayout() {
        let font = makeFont()
        let text = "Short Line"
        
        let leadingElem = TextElementRegistration(
            id: "lead",
            text: text,
            frame: CGRect(x: 0, y: 0, width: 300, height: 30),
            font: font,
            alignment: .leading
        )
        
        let centerElem = TextElementRegistration(
            id: "center",
            text: text,
            frame: CGRect(x: 0, y: 0, width: 300, height: 30),
            font: font,
            alignment: .center
        )
        
        let trailingElem = TextElementRegistration(
            id: "trail",
            text: text,
            frame: CGRect(x: 0, y: 0, width: 300, height: 30),
            font: font,
            alignment: .trailing
        )
        
        let leadingLayout = CachedElementLayout(element: leadingElem)!
        let centerLayout = CachedElementLayout(element: centerElem)!
        let trailingLayout = CachedElementLayout(element: trailingElem)!
        
        #expect(leadingLayout.lines.count == 1)
        #expect(centerLayout.lines.count == 1)
        #expect(trailingLayout.lines.count == 1)
        
        let leadX = leadingLayout.lines[0].origin.x
        let centerX = centerLayout.lines[0].origin.x
        let trailX = trailingLayout.lines[0].origin.x
        
        #expect(leadX < centerX, "Leading line origin (\(leadX)) must be to the left of Center line origin (\(centerX))")
        #expect(centerX < trailX, "Center line origin (\(centerX)) must be to the left of Trailing line origin (\(trailX))")
    }
    
    @Test("RTL layout direction mirrors leading and trailing alignment")
    func testRTLLayoutDirectionAlignment() {
        let font = makeFont()
        let text = "Short Line"
        
        let leadingRTLElem = TextElementRegistration(
            id: "lead_rtl",
            text: text,
            frame: CGRect(x: 0, y: 0, width: 300, height: 30),
            font: font,
            alignment: .leading,
            layoutDirection: .rightToLeft
        )
        
        let trailingRTLElem = TextElementRegistration(
            id: "trail_rtl",
            text: text,
            frame: CGRect(x: 0, y: 0, width: 300, height: 30),
            font: font,
            alignment: .trailing,
            layoutDirection: .rightToLeft
        )
        
        let leadRTLLayout = CachedElementLayout(element: leadingRTLElem)!
        let trailRTLLayout = CachedElementLayout(element: trailingRTLElem)!
        
        let leadRTLX = leadRTLLayout.lines[0].origin.x
        let trailRTLX = trailRTLLayout.lines[0].origin.x
        
        #expect(leadRTLX > trailRTLX, "In RTL, leading alignment should position text to the right of trailing alignment")
    }
}
