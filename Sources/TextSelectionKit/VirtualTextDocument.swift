import SwiftUI
import CoreText

#if os(iOS) || os(visionOS) || os(tvOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - Text Element Registration

struct TextElementRegistration: Identifiable, Equatable, @unchecked Sendable {
    let id: AnyHashable
    var text: String
    var attributedString: AttributedString?
    var frame: CGRect // in SelectionContainer coordinate space
    var font: PlatformFont
    var orderIndex: Int
    var delimiter: String
    var alignment: TextAlignment
    var lineSpacing: CGFloat
    var lineLimit: Int?
    var truncationMode: Text.TruncationMode
    var layoutDirection: LayoutDirection
    
    init(
        id: AnyHashable,
        text: String,
        attributedString: AttributedString? = nil,
        frame: CGRect,
        font: PlatformFont,
        orderIndex: Int,
        delimiter: String = "\n",
        alignment: TextAlignment = .leading,
        lineSpacing: CGFloat = 0,
        lineLimit: Int? = nil,
        truncationMode: Text.TruncationMode = .tail,
        layoutDirection: LayoutDirection = .leftToRight
    ) {
        self.id = id
        self.text = text
        self.attributedString = attributedString
        self.frame = frame
        self.font = font
        self.orderIndex = orderIndex
        self.delimiter = delimiter
        self.alignment = alignment
        self.lineSpacing = lineSpacing
        self.lineLimit = lineLimit
        self.truncationMode = truncationMode
        self.layoutDirection = layoutDirection
    }
}

// MARK: - Virtual Text Positions & Ranges (Cross-Platform / UIKit / AppKit)

#if os(iOS) || os(visionOS) || os(tvOS)
final class VirtualTextPosition: UITextPosition, Comparable {
    let offset: Int
    
    init(offset: Int) {
        self.offset = offset
        super.init()
    }
    
    static func < (lhs: VirtualTextPosition, rhs: VirtualTextPosition) -> Bool {
        lhs.offset < rhs.offset
    }
    
    static func == (lhs: VirtualTextPosition, rhs: VirtualTextPosition) -> Bool {
        lhs.offset == rhs.offset
    }
}

final class VirtualTextRange: UITextRange {
    let range: Range<Int>
    
    init(range: Range<Int>) {
        self.range = range
        super.init()
    }
    
    override var start: UITextPosition {
        VirtualTextPosition(offset: range.lowerBound)
    }
    
    override var end: UITextPosition {
        VirtualTextPosition(offset: range.upperBound)
    }
    
    override var isEmpty: Bool {
        range.isEmpty
    }
}
#endif

// MARK: - Virtual Element Slice

struct VirtualElementSlice {
    let element: TextElementRegistration
    let globalRange: Range<Int>
}

// MARK: - Line Layout & Cached CoreText Layout

struct LineLayout {
    let line: CTLine
    let origin: CGPoint
    let range: CFRange
    let ascent: CGFloat
    let descent: CGFloat
    let leading: CGFloat
    let top: CGFloat
    let bottom: CGFloat
    
    var height: CGFloat { bottom - top }
    var centerY: CGFloat { (top + bottom) / 2 }
}

final class CachedElementLayout {
    let elementId: AnyHashable
    let text: String
    let attributedString: AttributedString?
    let font: PlatformFont
    let frameWidth: CGFloat
    let frameHeight: CGFloat
    let alignment: TextAlignment
    let lineSpacing: CGFloat
    let lineLimit: Int?
    let truncationMode: Text.TruncationMode
    let layoutDirection: LayoutDirection
    let lines: [LineLayout]
    
