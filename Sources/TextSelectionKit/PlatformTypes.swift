import SwiftUI
import CoreText
import os

#if os(macOS)
import AppKit
typealias PlatformFont = NSFont
typealias PlatformColor = NSColor

extension NSFont {
    func withTraits(_ traits: NSFontDescriptor.SymbolicTraits) -> NSFont {
        let descriptor = fontDescriptor.withSymbolicTraits(traits)
        return NSFont(descriptor: descriptor, size: pointSize) ?? self
    }
    
    var bold: NSFont {
        NSFontManager.shared.convert(self, toHaveTrait: .boldFontMask)
    }
    
    var italic: NSFont {
        NSFontManager.shared.convert(self, toHaveTrait: .italicFontMask)
    }
    
    var boldItalic: NSFont {
        let b = bold
        return NSFontManager.shared.convert(b, toHaveTrait: .italicFontMask)
    }
    
    var monospaced: NSFont {
        NSFont.monospacedSystemFont(ofSize: pointSize, weight: .regular)
    }
}

#elseif os(iOS) || os(visionOS) || os(tvOS)
import UIKit
typealias PlatformFont = UIFont
typealias PlatformColor = UIColor

extension UIFont {
    func withTraits(_ traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        guard let descriptor = fontDescriptor.withSymbolicTraits(traits) else { return self }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
    
    var bold: UIFont {
        if let descriptor = fontDescriptor.withSymbolicTraits(.traitBold) {
            return UIFont(descriptor: descriptor, size: pointSize)
        }
        return UIFont.systemFont(ofSize: pointSize, weight: .bold)
    }
    
    var italic: UIFont {
        if let descriptor = fontDescriptor.withSymbolicTraits(.traitItalic) {
            return UIFont(descriptor: descriptor, size: pointSize)
        }
        return UIFont.italicSystemFont(ofSize: pointSize)
    }
    
    var boldItalic: UIFont {
        var traits = fontDescriptor.symbolicTraits
        traits.insert([.traitBold, .traitItalic])
        if let descriptor = fontDescriptor.withSymbolicTraits(traits) {
            return UIFont(descriptor: descriptor, size: pointSize)
        }
        return bold
    }
    
    var monospaced: UIFont {
        UIFont.monospacedSystemFont(ofSize: pointSize, weight: .regular)
    }
}
#endif

// MARK: - AttributedString to Platform NSAttributedString Converter (Without Mirror)

enum PlatformAttributedStringBuilder {
    static func build(from attributedString: AttributedString, defaultFont: PlatformFont, dynamicTypeSize: DynamicTypeSize? = nil) -> NSAttributedString {
        let rawText = String(attributedString.characters)
        let totalUtf16Count = rawText.utf16.count
        guard totalUtf16Count > 0 else {
            return NSAttributedString(string: "")
        }
        
        let mutable = NSMutableAttributedString(string: rawText)
        mutable.addAttribute(.font, value: defaultFont, range: NSRange(location: 0, length: totalUtf16Count))
        
        for run in attributedString.runs {
            let nsRange = NSRange(run.range, in: attributedString)
            guard nsRange.location != NSNotFound && nsRange.length > 0 && nsRange.location + nsRange.length <= totalUtf16Count else { continue }
            
            var font = defaultFont
            if let swiftUIFont = run.font {
                font = PlatformFontResolver.resolve(from: swiftUIFont, dynamicTypeSize: dynamicTypeSize)
            }
            #if os(macOS)
            if let nsFont = run.appKit.font {
                font = nsFont
            }
            #elseif os(iOS) || os(visionOS) || os(tvOS)
            if let uiFont = run.uiKit.font {
                font = uiFont
            }
            #endif
            
            // Check markdown presentation intents
            if let intent = run.inlinePresentationIntent {
                let isBold = intent.contains(.stronglyEmphasized)
                let isItalic = intent.contains(.emphasized)
                let isCode = intent.contains(.code)
                let isStrikethrough = intent.contains(.strikethrough)
                
                if isCode {
                    font = font.monospaced
                }
                if isBold && isItalic {
                    font = font.boldItalic
                } else if isBold {
                    font = font.bold
                } else if isItalic {
                    font = font.italic
                }
                if isStrikethrough {
                    mutable.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: nsRange)
                }
            }
            
            mutable.addAttribute(.font, value: font, range: nsRange)
            
            if let color = run.foregroundColor {
                #if os(macOS)
                mutable.addAttribute(.foregroundColor, value: NSColor(color), range: nsRange)
                #elseif os(iOS) || os(visionOS) || os(tvOS)
                mutable.addAttribute(.foregroundColor, value: UIColor(color), range: nsRange)
                #endif
            }
            
            if run.underlineStyle != nil {
                mutable.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: nsRange)
            }
            
