import Testing
import SwiftUI
@testable import TextSelectionKit

#if os(macOS)
import AppKit
#else
import UIKit
#endif

@Suite("Platform Bridge & Font Resolver Tests")
struct PlatformBridgeTests {
    
    @Test("Font resolver resolves default body font when font is nil")
    func testDefaultFontResolution() {
        let font = PlatformFontResolver.resolve(from: nil)
        #expect(font.pointSize > 0)
    }
    
    @Test("Font resolver caches resolved fonts with dynamic type size keys")
    func testFontCaching() {
        let swiftUIFont = Font.title
        let font1 = PlatformFontResolver.resolve(from: swiftUIFont, dynamicTypeSize: .medium)
        let font2 = PlatformFontResolver.resolve(from: swiftUIFont, dynamicTypeSize: .medium)
        
        #expect(font1.pointSize == font2.pointSize)
    }
    
    @Test("PlatformAttributedStringBuilder converts AttributedString to NSAttributedString")
    func testPlatformAttributedStringBuilder() {
        var attr = AttributedString("Rich Text Test")
        attr.font = .system(size: 16, weight: .bold)
        attr.foregroundColor = .blue
        attr.underlineStyle = .single
        attr.strikethroughStyle = .single
        
        #if os(macOS)
        let defaultFont = NSFont.systemFont(ofSize: 14)
        #else
        let defaultFont = UIFont.systemFont(ofSize: 14)
        #endif
        
        let nsAttr = PlatformAttributedStringBuilder.build(from: attr, defaultFont: defaultFont)
        #expect(nsAttr.string == "Rich Text Test")
        #expect(nsAttr.length == "Rich Text Test".utf16.count)
    }
    
    #if os(macOS)
    @Test("macOS selection highlight uses full opacity system colors")
    @MainActor
    func testMacOSSelectionHighlightColors() {
        let highlightView = MacOSSelectionHighlightView()
        
        let keyColor = highlightView.highlightColor(isKey: true)
        #expect(keyColor == NSColor.selectedTextBackgroundColor)
        #expect(keyColor.alphaComponent == 1.0)
        
        let nonKeyColor = highlightView.highlightColor(isKey: false)
        #expect(nonKeyColor == NSColor.unemphasizedSelectedTextBackgroundColor)
        #expect(nonKeyColor.alphaComponent == 1.0)
    }
    
    @Test("macOS selection highlight view marks needsDisplay on selection changes")
    @MainActor
    func testMacOSSelectionHighlightViewNeedsDisplayOnSelectionChange() {
        let manager = SelectionManager()
        let highlightView = MacOSSelectionHighlightView()
        highlightView.manager = manager
        
        var displayCallbackCount = 0
        highlightView.onNeedsDisplay = {
            displayCallbackCount += 1
        }
        
        let font = NSFont.systemFont(ofSize: 14)
        let elem = TextElementRegistration(
            id: UUID(),
            text: "macOS Highlight Test",
            frame: CGRect(x: 0, y: 0, width: 200, height: 20),
            font: font,
            orderIndex: 0
        )
        manager.updateRegisteredElements([elem])
        
        manager.select(0..<5)
        #expect(displayCallbackCount == 1)
        
        manager.deselectAll()
        #expect(displayCallbackCount == 2)
    }
    #endif
    
    #if os(iOS) || os(visionOS) || os(tvOS)
    @Test("Dynamic Type scaling on iOS scales text styles proportionally")
    func testDynamicTypeScaling() {
        let bodyFontSmall = PlatformFontResolver.resolve(from: .body, dynamicTypeSize: .xSmall)
        let bodyFontLarge = PlatformFontResolver.resolve(from: .body, dynamicTypeSize: .large)
        let bodyFontAX = PlatformFontResolver.resolve(from: .body, dynamicTypeSize: .accessibility3)
        
        #expect(bodyFontSmall.pointSize < bodyFontLarge.pointSize)
        #expect(bodyFontLarge.pointSize < bodyFontAX.pointSize)
    }
    
    @Test("Dynamic Type scaling on iOS scales custom system fonts")
    func testCustomFontDynamicTypeScaling() {
        let customFontSmall = PlatformFontResolver.resolve(from: .system(size: 16), dynamicTypeSize: .xSmall)
        let customFontLarge = PlatformFontResolver.resolve(from: .system(size: 16), dynamicTypeSize: .large)
        let customFontAX = PlatformFontResolver.resolve(from: .system(size: 16), dynamicTypeSize: .accessibility3)
        
        #expect(customFontSmall.pointSize < customFontLarge.pointSize)
        #expect(customFontLarge.pointSize < customFontAX.pointSize)
    }
    #endif
}