    init?(element: TextElementRegistration) {
        let text = element.text
        guard !text.isEmpty else { return nil }
        
        self.elementId = element.id
        self.text = text
        self.attributedString = element.attributedString
        self.font = element.font
        self.frameWidth = element.frame.width
        self.frameHeight = element.frame.height
        self.alignment = element.alignment
        self.lineSpacing = element.lineSpacing
        self.lineLimit = element.lineLimit
        self.truncationMode = element.truncationMode
        self.layoutDirection = element.layoutDirection
        
        let baseAttrString: NSAttributedString
        if let swiftUIAttributedString = element.attributedString {
            baseAttrString = PlatformAttributedStringBuilder.build(from: swiftUIAttributedString, defaultFont: element.font)
        } else {
            baseAttrString = NSAttributedString(string: text, attributes: [.font: element.font])
        }
        
        let mutableAttrString = NSMutableAttributedString(attributedString: baseAttrString)
        
        var ctAlignment: CTTextAlignment
        switch element.alignment {
        case .leading:
            ctAlignment = (element.layoutDirection == .rightToLeft) ? .right : .left
        case .center:
            ctAlignment = .center
        case .trailing:
            ctAlignment = (element.layoutDirection == .rightToLeft) ? .left : .right
        }
        
        var baseWritingDir: CTWritingDirection = (element.layoutDirection == .rightToLeft) ? .rightToLeft : .natural
        var spacing = CGFloat(element.lineSpacing)
        var lineBreakMode = CTLineBreakMode.byWordWrapping
        let paragraphStyle: CTParagraphStyle = withUnsafePointer(to: &ctAlignment) { alignPtr in
            withUnsafePointer(to: &spacing) { spacingPtr in
                withUnsafePointer(to: &lineBreakMode) { breakPtr in
                    withUnsafePointer(to: &baseWritingDir) { dirPtr in
                        let settings: [CTParagraphStyleSetting] = [
                            CTParagraphStyleSetting(spec: .alignment, valueSize: MemoryLayout<CTTextAlignment>.size, value: alignPtr),
                            CTParagraphStyleSetting(spec: .lineSpacingAdjustment, valueSize: MemoryLayout<CGFloat>.size, value: spacingPtr),
                            CTParagraphStyleSetting(spec: .lineBreakMode, valueSize: MemoryLayout<CTLineBreakMode>.size, value: breakPtr),
                            CTParagraphStyleSetting(spec: .baseWritingDirection, valueSize: MemoryLayout<CTWritingDirection>.size, value: dirPtr)
                        ]
                        return CTParagraphStyleCreate(settings, settings.count)
                    }
                }
            }
        }
        mutableAttrString.addAttribute(
            NSAttributedString.Key(kCTParagraphStyleAttributeName as String),
            value: paragraphStyle,
            range: NSRange(location: 0, length: mutableAttrString.length)
        )
        
        let framesetter = CTFramesetterCreateWithAttributedString(mutableAttrString as CFAttributedString)
        let width = max(10, element.frame.width)
        let path = CGPath(rect: CGRect(x: 0, y: 0, width: width, height: max(element.frame.height * 2, 10000)), transform: nil)
        let ctFrame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, nil)
        
        guard let allLines = CTFrameGetLines(ctFrame) as? [CTLine], !allLines.isEmpty else {
            return nil
        }
        
        var rawLines: [CTLine]
        if let limit = element.lineLimit, limit > 0 {
            rawLines = Array(allLines.prefix(limit))
        } else {
            rawLines = allLines
        }
        
        // Apply line truncation token on the last line if lines exceeded lineLimit
        var ctLines = rawLines
        if (element.lineLimit != nil && allLines.count > rawLines.count) || (element.lineLimit == 1) {
            if let lastIndex = ctLines.indices.last {
                let lastLine = ctLines[lastIndex]
                let lineWidth = CTLineGetTypographicBounds(lastLine, nil, nil, nil)
                if lineWidth > Double(width) {
                    let truncationType: CTLineTruncationType
                    switch element.truncationMode {
                    case .head:
                        truncationType = .start
                    case .middle:
                        truncationType = .middle
                    case .tail:
                        fallthrough
                    @unknown default:
                        truncationType = .end
                    }
                    let ellipsisAttr = NSAttributedString(string: "\u{2026}", attributes: [.font: element.font])
                    let token = CTLineCreateWithAttributedString(ellipsisAttr as CFAttributedString)
                    if let truncated = CTLineCreateTruncatedLine(lastLine, Double(width), truncationType, token) {
                        ctLines[lastIndex] = truncated
                    }
                }
            }
        }
        