            if run.strikethroughStyle != nil {
                mutable.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: nsRange)
            }
            
            if let tracking = run.tracking, let kern = run.kern {
                mutable.addAttribute(.tracking, value: tracking, range: nsRange)
                mutable.addAttribute(.kern, value: kern, range: nsRange)
            } else if let tracking = run.tracking {
                mutable.addAttribute(.tracking, value: tracking, range: nsRange)
            } else if let kern = run.kern {
                mutable.addAttribute(.kern, value: kern, range: nsRange)
            }
            
            if let baselineOffset = run.baselineOffset {
                mutable.addAttribute(.baselineOffset, value: baselineOffset, range: nsRange)
            }
        }
        
        return mutable
    }
}

// MARK: - Thread-Safe LRU Font Cache & Platform Font Resolver

struct FontCacheKey: Hashable, Sendable {
    let font: Font?
    let dynamicTypeSize: DynamicTypeSize?
}

private struct PlatformFontBox: @unchecked Sendable {
    let font: PlatformFont
}

private final class BoundedFontCache: @unchecked Sendable {
    private struct State: Sendable {
        var dict: [FontCacheKey: PlatformFontBox] = [:]
        var keys: [FontCacheKey] = []
    }
    
    private let lock = OSAllocatedUnfairLock(initialState: State())
    private let capacity: Int
    
    init(capacity: Int = 256) {
        self.capacity = capacity
    }
    
    func get(_ key: FontCacheKey) -> PlatformFont? {
        let box = lock.withLock { state in
            state.dict[key]
        }
        return box?.font
    }
    
    func set(_ key: FontCacheKey, font: PlatformFont) {
        let box = PlatformFontBox(font: font)
        lock.withLock { state in
            if state.dict[key] == nil {
                if state.keys.count >= capacity {
                    let oldest = state.keys.removeFirst()
                    state.dict.removeValue(forKey: oldest)
                }
                state.keys.append(key)
            }
            state.dict[key] = box
        }
    }
}

enum PlatformFontResolver {
    private static let cache = BoundedFontCache(capacity: 256)
    
    static func resolve(from font: Font?, dynamicTypeSize: DynamicTypeSize? = nil) -> PlatformFont {
        let key = FontCacheKey(font: font, dynamicTypeSize: dynamicTypeSize)
        
        if let cached = cache.get(key) {
            return cached
        }
        
        let resolved = resolveInternal(from: font, dynamicTypeSize: dynamicTypeSize)
        cache.set(key, font: resolved)
        return resolved
    }
    
    #if os(iOS) || os(visionOS) || os(tvOS)
    private static func traitCollection(from dynamicTypeSize: DynamicTypeSize?) -> UITraitCollection? {
        guard let dynamicTypeSize = dynamicTypeSize else { return nil }
        let category: UIContentSizeCategory
        switch dynamicTypeSize {
        case .xSmall: category = .extraSmall
        case .small: category = .small
        case .medium: category = .medium
        case .large: category = .large
        case .xLarge: category = .extraLarge
        case .xxLarge: category = .extraExtraLarge
        case .xxxLarge: category = .extraExtraExtraLarge
        case .accessibility1: category = .accessibilityMedium
        case .accessibility2: category = .accessibilityLarge
        case .accessibility3: category = .accessibilityExtraLarge
        case .accessibility4: category = .accessibilityExtraExtraLarge
        case .accessibility5: category = .accessibilityExtraExtraExtraLarge
        @unknown default: category = .large
        }
        return UITraitCollection(preferredContentSizeCategory: category)
    }
    #endif
    
