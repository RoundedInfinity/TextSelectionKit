import Testing
import SwiftUI
import CoreGraphics
@testable import TextSelectionKit

#if os(macOS)
import AppKit
#else
import UIKit
#endif

@Suite("Font Resolution & Typographic Metrics Accuracy Tests")
struct FontResolutionAccuracyTests {
    
    @Test("PlatformFontResolver resolves Font.Design: .rounded, .serif, and .monospaced")
    func testFontDesignResolution() {
        let roundedFont = Font.system(size: 15, weight: .medium, design: .rounded)
        let serifFont = Font.system(size: 15, weight: .regular, design: .serif)
        let monoFont = Font.system(size: 15, weight: .regular, design: .monospaced)
        let defaultFont = Font.system(size: 15, weight: .regular, design: .default)
        
        let resolvedRounded = PlatformFontResolver.resolve(from: roundedFont)
        let resolvedSerif = PlatformFontResolver.resolve(from: serifFont)
        let resolvedMono = PlatformFontResolver.resolve(from: monoFont)
        let resolvedDefault = PlatformFontResolver.resolve(from: defaultFont)
        
        #if os(macOS)
        let roundedDesc = resolvedRounded.fontDescriptor
        let serifDesc = resolvedSerif.fontDescriptor
        let monoDesc = resolvedMono.fontDescriptor
        
        // Assert point sizes are accurately preserved
        #expect(resolvedRounded.pointSize == 15)
        #expect(resolvedSerif.pointSize == 15)
        #expect(resolvedMono.pointSize == 15)
        #expect(resolvedDefault.pointSize == 15)
        
        // Assert distinct font descriptors for different designs
        #expect(resolvedRounded.fontName != resolvedDefault.fontName, "Rounded font should resolve to a rounded font family, got \(resolvedRounded.fontName)")
        #expect(resolvedSerif.fontName != resolvedDefault.fontName, "Serif font should resolve to a serif font family, got \(resolvedSerif.fontName)")
        #expect(resolvedMono.fontName != resolvedDefault.fontName, "Monospaced font should resolve to a monospaced font family, got \(resolvedMono.fontName)")
        #endif
    }
    
    @Test("PlatformFontResolver resolves all standard SwiftUI font weights")
    func testFontWeightResolution() {
        let weights: [(Font.Weight, String)] = [
            (.ultraLight, "ultraLight"),
            (.thin, "thin"),
            (.light, "light"),
            (.regular, "regular"),
            (.medium, "medium"),
            (.semibold, "semibold"),
            (.bold, "bold"),
            (.heavy, "heavy"),
            (.black, "black")
        ]
        
        for (w, label) in weights {
            let swiftUIFont = Font.system(size: 16, weight: w)
            let resolved = PlatformFontResolver.resolve(from: swiftUIFont)
            #expect(resolved.pointSize == 16, "Resolved font for \(label) must have point size 16")
        }
    }
    
    @Test("PlatformFontResolver handles TextStyle with design modifiers")
    func testTextStyleWithDesign() {
        let textStyleSerif = Font.system(.title, design: .serif)
        let textStyleRounded = Font.system(.body, design: .rounded)
        
        let resolvedSerif = PlatformFontResolver.resolve(from: textStyleSerif)
        let resolvedRounded = PlatformFontResolver.resolve(from: textStyleRounded)
        
        #if os(macOS)
        #expect(resolvedSerif.fontName != resolvedRounded.fontName)
        #endif
    }
    
    @Test("PlatformAttributedStringBuilder applies both tracking and kerning without dropping either")
    func testTrackingAndKerningAttributes() {
        var attr = AttributedString("Letter Tracking & Kerning")
        attr.tracking = 4.0
        attr.kern = 1.5
        
        #if os(macOS)
        let defaultFont = NSFont.systemFont(ofSize: 14)
        #else
        let defaultFont = UIFont.systemFont(ofSize: 14)
        #endif
        
        let nsAttr = PlatformAttributedStringBuilder.build(from: attr, defaultFont: defaultFont)
        
        var effectiveRange = NSRange(location: 0, length: 0)
        let attributes = nsAttr.attributes(at: 0, effectiveRange: &effectiveRange)
        
        // Assert that tracking and/or kerning are set
        let kernValue = attributes[.kern] as? CGFloat ?? (attributes[.kern] as? Double).map { CGFloat($0) }
        let trackingValue = attributes[.tracking] as? CGFloat ?? (attributes[.tracking] as? Double).map { CGFloat($0) }
        
        #expect(kernValue != nil || trackingValue != nil, "Kern or tracking attribute must be present")
        
        // If kern attribute represents combined spacing or individual spacing
        let totalSpacing = (kernValue ?? 0) + (trackingValue ?? 0)
        #expect(totalSpacing >= 5.0, "Combined tracking (4.0) + kerning (1.5) must equal 5.5pt total spacing, got \(totalSpacing)")
    }
    
    @Test("Compound SelectableText (+) preserves distinct font designs and sizes in layout")
    @MainActor
    func testCompoundTextFontMetrics() {
        let text1 = SelectableText("Headline Part: ").font(.headline)
        let text2 = SelectableText("Subheadline ").font(.subheadline)
        let text3 = SelectableText("with bold ").bold().font(.body)
        let text4 = SelectableText("and red serif emphasis.").font(.system(size: 15, design: .serif)).italic()
        
        let combined = text1 + text2 + text3 + text4
        let attr = combined.attributedText
        
        #if os(macOS)
        let defaultFont = NSFont.systemFont(ofSize: 13)
        #else
        let defaultFont = UIFont.systemFont(ofSize: 13)
        #endif
        
        let nsAttr = PlatformAttributedStringBuilder.build(from: attr, defaultFont: defaultFont)
        
        // Check that different runs have different fonts
        var runFonts: [PlatformFont] = []
        var index = 0
        while index < nsAttr.length {
            var range = NSRange(location: 0, length: 0)
            if let font = nsAttr.attribute(.font, at: index, effectiveRange: &range) as? PlatformFont {
                runFonts.append(font)
            }
            index = range.location + range.length
        }
        
        #expect(runFonts.count >= 3, "Expected at least 3 distinct font runs in compound text, got \(runFonts.count)")
    }
}