        var origins = [CGPoint](repeating: .zero, count: ctLines.count)
        CTFrameGetLineOrigins(ctFrame, CFRangeMake(0, ctLines.count), &origins)
        
        let lineCount = ctLines.count
        let linePitch: CGFloat
        if element.frame.height > 0 && lineCount > 0 {
            linePitch = element.frame.height / CGFloat(lineCount)
        } else {
            #if os(macOS)
            let defaultH = NSLayoutManager().defaultLineHeight(for: element.font)
            linePitch = defaultH + CGFloat(element.lineSpacing)
            #else
            linePitch = element.font.lineHeight + CGFloat(element.lineSpacing)
            #endif
        }
        
        var lineLayouts: [LineLayout] = []
        lineLayouts.reserveCapacity(lineCount)
        
        for (i, line) in ctLines.enumerated() {
            var asc: CGFloat = 0, desc: CGFloat = 0, lead: CGFloat = 0
            CTLineGetTypographicBounds(line, &asc, &desc, &lead)
            let range = CTLineGetStringRange(line)
            let lineTop = CGFloat(i) * linePitch
            let lineBottom = lineTop + linePitch
            
            lineLayouts.append(LineLayout(
                line: line,
                origin: origins[i],
                range: range,
                ascent: asc,
                descent: desc,
                leading: lead,
                top: lineTop,
                bottom: lineBottom
            ))
        }
        
        self.lines = lineLayouts
    }
    
    func isValid(for element: TextElementRegistration) -> Bool {
        elementId == element.id &&
        text == element.text &&
        attributedString == element.attributedString &&
        font == element.font &&
        alignment == element.alignment &&
        lineSpacing == element.lineSpacing &&
        lineLimit == element.lineLimit &&
        truncationMode == element.truncationMode &&
        layoutDirection == element.layoutDirection &&
        abs(frameWidth - element.frame.width) < 0.5 &&
        abs(frameHeight - element.frame.height) < 0.5
    }
}

// MARK: - Virtual Text Document

struct VirtualTextDocument {
    private(set) var elements: [TextElementRegistration] = []
    private(set) var slices: [VirtualElementSlice] = []
    private(set) var totalLength: Int = 0
    private(set) var fullText: String = ""
    
    private var layoutCache: [AnyHashable: CachedElementLayout] = [:]
    
    init(elements: [TextElementRegistration] = []) {
        self.update(elements: elements)
    }
    
    mutating func update(elements: [TextElementRegistration]) {
        if self.elements == elements && !self.slices.isEmpty {
            return
        }
        
        self.elements = elements.sorted {
            if $0.orderIndex != $1.orderIndex {
                return $0.orderIndex < $1.orderIndex
            }
            if abs($0.frame.minY - $1.frame.minY) > 2 {
                return $0.frame.minY < $1.frame.minY
            }
            return $0.frame.minX < $1.frame.minX
        }
        
        var currentOffset = 0
        var newSlices: [VirtualElementSlice] = []
        var fullTextBuilder = ""
        
        newSlices.reserveCapacity(self.elements.count)
        
        let currentIDs = Set(self.elements.map(\.id))
        self.layoutCache = self.layoutCache.filter { currentIDs.contains($0.key) }
        
        for (index, elem) in self.elements.enumerated() {
            let length = elem.text.utf16.count
            let start = currentOffset
            let end = start + length
            let globalRange = start..<end
            
            newSlices.append(VirtualElementSlice(element: elem, globalRange: globalRange))
            fullTextBuilder.append(elem.text)
            
            if let existing = layoutCache[elem.id], existing.isValid(for: elem) {
                // Retain cached layout
            } else if let newLayout = CachedElementLayout(element: elem) {
                self.layoutCache[elem.id] = newLayout
            }
            
            currentOffset = end
            if index < self.elements.count - 1 {
                let delim = elem.delimiter
                fullTextBuilder.append(delim)
                currentOffset += delim.utf16.count
            }
        }
        
        self.slices = newSlices
        self.totalLength = currentOffset
        self.fullText = fullTextBuilder
    }
    