    private static func resolveInternal(from font: Font?, dynamicTypeSize: DynamicTypeSize?) -> PlatformFont {
        #if os(macOS)
        guard let font = font else {
            return NSFont.systemFont(ofSize: NSFont.systemFontSize)
        }
        #else
        let traitCollection = traitCollection(from: dynamicTypeSize)
        guard let font = font else {
            if let traitCollection {
                return UIFont.preferredFont(forTextStyle: .body, compatibleWith: traitCollection)
            }
            return UIFont.preferredFont(forTextStyle: .body)
        }
        #endif
        
        var size: CGFloat?
        var textStyle: String?
        var weightVal: CGFloat?
        var fontDesign: Font.Design?
        var isBold = false
        var isItalic = false
        var isMonospaced = false
        var name: String?

        func extractWeight(from value: Any) -> CGFloat? {
            if let v = value as? CGFloat { return v }
            if let v = value as? Double { return CGFloat(v) }
            let m = Mirror(reflecting: value)
            for c in m.children {
                if c.label == "value" {
                    if let v = c.value as? CGFloat { return v }
                    if let v = c.value as? Double { return CGFloat(v) }
                }
                if let nested = extractWeight(from: c.value) {
                    return nested
                }
            }
            return nil
        }

        func traverse(_ value: Any) {
            let mirror = Mirror(reflecting: value)
            let typeName = "\(mirror.subjectType)"
            
            if typeName.contains("BoldModifier") { isBold = true }
            if typeName.contains("ItalicModifier") { isItalic = true }
            if typeName.contains("Monospaced") || typeName.contains("monospaced") {
                isMonospaced = true
                fontDesign = .monospaced
            }
            if typeName.contains("Rounded") || typeName.contains("rounded") {
                fontDesign = .rounded
            }
            if typeName.contains("Serif") || typeName.contains("serif") {
                fontDesign = .serif
            }
            
            for child in mirror.children {
                guard let label = child.label else {
                    traverse(child.value)
                    continue
                }
                
                switch label {
                case "size":
                    if let s = child.value as? CGFloat { size = s }
                    else if let s = child.value as? Double { size = CGFloat(s) }
                    else if let s = child.value as? Int { size = CGFloat(s) }
                case "style", "textStyle":
                    let str = "\(child.value)"
                    if !str.contains("nil") {
                        textStyle = str.replacing("Optional(", with: "").replacing(")", with: "").trimmingCharacters(in: .whitespaces)
                    }
                case "name":
                    let str = "\(child.value)"
                    if !str.contains("nil") {
                        name = str.replacing("Optional(\"", with: "").replacing("\")", with: "")
                    }
                case "weight":
                    if let w = extractWeight(from: child.value) {
                        weightVal = w
                    }
                case "value":
                    if typeName.contains("Weight") {
                        if let v = child.value as? CGFloat { weightVal = v }
                        else if let v = child.value as? Double { weightVal = CGFloat(v) }
                    }
                case "design":
                    let str = "\(child.value)"
                    if str.contains("monospaced") {
                        isMonospaced = true
                        fontDesign = .monospaced
                    } else if str.contains("rounded") {
                        fontDesign = .rounded
                    } else if str.contains("serif") {
                        fontDesign = .serif
                    } else if str.contains("default") {
                        fontDesign = .default
                    }
                default:
                    break
                }
                
                traverse(child.value)
            }
        }
        
        traverse(font)
        
        #if os(macOS)
        func applyDesign(_ design: Font.Design?, to font: NSFont) -> NSFont {
            guard let design = design else { return font }
            let systemDesign: NSFontDescriptor.SystemDesign
            switch design {
            case .serif: systemDesign = .serif
            case .rounded: systemDesign = .rounded
            case .monospaced: systemDesign = .monospaced
            default: systemDesign = .default
            }
            if let descriptor = font.fontDescriptor.withDesign(systemDesign) {
                return NSFont(descriptor: descriptor, size: font.pointSize) ?? font
            }
            return font
        }

        var baseFont: NSFont
        if let name = name, let size = size {
            baseFont = NSFont(name: name, size: size) ?? NSFont.systemFont(ofSize: size)
        } else if let size = size {
            let weight = weightVal.map { NSFont.Weight(rawValue: $0) } ?? (isBold ? .bold : .regular)
            if isMonospaced || fontDesign == .monospaced {
                baseFont = NSFont.monospacedSystemFont(ofSize: size, weight: weight)
            } else {
                baseFont = NSFont.systemFont(ofSize: size, weight: weight)
            }
            if let fontDesign = fontDesign, fontDesign != .default, fontDesign != .monospaced {
                baseFont = applyDesign(fontDesign, to: baseFont)
            }
        } else if let textStyle = textStyle {
            let nsStyle: NSFont.TextStyle
            switch textStyle {
            case "largeTitle": nsStyle = .largeTitle
            case "title", "title1": nsStyle = .title1
            case "title2": nsStyle = .title2
            case "title3": nsStyle = .title3
            case "headline": nsStyle = .headline
            case "subheadline": nsStyle = .subheadline
            case "body": nsStyle = .body
            case "callout": nsStyle = .callout
            case "footnote": nsStyle = .footnote
            case "caption", "caption1": nsStyle = .caption1
            case "caption2": nsStyle = .caption2
            default: nsStyle = .body
            }
            let unscaled = NSFont.preferredFont(forTextStyle: nsStyle)
            if let weightVal {
                let descriptor = unscaled.fontDescriptor.addingAttributes([
                    .traits: [NSFontDescriptor.TraitKey.weight: weightVal]
                ])
                baseFont = NSFont(descriptor: descriptor, size: unscaled.pointSize) ?? unscaled
            } else if isBold {
                baseFont = unscaled.bold
            } else {
                baseFont = unscaled
            }
            if isMonospaced || fontDesign == .monospaced {
                baseFont = baseFont.monospaced
            } else if let fontDesign = fontDesign, fontDesign != .default {
                baseFont = applyDesign(fontDesign, to: baseFont)
            }
        } else {
            let defaultFont = NSFont.preferredFont(forTextStyle: .body)
            if let weightVal {
                let descriptor = defaultFont.fontDescriptor.addingAttributes([
                    .traits: [NSFontDescriptor.TraitKey.weight: weightVal]
                ])
                baseFont = NSFont(descriptor: descriptor, size: defaultFont.pointSize) ?? defaultFont
            } else if isBold {
                baseFont = defaultFont.bold
            } else {
                baseFont = defaultFont
            }
            if isMonospaced || fontDesign == .monospaced {
                baseFont = baseFont.monospaced
            } else if let fontDesign = fontDesign, fontDesign != .default {
                baseFont = applyDesign(fontDesign, to: baseFont)
            }
        }
        
        if isItalic {
            return baseFont.italic
        }
        return baseFont
        
        #elseif os(iOS) || os(visionOS) || os(tvOS)
        func applyDesign(_ design: Font.Design?, to font: UIFont) -> UIFont {
            guard let design = design else { return font }
            let systemDesign: UIFontDescriptor.SystemDesign
            switch design {
            case .serif: systemDesign = .serif
            case .rounded: systemDesign = .rounded
            case .monospaced: systemDesign = .monospaced
            default: systemDesign = .default
            }
            if let descriptor = font.fontDescriptor.withDesign(systemDesign) {
                return UIFont(descriptor: descriptor, size: font.pointSize)
            }
            return font
        }

        var baseFont: UIFont
        if let name = name, let size = size {
            let unscaled = UIFont(name: name, size: size) ?? UIFont.systemFont(ofSize: size)
            if let traitCollection {
                baseFont = UIFontMetrics(forTextStyle: .body).scaledFont(for: unscaled, compatibleWith: traitCollection)
            } else {
                baseFont = unscaled
            }
        } else if let size = size {
            let weight = weightVal.map { UIFont.Weight(rawValue: $0) } ?? (isBold ? .bold : .regular)
            let unscaled: UIFont
            if isMonospaced || fontDesign == .monospaced {
                unscaled = UIFont.monospacedSystemFont(ofSize: size, weight: weight)
            } else {
                unscaled = UIFont.systemFont(ofSize: size, weight: weight)
            }
            let designed = applyDesign(fontDesign, to: unscaled)
            if let traitCollection {
                baseFont = UIFontMetrics(forTextStyle: .body).scaledFont(for: designed, compatibleWith: traitCollection)
            } else {
                baseFont = designed
            }
        } else if let textStyle = textStyle {
            let uiStyle: UIFont.TextStyle
            switch textStyle {
            case "largeTitle": uiStyle = .largeTitle
            case "title", "title1": uiStyle = .title1
            case "title2": uiStyle = .title2
            case "title3": uiStyle = .title3
            case "headline": uiStyle = .headline
            case "subheadline": uiStyle = .subheadline
            case "callout": uiStyle = .callout
            case "footnote": uiStyle = .footnote
            case "caption", "caption1": uiStyle = .caption1
            case "caption2": uiStyle = .caption2
            default: uiStyle = .body
            }
            let prefFont: UIFont
            if let traitCollection {
                prefFont = UIFont.preferredFont(forTextStyle: uiStyle, compatibleWith: traitCollection)
            } else {
                prefFont = UIFont.preferredFont(forTextStyle: uiStyle)
            }
            if let weightVal = weightVal {
                baseFont = UIFont.systemFont(ofSize: prefFont.pointSize, weight: UIFont.Weight(rawValue: weightVal))
            } else if isBold {
                baseFont = prefFont.bold
            } else if isMonospaced || fontDesign == .monospaced {
                baseFont = UIFont.monospacedSystemFont(ofSize: prefFont.pointSize, weight: .regular)
            } else {
                baseFont = prefFont
            }
            if let fontDesign = fontDesign, fontDesign != .default, fontDesign != .monospaced {
                baseFont = applyDesign(fontDesign, to: baseFont)
            }
        } else {
            let defaultSize: CGFloat
            if let traitCollection {
                defaultSize = UIFont.preferredFont(forTextStyle: .body, compatibleWith: traitCollection).pointSize
            } else {
                defaultSize = UIFont.labelFontSize
            }
            let weight = weightVal.map { UIFont.Weight(rawValue: $0) } ?? (isBold ? .bold : .regular)
            let standard = UIFont.systemFont(ofSize: defaultSize, weight: weight)
            baseFont = applyDesign(fontDesign, to: standard)
        }
        
        if isItalic {
            return baseFont.italic
        }
        return baseFont
        #endif
    }
}