    var isEmpty: Bool {
        totalLength == 0 || elements.isEmpty
    }
    
    // MARK: - Overlapping Slice Iteration Helper
    
    func forEachOverlappingSlice(in globalRange: Range<Int>, body: (VirtualElementSlice, Range<Int>) -> Void) {
        guard !globalRange.isEmpty else { return }
        for s in slices {
            if s.globalRange.upperBound <= globalRange.lowerBound { continue }
            if s.globalRange.lowerBound >= globalRange.upperBound { break }
            
            let overlapLower = max(s.globalRange.lowerBound, globalRange.lowerBound)
            let overlapUpper = min(s.globalRange.upperBound, globalRange.upperBound)
            if overlapLower < overlapUpper {
                let localRange = (overlapLower - s.globalRange.lowerBound)..<(overlapUpper - s.globalRange.lowerBound)
                body(s, localRange)
            }
        }
    }
    
    // MARK: - O(log N) Binary Search for Slices
    
    func slice(forGlobalOffset offset: Int) -> (slice: VirtualElementSlice, localOffset: Int)? {
        guard !slices.isEmpty else { return nil }
        let clamped = max(0, min(offset, totalLength))
        
        var low = 0
        var high = slices.count - 1
        
        while low <= high {
            let mid = (low + high) / 2
            let s = slices[mid]
            
            if s.globalRange.contains(clamped) || (clamped == s.globalRange.upperBound && clamped == totalLength) {
                let local = clamped - s.globalRange.lowerBound
                return (s, min(local, s.element.text.utf16.count))
            } else if clamped < s.globalRange.lowerBound {
                high = mid - 1
            } else {
                low = mid + 1
            }
        }
        
        if low < slices.count {
            return (slices[low], 0)
        }
        if let last = slices.last {
            return (last, last.element.text.utf16.count)
        }
        return nil
    }
    
    func text(in globalRange: Range<Int>) -> String {
        guard !globalRange.isEmpty else { return "" }
        let clampedLower = max(0, min(globalRange.lowerBound, totalLength))
        let clampedUpper = max(0, min(globalRange.upperBound, totalLength))
        guard clampedLower < clampedUpper else { return "" }
        
        let nsRange = NSRange(location: clampedLower, length: clampedUpper - clampedLower)
        if let range = Range(nsRange, in: fullText) {
            return String(fullText[range])
        }
        
        let utf16 = fullText.utf16
        let startIdx = utf16.index(utf16.startIndex, offsetBy: clampedLower, limitedBy: utf16.endIndex) ?? utf16.startIndex
        let endIdx = utf16.index(utf16.startIndex, offsetBy: clampedUpper, limitedBy: utf16.endIndex) ?? utf16.endIndex
        return String(utf16[startIdx..<endIdx]) ?? ""
    }
    
    func attributedString(in globalRange: Range<Int>) -> AttributedString {
        guard !globalRange.isEmpty else { return AttributedString() }
        var result = AttributedString()
        var previousSlice: VirtualElementSlice?
        
        forEachOverlappingSlice(in: globalRange) { slice, localRange in
            if let prev = previousSlice {
                result.append(AttributedString(prev.element.delimiter))
            }
            previousSlice = slice
            
            let baseAttr = slice.element.attributedString ?? AttributedString(slice.element.text)
            let text = slice.element.text
            let nsRange = NSRange(location: localRange.lowerBound, length: localRange.count)
            
            if let strRange = Range(nsRange, in: text),
               let attrStart = AttributedString.Index(strRange.lowerBound, within: baseAttr),
               let attrEnd = AttributedString.Index(strRange.upperBound, within: baseAttr) {
                result.append(baseAttr[attrStart..<attrEnd])
            } else {
                let utf16 = text.utf16
                let startIdx = utf16.index(utf16.startIndex, offsetBy: localRange.lowerBound, limitedBy: utf16.endIndex) ?? utf16.startIndex
                let endIdx = utf16.index(utf16.startIndex, offsetBy: localRange.upperBound, limitedBy: utf16.endIndex) ?? utf16.endIndex
                if let plainSlice = String(utf16[startIdx..<endIdx]) {
                    result.append(AttributedString(plainSlice))
                }
            }
        }
        
        return result
    }
    
    func perElementSelections(from globalRange: Range<Int>) -> [AnyHashable: Range<Int>] {
        var selections: [AnyHashable: Range<Int>] = [:]
        forEachOverlappingSlice(in: globalRange) { slice, localRange in
            selections[slice.element.id] = localRange
        }
        return selections
    }
    
    // MARK: - High-Performance Geometry Computations (Zero Allocation)
    
    func characterRect(atGlobalOffset offset: Int) -> CGRect {
        guard let (slice, localOffset) = slice(forGlobalOffset: offset) else {
            return .zero
        }
        let localRect = computeLocalCharacterRect(for: slice.element, charIndex: localOffset)
        return localRect.offsetBy(dx: slice.element.frame.minX, dy: slice.element.frame.minY)
    }
    
    func caretRect(atGlobalOffset offset: Int) -> CGRect {
        guard let (slice, localOffset) = slice(forGlobalOffset: offset) else {
            return .zero
        }
        let localRect = computeLocalCaretRect(for: slice.element, charIndex: localOffset)
        return localRect.offsetBy(dx: slice.element.frame.minX, dy: slice.element.frame.minY)
    }
    
    func lineSelectionRects(for globalRange: Range<Int>) -> [CGRect] {
        var result: [CGRect] = []
        forEachOverlappingSlice(in: globalRange) { slice, localRange in
            let rects = computeLocalSelectionRects(for: slice.element, range: localRange)
            for r in rects {
                result.append(r.offsetBy(dx: slice.element.frame.minX, dy: slice.element.frame.minY))
            }
        }
        return result
    }
    
    func closestGlobalOffset(to point: CGPoint) -> Int {
        guard !slices.isEmpty else { return 0 }
        
        // 1. Direct hit-test inside element bounding frames (with padding)
        for s in slices {
            let padded = s.element.frame.insetBy(dx: -2, dy: -2)
            if padded.contains(point) {
                let localPoint = CGPoint(x: point.x - s.element.frame.minX, y: point.y - s.element.frame.minY)
                let localIndex = computeLocalCharacterIndex(for: s.element, at: localPoint)
                return s.globalRange.lowerBound + localIndex
            }
        }
        
        // 2. Bound checks
        if let first = slices.first, point.y < first.element.frame.minY {
            return 0
        }
        if let last = slices.last, point.y > last.element.frame.maxY {
            return totalLength
        }
        
        // 3. Nearest 2D distance check (weighted vertical distance)
        var bestSlice = slices[0]
        var minDistance = CGFloat.greatestFiniteMagnitude
        
        for s in slices {
            let dx: CGFloat
            if point.x < s.element.frame.minX {
                dx = s.element.frame.minX - point.x
            } else if point.x > s.element.frame.maxX {
                dx = point.x - s.element.frame.maxX
            } else {
                dx = 0
            }
            
            let dy: CGFloat
            if point.y < s.element.frame.minY {
                dy = s.element.frame.minY - point.y
            } else if point.y > s.element.frame.maxY {
                dy = point.y - s.element.frame.maxY
            } else {
                dy = 0
            }
            
            let distance = (dy * dy * 4) + (dx * dx)
            if distance < minDistance {
                minDistance = distance
                bestSlice = s
            }
        }
        
        let localPoint = CGPoint(x: point.x - bestSlice.element.frame.minX, y: point.y - bestSlice.element.frame.minY)
        let localIndex = computeLocalCharacterIndex(for: bestSlice.element, at: localPoint)
        return bestSlice.globalRange.lowerBound + localIndex
    }
    
    // MARK: - Word & Paragraph Boundaries
    
    func wordRange(atGlobalOffset offset: Int) -> Range<Int>? {
        guard let (slice, localOffset) = slice(forGlobalOffset: offset) else { return nil }
        let text = slice.element.text
        let utf16 = text.utf16
        guard localOffset >= 0 && localOffset <= utf16.count && !text.isEmpty else { return nil }
        
        let targetIdx = min(localOffset, max(0, utf16.count - 1))
        let strIndex = utf16.index(utf16.startIndex, offsetBy: targetIdx, limitedBy: text.endIndex) ?? text.startIndex
        
        var found: Range<Int>?
        var closestFallback: Range<Int>?
        var minDistance = Int.max
        
        text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: .byWords) { _, range, _, stop in
            let start = text.utf16.distance(from: text.startIndex, to: range.lowerBound)
            let end = text.utf16.distance(from: text.startIndex, to: range.upperBound)
            let globalWordRange = (slice.globalRange.lowerBound + start)..<(slice.globalRange.lowerBound + end)
            
            if range.contains(strIndex) || (strIndex == text.endIndex && range.upperBound == strIndex) {
                found = globalWordRange
                stop = true
            } else {
                let dist = min(abs(start - targetIdx), abs(end - targetIdx))
                if dist < minDistance {
                    minDistance = dist
                    closestFallback = globalWordRange
                }
            }
        }
        return found ?? closestFallback
    }
    
    func paragraphRange(atGlobalOffset offset: Int) -> Range<Int>? {
        guard let (slice, localOffset) = slice(forGlobalOffset: offset) else { return nil }
        let text = slice.element.text
        let utf16 = text.utf16
        let clamped = max(0, min(localOffset, utf16.count))
        let strIndex = utf16.index(text.startIndex, offsetBy: clamped, limitedBy: text.endIndex) ?? text.startIndex
        let para = text.paragraphRange(for: strIndex..<strIndex)
        let start = text.utf16.distance(from: text.startIndex, to: para.lowerBound)
        let end = text.utf16.distance(from: text.startIndex, to: para.upperBound)
        return (slice.globalRange.lowerBound + start)..<(slice.globalRange.lowerBound + end)
    }
    
    // MARK: - Internal Cached Computation Helpers
    
    private func computeLocalCharacterIndex(for element: TextElementRegistration, at localPoint: CGPoint) -> Int {
        guard let layout = layoutCache[element.id] else { return 0 }
        let utf16Count = element.text.utf16.count
        guard utf16Count > 0, !layout.lines.isEmpty else { return 0 }
        
        var low = 0
        var high = layout.lines.count - 1
        var bestLine = layout.lines[0]
        var bestDistance = CGFloat.greatestFiniteMagnitude
        
        while low <= high {
            let mid = (low + high) / 2
            let line = layout.lines[mid]
            
            if localPoint.y >= line.top && localPoint.y <= line.bottom {
                bestLine = line
                break
            }
            
            let dist = abs(localPoint.y - line.centerY)
            if dist < bestDistance {
                bestDistance = dist
                bestLine = line
            }
            
            if localPoint.y < line.top {
                high = mid - 1
            } else {
                low = mid + 1
            }
        }
        
        let relativeX = localPoint.x - bestLine.origin.x
        let charIndex = CTLineGetStringIndexForPosition(bestLine.line, CGPoint(x: relativeX, y: 0))
        
        if charIndex == kCFNotFound {
            let lineWidth = CGFloat(CTLineGetTypographicBounds(bestLine.line, nil, nil, nil))
            let isRTL = element.layoutDirection == .rightToLeft
            if isRTL {
                return relativeX > lineWidth ? bestLine.range.location : (bestLine.range.location + bestLine.range.length)
            } else {
                return relativeX < 0 ? bestLine.range.location : (bestLine.range.location + bestLine.range.length)
            }
        }
        
        return min(max(0, charIndex), utf16Count)
    }
    
    private func computeLocalCaretRect(for element: TextElementRegistration, charIndex: Int) -> CGRect {
        let utf16Count = element.text.utf16.count
        guard utf16Count > 0, let layout = layoutCache[element.id], !layout.lines.isEmpty else {
            return CGRect(x: 0, y: 0, width: 2, height: max(16, element.frame.height))
        }
        
        let clampedIndex = max(0, min(charIndex, utf16Count))
        
        for (i, line) in layout.lines.enumerated() {
            let lineStart = line.range.location
            let lineEnd = lineStart + line.range.length
            
            if (clampedIndex >= lineStart && clampedIndex <= lineEnd) || (i == layout.lines.count - 1 && clampedIndex >= lineEnd) {
                let charOffsetInLine = min(clampedIndex, lineEnd)
                var secondaryOffset: CGFloat = 0
                let xOffset = CTLineGetOffsetForStringIndex(line.line, charOffsetInLine, &secondaryOffset)
                let finalX = line.origin.x + xOffset
                return CGRect(x: max(0, finalX), y: line.top, width: 2, height: line.height)
            }
        }
        
        return CGRect(x: 0, y: 0, width: 2, height: max(16, element.frame.height))
    }
    
    private func computeLocalCharacterRect(for element: TextElementRegistration, charIndex: Int) -> CGRect {
        let utf16Count = element.text.utf16.count
        guard utf16Count > 0, let layout = layoutCache[element.id], !layout.lines.isEmpty else {
            return CGRect(x: 0, y: 0, width: 10, height: max(16, element.frame.height))
        }
        
        let clampedIndex = max(0, min(charIndex, max(0, utf16Count - 1)))
        
        for line in layout.lines {
            let lineStart = line.range.location
            let lineEnd = lineStart + line.range.length
            if clampedIndex >= lineStart && clampedIndex < lineEnd {
                let startX = line.origin.x + CTLineGetOffsetForStringIndex(line.line, clampedIndex, nil)
                let endX = line.origin.x + CTLineGetOffsetForStringIndex(line.line, clampedIndex + 1, nil)
                return CGRect(
                    x: min(startX, endX),
                    y: line.top,
                    width: max(4, abs(endX - startX)),
                    height: line.height
                )
            }
        }
        
        let caret = computeLocalCaretRect(for: element, charIndex: charIndex)
        return CGRect(x: caret.minX, y: caret.minY, width: 10, height: caret.height)
    }
    
    private func computeLocalSelectionRects(for element: TextElementRegistration, range: Range<Int>) -> [CGRect] {
        guard let layout = layoutCache[element.id], !layout.lines.isEmpty else { return [] }
        var rects: [CGRect] = []
        
        for line in layout.lines {
            let lineStart = line.range.location
            let lineEnd = lineStart + line.range.length
            let overlapStart = max(range.lowerBound, lineStart)
            let overlapEnd = min(range.upperBound, lineEnd)
            
            guard overlapStart < overlapEnd else { continue }
            
            // Enumerate individual CTRun segments in the line for accurate Bidirectional / RTL highlights
            let runs = (CTLineGetGlyphRuns(line.line) as? [CTRun]) ?? []
            if runs.isEmpty {
                let startX = line.origin.x + CTLineGetOffsetForStringIndex(line.line, overlapStart, nil)
                let endX = line.origin.x + CTLineGetOffsetForStringIndex(line.line, overlapEnd, nil)
                rects.append(CGRect(
                    x: min(startX, endX),
                    y: line.top,
                    width: max(2, abs(endX - startX)),
                    height: line.height
                ))
            } else {
                for run in runs {
                    let runRange = CTRunGetStringRange(run)
                    let runStart = runRange.location
                    let runEnd = runStart + runRange.length
                    
                    let runOverlapStart = max(overlapStart, runStart)
                    let runOverlapEnd = min(overlapEnd, runEnd)
                    
                    if runOverlapStart < runOverlapEnd {
                        let startX = line.origin.x + CTLineGetOffsetForStringIndex(line.line, runOverlapStart, nil)
                        let endX = line.origin.x + CTLineGetOffsetForStringIndex(line.line, runOverlapEnd, nil)
                        rects.append(CGRect(
                            x: min(startX, endX),
                            y: line.top,
                            width: max(2, abs(endX - startX)),
                            height: line.height
                        ))
                    }
                }
            }
        }
        
        return rects
    }
}
